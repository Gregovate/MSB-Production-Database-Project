/*
Schema: lor_snap / ops / ref
Object: FieldWiring current-snapshot live verification
Filename: 01_FieldWiring_Current_Snapshot_Verification.sql
Type: Read-only engineering verification query
Owner: msbadmin

Purpose:
  Verify the live PostgreSQL objects needed to replace FormView with FieldWiring
  while using the existing current-snapshot and reconciliation interfaces.

  This query intentionally uses human-facing Display / Stage / Scene / Preview
  values in its output. LOR UUID values remain internal plumbing and are not
  selected for operator review.

Current-state contract:
  - FieldWiring uses only the current approved lor_snap snapshot.
  - No historical snapshot selection is required for normal FieldWiring use.
  - QR/manual lookup resolves a permanent ref.display.display_id.
  - ops.v_lor_display_reconciliation is the existing current-snapshot bridge
    between LOR identity and permanent display_id.
  - lor_snap.v_current_scene_lor_props supplies current Scene membership.
  - lor_snap.preview_wiring_fieldlead_v6 supplies practical field wiring rows.

Safety:
  SELECT only. Does not create, alter, update, delete, call promotion procedures,
  or modify any production object.

Reference test:
  FormView 0.3.1 loaded 79 Field Wiring rows from a V7 SQLite snapshot for
  "Show Background Stage 21 Polar Bears". The current PostgreSQL count may differ
  legitimately if newer approved previews have since been ingested.

Revision History:
  2026-08-17  GAL / OpenAI  Initial FieldWiring live current-snapshot verification.
*/

/* --------------------------------------------------------------------------
1. Confirm the current snapshot and basic row counts.
---------------------------------------------------------------------------- */
SELECT
    current_database() AS database_name,
    current_user AS database_user,
    now() AS checked_at,
    cr.import_run_id,
    cr.run_ts AS ingest_timestamp,
    cr.notes AS ingest_notes,
    (SELECT count(*) FROM lor_snap.v_current_previews) AS preview_count,
    (SELECT count(*) FROM lor_snap.v_current_scenes) AS scene_count,
    (SELECT count(*) FROM lor_snap.v_current_props) AS prop_count,
    (SELECT count(*) FROM lor_snap.v_current_sub_props) AS sub_prop_count,
    (SELECT count(*) FROM lor_snap.v_current_dmx_channels) AS dmx_channel_count,
    (SELECT count(*) FROM lor_snap.v_current_scene_lor_props) AS scene_lor_prop_count
FROM lor_snap.v_current_run AS cr;

/* --------------------------------------------------------------------------
2. Confirm the required existing objects are deployed.
---------------------------------------------------------------------------- */
SELECT *
FROM (
    VALUES
        ('lor_snap.v_current_run',                 to_regclass('lor_snap.v_current_run')),
        ('lor_snap.v_current_previews',            to_regclass('lor_snap.v_current_previews')),
        ('lor_snap.v_current_scenes',              to_regclass('lor_snap.v_current_scenes')),
        ('lor_snap.v_current_props',               to_regclass('lor_snap.v_current_props')),
        ('lor_snap.v_current_sub_props',           to_regclass('lor_snap.v_current_sub_props')),
        ('lor_snap.v_current_dmx_channels',        to_regclass('lor_snap.v_current_dmx_channels')),
        ('lor_snap.v_current_scene_lor_props',     to_regclass('lor_snap.v_current_scene_lor_props')),
        ('lor_snap.preview_wiring_map_v6',         to_regclass('lor_snap.preview_wiring_map_v6')),
        ('lor_snap.preview_wiring_fieldmap_v6',    to_regclass('lor_snap.preview_wiring_fieldmap_v6')),
        ('lor_snap.preview_wiring_fieldlead_v6',   to_regclass('lor_snap.preview_wiring_fieldlead_v6')),
        ('lor_snap.preview_wiring_circuit_rollup_v6', to_regclass('lor_snap.preview_wiring_circuit_rollup_v6')),
        ('ops.v_lor_display_reconciliation',       to_regclass('ops.v_lor_display_reconciliation')),
        ('ref.display',                             to_regclass('ref.display'))
) AS required_object(object_name, deployed_object)
ORDER BY object_name;

