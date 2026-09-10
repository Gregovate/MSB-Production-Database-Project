"""Reusable Setup Display-Setup metadata and resolved material context.

LOR remains authoritative for current Display membership. Setup separately
records whether a task is a physical Display Setup step (visual classification)
and whether it uses the current whole Stage/Scene Display-material resolver.

Material scope is database-owned, not filesystem-owned:

* Scene-scoped tasks use exact current ``ref.lor_scene_display`` membership for
  the task's ``lor_scene_id``.
* Stage/Sub-stage-scoped tasks use every current LOR Display for that stage_id,
  excluding LOR Scenes that are represented by active scene-scoped reusable
  Setup tasks for the same stage_id.

Google Drive folders and Procedure paths remain documentation-resolution facts;
they do not define Display membership or whether a LOR Scene is a separate Setup
material scope.

Task-specific component/KIT subdivision and staged pick timing are intentionally
out of scope here and remain deferred to Issue #141.
"""
from __future__ import annotations

from contextlib import closing
from typing import Any

import psycopg2
from psycopg2.extras import RealDictCursor
from flask import Blueprint, Response, jsonify

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
    """Current Setup/LOR database evidence cannot produce a material scope."""


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
    """Partition one Stage/Sub-stage using current LOR + reusable Setup scope.

    ``ref.lor_scene`` contains both true operational Scene scopes and LOR groups
    whose material belongs to the parent Stage task. Setup already records the
    operational distinction: a reusable task with ``lor_scene_id`` is explicitly
    Scene-scoped. Therefore Stage material is all current LOR groups for the
    stage minus the distinct current LOR Scenes referenced by active scene-scoped
    Setup tasks.

    This intentionally does not inspect Google Drive folders or BackgroundFile
    paths. Those resolve documentation; they are not material-membership data.
    """
    stage_id = task.get("stage_id")
    if stage_id is None:
        return [], [], []

    cur.execute(
        """
        SELECT ls.lor_scene_id
        FROM ref.lor_scene AS ls
        WHERE ls.stage_id = %s
        ORDER BY ls.lor_scene_id
        """,
        (stage_id,),
    )
    all_scene_ids = [int(row["lor_scene_id"]) for row in cur.fetchall()]

    cur.execute(
        """
        SELECT DISTINCT t.lor_scene_id
        FROM ref.setup_task AS t
        JOIN ref.lor_scene AS ls
          ON ls.lor_scene_id = t.lor_scene_id
         AND ls.stage_id = t.stage_id
        WHERE t.stage_id = %s
          AND t.active_flag
          AND t.lor_scene_id IS NOT NULL
        ORDER BY t.lor_scene_id
        """,
        (stage_id,),
    )
    specific_ids = [int(row["lor_scene_id"]) for row in cur.fetchall()]
    specific_set = set(specific_ids)
    remainder_ids = [scene_id for scene_id in all_scene_ids if scene_id not in specific_set]
    return remainder_ids, specific_ids, []


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

    # A Display in any active scene-scoped Setup LOR Scene is excluded from the
    # parent Stage remainder. This remains safe even if the LOR source happens
    # to duplicate a Display across another Stage-level group.
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
                    "Derived from current LOR Stage/Sub-stage membership after excluding "
                    "LOR Scenes represented by active scene-scoped reusable Setup tasks."
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
