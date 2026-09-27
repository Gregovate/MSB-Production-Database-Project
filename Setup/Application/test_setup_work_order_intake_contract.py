from __future__ import annotations

from pathlib import Path


APP_DIR = Path(__file__).resolve().parent
SETUP_DIR = APP_DIR.parent
MIGRATION = SETUP_DIR / "Database" / "062_add_setup_context_work_order_intake.sql"


def read_app(name: str) -> str:
    return (APP_DIR / name).read_text(encoding="utf-8")


def test_172_setup_correction_goes_to_existing_intake_not_active_work_order() -> None:
    sql = MIGRATION.read_text(encoding="utf-8")
    function = sql.split(
        "CREATE OR REPLACE FUNCTION ops.submit_setup_work_order_intake", 1
    )[1].split("REVOKE ALL ON FUNCTION ops.submit_setup_work_order_intake", 1)[0]

    assert "INSERT INTO stage.work_order_intake" in function
    assert "INSERT INTO ops.work_order" not in function
    assert "'1'" in function
    assert "'SUBMITTED'::text" in function
    assert "'SETUP'" in function
    assert "'SETUP_CORRECTION'" in function


def test_172_exact_assignment_is_authoritative_context_anchor() -> None:
    sql = MIGRATION.read_text(encoding="utf-8")
    function = sql.split(
        "CREATE OR REPLACE FUNCTION ops.submit_setup_work_order_intake", 1
    )[1].split("REVOKE ALL ON FUNCTION ops.submit_setup_work_order_intake", 1)[0]

    assert "p_setup_work_day_task_id bigint" in function
    assert "wdt.setup_work_day_task_id = p_setup_work_day_task_id" in function
    assert "wdt.setup_session_task_id = p_setup_session_task_id" in function
    assert "Scheduled assignment does not belong to this Setup task" in function
    assert "p_setup_work_day_id" not in function
    assert "p_shift_code" not in function


def test_172_intake_preserves_required_setup_captain_procedure_context() -> None:
    sql = MIGRATION.read_text(encoding="utf-8")

    for token in (
        "'season_year'",
        "'setup_session_id'",
        "'setup_session_task_id'",
        "'setup_task_id'",
        "'task_origin'",
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
        "'captain_person_id'",
        "'captain_display_name'",
        "'procedure_context'",
        "'suggested_correction_evidence'",
        "'reporter_person_id'",
        "'submitted_at'",
    ):
        assert token in sql

    assert "Setup provenance: session_id=" in sql
    assert "annual_task_id=" in sql
    assert "reusable_task_id=" in sql
    assert "assignment_id=" in sql
    assert "Procedure: " in sql


def test_172_reuses_accepted_execution_actor_authority() -> None:
    sql = MIGRATION.read_text(encoding="utf-8")
    function = sql.split(
        "CREATE OR REPLACE FUNCTION ops.submit_setup_work_order_intake", 1
    )[1].split("REVOKE ALL ON FUNCTION ops.submit_setup_work_order_intake", 1)[0]

    assert "ref.setup_execution_actor(p_email, v_setup_task_id)" in function
    assert "ref.setup_browser_capabilities" not in function
    assert "v_role_name" not in function
    assert "v_policy_names" not in function


def test_172_api_uses_governed_command_and_server_resolves_procedure() -> None:
    api = read_app("setup_work_order_intake_api.py")
    repo = read_app("setup_work_order_intake_repository.py")
    backend = read_app("production_backend.py")

    assert "/correction-intake" in api
    assert "Scheduled assignment identity is required" in api
    assert "assignment_context" in api
    assert "current_procedure_context" in api
    assert "_task_instructions" in api
    assert "suggested_correction_evidence" in api
    assert "ops.submit_setup_work_order_intake" in repo
    assert "Json(procedure_context)" in repo
    assert "INSERT INTO stage.work_order_intake" not in repo
    assert "setup_work_order_intake_api" in backend
    assert "app.register_blueprint(setup_work_order_intake_api)" in backend


def test_172_field_ui_is_low_friction_and_uses_exact_assignment() -> None:
    ui = read_app("setup_next_pass.js")

    for token in (
        "Report Correction",
        "What did you find?",
        "Suggested correction / evidence",
        "Work Order Intake for Manager triage",
        "it does not create an active Work Order",
        "setup_work_day_task_id: assignmentId",
        "suggested_correction_evidence",
        "Submitted to Work Order Intake",
    ):
        assert token in ui

    assert "Where is the problem?" not in ui
    assert "Which Stage?" not in ui
    assert "setup_work_day_id:" not in ui.split(
        "async function submitNextCorrectionIntake", 1
    )[1].split("async function openNextCorrectionIntake", 1)[0]
    assert "shift_code:" not in ui.split(
        "async function submitNextCorrectionIntake", 1
    )[1].split("async function openNextCorrectionIntake", 1)[0]


def test_172_report_correction_waits_for_context_before_opening() -> None:
    ui = read_app("setup_next_pass.js")
    body = ui.split("async function openNextCorrectionIntake(details) {", 1)[1].split(
        "function nextPerformAssignmentCard", 1
    )[0]

    assert "details.dataset.loading === '1'" in body
    assert "await loadNextTaskExecution(details, false)" in body
    assert "details.dataset.loaded !== '1'" in body
    assert body.index("details.open = true") > body.index("details.dataset.loaded !== '1'")


def test_172_migration_exposes_only_narrow_execute_to_application_role() -> None:
    sql = MIGRATION.read_text(encoding="utf-8")

    assert "GRANT EXECUTE ON FUNCTION ops.submit_setup_work_order_intake" in sql
    assert "TO fieldwiring_app" in sql
    assert "has_table_privilege(" in sql
    assert "'stage.work_order_intake'" in sql
    assert "'INSERT'" in sql
