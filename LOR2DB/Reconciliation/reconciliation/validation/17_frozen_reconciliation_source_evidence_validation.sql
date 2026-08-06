/* Read-only validation after installing 0021 and starting reconciliation. */

WITH latest AS (
    SELECT r.lor_reconciliation_run_id, r.import_run_id
    FROM ops.lor_reconciliation_run AS r
    ORDER BY r.lor_reconciliation_run_id DESC
    LIMIT 1
)
SELECT
    l.lor_reconciliation_run_id,
    l.import_run_id,
    sr.parser_version,
    sr.source_preview_folder,
    sr.ingest_script_version,
    sr.preview_count AS recorded_preview_count,
    count(DISTINCT p.lor_reconciliation_source_preview_id)
        AS frozen_preview_count,
    sr.scene_count AS recorded_scene_count,
    count(DISTINCT s.lor_reconciliation_source_scene_row_id)
        AS frozen_scene_count,
    count(DISTINCT p.lor_reconciliation_source_preview_id)
        FILTER (WHERE p.source_filename IS NULL) AS missing_source_filename_count,
    CASE
        WHEN sr.lor_reconciliation_run_id IS NULL THEN 'FAIL: SOURCE RUN MISSING'
        WHEN sr.preview_count IS DISTINCT FROM
             count(DISTINCT p.lor_reconciliation_source_preview_id)
            THEN 'FAIL: PREVIEW COUNT'
        WHEN sr.scene_count IS DISTINCT FROM
             count(DISTINCT s.lor_reconciliation_source_scene_row_id)
            THEN 'FAIL: SCENE COUNT'
        WHEN count(DISTINCT p.lor_reconciliation_source_preview_id)
             FILTER (WHERE p.source_filename IS NULL) <> 0
            THEN 'FAIL: SOURCE FILENAME'
        ELSE 'PASS'
    END AS frozen_source_validation
FROM latest AS l
LEFT JOIN ops.lor_reconciliation_source_run AS sr
  ON sr.lor_reconciliation_run_id = l.lor_reconciliation_run_id
LEFT JOIN ops.lor_reconciliation_source_preview AS p
  ON p.lor_reconciliation_run_id = l.lor_reconciliation_run_id
LEFT JOIN ops.lor_reconciliation_source_scene AS s
  ON s.lor_reconciliation_run_id = l.lor_reconciliation_run_id
GROUP BY l.lor_reconciliation_run_id, l.import_run_id,
         sr.lor_reconciliation_run_id, sr.parser_version,
         sr.source_preview_folder, sr.ingest_script_version,
         sr.preview_count, sr.scene_count;

SELECT
    source_filename,
    preview_name,
    preview_revision,
    stage_id
FROM ops.lor_reconciliation_source_preview
WHERE lor_reconciliation_run_id = (
    SELECT max(lor_reconciliation_run_id)
    FROM ops.lor_reconciliation_run
)
ORDER BY source_filename;
