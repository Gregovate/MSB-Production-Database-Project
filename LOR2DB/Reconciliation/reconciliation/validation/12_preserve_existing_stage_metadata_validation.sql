/* ============================================================================
Object:       Preserve-existing-stage-metadata validation
Repository:   LOR2DB/Reconciliation/reconciliation/validation/
File:         12_preserve_existing_stage_metadata_validation.sql
Type:         Rollback-only decision and projected-P1 validation

Purpose:
  Prove that eligible multi-preview stage groups expose and accept the explicit
  preservation action, remain approved for binding promotion, and are excluded
  from permanent stage metadata promotion.

Safety:
  Every action and counter change made by this script is rolled back.
  The script does not call P1 or P2 and does not modify production ref data.

Revision history:
  2026-08-03  GAL / OpenAI  Initial rollback-only preservation validation.
============================================================================ */

BEGIN;

/* Result 1: eligible unresolved stage groups and their complete membership. */
SELECT
    gr.lor_reconciliation_run_id,
    gr.import_run_id,
    gr.lor_reconciliation_group_id,
    gr.logical_group_key,
    gr.member_count,
    gr.effective_resolution_state,
    gr.allowed_action_types,
    count(c.*)::integer AS actual_candidate_count,
    count(DISTINCT c.resolved_stage_id)::integer AS resolved_stage_count,
    count(DISTINCT c.proposed_stage_name)
        FILTER (WHERE c.metadata_authoritative)::integer
        AS authoritative_name_count
FROM ops.v_lor_reconciliation_group_review AS gr
JOIN ops.lor_reconciliation_stage_candidate AS c
  ON c.lor_reconciliation_group_id = gr.lor_reconciliation_group_id
JOIN lor_snap.v_current_run AS cr ON cr.import_run_id = gr.import_run_id
WHERE gr.entity_type = 'STAGE'
  AND gr.effective_resolution_state = 'UNRESOLVED'
  AND ops.f_stage_group_can_preserve_existing_metadata(
        gr.lor_reconciliation_group_id
      )
GROUP BY
    gr.lor_reconciliation_run_id,
    gr.import_run_id,
    gr.lor_reconciliation_group_id,
    gr.logical_group_key,
    gr.member_count,
    gr.effective_resolution_state,
    gr.allowed_action_types
ORDER BY gr.lor_reconciliation_group_id;

/* Fail before testing if the current run has no eligible group. */
DO $assert_eligible$
DECLARE
    v_eligible_count integer;
    v_missing_action_count integer;
BEGIN
    SELECT
        count(*)::integer,
        count(*) FILTER (
            WHERE NOT (
                'PRESERVE_EXISTING_STAGE_METADATA' =
                    ANY(gr.allowed_action_types)
            )
        )::integer
      INTO v_eligible_count, v_missing_action_count
    FROM ops.v_lor_reconciliation_group_review AS gr
    JOIN lor_snap.v_current_run AS cr ON cr.import_run_id = gr.import_run_id
    WHERE gr.entity_type = 'STAGE'
      AND gr.effective_resolution_state = 'UNRESOLVED'
      AND ops.f_stage_group_can_preserve_existing_metadata(
            gr.lor_reconciliation_group_id
          );

    IF v_eligible_count = 0 THEN
        RAISE EXCEPTION
            'VALIDATION FAILED: no eligible unresolved multi-preview stage group exists';
    END IF;

    IF v_missing_action_count <> 0 THEN
        RAISE EXCEPTION
            'VALIDATION FAILED: % eligible groups do not expose the preservation action',
            v_missing_action_count;
    END IF;
END;
$assert_eligible$;

/* Record test decisions for every eligible current-run group. */
DO $record_test_actions$
DECLARE
    v_group record;
BEGIN
    FOR v_group IN
        SELECT
            gr.lor_reconciliation_run_id,
            gr.lor_reconciliation_group_id
        FROM ops.v_lor_reconciliation_group_review AS gr
        JOIN lor_snap.v_current_run AS cr
          ON cr.import_run_id = gr.import_run_id
        WHERE gr.entity_type = 'STAGE'
          AND gr.effective_resolution_state = 'UNRESOLVED'
          AND ops.f_stage_group_can_preserve_existing_metadata(
                gr.lor_reconciliation_group_id
              )
        ORDER BY gr.lor_reconciliation_group_id
    LOOP
        PERFORM ops.f_record_lor_stage_preserve_metadata_action(
            v_group.lor_reconciliation_run_id,
            v_group.lor_reconciliation_group_id,
            'Rollback validation: legitimate multi-preview stage; preserve permanent metadata and approve all frozen bindings.',
            'validation-12'
        );
    END LOOP;
END;
$record_test_actions$;

/* Result 2: test actions are effective and groups are approved. */
SELECT
    gr.lor_reconciliation_run_id,
    gr.lor_reconciliation_group_id,
    gr.logical_group_key,
    gr.member_count,
    gr.effective_action_type,
    gr.effective_resolution_state,
    gr.effective_reason
FROM ops.v_lor_reconciliation_group_review AS gr
JOIN lor_snap.v_current_run AS cr ON cr.import_run_id = gr.import_run_id
WHERE gr.entity_type = 'STAGE'
  AND gr.effective_action_type = 'PRESERVE_EXISTING_STAGE_METADATA'
ORDER BY gr.lor_reconciliation_group_id;

