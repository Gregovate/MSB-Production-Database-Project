"""#447 entry regression: fake connections only, no Production access."""
import sys
from contextlib import contextmanager
from pathlib import Path

import pytest

sys.path.insert(0, str(Path(__file__).resolve().parent))
import v1_runtime as runtime
from repository import WorkManagementError, WorkManagementRepository


class Connection:
    def __init__(self, events, *, failure=None, row=None):
        self.events = events
        self.failure = failure
        self.row = row

    def set_session(self, **kwargs):
        self.events.append(("session", kwargs))

    def cursor(self, **kwargs):
        return self

    def __enter__(self):
        return self

    def __exit__(self, *args):
        pass

    def execute(self, sql, args):
        self.events.append(("execute", sql, args))
        if self.failure:
            raise self.failure

    def fetchone(self):
        return self.row

    def commit(self):
        self.events.append("commit")

    def rollback(self):
        self.events.append("rollback")

    def close(self):
        self.events.append("close")


@pytest.fixture
def entry(monkeypatch):
    events = []
    monkeypatch.setenv("WORK_MGMT_RUNTIME_MODE", "production")
    monkeypatch.setenv("WORK_MGMT_PRODUCTION_DSN", "fake-only")
    monkeypatch.setenv("WORK_MGMT_V1_WRITE_GATE", "authorized_v1_release_only")
    conn = Connection(events, row={"person_id": 26})
    monkeypatch.setattr(runtime.psycopg2, "connect", lambda dsn: conn)
    monkeypatch.setattr(runtime, "require_native_database", lambda cur: events.append("native-check"))
    return runtime.V1Repository(), conn, events


def test_repair_commits_before_person_read_and_preserves_crew_rights(entry, monkeypatch):
    repo, conn, events = entry
    def read_access(self, email):
        assert email == "crew@sheboyganlights.org"
        assert events[-2:] == ["commit", "close"]
        events.append("read-access")
        return {"person_id": 26, "can_read": True, "can_manage": False}
    monkeypatch.setattr(WorkManagementRepository, "access", read_access)
    @contextmanager
    def read_connection():
        yield Connection(events, row={"person_id": 26, "can_manage": False})
    monkeypatch.setattr(repo, "connect", read_connection)
    actor = repo.access(" Crew@sheboyganlights.org ")
    assert actor["person_id"] == 26
    assert not any(actor[key] for key in ("can_manage", "can_create", "can_assign", "can_triage"))
    assert events[0] == ("session", {"readonly": False, "autocommit": False})
    assert events[1] == "native-check"
    assert events[2][1] == "SELECT person_id FROM ops.work_management_reconcile_actor(%s)"
    assert events[2][2] == ("crew@sheboyganlights.org",)


@pytest.mark.parametrize("failure", [RuntimeError("failure"), runtime.psycopg2.OperationalError("failure")])
def test_failure_rolls_back_and_closes_before_read(entry, failure, monkeypatch):
    repo, conn, events = entry
    conn.failure = failure
    monkeypatch.setattr(WorkManagementRepository, "access", lambda *a: pytest.fail("read after failure"))
    with pytest.raises(type(failure)):
        repo.access("crew@sheboyganlights.org")
    assert events[-2:] == ["rollback", "close"]
    assert "commit" not in events


def test_empty_actor_rolls_back(entry):
    repo, conn, events = entry
    conn.row = None
    with pytest.raises(WorkManagementError):
        repo.reconcile_identity("crew@sheboyganlights.org")
    assert events[-2:] == ["rollback", "close"]


@pytest.mark.parametrize("mode", ["production", "v1_disposable"])
def test_missing_write_gate_never_connects(entry, monkeypatch, mode):
    repo, _, events = entry
    monkeypatch.setenv("WORK_MGMT_RUNTIME_MODE", mode)
    monkeypatch.delenv("WORK_MGMT_V1_WRITE_GATE")
    monkeypatch.setenv("WORK_MGMT_V1_CLONE_DSN", "fake-only")
    monkeypatch.setenv("WORK_MGMT_V1_CLONE_IP", "127.0.0.2")
    monkeypatch.setenv("WORK_MGMT_PREVIEW_MODE", "disposable")
    monkeypatch.delenv("WORK_MGMT_V1_CLONE_WRITE_GATE", raising=False)
    with pytest.raises(WorkManagementError):
        repo.reconcile_identity("crew@sheboyganlights.org")
    assert events == []


def test_wrong_native_database_rolls_back_without_reconciliation(entry, monkeypatch):
    repo, _, events = entry
    def reject(cur):
        raise WorkManagementError("wrong database", 503)
    monkeypatch.setattr(runtime, "require_native_database", reject)
    with pytest.raises(WorkManagementError):
        repo.reconcile_identity("crew@sheboyganlights.org")
    assert not any(isinstance(x, tuple) and x[0] == "execute" for x in events)
    assert events[-2:] == ["rollback", "close"]


def test_identity_migration_keeps_shared_helper_private_and_actor_read_only():
    root = Path(__file__).resolve().parents[1]
    sql = (root / "Database/004_work_management_identity_reconciliation.sql").read_text()
    assert sql.index("WHERE c.can_read_setup") < sql.index("PERFORM ref.reconcile_directus_person_identity")
    assert "REVOKE ALL ON FUNCTION ops.work_management_reconcile_actor(text) FROM PUBLIC" in sql
    assert "GRANT EXECUTE ON FUNCTION ref.reconcile" not in sql
    assert "GRANT UPDATE" not in sql
    assert "CREATE TABLE" not in sql
    assert "CREATE OR REPLACE FUNCTION ops.work_management_v1_actor" not in sql
    runner = (root / "Acceptance/work_management_disposable_browser_preview_server.sh").read_text()
    assert runner.count('cat "$WORKTREE/WorkOrders/Database/004_work_management_identity_reconciliation.sql"') == 2
    assert runner.count('cat "$WORKTREE/WorkOrders/Acceptance/wo447_identity_disposable_validation.sql"') == 2


def test_browser_review_recreates_null_link_and_proves_http_commit():
    runner = (Path(__file__).resolve().parents[1] / "Acceptance" /
              "work_management_disposable_browser_preview_server.sh").read_text()
    unlink = runner.index("UPDATE ref.person SET directus_user_id=NULL")
    launch = runner.index('echo "--- Start pinned Work Management reviewer')
    assert unlink < launch < runner.index("HTTP entry did not persist audited Person repair")
    assert "repeat entry changed identity/audit" in runner
    assert '[[ "$all_status" == 403 ]]' in runner
