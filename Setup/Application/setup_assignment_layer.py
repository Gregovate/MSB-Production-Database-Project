"""Corrected Issue #141 reusable physical-material assignment layer.

This module is installed after the rejected V0.3.12 Display-ownership layer so
we can preserve its reviewed exclusive-owner foundation while correcting its
first-use behavior and adding explicit Kit Box assignments.

Authority boundaries:
* LOR remains the source of current Stage/real-Scene Display membership.
* Display ownership is exclusive when explicit rows are materialized.
* Active tasks in the same effective Stage/Scene scope are assignment targets;
  they do not have to be pre-marked requires_display_material.
* Assigning a Display establishes requires_display_material=true through the
  governed database command.
* Kit Boxes are ref.container rows with container_type_id=2 and are independent
  of LOR. Task -> Kit Box is intentionally many-to-many.
"""
from __future__ import annotations

from collections import defaultdict
from typing import Any, Callable

from psycopg2.extras import RealDictCursor

from setup_material_resolution import is_real_setup_scene, is_stage_level_lor_group
from setup_next_repository import SetupNextRepository, SetupNextRepositoryError


_PRIOR_FIELD_CONTEXT: Callable[..., dict[str, Any]] | None = None


def _scope_key(stage_id: int | None, lor_scene_id: int | None, scene_name: str | None) -> tuple[str, int] | None:
    if stage_id is None:
        return None
    if lor_scene_id is not None and is_real_setup_scene(scene_name):
        return ("SCENE", int(lor_scene_id))
    return ("STAGE", int(stage_id))


def _scope_tasks(self: SetupNextRepository, task: dict[str, Any]) -> list[dict[str, Any]]:
    stage_id = task.get("stage_id")
    scope_key = _scope_key(stage_id, task.get("lor_scene_id"), task.get("scene_name"))
    if stage_id is None or scope_key is None:
        return []

    with self.connect() as conn, conn.cursor(cursor_factory=RealDictCursor) as cur:
        cur.execute(
            """
            SELECT
                t.setup_task_id,
                t.task_name,
                t.stage_id,
                t.lor_scene_id,
                ls.scene_name,
                t.task_action_type,
                t.display_order,
                t.active_flag,
                t.requires_display_material
            FROM ref.setup_task AS t
            LEFT JOIN ref.lor_scene AS ls
              ON ls.lor_scene_id = t.lor_scene_id
            WHERE t.stage_id = %s
              AND t.active_flag
            ORDER BY t.display_order, t.setup_task_id
            """,
            (stage_id,),
        )
        rows = [dict(row) for row in cur.fetchall()]

    return [
        row
        for row in rows
        if _scope_key(row.get("stage_id"), row.get("lor_scene_id"), row.get("scene_name")) == scope_key
    ]


def _source_displays(
    self: SetupNextRepository,
    *,
    task: dict[str, Any],
    season_year: int,
) -> list[dict[str, Any]]:
    """Resolve the current LOR source set independent of the task material flag."""
    stage_id = task.get("stage_id")
    if stage_id is None:
        return []

    real_scene_id = task.get("lor_scene_id") if is_real_setup_scene(task.get("scene_name")) else None
    display_sources: dict[int, dict[str, Any]] = {}

    with self.connect() as conn, conn.cursor(cursor_factory=RealDictCursor) as cur:
        if real_scene_id is not None:
            cur.execute(
                """
                SELECT lsd.display_id, ls.scene_name
                FROM ref.lor_scene_display AS lsd
                JOIN ref.lor_scene AS ls
                  ON ls.lor_scene_id = lsd.lor_scene_id
                WHERE lsd.lor_scene_id = %s
                ORDER BY lsd.display_id
                """,
                (real_scene_id,),
            )
            for row in cur.fetchall():
                display_sources[int(row["display_id"])] = {
                    "relationship_source": "LOR_SCENE",
                    "relationship_notes": "Derived automatically from current LOR Scene membership.",
                    "source_name": row.get("scene_name"),
                }
        else:
            cur.execute(
                """
                SELECT ls.scene_name, lsd.display_id
                FROM ref.lor_scene AS ls
                JOIN ref.lor_scene_display AS lsd
                  ON lsd.lor_scene_id = ls.lor_scene_id
                WHERE ls.stage_id = %s
                ORDER BY ls.scene_name, ls.lor_scene_id, lsd.display_id
                """,
                (stage_id,),
            )
            for row in cur.fetchall():
                if not is_stage_level_lor_group(row.get("scene_name")):
                    continue
                display_id = int(row["display_id"])
                entry = display_sources.setdefault(
                    display_id,
                    {
                        "relationship_source": "LOR_STAGE_LEVEL",
                        "relationship_notes": "Derived automatically from current Stage-level LOR grouping.",
                        "source_names": [],
                    },
                )
                name = str(row.get("scene_name") or "").strip()
                if name and name not in entry["source_names"]:
                    entry["source_names"].append(name)

        display_ids = sorted(display_sources)
        if not display_ids:
            return []

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
        rows = [dict(row) for row in cur.fetchall()]

    for row in rows:
        source = display_sources[int(row["display_id"])]
        row["relationship_type"] = "REQUIRED"
        row["relationship_source"] = source["relationship_source"]
        notes = [source["relationship_notes"]]
        source_names = source.get("source_names") or []
        if source_names:
            notes.append(f"LOR group(s): {', '.join(source_names)}")
        elif source.get("source_name"):
            notes.append(f"LOR group: {source['source_name']}")
        row["relationship_notes"] = " ".join(notes)
    return rows


