"""#122 Work Orders → Setup wiring verification step contract.

Only the PLUG IN & VERIFY: Wire ... annual task is eligible.
Independent public Intake Stage is only a scope hint, not evidence of
which person performed the original work or caused a defect.
"""
from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parent
sys.path.insert(0, str(ROOT))
from setup_accountability import (eligible_wiring_task, safe_identity,
                                  stage_scope, fetch_wiring_candidates)


class FakeCursor:
    def __init__(self, *, stages=(), tasks=()):
        self.stages = list(stages)
        self.tasks = list(tasks)
        self.calls = []
        self.rows = []
    def execute(self, sql, params):
        self.calls.append((sql, params))
        self.rows = self.stages if "FROM ref.stage" in sql else self.tasks
    def fetchall(self):
        return self.rows


def ticket(stage_raw="13-Winter Wonderland-WW", stage_id=None):
    return {"type":"INTAKE_REQUEST","detail":{"stage_raw":stage_raw,
            "stage_id":stage_id},"setup_context":{}}


def test_wiring_task_filter_rejects_network_and_installation():
    assert eligible_wiring_task("PLUG IN & VERIFY: Wire Displays to Controller")
    assert eligible_wiring_task("PLUG IN & VERIFY: Wire Arches to Controllers")
    assert not eligible_wiring_task("Plug in Network to controller and watch 2 minute Test show")
    assert not eligible_wiring_task("Setup Church RGB (John's) Tree")
    assert not eligible_wiring_task("Install Church Steeples")
    assert not eligible_wiring_task("PLUG IN & VERIFY: Plug in Network")
    assert not eligible_wiring_task(None)


def test_stage_identity_does_not_prove_who_did_the_wiring():
    assert stage_scope(ticket()) == (None, "13-Winter Wonderland-WW")
    assert safe_identity(True) is None
    cur = FakeCursor(stages=[{"stage_id": 13, "stage_name": "13-Winter Wonderland-WW"}],
                     tasks=[{"setup_session_task_id":444, "task_name":
                             "PLUG IN & VERIFY: Wire Displays to Controller",
                             "execution_status":"IN_PROGRESS"},
                            {"setup_session_task_id":496,"task_name":
                             "Plug in Network to controller and watch Test show"}])
    outcome = fetch_wiring_candidates(cur, ticket())
    assert outcome["stage_id"] == 13
    assert len(outcome["candidates"]) == 1
    assert outcome["candidates"][0]["relationship"] == "CANDIDATE_NOT_LINKED"
    assert outcome["candidates"][0]["original_worker"] == "NOT_ESTABLISHED"
    assert cur.calls[1][1] == (2026,13)
    assert "annual_task_name ~*" in cur.calls[1][0]


def test_ambiguous_stage_remains_unlinked():
    cur = FakeCursor(stages=[{"stage_id": 13}, {"stage_id": 99}])
    result = fetch_wiring_candidates(cur,ticket())
    assert result["scope"] == "AMBIGUOUS_STAGE"
    assert result["candidates"] == []
    assert len(cur.calls) == 1


def test_exact_provenance_stage_bypasses_fuzzy_stage_matching():
    cur = FakeCursor(tasks=[{"setup_session_task_id":509,
                             "task_name":"PLUG IN & VERIFY: Wire Displays to Controller"}])
    result = fetch_wiring_candidates(cur,ticket(stage_id=6,stage_raw="Ignored"))
    assert result["stage_id"] == 6
    assert len(cur.calls)==1
    assert cur.calls[0][1] == (2026,6)


def test_no_writing_and_manager_only_contract():
    source = (ROOT/"repository.py").read_text()
    block = source.split("    def wiring_accountability(",1)[1].split(
        "    def related_information(",1)[0]
    assert 'actor.get("can_manage")' in block
    assert 'self.ticket(actor=actor, ticket_key=ticket_key)' in block
    assert 'self.connect()' in block
    assert "write_connect" not in block
    sql = (ROOT/"setup_accountability.py").read_text()
    assert "UPDATE ops" not in sql
    assert "INSERT INTO" not in sql
    assert "ops.setup_task_progress" not in sql  # least-privilege until reviewed
    assert "/api/work-orders/tickets/<key>/wiring-accountability" in (
        ROOT/"backend.py").read_text()
    ui = (ROOT/"app.js").read_text()
    assert "CANDIDATE ONLY — not linked or attributed" in ui
    assert 'state.actor?.can_manage' in ui


def test_clone_reader_does_not_gain_duplicate_table_access():
    # Current Production clone may already contain migration005, while the
    # legacy fieldwiring_app read harness intentionally lacks its SELECT grant.
    # Verify the read projection checks permissions before selecting the table.
    source = (ROOT / "repository.py").read_text()
    begin = source.index("duplicate_relation = cur.fetchone() or {}")
    section = source[begin:begin + 1100]
    assert "duplicate_lookup_available" in section
    assert 'if row["duplicate_lookup_available"]:' in section
    assert "has_table_privilege(current_user" in source
    assert "GRANT SELECT" not in section
    assert "ops.work_management_duplicate_link WHERE source_ticket" in section
