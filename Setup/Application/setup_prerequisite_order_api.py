"""Protected ordered reusable Setup prerequisite API for Issue #151."""
from __future__ import annotations

import psycopg2
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
from setup_prerequisite_order_repository import (
    SetupPrerequisiteOrderRepository,
    SetupPrerequisiteOrderRepositoryError,
)

setup_prerequisite_order_api = Blueprint("setup_prerequisite_order_api", __name__)


def repo() -> SetupPrerequisiteOrderRepository:
    return SetupPrerequisiteOrderRepository(setup_database_dsn())


@setup_prerequisite_order_api.get("/api/setup/dependencies/ordered")
def api_setup_ordered_dependencies() -> Response:
    require_reader()
    return jsonify(dependencies=repo().ordered_dependencies())


@setup_prerequisite_order_api.patch("/api/setup/tasks/<int:setup_task_id>/dependencies/order")
def api_setup_reorder_dependencies(setup_task_id: int) -> Response:
    require_setup_command()
    _base_repo, email, _access = require_manager()
    payload = json_body()
    raw = payload.get("prerequisite_setup_task_ids")
    if not isinstance(raw, list):
        raise SetupCommandError("prerequisite_setup_task_ids must be a list")

    prerequisite_ids: list[int] = []
    for value in raw:
        if isinstance(value, bool):
            raise SetupCommandError("prerequisite_setup_task_ids must contain integers")
        try:
            parsed = int(value)
        except (TypeError, ValueError) as exc:
            raise SetupCommandError("prerequisite_setup_task_ids must contain integers") from exc
        if parsed <= 0:
            raise SetupCommandError("prerequisite_setup_task_ids must contain positive task IDs")
        prerequisite_ids.append(parsed)

    result = repo().reorder_dependencies(
        email=email,
        task_id=setup_task_id,
        prerequisite_ids=prerequisite_ids,
    )
    return jsonify(dependencies=result)


@setup_prerequisite_order_api.errorhandler(SetupAuthenticationError)
def prerequisite_authentication_error(exc: SetupAuthenticationError) -> tuple[Response, int]:
    return jsonify(
        error="Setup Session sign-in identity is unavailable",
        engineering_error=str(exc),
    ), 401


@setup_prerequisite_order_api.errorhandler(SetupCommandError)
def prerequisite_command_error(exc: SetupCommandError) -> tuple[Response, int]:
    return jsonify(error=str(exc), engineering_error=str(exc)), 403


@setup_prerequisite_order_api.errorhandler(SetupPrerequisiteOrderRepositoryError)
def prerequisite_repository_error(exc: SetupPrerequisiteOrderRepositoryError) -> tuple[Response, int]:
    return jsonify(
        error="Setup prerequisite data is temporarily unavailable.",
        engineering_error=str(exc),
    ), 503


@setup_prerequisite_order_api.errorhandler(psycopg2.Error)
def prerequisite_database_error(exc: psycopg2.Error) -> tuple[Response, int]:
    sqlstate = exc.pgcode or ""
    if sqlstate == "42501":
        status = 403
    elif sqlstate == "23505":
        status = 409
    elif sqlstate in {"22023", "23503", "23514"}:
        status = 400
    elif sqlstate == "P0002":
        status = 404
    else:
        status = 500
    message = (exc.diag.message_primary or "Setup prerequisite database command failed").strip()
    return jsonify(error=message, engineering_error=str(exc)), status
