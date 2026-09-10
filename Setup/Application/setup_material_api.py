"""Reusable Setup Display-Setup metadata and resolved material context.

LOR remains authoritative for current Display membership. Setup separately
records whether a task is a physical Display Setup step (visual classification)
and whether it uses the current whole Stage/Scene Display-material resolver.
Scene tasks use exact current LOR Scene membership; Stage/Sub-stage tasks use the
current remainder after excluding Displays represented by more-specific resolved
LOR scopes.

Task-specific component/KIT subdivision and staged pick timing are intentionally
out of scope here and remain deferred to Issue #141.
"""
from __future__ import annotations

from contextlib import closing
from typing import Any

import psycopg2
from psycopg2.extras import RealDictCursor
from flask import Blueprint, Response, jsonify

from backend import drive_root
from FieldWiring.Application.field_context_resolver import resolve_structured_scope
from setup_api import (
    SetupAuthenticationError,
    SetupCommandError,
    json_body,
    require_manager,
    require_reader,
    require_setup_command,
    setup_database_dsn,
)
from setup_repository import SetupRepositoryError

setup_material_api = Blueprint("setup_material_api", __name__)


class SetupMaterialResolutionError(RuntimeError):
    """Current LOR/folder evidence cannot produce a complete material scope."""


def _same_scope_path(left: Any, right: Any) -> bool:
    return str(left).replace("\\", "/").casefold().rstrip("/") == str(right).replace(
        "\\", "/"
    ).casefold().rstrip("/")


def _task_context(cur: Any, setup_task_id: int) -> dict[str, Any]:
    cur.execute(
        """
        SELECT t.setup_task_id, t.stage_id, t.lor_scene_id,
               t.is_display_setup_step, t.requires_display_material,
               s.stage_key, s.stage_name, s.folder_path
        FROM ref.setup_task AS t
        LEFT JOIN ref.stage AS s ON s.stage_id = t.stage_id
        WHERE t.setup_task_id = %s
        """,
        (setup_task_id,),
    )
    row = cur.fetchone()
    if row is None:
        raise SetupMaterialResolutionError("Setup task was not found")
    return dict(row)


def _stage_remainder_scene_ids(cur: Any, task: dict[str, Any]) -> tuple[list[int], list[int], list[str]]:
    """Classify all current LOR groups in one Stage by resolved structured scope.

    Returns (remainder scene ids, more-specific scene ids, warnings). A complete
    list is required: unresolved LOR scope evidence fails closed rather than
    silently dropping Displays from the material list.
    """
    stage = {
        "stage_id": task.get("stage_id"),
        "stage_key": task.get("stage_key"),
        "stage_name": task.get("stage_name"),
        "folder_path": task.get("folder_path"),
    }
    root, _root_type, root_warnings = resolve_structured_scope(
        stage,
        None,
        {},
        drive_root(),
    )
    if root is None:
        raise SetupMaterialResolutionError(
            "Setup Display material could not resolve the task Stage/Sub-stage root: "
            + "; ".join(root_warnings)
        )

    cur.execute(
        """
        SELECT ls.lor_scene_id,
               ls.preview_uuid,
               cp.name AS preview_name,
               cp.background_file AS preview_background_file,
               cp.revision AS preview_revision,
               cp.source_filename,
               ls.scene_uuid,
               ls.scene_name,
               ls.stage_id AS scene_stage_id,
               ls.background_file AS scene_background_file
        FROM ref.lor_scene AS ls
        LEFT JOIN lor_snap.v_current_previews AS cp
          ON cp.id = ls.preview_uuid
        WHERE ls.stage_id = %s
        ORDER BY ls.lor_scene_id
        """,
        (task["stage_id"],),
    )

    remainder_ids: list[int] = []
    specific_ids: list[int] = []
    warnings: list[str] = list(root_warnings)
    unresolved: list[str] = []

    for raw in cur.fetchall():
        item = dict(raw)
        preview = {
            "preview_uuid": item.get("preview_uuid"),
            "preview_name": item.get("preview_name"),
            "preview_background_file": item.get("preview_background_file"),
            "preview_revision": item.get("preview_revision"),
            "source_filename": item.get("source_filename"),
        }
        scene = {
            "scene_uuid": item.get("scene_uuid"),
            "scene_name": item.get("scene_name"),
            "scene_stage_key": item.get("scene_stage_id"),
            "scene_background_file": item.get("scene_background_file"),
        }
        resolved, scope_type, item_warnings = resolve_structured_scope(
            stage,
            scene,
            preview,
            drive_root(),
        )
        warnings.extend(item_warnings)
        if resolved is None or scope_type == "UNRESOLVED":
            unresolved.append(
                f"{item.get('lor_scene_id')}:{item.get('scene_name') or 'unnamed'}"
            )
            continue
        if _same_scope_path(resolved, root):
            remainder_ids.append(int(item["lor_scene_id"]))
        else:
            specific_ids.append(int(item["lor_scene_id"]))

    if unresolved:
        raise SetupMaterialResolutionError(
            "Setup Display material refused a partial Stage list because current LOR scope "
            "could not be resolved for: " + ", ".join(unresolved)
        )

    return remainder_ids, specific_ids, warnings


