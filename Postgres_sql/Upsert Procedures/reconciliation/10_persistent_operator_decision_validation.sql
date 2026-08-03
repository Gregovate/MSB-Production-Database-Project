/* ============================================================================
Schema: ops / lor_snap / ref
Object: Persistent reconciliation operator-decision validation
Filename: 10_persistent_operator_decision_validation.sql
Type: Controlled persistence validation; no production writes
Owner: msbadmin

Purpose:
  Start or reopen the persistent reconciliation for the automatically captured
  current V7 ingest and return the complete validation evidence needed before
  any promotion procedure is implemented or enabled.

Safety:
  - Persists only ops reconciliation working state.
  - Does not call P1, P2, P3, or P4.
  - Does not modify ref or lor_snap data.
  - Repeated execution is idempotent for the same captured ingest.

Expected current validation characteristics are data results, not coded rules:
  - one persisted run for the captured import;
  - candidate counts agree with read-only diagnostics 03/04/08/09;
  - every identity dependency component has one shared logical group;
  - no atomic group can be decided through one candidate row;
  - projected exact matches allow optional DEFER without requiring approval;
  - all required decisions are unresolved until an action is recorded.

Revision history:
  2026-08-02  GAL / OpenAI  Initial persistent decision-layer validation.
============================================================================ */

WITH started AS (
    SELECT ops.f_start_lor_display_reconciliation(
        '10_persistent_operator_decision_validation.sql'
    ) AS lor_reconciliation_run_id
)
SELECT
    rr.*
FROM ops.v_lor_reconciliation_run_review AS rr
JOIN started AS s
  ON s.lor_reconciliation_run_id = rr.lor_reconciliation_run_id;

/* Operator-facing groups that require a decision or permit DEFER. */
SELECT
    gr.lor_reconciliation_run_id,
    gr.import_run_id,
    gr.lor_reconciliation_group_id,
    gr.logical_group_key,
    gr.group_kind,
    gr.member_count,
    gr.requires_atomic_decision,
    gr.decision_required,
    gr.effective_resolution_state,
    gr.allowed_action_types,
    gr.operator_message,
    gr.effective_action_type,
    gr.effective_reason
FROM ops.v_lor_reconciliation_group_review AS gr
JOIN lor_snap.v_current_run AS cr
  ON cr.import_run_id = gr.import_run_id
WHERE gr.decision_required
   OR cardinality(gr.allowed_action_types) > 0
ORDER BY
    gr.requires_atomic_decision DESC,
    gr.decision_required DESC,
    gr.logical_group_key;

/* Complete member detail for every nonautomatic or changed display group. */
SELECT *
FROM ops.v_lor_reconciliation_operator_display_review AS review
JOIN lor_snap.v_current_run AS cr
  ON cr.import_run_id = review.import_run_id
ORDER BY
    review.requires_atomic_decision DESC,
    review.logical_group_key,
    review.current_display_name NULLS LAST,
    review.proposed_display_name NULLS LAST;

