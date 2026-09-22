from __future__ import annotations

from pathlib import Path


APP_DIR = Path(__file__).resolve().parent
SETUP_DIR = APP_DIR.parent
MIGRATION = SETUP_DIR / "Database" / "053_add_production_crew_report_work_duration.sql"


def read_app(name: str) -> str:
    return (APP_DIR / name).read_text(encoding="utf-8")


def test_132_migration_adds_positive_per_progress_duration() -> None:
    sql = MIGRATION.read_text(encoding="utf-8")

    assert "ADD COLUMN IF NOT EXISTS duration_minutes integer" in sql
    assert "duration_minutes IS NULL OR duration_minutes > 0" in sql
    assert "Elapsed work duration must be greater than zero" in sql
    assert "sum(p.duration_minutes)" in sql
    assert "actual_duration_minutes = v_total_duration" in sql


def test_132_execution_authority_is_production_crew_not_captain_assignment() -> None:
    sql = MIGRATION.read_text(encoding="utf-8")
    actor = sql.split("CREATE OR REPLACE FUNCTION ref.setup_execution_actor", 1)[1].split(
        "REVOKE ALL ON FUNCTION ref.setup_execution_actor", 1
    )[0]

    assert "v_role_name = 'Production Crew'" in actor
    assert "'Production Crew' = ANY" in actor
    assert "coalesce(v_can_manage, false)" in actor
    assert "CAPTAIN" not in actor
    assert "ALTERNATE" not in actor
    assert "Setup work reporting requires Production Crew or Manager access" in actor


def test_132_replaces_old_progress_command_without_broad_table_dml() -> None:
    sql = MIGRATION.read_text(encoding="utf-8")

    assert "DROP FUNCTION ops.record_setup_task_progress(" in sql
    assert (
        "ops.record_setup_task_progress("
        "
    text,bigint,bigint,text,integer,integer,integer,text,text,boolean"
    ) in sql
    assert "GRANT EXECUTE ON FUNCTION ops.record_setup_task_progress" in sql
    assert "GRANT INSERT ON" not in sql
    assert "GRANT UPDATE ON" not in sql
    assert "GRANT DELETE ON" not in sql


def test_132_api_and_repository_require_duration_minutes() -> None:
    api = read_app("setup_next_api.py")
    repo = read_app("setup_next_repository.py")

    assert 'payload.get("duration_minutes")' in api
    assert 'duration_minutes must be greater than zero' in api
    assert "duration_minutes=duration" in api

    assert "duration_minutes: int" in repo
    assert "duration_minutes, quantity" in repo
    assert "p.duration_minutes" in repo
    assert "reported_duration_minutes" in repo
    assert "person_minutes" in repo


def test_132_mobile_report_work_uses_hours_minutes_and_preserves_schedule_context() -> None:
    ui = read_app("setup_next_pass.js")

    for token in (
        "next-duration-hours",
        "next-duration-minutes",
        "duration_minutes: durationMinutes",
        "setup_work_day_id",
        "setup_work_day_task_id",
        "shift_code",
        "work_date",
        "crew_code",
        "Reporting against scheduled context:",
        "Duration not recorded",
    ):
        assert token in ui

    assert "minutes > 59" in ui
    assert "durationMinutes <= 0" in ui
