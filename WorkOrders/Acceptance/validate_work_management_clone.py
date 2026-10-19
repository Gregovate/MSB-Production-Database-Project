"""#419 current-Production clone read AND rolled-back native-write preflight.

All mutation checks run against the disposable isolated clone, never Production.

Run only in a detached, pinned candidate checkout through the governed
MSB Server Management disposable Postgres runbook. This is a feature test,
not a database clone creator or a production deployment helper.
"""
from __future__ import annotations

import argparse
import os
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
APP_DIR = ROOT / "WorkOrders/Application"
sys.path.insert(0, str(APP_DIR))

from repository import WorkManagementError, WorkManagementRepository, ledger_select  # noqa:E402
from commands import CloneCommands  # noqa:E402

HEX40 = re.compile(r"^[a-f0-9]{40}$")
CURRENT_PHASE = "preflight"


def phase(name: str) -> None:
    """Expose only a fixed validation stage, never SQL, DSN or PII."""
    global CURRENT_PHASE
    CURRENT_PHASE = name
    print(f"CHECK: beginning {name}", flush=True)



def checked_sha(expected_sha: str) -> None:
    if not HEX40.fullmatch(expected_sha):
        raise ValueError("Expected pinned candidate must be an exact 40-character SHA.")
    # The privileged runner verifies detached Git identity before invocation.
    # The restricted service account cannot traverse the shared /opt Git metadata.
    actual = os.environ.get("WORK_MGMT_VERIFIED_CANDIDATE_SHA", "").strip().lower()
    if not HEX40.fullmatch(actual) or actual != expected_sha:
        raise RuntimeError("Privileged runner candidate identity proof missing or mismatched.")


