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
    assert "QC self-assignment, findings, repairs, and final" in qc
    assert "No QC PASS or repair status is inferred" in qc
    assert "commandOptions(" not in qc
    assert "/api/setup/" not in qc
    assert "POST" not in qc
    assert "INSERT" not in qc


def test_qc_mode_keeps_existing_scheduled_reporting_intact():
    render = segment("function renderNextExecution() {", "const allAssignments =")
    assert "nextEnsurePerformToolbar();" in render
    assert "nextQcEnsureDiscovery();" in render
    assert "if (nextQcDiscovery.mode === 'qc') return;" in render
    assert "next-perform-list" in render
    assert "next-perform-show-completed" in JS
    assert "submitNextCorrectionIntake" in JS
    assert "nextAssignmentLate" in JS


def test_theme_safe_read_only_qc_and_fresh_asset_pins():
    assert "background: var(--card" in CSS
    assert "color: var(--text" in CSS
    assert ".next-qc-row" in CSS
    assert 'setup_next_pass.js?v=2026-11-11.111.9' in HTML
    assert 'setup_next_pass.css?v=2026-11-11.111.9' in HTML
    assert "V0.3.111-explicit-no-work" in (APP / "production_backend.py").read_text()
