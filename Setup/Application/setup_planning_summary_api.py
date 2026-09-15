"""Read-only Planning Summary projection for Setup #122.

The Planning Summary is a reusable-Catalog review artifact.  It intentionally
does not create or depend on an annual Setup Session.  Existing durable Setup
sources remain authoritative; this module only projects them into a printable
shape.
"""
from __future__ import annotations

from collections import defaultdict
from contextlib import closing
from typing import Any

import psycopg2
from flask import Blueprint, Response, jsonify, request
from psycopg2.extras import RealDictCursor

from backend import ConfigError, ProcedureContextError, SetupInstructionError
from setup_api import (
    SetupAuthenticationError,
    SetupCommandError,
    require_reader,
    setup_database_dsn,
)
from setup_material_resolution import is_real_setup_scene
from setup_next_api import _task_instructions
from setup_next_repository import SetupNextRepository, SetupNextRepositoryError
from setup_repository import SetupRepositoryError


setup_planning_summary_api = Blueprint("setup_planning_summary_api", __name__)


def _positive_int_arg(name: str, *, required: bool = False) -> int | None:
    raw = request.args.get(name, "").strip()
    if not raw:
        if required:
            raise SetupCommandError(f"{name} is required")
        return None
    if not raw.isdigit() or int(raw) <= 0:
        raise SetupCommandError(f"{name} must be a positive integer")
    return int(raw)


def _scope_request() -> tuple[str, int | None, int | None]:
    scope = request.args.get("scope", "all").strip().lower() or "all"
    if scope not in {"all", "stage", "scene"}:
        raise SetupCommandError("scope must be all, stage, or scene")

    stage_id = _positive_int_arg("stage_id", required=scope in {"stage", "scene"})
    scene_id = _positive_int_arg("lor_scene_id", required=scope == "scene")
    return scope, stage_id, scene_id


def _task_sort_key(task: dict[str, Any]) -> tuple[Any, ...]:
    return (
        0 if task.get("stage_id") is None else 1,
        task.get("park_order") if task.get("park_order") is not None else 10**9,
        task.get("sub_order") if task.get("sub_order") is not None else 10**9,
        str(task.get("stage_key") or ""),
        0 if task.get("lor_scene_id") is None else 1,
        str(task.get("scene_name") or ""),
        task.get("baseline_plan_order") if task.get("baseline_plan_order") is not None else 10**9,
        task.get("display_order") if task.get("display_order") is not None else 10**9,
        task.get("setup_task_id") or 0,
    )


def _spec_text(row: dict[str, Any]) -> str | None:
    bits: list[str] = []
    if row.get("size_text"):
        bits.append(str(row["size_text"]))
    if row.get("length_value") is not None:
        length = str(row["length_value"])
        if row.get("length_unit"):
            length += f" {row['length_unit']}"
        bits.append(length)
    if row.get("color"):
        bits.append(str(row["color"]))
    return " · ".join(bits) or None


def _quantity_text(row: dict[str, Any]) -> str | None:
    if row.get("quantity_required") is None:
        return None
    text = str(row["quantity_required"])
    if row.get("quantity_uom"):
        text += f" {row['quantity_uom']}"
    qualifier = str(row.get("quantity_qualifier") or "").strip()
    if qualifier and qualifier != "EXACT":
        text += f" ({qualifier.replace('_', ' ').title()})"
    return text


