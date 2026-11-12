"""Protected Setup API for Manager-training/reconstruction corrections.

This module keeps reconstruction-only destructive operations and reusable-task
knowledge-owner maintenance separate from the ordinary task update surface.
Writes remain narrow SECURITY DEFINER function calls through the shared
read-mostly application login.
"""
from __future__ import annotations

from typing import Any

import psycopg2
from flask import Blueprint, Response, jsonify
from psycopg2.extras import RealDictCursor

from setup_api import (
    SetupAuthenticationError,
    SetupCommandError,
    json_body,
    require_manager,
    require_reader,
    require_setup_command,
    setup_database_dsn,
)


setup_training_api = Blueprint("setup_training_api", __name__)


def _read_rows(sql: str, params: tuple[Any, ...] = ()) -> list[dict[str, Any]]:
    conn = psycopg2.connect(setup_database_dsn())
    try:
        with conn.cursor(cursor_factory=RealDictCursor) as cur:
            cur.execute(sql, params)
            return [dict(row) for row in cur.fetchall()]
    finally:
        conn.close()


def _write_one(sql: str, params: tuple[Any, ...], empty_message: str) -> dict[str, Any]:
    conn = psycopg2.connect(setup_database_dsn())
    try:
        conn.set_session(readonly=False, autocommit=False)
        with conn.cursor(cursor_factory=RealDictCursor) as cur:
            cur.execute(sql, params)
            row = cur.fetchone()
            if row is None:
                raise RuntimeError(empty_message)
        conn.commit()
        return dict(row)
    except Exception:
        conn.rollback()
        raise
    finally:
        conn.close()


@setup_training_api.delete("/api/setup/tasks/<int:setup_task_id>/reconstruction-delete")
def api_delete_reconstruction_task(setup_task_id: int) -> Response:
    require_setup_command()
    _base_repo, email, _access = require_manager()
    row = _write_one(
        "SELECT * FROM ref.delete_setup_reconstruction_task(%s,%s)",
        (email, setup_task_id),
        "Setup reconstruction delete returned no result",
    )
    return jsonify(deleted_task=row)


@setup_training_api.get("/api/setup/tasks/<int:setup_task_id>/captains")
def api_setup_task_captains(setup_task_id: int) -> Response:
    require_reader()
    rows = _read_rows(
        "SELECT * FROM ref.setup_task_captain_list(%s)",
        (setup_task_id,),
    )
    return jsonify(captains=rows)


@setup_training_api.get("/api/setup/captain-people")
def api_setup_captain_people() -> Response:
    require_manager()
    return jsonify(people=_read_rows("SELECT * FROM ref.setup_captain_person_list()"))


@setup_training_api.patch("/api/setup/tasks/<int:setup_task_id>/captains/<int:person_id>")
def api_set_setup_task_captain(setup_task_id: int, person_id: int) -> Response:
    require_setup_command()
    _base_repo, email, _access = require_manager()
    payload = json_body()
    role = str(payload.get("captain_role") or "CAPTAIN").strip().upper()
    sort_order = payload.get("sort_order", 100)
    if isinstance(sort_order, bool):
        raise SetupCommandError("sort_order must be an integer")
    try:
        normalized_sort_order = int(sort_order)
    except (TypeError, ValueError) as exc:
        raise SetupCommandError("sort_order must be an integer") from exc

    row = _write_one(
        "SELECT * FROM ref.set_setup_task_captain(%s,%s,%s,%s,%s,%s,%s)",
        (
            email,
            setup_task_id,
            person_id,
            role,
            normalized_sort_order,
            str(payload.get("notes") or "").strip() or None,
            bool(payload.get("active", True)),
        ),
        "Setup Captain command returned no result",
    )
    return jsonify(captain=row)


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
