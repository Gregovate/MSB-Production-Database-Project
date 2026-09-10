"""Setup Display-Setup classification and explicit current-LOR material sources.

Work scope and Display material are separate relationships.

* ``ref.setup_task.stage_id`` / ``lor_scene_id`` describe where/what work occurs.
* ``ref.setup_task_material_source`` stores zero or more explicit LOR source choices.
* Current Display membership is resolved dynamically from LOR-owned current state.
* Containers are derived from current ``ref.display.container_id`` and deduplicated.

No task-name inference, Stage remainder inference, Google Drive/folder resolution, or
ordinary task-to-Display membership copy is used here.

Task-specific component/KIT subdivision and staged pick timing remain deferred to
Issue #141.
"""
from __future__ import annotations

from contextlib import closing
from typing import Any

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
from setup_repository import SetupRepositoryError

setup_material_api = Blueprint("setup_material_api", __name__)

SOURCE_TYPES = ("LOR_STAGE", "LOR_PREVIEW", "LOR_SCENE")


class SetupMaterialResolutionError(RuntimeError):
    """A selected material source can no longer be resolved from current LOR."""


def _task_context(cur: Any, setup_task_id: int) -> dict[str, Any]:
    cur.execute(
        """
        SELECT t.setup_task_id,
               t.stage_id AS work_stage_id,
               t.lor_scene_id AS work_lor_scene_id,
               t.is_display_setup_step
        FROM ref.setup_task AS t
        WHERE t.setup_task_id = %s
        """,
        (setup_task_id,),
    )
    row = cur.fetchone()
    if row is None:
        raise SetupMaterialResolutionError("Setup task was not found")
    return dict(row)


def _material_source_catalog(cur: Any) -> list[dict[str, Any]]:
    """Return selectable current LOR source identities with live Display counts."""
    catalog: list[dict[str, Any]] = []

    cur.execute(
        """
        SELECT s.stage_id,
               s.stage_key,
               s.stage_name,
               coalesce(x.display_count, 0) AS display_count
        FROM ref.stage AS s
        LEFT JOIN (
            SELECT d.stage_id, count(DISTINCT d.display_id) AS display_count
            FROM lor_snap.v_current_props AS p
            JOIN ref.display AS d
              ON d.lor_prop_id = p.raw_prop_id
             AND d.display_status_id = 1
            GROUP BY d.stage_id
        ) AS x ON x.stage_id = s.stage_id
        ORDER BY s.stage_key, s.stage_id
        """
    )
    for raw in cur.fetchall():
        row = dict(raw)
        catalog.append({
            "source_type": "LOR_STAGE", "source_key": str(row["stage_id"]),
            "label": f"Stage {row['stage_key']} — {row['stage_name']}",
            "stage_id": row["stage_id"], "stage_key": row["stage_key"],
            "stage_name": row["stage_name"], "preview_uuid": None,
            "preview_name": None, "lor_scene_id": None, "scene_name": None,
            "display_count": int(row.get("display_count") or 0), "available": True,
        })

    cur.execute(
        """
        SELECT pv.id AS preview_uuid,
               pv.name AS preview_name,
               pv.stage_id AS preview_stage_id,
               count(DISTINCT d.display_id) AS display_count
        FROM lor_snap.v_current_previews AS pv
        LEFT JOIN lor_snap.v_current_props AS p ON p.preview_id = pv.id
        LEFT JOIN ref.display AS d
          ON d.lor_prop_id = p.raw_prop_id
         AND d.display_status_id = 1
        GROUP BY pv.id, pv.name, pv.stage_id
        ORDER BY pv.name, pv.id
        """
    )
    for raw in cur.fetchall():
        row = dict(raw)
        catalog.append({
            "source_type": "LOR_PREVIEW", "source_key": str(row["preview_uuid"]),
            "label": f"Preview — {row['preview_name']}",
            "stage_id": row.get("preview_stage_id"), "stage_key": None,
            "stage_name": None, "preview_uuid": row["preview_uuid"],
            "preview_name": row["preview_name"], "lor_scene_id": None,
            "scene_name": None, "display_count": int(row.get("display_count") or 0),
            "available": True,
        })

    cur.execute(
        """
        SELECT ls.lor_scene_id, ls.preview_uuid, ls.scene_name, ls.stage_id,
               s.stage_key, s.stage_name, pv.name AS preview_name,
               count(DISTINCT d.display_id) AS display_count
        FROM ref.lor_scene AS ls
        JOIN ref.stage AS s ON s.stage_id = ls.stage_id
        LEFT JOIN lor_snap.v_current_previews AS pv ON pv.id = ls.preview_uuid
        LEFT JOIN ref.lor_scene_display AS lsd ON lsd.lor_scene_id = ls.lor_scene_id
        LEFT JOIN ref.display AS d
          ON d.display_id = lsd.display_id
         AND d.display_status_id = 1
        GROUP BY ls.lor_scene_id, ls.preview_uuid, ls.scene_name, ls.stage_id,
                 s.stage_key, s.stage_name, pv.name
        ORDER BY s.stage_key, ls.scene_name, ls.lor_scene_id
        """
    )
    for raw in cur.fetchall():
        row = dict(raw)
        catalog.append({
            "source_type": "LOR_SCENE", "source_key": str(row["lor_scene_id"]),
            "label": f"Scene / group {row['lor_scene_id']} — {row['scene_name']} · Stage {row['stage_key']}",
            "stage_id": row["stage_id"], "stage_key": row["stage_key"],
            "stage_name": row["stage_name"], "preview_uuid": row["preview_uuid"],
            "preview_name": row.get("preview_name"), "lor_scene_id": row["lor_scene_id"],
            "scene_name": row["scene_name"], "display_count": int(row.get("display_count") or 0),
            "available": True,
        })

    return catalog


