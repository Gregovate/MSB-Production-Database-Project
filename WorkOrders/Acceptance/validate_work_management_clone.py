"""#419 reusable current-Production-clone read acceptance (NO production writes).

Run only in a detached, pinned candidate checkout through the governed
MSB Server Management disposable Postgres runbook. This is a feature test,
not a database clone creator or a production deployment helper.
"""
from __future__ import annotations

import argparse
import os
import re
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
APP_DIR = ROOT / "WorkOrders/Application"
sys.path.insert(0, str(APP_DIR))

from repository import WorkManagementError, WorkManagementRepository, ledger_select  # noqa:E402

HEX40 = re.compile(r"^[a-f0-9]{40}$")


def checked_sha(expected_sha: str) -> None:
    if not HEX40.fullmatch(expected_sha):
        raise ValueError("Expected pinned candidate must be an exact 40-character SHA.")
    actual = subprocess.check_output(
        ["git", "-C", str(ROOT), "rev-parse", "HEAD"],
        text=True,
        stderr=subprocess.DEVNULL,
    ).strip().lower()
    if actual != expected_sha:
        raise RuntimeError("Work Management clone candidate SHA does not match.")


def validate(preview_email: str) -> None:
    repo = WorkManagementRepository()
    with repo.connect() as conn, conn.cursor() as cur:
        cur.execute("SHOW transaction_read_only")
        if cur.fetchone()[0] != "on":
            raise RuntimeError("Disposable reader transaction is not READ ONLY.")
        cur.execute("SELECT current_database(), inet_server_addr()::text")
        db_name, db_addr = cur.fetchone()
        if db_name == "msb" or not db_name.startswith("msb_"):
            raise RuntimeError("Expected a separately named approved MSB disposable clone.")
        # This is NOT sufficient to prove instance isolation; the governing
        # server runner must verify container IP, network, dump and live invariants.
        print(f"CHECK: clone_database={db_name}, internal_addr={db_addr}")
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

    access = repo.access(preview_email)
    if access["person_id"] < 1:
        raise RuntimeError("Approved reviewer is not a linked active Person.")

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

    all_rows = repo.tickets(
        actor=access, scope="all", person_id=None,
        show_completed=True, search="", limit=100,
    )
    print(f"CHECK: authorized All Work Orders read PASS; sampled_rows={len(all_rows)}")

    names = repo.assignees()
    if any(row["person_id"] < 1 for row in names):
        raise RuntimeError("Assignee list contains an invalid permanent Person ID.")
    print(f"CHECK: assignee Person selector PASS; choices={len(names)}")

    if access["can_manage"]:
        # The accepted source report Intake #60 is an excellent data fixture
        # but cannot be assumed present on every future/current clone.
        if any(row[0] == "INTAKE-60" for row in examples):
            ticket = repo.ticket(actor=access, ticket_key="INTAKE-60")
            original = ticket["setup_context"]
            if not original.get("stage_id"):
                raise RuntimeError("Intake #60 has no retained Stage provenance.")
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
        print("INFO: non-manager reviewer; Manager Intake fixture validation not applicable.")

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
        checked_sha(args.candidate_sha)
        validate(args.preview_email.strip().lower())
        return 0
    except (ValueError, RuntimeError, OSError, WorkManagementError) as exc:
        print("WORK MANAGEMENT #419 DISPOSABLE READ ACCEPTANCE HOLD:", str(exc))
        return 1
    except Exception as exc:
        # Retain the exception class and failing test phase without emitting
        # database errors, SQL, reporter text, credentials or stack traces.
        # Detailed traceback stays out of both operator terminal and report.
        print("WORK MANAGEMENT #419 DISPOSABLE READ ACCEPTANCE HOLD:"
              f" unexpected validator exception class={type(exc).__name__};"
              " no source/database diagnostic details emitted.")
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
