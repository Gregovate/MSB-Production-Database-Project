/* ============================================================================
File:        19_preview_manifest_stage_binding_validation.sql
Validation: Preview-manifest stage binding correction
Migration:  0023_use_preview_manifest_for_stage_bindings.sql

Purpose:
  Verify the installed stage builder uses preserved preview filenames as
  evidence and cannot treat descriptive names of existing-stage preview files
  as authority to rename permanent stage metadata.

Safety:
  - Read-only.
  - Does not start reconciliation, build candidates, record decisions, or call
    P1/P2/P3/P4.
  - Does not modify lor_snap, ops, ref, or production data.

Revision history:
  2026-08-03  GAL / OpenAI  Initial validation.
============================================================================ */

WITH installed AS (
    SELECT pg_get_functiondef(
        'ops.f_build_lor_reconciliation_stage_candidates(bigint)'::regprocedure
    ) AS function_definition
),
latest_completed_ingest AS (
    SELECT max(ir.import_run_id) AS import_run_id
    FROM lor_snap.import_run AS ir
    WHERE ir.ingest_completed_at IS NOT NULL
),
preview_evidence AS (
    SELECT
        p.import_run_id,
        lower(btrim(p.stage_id)) AS stage_key,
        p.id AS preview_id,
        p.source_filename,
        p.name AS preview_name,
        s.stage_id AS permanent_stage_id
    FROM lor_snap.previews AS p
    JOIN latest_completed_ingest AS li
      ON li.import_run_id = p.import_run_id
    LEFT JOIN ref.stage AS s
      ON s.stage_key = lower(btrim(p.stage_id))
    WHERE p.name NOT ILIKE '%master musical preview%'
      AND lower(btrim(p.stage_id)) ~ '^(0|[0-9]{1,2})[a-z]?$'
),
same_stage_multi_file AS (
    SELECT
        stage_key,
        permanent_stage_id,
        count(*)::integer AS preview_count,
        count(DISTINCT source_filename)::integer AS filename_count,
        array_agg(source_filename ORDER BY source_filename) AS source_filenames,
        array_agg(preview_name ORDER BY source_filename) AS preview_names
    FROM preview_evidence
    WHERE permanent_stage_id IS NOT NULL
    GROUP BY stage_key, permanent_stage_id
    HAVING count(DISTINCT source_filename) > 1
),
checks AS (
    SELECT
        'builder captures source_filename'::text AS check_name,
        position('p.source_filename' IN i.function_definition) > 0 AS passed,
        NULL::text AS detail
    FROM installed AS i

    UNION ALL

    SELECT
        'existing stage disables preview-name metadata authority',
        position(
            'coalesce(b.stage_id, sk.stage_id) IS NULL'
            IN i.function_definition
        ) > 0,
        NULL
    FROM installed AS i

    UNION ALL

    SELECT
        'latest ingest preview filenames are complete',
        count(*) FILTER (
            WHERE nullif(btrim(source_filename), '') IS NULL
        ) = 0,
        format(
            '%s eligible previews; %s missing filenames',
            count(*),
            count(*) FILTER (
                WHERE nullif(btrim(source_filename), '') IS NULL
            )
        )
    FROM preview_evidence

    UNION ALL

    SELECT
        'legitimate same-stage preview files remain individually visible',
        count(*) > 0,
        format('%s existing stages have multiple manifest files', count(*))
    FROM same_stage_multi_file
)
SELECT
    check_name,
    CASE WHEN passed THEN 'PASS' ELSE 'FAIL' END AS result,
    detail
FROM checks
ORDER BY check_name;

/* Human-readable evidence for Stage 00, Stage 01, Stage 04, and any others. */
WITH latest_completed_ingest AS (
    SELECT max(ir.import_run_id) AS import_run_id
    FROM lor_snap.import_run AS ir
    WHERE ir.ingest_completed_at IS NOT NULL
)
SELECT
    lower(btrim(p.stage_id)) AS stage_key,
    s.stage_id AS permanent_stage_id,
    s.stage_name AS permanent_stage_name,
    count(*)::integer AS preview_count,
    array_agg(p.source_filename ORDER BY p.source_filename) AS source_filenames,
    array_agg(p.name ORDER BY p.source_filename) AS preview_names,
    'AUTO-BIND FILES; PRESERVE PERMANENT STAGE METADATA'::text
        AS expected_behavior
FROM lor_snap.previews AS p
JOIN latest_completed_ingest AS li
  ON li.import_run_id = p.import_run_id
JOIN ref.stage AS s
  ON s.stage_key = lower(btrim(p.stage_id))
WHERE p.name NOT ILIKE '%master musical preview%'
  AND lower(btrim(p.stage_id)) ~ '^(0|[0-9]{1,2})[a-z]?$'
GROUP BY lower(btrim(p.stage_id)), s.stage_id, s.stage_name
HAVING count(DISTINCT p.source_filename) > 1
ORDER BY stage_key;
