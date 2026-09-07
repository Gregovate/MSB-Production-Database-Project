"""Protected API for Setup V0.2 organization, scheduling, and Captain execution."""
from __future__ import annotations

from typing import Any

import psycopg2
from flask import Blueprint, Response, jsonify, request

from setup_api import (
    json_body,
    require_manager,
    require_reader,
    require_setup_command,
    setup_database_dsn,
    SetupAuthenticationError,
    SetupCommandError,
)
from setup_next_repository import SetupNextRepository, SetupNextRepositoryError

setup_next_api = Blueprint("setup_next_api", __name__)


def repo() -> SetupNextRepository:
    return SetupNextRepository(setup_database_dsn())


def required_year() -> int:
    raw = request.args.get("season_year", "").strip()
    if not raw.isdigit():
        raise SetupCommandError("season_year is required")
    return int(raw)


def nullable_int(value: Any, name: str) -> int | None:
    if value is None or value == "":
        return None
    if isinstance(value, bool):
        raise SetupCommandError(f"{name} must be an integer")
    try:
        return int(value)
    except (TypeError, ValueError) as exc:
        raise SetupCommandError(f"{name} must be an integer") from exc


@setup_next_api.get("/api/setup/organization")
def api_setup_organization() -> Response:
    require_reader()
    return jsonify(organization=repo().organization())


@setup_next_api.patch("/api/setup/tasks/<int:setup_task_id>/scope")
def api_setup_task_scope(setup_task_id: int) -> Response:
    require_setup_command()
    _base_repo, email, _access = require_manager()
    payload = json_body()
    result = repo().set_scope(
        email=email,
        task_id=setup_task_id,
        stage_id=nullable_int(payload.get("stage_id"), "stage_id"),
        scene_id=nullable_int(payload.get("lor_scene_id"), "lor_scene_id"),
    )
    return jsonify(scope=result)


@setup_next_api.patch("/api/setup/tasks/<int:setup_task_id>/dependencies/<int:prerequisite_setup_task_id>")
def api_setup_dependency(setup_task_id: int, prerequisite_setup_task_id: int) -> Response:
    require_setup_command()
    _base_repo, email, _access = require_manager()
    payload = json_body()
    result = repo().set_dependency(
        email=email,
        task_id=setup_task_id,
        prerequisite_id=prerequisite_setup_task_id,
        note=(str(payload.get("dependency_note") or "").strip() or None),
        active=bool(payload.get("active", True)),
    )
    return jsonify(dependency=result)


@setup_next_api.get("/api/setup/schedule")
def api_setup_schedule() -> Response:
    require_reader()
    return jsonify(schedule=repo().schedule(required_year()))


@setup_next_api.post("/api/setup/work-days")
def api_setup_work_day() -> tuple[Response, int]:
    require_setup_command()
    _base_repo, email, _access = require_manager()
    payload = json_body()
    year = payload.get("season_year")
    if not isinstance(year, int):
        raise SetupCommandError("season_year must be an integer")
    work_date = str(payload.get("work_date") or "").strip()
    if not work_date:
        raise SetupCommandError("work_date is required")
    result = repo().upsert_work_day(
        email=email,
        season_year=year,
        work_date=work_date,
        status=str(payload.get("day_status") or "PLANNED"),
        notes=(str(payload.get("notes") or "").strip() or None),
    )
    return jsonify(work_day=result), 201


@setup_next_api.patch("/api/setup/work-days/<int:setup_work_day_id>/tasks/<int:setup_session_task_id>")
def api_setup_work_day_task(setup_work_day_id: int, setup_session_task_id: int) -> Response:
    require_setup_command()
    _base_repo, email, _access = require_manager()
    payload = json_body()
    result = repo().set_work_day_task(
        email=email,
        work_day_id=setup_work_day_id,
        session_task_id=setup_session_task_id,
        shift=str(payload.get("shift_code") or "ALL_DAY"),
        sort_order=nullable_int(payload.get("sort_order"), "sort_order") or 100,
        planned_crew=nullable_int(payload.get("planned_crew_count"), "planned_crew_count"),
        active=bool(payload.get("active", True)),
    )
    return jsonify(work_day_task=result)


@setup_next_api.get("/api/setup/execution")
def api_setup_execution() -> Response:
    require_reader()
    return jsonify(tasks=repo().execution_tasks(required_year()))


@setup_next_api.get("/api/setup/session-tasks/<int:setup_session_task_id>/progress")
def api_setup_progress_history(setup_session_task_id: int) -> Response:
    require_reader()
    return jsonify(progress=repo().progress(setup_session_task_id))


@setup_next_api.get("/api/setup/tasks/<int:setup_task_id>/field-context")
def api_setup_field_context(setup_task_id: int) -> Response:
    require_reader()
    return jsonify(context=repo().field_context(
        task_id=setup_task_id,
        season_year=required_year(),
    ))


@setup_next_api.post("/api/setup/session-tasks/<int:setup_session_task_id>/progress")
def api_setup_record_progress(setup_session_task_id: int) -> tuple[Response, int]:
    require_setup_command()
    _base_repo, email, _access = require_reader()
    payload = json_body()
    crew = nullable_int(payload.get("crew_count"), "crew_count")
    if crew is None:
        raise SetupCommandError("crew_count is required")
    result = repo().record_progress(
        email=email,
        session_task_id=setup_session_task_id,
        work_day_id=nullable_int(payload.get("setup_work_day_id"), "setup_work_day_id"),
        shift=str(payload.get("shift_code") or "ALL_DAY"),
        crew_count=crew,
        quantity=nullable_int(payload.get("completed_quantity"), "completed_quantity"),
        units=(str(payload.get("completed_units") or "").strip() or None),
        note=(str(payload.get("progress_note") or "").strip() or None),
        mark_complete=bool(payload.get("mark_complete", False)),
    )
    return jsonify(progress=result), 201


@setup_next_api.errorhandler(SetupAuthenticationError)
def setup_next_authentication_error(exc: SetupAuthenticationError) -> tuple[Response, int]:
    return jsonify(
        error="Setup Session sign-in identity is unavailable",
        engineering_error=str(exc),
    ), 401


@setup_next_api.errorhandler(SetupCommandError)
def setup_next_command_error(exc: SetupCommandError) -> tuple[Response, int]:
    return jsonify(error=str(exc), engineering_error=str(exc)), 403


@setup_next_api.errorhandler(SetupNextRepositoryError)
def setup_next_repository_error(exc: SetupNextRepositoryError) -> tuple[Response, int]:
    return jsonify(
        error="Setup Session next-pass data is temporarily unavailable.",
        engineering_error=str(exc),
    ), 503


@setup_next_api.errorhandler(psycopg2.Error)
def setup_next_database_error(exc: psycopg2.Error) -> tuple[Response, int]:
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
