"""Governed Setup -> existing Work Order Intake handoff for Issue #172."""
from __future__ import annotations

from contextlib import contextmanager
from typing import Any, Iterator

import psycopg2
from psycopg2.extras import RealDictCursor


class SetupWorkOrderIntakeRepositoryError(RuntimeError):
    pass


class SetupWorkOrderIntakeRepository:
    def __init__(self, dsn: str):
        self.dsn = (dsn or "").strip()
        if not self.dsn:
            raise SetupWorkOrderIntakeRepositoryError("Setup PostgreSQL DSN is required")

    @contextmanager
    def write_connect(self) -> Iterator[Any]:
        conn = psycopg2.connect(self.dsn)
        try:
            conn.set_session(readonly=False, autocommit=False)
            yield conn
        finally:
            conn.close()

    def submit(
        self,
        *,
        email: str,
        session_task_id: int,
        problem: str,
        suggested_change: str | None,
        assignment_id: int | None,
        work_day_id: int | None,
        shift_code: str | None,
    ) -> dict[str, Any]:
        with self.write_connect() as conn, conn.cursor(cursor_factory=RealDictCursor) as cur:
            cur.execute(
                """
                SELECT *
                FROM ops.submit_setup_work_order_intake(
                    %s,%s,%s,%s,%s,%s,%s
                )
                """,
                (
                    email,
                    session_task_id,
                    problem,
                    suggested_change,
                    assignment_id,
                    work_day_id,
                    shift_code,
                ),
            )
            row = cur.fetchone()
            if row is None:
                raise SetupWorkOrderIntakeRepositoryError(
                    "Setup problem intake command returned no result"
                )
            conn.commit()
            return dict(row)
