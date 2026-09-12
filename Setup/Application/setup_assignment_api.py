"""Governed API for Issue #141 physical-material assignments."""
from __future__ import annotations

import psycopg2
from flask import Blueprint, Response, jsonify

from setup_api import (
    SetupAuthenticationError,
    SetupCommandError,
    json_body,
    require_manager,
    require_setup_command,
    setup_database_dsn,
)
from setup_next_repository import SetupNextRepository, SetupNextRepositoryError


setup_assignment_api = Blueprint("setup_assignment_api", __name__)


def repo() -> SetupNextRepository:
    return SetupNextRepository(setup_database_dsn())


@setup_assignment_api.get("/api/setup/tasks/<int:setup_task_id>/kit-boxes")
def api_setup_task_kit_boxes(setup_task_id: int) -> Response:
    _base_repo, _email, _access = require_manager()
    return jsonify(kit_boxes=repo().kit_box_catalog(task_id=setup_task_id))


@setup_assignment_api.patch(
    "/api/setup/tasks/<int:setup_task_id>/kit-boxes/<int:container_id>"
)
def api_set_setup_task_kit_box(setup_task_id: int, container_id: int) -> Response:
    require_setup_command()
    _base_repo, email, _access = require_manager()
    payload = json_body()
    assigned = payload.get("assigned")
    if not isinstance(assigned, bool):
        raise SetupCommandError("assigned must be true or false")
    notes = payload.get("notes")
    if notes is not None and not isinstance(notes, str):
        raise SetupCommandError("notes must be text or null")

    rows = repo().set_kit_box_assignment(
        email=email,
        task_id=setup_task_id,
        container_id=container_id,
        assigned=assigned,
        notes=notes,
    )
    return jsonify(kit_boxes=rows)


@setup_assignment_api.errorhandler(SetupAuthenticationError)
def setup_assignment_authentication_error(
    exc: SetupAuthenticationError,
) -> tuple[Response, int]:
    return jsonify(
        error="Setup Session sign-in identity is unavailable",
        engineering_error=str(exc),
    ), 401


@setup_assignment_api.errorhandler(SetupCommandError)
def setup_assignment_command_error(exc: SetupCommandError) -> tuple[Response, int]:
    return jsonify(error=str(exc), engineering_error=str(exc)), 403


@setup_assignment_api.errorhandler(SetupNextRepositoryError)
def setup_assignment_repository_error(
    exc: SetupNextRepositoryError,
) -> tuple[Response, int]:
    return jsonify(error=str(exc), engineering_error=str(exc)), 400


@setup_assignment_api.errorhandler(psycopg2.Error)
def setup_assignment_database_error(exc: psycopg2.Error) -> tuple[Response, int]:
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
    message = (exc.diag.message_primary or "Setup assignment command failed").strip()
    return jsonify(error=message, engineering_error=str(exc)), status
