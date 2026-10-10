"""#205 scheduling workload candidate: source-level browser regression contracts.

These checks run under the existing Python-only Setup test workflow.
They do not replace disposable browser acceptance.
"""
from pathlib import Path

ROOT = Path(__file__).resolve().parent


def _read(name: str) -> str:
    return (ROOT / name).read_text(encoding="utf-8")


def test_changed_scheduling_scripts_have_fresh_browser_asset_pins():
    html = _read("production.html")
    assert "setup_next_pass.js?v=2026-10-09.324.5" in html
    assert "setup_scheduling_board.js?v=2026-10-09.324.5" in html


def test_board_workload_banner_stays_inside_shift_cell():
    js = _read("setup_scheduling_board.js")
    start = js.index("function board205Cell(")
    end = js.index("function board205CanRemoveWorkDay(", start)
    cell = js[start:end]
    assert "${board205WorkloadBanner(crew.setup_work_day_crew_id, shift)}" in cell
    start = js.index("function board205Day(")
    end = js.index("function board205RenderBoard(", start)
    day = js[start:end]
    assert "${board205Cell(day, 'MORNING', crew)}" in day
    assert "${board205Cell(day, 'AFTERNOON', crew)}" in day
    assert "${board205WorkloadBanner(crew.setup_work_day_crew_id, 'MORNING')}" not in day


def test_multi_selection_and_drag_drop_handlers_are_preserved():
    js = _read("setup_scheduling_board.js")
    for expected in (
        "event.ctrlKey || event.metaKey",
        "event.shiftKey",
        "selectedAssignmentIds",
        "card.addEventListener('dragstart'",
        "cell.addEventListener('drop'",
        "board205DropToCell(",
        "board205DraggedAssignmentItems(",
    ):
        assert expected in js
    assert "pointer-events:none;position:relative" in js


def test_perform_work_navigation_uses_existing_router_and_day_focus():
    perform = _read("setup_next_pass.js")
    board = _read("setup_scheduling_board.js")
    assert "navigateSetupView('schedule')" in perform
    assert "board205FocusWorkDate(date)" in perform
    assert "function board205FocusWorkDate(" in board
    assert "window.location.assign(url.toString())" not in perform


def test_perform_work_uses_stable_delegated_click_handler():
    js = _read("setup_next_pass.js")
    assert "target.dataset.manageScheduleInstalled" in js
    assert "target.addEventListener('click', async (event)" in js
    assert "event.target.closest('.next-perform-manage-day')" in js


def test_locked_cards_are_explicit_and_unlocked_cards_are_keyboard_selectable():
    js = _read("setup_scheduling_board.js")
    assert "Historical assignment — work reported; locked" in js
    assert "Historical actual — locked" in js
    assert "card.addEventListener('keydown'" in js


def test_annual_continuation_is_distinct_from_historical_assignment():
    js = _read("setup_scheduling_board.js")
    assert "function board205NeedsContinuation(task)" in js
    assert "Number(task.unworked_assignment_count || 0) === 0" in js
    assert "function board205ContinuationScheduled(task)" in js
    assert "function board205ReschedulingLabel(task)" in js
    assert "PRIORITY CONTINUATION" not in js
    assert "nextAssignmentReportedLabel(item)" in js
    assert "const priority = Number(board205NeedsContinuation(b))" in js


def test_historical_badges_use_assignment_report_evidence():
    perform = _read("setup_next_pass.js")
    board = _read("setup_scheduling_board.js")
    assert "nextAssignmentReportedLabel(item)" in board
    assert "nextAssignmentReportedLabel(assignment)" in perform
    assert "INCOMPLETE — Work Reported" in perform
    assert "COMPLETE — Work Reported" in perform
    assert "Number(assignment.work_report_count || 0) > 0" in perform


def test_reported_days_collapse_without_annual_completion_gate():
    board = _read("setup_scheduling_board.js")
    perform = _read("setup_next_pass.js")
    collapse = board.split("function board205CanCollapseDay(day)")[1].split("function board205Day(day)")[0]
    assert "effective_complete" not in collapse
    assert "actual_person_minutes" not in collapse
    assert "assignments.every(nextAssignmentReported)" in board
    assert "wholeDay.every(nextAssignmentReported)" in perform
    assert "setup-board205-toggle-day" in board
    assert "next-perform-toggle-complete-day" in perform
    assert "showCompleted || !nextAssignmentReported(assignment)" in perform


def test_late_and_captain_warnings_are_visible_in_both_views():
    perform = _read("setup_next_pass.js")
    board = _read("setup_scheduling_board.js")
    for source in (perform, board):
        assert "LATE — NO WORK REPORTED" in source
        assert "CAPTAIN TBD — NEEDS CAPTAIN" in source
        assert "lateCount" in source
    assert "timeZone: 'America/Chicago'" in perform
    assert "toISOString().slice(0, 10)" not in board
    assert "setup-board205-report-missed" in board
    assert "setupNextState.performCaptainFilter = 'ALL'" in board


def test_read_projection_preserves_assignment_and_legacy_report_identity():
    repository = _read("setup_scheduling_board_repository.py")
    for field in ("work_report_count", "reported_percent_complete"):
        before_field = repository.split(" AS " + field)[0].rsplit("(SELECT", 1)[1]
        assert "p.setup_work_day_task_id = wdt.setup_work_day_task_id" in before_field
        assert "p.setup_work_day_task_id IS NULL" in before_field
        assert "p.setup_work_day_id = wdt.setup_work_day_id" in before_field
        assert "p.setup_session_task_id = wdt.setup_session_task_id" in before_field
        assert "p.shift_code = wdt.shift_code" in before_field
