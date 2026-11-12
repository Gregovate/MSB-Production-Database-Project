"""Task-neutral read-only Production Database field-context repository.

This module owns permanent Display -> Stage / Scene / Preview relationship
resolution for field applications. It deliberately does not decide whether a
Display is eligible for FieldWiring, Procedures, Testing, or any other task.

The filesystem Stage/Sub-stage/Scene resolver remains in
``field_context_resolver.py``. This repository supplies the authoritative
current database facts that a caller passes to that resolver.
"""
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


def _scope_kind(scene_name: str | None) -> str:
    return (
        "Scene"
        if scene_name and scene_name.strip().casefold() != "root"
        else "Stage / Preview"
    )


def _stage_payload(row: Any) -> dict[str, Any]:
    return {
        "stage_id": row["stage_id"],
        "stage_key": row["stage_key"],
        "stage_name": row["stage_name"],
        "folder_path": row["folder_path"],
    }


def _context_payload(
    *,
    preview_uuid: str | None,
    preview_name: str | None,
    preview_background_file: str | None,
    preview_revision: Any = None,
    source_filename: str | None = None,
    scene_uuid: str | None,
    scene_name: str | None,
    scene_stage_key: Any = None,
    scene_background_file: str | None = None,
) -> dict[str, Any]:
    preview = {
        "preview_uuid": preview_uuid,
        "preview_name": preview_name,
        "preview_background_file": preview_background_file,
        "preview_revision": preview_revision,
        "source_filename": source_filename,
    }
    scene = None
    if scene_uuid or scene_name:
        scene = {
            "scene_uuid": scene_uuid,
            "scene_name": scene_name,
            "scene_stage_key": scene_stage_key,
            "scene_background_file": scene_background_file,
        }
    return {
        "preview": preview,
        "scene": scene,
        "scope_kind": _scope_kind(scene_name),
        "context_type": classify_context(preview_name),
    }


class FieldContextRepository:
    """Task-neutral current Display/Stage/Scene/Preview relationship contract."""

    def search_displays(self, query: str, limit: int = 40) -> list[dict[str, Any]]:
        raise NotImplementedError

    def display_context(self, display_id: int) -> dict[str, Any] | None:
        raise NotImplementedError

    def stages(self) -> list[dict[str, Any]]:
        raise NotImplementedError


