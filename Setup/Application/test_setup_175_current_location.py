"""Exercise the actual read projection and browser renderer for DBG-2026-001.

SQLite executes the repository's SELECTs with only PostgreSQL text casts and
parameter placeholders translated. This proves projection semantics locally;
it does not replace current-Production-clone PostgreSQL/privilege acceptance.
"""
from contextlib import contextmanager
from datetime import datetime
from decimal import Decimal
import json
from pathlib import Path
import re
import shutil
import sqlite3
import subprocess
import sys

import pytest

APP_DIR = Path(__file__).resolve().parent
sys.path.insert(0, str(APP_DIR))
from setup_next_repository import SetupNextRepository


class ProjectionCursor:
    def __init__(self, conn):
        self.conn = conn

    def __enter__(self):
        return self

    def __exit__(self, *args):
        return False

    def execute(self, sql, params):
        assert sql.lstrip().startswith(("WITH", "SELECT"))
        # Execute the real installed queries; expand PostgreSQL ANY array binds
        # into SQLite IN binds without replacing projection/join behavior.
        binds = iter(params)
        values = []

        def bind(match):
            value = next(binds)
            if match.group() != "%s":
                values.extend(value)
                return "IN (" + ",".join("?" for _ in value) + ")"
            values.append(value)
            return "?"

        translated = re.sub(r"=\s*ANY\(%s\)|%s", bind, sql.replace("::text", ""))
        self.rows = self.conn.execute(translated, values)

    def fetchone(self):
        row = self.rows.fetchone()
        return dict(row) if row is not None else None

    def fetchall(self):
        return [dict(row) for row in self.rows.fetchall()]


class ProjectionConnection:
    def __init__(self, conn):
        self.conn = conn

    def cursor(self, **kwargs):
        return ProjectionCursor(self.conn)


@pytest.fixture
def projection(monkeypatch):
    conn = sqlite3.connect(":memory:")
    conn.row_factory = sqlite3.Row
    conn.executescript("""
        ATTACH DATABASE ':memory:' AS ref;
        ATTACH DATABASE ':memory:' AS ops;
        CREATE TABLE ref.setup_task (setup_task_id INTEGER, lor_scene_id INTEGER);
        CREATE TABLE ref.setup_task_display (
            setup_task_id INTEGER, display_id INTEGER, relationship_type TEXT, notes TEXT);
        CREATE TABLE ref.lor_scene_display (lor_scene_id INTEGER, display_id INTEGER);
        CREATE TABLE ref.display (display_id INTEGER, display_name TEXT, container_id INTEGER);
        CREATE TABLE ref.container (container_id INTEGER, description TEXT, location_code TEXT);
        CREATE TABLE ref.stage (stage_id INTEGER, stage_key TEXT, stage_name TEXT);
        CREATE TABLE ref.setup_task_container_support (
            setup_task_id INTEGER, container_id INTEGER, relationship_type TEXT, notes TEXT);
        CREATE TABLE ops.setup_session (setup_session_id INTEGER, season_year INTEGER);
        CREATE TABLE ops.setup_container_state (
            setup_session_id INTEGER, container_id INTEGER, current_stage_id INTEGER,
            current_location_note TEXT, movement_status TEXT, last_movement_event_id INTEGER);
        CREATE TABLE ops.setup_display_state (
            setup_session_id INTEGER, display_id INTEGER, position_mode TEXT,
            current_stage_id INTEGER, current_location_note TEXT, movement_status TEXT,
            last_movement_event_id INTEGER);
        CREATE TABLE ops.setup_movement_event (
            setup_movement_event_id INTEGER, setup_session_id INTEGER, occurred_at TEXT,
            gps_latitude NUMERIC, gps_longitude NUMERIC, gps_accuracy_m NUMERIC,
            gps_fix_age_ms INTEGER, gps_quality TEXT, capture_method TEXT);
        INSERT INTO ops.setup_session VALUES (1, 2026), (2, 2025);
        INSERT INTO ref.setup_task VALUES (1, NULL), (2, 90);
        INSERT INTO ref.container VALUES (178, 'Steeple pallet', 'Z-BLDG-B-EAST');
        INSERT INTO ref.display VALUES (834, 'CH-Steeple-RH-Base', 178);
        INSERT INTO ref.setup_task_display VALUES (1, 834, 'REQUIRED', NULL);
        INSERT INTO ref.lor_scene_display VALUES (90, 834);
        INSERT INTO ref.setup_task_container_support VALUES (1, 178, 'KIT', NULL);
        INSERT INTO ref.stage VALUES (15, '15', 'Church-ParkingLot');
        INSERT INTO ops.setup_container_state VALUES (1, 178, NULL, NULL, 'PLACED', 44);
        INSERT INTO ops.setup_movement_event
            (setup_movement_event_id,setup_session_id,occurred_at,gps_latitude,gps_longitude,gps_accuracy_m,
             gps_fix_age_ms,gps_quality,capture_method) VALUES
            (41, 1, '2026-10-05T11:58:00-05:00', 43.778657, -87.749155, 1.58, 0, 'UNASSESSED', 'GPS'),
            (44, 1, '2026-10-05T14:50:00-05:00', 43.778556, -87.749142, 3.00, 0, 'UNASSESSED', 'TOUCH_SELECT');
    """)

    conn.executescript("""
        ALTER TABLE ops.setup_movement_event ADD COLUMN container_id INTEGER;
        ALTER TABLE ops.setup_movement_event ADD COLUMN destination_location_note TEXT;
        ALTER TABLE ops.setup_movement_event ADD COLUMN event_type TEXT;
        ALTER TABLE ops.setup_movement_event ADD COLUMN notes TEXT;
        ALTER TABLE ops.setup_movement_event ADD COLUMN destination_stage_id INTEGER;
    """)

    @contextmanager
    def connect():
        yield ProjectionConnection(conn)

    repo = SetupNextRepository("projection-fixture-only")
    monkeypatch.setattr(repo, "connect", connect)
    yield repo, conn
    conn.close()


