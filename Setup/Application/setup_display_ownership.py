"""Task-specific Setup Display ownership layered after the accepted LOR resolver.

Issue #141 does not replace Stage/real-Scene material resolution. This module
consumes the resolver's current source set and applies explicit
``ref.setup_task_display`` ownership only when one effective Setup scope has
multiple active material-bearing reusable tasks.

Simple scopes with one material-bearing task remain implicit and behave exactly
as the accepted resolver does today. Complex scopes require complete exclusive
ownership coverage before task-specific material demand is considered complete.
"""
from __future__ import annotations

from collections import defaultdict
from typing import Any, Callable

from psycopg2.extras import RealDictCursor

from setup_material_resolution import is_real_setup_scene
from setup_next_repository import SetupNextRepository, SetupNextRepositoryError


_BASE_FIELD_CONTEXT: Callable[..., dict[str, Any]] | None = None


def _scope_key(stage_id: int | None, lor_scene_id: int | None, scene_name: str | None) -> tuple[str, int] | None:
    if stage_id is None:
        return None
    if lor_scene_id is not None and is_real_setup_scene(scene_name):
        return ("SCENE", int(lor_scene_id))
    return ("STAGE", int(stage_id))


def _lor_source_row(row: dict[str, Any]) -> bool:
    sources = {
        item.strip()
        for item in str(row.get("relationship_source") or "").split(",")
        if item.strip()
    }
    return bool({"LOR_SCENE", "LOR_STAGE_LEVEL"} & sources)


def _scope_material_tasks(
    self: SetupNextRepository,
    *,
    stage_id: int | None,
    scope_key: tuple[str, int] | None,
) -> list[dict[str, Any]]:
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
                t.display_order,
                t.active_flag,
                t.requires_display_material
            FROM ref.setup_task AS t
            LEFT JOIN ref.lor_scene AS ls
              ON ls.lor_scene_id = t.lor_scene_id
            WHERE t.stage_id = %s
              AND t.active_flag
              AND t.requires_display_material
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


def _ownership_rows(
    self: SetupNextRepository,
    *,
    source_display_ids: list[int],
    eligible_task_ids: list[int],
) -> list[dict[str, Any]]:
    if not source_display_ids and not eligible_task_ids:
        return []

    clauses: list[str] = []
    params: list[Any] = []
    if source_display_ids:
        clauses.append("td.display_id = ANY(%s)")
        params.append(source_display_ids)
    if eligible_task_ids:
        clauses.append("td.setup_task_id = ANY(%s)")
        params.append(eligible_task_ids)

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


