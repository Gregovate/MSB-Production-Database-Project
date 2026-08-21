from __future__ import annotations

import json
import os
from typing import Any

import psycopg
from psycopg.rows import dict_row
from mcp.server import MCPServer
from mcp.types import ToolAnnotations


SERVER_NAME = "MSB PostgreSQL Read-Only"
DEFAULT_HOST = "127.0.0.1"
DEFAULT_PORT = 8000
DEFAULT_TIMEOUT_MS = 15000
ALLOWED_DESCRIBE_SCHEMAS = {"lor_snap", "ops", "ref"}

READ_ONLY = ToolAnnotations(
    readOnlyHint=True,
    destructiveHint=False,
    idempotentHint=True,
    openWorldHint=False,
)

mcp = MCPServer(
    SERVER_NAME,
    instructions=(
        "Read-only access to the current MSB PostgreSQL production state. "
        "Tools expose human-facing Display/Stage/Scene/wiring information and "
        "selected engineering metadata. No tool accepts arbitrary SQL and no "
        "tool performs database writes."
    ),
)


def _dsn() -> str:
    value = os.environ.get("MSB_PG_DSN", "").strip()
    if not value:
        raise RuntimeError("MSB_PG_DSN is not configured")
    return value


def _json_safe(value: Any) -> Any:
    return json.loads(json.dumps(value, default=str))


def _fetch_all(sql: str, params: tuple[Any, ...] = ()) -> list[dict[str, Any]]:
    conn = psycopg.connect(
        _dsn(),
        row_factory=dict_row,
        autocommit=False,
        connect_timeout=5,
        application_name="msb-postgres-mcp",
    )
    try:
        # Defense in depth. The deployment account must also be SELECT-only.
        conn.read_only = True
        with conn.cursor() as cur:
            cur.execute(f"SET LOCAL statement_timeout = '{DEFAULT_TIMEOUT_MS}ms'")
            cur.execute("SET LOCAL lock_timeout = '2s'")
            cur.execute(sql, params)
            rows = cur.fetchall()
        # Never commit from this service, even though the transaction is read-only.
        conn.rollback()
        return _json_safe(rows)
    finally:
        conn.close()


def _bounded_limit(limit: int, maximum: int = 100) -> int:
    return max(1, min(int(limit), maximum))


@mcp.tool(annotations=READ_ONLY)
def get_current_snapshot_summary() -> list[dict[str, Any]]:
    """Return the current LOR snapshot identity and row counts."""
    return _fetch_all(
        """
        SELECT
            current_database() AS database_name,
            current_user AS database_user,
            now() AS checked_at,
            cr.import_run_id,
            cr.run_ts AS ingest_timestamp,
            (SELECT count(*) FROM lor_snap.v_current_previews) AS preview_count,
            (SELECT count(*) FROM lor_snap.v_current_scenes) AS scene_count,
            (SELECT count(*) FROM lor_snap.v_current_props) AS prop_count,
            (SELECT count(*) FROM lor_snap.v_current_sub_props) AS sub_prop_count,
            (SELECT count(*) FROM lor_snap.v_current_dmx_channels) AS dmx_channel_count,
            (SELECT count(*) FROM lor_snap.v_current_scene_lor_props) AS scene_lor_prop_count,
            (SELECT count(*) FROM lor_snap.preview_wiring_fieldlead_v6) AS field_wiring_lead_count
        FROM lor_snap.v_current_run AS cr
        """
    )


@mcp.tool(annotations=READ_ONLY)
def find_display(search_text: str, stage_key: str | None = None, limit: int = 25) -> list[dict[str, Any]]:
    """Find permanent Displays by human Display Name, optionally limited to one Stage key."""
    search_text = search_text.strip()
    if not search_text:
        raise ValueError("search_text is required")
    stage_key = stage_key.strip().lower() if stage_key else None
    return _fetch_all(
        """
        SELECT
            d.display_id,
            d.display_name,
            ds.display_status_name AS status,
            st.stage_id,
            st.stage_key,
            st.stage_name,
            st.short_code,
            st.folder_name
        FROM ref.display AS d
        LEFT JOIN ref.stage AS st ON st.stage_id = d.stage_id
        LEFT JOIN ref.display_status AS ds ON ds.display_status_id = d.display_status_id
        WHERE d.display_name ILIKE %s
          AND (CAST(%s AS text) IS NULL OR lower(st.stage_key) = CAST(%s AS text))
        ORDER BY lower(d.display_name), st.stage_key
        LIMIT %s
        """,
        (f"%{search_text}%", stage_key, stage_key, _bounded_limit(limit)),
    )