/* --------------------------------------------------------------------------
3. Inventory any already-deployed Scene-oriented lor_snap views.
   This answers whether a Scene reporting view already exists in production
   even though the repository wiring-view script does not currently define one.
---------------------------------------------------------------------------- */
SELECT
    schemaname,
    viewname
FROM pg_views
WHERE schemaname = 'lor_snap'
  AND viewname ILIKE '%scene%'
ORDER BY viewname;

/* --------------------------------------------------------------------------
4. Show the current Stage 21 Background Preview(s) without exposing Preview UUIDs.
---------------------------------------------------------------------------- */
SELECT
    p.name AS preview_name,
    p.stage_id,
    p.revision,
    p.background_file,
    p.source_filename,
    p.import_run_id
FROM lor_snap.v_current_previews AS p
WHERE p.name ILIKE 'Show Background Stage 21%'
ORDER BY p.name;

/* --------------------------------------------------------------------------
5. Count current practical Field Wiring rows for Stage 21 Background Preview(s).

   Historical comparison point:
     A prior V7 SQLite/FormView test returned 79 rows.

   A different live count is not automatically an error if the approved
   previews have changed since that SQLite test.
---------------------------------------------------------------------------- */
SELECT
    w.preview_name,
    count(*) AS current_field_wiring_rows
FROM lor_snap.preview_wiring_fieldlead_v6 AS w
WHERE w.preview_name ILIKE 'Show Background Stage 21%'
GROUP BY w.preview_name
ORDER BY w.preview_name;

/* --------------------------------------------------------------------------
6. Verify that the EXISTING reconciliation bridge resolves current LOR Displays
   to permanent display_id values.

   No UUID values are displayed. The classification tells us whether current
   LOR identity/name evidence agrees with the permanent Display record.
---------------------------------------------------------------------------- */
WITH current_display_map AS MATERIALIZED (
    SELECT
        v.import_run_id,
        v.display_id,
        v.lor_display_name,
        v.production_display_name,
        v.preview_name,
        v.preview_stage_id,
        v.classification_code
    FROM ops.v_lor_display_reconciliation AS v
    JOIN lor_snap.v_current_run AS cr
      ON cr.import_run_id = v.import_run_id
    WHERE v.classification_code <> 'EXCLUDED_NONPHYSICAL'
)
SELECT
    classification_code,
    count(*) AS current_display_rows,
    count(*) FILTER (WHERE display_id IS NOT NULL) AS resolved_to_display_id,
    count(*) FILTER (WHERE display_id IS NULL) AS unresolved_display_id
FROM current_display_map
GROUP BY classification_code
ORDER BY classification_code;

/* --------------------------------------------------------------------------
7. Stage 21-specific current Display bridge summary.
   Human-facing names only; no LOR UUID output.
---------------------------------------------------------------------------- */
WITH current_display_map AS MATERIALIZED (
    SELECT
        v.import_run_id,
        v.display_id,
        v.lor_display_name,
        v.production_display_name,
        v.preview_name,
        v.preview_stage_id,
        v.classification_code
    FROM ops.v_lor_display_reconciliation AS v
    JOIN lor_snap.v_current_run AS cr
      ON cr.import_run_id = v.import_run_id
    WHERE v.classification_code <> 'EXCLUDED_NONPHYSICAL'
)
SELECT
    preview_name,
    preview_stage_id,
    classification_code,
    count(*) AS display_rows,
    count(*) FILTER (WHERE display_id IS NOT NULL) AS resolved_to_display_id,
    count(*) FILTER (WHERE display_id IS NULL) AS unresolved_display_id
FROM current_display_map
WHERE preview_name ILIKE 'Show Background Stage 21%'
GROUP BY preview_name, preview_stage_id, classification_code
ORDER BY preview_name, classification_code;

/* --------------------------------------------------------------------------
8. Show any current identity disagreement for Stage 21 WITHOUT showing UUIDs.
   These rows should be reviewed before FieldWiring relies on automatic routing.
---------------------------------------------------------------------------- */
WITH current_display_map AS MATERIALIZED (
    SELECT
        v.display_id,
        v.lor_display_name,
        v.production_display_name,
        v.preview_name,
        v.preview_stage_id,
        v.classification_code
    FROM ops.v_lor_display_reconciliation AS v
    JOIN lor_snap.v_current_run AS cr
      ON cr.import_run_id = v.import_run_id
    WHERE v.classification_code <> 'EXCLUDED_NONPHYSICAL'
)
SELECT
    display_id,
    production_display_name,
    lor_display_name AS current_lor_display_name,
    preview_name,
    preview_stage_id,
    classification_code
