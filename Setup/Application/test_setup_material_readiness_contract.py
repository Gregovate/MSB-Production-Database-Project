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



def test_206_pick_list_surface_remains_execution_only_with_manager_status_handoff() -> None:
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
    assert "Generated from the live Scheduling Board" in html
    assert "A workshop scan records an actual PICKED event." in html
    assert "@media print" in css
    assert "commandOptions(" in ui
    assert "../api/setup/material-readiness/overrides" not in ui
    assert 'id="manager-override-panel"' not in html
    assert "Edit Override" not in ui
    assert "Cancel Override" not in ui
    assert 'id="manager-material-status-link"' in html
    assert "../material-status/?season_year=" in ui
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
    assert '<option value="OUTSTANDING" selected>Needs pick</option>' in html
    assert '<option value="MOVED">Already moved</option>' in html
    assert "A workshop scan records an actual PICKED event." in html
    for heading in ("Container / Display", "Home Location", "Destination", "Pick By", "Needed For", "QR Code"):
        assert heading in ui
    assert "https://db.sheboyganlights.org/scan/" in ui
    assert "function humanReadableIdentity(item)" in ui
    assert "item.physical_type === 'CONTAINER'" in ui
    assert "padStart(3, '0')" in ui
    assert "humanReadableIdentity(item)" in ui
    assert "const type = item.physical_type === 'DISPLAY' ? 'DISP' : 'CONT';" in ui
    assert "new QRCode(" in ui
    assert "QRCode.CorrectLevel.M" in ui
    assert "function itemMoved(item)" in ui
    assert "last_movement_event_id" in ui
    assert 'class="location-cell"' in ui
    assert 'class="destination-cell"' in ui
    assert "Destination not resolved" in ui
    assert "NEEDS PICK" in ui



def test_pick_list_summary_totals_picked_containers_outside_working_filter() -> None:
    ui = read("setup_pick_list.js")
    css = read("setup_pick_list.css")

    assert "function scopedPhysicalItems(date = dateFilter?.value || '')" in ui
    assert "return (readiness?.physical_items || []).filter" in ui
    assert "function containersPickedCount(date = dateFilter?.value || '')" in ui
    assert "function renderSummary(date)" in ui
    assert "[\'Items to pick\', " in ui
    assert "[\'Delayed items\', " in ui
    assert "[\'Items already moved\', " in ui
    summary_block = ui.split("function renderSummary(date)", 1)[1].split("function itemDates", 1)[0]
    assert "Scheduled assignments" not in summary_block
    assert "const scopedItems = scopedPhysicalItems(date);" in ui
    assert "['Containers picked', containersPickedCount(date)]" in ui
    assert "item.physical_type === 'CONTAINER'" in ui
    assert "item.current_observation?.has_pick_event" in ui
    assert "renderSummary(date);" in ui
    assert "repeat(4,minmax(0,1fr))" in css


def test_later_demand_reports_existing_pick_state_without_error() -> None:
    html = read("pick_list.html")
    ui = read("setup_pick_list.js")
    assert '<option value="ALL">All demanded items</option>' in html
    assert '<option value="OUTSTANDING" selected>Needs pick</option>' in html
    assert '<option value="MOVED">Already moved</option>' in html
    assert "movement_status" in ui
    assert "'PICKED / MOVED'" in ui
    assert "last_observed_at" in ui
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



def test_pick_list_sorts_by_pick_deadline_then_physical_rack_walk_order() -> None:
    ui = read("setup_pick_list.js")
    html = read("pick_list.html")
    assert "function rackLocationParts(locationCode)" in ui
    assert "function compareHomeLocations(a, b)" in ui
    assert "function comparePickListOrder(a, b, selectedDate)" in ui
    assert "leftDates.pickBy" in ui
    assert "rightDates.pickBy" in ui
    assert "leftDates.neededFor" in ui
    assert "rightDates.neededFor" in ui
    assert "return compareHomeLocations(a, b);" in ui
    assert ".sort((a, b) => comparePickListOrder(a, b, date))" in ui
    assert ".sort(compareHomeLocations)" not in ui
    assert "left.row.localeCompare" in ui
    assert "left.column - right.column" in ui
    assert "left.level.localeCompare" in ui
    assert "left.slot - right.slot" in ui
    assert "setup_pick_list.js?v=2026-10-01.3" in html


