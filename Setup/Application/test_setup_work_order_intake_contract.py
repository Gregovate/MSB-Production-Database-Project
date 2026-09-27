from __future__ import annotations

from pathlib import Path


APP_DIR = Path(__file__).resolve().parent
SETUP_DIR = APP_DIR.parent
MIGRATION = SETUP_DIR / "Database" / "062_add_setup_context_work_order_intake.sql"
VALIDATION = (
    SETUP_DIR / "Acceptance" / "setup_172_report_correction_disposable_validation.sql"
)
PREVIEW_ENTRY = SETUP_DIR / "Acceptance" / "setup_session_browser_preview_entry.py"
PREVIEW_RUNNER = SETUP_DIR / "Acceptance" / "setup_disposable_browser_preview_server.sh"


def read_app(name: str) -> str:
    return (APP_DIR / name).read_text(encoding="utf-8")


def test_172_postgres_prepares_intake_but_does_not_insert_or_create_work_order() -> None:
    sql = MIGRATION.read_text(encoding="utf-8")
    function = sql.split(
        "CREATE OR REPLACE FUNCTION ops.prepare_setup_work_order_intake", 1
    )[1].split("REVOKE ALL ON FUNCTION ops.prepare_setup_work_order_intake", 1)[0]

    assert "jsonb_build_object(" in function
    assert "'source_system', 'SETUP'" in function
    assert "'source_form_name', 'SETUP_CORRECTION'" in function
    assert "'triage_dropdown', '1'" in function
    assert "INSERT INTO stage.work_order_intake" not in function
    assert "INSERT INTO ops.work_order" not in function


def test_172_exact_assignment_is_authoritative_context_anchor() -> None:
    sql = MIGRATION.read_text(encoding="utf-8")
    function = sql.split(
        "CREATE OR REPLACE FUNCTION ops.prepare_setup_work_order_intake", 1
    )[1].split("REVOKE ALL ON FUNCTION ops.prepare_setup_work_order_intake", 1)[0]

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
        "CREATE OR REPLACE FUNCTION ops.prepare_setup_work_order_intake", 1
    )[1].split("REVOKE ALL ON FUNCTION ops.prepare_setup_work_order_intake", 1)[0]

    assert "ref.setup_execution_actor(p_email, v_setup_task_id)" in function
    assert "ref.setup_browser_capabilities" not in function
    assert "v_role_name" not in function
    assert "v_policy_names" not in function


def test_172_api_prepares_then_creates_through_directus() -> None:
    api = read_app("setup_work_order_intake_api.py")
    repo = read_app("setup_work_order_intake_repository.py")
    client = read_app("setup_work_order_intake_directus.py")

    assert "/correction-intake" in api
    assert "Scheduled assignment identity is required" in api
    assert "current_procedure_context" in api
    assert "intake_repo.prepare(" in api
    assert "directus_client().create_intake(intake_payload)" in api
    assert "ops.prepare_setup_work_order_intake" in repo
    assert "INSERT INTO stage.work_order_intake" not in repo

    assert "/items/work_order_intake" in client
    assert "SETUP_DIRECTUS_INTAKE_TOKEN" in client
    assert "Authorization" in client
    assert "Bearer" in client
    assert "ProxyHandler({})" in client
    assert "CF-Access-Client-Secret" not in client
    assert "DIRECTUS_TOKEN =" not in client


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


def test_172_report_correction_waits_for_context_before_opening() -> None:
    ui = read_app("setup_next_pass.js")
    body = ui.split("async function openNextCorrectionIntake(details) {", 1)[1].split(
        "function nextPerformAssignmentCard", 1
    )[0]

    assert "details.dataset.loading === '1'" in body
    assert "await loadNextTaskExecution(details, false)" in body
    assert "details.dataset.loaded !== '1'" in body
    assert body.index("details.open = true") > body.index("details.dataset.loaded !== '1'")


def test_172_migration_exposes_only_prepare_execute_to_application_role() -> None:
    sql = MIGRATION.read_text(encoding="utf-8")

    assert "GRANT EXECUTE ON FUNCTION ops.prepare_setup_work_order_intake" in sql
    assert "TO fieldwiring_app" in sql
    assert "has_table_privilege(" in sql
    assert "'stage.work_order_intake'" in sql
    assert "'INSERT'" in sql


def test_172_disposable_validation_guards_directus_notification_contract() -> None:
    sql = VALIDATION.read_text(encoding="utf-8")

    assert "WOI Request Triage Email" in sql
    assert "f.trigger = 'event'" in sql
    assert "items.create" in sql
    assert "work_order_intake" in sql
    assert "o.type = 'mail'" in sql
    assert "ops.prepare_setup_work_order_intake" in sql


def test_172_browser_preview_never_contacts_production_directus() -> None:
    entry = PREVIEW_ENTRY.read_text(encoding="utf-8")
    runner = PREVIEW_RUNNER.read_text(encoding="utf-8")

    assert "PreviewDirectusIntakeClient" in entry
    assert "intake_api.directus_client = lambda" in entry
    assert '"intake_id": 0' in entry
    assert "INSERT INTO stage.work_order_intake" not in entry
    assert "SETUP_DIRECTUS_INTAKE_TOKEN" not in entry
    assert "MSB_SETUP_PREVIEW_INTAKE_DSN" not in runner


def test_172_directus_client_uses_local_items_api_and_never_cloudflare_secrets(monkeypatch) -> None:
    import json
    import setup_work_order_intake_directus as module

    captured = {}

    class FakeResponse:
        def __enter__(self):
            return self

        def __exit__(self, exc_type, exc, tb):
            return False

        def read(self):
            return b'{"data":{"intake_id":321}}'

    class FakeOpener:
        def open(self, request_object, timeout):
            captured["url"] = request_object.full_url
            captured["authorization"] = request_object.get_header("Authorization")
            captured["content_type"] = request_object.get_header("Content-type")
            captured["body"] = json.loads(request_object.data.decode("utf-8"))
            captured["timeout"] = timeout
            return FakeResponse()

    monkeypatch.setattr(module, "DIRECT_OPENER", FakeOpener())
    client = module.SetupDirectusIntakeClient(
        base_url="http://127.0.0.1:8055",
        token="test-token-not-a-production-secret",
    )
    created = client.create_intake(
        {
            "source_system": "SETUP",
            "source_form_name": "SETUP_CORRECTION",
            "triage_dropdown": "1",
            "problem_raw": "test",
        }
    )

    assert created["intake_id"] == 321
    assert captured["url"] == "http://127.0.0.1:8055/items/work_order_intake"
    assert captured["authorization"] == "Bearer test-token-not-a-production-secret"
    assert captured["content_type"] == "application/json"
    assert captured["body"]["source_system"] == "SETUP"
    assert captured["timeout"] == 15


def test_172_directus_token_is_runtime_only(monkeypatch) -> None:
    import pytest
    import setup_work_order_intake_directus as module

    monkeypatch.delenv("SETUP_DIRECTUS_INTAKE_TOKEN", raising=False)
    with pytest.raises(
        module.SetupDirectusIntakeError,
        match="service credential is not configured",
    ):
        module.SetupDirectusIntakeClient()