def test_gps_only_container_and_attached_display_use_same_observation(projection):
    repo, conn = projection
    conn.execute("INSERT INTO ops.setup_display_state VALUES (1,834,'WITH_CONTAINER',15,'old', 'PICKED',41)")
    context = repo.field_context(task_id=1, season_year=2026)
    for item in (context["displays"][0], context["support_containers"][0]):
        assert item["current_location_kind"] == "GPS"
        assert item["current_stage_id"] is None
        assert item["current_location_note"] is None
        assert item["current_movement_status"] == "PLACED"
        assert item["current_movement_event_id"] == 44
        assert item["current_gps_latitude"] == 43.778556
        assert item["current_gps_longitude"] == -87.749142
        assert item["current_gps_accuracy_m"] == 3
        assert item["current_capture_method"] == "TOUCH_SELECT"
        assert item["home_location_code"] == "Z-BLDG-B-EAST"


def test_detached_display_keeps_unload_event_after_later_container_movement(projection):
    repo, conn = projection
    # A shared unload event is valid evidence for a detached Display.
    conn.execute("INSERT INTO ops.setup_display_state VALUES (1,834,'DETACHED',NULL,NULL,'TASK_UNLOAD',41)")
    conn.execute("UPDATE ops.setup_container_state SET current_stage_id=15, current_location_note='later drop'")
    context = repo.field_context(task_id=1, season_year=2026)
    display = context["displays"][0]
    container = context["support_containers"][0]
    assert display["current_location_kind"] == "GPS"
    assert display["current_movement_status"] == "TASK_UNLOAD"
    assert display["current_movement_event_id"] == 41
    assert display["current_observed_at"] == "2026-10-05T11:58:00-05:00"
    assert display["current_gps_latitude"] == 43.778657
    assert display["current_stage_id"] is None
    assert container["current_location_kind"] == "NAMED"
    assert container["current_movement_event_id"] == 44


