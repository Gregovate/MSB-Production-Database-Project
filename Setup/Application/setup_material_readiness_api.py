"""Protected read-only API for Setup #206 material readiness."""
from __future__ import annotations

import psycopg2
from flask import Blueprint, Response, jsonify, request

from setup_api import SetupAuthenticationError, SetupCommandError, require_reader, setup_database_dsn
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


@setup_material_readiness_api.get("/api/setup/material-readiness")
def api_setup_material_readiness() -> Response:
    require_reader()
    return jsonify(readiness=repo().material_readiness(required_year()))


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
    message = (
        exc.diag.message_primary
        or "Setup material readiness database read failed"
    ).strip()
    return jsonify(error=message, engineering_error=str(exc)), 500
