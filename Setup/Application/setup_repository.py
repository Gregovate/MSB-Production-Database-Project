"""PostgreSQL access for the production Setup Session browser.

Reads use the application role's controlled SELECT surface. Writes call narrow
SECURITY DEFINER commands and never issue direct INSERT/UPDATE/DELETE from the
browser backend.
"""
from __future__ import annotations

from contextlib import contextmanager
from typing import Any, Iterator

import psycopg2
from psycopg2.extras import RealDictCursor


class SetupRepositoryError(RuntimeError):
    """Setup Session database work failed safely."""


class SetupRepository:
    def __init__(self, dsn: str):
        self.dsn = dsn.strip()
        if not self.dsn:
            raise SetupRepositoryError("Setup PostgreSQL DSN is required")

    @contextmanager
    def connect(self) -> Iterator[Any]:
        conn = psycopg2.connect(self.dsn)
        try:
            yield conn
        finally:
            conn.close()

    @contextmanager
    def write_connect(self) -> Iterator[Any]:
        """Open one explicit read-write transaction for a governed command.

        The shared fieldwiring_app login intentionally defaults transactions to
        read-only. Setup writes are allowed only through the narrow SECURITY
        DEFINER command functions, so the application must opt in to read-write
        mode for exactly those command transactions while ordinary reads retain
        the role-level read-only backstop.
        """
        conn = psycopg2.connect(self.dsn)
        try:
            conn.set_session(readonly=False, autocommit=False)
            yield conn
        finally:
            conn.close()

    def capabilities(self, email: str) -> dict[str, Any]:
        normalized = (email or "").strip().lower()
        with self.connect() as conn, conn.cursor(cursor_factory=RealDictCursor) as cur:
            cur.execute(
                """
                SELECT
                    email,
                    display_name,
                    role_name,
                    policy_names,
                    can_read_setup,
                    can_move_setup_assets,
                    can_manage_setup,
                    can_admin_setup
                FROM ref.setup_browser_capabilities(%s)
                """,
                (normalized,),
            )
            row = cur.fetchone()

        if row is None:
            return {
                "authenticated_email": normalized,
                "known_user": False,
                "display_name": normalized,
                "role_name": None,
                "policy_names": [],
                "can_read_setup": False,
                "can_move_setup_assets": False,
                "can_manage_setup": False,
                "can_admin_setup": False,
            }

        item = dict(row)
        return {
            "authenticated_email": normalized,
            "known_user": True,
            "display_name": item.get("display_name") or normalized,
            "role_name": item.get("role_name"),
            "policy_names": list(item.get("policy_names") or []),
            "can_read_setup": bool(item.get("can_read_setup")),
            "can_move_setup_assets": bool(item.get("can_move_setup_assets")),
            "can_manage_setup": bool(item.get("can_manage_setup")),
            "can_admin_setup": bool(item.get("can_admin_setup")),
        }

    def seasons(self) -> list[dict[str, Any]]:
        with self.connect() as conn, conn.cursor(cursor_factory=RealDictCursor) as cur:
            cur.execute(
                """
                SELECT
                    s.season_year,
                    s.season_name,
                    s.season_start_date,
                    s.season_end_date,
                    s.active_flag,
                    ss.setup_session_id,
                    ss.session_status,
                    ss.notes AS setup_session_notes
                FROM ref.season s
                LEFT JOIN ops.setup_session ss
                  ON ss.season_year = s.season_year
                ORDER BY s.season_year DESC
                """
            )
            return [dict(row) for row in cur.fetchall()]

    def stages(self) -> list[dict[str, Any]]:
        with self.connect() as conn, conn.cursor(cursor_factory=RealDictCursor) as cur:
            cur.execute(
                """
                SELECT
                    stage_id,
                    stage_key,
                    stage_name,
                    short_code,
                    folder_name,
                    folder_path,
                    park_order,
                    sub_order
                FROM ref.stage
                WHERE stage_key IS NOT NULL
                ORDER BY park_order NULLS LAST, sub_order NULLS LAST, stage_key
                """
            )
            return [dict(row) for row in cur.fetchall()]

    def tasks(self, season_year: int) -> list[dict[str, Any]]:
        with self.connect() as conn, conn.cursor(cursor_factory=RealDictCursor) as cur:
            cur.execute(
                """
                SELECT
                    t.setup_task_id,
                    t.task_name,
                    t.stage_id,
                    s.stage_key,
                    s.stage_name,
                    t.task_action_type,
                    t.display_order,
                    t.baseline_plan_order,
                    t.active_flag,
                    t.normal_crew_min,
                    t.normal_crew_max,
                    t.expected_duration_minutes,
                    t.completion_point,
                    t.readiness_note,
                    t.weather_note,
                    t.reusable_notes,
                    ss.setup_session_id,
                    ss.session_status,
                    st.setup_session_task_id,
                    st.included_flag,
                    st.verification_state,
                    st.execution_status,
                    st.planned_order,
                    st.planned_date,
                    st.actual_started_at,
                    st.actual_completed_at,
                    st.actual_crew_count,
                    st.actual_duration_minutes,
                    st.plan_change_reason,
                    st.annual_notes,
                    coalesce(dep.dependencies, '[]'::jsonb) AS dependencies
                FROM ref.setup_task t
                LEFT JOIN ref.stage s
                  ON s.stage_id = t.stage_id
                LEFT JOIN ops.setup_session ss
                  ON ss.season_year = %s
                LEFT JOIN ops.setup_session_task st
                  ON st.setup_session_id = ss.setup_session_id
                 AND st.setup_task_id = t.setup_task_id
                LEFT JOIN LATERAL (
                    SELECT jsonb_agg(
                        jsonb_build_object(
                            'setup_task_id', d.prerequisite_setup_task_id,
                            'task_name', pt.task_name,
                            'dependency_note', d.dependency_note
                        )
                        ORDER BY pt.display_order, pt.setup_task_id
                    ) AS dependencies
                    FROM ref.setup_task_dependency d
                    JOIN ref.setup_task pt
                      ON pt.setup_task_id = d.prerequisite_setup_task_id
                    WHERE d.setup_task_id = t.setup_task_id
                ) dep ON true
                WHERE t.active_flag OR st.setup_session_task_id IS NOT NULL
                ORDER BY
                    st.planned_order NULLS LAST,
                    t.baseline_plan_order NULLS LAST,
                    s.park_order NULLS LAST,
                    s.sub_order NULLS LAST,
                    s.stage_key NULLS LAST,
                    t.display_order,
                    t.setup_task_id
                """,
                (season_year,),
            )
            rows = []
            for row in cur.fetchall():
                item = dict(row)
                deps = item.get("dependencies")
                item["dependencies"] = deps if isinstance(deps, list) else list(deps or [])
                rows.append(item)
            return rows

    def movement_summary(self, season_year: int) -> dict[str, Any]:
        with self.connect() as conn, conn.cursor(cursor_factory=RealDictCursor) as cur:
            cur.execute(
                """
                SELECT
                    ss.setup_session_id,
                    ss.session_status,
                    (SELECT count(*)
                       FROM ops.setup_display_state ds
                      WHERE ds.setup_session_id = ss.setup_session_id) AS display_state_rows,
                    (SELECT count(*)
                       FROM ops.setup_container_state cs
                      WHERE cs.setup_session_id = ss.setup_session_id) AS container_state_rows,
                    (SELECT count(*)
                       FROM ops.setup_movement_event me
                      WHERE me.setup_session_id = ss.setup_session_id) AS movement_event_rows
                FROM ops.setup_session ss
                WHERE ss.season_year = %s
                """,
                (season_year,),
            )
            row = cur.fetchone()
        if row is None:
            return {
                "setup_session_id": None,
                "session_status": None,
                "display_state_rows": 0,
                "container_state_rows": 0,
                "movement_event_rows": 0,
            }
        return dict(row)

    def create_session(self, *, email: str, season_year: int, status: str) -> dict[str, Any]:
        with self.write_connect() as conn, conn.cursor(cursor_factory=RealDictCursor) as cur:
            cur.execute(
                """
                SELECT *
                FROM ops.create_setup_session(%s, %s, %s)
                """,
                (email, season_year, status),
            )
            row = cur.fetchone()
            conn.commit()
            if row is None:
                raise SetupRepositoryError("Setup Session creation returned no result")
            return dict(row)

    def create_task(self, *, email: str, payload: dict[str, Any]) -> dict[str, Any]:
        values = (
            email,
            payload.get("task_name"),
            payload.get("stage_id"),
            payload.get("task_action_type", "WORK"),
            payload.get("display_order", 100),
            payload.get("normal_crew_min"),
            payload.get("normal_crew_max"),
            payload.get("expected_duration_minutes"),
            payload.get("completion_point"),
            payload.get("readiness_note"),
            payload.get("weather_note"),
            payload.get("reusable_notes"),
        )
        with self.write_connect() as conn, conn.cursor(cursor_factory=RealDictCursor) as cur:
            cur.execute(
                """
                SELECT * FROM ref.create_setup_task(
                    %s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s
                )
                """,
                values,
            )
            row = cur.fetchone()
            conn.commit()
            if row is None:
                raise SetupRepositoryError("Setup task creation returned no result")
            return dict(row)

    def update_task(
        self,
        *,
        email: str,
        setup_task_id: int,
        payload: dict[str, Any],
    ) -> dict[str, Any]:
        values = (
            email,
            setup_task_id,
            payload.get("task_name"),
            payload.get("stage_id"),
            payload.get("task_action_type", "WORK"),
            payload.get("display_order", 100),
            payload.get("active_flag", True),
            payload.get("normal_crew_min"),
            payload.get("normal_crew_max"),
            payload.get("expected_duration_minutes"),
            payload.get("completion_point"),
            payload.get("readiness_note"),
            payload.get("weather_note"),
            payload.get("reusable_notes"),
        )
        with self.write_connect() as conn, conn.cursor(cursor_factory=RealDictCursor) as cur:
            cur.execute(
                """
                SELECT * FROM ref.update_setup_task(
                    %s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s
                )
                """,
                values,
            )
            row = cur.fetchone()
            conn.commit()
            if row is None:
                raise SetupRepositoryError("Setup task update returned no result")
            return dict(row)

    def update_session_task_review(
        self,
        *,
        email: str,
        setup_session_task_id: int,
        payload: dict[str, Any],
    ) -> dict[str, Any]:
        with self.write_connect() as conn, conn.cursor(cursor_factory=RealDictCursor) as cur:
            cur.execute(
                """
                SELECT * FROM ops.update_setup_session_task_review(
                    %s,%s,%s,%s,%s,%s,%s,%s
                )
                """,
                (
                    email,
                    setup_session_task_id,
                    payload.get("verification_state", "UNVERIFIED"),
                    payload.get("actual_started_at"),
                    payload.get("actual_completed_at"),
                    payload.get("actual_crew_count"),
                    payload.get("actual_duration_minutes"),
                    payload.get("annual_notes"),
                ),
            )
            row = cur.fetchone()
            conn.commit()
            if row is None:
                raise SetupRepositoryError("Setup annual review update returned no result")
            return dict(row)