def _owner_rows(
    self: SetupNextRepository,
    *,
    source_display_ids: list[int],
    candidate_task_ids: list[int],
) -> list[dict[str, Any]]:
    if not source_display_ids and not candidate_task_ids:
        return []

    clauses: list[str] = []
    params: list[Any] = []
    if source_display_ids:
        clauses.append("td.display_id = ANY(%s)")
        params.append(source_display_ids)
    if candidate_task_ids:
        clauses.append("td.setup_task_id = ANY(%s)")
        params.append(candidate_task_ids)

    with self.connect() as conn, conn.cursor(cursor_factory=RealDictCursor) as cur:
        cur.execute(
            f"""
            SELECT
                td.display_id,
                td.setup_task_id,
                owner.task_name AS owner_task_name,
                owner.stage_id AS owner_stage_id,
                owner.lor_scene_id AS owner_lor_scene_id,
                owner_scene.scene_name AS owner_scene_name,
                owner.active_flag AS owner_active_flag,
                owner.requires_display_material AS owner_requires_display_material,
                td.relationship_type,
                td.notes,
                td.updated_at,
                td.updated_by_person_id
            FROM ref.setup_task_display AS td
            JOIN ref.setup_task AS owner
              ON owner.setup_task_id = td.setup_task_id
            LEFT JOIN ref.lor_scene AS owner_scene
              ON owner_scene.lor_scene_id = owner.lor_scene_id
            WHERE {' OR '.join(clauses)}
            ORDER BY td.display_id, td.setup_task_id
            """,
            tuple(params),
        )
        return [dict(row) for row in cur.fetchall()]