def _scope_relationships(cur: Any, task: dict[str, Any]) -> tuple[dict[int, dict[str, str | None]], list[str], str]:
    relationships: dict[int, dict[str, str | None]] = {}

    # Existing explicit task mappings remain supported as exceptional mappings.
    # They are not used to construct ordinary Stage/Scene membership.
    cur.execute(
        """
        SELECT td.display_id, td.relationship_type, td.notes
        FROM ref.setup_task_display AS td
        WHERE td.setup_task_id = %s
        ORDER BY td.display_id
        """,
        (task["setup_task_id"],),
    )
    for row in cur.fetchall():
        relationships[int(row["display_id"])] = {
            "relationship_type": row["relationship_type"],
            "relationship_notes": row["notes"],
            "relationship_source": "TASK_MAP",
        }

    if not bool(task.get("requires_display_material")):
        return relationships, [], "EXPLICIT_ONLY" if relationships else "NONE"

    scene_id = task.get("lor_scene_id")
    if scene_id is not None:
        cur.execute(
            """
            SELECT DISTINCT lsd.display_id
            FROM ref.lor_scene_display AS lsd
            WHERE lsd.lor_scene_id = %s
            ORDER BY lsd.display_id
            """,
            (scene_id,),
        )
        for row in cur.fetchall():
            relationships.setdefault(
                int(row["display_id"]),
                {
                    "relationship_type": "SCENE_SCOPE",
                    "relationship_notes": "Derived from current exact LOR Scene membership.",
                    "relationship_source": "SCENE",
                },
            )
        return relationships, [], "SCENE"

    if task.get("stage_id") is None:
        return relationships, [], "SITE_WIDE_EXPLICIT_ONLY"

    remainder_ids, specific_ids, warnings = _stage_remainder_scene_ids(cur, task)
    if not remainder_ids:
        return relationships, warnings, "STAGE_REMAINDER"

    # More-specific current LOR scopes win. If a Display occurs in both a
    # Stage-fallback LOR group and a true child scope, exclude it from the
    # parent Stage remainder rather than duplicate it.
    cur.execute(
        """
        SELECT DISTINCT r.display_id
        FROM ref.lor_scene_display AS r
        WHERE r.lor_scene_id = ANY(%s)
          AND NOT EXISTS (
              SELECT 1
              FROM ref.lor_scene_display AS child
              WHERE child.display_id = r.display_id
                AND child.lor_scene_id = ANY(%s)
          )
        ORDER BY r.display_id
        """,
        (remainder_ids, specific_ids or [-1]),
    )
    for row in cur.fetchall():
        relationships.setdefault(
            int(row["display_id"]),
            {
                "relationship_type": "STAGE_SCOPE",
                "relationship_notes": (
                    "Derived from current LOR Stage/Sub-stage remainder after excluding "
                    "more-specific current LOR scopes."
                ),
                "relationship_source": "STAGE_REMAINDER",
            },
        )
    return relationships, warnings, "STAGE_REMAINDER"