class SQLiteFieldContextRepository(FieldContextRepository):
    """Read-only shared field context over a FieldWiring SQLite fixture."""

    def __init__(self, path: str | Path) -> None:
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

    @staticmethod
    def _has_table(conn: sqlite3.Connection, table_name: str) -> bool:
        row = conn.execute(
            "SELECT 1 FROM sqlite_master WHERE type IN ('table','view') AND name = ? LIMIT 1",
            (table_name,),
        ).fetchone()
        return row is not None

    @staticmethod
    def _has_column(conn: sqlite3.Connection, table_name: str, column_name: str) -> bool:
        try:
            rows = conn.execute(f"PRAGMA table_info({table_name})").fetchall()
        except sqlite3.DatabaseError:
            return False
        return any(row["name"] == column_name for row in rows)

    def _display_base_with_connection(
        self,
        conn: sqlite3.Connection,
        display_id: int,
    ) -> sqlite3.Row | None:
        folder_sql = (
            "s.folder_path"
            if self._has_column(conn, "ref__stage", "folder_path")
            else "NULL AS folder_path"
        )
        return conn.execute(
            f"""
            SELECT d.display_id, d.display_name, d.stage_id,
                   s.stage_key, s.stage_name, {folder_sql}
            FROM ref__display d
            LEFT JOIN ref__stage s ON s.stage_id = d.stage_id
            WHERE d.display_id = ? AND d.display_status_id = 1
            """,
            (display_id,),
        ).fetchone()

    def _context_details(
        self,
        conn: sqlite3.Connection,
        preview_uuid: str | None,
        scene_uuid: str | None,
        fallback_preview_name: str | None,
        fallback_scene_name: str | None,
        fallback_scene_stage_key: Any,
    ) -> dict[str, Any]:
        preview_name = fallback_preview_name
        preview_background_file = None
        preview_revision = None
        source_filename = None
        if preview_uuid and self._has_table(conn, "lor_snap__v_current_previews"):
            row = conn.execute(
                """
                SELECT name, background_file, revision, source_filename
                FROM lor_snap__v_current_previews
                WHERE id = ? LIMIT 1
                """,
                (preview_uuid,),
            ).fetchone()
            if row:
                preview_name = row["name"] or preview_name
                preview_background_file = row["background_file"]
                preview_revision = row["revision"]
                source_filename = row["source_filename"]

        scene_name = fallback_scene_name
        scene_stage_key = fallback_scene_stage_key
        scene_background_file = None
        if (
            preview_uuid
            and scene_uuid
            and self._has_table(conn, "lor_snap__v_current_scenes")
        ):
            row = conn.execute(
                """
                SELECT name, stage_id, background_file
                FROM lor_snap__v_current_scenes
                WHERE preview_id = ? AND scene_id = ? LIMIT 1
                """,
                (preview_uuid, scene_uuid),
            ).fetchone()
            if row:
                scene_name = row["name"] or scene_name
                scene_stage_key = row["stage_id"] or scene_stage_key
                scene_background_file = row["background_file"]

        return _context_payload(
            preview_uuid=preview_uuid,
            preview_name=preview_name,
            preview_background_file=preview_background_file,
            preview_revision=preview_revision,
            source_filename=source_filename,
            scene_uuid=scene_uuid,
            scene_name=scene_name,
            scene_stage_key=scene_stage_key,
            scene_background_file=scene_background_file,
        )

    def _contexts_with_connection(
        self,
        conn: sqlite3.Connection,
        display_name: str,
    ) -> list[dict[str, Any]]:
        if not self._has_table(conn, "lor_snap__v_display_lor_occurrence"):
            return []
        rows = conn.execute(
            """
            SELECT preview_id, preview_name, preview_stage_id,
                   scene_id, scene_name, scene_stage_id, location_type
            FROM lor_snap__v_display_lor_occurrence
            WHERE display_name = ? AND location_type = 'SCENE'
            ORDER BY
                CASE WHEN lower(coalesce(scene_name, '')) = 'root' THEN 1 ELSE 0 END,
                preview_name,
                scene_name
            """,
            (display_name,),
        ).fetchall()
        contexts: list[dict[str, Any]] = []
        seen: set[tuple[Any, Any]] = set()
        for row in rows:
            key = (row["preview_id"], row["scene_id"])
            if key in seen:
                continue
            seen.add(key)
            contexts.append(
                self._context_details(
                    conn,
                    row["preview_id"],
                    row["scene_id"],
                    row["preview_name"],
                    row["scene_name"],
                    row["scene_stage_id"] or row["preview_stage_id"],
                )
            )
        return contexts

    def display_context_with_connection(
        self,
        conn: sqlite3.Connection,
        display_id: int,
    ) -> dict[str, Any] | None:
        row = self._display_base_with_connection(conn, display_id)
        if row is None:
            return None
        return {
            "display_id": row["display_id"],
            "display_name": row["display_name"],
            "stage": _stage_payload(row),
            "contexts": self._contexts_with_connection(conn, row["display_name"]),
        }

    def display_context(self, display_id: int) -> dict[str, Any] | None:
        with self.connect() as conn:
            return self.display_context_with_connection(conn, display_id)

    def search_displays(self, query: str, limit: int = 40) -> list[dict[str, Any]]:
        kind, value = normalized_display_query(query)
        if not value:
            return []
        with self.connect() as conn:
            folder_sql = (
                "s.folder_path"
                if self._has_column(conn, "ref__stage", "folder_path")
                else "NULL AS folder_path"
            )
            if kind == "id":
                rows = conn.execute(
                    f"""
                    SELECT d.display_id, d.display_name, d.stage_id,
                           s.stage_key, s.stage_name, {folder_sql}
                    FROM ref__display d
                    LEFT JOIN ref__stage s ON s.stage_id = d.stage_id
                    WHERE d.display_status_id = 1 AND d.display_id = ?
                    """,
                    (int(value),),
                ).fetchall()
            else:
                rows = conn.execute(
                    f"""
                    SELECT d.display_id, d.display_name, d.stage_id,
                           s.stage_key, s.stage_name, {folder_sql}
                    FROM ref__display d
                    LEFT JOIN ref__stage s ON s.stage_id = d.stage_id
                    WHERE d.display_status_id = 1
                      AND lower(d.display_name) LIKE lower(?)
                    ORDER BY CASE WHEN lower(d.display_name) = lower(?) THEN 0 ELSE 1 END,
                             d.display_name
                    LIMIT ?
                    """,
                    (f"%{value}%", value, limit),
                ).fetchall()
        return [
            {
                "display_id": row["display_id"],
                "display_name": row["display_name"],
                "stage": _stage_payload(row),
            }
            for row in rows
        ]

    def stages(self) -> list[dict[str, Any]]:
        with self.connect() as conn:
            folder_sql = (
                "folder_path"
                if self._has_column(conn, "ref__stage", "folder_path")
                else "NULL AS folder_path"
            )
            stage_rows = conn.execute(
                f"""
                SELECT stage_id, stage_key, stage_name, {folder_sql}, park_order, sub_order
                FROM ref__stage
                ORDER BY park_order, sub_order, stage_key
                """
            ).fetchall()
            scene_rows = []
            if self._has_table(conn, "lor_snap__v_display_lor_occurrence"):
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
            seen: set[tuple[str, Any, Any]] = set()
            for row in scene_rows:
                stage_key = row["scene_stage_id"] or row["preview_stage_id"]
                if not stage_key:
                    continue
                key = (str(stage_key), row["preview_id"], row["scene_id"])
                if key in seen:
                    continue
                seen.add(key)
                by_stage.setdefault(str(stage_key), []).append(
                    self._context_details(
                        conn,
                        row["preview_id"],
                        row["scene_id"],
                        row["preview_name"],
                        row["scene_name"],
                        stage_key,
                    )
                )

        result: list[dict[str, Any]] = []
        for row in stage_rows:
            contexts = by_stage.get(str(row["stage_key"]), [])
            result.append({"stage": _stage_payload(row), "contexts": contexts})
        return result


