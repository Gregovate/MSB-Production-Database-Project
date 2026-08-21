"""Read-only current wiring data access for FieldWiring."""
from __future__ import annotations

from typing import Any

from wiring_common import WiringError


def _is_sqlite(repo: Any) -> bool:
    return repo.__class__.__name__ == "SQLiteSnapshotRepository"


def _rowdict(row: Any) -> dict[str, Any]:
    if isinstance(row, dict):
        return dict(row)
    return {key: row[key] for key in row.keys()}


def _sqlite_one(conn: Any, sql: str, params: tuple[Any, ...]) -> dict[str, Any] | None:
    row = conn.execute(sql, params).fetchone()
    return _rowdict(row) if row is not None else None


def _sqlite_rows(conn: Any, sql: str, params: tuple[Any, ...]) -> list[dict[str, Any]]:
    return [_rowdict(row) for row in conn.execute(sql, params).fetchall()]


def _sqlite_package(repo: Any, preview_uuid: str, scene_uuid: str | None, stage_id: int) -> dict[str, Any]:
    with repo.connect() as conn:
        preview = _sqlite_one(conn, """
            SELECT import_run_id, id AS preview_uuid, name AS preview_name,
                   revision AS preview_revision, background_file AS preview_background_file,
                   source_filename
            FROM lor_snap__v_current_previews
            WHERE id = ? LIMIT 1
        """, (preview_uuid,))
        if preview is None:
            raise WiringError("Resolved Preview is not present in the current FieldWiring snapshot")

        stage = _sqlite_one(conn, """
            SELECT stage_id, stage_key, stage_name, folder_path
            FROM ref__stage WHERE stage_id = ? LIMIT 1
        """, (stage_id,))
        if stage is None:
            raise WiringError("Resolved Stage is not present in the current Production Database snapshot")

        scene = None
        if scene_uuid:
            scene = _sqlite_one(conn, """
                SELECT scene_id AS scene_uuid, name AS scene_name, stage_id AS scene_stage_key,
                       background_file AS scene_background_file
                FROM lor_snap__v_current_scenes
                WHERE preview_id = ? AND scene_id = ? LIMIT 1
            """, (preview_uuid, scene_uuid))
            if scene is None:
                raise WiringError("Resolved Scene is not present in the current FieldWiring snapshot")

        scene_scope = bool(scene and (scene.get("scene_name") or "").strip().casefold() != "root")
        if scene_scope:
            members_sql = """
                WITH members AS (
                    SELECT DISTINCT d.display_id,
                           d.display_name AS production_display_name,
                           p.raw_prop_id, p.lor_comment, p.string_type
                    FROM lor_snap__v_current_scene_lor_props slp
                    JOIN lor_snap__v_current_props p
                      ON p.preview_id = slp.preview_id
                     AND p.prop_id = slp.prop_id
                     AND p.raw_prop_id = slp.raw_prop_id
                    JOIN ref__display d ON d.lor_prop_id = p.raw_prop_id
                    WHERE slp.preview_id = ? AND slp.scene_id = ?
                      AND d.display_status_id = 1
                      AND upper(coalesce(p.device_type, '')) <> 'NONE'
                )
                SELECT m.display_id, m.production_display_name AS display_name,
                       fw.channel_name, fw.network, fw.controller,
                       fw.start_channel, fw.end_channel, fw.device_type,
                       m.string_type, fw.source, fw.lor_tag,
                       fw.connection_type, fw.cross_display
                FROM members m
                JOIN lor_snap__preview_wiring_fieldlead_v6 fw
                  ON fw.preview_name = ?
                 AND fw.display_name = replace(trim(m.lor_comment), ' ', '-')
                ORDER BY fw.network, fw.controller, fw.start_channel, m.production_display_name
            """
            rows = _sqlite_rows(conn, members_sql, (preview_uuid, scene_uuid, preview["preview_name"]))
        else:
            members_sql = """
                WITH members AS (
                    SELECT DISTINCT d.display_id,
                           d.display_name AS production_display_name,
                           p.raw_prop_id, p.lor_comment, p.string_type
                    FROM lor_snap__v_current_props p
                    JOIN ref__display d ON d.lor_prop_id = p.raw_prop_id
                    WHERE p.preview_id = ?
                      AND d.display_status_id = 1
                      AND upper(coalesce(p.device_type, '')) <> 'NONE'
                )
                SELECT m.display_id, m.production_display_name AS display_name,
                       fw.channel_name, fw.network, fw.controller,
                       fw.start_channel, fw.end_channel, fw.device_type,
                       m.string_type, fw.source, fw.lor_tag,
                       fw.connection_type, fw.cross_display
                FROM members m
                JOIN lor_snap__preview_wiring_fieldlead_v6 fw
                  ON fw.preview_name = ?
                 AND fw.display_name = replace(trim(m.lor_comment), ' ', '-')
                ORDER BY fw.network, fw.controller, fw.start_channel, m.production_display_name
            """
            rows = _sqlite_rows(conn, members_sql, (preview_uuid, preview["preview_name"]))

        run = _sqlite_one(conn, """
            SELECT import_run_id, run_ts, parser_version, parser_completed_at,
                   source_preview_folder, ingest_script_version, ingest_completed_at
            FROM lor_snap__v_current_run
            ORDER BY import_run_id DESC LIMIT 1
        """, ()) or {"import_run_id": preview["import_run_id"]}

    return {"preview": preview, "stage": stage, "scene": scene, "rows": rows, "run": run}


