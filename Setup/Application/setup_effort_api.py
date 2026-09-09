"""Narrow reusable Setup effort read/write API.

The effort hint is permanent reusable-task knowledge. Reads use the existing
application SELECT surface; writes call only ref.set_setup_task_effort().
"""
from __future__ import annotations

from contextlib import closing

import psycopg2
from psycopg2.extras import RealDictCursor
from flask import Blueprint, Response, jsonify

from setup_api import (
    SetupAuthenticationError,
    SetupCommandError,
    authenticated_email,
    json_body,
    require_manager,
    require_reader,
    require_setup_command,
    setup_database_dsn,
)
from setup_repository import SetupRepositoryError

setup_effort_api = Blueprint("setup_effort_api", __name__)


@setup_effort_api.get("/api/setup/task-efforts")
def api_setup_task_efforts() -> Response:
    require_reader()
    with closing(psycopg2.connect(setup_database_dsn())) as conn:
        with conn.cursor(cursor_factory=RealDictCursor) as cur:
            cur.execute(
                """
                SELECT setup_task_id, effort_level
                FROM ref.setup_task
                WHERE active_flag
                ORDER BY setup_task_id
                """
            )
            rows = [dict(row) for row in cur.fetchall()]
    return jsonify(task_efforts=rows)


@setup_effort_api.patch("/api/setup/tasks/<int:setup_task_id>/effort")
def api_setup_task_effort_update(setup_task_id: int) -> Response:
    require_setup_command()
    _repo, email, _access = require_manager()
    payload = json_body()
    effort = payload.get("effort_level")
    if effort is not None and not isinstance(effort, str):
        raise SetupCommandError("effort_level must be LIGHT, MODERATE, HEAVY, or blank")

    conn = psycopg2.connect(setup_database_dsn())
    try:
        conn.set_session(readonly=False, autocommit=False)
        with conn.cursor(cursor_factory=RealDictCursor) as cur:
            cur.execute(
                "SELECT * FROM ref.set_setup_task_effort(%s,%s,%s)",
                (email, setup_task_id, effort),
            )
            row = cur.fetchone()
            if row is None:
                raise SetupRepositoryError("Setup effort command returned no result")
        conn.commit()
    finally:
        conn.close()

    return jsonify(setup_task_effort=dict(row))


@setup_effort_api.errorhandler(SetupAuthenticationError)
def setup_effort_authentication_error(exc: SetupAuthenticationError) -> tuple[Response, int]:
    return jsonify(error="Setup Session sign-in identity is unavailable", engineering_error=str(exc)), 401


@setup_effort_api.errorhandler(SetupCommandError)
def setup_effort_command_error(exc: SetupCommandError) -> tuple[Response, int]:
    return jsonify(error=str(exc), engineering_error=str(exc)), 403


@setup_effort_api.errorhandler(SetupRepositoryError)
def setup_effort_repository_error(exc: SetupRepositoryError) -> tuple[Response, int]:
    return jsonify(error=str(exc), engineering_error=str(exc)), 503


@setup_effort_api.errorhandler(psycopg2.Error)
def setup_effort_database_error(exc: psycopg2.Error) -> tuple[Response, int]:
    sqlstate = exc.pgcode or ""
    if sqlstate == "42501":
        status = 403
    elif sqlstate in {"22023", "23503", "23514"}:
        status = 400
    elif sqlstate == "P0002":
        status = 404
    else:
        status = 500
    message = (exc.diag.message_primary or "Setup effort command failed").strip()
    return jsonify(error=message, engineering_error=str(exc)), status
