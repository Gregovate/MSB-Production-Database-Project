"""Ordered reusable Setup prerequisite access for Issue #151."""
from __future__ import annotations

from contextlib import contextmanager
from typing import Any, Iterator

import psycopg2
from psycopg2.extras import RealDictCursor


class SetupPrerequisiteOrderRepositoryError(RuntimeError):
    pass


class SetupPrerequisiteOrderRepository:
    def __init__(self, dsn: str):
        self.dsn = (dsn or "").strip()
        if not self.dsn:
            raise SetupPrerequisiteOrderRepositoryError("Setup PostgreSQL DSN is required")

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

    def ordered_dependencies(self) -> list[dict[str, Any]]:
        with self.connect() as conn, conn.cursor(cursor_factory=RealDictCursor) as cur:
            cur.execute(
                """
                SELECT d.setup_task_id,
                       d.prerequisite_setup_task_id,
                       pt.task_name,
                       d.dependency_note,
                       d.sort_order
                FROM ref.setup_task_dependency d
                JOIN ref.setup_task pt
                  ON pt.setup_task_id = d.prerequisite_setup_task_id
                ORDER BY d.setup_task_id,
                         d.sort_order,
                         pt.display_order,
                         d.prerequisite_setup_task_id
                """
            )
            return [dict(row) for row in cur.fetchall()]

    def reorder_dependencies(
        self,
        *,
        email: str,
        task_id: int,
        prerequisite_ids: list[int],
    ) -> list[dict[str, Any]]:
        with self.write_connect() as conn, conn.cursor(cursor_factory=RealDictCursor) as cur:
            cur.execute(
                """
                SELECT *
                FROM ref.reorder_setup_task_dependencies(%s,%s,%s::bigint[])
                """,
                (email, task_id, prerequisite_ids),
            )
            rows = [dict(row) for row in cur.fetchall()]
            conn.commit()
            return rows