@mcp.tool(annotations=READ_ONLY)
def get_display_current_context(display_id: int) -> list[dict[str, Any]]:
    """Return current Preview/Scene occurrences for a permanent display_id without exposing LOR UUIDs."""
    return _fetch_all(
        """
        WITH current_map AS (
            SELECT DISTINCT
                v.import_run_id,
                v.display_id,
                v.lor_prop_id,
                v.lor_display_name,
                v.production_display_name,
                v.classification_code
            FROM ops.v_lor_display_reconciliation AS v
            JOIN lor_snap.v_current_run AS cr ON cr.import_run_id = v.import_run_id
            WHERE v.display_id = %s
              AND v.classification_code <> 'EXCLUDED_NONPHYSICAL'
        )
        SELECT DISTINCT
            cm.display_id,
            cm.production_display_name AS display_name,
            cm.lor_display_name AS current_lor_display_name,
            cm.classification_code AS identity_status,
            st.stage_key,
            st.stage_name,
            st.short_code,
            o.location_type,
            o.preview_name,
            CASE WHEN o.location_type = 'SCENE' THEN o.scene_name END AS scene_name,
            coalesce(o.scene_stage_id, o.preview_stage_id, st.stage_key) AS current_stage_key
        FROM current_map AS cm
        JOIN ref.display AS d ON d.display_id = cm.display_id
        LEFT JOIN ref.stage AS st ON st.stage_id = d.stage_id
        JOIN lor_snap.v_display_lor_occurrence AS o
          ON o.import_run_id = cm.import_run_id
         AND o.lor_prop_id = cm.lor_prop_id
        ORDER BY o.preview_name, o.location_type, scene_name NULLS FIRST
        """,
        (display_id,),
    )


@mcp.tool(annotations=READ_ONLY)
def get_current_field_wiring(display_id: int, preview_name: str | None = None) -> list[dict[str, Any]]:
    """Return current field-lead wiring rows for one permanent Display across its current Preview occurrences."""
    preview_name = preview_name.strip() if preview_name else None
    return _fetch_all(
        """
        WITH current_map AS (
            SELECT DISTINCT
                v.import_run_id,
                v.display_id,
                v.lor_prop_id,
                v.lor_display_name,
                v.production_display_name,
                v.classification_code
            FROM ops.v_lor_display_reconciliation AS v
            JOIN lor_snap.v_current_run AS cr ON cr.import_run_id = v.import_run_id
            WHERE v.display_id = %s
              AND v.classification_code <> 'EXCLUDED_NONPHYSICAL'
        ),
        current_previews AS (
            SELECT DISTINCT cm.*, o.preview_name
            FROM current_map AS cm
            JOIN lor_snap.v_display_lor_occurrence AS o
              ON o.import_run_id = cm.import_run_id
             AND o.lor_prop_id = cm.lor_prop_id
            WHERE (CAST(%s AS text) IS NULL OR o.preview_name = CAST(%s AS text))
        )
        SELECT DISTINCT
            cp.display_id,
            cp.production_display_name AS display_name,
            cp.classification_code AS identity_status,
            fw.preview_name,
            fw.source,
            fw.channel_name,
            fw.network,
            fw.controller,
            fw.start_channel,
            fw.end_channel,
            fw.connection_type,
            fw.cross_display,
            fw.device_type,
            fw.lor_tag
        FROM current_previews AS cp
        JOIN lor_snap.preview_wiring_fieldlead_v6 AS fw
          ON fw.preview_name = cp.preview_name
         AND fw.display_name = replace(btrim(cp.lor_display_name), ' ', '-')
        ORDER BY fw.preview_name, fw.network, fw.controller, fw.start_channel, fw.channel_name
        """,
        (display_id, preview_name, preview_name),
    )


