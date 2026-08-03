/* ============================================================================
Object:       Reconciliation-safe P1 stage validation
Repository:   Postgres_sql/Upsert Procedures/reconciliation/
File:         11_reconciliation_safe_p1_stage_validation.sql
Type:         Read-only validation plus rollback-only negative gate test

Purpose:
  Validate the installed 0015 stage candidate/binding contract against the
  captured reconciliation run. The transaction proves P1 cannot run while the
  reconciliation still has unresolved decisions.

Safety:
  The script ends with ROLLBACK. It does not resolve an operator decision and
  does not permit or perform a committed P1 production write.

Revision history:
  2026-08-02  GAL / OpenAI  Initial structural and gate validation.
============================================================================ */

BEGIN;

/* Result 1: run and frozen-stage population summary. */
SELECT
    r.lor_reconciliation_run_id,
    r.import_run_id,
    r.status,
    count(DISTINCT g.lor_reconciliation_group_id)::integer AS stage_group_count,
    count(c.*)::integer AS stage_candidate_count,
    count(DISTINCT g.lor_reconciliation_group_id) FILTER (
        WHERE gr.effective_resolution_state = 'AUTO_APPROVED'
    )::integer AS auto_approved_stage_group_count,
    count(DISTINCT g.lor_reconciliation_group_id) FILTER (
        WHERE gr.effective_resolution_state = 'UNRESOLVED'
    )::integer AS unresolved_stage_group_count,
    count(DISTINCT g.lor_reconciliation_group_id) FILTER (
        WHERE gr.effective_resolution_state = 'DEFERRED'
    )::integer AS deferred_stage_group_count
FROM ops.lor_reconciliation_run AS r
LEFT JOIN ops.lor_reconciliation_group AS g
  ON g.lor_reconciliation_run_id = r.lor_reconciliation_run_id
 AND g.entity_type = 'STAGE'
LEFT JOIN ops.v_lor_reconciliation_group_review AS gr
  ON gr.lor_reconciliation_group_id = g.lor_reconciliation_group_id
LEFT JOIN ops.lor_reconciliation_stage_candidate AS c
  ON c.lor_reconciliation_group_id = g.lor_reconciliation_group_id
WHERE r.import_run_id = (SELECT import_run_id FROM lor_snap.v_current_run)
GROUP BY r.lor_reconciliation_run_id, r.import_run_id, r.status;

/* Result 2: rows needing operator attention or producing a stage/binding change. */
SELECT *
FROM ops.v_lor_reconciliation_operator_stage_review
WHERE import_run_id = (SELECT import_run_id FROM lor_snap.v_current_run)
ORDER BY
    effective_resolution_state,
    proposed_stage_key,
    binding_type,
    preview_id,
    scene_id NULLS FIRST;

/* Result 3: database-wide structural assertions. */
WITH current_reconciliation AS (
    SELECT r.lor_reconciliation_run_id, r.import_run_id
    FROM ops.lor_reconciliation_run AS r
    JOIN lor_snap.v_current_run AS cr
      ON cr.import_run_id = r.import_run_id
),
checks AS (
    SELECT
        cr.lor_reconciliation_run_id,
        cr.import_run_id,
        (
            SELECT count(*)
            FROM ops.lor_reconciliation_stage_candidate AS c
            WHERE c.lor_reconciliation_run_id = cr.lor_reconciliation_run_id
              AND c.import_run_id <> cr.import_run_id
        ) AS wrong_import_scope,
        (
            SELECT count(*)
            FROM ops.lor_reconciliation_group AS g
            LEFT JOIN (
                SELECT lor_reconciliation_group_id, count(*)::integer AS actual_count
                FROM ops.lor_reconciliation_stage_candidate
                GROUP BY lor_reconciliation_group_id
            ) AS x ON x.lor_reconciliation_group_id = g.lor_reconciliation_group_id
            WHERE g.lor_reconciliation_run_id = cr.lor_reconciliation_run_id
              AND g.entity_type = 'STAGE'
              AND g.member_count <> coalesce(x.actual_count, 0)
        ) AS stored_member_count_mismatches,
        (
            SELECT count(*)
            FROM ops.lor_reconciliation_stage_candidate AS c
            WHERE c.lor_reconciliation_run_id = cr.lor_reconciliation_run_id
              AND c.source_stage_key !~ '^(0|[0-9]{1,2})[a-z]?$'
        ) AS noncanonical_stage_keys,
        (
            SELECT count(*)
            FROM ops.lor_reconciliation_stage_candidate AS c
            WHERE c.lor_reconciliation_run_id = cr.lor_reconciliation_run_id
              AND c.classification_code NOT IN (
                  'BINDING_STAGE_KEY_CONFLICT',
                  'NEW_STAGE_REQUIRES_AUTHORITATIVE_DECISION',
                  'BOOTSTRAP_BINDING_TO_EXISTING_STAGE',
                  'BOUND_STAGE_KEY_CHANGED',
                  'BOUND_STAGE_METADATA_CHANGED',
                  'EXACT_STAGE_BINDING'
              )
        ) AS invalid_classifications,
        (
            SELECT count(*)
            FROM ops.lor_reconciliation_stage_candidate AS c
            LEFT JOIN ref.stage AS s ON s.stage_id = c.resolved_stage_id
            WHERE c.lor_reconciliation_run_id = cr.lor_reconciliation_run_id
              AND c.resolved_stage_id IS NOT NULL
              AND s.stage_id IS NULL
        ) AS missing_resolved_stages
    FROM current_reconciliation AS cr
)
SELECT
    *,
    CASE WHEN wrong_import_scope = 0
              AND stored_member_count_mismatches = 0
              AND noncanonical_stage_keys = 0
              AND invalid_classifications = 0
              AND missing_resolved_stages = 0
         THEN 'PASS' ELSE 'FAIL' END AS stage_layer_validation
FROM checks;

/* Result 4: prove unresolved reconciliation state blocks P1. */
DO $test$
DECLARE
    v_run_id bigint;
BEGIN
    SELECT r.lor_reconciliation_run_id
      INTO v_run_id
    FROM ops.lor_reconciliation_run AS r
    JOIN lor_snap.v_current_run AS cr
      ON cr.import_run_id = r.import_run_id;

    BEGIN
        CALL ref.p1_promote_stage_from_reconciliation(v_run_id);
        RAISE EXCEPTION 'VALIDATION FAILED: P1 accepted a run that is not ready';
    EXCEPTION
        WHEN OTHERS THEN
            IF SQLERRM NOT LIKE 'Reconciliation run % is %, not ready for P1' THEN
                RAISE;
            END IF;
    END;
END;
$test$;

SELECT
    r.lor_reconciliation_run_id,
    r.status,
    count(*) FILTER (WHERE rr.committed)::integer AS committed_p1_result_count,
    'PASS'::text AS p1_not_ready_gate_validation
FROM ops.lor_reconciliation_run AS r
JOIN lor_snap.v_current_run AS cr ON cr.import_run_id = r.import_run_id
LEFT JOIN ops.lor_reconciliation_result AS rr
  ON rr.lor_reconciliation_run_id = r.lor_reconciliation_run_id
 AND rr.reason_code = 'P1_STAGE_METADATA'
GROUP BY r.lor_reconciliation_run_id, r.status;

ROLLBACK;
