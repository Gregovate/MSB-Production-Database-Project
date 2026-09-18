from __future__ import annotations

from pathlib import Path


APP_DIR = Path(__file__).resolve().parent
SETUP_DIR = APP_DIR.parent
DB_DIR = SETUP_DIR / "Database"


def read_app(name: str) -> str:
    return (APP_DIR / name).read_text(encoding="utf-8")


def read_db(name: str) -> str:
    return (DB_DIR / name).read_text(encoding="utf-8")


def test_205_migration_separates_reusable_and_season_only_annual_work() -> None:
    sql = read_db("050_add_setup_scheduling_board_foundation.sql")
    for token in (
        "setup_day_number",
        "task_origin",
        "'REUSABLE','SEASON_ONLY'",
        "annual_task_name",
        "annual_stage_id",
        "annual_lor_scene_id",
        "annual_expected_duration_minutes",
        "annual_effort_level",
        "annual_readiness_state",
        "create_setup_season_task",
        "update_setup_annual_task_definition",
    ):
        assert token in sql

    assert "ALTER COLUMN setup_task_id DROP NOT NULL" in sql
    assert "task_origin = 'SEASON_ONLY'" in sql
    assert "INSERT INTO ref.setup_task" not in sql.split(
        "CREATE OR REPLACE FUNCTION ops.create_setup_season_task", 1
    )[1].split("CREATE OR REPLACE FUNCTION ops.update_setup_annual_task_definition", 1)[0]


def test_205_annual_dependencies_can_include_season_only_tasks() -> None:
    sql = read_db("050_add_setup_scheduling_board_foundation.sql")
    assert "CREATE TABLE IF NOT EXISTS ops.setup_session_task_dependency" in sql
    assert "prerequisite_setup_session_task_id" in sql
    assert "REUSABLE_BASELINE" in sql
    assert "ops.set_setup_session_task_dependency" in sql
    assert "Annual prerequisite would create a circular Setup dependency" in sql
    assert "FROM chain c" in sql
    assert "WHERE c.setup_session_task_id = p_setup_session_task_id" in sql


def test_205_work_order_gate_is_a_real_relationship() -> None:
    sql = read_db("050_add_setup_scheduling_board_foundation.sql")
    repo = read_app("setup_scheduling_board_repository.py")
    assert "linked_work_order_id" in sql
    assert "REFERENCES ops.work_order(work_order_id)" in sql
    assert "linked_work_order_gate" in sql
    assert "CREATE OR REPLACE VIEW ops.setup_scheduling_work_order_gate" in sql
    assert "GRANT SELECT ON ops.setup_scheduling_work_order_gate TO fieldwiring_app" in sql
    assert "LEFT JOIN ops.setup_scheduling_work_order_gate wo" in repo
    assert "LEFT JOIN ops.work_order wo" not in repo
    assert "wo.date_completed" in repo
    assert "WAITING_ON_WORK_ORDER" in repo


def test_205_assignment_identity_and_stickiness_are_database_authoritative() -> None:
    sql = read_db("050_add_setup_scheduling_board_foundation.sql")
    for token in (
        "setup_work_day_task_id bigint GENERATED ALWAYS AS IDENTITY",
        "UNIQUE (setup_work_day_id, setup_session_task_id, shift_code)",
        "setup_work_day_crew_id bigint",
        "create_setup_work_day_assignment",
        "update_setup_work_day_assignment",
        "remove_setup_work_day_assignment",
        "Actual work exists for this assignment",
        "historical work cannot be removed",
        "ADD COLUMN IF NOT EXISTS setup_work_day_task_id bigint",
        "FOREIGN KEY (setup_work_day_task_id)",
    ):
        assert token in sql

    assert "crew_lane ~ '^[A-Z]+

