/* ============================================================================
Validation: Decision readiness synchronization

Purpose:
  Prove that every saved reconciliation action refreshes effective counters and
  the READY_TO_FINISH/AWAITING_DECISIONS lifecycle without promotion.

Safety:
  Read-only. Does not alter reconciliation or production data.
============================================================================ */

DO $validation$
DECLARE
    v_sync_definition text;
BEGIN
    IF to_regprocedure(
        'ops.f_sync_lor_reconciliation_effective_counters(bigint)'
    ) IS NULL OR to_regprocedure(
        'ops.f_sync_lor_reconciliation_readiness_after_action()'
    ) IS NULL THEN
        RAISE EXCEPTION
            'Decision readiness synchronization functions are incomplete';
    END IF;

    IF NOT EXISTS (
        SELECT 1
        FROM pg_trigger AS t
        JOIN pg_class AS c ON c.oid = t.tgrelid
        JOIN pg_namespace AS n ON n.oid = c.relnamespace
        WHERE n.nspname = 'ops'
          AND c.relname = 'lor_reconciliation_action'
          AND t.tgname =
              'trg_sync_lor_reconciliation_readiness_after_action'
          AND NOT t.tgisinternal
    ) THEN
        RAISE EXCEPTION 'Decision readiness trigger is not installed';
    END IF;

    SELECT pg_get_functiondef(
        'ops.f_sync_lor_reconciliation_effective_counters(bigint)'::regprocedure
    ) INTO v_sync_definition;

    IF v_sync_definition NOT ILIKE '%effective_resolution_state%'
       OR v_sync_definition NOT ILIKE '%READY_TO_FINISH%'
       OR v_sync_definition ~* 'p[1234]_promote' THEN
        RAISE EXCEPTION
            'Effective counter sync does not enforce the safe readiness contract';
    END IF;

    IF EXISTS (
        SELECT 1
        FROM ops.lor_reconciliation_run AS r
        CROSS JOIN LATERAL (
            SELECT
                count(*) FILTER (
                    WHERE gr.effective_resolution_state = 'UNRESOLVED'
                )::integer AS unresolved_count,
                count(*) FILTER (
                    WHERE gr.effective_resolution_state = 'DEFERRED'
                )::integer AS deferred_count,
                count(*) FILTER (
                    WHERE gr.effective_resolution_state = 'BLOCKED'
                )::integer AS blocked_count
            FROM ops.v_lor_reconciliation_group_review AS gr
            WHERE gr.lor_reconciliation_run_id =
                r.lor_reconciliation_run_id
        ) AS ec
        WHERE r.status IN ('AWAITING_DECISIONS', 'READY_TO_FINISH')
          AND (
              r.unresolved_count <> ec.unresolved_count
              OR r.deferred_count <> ec.deferred_count
              OR r.blocked_count <> ec.blocked_count
              OR r.status <> CASE
                  WHEN ec.unresolved_count = 0
                   AND ec.blocked_count = 0
                      THEN 'READY_TO_FINISH'
                  ELSE 'AWAITING_DECISIONS'
              END
          )
    ) THEN
        RAISE EXCEPTION
            'An open run lifecycle disagrees with its effective decisions';
    END IF;
END;
$validation$;

SELECT
    'PASS'::text AS validation_status,
    'Every saved decision refreshes counters and final-review readiness.'::text
        AS validation_detail;