def _load_base_tasks(
    scope: str,
    stage_id: int | None,
    scene_id: int | None,
) -> list[dict[str, Any]]:
    with closing(psycopg2.connect(setup_database_dsn())) as conn:
        with conn.cursor(cursor_factory=RealDictCursor) as cur:
            cur.execute(
                """
                SELECT
                    t.setup_task_id,
                    t.task_name,
                    t.task_action_type,
                    t.stage_id,
                    s.stage_key,
                    s.stage_name,
                    s.park_order,
                    s.sub_order,
                    t.lor_scene_id,
                    ls.scene_name,
                    t.display_order,
                    t.baseline_plan_order,
                    t.normal_crew_min,
                    t.normal_crew_max,
                    t.expected_duration_minutes,
                    t.effort_level,
                    t.completion_point,
                    t.readiness_note,
                    t.weather_note,
                    t.reusable_notes,
                    t.requires_display_material
                FROM ref.setup_task AS t
                LEFT JOIN ref.stage AS s
                  ON s.stage_id = t.stage_id
                LEFT JOIN ref.lor_scene AS ls
                  ON ls.lor_scene_id = t.lor_scene_id
                WHERE t.active_flag
                ORDER BY
                    s.park_order NULLS LAST,
                    s.sub_order NULLS LAST,
                    s.stage_key NULLS LAST,
                    t.baseline_plan_order NULLS LAST,
                    t.display_order,
                    t.setup_task_id
                """
            )
            raw = [dict(row) for row in cur.fetchall()]

    tasks: list[dict[str, Any]] = []
    for row in raw:
        if row.get("lor_scene_id") is not None and not is_real_setup_scene(row.get("scene_name")):
            row["lor_scene_id"] = None
            row["scene_name"] = None

        if scope in {"stage", "scene"} and row.get("stage_id") != stage_id:
            continue
        if scope == "scene" and row.get("lor_scene_id") != scene_id:
            continue
        tasks.append(row)

    if scope == "scene" and tasks:
        scene_names = {task.get("scene_name") for task in tasks}
        if len(scene_names) != 1 or None in scene_names:
            raise SetupCommandError("lor_scene_id is not a real Setup Scene for the selected Stage")

    return sorted(tasks, key=_task_sort_key)


def _load_dependencies(task_ids: list[int]) -> dict[int, list[dict[str, Any]]]:
    result: dict[int, list[dict[str, Any]]] = defaultdict(list)
    if not task_ids:
        return result
    with closing(psycopg2.connect(setup_database_dsn())) as conn:
        with conn.cursor(cursor_factory=RealDictCursor) as cur:
            cur.execute(
                """
                SELECT
                    d.setup_task_id,
                    d.prerequisite_setup_task_id,
                    pt.task_name,
                    d.dependency_note,
                    d.sort_order
                FROM ref.setup_task_dependency AS d
                JOIN ref.setup_task AS pt
                  ON pt.setup_task_id = d.prerequisite_setup_task_id
                WHERE d.setup_task_id = ANY(%s)
                ORDER BY d.setup_task_id,
                         d.sort_order,
                         pt.display_order,
                         d.prerequisite_setup_task_id
                """,
                (task_ids,),
            )
            for row in cur.fetchall():
                item = dict(row)
                result[int(item["setup_task_id"])].append(item)
    return result


def _load_resources(task_ids: list[int]) -> dict[int, list[dict[str, Any]]]:
    result: dict[int, list[dict[str, Any]]] = defaultdict(list)
    if not task_ids:
        return result
    with closing(psycopg2.connect(setup_database_dsn())) as conn:
        with conn.cursor(cursor_factory=RealDictCursor) as cur:
            cur.execute(
                """
                SELECT
                    tr.setup_task_id,
                    tr.setup_resource_id,
                    r.resource_name,
                    r.resource_type,
                    r.active_flag AS resource_active_flag,
                    tr.quantity_required,
                    tr.requirement_type,
                    tr.notes
                FROM ref.setup_task_resource AS tr
                JOIN ref.setup_resource AS r
                  ON r.setup_resource_id = tr.setup_resource_id
                WHERE tr.setup_task_id = ANY(%s)
                  AND tr.active_flag
                ORDER BY tr.setup_task_id,
                         CASE tr.requirement_type WHEN 'REQUIRED' THEN 0 ELSE 1 END,
                         r.display_order,
                         r.resource_name,
                         r.setup_resource_id
                """,
                (task_ids,),
            )
            for row in cur.fetchall():
                item = dict(row)
                result[int(item["setup_task_id"])].append(item)
    return result


def _load_support_containers(task_ids: list[int]) -> dict[int, list[dict[str, Any]]]:
    result: dict[int, list[dict[str, Any]]] = defaultdict(list)
    if not task_ids:
        return result
    with closing(psycopg2.connect(setup_database_dsn())) as conn:
        with conn.cursor(cursor_factory=RealDictCursor) as cur:
            cur.execute(
                """
                SELECT
                    tc.setup_task_id,
                    tc.container_id,
                    c.description AS container_description,
                    c.location_code AS home_location_code,
                    tc.relationship_type,
                    tc.notes AS relationship_notes
                FROM ref.setup_task_container_support AS tc
                JOIN ref.container AS c
                  ON c.container_id = tc.container_id
                WHERE tc.setup_task_id = ANY(%s)
                ORDER BY tc.setup_task_id,
                         CASE tc.relationship_type
                             WHEN 'KIT' THEN 0
                             WHEN 'REQUIRED_CONTAINER' THEN 1
                             ELSE 2
                         END,
                         lower(coalesce(c.description, '')),
                         c.container_id
                """,
                (task_ids,),
            )
            for row in cur.fetchall():
                item = dict(row)
                result[int(item["setup_task_id"])].append(item)
    return result