def _selected_source_rows(cur: Any, setup_task_id: int) -> list[dict[str, Any]]:
    cur.execute(
        """
        SELECT ms.setup_task_id, ms.source_type,
               CASE ms.source_type
                   WHEN 'LOR_STAGE' THEN ms.stage_id::text
                   WHEN 'LOR_PREVIEW' THEN ms.preview_uuid
                   WHEN 'LOR_SCENE' THEN ms.lor_scene_id::text
               END AS source_key,
               ms.stage_id, ms.preview_uuid, ms.lor_scene_id, ms.notes
        FROM ref.setup_task_material_source AS ms
        WHERE ms.setup_task_id = %s
        ORDER BY ms.source_type,
                 coalesce(ms.stage_id::text, ms.preview_uuid, ms.lor_scene_id::text)
        """,
        (setup_task_id,),
    )
    return [dict(row) for row in cur.fetchall()]


def _enrich_selected_sources(rows: list[dict[str, Any]], catalog: list[dict[str, Any]]) -> list[dict[str, Any]]:
    by_key = {(item["source_type"], str(item["source_key"])): item for item in catalog}
    enriched: list[dict[str, Any]] = []
    for row in rows:
        current = by_key.get((row["source_type"], str(row["source_key"])))
        if current is None:
            enriched.append({**row, "label": f"{row['source_type']} {row['source_key']} — NOT CURRENT", "display_count": None, "available": False})
        else:
            enriched.append({**row, **current})
    return enriched


def _selected_material_sources(cur: Any, setup_task_id: int, catalog: list[dict[str, Any]] | None = None) -> list[dict[str, Any]]:
    return _enrich_selected_sources(
        _selected_source_rows(cur, setup_task_id),
        catalog if catalog is not None else _material_source_catalog(cur),
    )


