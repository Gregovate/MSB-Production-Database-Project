"""Automatic Setup Display/container material resolution.

This module keeps Setup task material simple:

* ``requires_display_material = false`` means no LOR-derived Display material;
* a true child Scene task resolves exact current ``ref.lor_scene_display`` rows;
* a Stage-level task resolves the union of current LOR groups that follow the
  established Folder Alignment naming classification as Stage-level groups;
* current Containers are derived only after the Display set is known.

The LOR grouping and Display membership remain authoritative. Setup does not
store or ask the operator to maintain an ordinary material-source list.
"""
from __future__ import annotations

import re
from collections import defaultdict
from typing import Any

from psycopg2.extras import RealDictCursor

from setup_next_repository import SetupNextRepository, SetupNextRepositoryError


SCENE_PREFIX_RE = re.compile(r"^\s*(?P<num>\d{2})(?P<letter>[A-Za-z]?)-(?P<body>.+?)\s*$")
TWO_LETTER_SUFFIX_RE = re.compile(r"-[A-Za-z]{2}$")

# Keep the installed repository methods available before the focused extension
# replaces them. Their SQL remains authoritative for schedule/execution data;
# this module normalizes only the physical Setup scope presented to operators.
_ORIGINAL_EXECUTION_TASKS = SetupNextRepository.execution_tasks
_ORIGINAL_SCHEDULE = SetupNextRepository.schedule


def classify_lor_group(scene_name: str | None) -> tuple[str, str, str]:
    """Mirror the established Folder Alignment Scene/group classification.

    Returns ``(kind, token, expected_name)`` where kind is one of ROOT,
    DISPLAY_GROUP, STAGE_ROOT, SUB_STAGE, or SCENE.
    """
    name = str(scene_name or "").strip()
    if name.casefold() == "root":
        return "ROOT", "", ""

    match = SCENE_PREFIX_RE.match(name)
    if not match:
        return "DISPLAY_GROUP", "", ""

    token = f"{match.group('num')}{match.group('letter').casefold()}"
    if TWO_LETTER_SUFFIX_RE.search(name):
        return ("SUB_STAGE" if match.group("letter") else "STAGE_ROOT"), token, name

    return "SCENE", token, name


def is_real_setup_scene(scene_name: str | None) -> bool:
    return classify_lor_group(scene_name)[0] == "SCENE"


def is_stage_level_lor_group(scene_name: str | None) -> bool:
    return not is_real_setup_scene(scene_name)


def _normalize_task_scope(item: dict[str, Any]) -> dict[str, Any]:
    """Present programming/display groups as Stage-level Setup scope.

    Existing rows are not mutated. If an older reusable task happens to carry a
    ``lor_scene_id`` that names a programming/display group rather than a real
    child Scene, Setup treats that task as Stage-level for presentation,
    Procedure resolution, scheduling/execution presentation, and material
    resolution.
    """
    normalized = dict(item)
    raw_scene_id = normalized.get("lor_scene_id")
    normalized["source_lor_scene_id"] = raw_scene_id

    if raw_scene_id is not None and not is_real_setup_scene(normalized.get("scene_name")):
        normalized["lor_scene_id"] = None
        normalized["scene_name"] = None
        if "scene_uuid" in normalized:
            normalized["scene_uuid"] = None
        if "preview_uuid" in normalized:
            normalized["preview_uuid"] = None

    return normalized