class PostgresFieldContextRepository(FieldContextRepository):
    """Production shared field-context adapter. Sessions are read-only."""

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

    def display_context_with_cursor(self, cur: Any, display_id: int) -> dict[str, Any] | None:
        cur.execute(
            """
            SELECT d.display_id, d.display_name, d.stage_id,
                   st.stage_key, st.stage_name, st.folder_path
            FROM ref.display d
            LEFT JOIN ref.stage st ON st.stage_id = d.stage_id
            WHERE d.display_id = %s AND d.display_status_id = 1
            """,
            (display_id,),
        )
        row = cur.fetchone()
        if row is None:
            return None
        base = dict(row)

        cur.execute(
            """
            SELECT
                ls.preview_uuid,
                cp.name AS preview_name,
                cp.background_file AS preview_background_file,
                cp.revision AS preview_revision,
                cp.source_filename,
                ls.scene_uuid,
                ls.scene_name,
                ls.stage_id AS scene_stage_id,
                ls.background_file AS scene_background_file
            FROM ref.lor_scene_display lsd
            JOIN ref.lor_scene ls ON ls.lor_scene_id = lsd.lor_scene_id
            LEFT JOIN lor_snap.v_current_previews cp ON cp.id = ls.preview_uuid
            WHERE lsd.display_id = %s
            ORDER BY
                CASE WHEN lower(coalesce(ls.scene_name, '')) = 'root' THEN 1 ELSE 0 END,
                cp.name,
                ls.scene_name
            """,
            (display_id,),
        )
        contexts = [
            _context_payload(
                preview_uuid=item.get("preview_uuid"),
                preview_name=item.get("preview_name"),
                preview_background_file=item.get("preview_background_file"),
                preview_revision=item.get("preview_revision"),
                source_filename=item.get("source_filename"),
                scene_uuid=item.get("scene_uuid"),
                scene_name=item.get("scene_name"),
                scene_stage_key=item.get("scene_stage_id"),
                scene_background_file=item.get("scene_background_file"),
            )
            for item in self._row_dicts(cur)
        ]
        return {
            "display_id": base["display_id"],
            "display_name": base["display_name"],
            "stage": _stage_payload(base),
            "contexts": contexts,
        }

    def display_context(self, display_id: int) -> dict[str, Any] | None:
        with self.connect() as conn, conn.cursor(cursor_factory=RealDictCursor) as cur:
            return self.display_context_with_cursor(cur, display_id)

    def search_displays(self, query: str, limit: int = 40) -> list[dict[str, Any]]:
        kind, value = normalized_display_query(query)
        if not value:
            return []
        with self.connect() as conn, conn.cursor(cursor_factory=RealDictCursor) as cur:
            if kind == "id":
                cur.execute(
                    """
                    SELECT d.display_id, d.display_name, d.stage_id,
                           st.stage_key, st.stage_name, st.folder_path
                    FROM ref.display d
                    LEFT JOIN ref.stage st ON st.stage_id = d.stage_id
                    WHERE d.display_status_id = 1 AND d.display_id = %s
                    """,
                    (int(value),),
                )
            else:
                cur.execute(
                    """
                    SELECT d.display_id, d.display_name, d.stage_id,
                           st.stage_key, st.stage_name, st.folder_path
                    FROM ref.display d
                    LEFT JOIN ref.stage st ON st.stage_id = d.stage_id
                    WHERE d.display_status_id = 1
                      AND d.display_name ILIKE %s
                    ORDER BY
                        CASE WHEN lower(d.display_name) = lower(%s) THEN 0 ELSE 1 END,
                        d.display_name
                    LIMIT %s
                    """,
                    (f"%{value}%", value, limit),
                )
            rows = self._row_dicts(cur)
        return [
            {
                "display_id": row["display_id"],
                "display_name": row["display_name"],
                "stage": _stage_payload(row),
            }
            for row in rows
        ]

    def stages(self) -> list[dict[str, Any]]:
        with self.connect() as conn, conn.cursor(cursor_factory=RealDictCursor) as cur:
            cur.execute(
                """
                SELECT stage_id, stage_key, stage_name, folder_path,
                       park_order, sub_order
                FROM ref.stage
                ORDER BY park_order, sub_order, stage_key
                """
            )
            stage_rows = self._row_dicts(cur)

            cur.execute(
                """
                SELECT
                    ls.stage_id,
                    ls.preview_uuid,
                    cp.name AS preview_name,
                    cp.background_file AS preview_background_file,
                    cp.revision AS preview_revision,
                    cp.source_filename,
                    ls.scene_uuid,
                    ls.scene_name,
                    ls.background_file AS scene_background_file
                FROM ref.lor_scene ls
                LEFT JOIN lor_snap.v_current_previews cp ON cp.id = ls.preview_uuid
                ORDER BY ls.stage_id, cp.name, ls.scene_name
                """
            )
            context_rows = self._row_dicts(cur)

        by_stage: dict[int, list[dict[str, Any]]] = {}
        for item in context_rows:
            by_stage.setdefault(int(item["stage_id"]), []).append(
                _context_payload(
                    preview_uuid=item.get("preview_uuid"),
                    preview_name=item.get("preview_name"),
                    preview_background_file=item.get("preview_background_file"),
                    preview_revision=item.get("preview_revision"),
                    source_filename=item.get("source_filename"),
                    scene_uuid=item.get("scene_uuid"),
                    scene_name=item.get("scene_name"),
                    scene_stage_key=item.get("stage_id"),
                    scene_background_file=item.get("scene_background_file"),
                )
            )

        return [
            {
                "stage": _stage_payload(row),
                "contexts": by_stage.get(int(row["stage_id"]), []),
            }
            for row in stage_rows
        ]
