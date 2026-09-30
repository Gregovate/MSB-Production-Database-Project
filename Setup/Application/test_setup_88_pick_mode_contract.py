from pathlib import Path
import json

APP_DIR = Path(__file__).resolve().parent
ROOT = APP_DIR.parent


def read(name: str) -> str:
    return (APP_DIR / name).read_text(encoding="utf-8")


def migration() -> str:
    return (ROOT / "Database" / "065_add_setup_movement_capture.sql").read_text(
        encoding="utf-8"
    )


def validation() -> str:
    return (
        ROOT / "Acceptance" / "setup_88_movement_capture_disposable_validation.sql"
    ).read_text(encoding="utf-8")


def test_pick_list_defaults_to_needs_pick_and_keeps_back_navigation_while_scanning():
    html = read("pick_list.html")
    css = read("setup_pick_mode.css")

    assert '<option value="OUTSTANDING" selected>Needs pick</option>' in html
    assert 'id="back-button"' in html
    active_rule = next(
        line for line in css.splitlines()
        if line.startswith("body.pick-mode-active #print-button")
    )
    assert "#back-button" not in active_rule


def test_pick_list_is_workshop_only_and_record_location_is_separate():
    pick_html = read("pick_list.html")
    pick_ui = read("setup_pick_mode.js")
    location_html = read("record_location.html")
    location_ui = read("setup_record_location.js")
    backend = read("production_backend.py")

    assert 'id="start-pick-mode"' in pick_html
    assert "Start Picking" in pick_html
    assert "Park Scan" not in pick_html
    assert 'id="start-park-mode"' not in pick_html
    assert "CONTAINER_MOVE" not in pick_ui
    assert "DISPLAY_MOVE" not in pick_ui
    assert "movement_action: 'PICKED'" in pick_ui

    assert "<h1>Record Location</h1>" in location_html
    assert "CONTAINER_MOVE" in location_ui
    assert "DISPLAY_MOVE" in location_ui
    assert "RETURNED" in location_ui
    assert '@app.get("/record-location/")' in backend


def test_record_location_preserves_many_identity_entry_options_and_scan_handoff():
    ui = read("setup_record_location.js")
    html = read("record_location.html")

    assert "HID_SCAN" in ui
    assert "CAMERA_SCAN" in ui
    assert "MANUAL_ENTRY" in ui
    assert "TOUCH_SELECT" in ui
    assert "BarcodeDetector" in ui
    assert "/api/setup/movements/search" in ui
    assert "pageParams.get('asset')" in ui
    assert "/scan\\/(CONT|DISP)\\/(\\d+)" in ui
    assert 'id="movement-camera-toggle"' in html
    assert 'id="movement-search-input"' in html


def test_record_location_training_mode_uses_real_reads_but_never_writes_or_queues():
    ui = read("setup_record_location.js")
    html = read("record_location.html")

    assert 'id="training-entry"' in html
    assert '<summary>Training / device test</summary>' in html
    assert 'id="training-enter"' in html
    assert 'id="training-exit"' in html
    assert 'id="training-toggle"' not in html
    assert 'id="training-banner"' in html
    assert "TRAINING MODE — NOTHING WILL BE RECORDED" in html
    assert "const trainingMode = pageParams.get('training') === '1';" in ui
    assert "window.confirm(" in ui
    assert "enterTrainingMode" in ui
    assert "exitTrainingMode" in ui
    assert "Training Mode blocks Setup movement writes." in ui
    assert "Training Mode blocks the offline movement queue." in ui
    assert "if (trainingMode || syncing || !navigator.onLine) return;" in ui
    assert "if (navigator.onLine && !trainingMode) void syncQueue();" in ui
    assert "TRAINING — WOULD RECORD " in ui
    assert "NOTHING RECORDED" in ui
    assert "fetchContainerContents" in ui
    assert "fetchState" in ui
    assert "startGps" in ui


def test_record_location_gps_is_explicit_and_identity_can_precede_gps():
    ui = read("setup_record_location.js")
    html = read("record_location.html")

    assert "navigator.geolocation.watchPosition" in ui
    assert "navigator.geolocation.clearWatch" in ui
    assert "GPS OFF" in ui
    assert 'id="movement-gps-toggle"' in html
    assert "void initialize();" in ui
    initialize = ui.split("async function initialize()", 1)[1]
    assert "stopGps();" in initialize
    assert "startGps();" not in initialize
    assert "selectIdentity(identity, 'TOUCH_SELECT')" in initialize


