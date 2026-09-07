"""Structured reusable equipment/resource access for Setup Session."""
from __future__ import annotations

from contextlib import contextmanager
from typing import Any, Iterator

import psycopg2
from psycopg2.extras import RealDictCursor


class SetupResourceRepositoryError(RuntimeError):
    """Setup resource work failed safely."""


class SetupResourceRepository:
    def __init__(self, dsn: str):
        self.dsn = dsn.strip()
        if not self.dsn:
            raise SetupResourceRepositoryError("Setup PostgreSQL DSN is required")

    @contextmanager
    def connect(self) -> Iterator[Any]:
        conn = psycopg2.connect(self.dsn)
        try:
            yield conn
        finally:
            conn.close()

    def catalog(self) -> list[dict[str, Any]]:
        with self.connect() as conn, conn.cursor(cursor_factory=RealDictCursor) as cur:
            cur.execute(
                """
                SELECT
                    setup_resource_id,
                    resource_name,
                    resource_type,
                    active_flag,
                    notes
                FROM ref.setup_resource
                WHERE active_flag
                ORDER BY resource_type, resource_name, setup_resource_id
                """
            )
            return [dict(row) for row in cur.fetchall()]

    def task_resources(self, setup_task_id: int) -> list[dict[str, Any]]:
        with self.connect() as conn, conn.cursor(cursor_factory=RealDictCursor) as cur:
            cur.execute(
                """
                SELECT
                    tr.setup_task_id,
                    tr.setup_resource_id,
                    r.resource_name,
                    r.resource_type,
                    tr.quantity_required,
                    tr.requirement_type,
                    tr.notes,
                    tr.active_flag
                FROM ref.setup_task_resource tr
                JOIN ref.setup_resource r
                  ON r.setup_resource_id = tr.setup_resource_id
                WHERE tr.setup_task_id = %s
                  AND tr.active_flag
                  AND r.active_flag
                ORDER BY
                    CASE tr.requirement_type WHEN 'REQUIRED' THEN 0 ELSE 1 END,
                    r.resource_type,
                    r.resource_name,
                    tr.setup_resource_id
                """,
                (setup_task_id,),
            )
            return [dict(row) for row in cur.fetchall()]

    def create_resource(self, *, email: str, payload: dict[str, Any]) -> dict[str, Any]:
        with self.connect() as conn, conn.cursor(cursor_factory=RealDictCursor) as cur:
            cur.execute(
                """
                SELECT *
                FROM ref.create_setup_resource(%s, %s, %s, %s)
                """,
                (
                    email,
                    payload.get("resource_name"),
                    payload.get("resource_type", "EQUIPMENT"),
                    payload.get("notes"),
                ),
            )
            row = cur.fetchone()
            conn.commit()
            if row is None:
                raise SetupResourceRepositoryError("Setup resource creation returned no result")
            return dict(row)

    def set_task_resource(
        self,
        *,
        email: str,
        setup_task_id: int,
        setup_resource_id: int,
        payload: dict[str, Any],
    ) -> dict[str, Any]:
        with self.connect() as conn, conn.cursor(cursor_factory=RealDictCursor) as cur:
            cur.execute(
                """
                SELECT *
                FROM ref.set_setup_task_resource(%s, %s, %s, %s, %s, %s, %s)
                """,
                (
                    email,
                    setup_task_id,
                    setup_resource_id,
                    payload.get("quantity_required", 1),
                    payload.get("requirement_type", "REQUIRED"),
                    payload.get("notes"),
                    payload.get("active_flag", True),
                ),
            )
            row = cur.fetchone()
            conn.commit()
            if row is None:
                raise SetupResourceRepositoryError("Setup task resource update returned no result")
            return dict(row)