def _postgres_package(repo: Any, preview_uuid: str, scene_uuid: str | None, stage_id: int) -> dict[str, Any]:
    cursor_factory = getattr(__import__("repository"), "RealDictCursor")
    with repo.connect() as conn:
        with conn.cursor(cursor_factory=cursor_factory) as cur:
            cur.execute("""
                SELECT import_run_id, id AS preview_uuid, name AS preview_name,
                       revision AS preview_revision, background_file AS preview_background_file,
                       source_filename
                FROM lor_snap.v_current_previews
                WHERE id = %s LIMIT 1
            """, (preview_uuid,))
            row = cur.fetchone(); preview = dict(row) if row else None
            if preview is None:
                raise WiringError("Resolved Preview is not present in the current LOR snapshot")

            cur.execute("""
                SELECT stage_id, stage_key, stage_name, folder_path
                FROM ref.stage WHERE stage_id = %s LIMIT 1
            """, (stage_id,))
            row = cur.fetchone(); stage = dict(row) if row else None
            if stage is None:
                raise WiringError("Resolved Stage is not present in the Production Database")

            scene = None
            if scene_uuid:
                cur.execute("""
                    SELECT scene_id AS scene_uuid, name AS scene_name, stage_id AS scene_stage_key,
                           background_file AS scene_background_file
                    FROM lor_snap.v_current_scenes
                    WHERE preview_id = %s AND scene_id = %s LIMIT 1
                """, (preview_uuid, scene_uuid))
                row = cur.fetchone(); scene = dict(row) if row else None
                if scene is None:
                    raise WiringError("Resolved Scene is not present in the current LOR snapshot")

            scene_scope = bool(scene and (scene.get("scene_name") or "").strip().casefold() != "root")
            if scene_scope:
                cur.execute("""
                    WITH members AS (
                        SELECT DISTINCT d.display_id,
                               d.display_name AS production_display_name,
                               p.raw_prop_id, p.lor_comment, p.string_type
                        FROM lor_snap.v_current_scene_lor_props slp
                        JOIN lor_snap.v_current_props p
                          ON p.preview_id = slp.preview_id
                         AND p.prop_id = slp.prop_id
                         AND p.raw_prop_id = slp.raw_prop_id
                        JOIN ref.display d ON d.lor_prop_id = p.raw_prop_id
                        WHERE slp.preview_id = %s AND slp.scene_id = %s
                          AND d.display_status_id = 1
                          AND upper(coalesce(p.device_type, '')) <> 'NONE'
                    )
                    SELECT m.display_id, m.production_display_name AS display_name,
                           fw.channel_name, fw.network, fw.controller,
                           fw.start_channel, fw.end_channel, fw.device_type,
                           m.string_type, fw.source, fw.lor_tag,
                           fw.connection_type, fw.cross_display
                    FROM members m
                    JOIN lor_snap.preview_wiring_fieldlead_v6 fw
                      ON fw.preview_name = %s
                     AND fw.display_name = replace(btrim(m.lor_comment), ' ', '-')
                    ORDER BY fw.network, fw.controller, fw.start_channel, m.production_display_name
                """, (preview_uuid, scene_uuid, preview["preview_name"]))
            else:
                cur.execute("""
                    WITH members AS (
                        SELECT DISTINCT d.display_id,
                               d.display_name AS production_display_name,
                               p.raw_prop_id, p.lor_comment, p.string_type
                        FROM lor_snap.v_current_props p
                        JOIN ref.display d ON d.lor_prop_id = p.raw_prop_id
                        WHERE p.preview_id = %s
                          AND d.display_status_id = 1
                          AND upper(coalesce(p.device_type, '')) <> 'NONE'
                    )
                    SELECT m.display_id, m.production_display_name AS display_name,
                           fw.channel_name, fw.network, fw.controller,
                           fw.start_channel, fw.end_channel, fw.device_type,
                           m.string_type, fw.source, fw.lor_tag,
                           fw.connection_type, fw.cross_display
                    FROM members m
                    JOIN lor_snap.preview_wiring_fieldlead_v6 fw
                      ON fw.preview_name = %s
                     AND fw.display_name = replace(btrim(m.lor_comment), ' ', '-')
                    ORDER BY fw.network, fw.controller, fw.start_channel, m.production_display_name
                """, (preview_uuid, preview["preview_name"]))
            rows = [dict(row) for row in cur.fetchall()]

            cur.execute("""
                SELECT import_run_id, run_ts, parser_version, parser_completed_at,
                       source_preview_folder, ingest_script_version, ingest_completed_at
                FROM lor_snap.v_current_run LIMIT 1
            """)
            row = cur.fetchone(); run = dict(row) if row else {"import_run_id": preview["import_run_id"]}

    return {"preview": preview, "stage": stage, "scene": scene, "rows": rows, "run": run}


def load_wiring_data(repo: Any, preview_uuid: str, scene_uuid: str | None, stage_id: int) -> dict[str, Any]:
    if _is_sqlite(repo):
        return _sqlite_package(repo, preview_uuid, scene_uuid, stage_id)
    return _postgres_package(repo, preview_uuid, scene_uuid, stage_id)
