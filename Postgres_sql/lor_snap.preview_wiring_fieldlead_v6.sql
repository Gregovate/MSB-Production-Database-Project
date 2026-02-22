-- Exactly one lead row per display per circuit (what to wire in the field)
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