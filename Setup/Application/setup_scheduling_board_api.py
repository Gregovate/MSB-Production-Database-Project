"""Protected API for Setup #205 rolling Scheduling Board."""
from __future__ import annotations

from typing import Any

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
from setup_scheduling_board_repository import (
    SetupSchedulingBoardRepository,
    SetupSchedulingBoardRepositoryError,
)

setup_scheduling_board_api = Blueprint("setup_scheduling_board_api", __name__)


def repo() -> SetupSchedulingBoardRepository:
    return SetupSchedulingBoardRepository(setup_database_dsn())


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


def required_int(value: Any, name: str) -> int:
    parsed = nullable_int(value, name)
    if parsed is None:
        raise SetupCommandError(f"{name} is required")
    return parsed


def optional_text(value: Any) -> str | None:
    text = str(value or "").strip()
    return text or None


@setup_scheduling_board_api.get("/api/setup/scheduling-board")
def api_setup_scheduling_board() -> Response:
    require_reader()
    return jsonify(board=repo().board(required_year()))


@setup_scheduling_board_api.post("/api/setup/scheduling-board/work-days")
def api_setup_scheduling_board_work_day() -> tuple[Response, int]:
    require_setup_command()
    _base_repo, email, _access = require_manager()
    payload = json_body()

    season_year = required_int(payload.get("season_year"), "season_year")
    work_date = str(payload.get("work_date") or "").strip()
    if not work_date:
        raise SetupCommandError("work_date is required")

    result = repo().upsert_work_day(
        email=email,
        season_year=season_year,
        work_date=work_date,
        setup_day_number=nullable_int(payload.get("setup_day_number"), "setup_day_number"),
        status=str(payload.get("day_status") or "PLANNED"),
        weather_note=optional_text(payload.get("weather_note")),
        volunteer_note=optional_text(payload.get("volunteer_note")),
        notes=optional_text(payload.get("notes")),
    )
    return jsonify(work_day=result), 201


@setup_scheduling_board_api.post("/api/setup/scheduling-board/assignments")
def api_setup_scheduling_board_assignment_create() -> tuple[Response, int]:
    require_setup_command()
    _base_repo, email, _access = require_manager()
    payload = json_body()

    result = repo().create_assignment(
        email=email,
        work_day_id=required_int(payload.get("setup_work_day_id"), "setup_work_day_id"),
        session_task_id=required_int(payload.get("setup_session_task_id"), "setup_session_task_id"),
        shift=str(payload.get("shift_code") or "ALL_DAY"),
        crew_lane=str(payload.get("crew_lane") or "A"),
        sort_order=nullable_int(payload.get("sort_order"), "sort_order") or 100,
        planned_crew_count=nullable_int(payload.get("planned_crew_count"), "planned_crew_count"),
    )
    return jsonify(assignment=result), 201


@setup_scheduling_board_api.patch(
    "/api/setup/scheduling-board/assignments/<int:setup_work_day_task_id>"
)
def api_setup_scheduling_board_assignment_update(
    setup_work_day_task_id: int,
) -> Response:
    require_setup_command()
    _base_repo, email, _access = require_manager()
    payload = json_body()

    result = repo().update_assignment(
        email=email,
        assignment_id=setup_work_day_task_id,
        work_day_id=required_int(payload.get("setup_work_day_id"), "setup_work_day_id"),
        shift=str(payload.get("shift_code") or "ALL_DAY"),
        crew_lane=str(payload.get("crew_lane") or "A"),
        sort_order=nullable_int(payload.get("sort_order"), "sort_order") or 100,
        planned_crew_count=nullable_int(payload.get("planned_crew_count"), "planned_crew_count"),
    )
    return jsonify(assignment=result)


@setup_scheduling_board_api.delete(
    "/api/setup/scheduling-board/assignments/<int:setup_work_day_task_id>"
)
def api_setup_scheduling_board_assignment_remove(
    setup_work_day_task_id: int,
) -> Response:
    require_setup_command()
    _base_repo, email, _access = require_manager()
    result = repo().remove_assignment(
        email=email,
        assignment_id=setup_work_day_task_id,
    )
    return jsonify(assignment=result)


