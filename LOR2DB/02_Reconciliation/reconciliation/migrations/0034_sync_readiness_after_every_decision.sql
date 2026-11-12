/* ============================================================================
File:       0034_sync_readiness_after_every_decision.sql
Migration:  Synchronize run readiness after every recorded decision

Purpose:
  Keep the durable run counters and lifecycle status aligned with the effective
  logical-group decisions.  Every decision recorder writes to
  ops.lor_reconciliation_action, so one AFTER INSERT trigger closes the gap
  between a visibly saved decision and READY_TO_FINISH.

Safety:
  - Does not call Finish or any P1-P4 promotion procedure.
  - Does not change production Stage, Display, Scene, or Scene/Display rows.
  - Repairs only open decision-state runs from their persisted effective state.

Revision History:
  2026-08-17  GAL / OpenAI  Initial readiness synchronization.
============================================================================ */

BEGIN;

CREATE OR REPLACE FUNCTION ops.f_sync_lor_reconciliation_effective_counters(
    p_lor_reconciliation_run_id bigint
)
RETURNS TABLE (
    unresolved_count integer,
    deferred_count integer,
    blocked_count integer
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, ops
AS $function$
BEGIN
    IF NOT EXISTS (
        SELECT 1
        FROM ops.lor_reconciliation_run AS r
        WHERE r.lor_reconciliation_run_id = p_lor_reconciliation_run_id
    ) THEN
        RAISE EXCEPTION 'Reconciliation run % does not exist',
            p_lor_reconciliation_run_id;
    END IF;

    RETURN QUERY
    WITH effective_counts AS (
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
            p_lor_reconciliation_run_id
    ), updated AS (
        UPDATE ops.lor_reconciliation_run AS r
           SET unresolved_count = ec.unresolved_count,
               deferred_count = ec.deferred_count,
               blocked_count = ec.blocked_count,
               status = CASE
                   WHEN r.status IN (
                       'AWAITING_DECISIONS', 'READY_TO_FINISH'
                   ) THEN CASE
                       WHEN ec.unresolved_count = 0
                        AND ec.blocked_count = 0
                           THEN 'READY_TO_FINISH'
                       ELSE 'AWAITING_DECISIONS'
                   END
                   ELSE r.status
               END,
               resumed_at = CASE
                   WHEN r.status IN (
                       'AWAITING_DECISIONS', 'READY_TO_FINISH'
                   )
                    AND ec.unresolved_count = 0
                    AND ec.blocked_count = 0
                       THEN now()
                   ELSE r.resumed_at
               END,
               paused_at = CASE
                   WHEN r.status IN (
                       'AWAITING_DECISIONS', 'READY_TO_FINISH'
                   )
                    AND ec.unresolved_count = 0
                    AND ec.blocked_count = 0
                       THEN NULL
                   WHEN r.status IN (
                       'AWAITING_DECISIONS', 'READY_TO_FINISH'
                   ) THEN coalesce(r.paused_at, now())
                   ELSE r.paused_at
               END
          FROM effective_counts AS ec
         WHERE r.lor_reconciliation_run_id =
            p_lor_reconciliation_run_id
        RETURNING
            r.unresolved_count,
            r.deferred_count,
            r.blocked_count
    )
    SELECT
        u.unresolved_count,
        u.deferred_count,
        u.blocked_count
    FROM updated AS u;
END;
$function$;

COMMENT ON FUNCTION
    ops.f_sync_lor_reconciliation_effective_counters(bigint) IS
'Synchronizes one run counters and decision-state readiness from effective logical-group state; never performs promotion.';

REVOKE EXECUTE ON FUNCTION
    ops.f_sync_lor_reconciliation_effective_counters(bigint) FROM PUBLIC;

CREATE OR REPLACE FUNCTION
    ops.f_sync_lor_reconciliation_readiness_after_action()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, ops
AS $trigger$
DECLARE
    v_status text;
BEGIN
    SELECT r.status
      INTO v_status
    FROM ops.lor_reconciliation_run AS r
    WHERE r.lor_reconciliation_run_id = NEW.lor_reconciliation_run_id;

    /* PREFLIGHT can insert automatic actions while groups are still forming. */
    IF v_status IN ('AWAITING_DECISIONS', 'READY_TO_FINISH') THEN
        PERFORM *
        FROM ops.f_sync_lor_reconciliation_effective_counters(
            NEW.lor_reconciliation_run_id
        );
    END IF;

    RETURN NEW;
END;
$trigger$;

COMMENT ON FUNCTION
    ops.f_sync_lor_reconciliation_readiness_after_action() IS
'Refreshes an open run lifecycle after any persisted operator or automatic action; skips PREFLIGHT while groups are still forming.';

REVOKE EXECUTE ON FUNCTION
    ops.f_sync_lor_reconciliation_readiness_after_action() FROM PUBLIC;

DROP TRIGGER IF EXISTS trg_sync_lor_reconciliation_readiness_after_action
    ON ops.lor_reconciliation_action;

CREATE TRIGGER trg_sync_lor_reconciliation_readiness_after_action
AFTER INSERT ON ops.lor_reconciliation_action
FOR EACH ROW
EXECUTE FUNCTION
    ops.f_sync_lor_reconciliation_readiness_after_action();

/* Repair any open run whose saved decisions and lifecycle state diverged. */
DO $migration$
DECLARE
    v_run_id bigint;
BEGIN
    FOR v_run_id IN
        SELECT r.lor_reconciliation_run_id
        FROM ops.lor_reconciliation_run AS r
        WHERE r.status IN ('AWAITING_DECISIONS', 'READY_TO_FINISH')
        ORDER BY r.lor_reconciliation_run_id
    LOOP
        PERFORM *
        FROM ops.f_sync_lor_reconciliation_effective_counters(v_run_id);
    END LOOP;
END;
$migration$;

COMMIT;

SELECT
    '2026-08-17-decision-readiness-sync-v1'::text AS installed_revision,
    to_regprocedure(
        'ops.f_sync_lor_reconciliation_readiness_after_action()'
    ) IS NOT NULL AS readiness_trigger_function_installed,
    EXISTS (
        SELECT 1
        FROM pg_trigger AS t
        JOIN pg_class AS c ON c.oid = t.tgrelid
        JOIN pg_namespace AS n ON n.oid = c.relnamespace
        WHERE n.nspname = 'ops'
          AND c.relname = 'lor_reconciliation_action'
          AND t.tgname =
              'trg_sync_lor_reconciliation_readiness_after_action'
          AND NOT t.tgisinternal
    ) AS readiness_trigger_installed;
