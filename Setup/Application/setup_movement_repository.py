"""Repository for Setup #88 explicit physical movement capture."""
from __future__ import annotations

from contextlib import contextmanager
from typing import Any, Iterator
from uuid import UUID

import psycopg2
from psycopg2.extras import RealDictCursor, Json


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
        reconciliation: dict[str, Any] | None = None,
    ) -> dict[str, Any]:
        with self.write_connect() as conn, conn.cursor(cursor_factory=RealDictCursor) as cur:
            command = "ops.record_setup_container_reconciliation" if reconciliation else "ops.record_setup_movement_event"
            extra_placeholder = ",%s::jsonb" if reconciliation else ""
            cur.execute(
                f"""
                SELECT *
                FROM {command}(
                    %s,%s,%s::uuid,%s,%s,%s,%s::timestamptz,
                    %s,%s,%s,%s,%s,%s,%s,%s,%s,%s,
                    %s,%s,%s,%s,%s{extra_placeholder}
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
                ) + ((Json(reconciliation),) if reconciliation else ()),
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
                    ct.container_type_name,
                    cs.movement_status,
                    cs.last_movement_at,
                    cs.current_stage_id,
                    cs.current_location_note,
                    cs.last_movement_event_id
                FROM ref.container AS c
                JOIN ref.container_type AS ct USING (container_type_id)
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
        result["displays"] = [dict(row) for row in rows if row["position_mode"] == "WITH_CONTAINER"]
        result["reconciliation_allowed"] = not (
            result.get("container_type_name") == "Standalone Display" or
            (result.get("container_type_name") in {"Display Pallet", "Display-Pallet"} and len(rows) == 1)
        )
        # Read event history so legacy NULL state (C095) is corrected without
        # changing immutable observations or treating Home metadata as field truth.
        result["prior_location"] = self.effective_container_location(
            season_year=season_year, container_id=container_id)

        result["active_display_count"] = len(rows)
        result["remaining_with_container_count"] = remaining_count
        result["detached_display_count"] = detached_count
        result["mixed_stage"] = (
            sum(1 for group in ordered_groups if group["bulk_selectable"]) > 1
        )
        return result

    def effective_container_location(self, *, season_year: int, container_id: int) -> dict[str, Any] | None:
        with self.connect() as conn, conn.cursor(cursor_factory=RealDictCursor) as cur:
            cur.execute("""
                SELECT e.*, named.destination_location_note AS named_context,
                       named.setup_movement_event_id AS named_context_event_id
                FROM ops.setup_movement_event e
                JOIN ops.setup_session ss USING (setup_session_id)
                LEFT JOIN LATERAL (
                    SELECT n.destination_location_note, n.setup_movement_event_id
                    FROM ops.setup_movement_event n
                    WHERE n.setup_session_id=e.setup_session_id AND n.container_id=e.container_id
                      AND (n.occurred_at,n.setup_movement_event_id)<=(e.occurred_at,e.setup_movement_event_id)
                      AND nullif(btrim(n.destination_location_note),'') IS NOT NULL
                      AND NOT EXISTS (SELECT 1 FROM ops.setup_movement_event r
                        WHERE r.setup_session_id=e.setup_session_id AND r.container_id=e.container_id
                          AND r.event_type='RETURNED' AND r.occurred_at>=n.occurred_at AND r.occurred_at<=e.occurred_at)
                    ORDER BY n.occurred_at DESC,n.setup_movement_event_id DESC LIMIT 1
                ) named ON true
                WHERE ss.season_year=%s AND e.container_id=%s
                  AND (e.event_type='RETURNED' OR e.gps_latitude IS NOT NULL OR e.destination_stage_id IS NOT NULL
                       OR nullif(btrim(e.destination_location_note),'') IS NOT NULL)
                ORDER BY e.occurred_at DESC,e.setup_movement_event_id DESC LIMIT 1
            """, (season_year, container_id))
            row=cur.fetchone()
            if row is None:
                return None
            result=dict(row)
            if result["event_type"] == "RETURNED":
                # The event's immutable note can be NULL; the canonical destination
                # is available from the current explicit RETURNED state only.
                result["named_context"] = None
            return result

    def search_assets(
        self,
        *,
        query: str,
        limit: int = 30,
    ) -> list[dict[str, Any]]:
        text = str(query or "").strip()
        if not text:
            return []
        like = f"%{text}%"
        numeric_id = int(text) if text.isdigit() else None
        with self.connect() as conn, conn.cursor(cursor_factory=RealDictCursor) as cur:
            cur.execute(
                """
                WITH matches AS (
                    SELECT
                        'CONTAINER'::text AS asset_type,
                        c.container_id::bigint AS asset_id,
                        'CONT:' || c.container_id::text AS identity,
                        coalesce(nullif(btrim(c.description), ''), 'Container ' || c.container_id::text) AS label,
                        CASE
                            WHEN %s::bigint IS NOT NULL AND c.container_id = %s::bigint THEN 0
                            ELSE 2
                        END AS rank_order
                    FROM ref.container AS c
                    WHERE (%s::bigint IS NOT NULL AND c.container_id = %s::bigint)
                       OR c.description ILIKE %s

                    UNION ALL

                    SELECT
                        'DISPLAY'::text AS asset_type,
                        d.display_id::bigint AS asset_id,
                        'DISP:' || d.display_id::text AS identity,
                        coalesce(nullif(btrim(d.display_name), ''), 'Display ' || d.display_id::text) AS label,
                        CASE
                            WHEN %s::bigint IS NOT NULL AND d.display_id = %s::bigint THEN 0
                            ELSE 1
                        END AS rank_order
                    FROM ref.display AS d
                    WHERE (%s::bigint IS NOT NULL AND d.display_id = %s::bigint)
                       OR d.display_name ILIKE %s
                )
                SELECT asset_type, asset_id, identity, label
                FROM matches
                ORDER BY rank_order, label, asset_id
                LIMIT %s
                """,
                (
                    numeric_id,
                    numeric_id,
                    numeric_id,
                    numeric_id,
                    like,
                    numeric_id,
                    numeric_id,
                    numeric_id,
                    numeric_id,
                    like,
                    limit,
                ),
            )
            return [dict(row) for row in cur.fetchall()]

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
                     AND me.setup_session_id = ss.setup_session_id
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
                        d.container_id,
                        ct.container_type_name,
                        (SELECT count(*) FROM ref.display child JOIN ref.display_status st USING(display_status_id)
                         WHERE child.container_id=c.container_id AND upper(st.display_status_name)='ACTIVE') AS active_container_display_count,
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
                    LEFT JOIN ref.container_type ct USING(container_type_id)
                    LEFT JOIN ops.setup_display_state ds
                      ON ds.setup_session_id = ss.setup_session_id
                     AND ds.display_id = d.display_id
                    LEFT JOIN ref.stage s ON s.stage_id = ds.current_stage_id
                    LEFT JOIN ops.setup_movement_event me
                      ON me.setup_movement_event_id = ds.last_movement_event_id
                     AND me.setup_session_id = ss.setup_session_id
                    WHERE ss.season_year = %s
                    """,
                    (asset_id, season_year),
                )
            else:
                raise SetupMovementRepositoryError(
                    "Movement asset type must be CONTAINER or DISPLAY"
                )
            row = cur.fetchone()
            result = dict(row) if row is not None else None
            if result is not None and asset_type == "DISPLAY":
                # LOR assignments are suggestions, never physical placement evidence.
                cur.execute(
                    """
                    SELECT s.stage_id, s.stage_key, s.stage_name,
                           EXISTS (SELECT 1 FROM ref.lor_scene_display lsd
                                   JOIN ref.lor_scene ls USING(lor_scene_id)
                                   WHERE lsd.display_id=%s AND ls.stage_id=s.stage_id) AS assigned
                    FROM ref.stage s
                    ORDER BY s.stage_key, s.stage_id
                    """,
                    (asset_id,),
                )
                result["placement_stages"] = [dict(stage) for stage in cur.fetchall()]
        if result is not None and asset_type == "DISPLAY":
            result["can_detach"] = not (result.get("container_type_name") == "Standalone Display" or
                (result.get("container_type_name") in {"Display Pallet", "Display-Pallet"} and result.get("active_container_display_count") == 1))
        if result is not None and asset_type == "CONTAINER":
            location = self.effective_container_location(season_year=season_year, container_id=asset_id)
            if location and location.get("event_type") != "RETURNED":
                result["current_location_note"] = result.get("current_location_note") or location.get("named_context")
                result["named_context_event_id"] = location.get("named_context_event_id")
                result["location_observed_at"] = location.get("occurred_at")
                for key in ("gps_latitude", "gps_longitude", "gps_accuracy_m", "gps_fix_at", "gps_fix_age_ms", "gps_quality", "gps_quality_note"):
                    result[key] = location.get(key)
        return result
