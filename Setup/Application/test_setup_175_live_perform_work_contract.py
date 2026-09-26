from __future__ import annotations

from pathlib import Path


APP_DIR = Path(__file__).resolve().parent
DB_DIR = APP_DIR.parent / "Database"


def read_app(name: str) -> str:
    return (APP_DIR / name).read_text(encoding="utf-8")


def test_perform_work_is_scheduled_assignment_projection() -> None:
    ui = read_app("setup_next_pass.js")

    assert "api/setup/scheduling-board?season_year=" in ui
    assert "performAssignmentMode: true" in ui
    assert "Setup Day" in ui
    assert "MORNING" in ui
    assert "AFTERNOON" in ui
    assert "Crew " in ui
    assert "captain_display_name" in ui
    assert 'data-assignment-id=' in ui

    assert 'id="next-perform-filter"' not in ui


def test_perform_work_defaults_to_signed_in_captain_when_scheduled() -> None:
    ui = read_app("setup_next_pass.js")

    for token in (
        'id="next-perform-captain-filter"',
        "captain_person_id",
        "captain_candidates",
        "authenticated_email",
        "All scheduled work",
        "nextPerformDefaultCaptainFilter",
        "nextEnsurePerformToolbar",
        "nextFilterPerformAssignments",
    ):
        assert token in ui


def test_report_work_requires_actual_crew_duration_and_percent() -> None:
    ui = read_app("setup_next_pass.js")

    for token in (
        "next-crew",
        "next-duration-hours",
        "next-duration-minutes",
        "next-percent-complete",
        "setup_work_day_task_id: assignmentId",
        "duration_minutes: durationMinutes",
        "percent_complete: percent",
        "100% completes the annual task",
        "remains In Progress",
    ):
        assert token in ui

    assert "next-mark-complete" not in ui
    assert "mark_complete:" not in ui


def test_report_work_surfaces_one_editable_actual_work_date() -> None:
    ui = read_app("setup_next_pass.js")

    assert "Work completed on" in ui
    assert 'class="next-performed-on"' in ui
    assert 'value="${escapeHtml(day?.work_date || assignment?.work_date || \'\')}"' in ui
    assert "performed_on: performedOn" in ui
    assert "p.performed_on || p.work_date" in ui
    assert "recorded_at" not in ui.split(
        '<form class="next-completion-form next-report-work-form"', 1
    )[1].split("</form>", 1)[0]


def test_incomplete_report_requires_remaining_work_note() -> None:
    ui = read_app("setup_next_pass.js")

    assert "percent < 100 && !note" in ui
    assert "what was done and what remains" in ui


def test_assignment_grouping_is_not_reordered_by_stage_view() -> None:
    stage = read_app("setup_stage_order.js")

    assert "performAssignmentMode" in stage
    assert "if (setupNextState?.performAssignmentMode) return;" in stage


def test_legacy_acceptance_override_delegates_assignment_mode() -> None:
    acceptance = read_app("setup_acceptance_fixes.js")

    assert "setupAcceptanceBaseLoadNextTaskExecution = loadNextTaskExecution" in acceptance
    assert "if (setupNextState?.performAssignmentMode)" in acceptance
    assert "setupAcceptanceBaseLoadNextTaskExecution(details, focusReport)" in acceptance


def test_perform_work_status_separates_schedule_from_readiness() -> None:
    ui = read_app("setup_next_pass.js")

    assert "task.board_status" in ui
    assert "boardStatus === 'SCHEDULED'" in ui
    assert "next-perform-readiness-warning" in ui
    assert "soft planning condition; actual work may still be reported" in ui


def test_field_actions_use_report_correction_and_colored_print_task() -> None:
    ui = read_app("setup_next_pass.js")
    css = read_app("setup_next_pass.css")

    assert ">Report Correction</button>" in ui
    assert "Report Correction handoff is owned by #172" in ui
    assert ">Report Problem</button>" not in ui
    assert ".next-perform-actions .next-print-task" in css
    assert "var(--accent-soft" in css
    assert "var(--accent" in css


