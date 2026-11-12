"""Governed Setup Report Correction payload preparation for Work Order Intake."""
from __future__ import annotations

from contextlib import contextmanager
from typing import Any, Iterator

import psycopg2
from psycopg2.extras import Json, RealDictCursor


class SetupWorkOrderIntakeRepositoryError(RuntimeError):
    pass


class SetupWorkOrderIntakeRepository:
    def __init__(self, dsn: str):
        self.dsn = (dsn or "").strip()
        if not self.dsn:
            raise SetupWorkOrderIntakeRepositoryError("Setup PostgreSQL DSN is required")

    @contextmanager
    def connect(self) -> Iterator[Any]:
        conn = psycopg2.connect(self.dsn)
        try:
            conn.set_session(readonly=True, autocommit=False)
            yield conn
        finally:
            conn.close()

    def assignment_context(
        self,
        *,
        session_task_id: int,
        assignment_id: int,
    ) -> dict[str, Any] | None:
        with self.connect() as conn, conn.cursor(cursor_factory=RealDictCursor) as cur:
            cur.execute(
                """
                SELECT
                    st.setup_session_task_id,
                    st.setup_task_id,
                    st.task_origin
                FROM ops.setup_work_day_task wdt
                JOIN ops.setup_session_task st
                  ON st.setup_session_task_id = wdt.setup_session_task_id
                WHERE wdt.setup_work_day_task_id = %s
                  AND st.setup_session_task_id = %s
                """,
                (assignment_id, session_task_id),
            )
            row = cur.fetchone()
            return dict(row) if row is not None else None

    def prepare(
        self,
        *,
        email: str,
        session_task_id: int,
        assignment_id: int,
        problem: str,
        suggested_correction_evidence: str | None,
        procedure_context: dict[str, Any],
    ) -> dict[str, Any]:
        with self.connect() as conn, conn.cursor(cursor_factory=RealDictCursor) as cur:
            cur.execute(
                """
                SELECT *
                FROM ops.prepare_setup_work_order_intake(
                    %s,%s,%s,%s,%s,%s
                )
                """,
                (
                    email,
                    session_task_id,
                    assignment_id,
                    problem,
                    suggested_correction_evidence,
                    Json(procedure_context),
                ),
            )
            row = cur.fetchone()
            if row is None:
                raise SetupWorkOrderIntakeRepositoryError(
                    "Setup correction Intake preparation returned no result"
                )
            return dict(row)
