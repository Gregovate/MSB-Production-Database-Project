-- Inventory-only assets (present in previews, but with NO channels)
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
  AND BTRIM(COALESCE(
        COALESCE(NULLIF(sp.lor_comment,''), p.lor_comment),
        ''
      )) <> '';