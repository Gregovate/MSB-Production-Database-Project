"""#171/#230 protected reference API contract, no database or Production access."""
import json

import pytest
from flask import Flask

import setup_site_reference_api as api


class FakeCursor:
    def __init__(self, connection):
        self.conn = connection
        self.row = None

    def __enter__(self):
        return self

    def __exit__(self, *_):
        return False

    def execute(self, sql, args=None):
        self.conn.queries.append((sql, args))
        if "ref.site_reference_snapshot()" in sql:
            self.row = (self.conn.snapshot,)
        elif "ref.site_reference_permissions" in sql:
            self.row = (self.conn.permissions,)
        elif "ref.site_reference_command" in sql:
            self.row = ({"revision": 4, "command": args[1], "changed": True},)
        else:
            raise AssertionError(f"Unexpected SQL: {sql}")

    def fetchone(self):
        return self.row


class FakeConnection:
    def __init__(self, permissions=None):
        self.queries = []
        self.snapshot = {"data_mode": "postgres", "format_version": 1,
                         "revision": 3, "waypoints": [], "networks": []}
        self.permissions = permissions or {"identity": False, "operations": False}
        self.committed = False
        self.rollback_count = 0
        self.closed = False
        self.write_session = False

    def cursor(self):
        return FakeCursor(self)

    def set_session(self, **kwargs):
        # Real psycopg2 refuses changes while SELECT's transaction is open.
        assert self.rollback_count == 1
        assert kwargs == {"readonly": False, "autocommit": False}
        self.write_session = True

    def rollback(self):
        self.rollback_count += 1

    def commit(self):
        self.committed = True

    def close(self):
        self.closed = True


@pytest.fixture
def setup(monkeypatch):
    conn = FakeConnection()
    # Return this same in-memory connection for each HTTP request's new DB connect.
    monkeypatch.setattr(api.psycopg2, "connect", lambda _: conn)
    monkeypatch.setattr(api, "setup_database_dsn", lambda: "disposable-only")
    access = {"can_read_setup": True, "can_manage_setup": False,
              "can_move_setup_assets": True}
    monkeypatch.setattr(api, "require_reader",
                        lambda: (None, "volunteer@example.test", access))
    app = Flask(__name__)
    app.register_blueprint(api.site_reference_api)
    app.testing = True
    return app.test_client(), conn, access


def _post(client, command="manager_add_alias", *, header=True, revision=3):
    headers = {"Content-Type": "application/json"}
    if header:
        headers["X-MSB-Setup-Command"] = "1"
    return client.post("/api/setup/locate/references/command", headers=headers,
        json={"command": command, "expected_revision": revision,
              "fields": {"waypoint_id": 17, "meter_identifier": "TEST ONLY",
                         "evidence_notes": "Reviewed fixture"}})


def test_read_requires_explicit_reader_gate(setup, monkeypatch):
    client, conn, access = setup
    response = client.get("/api/setup/locate/references")
    assert response.status_code == 200
    assert response.json["revision"] == 3
    assert response.json["permissions"] == {"identity": False, "operations": False}
    assert response.headers["Cache-Control"].startswith("no-store")
    assert conn.closed
    # The actual Cloudflare/Directus reader is reused, not modeled by the fixture.
    monkeypatch.setattr(api, "require_reader",
                        lambda: (_ for _ in ()).throw(
                            api.SetupAuthenticationError("No authenticated reader")))
    assert client.get("/api/setup/locate/references").status_code == 401


def test_crew_default_deny_even_when_movement_allowed(setup):
    client, conn, access = setup
    denied = _post(client)
    assert denied.status_code == 403
    assert not any("site_reference_command(" in q for q, _ in conn.queries)
    assert not conn.committed


def test_write_requires_setup_command_guard_and_evidence(setup):
    client, conn, access = setup
    conn.permissions["operations"] = True
    assert _post(client, header=False).status_code == 400
    assert client.post("/api/setup/locate/references/command",
        json={"command": "manager_add_alias", "expected_revision": 3,
              "fields": {"waypoint_id": 17}},
        headers={"X-MSB-Setup-Command": "1"}).status_code == 400
    assert _post(client, command="arbitrary_sql").status_code == 400
    assert not conn.committed


def test_legacy_power_commands_rejected_even_for_manager(setup):
    client, conn, access = setup
    conn.permissions.update(identity=True, operations=True)
    access['can_manage_setup'] = True
    assert _post(client, command='crew_set_meter').status_code == 400
    assert _post(client, command='manager_set_panel_owner').status_code == 400
    assert not conn.committed


def test_identity_grant_also_requires_setup_manager(setup):
    client, conn, access = setup
    conn.permissions["identity"] = True
    assert _post(client, command="manager_update_waypoint").status_code == 403
    access["can_manage_setup"] = True
    result = _post(client, command="manager_update_waypoint")
    assert result.status_code == 200
    assert conn.committed


def test_stale_or_noninteger_revision_rejected_before_sql(setup):
    client, conn, access = setup
    conn.permissions["operations"] = True
    result = _post(client, revision=-1)
    assert result.status_code == 400
    assert not conn.write_session
    response = client.post("/api/setup/locate/references/command",
        headers={"X-MSB-Setup-Command": "1"},
        json={"command": "manager_add_alias", "expected_revision": True,
              "fields": {"evidence_notes": "proof"}})
    assert response.status_code == 400
