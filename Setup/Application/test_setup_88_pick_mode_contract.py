from pathlib import Path

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


def test_pick_and_park_are_the_only_operator_modes_not_a_warehouse_action_grid():
    ui = read("setup_pick_mode.js")
    html = read("pick_list.html")

    assert 'id="start-pick-mode"' in html
    assert "Start Picking" in html
    assert 'id="start-park-mode"' in html
    assert "Park Scan" in html
    assert "MODE_PICK = 'PICK'" in ui
    assert "MODE_PARK = 'PARK'" in ui
    assert "'PICKED'" in ui
    assert "'CONTAINER_MOVE'" in ui
    assert "'DISPLAY_MOVE'" in ui
    assert "'RETURNED'" in ui

    for retired_button in (
        'data-movement-action="LOADED"',
        'data-movement-action="IN_TRANSIT"',
        'data-movement-action="UNLOADED"',
        'data-movement-action="STAGED"',
        'data-movement-action="PLACED"',
        'data-movement-action="RELOCATED"',
    ):
        assert retired_button not in html
    assert "movement-action-grid" not in html


def test_scanner_identity_remains_canonical_and_touch_manual_fallbacks_share_it():
    ui = read("setup_pick_mode.js")
    pick = read("setup_pick_list.js")
    html = read("pick_list.html")

    assert "/^(CONT|DISP):(\\d+)$/" in ui
    assert "HID_SCAN" in ui
    assert "MANUAL_ENTRY" in ui
    assert "TOUCH_SELECT" in ui
    assert "msb-movement-select" in ui
    assert "msb-movement-select" in pick
    assert 'id="movement-manual-input"' in html
    assert "PICK:" not in ui
    assert "PICK:" not in pick
    assert "https://db.sheboyganlights.org/scan/" in pick


def test_direct_park_shortcut_mode_is_explicit_and_rearms_only_from_url():
    ui = read("setup_pick_mode.js")
    pick = read("setup_pick_list.js")

    assert "url.searchParams.set('mode', 'park')" in ui
    assert "requested === 'park'" in ui
    assert "msb-pick-list-ready" in ui
    assert "msb-pick-list-ready" in pick


def test_park_mode_has_operator_controlled_gps_and_existing_reference_context():
    ui = read("setup_pick_mode.js")
    html = read("pick_list.html")

    assert "navigator.geolocation.watchPosition" in ui
    assert "navigator.geolocation.clearWatch" in ui
    assert "GPS OFF" in ui
    assert 'id="movement-gps-toggle"' in html
    assert "REFERENCE_POINTS" in ui
    assert "04-Food Collection-FC" in ui
    assert "30-Santa's Station-QV" in ui
    assert "Nearest:" in ui
    assert "gps_fix_at" in ui
    assert "gps_fix_age_ms" in ui
    assert "QUESTIONABLE" in ui
    assert "BAD" in ui


def test_mixed_container_ui_records_only_selected_display_groups_as_unloaded():
    ui = read("setup_pick_mode.js")
    html = read("pick_list.html")
    repository = read("setup_movement_repository.py")
    sql = migration()

    assert "What came off here?" in ui
    assert "anything not selected stays WITH_CONTAINER" in ui.lower()
    assert "unloaded_display_ids" in ui
    assert "container_contents" in repository
    assert "coalesce(ds.position_mode, 'WITH_CONTAINER')" in repository
    assert "bulk_selectable" in repository
    assert 'id="movement-unload-groups"' in html

    assert "p_unloaded_display_ids bigint[]" in sql
    assert "'UNLOADED'" in sql
    assert "'TASK_UNLOAD'" in sql
    assert "position_mode = 'DETACHED'" in sql
    assert "Grouped unload contains a Display that is not still WITH_CONTAINER" in sql


def test_repeated_container_and_display_observations_are_not_blocked_as_same_state():
    sql = migration()
    assert "v_action NOT IN ('CONTAINER_MOVE','DISPLAY_MOVE')" in sql
    assert "'CONTAINER_MOVE','DISPLAY_MOVE'" in sql


def test_movement_command_preserves_raw_gps_uncertainty_without_rewriting_reference_data():
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
    assert "UPDATE ref.container" not in sql
    assert "UPDATE ref.display" not in sql


def test_pick_mode_queue_is_durable_idempotent_and_allows_multiple_park_moves():
    ui = read("setup_pick_mode.js")
    sw = read("setup_pick_mode_sw.js")

    assert "indexedDB.open" in ui
    assert "client_event_id" in ui
    assert "occurred_at" in ui
    assert "offline_captured" in ui
    assert "queueRows()" in ui
    assert "syncQueue()" in ui
    assert "queuedPickKeys" in ui
    assert "movement_action === 'PICKED'" in ui
    assert "serviceWorker.register('service-worker.js'" in ui
    assert "networkFirst" in sw


