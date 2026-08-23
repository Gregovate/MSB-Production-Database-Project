"""Read-only FieldWiring repository adapter over shared field context."""
from __future__ import annotations

import sqlite3
from pathlib import Path
from typing import Any

from field_context_repository import (
    ConfigError,
    PostgresFieldContextRepository,
    RealDictCursor,
    SQLiteFieldContextRepository,
    classify_context,
    normalized_display_query,
)


def _flatten_fieldwiring_context(
    shared: dict[str, Any],
    device_type: str | None,
) -> dict[str, Any]:
    """Adapt shared identity/context facts to FieldWiring's legacy flat shape."""
    stage = shared.get("stage") or {}
    contexts = shared.get("contexts") or []
    selected = contexts[0] if contexts else None
    preview = (selected or {}).get("preview") or {}
    scene = (selected or {}).get("scene") or {}
    scene_name = scene.get("scene_name")
    return {
        "display_id": shared.get("display_id"),
        "display_name": shared.get("display_name"),
        "stage_id": stage.get("stage_id"),
        "stage_key": stage.get("stage_key"),
        "stage_name": stage.get("stage_name"),
        "device_type": device_type,
        "preview_uuid": preview.get("preview_uuid"),
        "preview_name": preview.get("preview_name"),
        "scene_uuid": scene.get("scene_uuid"),
        "scene_name": scene_name,
        "scope_kind": (
            (selected or {}).get("scope_kind")
            if selected
            else "Stage / Preview"
        ),
        "context_type": (
            (selected or {}).get("context_type")
            if selected
            else classify_context(None)
        ),
    }


class Repository:
    """FieldWiring-facing repository contract.

    ``shared_*`` methods expose task-neutral identity/context facts. The legacy
    methods remain FieldWiring-filtered so the existing Wiring search/browse UI
    does not widen to inventory-only Displays.
    """

    def shared_search_displays(self, query: str, limit: int = 40) -> list[dict[str, Any]]:
        raise NotImplementedError

    def shared_display_context(self, display_id: int) -> dict[str, Any] | None:
        raise NotImplementedError

    def shared_stages(self) -> list[dict[str, Any]]:
        raise NotImplementedError

    def search_displays(self, query: str, limit: int = 40) -> list[dict[str, Any]]:
        raise NotImplementedError

    def stages(self) -> list[dict[str, Any]]:
        raise NotImplementedError

    def display_context(self, display_id: int) -> dict[str, Any] | None:
        raise NotImplementedError


