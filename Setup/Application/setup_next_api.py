"""Protected API for Setup V0.3 organization, planning, scheduling, and Captain execution."""
from __future__ import annotations

from pathlib import Path
from typing import Any

import psycopg2
from flask import Blueprint, Response, jsonify, request, send_file

from backend import drive_root, repository as field_context_repository
from FieldWiring.Application.field_context_resolver import MARKER_NAME
from Procedures.Application.procedure_context import resolve_stage_procedure
from setup_api import (
    json_body,
    require_manager,
    require_reader,
    require_setup_command,
    setup_database_dsn,
    SetupAuthenticationError,
    SetupCommandError,
)
from setup_google_docs import preferred_editable_sources, runtime_google_sources
from setup_next_repository import SetupNextRepository, SetupNextRepositoryError

setup_next_api = Blueprint("setup_next_api", __name__)
PARK_INFRASTRUCTURE_FOLDER = "41 Park Infrastructure-PI"


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


def _direct_pdfs(folder: Path) -> list[dict[str, Any]]:
    if not folder.is_dir():
        return []
    try:
        files = [p for p in folder.iterdir() if p.is_file() and p.suffix.casefold() == ".pdf"]
    except OSError:
        return []
    return [
        {"name": p.name, "path": str(p), "size": p.stat().st_size}
        for p in sorted(files, key=lambda item: item.name.casefold())
    ]


def _manager_sources(instructions: dict[str, Any], access: dict[str, Any]) -> dict[str, Any]:
    if not access.get("can_manage_setup"):
        instructions["editable_sources"] = []
        instructions.pop("manager_rule", None)
        return instructions

    task_root = str(instructions.get("task_root") or "").strip()
    runtime_sources: list[dict[str, Any]] = []
    runtime_warnings: list[str] = []
    if task_root:
        runtime_sources, runtime_warnings = runtime_google_sources(
            task_root=task_root,
            drive_root=str(drive_root()),
        )
    instructions["editable_sources"] = preferred_editable_sources(
        list(instructions.get("editable_sources") or []),
        runtime_sources,
    )
    if runtime_warnings:
        instructions["warnings"] = [
            *(instructions.get("warnings") or []),
            *runtime_warnings,
        ]
    return instructions


def _park_infrastructure_instructions(access: dict[str, Any]) -> dict[str, Any]:
    root = Path(drive_root()) / PARK_INFRASTRUCTURE_FOLDER
    procedures_root = root / "Procedures"
    task_root = procedures_root / "Setup"
    warnings: list[str] = []

    result: dict[str, Any] = {
        "status": "UNRESOLVED_SCOPE",
        "task": "Setup",
        "scope_type": "SITE_WIDE",
        "scope_root": str(root),
        "procedures_root": str(procedures_root),
        "task_root": str(task_root),
        "current_documents": [],
        "documents": [],
        "images": [],
        "editable_sources": [],
        "warnings": warnings,
    }

    if not root.is_dir():
        warnings.append(f"Park Infrastructure Procedure root is missing: {root}")
        return _manager_sources(result, access)
    if not (root / MARKER_NAME).is_file():
        result["status"] = "UNAPPROVED_SCOPE"
        warnings.append(f"Park Infrastructure root marker is missing: {root / MARKER_NAME}")
        return _manager_sources(result, access)
    if not procedures_root.is_dir():
        result["status"] = "PROCEDURES_UNAVAILABLE"
        warnings.append(f"Procedure subsystem folder is missing: {procedures_root}")
        return _manager_sources(result, access)
    if not (procedures_root / MARKER_NAME).is_file():
        result["status"] = "PROCEDURES_UNAVAILABLE"
        warnings.append(f"Procedure subsystem marker is missing: {procedures_root / MARKER_NAME}")
        return _manager_sources(result, access)
    if not task_root.is_dir():
        result["status"] = "TASK_UNAVAILABLE"
        warnings.append(f"Procedure task folder is missing: {task_root}")
        return _manager_sources(result, access)

    documents = _direct_pdfs(task_root)
    result["current_documents"] = documents
    result["documents"] = documents
    result["status"] = "AVAILABLE" if documents else "NO_CURRENT_DOCUMENTS"
    if not documents:
        warnings.append(f"No current published Setup PDF is present in {task_root}")
    return _manager_sources(result, access)


def _stage_scene_instructions(task: dict[str, Any], access: dict[str, Any]) -> dict[str, Any]:
    stage_id = task.get("stage_id")
    if stage_id is None:
        raise SetupCommandError("Stage/Scene Procedure resolution requires a Stage")

    scene_uuid = str(task.get("scene_uuid") or "").strip() or None
    preview_uuid = str(task.get("preview_uuid") or "").strip() or None
    scene_scoped = task.get("lor_scene_id") is not None
    procedure = resolve_stage_procedure(
        field_context_repository(),
        stage_id=int(stage_id),
        task="Setup",
        drive_root=drive_root(),
        whole_stage=not scene_scoped,
        preview_uuid=preview_uuid if scene_scoped else None,
        scene_uuid=scene_uuid if scene_scoped else None,
    )
    documents = [
        {
            "name": item.get("name"),
            "path": item.get("path"),
            "size": item.get("size"),
        }
        for item in (procedure.get("documents") or [])
        if item.get("name")
    ]
    instructions: dict[str, Any] = {
        "status": procedure.get("status"),
        "task": "Setup",
        "scope_type": procedure.get("scope_type"),
        "scope_root": procedure.get("scope_root"),
        "procedures_root": procedure.get("procedures_root"),
        "task_root": procedure.get("task_root"),
        "current_documents": documents,
        "documents": documents,
        "images": procedure.get("images") or [],
        "editable_sources": [],
        "warnings": procedure.get("operator_warnings") or procedure.get("warnings") or [],
        "selected_context": procedure.get("selected_context"),
    }
    return _manager_sources(instructions, access)


