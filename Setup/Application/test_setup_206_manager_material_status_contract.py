from __future__ import annotations

from pathlib import Path

APP_DIR = Path(__file__).resolve().parent


def read(name: str) -> str:
    return (APP_DIR / name).read_text(encoding="utf-8")


def test_pick_list_needed_for_filter_keeps_manager_override_without_needed_for() -> None:
    ui = read("setup_pick_list.js")

    helper = ui.split("function reasonNeededForDate(reason)", 1)[1].split(
        "function itemReasonsForDate", 1
    )[0]
    assert "reason.manager_override_needed_for" in helper
    assert "|| reason.work_date" in helper
    assert "|| reason.manager_override_pick_by" in helper
    assert "|| reason.target_staged_by" in helper

    reasons = ui.split("function itemReasonsForDate(item, date)", 1)[1].split(
        "function stageScene", 1
    )[0]
    assert "reasonNeededForDate(reason) === date" in reasons

    dates = ui.split("function populateDates()", 1)[1].split(
        "function scopedPhysicalItems", 1
    )[0]
    assert ".map(reasonNeededForDate)" in dates
    assert "manager_override_needed_for" not in dates


def test_manager_material_status_is_manager_only_and_uses_existing_override_api() -> None:
    html = read("material_status.html")
    ui = read("setup_material_status.js")
    api = read("setup_material_readiness_api.py")
    backend = read("production_backend.py")
    root_html = read("production.html")
    root_ui = read("setup_production.js")

    assert "Manager Material Status" in html
    assert '@app.get("/material-status")' in backend
    assert "setup_material_status.css" in backend
    assert "setup_material_status.js" in backend
    assert 'id="manager-material-status-link"' in root_html
    assert "manager-only" in root_html
    assert "material-status/" in root_ui

    route = api.split(
        '@setup_material_readiness_api.get("/api/setup/material-status")', 1
    )[1].split(
        '@setup_material_readiness_api.post("/api/setup/material-readiness/overrides")', 1
    )[0]
    assert "require_manager()" in route
    assert "manager_material_status" in route

    assert "../api/setup/material-readiness/overrides" in ui
    assert "Add all" not in html
    assert "Remove all" not in html
    assert "Add All" not in ui
    assert "Remove All" not in ui


def test_manager_material_status_search_sort_and_date_edit_controls() -> None:
    html = read("material_status.html")
    ui = read("setup_material_status.js")

    assert 'id="search-filter" type="search"' in html
    assert "Display, Container, task, location, date, reason" in html
    assert '<option value="PICK_BY">Pick By</option>' in html
    assert '<option value="NEEDED_FOR">Needed For</option>' in html
    assert '<option value="HOME">Home Location</option>' in html
    assert '<option value="IDENTITY">Container / Display</option>' in html

    for token in (
        "item.identity",
        "item.label",
        "item.home_location_code",
        "effectivePickBy(item)",
        "effectiveNeededFor(item)",
        "override.pick_by_date",
        "override.needed_for_date",
        "override.override_reason",
        "reason.task_name",
        "reason.stage_key",
        "reason.stage_name",
        "reason.scene_name",
        "reason.work_date",
        "reason.display_names",
        "reason.display_ids",
    ):
        assert token in ui

    assert "Edit Dates / Override" in ui
    assert "function effectivePickBy(item)" in ui
    assert "function effectiveNeededFor(item)" in ui
    assert "function managerTimingText(item)" in ui
    assert "if (mode === 'PICK_BY')" in ui
    assert "if (mode === 'NEEDED_FOR')" in ui


def test_schedule_demand_never_replaces_manager_override() -> None:
    repo = read("setup_material_readiness_repository.py")
    ui = read("setup_material_status.js")

    assert "def manager_material_status(self, season_year: int)" in repo
    overlay = repo.split("for item in items:", 1)[1].split(
        "stage_rows: dict[int, dict[str, Any]]", 1
    )[0]

    assert 'if has_schedule_demand and has_override:' in overlay
    assert 'demand_source = "BOTH"' in overlay
    assert "schedule must not replace, deactivate, or rewrite an" in overlay
    assert 'item["can_remove_manager_override"] = bool(' in overlay
    assert "and has_override" in overlay
    assert "and has_schedule_demand" in overlay
    assert 'item["can_edit_pick_list_override"] = bool(' in overlay
    assert "and not moved" in overlay

    # Removing a Manager override from BOTH demand must leave schedule demand.
    assert "Schedule-derived Pick List demand will remain." in ui
    assert "The schedule never replaces or edits the Manager override automatically." in ui


def test_manager_material_status_safety_blocks_workshop_and_movement_overreach() -> None:
    repo = read("setup_material_readiness_repository.py")
    ui = read("setup_material_status.js")

    assert "c.goes_to_endpoint_id" in repo
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
    assert "!item?.can_remove_from_pick_list && !item?.can_remove_manager_override" in ui


def test_manager_material_status_batches_unscheduled_material_resolution() -> None:
    repo = read("setup_material_readiness_repository.py")

    assert "def _bulk_unscheduled_material_contexts(" in repo
    assert "is_real_setup_scene" in repo
    assert "is_stage_level_lor_group" in repo
    assert "ref.setup_task_display" in repo
    assert "ref.lor_scene_display" in repo
    assert "upper(status.display_status_name) = 'ACTIVE'" in repo
    assert "ref.setup_task_container_support" in repo

    manager = repo.split("def manager_material_status(", 1)[1].split(
        "def material_readiness(", 1
    )[0]
    assert "_bulk_unscheduled_material_contexts(" in manager
    assert "next_repo.field_context(" not in manager
    assert "SetupNextRepository(self.dsn)" not in manager



def test_manager_material_status_shows_contents_and_routes_unresolved_to_audit() -> None:
    html = read("material_status.html")
    ui = read("setup_material_status.js")

    assert 'id="open-material-audit"' in html
    assert "Unresolved material is read-only here." in html
    assert "function renderContents(item)" in ui
    assert "reason.display_names" in ui
    assert "reason.extra_material_name" in ui
    assert 'class="material-contents"' in ui
    assert "function renderReasons(item)" not in ui
    assert "location.href = '../material-audit/'" in ui


def test_manager_material_status_keeps_item_visible_when_override_changes_status() -> None:
    ui = read("setup_material_status.js")

    assert "statusFilter.value === 'UNSCHEDULED_PICKABLE'" in ui
    assert "statusFilter.value === 'SCHEDULED_TO_PICK'" in ui
    assert "statusFilter.value = ''" in ui
    assert "item.can_remove_from_pick_list" in ui