/* Hard validation assertions returned as one row. */
WITH current_persisted_run AS (
    SELECT r.lor_reconciliation_run_id, r.import_run_id, r.status
    FROM ops.lor_reconciliation_run AS r
    JOIN lor_snap.v_current_run AS cr
      ON cr.import_run_id = r.import_run_id
),
group_checks AS (
    SELECT
        count(*) FILTER (
            WHERE g.member_count <> actual.actual_member_count
        ) AS stored_member_count_mismatches,
        count(*) FILTER (
            WHERE g.requires_atomic_decision
              AND (
                  g.group_kind <> 'IDENTITY_COMPONENT'
                  OR g.member_count <= 1
                  OR NOT g.decision_required
                  OR NOT (
                      ARRAY['REASSOCIATE_DISPLAY', 'CORRECT_SOURCE_REQUIRED', 'DEFER']::text[]
                      <@ g.allowed_action_types
                  )
              )
        ) AS invalid_atomic_groups
    FROM current_persisted_run AS r
    JOIN ops.lor_reconciliation_group AS g
      ON g.lor_reconciliation_run_id = r.lor_reconciliation_run_id
    CROSS JOIN LATERAL (
        SELECT count(*)::integer AS actual_member_count
        FROM ops.lor_reconciliation_display_candidate AS c
        WHERE c.lor_reconciliation_group_id = g.lor_reconciliation_group_id
    ) AS actual
),
candidate_checks AS (
    SELECT
        count(*) FILTER (
            WHERE c.import_run_id <> r.import_run_id
        ) AS wrong_import_scope,
        count(*) FILTER (
            WHERE c.source_prop_id IS NOT NULL
              AND NOT EXISTS (
                  SELECT 1
                  FROM lor_snap.props AS p
                  WHERE p.import_run_id = c.import_run_id
                    AND p.prop_id = c.source_prop_id
                    AND p.raw_prop_id = c.lor_prop_id
              )
        ) AS missing_exact_source_rows,
        count(*) FILTER (
            WHERE c.candidate_class = 'EXCLUDED_NONPHYSICAL'
              AND c.initial_resolution_state <> 'EXCLUDED'
        ) AS invalid_nonphysical_states,
        count(*) FILTER (
            WHERE c.classification_code = 'EXACT_MATCH'
              AND cardinality(c.changed_fields) > 0
              AND (
                  c.decision_required
                  OR c.initial_resolution_state <> 'AUTO_APPROVED'
                  OR NOT ('DEFER' = ANY(c.allowed_action_types))
              )
        ) AS invalid_exact_change_states
    FROM current_persisted_run AS r
    JOIN ops.lor_reconciliation_display_candidate AS c
      ON c.lor_reconciliation_run_id = r.lor_reconciliation_run_id
)
SELECT
    r.status AS reconciliation_status,
    CASE WHEN r.status IN ('AWAITING_DECISIONS', 'READY_TO_FINISH')
         THEN 0 ELSE 1 END AS invalid_run_status,
    gc.stored_member_count_mismatches,
    gc.invalid_atomic_groups,
    cc.wrong_import_scope,
    cc.missing_exact_source_rows,
    cc.invalid_nonphysical_states,
    cc.invalid_exact_change_states,
    CASE
        WHEN r.status IN ('AWAITING_DECISIONS', 'READY_TO_FINISH')
         AND EXISTS (
             SELECT 1
             FROM ops.lor_reconciliation_display_candidate AS c
             WHERE c.lor_reconciliation_run_id = r.lor_reconciliation_run_id
         )
         AND gc.stored_member_count_mismatches = 0
         AND gc.invalid_atomic_groups = 0
         AND cc.wrong_import_scope = 0
         AND cc.missing_exact_source_rows = 0
         AND cc.invalid_nonphysical_states = 0
         AND cc.invalid_exact_change_states = 0
            THEN 'PASS'
        ELSE 'FAIL'
    END AS decision_layer_validation
FROM group_checks AS gc
CROSS JOIN candidate_checks AS cc
CROSS JOIN current_persisted_run AS r;

/*
Rollback-only action tests are intentionally separate from normal validation.
Use actual IDs returned above; the transaction guarantees no decision remains.

BEGIN;

SELECT ops.f_record_lor_reconciliation_action(
    p_lor_reconciliation_run_id => :run_id,
    p_lor_reconciliation_group_id => :group_id,
    p_action_type => 'DEFER',
    p_reason => 'Validation only; rolled back',
    p_acted_by_application => 'DBeaver rollback validation'
);

SELECT *
FROM ops.v_lor_reconciliation_group_review
WHERE lor_reconciliation_group_id = :group_id;

ROLLBACK;

For REASSOCIATE_DISPLAY, p_reassociation_map must be a JSON object whose keys
are every candidate ID in the atomic group and whose values are the selected
permanent display IDs, for example:

    jsonb_build_object(
        :candidate_id_1::text, :display_id_1,
        :candidate_id_2::text, :display_id_2
    )

An incomplete map, duplicate target, outside candidate, or outside display
identity is rejected before any action is recorded.
*/
