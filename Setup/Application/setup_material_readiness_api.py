"""Protected API for Setup #206 material readiness and Manager pick overrides."""
from __future__ import annotations

import psycopg2
from flask import Blueprint, Response, jsonify, request

from setup_api import (
    SetupAuthenticationError,
    SetupCommandError,
    json_body,
    require_manager,
    require_reader,
    require_setup_command,
    setup_database_dsn,
)
from setup_material_readiness_repository import (
    SetupMaterialReadinessRepository,
    SetupMaterialReadinessRepositoryError,
)

setup_material_readiness_api = Blueprint("setup_material_readiness_api", __name__)


def repo() -> SetupMaterialReadinessRepository:
    return SetupMaterialReadinessRepository(setup_database_dsn())


def required_year() -> int:
    raw = request.args.get("season_year", "").strip()
    if not raw.isdigit():
        raise SetupCommandError("season_year is required")
    return int(raw)


def required_int(value: object, name: str) -> int:
    if isinstance(value, bool):
        raise SetupCommandError(f"{name} must be an integer")
    try:
        parsed = int(value)
    except (TypeError, ValueError) as exc:
        raise SetupCommandError(f"{name} is required") from exc
    if parsed <= 0:
        raise SetupCommandError(f"{name} must be greater than zero")
    return parsed


def optional_text(value: object) -> str | None:
    text = str(value or "").strip()
    return text or None


@setup_material_readiness_api.get("/api/setup/material-readiness")
def api_setup_material_readiness() -> Response:
    require_reader()
    return jsonify(readiness=repo().material_readiness(required_year()))


@setup_material_readiness_api.post("/api/setup/material-readiness/overrides")
def api_setup_material_readiness_override_set() -> tuple[Response, int]:
    require_setup_command()
    _base_repo, email, _access = require_manager()
    payload = json_body()
    result = repo().set_pick_list_override(
        email=email,
        season_year=required_int(payload.get("season_year"), "season_year"),
        container_id=required_int(payload.get("container_id"), "container_id"),
        pick_by_date=optional_text(payload.get("pick_by_date")),
        needed_for_date=optional_text(payload.get("needed_for_date")),
        destination_note=optional_text(payload.get("destination_note")),
        reason=optional_text(payload.get("override_reason")),
        active=True,
    )
    return jsonify(pick_list_override=result), 201


@setup_material_readiness_api.delete(
    "/api/setup/material-readiness/overrides/<int:container_id>"
)
def api_setup_material_readiness_override_remove(container_id: int) -> Response:
    require_setup_command()
    _base_repo, email, _access = require_manager()
    payload = json_body()
    result = repo().set_pick_list_override(
        email=email,
        season_year=required_int(payload.get("season_year"), "season_year"),
        container_id=container_id,
        pick_by_date=None,
        needed_for_date=None,
        destination_note=None,
        reason=None,
        active=False,
    )
    return jsonify(pick_list_override=result)


@setup_material_readiness_api.errorhandler(SetupAuthenticationError)
def material_readiness_authentication_error(
    exc: SetupAuthenticationError,
) -> tuple[Response, int]:
    return jsonify(
        error="Setup Session sign-in identity is unavailable",
        engineering_error=str(exc),
    ), 401


@setup_material_readiness_api.errorhandler(SetupCommandError)
def material_readiness_command_error(
    exc: SetupCommandError,
) -> tuple[Response, int]:
    return jsonify(error=str(exc), engineering_error=str(exc)), 403


@setup_material_readiness_api.errorhandler(SetupMaterialReadinessRepositoryError)
def material_readiness_repository_error(
    exc: SetupMaterialReadinessRepositoryError,
) -> tuple[Response, int]:
    return jsonify(
        error="Setup material readiness is temporarily unavailable.",
        engineering_error=str(exc),
    ), 503


@setup_material_readiness_api.errorhandler(psycopg2.Error)
def material_readiness_database_error(exc: psycopg2.Error) -> tuple[Response, int]:
    sqlstate = exc.pgcode or ""
    if sqlstate == "42501":
        status = 403
    elif sqlstate in {"22023", "23503", "23514"}:
        status = 400
    elif sqlstate == "P0002":
        status = 404
    else:
        status = 500
    message = (
        exc.diag.message_primary
        or "Setup material readiness database command failed"
    ).strip()
    return jsonify(error=message, engineering_error=str(exc)), status