class SQLiteSnapshotRepository(Repository):
    """FieldWiring adapter over the shared read-only SQLite field context."""

    def __init__(self, path: str) -> None:
        self.path = Path(path)
        self._field_context = SQLiteFieldContextRepository(self.path)

    def connect(self):
        return self._field_context.connect()

    def shared_search_displays(self, query: str, limit: int = 40) -> list[dict[str, Any]]:
        return self._field_context.search_displays(query, limit)

    def shared_display_context(self, display_id: int) -> dict[str, Any] | None:
        return self._field_context.display_context(display_id)

    def shared_stages(self) -> list[dict[str, Any]]:
        return self._field_context.stages()

    def _device_type(self, conn: sqlite3.Connection, lor_prop_id: str | None) -> str | None:
        if not lor_prop_id:
            return None
        row = conn.execute(
            """
            SELECT device_type
            FROM lor_snap__v_current_props
            WHERE raw_prop_id = ?
            LIMIT 1
            """,
            (lor_prop_id,),
        ).fetchone()
        return row[0] if row else None

    def search_displays(self, query: str, limit: int = 40) -> list[dict[str, Any]]:
        kind, value = normalized_display_query(query)
        if not value:
            return []
        with self.connect() as conn:
            if kind == "id":
                rows = conn.execute(
                    """
                    SELECT d.display_id, d.display_name, d.stage_id, d.lor_prop_id,
                           s.stage_key, s.stage_name
                    FROM ref__display d
                    LEFT JOIN ref__stage s ON s.stage_id = d.stage_id
                    WHERE d.display_status_id = 1 AND d.display_id = ?
                    """,
                    (int(value),),
                ).fetchall()
            else:
                rows = conn.execute(
                    """
                    SELECT d.display_id, d.display_name, d.stage_id, d.lor_prop_id,
                           s.stage_key, s.stage_name
                    FROM ref__display d
                    LEFT JOIN ref__stage s ON s.stage_id = d.stage_id
                    WHERE d.display_status_id = 1
                      AND lower(d.display_name) LIKE lower(?)
                    ORDER BY CASE WHEN lower(d.display_name) = lower(?) THEN 0 ELSE 1 END,
                             d.display_name
                    LIMIT ?
                    """,
                    (f"%{value}%", value, limit * 2),
                ).fetchall()

            result: list[dict[str, Any]] = []
            for row in rows:
                device_type = self._device_type(conn, row["lor_prop_id"])
                if (device_type or "").strip().lower() == "none":
                    continue
                shared = self._field_context.display_context_with_connection(
                    conn,
                    int(row["display_id"]),
                )
                if shared is None:
                    continue
                result.append(_flatten_fieldwiring_context(shared, device_type))
                if len(result) >= limit:
                    break
            return result

    def display_context(self, display_id: int) -> dict[str, Any] | None:
        with self.connect() as conn:
            row = conn.execute(
                """
                SELECT lor_prop_id
                FROM ref__display
                WHERE display_id = ? AND display_status_id = 1
                """,
                (display_id,),
            ).fetchone()
            if row is None:
                return None
            device_type = self._device_type(conn, row["lor_prop_id"])
            if (device_type or "").strip().lower() == "none":
                return None
            shared = self._field_context.display_context_with_connection(conn, display_id)
            return (
                _flatten_fieldwiring_context(shared, device_type)
                if shared is not None
                else None
            )

    def stages(self) -> list[dict[str, Any]]:
        # Preserve the accepted SQLite development-snapshot behavior exactly.
        with self.connect() as conn:
            stage_rows = conn.execute(
                """
                SELECT stage_id, stage_key, stage_name, park_order, sub_order
                FROM ref__stage
                ORDER BY park_order, sub_order, stage_key
                """
            ).fetchall()
            scene_rows = conn.execute(
                """
                SELECT DISTINCT preview_id, preview_name, preview_stage_id,
                       scene_id, scene_name, scene_stage_id
                FROM lor_snap__v_display_lor_occurrence
                WHERE location_type = 'SCENE'
                ORDER BY preview_name, scene_name
                """
            ).fetchall()

        by_stage: dict[str, list[dict[str, Any]]] = {}
        seen: set[tuple[str, str, str]] = set()
        for row in scene_rows:
            stage_key = row["scene_stage_id"] or row["preview_stage_id"]
            if not stage_key:
                continue
            scene_name = row["scene_name"] or "Root"
            key = (str(stage_key), row["preview_id"], scene_name)
            if key in seen:
                continue
            seen.add(key)
            by_stage.setdefault(str(stage_key), []).append(
                {
                    "preview_uuid": row["preview_id"],
                    "preview_name": row["preview_name"],
                    "scene_uuid": row["scene_id"],
                    "scene_name": scene_name,
                    "scope_kind": (
                        "Stage / Preview" if scene_name.strip().lower() == "root" else "Scene"
                    ),
                    "context_type": classify_context(row["preview_name"]),
                }
            )

        stages: list[dict[str, Any]] = []
        for row in stage_rows:
            contexts = by_stage.get(str(row["stage_key"]), [])
            if not contexts:
                continue
            contexts.sort(key=lambda c: (c["context_type"], c["scene_name"]))
            stages.append(
                {
                    "stage_id": row["stage_id"],
                    "stage_key": row["stage_key"],
                    "stage_name": row["stage_name"],
                    "contexts": contexts,
                }
            )
        return stages


