from pathlib import Path

APP_DIR = Path(__file__).resolve().parent
ROOT = APP_DIR.parent


def read(name: str) -> str:
    return (APP_DIR / name).read_text(encoding="utf-8")


def test_pick_mode_uses_existing_canonical_scanner_payload_and_no_pick_barcode():
    ui = read("setup_pick_mode.js")
    pick = read("setup_pick_list.js")
    html = read("pick_list.html")

    assert "/^(CONT|DISP):(\\d+)$/" in ui
    assert "capture_method: 'HID_SCAN'" in ui
    assert "PICK:" not in ui
    assert "PICK:" not in pick
    assert "function qrPayload(item)" in pick
    assert "https://db.sheboyganlights.org/scan/" in pick
    assert 'id="start-pick-mode"' in html
    assert "Start Picking" in html


def test_pick_mode_is_explicit_armed_scanner_flow_without_second_confirmation():
    ui = read("setup_pick_mode.js")
    html = read("pick_list.html")

    assert "function startMode()" in ui
    assert "movement_action: 'PICKED'" in ui
    assert "document.addEventListener('keydown', captureKeydown, true)" in ui
    assert "event.stopImmediatePropagation()" in ui
    assert "window.confirm" not in ui
    assert "READY — scan the next item" in ui
    assert "DELAYED — DO NOT PICK YET" in ui
    assert "NOT ON CURRENT PICK LIST" in ui
    assert "ALREADY QUEUED OFFLINE" in ui
    assert 'id="pick-mode-feedback"' in html


def test_pick_mode_hides_manager_mutation_controls_while_armed():
    css = read("setup_pick_mode.css")
    assert "body.pick-mode-active #manager-override-panel" in css
    assert "body.pick-mode-active .delay-pick" in css
    assert "body.pick-mode-active .resume-pick" in css
    assert "body.pick-mode-active .cancel-override" in css


def test_pick_mode_queue_is_durable_idempotent_and_reloads_fail_safe():
    ui = read("setup_pick_mode.js")
    sw = read("setup_pick_mode_sw.js")

    assert "indexedDB.open" in ui
    assert "client_event_id" in ui
    assert "occurred_at" in ui
    assert "offline_captured" in ui
    assert "queueRows()" in ui
    assert "syncQueue()" in ui
    assert "stopMode();" in ui
    assert "serviceWorker.register('service-worker.js'" in ui
    assert "material-readiness" in sw
    assert "/api/setup/access" in sw
    assert "networkFirst" in sw


def test_movement_api_uses_field_movement_capability_and_governed_command():
    api = read("setup_movement_api.py")
    repository = read("setup_movement_repository.py")

    assert "require_movement_operator()" in api
    assert "require_setup_command()" in api
    assert '@setup_movement_api.post("/api/setup/movements")' in api
    assert "ops.record_setup_movement_event" in repository
    assert "INSERT INTO ops.setup_movement_event" not in repository
    assert "UPDATE ops.setup_container_state" not in repository
    assert "UPDATE ops.setup_display_state" not in repository


def test_online_pick_is_checked_against_current_authoritative_pick_list():
    api = read("setup_movement_api.py")
    assert "SetupMaterialReadinessRepository" in api
    assert "Asset is not on the current Pick List." in api
    assert "DELAYED — DO NOT PICK YET" in api
    assert 'movement_action == "PICKED" and not offline_captured' in api


def test_movement_migration_evolves_existing_tables_instead_of_parallel_model():
    migration = (ROOT / "Database" / "065_add_setup_movement_capture.sql").read_text(
        encoding="utf-8"
    )

    assert "ALTER TABLE ops.setup_movement_event" in migration
    assert "ALTER TABLE ops.setup_container_state" in migration
    assert "ALTER TABLE ops.setup_display_state" in migration
    assert "CREATE TABLE" not in migration
    assert "client_event_id uuid" in migration
    assert "movement_status text" in migration
    assert "gps_latitude numeric(9,6)" in migration
    assert "gps_accuracy_m numeric(10,2)" in migration
    assert "source_location_code text" in migration
    assert "captured_operator_email text" in migration
    assert "captured_operator_person_id integer" in migration
    assert "CREATE UNIQUE INDEX IF NOT EXISTS uq_setup_movement_event_client_event" in migration


def test_movement_command_supports_idempotency_return_home_and_no_fake_destination():
    migration = (ROOT / "Database" / "065_add_setup_movement_capture.sql").read_text(
        encoding="utf-8"
    )

    assert "CREATE OR REPLACE FUNCTION ops.record_setup_movement_event" in migration
    assert "WHERE me.client_event_id = p_client_event_id" in migration
    assert "duplicate_event boolean" in migration
    assert "'PICKED'," in migration
    assert "'LOADED'," in migration
    assert "'IN_TRANSIT'," in migration
    assert "'RETURNED'" in migration
    assert "v_action = 'RETURNED' THEN v_home_location" in migration
    assert "source_location_code" in migration
    assert "Park movement cannot be recorded before the 2026-10-05 material-access date" in migration


