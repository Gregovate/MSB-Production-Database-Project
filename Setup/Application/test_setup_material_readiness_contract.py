from __future__ import annotations

from pathlib import Path


APP_DIR = Path(__file__).resolve().parent
DB_DIR = APP_DIR.parent / "Database"


def read(name: str) -> str:
    return (APP_DIR / name).read_text(encoding="utf-8")


def test_readiness_get_is_reader_authorized_and_never_writes_movement_or_schedule() -> None:
    api = read("setup_material_readiness_api.py")
    repo = read("setup_material_readiness_repository.py")
    assert '@setup_material_readiness_api.get("/api/setup/material-readiness")' in api
    assert "require_reader()" in api
    for forbidden in (
        "INSERT INTO ops.setup_movement_event",
        "UPDATE ops.setup_container_state",
        "UPDATE ops.setup_display_state",
        "DELETE FROM ops.setup_movement_event",
        "UPDATE ops.setup_session_task",
        "INSERT INTO ops.setup_work_day_task",
    ):
        assert forbidden not in repo


def test_readiness_consumes_current_authorities() -> None:
    repo = read("setup_material_readiness_repository.py")
    for token in (
        "ops.setup_work_day_task",
        "SetupNextRepository(self.dsn)",
        "field_context",
        "ref.setup_task_extra_material",
        "ref.setup_task_extra_material_source",
        "ops.setup_container_state",
        "ops.setup_display_state",
        "ops.setup_movement_event",
    ):
        assert token in repo


def test_readiness_preserves_detached_display_semantics() -> None:
    repo = read("setup_material_readiness_repository.py")
    assert 'position_mode == "DETACHED" or container_id is None' in repo
    assert 'key = ("DISPLAY", int(display["display_id"]))' in repo
    assert 'key = ("CONTAINER", int(container_id))' in repo



def test_readiness_surfaces_season_only_material_authority_gap() -> None:
    repo = read("setup_material_readiness_repository.py")
    assert "SEASON_ONLY_NO_REUSABLE_MATERIAL_AUTHORITY" in repo
    assert "SEASON_ONLY_MATERIAL_AUTHORITY" in repo
    assert "Review whether physical material is required before relying on the Pick List." in repo

def test_readiness_keeps_unsourced_extra_material_as_exception_without_audit_verification_blockers() -> None:
    repo = read("setup_material_readiness_repository.py")
    assert "Required Extra Material has no active expected-source Container." in repo
    assert "Extra Material requirement is not VERIFIED for Pick List use." not in repo
    assert "Expected-source Container is not VERIFIED for Pick List use." not in repo
    assert "source_verification_state" in repo
    assert "requirement_verification_state" in repo


def test_projection_implements_d_minus_one_and_reason_preservation() -> None:
    projection = read("setup_material_readiness_projection.py")
    assert "timedelta(days=1)" in projection
    assert 'item["reasons"].append(reason)' in projection
    assert 'item["target_staged_by"]' in projection


def test_production_host_registers_material_readiness_blueprint() -> None:
    host = read("production_backend.py")
    assert "from setup_material_readiness_api import setup_material_readiness_api" in host
    assert "app.register_blueprint(setup_material_readiness_api)" in host


def test_206_pick_list_surface_is_schedule_driven_with_narrow_manager_override() -> None:
    backend = read("production_backend.py")
    html = read("pick_list.html")
    ui = read("setup_pick_list.js")
    css = read("setup_pick_list.css")
    navigation_ui = read("setup_review_usability.js")

    assert '@app.get("/pick-list")' in backend
    assert "setup_pick_list.css" in backend
    assert "setup_pick_list.js" in backend
    assert "qrcode.min.js" in backend
    assert "assets/qrcode.min.js" in html
    assert "api/setup/material-readiness?season_year=" in ui
    assert "Physical items to pull / stage" in html
    assert "Material data exceptions" in html
    assert "Generated from the live Scheduling Board" in html
    assert "A workshop scan records that an item was actually picked/moved" in html
    assert "@media print" in css
    assert "commandOptions(" in ui
    assert "../api/setup/material-readiness/overrides" in ui
    assert "api/setup/scheduling-board/assignments" not in ui
    assert "setup-pick-list-link" in navigation_ui
    assert "pick-list/" in navigation_ui
    assert navigation_ui.index("Pick List") < navigation_ui.index("How Setup Works")