def validate(preview_email: str) -> None:
    phase("clone_connection")
    repo = WorkManagementRepository()
    with repo.connect() as conn, conn.cursor() as cur:
        phase("read_only_transaction")
        cur.execute("SHOW transaction_read_only")
        if cur.fetchone()[0] != "on":
            raise RuntimeError("Disposable reader transaction is not READ ONLY.")
        phase("clone_identity")
        cur.execute("SELECT current_database(), inet_server_addr()::text")
        db_name, db_addr = cur.fetchone()
        if db_name == "msb" or not db_name.startswith("msb_"):
            raise RuntimeError("Expected a separately named approved MSB disposable clone.")
        # This is NOT sufficient to prove instance isolation; the governing
        # server runner must verify container IP, network, dump and live invariants.
        print(f"CHECK: clone_database={db_name}, internal_addr={db_addr}")
        phase("unified_ledger_query")
        cur.execute(
            "SELECT t.ticket, t.type, t.state, t.done_at, t.owners "
            "FROM (" + ledger_select() + ") t "
            "WHERE t.ticket IN ('WO-372','WO-418','INTAKE-60','INTAKE-40','INTAKE-57') "
            "ORDER BY t.ticket"
        )
        examples = cur.fetchall()
        if not examples:
            raise RuntimeError("Current clone has no known Work Order/Intake fixtures.")
        for row in examples:
            # Don't emit private reporter contacts or full free-text descriptions.
            print("CHECK: ticket=%s type=%s state=%s completion=%s assignees=%s"
                  % (row[0], row[1], row[2], "dated" if row[3] else "none", row[4]))

    phase("reviewer_authorization")
    access = repo.access(preview_email)
    if access["person_id"] < 1:
        raise RuntimeError("Approved reviewer is not a linked active Person.")

    phase("my_work_query")
    scope = repo.tickets(
        actor=access, scope="mine", person_id=None,
        show_completed=False, search="", limit=20,
    )
    if any(row["type"] != "WORK_ORDER" for row in scope):
        raise RuntimeError("My Work included an unrelated public/feedback Intake.")
    if any(access["person_id"] not in (row["assignee_ids"] or []) for row in scope):
        raise RuntimeError("My Work exposed another Person's Work Order.")
    if any(row["done_at"] is not None for row in scope):
        raise RuntimeError("Default My Work included dated-completed Work Orders.")
    print(f"CHECK: My Work identity/person scope PASS; rows={len(scope)}")

    phase("all_tickets_query")
    all_rows = repo.tickets(
        actor=access, scope="all", person_id=None,
        show_completed=True, search="", limit=100,
    )
    print(f"CHECK: authorized All Work Orders read PASS; sampled_rows={len(all_rows)}")

    phase("assignee_selector_query")
    names = repo.assignees()
    if any(row["person_id"] < 1 for row in names):
        raise RuntimeError("Assignee list contains an invalid permanent Person ID.")
    print(f"CHECK: assignee Person selector PASS; choices={len(names)}")

    phase("direct_create_catalogs")
    catalogs = repo.reviewer_options(access)
    if not catalogs["task_types"] or not catalogs["stages"] or not catalogs["work_areas"]:
        raise RuntimeError("Internal creation requires current Task Type/Stage/Work Area.")
    print("CHECK: authorized internal Create catalogs PASS")

    if access["can_manage"]:
        phase("manager_aging_all_open_work_orders")
        report = repo.aging_report(actor=access, sort="created_asc")
        with repo.connect() as conn, conn.cursor() as cur:
            cur.execute(
                "SELECT count(*), count(*) FILTER (WHERE NOT is_active) "
                "FROM ops.work_order WHERE date_completed IS NULL"
            )
            expected_open, expected_inactive = cur.fetchone()
        if len(report) != expected_open:
            raise RuntimeError("Aging report omitted some recorded-open Work Orders.")
        if sum(1 for row in report if not row["active"]) != expected_inactive:
            raise RuntimeError("Aging report excluded undated inactive exceptions.")
        dates = [row["opened_at"] for row in report if row["opened_at"] is not None]
        if dates != sorted(dates):
            raise RuntimeError("Aging report is not oldest-creation-first.")
        if any(row["days_open"] is not None and row["days_open"] < 0 for row in report):
            raise RuntimeError("Aging report contains a negative age.")
        print("CHECK: Manager all-open aging report PASS; "
              f"rows={len(report)} inactive-exceptions={expected_inactive}")
        phase("manager_rehearsal_catalogs")
        if not catalogs["people"]:
            raise RuntimeError("Manager assignment requires current active People.")
        print("CHECK: Manager catalog authority PASS; isolated clone write preflight follows")

        # Prove native CRUD and assignment audit tables BEFORE displaying READY.
        # SAVEPOINT rollback means even the disposable clone has no preflight data.
        phase("clone_write_transaction_rollback")
        writer = CloneCommands()
        with writer.transaction(access) as cur:
            cur.execute("SHOW transaction_read_only")
            if cur.fetchone()["transaction_read_only"] != "off":
                raise RuntimeError("Disposable command transaction is unexpectedly read only.")
            cur.execute("SAVEPOINT wo419_preflight")
            wo = writer.new_work_order(cur, access, {
                "problem": "WO419 disposable preflight only; deliberately rolled back",
                "task_type_id": catalogs["task_types"][0]["id"],
                "urgency": 3,
                "target_year": 2026,
                "stage_id": catalogs["stages"][0]["id"],
                "work_area_id": None,
            })
            added, removed = writer.reassign(cur, wo, [
                int(catalogs["people"][0]["person_id"])
            ])
            if len(added) != 1 or removed:
                raise RuntimeError("New Work Order assignment did not persist in transaction.")
            cur.execute("SELECT count(*) AS count FROM ops.work_order_assignment "
                        "WHERE work_order_id=%s AND active_flag", (wo,))
            if cur.fetchone()["count"] != 1:
                raise RuntimeError("Assigned Person row was not present.")
            if catalogs.get("setup_seasons"):
                phase("atomic_work_order_setup_season_gate")
                setup_season_year = int(catalogs["setup_seasons"][0]["id"])
                linked_task = writer.create_season_only_work_order_gate(
                    cur, access, wo, {
                        "problem": "WO419 disposable linked Setup gate preflight",
                        "stage_id": catalogs["stages"][0]["id"],
                        "work_area_id": None,
                        "setup_season_year": setup_season_year,
                    }
                )
                cur.execute(
                    "SELECT task_origin,setup_task_id,linked_work_order_gate,"
                    "linked_work_order_id FROM ops.setup_session_task "
                    "WHERE setup_session_task_id=%s", (linked_task,)
                )
                annual = cur.fetchone()
                if not annual or (
                    annual["task_origin"] != "SEASON_ONLY"
                    or annual["setup_task_id"] is not None
                    or annual["linked_work_order_gate"] is not True
                    or annual["linked_work_order_id"] != wo
                ):
                    raise RuntimeError("Linked Setup gate lost seasonal-only/WO identity.")
            else:
                print("INFO: No ACTIVE/PLANNING Setup season: atomic linked gate "
                      "cannot be exercised; Manager must not be offered season creation.")
            cur.execute("UPDATE ops.work_order SET completion_notes=%s,"
                        "completed_by_person_id=%s,repair_complete=true,date_completed=now() "
                        "WHERE work_order_id=%s", (
                            "WO419 disposable rollback-only completion check",
                            access["person_id"], wo))
            if cur.rowcount != 1:
                raise RuntimeError("Existing native completion command failed.")
            cur.execute("ROLLBACK TO SAVEPOINT wo419_preflight")
        print("CHECK: clone-only Create/Assign/Complete and optional "
              "season-only Setup GATE transactional rollback PASS; "
              "no fixture retained, no email generated")

        # The accepted source report Intake #60 is an excellent data fixture
        # but cannot be assumed present on every future/current clone.
        if any(row[0] == "INTAKE-60" for row in examples):
            phase("intake_60_detail_query")
            ticket = repo.ticket(actor=access, ticket_key="INTAKE-60")
            original = ticket["setup_context"]
            if not original.get("stage_id"):
                raise RuntimeError("Intake #60 has no retained Stage provenance.")
            phase("intake_60_related_information")
            related = repo.related_information(actor=access, ticket_key="INTAKE-60")
            if related["stage_id"] != original["stage_id"]:
                raise RuntimeError("Related Information did not use original Stage identity.")
            if any(
                record["relation"] not in ("DIRECT_TASK", "STAGE_RELATED", "SUBMITTED_CONTEXT")
                for record in related["groups"]
            ):
                raise RuntimeError("Unknown or falsely confirmed Stage relationship.")
            print("CHECK: Intake #60 original context and lazy Stage resource read PASS;"
                  f" resources={len(related['groups'])}")
        else:
            print("HOLD: Intake #60 absent on this clone; select documented current fixture.")
    else:
        phase("crew_aging_denied")
        try:
            repo.aging_report(actor=access, sort="created_asc")
            raise RuntimeError("Crew obtained Manager-only aging report.")
        except WorkManagementError as denied:
            if denied.status != 403:
                raise RuntimeError("Unexpected aging-report rejection.")
        phase("crew_direct_create_rollback")
        writer = CloneCommands()
        # Crew Create is an unassigned native WO, never a false My Work assignment.
        with writer.transaction(access) as cur:
            cur.execute("SAVEPOINT wo419_crew_preflight")
            wo = writer.new_work_order(cur, access, {
                "problem": "WO419 Crew direct-create preflight, disposable and rolled back",
                "task_type_id": catalogs["task_types"][0]["id"],
                "urgency": 3, "target_year": 2026,
                "stage_id": catalogs["stages"][0]["id"],
                "work_area_id": None,
            })
            cur.execute(
                "SELECT submitted_by_person_id FROM ops.work_order WHERE work_order_id=%s",
                (wo,))
            row = cur.fetchone()
            if not row or row["submitted_by_person_id"] != access["person_id"]:
                raise RuntimeError("Crew Create did not attribute original reporter.")
            cur.execute(
                "SELECT count(*) AS count FROM ops.work_order_assignment "
                "WHERE work_order_id=%s AND active_flag", (wo,))
            if cur.fetchone()["count"] != 0:
                raise RuntimeError("Crew direct Create unexpectedly assigned volunteers.")
            cur.execute("ROLLBACK TO SAVEPOINT wo419_crew_preflight")
        print("CHECK: Crew native Create, attribution and unassigned rollback PASS;"
              " Manager Intake fixture not applicable.")

    print("WORK MANAGEMENT #419 DISPOSABLE READ ACCEPTANCE PASS"
          " (not browser or P0 acceptance)")


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--candidate-sha", required=True)
    parser.add_argument("--preview-email", required=True)
    args = parser.parse_args()
    try:
        if os.environ.get("WORK_MGMT_PREVIEW_MODE") != "disposable":
            raise RuntimeError("WORK_MGMT_PREVIEW_MODE=disposable required.")
        if not os.environ.get("WORK_MGMT_DATABASE_DSN", "").strip():
            raise RuntimeError("Clone DSN not supplied by approved runner.")
        phase("candidate_identity")
        checked_sha(args.candidate_sha)
        validate(args.preview_email.strip().lower())
        return 0
    except (ValueError, RuntimeError, OSError, WorkManagementError) as exc:
        print(f"WORK MANAGEMENT #419 DISPOSABLE READ ACCEPTANCE HOLD at {CURRENT_PHASE}:", str(exc))
        return 1
    except Exception as exc:
        # Retain the exception class and failing test phase without emitting
        # database errors, SQL, reporter text, credentials or stack traces.
        # Detailed traceback stays out of both operator terminal and report.
        print("WORK MANAGEMENT #419 DISPOSABLE READ ACCEPTANCE HOLD:"
              f" phase={CURRENT_PHASE} exception_class={type(exc).__name__};"
              " no source/database diagnostic details emitted.")
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