def test_movement_command_does_not_rewrite_permanent_home_or_display_container():
    migration = (ROOT / "Database" / "065_add_setup_movement_capture.sql").read_text(
        encoding="utf-8"
    )
    assert "UPDATE ref.container" not in migration
    assert "UPDATE ref.display" not in migration
    assert "INSERT INTO ops.setup_movement_event_display" in migration
    assert "position_mode = 'DETACHED'" in migration


def test_pick_list_uses_explicit_movement_status_and_returned_is_pickable_again():
    ui = read("setup_pick_list.js")
    repository = read("setup_material_readiness_repository.py")

    assert "movementStatus === 'RETURNED'" in ui
    assert "'PICKED'" in ui
    assert "'LOADED'" in ui
    assert "movement_status" in repository
    assert "has_outbound_movement" in repository
    assert "has_legacy_unclassified_movement" in repository


def test_disposable_validation_checks_idempotency_authority_and_oct5_gate():
    validation = (
        ROOT / "Acceptance" / "setup_88_movement_capture_disposable_validation.sql"
    ).read_text(encoding="utf-8")

    assert "SETUP_88_MOVEMENT_CAPTURE_DISPOSABLE_VALIDATION_PASS" in validation
    assert "v_duplicate" in validation
    assert "Movement rewrote permanent Container Home Location" in validation
    assert "Display movement rewrote permanent Display-to-Container assignment" in validation
    assert "Pre-2026-10-05 park delivery was incorrectly accepted" in validation
    assert "Location-dependent movement was accepted without location evidence" in validation
    assert "Closed movement chain did not finish at RETURNED" in validation
    assert "v_transit_uuid" in validation
    assert "v_unload_uuid" in validation
    assert "v_stage_uuid" in validation
    assert "v_place_uuid" in validation
    assert "v_relocate_uuid" in validation
    assert "fieldwiring_app retains forbidden broad movement DML" in validation


def test_production_host_registers_movement_api_pick_mode_assets_and_service_worker():
    backend = read("production_backend.py")

    assert "from setup_movement_api import setup_movement_api" in backend
    assert "app.register_blueprint(setup_movement_api)" in backend
    assert '"setup_pick_mode.css"' in backend
    assert '"setup_pick_mode.js"' in backend
    assert '@app.get("/pick-list/service-worker.js")' in backend
    assert '"setup_pick_mode_sw.js"' in backend


def test_pick_mode_exposes_closed_loop_actions_and_gps_feedback():
    ui = read("setup_pick_mode.js")
    html = read("pick_list.html")

    for action in (
        "PICKED",
        "LOADED",
        "IN_TRANSIT",
        "UNLOADED",
        "STAGED",
        "PLACED",
        "RELOCATED",
        "RETURNED",
    ):
        assert f'data-movement-action="{action}"' in html
        assert action in ui

    assert "GPS_REQUIRED_ACTIONS" in ui
    assert "GPS ±" in ui
    assert "HOME LOCATION MISSING — MANAGER EXCEPTION" in ui
    assert "movement_action: currentAction" in ui
    assert "actionKey(" in ui


def test_current_state_exposes_latest_movement_gps_evidence():
    repository = read("setup_movement_repository.py")
    assert "me.gps_latitude" in repository
    assert "me.gps_longitude" in repository
    assert "me.gps_accuracy_m" in repository
    assert "me.capture_method" in repository
    assert "me.offline_captured" in repository


def test_return_requires_canonical_home_and_location_actions_require_evidence():
    migration = (ROOT / "Database" / "065_add_setup_movement_capture.sql").read_text(
        encoding="utf-8"
    )
    assert "Home Location is missing — Manager correction required before RETURNED" in migration
    assert "Location evidence is required for this movement action" in migration
    assert "CASE WHEN v_action = 'PICKED' THEN v_home_location ELSE NULL END" in migration


def test_movement_release_identity_is_distinct_and_synchronized():
    backend = read("production_backend.py")
    guard = read("setup_catalog_dirty_guard.js")
    assert 'PRODUCTION_VERSION = "V0.3.23-movement-loop"' in backend
    assert "const CLIENT_BUILD = 'V0.3.23-movement-loop';" in guard


def test_service_worker_serves_precached_assets_for_offline_cold_start():
    sw = read("setup_pick_mode_sw.js")
    html = read("pick_list.html")

    assert "msb-setup-pick-mode-v2" in sw
    assert "isPickListAssetRequest" in sw
    assert "caches.match(event.request)" in sw
    assert "/pick-list/assets/" in sw
    assert "setup_pick_mode.css?v=2026-09-30.1" in sw
    assert "setup_pick_mode.js?v=2026-09-30.1" in sw
    assert "setup_pick_mode.css?v=2026-09-30.1" in html
    assert "setup_pick_mode.js?v=2026-09-30.1" in html
