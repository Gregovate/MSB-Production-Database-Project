"""Protected Setup Extra Material / Container inventory API."""
from __future__ import annotations

import psycopg2
from flask import Blueprint, Response, jsonify, request
from psycopg2.extras import RealDictCursor

from setup_api import (
    SetupAuthenticationError,
    SetupCommandError,
    json_body,
    require_manager,
    require_reader,
    require_setup_command,
    setup_database_dsn,
)
from setup_extra_material_repository import (
    SetupExtraMaterialRepository,
    SetupExtraMaterialRepositoryError,
)
from setup_repository import SetupRepositoryError
from setup_uom_repository import SetupUomRepository, SetupUomRepositoryError

setup_extra_material_api = Blueprint("setup_extra_material_api", __name__)


def repo() -> SetupExtraMaterialRepository:
    return SetupExtraMaterialRepository(setup_database_dsn())


def uom_repo() -> SetupUomRepository:
    return SetupUomRepository(setup_database_dsn())


def require_inventory_operator():
    """Allow durable stock adjustments only to Production Crew or Managers.

    The existing movement capability also includes Volunteers, so it is
    intentionally not reused for durable Extra Material inventory changes.
    The SECURITY DEFINER command independently rechecks the same boundary.
    """
    base_repo, email, access = require_reader()
    role_name = str(access.get("role_name") or "")
    policy_names = {str(name) for name in access.get("policy_names") or []}
    can_adjust = bool(access.get("can_manage_setup")) or role_name == "Production Crew" or "Production Crew" in policy_names
    if not can_adjust:
        raise SetupCommandError("Setup Extra Material inventory adjustment is not authorized for this account")
    return base_repo, email, access


@setup_extra_material_api.get("/api/setup/extra-materials")
def api_extra_materials() -> Response:
    require_reader()
    return jsonify(extra_materials=repo().catalog())


@setup_extra_material_api.get("/api/setup/extra-material-catalog")
def api_extra_material_catalog() -> Response:
    require_manager()
    return jsonify(extra_materials=repo().catalog(include_inactive=True))


@setup_extra_material_api.get("/api/setup/containers/source-options")
def api_setup_extra_material_source_containers() -> Response:
    """Return current Containers eligible to be an Extra Material source.

    Source allocation is intentionally not limited to Kit Boxes. Display
    Pallets, shared-stock Containers, Kit Boxes, and other real Containers may
    all be valid depending on the physical Setup workflow.
    """
    require_reader()
    with psycopg2.connect(setup_database_dsn()) as conn, conn.cursor(cursor_factory=RealDictCursor) as cur:
        cur.execute(
            """
            SELECT
                c.container_id,
                c.description AS container_description,
                c.container_type_id,
                ct.container_type_name,
                c.location_code AS home_location_code
            FROM ref.container AS c
            LEFT JOIN ref.container_type AS ct
              ON ct.container_type_id = c.container_type_id
            ORDER BY c.container_id
            """
        )
        rows = [dict(row) for row in cur.fetchall()]
    return jsonify(containers=rows)


@setup_extra_material_api.get("/api/setup/uoms")
def api_setup_uoms() -> Response:
    require_reader()
    return jsonify(uoms=uom_repo().catalog())


@setup_extra_material_api.get("/api/setup/uom-catalog")
def api_setup_uom_catalog() -> Response:
    require_manager()
    return jsonify(uoms=uom_repo().catalog(include_inactive=True))


@setup_extra_material_api.post("/api/setup/uoms")
def api_setup_uom_create() -> tuple[Response, int]:
    require_setup_command()
    _base_repo, email, _access = require_manager()
    result = uom_repo().create(email=email, payload=json_body())
    return jsonify(uom=result), 201


@setup_extra_material_api.patch("/api/setup/uoms/<path:uom_code>")
def api_setup_uom_update(uom_code: str) -> Response:
    require_setup_command()
    _base_repo, email, _access = require_manager()
    return jsonify(uom=uom_repo().update(
        email=email,
        uom_code=uom_code,
        payload=json_body(),
    ))


@setup_extra_material_api.get("/api/setup/tasks/<int:setup_task_id>/extra-materials")
def api_task_extra_materials(setup_task_id: int) -> Response:
    require_reader()
    return jsonify(extra_materials=repo().task_materials(setup_task_id))


@setup_extra_material_api.get("/api/setup/containers/<int:container_id>/extra-materials")
def api_container_extra_materials(container_id: int) -> Response:
    require_reader()
    return jsonify(**repo().container_contents(container_id))


@setup_extra_material_api.get("/api/setup/container-extra-materials/<int:content_id>/inventory-events")
def api_container_extra_material_inventory_history(content_id: int) -> Response:
    require_reader()
    return jsonify(events=repo().inventory_history(content_id))


@setup_extra_material_api.get("/api/setup/extra-materials/balance-summary")
def api_extra_material_balance_summary() -> Response:
    require_reader()
    name = request.args.get("material_name", "").strip() or None
    return jsonify(summary=repo().balance_summary(material_name=name))


@setup_extra_material_api.post("/api/setup/extra-materials")
def api_extra_material_create() -> tuple[Response, int]:
    require_setup_command()
    _base_repo, email, _access = require_manager()
    result = repo().create_material(email=email, payload=json_body())
    return jsonify(extra_material=result), 201