def _task_instructions(setup_task_id: int, access: dict[str, Any]) -> tuple[dict[str, Any], dict[str, Any]]:
    task = repo().task_scope(setup_task_id)
    if task.get("stage_id") is not None:
        instructions = _stage_scene_instructions(task, access)
        instructions["setup_task_id"] = setup_task_id
        return task, instructions

    instructions = _park_infrastructure_instructions(access)
    instructions["setup_task_id"] = setup_task_id
    return task, instructions


def _safe_pdf_name(name: str) -> str:
    safe_name = Path(name or "").name
    if not safe_name or safe_name != name or not safe_name.casefold().endswith(".pdf"):
        raise SetupCommandError("A current Setup PDF name is required")
    return safe_name


def _park_current_document(name: str) -> Path:
    safe_name = _safe_pdf_name(name)
    folder = Path(drive_root()) / PARK_INFRASTRUCTURE_FOLDER / "Procedures" / "Setup"
    path = folder / safe_name
    if not path.is_file() or path.parent != folder:
        raise SetupCommandError("Current Park Infrastructure PDF was not found")
    return path


def _stage_scene_current_document(task: dict[str, Any], name: str) -> Path:
    safe_name = _safe_pdf_name(name)
    stage_id = task.get("stage_id")
    if stage_id is None:
        raise SetupCommandError("Stage/Scene Procedure resolution requires a Stage")
    scene_scoped = task.get("lor_scene_id") is not None
    procedure = resolve_stage_procedure(
        field_context_repository(),
        stage_id=int(stage_id),
        task="Setup",
        drive_root=drive_root(),
        whole_stage=not scene_scoped,
        preview_uuid=(str(task.get("preview_uuid") or "").strip() or None) if scene_scoped else None,
        scene_uuid=(str(task.get("scene_uuid") or "").strip() or None) if scene_scoped else None,
    )
    task_root_text = str(procedure.get("task_root") or "").strip()
    if not task_root_text:
        raise SetupCommandError("Current Setup Procedure folder could not be resolved")
    task_root = Path(task_root_text)
    matched = next(
        (item for item in (procedure.get("documents") or []) if item.get("name") == safe_name),
        None,
    )
    if matched is None:
        raise SetupCommandError("Requested PDF is not a current published Setup document")
    candidate = Path(str(matched.get("path") or ""))
    if not candidate.is_file():
        raise SetupCommandError("Requested current Setup PDF is unavailable")
    try:
        resolved_root = task_root.resolve(strict=True)
        resolved_candidate = candidate.resolve(strict=True)
        resolved_candidate.relative_to(resolved_root)
    except (OSError, ValueError) as exc:
        raise SetupCommandError("Requested PDF is outside the resolved Setup folder") from exc
    if resolved_candidate.parent != resolved_root:
        raise SetupCommandError("Requested PDF is not directly published in Procedures/Setup")
    return candidate


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


@setup_next_api.patch("/api/setup/session-tasks/<int:setup_session_task_id>/planned-order")
def api_setup_planned_order(setup_session_task_id: int) -> Response:
    require_setup_command()
    _base_repo, email, _access = require_manager()
    payload = json_body()
    order = nullable_int(payload.get("planned_order"), "planned_order")
    if order is None:
        raise SetupCommandError("planned_order is required")
    result = repo().set_planned_order(
        email=email,
        session_task_id=setup_session_task_id,
        planned_order=order,
        reason=(str(payload.get("plan_change_reason") or "").strip() or None),
    )
    return jsonify(planning=result)


@setup_next_api.post("/api/setup/planning/promote-baseline")
def api_setup_promote_baseline() -> Response:
    require_setup_command()
    _base_repo, email, _access = require_manager()
    payload = json_body()
    year = payload.get("season_year")
    if not isinstance(year, int):
        raise SetupCommandError("season_year must be an integer")
    return jsonify(baseline=repo().promote_plan_baseline(email=email, season_year=year))


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
        crew_lane=(str(payload.get("crew_lane") or "A").strip() or "A"),
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


@setup_next_api.get("/api/setup/tasks/<int:setup_task_id>/procedure")
def api_setup_task_procedure(setup_task_id: int) -> Response:
    _base_repo, _email, access = require_reader()
    _task, instructions = _task_instructions(setup_task_id, access)
    return jsonify(instructions=instructions)


@setup_next_api.get("/api/setup/tasks/<int:setup_task_id>/procedure/current")
def api_setup_task_procedure_current(setup_task_id: int) -> Response:
    _base_repo, _email, _access = require_reader()
    task = repo().task_scope(setup_task_id)
    name = request.args.get("name", "").strip()
    path = (
        _stage_scene_current_document(task, name)
        if task.get("stage_id") is not None
        else _park_current_document(name)
    )
    return send_file(
        path,
        conditional=True,
        max_age=60,
        as_attachment=False,
        download_name=path.name,
    )


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
