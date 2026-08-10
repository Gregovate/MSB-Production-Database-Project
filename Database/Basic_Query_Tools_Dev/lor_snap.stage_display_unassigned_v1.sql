-- Unassigned quick check
CREATE OR REPLACE VIEW lor_snap.stage_display_unassigned_v1 AS
SELECT display_name
FROM lor_snap.stage_display_list_all_v1
WHERE stage_bucket = 'Unassigned';