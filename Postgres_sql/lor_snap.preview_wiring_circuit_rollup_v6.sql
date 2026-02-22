-- Per-circuit rollup for auditing shared circuits (controllers are HEX)
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