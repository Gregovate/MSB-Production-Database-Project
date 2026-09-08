"""Protected Setup API for Manager-training/reconstruction corrections.

This module keeps reconstruction-only destructive operations separate from the
ordinary reusable-task update surface. Writes remain narrow SECURITY DEFINER
function calls through the shared read-mostly application login.
"""
from __future__ import annotations

import psycopg2
from flask import Blueprint, Response, jsonify
from psycopg2.extras import RealDictCursor

from setup_api import (
    SetupAuthenticationError,
    SetupCommandError,
    require_manager,
    require_setup_command,
    setup_database_dsn,
)


setup_training_api = Blueprint("setup_training_api", __name__)


@setup_training_api.delete("/api/setup/tasks/<int:setup_task_id>/reconstruction-delete")
def api_delete_reconstruction_task(setup_task_id: int) -> Response:
    require_setup_command()
    _base_repo, email, _access = require_manager()

    conn = psycopg2.connect(setup_database_dsn())
    try:
        conn.set_session(readonly=False, autocommit=False)
        with conn.cursor(cursor_factory=RealDictCursor) as cur:
            cur.execute(
                "SELECT * FROM ref.delete_setup_reconstruction_task(%s,%s)",
                (email, setup_task_id),
            )
            row = cur.fetchone()
            if row is None:
                raise RuntimeError("Setup reconstruction delete returned no result")
        conn.commit()
        return jsonify(deleted_task=dict(row))
    except Exception:
        conn.rollback()
        raise
    finally:
        conn.close()


@setup_training_api.errorhandler(SetupAuthenticationError)
def setup_training_authentication_error(exc: SetupAuthenticationError) -> tuple[Response, int]:
    return jsonify(
        error="Setup Session sign-in identity is unavailable",
        engineering_error=str(exc),
    ), 401


@setup_training_api.errorhandler(SetupCommandError)
def setup_training_command_error(exc: SetupCommandError) -> tuple[Response, int]:
    return jsonify(error=str(exc), engineering_error=str(exc)), 403


@setup_training_api.errorhandler(psycopg2.Error)
def setup_training_database_error(exc: psycopg2.Error) -> tuple[Response, int]:
    primary = getattr(getattr(exc, "diag", None), "message_primary", None)
    message = str(primary or exc).strip()
    return jsonify(
        error=message or "Setup reconstruction correction was rejected by the database.",
        engineering_error=str(exc),
    ), 409


@setup_training_api.errorhandler(RuntimeError)
def setup_training_runtime_error(exc: RuntimeError) -> tuple[Response, int]:
    return jsonify(error=str(exc), engineering_error=str(exc)), 500
