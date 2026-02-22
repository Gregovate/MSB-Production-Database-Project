-- =============================================================================
-- MSB Database — LOR Snapshot Views (lor_snap)
-- postgres_create_views_lor_snap.sql
--
-- Initial Release : 2026-02-22  V0.1.0
-- Current Version : 2026-02-22  V0.1.0
-- Changes:
-- - Initial Postgres view layer for wiring + stage display reporting
-- - Mirrors v6 SQLite view intent using lor_snap.v_current_* sources
-- (GAL)
-- Author          : Greg Liebig, Engineering Innovations, LLC.
--
-- Purpose
-- -------
-- Rebuild all Postgres views that sit on top of the latest LOR snapshot run:
--   - Wiring views (preview_wiring_*)
--   - Stage display / inventory views (stage_display_*)
--
-- Notes
-- -----
-- - These views target lor_snap.v_current_* so they automatically follow
--   the most recent import_run_id.
-- - This file is intended to be run after each ingestion.
-- - Execute with ON_ERROR_STOP=1 so you never end up with partial builds.
-- =============================================================================

BEGIN;

CREATE SCHEMA IF NOT EXISTS lor_snap;

-- =============================================================================
-- 1) Wiring Views (dependency order)
-- =============================================================================

-- 1.1 preview_wiring_map_v6
CREATE OR REPLACE VIEW lor_snap.preview_wiring_map_v6 AS
    -- Master props (single-grid legs on props)
    SELECT
        pv.name AS preview_name,
        REPLACE(BTRIM(p.lor_comment), ' ', '-') AS display_name,
        p.name AS lor_name,
        p.network AS network,
        p.uid AS controller,
        p.start_channel AS start_channel,
        p.end_channel AS end_channel,
        p.device_type AS device_type,
        'PROP'::text AS source,
        p.tag AS lor_tag
    FROM lor_snap.v_current_props p
    JOIN lor_snap.v_current_previews pv ON pv.id = p.preview_id
    WHERE p.network IS NOT NULL
      AND p.start_channel IS NOT NULL

    UNION ALL

    -- Subprops (multi-grid legs)
    SELECT
        pv.name AS preview_name,
        REPLACE(BTRIM(COALESCE(NULLIF(sp.lor_comment,''), p.lor_comment)), ' ', '-') AS display_name,
        sp.name AS lor_name,
        sp.network AS network,
        sp.uid AS controller,
        sp.start_channel AS start_channel,
        sp.end_channel AS end_channel,
        COALESCE(sp.device_type,'LOR') AS device_type,
        'SUBPROP'::text AS source,
        sp.tag AS lor_tag
    FROM lor_snap.v_current_sub_props sp
    JOIN lor_snap.v_current_props p  ON p.prop_id = sp.master_prop_id
    JOIN lor_snap.v_current_previews pv ON pv.id = sp.preview_id

    UNION ALL

    -- DMX channel blocks
    SELECT
        pv.name AS preview_name,
        REPLACE(BTRIM(p.lor_comment), ' ', '-') AS display_name,
        p.name AS lor_name,
        dc.network AS network,
        dc.start_universe::text AS controller,
        dc.start_channel AS start_channel,
        dc.end_channel AS end_channel,
        'DMX'::text AS device_type,
        'DMX'::text AS source,
        p.tag AS lor_tag
    FROM lor_snap.v_current_dmx_channels dc
    JOIN lor_snap.v_current_props p  ON p.prop_id = dc.prop_id
    JOIN lor_snap.v_current_previews pv ON pv.id = p.preview_id;


-- 1.2 preview_wiring_sorted_v6
CREATE OR REPLACE VIEW lor_snap.preview_wiring_sorted_v6 AS
SELECT
  preview_name,
  display_name,
  lor_name,
  network,
  controller,
  start_channel,
  end_channel,
  device_type,
  source,
  lor_tag
FROM lor_snap.preview_wiring_map_v6
ORDER BY
  lower(preview_name)  ASC,
  lower(display_name)  ASC,
  controller           ASC,
  start_channel        ASC;


