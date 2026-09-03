"""FieldWiring adapter for V7.0.11+ atomic DMX source rows.

The legacy preview_wiring_*_v6 views remain the compatibility surface for
FormView and non-DMX FieldWiring behavior.  This module replaces only DMX rows
inside a resolved FieldWiring package with the richer current-snapshot source
rows now preserved by parser V7.0.11 and PostgreSQL migration 0037.

Identity is intentionally split:

    dc.prop_id
        -> canonical current Prop p.prop_id
        -> canonical p.raw_prop_id
        -> ref.display.lor_prop_id
        -> permanent ref.display.display_id

    dc.raw_prop_id
        -> originating grouped-DMX PropClass provenance for this wiring row

The source RawPropID is never used as permanent Display identity.
"""
from __future__ import annotations

import re
from typing import Any

from wiring_common import WiringError

_VERSION_RE = re.compile(r"^V(\d+)\.(\d+)\.(\d+)$", re.IGNORECASE)
_DMX_SOURCE_DETAIL_VERSION = (7, 0, 11)


def _is_sqlite(repo: Any) -> bool:
    return repo.__class__.__name__ == "SQLiteSnapshotRepository"


def _rowdict(row: Any) -> dict[str, Any]:
    if isinstance(row, dict):
        return dict(row)
    return {key: row[key] for key in row.keys()}


def _requires_source_detail(parser_version: Any) -> bool:
    match = _VERSION_RE.fullmatch(str(parser_version or "").strip())
    if not match:
        return False
    return tuple(int(part) for part in match.groups()) >= _DMX_SOURCE_DETAIL_VERSION


def _validate_source_rows(rows: list[dict[str, Any]]) -> None:
    invalid: list[str] = []
    for row in rows:
        raw_prop_id = str(row.get("source_raw_prop_id") or "").strip()
        channel_name = str(row.get("channel_name") or "").strip()
        grid_row = row.get("channel_grid_row_number")
        if not raw_prop_id or not channel_name or not isinstance(grid_row, int) or grid_row <= 0:
            invalid.append(
                f"display={row.get('display_id')} source={raw_prop_id or 'blank'} "
                f"channel={channel_name or 'blank'} row={grid_row!r}"
            )
    if invalid:
        detail = "; ".join(invalid[:5])
        if len(invalid) > 5:
            detail += f"; ... {len(invalid) - 5} more"
        raise WiringError(
            "Current V7.0.11+ DMX source-detail rows are incomplete: " + detail
        )


def _sqlite_source_rows(
    repo: Any,
    preview_uuid: str,
    scene_uuid: str | None,
    scene_scope: bool,
) -> list[dict[str, Any]]:
    with repo.connect() as conn:
        if scene_scope:
            sql = """
                WITH members AS (
                    SELECT DISTINCT
                           d.display_id,
                           d.display_name AS production_display_name,
                           p.prop_id AS canonical_prop_id,
                           p.raw_prop_id AS canonical_raw_prop_id,
                           p.string_type,
                           p.tag AS lor_tag
                    FROM lor_snap__v_current_scene_lor_props slp
                    JOIN lor_snap__v_current_props p
                      ON p.preview_id = slp.preview_id
                     AND p.prop_id = slp.prop_id
                     AND p.raw_prop_id = slp.raw_prop_id
                    JOIN ref__display d
                      ON d.lor_prop_id = p.raw_prop_id
                    WHERE slp.preview_id = ?
                      AND slp.scene_id = ?
                      AND d.display_status_id = 1
                      AND upper(coalesce(p.device_type, '')) = 'DMX'
                )
                SELECT
                    m.display_id,
                    m.production_display_name AS display_name,
                    dc.channel_name,
                    dc.network,
                    CAST(dc.start_universe AS TEXT) AS controller,
                    dc.start_universe,
                    dc.start_channel,
                    dc.end_channel,
                    'DMX' AS device_type,
                    m.string_type,
                    'DMX_SOURCE' AS source,
                    m.lor_tag,
                    'FIELD' AS connection_type,
                    0 AS cross_display,
                    m.canonical_prop_id,
                    m.canonical_raw_prop_id,
                    dc.raw_prop_id AS source_raw_prop_id,
                    dc.channel_grid_row_number
                FROM members m
                JOIN lor_snap__v_current_dmx_channels dc
                  ON dc.preview_id = ?
                 AND dc.prop_id = m.canonical_prop_id
                ORDER BY
                    m.production_display_name,
                    dc.raw_prop_id,
                    dc.channel_grid_row_number,
                    dc.start_universe,
                    dc.start_channel
            """
            params: tuple[Any, ...] = (preview_uuid, scene_uuid, preview_uuid)
        else:
            sql = """
                WITH members AS (
                    SELECT DISTINCT
                           d.display_id,
                           d.display_name AS production_display_name,
                           p.prop_id AS canonical_prop_id,
                           p.raw_prop_id AS canonical_raw_prop_id,
                           p.string_type,
                           p.tag AS lor_tag
                    FROM lor_snap__v_current_props p
                    JOIN ref__display d ON d.lor_prop_id = p.raw_prop_id
                    WHERE p.preview_id = ?
                      AND d.display_status_id = 1
                      AND upper(coalesce(p.device_type, '')) = 'DMX'
                )
                SELECT
                    m.display_id,
                    m.production_display_name AS display_name,
                    dc.channel_name,
                    dc.network,
                    CAST(dc.start_universe AS TEXT) AS controller,
                    dc.start_universe,
                    dc.start_channel,
                    dc.end_channel,
                    'DMX' AS device_type,
                    m.string_type,
                    'DMX_SOURCE' AS source,
                    m.lor_tag,
                    'FIELD' AS connection_type,
                    0 AS cross_display,
                    m.canonical_prop_id,
                    m.canonical_raw_prop_id,
                    dc.raw_prop_id AS source_raw_prop_id,
                    dc.channel_grid_row_number
                FROM members m
                JOIN lor_snap__v_current_dmx_channels dc
                  ON dc.preview_id = ?
                 AND dc.prop_id = m.canonical_prop_id
                ORDER BY
                    m.production_display_name,
                    dc.raw_prop_id,
                    dc.channel_grid_row_number,
                    dc.start_universe,
                    dc.start_channel
            """
            params = (preview_uuid, preview_uuid)
        return [_rowdict(row) for row in conn.execute(sql, params).fetchall()]


