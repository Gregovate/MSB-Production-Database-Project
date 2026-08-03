/* ============================================================================
Object:   Read-only validation of current LOR snapshot provenance views
Filename: 16_current_snapshot_provenance_validation.sql
Revision: 2026-08-03-current-snapshot-provenance-validation-v1

Purpose:
  Verify that the current-run interface exposes all parser/ingest provenance
  and that every preview in the latest parser generation exposes its source
  filename. Historical nullable provenance does not affect this current-run
  validation.

Safety:
  Read only. No snapshot, reconciliation, or production data is changed.

Revision history:
  2026-08-03  GAL / OpenAI  Initial current-snapshot provenance validation.
============================================================================ */

WITH current_provenance AS (
    SELECT
        cr.*,
        (SELECT count(*)
         FROM lor_snap.v_current_previews) AS actual_preview_count,
        (SELECT count(*)
         FROM lor_snap.v_current_previews AS p
         WHERE p.source_filename IS NULL
            OR btrim(p.source_filename) = '') AS missing_source_filename_count
    FROM lor_snap.v_current_run AS cr
)
SELECT
    import_run_id,
    parser_version,
    parser_started_at,
    parser_completed_at,
    parser_actor,
    parser_host,
    source_preview_folder,
    source_sqlite_path,
    ingest_script_version,
    ingest_actor,
    ingest_host,
    ingest_started_at,
    ingest_completed_at,
    preview_count AS recorded_preview_count,
    actual_preview_count,
    missing_source_filename_count,
    CASE
        WHEN parser_version IS NULL
          OR parser_completed_at IS NULL
          OR source_preview_folder IS NULL
          OR ingest_script_version IS NULL
          OR ingest_completed_at IS NULL
          OR preview_count IS DISTINCT FROM actual_preview_count
          OR missing_source_filename_count <> 0
        THEN 'FAIL'
        ELSE 'PASS'
    END AS provenance_validation
FROM current_provenance;

SELECT
    p.source_filename,
    p.name AS preview_name,
    p.revision AS preview_revision,
    p.stage_id
FROM lor_snap.v_current_previews AS p
ORDER BY p.source_filename, p.name;