FROM current_display_map
WHERE preview_name ILIKE 'Show Background Stage 21%'
  AND classification_code <> 'EXACT_MATCH'
ORDER BY classification_code, production_display_name, lor_display_name;

/* --------------------------------------------------------------------------
9. Resolve current Stage 21 Scene membership directly from the CURRENT snapshot
   using the existing reconciliation bridge.

   This is intentionally current-state logic. It does not depend on historical
   snapshots and it does not require the operator to see Scene/Preview UUIDs.
---------------------------------------------------------------------------- */
WITH current_display_map AS MATERIALIZED (
    SELECT
        v.import_run_id,
        v.lor_prop_id AS source_lor_prop_id,
        v.display_id,
        v.production_display_name AS display_name,
        v.classification_code
    FROM ops.v_lor_display_reconciliation AS v
    JOIN lor_snap.v_current_run AS cr
      ON cr.import_run_id = v.import_run_id
    WHERE v.classification_code <> 'EXCLUDED_NONPHYSICAL'
      AND v.display_id IS NOT NULL
),
current_scene_membership AS (
    SELECT DISTINCT
        p.name AS preview_name,
        s.name AS scene_name,
        coalesce(slp.scene_stage_id, s.stage_id) AS scene_stage_id,
        dm.display_id,
        dm.display_name,
        dm.classification_code
    FROM lor_snap.v_current_scene_lor_props AS slp
    JOIN current_display_map AS dm
      ON dm.import_run_id = slp.import_run_id
     AND dm.source_lor_prop_id = slp.raw_prop_id
    JOIN lor_snap.v_current_previews AS p
      ON p.id = slp.preview_id
    LEFT JOIN lor_snap.v_current_scenes AS s
      ON s.preview_id = slp.preview_id
     AND s.scene_id = slp.scene_id
)
SELECT
    preview_name,
    scene_name,
    scene_stage_id,
    count(DISTINCT display_id) AS display_count
FROM current_scene_membership
WHERE lower(btrim(coalesce(scene_stage_id, ''))) = '21'
GROUP BY preview_name, scene_name, scene_stage_id
ORDER BY preview_name, scene_name;

/* --------------------------------------------------------------------------
10. Optional human-readable Stage 21 Scene membership detail.
    Useful if the summary above looks wrong.
---------------------------------------------------------------------------- */
WITH current_display_map AS MATERIALIZED (
    SELECT
        v.import_run_id,
        v.lor_prop_id AS source_lor_prop_id,
        v.display_id,
        v.production_display_name AS display_name,
        v.classification_code
    FROM ops.v_lor_display_reconciliation AS v
    JOIN lor_snap.v_current_run AS cr
      ON cr.import_run_id = v.import_run_id
    WHERE v.classification_code <> 'EXCLUDED_NONPHYSICAL'
      AND v.display_id IS NOT NULL
),
current_scene_membership AS (
    SELECT DISTINCT
        p.name AS preview_name,
        s.name AS scene_name,
        coalesce(slp.scene_stage_id, s.stage_id) AS scene_stage_id,
        dm.display_id,
        dm.display_name,
        dm.classification_code
    FROM lor_snap.v_current_scene_lor_props AS slp
    JOIN current_display_map AS dm
      ON dm.import_run_id = slp.import_run_id
     AND dm.source_lor_prop_id = slp.raw_prop_id
    JOIN lor_snap.v_current_previews AS p
      ON p.id = slp.preview_id
    LEFT JOIN lor_snap.v_current_scenes AS s
      ON s.preview_id = slp.preview_id
     AND s.scene_id = slp.scene_id
)
SELECT
    preview_name,
    scene_name,
    scene_stage_id,
    display_id,
    display_name,
    classification_code
FROM current_scene_membership
WHERE lower(btrim(coalesce(scene_stage_id, ''))) = '21'
ORDER BY preview_name, scene_name, display_name;