def test_print_task_waits_for_context_before_opening_details() -> None:
    ui = read_app("setup_next_pass.js")

    function_body = ui.split("async function printNextPerformTask(details) {", 1)[1].split(
        "function nextLocationText", 1
    )[0]
    assert "details.dataset.loading === '1'" in function_body
    assert "await loadNextTaskExecution(details, false)" in function_body
    assert function_body.index("details.open = true") > function_body.index(
        "details.dataset.loaded !== '1'"
    )


def test_optional_quantity_detail_is_collapsed_by_default() -> None:
    ui = read_app("setup_next_pass.js")
    css = read_app("setup_next_pass.css")

    assert "Add quantity detail (optional)" in ui
    assert 'class="next-report-quantity-details"' in ui
    assert 'class="next-quantity"' in ui
    assert 'class="next-units"' in ui
    assert ".next-report-quantity-details" in css


def test_report_work_layout_keeps_actual_fields_compact() -> None:
    ui = read_app("setup_next_pass.js")
    css = read_app("setup_next_pass.css")

    assert 'class="next-report-note"' in ui
    assert 'class="next-report-quantity"' in ui
    assert 'class="next-report-units"' in ui
    assert ".next-report-work-form .next-report-work-grid" in css
    assert "minmax(145px, 175px)" in css


def test_print_task_is_bounded_cover_sheet_not_schedule_print() -> None:
    ui = read_app("setup_next_pass.js")
    css = read_app("setup_scheduling_board.css")

    assert "printNextPerformTask(details)" in ui
    assert "setup-perform-print-sheet" in ui
    assert "setup-print-perform-task" in ui
    assert "Field notes / corrections / problems" in ui
    assert "body.setup-print-perform-task > #setup-perform-print-sheet" in css
    assert "body.setup-print-perform-task #schedule-view" in css


def test_procedure_failure_does_not_block_report_work() -> None:
    ui = read_app("setup_next_pass.js")

    assert ".catch((error) => ({ payload: null, error }))" in ui
    assert "Procedure context unavailable." in ui
    assert "Report Work remains available." in ui


def test_live_report_work_database_contract() -> None:
    sql = (DB_DIR / "061_add_live_assignment_report_work.sql").read_text(encoding="utf-8")

    assert "ADD COLUMN IF NOT EXISTS performed_on date" in sql
    assert "p_performed_on date" in sql
    assert "Work performed date cannot be in the future" in sql
    assert "ADD COLUMN IF NOT EXISTS duration_minutes integer" in sql
    assert "ADD COLUMN IF NOT EXISTS percent_complete integer" in sql
    assert "percent_complete BETWEEN 1 AND 100" in sql
    assert "Setup work reporting requires Production Crew or Manager access" in sql
    assert "p_setup_work_day_task_id bigint DEFAULT NULL" in sql
    assert "wdt.setup_work_day_task_id = v_assignment_id" in sql
    assert "WHEN p_percent_complete = 100 THEN 'COMPLETE'" in sql
    assert "ELSE 'IN_PROGRESS'" in sql
    assert "PERFORM ops.refresh_setup_session_task_schedule_state" in sql
    assert "actual_started_at = coalesce(st.actual_started_at, v_recorded_at)" not in sql
    assert "WHEN p_percent_complete = 100 THEN v_recorded_at" not in sql


def test_perform_work_asset_pins_are_refreshed() -> None:
    html = read_app("production.html")

    assert "setup_next_pass.css?v=2026-09-26.8" in html
    assert "setup_next_pass.js?v=2026-09-26.8" in html
    assert "setup_acceptance_fixes.css?v=2026-09-26.1" in html
    assert "setup_acceptance_fixes.js?v=2026-09-26.1" in html
    assert "setup_scheduling_board.css?v=2026-09-26.1" in html
    assert "setup_stage_order.js?v=2026-09-25.1" in html