def test_reference_locations_are_refreshable_versioned_and_not_hardcoded_in_js():
    ui = read("setup_record_location.js")
    sw = read("setup_record_location_sw.js")
    data = json.loads(read("setup_location_references.json"))

    assert "REFERENCE_POINTS" not in ui
    assert "location-references.json" in ui
    assert "REFERENCE_CACHE_KEY" in ui
    assert "referenceSet.version" in ui
    assert "location_reference_set=" in ui
    assert "location-references.json" in sw
    assert data["version"]
    assert data["source"] == "2026_msb.gpx"
    assert len(data["points"]) >= 30
    assert any(row["name"] == "04-Food Collection-FC" for row in data["points"])
    assert any(row["name"] == "30-Santa's Station-QV" for row in data["points"])


def test_record_location_offline_queue_is_durable_and_mixed_unload_fails_conservatively():
    ui = read("setup_record_location.js")
    sw = read("setup_record_location_sw.js")

    assert "indexedDB.open" in ui
    assert "client_event_id" in ui
    assert "occurred_at" in ui
    assert "offline_captured" in ui
    assert "syncQueue()" in ui
    assert "OBSERVATION QUEUED OFFLINE" in ui
    assert "Container contents unavailable." in ui
    assert "unloaded_display_ids" in ui
    assert "/api/setup/movements/container-contents" not in sw
    assert "/api/setup/movements/state" not in sw


def test_record_location_shell_and_pick_shell_are_network_first_for_navigation():
    pick_sw = read("setup_pick_mode_sw.js")
    location_sw = read("setup_record_location_sw.js")

    assert "networkFirst" in pick_sw
    assert "event.request.mode === 'navigate'" in pick_sw
    assert "networkFirst" in location_sw
    assert "event.request.mode === 'navigate'" in location_sw


def test_mixed_container_ui_records_only_selected_display_groups_as_unloaded():
    ui = read("setup_record_location.js")
    repository = read("setup_movement_repository.py")
    sql = migration()

    assert "What came off here?" in ui
    assert "Anything not selected stays WITH_CONTAINER" in ui
    assert "unloaded_display_ids" in ui
    assert "container_contents" in repository
    assert "coalesce(ds.position_mode, 'WITH_CONTAINER')" in repository
    assert "bulk_selectable" in repository

    assert "p_unloaded_display_ids bigint[]" in sql
    assert "'UNLOADED'" in sql
    assert "'TASK_UNLOAD'" in sql
    assert "position_mode = 'DETACHED'" in sql
    assert "material-access date" not in sql
    assert "DATE '2026-10-05'" not in sql
    assert "Grouped unload contains a Display that is not still WITH_CONTAINER" in sql


def test_movement_api_uses_field_capability_governed_command_and_asset_search():
    api = read("setup_movement_api.py")
    repository = read("setup_movement_repository.py")

    assert "require_movement_operator()" in api
    assert "require_setup_command()" in api
    assert '@setup_movement_api.post("/api/setup/movements")' in api
    assert '@setup_movement_api.get("/api/setup/movements/container-contents")' in api
    assert '@setup_movement_api.get("/api/setup/movements/search")' in api
    assert "def search_assets(" in repository
    assert "ops.record_setup_movement_event" in repository
    assert "INSERT INTO ops.setup_movement_event" not in repository
    assert "UPDATE ops.setup_container_state" not in repository
    assert "UPDATE ops.setup_display_state" not in repository