def test_manager_pick_override_is_session_scoped_governed_demand_not_fake_task_assignment() -> None:
    api = read("setup_material_readiness_api.py")
    repo = read("setup_material_readiness_repository.py")
    migration = (DB_DIR / "060_add_setup_pick_list_manager_override.sql").read_text(encoding="utf-8")
    correction = (DB_DIR / "066_allow_manager_pick_override_cancel_after_movement.sql").read_text(encoding="utf-8")
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
    assert "CREATE OR REPLACE FUNCTION ops.set_setup_pick_list_override" in correction
    assert "Cannot cancel a Manager Pick List override after the Container has movement evidence" not in correction
    assert "Workshop Containers cannot be added to the Setup Pick List" in correction
    assert "c.goes_to_endpoint_id = 1" in correction
    assert "SETUP_206_PICK_LIST_OVERRIDE_DISPOSABLE_VALIDATION_PASS" in validation
    assert "Workshop-marked Container was incorrectly accepted" in validation
    assert "Editing Manager override timing created a second override identity" in validation
    assert "Manager override timing edit did not update the existing demand row" in validation
    assert "Manager override timing edit produced duplicate Container demand rows" in validation
    assert "Canceling Manager override incorrectly removed physical movement history" in validation
    assert "Canceling Manager override incorrectly changed current Container movement state" in validation
    assert "fieldwiring_app has forbidden broad Pick List override DML" in validation

    assert '@setup_material_readiness_api.post("/api/setup/material-readiness/overrides")' in api
    assert "require_setup_command()" in api
    assert "require_manager()" in api
    assert "set_pick_list_override" in repo
    assert '"demand_origin": "MANAGER_OVERRIDE"' in repo
    assert '"reason_type": "MANAGER_OVERRIDE"' in repo
    assert "create_setup_work_day_assignment" not in repo
    assert "set_setup_session_task_dependency" not in repo



def test_manager_material_status_is_manager_only_and_picker_link_fails_closed() -> None:
    picker_html = read("pick_list.html")
    picker_ui = read("setup_pick_list.js")
    status_html = read("material_status.html")
    status_ui = read("setup_material_status.js")
    api = read("setup_material_readiness_api.py")
    backend = read("production_backend.py")

    assert 'id="manager-material-status-link" type="button" hidden' in picker_html
    access_block = picker_ui.split("function applyAccess()", 1)[1].split(
        "function seasonFromUrl", 1
    )[0]
    assert "access?.can_manage_setup" in access_block
    assert "managerMaterialStatusLink.hidden" in access_block
    assert "Manager Material Status" in status_html
    assert '@app.get("/material-status")' in backend
    assert "setup_material_status.css" in backend
    assert "setup_material_status.js" in backend

    route = api.split(
        '@setup_material_readiness_api.get("/api/setup/material-status")', 1
    )[1].split(
        '@setup_material_readiness_api.post("/api/setup/material-readiness/overrides")', 1
    )[0]
    assert "require_manager()" in route
    assert "manager_material_status" in route

    # Override mutations remain protected even if a request is forged.
    assert "../api/setup/material-readiness/overrides" in status_ui
    set_route = api.split(
        '@setup_material_readiness_api.post("/api/setup/material-readiness/overrides")',
        1,
    )[1].split(
        '@setup_material_readiness_api.delete',
        1,
    )[0]
    assert "require_manager()" in set_route


def test_manager_material_status_owns_explicit_one_item_pick_list_controls() -> None:
    html = read("material_status.html")
    ui = read("setup_material_status.js")
    picker_html = read("pick_list.html")
    picker_ui = read("setup_pick_list.js")

    assert "Manager Material Status" in html
    assert "Add to Pick List" in html
    assert 'id="override-container-id" type="hidden"' in html
    assert 'id="override-pick-by" type="date" required' in html
    assert 'id="override-needed-for" type="date"' in html
    assert 'id="override-destination" required' in html
    assert 'id="override-reason"' in html
    assert "Pick By, Destination, and Reason are required." in ui
    assert "Needed For cannot be before Pick By." in ui
    assert "function openOverride(containerId, editing)" in ui
    assert "function removeOverride(containerId)" in ui
    assert "item.can_add_to_pick_list" in ui
    assert "item.can_remove_from_pick_list" in ui
    assert "item.can_edit_pick_list_override" in ui
    assert "Schedule demand and movement truth are never removed here." in ui
    assert "Add all" not in html
    assert "Remove all" not in html
    assert "Add All" not in ui
    assert "Remove All" not in ui

    # Rolling Pick List displays the demand badge but does not own override editing.
    assert 'id="manager-override-panel"' not in picker_html
    override_badge = picker_ui.split("function overrideBadgeHtml(item)", 1)[1].split(
        "function delayActionHtml", 1
    )[0]
    assert "MANAGER OVERRIDE" in override_badge
    assert "Edit Override" not in override_badge
    assert "Cancel Override" not in override_badge

def test_pick_list_qr_renderer_does_not_force_canvas_and_image_visible_together() -> None:
    css = read("setup_pick_list.css")
    assert ".pick-qr canvas,.pick-qr img,.pick-qr svg{width:96px!important" in css
    assert "display:block!important" not in css



