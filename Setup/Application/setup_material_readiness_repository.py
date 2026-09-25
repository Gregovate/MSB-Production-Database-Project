"""Read-only material-readiness resolver for Setup #206.

This repository consumes the accepted #205 schedule and existing reusable
material authorities.  It deliberately performs no movement writes and does
not invent a second mutable current-location field.
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
                "unresolved_requirements": [],
                "summary": {
                    "scheduled_assignment_count": 0,
                    "physical_item_count": 0,
                    "container_count": 0,
                    "display_count": 0,
                    "unresolved_requirement_count": 0,
                },
            }

        assignments = self._scheduled_work(int(session["setup_session_id"]))
        reusable_task_ids = sorted({
            int(row["setup_task_id"])
            for row in assignments
            if row.get("setup_task_id") is not None
        })
        extra_by_task: dict[int, list[dict[str, Any]]] = defaultdict(list)
        for row in self._extra_material_rows(reusable_task_ids, season_year):
            extra_by_task[int(row["setup_task_id"])].append(row)

        next_repo = SetupNextRepository(self.dsn)
        demand_rows: list[dict[str, Any]] = []
        unresolved: list[dict[str, Any]] = []
        scheduled_work: list[dict[str, Any]] = []

        for assignment in assignments:
            scheduled = dict(assignment)
            task_id = assignment.get("setup_task_id")
            if task_id is None:
                scheduled["material_resolution_status"] = "SEASON_ONLY_NO_REUSABLE_MATERIAL_AUTHORITY"
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

            try:
                context = next_repo.field_context(task_id=int(task_id), season_year=season_year)
            except SetupNextRepositoryError as exc:
                raise SetupMaterialReadinessRepositoryError(str(exc)) from exc

            material_resolution = dict(context.get("material_resolution") or {})
            scheduled["material_resolution"] = material_resolution
            scheduled["material_resolution_status"] = (
                material_resolution.get("ownership_status")
                or ("REVIEW_REQUIRED" if material_resolution.get("warning") else "COMPLETE")
            )
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
                if str(extra.get("source_verification_state") or "") != "VERIFIED":
                    unresolved.append({
                        **self._demand_base(assignment),
                        "requirement_type": "EXTRA_MATERIAL_SOURCE_VERIFICATION",
                        "extra_material_id": extra.get("setup_extra_material_id"),
                        "extra_material_name": material_name,
                        "container_id": container_id,
                        "message": "Expected-source Container is not VERIFIED for Pick List use.",
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
                if str(extra.get("requirement_verification_state") or "") != "VERIFIED":
                    unresolved.append({
                        **self._demand_base(assignment),
                        "requirement_type": "EXTRA_MATERIAL_VERIFICATION",
                        "extra_material_id": extra.get("setup_extra_material_id"),
                        "extra_material_name": extra.get("material_name"),
                        "message": "Extra Material requirement is not VERIFIED for Pick List use.",
                    })

        physical_items = project_physical_demand(demand_rows)
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
            "unresolved_requirements": unresolved,
            "summary": {
                "scheduled_assignment_count": len(assignments),
                "physical_item_count": len(physical_items),
                "container_count": len(container_ids),
                "display_count": len(display_ids),
                "unresolved_requirement_count": len(unresolved),
            },
        }
