"""#205 Oct 16 V0.3.76 operator-rejected browser checks.
These source contracts supplement, not replace, the integrated disposable review.
"""
from pathlib import Path
APP = Path(__file__).parent


def source(name):
    return (APP / name).read_text(encoding="utf-8")


def test_workload_excludes_reported_assignments_and_keeps_continuation():
    board = source("setup_scheduling_board.js")
    am = board.split("function board205AmCapacity(", 1)[1].split(
        "\nfunction board205ShiftWorkload(", 1)[0]
    workload = board.split("function board205ShiftWorkload(", 1)[1].split(
        "\nfunction board205WorkloadBanner(", 1)[0]
    banner = board.split("function board205WorkloadBanner(", 1)[1].split(
        "\nfunction board205AmCapacityNote(", 1)[0]
    for snippet in (am, workload):
        assert "!nextAssignmentReported(item)" in snippet
    assert "w.count" in banner
    assert "hours scheduled" in banner
    assert "continue in PM" in banner
    assert "PM staffing needs a Manager decision" not in banner
    assert "total planned" not in banner
    assert "setup-board205-workload-banner" in banner


def test_crew_save_updates_only_its_banner_after_confirmed_patch():
    board = source("setup_scheduling_board.js")
    saver = board.split("async function board205SaveCrew(", 1)[1].split(
        "\nasync function board205EnsureCrewSaved(", 1)[0]
    assert "crew.am_planned_crew_count = saved.am_planned_crew_count" in saver
    assert "oldBanner.outerHTML = board205WorkloadBanner(crewId, shift)" in saver
    assert "daySummary.textContent = nextDayStaffingSummary(" in saver
    assert "setup-board205-plan-staffing" in saver
    assert "board205LaborHoursText(planned, task.expected_duration_minutes)" in saver
    assert "board205Load()" not in saver
    assert "Saved" in saver


def test_planning_range_is_validated_before_sql_and_full_editor_does_not_autosave():
    board = source("setup_scheduling_board.js")
    saver = board.split("async function board205PersistPlanningInfo(", 1)[1].split(
        "\nasync function board205SubmitPlanningInfo(", 1)[0]
    assert "draft.normal_crew_min > draft.normal_crew_max" in saver
    assert "maxInput?.setCustomValidity(message)" in saver
    assert "maxInput?.reportValidity()" in saver
    assert saver.index("draft.normal_crew_min > draft.normal_crew_max") < saver.index("await api(")
    opener = board.split(
        "document.getElementById('setup-board205-open-full-reusable')?.addEventListener", 1
    )[1].split("document.getElementById('setup-board205-season-form')", 1)[0]
    assert "board205PlanningInfoDirty() ? board205PlanningDraft() : null" in opener
    assert "setupNavigateToReusableTaskFromFinder(reusableTaskId)" in opener
    assert "edit-crew-min" in opener and "edit-crew-max" in opener
    assert "board205PersistPlanningInfo(" not in opener
    assert "Review the crew range, then Save Reusable Task" in opener


def test_action_center_is_selected_only_when_active_and_perform_scrolls():
    css = source("setup_next_pass.css")
    perform = source("setup_next_pass.js")
    assert 'button.tab[data-view="action-center"]:not(.active)' in css
    assert 'button.tab[data-view="action-center"].active' in css
    assert 'body:not(.setup-schedule-view) #perform-view' in css
    assert "next-perform-back-to-top" in perform
    assert "scrollIntoView(" in perform


def test_kit_inventory_has_durable_visible_setup_navigation():
    html = source("kit_inventory.html")
    css = source("setup_kit_inventory.css")
    assert 'aria-label="Setup navigation"' in html
    for page in ("?view=schedule", "?view=perform", "?view=action-center",
                 "?view=review", "inventory-back-setup"):
        assert page in html
    assert "position: sticky" in css
    assert ".inventory-setup-nav" in css
    assert "setup_kit_inventory.css?v=2026-10-16.2" in html


def test_scope_preserves_mandatory_task_estimates_and_disposable_sync():
    board = source("setup_scheduling_board.js")
    assert "Enter estimated ${missing.join(', ')} before scheduling" in board
    assert "MigrationPaths" not in board
    sql = (APP.parent / "Database/076_capture_2026_reusable_task_estimates.sql").read_text(encoding="utf-8")
    assert "sync_setup_task_estimates_to_2026" in sql
    assert "v_has_actual" in sql