def _postgres_source_rows(
    repo: Any,
    preview_uuid: str,
    scene_uuid: str | None,
    scene_scope: bool,
) -> list[dict[str, Any]]:
    cursor_factory = getattr(__import__("repository"), "RealDictCursor")
    with repo.connect() as conn:
        with conn.cursor(cursor_factory=cursor_factory) as cur:
            if scene_scope:
                cur.execute("""
                    WITH members AS (
                        SELECT DISTINCT
                               d.display_id,
                               d.display_name AS production_display_name,
                               p.prop_id AS canonical_prop_id,
                               p.raw_prop_id AS canonical_raw_prop_id,
                               p.string_type,
                               p.tag AS lor_tag
                        FROM lor_snap.v_current_scene_lor_props slp
                        JOIN lor_snap.v_current_props p
                          ON p.preview_id = slp.preview_id
                         AND p.prop_id = slp.prop_id
                         AND p.raw_prop_id = slp.raw_prop_id
                        JOIN ref.display d
                          ON d.lor_prop_id = p.raw_prop_id
                        WHERE slp.preview_id = %s
                          AND slp.scene_id = %s
                          AND d.display_status_id = 1
                          AND upper(coalesce(p.device_type, '')) = 'DMX'
                    )
                    SELECT
                        m.display_id,
                        m.production_display_name AS display_name,
                        dc.channel_name,
                        dc.network,
                        dc.start_universe::text AS controller,
                        dc.start_universe,
                        dc.start_channel,
                        dc.end_channel,
                        'DMX'::text AS device_type,
                        m.string_type,
                        'DMX_SOURCE'::text AS source,
                        m.lor_tag,
                        'FIELD'::text AS connection_type,
                        0::integer AS cross_display,
                        m.canonical_prop_id,
                        m.canonical_raw_prop_id,
                        dc.raw_prop_id AS source_raw_prop_id,
                        dc.channel_grid_row_number
                    FROM members m
                    JOIN lor_snap.v_current_dmx_channels dc
                      ON dc.preview_id = %s
                     AND dc.prop_id = m.canonical_prop_id
                    ORDER BY
                        m.production_display_name,
                        dc.raw_prop_id,
                        dc.channel_grid_row_number,
                        dc.start_universe,
                        dc.start_channel
                """, (preview_uuid, scene_uuid, preview_uuid))
            else:
                cur.execute("""
                    WITH members AS (
                        SELECT DISTINCT
                               d.display_id,
                               d.display_name AS production_display_name,
                               p.prop_id AS canonical_prop_id,
                               p.raw_prop_id AS canonical_raw_prop_id,
                               p.string_type,
                               p.tag AS lor_tag
                        FROM lor_snap.v_current_props p
                        JOIN ref.display d
                          ON d.lor_prop_id = p.raw_prop_id
                        WHERE p.preview_id = %s
                          AND d.display_status_id = 1
                          AND upper(coalesce(p.device_type, '')) = 'DMX'
                    )
                    SELECT
                        m.display_id,
                        m.production_display_name AS display_name,
                        dc.channel_name,
                        dc.network,
                        dc.start_universe::text AS controller,
                        dc.start_universe,
                        dc.start_channel,
                        dc.end_channel,
                        'DMX'::text AS device_type,
                        m.string_type,
                        'DMX_SOURCE'::text AS source,
                        m.lor_tag,
                        'FIELD'::text AS connection_type,
                        0::integer AS cross_display,
                        m.canonical_prop_id,
                        m.canonical_raw_prop_id,
                        dc.raw_prop_id AS source_raw_prop_id,
                        dc.channel_grid_row_number
                    FROM members m
                    JOIN lor_snap.v_current_dmx_channels dc
                      ON dc.preview_id = %s
                     AND dc.prop_id = m.canonical_prop_id
                    ORDER BY
                        m.production_display_name,
                        dc.raw_prop_id,
                        dc.channel_grid_row_number,
                        dc.start_universe,
                        dc.start_channel
                """, (preview_uuid, preview_uuid))
            return [dict(row) for row in cur.fetchall()]


