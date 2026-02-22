-- MSB Database — Postgres View
-- Mirrors SQLite: preview_wiring_map_v6
-- Source: lor_snap.v_current_* (latest import_run_id)

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
    WHERE p.network IS NOT NULL AND p.start_channel IS NOT NULL

    UNION ALL

    -- Subprops (multi-grid legs on sub_props)
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

    -- DMX channel blocks (dmx_channels)
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