def _apply_assignment_layer(
    self: SetupNextRepository,
    *,
    task_id: int,
    season_year: int,
    base_context: dict[str, Any],
) -> dict[str, Any]:
    context = dict(base_context)
    context["support_containers"] = [dict(row) for row in base_context.get("support_containers", [])]
    context["material_resolution"] = dict(base_context.get("material_resolution") or {})

    task = self.task_scope(task_id)
    scope_key = _scope_key(task.get("stage_id"), task.get("lor_scene_id"), task.get("scene_name"))
    candidate_tasks = _scope_tasks(self, task)
    candidate_ids = [int(row["setup_task_id"]) for row in candidate_tasks]
    candidate_id_set = set(candidate_ids)
    material_tasks = [row for row in candidate_tasks if bool(row.get("requires_display_material"))]

    source_displays = _source_displays(self, task=task, season_year=season_year)
    source_by_id = {int(row["display_id"]): dict(row) for row in source_displays}
    source_ids = sorted(source_by_id)
    source_id_set = set(source_ids)

    owner_rows = _owner_rows(
        self,
        source_display_ids=source_ids,
        candidate_task_ids=candidate_ids,
    )
    owners_by_display: dict[int, list[dict[str, Any]]] = defaultdict(list)
    for row in owner_rows:
        owners_by_display[int(row["display_id"])].append(row)

    explicit_source_rows = [row for row in owner_rows if int(row["display_id"]) in source_id_set]
    explicit_mode = bool(explicit_source_rows)
    sole_implicit_owner = int(material_tasks[0]["setup_task_id"]) if len(material_tasks) == 1 else None

    assignments: list[dict[str, Any]] = []
    assigned_count = 0
    missing_count = 0
    invalid_owner_count = 0
    duplicate_count = 0

    for display_id in source_ids:
        display = dict(source_by_id[display_id])
        owners = owners_by_display.get(display_id, [])
        valid_owners = [row for row in owners if int(row["setup_task_id"]) in candidate_id_set]

        if len(owners) > 1:
            state = "DUPLICATE"
            duplicate_count += 1
            owner = valid_owners[0] if valid_owners else owners[0]
        elif len(valid_owners) == 1:
            state = "ASSIGNED"
            assigned_count += 1
            owner = valid_owners[0]
        elif owners:
            state = "INVALID_OWNER"
            invalid_owner_count += 1
            owner = owners[0]
        elif not explicit_mode and sole_implicit_owner is not None:
            state = "IMPLICIT"
            owner = next(
                row for row in candidate_tasks
                if int(row["setup_task_id"]) == sole_implicit_owner
            )
            assigned_count += 1
        else:
            state = "UNASSIGNED"
            missing_count += 1
            owner = None

        assignments.append({
            **display,
            "ownership_state": state,
            "owner_setup_task_id": int(owner["setup_task_id"]) if owner else None,
            "owner_task_name": owner.get("owner_task_name", owner.get("task_name")) if owner else None,
        })

    stale_rows = [
        row for row in owner_rows
        if int(row["setup_task_id"]) in candidate_id_set
        and int(row["display_id"]) not in source_id_set
    ]

    if explicit_mode:
        ownership_mode = "EXPLICIT_MULTI"
        coverage_status = (
            "COMPLETE"
            if assigned_count == len(source_displays)
            and missing_count == 0
            and invalid_owner_count == 0
            and duplicate_count == 0
            and not stale_rows
            else "REVIEW_REQUIRED"
        )
        effective_displays = [
            dict(source_by_id[int(item["display_id"])])
            for item in assignments
            if item.get("ownership_state") == "ASSIGNED"
            and int(item.get("owner_setup_task_id") or 0) == int(task_id)
        ]
    elif len(candidate_tasks) > 1 and source_displays:
        # Assignment can begin from an untouched Production state. Existing
        # single-task material behavior remains effective until explicit rows
        # are created.
        ownership_mode = "UNINITIALIZED_MULTI"
        coverage_status = "COMPLETE" if sole_implicit_owner is not None else "REVIEW_REQUIRED"
        effective_displays = source_displays if sole_implicit_owner == int(task_id) else []
    elif bool(task.get("requires_display_material")):
        ownership_mode = "IMPLICIT_SINGLE"
        coverage_status = "COMPLETE"
        effective_displays = source_displays
    else:
        ownership_mode = "NOT_APPLICABLE"
        coverage_status = "NOT_APPLICABLE"
        effective_displays = []

    container_ids = sorted({
        int(row["container_id"])
        for row in effective_displays
        if row.get("container_id") is not None
    })
    uncontained = sum(1 for row in effective_displays if row.get("container_id") is None)

    resolution = context["material_resolution"]
    resolution["requires_display_material"] = bool(task.get("requires_display_material"))
    resolution["display_count"] = len(effective_displays)
    resolution["container_count"] = len(container_ids)
    resolution["container_ids"] = container_ids
    resolution["uncontained_display_count"] = uncontained
    resolution["source_display_count"] = len(source_displays)
    resolution["ownership_mode"] = ownership_mode
    resolution["ownership_status"] = coverage_status
    if coverage_status == "REVIEW_REQUIRED":
        resolution["warning"] = (
            "Display assignment coverage requires Manager review before task-specific material demand is complete."
        )
    elif resolution.get("warning") and ownership_mode != "EXPLICIT_MULTI":
        resolution["warning"] = None

    context["displays"] = effective_displays
    context["display_ownership"] = {
        "mode": ownership_mode,
        "coverage_status": coverage_status,
        "scope_type": scope_key[0] if scope_key else None,
        "stage_id": task.get("stage_id"),
        "lor_scene_id": task.get("lor_scene_id"),
        "scene_name": task.get("scene_name"),
        "selected_setup_task_id": int(task_id),
        "eligible_tasks": candidate_tasks,
        "material_tasks": material_tasks,
        "assignments": assignments,
        "stale_assignments": stale_rows,
        "resolved_display_count": len(source_displays),
        "assigned_display_count": assigned_count,
        "missing_owner_count": missing_count,
        "invalid_owner_count": invalid_owner_count,
        "duplicate_owner_count": duplicate_count,
        "stale_owner_count": len(stale_rows),
        "explicit_owner_count": len(explicit_source_rows),
        "sole_implicit_owner_setup_task_id": sole_implicit_owner,
        "can_initialize": bool(
            len(candidate_tasks) > 1
            and source_displays
            and not explicit_source_rows
        ),
    }
    return context


