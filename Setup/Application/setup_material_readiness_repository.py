"""Material-readiness resolver for Setup #206.

The read path consumes the accepted schedule and existing reusable material
authorities. Narrow Manager writes are limited to early-pick overrides and
transient Pick Delays. Pick Delays are session logistics only: they do not
schedule work, change reusable task knowledge, or write movement/location state.
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
from setup_material_resolution import is_real_setup_scene, is_stage_level_lor_group


class SetupMaterialReadinessRepositoryError(RuntimeError):
    pass


class SetupMaterialReadinessConflictError(RuntimeError):
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
                    coalesce(cs.current_location_note, (
                            SELECT n.destination_location_note FROM ops.setup_movement_event n
                            JOIN ops.setup_movement_event anchor ON anchor.setup_movement_event_id=cs.last_movement_event_id
                              AND anchor.setup_session_id=cs.setup_session_id
                            WHERE n.setup_session_id=cs.setup_session_id AND n.container_id=cs.container_id
                              AND (n.occurred_at,n.setup_movement_event_id)<=(anchor.occurred_at,anchor.setup_movement_event_id)
                              AND nullif(trim(n.destination_location_note),'') IS NOT NULL
                              AND NOT EXISTS (SELECT 1 FROM ops.setup_movement_event r WHERE r.setup_session_id=n.setup_session_id
                                AND r.container_id=n.container_id AND r.event_type='RETURNED'
                                AND r.occurred_at>=n.occurred_at AND r.occurred_at<=anchor.occurred_at)
                            ORDER BY n.occurred_at DESC,n.setup_movement_event_id DESC LIMIT 1
                        )) AS current_location_note,
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


    def _pick_list_delays(
        self, setup_session_id: int
    ) -> list[dict[str, Any]]:
        with self.connect() as conn, conn.cursor(cursor_factory=RealDictCursor) as cur:
            cur.execute(
                """
                SELECT
                    d.setup_pick_list_delay_id,
                    d.setup_session_id,
                    d.container_id,
                    d.release_setup_session_task_ids,
                    d.delay_reason,
                    d.created_at,
                    d.updated_at,
                    c.description AS container_description,
                    c.location_code AS home_location_code,
                    coalesce(
                        nullif(btrim(concat_ws(' ', p.first_name, p.last_name)), ''),
                        d.updated_by
                    ) AS delayed_by_display
                FROM ops.setup_pick_list_delay AS d
                JOIN ref.container AS c
                  ON c.container_id = d.container_id
                LEFT JOIN ref.person AS p
                  ON p.person_id = d.updated_by_person_id
                WHERE d.setup_session_id = %s
                ORDER BY c.location_code NULLS LAST, d.container_id
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
                raise SetupMaterialReadinessConflictError(
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


    def set_pick_list_delay(
        self,
        *,
        email: str,
        season_year: int,
        container_id: int,
        reason: str | None,
        delayed: bool,
    ) -> dict[str, Any]:
        release_session_task_ids: list[int] = []

        if delayed:
            readiness = self.material_readiness(season_year)
            item = next(
                (
                    candidate
                    for candidate in readiness.get("physical_items") or []
                    if candidate.get("physical_type") == "CONTAINER"
                    and int(candidate.get("physical_id") or 0) == int(container_id)
                ),
                None,
            )
            if item is None:
                raise SetupMaterialReadinessConflictError(
                    "Container is not current Pick List demand."
                )
            if (item.get("current_observation") or {}).get("last_movement_event_id") is not None:
                raise SetupMaterialReadinessConflictError(
                    "Container already has Setup movement evidence and cannot be delayed as an unpicked item."
                )

            reasons = list(item.get("reasons") or [])
            origins = {
                str(row.get("demand_origin") or "DIRECT_SCHEDULE")
                for row in reasons
            }
            if origins != {"DOWNSTREAM_FROM_SCHEDULE"}:
                raise SetupMaterialReadinessConflictError(
                    "Pick Delay is allowed only for anticipated downstream demand. "
                    "Direct scheduled or Manager-override demand must remain actionable."
                )

            release_session_task_ids = sorted({
                int(row["setup_session_task_id"])
                for row in reasons
                if row.get("setup_session_task_id") is not None
            })
            if not release_session_task_ids:
                raise SetupMaterialReadinessConflictError(
                    "Anticipated Pick List demand has no downstream task identity to release the delay."
                )

        with self.write_connect() as conn, conn.cursor(cursor_factory=RealDictCursor) as cur:
            cur.execute(
                """
                SELECT *
                FROM ops.set_setup_pick_list_delay(
                    %s,%s,%s,%s::bigint[],%s,%s
                )
                """,
                (
                    email,
                    season_year,
                    container_id,
                    release_session_task_ids,
                    reason,
                    delayed,
                ),
            )
            result = self._one(cur, "Pick Delay command returned no result")
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
                        coalesce(cs.current_location_note, (
                            SELECT n.destination_location_note FROM ops.setup_movement_event n
                            JOIN ops.setup_movement_event anchor ON anchor.setup_movement_event_id=cs.last_movement_event_id
                              AND anchor.setup_session_id=cs.setup_session_id
                            WHERE n.setup_session_id=cs.setup_session_id AND n.container_id=cs.container_id
                              AND (n.occurred_at,n.setup_movement_event_id)<=(anchor.occurred_at,anchor.setup_movement_event_id)
                              AND nullif(trim(n.destination_location_note),'') IS NOT NULL
                              AND NOT EXISTS (SELECT 1 FROM ops.setup_movement_event r WHERE r.setup_session_id=n.setup_session_id
                                AND r.container_id=n.container_id AND r.event_type='RETURNED'
                                AND r.occurred_at>=n.occurred_at AND r.occurred_at<=anchor.occurred_at)
                            ORDER BY n.occurred_at DESC,n.setup_movement_event_id DESC LIMIT 1
                        )) AS current_location_note,
                        cs.movement_status,
                        cs.last_movement_at,
                        cs.last_movement_event_id,
                        me.event_type AS last_event_type,
                        me.occurred_at AS last_observed_at,
                        me.gps_latitude,
                        me.gps_longitude,
                        me.gps_accuracy_m,
                        me.gps_quality,
                        me.gps_fix_age_ms,
                        me.destination_stage_id,
                        me.destination_location_note,
                        EXISTS (
                            SELECT 1
                            FROM ops.setup_movement_event AS picked
                            WHERE picked.setup_session_id = %s
                              AND picked.container_id = c.container_id
                              AND picked.event_type = 'PICKED'
                        ) AS has_pick_event
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
                    (setup_session_id, setup_session_id, container_ids),
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
                        ds.movement_status,
                        ds.last_movement_at,
                        ds.last_movement_event_id,
                        me.event_type AS last_event_type,
                        me.occurred_at AS last_observed_at,
                        me.gps_latitude,
                        me.gps_longitude,
                        me.gps_accuracy_m,
                        me.gps_quality,
                        me.gps_fix_age_ms,
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

    def _matching_material_task_ids(
        self,
        *,
        setup_session_id: int,
        task_ids: list[int],
        asset_type: str,
        asset_id: int,
    ) -> set[int]:
        """Return only current reusable tasks whose physical authority uses this asset."""
        if not task_ids:
            return set()

        normalized_type = str(asset_type or "").strip().upper()
        if normalized_type not in {"CONTAINER", "DISPLAY"}:
            raise SetupMaterialReadinessRepositoryError(
                "Pick validation asset type must be CONTAINER or DISPLAY"
            )

        with self.connect() as conn, conn.cursor(cursor_factory=RealDictCursor) as cur:
            if normalized_type == "DISPLAY":
                cur.execute(
                    """
                    WITH task_context AS (
                        SELECT t.setup_task_id, t.lor_scene_id
                        FROM ref.setup_task AS t
                        WHERE t.setup_task_id = ANY(%s)
                    ),
                    display_scope AS (
                        SELECT tc.setup_task_id, td.display_id
                        FROM task_context AS tc
                        JOIN ref.setup_task_display AS td
                          ON td.setup_task_id = tc.setup_task_id

                        UNION

                        SELECT tc.setup_task_id, lsd.display_id
                        FROM task_context AS tc
                        JOIN ref.lor_scene_display AS lsd
                          ON lsd.lor_scene_id = tc.lor_scene_id
                        WHERE tc.lor_scene_id IS NOT NULL
                    )
                    SELECT DISTINCT scope.setup_task_id
                    FROM display_scope AS scope
                    JOIN ref.display AS d
                      ON d.display_id = scope.display_id
                    LEFT JOIN ops.setup_display_state AS ds
                      ON ds.setup_session_id = %s
                     AND ds.display_id = d.display_id
                    WHERE d.display_id = %s
                      AND (
                          d.container_id IS NULL
                          OR coalesce(ds.position_mode, 'WITH_CONTAINER') = 'DETACHED'
                      )
                    """,
                    (task_ids, setup_session_id, asset_id),
                )
            else:
                cur.execute(
                    """
                    WITH task_context AS (
                        SELECT t.setup_task_id, t.lor_scene_id
                        FROM ref.setup_task AS t
                        WHERE t.setup_task_id = ANY(%s)
                    ),
                    display_scope AS (
                        SELECT tc.setup_task_id, td.display_id
                        FROM task_context AS tc
                        JOIN ref.setup_task_display AS td
                          ON td.setup_task_id = tc.setup_task_id

                        UNION

                        SELECT tc.setup_task_id, lsd.display_id
                        FROM task_context AS tc
                        JOIN ref.lor_scene_display AS lsd
                          ON lsd.lor_scene_id = tc.lor_scene_id
                        WHERE tc.lor_scene_id IS NOT NULL
                    ),
                    matches AS (
                        SELECT DISTINCT scope.setup_task_id
                        FROM display_scope AS scope
                        JOIN ref.display AS d
                          ON d.display_id = scope.display_id
                        LEFT JOIN ops.setup_display_state AS ds
                          ON ds.setup_session_id = %s
                         AND ds.display_id = d.display_id
                        WHERE d.container_id = %s
                          AND coalesce(ds.position_mode, 'WITH_CONTAINER') <> 'DETACHED'

                        UNION

                        SELECT tc.setup_task_id
                        FROM ref.setup_task_container_support AS tc
                        WHERE tc.setup_task_id = ANY(%s)
                          AND tc.container_id = %s

                        UNION

                        SELECT tm.setup_task_id
                        FROM ref.setup_task_extra_material AS tm
                        JOIN ref.setup_extra_material AS m
                          ON m.setup_extra_material_id = tm.setup_extra_material_id
                        JOIN ref.setup_task_extra_material_source AS src
                          ON src.setup_task_extra_material_id = tm.setup_task_extra_material_id
                         AND src.active_flag
                        WHERE tm.setup_task_id = ANY(%s)
                          AND tm.active_flag
                          AND m.active_flag
                          AND src.container_id = %s
                    )
                    SELECT DISTINCT setup_task_id
                    FROM matches
                    """,
                    (
                        task_ids,
                        setup_session_id,
                        asset_id,
                        task_ids,
                        asset_id,
                        task_ids,
                        asset_id,
                    ),
                )
            return {int(row["setup_task_id"]) for row in cur.fetchall()}

    def pick_demand_status(
        self,
        *,
        season_year: int,
        asset_type: str,
        asset_id: int,
    ) -> dict[str, Any]:
        """Focused authoritative Pick validation without building the full Pick List."""
        normalized_type = str(asset_type or "").strip().upper()
        if normalized_type not in {"CONTAINER", "DISPLAY"}:
            raise SetupMaterialReadinessRepositoryError(
                "Pick validation asset type must be CONTAINER or DISPLAY"
            )

        with self.connect() as conn, conn.cursor(cursor_factory=RealDictCursor) as cur:
            cur.execute(
                """
                SELECT setup_session_id
                FROM ops.setup_session
                WHERE season_year = %s
                  AND session_status NOT IN ('COMPLETE', 'HISTORICAL_VERIFICATION')
                LIMIT 1
                """,
                (season_year,),
            )
            session = cur.fetchone()

        if session is None:
            return {
                "demanded": False,
                "pick_delayed": False,
                "demand_origins": [],
                "current_observation": None,
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
                })
                demand_assignments.append(expanded)

        origins_by_task: dict[int, set[str]] = defaultdict(set)
        for assignment in demand_assignments:
            task_id = assignment.get("setup_task_id")
            if task_id is None:
                continue
            origins_by_task[int(task_id)].add(
                str(assignment.get("demand_origin") or "DIRECT_SCHEDULE")
            )

        candidate_task_ids = sorted(origins_by_task)
        matched_task_ids = self._matching_material_task_ids(
            setup_session_id=setup_session_id,
            task_ids=candidate_task_ids,
            asset_type=normalized_type,
            asset_id=asset_id,
        )

        origins: set[str] = set()
        for task_id in matched_task_ids:
            origins.update(origins_by_task.get(task_id) or set())

        active_override = False
        active_delay = False
        if normalized_type == "CONTAINER":
            with self.connect() as conn, conn.cursor(cursor_factory=RealDictCursor) as cur:
                cur.execute(
                    """
                    SELECT
                        EXISTS (
                            SELECT 1
                            FROM ops.setup_pick_list_override AS o
                            WHERE o.setup_session_id = %s
                              AND o.container_id = %s
                              AND o.active_flag
                        ) AS active_override,
                        EXISTS (
                            SELECT 1
                            FROM ops.setup_pick_list_delay AS d
                            WHERE d.setup_session_id = %s
                              AND d.container_id = %s
                        ) AS active_delay
                    """,
                    (setup_session_id, asset_id, setup_session_id, asset_id),
                )
                row = self._one(cur, "Pick validation state query returned no result")
                active_override = bool(row["active_override"])
                active_delay = bool(row["active_delay"])
            if active_override:
                origins.add("MANAGER_OVERRIDE")

        state = self._observation_state(
            setup_session_id=setup_session_id,
            container_ids=[asset_id] if normalized_type == "CONTAINER" else [],
            display_ids=[asset_id] if normalized_type == "DISPLAY" else [],
        )
        observation = dict(state.get((normalized_type, int(asset_id))) or {})

        status = {
            "demanded": bool(origins),
            "pick_delayed": bool(
                normalized_type == "CONTAINER"
                and active_delay
                and origins == {"DOWNSTREAM_FROM_SCHEDULE"}
            ),
            "demand_origins": sorted(origins),
            "current_observation": observation or None,
        }

        # The focused mapping is an optimization, not an independent authority.
        # Stage-level LOR membership and ownership can yield current demand that
        # has no explicit task-display row. Confirm misses against the same live
        # projection used by Pick List/Material Status before rejecting a scan.
        return self._reconcile_pick_demand(
            season_year=season_year, asset_type=normalized_type,
            asset_id=asset_id, status=status,
        )

    def _reconcile_pick_demand(
        self, *, season_year: int, asset_type: str, asset_id: int,
        status: dict[str, Any],
    ) -> dict[str, Any]:
        if status.get("demanded"):
            return status
        readiness = self.material_readiness(season_year)
        item = next((row for row in readiness.get("physical_items") or []
                     if str(row.get("physical_type") or "").upper() == asset_type
                     and int(row.get("physical_id") or 0) == int(asset_id)), None)
        if item is None:
            return status
        return {
            "demanded": True,
            "pick_delayed": bool(item.get("pick_delayed")),
            "demand_origins": sorted({
                str(reason.get("demand_origin") or "DIRECT_SCHEDULE")
                for reason in item.get("reasons") or []
            }),
            "current_observation": item.get("current_observation"),
        }

    def _container_endpoint_policy(
        self, container_ids: list[int]
    ) -> dict[int, int | None]:
        if not container_ids:
            return {}
        with self.connect() as conn, conn.cursor(cursor_factory=RealDictCursor) as cur:
            cur.execute(
                """
                SELECT c.container_id, c.goes_to_endpoint_id
                FROM ref.container AS c
                WHERE c.container_id = ANY(%s)
                """,
                (container_ids,),
            )
            return {
                int(row["container_id"]): (
                    int(row["goes_to_endpoint_id"])
                    if row.get("goes_to_endpoint_id") is not None
                    else None
                )
                for row in cur.fetchall()
            }

    def _bulk_unscheduled_material_contexts(
        self,
        *,
        setup_session_id: int,
        task_ids: list[int],
    ) -> dict[int, dict[str, Any]]:
        """Resolve unscheduled reusable material for many tasks with bounded reads.

        This preserves the accepted field_context material rules but avoids one
        PostgreSQL connection/query bundle per annual task.
        """
        if not task_ids:
            return {}

        normalized_task_ids = sorted({int(task_id) for task_id in task_ids})
        contexts: dict[int, dict[str, Any]] = {
            task_id: {
                "displays": [],
                "support_containers": [],
                "material_resolution": {"warning": None},
            }
            for task_id in normalized_task_ids
        }

        with self.connect() as conn, conn.cursor(cursor_factory=RealDictCursor) as cur:
            cur.execute(
                """
                SELECT
                    t.setup_task_id,
                    t.stage_id,
                    t.lor_scene_id,
                    ls.scene_name,
                    t.requires_display_material
                FROM ref.setup_task AS t
                LEFT JOIN ref.lor_scene AS ls
                  ON ls.lor_scene_id = t.lor_scene_id
                WHERE t.setup_task_id = ANY(%s)
                """,
                (normalized_task_ids,),
            )
            task_meta = {
                int(row["setup_task_id"]): dict(row)
                for row in cur.fetchall()
            }

            cur.execute(
                """
                SELECT setup_task_id, display_id
                FROM ref.setup_task_display
                WHERE setup_task_id = ANY(%s)
                ORDER BY setup_task_id, display_id
                """,
                (normalized_task_ids,),
            )
            explicit_by_task: dict[int, set[int]] = defaultdict(set)
            for row in cur.fetchall():
                explicit_by_task[int(row["setup_task_id"])].add(int(row["display_id"]))

            stage_ids = sorted({
                int(meta["stage_id"])
                for meta in task_meta.values()
                if meta.get("stage_id") is not None
            })
            scene_memberships: dict[int, set[int]] = defaultdict(set)
            stage_memberships: dict[int, list[tuple[str | None, int]]] = defaultdict(list)
            if stage_ids:
                cur.execute(
                    """
                    SELECT
                        ls.stage_id,
                        ls.lor_scene_id,
                        ls.scene_name,
                        lsd.display_id
                    FROM ref.lor_scene AS ls
                    JOIN ref.lor_scene_display AS lsd
                      ON lsd.lor_scene_id = ls.lor_scene_id
                    WHERE ls.stage_id = ANY(%s)
                    ORDER BY ls.stage_id, ls.lor_scene_id, lsd.display_id
                    """,
                    (stage_ids,),
                )
                for row in cur.fetchall():
                    stage_id = int(row["stage_id"])
                    scene_id = int(row["lor_scene_id"])
                    display_id = int(row["display_id"])
                    scene_memberships[scene_id].add(display_id)
                    stage_memberships[stage_id].append((row.get("scene_name"), display_id))

            selected_by_task: dict[int, set[int]] = defaultdict(set)
            for task_id, meta in task_meta.items():
                requires_display_material = bool(meta.get("requires_display_material"))
                stage_id = meta.get("stage_id")
                if not requires_display_material:
                    continue
                if stage_id is None:
                    contexts[task_id]["material_resolution"] = {
                        "warning": "Display material requires a Stage or real Scene scope."
                    }
                    continue

                selected = selected_by_task[task_id]
                selected.update(explicit_by_task.get(task_id) or set())

                scene_id = meta.get("lor_scene_id")
                scene_name = meta.get("scene_name")
                if scene_id is not None and is_real_setup_scene(scene_name):
                    selected.update(scene_memberships.get(int(scene_id)) or set())
                else:
                    for group_name, display_id in stage_memberships.get(int(stage_id), []):
                        if is_stage_level_lor_group(group_name):
                            selected.add(int(display_id))

            all_display_ids = sorted({
                display_id
                for display_ids in selected_by_task.values()
                for display_id in display_ids
            })
            display_by_id: dict[int, dict[str, Any]] = {}
            if all_display_ids:
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
                            ELSE coalesce(cs.current_location_note, (
                            SELECT n.destination_location_note FROM ops.setup_movement_event n
                            JOIN ops.setup_movement_event anchor ON anchor.setup_movement_event_id=cs.last_movement_event_id
                              AND anchor.setup_session_id=cs.setup_session_id
                            WHERE n.setup_session_id=cs.setup_session_id AND n.container_id=cs.container_id
                              AND (n.occurred_at,n.setup_movement_event_id)<=(anchor.occurred_at,anchor.setup_movement_event_id)
                              AND nullif(trim(n.destination_location_note),'') IS NOT NULL
                              AND NOT EXISTS (SELECT 1 FROM ops.setup_movement_event r WHERE r.setup_session_id=n.setup_session_id
                                AND r.container_id=n.container_id AND r.event_type='RETURNED'
                                AND r.occurred_at>=n.occurred_at AND r.occurred_at<=anchor.occurred_at)
                            ORDER BY n.occurred_at DESC,n.setup_movement_event_id DESC LIMIT 1
                        ))
                        END AS current_location_note,
                        c.location_code AS home_location_code
                    FROM ref.display AS d
                    JOIN ref.display_status AS status
                      ON status.display_status_id = d.display_status_id
                    LEFT JOIN ref.container AS c
                      ON c.container_id = d.container_id
                    LEFT JOIN ops.setup_display_state AS ds
                      ON ds.setup_session_id = %s
                     AND ds.display_id = d.display_id
                    LEFT JOIN ops.setup_container_state AS cs
                      ON cs.setup_session_id = %s
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
                    (setup_session_id, setup_session_id, all_display_ids),
                )
                display_by_id = {
                    int(row["display_id"]): dict(row)
                    for row in cur.fetchall()
                }

            for task_id, display_ids in selected_by_task.items():
                contexts[task_id]["displays"] = [
                    dict(display_by_id[display_id])
                    for display_id in sorted(display_ids)
                    if display_id in display_by_id
                ]

            cur.execute(
                """
                SELECT
                    tc.setup_task_id,
                    c.container_id,
                    c.description AS container_description,
                    c.location_code AS home_location_code,
                    cs.current_stage_id,
                    s.stage_key AS current_stage_key,
                    s.stage_name AS current_stage_name,
                    coalesce(cs.current_location_note, (
                            SELECT n.destination_location_note FROM ops.setup_movement_event n
                            JOIN ops.setup_movement_event anchor ON anchor.setup_movement_event_id=cs.last_movement_event_id
                              AND anchor.setup_session_id=cs.setup_session_id
                            WHERE n.setup_session_id=cs.setup_session_id AND n.container_id=cs.container_id
                              AND (n.occurred_at,n.setup_movement_event_id)<=(anchor.occurred_at,anchor.setup_movement_event_id)
                              AND nullif(trim(n.destination_location_note),'') IS NOT NULL
                              AND NOT EXISTS (SELECT 1 FROM ops.setup_movement_event r WHERE r.setup_session_id=n.setup_session_id
                                AND r.container_id=n.container_id AND r.event_type='RETURNED'
                                AND r.occurred_at>=n.occurred_at AND r.occurred_at<=anchor.occurred_at)
                            ORDER BY n.occurred_at DESC,n.setup_movement_event_id DESC LIMIT 1
                        )) AS current_location_note,
                    tc.relationship_type,
                    tc.notes AS relationship_notes
                FROM ref.setup_task_container_support AS tc
                JOIN ref.container AS c
                  ON c.container_id = tc.container_id
                LEFT JOIN ops.setup_container_state AS cs
                  ON cs.setup_session_id = %s
                 AND cs.container_id = c.container_id
                LEFT JOIN ref.stage AS s
                  ON s.stage_id = cs.current_stage_id
                WHERE tc.setup_task_id = ANY(%s)
                ORDER BY tc.setup_task_id, c.container_id
                """,
                (setup_session_id, normalized_task_ids),
            )
            for row in cur.fetchall():
                task_id = int(row["setup_task_id"])
                if task_id in contexts:
                    contexts[task_id]["support_containers"].append(dict(row))

        return contexts


    def manager_material_status(self, season_year: int) -> dict[str, Any]:
        """Manager-only annual material oversight across scheduled and unscheduled work.

        The Rolling Pick List remains the execution surface. This projection
        extends the same accepted material authorities to included annual work
        that is not yet scheduled, then overlays movement truth and Workshop
        endpoint policy without creating a second material store.
        """
        readiness = self.material_readiness(season_year)
        session = readiness.get("session")
        if session is None:
            return {
                "session": None,
                "items": [],
                "unresolved_requirements": [],
                "stages": [],
                "summary": {
                    "picked_moved": 0,
                    "scheduled_to_pick": 0,
                    "unscheduled_pickable": 0,
                    "workshop": 0,
                    "unresolved": 0,
                },
            }

        setup_session_id = int(session["setup_session_id"])
        tasks_by_session_id, _downstream = self._annual_demand_graph(setup_session_id)
        material_bearing_ids = self._material_bearing_session_task_ids(setup_session_id)
        for session_task_id, task in tasks_by_session_id.items():
            task["material_bearing"] = session_task_id in material_bearing_ids

        items_by_key: dict[tuple[str, int], dict[str, Any]] = {}
        for source in readiness.get("physical_items") or []:
            item = dict(source)
            item["reasons"] = [dict(reason) for reason in source.get("reasons") or []]
            item["manager_overrides"] = [
                dict(row) for row in source.get("manager_overrides") or []
            ]
            items_by_key[
                (str(item["physical_type"]).upper(), int(item["physical_id"]))
            ] = item

        schedule_origins = {"DIRECT_SCHEDULE", "DOWNSTREAM_FROM_SCHEDULE"}
        demanded_session_task_ids: set[int] = set()
        for item in items_by_key.values():
            for reason in item.get("reasons") or []:
                if str(reason.get("demand_origin") or "").upper() not in schedule_origins:
                    continue
                session_task_id = reason.get("setup_session_task_id")
                if session_task_id is not None:
                    demanded_session_task_ids.add(int(session_task_id))

        unresolved = [dict(row) for row in readiness.get("unresolved_requirements") or []]
        unresolved_session_task_ids = {
            int(row["setup_session_task_id"])
            for row in unresolved
            if row.get("setup_session_task_id") is not None
        }

        candidate_tasks: list[dict[str, Any]] = []
        for session_task_id, task in tasks_by_session_id.items():
            execution_status = str(task.get("execution_status") or "").upper()
            if execution_status in {"COMPLETE", "DEFERRED"}:
                continue
            if session_task_id in demanded_session_task_ids:
                continue

            if task.get("setup_task_id") is None:
                if session_task_id not in unresolved_session_task_ids:
                    unresolved.append({
                        "setup_work_day_task_id": None,
                        "setup_session_task_id": session_task_id,
                        "setup_task_id": None,
                        "task_name": task.get("task_name"),
                        "setup_day_number": None,
                        "work_date": None,
                        "shift_code": None,
                        "crew_lane": None,
                        "stage_id": task.get("stage_id"),
                        "stage_key": task.get("stage_key"),
                        "stage_name": task.get("stage_name"),
                        "lor_scene_id": task.get("lor_scene_id"),
                        "scene_name": task.get("scene_name"),
                        "demand_origin": "UNSCHEDULED_ANNUAL",
                        "requirement_type": "SEASON_ONLY_MATERIAL_AUTHORITY",
                        "message": (
                            "Season-only annual work has no reusable material authority. "
                            "Review whether physical material is required before adding Pick List demand."
                        ),
                    })
                continue

            if task.get("material_bearing"):
                candidate_tasks.append(task)

        candidate_task_ids = sorted({
            int(task["setup_task_id"])
            for task in candidate_tasks
            if task.get("setup_task_id") is not None
        })
        extra_by_task: dict[int, list[dict[str, Any]]] = defaultdict(list)
        for row in self._extra_material_rows(candidate_task_ids, season_year):
            extra_by_task[int(row["setup_task_id"])].append(row)

        bulk_context_by_task = self._bulk_unscheduled_material_contexts(
            setup_session_id=setup_session_id,
            task_ids=candidate_task_ids,
        )

        def ensure_item(
            physical_type: str,
            physical_id: int,
            *,
            identity: str,
            label: str | None,
            home_location_code: str | None,
        ) -> dict[str, Any]:
            key = (physical_type, int(physical_id))
            item = items_by_key.get(key)
            if item is None:
                item = {
                    "physical_type": physical_type,
                    "physical_id": int(physical_id),
                    "identity": identity,
                    "label": label,
                    "home_location_code": home_location_code,
                    "earliest_needed_for_work": None,
                    "target_staged_by": None,
                    "reasons": [],
                    "manager_overrides": [],
                    "override_only": False,
                }
                items_by_key[key] = item
            else:
                if not item.get("label") and label:
                    item["label"] = label
                if not item.get("home_location_code") and home_location_code:
                    item["home_location_code"] = home_location_code
            return item

        def base_reason(task: dict[str, Any]) -> dict[str, Any]:
            return {
                "setup_work_day_task_id": None,
                "setup_session_task_id": task.get("setup_session_task_id"),
                "setup_task_id": task.get("setup_task_id"),
                "task_name": task.get("task_name"),
                "setup_day_number": None,
                "work_date": None,
                "target_staged_by": None,
                "shift_code": None,
                "crew_lane": None,
                "stage_id": task.get("stage_id"),
                "stage_key": task.get("stage_key"),
                "stage_name": task.get("stage_name"),
                "lor_scene_id": task.get("lor_scene_id"),
                "scene_name": task.get("scene_name"),
                "demand_origin": "UNSCHEDULED_ANNUAL",
                "scheduled_trigger_setup_work_day_task_id": None,
                "scheduled_trigger_setup_session_task_id": None,
                "scheduled_trigger_setup_task_id": None,
                "scheduled_trigger_task_name": None,
            }

        for task in candidate_tasks:
            task_id = int(task["setup_task_id"])
            context = bulk_context_by_task.get(task_id) or {
                "displays": [],
                "support_containers": [],
                "material_resolution": {"warning": None},
            }

            material_resolution = dict(context.get("material_resolution") or {})
            if material_resolution.get("warning"):
                unresolved.append({
                    **base_reason(task),
                    "requirement_type": "DISPLAY_MATERIAL_OWNERSHIP",
                    "message": material_resolution.get("warning"),
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
                names = [str(row.get("display_name") or row["display_id"]) for row in displays]
                item = ensure_item(
                    physical_type,
                    physical_id,
                    identity=f"{'CONT' if physical_type == 'CONTAINER' else 'DISP'}:{physical_id}",
                    label=(
                        first.get("container_description")
                        if physical_type == "CONTAINER"
                        else first.get("display_name")
                    ),
                    home_location_code=first.get("home_location_code"),
                )
                item["reasons"].append({
                    **base_reason(task),
                    "reason_type": "DISPLAY_MATERIAL",
                    "reason_label": f"{len(displays)} required Display{'s' if len(displays) != 1 else ''}",
                    "reason_detail": ", ".join(names),
                    "display_ids": [int(row["display_id"]) for row in displays],
                    "display_names": names,
                })

            for support in context.get("support_containers") or []:
                container_id = int(support["container_id"])
                relationship = str(support.get("relationship_type") or "SUPPORT")
                item = ensure_item(
                    "CONTAINER",
                    container_id,
                    identity=f"CONT:{container_id}",
                    label=support.get("container_description") or f"Container {container_id}",
                    home_location_code=support.get("home_location_code"),
                )
                item["reasons"].append({
                    **base_reason(task),
                    "reason_type": relationship,
                    "reason_label": relationship.replace("_", " ").title(),
                    "reason_detail": support.get("relationship_notes"),
                    "display_ids": [],
                    "display_names": [],
                })

            requirement_sources: dict[int, int] = defaultdict(int)
            for extra in extra_by_task.get(task_id, []):
                requirement_id = int(extra["setup_task_extra_material_id"])
                if extra.get("container_id") is None:
                    continue
                requirement_sources[requirement_id] += 1
                container_id = int(extra["container_id"])
                material_name = str(extra.get("material_name") or "Extra Material")
                item = ensure_item(
                    "CONTAINER",
                    container_id,
                    identity=f"CONT:{container_id}",
                    label=extra.get("container_description") or f"Container {container_id}",
                    home_location_code=extra.get("home_location_code"),
                )
                item["reasons"].append({
                    **base_reason(task),
                    "reason_type": "EXTRA_MATERIAL_SOURCE",
                    "reason_label": material_name,
                    "reason_detail": extra.get("source_verification_state"),
                    "display_ids": [],
                    "display_names": [],
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
            for extra in extra_by_task.get(task_id, []):
                requirement_id = int(extra["setup_task_extra_material_id"])
                if requirement_id in seen_requirements:
                    continue
                seen_requirements.add(requirement_id)
                if requirement_sources.get(requirement_id, 0) == 0:
                    unresolved.append({
                        **base_reason(task),
                        "requirement_type": "EXTRA_MATERIAL_SOURCE",
                        "extra_material_id": extra.get("setup_extra_material_id"),
                        "extra_material_name": extra.get("material_name"),
                        "quantity_required": extra.get("quantity_required"),
                        "quantity_uom": extra.get("quantity_uom"),
                        "message": "Required Extra Material has no active expected-source Container.",
                    })

        items = list(items_by_key.values())
        container_ids = sorted({
            int(item["physical_id"])
            for item in items
            if item["physical_type"] == "CONTAINER"
        })
        display_ids = sorted({
            int(item["physical_id"])
            for item in items
            if item["physical_type"] == "DISPLAY"
        })
        observation_state = self._observation_state(
            setup_session_id=setup_session_id,
            container_ids=container_ids,
            display_ids=display_ids,
        )
        endpoint_policy = self._container_endpoint_policy(container_ids)

        outbound_statuses = {
            "PICKED",
            "LOADED",
            "IN_TRANSIT",
            "DELIVERED",
            "UNLOADED",
            "STAGED",
            "PLACED",
            "RELOCATED",
            "CONTAINER_MOVE",
            "DISPLAY_MOVE",
            "TASK_UNLOAD",
        }

        for item in items:
            key = (str(item["physical_type"]).upper(), int(item["physical_id"]))
            observation = dict(observation_state.get(key) or {})
            item["current_observation"] = observation or None

            origins = {
                str(reason.get("demand_origin") or "").upper()
                for reason in item.get("reasons") or []
            }
            has_schedule_demand = bool(origins & schedule_origins)
            has_unscheduled_demand = "UNSCHEDULED_ANNUAL" in origins
            has_override = bool(item.get("manager_overrides"))
            movement_status = str(observation.get("movement_status") or "").upper()
            moved = bool(
                observation.get("has_pick_event")
                or movement_status in outbound_statuses
            )
            workshop = bool(
                item["physical_type"] == "CONTAINER"
                and endpoint_policy.get(int(item["physical_id"])) == 1
            )

            if moved:
                status = "PICKED_MOVED"
            elif workshop:
                status = "WORKSHOP"
            elif has_schedule_demand or has_override:
                # Status answers whether this physical item is currently on the
                # actionable Pick List. demand_source separately explains
                # SCHEDULE vs MANAGER_OVERRIDE vs BOTH.
                status = "SCHEDULED_TO_PICK"
            else:
                status = "UNSCHEDULED_PICKABLE"

            if has_schedule_demand and has_override:
                # A later schedule must not replace, deactivate, or rewrite an
                # existing Manager override. Both planning reasons remain live;
                # the Manager may still edit/remove only the override while the
                # schedule-derived demand remains independently authoritative.
                demand_source = "BOTH"
            elif has_schedule_demand:
                demand_source = "SCHEDULE"
            elif has_override:
                demand_source = "MANAGER_OVERRIDE"
            else:
                demand_source = "NONE"

            item["status"] = status
            item["demand_source"] = demand_source
            item["on_pick_list"] = bool(has_schedule_demand or has_override)
            item["workshop_do_not_mobilize"] = workshop
            item["goes_to_endpoint_id"] = (
                endpoint_policy.get(int(item["physical_id"]))
                if item["physical_type"] == "CONTAINER"
                else None
            )
            item["can_add_to_pick_list"] = bool(
                item["physical_type"] == "CONTAINER"
                and has_unscheduled_demand
                and not has_schedule_demand
                and not has_override
                and not moved
                and not workshop
            )
            item["can_remove_from_pick_list"] = bool(
                item["physical_type"] == "CONTAINER"
                and has_override
                and not has_schedule_demand
                and not moved
            )
            item["can_remove_manager_override"] = bool(
                item["physical_type"] == "CONTAINER"
                and has_override
                and has_schedule_demand
                and not moved
            )
            item["can_edit_pick_list_override"] = bool(
                item["physical_type"] == "CONTAINER"
                and has_override
                and not moved
            )

        stage_rows: dict[int, dict[str, Any]] = {}
        for task in tasks_by_session_id.values():
            stage_id = task.get("stage_id")
            if stage_id is None:
                continue
            stage_rows[int(stage_id)] = {
                "stage_id": int(stage_id),
                "stage_key": task.get("stage_key"),
                "stage_name": task.get("stage_name"),
            }
        stages = sorted(
            stage_rows.values(),
            key=lambda row: (
                str(row.get("stage_key") or ""),
                str(row.get("stage_name") or ""),
                int(row["stage_id"]),
            ),
        )

        status_order = {
            "PICKED_MOVED": 0,
            "SCHEDULED_TO_PICK": 1,
            "UNSCHEDULED_PICKABLE": 2,
            "WORKSHOP": 3,
        }

        def item_stage_sort(item: dict[str, Any]) -> tuple[str, str]:
            reasons = item.get("reasons") or []
            stage_keys = sorted(
                str(reason.get("stage_key"))
                for reason in reasons
                if reason.get("stage_key")
            )
            stage_names = sorted(
                str(reason.get("stage_name"))
                for reason in reasons
                if reason.get("stage_name")
            )
            return (
                stage_keys[0] if stage_keys else "ZZZ",
                stage_names[0] if stage_names else "",
            )

        items.sort(
            key=lambda item: (
                item_stage_sort(item),
                status_order.get(str(item.get("status")), 9),
                0 if item["physical_type"] == "CONTAINER" else 1,
                int(item["physical_id"]),
            )
        )

        summary = {
            "picked_moved": sum(1 for item in items if item["status"] == "PICKED_MOVED"),
            "scheduled_to_pick": sum(
                1 for item in items if item["status"] == "SCHEDULED_TO_PICK"
            ),
            "unscheduled_pickable": sum(
                1 for item in items if item["status"] == "UNSCHEDULED_PICKABLE"
            ),
            "workshop": sum(1 for item in items if item["status"] == "WORKSHOP"),
            "unresolved": len(unresolved),
        }

        return {
            "session": dict(session),
            "items": items,
            "unresolved_requirements": unresolved,
            "stages": stages,
            "summary": summary,
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
                "pick_list_delays": [],
                "unresolved_requirements": [],
                "summary": {
                    "scheduled_assignment_count": 0,
                    "physical_item_count": 0,
                    "container_count": 0,
                    "display_count": 0,
                    "pick_delay_count": 0,
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
        delays = self._pick_list_delays(setup_session_id)
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
        delay_by_container = {
            int(delay["container_id"]): dict(delay)
            for delay in delays
        }

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

            reasons = list(item.get("reasons") or [])
            origins = {
                str(reason.get("demand_origin") or "DIRECT_SCHEDULE")
                for reason in reasons
            }
            movement_status = str(observation.get("movement_status") or "").upper()
            has_outbound_movement = movement_status in {
                "PICKED",
                "LOADED",
                "IN_TRANSIT",
                "DELIVERED",
                "UNLOADED",
                "STAGED",
                "PLACED",
                "RELOCATED",
                "CONTAINER_MOVE",
                "DISPLAY_MOVE",
                "TASK_UNLOAD",
            }
            has_legacy_unclassified_movement = bool(
                not movement_status
                and observation.get("last_movement_event_id") is not None
            )
            item["pick_delay_eligible"] = bool(
                item["physical_type"] == "CONTAINER"
                and not has_outbound_movement
                and not has_legacy_unclassified_movement
                and origins == {"DOWNSTREAM_FROM_SCHEDULE"}
            )
            delay = (
                delay_by_container.get(int(item["physical_id"]))
                if item["physical_type"] == "CONTAINER"
                and "DIRECT_SCHEDULE" not in origins
                and "MANAGER_OVERRIDE" not in origins
                else None
            )
            item["pick_delay"] = delay
            item["pick_delayed"] = bool(delay)

        return {
            "session": dict(session),
            "scheduled_work": scheduled_work,
            "physical_items": physical_items,
            "pick_list_overrides": overrides,
            "pick_list_delays": delays,
            "unresolved_requirements": unresolved,
            "summary": {
                "scheduled_assignment_count": len(assignments),
                "physical_item_count": len(physical_items),
                "container_count": len(container_ids),
                "display_count": len(display_ids),
                "pick_delay_count": sum(1 for item in physical_items if item.get("pick_delayed")),
                "unresolved_requirement_count": len(unresolved),
            },
        }