def test_detached_display_with_no_observation_never_borrows_container_gps(projection):
    repo, conn = projection
    conn.execute("INSERT INTO ops.setup_display_state VALUES (1,834,'DETACHED',NULL,NULL,NULL,NULL)")
    item = repo.field_context(task_id=1, season_year=2026)["displays"][0]
    assert item["current_location_kind"] == "NONE"
    assert item["current_gps_latitude"] is None


def test_no_state_and_different_season_do_not_infer_home_as_current(projection):
    repo, _ = projection
    context = repo.field_context(task_id=1, season_year=2025)
    for item in (context["displays"][0], context["support_containers"][0]):
        assert item["current_location_kind"] == "NONE"
        assert item["current_movement_event_id"] is None
        assert item["home_location_code"] == "Z-BLDG-B-EAST"


def test_named_location_and_scene_derived_membership_are_preserved(projection):
    repo, conn = projection
    conn.execute("UPDATE ops.setup_container_state SET current_stage_id=15, current_location_note='beside tower'")
    item = repo.field_context(task_id=2, season_year=2026)["displays"][0]
    assert item["current_location_kind"] == "NAMED"
    assert item["current_stage_key"] == "15"
    assert item["current_location_note"] == "beside tower"
    assert item["relationship_source"] == "SCENE"


def test_movement_without_gps_remains_unnamed_and_cannot_reuse_old_event(projection):
    repo, conn = projection
    conn.execute("UPDATE ops.setup_container_state SET movement_status='IN_TRANSIT', last_movement_event_id=45")
    item = repo.field_context(task_id=1, season_year=2026)["displays"][0]
    assert item["current_location_kind"] == "UNRESOLVED_FIELD"
    assert item["current_movement_event_id"] == 45
    assert item["current_gps_latitude"] is None
    assert item["current_gps_accuracy_m"] is None


def test_event_join_is_scoped_to_current_session(projection):
    repo, conn = projection
    conn.execute("UPDATE ops.setup_movement_event SET setup_session_id=2 WHERE setup_movement_event_id=44")
    item = repo.field_context(task_id=1, season_year=2026)["displays"][0]
    assert item["current_location_kind"] == "UNRESOLVED_FIELD"
    assert item["current_gps_latitude"] is None