def _validate_selected_sources(sources: list[dict[str, Any]]) -> None:
    stale = [source for source in sources if not source.get("available")]
    if stale:
        labels = ", ".join(str(source.get("label")) for source in stale)
        raise SetupMaterialResolutionError(
            "Setup Display material refused to return a partial result because selected LOR material source is no longer current: " + labels
        )


def _resolved_display_ids(cur: Any, sources: list[dict[str, Any]]) -> list[int]:
    """Union current Display membership from every explicitly selected LOR source."""
    if not sources:
        return []

    stage_ids = [int(source["source_key"]) for source in sources if source["source_type"] == "LOR_STAGE"]
    preview_uuids = [str(source["source_key"]) for source in sources if source["source_type"] == "LOR_PREVIEW"]
    scene_ids = [int(source["source_key"]) for source in sources if source["source_type"] == "LOR_SCENE"]
    display_ids: set[int] = set()

    if stage_ids:
        cur.execute(
            """
            SELECT DISTINCT d.display_id
            FROM lor_snap.v_current_props AS p
            JOIN ref.display AS d ON d.lor_prop_id = p.raw_prop_id
            WHERE d.display_status_id = 1 AND d.stage_id = ANY(%s)
            """,
            (stage_ids,),
        )
        display_ids.update(int(row["display_id"]) for row in cur.fetchall())

    if preview_uuids:
        cur.execute(
            """
            SELECT DISTINCT d.display_id
            FROM lor_snap.v_current_props AS p
            JOIN ref.display AS d ON d.lor_prop_id = p.raw_prop_id
            WHERE d.display_status_id = 1 AND p.preview_id = ANY(%s)
            """,
            (preview_uuids,),
        )
        display_ids.update(int(row["display_id"]) for row in cur.fetchall())

    if scene_ids:
        cur.execute(
            """
            SELECT DISTINCT d.display_id
            FROM ref.lor_scene_display AS lsd
            JOIN ref.display AS d ON d.display_id = lsd.display_id
            WHERE d.display_status_id = 1 AND lsd.lor_scene_id = ANY(%s)
            """,
            (scene_ids,),
        )
        display_ids.update(int(row["display_id"]) for row in cur.fetchall())

    return sorted(display_ids)


