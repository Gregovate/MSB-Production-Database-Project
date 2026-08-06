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