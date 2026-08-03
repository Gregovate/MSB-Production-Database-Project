/* ============================================================================
Object:   Rollback-only validation of atomic Finish/Cancel lifecycle
Filename: 15_reconciliation_finish_cancel_rollback_validation.sql
Revision: 2026-08-03-reconciliation-finish-cancel-validation-v1

Safety:
  Part A calls Finish for development Run 1 and rolls back all P1-P4 writes.
  Part B calls Cancel for the same restored run and rolls back the snapshot
  deletion and cancellation audit. No production or snapshot change persists.

Revision history:
  2026-08-03  GAL / OpenAI  Initial Finish/Cancel rollback validation.
============================================================================ */

/* Part A: atomic Finish. */
BEGIN;

DO $validation$
DECLARE
    v_run_id bigint := 1;
    v_group_id bigint;
    v_map jsonb;
BEGIN
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

    IF (SELECT count(*) FROM jsonb_object_keys(coalesce(v_map, '{}'::jsonb))) <> 2
    THEN
        RAISE EXCEPTION 'Finish validation requires two Welcome candidates';
    END IF;

    PERFORM ops.f_record_lor_reconciliation_action(
        v_run_id, v_group_id, 'REASSOCIATE_DISPLAY',
        'Rollback validation only: confirmed Welcome chained rename.',
        v_map, 'rollback-validation-15'
    );
END;
$validation$;

CALL ops.p_finish_lor_reconciliation(1, 'rollback-validation-15');

SELECT
    r.lor_reconciliation_run_id,
    r.import_run_id,
    r.status,
    r.validation_state,
    r.unresolved_count,
    r.deferred_count,
    r.blocked_count,
    count(rr.lor_reconciliation_result_id) FILTER (
        WHERE rr.reason_code = 'FINISH_POST_WRITE_VALIDATION_PASSED'
          AND rr.committed
    ) AS finish_validation_result_count
FROM ops.lor_reconciliation_run AS r
LEFT JOIN ops.lor_reconciliation_result AS rr
  ON rr.lor_reconciliation_run_id = r.lor_reconciliation_run_id
WHERE r.lor_reconciliation_run_id = 1
GROUP BY r.lor_reconciliation_run_id;

SELECT
    count(*) FILTER (WHERE s.lor_scene_id IS NULL) AS missing_scene_count,
    count(*) FILTER (WHERE sd.lor_scene_display_id IS NULL)
        AS missing_membership_count,
    CASE WHEN count(*) FILTER (
        WHERE s.lor_scene_id IS NULL OR sd.lor_scene_display_id IS NULL
    ) = 0 THEN 'PASS' ELSE 'FAIL' END AS finish_projection_validation
FROM ops.lor_reconciliation_scene_display_candidate AS c
JOIN ops.lor_reconciliation_display_candidate AS dc
  ON dc.lor_reconciliation_display_candidate_id =
     c.lor_reconciliation_display_candidate_id
JOIN ops.v_lor_reconciliation_group_review AS display_group
  ON display_group.lor_reconciliation_group_id = dc.lor_reconciliation_group_id
LEFT JOIN ref.display AS d ON d.lor_prop_id = c.source_lor_prop_id
LEFT JOIN ref.lor_scene AS s
  ON s.preview_uuid = c.preview_id
 AND s.scene_uuid = c.scene_id
LEFT JOIN ref.lor_scene_display AS sd
  ON sd.lor_scene_id = s.lor_scene_id
 AND sd.display_id = d.display_id
WHERE c.lor_reconciliation_run_id = 1
  AND c.initial_resolution_state = 'AUTO_APPROVED'
  AND NOT c.is_blocking
  AND display_group.effective_resolution_state IN ('AUTO_APPROVED', 'APPROVED');

ROLLBACK;

/* Part B: atomic Cancel. */
BEGIN;

CALL ops.p_cancel_lor_reconciliation(
    1,
    'Rollback validation only: prove atomic cancellation and snapshot deletion.',
    'rollback-validation-15'
);

SELECT
    r.lor_reconciliation_run_id,
    r.import_run_id,
    r.status,
    r.validation_state,
    r.cancelled_at IS NOT NULL AS has_cancelled_at,
    r.cancellation_reason,
    NOT EXISTS (
        SELECT 1 FROM lor_snap.import_run AS ir
        WHERE ir.import_run_id = r.import_run_id
    ) AS captured_snapshot_deleted,
    count(DISTINCT a.lor_reconciliation_action_id) FILTER (
        WHERE a.action_type = 'CANCEL_RECONCILIATION'
    ) AS cancellation_action_count,
    count(DISTINCT rr.lor_reconciliation_result_id) FILTER (
        WHERE rr.reason_code = 'CANCELLED_BEFORE_PROMOTION'
          AND rr.committed
    ) AS cancellation_result_count,
    'ROLLBACK REQUIRED'::text AS transaction_disposition
FROM ops.lor_reconciliation_run AS r
LEFT JOIN ops.lor_reconciliation_action AS a
  ON a.lor_reconciliation_run_id = r.lor_reconciliation_run_id
LEFT JOIN ops.lor_reconciliation_result AS rr
  ON rr.lor_reconciliation_run_id = r.lor_reconciliation_run_id
WHERE r.lor_reconciliation_run_id = 1
GROUP BY r.lor_reconciliation_run_id;

ROLLBACK;
