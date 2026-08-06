-- All assets together (channel-bearing + inventory-only)
CREATE OR REPLACE VIEW lor_snap.stage_display_assets_all_v1 AS
SELECT * 
FROM lor_snap.stage_display_assets_v1

UNION ALL

SELECT * 
FROM lor_snap.stage_display_inventory_only_v1;