def _load_extra_materials(task_ids: list[int]) -> dict[int, list[dict[str, Any]]]:
    grouped: dict[int, dict[int, dict[str, Any]]] = defaultdict(dict)
    if not task_ids:
        return defaultdict(list)

    with closing(psycopg2.connect(setup_database_dsn())) as conn:
        with conn.cursor(cursor_factory=RealDictCursor) as cur:
            cur.execute(
                """
                SELECT
                    tm.setup_task_id,
                    tm.setup_task_extra_material_id,
                    tm.setup_extra_material_id,
                    m.material_name,
                    m.lifecycle_class,
                    m.active_flag AS material_active_flag,
                    tm.quantity_required,
                    tm.quantity_uom,
                    tm.size_text,
                    tm.length_value,
                    tm.length_unit,
                    tm.color,
                    tm.quantity_qualifier,
                    tm.verification_state,
                    tm.notes,
                    src.setup_task_extra_material_source_id,
                    src.container_id AS source_container_id,
                    c.description AS source_container_description,
                    src.expected_quantity AS source_expected_quantity,
                    src.verification_state AS source_verification_state,
                    src.notes AS source_notes
                FROM ref.setup_task_extra_material AS tm
                JOIN ref.setup_extra_material AS m
                  ON m.setup_extra_material_id = tm.setup_extra_material_id
                LEFT JOIN ref.setup_task_extra_material_source AS src
                  ON src.setup_task_extra_material_id = tm.setup_task_extra_material_id
                 AND src.active_flag
                LEFT JOIN ref.container AS c
                  ON c.container_id = src.container_id
                WHERE tm.setup_task_id = ANY(%s)
                  AND tm.active_flag
                ORDER BY tm.setup_task_id,
                         m.display_order,
                         m.material_name,
                         tm.length_value NULLS LAST,
                         tm.size_text NULLS LAST,
                         tm.color NULLS LAST,
                         tm.setup_task_extra_material_id,
                         src.setup_task_extra_material_source_id
                """,
                (task_ids,),
            )
            rows = [dict(row) for row in cur.fetchall()]

    for row in rows:
        task_id = int(row["setup_task_id"])
        requirement_id = int(row["setup_task_extra_material_id"])
        requirement = grouped[task_id].get(requirement_id)
        if requirement is None:
            requirement = {
                "setup_task_extra_material_id": requirement_id,
                "setup_extra_material_id": row.get("setup_extra_material_id"),
                "material_name": row.get("material_name"),
                "lifecycle_class": row.get("lifecycle_class"),
                "material_active_flag": bool(row.get("material_active_flag")),
                "quantity_required": row.get("quantity_required"),
                "quantity_uom": row.get("quantity_uom"),
                "quantity_text": _quantity_text(row),
                "size_text": row.get("size_text"),
                "length_value": row.get("length_value"),
                "length_unit": row.get("length_unit"),
                "color": row.get("color"),
                "spec_text": _spec_text(row),
                "quantity_qualifier": row.get("quantity_qualifier"),
                "verification_state": row.get("verification_state"),
                "notes": row.get("notes"),
                "sources": [],
            }
            grouped[task_id][requirement_id] = requirement

        if row.get("setup_task_extra_material_source_id") is not None:
            requirement["sources"].append(
                {
                    "setup_task_extra_material_source_id": row.get("setup_task_extra_material_source_id"),
                    "container_id": row.get("source_container_id"),
                    "container_description": row.get("source_container_description"),
                    "expected_quantity": row.get("source_expected_quantity"),
                    "verification_state": row.get("source_verification_state"),
                    "notes": row.get("source_notes"),
                }
            )

    result: dict[int, list[dict[str, Any]]] = defaultdict(list)
    for task_id, requirements in grouped.items():
        result[task_id] = list(requirements.values())
    return result


