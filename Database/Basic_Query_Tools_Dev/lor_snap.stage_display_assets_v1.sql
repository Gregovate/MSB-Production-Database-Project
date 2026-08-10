-- Channel-bearing assets (props / sub_props / dmx_channels)
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