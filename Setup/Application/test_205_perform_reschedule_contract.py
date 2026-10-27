"""#205 Manager no-work rescheduling from Perform Work; no Production writes."""
from pathlib import Path

ROOT=Path(__file__).resolve().parents[1]
APP=Path(__file__).resolve().parent


def test_perform_work_manager_action_exists_without_task_context_or_work_report():
    ui=(APP/"setup_next_pass.js").read_text()
    assert "Reschedule · No work performed" in ui
    assert "nextCanRescheduleNoWork(assignment, task)" in ui
    assert "appState.access?.can_manage_setup" in ui
    assert "!assignment.historical_locked" in ui
    assert "!nextAssignmentReported(assignment)" in ui
    assert "nextOpenRescheduleNoWorkDialog(Number(details.dataset.assignmentId))" in ui
    assert "async function nextSubmitRescheduleNoWork(event)" in ui
    assert "api/setup/scheduling-board/assignments/" in ui
    assert "/crews/with-tasks" in ui
    assert "NO WORK WAS PERFORMED" in ui
    assert "await loadNextExecution()" in ui
    assert "Old late warning cleared" in ui
    # Context 404 must not prevent initiating the Manager-only reschedule.
    section=ui.split("function nextRescheduleNoWorkDialog()",1)[1].split(
        "\nfunction nextPerformLaborKpis(",1
    )[0]
    assert "field-context?" not in section
    assert "api/setup/session-tasks/" not in section
    assert "record_setup_task_progress" not in section


def test_no_automatic_one_percent_progress_when_no_report_exists():
    ui=(APP/"setup_next_pass.js").read_text()
    assert 'value="${lastPercent >= 1 ? lastPercent : \'\'}" required' in ui
    assert "Math.max(lastPercent, 1)" not in ui
    assert "min=\"1\" max=\"100\"" in ui
    assert "No progress recorded yet." in ui


def test_governed_move_records_old_date_without_data_repair():
    migration=(ROOT/"Database/069_fix_setup_day_sequence_and_audit.sql").read_text()
    for symbol in (
        "CREATE TABLE IF NOT EXISTS ops.setup_schedule_event",
        "'ASSIGNMENT_MOVED'",
        "from_work_date",
        "to_work_date",
        "from_shift_code",
        "to_shift_code",
        "from_crew_code",
        "to_crew_code",
        "p_setup_work_day_task_id",
    ):
        assert symbol in migration
    api=(APP/"setup_scheduling_board_api.py").read_text()
    assert '@setup_scheduling_board_api.patch(' in api
    assert "def api_setup_scheduling_board_assignment_update(" in api
    segment=api.split("def api_setup_scheduling_board_assignment_update(",1)[1].split(
        "@setup_scheduling_board_api.delete(",1
    )[0]
    assert "require_setup_command()" in segment
    assert "require_manager()" in segment
    assert "repo().update_assignment(" in segment