-- 1.3 preview_wiring_fieldmap_v6
CREATE OR REPLACE VIEW lor_snap.preview_wiring_fieldmap_v6 AS
WITH map AS (
  SELECT
    m.preview_name,
    m.source,
    m.lor_name      AS channel_name,
    m.display_name  AS display_name,
    m.network,
    m.controller,
    m.start_channel,
    m.end_channel,
    CASE WHEN m.device_type = 'DMX' THEN 'RGB' ELSE NULL END AS color,
    m.device_type   AS device_type,
    m.lor_tag
  FROM lor_snap.preview_wiring_sorted_v6 m
  WHERE m.controller IS NOT NULL
    AND m.start_channel IS NOT NULL
    AND m.device_type <> 'None'
),
ranked AS (
  SELECT
    map.*,
    ROW_NUMBER() OVER (
      PARTITION BY preview_name, network, controller, start_channel, display_name
      ORDER BY (source = 'PROP') DESC, lower(channel_name)
    ) AS lead_rank
  FROM map
),
span AS (
  SELECT
    ranked.*,
    SUM(CASE WHEN lead_rank = 1 THEN 1 ELSE 0 END)
      OVER (PARTITION BY preview_name, network, controller, start_channel) AS display_span
  FROM ranked
)
SELECT
  preview_name,
  source,
  channel_name,
  display_name,
  network,
  controller,
  start_channel,
  end_channel,
  color,
  device_type,
  lor_tag,
  CASE WHEN lead_rank = 1 THEN 'FIELD' ELSE 'INTERNAL' END AS connection_type,
  CASE WHEN display_span > 1 THEN 1 ELSE 0 END             AS cross_display
FROM span;


-- 1.4 preview_wiring_fieldlead_v6
CREATE OR REPLACE VIEW lor_snap.preview_wiring_fieldlead_v6 AS
WITH ranked AS (
  SELECT
    f.*,
    ROW_NUMBER() OVER (
      PARTITION BY f.preview_name, f.network, f.controller, f.start_channel, f.display_name
      ORDER BY (f.source = 'PROP') DESC, lower(f.channel_name)
    ) AS lead_rank
  FROM lor_snap.preview_wiring_fieldmap_v6 f
)
SELECT *
FROM ranked
WHERE lead_rank = 1;


-- 1.5 preview_wiring_circuit_rollup_v6  (controller is HEX)
CREATE OR REPLACE VIEW lor_snap.preview_wiring_circuit_rollup_v6 AS
SELECT
  preview_name,
  network,
  controller,
  start_channel,
  COUNT(*) AS display_count,
  string_agg(display_name, ' | ' ORDER BY lower(display_name)) AS displays
FROM lor_snap.preview_wiring_fieldlead_v6
GROUP BY preview_name, network, controller, start_channel
ORDER BY
  network,
  CASE
    WHEN controller ~* '^[0-9a-f]+$'
      THEN ('x' || controller)::bit(32)::int
    ELSE NULL
  END,
  controller,
  start_channel;


-- 1.6 preview_wiring_fieldonly_v6
CREATE OR REPLACE VIEW lor_snap.preview_wiring_fieldonly_v6 AS
SELECT *
FROM lor_snap.preview_wiring_fieldmap_v6
WHERE connection_type = 'FIELD';


-- =============================================================================
-- 2) Stage / Display / Inventory Views (dependency order)
-- =============================================================================

-- 2.1 stage_display_assets_v1  (channel-bearing)
CREATE OR REPLACE VIEW lor_snap.stage_display_assets_v1 AS
-- Props
SELECT
  pv.stage_id,
  pv.name AS preview_name,
  p.lor_comment AS display_name,
  p.name AS channel_name,
  COALESCE(p.device_type, 'LOR') AS device_type,
  p.network,
  p.uid,
  p.start_channel,
  p.end_channel,
  1 AS has_wiring,
  'PROP'::text AS source
FROM lor_snap.v_current_props p
JOIN lor_snap.v_current_previews pv ON pv.id = p.preview_id
WHERE p.network IS NOT NULL
  AND p.start_channel IS NOT NULL

UNION ALL

-- Subprops
SELECT
  pv.stage_id,
  pv.name,
  COALESCE(NULLIF(sp.lor_comment,''), p.lor_comment) AS display_name,
  sp.name AS channel_name,
  COALESCE(sp.device_type,'LOR') AS device_type,
  sp.network,
  sp.uid,
  sp.start_channel,
  sp.end_channel,
  1 AS has_wiring,
  'SUBPROP'::text
FROM lor_snap.v_current_sub_props sp
JOIN lor_snap.v_current_props p  ON p.prop_id = sp.master_prop_id
JOIN lor_snap.v_current_previews pv ON pv.id = sp.preview_id
WHERE sp.network IS NOT NULL
  AND sp.start_channel IS NOT NULL