def test_205_work_day_number_is_persisted_and_dow_is_derived() -> None:
    sql = read_db("050_add_setup_scheduling_board_foundation.sql")
    repo = read_app("setup_scheduling_board_repository.py")
    ui = read_app("setup_scheduling_board.js")
    assert "ADD COLUMN IF NOT EXISTS setup_day_number integer" in sql
    assert "UNIQUE (setup_session_id, setup_day_number)" in sql
    assert "upper(to_char(wd.work_date, 'Dy')) AS day_of_week" in repo
    assert "extract(isodow FROM wd.work_date)" in repo
    assert "Day " in ui and "setup_day_number" in ui
    assert "Saturday · typically stronger volunteer turnout" in ui
    assert "Sunday · avoid scheduling unless deliberately needed" in ui
    assert "Setup Day %s is already assigned to %s" in sql


def test_205_board_uses_dynamic_crews_am_pm_and_accessible_move_controls() -> None:
    ui = read_app("setup_scheduling_board.js")
    css = read_app("setup_scheduling_board.css")

    for phrase in (
        "Crew A",
        "+ Add Crew",
        "MORNING",
        "AFTERNOON",
        "Schedule…",
        "Move…",
        "Remove",
        "Historical actual — locked",
        "Drop work here",
        "Legacy All Day",
    ):
        assert phrase in ui

    assert '<option value="ALL_DAY">All Day</option>' not in ui
    assert "dragstart" in ui
    assert "dragover" in ui
    assert "setup-board205-up" in ui
    assert "setup-board205-down" in ui
    assert "repeat(2, minmax(14rem, 1fr))" in css


def test_205_finder_uses_task_time_minimum_crew_and_effort() -> None:
    sql = read_db("050_add_setup_scheduling_board_foundation.sql")
    repo = read_app("setup_scheduling_board_repository.py")
    ui = read_app("setup_scheduling_board.js")

    assert "annual_effort_level" in sql
    assert "st.annual_effort_level AS effort_level" in repo
    assert "setup-board205-task-search" in ui
    assert "setup-board205-time-filter" in ui
    assert "setup-board205-crew-filter" in ui
    assert "setup-board205-effort-filter" in ui
    assert "task.normal_crew_min" in ui
    assert "task.expected_duration_minutes" in ui
    assert "task.effort_level" in ui
    assert "Available Now / Needs Continuation" in ui
    assert "Outstanding / Blocked" in ui


def test_205_heavy_work_is_warning_not_prohibition() -> None:
    ui = read_app("setup_scheduling_board.js")
    assert "HEAVY work follows HEAVY work for this crew" in ui
    assert "board205HeavyWarning" in ui
    assert "window.confirm('HEAVY" not in ui


def test_205_am_to_pm_spillover_is_advisory_not_a_third_shift() -> None:
    ui = read_app("setup_scheduling_board.js")
    assert "SETUP_BOARD205_TYPICAL_AM_MINUTES = 180" in ui
    assert "of AM work carries past lunch into PM" in ui
    assert "≈ 9–12" in ui
    assert "after lunch ≈ 1 PM" in ui
    assert '<option value="ALL_DAY">All Day</option>' not in ui


def test_205_readiness_is_annual_state_separate_from_hard_predecessors() -> None:
    sql = read_db("050_add_setup_scheduling_board_foundation.sql")
    repo = read_app("setup_scheduling_board_repository.py")
    api = read_app("setup_scheduling_board_api.py")
    ui = read_app("setup_scheduling_board.js")

    assert "annual_readiness_state" in sql
    assert "annual_readiness_state IN ('READY','NOT_READY')" in sql
    assert "ops.set_setup_annual_task_readiness" in sql
    assert "st.annual_readiness_state = 'NOT_READY'" in repo
    assert "st.execution_status = 'NOT_READY'" not in repo.split("AS board_status", 1)[0]
    assert "/readiness" in api
    assert "Mark Ready" in ui
    assert "Mark Not Ready" in ui
    assert "Hard predecessor(s)" in ui
    assert "Readiness not met" in ui


def test_205_board_exposes_required_candidate_states() -> None:
    repo = read_app("setup_scheduling_board_repository.py")
    ui = read_app("setup_scheduling_board.js")
    for state in (
        "READY_TO_SCHEDULE",
        "BLOCKED",
        "NEEDS_SCHEDULING_AGAIN",
        "SCHEDULED",
        "COMPLETE",
        "WAITING_ON_WORK_ORDER",
    ):
        assert state in repo or state in ui