def _installed_production_location_case(case):
    """Run in a child process: Production's installers mutate repository methods."""
    monkeypatch = pytest.MonkeyPatch()
    fixture = projection.__wrapped__(monkeypatch)
    repo, conn = next(fixture)
    conn.executescript("""
        ALTER TABLE ref.setup_task ADD COLUMN task_name TEXT DEFAULT 'Steeples';
        ALTER TABLE ref.setup_task ADD COLUMN stage_id INTEGER DEFAULT 15;
        ALTER TABLE ref.setup_task ADD COLUMN requires_display_material INTEGER DEFAULT 1;
        ALTER TABLE ref.setup_task ADD COLUMN active_flag INTEGER DEFAULT 1;
        ALTER TABLE ref.setup_task ADD COLUMN task_action_type TEXT DEFAULT 'SETUP';
        ALTER TABLE ref.setup_task ADD COLUMN display_order INTEGER DEFAULT 1;
        ALTER TABLE ref.setup_task_display ADD COLUMN updated_at TEXT;
        ALTER TABLE ref.setup_task_display ADD COLUMN updated_by_person_id INTEGER;
        ALTER TABLE ref.display ADD COLUMN display_status_id INTEGER DEFAULT 1;
        CREATE TABLE ref.display_status (display_status_id INTEGER, display_status_name TEXT);
        INSERT INTO ref.display_status VALUES (1, 'ACTIVE');
        CREATE TABLE ref.lor_scene (
            lor_scene_id INTEGER, stage_id INTEGER, scene_name TEXT,
            scene_uuid TEXT, preview_uuid TEXT);
        INSERT INTO ref.lor_scene VALUES (90,15,'15-Steeples & Crosses',NULL,NULL);
        UPDATE ref.setup_task SET lor_scene_id=90;
        UPDATE ref.setup_task SET active_flag=0 WHERE setup_task_id=2;
        DELETE FROM ref.setup_task_display;
        INSERT INTO ref.container VALUES (177,'Left steeple','Z-BLDG-B-EAST');
        INSERT INTO ref.display VALUES
            (840,'CH-Steeple-RH-Top',178,1), (848,'CH-Steeple-RH-Mid',178,1),
            (853,'CH-Steeple-LH-Mid',177,1), (860,'CH-Steeple-LH-Top',177,1),
            (861,'CH-Steeple-LH-Base',177,1);
        INSERT INTO ref.lor_scene_display VALUES
            (90,840),(90,848),(90,853),(90,860),(90,861);
        INSERT INTO ops.setup_container_state VALUES (1,177,NULL,NULL,'CONTAINER_MOVE',43);
        UPDATE ops.setup_container_state SET movement_status='CONTAINER_MOVE';
        INSERT INTO ops.setup_movement_event
            (setup_movement_event_id,setup_session_id,occurred_at,gps_latitude,gps_longitude,gps_accuracy_m,
             gps_fix_age_ms,gps_quality,capture_method) VALUES
            (43,1,'2026-10-05T14:50:15-05:00',43.778465,-87.749201,3.00,0,'UNASSESSED','TOUCH_SELECT');
        INSERT INTO ops.setup_display_state
            SELECT 1,display_id,'DETACHED',NULL,NULL,'TASK_UNLOAD',
                CASE WHEN container_id=177 THEN 43 ELSE 44 END
            FROM ref.display;
    """)
    if case in ("continuity", "location_after_pick"):
        conn.execute("UPDATE ops.setup_display_state SET position_mode='WITH_CONTAINER'")
        conn.execute("UPDATE ops.setup_movement_event SET container_id=178,event_type='CONTAINER_MOVE' WHERE setup_movement_event_id=44")
        conn.execute("UPDATE ops.setup_movement_event SET container_id=177,event_type='CONTAINER_MOVE' WHERE setup_movement_event_id=43")
        conn.executescript("""
            INSERT INTO ops.setup_movement_event (setup_movement_event_id,setup_session_id,occurred_at,container_id,destination_location_note,event_type)
            VALUES (10,1,'2026-10-05T12:00:00-05:00',178,'15-Church-ParkingLot','CONTAINER_MOVE'),
                   (11,1,'2026-10-05T12:00:00-05:00',177,'15-Church-ParkingLot','CONTAINER_MOVE');
        """)
    elif case == "attached":
        conn.execute("UPDATE ops.setup_display_state SET position_mode='WITH_CONTAINER', last_movement_event_id=41")
    elif case == "later_parent":
        conn.execute("UPDATE ops.setup_container_state SET current_stage_id=15, current_location_note='later parent location', last_movement_event_id=41")
    elif case == "missing":
        conn.execute("UPDATE ops.setup_display_state SET movement_status=NULL,last_movement_event_id=NULL")
    elif case == "explicit":
        conn.execute("UPDATE ref.setup_task SET active_flag=1 WHERE setup_task_id=2")
        conn.execute("INSERT INTO ref.setup_task_display (setup_task_id,display_id,relationship_type) SELECT CASE WHEN display_id=834 THEN 2 ELSE 1 END,display_id,'REQUIRED' FROM ref.display")

    if case == "location_after_pick":
        conn.executescript("""
            INSERT INTO ops.setup_movement_event (setup_movement_event_id,setup_session_id,occurred_at,container_id,event_type)
            VALUES (50,1,'2026-10-05T16:00:00-05:00',178,'PICKED'),(51,1,'2026-10-05T16:00:00-05:00',177,'PICKED');
            UPDATE ops.setup_container_state SET movement_status='PICKED',last_movement_event_id=CASE WHEN container_id=177 THEN 51 ELSE 50 END;
        """)

    # Import the real host, which installs material -> ownership -> assignment
    # exactly as the disposable browser/Production process does.
    import production_backend
    import setup_next_api
    import setup_material_resolution

    monkeypatch.setenv("SETUP_DATABASE_DSN", "projection-fixture-only")
    monkeypatch.setattr(SetupNextRepository, "connect", lambda self: repo.connect())
    monkeypatch.setattr(setup_next_api, "require_reader", lambda: None)

    year = 2025 if case == "other_season" else 2026
    # Verify the underlying material/support projection as well as the final
    # assignment replacement. No repository result or location field is mocked.
    material = setup_material_resolution._field_context(repo, task_id=1, season_year=year)
    response = production_backend.app.test_client().get(
        f"/api/setup/tasks/1/field-context?season_year={year}")
    assert response.status_code == 200, response.get_data(as_text=True)
    context = response.get_json()["context"]
    assert len(material["displays"]) == 6
    assert len(context["displays"]) == (5 if case == "explicit" else 6)
    assert context["display_ownership"]["mode"] == ("EXPLICIT_MULTI" if case == "explicit" else "IMPLICIT_SINGLE")

    for item in [*material["displays"], *context["displays"], *context["display_ownership"]["assignments"]]:
        assert item["home_location_code"] == "Z-BLDG-B-EAST"
        if case in ("missing", "other_season"):
            assert item["current_location_kind"] == "NONE"
            assert item["current_gps_latitude"] is None
            assert item["current_nearest_reference"] is None
        else:
            assert item["current_location_kind"] == ("NAMED" if case in ("continuity", "location_after_pick") else "GPS")
            if case in ("continuity", "location_after_pick"):
                assert item["current_location_note"] == "15-Church-ParkingLot"
                assert item["current_named_context_inherited"]
            assert item["current_movement_event_id"] == ((51 if item["container_id"] == 177 else 50) if case == "location_after_pick" else (43 if item["container_id"] == 177 else 44))
            if case == "location_after_pick":
                assert item["current_movement_status"] == "PICKED"
                assert item["current_location_event_id"] == (43 if item["container_id"] == 177 else 44)
            assert item["current_gps_accuracy_m"] == 3
            assert item["current_gps_latitude"] == (43.778465 if item["container_id"] == 177 else 43.778556)
            reference = item["current_nearest_reference"]
            assert reference["name"] == "15-Church-Bells-CH"
            assert round(reference["distance_ft"]) == (46 if item["container_id"] == 177 else 76)
            assert reference["reference_set_version"] == "2026-stage-reference-20261003.1"
    support = context["support_containers"][0]
    assert support["current_location_kind"] == ("NONE" if case == "other_season" else "NAMED" if case in ("later_parent", "continuity", "location_after_pick") else "GPS")