@mcp.tool(annotations=READ_ONLY)
def get_scene_field_wiring(display_id: int, preview_name: str | None = None) -> list[dict[str, Any]]:
    """Return the current Scene-scoped field wiring package containing a selected permanent Display."""
    preview_name = preview_name.strip() if preview_name else None
    return _fetch_all(
        """
        WITH current_display_map AS MATERIALIZED (
            SELECT DISTINCT
                v.import_run_id,
                v.lor_prop_id AS source_lor_prop_id,
                v.display_id,
                v.lor_display_name,
                v.production_display_name,
                v.classification_code
            FROM ops.v_lor_display_reconciliation AS v
            JOIN lor_snap.v_current_run AS cr ON cr.import_run_id = v.import_run_id
            WHERE v.classification_code <> 'EXCLUDED_NONPHYSICAL'
              AND v.display_id IS NOT NULL
        ),
        target_scenes AS (
            SELECT DISTINCT
                slp.import_run_id,
                slp.preview_id,
                slp.scene_id
            FROM current_display_map AS target
            JOIN lor_snap.v_current_scene_lor_props AS slp
              ON slp.import_run_id = target.import_run_id
             AND slp.raw_prop_id = target.source_lor_prop_id
            WHERE target.display_id = %s
        ),
        scene_members AS (
            SELECT DISTINCT
                ts.import_run_id,
                ts.preview_id,
                ts.scene_id,
                dm.display_id,
                dm.lor_display_name,
                dm.production_display_name,
                dm.classification_code
            FROM target_scenes AS ts
            JOIN lor_snap.v_current_scene_lor_props AS slp
              ON slp.import_run_id = ts.import_run_id
             AND slp.preview_id = ts.preview_id
             AND slp.scene_id = ts.scene_id
            JOIN current_display_map AS dm
              ON dm.import_run_id = slp.import_run_id
             AND dm.source_lor_prop_id = slp.raw_prop_id
        )
        SELECT DISTINCT
            p.name AS preview_name,
            s.name AS scene_name,
            sm.display_id,
            sm.production_display_name AS display_name,
            sm.classification_code AS identity_status,
            fw.source,
            fw.channel_name,
            fw.network,
            fw.controller,
            fw.start_channel,
            fw.end_channel,
            fw.connection_type,
            fw.cross_display,
            fw.device_type,
            fw.lor_tag
        FROM scene_members AS sm
        JOIN lor_snap.v_current_previews AS p ON p.id = sm.preview_id
        JOIN lor_snap.v_current_scenes AS s
          ON s.preview_id = sm.preview_id
         AND s.scene_id = sm.scene_id
        JOIN lor_snap.preview_wiring_fieldlead_v6 AS fw
          ON fw.preview_name = p.name
         AND fw.display_name = replace(btrim(sm.lor_display_name), ' ', '-')
        WHERE (CAST(%s AS text) IS NULL OR p.name = CAST(%s AS text))
        ORDER BY p.name, s.name, fw.network, fw.controller, fw.start_channel, sm.display_id
        """,
        (display_id, preview_name, preview_name),
    )


@mcp.tool(annotations=READ_ONLY)
def describe_relation(schema_name: str, relation_name: str) -> dict[str, Any]:
    """Describe columns and, for views/materialized views, return the deployed definition for engineering verification."""
    schema_name = schema_name.strip().lower()
    relation_name = relation_name.strip()
    if schema_name not in ALLOWED_DESCRIBE_SCHEMAS:
        raise ValueError(f"schema_name must be one of: {', '.join(sorted(ALLOWED_DESCRIBE_SCHEMAS))}")
    if not relation_name:
        raise ValueError("relation_name is required")

    columns = _fetch_all(
        """
        SELECT
            ordinal_position,
            column_name,
            data_type,
            is_nullable
        FROM information_schema.columns
        WHERE table_schema = %s
          AND table_name = %s
        ORDER BY ordinal_position
        """,
        (schema_name, relation_name),
    )

    definition = _fetch_all(
        """
        SELECT
            c.relkind,
            CASE WHEN c.relkind IN ('v', 'm') THEN pg_get_viewdef(c.oid, true) END AS view_definition
        FROM pg_class AS c
        JOIN pg_namespace AS n ON n.oid = c.relnamespace
        WHERE n.nspname = %s
          AND c.relname = %s
        """,
        (schema_name, relation_name),
    )

    return {"schema": schema_name, "relation": relation_name, "columns": columns, "definition": definition}


if __name__ == "__main__":
    host = os.environ.get("MSB_MCP_HOST", DEFAULT_HOST)
    port = int(os.environ.get("MSB_MCP_PORT", str(DEFAULT_PORT)))
    mcp.run(
        transport="streamable-http",
        host=host,
        port=port,
        streamable_http_path="/mcp",
        stateless_http=True,
        json_response=True,
    )