UNION ALL

-- DMX channels
SELECT
  pv.stage_id,
  pv.name,
  p.lor_comment AS display_name,
  p.name AS channel_name,
  'DMX'::text AS device_type,
  dc.network,
  dc.start_universe::text AS uid,
  dc.start_channel,
  dc.end_channel,
  1 AS has_wiring,
  'DMX'::text
FROM lor_snap.v_current_dmx_channels dc
JOIN lor_snap.v_current_props p  ON p.prop_id = dc.prop_id
JOIN lor_snap.v_current_previews pv ON pv.id = p.preview_id;


-- 2.2 stage_display_inventory_only_v1  (present, no channels)
CREATE OR REPLACE VIEW lor_snap.stage_display_inventory_only_v1 AS
-- Props without wiring
SELECT DISTINCT
  pv.stage_id,
  pv.name AS preview_name,
  p.lor_comment AS display_name,
  NULL::text AS channel_name,
  COALESCE(p.device_type,'INV') AS device_type,
  NULL::text AS network,
  NULL::text AS uid,
  NULL::integer AS start_channel,
  NULL::integer AS end_channel,
  0 AS has_wiring,
  'PROP_INV'::text AS source
FROM lor_snap.v_current_props p
JOIN lor_snap.v_current_previews pv ON pv.id = p.preview_id
WHERE (p.network IS NULL OR p.start_channel IS NULL)
  AND BTRIM(COALESCE(p.lor_comment,'')) <> ''

UNION

-- Subprops without wiring
SELECT DISTINCT
  pv.stage_id,
  pv.name,
  COALESCE(NULLIF(sp.lor_comment,''), p.lor_comment) AS display_name,
  NULL::text AS channel_name,
  COALESCE(sp.device_type,'INV') AS device_type,
  NULL::text,
  NULL::text,
  NULL::integer,
  NULL::integer,
  0 AS has_wiring,
  'SUBPROP_INV'::text
FROM lor_snap.v_current_sub_props sp
JOIN lor_snap.v_current_props p  ON p.prop_id = sp.master_prop_id
JOIN lor_snap.v_current_previews pv ON pv.id = sp.preview_id
WHERE (sp.network IS NULL OR sp.start_channel IS NULL)
  AND BTRIM(COALESCE(COALESCE(NULLIF(sp.lor_comment,''), p.lor_comment), '')) <> '';


-- 2.3 stage_display_assets_all_v1
CREATE OR REPLACE VIEW lor_snap.stage_display_assets_all_v1 AS
SELECT * FROM lor_snap.stage_display_assets_v1
UNION ALL
SELECT * FROM lor_snap.stage_display_inventory_only_v1;


-- 2.4 stage_display_list_all_v1  (print-friendly distinct list)
CREATE OR REPLACE VIEW lor_snap.stage_display_list_all_v1 AS
WITH base AS (
  SELECT
    COALESCE(stage_id, 'Unassigned') AS stage_bucket,
    preview_name,
    BTRIM(display_name) AS display_name,
    has_wiring
  FROM lor_snap.stage_display_assets_all_v1
  WHERE BTRIM(COALESCE(display_name,'')) <> ''
),
labeled AS (
  SELECT
    stage_bucket,
    (stage_bucket || ' — ' || preview_name) AS stage_preview_label,
    display_name,
    has_wiring
  FROM base
),
aggregated AS (
  SELECT
    stage_bucket,
    stage_preview_label,
    display_name,
    MAX(has_wiring) AS has_wiring
  FROM labeled
  GROUP BY stage_bucket, stage_preview_label, display_name
)
SELECT *
FROM aggregated
ORDER BY
  CASE WHEN stage_bucket = 'Unassigned' THEN 1 ELSE 0 END,
  length(stage_bucket),
  stage_bucket,
  CASE WHEN stage_preview_label LIKE '%Show Background Stage%' THEN 0 ELSE 1 END,
  CASE WHEN stage_preview_label LIKE '%RGB Plus Prop Stage%' THEN 0 ELSE 1 END,
  lower(stage_preview_label),
  lower(display_name);


-- 2.5 stage_display_unassigned_v1
CREATE OR REPLACE VIEW lor_snap.stage_display_unassigned_v1 AS
SELECT display_name
FROM lor_snap.stage_display_list_all_v1
WHERE stage_bucket = 'Unassigned';

COMMIT;