def _organization(self: SetupNextRepository) -> dict[str, list[dict[str, Any]]]:
    with self.connect() as conn, conn.cursor(cursor_factory=RealDictCursor) as cur:
        cur.execute(
            """
            SELECT
                ls.lor_scene_id,
                ls.stage_id,
                s.stage_key,
                ls.scene_name,
                ls.scene_section,
                ls.preview_uuid,
                ls.scene_uuid
            FROM ref.lor_scene AS ls
            JOIN ref.stage AS s
              ON s.stage_id = ls.stage_id
            ORDER BY s.park_order NULLS LAST,
                     s.sub_order NULLS LAST,
                     s.stage_key,
                     ls.scene_name,
                     ls.lor_scene_id
            """
        )
        scenes = [
            dict(row)
            for row in cur.fetchall()
            if is_real_setup_scene(row.get("scene_name"))
        ]

        cur.execute(
            """
            SELECT
                t.setup_task_id,
                t.stage_id,
                t.lor_scene_id,
                ls.scene_name,
                t.baseline_plan_order
            FROM ref.setup_task AS t
            LEFT JOIN ref.lor_scene AS ls
              ON ls.lor_scene_id = t.lor_scene_id
            ORDER BY t.setup_task_id
            """
        )
        scopes = [_normalize_task_scope(dict(row)) for row in cur.fetchall()]

    return {"scenes": scenes, "task_scopes": scopes}


def _task_scope(self: SetupNextRepository, task_id: int) -> dict[str, Any]:
    with self.connect() as conn, conn.cursor(cursor_factory=RealDictCursor) as cur:
        cur.execute(
            """
            SELECT
                t.setup_task_id,
                t.task_name,
                t.stage_id,
                s.stage_key,
                s.stage_name,
                t.lor_scene_id,
                ls.scene_name,
                ls.scene_uuid,
                ls.preview_uuid,
                t.requires_display_material
            FROM ref.setup_task AS t
            LEFT JOIN ref.stage AS s
              ON s.stage_id = t.stage_id
            LEFT JOIN ref.lor_scene AS ls
              ON ls.lor_scene_id = t.lor_scene_id
            WHERE t.setup_task_id = %s
            """,
            (task_id,),
        )
        row = cur.fetchone()

    if row is None:
        raise SetupNextRepositoryError("Setup task was not found")
    return _normalize_task_scope(dict(row))


def _execution_tasks(self: SetupNextRepository, season_year: int) -> list[dict[str, Any]]:
    """Reuse installed execution SQL, but expose only real Setup Scene scope."""
    return [
        _normalize_task_scope(dict(row))
        for row in _ORIGINAL_EXECUTION_TASKS(self, season_year)
    ]


def _schedule(self: SetupNextRepository, season_year: int) -> dict[str, list[dict[str, Any]]]:
    """Reuse installed schedule SQL and normalize assignment Scene presentation."""
    data = _ORIGINAL_SCHEDULE(self, season_year)
    return {
        "work_days": [dict(row) for row in data.get("work_days", [])],
        "assignments": [
            _normalize_task_scope(dict(row))
            for row in data.get("assignments", [])
        ],
    }


def _add_material_source(
    material: dict[int, dict[str, Any]],
    *,
    display_id: int,
    source: str,
    source_name: str | None = None,
    relationship_type: str = "REQUIRED",
    relationship_notes: str | None = None,
) -> None:
    entry = material.setdefault(
        int(display_id),
        {
            "sources": [],
            "source_names": [],
            "relationship_types": [],
            "relationship_notes": [],
        },
    )
    if source not in entry["sources"]:
        entry["sources"].append(source)
    if source_name and source_name not in entry["source_names"]:
        entry["source_names"].append(source_name)
    if relationship_type and relationship_type not in entry["relationship_types"]:
        entry["relationship_types"].append(relationship_type)
    if relationship_notes and relationship_notes not in entry["relationship_notes"]:
        entry["relationship_notes"].append(relationship_notes)