def _resolved_material_context(setup_task_id: int, season_year: int) -> dict[str, Any]:
    with closing(psycopg2.connect(setup_database_dsn())) as conn:
        conn.set_session(readonly=True, autocommit=True)
        with conn.cursor(cursor_factory=RealDictCursor) as cur:
            task = _task_context(cur, setup_task_id)
            catalog = _material_source_catalog(cur)
            sources = _selected_material_sources(cur, setup_task_id, catalog)
            _validate_selected_sources(sources)
            display_ids = _resolved_display_ids(cur, sources)

            displays: list[dict[str, Any]] = []
            if display_ids:
                cur.execute(
                    """
                    SELECT d.display_id, d.display_name, d.container_id,
                           c.description AS container_description,
                           ds.position_mode,
                           CASE WHEN ds.position_mode = 'DETACHED' THEN ds.current_stage_id ELSE cs.current_stage_id END AS current_stage_id,
                           current_stage.stage_key AS current_stage_key,
                           current_stage.stage_name AS current_stage_name,
                           CASE WHEN ds.position_mode = 'DETACHED' THEN ds.current_location_note ELSE cs.current_location_note END AS current_location_note,
                           c.location_code AS home_location_code,
                           'REQUIRED'::text AS relationship_type,
                           'Resolved dynamically from explicitly selected current LOR material source(s).'::text AS relationship_notes,
                           'LOR_MATERIAL_SOURCE'::text AS relationship_source
                    FROM ref.display AS d
                    LEFT JOIN ref.container AS c ON c.container_id = d.container_id
                    LEFT JOIN ops.setup_session AS ss ON ss.season_year = %s
                    LEFT JOIN ops.setup_display_state AS ds ON ds.setup_session_id = ss.setup_session_id AND ds.display_id = d.display_id
                    LEFT JOIN ops.setup_container_state AS cs ON cs.setup_session_id = ss.setup_session_id AND cs.container_id = d.container_id
                    LEFT JOIN ref.stage AS current_stage
                      ON current_stage.stage_id = CASE WHEN ds.position_mode = 'DETACHED' THEN ds.current_stage_id ELSE cs.current_stage_id END
                    WHERE d.display_id = ANY(%s)
                    ORDER BY d.container_id NULLS LAST, d.display_name, d.display_id
                    """,
                    (season_year, display_ids),
                )
                displays = [dict(row) for row in cur.fetchall()]

            material_containers: list[dict[str, Any]] = []
            container_ids = sorted({int(row["container_id"]) for row in displays if row.get("container_id") is not None})
            if container_ids:
                cur.execute(
                    """
                    SELECT c.container_id, c.description AS container_description,
                           c.location_code AS home_location_code, cs.current_stage_id,
                           s.stage_key AS current_stage_key, s.stage_name AS current_stage_name,
                           cs.current_location_note
                    FROM ref.container AS c
                    LEFT JOIN ops.setup_session AS ss ON ss.season_year = %s
                    LEFT JOIN ops.setup_container_state AS cs ON cs.setup_session_id = ss.setup_session_id AND cs.container_id = c.container_id
                    LEFT JOIN ref.stage AS s ON s.stage_id = cs.current_stage_id
                    WHERE c.container_id = ANY(%s)
                    ORDER BY c.container_id
                    """,
                    (season_year, container_ids),
                )
                material_containers = [dict(row) for row in cur.fetchall()]

            cur.execute(
                """
                SELECT c.container_id, c.description AS container_description,
                       c.location_code AS home_location_code, cs.current_stage_id,
                       s.stage_key AS current_stage_key, s.stage_name AS current_stage_name,
                       cs.current_location_note, tc.relationship_type, tc.notes AS relationship_notes
                FROM ref.setup_task_container_support AS tc
                JOIN ref.container AS c ON c.container_id = tc.container_id
                LEFT JOIN ops.setup_session AS ss ON ss.season_year = %s
                LEFT JOIN ops.setup_container_state AS cs ON cs.setup_session_id = ss.setup_session_id AND cs.container_id = c.container_id
                LEFT JOIN ref.stage AS s ON s.stage_id = cs.current_stage_id
                WHERE tc.setup_task_id = %s
                ORDER BY c.container_id
                """,
                (season_year, setup_task_id),
            )
            support_containers = [dict(row) for row in cur.fetchall()]

    return {
        "displays": displays,
        "material_containers": material_containers,
        "support_containers": support_containers,
        "material_resolution": {
            "is_display_setup_step": bool(task.get("is_display_setup_step")),
            "mode": "EXPLICIT_LOR_SOURCES" if sources else "NONE",
            "source_count": len(sources), "sources": sources,
            "work_stage_id": task.get("work_stage_id"),
            "work_lor_scene_id": task.get("work_lor_scene_id"), "warnings": [],
        },
    }


