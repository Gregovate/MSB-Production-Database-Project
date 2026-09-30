"""Repository for Setup #88 explicit physical movement capture."""
from __future__ import annotations

from contextlib import contextmanager
from typing import Any, Iterator
from uuid import UUID

import psycopg2
from psycopg2.extras import RealDictCursor


class SetupMovementRepositoryError(RuntimeError):
    pass


class SetupMovementConflictError(RuntimeError):
    pass


class SetupMovementRepository:
    def __init__(self, dsn: str):
        self.dsn = (dsn or "").strip()
        if not self.dsn:
            raise SetupMovementRepositoryError("Setup PostgreSQL DSN is required")

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
            raise SetupMovementRepositoryError(message)
        return dict(row)

    def record_event(
        self,
        *,
        email: str,
        season_year: int,
        client_event_id: UUID,
        asset_type: str,
        asset_id: int,
        movement_action: str,
        occurred_at: str,
        device_id: str | None,
        capture_method: str,
        offline_captured: bool,
        gps_latitude: float | None,
        gps_longitude: float | None,
        gps_accuracy_m: float | None,
        destination_stage_id: int | None,
        destination_location_note: str | None,
        notes: str | None,
    ) -> dict[str, Any]:
        with self.write_connect() as conn, conn.cursor(cursor_factory=RealDictCursor) as cur:
            cur.execute(
                """
                SELECT *
                FROM ops.record_setup_movement_event(
                    %s,%s,%s::uuid,%s,%s,%s,%s::timestamptz,
                    %s,%s,%s,%s,%s,%s,%s,%s,%s
                )
                """,
                (
                    email,
                    season_year,
                    str(client_event_id),
                    asset_type,
                    asset_id,
                    movement_action,
                    occurred_at,
                    device_id,
                    capture_method,
                    offline_captured,
                    gps_latitude,
                    gps_longitude,
                    gps_accuracy_m,
                    destination_stage_id,
                    destination_location_note,
                    notes,
                ),
            )
            result = self._one(cur, "Setup movement command returned no result")
            conn.commit()
            return result

    def current_state(
        self,
        *,
        season_year: int,
        asset_type: str,
        asset_id: int,
    ) -> dict[str, Any] | None:
        asset_type = str(asset_type or "").strip().upper()
        with self.connect() as conn, conn.cursor(cursor_factory=RealDictCursor) as cur:
            if asset_type == "CONTAINER":
                cur.execute(
                    """
                    SELECT
                        ss.setup_session_id,
                        'CONTAINER'::text AS asset_type,
                        c.container_id::bigint AS asset_id,
                        c.description AS label,
                        c.location_code AS home_location_code,
                        cs.movement_status,
                        cs.last_movement_at,
                        cs.current_stage_id,
                        s.stage_key,
                        s.stage_name,
                        cs.current_location_note,
                        cs.last_movement_event_id
                    FROM ops.setup_session ss
                    JOIN ref.container c ON c.container_id = %s
                    LEFT JOIN ops.setup_container_state cs
                      ON cs.setup_session_id = ss.setup_session_id
                     AND cs.container_id = c.container_id
                    LEFT JOIN ref.stage s ON s.stage_id = cs.current_stage_id
                    WHERE ss.season_year = %s
                    """,
                    (asset_id, season_year),
                )
            elif asset_type == "DISPLAY":
                cur.execute(
                    """
                    SELECT
                        ss.setup_session_id,
                        'DISPLAY'::text AS asset_type,
                        d.display_id::bigint AS asset_id,
                        d.display_name AS label,
                        c.location_code AS home_location_code,
                        ds.movement_status,
                        ds.last_movement_at,
                        ds.position_mode,
                        ds.current_stage_id,
                        s.stage_key,
                        s.stage_name,
                        ds.current_location_note,
                        ds.last_movement_event_id
                    FROM ops.setup_session ss
                    JOIN ref.display d ON d.display_id = %s
                    LEFT JOIN ref.container c ON c.container_id = d.container_id
                    LEFT JOIN ops.setup_display_state ds
                      ON ds.setup_session_id = ss.setup_session_id
                     AND ds.display_id = d.display_id
                    LEFT JOIN ref.stage s ON s.stage_id = ds.current_stage_id
                    WHERE ss.season_year = %s
                    """,
                    (asset_id, season_year),
                )
            else:
                raise SetupMovementRepositoryError(
                    "Movement asset type must be CONTAINER or DISPLAY"
                )
            row = cur.fetchone()
            return dict(row) if row is not None else None
