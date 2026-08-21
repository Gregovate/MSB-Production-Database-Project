/* ============================================================================
Validation: 32_dmx_source_detail_validation.sql
Purpose:
  Read-only validation for migration 0037.  Confirms the additive DMX source
  fields and current-run projection without requiring historical snapshots to
  contain V7.0.11 source detail.
============================================================================ */

-- 1. Snapshot table: expected legacy columns first, then the three additions.
SELECT
    ordinal_position,
    column_name,
    data_type,
    is_nullable
FROM information_schema.columns
WHERE table_schema = 'lor_snap'
  AND table_name = 'dmx_channels'
ORDER BY ordinal_position;

-- Expected positions 1-12:
--  1 import_run_id
--  2 int_dmx_channel_id
--  3 prop_id
--  4 network
--  5 start_universe
--  6 start_channel
--  7 end_channel
--  8 unknown
--  9 preview_id
-- 10 raw_prop_id
-- 11 channel_name
-- 12 channel_grid_row_number

-- 2. Current-run view must expose the same three fields explicitly.
SELECT
    ordinal_position,
    column_name,
    data_type
FROM information_schema.columns
WHERE table_schema = 'lor_snap'
  AND table_name = 'v_current_dmx_channels'
ORDER BY ordinal_position;

-- 3. Show the exact deployed current-run projection for review.
SELECT pg_get_viewdef(
    'lor_snap.v_current_dmx_channels'::regclass,
    true
) AS view_definition;

-- 4. Preserve established current-snapshot view ownership/read access.
SELECT
    n.nspname AS schema_name,
    c.relname AS view_name,
    pg_get_userbyid(c.relowner) AS owner_name
FROM pg_class AS c
JOIN pg_namespace AS n ON n.oid = c.relnamespace
WHERE n.nspname = 'lor_snap'
  AND c.relname = 'v_current_dmx_channels'
  AND c.relkind = 'v';

SELECT
    has_table_privilege(
        'directus_app',
        'lor_snap.v_current_dmx_channels',
        'SELECT'
    ) AS directus_app_can_select_current_dmx;

-- Expected:
-- owner_name = msbadmin
-- directus_app_can_select_current_dmx = true

-- 5. Prove no foreign key was added from source raw_prop_id.  The established
--    prop_id and preview_id foreign keys remain the only DMX foreign keys.
SELECT
    c.conname,
    pg_get_constraintdef(c.oid, true) AS constraint_definition
FROM pg_constraint AS c
JOIN pg_class AS t ON t.oid = c.conrelid
JOIN pg_namespace AS n ON n.oid = t.relnamespace
WHERE n.nspname = 'lor_snap'
  AND t.relname = 'dmx_channels'
  AND c.contype = 'f'
ORDER BY c.conname;

-- 6. Historical/current-state compatibility.  If the current run still uses
--    parser V7.0.10, NULL values in the new columns are expected and valid.
SELECT
    r.import_run_id,
    r.parser_version,
    count(*) AS dmx_rows,
    count(*) FILTER (WHERE dc.raw_prop_id IS NOT NULL) AS rows_with_raw_prop_id,
    count(*) FILTER (WHERE dc.channel_name IS NOT NULL) AS rows_with_channel_name,
    count(*) FILTER (WHERE dc.channel_grid_row_number IS NOT NULL) AS rows_with_grid_row_number
FROM lor_snap.v_current_run AS r
LEFT JOIN lor_snap.v_current_dmx_channels AS dc
  ON dc.import_run_id = r.import_run_id
GROUP BY r.import_run_id, r.parser_version;

-- 7. Protected dependent/compatibility views must remain definition-identical
--    to the preflight fingerprints.  Compare this result directly with
--    preflight 10 before accepting migration 0037.
WITH protected_views(view_name) AS (
    VALUES
        ('preview_wiring_map_v6'),
        ('preview_wiring_sorted_v6'),
        ('preview_wiring_fieldmap_v6'),
        ('preview_wiring_fieldlead_v6'),
        ('preview_wiring_circuit_rollup_v6'),
        ('preview_wiring_fieldonly_v6'),
        ('stage_display_assets_v1')
)
SELECT
    pv.view_name,
    md5(pg_get_viewdef(to_regclass('lor_snap.' || pv.view_name), true))
        AS view_definition_md5,
    (
        SELECT string_agg(
            c.column_name || ':' || c.data_type,
            ',' ORDER BY c.ordinal_position
        )
        FROM information_schema.columns AS c
        WHERE c.table_schema = 'lor_snap'
          AND c.table_name = pv.view_name
    ) AS column_signature
FROM protected_views AS pv
ORDER BY pv.view_name;

SELECT
    (SELECT COUNT(*) FROM lor_snap.preview_wiring_map_v6)
        AS preview_wiring_map_rows,
    (SELECT COUNT(*) FROM lor_snap.preview_wiring_fieldlead_v6)
        AS preview_wiring_fieldlead_rows,
    (SELECT COUNT(*) FROM lor_snap.preview_wiring_fieldonly_v6)
        AS preview_wiring_fieldonly_rows,
    (SELECT COUNT(*) FROM lor_snap.stage_display_assets_v1)
        AS stage_display_assets_rows;

-- 8. Once a V7.0.11+ run becomes current, all three source-detail fields are
--    required by ingest V0.4.2.  This query surfaces any violation without
--    falsely failing the current V7.0.10 historical snapshot.
SELECT
    r.import_run_id,
    r.parser_version,
    count(*) FILTER (
        WHERE dc.raw_prop_id IS NULL OR btrim(dc.raw_prop_id) = ''
    ) AS blank_raw_prop_id,
    count(*) FILTER (
        WHERE dc.channel_name IS NULL OR btrim(dc.channel_name) = ''
    ) AS blank_channel_name,
    count(*) FILTER (
        WHERE dc.channel_grid_row_number IS NULL
           OR dc.channel_grid_row_number <= 0
    ) AS invalid_channel_grid_row_number
FROM lor_snap.v_current_run AS r
LEFT JOIN lor_snap.v_current_dmx_channels AS dc
  ON dc.import_run_id = r.import_run_id
GROUP BY r.import_run_id, r.parser_version;
