"""Repository for Setup V0.3 browser-review organization, planning, and field workflows."""
from __future__ import annotations

from contextlib import contextmanager
from typing import Any, Iterator

import psycopg2
from psycopg2.extras import RealDictCursor


class SetupNextRepositoryError(RuntimeError):
    pass


class SetupNextRepository:
    def __init__(self, dsn: str):
        self.dsn = (dsn or "").strip()
        if not self.dsn:
            raise SetupNextRepositoryError("Setup PostgreSQL DSN is required")

    @contextmanager
    def connect(self) -> Iterator[Any]:
        conn = psycopg2.connect(self.dsn)
        try:
            yield conn
        finally:
            conn.close()

    @staticmethod
    def _one(cur: Any, message: str) -> dict[str, Any]:
        row = cur.fetchone()
        if row is None:
            raise SetupNextRepositoryError(message)
        return dict(row)

    def organization(self) -> dict[str, list[dict[str, Any]]]:
        with self.connect() as conn, conn.cursor(cursor_factory=RealDictCursor) as cur:
            cur.execute("""
                SELECT lor_scene_id, stage_id, scene_name, scene_section,
                       preview_uuid, scene_uuid
                FROM ref.lor_scene
                ORDER BY stage_id, scene_name, lor_scene_id
            """)
            scenes = [dict(r) for r in cur.fetchall()]
            cur.execute("""
                SELECT t.setup_task_id, t.stage_id, t.lor_scene_id, ls.scene_name,
                       t.baseline_plan_order
                FROM ref.setup_task t
                LEFT JOIN ref.lor_scene ls ON ls.lor_scene_id = t.lor_scene_id
                ORDER BY t.setup_task_id
            """)
            scopes = [dict(r) for r in cur.fetchall()]
        return {"scenes": scenes, "task_scopes": scopes}

    def task_scope(self, task_id: int) -> dict[str, Any]:
        with self.connect() as conn, conn.cursor(cursor_factory=RealDictCursor) as cur:
            cur.execute("""
                SELECT t.setup_task_id, t.task_name, t.stage_id, s.stage_key,
                       s.stage_name, t.lor_scene_id, ls.scene_name
                FROM ref.setup_task t
                LEFT JOIN ref.stage s ON s.stage_id = t.stage_id
                LEFT JOIN ref.lor_scene ls ON ls.lor_scene_id = t.lor_scene_id
                WHERE t.setup_task_id = %s
            """, (task_id,))
            return self._one(cur, "Setup task was not found")

    def set_scope(self, *, email: str, task_id: int, stage_id: int | None, scene_id: int | None) -> dict[str, Any]:
        with self.connect() as conn, conn.cursor(cursor_factory=RealDictCursor) as cur:
            cur.execute("SELECT * FROM ref.set_setup_task_scope(%s,%s,%s,%s)",
                        (email, task_id, stage_id, scene_id))
            result = self._one(cur, "Setup task scope command returned no result")
            conn.commit()
            return result

    def set_dependency(self, *, email: str, task_id: int, prerequisite_id: int,
                       note: str | None, active: bool) -> dict[str, Any]:
        with self.connect() as conn, conn.cursor(cursor_factory=RealDictCursor) as cur:
            cur.execute("SELECT * FROM ref.set_setup_task_dependency(%s,%s,%s,%s,%s)",
                        (email, task_id, prerequisite_id, note, active))
            result = self._one(cur, "Setup prerequisite command returned no result")
            conn.commit()
            return result

    def set_planned_order(self, *, email: str, session_task_id: int,
                          planned_order: int, reason: str | None) -> dict[str, Any]:
        with self.connect() as conn, conn.cursor(cursor_factory=RealDictCursor) as cur:
            cur.execute(
                "SELECT * FROM ops.set_setup_session_task_planned_order(%s,%s,%s,%s)",
                (email, session_task_id, planned_order, reason),
            )
            result = self._one(cur, "Setup planned-order command returned no result")
            conn.commit()
            return result

    def promote_plan_baseline(self, *, email: str, season_year: int) -> dict[str, Any]:
        with self.connect() as conn, conn.cursor(cursor_factory=RealDictCursor) as cur:
            cur.execute(
                "SELECT * FROM ops.promote_setup_session_order_to_baseline(%s,%s)",
                (email, season_year),
            )
            result = self._one(cur, "Setup baseline-promotion command returned no result")
            conn.commit()
            return result

    def schedule(self, season_year: int) -> dict[str, list[dict[str, Any]]]:
        with self.connect() as conn, conn.cursor(cursor_factory=RealDictCursor) as cur:
            cur.execute("""
                SELECT wd.setup_work_day_id, wd.setup_session_id, wd.work_date,
                       wd.day_status, wd.weather_note, wd.volunteer_note, wd.notes
                FROM ops.setup_work_day wd
                JOIN ops.setup_session ss ON ss.setup_session_id = wd.setup_session_id
                WHERE ss.season_year = %s
                ORDER BY wd.work_date, wd.setup_work_day_id
            """, (season_year,))
            days = [dict(r) for r in cur.fetchall()]
            cur.execute("""
                SELECT wd.setup_work_day_id, wdt.setup_session_task_id,
                       wdt.shift_code, wdt.crew_lane, wdt.sort_order,
                       wdt.planned_crew_count, wdt.actual_crew_count,
                       wdt.started_at, wdt.completed_at, wdt.notes,
                       st.execution_status, st.planned_order,
                       t.baseline_plan_order, t.setup_task_id, t.task_name,
                       t.stage_id, s.stage_key, s.stage_name, t.lor_scene_id,
                       ls.scene_name
                FROM ops.setup_work_day wd
                JOIN ops.setup_session ss ON ss.setup_session_id = wd.setup_session_id
                JOIN ops.setup_work_day_task wdt ON wdt.setup_work_day_id = wd.setup_work_day_id
                JOIN ops.setup_session_task st ON st.setup_session_task_id = wdt.setup_session_task_id
                JOIN ref.setup_task t ON t.setup_task_id = st.setup_task_id
                LEFT JOIN ref.stage s ON s.stage_id = t.stage_id
                LEFT JOIN ref.lor_scene ls ON ls.lor_scene_id = t.lor_scene_id
                WHERE ss.season_year = %s
                ORDER BY wd.work_date,
                    CASE wdt.shift_code WHEN 'ALL_DAY' THEN 0 WHEN 'MORNING' THEN 1 ELSE 2 END,
                    wdt.crew_lane, wdt.sort_order, st.planned_order, t.setup_task_id
            """, (season_year,))
            assignments = [dict(r) for r in cur.fetchall()]
        return {"work_days": days, "assignments": assignments}

    def upsert_work_day(self, *, email: str, season_year: int, work_date: str,
                        status: str, notes: str | None) -> dict[str, Any]:
        with self.connect() as conn, conn.cursor(cursor_factory=RealDictCursor) as cur:
            cur.execute("SELECT * FROM ops.upsert_setup_work_day(%s,%s,%s::date,%s,%s)",
                        (email, season_year, work_date, status, notes))
            result = self._one(cur, "Setup work-day command returned no result")
            conn.commit()
            return result

    def set_work_day_task(self, *, email: str, work_day_id: int, session_task_id: int,
                          shift: str, crew_lane: str, sort_order: int,
                          planned_crew: int | None, active: bool) -> dict[str, Any]:
        with self.connect() as conn, conn.cursor(cursor_factory=RealDictCursor) as cur:
            cur.execute(
                "SELECT * FROM ops.set_setup_work_day_task(%s,%s,%s,%s,%s,%s,%s,%s)",
                (email, work_day_id, session_task_id, shift, crew_lane, sort_order,
                 planned_crew, active),
            )
            result = self._one(cur, "Setup scheduled-task command returned no result")
            conn.commit()
            return result

    def execution_tasks(self, season_year: int) -> list[dict[str, Any]]:
        with self.connect() as conn, conn.cursor(cursor_factory=RealDictCursor) as cur:
            cur.execute("""
                SELECT st.setup_session_task_id, st.setup_session_id, st.setup_task_id,
                       st.execution_status, st.verification_state, st.planned_order,
                       st.planned_date, st.plan_change_reason,
                       st.actual_started_at, st.actual_completed_at, st.actual_crew_count,
                       st.completion_note, st.completed_by_person_id,
                       nullif(btrim(concat_ws(' ', cp.first_name, cp.last_name)), '') AS completed_by_name,
                       t.task_name, t.task_action_type, t.display_order,
                       t.baseline_plan_order, t.stage_id,
                       s.stage_key, s.stage_name, t.lor_scene_id, ls.scene_name,
                       t.normal_crew_min, t.normal_crew_max, t.expected_duration_minutes,
                       t.completion_point, t.readiness_note, t.weather_note,
                       coalesce(dep.prerequisites_complete, true) AS prerequisites_complete,
                       coalesce(dep.prerequisite_count, 0) AS prerequisite_count,
                       coalesce(progress.progress_entries, 0) AS progress_entries,
                       coalesce(progress.completed_quantity, 0) AS completed_quantity,
                       coalesce(schedule.scheduled_count, 0) AS scheduled_count
                FROM ops.setup_session_task st
                JOIN ops.setup_session ss ON ss.setup_session_id = st.setup_session_id
                JOIN ref.setup_task t ON t.setup_task_id = st.setup_task_id
                LEFT JOIN ref.stage s ON s.stage_id = t.stage_id
                LEFT JOIN ref.lor_scene ls ON ls.lor_scene_id = t.lor_scene_id
                LEFT JOIN ref.person cp ON cp.person_id = st.completed_by_person_id
                LEFT JOIN LATERAL (
                    SELECT count(*) AS prerequisite_count,
                           bool_and(pst.execution_status = 'COMPLETE') AS prerequisites_complete
                    FROM ref.setup_task_dependency d
                    LEFT JOIN ops.setup_session_task pst
                      ON pst.setup_session_id = st.setup_session_id
                     AND pst.setup_task_id = d.prerequisite_setup_task_id
                    WHERE d.setup_task_id = t.setup_task_id
                ) dep ON true
                LEFT JOIN LATERAL (
                    SELECT count(*) AS progress_entries,
                           sum(coalesce(p.completed_quantity, 0)) AS completed_quantity
                    FROM ops.setup_task_progress p
                    WHERE p.setup_session_task_id = st.setup_session_task_id
                ) progress ON true
                LEFT JOIN LATERAL (
                    SELECT count(*) AS scheduled_count
                    FROM ops.setup_work_day_task wdt
                    WHERE wdt.setup_session_task_id = st.setup_session_task_id
                ) schedule ON true
                WHERE ss.season_year = %s AND st.included_flag AND t.active_flag
                ORDER BY st.planned_order NULLS LAST,
                         t.baseline_plan_order NULLS LAST,
                         t.setup_task_id
            """, (season_year,))
            return [dict(r) for r in cur.fetchall()]

    def progress(self, session_task_id: int) -> list[dict[str, Any]]:
        with self.connect() as conn, conn.cursor(cursor_factory=RealDictCursor) as cur:
            cur.execute("""
                SELECT p.setup_task_progress_id, p.setup_session_task_id,
                       p.setup_work_day_id, wd.work_date, p.shift_code, p.crew_count,
                       p.completed_quantity, p.completed_units, p.progress_note,
                       p.marks_task_complete, p.recorded_at,
                       nullif(btrim(concat_ws(' ', actor.first_name, actor.last_name)), '') AS recorded_by_name
                FROM ops.setup_task_progress p
                LEFT JOIN ops.setup_work_day wd ON wd.setup_work_day_id = p.setup_work_day_id
                LEFT JOIN ref.person actor ON actor.person_id = p.created_by_person_id
                WHERE p.setup_session_task_id = %s
                ORDER BY p.recorded_at, p.setup_task_progress_id
            """, (session_task_id,))
            return [dict(r) for r in cur.fetchall()]

    def field_context(self, *, task_id: int, season_year: int) -> dict[str, list[dict[str, Any]]]:
        with self.connect() as conn, conn.cursor(cursor_factory=RealDictCursor) as cur:
            cur.execute("""
                SELECT d.display_id, d.display_name, d.container_id, ds.position_mode,
                       CASE WHEN ds.position_mode = 'DETACHED' THEN ds.current_stage_id
                            ELSE cs.current_stage_id END AS current_stage_id,
                       current_stage.stage_key AS current_stage_key,
                       current_stage.stage_name AS current_stage_name,
                       CASE WHEN ds.position_mode = 'DETACHED' THEN ds.current_location_note
                            ELSE cs.current_location_note END AS current_location_note,
                       c.location_code AS home_location_code,
                       td.relationship_type, td.notes AS relationship_notes
                FROM ref.setup_task_display td
                JOIN ref.display d ON d.display_id = td.display_id
                LEFT JOIN ref.container c ON c.container_id = d.container_id
                LEFT JOIN ops.setup_session ss ON ss.season_year = %s
                LEFT JOIN ops.setup_display_state ds
                  ON ds.setup_session_id = ss.setup_session_id AND ds.display_id = d.display_id
                LEFT JOIN ops.setup_container_state cs
                  ON cs.setup_session_id = ss.setup_session_id AND cs.container_id = d.container_id
                LEFT JOIN ref.stage current_stage
                  ON current_stage.stage_id = CASE
                      WHEN ds.position_mode = 'DETACHED' THEN ds.current_stage_id
                      ELSE cs.current_stage_id END
                WHERE td.setup_task_id = %s
                ORDER BY d.container_id NULLS LAST, d.display_name, d.display_id
            """, (season_year, task_id))
            displays = [dict(r) for r in cur.fetchall()]
            cur.execute("""
                SELECT c.container_id, c.location_code AS home_location_code,
                       cs.current_stage_id, s.stage_key AS current_stage_key,
                       s.stage_name AS current_stage_name, cs.current_location_note,
                       tc.relationship_type, tc.notes AS relationship_notes
                FROM ref.setup_task_container_support tc
                JOIN ref.container c ON c.container_id = tc.container_id
                LEFT JOIN ops.setup_session ss ON ss.season_year = %s
                LEFT JOIN ops.setup_container_state cs
                  ON cs.setup_session_id = ss.setup_session_id AND cs.container_id = c.container_id
                LEFT JOIN ref.stage s ON s.stage_id = cs.current_stage_id
                WHERE tc.setup_task_id = %s
                ORDER BY c.container_id
            """, (season_year, task_id))
            containers = [dict(r) for r in cur.fetchall()]
        return {"displays": displays, "support_containers": containers}

    def record_progress(self, *, email: str, session_task_id: int,
                        work_day_id: int | None, shift: str, crew_count: int,
                        quantity: int | None, units: str | None, note: str | None,
                        mark_complete: bool) -> dict[str, Any]:
        with self.connect() as conn, conn.cursor(cursor_factory=RealDictCursor) as cur:
            cur.execute("""
                SELECT * FROM ops.record_setup_task_progress(
                    %s,%s,%s,%s,%s,%s,%s,%s,%s
                )
            """, (email, session_task_id, work_day_id, shift, crew_count,
                    quantity, units, note, mark_complete))
            result = self._one(cur, "Setup progress command returned no result")
            conn.commit()
            return result
