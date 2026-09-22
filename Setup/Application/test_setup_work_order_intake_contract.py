from __future__ import annotations

from pathlib import Path


APP_DIR = Path(__file__).resolve().parent
SETUP_DIR = APP_DIR.parent
MIGRATION = SETUP_DIR / "Database" / "054_add_setup_context_work_order_intake.sql"


def read_app(name: str) -> str:
    return (APP_DIR / name).read_text(encoding="utf-8")


def test_172_setup_finding_goes_to_existing_intake_not_active_work_order() -> None:
    sql = MIGRATION.read_text(encoding="utf-8")
    function = sql.split(
        "CREATE OR REPLACE FUNCTION ops.submit_setup_work_order_intake", 1
    )[1].split("REVOKE ALL ON FUNCTION ops.submit_setup_work_order_intake", 1)[0]

    assert "INSERT INTO stage.work_order_intake" in function
    assert "INSERT INTO ops.work_order" not in function
    assert "'1'" in function
    assert "'SUBMITTED'::text" in function
    assert "'SETUP'" in function
    assert "'SETUP_TASK'" in function


def test_172_intake_preserves_known_setup_context_in_source_payload() -> None:
    sql = MIGRATION.read_text(encoding="utf-8")

    for token in (
        "'season_year'",
        "'setup_session_id'",
        "'setup_session_task_id'",
        "'setup_task_id'",
        "'task_name'",
        "'stage_id'",
        "'stage_key'",
        "'stage_name'",
        "'lor_scene_id'",
        "'scene_name'",
        "'setup_work_day_id'",
        "'setup_day_number'",
        "'work_date'",
        "'setup_work_day_task_id'",
        "'shift_code'",
        "'setup_work_day_crew_id'",
        "'crew_code'",
        "'suggested_change'",
        "'reporter_person_id'",
    ):
        assert token in sql


def test_172_submission_is_production_crew_or_manager_not_captain_gated() -> None:
    sql = MIGRATION.read_text(encoding="utf-8")
    function = sql.split(
        "CREATE OR REPLACE FUNCTION ops.submit_setup_work_order_intake", 1
    )[1].split("REVOKE ALL ON FUNCTION ops.submit_setup_work_order_intake", 1)[0]

    assert "v_role_name = 'Production Crew'" in function
    assert "'Production Crew' = ANY" in function
    assert "coalesce(v_can_manage, false)" in function
    assert "CAPTAIN" not in function
    assert "ALTERNATE" not in function


def test_172_api_uses_governed_command_without_direct_intake_dml() -> None:
    api = read_app("setup_work_order_intake_api.py")
    repo = read_app("setup_work_order_intake_repository.py")
    backend = read_app("production_backend.py")

    assert "/problem-intake" in api
    assert "require_setup_command()" in api
    assert "require_reader()" in api
    assert "ops.submit_setup_work_order_intake" in repo
    assert "INSERT INTO stage.work_order_intake" not in repo
    assert "setup_work_order_intake_api" in backend
    assert "app.register_blueprint(setup_work_order_intake_api)" in backend


def test_172_field_ui_only_asks_for_observation_and_optional_suggestion() -> None:
    ui = read_app("setup_next_pass.js")

    for token in (
        "Report Problem / Suggest Change",
        "What did you find?",
        "What do you think should change?",
        "Work Order Intake for Manager triage",
        "it does not create an active Work Order",
        "setup_work_day_task_id",
        "setup_work_day_id",
        "shift_code",
        "Submitted to Work Order Intake",
    ):
        assert token in ui

    assert "Where is the problem?" not in ui
    assert "Which Stage?" not in ui