def test_movement_api_uses_field_capability_and_governed_commands_only():
    api = read("setup_movement_api.py")
    repository = read("setup_movement_repository.py")

    assert "require_movement_operator()" in api
    assert "require_setup_command()" in api
    assert '@setup_movement_api.post("/api/setup/movements")' in api
    assert '@setup_movement_api.get("/api/setup/movements/container-contents")' in api
    assert "ops.record_setup_movement_event" in repository
    assert "INSERT INTO ops.setup_movement_event" not in repository
    assert "UPDATE ops.setup_container_state" not in repository
    assert "UPDATE ops.setup_display_state" not in repository


def test_online_workshop_pick_is_still_checked_against_authoritative_pick_list():
    api = read("setup_movement_api.py")
    assert "SetupMaterialReadinessRepository" in api
    assert "Asset is not on the current Pick List." in api
    assert "DELAYED — DO NOT PICK YET" in api
    assert 'movement_action == "PICKED" and not offline_captured' in api


def test_movement_migration_evolves_existing_tables_and_keeps_original_identity_model():
    sql = migration()

    assert "ALTER TABLE ops.setup_movement_event" in sql
    assert "ALTER TABLE ops.setup_container_state" in sql
    assert "ALTER TABLE ops.setup_display_state" in sql
    assert "CREATE TABLE" not in sql
    assert "CREATE UNIQUE INDEX IF NOT EXISTS uq_setup_movement_event_client_event" in sql
    assert "source_location_code text" in sql
    assert "captured_operator_email text" in sql
    assert "captured_operator_person_id integer" in sql


def test_display_detach_never_rewrites_permanent_container_assignment():
    sql = migration()
    assert "INSERT INTO ops.setup_movement_event_display" in sql
    assert "position_mode = 'DETACHED'" in sql
    assert "UPDATE ref.display" not in sql
    assert "UPDATE ref.container" not in sql


def test_pick_list_treats_physical_observations_as_outbound_until_returned():
    ui = read("setup_pick_list.js")
    repository = read("setup_material_readiness_repository.py")

    assert "movementStatus === 'RETURNED'" in ui
    assert "'CONTAINER_MOVE'" in ui
    assert "'DISPLAY_MOVE'" in ui
    assert "'TASK_UNLOAD'" in ui
    assert '"CONTAINER_MOVE"' in repository
    assert '"DISPLAY_MOVE"' in repository
    assert '"TASK_UNLOAD"' in repository


def test_current_state_exposes_latest_gps_quality_evidence():
    repository = read("setup_movement_repository.py")
    for token in (
        "me.gps_latitude",
        "me.gps_longitude",
        "me.gps_accuracy_m",
        "me.gps_fix_at",
        "me.gps_fix_age_ms",
        "me.gps_quality",
        "me.gps_quality_note",
        "me.capture_method",
        "me.offline_captured",
    ):
        assert token in repository


def test_disposable_validation_proves_stay_behind_follow_and_independent_display_move():
    sql = validation()

    assert "SETUP_88_MOVEMENT_CAPTURE_DISPOSABLE_VALIDATION_PASS" in sql
    assert "one Display stays here" in sql
    assert "Unselected Display was incorrectly detached from the Container" in sql
    assert "Display left at first stop incorrectly followed later Container movement" in sql
    assert "Independent Display move did not detach only that Display" in sql
    assert "Raw GPS uncertainty/reference evidence was not preserved" in sql
    assert "Repeated Container move was not recorded as a new observation" in sql
    assert "Pre-2026-10-05 park movement was incorrectly accepted" in sql
    assert "fieldwiring_app retains forbidden broad movement DML" in sql


def test_release_identity_and_offline_shell_are_synchronized():
    backend = read("production_backend.py")
    guard = read("setup_catalog_dirty_guard.js")
    sw = read("setup_pick_mode_sw.js")
    html = read("pick_list.html")

    assert 'PRODUCTION_VERSION = "V0.3.24-field-movement"' in backend
    assert "const CLIENT_BUILD = 'V0.3.24-field-movement';" in guard
    assert "msb-setup-pick-mode-v3" in sw
    assert "/api/setup/movements/container-contents" in sw
    assert "/api/setup/movements/state" in sw
    assert "setup_pick_mode.css?v=2026-09-30.4" in sw
    assert "setup_pick_mode.js?v=2026-09-30.4" in sw
    assert "setup_pick_list.js?v=2026-09-30.4" in sw
    assert "setup_pick_mode.css?v=2026-09-30.4" in html
    assert "setup_pick_mode.js?v=2026-09-30.4" in html
    assert "setup_pick_list.js?v=2026-09-30.4" in html


def test_movement_state_upserts_use_named_constraints_to_avoid_plpgsql_output_ambiguity():
    sql = migration()

    assert "ON CONFLICT ON CONSTRAINT pk_setup_container_state" in sql
    assert "ON CONFLICT ON CONSTRAINT pk_setup_display_state" in sql
    assert "ON CONFLICT (setup_session_id, container_id)" not in sql
    assert "ON CONFLICT (setup_session_id, display_id)" not in sql
