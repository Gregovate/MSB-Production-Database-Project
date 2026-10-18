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