def _resolved_material_context(setup_task_id: int, season_year: int) -> dict[str, Any]:
    with closing(psycopg2.connect(setup_database_dsn())) as conn:
        conn.set_session(readonly=True, autocommit=True)
        with conn.cursor(cursor_factory=RealDictCursor) as cur:
            task = _task_context(cur, setup_task_id)
            relationships, warnings, mode = _scope_relationships(cur, task)
            display_ids = sorted(relationships)

            displays: list[dict[str, Any]] = []
            if display_ids:
                cur.execute(
                    """
                    SELECT d.display_id, d.display_name, d.container_id,
                           c.description AS container_description,
                           ds.position_mode,
                           CASE WHEN ds.position_mode = 'DETACHED' THEN ds.current_stage_id
                                ELSE cs.current_stage_id END AS current_stage_id,
                           current_stage.stage_key AS current_stage_key,
                           current_stage.stage_name AS current_stage_name,
                           CASE WHEN ds.position_mode = 'DETACHED' THEN ds.current_location_note
                                ELSE cs.current_location_note END AS current_location_note,
                           c.location_code AS home_location_code
                    FROM ref.display AS d
                    LEFT JOIN ref.container AS c ON c.container_id = d.container_id
                    LEFT JOIN ops.setup_session AS ss ON ss.season_year = %s
                    LEFT JOIN ops.setup_display_state AS ds
                      ON ds.setup_session_id = ss.setup_session_id
                     AND ds.display_id = d.display_id
                    LEFT JOIN ops.setup_container_state AS cs
                      ON cs.setup_session_id = ss.setup_session_id
                     AND cs.container_id = d.container_id
                    LEFT JOIN ref.stage AS current_stage
                      ON current_stage.stage_id = CASE
                          WHEN ds.position_mode = 'DETACHED' THEN ds.current_stage_id
                          ELSE cs.current_stage_id END
                    WHERE d.display_id = ANY(%s)
                      AND d.display_status_id = 1
                    ORDER BY d.container_id NULLS LAST, d.display_name, d.display_id
                    """,
                    (season_year, display_ids),
                )
                for row in cur.fetchall():
                    item = dict(row)
                    item.update(relationships[int(item["display_id"])])
                    displays.append(item)

            cur.execute(
                """
                SELECT c.container_id, c.description AS container_description,
                       c.location_code AS home_location_code,
                       cs.current_stage_id, s.stage_key AS current_stage_key,
                       s.stage_name AS current_stage_name, cs.current_location_note,
                       tc.relationship_type, tc.notes AS relationship_notes
                FROM ref.setup_task_container_support AS tc
                JOIN ref.container AS c ON c.container_id = tc.container_id
                LEFT JOIN ops.setup_session AS ss ON ss.season_year = %s
                LEFT JOIN ops.setup_container_state AS cs
                  ON cs.setup_session_id = ss.setup_session_id
                 AND cs.container_id = c.container_id
                LEFT JOIN ref.stage AS s ON s.stage_id = cs.current_stage_id
                WHERE tc.setup_task_id = %s
                ORDER BY c.container_id
                """,
                (season_year, setup_task_id),
            )
            containers = [dict(row) for row in cur.fetchall()]

    return {
        "displays": displays,
        "support_containers": containers,
        "material_resolution": {
            "is_display_setup_step": bool(task.get("is_display_setup_step")),
            "requires_display_material": bool(task.get("requires_display_material")),
            "mode": mode,
            "warnings": list(dict.fromkeys(warnings)),
        },
    }


@setup_material_api.get("/api/setup/task-display-material")
def api_setup_task_display_material() -> Response:
    require_reader()
    with closing(psycopg2.connect(setup_database_dsn())) as conn:
        with conn.cursor(cursor_factory=RealDictCursor) as cur:
            cur.execute(
                """
                SELECT setup_task_id, is_display_setup_step, requires_display_material
                FROM ref.setup_task
                ORDER BY setup_task_id
                """
            )
            rows = [dict(row) for row in cur.fetchall()]
    return jsonify(task_display_material=rows)