def load_dmx_source_rows(
    repo: Any,
    *,
    preview_uuid: str,
    scene_uuid: str | None,
    scene_scope: bool,
) -> list[dict[str, Any]]:
    if _is_sqlite(repo):
        return _sqlite_source_rows(repo, preview_uuid, scene_uuid, scene_scope)
    return _postgres_source_rows(repo, preview_uuid, scene_uuid, scene_scope)


def replace_legacy_dmx_rows(
    repo: Any,
    rows: list[dict[str, Any]],
    *,
    preview_uuid: str,
    scene_uuid: str | None,
    scene_scope: bool,
    parser_version: Any,
) -> list[dict[str, Any]]:
    """Replace only DMX Displays already present in the resolved wiring scope.

    The incoming ``rows`` list is already bounded to the resolved Display,
    Stage, or Scene by ``wiring_data``. The atomic DMX source-detail query is an
    enrichment source and must never broaden that context. In particular, a
    shared/master Preview may contain DMX Displays from many Stages.

    Pre-V7.0.11 snapshots retain the legacy compatibility path. On V7.0.11+ a
    context that has legacy DMX wiring must also expose approved source detail;
    otherwise FieldWiring fails closed instead of silently reverting to
    canonical master Channel Names.
    """
    legacy_dmx = [
        row for row in rows
        if str(row.get("device_type") or "").strip().casefold() == "dmx"
    ]
    required = _requires_source_detail(parser_version)

    # No DMX exists in the already-resolved context. Do not query/reintroduce
    # atomic DMX rows from other Displays in the shared Preview.
    if not legacy_dmx:
        return rows

    allowed_display_ids = {
        int(row["display_id"])
        for row in legacy_dmx
        if row.get("display_id") is not None
    }

    try:
        source_rows = load_dmx_source_rows(
            repo,
            preview_uuid=preview_uuid,
            scene_uuid=scene_uuid,
            scene_scope=scene_scope,
        )
    except Exception as exc:
        if required:
            raise WiringError(
                "Current V7.0.11+ FieldWiring data does not expose the required "
                "DMX source-detail columns. Regenerate the FieldWiring snapshot "
                "or verify the production current-DMX view."
            ) from exc
        return rows

    # Atomic source detail may contain DMX Displays from elsewhere in a shared
    # Preview. Keep only Displays that were already present in the resolved
    # Stage/Scene/Display package.
    source_rows = [
        row for row in source_rows
        if row.get("display_id") is not None
        and int(row["display_id"]) in allowed_display_ids
    ]

    if not source_rows:
        if required:
            raise WiringError(
                "Current V7.0.11+ wiring contains DMX relationships but no atomic "
                "DMX source rows were resolved for this context."
            )
        return rows

    _validate_source_rows(source_rows)

    if required:
        source_display_ids = {
            int(row["display_id"])
            for row in source_rows
            if row.get("display_id") is not None
        }
        missing = sorted(allowed_display_ids - source_display_ids)
        if missing:
            raise WiringError(
                "Atomic DMX source rows did not resolve every DMX Display from the "
                f"compatibility surface; missing display_id values: {missing}"
            )

    non_dmx = [
        row for row in rows
        if str(row.get("device_type") or "").strip().casefold() != "dmx"
    ]
    return non_dmx + source_rows