def test_205_season_task_editor_is_in_annual_plan_not_reusable_catalog() -> None:
    ui = read_app("setup_scheduling_board.js")
    assert "Add Season Task" in ui
    assert "THIS SEASON ONLY" in ui
    assert "It does not enter the Reusable Task Catalog" in ui
    assert "Existing Work Order ID" in ui
    assert "Work Order completion satisfies this gate" in ui
    assert "Insert after / prerequisite" in ui
    assert "Block downstream task" in ui


def test_205_api_uses_governed_manager_commands_for_plan_mutations() -> None:
    api = read_app("setup_scheduling_board_api.py")
    repository = read_app("setup_scheduling_board_repository.py")
    for route in (
        "/api/setup/scheduling-board",
        "/api/setup/scheduling-board/work-days",
        "/api/setup/scheduling-board/assignments",
        "/api/setup/scheduling-board/work-days/<int:setup_work_day_id>/crews",
        "/api/setup/scheduling-board/crews/<int:setup_work_day_crew_id>",
        "/api/setup/scheduling-board/season-tasks",
        "/api/setup/scheduling-board/season-tasks/<int:setup_session_task_id>/readiness",
    ):
        assert route in api
    assert "require_reader()" in api
    assert "require_manager()" in api
    assert "require_setup_command()" in api
    assert "INSERT INTO ops.setup_work_day" not in repository
    assert "UPDATE ops.setup_work_day_task" not in repository
    assert "DELETE FROM ops.setup_work_day_task" not in repository


def test_205_work_day_form_survives_async_submit() -> None:
    ui = read_app("setup_scheduling_board.js")
    block = ui.split("async function board205AddWorkDay(event)", 1)[1].split(
        "function board205OpenSeasonTaskDialog", 1
    )[0]
    assert "const form = event.currentTarget;" in block
    assert "form.reset();" in block
    assert "event.currentTarget.reset();" not in block


def test_205_production_host_registers_board_without_replacing_report_work() -> None:
    host = read_app("production_backend.py")
    html = read_app("production.html")
    assert "setup_scheduling_board_api" in host
    assert "app.register_blueprint(setup_scheduling_board_api)" in host
    assert '"setup_scheduling_board.css"' in host
    assert '"setup_scheduling_board.js"' in host
    assert "setup_scheduling_board.css?v=2026-09-17.3" in html
    assert "setup_scheduling_board.js?v=2026-09-17.3" in html
    assert "setup_next_pass.js" in html
" in sql
    assert "setup_work_day_task_id" in sql.split(
        "CREATE OR REPLACE FUNCTION ops.record_setup_task_progress", 1
    )[1]


def test_205_work_day_crews_are_dynamic_and_shift_specific() -> None:
    sql = read_db("050_add_setup_scheduling_board_foundation.sql")
    api = read_app("setup_scheduling_board_api.py")
    repo = read_app("setup_scheduling_board_repository.py")
    ui = read_app("setup_scheduling_board.js")

    for token in (
        "CREATE TABLE IF NOT EXISTS ops.setup_work_day_crew",
        "crew_number integer NOT NULL",
        "crew_code text NOT NULL",
        "am_planned_crew_count integer",
        "pm_planned_crew_count integer",
        "ops.add_setup_work_day_crew",
        "ops.update_setup_work_day_crew",
        "ops.remove_setup_work_day_crew",
        "ops.setup_crew_code",
    ):
        assert token in sql

    assert "VALUES (v_day_id, 1, 'A')" in sql
    assert "crew_lane IN ('A','B','C','D')" not in sql
    assert "/api/setup/scheduling-board/work-days/<int:setup_work_day_id>/crews" in api
    assert "/api/setup/scheduling-board/crews/<int:setup_work_day_crew_id>" in api
    assert '"crews": crews' in repo
    assert "+ Add Crew" in ui
    assert "am_planned_crew_count" in ui
    assert "pm_planned_crew_count" in ui