def _field_context(
    self: SetupNextRepository,
    *,
    task_id: int,
    season_year: int,
) -> dict[str, Any]:
    if _PRIOR_FIELD_CONTEXT is None:
        raise SetupNextRepositoryError("Setup assignment layer is not installed correctly")
    base_context = _PRIOR_FIELD_CONTEXT(self, task_id=task_id, season_year=season_year)
    return _apply_assignment_layer(
        self,
        task_id=task_id,
        season_year=season_year,
        base_context=base_context,
    )


def _initialize_display_ownership(
    self: SetupNextRepository,
    *,
    email: str,
    task_id: int,
    season_year: int,
) -> dict[str, Any]:
    preview = self.field_context(task_id=task_id, season_year=season_year)
    ownership = preview.get("display_ownership") or {}
    if not ownership.get("can_initialize"):
        raise SetupNextRepositoryError(
            "Display assignment is already explicit or this scope does not need task subdivision"
        )

    candidate_ids = {int(row["setup_task_id"]) for row in ownership.get("eligible_tasks") or []}
    if int(task_id) not in candidate_ids:
        raise SetupNextRepositoryError("Selected task is outside the current Stage/Scene assignment scope")

    source_ids = [int(row["display_id"]) for row in ownership.get("assignments") or []]
    if not source_ids:
        raise SetupNextRepositoryError("No current resolved Displays are available to initialize")

    with self.write_connect() as conn, conn.cursor(cursor_factory=RealDictCursor) as cur:
        for display_id in source_ids:
            cur.execute(
                "SELECT * FROM ref.set_setup_task_display_owner(%s,%s,%s,%s)",
                (email, display_id, task_id, None),
            )
            if cur.fetchone() is None:
                raise SetupNextRepositoryError("Setup Display owner command returned no result")
        conn.commit()

    return self.field_context(task_id=task_id, season_year=season_year)


def _set_display_owner(
    self: SetupNextRepository,
    *,
    email: str,
    context_task_id: int,
    display_id: int,
    target_task_id: int,
    season_year: int,
) -> dict[str, Any]:
    preview = self.field_context(task_id=context_task_id, season_year=season_year)
    ownership = preview.get("display_ownership") or {}
    candidate_ids = {int(row["setup_task_id"]) for row in ownership.get("eligible_tasks") or []}
    if int(target_task_id) not in candidate_ids:
        raise SetupNextRepositoryError("Target task is outside the current Stage/Scene assignment scope")

    assignment = next(
        (
            row for row in ownership.get("assignments") or []
            if int(row["display_id"]) == int(display_id)
        ),
        None,
    )
    if assignment is None:
        raise SetupNextRepositoryError("Display is not in the current LOR resolver source set for this scope")
    if assignment.get("ownership_state") == "DUPLICATE":
        raise SetupNextRepositoryError("Display has duplicate ownership rows and must be reconciled before moving")

    current_owner = assignment.get("owner_setup_task_id")
    if current_owner is not None and int(current_owner) == int(target_task_id):
        return preview

    explicit_count = int(ownership.get("explicit_owner_count") or 0)
    implicit_owner = ownership.get("sole_implicit_owner_setup_task_id")

    with self.write_connect() as conn, conn.cursor(cursor_factory=RealDictCursor) as cur:
        expected_source = int(current_owner) if current_owner is not None else None

        # Convert the accepted simple implicit state into complete explicit
        # coverage before moving the first Display to another task. This avoids
        # making all untouched Displays disappear from material coverage.
        if explicit_count == 0 and implicit_owner is not None:
            implicit_owner = int(implicit_owner)
            source_ids = [int(row["display_id"]) for row in ownership.get("assignments") or []]
            for source_id in source_ids:
                cur.execute(
                    "SELECT * FROM ref.set_setup_task_display_owner(%s,%s,%s,%s)",
                    (email, source_id, implicit_owner, None),
                )
                if cur.fetchone() is None:
                    raise SetupNextRepositoryError("Setup Display owner command returned no result")
            expected_source = implicit_owner

        cur.execute(
            "SELECT * FROM ref.set_setup_task_display_owner(%s,%s,%s,%s)",
            (email, int(display_id), int(target_task_id), expected_source),
        )
        if cur.fetchone() is None:
            raise SetupNextRepositoryError("Setup Display owner command returned no result")
        conn.commit()

    return self.field_context(task_id=context_task_id, season_year=season_year)