@pytest.mark.parametrize("case", ["detached", "attached", "later_parent", "missing", "explicit", "other_season", "continuity", "location_after_pick"])
def test_installed_production_api_preserves_effective_movement_evidence(case):
    # Isolate method installers from the unit tests that exercise the base class.
    result = subprocess.run(
        [sys.executable, "-c", "from test_setup_175_current_location import _installed_production_location_case; "
         f"_installed_production_location_case({case!r})"],
        cwd=APP_DIR, capture_output=True, text=True, check=False,
    )
    assert result.returncode == 0, result.stdout + result.stderr


def test_field_context_api_serializes_postgresql_observation_types(monkeypatch, projection):
    from flask import Flask
    import setup_next_api

    repo, _ = projection
    context = repo.field_context(task_id=1, season_year=2026)
    display = context["displays"][0]
    display["current_gps_accuracy_m"] = Decimal("3.00")
    display["current_observed_at"] = datetime.fromisoformat(display["current_observed_at"])
    monkeypatch.setattr(repo, "field_context", lambda **kwargs: context)
    monkeypatch.setattr(setup_next_api, "repo", lambda: repo)
    monkeypatch.setattr(setup_next_api, "require_reader", lambda: None)
    app = Flask(__name__)
    app.register_blueprint(setup_next_api.setup_next_api)
    response = app.test_client().get("/api/setup/tasks/1/field-context?season_year=2026")
    assert response.status_code == 200
    payload = response.get_json()["context"]["displays"][0]
    assert payload["current_location_kind"] == "GPS"
    assert payload["current_gps_accuracy_m"] == "3.00"
    assert payload["current_observed_at"]


