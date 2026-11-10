"""#205/#122: historical Setup review remains navigable without changing work records.

These are source-contract checks that need no Node.js on Greg's workstation.
Real browser/operator acceptance remains required before Production release.
"""
from pathlib import Path

SOURCE = Path(__file__).with_name("setup_next_pass.js").read_text(encoding="utf-8")


def _section(start, end):
    return SOURCE.split(start, 1)[1].split(end, 1)[0]


def test_late_review_collapsed_and_retains_exact_assignment():
    section = _section(
        "function nextLateWorkSummary(assignments, board) {",
        "/* #205 Whole-Setup deadline dashboard"
    )
    assert '<details class="next-late-review"' in section
    assert 'data-assignment-id=' in section
    assert 'nextAssignmentLate(' in section
    assert 'nextPerformTask(item.setup_session_task_id)' in section
    assert "nextAssignmentReviewLabel(task)" in section


def test_search_includes_completed_historical_assignments_and_identity():
    section = _section(
        "function nextFilterPerformAssignments(assignments) {",
        "function nextCanSubmitFieldFinding()"
    )
    assert "setupNextState.performTaskSearch" in section
    assert "setup_session_task_id" in section
    assert "setup_work_day_task_id" in section
    assert "task.stage_name" in section
    assert "task.scene_name" in section
    assert "return assignments.filter(" in section
    assert "return nextPerformCaptainScopedAssignments(assignments)" in section


def test_hidden_late_card_shortcut_never_silently_submits_report():
    section = _section(
        "target.querySelectorAll('.next-late-report').forEach",
        "// Navigate through the existing route"
    )
    assert "setupNextState.performTaskSearch = String(id)" in section
    assert "renderNextExecution();" in section
    assert "details.scrollIntoView" in section
    assert "setAlert('Assignment #'" in section
    assert ".click()" not in section
    assert "commandOptions(" not in section


def test_existing_feedback_intake_remains_authoritative():
    assert "api/setup/session-tasks/${sessionTaskId}/correction-intake" in SOURCE
    assert "Submitted to Work Order Intake #" in SOURCE
    assert "openNextCorrectionIntake(details)" in SOURCE
