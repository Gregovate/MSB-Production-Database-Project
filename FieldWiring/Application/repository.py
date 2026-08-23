"""Read-only FieldWiring lookup repository adapters."""

from __future__ import annotations

import re
import sqlite3
from contextlib import contextmanager
from pathlib import Path
from typing import Any, Iterator

try:
    import psycopg2
    from psycopg2.extras import RealDictCursor
except ImportError:  # development snapshot mode does not require psycopg2
    psycopg2 = None
    RealDictCursor = None


class ConfigError(RuntimeError):
    pass


def classify_context(preview_name: str | None) -> str:
    name = (preview_name or "").lower()
    if "master musical" in name:
        return "Musical"
    if "show background" in name or name.startswith("show stage"):
        return "Background / Static"
    if "show animation" in name:
        return "Animation"
    return "Other"


def normalized_display_query(value: str) -> tuple[str, str]:
    value = value.strip()
    match = re.fullmatch(r"DISP:(\d+)", value, re.IGNORECASE)
    if match:
        return "id", match.group(1)
    if value.isdigit():
        return "id", value
    return "text", value


class Repository:
    def search_displays(self, query: str, limit: int = 40) -> list[dict[str, Any]]:
        raise NotImplementedError

    def stages(self) -> list[dict[str, Any]]:
        raise NotImplementedError

    def display_context(self, display_id: int) -> dict[str, Any] | None:
        raise NotImplementedError