@pytest.mark.parametrize("evidence, kind", [
    ({"current_location_note": "RC05-A-01", "current_movement_status": "RETURNED"}, "NAMED"),
    ({"current_location_note": "   ", "home_location_code": "RC05-A-01"}, "NONE"),
    ({"current_gps_latitude": 0, "current_gps_longitude": 0}, "GPS"),
    ({"current_gps_latitude": 43, "current_movement_event_id": 1}, "UNRESOLVED_FIELD"),
])
def test_location_evidence_classification(evidence, kind):
    assert SetupNextRepository._field_location(evidence)["current_location_kind"] == kind


def test_nearest_waypoint_uses_recorded_fix_without_replacing_named_evidence():
    evidence = {"current_location_note": "operator-confirmed location",
                "current_gps_latitude": Decimal("43.778465"),
                "current_gps_longitude": Decimal("-87.749201")}
    result = SetupNextRepository._field_location(evidence.copy())
    assert result["current_location_kind"] == "NAMED"
    assert result["current_location_note"] == evidence["current_location_note"]
    assert result["current_gps_latitude"] == evidence["current_gps_latitude"]
    assert result["current_nearest_reference"]["name"] == "15-Church-Bells-CH"
    assert 46 < result["current_nearest_reference"]["distance_ft"] < 47


def test_missing_reference_set_preserves_recorded_coordinates(monkeypatch):
    import setup_location_evidence
    monkeypatch.setattr(setup_location_evidence, "_reference_set", lambda: {})
    result = SetupNextRepository._field_location({"current_gps_latitude": 43.778465,
                                                "current_gps_longitude": -87.749201})
    assert result["current_location_kind"] == "GPS"
    assert result["current_nearest_reference"] is None
    assert result["current_gps_latitude"] == 43.778465


def test_invalid_waypoints_and_observations_cannot_produce_nearest_labels(monkeypatch):
    import setup_location_evidence
    monkeypatch.setattr(setup_location_evidence, "_reference_set", lambda: {"points": [
        {"name": "bad", "latitude": "NaN", "longitude": -87},
        {"name": "outside", "latitude": 100, "longitude": -87},
    ]})
    for latitude, longitude in [(43, -87), (None, -87), ("NaN", -87), (True, -87), (43, 181)]:
        assert setup_location_evidence.nearest_recorded_reference(latitude, longitude) is None


