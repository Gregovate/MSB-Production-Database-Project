/* ============================================================================
File:       0026_sync_effective_reconciliation_counters.sql
Migration:  Synchronize reconciliation counters from effective group state

Purpose:
  Make run-level exception counters reflect current effective logical-group
  state. Frozen candidate flags remain immutable audit evidence and do not
  remain current exceptions after an operator resolves their group.

Run 3 recovery:
  Installation safely resynchronizes every run currently in REPORTING. It does
  not execute Finish, P1, P2, P3, P4, or report publication.

Revision History:
  2026-08-03  GAL / OpenAI  Initial effective-state counter synchronization.
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
        WHERE gr.lor_reconciliation_run_id = p_lor_reconciliation_run_id
    ), updated AS (
        UPDATE ops.lor_reconciliation_run AS r
           SET unresolved_count = ec.unresolved_count,
               deferred_count = ec.deferred_count,
               blocked_count = ec.blocked_count
          FROM effective_counts AS ec
         WHERE r.lor_reconciliation_run_id = p_lor_reconciliation_run_id
        RETURNING r.unresolved_count, r.deferred_count, r.blocked_count
    )
    SELECT u.unresolved_count, u.deferred_count, u.blocked_count
    FROM updated AS u;
END;
$function$;

COMMENT ON FUNCTION ops.f_sync_lor_reconciliation_effective_counters(bigint) IS
'Synchronizes one reconciliation run exception counters exclusively from effective logical-group resolution states.';

REVOKE EXECUTE ON FUNCTION
    ops.f_sync_lor_reconciliation_effective_counters(bigint) FROM PUBLIC;

CREATE OR REPLACE FUNCTION ops.f_sync_lor_reconciliation_counters_on_reporting()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, ops
AS $trigger$
BEGIN
    PERFORM *
    FROM ops.f_sync_lor_reconciliation_effective_counters(
        NEW.lor_reconciliation_run_id
    );
    RETURN NEW;
END;
$trigger$;

DROP TRIGGER IF EXISTS trg_sync_lor_reconciliation_counters_on_reporting
    ON ops.lor_reconciliation_run;

CREATE TRIGGER trg_sync_lor_reconciliation_counters_on_reporting
AFTER UPDATE OF status ON ops.lor_reconciliation_run
FOR EACH ROW
WHEN (NEW.status = 'REPORTING' AND OLD.status IS DISTINCT FROM NEW.status)
EXECUTE FUNCTION ops.f_sync_lor_reconciliation_counters_on_reporting();

/* Repair runs already waiting for publication, including retained Run 3. */
DO $migration$
DECLARE
    v_run_id bigint;
BEGIN
    FOR v_run_id IN
        SELECT r.lor_reconciliation_run_id
        FROM ops.lor_reconciliation_run AS r
        WHERE r.status = 'REPORTING'
        ORDER BY r.lor_reconciliation_run_id
    LOOP
        PERFORM *
        FROM ops.f_sync_lor_reconciliation_effective_counters(v_run_id);
    END LOOP;
END;
$migration$;

COMMIT;

SELECT
    '2026-08-03-effective-reconciliation-counters-v1'::text AS installed_revision,
    to_regprocedure(
        'ops.f_sync_lor_reconciliation_effective_counters(bigint)'
    ) IS NOT NULL AS has_counter_sync_function,
    EXISTS (
        SELECT 1
        FROM pg_trigger AS t
        JOIN pg_class AS c ON c.oid = t.tgrelid
        JOIN pg_namespace AS n ON n.oid = c.relnamespace
        WHERE n.nspname = 'ops'
          AND c.relname = 'lor_reconciliation_run'
          AND t.tgname = 'trg_sync_lor_reconciliation_counters_on_reporting'
          AND NOT t.tgisinternal
    ) AS has_reporting_sync_trigger;