def _apply_display_ownership(
    self: SetupNextRepository,
    *,
    task_id: int,
    season_year: int,
    source_context: dict[str, Any],
) -> dict[str, Any]:
    context = dict(source_context)
    context["displays"] = [dict(row) for row in source_context.get("displays", [])]
    context["support_containers"] = [dict(row) for row in source_context.get("support_containers", [])]
    context["material_resolution"] = dict(source_context.get("material_resolution") or {})

    task = self.task_scope(task_id)
    requires_display_material = bool(task.get("requires_display_material"))
    scope_key = _scope_key(task.get("stage_id"), task.get("lor_scene_id"), task.get("scene_name"))

    source_displays = [
        dict(row)
        for row in source_context.get("displays", [])
        if _lor_source_row(dict(row))
    ]
    source_display_ids = sorted({int(row["display_id"]) for row in source_displays})

    eligible_tasks = _scope_material_tasks(
        self,
        stage_id=task.get("stage_id"),
        scope_key=scope_key,
    ) if requires_display_material else []
    eligible_task_ids = [int(row["setup_task_id"]) for row in eligible_tasks]
    eligible_task_id_set = set(eligible_task_ids)

    owner_rows = _ownership_rows(
        self,
        source_display_ids=source_display_ids,
        eligible_task_ids=eligible_task_ids,
    ) if requires_display_material else []

    owners_by_display: dict[int, list[dict[str, Any]]] = defaultdict(list)
    for row in owner_rows:
        owners_by_display[int(row["display_id"])].append(row)

    assignments: list[dict[str, Any]] = []
    assigned_count = 0
    missing_count = 0
    invalid_owner_count = 0
    duplicate_count = 0

    source_by_id = {int(row["display_id"]): row for row in source_displays}
    for display_id in source_display_ids:
        display = dict(source_by_id[display_id])
        owners = owners_by_display.get(display_id, [])
        valid_owners = [
            row for row in owners
            if int(row["setup_task_id"]) in eligible_task_id_set
        ]

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
        else:
            state = "UNASSIGNED"
            missing_count += 1
            owner = None

        assignments.append({
            **display,
            "ownership_state": state,
            "owner_setup_task_id": int(owner["setup_task_id"]) if owner else None,
            "owner_task_name": owner.get("owner_task_name") if owner else None,
        })

    source_display_id_set = set(source_display_ids)
    stale_rows = [
        row
        for row in owner_rows
        if int(row["setup_task_id"]) in eligible_task_id_set
        and int(row["display_id"]) not in source_display_id_set
    ]

    if not requires_display_material:
        ownership_mode = "NOT_APPLICABLE"
        coverage_status = "NOT_APPLICABLE"
        effective_displays: list[dict[str, Any]] = []
    elif len(eligible_tasks) <= 1:
        # Preserve the accepted simple-scope behavior. Explicit rows are not
        # required merely to restate the only possible effective owner.
        ownership_mode = "IMPLICIT_SINGLE"
        coverage_status = "COMPLETE"
        effective_displays = source_displays
        selected_owner_id = eligible_task_ids[0] if eligible_task_ids else int(task_id)
        for assignment in assignments:
            assignment["ownership_state"] = "IMPLICIT"
            assignment["owner_setup_task_id"] = selected_owner_id
            assignment["owner_task_name"] = next(
                (
                    row.get("task_name")
                    for row in eligible_tasks
                    if int(row["setup_task_id"]) == selected_owner_id
                ),
                task.get("task_name"),
            )
        assigned_count = len(source_displays)
        missing_count = 0
        invalid_owner_count = 0
        duplicate_count = 0
    else:
        explicit_source_rows = [
            row for row in owner_rows
            if int(row["display_id"]) in source_display_id_set
        ]
        ownership_mode = "UNINITIALIZED_MULTI" if not explicit_source_rows else "EXPLICIT_MULTI"
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
            dict(source_by_id[item["display_id"]])
            for item in assignments
            if item.get("ownership_state") == "ASSIGNED"
            and int(item.get("owner_setup_task_id") or 0) == int(task_id)
        ]

    container_ids = sorted({
        int(row["container_id"])
        for row in effective_displays
        if row.get("container_id") is not None
    })
    uncontained = sum(1 for row in effective_displays if row.get("container_id") is None)

    resolution = context["material_resolution"]
    resolution["display_count"] = len(effective_displays)
    resolution["container_count"] = len(container_ids)
    resolution["container_ids"] = container_ids
    resolution["uncontained_display_count"] = uncontained
    resolution["source_display_count"] = len(source_displays)
    resolution["ownership_mode"] = ownership_mode
    resolution["ownership_status"] = coverage_status
    if coverage_status == "REVIEW_REQUIRED":
        resolution["warning"] = (
            "Display ownership coverage requires Manager review before this scope can provide complete task-specific material demand."
        )

    context["displays"] = effective_displays
    context["display_ownership"] = {
        "mode": ownership_mode,
        "coverage_status": coverage_status,
        "scope_type": scope_key[0] if scope_key else None,
        "stage_id": task.get("stage_id"),
        "lor_scene_id": task.get("lor_scene_id"),
        "scene_name": task.get("scene_name"),
        "selected_setup_task_id": int(task_id),
        "eligible_tasks": eligible_tasks,
        "assignments": assignments,
        "stale_assignments": stale_rows,
        "resolved_display_count": len(source_displays),
        "assigned_display_count": assigned_count,
        "missing_owner_count": missing_count,
        "invalid_owner_count": invalid_owner_count,
        "duplicate_owner_count": duplicate_count,
        "stale_owner_count": len(stale_rows),
        "can_initialize": bool(
            requires_display_material
            and len(eligible_tasks) > 1
            and ownership_mode == "UNINITIALIZED_MULTI"
            and source_displays
        ),
    }
    return context