def test_actual_browser_helpers_separate_current_from_home(projection):
    node = shutil.which("node")
    if node is None:
        pytest.skip("Node unavailable; run the renderer check on the engineering workstation")
    repo, _ = projection
    gps = repo.field_context(task_id=1, season_year=2026)["displays"][0]
    script = """
        const fs = require('fs');
        const vm = require('vm');
        const assert = require('node:assert/strict');
        const source = fs.readFileSync(process.argv[1], 'utf8');
        const start = source.indexOf('function nextLocationText(');
        const end = source.indexOf('function nextProgressAuditText(', start);
        function escapeHtml(value) {
          return String(value).replace(/[&<>"']/g, c => ({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));
        }
        vm.runInThisContext(source.slice(start, end));
        const gps = JSON.parse(process.argv[2]);
        const nearest = 'Current: near 15-Church-Bells-CH (76 ft)';
        assert.equal(nextLocationText(gps), nearest);
        assert.equal(nextLocationText({...gps, current_gps_accuracy_m: null}), nearest);
        assert.equal(nextLocationText({...gps, current_gps_accuracy_m: '', current_gps_quality: 'BAD'}), nearest + ' · GPS quality bad');
        assert.equal(nextLocationText({...gps, current_gps_accuracy_m: '1.58', current_gps_quality: 'QUESTIONABLE'}), nearest + ' · GPS quality questionable');
        assert.equal(nextLocationText({...gps, current_nearest_reference:null}), 'Current: GPS 43.778556, -87.749142');
        assert.equal(nextRecordedGpsText({current_gps_latitude:0,current_gps_longitude:0}), '0.000000, 0.000000');
        assert.equal(nextRecordedGpsText({current_gps_latitude:null,current_gps_longitude:0}), '');
        assert.equal(nextLocationText({current_location_kind:'UNRESOLVED_FIELD', home_location_code:'Z-BLDG-B-EAST'}), 'Current: Location recorded — unnamed');
        assert.equal(nextLocationText({home_location_code:'RC05-A-01'}), 'Current location not recorded');
        assert.equal(nextLocationText({current_stage_key:'15',current_stage_name:'Church-ParkingLot',current_location_note:'beside tower'}), 'Current: Stage 15 — Church-ParkingLot · beside tower');
        assert.equal(nextLocationText({current_location_kind:'NAMED',current_location_note:'RC05-A-01',current_movement_status:'RETURNED'}), 'Current: RC05-A-01');
        const markup = nextLocationMarkup(gps);
        assert.ok(markup.startsWith('<strong>' + nearest + '</strong>'));
        assert.ok(markup.includes(' · Home: Z-BLDG-B-EAST'));
        assert.ok(markup.includes('<details class="setup-location-details"><summary>GPS</summary>'));
        assert.ok(!markup.includes(' open'));
        assert.ok(markup.includes('Recorded GPS: 43.778556, -87.749142<br>Accuracy: ±10 ft'));
        assert.ok(nextLocationMarkup({...gps,current_gps_accuracy_m:'1.58'}).includes('Accuracy: ±6 ft'));
        assert.ok(!nextLocationMarkup({...gps,current_gps_accuracy_m:null}).includes('Accuracy:'));
        assert.ok(!nextLocationMarkup({...gps,current_gps_accuracy_m:-1}).includes('Accuracy:'));
        assert.ok(!nextLocationMarkup({home_location_code:'RC05-A-01'}).includes('<details'));
        assert.ok(source.includes("sheet.querySelectorAll('details.setup-location-details')"));
        assert.ok(nextLocationMarkup({...gps,current_nearest_reference:{name:'<img>',distance_ft:1}}).includes('&lt;img&gt;'));
        assert.ok(!nextLocationMarkup({current_location_note:'<script>',home_location_code:'<img>'}).includes('<script>'));
        assert.ok(nextLocationMarkup({current_location_note:'<script>',home_location_code:'<img>'}).includes('&lt;img&gt;'));
        // The older grouped overlay must also preserve each Display's location.
        const overlay = fs.readFileSync(process.argv[3], 'utf8');
        vm.runInThisContext(overlay.slice(overlay.indexOf('function acceptanceMaterialMarkup('), overlay.indexOf('const setupAcceptanceBaseLoadNextTaskExecution')));
        const grouped = acceptanceMaterialMarkup({displays: [gps, {...gps, display_id: 840, position_mode:'DETACHED', current_location_note:'separate placement'}]});
        assert.ok(grouped.includes(nearest));
        assert.ok(grouped.includes('Recorded GPS: 43.778556, -87.749142'));
        assert.ok(grouped.includes('Current: separate placement'));
        assert.ok(grouped.includes('Home: Z-BLDG-B-EAST'));
        console.log('Current/Home renderer behavior PASS');
    """
    result = subprocess.run([node, "-e", script, str(APP_DIR / "setup_next_pass.js"), json.dumps(gps),
                             str(APP_DIR / "setup_acceptance_fixes.js")],
                            check=True, capture_output=True, text=True)
    assert "renderer behavior PASS" in result.stdout
