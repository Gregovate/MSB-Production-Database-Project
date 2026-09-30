from __future__ import annotations

from pathlib import Path


APP_DIR = Path(__file__).resolve().parent
SETUP_DIR = APP_DIR.parent
MIGRATION = SETUP_DIR / "Database" / "055_fix_setup_reconstruction_delete_annual_dependencies.sql"


def test_145_delete_order_removes_annual_dependency_shells_before_annual_tasks() -> None:
    sql = MIGRATION.read_text(encoding="utf-8")

    dep_delete = sql.index("DELETE FROM ops.setup_session_task_dependency")
    annual_delete = sql.index("DELETE FROM ops.setup_session_task st")
    reusable_dep_delete = sql.index("DELETE FROM ref.setup_task_dependency")

    assert dep_delete < annual_delete < reusable_dep_delete
    assert "d.setup_session_task_id IN (" in sql
    assert "d.prerequisite_setup_session_task_id IN (" in sql
    assert "WHERE st.setup_task_id = p_setup_task_id" in sql


def test_145_delete_order_preserves_existing_fail_closed_evidence_guards() -> None:
    sql = MIGRATION.read_text(encoding="utf-8")

    for token in (
        "ss.session_status <> 'HISTORICAL_VERIFICATION'",
        "st.actual_started_at IS NOT NULL",
        "st.actual_completed_at IS NOT NULL",
        "st.actual_crew_count IS NOT NULL",
        "st.actual_duration_minutes IS NOT NULL",
        "st.planned_date IS NOT NULL",
        "ops.setup_work_day_task",
        "ops.setup_task_progress",
        "ops.setup_movement_event",
        "Do not CASCADE",
    ):
        assert token in sql

    assert "ON DELETE CASCADE" not in sql
    assert "DELETE CASCADE" not in sql


def test_145_delete_order_keeps_narrow_application_authority() -> None:
    sql = MIGRATION.read_text(encoding="utf-8")

    assert (
        "GRANT EXECUTE ON FUNCTION "
        "ref.delete_setup_reconstruction_task(text,bigint) TO fieldwiring_app"
    ) in sql
    assert "GRANT DELETE ON ops.setup_session_task_dependency" not in sql
    assert "GRANT DELETE ON ops.setup_session_task" not in sql
    assert "GRANT DELETE ON ref.setup_task" not in sql


def test_145_delete_order_cleans_post_019_extra_material_relationships() -> None:
    sql = MIGRATION.read_text(encoding="utf-8")

    source_delete = sql.index("DELETE FROM ref.setup_task_extra_material_source")
    requirement_delete = sql.index("DELETE FROM ref.setup_task_extra_material tm")
    task_delete = sql.index("DELETE FROM ref.setup_task t")

    assert source_delete < requirement_delete < task_delete
    assert "WHERE tm.setup_task_id = p_setup_task_id" in sql
    assert "ref.setup_task_extra_material" in sql
    assert "ref.setup_task_extra_material_source" in sql
    assert "DELETE FROM ref.setup_extra_material" not in sql
    assert "DELETE FROM ref.container" not in sql


def test_145_delete_order_does_not_grant_direct_extra_material_delete() -> None:
    sql = MIGRATION.read_text(encoding="utf-8")

    assert "GRANT DELETE ON ref.setup_task_extra_material" not in sql
    assert "GRANT DELETE ON ref.setup_task_extra_material_source" not in sql