class SQLiteSnapshotRepository(Repository):
    """Read-only development adapter for exported FieldWiring snapshot fixtures."""

    def __init__(self, path: str) -> None:
        self.path = Path(path)
        if not self.path.is_file():
            raise ConfigError(f"FIELDWIRING_DEV_SNAPSHOT does not exist: {self.path}")

    @contextmanager
    def connect(self) -> Iterator[sqlite3.Connection]:
        uri = f"file:{self.path.as_posix()}?mode=ro"
        conn = sqlite3.connect(uri, uri=True)
        conn.row_factory = sqlite3.Row
        try:
            yield conn
        finally:
            conn.close()

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

    def _display_base(self, conn: sqlite3.Connection, display_id: int) -> sqlite3.Row | None:
        return conn.execute(
            """
            SELECT d.display_id, d.display_name, d.stage_id, d.lor_prop_id,
                   s.stage_key, s.stage_name
            FROM ref__display d
            LEFT JOIN ref__stage s ON s.stage_id = d.stage_id
            WHERE d.display_id = ? AND d.display_status_id = 1
            """,
            (display_id,),
        ).fetchone()

    def _occurrence_context(self, conn: sqlite3.Connection, display_name: str) -> dict[str, Any]:
        rows = conn.execute(
            """
            SELECT preview_id, preview_name, preview_stage_id,
                   scene_id, scene_name, scene_stage_id, location_type
            FROM lor_snap__v_display_lor_occurrence
            WHERE display_name = ?
            ORDER BY preview_name, scene_name
            """,
            (display_name,),
        ).fetchall()
        if not rows:
            return {
                "preview_uuid": None,
                "preview_name": None,
                "scene_uuid": None,
                "scene_name": None,
                "scope_kind": "Unresolved",
                "context_type": "Unknown",
            }
        preview_uuid = next((r["preview_id"] for r in rows if r["preview_id"]), None)
        preview_name = next((r["preview_name"] for r in rows if r["preview_name"]), None)
        non_root = next(
            (
                r
                for r in rows
                if r["location_type"] == "SCENE"
                and r["scene_name"]
                and r["scene_name"].strip().lower() != "root"
            ),
            None,
        )
        root = next(
            (
                r
                for r in rows
                if r["location_type"] == "SCENE"
                and r["scene_name"]
                and r["scene_name"].strip().lower() == "root"
            ),
            None,
        )
        selected = non_root or root
        return {
            "preview_uuid": preview_uuid,
            "preview_name": preview_name,
            "scene_uuid": selected["scene_id"] if selected else None,
            "scene_name": selected["scene_name"] if selected else None,
            "scope_kind": "Scene" if non_root else "Stage / Preview",
            "context_type": classify_context(preview_name),
        }

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
                context = self._occurrence_context(conn, row["display_name"])
                result.append(
                    {
                        "display_id": row["display_id"],
                        "display_name": row["display_name"],
                        "stage_id": row["stage_id"],
                        "stage_key": row["stage_key"],
                        "stage_name": row["stage_name"],
                        "device_type": device_type,
                        **context,
                    }
                )
                if len(result) >= limit:
                    break
            return result

    def display_context(self, display_id: int) -> dict[str, Any] | None:
        with self.connect() as conn:
            row = self._display_base(conn, display_id)
            if row is None:
                return None
            device_type = self._device_type(conn, row["lor_prop_id"])
            if (device_type or "").strip().lower() == "none":
                return None
            return {
                "display_id": row["display_id"],
                "display_name": row["display_name"],
                "stage_id": row["stage_id"],
                "stage_key": row["stage_key"],
                "stage_name": row["stage_name"],
                "device_type": device_type,
                **self._occurrence_context(conn, row["display_name"]),
            }

    def stages(self) -> list[dict[str, Any]]:
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
    """Production read adapter. Every PostgreSQL session is read-only."""

    def __init__(self, dsn: str) -> None:
        if psycopg2 is None:
            raise ConfigError("psycopg2 is required for PostgreSQL mode")
        self.dsn = dsn

    @contextmanager
    def connect(self) -> Iterator[Any]:
        conn = psycopg2.connect(self.dsn)
        conn.set_session(readonly=True, autocommit=True)
        try:
            yield conn
        finally:
            conn.close()

    @staticmethod
    def _row_dicts(cur: Any) -> list[dict[str, Any]]:
        return [dict(row) for row in cur.fetchall()]

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
            for item in base:
                context = self._display_context_with_cursor(cur, int(item["display_id"]))
                if context:
                    item.update(
                        {
                            "preview_uuid": context.get("preview_uuid"),
                            "preview_name": context.get("preview_name"),
                            "scene_uuid": context.get("scene_uuid"),
                            "scene_name": context.get("scene_name"),
                            "scope_kind": context.get("scope_kind"),
                            "context_type": context.get("context_type"),
                        }
                    )
            return base

    def _display_context_with_cursor(self, cur: Any, display_id: int) -> dict[str, Any] | None:
        cur.execute(
            """
            SELECT
                d.display_id, d.display_name, d.stage_id,
                st.stage_key, st.stage_name,
                p.device_type,
                ls.preview_uuid,
                cp.name AS preview_name,
                ls.scene_uuid,
                ls.scene_name
            FROM ref.display d
            LEFT JOIN ref.stage st ON st.stage_id = d.stage_id
            JOIN lor_snap.v_current_props p ON p.raw_prop_id = d.lor_prop_id
            LEFT JOIN ref.lor_scene_display lsd ON lsd.display_id = d.display_id
            LEFT JOIN ref.lor_scene ls ON ls.lor_scene_id = lsd.lor_scene_id
            LEFT JOIN lor_snap.v_current_previews cp ON cp.id = ls.preview_uuid
            WHERE d.display_id = %s
              AND d.display_status_id = 1
              AND upper(coalesce(p.device_type, '')) <> 'NONE'
            ORDER BY
                CASE WHEN lower(coalesce(ls.scene_name, '')) = 'root' THEN 1 ELSE 0 END,
                cp.name,
                ls.scene_name
            LIMIT 1
            """,
            (display_id,),
        )
        row = cur.fetchone()
        if row is None:
            return None
        item = dict(row)
        scene_name = item.get("scene_name")
        item["scope_kind"] = (
            "Scene"
            if scene_name and scene_name.strip().lower() != "root"
            else "Stage / Preview"
        )
        item["context_type"] = classify_context(item.get("preview_name"))
        return item

    def display_context(self, display_id: int) -> dict[str, Any] | None:
        with self.connect() as conn, conn.cursor(cursor_factory=RealDictCursor) as cur:
            return self._display_context_with_cursor(cur, display_id)

    def stages(self) -> list[dict[str, Any]]:
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