def test_manager_material_status_searches_display_container_task_and_location() -> None:
    html = read("material_status.html")
    ui = read("setup_material_status.js")
    assert 'id="search-filter" type="search"' in html
    assert "Display, Container, task, home location" in html
    assert "function searchText(item)" in ui
    for token in (
        "item.identity",
        "item.label",
        "item.home_location_code",
        "reason.task_name",
        "reason.stage_key",
        "reason.stage_name",
        "reason.scene_name",
        "reason.display_names",
        "reason.display_ids",
    ):
        assert token in ui


def test_sunday_rule_applies_to_schedule_and_manager_status_override() -> None:
    projection = read("setup_material_readiness_projection.py")
    migration = (DB_DIR / "060_add_setup_pick_list_manager_override.sql").read_text(encoding="utf-8")
    ui = read("setup_material_status.js")
    assert "if target.weekday() == 6" in projection
    assert "Pick By cannot be Sunday; use Saturday or another day" in migration
    assert "function noSundayPickDate(value)" in ui
    assert "Sunday is not a pick day. Pick By moved to Saturday." in ui
    assert "noSundayPickDate(todayIso())" in ui


def test_manager_status_override_destination_uses_annual_stage_authority() -> None:
    html = read("material_status.html")
    ui = read("setup_material_status.js")
    api = read("setup_material_readiness_api.py")
    repo = read("setup_material_readiness_repository.py")
    migration = (DB_DIR / "060_add_setup_pick_list_manager_override.sql").read_text(encoding="utf-8")

    assert 'id="override-destination" required' in html
    assert "stageOptions()" in ui
    assert "destination_stage_id: Number(destinationInput.value)" in ui
    assert 'payload.get("destination_stage_id")' in api
    assert "JOIN ref.stage AS ds" in repo
    assert "destination_stage_key" in repo
    assert "destination_stage_name" in repo
    assert "destination_stage_id integer NOT NULL" in migration
    assert "Destination Stage is required for a Manager Pick List override" in migration
    assert "Destination Stage was not found" in migration


def test_manager_status_action_eligibility_blocks_workshop_schedule_and_movement_overreach() -> None:
    repo = read("setup_material_readiness_repository.py")
    ui = read("setup_material_status.js")
    source_api = read("setup_extra_material_api.py")
    correction = (DB_DIR / "066_allow_manager_pick_override_cancel_after_movement.sql").read_text(encoding="utf-8")

    assert "def manager_material_status(self, season_year: int)" in repo
    assert "c.goes_to_endpoint_id" in repo
    assert "endpoint_policy.get(int(item[\"physical_id\"])) == 1" in repo
    assert 'status = "PICKED_MOVED"' in repo
    assert 'status = "WORKSHOP"' in repo
    assert 'status = "SCHEDULED_TO_PICK"' in repo
    assert 'status = "UNSCHEDULED_PICKABLE"' in repo
    assert 'item["can_add_to_pick_list"] = bool(' in repo
    assert "and has_unscheduled_demand" in repo
    assert "and not has_schedule_demand" in repo
    assert "and not has_override" in repo
    assert "and not moved" in repo
    assert "and not workshop" in repo
    assert 'item["can_remove_from_pick_list"] = bool(' in repo
    assert 'item["can_remove_manager_override"] = bool(' in repo
    assert 'item["can_edit_pick_list_override"] = bool(' in repo
    assert "and has_override" in repo
    assert "and not has_schedule_demand" in repo
    assert "and has_schedule_demand" in repo
    assert "Container is already on the Pick List from scheduled material demand" in repo
    assert "c.goes_to_endpoint_id" in source_api
    assert "Workshop Containers cannot be added to the Setup Pick List" in correction
    assert "!item?.can_remove_from_pick_list && !item?.can_remove_manager_override" in ui

def test_manager_material_status_preserves_unscheduled_and_unresolved_annual_truth() -> None:
    repo = read("setup_material_readiness_repository.py")
    html = read("material_status.html")
    ui = read("setup_material_status.js")

    assert '"demand_origin": "UNSCHEDULED_ANNUAL"' in repo
    assert "SetupNextRepository(self.dsn)" in repo
    assert "next_repo.field_context" in repo
    assert "_extra_material_rows(candidate_task_ids, season_year)" in repo
    assert "Season-only annual work has no reusable material authority." in repo
    assert "Required Extra Material has no active expected-source Container." in repo
    assert '"demand_source":' not in html
    assert "PICKED / MOVED" in html
    assert "SCHEDULED TO PICK" in html
    assert "UNSCHEDULED / PICKABLE" in html
    assert "WORKSHOP / DO NOT MOBILIZE" in html
    assert "Unresolved" in html
    assert "unresolved_requirements" in ui
    assert "Unresolved material is shown for Manager review" in html


