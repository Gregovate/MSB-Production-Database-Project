"""#419: source-only guards for the governed, read-only unified ticket ledger.

These tests protect the database integration contract, not live PostgreSQL
permissions or browser behavior. Live/disposable acceptance is separate.
"""
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
WO_DIR = (
    ROOT
    / "Docs/02_Production_Database/01_System_Architecture/06_Work_Orders"
)
SQL = WO_DIR / "engineering/WO419_Unified_Ticket_Read_Only_Candidate.sql"
DESIGN = WO_DIR / "Work_Order_System_Design.md"


def test_419_unified_ticket_ledger_reads_both_authoritative_sources():
    sql = SQL.read_text(encoding="utf-8")
    for token in (
        "FROM ops.work_order w",
        "FROM stage.work_order_intake i",
        "ops.work_order_assignment a",
        "ops.work_order_status_history h",
        "ref.work_order_status s",
        "UNION ALL",
        "source_intake_id AS intake_id",
        "i.intake_id",
        "'TASK_FEEDBACK'",
        "'WORK_ORDER'",
    ):
        assert token in sql, token


def test_419_ticket_ledger_preserves_completion_and_assignment_truth():
    sql = SQL.read_text(encoding="utf-8")
    for token in (
        "a.active_flag",
        "w.date_completed",
        "w.is_active",
        "h.changed_at DESC",
        "'DONE_DATE_ONLY'",
        "'STATUS_NOT_RECORDED'",
        "'CORRECTION_OWNER_NOT_TRACKED'",
        "'UNASSIGNED'",
    ):
        assert token in sql, token
    # Do not regress to the archival table or bypass the Person/role boundary.
    assert "work_order_assignee" not in sql
    assert "directus_users" not in sql


def test_419_ticket_ledger_is_source_only_read_model():
    sql = SQL.read_text(encoding="utf-8")
    actual_sql = "\n".join(
        line for line in sql.splitlines()
        if not line.lstrip().startswith("--")
    ).lstrip().upper()
    assert actual_sql.startswith("WITH ASSIGNMENT_ROLLUP AS")
    for statement in (
        "CREATE TABLE",
        "CREATE VIEW",
        "ALTER TABLE",
        "DROP TABLE",
        "INSERT INTO",
        "DELETE FROM",
        "TRUNCATE",
        "UPDATE OPS.",
        "UPDATE STAGE.",
        "SELECT STAGE.P_PROCESS_WORK_ORDER_INTAKE",
        "SET ROLE",
        "GRANT ",
    ):
        assert statement not in actual_sql, statement


def test_419_design_is_authority_for_reader_and_reporter_closure():
    design = DESIGN.read_text(encoding="utf-8").casefold()
    for required in (
        "## #419 — Unified MSB Work Management Application Contract",
        "**Engineering authority and status:**",
        "**Status interpretation:**",
        "**Every actionable item must be discoverable",
        "Request Clarification",
        "January review",
        "source provenance",
    ):
        assert required.casefold() in design, required


def test_419_scope_uses_real_person_ids_not_display_names():
    """App may choose Me / All / another assignee using stable Person IDs."""
    sql = SQL.read_text(encoding="utf-8")
    design = DESIGN.read_text(encoding="utf-8")
    for token in (
        "a.person_id",
        "a.active_flag",
        "active_assignee_person_ids",
        "array_agg(DISTINCT a.person_id ORDER BY a.person_id)",
        "NULL::integer[] AS active_assignee_person_ids",
        "active_assignee_person_ids AS assignee_ids",
    ):
        assert token in sql, token
    for token in (
        "### Work Order landing view — default My Work",
        "All Work Orders",
        "Show completed",
        "ref.person.person_id",
        "server-side",
    ):
        assert token in design, token


def test_419_testing_origin_is_explicit_and_not_a_fake_intake():
    """Testing-generated repairs must link back to the real Test Session."""
    sql = SQL.read_text(encoding="utf-8")
    design = DESIGN.read_text(encoding="utf-8")
    for token in (
        "w.display_test_session_id AS test_detail_id",
        "w.display_id AS display_id",
        "NULL::bigint AS test_detail_id",
        "NULL::bigint AS display_id",
        "test_detail_id AS test_id",
        "display_id AS disp_id",
        "w.submitted_by_person_id AS reporter_person_id",
        "i.submitter_person_id AS reporter_person_id",
    ):
        assert token in sql, token
    for token in (
        "### Test Session-generated Work Orders — feedback and ownership",
        "Test Session repair",
        "No competing communication model",
        "do **not** automatically have an original Intake reporter",
    ):
        assert token.casefold() in design.casefold(), token