class PostgresRepository(Repository):
    """Production FieldWiring adapter over shared read-only PostgreSQL context."""

    def __init__(self, dsn: str) -> None:
        self._field_context = PostgresFieldContextRepository(dsn)
        self.dsn = dsn

    def connect(self):
        return self._field_context.connect()

    @staticmethod
    def _row_dicts(cur: Any) -> list[dict[str, Any]]:
        return [dict(row) for row in cur.fetchall()]

    def shared_search_displays(self, query: str, limit: int = 40) -> list[dict[str, Any]]:
        return self._field_context.search_displays(query, limit)

    def shared_display_context(self, display_id: int) -> dict[str, Any] | None:
        return self._field_context.display_context(display_id)

    def shared_stages(self) -> list[dict[str, Any]]:
        return self._field_context.stages()

    @staticmethod
    def _fieldwiring_device_type(cur: Any, display_id: int) -> tuple[bool, str | None]:
        cur.execute(
            """
            SELECT p.device_type
            FROM ref.display d
            JOIN lor_snap.v_current_props p ON p.raw_prop_id = d.lor_prop_id
            WHERE d.display_id = %s
              AND d.display_status_id = 1
              AND upper(coalesce(p.device_type, '')) <> 'NONE'
            LIMIT 1
            """,
            (display_id,),
        )
        row = cur.fetchone()
        return (row is not None, row["device_type"] if row else None)

    def search_displays(self, query: str, limit: int = 40) -> list[dict[str, Any]]:
        kind, value = normalized_display_query(query)
        if not value:
            return []
        with self.connect() as conn, conn.cursor(cursor_factory=RealDictCursor) as cur:
            if kind == "id":
                cur.execute(
                    """
                    SELECT DISTINCT
                        d.display_id, d.display_name, d.stage_id,
                        s.stage_key, s.stage_name,
                        p.device_type
                    FROM ref.display d
                    LEFT JOIN ref.stage s ON s.stage_id = d.stage_id
                    JOIN lor_snap.v_current_props p ON p.raw_prop_id = d.lor_prop_id
                    WHERE d.display_status_id = 1
                      AND upper(coalesce(p.device_type, '')) <> 'NONE'
                      AND d.display_id = %s
                    """,
                    (int(value),),
                )
            else:
                cur.execute(
                    """
                    SELECT *
                    FROM (
                        SELECT DISTINCT
                            d.display_id, d.display_name, d.stage_id,
                            s.stage_key, s.stage_name,
                            p.device_type
                        FROM ref.display d
                        LEFT JOIN ref.stage s ON s.stage_id = d.stage_id
                        JOIN lor_snap.v_current_props p ON p.raw_prop_id = d.lor_prop_id
                        WHERE d.display_status_id = 1
                          AND upper(coalesce(p.device_type, '')) <> 'NONE'
                          AND d.display_name ILIKE %s
                    ) AS matches
                    ORDER BY
                        CASE WHEN lower(display_name) = lower(%s) THEN 0 ELSE 1 END,
                        display_name
                    LIMIT %s
                    """,
                    (f"%{value}%", value, limit),
                )
            base = self._row_dicts(cur)
            result: list[dict[str, Any]] = []
            for item in base:
                shared = self._field_context.display_context_with_cursor(
                    cur,
                    int(item["display_id"]),
                )
                if shared is None:
                    continue
                result.append(
                    _flatten_fieldwiring_context(shared, item.get("device_type"))
                )
            return result

    def display_context(self, display_id: int) -> dict[str, Any] | None:
        with self.connect() as conn, conn.cursor(cursor_factory=RealDictCursor) as cur:
            shared = self._field_context.display_context_with_cursor(cur, display_id)
            if shared is None:
                return None
            eligible, device_type = self._fieldwiring_device_type(cur, display_id)
            if not eligible:
                return None
            return _flatten_fieldwiring_context(shared, device_type)

    def stages(self) -> list[dict[str, Any]]:
        # Preserve the production FieldWiring browse eligibility filter exactly.
        with self.connect() as conn, conn.cursor(cursor_factory=RealDictCursor) as cur:
            cur.execute(
                """
                SELECT
                    st.stage_id, st.stage_key, st.stage_name,
                    st.park_order, st.sub_order,
                    ls.preview_uuid,
                    cp.name AS preview_name,
                    ls.scene_uuid,
                    ls.scene_name
                FROM ref.stage st
                JOIN ref.lor_scene ls ON ls.stage_id = st.stage_id
                LEFT JOIN lor_snap.v_current_previews cp ON cp.id = ls.preview_uuid
                WHERE EXISTS (
                    SELECT 1
                    FROM ref.lor_scene_display lsd
                    JOIN ref.display d ON d.display_id = lsd.display_id
                    JOIN lor_snap.v_current_props p ON p.raw_prop_id = d.lor_prop_id
                    WHERE lsd.lor_scene_id = ls.lor_scene_id
                      AND d.display_status_id = 1
                      AND upper(coalesce(p.device_type, '')) <> 'NONE'
                )
                ORDER BY st.park_order, st.sub_order, st.stage_key,
                         cp.name, ls.scene_name
                """
            )
            rows = self._row_dicts(cur)

        stages: dict[int, dict[str, Any]] = {}
        for row in rows:
            stage = stages.setdefault(
                row["stage_id"],
                {
                    "stage_id": row["stage_id"],
                    "stage_key": row["stage_key"],
                    "stage_name": row["stage_name"],
                    "contexts": [],
                },
            )
            scene_name = row.get("scene_name") or "Root"
            stage["contexts"].append(
                {
                    "preview_uuid": row.get("preview_uuid"),
                    "preview_name": row.get("preview_name"),
                    "scene_uuid": row.get("scene_uuid"),
                    "scene_name": scene_name,
                    "scope_kind": (
                        "Stage / Preview" if scene_name.strip().lower() == "root" else "Scene"
                    ),
                    "context_type": classify_context(row.get("preview_name")),
                }
            )
        return list(stages.values())
