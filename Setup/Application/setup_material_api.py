"""Narrow reusable Setup Display-material read/write API.

The operator decides only whether a reusable Setup task requires Display/container
material. LOR material membership itself is resolved automatically elsewhere.
"""
from __future__ import annotations

from contextlib import closing

import psycopg2
from psycopg2.extras import RealDictCursor
from flask import Blueprint, Response, jsonify

from setup_api import (
    SetupAuthenticationError,
    SetupCommandError,
    json_body,
    require_manager,
    require_reader,
    require_setup_command,
    setup_database_dsn,
)
from setup_repository import SetupRepositoryError


setup_material_api = Blueprint("setup_material_api", __name__)


@setup_material_api.get("/api/setup/task-material-flags")
def api_setup_task_material_flags() -> Response:
    require_reader()
    with closing(psycopg2.connect(setup_database_dsn())) as conn:
        with conn.cursor(cursor_factory=RealDictCursor) as cur:
            cur.execute(
                """
                SELECT setup_task_id, requires_display_material
                FROM ref.setup_task
                ORDER BY setup_task_id
                """
            )
            rows = [dict(row) for row in cur.fetchall()]
    return jsonify(task_material_flags=rows)


@setup_material_api.patch("/api/setup/tasks/<int:setup_task_id>/display-material")
def api_setup_task_display_material_update(setup_task_id: int) -> Response:
    require_setup_command()
    _repo, email, _access = require_manager()
    payload = json_body()
    requires = payload.get("requires_display_material")
    if not isinstance(requires, bool):
        raise SetupCommandError("requires_display_material must be true or false")

    conn = psycopg2.connect(setup_database_dsn())
    try:
        conn.set_session(readonly=False, autocommit=False)
        with conn.cursor(cursor_factory=RealDictCursor) as cur:
            cur.execute(
                """
                SELECT *
                FROM ref.set_setup_task_display_material_requirement(%s,%s,%s)
                """,
                (email, setup_task_id, requires),
            )
            row = cur.fetchone()
            if row is None:
                raise SetupRepositoryError("Setup Display-material command returned no result")
        conn.commit()
    finally:
        conn.close()

    return jsonify(setup_task_material=dict(row))


@setup_material_api.errorhandler(SetupAuthenticationError)
def setup_material_authentication_error(exc: SetupAuthenticationError) -> tuple[Response, int]:
    return jsonify(error="Setup Session sign-in identity is unavailable", engineering_error=str(exc)), 401


@setup_material_api.errorhandler(SetupCommandError)
def setup_material_command_error(exc: SetupCommandError) -> tuple[Response, int]:
    return jsonify(error=str(exc), engineering_error=str(exc)), 403


@setup_material_api.errorhandler(SetupRepositoryError)
def setup_material_repository_error(exc: SetupRepositoryError) -> tuple[Response, int]:
    return jsonify(error=str(exc), engineering_error=str(exc)), 503


@setup_material_api.errorhandler(psycopg2.Error)
def setup_material_database_error(exc: psycopg2.Error) -> tuple[Response, int]:
    sqlstate = exc.pgcode or ""
    if sqlstate == "42501":
        status = 403
    elif sqlstate in {"22023", "23503", "23514"}:
        status = 400
    elif sqlstate == "P0002":
        status = 404
    else:
        status = 500
    message = (exc.diag.message_primary or "Setup Display-material command failed").strip()
    return jsonify(error=message, engineering_error=str(exc)), status