@setup_extra_material_api.patch("/api/setup/extra-materials/<int:material_id>")
def api_extra_material_update(material_id: int) -> Response:
    require_setup_command()
    _base_repo, email, _access = require_manager()
    return jsonify(extra_material=repo().update_material(
        email=email,
        material_id=material_id,
        payload=json_body(),
    ))


@setup_extra_material_api.post("/api/setup/tasks/<int:setup_task_id>/extra-materials")
def api_task_extra_material_create(setup_task_id: int) -> tuple[Response, int]:
    require_setup_command()
    _base_repo, email, _access = require_manager()
    result = repo().set_task_material(
        email=email,
        setup_task_id=setup_task_id,
        row_id=None,
        payload=json_body(),
    )
    return jsonify(setup_task_extra_material=result), 201


@setup_extra_material_api.patch(
    "/api/setup/tasks/<int:setup_task_id>/extra-materials/<int:row_id>"
)
def api_task_extra_material_update(setup_task_id: int, row_id: int) -> Response:
    require_setup_command()
    _base_repo, email, _access = require_manager()
    return jsonify(setup_task_extra_material=repo().set_task_material(
        email=email,
        setup_task_id=setup_task_id,
        row_id=row_id,
        payload=json_body(),
    ))


@setup_extra_material_api.post(
    "/api/setup/task-extra-materials/<int:requirement_id>/sources"
)
def api_task_extra_material_source_create(requirement_id: int) -> tuple[Response, int]:
    require_setup_command()
    _base_repo, email, _access = require_manager()
    result = repo().set_task_source(
        email=email,
        requirement_id=requirement_id,
        row_id=None,
        payload=json_body(),
    )
    return jsonify(setup_task_extra_material_source=result), 201


@setup_extra_material_api.patch(
    "/api/setup/task-extra-materials/<int:requirement_id>/sources/<int:row_id>"
)
def api_task_extra_material_source_update(requirement_id: int, row_id: int) -> Response:
    require_setup_command()
    _base_repo, email, _access = require_manager()
    return jsonify(setup_task_extra_material_source=repo().set_task_source(
        email=email,
        requirement_id=requirement_id,
        row_id=row_id,
        payload=json_body(),
    ))


@setup_extra_material_api.post("/api/setup/containers/<int:container_id>/extra-materials")
def api_container_extra_material_create(container_id: int) -> tuple[Response, int]:
    require_setup_command()
    _base_repo, email, _access = require_manager()
    result = repo().set_container_content(
        email=email,
        container_id=container_id,
        row_id=None,
        payload=json_body(),
    )
    return jsonify(setup_container_extra_material=result), 201


@setup_extra_material_api.patch(
    "/api/setup/containers/<int:container_id>/extra-materials/<int:row_id>"
)
def api_container_extra_material_update(container_id: int, row_id: int) -> Response:
    require_setup_command()
    _base_repo, email, _access = require_manager()
    return jsonify(setup_container_extra_material=repo().set_container_content(
        email=email,
        container_id=container_id,
        row_id=row_id,
        payload=json_body(),
    ))


@setup_extra_material_api.patch("/api/setup/containers/<int:container_id>/unverified-items")
def api_container_unverified_items(container_id: int) -> Response:
    require_setup_command()
    _base_repo, email, _access = require_manager()
    payload = json_body()
    return jsonify(container_review=repo().set_unverified_items(
        email=email,
        container_id=container_id,
        text=payload.get("unverified_items_text"),
    ))


@setup_extra_material_api.post(
    "/api/setup/container-extra-materials/<int:content_id>/inventory-events"
)
def api_container_extra_material_inventory_event(content_id: int) -> tuple[Response, int]:
    require_setup_command()
    _base_repo, email, _access = require_inventory_operator()
    result = repo().record_inventory_event(
        email=email,
        content_id=content_id,
        payload=json_body(),
    )
    return jsonify(inventory_event=result), 201


@setup_extra_material_api.errorhandler(SetupAuthenticationError)
def auth_error(exc: SetupAuthenticationError) -> tuple[Response, int]:
    return jsonify(error="Setup Session sign-in identity is unavailable", engineering_error=str(exc)), 401


@setup_extra_material_api.errorhandler(SetupCommandError)
def command_error(exc: SetupCommandError) -> tuple[Response, int]:
    return jsonify(error=str(exc), engineering_error=str(exc)), 403


@setup_extra_material_api.errorhandler(SetupRepositoryError)
@setup_extra_material_api.errorhandler(SetupExtraMaterialRepositoryError)
@setup_extra_material_api.errorhandler(SetupUomRepositoryError)
def repository_error(exc: SetupRepositoryError | SetupExtraMaterialRepositoryError | SetupUomRepositoryError) -> tuple[Response, int]:
    return jsonify(error="Setup Extra Materials are temporarily unavailable.", engineering_error=str(exc)), 503


@setup_extra_material_api.errorhandler(psycopg2.Error)
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
    message = (exc.diag.message_primary or "Setup Extra Material database command failed").strip()
    return jsonify(error=message, engineering_error=str(exc)), status
