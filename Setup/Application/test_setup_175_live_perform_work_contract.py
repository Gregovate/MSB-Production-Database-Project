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

    assert "next-perform-filter" not in ui


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


def test_incomplete_report_requires_remaining_work_note() -> None:
    ui = read_app("setup_next_pass.js")

    assert "percent < 100 && !note" in ui
    assert "what was done and what remains" in ui


def test_assignment_grouping_is_not_reordered_by_stage_view() -> None:
    stage = read_app("setup_stage_order.js")

    assert "performAssignmentMode" in stage
    assert "if (setupNextState?.performAssignmentMode) return;" in stage


def test_live_report_work_database_contract() -> None:
    sql = (DB_DIR / "059_add_live_assignment_report_work.sql").read_text(encoding="utf-8")

    assert "ADD COLUMN IF NOT EXISTS duration_minutes integer" in sql
    assert "ADD COLUMN IF NOT EXISTS percent_complete integer" in sql
    assert "percent_complete BETWEEN 1 AND 100" in sql
    assert "Setup work reporting requires Production Crew or Manager access" in sql
    assert "p_setup_work_day_task_id bigint DEFAULT NULL" in sql
    assert "wdt.setup_work_day_task_id = v_assignment_id" in sql
    assert "WHEN p_percent_complete = 100 THEN 'COMPLETE'" in sql
    assert "ELSE 'IN_PROGRESS'" in sql
    assert "PERFORM ops.refresh_setup_session_task_schedule_state" in sql


def test_perform_work_asset_pins_are_refreshed() -> None:
    html = read_app("production.html")

    assert "setup_next_pass.css?v=2026-09-25.3" in html
    assert "setup_next_pass.js?v=2026-09-25.3" in html
    assert "setup_stage_order.js?v=2026-09-25.1" in html
