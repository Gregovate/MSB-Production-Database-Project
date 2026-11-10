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


def test_actual_local_date_labor_is_separate_from_scheduled_occurrence():
    repo_source = (Path(__file__).with_name(
        "setup_scheduling_board_repository.py"
    )).read_text(encoding="utf-8")
    assert "p.performed_on = wd.work_date" in repo_source
    assert "st.setup_session_id = wd.setup_session_id" in repo_source
    assert "actual_date_person_minutes" in repo_source
    assert "actual_date_report_count" in repo_source
    render = _section("function renderNextExecution() {", "async function printNextPerformTask(")
    assert "const actualDayHours" in render
    assert "const assignmentHours" in render
    assert "person-hours performed on" in render
    assert "person-hours linked to scheduled assignments" in render


def test_qc_display_lookup_reuses_governed_identity_and_never_guesses_actor():
    api = (Path(__file__).with_name("setup_scheduling_board_api.py")).read_text(encoding="utf-8")
    repo = (Path(__file__).with_name("setup_scheduling_board_repository.py")).read_text(encoding="utf-8")
    assert "/api/setup/scheduling-board/qc-displays" in api
    assert "require_reader()" in api.split("def api_setup_qc_display_lookup", 1)[1].split("\n\n",1)[0]
    assert "ref.display d" in repo
    assert "ref.setup_task_display" in repo
    assert "EXPLICIT_TASK_OWNER" in repo
    assert "STAGE_CANDIDATE" in repo
    assert "p.performed_on" in repo
    assert "qc_display_lookup" in repo
    assert "INSERT INTO" not in repo.split("def qc_display_lookup(",1)[1].split("def upsert_work_day(",1)[0]


def test_qc_results_do_not_auto_submit_feedback_or_reshape_original_reports():
    section = _section("// #205 QC: only permanent Display IDs",
                       "function renderNextExecution() {")
    assert "next-qc-display-results" in SOURCE
    assert "Display matches for QC / work history" in section
    assert "Explicit owner" in section
    assert "Stage candidate" in section
    assert "next-qc-open-step" in section
    assert "api/setup/scheduling-board/qc-displays" in section
    assert "commandOptions(" not in section
    assert "setupNextState.performTaskSearch = id" in section
    assert "No scheduled assignment for this task" in section
