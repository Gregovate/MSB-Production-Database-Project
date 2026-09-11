"""Protected ordered reusable Setup prerequisite API for Issue #151."""
from __future__ import annotations

from flask import Blueprint, Response, jsonify

from setup_api import (
    SetupCommandError,
    json_body,
    require_manager,
    require_reader,
    require_setup_command,
    setup_database_dsn,
)
from setup_prerequisite_order_repository import SetupPrerequisiteOrderRepository

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