def test_early_demand_uses_annual_prerequisites_without_scheduling_mutation() -> None:
    repo = read("setup_material_readiness_repository.py")
    projection = read("setup_material_readiness_projection.py")
    assert "ref.setup_task_dependency" in repo
    assert "ops.setup_session_task_dependency" in repo
    assert "downstream_material_frontier" in repo
    assert '"demand_origin": "DOWNSTREAM_FROM_SCHEDULE"' in repo
    assert "scheduled_trigger_setup_session_task_id" in repo
    assert "def downstream_material_frontier(" in projection
    for forbidden in (
        "create_setup_work_day_assignment",
        "set_setup_annual_task_readiness",
        "execution_status = 'COMPLETE'",
        "UPDATE ops.setup_session_task",
    ):
        assert forbidden not in repo



def test_live_pick_list_surface_exposes_operational_columns_needs_pick_picked_and_qr() -> None:
    html = read("pick_list.html")
    ui = read("setup_pick_list.js")
    assert "Live 2026 Setup" in html
    assert "Rolling Pick List" in html
    assert 'id="pick-status-filter"' in html
    assert '<option value="ALL">All demanded items</option>' in html
    assert '<option value="OUTSTANDING">Needs pick</option>' in html
    assert '<option value="MOVED">Picked / moved</option>' in html
    assert "A workshop scan records that an item was actually picked/moved" in html
    for heading in ("Container / Display", "Home Location", "Destination", "Pick By", "Needed For", "QR Code"):
        assert heading in ui
    assert "https://db.sheboyganlights.org/scan/" in ui
    assert "new QRCode(" in ui
    assert "QRCode.CorrectLevel.M" in ui
    assert "function itemMoved(item)" in ui
    assert "last_movement_event_id" in ui
    assert 'class="location-cell"' in ui
    assert 'class="destination-cell"' in ui
    assert "Destination not resolved" in ui
    assert "NEEDS PICK" in ui



def test_later_demand_reports_existing_pick_state_without_error() -> None:
    html = read("pick_list.html")
    ui = read("setup_pick_list.js")
    assert '<option value="ALL">All demanded items</option>' in html
    assert '<option value="OUTSTANDING">Needs pick</option>' in html
    assert '<option value="MOVED">Picked / moved</option>' in html
    assert ">PICKED<" in ui
    assert "last_observed_at" in ui
    assert "currentLocationText(item)" in ui
    assert "Current location not resolved" in ui
    assert ">NEEDS PICK<" in ui



def test_pick_list_separates_physical_rows_and_emphasizes_home_location() -> None:
    ui = read("setup_pick_list.js")
    css = read("setup_pick_list.css")
    assert 'class="home-location-code"' in ui
    assert "LOC:" in ui
    assert "font-size:1.72rem" in css
    assert "font-weight:900" in css
    assert ".destination-cell{font-size:1.22rem" in css
    assert "border-spacing:0 .75rem" in css
    assert "border-top:2px solid" in css
    assert "border-left:2px solid" in css



def test_pick_list_defaults_to_physical_rack_walk_order() -> None:
    ui = read("setup_pick_list.js")
    assert "function rackLocationParts(locationCode)" in ui
    assert "function compareHomeLocations(a, b)" in ui
    assert ".sort(compareHomeLocations)" in ui
    assert "left.row.localeCompare" in ui
    assert "left.column - right.column" in ui
    assert "left.level.localeCompare" in ui
    assert "left.slot - right.slot" in ui


