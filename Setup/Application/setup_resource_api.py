"""Protected Setup equipment/resource API."""
from __future__ import annotations

import psycopg2
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
from setup_resource_repository import SetupResourceRepository, SetupResourceRepositoryError

setup_resource_api = Blueprint("setup_resource_api", __name__)


def resource_repository() -> SetupResourceRepository:
    return SetupResourceRepository(setup_database_dsn())


@setup_resource_api.get("/api/setup/resources")
def api_setup_resources() -> Response:
    authenticated_email()
    require_reader()
    return jsonify(resources=resource_repository().catalog())


@setup_resource_api.get("/api/setup/resource-catalog")
def api_setup_resource_catalog() -> Response:
    _repo, _email, _access = require_manager()
    return jsonify(resources=resource_repository().catalog(include_inactive=True))


@setup_resource_api.get("/api/setup/tasks/<int:setup_task_id>/resources")
def api_setup_task_resources(setup_task_id: int) -> Response:
    authenticated_email()
    require_reader()
    return jsonify(resources=resource_repository().task_resources(setup_task_id))


@setup_resource_api.post("/api/setup/resources")
def api_setup_resource_create() -> tuple[Response, int]:
    require_setup_command()
    _repo, email, _access = require_manager()
    result = resource_repository().create_resource(email=email, payload=json_body())
    return jsonify(setup_resource=result), 201


@setup_resource_api.patch("/api/setup/resources/<int:setup_resource_id>")
def api_setup_resource_update(setup_resource_id: int) -> Response:
    require_setup_command()
    _repo, email, _access = require_manager()
    result = resource_repository().update_resource(
        email=email,
        setup_resource_id=setup_resource_id,
        payload=json_body(),
    )
    return jsonify(setup_resource=result)


@setup_resource_api.patch(
    "/api/setup/tasks/<int:setup_task_id>/resources/<int:setup_resource_id>"
)
def api_setup_task_resource_update(
    setup_task_id: int,
    setup_resource_id: int,
) -> Response:
    require_setup_command()
    _repo, email, _access = require_manager()
    result = resource_repository().set_task_resource(
        email=email,
        setup_task_id=setup_task_id,
        setup_resource_id=setup_resource_id,
        payload=json_body(),
    )
    return jsonify(setup_task_resource=result)


@setup_resource_api.errorhandler(SetupAuthenticationError)
def setup_resource_authentication_error(
    exc: SetupAuthenticationError,
) -> tuple[Response, int]:
    return jsonify(
        error="Setup Session sign-in identity is unavailable",
        engineering_error=str(exc),
    ), 401


@setup_resource_api.errorhandler(SetupCommandError)
def setup_resource_command_error(exc: SetupCommandError) -> tuple[Response, int]:
    return jsonify(error=str(exc), engineering_error=str(exc)), 403


@setup_resource_api.errorhandler(SetupRepositoryError)
@setup_resource_api.errorhandler(SetupResourceRepositoryError)
def setup_resource_repository_error(
    exc: SetupRepositoryError | SetupResourceRepositoryError,
) -> tuple[Response, int]:
    return jsonify(
        error="Setup equipment/resources are temporarily unavailable.",
        engineering_error=str(exc),
    ), 503


@setup_resource_api.errorhandler(psycopg2.Error)
def setup_resource_database_error(exc: psycopg2.Error) -> tuple[Response, int]:
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
    message = (exc.diag.message_primary or "Setup resource database command failed").strip()
    return jsonify(error=message, engineering_error=str(exc)), status