@setup_material_api.get("/api/setup/task-display-material")
def api_setup_task_display_material() -> Response:
    require_reader()
    with closing(psycopg2.connect(setup_database_dsn())) as conn:
        conn.set_session(readonly=True, autocommit=True)
        with conn.cursor(cursor_factory=RealDictCursor) as cur:
            catalog = _material_source_catalog(cur)
            cur.execute("SELECT setup_task_id, is_display_setup_step FROM ref.setup_task ORDER BY setup_task_id")
            tasks = [dict(row) for row in cur.fetchall()]
            cur.execute(
                """
                SELECT ms.setup_task_id, ms.source_type,
                       CASE ms.source_type WHEN 'LOR_STAGE' THEN ms.stage_id::text WHEN 'LOR_PREVIEW' THEN ms.preview_uuid WHEN 'LOR_SCENE' THEN ms.lor_scene_id::text END AS source_key,
                       ms.stage_id, ms.preview_uuid, ms.lor_scene_id, ms.notes
                FROM ref.setup_task_material_source AS ms
                ORDER BY ms.setup_task_id, ms.source_type, coalesce(ms.stage_id::text, ms.preview_uuid, ms.lor_scene_id::text)
                """
            )
            rows_by_task: dict[int, list[dict[str, Any]]] = {}
            for raw in cur.fetchall():
                row = dict(raw)
                rows_by_task.setdefault(int(row["setup_task_id"]), []).append(row)
            for task in tasks:
                task_id = int(task["setup_task_id"])
                task["material_sources"] = _enrich_selected_sources(rows_by_task.get(task_id, []), catalog)
    return jsonify(task_display_material=tasks, material_source_catalog=catalog)


def _boolean_payload(payload: dict[str, Any], name: str) -> bool:
    value = payload.get(name)
    if not isinstance(value, bool):
        raise SetupCommandError(f"{name} must be true or false")
    return value


def _material_source_payload(payload: dict[str, Any]) -> tuple[str, str, bool]:
    source_type = str(payload.get("source_type") or "").strip().upper()
    source_key = str(payload.get("source_key") or "").strip()
    active = payload.get("active")
    if source_type not in SOURCE_TYPES:
        raise SetupCommandError("source_type must be LOR_STAGE, LOR_PREVIEW, or LOR_SCENE")
    if not source_key:
        raise SetupCommandError("source_key is required")
    if not isinstance(active, bool):
        raise SetupCommandError("active must be true or false")
    return source_type, source_key, active


@setup_material_api.patch("/api/setup/tasks/<int:setup_task_id>/display-setup-step")
def api_setup_task_display_setup_step_update(setup_task_id: int) -> Response:
    require_setup_command()
    _repo, email, _access = require_manager()
    value = _boolean_payload(json_body(), "is_display_setup_step")
    conn = psycopg2.connect(setup_database_dsn())
    try:
        conn.set_session(readonly=False, autocommit=False)
        with conn.cursor(cursor_factory=RealDictCursor) as cur:
            cur.execute("SELECT * FROM ref.set_setup_task_display_setup_step(%s,%s,%s)", (email, setup_task_id, value))
            row = cur.fetchone()
            if row is None:
                raise SetupRepositoryError("Setup Display Setup command returned no result")
        conn.commit()
    finally:
        conn.close()
    return jsonify(setup_task_display_setup_step=dict(row))


@setup_material_api.patch("/api/setup/tasks/<int:setup_task_id>/material-source")
def api_setup_task_material_source_update(setup_task_id: int) -> Response:
    require_setup_command()
    _repo, email, _access = require_manager()
    source_type, source_key, active = _material_source_payload(json_body())
    conn = psycopg2.connect(setup_database_dsn())
    try:
        conn.set_session(readonly=False, autocommit=False)
        with conn.cursor(cursor_factory=RealDictCursor) as cur:
            cur.execute("SELECT * FROM ref.set_setup_task_material_source(%s,%s,%s,%s,%s)", (email, setup_task_id, source_type, source_key, active))
            row = cur.fetchone()
            if row is None:
                raise SetupRepositoryError("Setup material-source command returned no result")
        conn.commit()
    finally:
        conn.close()
    return jsonify(setup_task_material_source=dict(row))


@setup_material_api.get("/api/setup/tasks/<int:setup_task_id>/material-context")
def api_setup_task_material_context(setup_task_id: int) -> Response:
    require_reader()
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
    if sqlstate == "42501": status = 403
    elif sqlstate == "P0002": status = 404
    elif sqlstate in {"22023", "23503", "23514"}: status = 400
    else: status = 503
    message = str(exc).strip()
    return jsonify(error=message, engineering_error=message), status
