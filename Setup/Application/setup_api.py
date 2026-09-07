"""Protected production API for Setup Session role-governed workflows."""
from __future__ import annotations

import os
from typing import Any

import psycopg2
from flask import Blueprint, Response, jsonify, request

from setup_repository import SetupRepository, SetupRepositoryError

setup_api = Blueprint("setup_api", __name__)

CLOUDFLARE_EMAIL_HEADER = "Cf-Access-Authenticated-User-Email"
SETUP_COMMAND_HEADER = "X-MSB-Setup-Command"


class SetupAuthenticationError(RuntimeError):
    """Protected request is missing trusted Cloudflare identity."""


class SetupCommandError(RuntimeError):
    """Setup request did not satisfy the authorization/command boundary."""


def setup_database_dsn() -> str:
    for name in (
        "SETUP_DATABASE_DSN",
        "FIELDWIRING_DATABASE_DSN",
        "PROCEDURE_DATABASE_DSN",
    ):
        value = os.environ.get(name, "").strip()
        if value:
            return value
    raise SetupRepositoryError(
        "Configure SETUP_DATABASE_DSN or the existing protected application PostgreSQL DSN"
    )


def setup_repository() -> SetupRepository:
    return SetupRepository(setup_database_dsn())


def authenticated_email() -> str:
    email = (request.headers.get(CLOUDFLARE_EMAIL_HEADER) or "").strip().lower()
    if not email:
        raise SetupAuthenticationError("Cloudflare Access operator identity is missing")
    return email


def require_setup_command() -> None:
    """Require the same non-simple same-origin command shape used by Controllers."""
    if not request.is_json:
        raise SetupCommandError("Setup command requires an application/json request")
    if request.headers.get(SETUP_COMMAND_HEADER, "") != "1":
        raise SetupCommandError("Setup command request guard is missing")


def json_body() -> dict[str, Any]:
    payload = request.get_json(silent=True)
    if not isinstance(payload, dict):
        raise SetupCommandError("Setup command requires a JSON object")
    return payload


def require_reader() -> tuple[SetupRepository, str, dict[str, Any]]:
    """Require an active Directus user/policy authorized to view Setup."""
    repo = setup_repository()
    email = authenticated_email()
    access = repo.capabilities(email)
    if not access.get("can_read_setup"):
        raise SetupCommandError("Setup read access is not authorized for this account")
    return repo, email, access


def require_movement_operator() -> tuple[SetupRepository, str, dict[str, Any]]:
    """Authorize Container/Display movement/scanning only.

    This capability is intentionally separate from reusable-task, annual-review,
    planning, schedule, Procedure-maintenance, and generic task-completion writes.
    """
    repo, email, access = require_reader()
    if not access.get("can_move_setup_assets"):
        raise SetupCommandError("Setup asset movement is not authorized for this account")
    return repo, email, access


def require_manager() -> tuple[SetupRepository, str, dict[str, Any]]:
    repo, email, access = require_reader()
    if not access.get("can_manage_setup"):
        raise SetupCommandError("Setup maintenance is not authorized for this account")
    return repo, email, access


def require_admin() -> tuple[SetupRepository, str, dict[str, Any]]:
    repo, email, access = require_manager()
    if not access.get("can_admin_setup"):
        raise SetupCommandError("Setup Session creation requires Administrator access")
    return repo, email, access


@setup_api.get("/api/setup/access")
def api_setup_access() -> Response:
    email = authenticated_email()
    return jsonify(access=setup_repository().capabilities(email))


@setup_api.get("/api/setup/seasons")
def api_setup_seasons() -> Response:
    repo, _email, _access = require_reader()
    return jsonify(seasons=repo.seasons())


@setup_api.get("/api/setup/stages")
def api_setup_stages() -> Response:
    repo, _email, _access = require_reader()
    return jsonify(stages=repo.stages())


@setup_api.get("/api/setup/tasks")
def api_setup_tasks() -> Response:
    repo, _email, _access = require_reader()
    raw_year = request.args.get("season_year", "").strip()
    if not raw_year.isdigit():
        raise SetupCommandError("season_year is required")
    return jsonify(tasks=repo.tasks(int(raw_year)))


@setup_api.post("/api/setup/sessions")
def api_setup_session_create() -> Response:
    require_setup_command()
    repo, email, _access = require_admin()
    payload = json_body()
    season_year = payload.get("season_year")
    if not isinstance(season_year, int):
        raise SetupCommandError("season_year must be an integer")
    result = repo.create_session(
        email=email,
        season_year=season_year,
        status=str(payload.get("session_status") or "PLANNING"),
    )
    return jsonify(setup_session=result), 201


@setup_api.post("/api/setup/tasks")
def api_setup_task_create() -> Response:
    require_setup_command()
    repo, email, _access = require_manager()
    result = repo.create_task(email=email, payload=json_body())
    return jsonify(setup_task=result), 201


@setup_api.patch("/api/setup/tasks/<int:setup_task_id>")
def api_setup_task_update(setup_task_id: int) -> Response:
    require_setup_command()
    repo, email, _access = require_manager()
    result = repo.update_task(
        email=email,
        setup_task_id=setup_task_id,
        payload=json_body(),
    )
    return jsonify(setup_task=result)


@setup_api.patch("/api/setup/session-tasks/<int:setup_session_task_id>/review")
def api_setup_session_task_review(setup_session_task_id: int) -> Response:
    require_setup_command()
    repo, email, _access = require_manager()
    result = repo.update_session_task_review(
        email=email,
        setup_session_task_id=setup_session_task_id,
        payload=json_body(),
    )
    return jsonify(setup_session_task=result)


@setup_api.errorhandler(SetupAuthenticationError)
def setup_authentication_error(exc: SetupAuthenticationError) -> tuple[Response, int]:
    return jsonify(error="Setup Session sign-in identity is unavailable", engineering_error=str(exc)), 401


@setup_api.errorhandler(SetupCommandError)
def setup_command_error(exc: SetupCommandError) -> tuple[Response, int]:
    return jsonify(error=str(exc), engineering_error=str(exc)), 403


@setup_api.errorhandler(SetupRepositoryError)
def setup_repository_error(exc: SetupRepositoryError) -> tuple[Response, int]:
    return jsonify(
        error="Setup Session is temporarily unavailable because its database source is not ready.",
        engineering_error=str(exc),
    ), 503


@setup_api.errorhandler(psycopg2.Error)
def setup_database_error(exc: psycopg2.Error) -> tuple[Response, int]:
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
    message = (exc.diag.message_primary or "Setup database command failed").strip()
    return jsonify(error=message, engineering_error=str(exc)), status