def _material_summary(task: dict[str, Any], next_repo: SetupNextRepository) -> dict[str, Any]:
    requires = bool(task.get("requires_display_material"))
    if not requires:
        return {
            "requires_display_material": False,
            "display_count": 0,
            "container_count": 0,
            "containers": [],
            "uncontained_display_count": 0,
            "ownership_status": "NOT_APPLICABLE",
            "warning": None,
        }

    # 0 deliberately suppresses annual movement-state joins.  The installed
    # resolver still uses current LOR membership, Display ownership, and the
    # current Display -> Container relationship.
    context = next_repo.field_context(task_id=int(task["setup_task_id"]), season_year=0)
    resolution = dict(context.get("material_resolution") or {})
    containers: dict[int, str | None] = {}
    for display in context.get("displays") or []:
        container_id = display.get("container_id")
        if container_id is None:
            continue
        containers[int(container_id)] = display.get("container_description")

    return {
        "requires_display_material": bool(resolution.get("requires_display_material")),
        "mode": resolution.get("mode"),
        "display_count": int(resolution.get("display_count") or 0),
        "source_display_count": int(resolution.get("source_display_count") or 0),
        "container_count": int(resolution.get("container_count") or 0),
        "containers": [
            {"container_id": container_id, "container_description": containers[container_id]}
            for container_id in sorted(containers)
        ],
        "uncontained_display_count": int(resolution.get("uncontained_display_count") or 0),
        "ownership_mode": resolution.get("ownership_mode"),
        "ownership_status": resolution.get("ownership_status"),
        "warning": resolution.get("warning"),
    }


def _procedure_summary(
    task_id: int,
    access: dict[str, Any],
) -> dict[str, Any]:
    try:
        _task, instructions = _task_instructions(task_id, access)
    except (
        SetupCommandError,
        SetupNextRepositoryError,
        ConfigError,
        ProcedureContextError,
        SetupInstructionError,
        OSError,
    ) as exc:
        return {
            "status": "UNRESOLVED",
            "scope_type": None,
            "documents": [],
            "warnings": [str(exc)],
        }

    documents = [
        {"name": item.get("name")}
        for item in (instructions.get("current_documents") or [])
        if item.get("name")
    ]
    return {
        "status": instructions.get("status"),
        "scope_type": instructions.get("scope_type"),
        "documents": documents,
        "warnings": list(instructions.get("warnings") or []),
    }


def _review_indicators(task: dict[str, Any]) -> list[dict[str, str]]:
    indicators: list[dict[str, str]] = []

    material = task.get("display_material") or {}
    if material.get("ownership_status") == "REVIEW_REQUIRED":
        indicators.append(
            {
                "state": "NEEDS_REVIEW",
                "source": "Display ownership",
                "detail": str(material.get("warning") or "Display assignment coverage requires review."),
            }
        )
    if int(material.get("uncontained_display_count") or 0) > 0:
        indicators.append(
            {
                "state": "NEEDS_REVIEW",
                "source": "Display material",
                "detail": f"{material['uncontained_display_count']} resolved Display(s) have no current Container.",
            }
        )

    for resource in task.get("resources") or []:
        if resource.get("resource_active_flag") is False:
            indicators.append(
                {
                    "state": "NEEDS_REVIEW",
                    "source": str(resource.get("resource_name") or "Resource"),
                    "detail": "Task requirement points to an inactive Resource Catalog entry.",
                }
            )

    for requirement in task.get("extra_materials") or []:
        if requirement.get("material_active_flag") is False:
            indicators.append(
                {
                    "state": "NEEDS_REVIEW",
                    "source": str(requirement.get("material_name") or "Extra Material"),
                    "detail": "Task requirement points to an inactive Extra Material Catalog entry.",
                }
            )
        state = str(requirement.get("verification_state") or "").upper()
        if state and state != "VERIFIED":
            indicators.append(
                {
                    "state": state,
                    "source": str(requirement.get("material_name") or "Extra Material"),
                    "detail": "Task requirement verification state.",
                }
            )
        for source in requirement.get("sources") or []:
            source_state = str(source.get("verification_state") or "").upper()
            if source_state and source_state != "VERIFIED":
                description = source.get("container_description") or source.get("container_id") or "source"
                indicators.append(
                    {
                        "state": source_state,
                        "source": f"{requirement.get('material_name') or 'Extra Material'} source",
                        "detail": f"Expected source {description}.",
                    }
                )

    procedure = task.get("procedure") or {}
    if procedure.get("status") != "AVAILABLE" or not procedure.get("documents"):
        indicators.append(
            {
                "state": "NEEDS_REVIEW",
                "source": "Procedure",
                "detail": "No current published Setup PDF is available for this scope.",
            }
        )
    return indicators


