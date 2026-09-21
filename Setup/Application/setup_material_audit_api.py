"""Manager-governed API for Issue #145 Material Completeness Audit."""
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
from setup_material_audit_repository import (
    SetupMaterialAuditRepository,
    SetupMaterialAuditRepositoryError,
)


setup_material_audit_api = Blueprint("setup_material_audit_api", __name__)


def repo() -> SetupMaterialAuditRepository:
    return SetupMaterialAuditRepository(setup_database_dsn())


@setup_material_audit_api.get("/api/setup/material-audit")
def api_setup_material_audit() -> Response:
    _base_repo, _email, _access = require_manager()
    return jsonify(audit=repo().audit())


@setup_material_audit_api.patch(
    "/api/setup/material-audit/kits/<int:container_id>/shared-non-task"
)
def api_set_setup_kit_shared_non_task(container_id: int) -> Response:
    require_setup_command()
    _base_repo, email, _access = require_manager()
    payload = json_body()

    reviewed = payload.get("reviewed_shared_non_task")
    if not isinstance(reviewed, bool):
        raise SetupCommandError("reviewed_shared_non_task must be true or false")

    note = payload.get("note")
    if note is not None and not isinstance(note, str):
        raise SetupCommandError("note must be text or null")

    result = repo().set_kit_disposition(
        email=email,
        container_id=container_id,
        reviewed_shared_non_task=reviewed,
        note=note,
    )
    return jsonify(disposition=result)


@setup_material_audit_api.errorhandler(SetupAuthenticationError)
def authentication_error(exc: SetupAuthenticationError) -> tuple[Response, int]:
    return jsonify(
        error="Setup Session sign-in identity is unavailable",
        engineering_error=str(exc),
    ), 401


@setup_material_audit_api.errorhandler(SetupCommandError)
def command_error(exc: SetupCommandError) -> tuple[Response, int]:
    return jsonify(error=str(exc), engineering_error=str(exc)), 403


@setup_material_audit_api.errorhandler(SetupMaterialAuditRepositoryError)
def repository_error(exc: SetupMaterialAuditRepositoryError) -> tuple[Response, int]:
    return jsonify(error=str(exc), engineering_error=str(exc)), 400


@setup_material_audit_api.errorhandler(psycopg2.Error)
def database_error(exc: psycopg2.Error) -> tuple[Response, int]:
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
    message = (exc.diag.message_primary or "Setup Material Completeness Audit command failed").strip()
    return jsonify(error=message, engineering_error=str(exc)), status