def test_manager_pick_override_is_session_scoped_governed_demand_not_fake_task_assignment() -> None:
    api = read("setup_material_readiness_api.py")
    repo = read("setup_material_readiness_repository.py")
    migration = (DB_DIR / "060_add_setup_pick_list_manager_override.sql").read_text(encoding="utf-8")
    validation = (APP_DIR.parent / "Acceptance" / "setup_206_pick_list_override_disposable_validation.sql").read_text(encoding="utf-8")

    assert "CREATE TABLE IF NOT EXISTS ops.setup_pick_list_override" in migration
    assert "UNIQUE (setup_session_id, container_id)" in migration
    assert "pick_by_date date NOT NULL" in migration
    assert "needed_for_date date" in migration
    assert "destination_stage_id integer NOT NULL" in migration
    assert "REFERENCES ref.stage(stage_id)" in migration
    assert "override_reason text NOT NULL" in migration
    assert "ref.setup_management_actor(p_email, false)" in migration
    assert "SECURITY DEFINER" in migration
    assert "ref.set_actor_on_insert()" in migration
    assert "ref.set_actor_on_update()" in migration
    assert "last_movement_event_id IS NOT NULL" in migration
    assert "Cannot cancel a Manager Pick List override after the Container has movement evidence" in migration
    assert "ops.set_setup_pick_list_override" in migration
    assert "SETUP_206_PICK_LIST_OVERRIDE_DISPOSABLE_VALIDATION_PASS" in validation
    assert "fieldwiring_app has forbidden broad Pick List override DML" in validation

    assert '@setup_material_readiness_api.post("/api/setup/material-readiness/overrides")' in api
    assert "require_setup_command()" in api
    assert "require_manager()" in api
    assert "set_pick_list_override" in repo
    assert '"demand_origin": "MANAGER_OVERRIDE"' in repo
    assert '"reason_type": "MANAGER_OVERRIDE"' in repo
    assert "create_setup_work_day_assignment" not in repo
    assert "set_setup_session_task_dependency" not in repo


def test_manager_override_ui_is_explicit_and_dedupes_into_normal_pick_rows() -> None:
    html = read("pick_list.html")
    ui = read("setup_pick_list.js")
    assert 'id="manager-override-panel"' in html
    assert "Add Container to Pick List" in html
    assert 'id="override-container-id"' in html
    assert 'id="override-pick-by"' in html
    assert 'id="override-needed-for"' in html
    assert 'id="override-destination-stage"' in html
    assert "Select destination Stage" in html
    assert 'id="override-reason"' in html
    assert "This does not schedule work or mark the Container picked." in html
    assert "MANAGER OVERRIDE" in ui
    assert "Cancel Override" in ui
    assert "Schedule-derived demand, if any, will remain." in ui
    assert "override_destination" in ui
    assert "../api/setup/stages" in ui
    assert "destination_stage_id" in ui
    assert "manager_override_needed_for" in ui
    assert "reason.reason_type === 'MANAGER_OVERRIDE'" in ui



def test_pick_list_qr_renderer_does_not_force_canvas_and_image_visible_together() -> None:
    css = read("setup_pick_list.css")
    assert ".pick-qr canvas,.pick-qr img,.pick-qr svg{width:96px!important" in css
    assert "display:block!important" not in css


def test_manager_override_container_selection_is_name_first_search() -> None:
    html = read("pick_list.html")
    ui = read("setup_pick_list.js")
    assert 'id="override-container-search"' in html
    assert 'placeholder="Search by Container name"' in html
    assert 'id="override-container-id" type="hidden"' in html
    assert "../api/setup/containers/source-options" in ui
    assert "containerSearchText(row)" in ui
    assert "container_description" in ui
    assert "home_location_code" in ui
    assert "Select a Container from the search results." in ui


def test_pick_list_sunday_rule_applies_to_schedule_and_manager_override() -> None:
    projection = read("setup_material_readiness_projection.py")
    migration = (DB_DIR / "060_add_setup_pick_list_manager_override.sql").read_text(encoding="utf-8")
    ui = read("setup_pick_list.js")
    assert "if target.weekday() == 6" in projection
    assert "Pick By cannot be Sunday; use Saturday or another day" in migration
    assert "function noSundayPickDate(value)" in ui
    assert "Sunday is not a pick day. Pick By moved to Saturday" in ui



def test_manager_override_destination_uses_governed_stage_authority() -> None:
    html = read("pick_list.html")
    ui = read("setup_pick_list.js")
    api = read("setup_material_readiness_api.py")
    repo = read("setup_material_readiness_repository.py")
    migration = (DB_DIR / "060_add_setup_pick_list_manager_override.sql").read_text(encoding="utf-8")

    assert 'id="override-destination-stage"' in html
    assert 'type="text" required placeholder="e.g. Food Collection / Mt Crumpit"' not in html
    assert "../api/setup/stages" in ui
    assert "loadDestinationStages" in ui
    assert "destination_stage_id: Number(overrideDestinationStage.value)" in ui
    assert 'payload.get("destination_stage_id")' in api
    assert "JOIN ref.stage AS ds" in repo
    assert "destination_stage_key" in repo
    assert "destination_stage_name" in repo
    assert "destination_stage_id integer NOT NULL" in migration
    assert "Destination Stage is required for a Manager Pick List override" in migration
    assert "Destination Stage was not found" in migration
