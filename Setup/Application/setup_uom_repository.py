"""Governed Setup Unit-of-Measure catalog access."""
from __future__ import annotations

from contextlib import contextmanager
from typing import Any, Iterator

import psycopg2
from psycopg2.extras import RealDictCursor


class SetupUomRepositoryError(RuntimeError):
    """Setup UOM catalog work failed safely."""


class SetupUomRepository:
    def __init__(self, dsn: str):
        self.dsn = dsn.strip()
        if not self.dsn:
            raise SetupUomRepositoryError("Setup PostgreSQL DSN is required")

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

    def catalog(self, *, include_inactive: bool = False) -> list[dict[str, Any]]:
        with self.connect() as conn, conn.cursor(cursor_factory=RealDictCursor) as cur:
            cur.execute(
                """
                SELECT uom_code, display_name, active_flag, display_order, notes
                FROM ref.setup_uom
                WHERE (%s OR active_flag)
                ORDER BY display_order, uom_code
                """,
                (include_inactive,),
            )
            return [dict(row) for row in cur.fetchall()]

    def _command(self, sql: str, values: tuple[Any, ...], empty_error: str) -> dict[str, Any]:
        with self.write_connect() as conn, conn.cursor(cursor_factory=RealDictCursor) as cur:
            cur.execute(sql, values)
            row = cur.fetchone()
            conn.commit()
            if row is None:
                raise SetupUomRepositoryError(empty_error)
            return dict(row)

    def create(self, *, email: str, payload: dict[str, Any]) -> dict[str, Any]:
        return self._command(
            "SELECT * FROM ref.create_setup_uom(%s,%s,%s,%s)",
            (
                email,
                payload.get("uom_code"),
                payload.get("display_name"),
                payload.get("notes"),
            ),
            "Setup UOM creation returned no result",
        )

    def update(self, *, email: str, uom_code: str, payload: dict[str, Any]) -> dict[str, Any]:
        return self._command(
            "SELECT * FROM ref.update_setup_uom(%s,%s,%s,%s,%s,%s)",
            (
                email,
                uom_code,
                payload.get("display_name"),
                payload.get("notes"),
                payload.get("active_flag", True),
                payload.get("display_order", 100),
            ),
            "Setup UOM update returned no result",
        )
