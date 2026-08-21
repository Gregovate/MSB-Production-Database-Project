/* ============================================================================
Preflight: 10_fieldwiring_dmx_0037_preflight.sql
Purpose:
  Read-only production baseline immediately before considering migration 0037.
  Captures current snapshot identity, object ownership/grants, dependencies,
  constraints, protected dependent-view fingerprints, and row-count baselines.

Safety:
  READ ONLY.  This file contains SELECT statements only.
  It does not apply migration 0037 and does not change any database object.

Expected baseline from 2026-08-21 live verification:
  current import_run_id       50
  parser_version              V7.0.10
  ingest_script_version       V0.4.1
  current DMX rows            508
  new DMX source columns      absent before migration 0037
============================================================================ */

-- 1. Execution identity.  Migration installation is expected to be performed
--    by the database administrator/owner context, not directus_app.
SELECT
    current_database() AS database_name,
    session_user,
    current_user;

-- 2. Current append-only snapshot baseline.
SELECT
    import_run_id,
    parser_version,
    parser_completed_at,
    ingest_script_version,
    ingest_completed_at,
    dmx_channel_count
FROM lor_snap.v_current_run;

SELECT COUNT(*) AS current_dmx_rows
FROM lor_snap.v_current_dmx_channels;

-- 3. Physical table/current-view owner baseline.
SELECT
    n.nspname AS schema_name,
    c.relname AS object_name,
    c.relkind,
    pg_get_userbyid(c.relowner) AS owner_name
FROM pg_class AS c
JOIN pg_namespace AS n
  ON n.oid = c.relnamespace
WHERE n.nspname = 'lor_snap'
  AND c.relname IN ('dmx_channels', 'v_current_dmx_channels')
ORDER BY c.relname;

-- 4. Current-view read privilege expected by established lor_snap conventions.
SELECT
    has_table_privilege(
        'directus_app',
        'lor_snap.v_current_dmx_channels',
        'SELECT'
    ) AS directus_app_can_select_current_dmx;

-- 5. Pre-migration column baseline.  Before 0037, the table and current view
--    should still contain only the legacy nine PostgreSQL columns.
SELECT
    table_name,
    ordinal_position,
    column_name,
    data_type,
    is_nullable
FROM information_schema.columns
WHERE table_schema = 'lor_snap'
  AND table_name IN ('dmx_channels', 'v_current_dmx_channels')
ORDER BY table_name, ordinal_position;

-- 6. Existing PK/FK baseline.  Migration 0037 must not change these or create
--    a foreign key involving raw_prop_id.
SELECT
    c.contype,
    c.conname,
    pg_get_constraintdef(c.oid, true) AS constraint_definition
FROM pg_constraint AS c
JOIN pg_class AS t
  ON t.oid = c.conrelid
JOIN pg_namespace AS n
  ON n.oid = t.relnamespace
WHERE n.nspname = 'lor_snap'
  AND t.relname = 'dmx_channels'
  AND c.contype IN ('p', 'f')
ORDER BY c.contype, c.conname;

-- 7. Direct database-view dependencies on v_current_dmx_channels.  Appending
--    columns to the end of the current view must leave these dependent objects
--    valid; migration 0037 does not replace them.
SELECT DISTINCT
    dep_ns.nspname AS dependent_schema,
    dep.relname AS dependent_object,
    dep.relkind AS dependent_relkind
FROM pg_depend AS d
JOIN pg_rewrite AS rw
  ON rw.oid = d.objid
JOIN pg_class AS dep
  ON dep.oid = rw.ev_class
JOIN pg_namespace AS dep_ns
  ON dep_ns.oid = dep.relnamespace
WHERE d.refobjid = 'lor_snap.v_current_dmx_channels'::regclass
  AND dep.oid <> 'lor_snap.v_current_dmx_channels'::regclass
ORDER BY dependent_schema, dependent_object;

-- 8. Freeze every protected direct/legacy dependent view before migration.
--    Save this result with the preflight evidence; the same hashes/signatures
--    must be unchanged after migration 0037.
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

-- 9. Freeze representative legacy row counts before migration.  Migration 0037
--    must not change these counts while Run 50 remains current.
SELECT
    (SELECT COUNT(*) FROM lor_snap.preview_wiring_map_v6)
        AS preview_wiring_map_rows,
    (SELECT COUNT(*) FROM lor_snap.preview_wiring_fieldlead_v6)
        AS preview_wiring_fieldlead_rows,
    (SELECT COUNT(*) FROM lor_snap.preview_wiring_fieldonly_v6)
        AS preview_wiring_fieldonly_rows,
    (SELECT COUNT(*) FROM lor_snap.stage_display_assets_v1)
        AS stage_display_assets_rows;

-- 10. Explicitly show whether any of the three 0037 fields already exists.
--     Pre-migration expectation: zero rows returned.
SELECT
    table_name,
    column_name
FROM information_schema.columns
WHERE table_schema = 'lor_snap'
  AND table_name IN ('dmx_channels', 'v_current_dmx_channels')
  AND column_name IN (
      'raw_prop_id',
      'channel_name',
      'channel_grid_row_number'
  )
ORDER BY table_name, column_name;
