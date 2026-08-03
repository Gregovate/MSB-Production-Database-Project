/*
Validation: independent reconciliation-attempt lifecycle
Revision:   2026-08-03-independent-reconciliation-attempts-v1

Read-only. Run after migration 0022. This does not start, finish, supersede,
cancel, promote, or delete any reconciliation or snapshot.
*/

SELECT
    to_regprocedure('ops.f_start_lor_reconciliation(text)') IS NOT NULL
        AS has_unified_start,
    to_regprocedure('ops.f_start_lor_display_reconciliation(text)') IS NOT NULL
        AS has_independent_display_start,
    to_regprocedure('ops.trg_require_terminal_reconciliation_decisions()')
        IS NOT NULL AS has_terminal_decision_guard,
    to_regclass('ops.ux_lor_reconciliation_one_open_run') IS NULL
        AS global_open_run_block_removed,
    NOT EXISTS (
        SELECT 1
        FROM pg_constraint AS c
        JOIN pg_class AS t ON t.oid = c.conrelid
        JOIN pg_namespace AS n ON n.oid = t.relnamespace
        WHERE n.nspname = 'ops'
          AND t.relname = 'lor_reconciliation_run'
          AND c.conname = 'ux_lor_reconciliation_run_import'
    ) AS one_attempt_per_import_block_removed,
    EXISTS (
        SELECT 1
        FROM information_schema.columns
        WHERE table_schema = 'ops'
          AND table_name = 'lor_reconciliation_run'
          AND column_name = 'superseded_by_run_id'
    ) AS has_supersession_lineage;

SELECT
    r.lor_reconciliation_run_id,
    r.import_run_id,
    r.status,
    r.unresolved_count,
    r.deferred_count,
    r.blocked_count,
    r.superseded_at,
    r.superseded_by_run_id,
    r.supersession_reason
FROM ops.lor_reconciliation_run AS r
ORDER BY r.lor_reconciliation_run_id;
