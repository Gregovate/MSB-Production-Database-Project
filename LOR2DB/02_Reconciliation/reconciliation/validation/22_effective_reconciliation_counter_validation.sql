/* ============================================================================
Validation: Effective reconciliation exception counters

Purpose:
  Prove installed lifecycle counters use effective logical-group states, that
  REPORTING runs are synchronized, and that no promotion is performed.

Safety:
  Read-only. Does not alter reconciliation or production data.
============================================================================ */

WITH checks AS (
    SELECT
        'counter sync function installed'::text AS check_name,
        to_regprocedure(
            'ops.f_sync_lor_reconciliation_effective_counters(bigint)'
        ) IS NOT NULL AS passed
    UNION ALL
    SELECT
        'REPORTING transition sync trigger installed',
        EXISTS (
            SELECT 1
            FROM pg_trigger AS t
            JOIN pg_class AS c ON c.oid = t.tgrelid
            JOIN pg_namespace AS n ON n.oid = c.relnamespace
            WHERE n.nspname = 'ops'
              AND c.relname = 'lor_reconciliation_run'
              AND t.tgname = 'trg_sync_lor_reconciliation_counters_on_reporting'
              AND NOT t.tgisinternal
        )
    UNION ALL
    SELECT
        'sync function uses effective group state',
        pg_get_functiondef(
            'ops.f_sync_lor_reconciliation_effective_counters(bigint)'::regprocedure
        ) ILIKE '%effective_resolution_state%'
    UNION ALL
    SELECT
        'sync function ignores frozen candidate flags',
        pg_get_functiondef(
            'ops.f_sync_lor_reconciliation_effective_counters(bigint)'::regprocedure
        ) NOT ILIKE '%is_blocking%'
    UNION ALL
    SELECT
        'sync function does not execute promotion',
        pg_get_functiondef(
            'ops.f_sync_lor_reconciliation_effective_counters(bigint)'::regprocedure
        ) !~* 'p[1234]_promote'
    UNION ALL
    SELECT
        'REPORTING counters match effective states',
        NOT EXISTS (
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
                WHERE gr.lor_reconciliation_run_id = r.lor_reconciliation_run_id
            ) AS ec
            WHERE r.status = 'REPORTING'
              AND (
                  r.unresolved_count <> ec.unresolved_count
                  OR r.deferred_count <> ec.deferred_count
                  OR r.blocked_count <> ec.blocked_count
              )
        )
)
SELECT check_name, passed
FROM checks
ORDER BY check_name;

/* Human-readable retained-run confirmation. */
SELECT
    r.lor_reconciliation_run_id AS reconciliation_run,
    r.import_run_id AS captured_ingest,
    r.status,
    r.validation_state,
    r.unresolved_count,
    r.deferred_count,
    r.blocked_count
FROM ops.lor_reconciliation_run AS r
WHERE r.status = 'REPORTING'
ORDER BY r.lor_reconciliation_run_id;