def test_online_workshop_pick_is_still_checked_against_authoritative_pick_list():
    api = read("setup_movement_api.py")
    readiness_repo = read("setup_material_readiness_repository.py")

    validator = api.split("def _validate_live_pick_demand(", 1)[1].split(
        "@setup_movement_api.get", 1
    )[0]
    assert "SetupMaterialReadinessRepository" in validator
    assert ".pick_demand_status(" in validator
    assert ".material_readiness(" not in validator
    assert "Asset is not on the current Pick List." in validator
    assert "DELAYED — DO NOT PICK YET" in validator
    assert 'movement_action == "PICKED" and not offline_captured' in api

    assert "def pick_demand_status(" in readiness_repo
    assert "def _matching_material_task_ids(" in readiness_repo
    focused = readiness_repo.split("def pick_demand_status(", 1)[1].split(
        "def material_readiness(", 1
    )[0]
    assert "field_context(" not in focused
    assert "material_readiness(" not in focused
    assert "ref.setup_task_display" in readiness_repo
    assert "ref.lor_scene_display" in readiness_repo
    assert "ref.setup_task_container_support" in readiness_repo
    assert "ref.setup_task_extra_material_source" in readiness_repo
    assert "ops.setup_pick_list_override" in readiness_repo
    assert "ops.setup_pick_list_delay" in readiness_repo



def test_focused_pick_validator_preserves_demand_delay_and_outbound_safety(monkeypatch):
    import setup_movement_api

    status = {
        "demanded": True,
        "pick_delayed": False,
        "current_observation": None,
    }

    class FakeReadinessRepository:
        def __init__(self, _dsn):
            pass

        def pick_demand_status(self, **_kwargs):
            return dict(status)

    monkeypatch.setattr(
        setup_movement_api,
        "SetupMaterialReadinessRepository",
        FakeReadinessRepository,
    )
    monkeypatch.setattr(setup_movement_api, "setup_database_dsn", lambda: "fake-dsn")

    setup_movement_api._validate_live_pick_demand(
        season_year=2026,
        asset_type="CONTAINER",
        asset_id=36,
    )

    status["demanded"] = False
    try:
        setup_movement_api._validate_live_pick_demand(
            season_year=2026,
            asset_type="CONTAINER",
            asset_id=36,
        )
    except setup_movement_api.SetupMovementConflictError as exc:
        assert "not on the current Pick List" in str(exc)
    else:
        raise AssertionError("non-demand asset was accepted for Pick")

    status.update({"demanded": True, "pick_delayed": True})
    try:
        setup_movement_api._validate_live_pick_demand(
            season_year=2026,
            asset_type="CONTAINER",
            asset_id=36,
        )
    except setup_movement_api.SetupMovementConflictError as exc:
        assert "DELAYED — DO NOT PICK YET" in str(exc)
    else:
        raise AssertionError("delayed asset was accepted for Pick")

    status.update({
        "pick_delayed": False,
        "current_observation": {"movement_status": "PICKED"},
    })
    try:
        setup_movement_api._validate_live_pick_demand(
            season_year=2026,
            asset_type="CONTAINER",
            asset_id=36,
        )
    except setup_movement_api.SetupMovementConflictError as exc:
        assert "already in PICKED movement state" in str(exc)
    else:
        raise AssertionError("already-outbound asset was accepted for Pick")

def test_movement_migration_preserves_raw_gps_and_permanent_assignment():
    sql = migration()

    for column in (
        "gps_latitude numeric(9,6)",
        "gps_longitude numeric(9,6)",
        "gps_accuracy_m numeric(10,2)",
        "gps_fix_at timestamptz",
        "gps_fix_age_ms integer",
        "gps_quality text",
        "gps_quality_note text",
    ):
        assert column in sql

    assert "gps_quality IN ('UNASSESSED','QUESTIONABLE','BAD')" in sql
    assert "UPDATE ref.display" not in sql
    assert "UPDATE ref.container" not in sql
    assert "position_mode = 'DETACHED'" in sql


def test_disposable_validation_still_proves_movement_semantics_and_least_privilege():
    sql = validation()

    assert "SETUP_88_MOVEMENT_CAPTURE_DISPOSABLE_VALIDATION_PASS" in sql
    assert "one Display stays here" in sql
    assert "Unselected Display was incorrectly detached from the Container" in sql
    assert "Display left at first stop incorrectly followed later Container movement" in sql
    assert "Independent Display move did not detach only that Display" in sql
    assert "Raw GPS uncertainty/reference evidence was not preserved" in sql
    assert "Repeated Container move was not recorded as a new observation" in sql
    assert "Real pre-2026-10-05 field observation was not recorded" in sql
    assert "Pre-access-date physical evidence was not preserved truthfully" in sql
    assert "fieldwiring_app retains forbidden broad movement DML" in sql