def _kit_box_catalog(self: SetupNextRepository, *, task_id: int) -> list[dict[str, Any]]:
    with self.connect() as conn, conn.cursor(cursor_factory=RealDictCursor) as cur:
        cur.execute(
            """
            SELECT t.setup_task_id, t.active_flag, t.stage_id
            FROM ref.setup_task AS t
            WHERE t.setup_task_id = %s
            """,
            (task_id,),
        )
        task = cur.fetchone()
        if task is None:
            raise SetupNextRepositoryError("Setup task was not found")

        cur.execute(
            """
            SELECT
                c.container_id,
                c.description AS container_description,
                c.location_code AS home_location_code,
                c.container_type_id,
                ct.container_type_name,
                (current_tc.container_id IS NOT NULL) AS assigned,
                current_tc.notes AS assignment_notes,
                coalesce(shared.other_task_count, 0) AS other_task_count,
                shared.other_task_assignments
            FROM ref.container AS c
            JOIN ref.container_type AS ct
              ON ct.container_type_id = c.container_type_id
            LEFT JOIN ref.setup_task_container_support AS current_tc
              ON current_tc.setup_task_id = %s
             AND current_tc.container_id = c.container_id
             AND current_tc.relationship_type = 'KIT'
            LEFT JOIN LATERAL (
                SELECT
                    count(*) AS other_task_count,
                    string_agg(
                        coalesce(s.stage_key || ' · ', '') || other_t.task_name,
                        '; ' ORDER BY s.park_order NULLS LAST,
                                     s.sub_order NULLS LAST,
                                     s.stage_key,
                                     other_t.display_order,
                                     other_t.setup_task_id
                    ) AS other_task_assignments
                FROM ref.setup_task_container_support AS other_tc
                JOIN ref.setup_task AS other_t
                  ON other_t.setup_task_id = other_tc.setup_task_id
                LEFT JOIN ref.stage AS s
                  ON s.stage_id = other_t.stage_id
                WHERE other_tc.container_id = c.container_id
                  AND other_tc.relationship_type = 'KIT'
                  AND other_tc.setup_task_id <> %s
            ) AS shared ON true
            WHERE c.container_type_id = 2
            ORDER BY lower(coalesce(c.description, '')), c.container_id
            """,
            (task_id, task_id),
        )
        return [dict(row) for row in cur.fetchall()]


def _set_kit_box_assignment(
    self: SetupNextRepository,
    *,
    email: str,
    task_id: int,
    container_id: int,
    assigned: bool,
    notes: str | None = None,
) -> list[dict[str, Any]]:
    with self.write_connect() as conn, conn.cursor(cursor_factory=RealDictCursor) as cur:
        cur.execute(
            """
            SELECT *
            FROM ref.set_setup_task_kit_box_assignment(%s,%s,%s,%s,%s)
            """,
            (email, task_id, container_id, bool(assigned), notes),
        )
        if cur.fetchone() is None:
            raise SetupNextRepositoryError("Setup Kit Box assignment command returned no result")
        conn.commit()
    return self.kit_box_catalog(task_id=task_id)


def install_setup_assignment_layer() -> None:
    """Install the corrected #141 behavior after the rejected ownership layer."""
    global _PRIOR_FIELD_CONTEXT
    if _PRIOR_FIELD_CONTEXT is not None:
        return
    _PRIOR_FIELD_CONTEXT = SetupNextRepository.field_context
    SetupNextRepository.field_context = _field_context
    SetupNextRepository.initialize_display_ownership = _initialize_display_ownership
    SetupNextRepository.set_display_owner = _set_display_owner
    SetupNextRepository.kit_box_catalog = _kit_box_catalog
    SetupNextRepository.set_kit_box_assignment = _set_kit_box_assignment
