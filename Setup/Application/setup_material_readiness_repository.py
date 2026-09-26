"""Material-readiness resolver for Setup #206.

The read path consumes the accepted schedule and existing reusable material
authorities. The only write path is the narrow governed Manager early-pick
override command. It performs no movement writes, does not schedule work, and
does not invent a second mutable current-location field.
"""
from __future__ import annotations

from collections import defaultdict
from contextlib import contextmanager
from typing import Any, Iterator

import psycopg2
from psycopg2.extras import RealDictCursor

from setup_material_readiness_projection import (
    downstream_material_frontier,
    project_physical_demand,
)
from setup_next_repository import SetupNextRepository, SetupNextRepositoryError


class SetupMaterialReadinessRepositoryError(RuntimeError):
    pass


class SetupMaterialReadinessRepository:
    def __init__(self, dsn: str):
        self.dsn = (dsn or "").strip()
        if not self.dsn:
            raise SetupMaterialReadinessRepositoryError("Setup PostgreSQL DSN is required")

    @contextmanager
    def connect(self) -> Iterator[Any]:
        conn = psycopg2.connect(self.dsn)
        try:
            yield conn
        finally:
            conn.close()

    @contextmanager
    def write_connect(self) -> Iterator[Any]:
        conn = psycopg2.connect(self.dsn)
        try:
            conn.set_session(readonly=False, autocommit=False)
            yield conn
        finally:
            conn.close()

    @staticmethod
    def _one(cur: Any, message: str) -> dict[str, Any]:
        row = cur.fetchone()
        if row is None:
            raise SetupMaterialReadinessRepositoryError(message)
        return dict(row)

    def _scheduled_work(self, setup_session_id: int) -> list[dict[str, Any]]:
        with self.connect() as conn, conn.cursor(cursor_factory=RealDictCursor) as cur:
            cur.execute(
                """
                SELECT
                    wdt.setup_work_day_task_id,
                    wdt.setup_work_day_id,
                    wd.setup_day_number,
                    wd.work_date::text AS work_date,
                    wdt.setup_session_task_id,
                    st.setup_task_id,
                    st.task_origin,
                    st.annual_task_name AS task_name,
                    st.annual_stage_id AS stage_id,
                    s.stage_key,
                    s.stage_name,
                    st.annual_lor_scene_id AS lor_scene_id,
                    ls.scene_name,
                    wdt.shift_code,
                    coalesce(c.crew_code, wdt.crew_lane) AS crew_lane,
                    wdt.sort_order
                FROM ops.setup_work_day_task AS wdt
                JOIN ops.setup_work_day AS wd
                  ON wd.setup_work_day_id = wdt.setup_work_day_id
                JOIN ops.setup_session_task AS st
                  ON st.setup_session_task_id = wdt.setup_session_task_id
                LEFT JOIN ops.setup_work_day_crew AS c
                  ON c.setup_work_day_crew_id = wdt.setup_work_day_crew_id
                LEFT JOIN ref.stage AS s
                  ON s.stage_id = st.annual_stage_id
                LEFT JOIN ref.lor_scene AS ls
                  ON ls.lor_scene_id = st.annual_lor_scene_id
                WHERE wd.setup_session_id = %s
                  AND wd.day_status <> 'CANCELLED'
                  AND st.included_flag
                  AND wd.work_date >= current_date
                ORDER BY wd.work_date,
                         wd.setup_day_number,
                         CASE wdt.shift_code
                             WHEN 'MORNING' THEN 1
                             WHEN 'AFTERNOON' THEN 2
                             ELSE 3
                         END,
                         coalesce(c.crew_number, 999999),
                         wdt.sort_order,
                         wdt.setup_work_day_task_id
                """,
                (setup_session_id,),
            )
            return [dict(row) for row in cur.fetchall()]


    def _annual_demand_graph(
        self, setup_session_id: int
    ) -> tuple[dict[int, dict[str, Any]], dict[int, list[int]]]:
        """Read the annual prerequisite graph used by the Scheduling Board."""
        with self.connect() as conn, conn.cursor(cursor_factory=RealDictCursor) as cur:
            cur.execute(
                """
                SELECT
                    st.setup_session_task_id,
                    st.setup_task_id,
                    st.task_origin,
                    st.annual_task_name AS task_name,
                    st.annual_stage_id AS stage_id,
                    s.stage_key,
                    s.stage_name,
                    st.annual_lor_scene_id AS lor_scene_id,
                    ls.scene_name,
                    st.execution_status,
                    st.planned_order
                FROM ops.setup_session_task AS st
                LEFT JOIN ref.stage AS s ON s.stage_id = st.annual_stage_id
                LEFT JOIN ref.lor_scene AS ls ON ls.lor_scene_id = st.annual_lor_scene_id
                WHERE st.setup_session_id = %s
                  AND st.included_flag
                """,
                (setup_session_id,),
            )
            tasks = {
                int(row["setup_session_task_id"]): dict(row)
                for row in cur.fetchall()
            }
            cur.execute(
                """
                WITH reusable_current AS (
                    SELECT
                        st.setup_session_task_id,
                        pst.setup_session_task_id AS prerequisite_setup_session_task_id
                    FROM ops.setup_session_task AS st
                    JOIN ref.setup_task_dependency AS rd
                      ON rd.setup_task_id = st.setup_task_id
                    JOIN ops.setup_session_task AS pst
                      ON pst.setup_session_id = st.setup_session_id
                     AND pst.setup_task_id = rd.prerequisite_setup_task_id
                    WHERE st.setup_session_id = %s
                      AND st.task_origin = 'REUSABLE'
                      AND st.included_flag
                      AND pst.included_flag
                ),
                annual_explicit AS (
                    SELECT
                        ad.setup_session_task_id,
                        ad.prerequisite_setup_session_task_id
                    FROM ops.setup_session_task_dependency AS ad
                    JOIN ops.setup_session_task AS st
                      ON st.setup_session_task_id = ad.setup_session_task_id
                    JOIN ops.setup_session_task AS pst
                      ON pst.setup_session_task_id = ad.prerequisite_setup_session_task_id
                    WHERE st.setup_session_id = %s
                      AND st.included_flag
                      AND pst.included_flag
                      AND (
                          st.task_origin = 'SEASON_ONLY'
                          OR (
                              ad.dependency_origin = 'ANNUAL'
                              AND NOT EXISTS (
                                  SELECT 1
                                  FROM ref.setup_task_dependency AS rd
                                  WHERE rd.setup_task_id = st.setup_task_id
                                    AND rd.prerequisite_setup_task_id = pst.setup_task_id
                              )
                          )
                      )
                )
                SELECT * FROM reusable_current
                UNION ALL
                SELECT * FROM annual_explicit
                """,
                (setup_session_id, setup_session_id),
            )
            downstream: dict[int, list[int]] = defaultdict(list)
            for row in cur.fetchall():
                prerequisite_id = int(row["prerequisite_setup_session_task_id"])
                downstream[prerequisite_id].append(int(row["setup_session_task_id"]))
        return tasks, dict(downstream)



    def _material_bearing_session_task_ids(
        self, setup_session_id: int
    ) -> set[int]:
        """Return annual tasks with real reusable material authority."""
        with self.connect() as conn, conn.cursor(cursor_factory=RealDictCursor) as cur:
            cur.execute(
                """
                SELECT st.setup_session_task_id
                FROM ops.setup_session_task AS st
                JOIN ref.setup_task AS t ON t.setup_task_id = st.setup_task_id
                WHERE st.setup_session_id = %s
                  AND st.included_flag
                  AND (
                      EXISTS (
                          SELECT 1
                          FROM ref.setup_task_display AS td
                          WHERE td.setup_task_id = t.setup_task_id
                      )
                      OR (
                          t.lor_scene_id IS NOT NULL
                          AND EXISTS (
                              SELECT 1
                              FROM ref.lor_scene_display AS lsd
                              WHERE lsd.lor_scene_id = t.lor_scene_id
                          )
                      )
                      OR EXISTS (
                          SELECT 1
                          FROM ref.setup_task_container_support AS tc
                          WHERE tc.setup_task_id = t.setup_task_id
                      )
                      OR EXISTS (
                          SELECT 1
                          FROM ref.setup_task_extra_material AS tm
                          JOIN ref.setup_extra_material AS m
                            ON m.setup_extra_material_id = tm.setup_extra_material_id
                          WHERE tm.setup_task_id = t.setup_task_id
                            AND tm.active_flag
                            AND m.active_flag
                      )
                  )
                """,
                (setup_session_id,),
            )
            return {int(row["setup_session_task_id"]) for row in cur.fetchall()}


    def _extra_material_rows(self, task_ids: list[int], season_year: int) -> list[dict[str, Any]]:
        if not task_ids:
            return []
        with self.connect() as conn, conn.cursor(cursor_factory=RealDictCursor) as cur:
            cur.execute(
                """
                SELECT
                    tm.setup_task_id,
                    tm.setup_task_extra_material_id,
                    m.setup_extra_material_id,
                    m.material_name,
                    tm.quantity_required,
                    tm.quantity_uom,
                    tm.quantity_qualifier,
                    tm.size_text,
                    tm.length_value,
                    tm.length_unit,
                    tm.color,
                    tm.notes AS requirement_notes,
                    tm.verification_state AS requirement_verification_state,
                    src.setup_task_extra_material_source_id,
                    src.container_id,
                    src.expected_quantity,
                    src.verification_state AS source_verification_state,
                    c.description AS container_description,
                    c.location_code AS home_location_code,
                    cs.current_stage_id,
                    current_stage.stage_key AS current_stage_key,
                    current_stage.stage_name AS current_stage_name,
                    cs.current_location_note,
                    cs.last_movement_event_id
                FROM ref.setup_task_extra_material AS tm
                JOIN ref.setup_extra_material AS m
                  ON m.setup_extra_material_id = tm.setup_extra_material_id
                LEFT JOIN ref.setup_task_extra_material_source AS src
                  ON src.setup_task_extra_material_id = tm.setup_task_extra_material_id
                 AND src.active_flag
                LEFT JOIN ref.container AS c
                  ON c.container_id = src.container_id
                LEFT JOIN ops.setup_session AS ss
                  ON ss.season_year = %s
                LEFT JOIN ops.setup_container_state AS cs
                  ON cs.setup_session_id = ss.setup_session_id
                 AND cs.container_id = src.container_id
                LEFT JOIN ref.stage AS current_stage
                  ON current_stage.stage_id = cs.current_stage_id
                WHERE tm.setup_task_id = ANY(%s)
                  AND tm.active_flag
                  AND m.active_flag
                ORDER BY tm.setup_task_id,
                         m.display_order,
                         m.material_name,
                         tm.setup_task_extra_material_id,
                         src.container_id
                """,
                (season_year, task_ids),
            )
            return [dict(row) for row in cur.fetchall()]

    def _pick_list_overrides(
        self, setup_session_id: int
    ) -> list[dict[str, Any]]:
        with self.connect() as conn, conn.cursor(cursor_factory=RealDictCursor) as cur:
            cur.execute(
                """
                SELECT
                    o.setup_pick_list_override_id,
                    o.setup_session_id,
                    o.container_id,
                    o.pick_by_date::text AS pick_by_date,
                    o.needed_for_date::text AS needed_for_date,
                    o.destination_stage_id,
                    ds.stage_key AS destination_stage_key,
                    ds.stage_name AS destination_stage_name,
                    o.override_reason,
                    o.active_flag,
                    o.created_at,
                    o.updated_at,
                    c.description AS container_description,
                    c.location_code AS home_location_code,
                    coalesce(
                        nullif(btrim(concat_ws(' ', p.first_name, p.last_name)), ''),
                        o.updated_by
                    ) AS requested_by_display
                FROM ops.setup_pick_list_override AS o
                JOIN ref.container AS c
                  ON c.container_id = o.container_id
                JOIN ref.stage AS ds
                  ON ds.stage_id = o.destination_stage_id
                LEFT JOIN ref.person AS p
                  ON p.person_id = o.updated_by_person_id
                WHERE o.setup_session_id = %s
                  AND o.active_flag
                ORDER BY o.pick_by_date, c.location_code, o.container_id
                """,
                (setup_session_id,),
            )
            return [dict(row) for row in cur.fetchall()]

    def set_pick_list_override(
        self,
        *,
        email: str,
        season_year: int,
        container_id: int,
        pick_by_date: str | None,
        needed_for_date: str | None,
        destination_stage_id: int | None,
        reason: str | None,
        active: bool,
    ) -> dict[str, Any]:
        if active:
            readiness = self.material_readiness(season_year)
            existing = next(
                (
                    item
                    for item in readiness.get("physical_items") or []
                    if item.get("physical_type") == "CONTAINER"
                    and int(item.get("physical_id") or 0) == int(container_id)
                ),
                None,
            )
            if existing is not None and not existing.get("manager_overrides"):
                raise SetupMaterialReadinessRepositoryError(
                    "Container is already on the Pick List from scheduled material demand; "
                    "a Manager override is not needed."
                )

        with self.write_connect() as conn, conn.cursor(cursor_factory=RealDictCursor) as cur:
            cur.execute(
                """
                SELECT *
                FROM ops.set_setup_pick_list_override(
                    %s,%s,%s,%s::date,%s::date,%s::integer,%s,%s
                )
                """,
                (
                    email,
                    season_year,
                    container_id,
                    pick_by_date,
                    needed_for_date,
                    destination_stage_id,
                    reason,
                    active,
                ),
            )
            result = self._one(cur, "Pick List override command returned no result")
            conn.commit()
            return result

    def _observation_state(
        self,
        *,
        setup_session_id: int,
        container_ids: list[int],
        display_ids: list[int],
    ) -> dict[tuple[str, int], dict[str, Any]]:
        state: dict[tuple[str, int], dict[str, Any]] = {}
        with self.connect() as conn, conn.cursor(cursor_factory=RealDictCursor) as cur:
            if container_ids:
                cur.execute(
                    """
                    SELECT
                        c.container_id,
                        c.description AS label,
                        c.location_code AS home_location_code,
                        cs.current_stage_id,
                        s.stage_key AS current_stage_key,
                        s.stage_name AS current_stage_name,
                        cs.current_location_note,
                        cs.last_movement_event_id,
                        me.event_type AS last_event_type,
                        me.occurred_at AS last_observed_at,
                        me.destination_stage_id,
                        me.destination_location_note
                    FROM ref.container AS c
                    LEFT JOIN ops.setup_container_state AS cs
                      ON cs.setup_session_id = %s
                     AND cs.container_id = c.container_id
                    LEFT JOIN ref.stage AS s
                      ON s.stage_id = cs.current_stage_id
                    LEFT JOIN ops.setup_movement_event AS me
                      ON me.setup_movement_event_id = cs.last_movement_event_id
                    WHERE c.container_id = ANY(%s)
                    """,
                    (setup_session_id, container_ids),
                )
                for row in cur.fetchall():
                    item = dict(row)
                    state[("CONTAINER", int(item["container_id"]))] = item

            if display_ids:
                cur.execute(
                    """
                    SELECT
                        d.display_id,
                        d.display_name AS label,
                        c.location_code AS home_location_code,
                        ds.position_mode,
                        ds.current_stage_id,
                        s.stage_key AS current_stage_key,
                        s.stage_name AS current_stage_name,
                        ds.current_location_note,
                        ds.last_movement_event_id,
                        me.event_type AS last_event_type,
                        me.occurred_at AS last_observed_at,
                        me.destination_stage_id,
                        me.destination_location_note
                    FROM ref.display AS d
                    LEFT JOIN ref.container AS c
                      ON c.container_id = d.container_id
                    LEFT JOIN ops.setup_display_state AS ds
                      ON ds.setup_session_id = %s
                     AND ds.display_id = d.display_id
                    LEFT JOIN ref.stage AS s
                      ON s.stage_id = ds.current_stage_id
                    LEFT JOIN ops.setup_movement_event AS me
                      ON me.setup_movement_event_id = ds.last_movement_event_id
                    WHERE d.display_id = ANY(%s)
                    """,
                    (setup_session_id, display_ids),
                )
                for row in cur.fetchall():
                    item = dict(row)
                    state[("DISPLAY", int(item["display_id"]))] = item
        return state

    @staticmethod
    def _demand_base(assignment: dict[str, Any]) -> dict[str, Any]:
        return {
            "setup_work_day_task_id": assignment["setup_work_day_task_id"],
            "setup_session_task_id": assignment["setup_session_task_id"],
            "setup_task_id": assignment.get("setup_task_id"),
            "task_name": assignment.get("task_name"),
            "setup_day_number": assignment.get("setup_day_number"),
            "work_date": assignment["work_date"],
            "shift_code": assignment.get("shift_code"),
            "crew_lane": assignment.get("crew_lane"),
            "stage_id": assignment.get("stage_id"),
            "stage_key": assignment.get("stage_key"),
            "stage_name": assignment.get("stage_name"),
            "lor_scene_id": assignment.get("lor_scene_id"),
            "scene_name": assignment.get("scene_name"),
            "demand_origin": assignment.get("demand_origin") or "DIRECT_SCHEDULE",
            "scheduled_trigger_setup_work_day_task_id": assignment.get(
                "scheduled_trigger_setup_work_day_task_id"
            ),
            "scheduled_trigger_setup_session_task_id": assignment.get(
                "scheduled_trigger_setup_session_task_id"
            ),
            "scheduled_trigger_setup_task_id": assignment.get(
                "scheduled_trigger_setup_task_id"
            ),
            "scheduled_trigger_task_name": assignment.get(
                "scheduled_trigger_task_name"
            ),
        }

    def material_readiness(self, season_year: int) -> dict[str, Any]:
        with self.connect() as conn, conn.cursor(cursor_factory=RealDictCursor) as cur:
            cur.execute(
                """
                SELECT setup_session_id, season_year, session_status, notes
                FROM ops.setup_session
                WHERE season_year = %s
                """,
                (season_year,),
            )
            session = cur.fetchone()
        if session is None:
            return {
                "session": None,
                "scheduled_work": [],
                "physical_items": [],
                "pick_list_overrides": [],
                "unresolved_requirements": [],
                "summary": {
                    "scheduled_assignment_count": 0,
                    "physical_item_count": 0,
                    "container_count": 0,
                    "display_count": 0,
                    "unresolved_requirement_count": 0,
                },
            }

        setup_session_id = int(session["setup_session_id"])
        assignments = self._scheduled_work(setup_session_id)
        tasks_by_session_id, downstream_by_prerequisite = self._annual_demand_graph(
            setup_session_id
        )
        material_bearing_session_ids = self._material_bearing_session_task_ids(
            setup_session_id
        )
        for session_task_id, task in tasks_by_session_id.items():
            task["material_bearing"] = session_task_id in material_bearing_session_ids

        demand_assignments: list[dict[str, Any]] = []
        for assignment in assignments:
            direct = dict(assignment)
            direct["demand_origin"] = "DIRECT_SCHEDULE"
            direct["scheduled_trigger_setup_work_day_task_id"] = assignment[
                "setup_work_day_task_id"
            ]
            direct["scheduled_trigger_setup_session_task_id"] = assignment[
                "setup_session_task_id"
            ]
            direct["scheduled_trigger_setup_task_id"] = assignment.get("setup_task_id")
            direct["scheduled_trigger_task_name"] = assignment.get("task_name")
            demand_assignments.append(direct)

            for target in downstream_material_frontier(
                int(assignment["setup_session_task_id"]),
                tasks_by_session_id,
                downstream_by_prerequisite,
            ):
                expanded = dict(assignment)
                expanded.update({
                    "setup_session_task_id": target["setup_session_task_id"],
                    "setup_task_id": target.get("setup_task_id"),
                    "task_origin": target.get("task_origin"),
                    "task_name": target.get("task_name"),
                    "stage_id": target.get("stage_id"),
                    "stage_key": target.get("stage_key"),
                    "stage_name": target.get("stage_name"),
                    "lor_scene_id": target.get("lor_scene_id"),
                    "scene_name": target.get("scene_name"),
                    "demand_origin": "DOWNSTREAM_FROM_SCHEDULE",
                    "scheduled_trigger_setup_work_day_task_id": assignment[
                        "setup_work_day_task_id"
                    ],
                    "scheduled_trigger_setup_session_task_id": assignment[
                        "setup_session_task_id"
                    ],
                    "scheduled_trigger_setup_task_id": assignment.get("setup_task_id"),
                    "scheduled_trigger_task_name": assignment.get("task_name"),
                })
                demand_assignments.append(expanded)

        demand_task_ids = sorted({
            int(row["setup_task_id"])
            for row in demand_assignments
            if row.get("setup_task_id") is not None
        })
        extra_by_task: dict[int, list[dict[str, Any]]] = defaultdict(list)
        for row in self._extra_material_rows(demand_task_ids, season_year):
            extra_by_task[int(row["setup_task_id"])].append(row)

        next_repo = SetupNextRepository(self.dsn)
        context_by_task: dict[int, dict[str, Any]] = {}
        for task_id in demand_task_ids:
            try:
                context_by_task[task_id] = next_repo.field_context(
                    task_id=task_id, season_year=season_year
                )
            except SetupNextRepositoryError as exc:
                raise SetupMaterialReadinessRepositoryError(str(exc)) from exc

        demand_rows: list[dict[str, Any]] = []
        unresolved: list[dict[str, Any]] = []
        scheduled_work: list[dict[str, Any]] = []

        for assignment in demand_assignments:
            scheduled = dict(assignment)
            is_direct_schedule = assignment.get("demand_origin") == "DIRECT_SCHEDULE"
            task_id = assignment.get("setup_task_id")
            if task_id is None:
                scheduled["material_resolution_status"] = "SEASON_ONLY_NO_REUSABLE_MATERIAL_AUTHORITY"
                if is_direct_schedule:
                    scheduled_work.append(scheduled)
                unresolved.append({
                    **self._demand_base(assignment),
                    "requirement_type": "SEASON_ONLY_MATERIAL_AUTHORITY",
                    "message": (
                        "Season-only scheduled work has no reusable material authority. "
                        "Review whether physical material is required before relying on the Pick List."
                    ),
                })
                continue

            context = context_by_task[int(task_id)]
            material_resolution = dict(context.get("material_resolution") or {})
            scheduled["material_resolution"] = material_resolution
            scheduled["material_resolution_status"] = (
                material_resolution.get("ownership_status")
                or ("REVIEW_REQUIRED" if material_resolution.get("warning") else "COMPLETE")
            )
            if is_direct_schedule:
                scheduled_work.append(scheduled)

            if scheduled["material_resolution_status"] == "REVIEW_REQUIRED":
                unresolved.append({
                    **self._demand_base(assignment),
                    "requirement_type": "DISPLAY_MATERIAL_OWNERSHIP",
                    "message": material_resolution.get("warning")
                    or "Display material ownership requires review.",
                })

            grouped_displays: dict[tuple[str, int], list[dict[str, Any]]] = defaultdict(list)
            for display in context.get("displays") or []:
                position_mode = str(display.get("position_mode") or "WITH_CONTAINER").upper()
                container_id = display.get("container_id")
                if position_mode == "DETACHED" or container_id is None:
                    key = ("DISPLAY", int(display["display_id"]))
                else:
                    key = ("CONTAINER", int(container_id))
                grouped_displays[key].append(dict(display))

            for (physical_type, physical_id), displays in grouped_displays.items():
                first = displays[0]
                if physical_type == "CONTAINER":
                    identity = f"CONT:{physical_id}"
                    label = first.get("container_description") or f"Container {physical_id}"
                else:
                    identity = f"DISP:{physical_id}"
                    label = first.get("display_name") or f"Display {physical_id}"
                names = [str(row.get("display_name") or row["display_id"]) for row in displays]
                demand_rows.append({
                    **self._demand_base(assignment),
                    "physical_type": physical_type,
                    "physical_id": physical_id,
                    "identity": identity,
                    "label": label,
                    "home_location_code": first.get("home_location_code"),
                    "reason_type": "DISPLAY_MATERIAL",
                    "reason_label": f"{len(displays)} required Display{'s' if len(displays) != 1 else ''}",
                    "reason_detail": ", ".join(names),
                    "display_ids": [int(row["display_id"]) for row in displays],
                    "display_names": names,
                })

            for support in context.get("support_containers") or []:
                container_id = int(support["container_id"])
                relationship = str(support.get("relationship_type") or "SUPPORT")
                demand_rows.append({
                    **self._demand_base(assignment),
                    "physical_type": "CONTAINER",
                    "physical_id": container_id,
                    "identity": f"CONT:{container_id}",
                    "label": support.get("container_description") or f"Container {container_id}",
                    "home_location_code": support.get("home_location_code"),
                    "reason_type": relationship,
                    "reason_label": relationship.replace("_", " ").title(),
                    "reason_detail": support.get("relationship_notes"),
                })

            requirement_sources: dict[int, int] = defaultdict(int)
            for extra in extra_by_task.get(int(task_id), []):
                requirement_id = int(extra["setup_task_extra_material_id"])
                if extra.get("container_id") is None:
                    continue
                requirement_sources[requirement_id] += 1
                container_id = int(extra["container_id"])
                material_name = str(extra.get("material_name") or "Extra Material")
                demand_rows.append({
                    **self._demand_base(assignment),
                    "physical_type": "CONTAINER",
                    "physical_id": container_id,
                    "identity": f"CONT:{container_id}",
                    "label": extra.get("container_description") or f"Container {container_id}",
                    "home_location_code": extra.get("home_location_code"),
                    "reason_type": "EXTRA_MATERIAL_SOURCE",
                    "reason_label": material_name,
                    "reason_detail": extra.get("source_verification_state"),
                    "extra_material_id": extra.get("setup_extra_material_id"),
                    "extra_material_name": material_name,
                    "quantity_required": extra.get("quantity_required"),
                    "quantity_uom": extra.get("quantity_uom"),
                    "quantity_qualifier": extra.get("quantity_qualifier"),
                    "size_text": extra.get("size_text"),
                    "length_value": extra.get("length_value"),
                    "length_unit": extra.get("length_unit"),
                    "color": extra.get("color"),
                    "requirement_notes": extra.get("requirement_notes"),
                    "source_expected_quantity": extra.get("expected_quantity"),
                    "source_verification_state": extra.get("source_verification_state"),
                })

            seen_requirements: set[int] = set()
            for extra in extra_by_task.get(int(task_id), []):
                requirement_id = int(extra["setup_task_extra_material_id"])
                if requirement_id in seen_requirements:
                    continue
                seen_requirements.add(requirement_id)
                if requirement_sources.get(requirement_id, 0) == 0:
                    unresolved.append({
                        **self._demand_base(assignment),
                        "requirement_type": "EXTRA_MATERIAL_SOURCE",
                        "extra_material_id": extra.get("setup_extra_material_id"),
                        "extra_material_name": extra.get("material_name"),
                        "quantity_required": extra.get("quantity_required"),
                        "quantity_uom": extra.get("quantity_uom"),
                        "message": "Required Extra Material has no active expected-source Container.",
                    })

        physical_items = project_physical_demand(demand_rows)
        item_by_key = {
            (item["physical_type"], int(item["physical_id"])): item
            for item in physical_items
        }
        overrides = self._pick_list_overrides(setup_session_id)
        for override in overrides:
            container_id = int(override["container_id"])
            key = ("CONTAINER", container_id)
            pick_by = str(override["pick_by_date"])
            needed_for = override.get("needed_for_date")
            effective_needed = str(needed_for or pick_by)
            override_reason = {
                "setup_work_day_task_id": None,
                "setup_session_task_id": None,
                "setup_task_id": None,
                "task_name": None,
                "setup_day_number": None,
                "work_date": effective_needed,
                "target_staged_by": pick_by,
                "shift_code": None,
                "crew_lane": None,
                "stage_id": None,
                "stage_key": None,
                "stage_name": None,
                "lor_scene_id": None,
                "scene_name": None,
                "reason_type": "MANAGER_OVERRIDE",
                "reason_label": "Manager early-pick override",
                "override_destination_stage_id": override.get("destination_stage_id"),
                "override_destination": (
                    " — ".join(
                        value
                        for value in (
                            override.get("destination_stage_key"),
                            override.get("destination_stage_name"),
                        )
                        if value
                    )
                    or "Destination Stage"
                ),
                "reason_detail": override.get("override_reason"),
                "display_ids": [],
                "display_names": [],
                "extra_material_id": None,
                "extra_material_name": None,
                "quantity_required": None,
                "quantity_uom": None,
                "quantity_qualifier": None,
                "size_text": None,
                "length_value": None,
                "length_unit": None,
                "color": None,
                "requirement_notes": None,
                "source_expected_quantity": None,
                "source_verification_state": None,
                "demand_origin": "MANAGER_OVERRIDE",
                "scheduled_trigger_setup_work_day_task_id": None,
                "scheduled_trigger_setup_session_task_id": None,
                "scheduled_trigger_setup_task_id": None,
                "scheduled_trigger_task_name": None,
                "manager_override_id": override["setup_pick_list_override_id"],
                "manager_override_pick_by": pick_by,
                "manager_override_needed_for": needed_for,
                "manager_override_reason": override.get("override_reason"),
                "manager_override_actor": override.get("requested_by_display"),
            }
            override_meta = {
                "setup_pick_list_override_id": override["setup_pick_list_override_id"],
                "pick_by_date": pick_by,
                "needed_for_date": needed_for,
                "destination_stage_id": override.get("destination_stage_id"),
                "destination_stage_key": override.get("destination_stage_key"),
                "destination_stage_name": override.get("destination_stage_name"),
                "override_reason": override.get("override_reason"),
                "requested_by_display": override.get("requested_by_display"),
                "updated_at": override.get("updated_at"),
            }
            item = item_by_key.get(key)
            if item is None:
                item = {
                    "physical_type": "CONTAINER",
                    "physical_id": container_id,
                    "identity": f"CONT:{container_id}",
                    "label": override.get("container_description") or f"Container {container_id}",
                    "home_location_code": override.get("home_location_code"),
                    "earliest_needed_for_work": effective_needed,
                    "target_staged_by": pick_by,
                    "reasons": [override_reason],
                    "manager_overrides": [override_meta],
                    "override_only": True,
                }
                physical_items.append(item)
                item_by_key[key] = item
            else:
                item.setdefault("manager_overrides", []).append(override_meta)
                item["reasons"].append(override_reason)
                item["override_only"] = False
                if pick_by < str(item["target_staged_by"]):
                    item["target_staged_by"] = pick_by
                if needed_for and str(needed_for) < str(item["earliest_needed_for_work"]):
                    item["earliest_needed_for_work"] = str(needed_for)

        physical_items.sort(
            key=lambda item: (
                str(item["target_staged_by"]),
                str(item["earliest_needed_for_work"]),
                0 if item["physical_type"] == "CONTAINER" else 1,
                int(item["physical_id"]),
            )
        )
        container_ids = [int(item["physical_id"]) for item in physical_items if item["physical_type"] == "CONTAINER"]
        display_ids = [int(item["physical_id"]) for item in physical_items if item["physical_type"] == "DISPLAY"]
        state = self._observation_state(
            setup_session_id=int(session["setup_session_id"]),
            container_ids=container_ids,
            display_ids=display_ids,
        )

        for item in physical_items:
            key = (item["physical_type"], int(item["physical_id"]))
            observation = dict(state.get(key) or {})
            item["current_observation"] = observation or None
            if observation.get("last_movement_event_id") is not None:
                item["location_evidence_status"] = "HAS_SETUP_OBSERVATION"
            elif observation.get("current_stage_id") is not None or observation.get("current_location_note"):
                item["location_evidence_status"] = "LOCATION_WITHOUT_EVENT"
            else:
                item["location_evidence_status"] = "NO_SETUP_OBSERVATION"

        return {
            "session": dict(session),
            "scheduled_work": scheduled_work,
            "physical_items": physical_items,
            "pick_list_overrides": overrides,
            "unresolved_requirements": unresolved,
            "summary": {
                "scheduled_assignment_count": len(assignments),
                "physical_item_count": len(physical_items),
                "container_count": len(container_ids),
                "display_count": len(display_ids),
                "unresolved_requirement_count": len(unresolved),
            },
        }