def _boolean_payload(payload: dict[str, Any], name: str) -> bool:
    value = payload.get(name)
    if not isinstance(value, bool):
        raise SetupCommandError(f"{name} must be true or false")
    return value


@setup_material_api.patch("/api/setup/tasks/<int:setup_task_id>/display-setup-step")
def api_setup_task_display_setup_step_update(setup_task_id: int) -> Response:
    require_setup_command()
    _repo, email, _access = require_manager()
    required = _boolean_payload(json_body(), "is_display_setup_step")

    conn = psycopg2.connect(setup_database_dsn())
    try:
        conn.set_session(readonly=False, autocommit=False)
        with conn.cursor(cursor_factory=RealDictCursor) as cur:
            cur.execute(
                "SELECT * FROM ref.set_setup_task_display_setup_step(%s,%s,%s)",
                (email, setup_task_id, required),
            )
            row = cur.fetchone()
            if row is None:
                raise SetupRepositoryError("Setup Display Setup command returned no result")
        conn.commit()
    finally:
        conn.close()

    return jsonify(setup_task_display_setup_step=dict(row))


@setup_material_api.patch("/api/setup/tasks/<int:setup_task_id>/display-material")
def api_setup_task_display_material_update(setup_task_id: int) -> Response:
    require_setup_command()
    _repo, email, _access = require_manager()
    required = _boolean_payload(json_body(), "requires_display_material")

    conn = psycopg2.connect(setup_database_dsn())
    try:
        conn.set_session(readonly=False, autocommit=False)
        with conn.cursor(cursor_factory=RealDictCursor) as cur:
            cur.execute(
                "SELECT * FROM ref.set_setup_task_display_material_requirement(%s,%s,%s)",
                (email, setup_task_id, required),
            )
            row = cur.fetchone()
            if row is None:
                raise SetupRepositoryError("Setup Display material command returned no result")
        conn.commit()
    finally:
        conn.close()

    return jsonify(setup_task_display_material=dict(row))


@setup_material_api.get("/api/setup/tasks/<int:setup_task_id>/material-context")
def api_setup_task_material_context(setup_task_id: int) -> Response:
    require_reader()
    from flask import request

    raw_year = request.args.get("season_year", "").strip()
    if not raw_year.isdigit():
        raise SetupCommandError("season_year is required")
    return jsonify(context=_resolved_material_context(setup_task_id, int(raw_year)))


@setup_material_api.errorhandler(SetupAuthenticationError)
def setup_material_authentication_error(exc: SetupAuthenticationError) -> tuple[Response, int]:
    return jsonify(error="Setup Session sign-in identity is unavailable", engineering_error=str(exc)), 401


@setup_material_api.errorhandler(SetupCommandError)
def setup_material_command_error(exc: SetupCommandError) -> tuple[Response, int]:
    return jsonify(error=str(exc), engineering_error=str(exc)), 403


@setup_material_api.errorhandler(SetupMaterialResolutionError)
def setup_material_resolution_error(exc: SetupMaterialResolutionError) -> tuple[Response, int]:
    return jsonify(error=str(exc), engineering_error=str(exc)), 409


@setup_material_api.errorhandler(SetupRepositoryError)
def setup_material_repository_error(exc: SetupRepositoryError) -> tuple[Response, int]:
    return jsonify(error=str(exc), engineering_error=str(exc)), 503


@setup_material_api.errorhandler(psycopg2.Error)
def setup_material_database_error(exc: psycopg2.Error) -> tuple[Response, int]:
    sqlstate = exc.pgcode or ""
    if sqlstate == "42501":
        status = 403
    elif sqlstate in {"22023", "23503", "23514"}:
        status = 400
    elif sqlstate == "P0002":
        status = 404
    else:
        status = 500
    message = (exc.diag.message_primary or "Setup Display material command failed").strip()
    return jsonify(error=message, engineering_error=str(exc)), status