def test_print_pick_list_is_compact_and_uses_print_specific_values() -> None:
    ui = read("setup_pick_list.js")
    css = read("setup_pick_list.css")

    assert "function destinationPrintText(reasons)" in ui
    assert "function formatDatePrint(value)" in ui
    assert 'class="print-value"' in ui
    assert ".print-value{display:none}" in css
    assert ".screen-value{display:none!important}" in css
    assert ".print-value{display:inline!important}" in css
    assert ".summary,.pick-reasons-row,.pick-state,.override-state,.home-location-payload{display:none!important}" in css
    assert "table-layout:fixed" in css
    assert "border-collapse:collapse" in css
    assert ".pick-qr{width:68px;height:68px" in css
    assert "width:64px!important;height:64px!important" in css


def test_pick_list_tablet_layout_becomes_complete_card_without_horizontal_scroll() -> None:
    ui = read("setup_pick_list.js")
    css = read("setup_pick_list.css")

    assert 'class="date-cell pick-by-cell"' in ui
    assert 'class="date-cell needed-for-cell"' in ui
    assert "@media(max-width:1100px)" in css
    assert ".pick-table-wrap{overflow:visible}" in css
    assert ".pick-table{display:block;width:100%;min-width:0" in css
    assert 'grid-template-areas:' in css
    assert '"identity location qr"' in css
    assert '"destination destination qr"' in css
    assert '"pickby needed qr"' in css
    assert '.destination-cell::before{content:"Destination"}' in css
    assert '.pick-by-cell::before{content:"Pick By"}' in css
    assert '.needed-for-cell::before{content:"Needed For"}' in css
    assert ".pick-table{min-width:900px}" not in css
    assert ".pick-table{display:table;width:100%;min-width:0" in css


def test_pick_delay_is_transient_visible_filterable_and_schedule_released() -> None:
    api = read("setup_material_readiness_api.py")
    repo = read("setup_material_readiness_repository.py")
    ui = read("setup_pick_list.js")
    html = read("pick_list.html")
    css = read("setup_pick_list.css")
    migration = (DB_DIR / "063_add_setup_pick_list_delay.sql").read_text(encoding="utf-8")
    validation = (
        APP_DIR.parent / "Acceptance" / "setup_206_pick_delay_disposable_validation.sql"
    ).read_text(encoding="utf-8")

    assert "CREATE TABLE IF NOT EXISTS ops.setup_pick_list_delay" in migration
    assert "release_setup_session_task_ids bigint[] NOT NULL" in migration
    assert "DELETE FROM ops.setup_pick_list_delay" in migration
    assert "clear_setup_pick_list_delay_on_schedule" in migration
    assert "AFTER INSERT OR UPDATE OF setup_session_task_id" in migration
    assert "SETUP_206_PICK_DELAY_DISPOSABLE_VALIDATION_PASS" in validation
    assert "fieldwiring_app has forbidden broad Pick Delay DML" in validation

    assert '@setup_material_readiness_api.post("/api/setup/material-readiness/delays")' in api
    assert '"/api/setup/material-readiness/delays/<int:container_id>"' in api
    assert "set_pick_list_delay" in repo
    assert 'origins == {"DOWNSTREAM_FROM_SCHEDULE"}' in repo
    assert "Direct scheduled or Manager-override demand must remain actionable." in repo
    assert '"pick_delay_eligible"' in repo
    assert '"pick_delayed"' in repo

    assert 'id="show-delayed-picks"' in html
    assert "Show delayed picks" in html
    assert "DELAYED — DO NOT PICK YET" in ui
    assert "Delay Pick" in ui
    assert "Resume Pick" in ui
    assert "!showDelayedPicks?.checked && itemDelayed(item)" in ui
    assert ".pick-status.delayed" in css


def test_downstream_frontier_is_first_incomplete_material_not_contiguous_material_wave() -> None:
    projection = read("setup_material_readiness_projection.py")
    assert "first incomplete material-bearing task" in projection
    assert "found[current_id] = task" in projection
    assert "continue" in projection
    assert "material_wave_started" not in projection


def test_delayed_pick_warning_survives_print_when_delayed_rows_are_shown() -> None:
    ui = read("setup_pick_list.js")
    css = read("setup_pick_list.css")
    html = read("pick_list.html")

    assert 'class="print-delay-badge">DELAYED — DO NOT PICK YET</div>' in ui
    assert ".print-delay-badge{display:none" in css
    assert ".print-delay-badge{display:inline-block!important" in css
    assert "setup_pick_list.css?v=2026-10-01.1" in html
    assert "setup_pick_list.js?v=2026-10-01.3" in html
