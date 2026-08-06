/* ============================================================================
Object:       Safe exact-name UUID relink validation
Filename:     24_safe_uuid_relink_validation.sql
Type:         Read-only post-install validation

Purpose:
  Confirm that migration 0028 removes qualifying UUID_CHANGED_SAME_NAME rows
  from operator review by appending an automatic UPDATE_LOR_LINK action while
  retaining the original frozen candidate and group unchanged.

Revision history:
  2026-08-05  GAL / OpenAI  v2: Validate the append-only automatic action.
  2026-08-05  GAL / OpenAI  Initial validation.
============================================================================ */

/* Validation 1: the automatic policy trigger is installed and enabled. */
SELECT
    to_regprocedure('ops.trg_auto_approve_safe_uuid_relink()') IS NOT NULL
        AS has_trigger_function,
    EXISTS (
        SELECT 1
        FROM pg_trigger AS t
        JOIN pg_class AS c ON c.oid = t.tgrelid
        JOIN pg_namespace AS n ON n.oid = c.relnamespace
        WHERE n.nspname = 'ops'
          AND c.relname = 'lor_reconciliation_display_candidate'
          AND t.tgname = 'trg_auto_approve_safe_uuid_relink'
          AND t.tgenabled <> 'D'
          AND NOT t.tgisinternal
    ) AS has_enabled_candidate_trigger;

/*
  Validation 2: no qualifying exact-name UUID relink remains decision-required
  in an open run. A result greater than zero fails the migration contract.
*/
SELECT count(*) AS invalid_uuid_relink_review_count
FROM ops.lor_reconciliation_display_candidate AS c
JOIN ops.lor_reconciliation_group AS g
  ON g.lor_reconciliation_group_id = c.lor_reconciliation_group_id
JOIN ops.lor_reconciliation_run AS r
  ON r.lor_reconciliation_run_id = c.lor_reconciliation_run_id
WHERE c.classification_code = 'UUID_CHANGED_SAME_NAME'
  AND g.group_kind = 'SINGLE_CANDIDATE'
  AND g.member_count = 1
  AND NOT g.requires_atomic_decision
  AND r.status IN ('PREFLIGHT', 'AWAITING_DECISIONS', 'READY_TO_FINISH')
  AND NOT EXISTS (
      SELECT 1
      FROM ops.v_lor_reconciliation_group_review AS gr
      WHERE gr.lor_reconciliation_group_id = c.lor_reconciliation_group_id
        AND gr.effective_action_type = 'UPDATE_LOR_LINK'
        AND gr.acted_by_application =
            'reconciliation:auto-safe-uuid-relink'
  );

/* Validation 3: show immutable evidence and its effective automatic action. */
SELECT
    c.lor_reconciliation_run_id,
    c.import_run_id,
    c.display_id,
    c.current_display_name,
    c.proposed_display_name,
    c.lor_prop_id AS proposed_lor_prop_id,
    c.classification_code,
    c.initial_resolution_state,
    c.decision_required,
    c.is_blocking,
    g.logical_group_key,
    g.decision_required AS group_decision_required,
    g.allowed_action_types AS group_allowed_actions,
    gr.effective_action_type,
    gr.effective_resolution_state,
    gr.effective_reason,
    gr.acted_by_application
FROM ops.lor_reconciliation_display_candidate AS c
JOIN ops.lor_reconciliation_group AS g
  ON g.lor_reconciliation_group_id = c.lor_reconciliation_group_id
JOIN ops.lor_reconciliation_run AS r
  ON r.lor_reconciliation_run_id = c.lor_reconciliation_run_id
JOIN ops.v_lor_reconciliation_group_review AS gr
  ON gr.lor_reconciliation_group_id = c.lor_reconciliation_group_id
WHERE c.classification_code = 'UUID_CHANGED_SAME_NAME'
  AND r.status IN ('PREFLIGHT', 'AWAITING_DECISIONS', 'READY_TO_FINISH')
ORDER BY c.lor_reconciliation_run_id, c.display_id;

/* Validation 4: list exactly what the operator application will still load. */
SELECT
    gr.lor_reconciliation_run_id,
    gr.import_run_id,
    gr.entity_type,
    gr.logical_group_key,
    gr.decision_required,
    gr.effective_resolution_state,
    gr.allowed_action_types,
    gr.operator_message
FROM ops.v_lor_reconciliation_group_review AS gr
JOIN ops.lor_reconciliation_run AS r
  ON r.lor_reconciliation_run_id = gr.lor_reconciliation_run_id
WHERE r.status IN ('AWAITING_DECISIONS', 'READY_TO_FINISH')
  AND (gr.decision_required OR gr.effective_action_id IS NOT NULL)
ORDER BY gr.lor_reconciliation_run_id, gr.logical_group_key;
