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
        self.rows = self.conn.execute(sql.replace("::text", "").replace("%s", "?"), params)

    def fetchall(self):
        return self.rows.fetchall()


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
        INSERT INTO ops.setup_movement_event VALUES
            (41, 1, '2026-10-05T11:58:00-05:00', 43.778657, -87.749155, 1.58, 0, 'UNASSESSED', 'GPS'),
            (44, 1, '2026-10-05T14:50:00-05:00', 43.778556, -87.749142, 3.00, 0, 'UNASSESSED', 'TOUCH_SELECT');
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
        assert.equal(nextLocationText(gps), 'Current: GPS observation · ±10 ft');
        assert.equal(nextLocationText({...gps, current_gps_accuracy_m: null}), 'Current: GPS observation');
        assert.equal(nextLocationText({...gps, current_gps_accuracy_m: '', current_gps_quality: 'BAD'}), 'Current: GPS observation · GPS quality bad');
        assert.equal(nextLocationText({...gps, current_gps_accuracy_m: '1.58', current_gps_quality: 'QUESTIONABLE'}), 'Current: GPS observation · ±6 ft · GPS quality questionable');
        assert.equal(nextLocationText({current_location_kind:'UNRESOLVED_FIELD', home_location_code:'Z-BLDG-B-EAST'}), 'Current: Location recorded — unnamed');
        assert.equal(nextLocationText({home_location_code:'RC05-A-01'}), 'Current location not recorded');
        assert.equal(nextLocationText({current_stage_key:'15',current_stage_name:'Church-ParkingLot',current_location_note:'beside tower'}), 'Current: Stage 15 — Church-ParkingLot · beside tower');
        assert.equal(nextLocationText({current_location_kind:'NAMED',current_location_note:'RC05-A-01',current_movement_status:'RETURNED'}), 'Current: RC05-A-01');
        assert.equal(nextLocationMarkup(gps), '<strong>Current: GPS observation · ±10 ft</strong><br><span class="muted">Home storage: Z-BLDG-B-EAST</span>');
        assert.ok(!nextLocationMarkup({current_location_note:'<script>',home_location_code:'<img>'}).includes('<script>'));
        assert.ok(nextLocationMarkup({current_location_note:'<script>',home_location_code:'<img>'}).includes('&lt;img&gt;'));
        // The older grouped overlay must also preserve each Display's location.
        const overlay = fs.readFileSync(process.argv[3], 'utf8');
        vm.runInThisContext(overlay.slice(overlay.indexOf('function acceptanceMaterialMarkup('), overlay.indexOf('const setupAcceptanceBaseLoadNextTaskExecution')));
        const grouped = acceptanceMaterialMarkup({displays: [gps, {...gps, display_id: 840, position_mode:'DETACHED', current_location_note:'separate placement'}]});
        assert.ok(grouped.includes('Current: GPS observation · ±10 ft'));
        assert.ok(grouped.includes('Current: separate placement'));
        assert.ok(grouped.includes('Home storage: Z-BLDG-B-EAST'));
        console.log('Current/Home renderer behavior PASS');
    """
    result = subprocess.run([node, "-e", script, str(APP_DIR / "setup_next_pass.js"), json.dumps(gps),
                             str(APP_DIR / "setup_acceptance_fixes.js")],
                            check=True, capture_output=True, text=True)
    assert "renderer behavior PASS" in result.stdout