def _resolve_material_membership(
    cur: Any,
    *,
    task_id: int,
    stage_id: int | None,
    lor_scene_id: int | None,
    scene_name: str | None,
    requires_display_material: bool,
) -> tuple[dict[int, dict[str, Any]], str, str | None]:
    material: dict[int, dict[str, Any]] = {}

    if not requires_display_material:
        return material, "NONE", None
    if stage_id is None:
        return material, "UNRESOLVED", "Display material requires a Stage or real Scene scope."

    if lor_scene_id is not None and is_real_setup_scene(scene_name):
        cur.execute(
            """
            SELECT lsd.display_id
            FROM ref.lor_scene_display AS lsd
            WHERE lsd.lor_scene_id = %s
            ORDER BY lsd.display_id
            """,
            (lor_scene_id,),
        )
        for row in cur.fetchall():
            _add_material_source(
                material,
                display_id=int(row["display_id"]),
                source="LOR_SCENE",
                source_name=scene_name,
                relationship_notes="Derived automatically from current LOR Scene membership.",
            )
        mode = "SCENE"
    else:
        cur.execute(
            """
            SELECT
                ls.lor_scene_id,
                ls.scene_name,
                lsd.display_id
            FROM ref.lor_scene AS ls
            JOIN ref.lor_scene_display AS lsd
              ON lsd.lor_scene_id = ls.lor_scene_id
            WHERE ls.stage_id = %s
            ORDER BY ls.scene_name, ls.lor_scene_id, lsd.display_id
            """,
            (stage_id,),
        )
        for row in cur.fetchall():
            group_name = row.get("scene_name")
            if not is_stage_level_lor_group(group_name):
                continue
            _add_material_source(
                material,
                display_id=int(row["display_id"]),
                source="LOR_STAGE_LEVEL",
                source_name=str(group_name or "").strip() or None,
                relationship_notes="Derived automatically from current Stage-level LOR grouping.",
            )
        mode = "STAGE"

    # Preserve the existing explicit task-to-Display relationship as a governed
    # exception surface. It is not used for ordinary LOR membership and remains
    # empty in the current Production baseline.
    cur.execute(
        """
        SELECT display_id, relationship_type, notes
        FROM ref.setup_task_display
        WHERE setup_task_id = %s
        ORDER BY display_id
        """,
        (task_id,),
    )
    for row in cur.fetchall():
        _add_material_source(
            material,
            display_id=int(row["display_id"]),
            source="TASK_MAP",
            relationship_type=str(row.get("relationship_type") or "REQUIRED"),
            relationship_notes=str(row.get("notes") or "").strip() or "Explicit Setup task Display relationship.",
        )

    return material, mode, None