def test_release_identity_and_offline_shells_are_synchronized():
    backend = read("production_backend.py")
    guard = read("setup_catalog_dirty_guard.js")
    pick_sw = read("setup_pick_mode_sw.js")
    pick_html = read("pick_list.html")
    location_sw = read("setup_record_location_sw.js")
    location_html = read("record_location.html")

    assert 'PRODUCTION_VERSION = "V0.3.28-field-evidence"' in backend
    assert "const CLIENT_BUILD = 'V0.3.28-field-evidence';" in guard
    assert "msb-setup-pick-mode-v8" in pick_sw
    assert "setup_pick_mode.js?v=2026-09-30.7" in pick_sw
    assert "setup_pick_mode.js?v=2026-09-30.6" in pick_html
    assert "msb-setup-record-location-v6" in location_sw
    assert "setup_record_location.js?v=2026-09-30.6" in location_sw
    assert "setup_record_location.js?v=2026-09-30.5" in location_html


def test_movement_state_upserts_use_named_constraints_to_avoid_plpgsql_output_ambiguity():
    sql = migration()
    assert "ON CONFLICT ON CONSTRAINT pk_setup_container_state" in sql
    assert "ON CONFLICT ON CONSTRAINT pk_setup_display_state" in sql
    assert "ON CONFLICT (setup_session_id, container_id)" not in sql
    assert "ON CONFLICT (setup_session_id, display_id)" not in sql


def test_pick_list_training_mode_is_fail_closed_and_keeps_real_pick_totals_visible():
    html = read("pick_list.html")
    ui = read("setup_pick_mode.js")
    css = read("setup_pick_mode.css")
    list_ui = read("setup_pick_list.js")

    assert 'id="pick-training-entry"' in html
    assert '<summary>Training / device test</summary>' in html
    assert 'id="enter-pick-training"' in html
    assert 'id="exit-pick-training"' in html
    assert 'id="pick-training-banner"' in html
    assert "TRAINING MODE — NOTHING WILL BE RECORDED" in html
    assert 'id="pick-mode-containers-picked"' in html
    assert 'id="pick-mode-training-count"' in html
    assert 'class="pick-mode-toolbar-actions"' in html
    assert 'class="pick-mode-toolbar-counts"' in html
    assert "const trainingMode = pageParams.get('training') === '1';" in ui
    assert "Training Mode blocks Setup movement writes." in ui
    assert "Training Mode blocks the offline movement queue." in ui
    assert "if (trainingMode || syncing || !navigator.onLine) return;" in ui
    assert "TRAINING — WOULD PICK " in ui
    assert "NOTHING RECORDED" in ui
    assert "containersPickedCount" in list_ui
    assert "pick-mode-toolbar-counts" in css
    assert "settlePicked" in list_ui
    assert "settledPickEvidence" in list_ui
    assert "bridge().settlePicked(identity, movement)" in ui
    assert "void bridge().reload().catch" in ui


def test_record_location_requires_visible_location_review_before_record_action():
    html = read("record_location.html")
    ui = read("setup_record_location.js")
    css = read("setup_record_location.css")

    assert "3 · Review and record" in html
    assert 'id="movement-review-location"' in html
    assert 'id="movement-record-here" type="button" class="primary" disabled' in html
    assert 'id="movement-compact-status"' in html
    assert '<summary>Other location note</summary>' in html
    assert '<summary>Reference data</summary>' in html
    assert 'class="panel status-panel"' not in html
    assert "function currentLocationEvidence()" in ui
    assert "function renderRecordReadiness()" in ui
    assert "Location confirmed:" in ui
    assert "Choose a location first" in ui
    assert "scrollIntoView({behavior: 'smooth', block: 'start'})" in ui
    assert "locationNote.addEventListener('input', renderRecordReadiness)" in ui
    assert ".compact-status" in css
    assert 'id="movement-home-location"' in html
    assert "Home Location:" in ui
    assert "Manager correction required before return" in ui
    assert "Returned " in ui
    assert "home_location_code" in ui