@setup_planning_summary_api.get("/api/setup/planning-summary")
def api_setup_planning_summary() -> Response:
    _base_repo, _email, access = require_reader()
    scope, stage_id, scene_id = _scope_request()
    tasks = _load_base_tasks(scope, stage_id, scene_id)

    if scope == "scene" and not tasks:
        raise SetupCommandError("No active reusable Setup tasks were found for that real Scene")

    task_ids = [int(task["setup_task_id"]) for task in tasks]
    dependencies = _load_dependencies(task_ids)
    resources = _load_resources(task_ids)
    support_containers = _load_support_containers(task_ids)
    extra_materials = _load_extra_materials(task_ids)

    next_repo = SetupNextRepository(setup_database_dsn())
    material_cache: dict[int, dict[str, Any]] = {}
    procedure_cache: dict[tuple[int | None, int | None], dict[str, Any]] = {}

    for task in tasks:
        task_id = int(task["setup_task_id"])
        task["dependencies"] = dependencies.get(task_id, [])
        task["resources"] = resources.get(task_id, [])
        task["support_containers"] = support_containers.get(task_id, [])
        task["extra_materials"] = extra_materials.get(task_id, [])
        task["tpost_requirements"] = [
            row for row in task["extra_materials"]
            if row.get("material_name") == "T-Post"
        ]

        if task_id not in material_cache:
            material_cache[task_id] = _material_summary(task, next_repo)
        task["display_material"] = material_cache[task_id]

        scope_key = (
            int(task["stage_id"]) if task.get("stage_id") is not None else None,
            int(task["lor_scene_id"]) if task.get("lor_scene_id") is not None else None,
        )
        if scope_key not in procedure_cache:
            procedure_cache[scope_key] = _procedure_summary(task_id, access)
        task["procedure"] = procedure_cache[scope_key]
        task["review_indicators"] = _review_indicators(task)

    scope_label = "All active reusable Setup tasks"
    if scope == "stage":
        selected = tasks[0] if tasks else None
        scope_label = (
            f"{selected.get('stage_key')} — {selected.get('stage_name')}"
            if selected
            else f"Stage {stage_id}"
        )
    elif scope == "scene":
        selected = tasks[0]
        scope_label = (
            f"{selected.get('stage_key')} — {selected.get('stage_name')} / "
            f"{selected.get('scene_name')}"
        )

    return jsonify(
        planning_summary={
            "artifact": "Reusable Setup Catalog Planning Summary",
            "scope": scope,
            "scope_label": scope_label,
            "stage_id": stage_id,
            "lor_scene_id": scene_id,
            "task_count": len(tasks),
            "tasks": tasks,
            "verification_boundary": (
                "Reusable tasks do not have a reusable task-level verification state. "
                "Printed UNVERIFIED / NEEDS_REVIEW indicators belong to the durable fact "
                "that owns the uncertainty."
            ),
        }
    )


@setup_planning_summary_api.errorhandler(SetupAuthenticationError)
def planning_summary_authentication_error(
    exc: SetupAuthenticationError,
) -> tuple[Response, int]:
    return jsonify(
        error="Setup Session sign-in identity is unavailable",
        engineering_error=str(exc),
    ), 401


@setup_planning_summary_api.errorhandler(SetupCommandError)
def planning_summary_command_error(exc: SetupCommandError) -> tuple[Response, int]:
    return jsonify(error=str(exc), engineering_error=str(exc)), 400


@setup_planning_summary_api.errorhandler(SetupRepositoryError)
@setup_planning_summary_api.errorhandler(SetupNextRepositoryError)
def planning_summary_repository_error(
    exc: SetupRepositoryError | SetupNextRepositoryError,
) -> tuple[Response, int]:
    return jsonify(
        error="Setup Planning Summary is temporarily unavailable.",
        engineering_error=str(exc),
    ), 503


@setup_planning_summary_api.errorhandler(psycopg2.Error)
def planning_summary_database_error(exc: psycopg2.Error) -> tuple[Response, int]:
    message = (exc.diag.message_primary or "Setup Planning Summary database read failed").strip()
    return jsonify(error=message, engineering_error=str(exc)), 500
