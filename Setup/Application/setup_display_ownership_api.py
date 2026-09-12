"""Governed API for #141 task-specific reusable Setup Display ownership."""
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


setup_display_ownership_api = Blueprint("setup_display_ownership_api", __name__)


def repo() -> SetupNextRepository:
    return SetupNextRepository(setup_database_dsn())


def required_year(payload: dict) -> int:
    year = payload.get("season_year")
    if isinstance(year, bool) or not isinstance(year, int):
        raise SetupCommandError("season_year must be an integer")
    return year


@setup_display_ownership_api.post(
    "/api/setup/tasks/<int:setup_task_id>/display-ownership/initialize"
)
def api_initialize_setup_display_ownership(setup_task_id: int) -> Response:
    require_setup_command()
    _base_repo, email, _access = require_manager()
    payload = json_body()
    context = repo().initialize_display_ownership(
        email=email,
        task_id=setup_task_id,
        season_year=required_year(payload),
    )
    return jsonify(context=context)


@setup_display_ownership_api.patch(
    "/api/setup/tasks/<int:context_setup_task_id>/display-ownership/<int:display_id>"
)
def api_set_setup_display_owner(context_setup_task_id: int, display_id: int) -> Response:
    require_setup_command()
    _base_repo, email, _access = require_manager()
    payload = json_body()
    target_task_id = payload.get("target_setup_task_id")
    if isinstance(target_task_id, bool) or not isinstance(target_task_id, int):
        raise SetupCommandError("target_setup_task_id must be an integer")

    context = repo().set_display_owner(
        email=email,
        context_task_id=context_setup_task_id,
        display_id=display_id,
        target_task_id=target_task_id,
        season_year=required_year(payload),
    )
    return jsonify(context=context)


@setup_display_ownership_api.errorhandler(SetupAuthenticationError)
def setup_display_ownership_authentication_error(
    exc: SetupAuthenticationError,
) -> tuple[Response, int]:
    return jsonify(
        error="Setup Session sign-in identity is unavailable",
        engineering_error=str(exc),
    ), 401


@setup_display_ownership_api.errorhandler(SetupCommandError)
def setup_display_ownership_command_error(exc: SetupCommandError) -> tuple[Response, int]:
    return jsonify(error=str(exc), engineering_error=str(exc)), 403


@setup_display_ownership_api.errorhandler(SetupNextRepositoryError)
def setup_display_ownership_repository_error(
    exc: SetupNextRepositoryError,
) -> tuple[Response, int]:
    return jsonify(error=str(exc), engineering_error=str(exc)), 400


@setup_display_ownership_api.errorhandler(psycopg2.Error)
def setup_display_ownership_database_error(exc: psycopg2.Error) -> tuple[Response, int]:
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
    message = (exc.diag.message_primary or "Setup Display ownership command failed").strip()
    return jsonify(error=message, engineering_error=str(exc)), status
