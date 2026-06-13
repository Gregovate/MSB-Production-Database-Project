-- MSB Database — Postgres View
-- Mirrors SQLite: preview_wiring_sorted_v6
-- Source: lor_snap.preview_wiring_map_v6 (current-run)

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