"""#171/#230: protected SAME-map PostgreSQL reference read and named writes.

No GPX/FLW edits, no new movement projection, no arbitrary table CRUD.
Cloudflare identity + Directus Setup read gate + installed Directus capabilities
are evaluated on the SERVER; client-side controls are only a convenience.
"""
from __future__ import annotations

import json
from contextlib import closing

import psycopg2
from flask import Blueprint, Response, jsonify

from setup_api import (
    SetupAuthenticationError,
    SetupCommandError,
    json_body,
    require_reader,
    require_setup_command,
    setup_database_dsn,
)
from setup_repository import SetupRepositoryError

site_reference_api = Blueprint("site_reference_api", __name__)

MANAGER_COMMANDS = frozenset({
    "manager_update_waypoint", "manager_add_network",
    "manager_create_cable", "manager_link_test", "manager_add_alias",
    "manager_retire_cable", "manager_update_track_label",
})
CREW_COMMANDS = frozenset()  # Power writes use the existing FieldWiring API.


def _no_store(response: Response) -> Response:
    response.headers["Cache-Control"] = "no-store, max-age=0"
    response.headers["Pragma"] = "no-cache"
    response.headers["Vary"] = "Cf-Access-Authenticated-User-Email"
    return response


def _permissions(cursor, email: str) -> dict:
    cursor.execute("SELECT ref.site_reference_permissions(%s)", (email,))
    return cursor.fetchone()[0]


@site_reference_api.get("/api/setup/locate/references")
def read_references() -> Response:
    """Read maintained map references and resolved FLW test connections together."""
    _repo, email, access = require_reader()
    with closing(psycopg2.connect(setup_database_dsn())) as connection:
        with connection.cursor() as cursor:
            cursor.execute("SELECT ref.site_reference_snapshot() || ref.site_map_power_details()")
            snapshot = cursor.fetchone()[0]
            permissions = _permissions(cursor, email)
    if not isinstance(snapshot, dict) or snapshot.get("data_mode") != "postgres":
        raise SetupRepositoryError("GIS reference snapshot not configured")
    # Setup manager alone is not an identity grant; crew rights are independent
    # of movement and task administration.
    permissions = {
        "identity": bool(access.get("can_manage_setup") and permissions.get("identity")),
        "operations": bool(permissions.get("operations")),
    }
    snapshot["permissions"] = permissions
    return _no_store(jsonify(snapshot))


@site_reference_api.post("/api/setup/locate/references/command")
def write_references() -> Response:
    """Named audited command with expected revision, not generic ref.* mutation."""
    _repo, email, access = require_reader()
    require_setup_command()
    body = json_body()
    command = body.get("command")
    expected = body.get("expected_revision")
    fields = body.get("fields")
    if command not in MANAGER_COMMANDS | CREW_COMMANDS:
        raise SetupCommandError("Unknown site reference command")
    if isinstance(expected, bool) or not isinstance(expected, int) or expected < 0:
        raise SetupCommandError("Expected numeric map reference revision required")
    if not isinstance(fields, dict) or not isinstance(fields.get("evidence_notes"), str) \
            or not fields["evidence_notes"].strip():
        raise SetupCommandError("Evidence notes are required")
    # Enforce distinct identity and field-maintenance rights before transaction.
    with closing(psycopg2.connect(setup_database_dsn())) as connection:
        with connection.cursor() as cursor:
            perms = _permissions(cursor, email)
        if command in MANAGER_COMMANDS:
            authorized = bool(access.get("can_manage_setup") and perms.get("identity"))
        else:
            authorized = bool(perms.get("operations"))
        if not authorized:
            raise SetupCommandError("Site reference editor scope not granted")
        # Permissions SELECT opened a transaction; close before changing mode.
        connection.rollback()
        connection.set_session(readonly=False, autocommit=False)
        try:
            with connection.cursor() as cursor:
                cursor.execute(
                    "SELECT ref.site_reference_command(%s,%s,%s,%s::jsonb)",
                    (email, command, expected, json.dumps(fields)),
                )
                result = cursor.fetchone()[0]
            connection.commit()
        except Exception:
            connection.rollback()
            raise
    return _no_store(jsonify(result))


@site_reference_api.errorhandler(SetupAuthenticationError)
def _unauthenticated(exc: SetupAuthenticationError):
    return _no_store(jsonify(error=str(exc))), 401


@site_reference_api.errorhandler(SetupCommandError)
def _command_denied(exc: SetupCommandError):
    message = str(exc)
    status = 403 if ("not granted" in message or "not authorized" in message) else 400
    return _no_store(jsonify(error=message)), status


@site_reference_api.errorhandler(SetupRepositoryError)
def _repository_unavailable(exc: SetupRepositoryError):
    return _no_store(jsonify(error=str(exc))), 503


@site_reference_api.errorhandler(psycopg2.Error)
def _database_error(exc: psycopg2.Error):
    sqlstate = exc.pgcode or ""
    code = (403 if sqlstate == "42501" else
            409 if sqlstate in ("40001", "23505") else
            404 if sqlstate == "P0002" else
            400 if sqlstate in ("22023", "23503", "23514", "22P02") else
            503 if sqlstate in ("42P01", "42883") else 500)
    message = getattr(getattr(exc, "diag", None), "message_primary", None) \
        or "GIS reference database command failed"
    return _no_store(jsonify(error=message)), code