/*
  Result 3: projected P1 behavior.
  - preserved_metadata_candidate_count must be 0;
  - approved_binding_candidate_count must equal all candidates in the preserved
    groups;
  - incomplete_preserved_group_count must be 0.
*/
WITH preserved_groups AS (
    SELECT gr.lor_reconciliation_group_id
    FROM ops.v_lor_reconciliation_group_review AS gr
    JOIN lor_snap.v_current_run AS cr ON cr.import_run_id = gr.import_run_id
    WHERE gr.entity_type = 'STAGE'
      AND gr.effective_action_type =
            'PRESERVE_EXISTING_STAGE_METADATA'
      AND gr.effective_resolution_state = 'APPROVED'
),
checks AS (
    SELECT
        (
            SELECT count(*)
            FROM ops.lor_reconciliation_stage_candidate AS c
            JOIN ops.v_lor_reconciliation_group_review AS gr
              ON gr.lor_reconciliation_group_id =
                    c.lor_reconciliation_group_id
            WHERE c.lor_reconciliation_group_id IN (
                    SELECT lor_reconciliation_group_id
                    FROM preserved_groups
                  )
              AND gr.effective_resolution_state IN (
                    'AUTO_APPROVED', 'APPROVED'
                  )
              AND gr.effective_action_type IS DISTINCT FROM
                    'PRESERVE_EXISTING_STAGE_METADATA'
        )::integer AS preserved_metadata_candidate_count,
        (
            SELECT count(*)
            FROM ops.lor_reconciliation_stage_candidate AS c
            JOIN ops.v_lor_reconciliation_group_review AS gr
              ON gr.lor_reconciliation_group_id =
                    c.lor_reconciliation_group_id
            WHERE c.lor_reconciliation_group_id IN (
                    SELECT lor_reconciliation_group_id
                    FROM preserved_groups
                  )
              AND c.resolved_stage_id IS NOT NULL
              AND gr.effective_resolution_state IN (
                    'AUTO_APPROVED', 'APPROVED'
                  )
        )::integer AS approved_binding_candidate_count,
        (
            SELECT count(*)
            FROM ops.lor_reconciliation_group AS g
            WHERE g.lor_reconciliation_group_id IN (
                    SELECT lor_reconciliation_group_id
                    FROM preserved_groups
                  )
              AND g.member_count <> (
                    SELECT count(*)
                    FROM ops.lor_reconciliation_stage_candidate AS c
                    WHERE c.lor_reconciliation_group_id =
                            g.lor_reconciliation_group_id
              )
        )::integer AS incomplete_preserved_group_count
)
SELECT
    *,
    CASE
        WHEN preserved_metadata_candidate_count = 0
         AND approved_binding_candidate_count > 0
         AND incomplete_preserved_group_count = 0
        THEN 'PASS'
        ELSE 'FAIL'
    END AS projected_p1_preservation_validation
FROM checks;

/* Prove the stage-only function rejects a display group. */
DO $reject_wrong_entity$
DECLARE
    v_run_id bigint;
    v_display_group_id bigint;
BEGIN
    SELECT
        gr.lor_reconciliation_run_id,
        gr.lor_reconciliation_group_id
      INTO v_run_id, v_display_group_id
    FROM ops.v_lor_reconciliation_group_review AS gr
    JOIN lor_snap.v_current_run AS cr ON cr.import_run_id = gr.import_run_id
    WHERE gr.entity_type = 'DISPLAY'
    ORDER BY gr.lor_reconciliation_group_id
    LIMIT 1;

    IF v_display_group_id IS NULL THEN
        RAISE EXCEPTION
            'VALIDATION FAILED: no display group exists for wrong-entity test';
    END IF;

    BEGIN
        PERFORM ops.f_record_lor_stage_preserve_metadata_action(
            v_run_id,
            v_display_group_id,
            'This action must be rejected.',
            'validation-12'
        );
        RAISE EXCEPTION
            'VALIDATION FAILED: stage preservation accepted display group %',
            v_display_group_id;
    EXCEPTION
        WHEN OTHERS THEN
            IF SQLERRM NOT LIKE 'Stage group % does not belong to reconciliation run %'
               AND SQLERRM NOT LIKE 'Stage group % is not eligible to preserve existing metadata'
            THEN
                RAISE;
            END IF;
    END;
END;
$reject_wrong_entity$;

/* Result 4: action counts and durable run counters inside the test transaction. */
SELECT
    r.lor_reconciliation_run_id,
    r.import_run_id,
    r.status,
    count(DISTINCT a.lor_reconciliation_group_id) FILTER (
        WHERE a.action_type = 'PRESERVE_EXISTING_STAGE_METADATA'
          AND a.acted_by_application = 'validation-12'
    )::integer AS test_preservation_action_count,
    r.unresolved_count,
    r.deferred_count,
    r.blocked_count,
    CASE
        WHEN count(DISTINCT a.lor_reconciliation_group_id) FILTER (
                WHERE a.action_type =
                        'PRESERVE_EXISTING_STAGE_METADATA'
                  AND a.acted_by_application = 'validation-12'
             ) > 0
         AND r.deferred_count = 0
         AND r.blocked_count = 0
        THEN 'PASS'
        ELSE 'FAIL'
    END AS action_and_counter_validation
FROM ops.lor_reconciliation_run AS r
JOIN lor_snap.v_current_run AS cr ON cr.import_run_id = r.import_run_id
LEFT JOIN ops.lor_reconciliation_action AS a
  ON a.lor_reconciliation_run_id = r.lor_reconciliation_run_id
GROUP BY
    r.lor_reconciliation_run_id,
    r.import_run_id,
    r.status,
    r.unresolved_count,
    r.deferred_count,
    r.blocked_count;

ROLLBACK;
