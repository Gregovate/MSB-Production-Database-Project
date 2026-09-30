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
        captured_operator_email: str,
        capture_method: str,
        offline_captured: bool,
        gps_latitude: float | None,
        gps_longitude: float | None,
        gps_accuracy_m: float | None,
        destination_stage_id: int | None,
        destination_location_note: str | None,
        notes: str | None,
        unloaded_display_ids: list[int] | None,
        gps_fix_at: str | None,
        gps_fix_age_ms: int | None,
        gps_quality: str,
        gps_quality_note: str | None,
    ) -> dict[str, Any]:
        with self.write_connect() as conn, conn.cursor(cursor_factory=RealDictCursor) as cur:
            cur.execute(
                """
                SELECT *
                FROM ops.record_setup_movement_event(
                    %s,%s,%s::uuid,%s,%s,%s,%s::timestamptz,
                    %s,%s,%s,%s,%s,%s,%s,%s,%s,%s,
                    %s,%s,%s,%s,%s
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
                    captured_operator_email,
                    capture_method,
                    offline_captured,
                    gps_latitude,
                    gps_longitude,
                    gps_accuracy_m,
                    destination_stage_id,
                    destination_location_note,
                    notes,
                    unloaded_display_ids or [],
                    gps_fix_at,
                    gps_fix_age_ms,
                    gps_quality,
                    gps_quality_note,
                ),
            )
            result = self._one(cur, "Setup movement command returned no result")
            conn.commit()
            return result

    def container_contents(
        self,
        *,
        season_year: int,
        container_id: int,
    ) -> dict[str, Any] | None:
        with self.connect() as conn, conn.cursor(cursor_factory=RealDictCursor) as cur:
            cur.execute(
                """
                SELECT
                    ss.setup_session_id,
                    c.container_id,
                    c.description AS label,
                    c.location_code AS home_location_code,
                    cs.movement_status,
                    cs.last_movement_at,
                    cs.current_stage_id,
                    cs.current_location_note,
                    cs.last_movement_event_id
                FROM ref.container AS c
                LEFT JOIN ops.setup_session AS ss
                  ON ss.season_year = %s
                 AND ss.session_status NOT IN ('COMPLETE', 'HISTORICAL_VERIFICATION')
                LEFT JOIN ops.setup_container_state AS cs
                  ON cs.setup_session_id = ss.setup_session_id
                 AND cs.container_id = c.container_id
                WHERE c.container_id = %s
                """,
                (season_year, container_id),
            )
            container = cur.fetchone()
            if container is None:
                return None

            cur.execute(
                """
                WITH active_session AS (
                    SELECT setup_session_id
                    FROM ops.setup_session
                    WHERE season_year = %s
                      AND session_status NOT IN ('COMPLETE', 'HISTORICAL_VERIFICATION')
                    LIMIT 1
                ),
                display_stage AS (
                    SELECT
                        d.display_id,
                        d.display_name,
                        coalesce(ds.position_mode, 'WITH_CONTAINER') AS position_mode,
                        coalesce(
                            array_agg(DISTINCT ls.stage_id)
                                FILTER (WHERE ls.stage_id IS NOT NULL),
                            ARRAY[]::integer[]
                        ) AS stage_ids
                    FROM ref.display AS d
                    JOIN ref.display_status AS status
                      ON status.display_status_id = d.display_status_id
                    LEFT JOIN active_session AS ss ON true
                    LEFT JOIN ops.setup_display_state AS ds
                      ON ds.setup_session_id = ss.setup_session_id
                     AND ds.display_id = d.display_id
                    LEFT JOIN ref.lor_scene_display AS lsd
                      ON lsd.display_id = d.display_id
                    LEFT JOIN ref.lor_scene AS ls
                      ON ls.lor_scene_id = lsd.lor_scene_id
                    WHERE d.container_id = %s
                      AND upper(status.display_status_name) = 'ACTIVE'
                    GROUP BY
                        d.display_id,
                        d.display_name,
                        coalesce(ds.position_mode, 'WITH_CONTAINER')
                )
                SELECT
                    ds.display_id,
                    ds.display_name,
                    ds.position_mode,
                    ds.stage_ids,
                    s.stage_id,
                    s.stage_key,
                    s.stage_name
                FROM display_stage AS ds
                LEFT JOIN ref.stage AS s
                  ON cardinality(ds.stage_ids) = 1
                 AND s.stage_id = ds.stage_ids[1]
                ORDER BY ds.display_name, ds.display_id
                """,
                (season_year, container_id),
            )
            rows = [dict(row) for row in cur.fetchall()]

        groups: dict[str, dict[str, Any]] = {}
        detached_count = 0
        remaining_count = 0
        for row in rows:
            if str(row.get("position_mode") or "WITH_CONTAINER").upper() == "DETACHED":
                detached_count += 1
                continue
            remaining_count += 1
            stage_ids = list(row.get("stage_ids") or [])
            if len(stage_ids) == 1 and row.get("stage_id") is not None:
                key = f"STAGE:{int(row['stage_id'])}"
                group = groups.setdefault(
                    key,
                    {
                        "group_key": key,
                        "stage_id": int(row["stage_id"]),
                        "stage_key": row.get("stage_key"),
                        "stage_name": row.get("stage_name"),
                        "label": " — ".join(
                            value
                            for value in (
                                str(row.get("stage_key") or "").strip(),
                                str(row.get("stage_name") or "").strip(),
                            )
                            if value
                        ) or f"Stage {row['stage_id']}",
                        "bulk_selectable": True,
                        "displays": [],
                    },
                )
            else:
                key = "AMBIGUOUS" if len(stage_ids) > 1 else "UNASSIGNED"
                group = groups.setdefault(
                    key,
                    {
                        "group_key": key,
                        "stage_id": None,
                        "stage_key": None,
                        "stage_name": None,
                        "label": (
                            "Multiple Stage memberships — scan Display individually"
                            if key == "AMBIGUOUS"
                            else "No Stage grouping — scan Display individually"
                        ),
                        "bulk_selectable": False,
                        "displays": [],
                    },
                )
            group["displays"].append(
                {
                    "display_id": int(row["display_id"]),
                    "display_name": row.get("display_name"),
                }
            )

        ordered_groups = sorted(
            groups.values(),
            key=lambda group: (
                1 if not group["bulk_selectable"] else 0,
                str(group.get("stage_key") or ""),
                str(group.get("label") or ""),
            ),
        )
        for group in ordered_groups:
            group["display_count"] = len(group["displays"])
            group["display_ids"] = [
                int(display["display_id"]) for display in group["displays"]
            ]

        result = dict(container)
        result["groups"] = ordered_groups
        result["active_display_count"] = len(rows)
        result["remaining_with_container_count"] = remaining_count
        result["detached_display_count"] = detached_count
        result["mixed_stage"] = (
            sum(1 for group in ordered_groups if group["bulk_selectable"]) > 1
        )
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
                        cs.last_movement_event_id,
                        me.event_type AS last_event_type,
                        me.occurred_at AS last_observed_at,
                        me.gps_latitude,
                        me.gps_longitude,
                        me.gps_accuracy_m,
                        me.gps_fix_at,
                        me.gps_fix_age_ms,
                        me.gps_quality,
                        me.gps_quality_note,
                        me.capture_method,
                        me.offline_captured
                    FROM ops.setup_session ss
                    JOIN ref.container c ON c.container_id = %s
                    LEFT JOIN ops.setup_container_state cs
                      ON cs.setup_session_id = ss.setup_session_id
                     AND cs.container_id = c.container_id
                    LEFT JOIN ref.stage s ON s.stage_id = cs.current_stage_id
                    LEFT JOIN ops.setup_movement_event me
                      ON me.setup_movement_event_id = cs.last_movement_event_id
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
                        ds.last_movement_event_id,
                        me.event_type AS last_event_type,
                        me.occurred_at AS last_observed_at,
                        me.gps_latitude,
                        me.gps_longitude,
                        me.gps_accuracy_m,
                        me.gps_fix_at,
                        me.gps_fix_age_ms,
                        me.gps_quality,
                        me.gps_quality_note,
                        me.capture_method,
                        me.offline_captured
                    FROM ops.setup_session ss
                    JOIN ref.display d ON d.display_id = %s
                    LEFT JOIN ref.container c ON c.container_id = d.container_id
                    LEFT JOIN ops.setup_display_state ds
                      ON ds.setup_session_id = ss.setup_session_id
                     AND ds.display_id = d.display_id
                    LEFT JOIN ref.stage s ON s.stage_id = ds.current_stage_id
                    LEFT JOIN ops.setup_movement_event me
                      ON me.setup_movement_event_id = ds.last_movement_event_id
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
