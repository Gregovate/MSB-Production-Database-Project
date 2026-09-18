"""Repository for Setup #205 rolling Scheduling Board.

The board reads annual task snapshots and writes only through narrow governed
commands installed by migration 050. Reusable Catalog rows remain source
knowledge; season-only work exists only as an annual Setup Session occurrence.
"""
from __future__ import annotations

from contextlib import contextmanager
from typing import Any, Iterator

import psycopg2
from psycopg2.extras import RealDictCursor


class SetupSchedulingBoardRepositoryError(RuntimeError):
    pass


class SetupSchedulingBoardRepository:
    def __init__(self, dsn: str):
        self.dsn = (dsn or "").strip()
        if not self.dsn:
            raise SetupSchedulingBoardRepositoryError("Setup PostgreSQL DSN is required")

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
            raise SetupSchedulingBoardRepositoryError(message)
        return dict(row)

    def board(self, season_year: int) -> dict[str, Any]:
        with self.connect() as conn, conn.cursor(cursor_factory=RealDictCursor) as cur:
            cur.execute(
                """
                SELECT ss.setup_session_id, ss.season_year, ss.session_status, ss.notes
                FROM ops.setup_session ss
                WHERE ss.season_year = %s
                """,
                (season_year,),
            )
            session = cur.fetchone()
            if session is None:
                return {
                    "session": None,
                    "work_days": [],
                    "crews": [],
                    "captain_candidates": [],
                    "tasks": [],
                    "assignments": [],
                    "dependencies": [],
                }

            cur.execute(
                """
                SELECT
                    wd.setup_work_day_id,
                    wd.setup_session_id,
                    wd.setup_day_number,
                    wd.work_date::text AS work_date,
                    upper(to_char(wd.work_date, 'Dy')) AS day_of_week,
                    extract(isodow FROM wd.work_date)::integer AS iso_day_of_week,
                    wd.day_status,
                    wd.weather_note,
                    wd.volunteer_note,
                    wd.notes
                FROM ops.setup_work_day wd
                WHERE wd.setup_session_id = %s
                ORDER BY wd.work_date, wd.setup_day_number, wd.setup_work_day_id
                """,
                (session["setup_session_id"],),
            )
            work_days = [dict(row) for row in cur.fetchall()]

            cur.execute(
                """
                SELECT
                    c.setup_work_day_crew_id,
                    c.setup_work_day_id,
                    c.crew_number,
                    c.crew_code,
                    c.am_planned_crew_count,
                    c.pm_planned_crew_count,
                    c.captain_person_id,
                    coalesce(
                        nullif(btrim(pg_catalog.concat_ws(' ', cp.first_name, cp.last_name)), ''),
                        nullif(btrim(cp.email), '')
                    ) AS captain_display_name
                FROM ops.setup_work_day_crew c
                JOIN ops.setup_work_day wd
                  ON wd.setup_work_day_id = c.setup_work_day_id
                LEFT JOIN ref.person cp
                  ON cp.person_id = c.captain_person_id
                WHERE wd.setup_session_id = %s
                ORDER BY wd.work_date, c.crew_number
                """,
                (session["setup_session_id"],),
            )
            crews = [dict(row) for row in cur.fetchall()]

            cur.execute(
                """
                SELECT person_id, display_name, email
                FROM ref.setup_captain_person_list()
                ORDER BY display_name, person_id
                """
            )
            captain_candidates = [dict(row) for row in cur.fetchall()]

            cur.execute(
                """
                SELECT
                    st.setup_session_task_id,
                    st.setup_session_id,
                    st.setup_task_id,
                    st.task_origin,
                    st.included_flag,
                    st.execution_status,
                    st.planned_order,
                    st.planned_date::text AS planned_date,
                    st.plan_change_reason,
                    st.annual_notes,
                    st.actual_started_at,
                    st.actual_completed_at,
                    st.actual_crew_count,
                    st.actual_duration_minutes,
                    st.completion_note,
                    st.completed_by_person_id,
                    st.annual_task_name AS task_name,
                    st.annual_task_action_type AS task_action_type,
                    st.annual_stage_id AS stage_id,
                    s.stage_key,
                    s.stage_name,
                    st.annual_lor_scene_id AS lor_scene_id,
                    ls.scene_name,
                    st.annual_normal_crew_min AS normal_crew_min,
                    st.annual_normal_crew_max AS normal_crew_max,
                    st.annual_expected_duration_minutes AS expected_duration_minutes,
                    st.annual_effort_level AS effort_level,
                    st.annual_completion_point AS completion_point,
                    st.annual_readiness_note AS readiness_note,
                    st.annual_readiness_state AS readiness_state,
                    st.annual_weather_note AS weather_note,
                    coalesce(captains.captain_person_ids, ARRAY[]::integer[]) AS reusable_captain_person_ids,
                    rt.baseline_plan_order,
                    rt.active_flag AS reusable_active_flag,
                    coalesce(rt.requires_display_material, false) AS requires_display_material,
                    coalesce(resources.resource_count, 0) AS resource_count,
                    resources.resource_summary,
                    coalesce(support.support_container_count, 0) AS support_container_count,
                    support.support_container_summary,
                    coalesce(extra.extra_material_count, 0) AS extra_material_count,
                    coalesce(extra.extra_material_review_count, 0) AS extra_material_review_count,
                    extra.extra_material_summary,
                    st.linked_work_order_id,
                    st.linked_work_order_gate,
                    wo.problem AS linked_work_order_problem,
                    wo.date_completed AS linked_work_order_completed_at,
                    CASE
                        WHEN st.execution_status = 'COMPLETE' THEN true
                        WHEN st.linked_work_order_gate
                             AND st.linked_work_order_id IS NOT NULL
                             AND wo.date_completed IS NOT NULL THEN true
                        ELSE false
                    END AS effective_complete,
                    coalesce(dep.prerequisite_count, 0) AS prerequisite_count,
                    coalesce(dep.prerequisites_complete, true) AS prerequisites_complete,
                    coalesce(sched.future_assignment_count, 0) AS future_assignment_count,
                    coalesce(sched.historical_assignment_count, 0) AS historical_assignment_count,
                    coalesce(progress.progress_entries, 0) AS progress_entries,
                    coalesce(progress.completed_quantity, 0) AS completed_quantity,
                    CASE
                        WHEN st.execution_status = 'COMPLETE'
                             OR (
                                 st.linked_work_order_gate
                                 AND st.linked_work_order_id IS NOT NULL
                                 AND wo.date_completed IS NOT NULL
                             )
                            THEN 'COMPLETE'
                        WHEN st.execution_status = 'DEFERRED'
                            THEN 'DEFERRED'
                        WHEN coalesce(dep.prerequisites_complete, true) IS NOT TRUE
                            THEN 'BLOCKED'
                        WHEN st.annual_readiness_state = 'NOT_READY'
                            THEN 'BLOCKED'
                        WHEN st.linked_work_order_gate
                             AND st.linked_work_order_id IS NOT NULL
                             AND wo.date_completed IS NULL
                            THEN 'WAITING_ON_WORK_ORDER'
                        WHEN st.execution_status = 'IN_PROGRESS'
                             AND coalesce(sched.future_assignment_count, 0) = 0
                            THEN 'NEEDS_SCHEDULING_AGAIN'
                        WHEN coalesce(sched.future_assignment_count, 0) > 0
                            THEN 'SCHEDULED'
                        ELSE 'READY_TO_SCHEDULE'
                    END AS board_status
                FROM ops.setup_session_task st
                LEFT JOIN ref.setup_task rt
                  ON rt.setup_task_id = st.setup_task_id
                LEFT JOIN ref.stage s
                  ON s.stage_id = st.annual_stage_id
                LEFT JOIN ref.lor_scene ls
                  ON ls.lor_scene_id = st.annual_lor_scene_id
                LEFT JOIN ref.person completed_by
                  ON completed_by.person_id = st.completed_by_person_id
                LEFT JOIN LATERAL (
                    SELECT array_agg(c.person_id ORDER BY c.sort_order, c.person_id) AS captain_person_ids
                    FROM ref.setup_task_captain c
                    WHERE c.setup_task_id = st.setup_task_id
                      AND c.captain_role = 'CAPTAIN'
                ) captains ON true
                LEFT JOIN ops.setup_scheduling_work_order_gate wo
                  ON wo.work_order_id = st.linked_work_order_id
                LEFT JOIN LATERAL (
                    SELECT
                        count(*) AS resource_count,
                        string_agg(
                            r.resource_name
                            || CASE
                                WHEN tr.quantity_required > 1
                                    THEN ' x' || tr.quantity_required::text
                                ELSE ''
                               END
                            || CASE
                                WHEN tr.requirement_type = 'PREFERRED'
                                    THEN ' (preferred)'
                                ELSE ''
                               END,
                            ', ' ORDER BY
                                CASE tr.requirement_type WHEN 'REQUIRED' THEN 0 ELSE 1 END,
                                r.display_order,
                                r.resource_name
                        ) AS resource_summary
                    FROM ref.setup_task_resource tr
                    JOIN ref.setup_resource r
                      ON r.setup_resource_id = tr.setup_resource_id
                    WHERE tr.setup_task_id = st.setup_task_id
                      AND r.active_flag
                ) resources ON true
                LEFT JOIN LATERAL (
                    SELECT
                        count(*) AS support_container_count,
                        string_agg(
                            'C' || lpad(tc.container_id::text, 3, '0')
                            || coalesce(' · ' || nullif(btrim(c.description), ''), ''),
                            ', ' ORDER BY
                                CASE tc.relationship_type
                                    WHEN 'REQUIRED_CONTAINER' THEN 0
                                    ELSE 1
                                END,
                                tc.container_id
                        ) AS support_container_summary
                    FROM ref.setup_task_container_support tc
                    JOIN ref.container c
                      ON c.container_id = tc.container_id
                    WHERE tc.setup_task_id = st.setup_task_id
                ) support ON true
                LEFT JOIN LATERAL (
                    SELECT
                        count(*) AS extra_material_count,
                        count(*) FILTER (
                            WHERE tm.verification_state <> 'VERIFIED'
                               OR m.active_flag IS NOT TRUE
                        ) AS extra_material_review_count,
                        string_agg(
                            m.material_name
                            || CASE
                                WHEN tm.quantity_required IS NOT NULL
                                    THEN ' ' || trim(to_char(tm.quantity_required, 'FM999999990.###'))
                                         || ' ' || tm.quantity_uom
                                ELSE ''
                               END,
                            ', ' ORDER BY m.display_order, m.material_name,
                                tm.setup_task_extra_material_id
                        ) AS extra_material_summary
                    FROM ref.setup_task_extra_material tm
                    JOIN ref.setup_extra_material m
                      ON m.setup_extra_material_id = tm.setup_extra_material_id
                    WHERE tm.setup_task_id = st.setup_task_id
                      AND tm.active_flag
                ) extra ON true
                LEFT JOIN LATERAL (
                    SELECT
                        count(*) AS prerequisite_count,
                        bool_and(
                            CASE
                                WHEN pst.execution_status = 'COMPLETE' THEN true
                                WHEN pst.linked_work_order_gate
                                     AND pst.linked_work_order_id IS NOT NULL
                                     AND pwo.date_completed IS NOT NULL THEN true
                                ELSE false
                            END
                        ) AS prerequisites_complete
                    FROM ops.setup_session_task_dependency d
                    JOIN ops.setup_session_task pst
                      ON pst.setup_session_task_id = d.prerequisite_setup_session_task_id
                    LEFT JOIN ops.setup_scheduling_work_order_gate pwo
                      ON pwo.work_order_id = pst.linked_work_order_id
                    WHERE d.setup_session_task_id = st.setup_session_task_id
                ) dep ON true
                LEFT JOIN LATERAL (
                    SELECT
                        count(*) FILTER (
                            WHERE wd.day_status <> 'CANCELLED'
                              AND wd.work_date >= current_date
                              AND NOT (
                                  wdt.actual_crew_count IS NOT NULL
                                  OR wdt.started_at IS NOT NULL
                                  OR wdt.completed_at IS NOT NULL
                                  OR EXISTS (
                                      SELECT 1
                                      FROM ops.setup_task_progress p2
                                      WHERE p2.setup_work_day_task_id = wdt.setup_work_day_task_id
                                         OR (
                                             p2.setup_work_day_task_id IS NULL
                                             AND p2.setup_work_day_id = wdt.setup_work_day_id
                                             AND p2.setup_session_task_id = wdt.setup_session_task_id
                                             AND p2.shift_code = wdt.shift_code
                                         )
                                  )
                              )
                        ) AS future_assignment_count,
                        count(*) FILTER (
                            WHERE wdt.actual_crew_count IS NOT NULL
                               OR wdt.started_at IS NOT NULL
                               OR wdt.completed_at IS NOT NULL
                               OR EXISTS (
                                   SELECT 1
                                   FROM ops.setup_task_progress p3
                                   WHERE p3.setup_work_day_task_id = wdt.setup_work_day_task_id
                                      OR (
                                          p3.setup_work_day_task_id IS NULL
                                          AND p3.setup_work_day_id = wdt.setup_work_day_id
                                          AND p3.setup_session_task_id = wdt.setup_session_task_id
                                          AND p3.shift_code = wdt.shift_code
                                      )
                               )
                        ) AS historical_assignment_count
                    FROM ops.setup_work_day_task wdt
                    JOIN ops.setup_work_day wd
                      ON wd.setup_work_day_id = wdt.setup_work_day_id
                    WHERE wdt.setup_session_task_id = st.setup_session_task_id
                ) sched ON true
                LEFT JOIN LATERAL (
                    SELECT
                        count(*) AS progress_entries,
                        sum(coalesce(p.completed_quantity, 0)) AS completed_quantity
                    FROM ops.setup_task_progress p
                    WHERE p.setup_session_task_id = st.setup_session_task_id
                ) progress ON true
                WHERE st.setup_session_id = %s
                  AND st.included_flag
                ORDER BY
                    st.planned_order NULLS LAST,
                    rt.baseline_plan_order NULLS LAST,
                    st.setup_session_task_id
                """,
                (session["setup_session_id"],),
            )
            tasks = [dict(row) for row in cur.fetchall()]

            cur.execute(
                """
                SELECT
                    wdt.setup_work_day_task_id,
                    wdt.setup_work_day_id,
                    wd.setup_day_number,
                    wd.work_date::text AS work_date,
                    upper(to_char(wd.work_date, 'Dy')) AS day_of_week,
                    extract(isodow FROM wd.work_date)::integer AS iso_day_of_week,
                    wd.day_status,
                    wdt.setup_session_task_id,
                    wdt.shift_code,
                    wdt.setup_work_day_crew_id,
                    coalesce(c.crew_code, wdt.crew_lane) AS crew_lane,
                    c.crew_number,
                    c.am_planned_crew_count,
                    c.pm_planned_crew_count,
                    wdt.sort_order,
                    wdt.planned_crew_count,
                    wdt.actual_crew_count,
                    wdt.started_at,
                    wdt.completed_at,
                    wdt.notes,
                    st.task_origin,
                    st.setup_task_id,
                    st.annual_task_name AS task_name,
                    st.annual_task_action_type AS task_action_type,
                    st.annual_stage_id AS stage_id,
                    s.stage_key,
                    s.stage_name,
                    st.annual_lor_scene_id AS lor_scene_id,
                    ls.scene_name,
                    st.annual_normal_crew_min AS normal_crew_min,
                    st.annual_normal_crew_max AS normal_crew_max,
                    st.annual_expected_duration_minutes AS expected_duration_minutes,
                    st.annual_effort_level AS effort_level,
                    st.linked_work_order_id,
                    st.linked_work_order_gate,
                    wo.date_completed AS linked_work_order_completed_at,
                    CASE
                        WHEN wdt.actual_crew_count IS NOT NULL
                          OR wdt.started_at IS NOT NULL
                          OR wdt.completed_at IS NOT NULL
                          OR EXISTS (
                              SELECT 1
                              FROM ops.setup_task_progress p
                              WHERE p.setup_work_day_task_id = wdt.setup_work_day_task_id
                                 OR (
                                     p.setup_work_day_task_id IS NULL
                                     AND p.setup_work_day_id = wdt.setup_work_day_id
                                     AND p.setup_session_task_id = wdt.setup_session_task_id
                                     AND p.shift_code = wdt.shift_code
                                 )
                          )
                        THEN true
                        ELSE false
                    END AS historical_locked
                FROM ops.setup_work_day_task wdt
                JOIN ops.setup_work_day wd
                  ON wd.setup_work_day_id = wdt.setup_work_day_id
                JOIN ops.setup_session_task st
                  ON st.setup_session_task_id = wdt.setup_session_task_id
                LEFT JOIN ops.setup_work_day_crew c
                  ON c.setup_work_day_crew_id = wdt.setup_work_day_crew_id
                LEFT JOIN ref.stage s
                  ON s.stage_id = st.annual_stage_id
                LEFT JOIN ref.lor_scene ls
                  ON ls.lor_scene_id = st.annual_lor_scene_id
                LEFT JOIN ops.setup_scheduling_work_order_gate wo
                  ON wo.work_order_id = st.linked_work_order_id
                WHERE wd.setup_session_id = %s
                ORDER BY
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
                (session["setup_session_id"],),
            )
            assignments = [dict(row) for row in cur.fetchall()]

            cur.execute(
                """
                SELECT
                    d.setup_session_task_id,
                    d.prerequisite_setup_session_task_id,
                    d.dependency_origin,
                    d.dependency_note,
                    d.sort_order,
                    pst.annual_task_name AS prerequisite_task_name,
                    pst.task_origin AS prerequisite_task_origin,
                    pst.execution_status AS prerequisite_execution_status,
                    pst.linked_work_order_id AS prerequisite_work_order_id,
                    pwo.date_completed AS prerequisite_work_order_completed_at,
                    CASE
                        WHEN pst.execution_status = 'COMPLETE' THEN true
                        WHEN pst.linked_work_order_gate
                             AND pst.linked_work_order_id IS NOT NULL
                             AND pwo.date_completed IS NOT NULL THEN true
                        ELSE false
                    END AS prerequisite_complete
                FROM ops.setup_session_task_dependency d
                JOIN ops.setup_session_task st
                  ON st.setup_session_task_id = d.setup_session_task_id
                JOIN ops.setup_session_task pst
                  ON pst.setup_session_task_id = d.prerequisite_setup_session_task_id
                LEFT JOIN ops.setup_scheduling_work_order_gate pwo
                  ON pwo.work_order_id = pst.linked_work_order_id
                WHERE st.setup_session_id = %s
                ORDER BY d.setup_session_task_id, d.sort_order,
                         d.prerequisite_setup_session_task_id
                """,
                (session["setup_session_id"],),
            )
            dependencies = [dict(row) for row in cur.fetchall()]

        return {
            "session": dict(session),
            "work_days": work_days,
            "crews": crews,
            "captain_candidates": captain_candidates,
            "tasks": tasks,
            "assignments": assignments,
            "dependencies": dependencies,
        }

    def upsert_work_day(
        self,
        *,
        email: str,
        season_year: int,
        work_date: str,
        setup_day_number: int | None,
        status: str,
        weather_note: str | None,
        volunteer_note: str | None,
        notes: str | None,
    ) -> dict[str, Any]:
        with self.write_connect() as conn, conn.cursor(cursor_factory=RealDictCursor) as cur:
            cur.execute(
                """
                SELECT * FROM ops.upsert_setup_work_day(
                    %s,%s,%s::date,%s,%s,%s,%s,%s
                )
                """,
                (
                    email,
                    season_year,
                    work_date,
                    setup_day_number,
                    status,
                    weather_note,
                    volunteer_note,
                    notes,
                ),
            )
            result = self._one(cur, "Setup work-day command returned no result")
            conn.commit()
            return result

    def add_crew(self, *, email: str, work_day_id: int) -> dict[str, Any]:
        with self.write_connect() as conn, conn.cursor(cursor_factory=RealDictCursor) as cur:
            cur.execute(
                "SELECT * FROM ops.add_setup_work_day_crew(%s,%s)",
                (email, work_day_id),
            )
            result = self._one(cur, "Add Setup work-day crew returned no result")
            conn.commit()
            return result

    def update_crew(
        self,
        *,
        email: str,
        crew_id: int,
        am_planned_crew_count: int | None,
        pm_planned_crew_count: int | None,
        captain_person_id: int | None,
    ) -> dict[str, Any]:
        with self.write_connect() as conn, conn.cursor(cursor_factory=RealDictCursor) as cur:
            cur.execute(
                "SELECT * FROM ops.update_setup_work_day_crew(%s,%s,%s,%s,%s)",
                (
                    email,
                    crew_id,
                    am_planned_crew_count,
                    pm_planned_crew_count,
                    captain_person_id,
                ),
            )
            result = self._one(cur, "Update Setup work-day crew returned no result")
            conn.commit()
            return result

    def remove_crew(self, *, email: str, crew_id: int) -> dict[str, Any]:
        with self.write_connect() as conn, conn.cursor(cursor_factory=RealDictCursor) as cur:
            cur.execute(
                "SELECT * FROM ops.remove_setup_work_day_crew(%s,%s)",
                (email, crew_id),
            )
            result = self._one(cur, "Remove Setup work-day crew returned no result")
            conn.commit()
            return result

    def create_assignment(
        self,
        *,
        email: str,
        work_day_id: int,
        session_task_id: int,
        shift: str,
        crew_id: int,
        sort_order: int,
    ) -> dict[str, Any]:
        with self.write_connect() as conn, conn.cursor(cursor_factory=RealDictCursor) as cur:
            cur.execute(
                """
                SELECT * FROM ops.create_setup_work_day_assignment(
                    %s,%s,%s,%s,%s,%s
                )
                """,
                (
                    email,
                    work_day_id,
                    session_task_id,
                    shift,
                    crew_id,
                    sort_order,
                ),
            )
            result = self._one(cur, "Setup assignment command returned no result")
            conn.commit()
            return result

    def update_assignment(
        self,
        *,
        email: str,
        assignment_id: int,
        work_day_id: int,
        shift: str,
        crew_id: int,
        sort_order: int,
    ) -> dict[str, Any]:
        with self.write_connect() as conn, conn.cursor(cursor_factory=RealDictCursor) as cur:
            cur.execute(
                """
                SELECT * FROM ops.update_setup_work_day_assignment(
                    %s,%s,%s,%s,%s,%s
                )
                """,
                (
                    email,
                    assignment_id,
                    work_day_id,
                    shift,
                    crew_id,
                    sort_order,
                ),
            )
            result = self._one(cur, "Setup assignment update returned no result")
            conn.commit()
            return result

    def remove_assignment(self, *, email: str, assignment_id: int) -> dict[str, Any]:
        with self.write_connect() as conn, conn.cursor(cursor_factory=RealDictCursor) as cur:
            cur.execute(
                "SELECT * FROM ops.remove_setup_work_day_assignment(%s,%s)",
                (email, assignment_id),
            )
            result = self._one(cur, "Setup assignment removal returned no result")
            conn.commit()
            return result

    def create_season_task(
        self,
        *,
        email: str,
        season_year: int,
        task_name: str,
        stage_id: int | None,
        scene_id: int | None,
        action_type: str,
        planned_order: int | None,
        crew_min: int | None,
        crew_max: int | None,
        expected_duration_minutes: int | None,
        effort_level: str | None,
        completion_point: str | None,
        readiness_note: str | None,
        weather_note: str | None,
        linked_work_order_id: int | None,
        linked_work_order_gate: bool,
        annual_notes: str | None,
    ) -> dict[str, Any]:
        with self.write_connect() as conn, conn.cursor(cursor_factory=RealDictCursor) as cur:
            cur.execute(
                """
                SELECT * FROM ops.create_setup_season_task(
                    %s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s
                )
                """,
                (
                    email,
                    season_year,
                    task_name,
                    stage_id,
                    scene_id,
                    action_type,
                    planned_order,
                    crew_min,
                    crew_max,
                    expected_duration_minutes,
                    effort_level,
                    completion_point,
                    readiness_note,
                    weather_note,
                    linked_work_order_id,
                    linked_work_order_gate,
                    annual_notes,
                ),
            )
            result = self._one(cur, "Season-only Setup task command returned no result")
            conn.commit()
            return result

    def update_annual_task(
        self,
        *,
        email: str,
        session_task_id: int,
        task_name: str,
        stage_id: int | None,
        scene_id: int | None,
        action_type: str,
        crew_min: int | None,
        crew_max: int | None,
        expected_duration_minutes: int | None,
        effort_level: str | None,
        completion_point: str | None,
        readiness_note: str | None,
        weather_note: str | None,
        linked_work_order_id: int | None,
        linked_work_order_gate: bool,
        annual_notes: str | None,
    ) -> dict[str, Any]:
        with self.write_connect() as conn, conn.cursor(cursor_factory=RealDictCursor) as cur:
            cur.execute(
                """
                SELECT * FROM ops.update_setup_annual_task_definition(
                    %s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s
                )
                """,
                (
                    email,
                    session_task_id,
                    task_name,
                    stage_id,
                    scene_id,
                    action_type,
                    crew_min,
                    crew_max,
                    expected_duration_minutes,
                    effort_level,
                    completion_point,
                    readiness_note,
                    weather_note,
                    linked_work_order_id,
                    linked_work_order_gate,
                    annual_notes,
                ),
            )
            result = self._one(cur, "Annual Setup task update returned no result")
            conn.commit()
            return result

    def update_planning_info(
        self,
        *,
        email: str,
        session_task_id: int,
        crew_min: int | None,
        crew_max: int | None,
        expected_duration_minutes: int | None,
        effort_level: str | None,
        readiness_note: str | None,
        weather_note: str | None,
        completion_point: str | None,
    ) -> dict[str, Any]:
        with self.write_connect() as conn, conn.cursor(cursor_factory=RealDictCursor) as cur:
            cur.execute(
                """
                SELECT * FROM ops.update_setup_scheduling_task_planning_info(
                    %s,%s,%s,%s,%s,%s,%s,%s,%s
                )
                """,
                (
                    email,
                    session_task_id,
                    crew_min,
                    crew_max,
                    expected_duration_minutes,
                    effort_level,
                    readiness_note,
                    weather_note,
                    completion_point,
                ),
            )
            result = self._one(cur, "Scheduling planning-info update returned no result")
            conn.commit()
            return result

    def promote_crew_captain_to_task(
        self,
        *,
        email: str,
        session_task_id: int,
        crew_id: int,
    ) -> dict[str, Any]:
        with self.write_connect() as conn, conn.cursor(cursor_factory=RealDictCursor) as cur:
            cur.execute(
                "SELECT * FROM ops.add_setup_crew_captain_to_reusable_task(%s,%s,%s)",
                (email, session_task_id, crew_id),
            )
            result = self._one(cur, "Crew Captain knowledge update returned no result")
            conn.commit()
            return result

    def set_readiness(
        self,
        *,
        email: str,
        session_task_id: int,
        ready: bool,
    ) -> dict[str, Any]:
        with self.write_connect() as conn, conn.cursor(cursor_factory=RealDictCursor) as cur:
            cur.execute(
                "SELECT * FROM ops.set_setup_annual_task_readiness(%s,%s,%s)",
                (email, session_task_id, ready),
            )
            result = self._one(cur, "Annual Setup readiness command returned no result")
            conn.commit()
            return result

    def set_dependency(
        self,
        *,
        email: str,
        session_task_id: int,
        prerequisite_session_task_id: int,
        note: str | None,
        active: bool,
    ) -> dict[str, Any]:
        with self.write_connect() as conn, conn.cursor(cursor_factory=RealDictCursor) as cur:
            cur.execute(
                """
                SELECT * FROM ops.set_setup_session_task_dependency(
                    %s,%s,%s,%s,%s
                )
                """,
                (
                    email,
                    session_task_id,
                    prerequisite_session_task_id,
                    note,
                    active,
                ),
            )
            result = self._one(cur, "Annual Setup dependency command returned no result")
            conn.commit()
            return result
