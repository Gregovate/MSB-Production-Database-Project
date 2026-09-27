"""Protected API for #172 Setup Report Correction -> Work Order Intake."""
from __future__ import annotations

from typing import Any

import psycopg2
from flask import Blueprint, Response, jsonify

from backend import ConfigError, ProcedureContextError, SetupInstructionError
from setup_api import (
    SetupAuthenticationError,
    SetupCommandError,
    json_body,
    require_reader,
    require_setup_command,
    setup_database_dsn,
)
from setup_next_api import _task_instructions
from setup_next_repository import SetupNextRepositoryError
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


def current_procedure_context(
    setup_task_id: int | None,
    access: dict[str, Any],
) -> dict[str, Any]:
    """Resolve current Procedure identity without blocking correction intake."""
    if setup_task_id is None:
        return {
            "status": "NOT_APPLICABLE",
            "scope_type": "SEASON_ONLY",
            "documents": [],
            "summary": "No reusable Setup Procedure identity",
        }

    try:
        _task, instructions = _task_instructions(setup_task_id, access)
    except (
        SetupCommandError,
        SetupNextRepositoryError,
        ConfigError,
        ProcedureContextError,
        SetupInstructionError,
        OSError,
    ):
        return {
            "status": "UNRESOLVED",
            "scope_type": None,
            "documents": [],
            "summary": "Current Setup Procedure context unresolved",
        }

    documents = [
        {"name": str(item.get("name") or "").strip()}
        for item in (instructions.get("current_documents") or [])
        if str(item.get("name") or "").strip()
    ]
    names = [item["name"] for item in documents]
    status = str(instructions.get("status") or "").strip() or None
    scope_type = str(instructions.get("scope_type") or "").strip() or None
    summary = ", ".join(names) if names else (status or "No current Setup Procedure")

    return {
        "status": status,
        "scope_type": scope_type,
        "documents": documents,
        "summary": summary,
    }


@setup_work_order_intake_api.post(
    "/api/setup/session-tasks/<int:setup_session_task_id>/correction-intake"
)
def api_setup_correction_intake(
    setup_session_task_id: int,
) -> tuple[Response, int]:
    require_setup_command()
    _base_repo, email, access = require_reader()
    payload = json_body()

    problem = str(payload.get("problem") or "").strip()
    if not problem:
        raise SetupCommandError("What did you find? is required")
    if len(problem) > 255:
        raise SetupCommandError("Finding must be 255 characters or less")

    suggestion = str(
        payload.get("suggested_correction_evidence") or ""
    ).strip() or None
    if suggestion is not None and len(suggestion) > 2000:
        raise SetupCommandError(
            "Suggested correction / evidence must be 2000 characters or less"
        )

    assignment_id = nullable_int(
        payload.get("setup_work_day_task_id"),
        "setup_work_day_task_id",
    )
    if assignment_id is None:
        raise SetupCommandError("Scheduled assignment identity is required")

    intake_repo = repo()
    assignment = intake_repo.assignment_context(
        session_task_id=setup_session_task_id,
        assignment_id=assignment_id,
    )
    if assignment is None:
        raise SetupCommandError(
            "Scheduled assignment does not belong to this Setup task"
        )

    procedure_context = current_procedure_context(
        nullable_int(assignment.get("setup_task_id"), "setup_task_id"),
        access,
    )

    result = intake_repo.submit(
        email=email,
        session_task_id=setup_session_task_id,
        assignment_id=assignment_id,
        problem=problem,
        suggested_correction_evidence=suggestion,
        procedure_context=procedure_context,
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
        error="Setup correction intake is temporarily unavailable.",
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
    message = (exc.diag.message_primary or "Setup correction intake failed").strip()
    return jsonify(error=message, engineering_error=str(exc)), status
