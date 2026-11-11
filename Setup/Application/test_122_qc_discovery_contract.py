"""#122: final QC list must be independent of scheduled work and PR483-safe.

This is a source/contract regression gate, NOT end-to-end browser approval.
Actual QC writing requires a separate governed migration and acceptance.
"""
from pathlib import Path

APP = Path(__file__).resolve().parent
JS = (APP / "setup_next_pass.js").read_text(encoding="utf-8")
CSS = (APP / "setup_next_pass.css").read_text(encoding="utf-8")
HTML = (APP / "production.html").read_text(encoding="utf-8")


def segment(start: str, end: str) -> str:
    return JS.split(start, 1)[1].split(end, 1)[0]


def test_final_qc_search_uses_all_annual_tasks_not_assignments():
    finder = segment("function nextQcAnnualTasks()", "function nextQcEnsureDiscovery()")
    assert "setupNextState.performBoard.tasks || []" in finder
    assert "filter(nextIsFinalShowQc)" in finder
    assert "return (setupNextState.performBoard.assignments" not in finder
    assert "task.setup_session_task_id" in finder
    assert "task.setup_task_id" in finder
    assert "task.stage_name" in finder
    assert "task.scene_name" in finder
    assert "task.execution_status" in finder
    assert "task.annual_readiness_state" in finder


def test_qc_controls_do_not_create_schedule_or_simulate_saved_qc():
    qc = segment("// #122 QC discovery:", "function renderNextExecution()")
    assert "Scheduled Work" in qc
    assert "QC Check" in qc
    assert "next-qc-search" in qc
    assert "Never scheduled" in qc
    assert "task.prerequisites_complete" in qc
    assert "Report Fixes" in qc
    assert "window.setupQcRenderCurrent" in qc
    assert "No QC PASS or repair status is inferred" in qc
    assert "commandOptions(" not in qc
    assert "/api/setup/" not in qc
    assert "POST" not in qc
    assert "INSERT" not in qc


def test_qc_mode_keeps_existing_scheduled_reporting_intact():
    render = segment("function renderNextExecution() {", "const allAssignments =")
    assert "nextEnsurePerformToolbar();" in render
    assert "nextQcEnsureDiscovery();" in render
    # Both QC Check and Report Fixes must bypass scheduled-work rendering.
    assert "if (nextQcDiscovery.mode !== 'work') return;" in render
    assert "next-perform-list" in render
    assert "next-perform-show-completed" in JS
    assert "submitNextCorrectionIntake" in JS
    assert "nextAssignmentLate" in JS


def test_theme_safe_qc_and_fresh_asset_pins():
    assert "background: var(--card" in CSS
    assert "color: var(--text" in CSS
    assert ".next-qc-row" in CSS
    assert 'setup_next_pass.js?v=2026-11-11.111.9' in HTML
    assert 'setup_next_pass.css?v=2026-11-11.111.9' in HTML
    assert "V0.3.111-explicit-no-work" in (APP / "production_backend.py").read_text()


def test_final_qc_regex_and_multiword_search_are_executable_javascript_patterns():
    # A literal double backslash matches backslash+s, not spaces; it can
    # silently return zero QC tasks even when the annual tasks are present.
    assert r"/plug\s+in\s+network\s+to\s+controller.*2\s+minute\s+test\s+show/i" in JS
    assert r"/plug\\s+in" not in JS
    assert r"query.split(/\s+/)" in JS
    assert r"query.split(/\\s+/)" not in JS


def test_qc_report_and_fixes_share_the_exact_same_finding_identity():
    client = (APP / 'setup_qc.js').read_text(encoding='utf-8')
    assert 'setup_session_task_id' in client
    assert 'qc_finding_id' in client
    assert 'REPORT' in client and 'OBSERVATION' in client
    assert 'CLAIM_REPAIR' in client and 'REPAIRED' in client
    assert 'RETEST_PASS' in client and 'RETEST_FAIL' in client
    assert 'INITIAL_POWER' in client
    assert 'data-qc-problem' in client
    assert 'data-qc-evidence' in client
    assert 'setup_qc.js?v=2026-11-11.112.2' in HTML
    assert 'Setup/Application' not in client  # no raw file-loading or synthetic work items


def test_qc_writes_are_narrow_governed_commands_not_scheduling_rows():
    sql = (APP.parent / 'Database/081_add_unscheduled_setup_qc_findings.sql').read_text()
    assert 'CREATE FUNCTION ops.setup_qc_command(' in sql
    assert 'SECURITY DEFINER' in sql
    assert 'ref.setup_execution_actor' in sql
    assert 'CREATE TABLE IF NOT EXISTS ops.setup_qc_finding' in sql
    assert 'CREATE TABLE IF NOT EXISTS ops.setup_qc_event' in sql
    assert 'CREATE TABLE IF NOT EXISTS ops.setup_qc_intake_link' in sql
    assert 'REFERENCES stage.work_order_intake(intake_id)' in sql
    assert 'INSERT INTO ops.setup_work_day_task' not in sql
    assert 'INSERT INTO ops.work_order' not in sql
    assert 'UPDATE stage.work_order_intake' not in sql