def _field_context_with_display_ownership(
    self: SetupNextRepository,
    *,
    task_id: int,
    season_year: int,
) -> dict[str, Any]:
    if _BASE_FIELD_CONTEXT is None:
        raise SetupNextRepositoryError("Setup Display ownership layer is not installed correctly")
    source_context = _BASE_FIELD_CONTEXT(self, task_id=task_id, season_year=season_year)
    return _apply_display_ownership(
        self,
        task_id=task_id,
        season_year=season_year,
        source_context=source_context,
    )


def _initialize_display_ownership(
    self: SetupNextRepository,
    *,
    email: str,
    task_id: int,
    season_year: int,
) -> dict[str, Any]:
    if _BASE_FIELD_CONTEXT is None:
        raise SetupNextRepositoryError("Setup Display ownership layer is not installed correctly")

    source_context = _BASE_FIELD_CONTEXT(self, task_id=task_id, season_year=season_year)
    preview = _apply_display_ownership(
        self,
        task_id=task_id,
        season_year=season_year,
        source_context=source_context,
    )
    ownership = preview.get("display_ownership") or {}
    if ownership.get("mode") != "UNINITIALIZED_MULTI":
        raise SetupNextRepositoryError(
            "Display ownership is already initialized or this scope does not require explicit subdivision"
        )

    eligible_ids = {
        int(row["setup_task_id"])
        for row in ownership.get("eligible_tasks") or []
    }
    if int(task_id) not in eligible_ids:
        raise SetupNextRepositoryError("Selected task is not eligible to own Displays in this scope")

    source_ids = [
        int(row["display_id"])
        for row in ownership.get("assignments") or []
    ]
    if not source_ids:
        raise SetupNextRepositoryError("No current resolved Displays are available to initialize")

    with self.write_connect() as conn, conn.cursor(cursor_factory=RealDictCursor) as cur:
        for display_id in source_ids:
            cur.execute(
                """
                SELECT *
                FROM ref.set_setup_task_display_owner(%s,%s,%s,%s)
                """,
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
    if _BASE_FIELD_CONTEXT is None:
        raise SetupNextRepositoryError("Setup Display ownership layer is not installed correctly")

    source_context = _BASE_FIELD_CONTEXT(self, task_id=context_task_id, season_year=season_year)
    preview = _apply_display_ownership(
        self,
        task_id=context_task_id,
        season_year=season_year,
        source_context=source_context,
    )
    ownership = preview.get("display_ownership") or {}
    eligible_ids = {
        int(row["setup_task_id"])
        for row in ownership.get("eligible_tasks") or []
    }
    if len(eligible_ids) <= 1:
        raise SetupNextRepositoryError("This scope does not require explicit Display ownership")
    if int(target_task_id) not in eligible_ids:
        raise SetupNextRepositoryError("Target task is outside the applicable material-owning Setup scope")

    assignment = next(
        (
            row
            for row in ownership.get("assignments") or []
            if int(row["display_id"]) == int(display_id)
        ),
        None,
    )
    if assignment is None:
        raise SetupNextRepositoryError("Display is not in the current resolver source set for this scope")
    if assignment.get("ownership_state") == "DUPLICATE":
        raise SetupNextRepositoryError("Display has duplicate ownership rows and must be reconciled before moving")

    expected_source = assignment.get("owner_setup_task_id")
    with self.write_connect() as conn, conn.cursor(cursor_factory=RealDictCursor) as cur:
        cur.execute(
            """
            SELECT *
            FROM ref.set_setup_task_display_owner(%s,%s,%s,%s)
            """,
            (
                email,
                int(display_id),
                int(target_task_id),
                int(expected_source) if expected_source is not None else None,
            ),
        )
        if cur.fetchone() is None:
            raise SetupNextRepositoryError("Setup Display owner command returned no result")
        conn.commit()

    return self.field_context(task_id=context_task_id, season_year=season_year)


def install_setup_display_ownership() -> None:
    """Install #141 ownership behavior after automatic material resolution."""
    global _BASE_FIELD_CONTEXT
    if _BASE_FIELD_CONTEXT is not None:
        return
    _BASE_FIELD_CONTEXT = SetupNextRepository.field_context
    SetupNextRepository.field_context = _field_context_with_display_ownership
    SetupNextRepository.initialize_display_ownership = _initialize_display_ownership
    SetupNextRepository.set_display_owner = _set_display_owner
