/* ============================================================================
Object:   Rollback-only validation of reconciliation-safe P3/P4
Filename: 14_reconciliation_safe_scene_promotion_validation.sql

Safety:
  This entire validation is one transaction ending in ROLLBACK. It temporarily
  records the already-confirmed Welcome reassociation required by Run 1, calls
  P3/P2/P4 in dependency order twice, validates the current-state projection,
  and rolls back every action, result, scene, membership, and display change.

Revision history:
  2026-08-03  GAL / OpenAI  Initial P3/P4 rollback validation.
============================================================================ */

BEGIN;

DO $validation$
DECLARE
    v_run_id bigint := 1;
    v_group_id bigint;
    v_map jsonb;
BEGIN
    IF NOT EXISTS (
        SELECT 1
        FROM ops.lor_reconciliation_scene_candidate
        WHERE lor_reconciliation_run_id = v_run_id
    ) THEN
        RAISE EXCEPTION 'Run 1 has no frozen scene candidates; install 0018 first';
    END IF;

    IF EXISTS (
        SELECT 1
        FROM ops.lor_reconciliation_scene_candidate
        WHERE lor_reconciliation_run_id = v_run_id
          AND is_blocking
    ) OR EXISTS (
        SELECT 1
        FROM ops.lor_reconciliation_scene_display_candidate
        WHERE lor_reconciliation_run_id = v_run_id
          AND is_blocking
    ) THEN
        RAISE EXCEPTION 'Run 1 contains blocked scene data; promotion validation must stop';
    END IF;

    SELECT g.lor_reconciliation_group_id
      INTO STRICT v_group_id
    FROM ops.lor_reconciliation_group AS g
    WHERE g.lor_reconciliation_run_id = v_run_id
      AND g.entity_type = 'DISPLAY'
      AND g.logical_group_key = 'DISPLAY_IDENTITY:920';

    SELECT jsonb_object_agg(
               c.lor_reconciliation_display_candidate_id::text,
               c.display_id
           )
      INTO v_map
    FROM ops.lor_reconciliation_display_candidate AS c
    WHERE c.lor_reconciliation_group_id = v_group_id;

    IF (
        SELECT count(*)
        FROM jsonb_object_keys(coalesce(v_map, '{}'::jsonb))
    ) <> 2 THEN
        RAISE EXCEPTION 'Welcome validation requires exactly two frozen members';
    END IF;

    PERFORM ops.f_record_lor_reconciliation_action(
        v_run_id,
        v_group_id,
        'REASSOCIATE_DISPLAY',
        'Rollback validation only: confirmed Welcome chained rename.',
        v_map,
        'rollback-validation-14'
    );
END;
$validation$;

/* Prove that P3 removes a scene whose preview is absent from captured Run 1. */
INSERT INTO ref.lor_scene (
    preview_uuid, scene_uuid, stage_id, scene_name, source_import_run_id
)
SELECT
    '__ROLLBACK_OBSOLETE_PREVIEW__',
    '__ROLLBACK_OBSOLETE_SCENE__',
    min(c.resolved_stage_id),
    'Rollback-only obsolete-scene test',
    r.import_run_id
FROM ops.lor_reconciliation_scene_candidate AS c
JOIN ops.lor_reconciliation_run AS r
  ON r.lor_reconciliation_run_id = c.lor_reconciliation_run_id
WHERE c.lor_reconciliation_run_id = 1
  AND c.resolved_stage_id IS NOT NULL
GROUP BY r.import_run_id;

CALL ref.p3_promote_scene_from_reconciliation(1);
CALL ref.p2_promote_display_from_reconciliation(1);
CALL ref.p4_promote_scene_display_from_reconciliation(1);

SELECT
    (SELECT count(*)
     FROM ops.lor_reconciliation_scene_candidate
     WHERE lor_reconciliation_run_id = 1) AS frozen_scene_count,
    (SELECT count(*)
     FROM ref.lor_scene
     WHERE source_import_run_id = (
         SELECT import_run_id FROM ops.lor_reconciliation_run
         WHERE lor_reconciliation_run_id = 1
     )) AS promoted_scene_count,
    (SELECT count(*)
     FROM ops.lor_reconciliation_scene_display_candidate
     WHERE lor_reconciliation_run_id = 1) AS frozen_membership_count,
    (SELECT count(*)
     FROM ref.lor_scene_display
     WHERE source_import_run_id = (
         SELECT import_run_id FROM ops.lor_reconciliation_run
         WHERE lor_reconciliation_run_id = 1
     )) AS promoted_membership_count;

SELECT
    count(*) FILTER (WHERE ls.lor_scene_id IS NULL)
        AS missing_promoted_scene_count,
    count(*) FILTER (
        WHERE ls.stage_id IS DISTINCT FROM c.resolved_stage_id
           OR ls.scene_name IS DISTINCT FROM c.scene_name
           OR ls.scene_section IS DISTINCT FROM c.scene_section
           OR ls.background_file IS DISTINCT FROM c.background_file
           OR ls.h_scroll IS DISTINCT FROM c.h_scroll
           OR ls.v_scroll IS DISTINCT FROM c.v_scroll
           OR ls.zoom IS DISTINCT FROM c.zoom
           OR ls.create_grid_view IS DISTINCT FROM c.create_grid_view
    ) AS incorrect_scene_count,
    count(*) FILTER (
        WHERE c.is_blocking OR c.initial_resolution_state <> 'AUTO_APPROVED'
    ) AS ineligible_scene_count,
    CASE WHEN count(*) FILTER (
        WHERE ls.lor_scene_id IS NULL
           OR ls.stage_id IS DISTINCT FROM c.resolved_stage_id
           OR ls.scene_name IS DISTINCT FROM c.scene_name
           OR ls.scene_section IS DISTINCT FROM c.scene_section
           OR ls.background_file IS DISTINCT FROM c.background_file
           OR ls.h_scroll IS DISTINCT FROM c.h_scroll
           OR ls.v_scroll IS DISTINCT FROM c.v_scroll
           OR ls.zoom IS DISTINCT FROM c.zoom
           OR ls.create_grid_view IS DISTINCT FROM c.create_grid_view
    ) = 0 THEN 'PASS' ELSE 'FAIL' END AS p3_scene_projection_validation
