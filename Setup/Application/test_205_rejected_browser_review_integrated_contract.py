"""#205 October 15 rejection: all correction gates stay in ONE candidate."""
from pathlib import Path

APP = Path(__file__).parent


def read(name):
    return (APP / name).read_text(encoding="utf-8")


def test_manager_action_center_is_separate_protected_tab_not_scheduler_content():
    ui=read("setup_next_pass.js")
    nav=read("setup_production.js")
    board=read("setup_scheduling_board.js")
    assert "management.id = 'action-center-view'" in ui
    assert "actionButton.dataset.view = 'action-center'" in ui
    assert "actionButton.hidden = !appState.access?.can_manage_setup" in ui
    assert "loadSetup205ActionCenter()" in ui
    assert "setup205ActionCenterHtml(board) +" in ui
    summary=ui.split("function setup205DeadlineKpiHtml(",1)[1].split(
        "\nasync function loadSetup205ActionCenter()",1)[0]
    assert "setup205-kpi-glance" in summary
    assert "setup205ActionCenterHtml" not in summary
    assert "setup205-kpi-expand" not in summary
    assert "setup205WireManagementNavigation" in board
    assert "setup205WireActionCenter" not in board
    assert "if (name === 'action-center' && !appState.access?.can_manage_setup) return false" in nav
    assert "requestedView === 'action-center' && !appState.access?.can_manage_setup" in nav


def test_report_actual_time_fields_equal_sized_and_crew_readable():
    css=read("setup_next_pass.css")
    assert "unified operator rejection correction" in css
    assert ".next-report-work-form .next-report-work-grid .next-duration-hours" in css
    assert ".next-report-work-form .next-report-work-grid .next-duration-minutes" in css
    assert "grid-template-columns: repeat(2, minmax(0, 1fr))" in css
    assert "height: 48px" in css
    assert ".next-work-crew-field" in css
    assert "@media (max-width: 680px)" in css
    ui=read("setup_next_pass.js")
    for field in ("date","crew","hours","minutes","percent","notes"):
        assert "nextReportHelpButton('"+field+"')" in ui
    assert "wireNextReportHelp(form);" in ui
    assert "Full Report Work instructions" in ui
    assert "role=\"button\" tabindex=\"0\"" in ui
    assert "next-report-help-close" in ui
    assert "value=\"${lastPercent >= 1 ? lastPercent : ''}\"" in ui


def test_field_context_404_is_optional_but_progress_is_not():
    ui=read("setup_next_pass.js")
    fn=ui.split("async function loadNextTaskExecution(",1)[1].split(
        "\nasync function submitNextProgress(",1)[0]
    assert "const reusableTaskId = Number.isSafeInteger(taskId) && taskId > 0;" in fn
    assert "optional(api(" in fn
    assert "contextError" in fn
    assert "api(`api/setup/session-tasks/${sessionTaskId}/progress`)" in fn
    assert "Unable" not in fn or "Scheduled work context could not be loaded." in fn
    assert "next-report-work-form" in fn


def test_task_feedback_is_plain_language_but_172_intake_persists():
    ui=read("setup_next_pass.js")
    assert '>Task Feedback</button>' in ui
    assert "next-report-correction-submit" in ui
    assert "api/setup/session-tasks/${sessionTaskId}/correction-intake" in ui
    assert "Work Order Intake for Manager triage" in ui


def test_schedule_shows_active_work_instead_of_reported_card_clutter():
    ui=read("setup_scheduling_board.js")
    css=read("setup_scheduling_board.css")
    assert 'id="setup-board205-show-reported-tasks" type="checkbox"' in ui
    assert "function board205ActiveAssignmentsFor(" in ui
    assert "rows.filter(item => !nextAssignmentReported(item))" in ui
    assert "setup-board205-completed-crew-summary" in ui
    assert "historyToggle.checked = true;" in ui
    assert "position: sticky;" in css and ".setup-board205-day-header" in css
    assert ".setup-board205-day.day-band-even" in css
    assert ".setup-board205-day.day-band-odd" in css


def test_no_work_and_weather_reschedules_are_integrated_and_manager_guarded():
    ui=read("setup_next_pass.js")
    api=read("setup_scheduling_board_api.py")
    repo=read("setup_scheduling_board_repository.py")
    assert "Reschedule · No work performed" in ui
    assert "nextOpenRescheduleNoWorkBatch(" in ui
    assert "next-reschedule-unworked-shift" in ui
    assert "nextCanRescheduleNoWork" in ui
    assert "NO WORK WAS PERFORMED" in ui
    assert "bulk-reschedule" in ui and "bulk-reschedule" in api
    assert "require_manager()" in api
    assert "bulk_reschedule_unworked(" in repo
    assert "ops.update_setup_work_day_assignment" in repo
    assert "conn.commit()" in repo
    assert "with-tasks" in ui and "with-tasks" in api
