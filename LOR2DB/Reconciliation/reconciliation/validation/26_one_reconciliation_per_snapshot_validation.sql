/* ============================================================================
Validation: 0030 snapshot reconciliation ownership
Safety:     Read-only. Does not start, finish, cancel, or promote a run.
============================================================================ */

WITH duplicate_snapshot AS (
    SELECT r.import_run_id, count(*) AS run_count
    FROM ops.lor_reconciliation_run AS r
    GROUP BY r.import_run_id
    HAVING count(*) > 1
),
unfinished AS (
    SELECT r.lor_reconciliation_run_id, r.import_run_id, r.status
    FROM ops.lor_reconciliation_run AS r
    WHERE r.status IN (
        'STARTING', 'PREFLIGHT', 'AWAITING_DECISIONS', 'READY_TO_FINISH',
        'PROMOTING', 'VALIDATING', 'REPORTING'
    )
)
SELECT
    'ONE_RECONCILIATION_PER_SNAPSHOT' AS check_name,
    CASE WHEN (SELECT count(*) FROM duplicate_snapshot) = 0
         THEN 'PASS' ELSE 'FAIL' END AS result,
    (SELECT count(*) FROM duplicate_snapshot) AS violation_count
UNION ALL
SELECT
    'AT_MOST_ONE_UNFINISHED_RUN',
    CASE WHEN (SELECT count(*) FROM unfinished) <= 1
         THEN 'PASS' ELSE 'FAIL' END,
    greatest((SELECT count(*) FROM unfinished) - 1, 0);

/* The obsolete, uncommitted Run 2 attempt must be gone. Run 3 must remain as
   the sole authoritative reconciliation for snapshot 44. */
SELECT
    'OBSOLETE_RUN_2_REMOVED' AS check_name,
    CASE WHEN NOT EXISTS (
        SELECT 1
        FROM ops.lor_reconciliation_run
        WHERE lor_reconciliation_run_id = 2
    ) THEN 'PASS' ELSE 'FAIL' END AS result,
    count(*) FILTER (WHERE lor_reconciliation_run_id = 2) AS violation_count
FROM ops.lor_reconciliation_run
UNION ALL
SELECT
    'RUN_3_OWNS_SNAPSHOT_44',
    CASE WHEN count(*) = 1
              AND bool_and(lor_reconciliation_run_id = 3)
              AND bool_and(status = 'COMPLETED')
              AND bool_and(validation_state = 'PASSED')
         THEN 'PASS' ELSE 'FAIL' END,
    count(*) FILTER (WHERE lor_reconciliation_run_id <> 3)
FROM ops.lor_reconciliation_run
WHERE import_run_id = 44;

SELECT
    r.lor_reconciliation_run_id,
    r.import_run_id,
    r.status,
    r.validation_state,
    r.report_url,
    CASE
        WHEN r.status IN (
            'STARTING', 'PREFLIGHT', 'AWAITING_DECISIONS',
            'READY_TO_FINISH', 'PROMOTING', 'VALIDATING', 'REPORTING'
        ) THEN 'CONTINUE_PREVIOUS_RECONCILIATION'
        ELSE 'SNAPSHOT_CONSUMED'
    END AS expected_landing_page_action
FROM ops.lor_reconciliation_run AS r
ORDER BY r.lor_reconciliation_run_id DESC;

SELECT
    to_regclass('ops.ux_lor_reconciliation_one_unfinished_run') IS NOT NULL
        AS has_one_unfinished_run_guard,
    EXISTS (
        SELECT 1
        FROM pg_constraint AS c
        WHERE c.conrelid = 'ops.lor_reconciliation_run'::regclass
          AND c.conname = 'ux_lor_reconciliation_run_import'
    ) AS has_one_run_per_snapshot_guard;
