"""Protected API for #172 Setup-context Work Order Intake submission."""
from __future__ import annotations

from typing import Any

import psycopg2
from flask import Blueprint, Response, jsonify, request

from setup_api import (
    SetupAuthenticationError,
    SetupCommandError,
    json_body,
    require_reader,
    require_setup_command,
    setup_database_dsn,
)
from setup_work_order_intake_repository import (
    SetupWorkOrderIntakeRepository,
    SetupWorkOrderIntakeRepositoryError,
)


setup_work_order_intake_api = Blueprint("setup_work_order_intake_api", __name__)


def repo() -> SetupWorkOrderIntakeRepository:
    return SetupWorkOrderIntakeRepository(setup_database_dsn())


def nullable_int(value: Any, name: str) -> int | None:
    if value is None or value == "":
        return None
    if isinstance(value, bool):
        raise SetupCommandError(f"{name} must be an integer")
    try:
        return int(value)
    except (TypeError, ValueError) as exc:
        raise SetupCommandError(f"{name} must be an integer") from exc


@setup_work_order_intake_api.post(
    "/api/setup/session-tasks/<int:setup_session_task_id>/problem-intake"
)
def api_setup_problem_intake(setup_session_task_id: int) -> tuple[Response, int]:
    require_setup_command()
    _base_repo, email, _access = require_reader()
    payload = json_body()

    problem = str(payload.get("problem") or "").strip()
    if not problem:
        raise SetupCommandError("What did you find? is required")
    if len(problem) > 255:
        raise SetupCommandError("Problem description must be 255 characters or less")

    result = repo().submit(
        email=email,
        session_task_id=setup_session_task_id,
        problem=problem,
        suggested_change=(str(payload.get("suggested_change") or "").strip() or None),
        assignment_id=nullable_int(
            payload.get("setup_work_day_task_id"),
            "setup_work_day_task_id",
        ),
        work_day_id=nullable_int(
            payload.get("setup_work_day_id"),
            "setup_work_day_id",
        ),
        shift_code=(str(payload.get("shift_code") or "").strip() or None),
    )
    return jsonify(intake=result), 201


@setup_work_order_intake_api.errorhandler(SetupAuthenticationError)
def setup_intake_authentication_error(
    exc: SetupAuthenticationError,
) -> tuple[Response, int]:
    return jsonify(
        error="Setup Session sign-in identity is unavailable",
        engineering_error=str(exc),
    ), 401


@setup_work_order_intake_api.errorhandler(SetupCommandError)
def setup_intake_command_error(exc: SetupCommandError) -> tuple[Response, int]:
    return jsonify(error=str(exc), engineering_error=str(exc)), 403


@setup_work_order_intake_api.errorhandler(SetupWorkOrderIntakeRepositoryError)
def setup_intake_repository_error(
    exc: SetupWorkOrderIntakeRepositoryError,
) -> tuple[Response, int]:
    return jsonify(
        error="Setup problem intake is temporarily unavailable.",
        engineering_error=str(exc),
    ), 503


@setup_work_order_intake_api.errorhandler(psycopg2.Error)
def setup_intake_database_error(exc: psycopg2.Error) -> tuple[Response, int]:
    sqlstate = exc.pgcode or ""
    if sqlstate == "42501":
        status = 403
    elif sqlstate in {"22023", "23503", "23514"}:
        status = 400
    elif sqlstate == "P0002":
        status = 404
    else:
        status = 500
    message = (exc.diag.message_primary or "Setup problem intake failed").strip()
    return jsonify(error=message, engineering_error=str(exc)), status
