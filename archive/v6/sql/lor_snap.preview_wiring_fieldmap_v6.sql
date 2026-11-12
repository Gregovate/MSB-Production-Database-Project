-- =============================================================================
-- MSB Database — Wiring Field Mapping Views (Postgres)
-- Port of:
--   preview_wiring_fieldmap_v6
--   preview_wiring_fieldlead_v6
--   preview_wiring_circuit_rollup_v6
--   preview_wiring_fieldonly_v6
-- Source: lor_snap.preview_wiring_sorted_v6 (current-run)
-- Controllers are HEX (e.g., 0A, 0B, 10, 1F)
-- =============================================================================

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

-- Rollup: safe sort for HEX controller codes
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
  lower(preview_name),
  network,
  CASE
    WHEN controller ~* '^[0-9a-f]+$'
      THEN ('x' || controller)::bit(32)::int
    ELSE NULL
  END,
  controller,
  start_channel;

CREATE OR REPLACE VIEW lor_snap.preview_wiring_fieldonly_v6 AS
SELECT *
FROM lor_snap.preview_wiring_fieldmap_v6
WHERE connection_type = 'FIELD';