def test_205_work_day_number_is_persisted_and_dow_is_derived() -> None:
    sql = read_db("050_add_setup_scheduling_board_foundation.sql")
    repo = read_app("setup_scheduling_board_repository.py")
    ui = read_app("setup_scheduling_board.js")
    assert "ADD COLUMN IF NOT EXISTS setup_day_number integer" in sql
    assert "UNIQUE (setup_session_id, setup_day_number)" in sql
    assert "upper(to_char(wd.work_date, 'Dy')) AS day_of_week" in repo
    assert "extract(isodow FROM wd.work_date)" in repo
    assert "Day " in ui and "setup_day_number" in ui
    assert "Saturday · typically stronger volunteer turnout" in ui
    assert "Sunday · avoid scheduling unless deliberately needed" in ui
    assert "Setup Day %s is already assigned to %s" in sql


def test_205_board_has_four_fixed_crews_stacking_and_accessible_move_controls() -> None:
    ui = read_app("setup_scheduling_board.js")
    css = read_app("setup_scheduling_board.css")
    for phrase in (
        "Crew A",
        "Crew B",
        "Crew C",
        "Crew D",
        "MORNING",
        "AFTERNOON",
        "ALL_DAY",
        "Schedule…",
        "Move…",
        "Remove",
        "Historical actual — locked",
        "Drop work here",
    ):
        assert phrase in ui
    assert "dragstart" in ui
    assert "dragover" in ui
    assert "setup-board205-up" in ui
    assert "setup-board205-down" in ui
    assert "grid-template-columns: 6rem repeat(3" in css


def test_205_board_exposes_required_candidate_states() -> None:
    repo = read_app("setup_scheduling_board_repository.py")
    ui = read_app("setup_scheduling_board.js")
    for state in (
        "READY_TO_SCHEDULE",
        "BLOCKED",
        "NEEDS_SCHEDULING_AGAIN",
        "SCHEDULED",
        "COMPLETE",
        "WAITING_ON_WORK_ORDER",
    ):
        assert state in repo or state in ui


def test_205_season_task_editor_is_in_annual_plan_not_reusable_catalog() -> None:
    ui = read_app("setup_scheduling_board.js")
    assert "Add Season Task" in ui
    assert "THIS SEASON ONLY" in ui
    assert "It does not enter the Reusable Task Catalog" in ui
    assert "Existing Work Order ID" in ui
    assert "Work Order completion satisfies this gate" in ui
    assert "Insert after / prerequisite" in ui
    assert "Block downstream task" in ui


def test_205_api_uses_governed_manager_commands_for_plan_mutations() -> None:
    api = read_app("setup_scheduling_board_api.py")
    repository = read_app("setup_scheduling_board_repository.py")
    for route in (
        "/api/setup/scheduling-board",
        "/api/setup/scheduling-board/work-days",
        "/api/setup/scheduling-board/assignments",
        "/api/setup/scheduling-board/season-tasks",
    ):
        assert route in api
    assert "require_reader()" in api
    assert "require_manager()" in api
    assert "require_setup_command()" in api
    assert "INSERT INTO ops.setup_work_day" not in repository
    assert "UPDATE ops.setup_work_day_task" not in repository
    assert "DELETE FROM ops.setup_work_day_task" not in repository


def test_205_work_day_form_survives_async_submit() -> None:
    ui = read_app("setup_scheduling_board.js")
    block = ui.split("async function board205AddWorkDay(event)", 1)[1].split(
        "function board205OpenSeasonTaskDialog", 1
    )[0]
    assert "const form = event.currentTarget;" in block
    assert "form.reset();" in block
    assert "event.currentTarget.reset();" not in block


def test_205_production_host_registers_board_without_replacing_report_work() -> None:
    host = read_app("production_backend.py")
    html = read_app("production.html")
    assert "setup_scheduling_board_api" in host
    assert "app.register_blueprint(setup_scheduling_board_api)" in host
    assert '"setup_scheduling_board.css"' in host
    assert '"setup_scheduling_board.js"' in host
    assert "setup_scheduling_board.css?v=2026-09-17.2" in html
    assert "setup_scheduling_board.js?v=2026-09-17.2" in html
    assert "setup_next_pass.js" in html