@setup_scheduling_board_api.post("/api/setup/scheduling-board/season-tasks")
def api_setup_scheduling_board_season_task_create() -> tuple[Response, int]:
    require_setup_command()
    _base_repo, email, _access = require_manager()
    payload = json_body()

    result = repo().create_season_task(
        email=email,
        season_year=required_int(payload.get("season_year"), "season_year"),
        task_name=str(payload.get("task_name") or "").strip(),
        stage_id=nullable_int(payload.get("stage_id"), "stage_id"),
        scene_id=nullable_int(payload.get("lor_scene_id"), "lor_scene_id"),
        action_type=str(payload.get("task_action_type") or "WORK"),
        planned_order=nullable_int(payload.get("planned_order"), "planned_order"),
        crew_min=nullable_int(payload.get("normal_crew_min"), "normal_crew_min"),
        crew_max=nullable_int(payload.get("normal_crew_max"), "normal_crew_max"),
        expected_duration_minutes=nullable_int(
            payload.get("expected_duration_minutes"),
            "expected_duration_minutes",
        ),
        completion_point=optional_text(payload.get("completion_point")),
        readiness_note=optional_text(payload.get("readiness_note")),
        weather_note=optional_text(payload.get("weather_note")),
        linked_work_order_id=nullable_int(payload.get("linked_work_order_id"), "linked_work_order_id"),
        linked_work_order_gate=bool(payload.get("linked_work_order_gate", False)),
        annual_notes=optional_text(payload.get("annual_notes")),
    )
    return jsonify(season_task=result), 201


@setup_scheduling_board_api.patch(
    "/api/setup/scheduling-board/season-tasks/<int:setup_session_task_id>"
)
def api_setup_scheduling_board_season_task_update(
    setup_session_task_id: int,
) -> Response:
    require_setup_command()
    _base_repo, email, _access = require_manager()
    payload = json_body()

    result = repo().update_annual_task(
        email=email,
        session_task_id=setup_session_task_id,
        task_name=str(payload.get("task_name") or "").strip(),
        stage_id=nullable_int(payload.get("stage_id"), "stage_id"),
        scene_id=nullable_int(payload.get("lor_scene_id"), "lor_scene_id"),
        action_type=str(payload.get("task_action_type") or "WORK"),
        crew_min=nullable_int(payload.get("normal_crew_min"), "normal_crew_min"),
        crew_max=nullable_int(payload.get("normal_crew_max"), "normal_crew_max"),
        expected_duration_minutes=nullable_int(
            payload.get("expected_duration_minutes"),
            "expected_duration_minutes",
        ),
        completion_point=optional_text(payload.get("completion_point")),
        readiness_note=optional_text(payload.get("readiness_note")),
        weather_note=optional_text(payload.get("weather_note")),
        linked_work_order_id=nullable_int(payload.get("linked_work_order_id"), "linked_work_order_id"),
        linked_work_order_gate=bool(payload.get("linked_work_order_gate", False)),
        annual_notes=optional_text(payload.get("annual_notes")),
    )
    return jsonify(season_task=result)


@setup_scheduling_board_api.patch(
    "/api/setup/scheduling-board/season-tasks/<int:setup_session_task_id>/dependencies/"
    "<int:prerequisite_setup_session_task_id>"
)
def api_setup_scheduling_board_dependency(
    setup_session_task_id: int,
    prerequisite_setup_session_task_id: int,
) -> Response:
    require_setup_command()
    _base_repo, email, _access = require_manager()
    payload = json_body()

    result = repo().set_dependency(
        email=email,
        session_task_id=setup_session_task_id,
        prerequisite_session_task_id=prerequisite_setup_session_task_id,
        note=optional_text(payload.get("dependency_note")),
        active=bool(payload.get("active", True)),
    )
    return jsonify(dependency=result)


@setup_scheduling_board_api.errorhandler(SetupAuthenticationError)
def scheduling_board_authentication_error(
    exc: SetupAuthenticationError,
) -> tuple[Response, int]:
    return jsonify(
        error="Setup Session sign-in identity is unavailable",
        engineering_error=str(exc),
    ), 401


@setup_scheduling_board_api.errorhandler(SetupCommandError)
def scheduling_board_command_error(
    exc: SetupCommandError,
) -> tuple[Response, int]:
    return jsonify(error=str(exc), engineering_error=str(exc)), 403


@setup_scheduling_board_api.errorhandler(SetupSchedulingBoardRepositoryError)
def scheduling_board_repository_error(
    exc: SetupSchedulingBoardRepositoryError,
) -> tuple[Response, int]:
    return jsonify(
        error="Setup Scheduling Board is temporarily unavailable.",
        engineering_error=str(exc),
    ), 503


@setup_scheduling_board_api.errorhandler(psycopg2.Error)
def scheduling_board_database_error(exc: psycopg2.Error) -> tuple[Response, int]:
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
    message = (
        exc.diag.message_primary
        or "Setup Scheduling Board database command failed"
    ).strip()
    return jsonify(error=message, engineering_error=str(exc)), status