def _field_context(
    self: SetupNextRepository,
    *,
    task_id: int,
    season_year: int,
) -> dict[str, Any]:
    with self.connect() as conn, conn.cursor(cursor_factory=RealDictCursor) as cur:
        cur.execute(
            """
            SELECT
                t.setup_task_id,
                t.stage_id,
                s.stage_key,
                t.lor_scene_id,
                ls.scene_name,
                t.requires_display_material
            FROM ref.setup_task AS t
            LEFT JOIN ref.stage AS s
              ON s.stage_id = t.stage_id
            LEFT JOIN ref.lor_scene AS ls
              ON ls.lor_scene_id = t.lor_scene_id
            WHERE t.setup_task_id = %s
            """,
            (task_id,),
        )
        task = cur.fetchone()
        if task is None:
            raise SetupNextRepositoryError("Setup task was not found")

        raw_scene_id = task.get("lor_scene_id")
        raw_scene_name = task.get("scene_name")
        real_scene_id = raw_scene_id if is_real_setup_scene(raw_scene_name) else None
        real_scene_name = raw_scene_name if real_scene_id is not None else None

        membership, mode, warning = _resolve_material_membership(
            cur,
            task_id=task_id,
            stage_id=task.get("stage_id"),
            lor_scene_id=real_scene_id,
            scene_name=real_scene_name,
            requires_display_material=bool(task.get("requires_display_material")),
        )

        displays: list[dict[str, Any]] = []
        display_ids = sorted(membership)
        if display_ids:
            cur.execute(
                """
                SELECT
                    d.display_id,
                    d.display_name,
                    d.container_id,
                    c.description AS container_description,
                    ds.position_mode,
                    CASE
                        WHEN ds.position_mode = 'DETACHED' THEN ds.current_stage_id
                        ELSE cs.current_stage_id
                    END AS current_stage_id,
                    current_stage.stage_key AS current_stage_key,
                    current_stage.stage_name AS current_stage_name,
                    CASE
                        WHEN ds.position_mode = 'DETACHED' THEN ds.current_location_note
                        ELSE cs.current_location_note
                    END AS current_location_note,
                    c.location_code AS home_location_code
                FROM ref.display AS d
                JOIN ref.display_status AS status
                  ON status.display_status_id = d.display_status_id
                LEFT JOIN ref.container AS c
                  ON c.container_id = d.container_id
                LEFT JOIN ops.setup_session AS ss
                  ON ss.season_year = %s
                LEFT JOIN ops.setup_display_state AS ds
                  ON ds.setup_session_id = ss.setup_session_id
                 AND ds.display_id = d.display_id
                LEFT JOIN ops.setup_container_state AS cs
                  ON cs.setup_session_id = ss.setup_session_id
                 AND cs.container_id = d.container_id
                LEFT JOIN ref.stage AS current_stage
                  ON current_stage.stage_id = CASE
                      WHEN ds.position_mode = 'DETACHED' THEN ds.current_stage_id
                      ELSE cs.current_stage_id
                  END
                WHERE d.display_id = ANY(%s)
                  AND upper(status.display_status_name) = 'ACTIVE'
                ORDER BY d.container_id NULLS LAST, d.display_name, d.display_id
                """,
                (season_year, display_ids),
            )
            for row in cur.fetchall():
                item = dict(row)
                source = membership[int(item["display_id"])]
                item["relationship_type"] = ", ".join(source["relationship_types"]) or "REQUIRED"
                item["relationship_source"] = ", ".join(source["sources"])
                source_names = ", ".join(source["source_names"])
                notes = list(source["relationship_notes"])
                if source_names:
                    notes.append(f"LOR group(s): {source_names}")
                item["relationship_notes"] = " ".join(notes)
                displays.append(item)

        cur.execute(
            """
            SELECT
                c.container_id,
                c.description AS container_description,
                c.location_code AS home_location_code,
                cs.current_stage_id,
                s.stage_key AS current_stage_key,
                s.stage_name AS current_stage_name,
                cs.current_location_note,
                tc.relationship_type,
                tc.notes AS relationship_notes
            FROM ref.setup_task_container_support AS tc
            JOIN ref.container AS c
              ON c.container_id = tc.container_id
            LEFT JOIN ops.setup_session AS ss
              ON ss.season_year = %s
            LEFT JOIN ops.setup_container_state AS cs
              ON cs.setup_session_id = ss.setup_session_id
             AND cs.container_id = c.container_id
            LEFT JOIN ref.stage AS s
              ON s.stage_id = cs.current_stage_id
            WHERE tc.setup_task_id = %s
            ORDER BY c.container_id
            """,
            (season_year, task_id),
        )
        support_containers = [dict(row) for row in cur.fetchall()]

    container_ids = sorted({
        int(item["container_id"])
        for item in displays
        if item.get("container_id") is not None
    })
    uncontained = sum(1 for item in displays if item.get("container_id") is None)

    resolution = {
        "requires_display_material": bool(task.get("requires_display_material")),
        "mode": mode,
        "stage_key": task.get("stage_key"),
        "lor_scene_id": real_scene_id,
        "scene_name": real_scene_name,
        "display_count": len(displays),
        "container_count": len(container_ids),
        "container_ids": container_ids,
        "uncontained_display_count": uncontained,
        "warning": warning,
    }

    return {
        "displays": displays,
        "support_containers": support_containers,
        "material_resolution": resolution,
    }


def install_setup_material_resolution() -> None:
    """Install the focused Setup behavior on the existing V0.3 repository class."""
    SetupNextRepository.organization = _organization
    SetupNextRepository.task_scope = _task_scope
    SetupNextRepository.execution_tasks = _execution_tasks
    SetupNextRepository.schedule = _schedule
    SetupNextRepository.field_context = _field_context