FROM ops.lor_reconciliation_scene_candidate AS c
LEFT JOIN ref.lor_scene AS ls
  ON ls.preview_uuid = c.preview_id
 AND ls.scene_uuid = c.scene_id
WHERE c.lor_reconciliation_run_id = 1;

SELECT
    count(*) FILTER (WHERE lsd.display_id IS NULL)
        AS missing_promoted_membership_count,
    count(*) FILTER (WHERE lsd.lor_scene_id IS DISTINCT FROM ls.lor_scene_id)
        AS incorrect_membership_count,
    count(*) FILTER (WHERE d.display_id IS NULL)
        AS unresolved_permanent_display_count,
    (SELECT count(*)
     FROM (
         SELECT preview_uuid, display_id
         FROM ref.lor_scene_display
         GROUP BY preview_uuid, display_id
         HAVING count(*) > 1
     ) AS duplicate_membership) AS duplicate_preview_display_count,
    CASE WHEN count(*) FILTER (
        WHERE d.display_id IS NULL
           OR lsd.display_id IS NULL
           OR lsd.lor_scene_id IS DISTINCT FROM ls.lor_scene_id
    ) = 0 THEN 'PASS' ELSE 'FAIL' END AS p4_membership_projection_validation
FROM ops.lor_reconciliation_scene_display_candidate AS c
JOIN ops.lor_reconciliation_display_candidate AS dc
  ON dc.lor_reconciliation_display_candidate_id =
     c.lor_reconciliation_display_candidate_id
JOIN ops.v_lor_reconciliation_group_review AS dgr
  ON dgr.lor_reconciliation_group_id = dc.lor_reconciliation_group_id
LEFT JOIN ref.display AS d ON d.lor_prop_id = c.source_lor_prop_id
LEFT JOIN ref.lor_scene AS ls
  ON ls.preview_uuid = c.preview_id
 AND ls.scene_uuid = c.scene_id
LEFT JOIN ref.lor_scene_display AS lsd
  ON lsd.preview_uuid = c.preview_id
 AND lsd.display_id = d.display_id
WHERE c.lor_reconciliation_run_id = 1
  AND NOT c.is_blocking
  AND dgr.effective_resolution_state IN ('AUTO_APPROVED', 'APPROVED');

SELECT
    count(*) AS obsolete_scene_remaining_count,
    CASE WHEN count(*) = 0 THEN 'PASS' ELSE 'FAIL' END
        AS p3_obsolete_scene_deletion_validation
FROM ref.lor_scene
WHERE preview_uuid = '__ROLLBACK_OBSOLETE_PREVIEW__'
  AND scene_uuid = '__ROLLBACK_OBSOLETE_SCENE__';

CREATE TEMP TABLE pg_temp._scene_result_count ON COMMIT DROP AS
SELECT entity_type, count(*) AS result_count
FROM ops.lor_reconciliation_result
WHERE lor_reconciliation_run_id = 1
  AND entity_type IN ('SCENE', 'SCENE_DISPLAY')
  AND committed
GROUP BY entity_type;

CALL ref.p3_promote_scene_from_reconciliation(1);
CALL ref.p2_promote_display_from_reconciliation(1);
CALL ref.p4_promote_scene_display_from_reconciliation(1);

SELECT
    before_count.entity_type,
    before_count.result_count AS first_call_result_count,
    count(r.*) AS second_call_result_count,
    CASE WHEN count(r.*) = before_count.result_count
         THEN 'PASS' ELSE 'FAIL' END
        AS same_transaction_idempotency_validation
FROM pg_temp._scene_result_count AS before_count
LEFT JOIN ops.lor_reconciliation_result AS r
  ON r.lor_reconciliation_run_id = 1
 AND r.entity_type = before_count.entity_type
 AND r.committed
GROUP BY before_count.entity_type, before_count.result_count
ORDER BY before_count.entity_type;

SELECT
    r.lor_reconciliation_run_id,
    r.import_run_id,
    r.status,
    r.unresolved_count,
    r.deferred_count,
    r.blocked_count,
    count(rr.*) FILTER (WHERE rr.entity_type = 'SCENE' AND rr.committed)
        AS rollback_test_scene_result_count,
    count(rr.*) FILTER (
        WHERE rr.entity_type = 'SCENE_DISPLAY' AND rr.committed
    ) AS rollback_test_membership_result_count,
    'ROLLBACK REQUIRED'::text AS transaction_disposition
FROM ops.lor_reconciliation_run AS r
LEFT JOIN ops.lor_reconciliation_result AS rr
  ON rr.lor_reconciliation_run_id = r.lor_reconciliation_run_id
WHERE r.lor_reconciliation_run_id = 1
GROUP BY r.lor_reconciliation_run_id;

ROLLBACK;
