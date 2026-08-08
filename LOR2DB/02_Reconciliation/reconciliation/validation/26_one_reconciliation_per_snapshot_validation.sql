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

/* Verified pre-production Runs 1 and 2 must be gone. Run 3 and every later
   real workflow run remain outside the cleanup boundary. */
SELECT
    'PREPRODUCTION_RUNS_1_AND_2_REMOVED' AS check_name,
    CASE WHEN NOT EXISTS (
        SELECT 1
        FROM ops.lor_reconciliation_run
        WHERE lor_reconciliation_run_id IN (1, 2)
    ) THEN 'PASS' ELSE 'FAIL' END AS result,
    count(*) FILTER (WHERE lor_reconciliation_run_id IN (1, 2)) AS violation_count
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

/* The guard and resume-aware Start function must cover every nonterminal
   lifecycle state, not only REPORTING. */
WITH required_state(status) AS (
    VALUES
        ('STARTING'), ('PREFLIGHT'), ('AWAITING_DECISIONS'),
        ('READY_TO_FINISH'), ('PROMOTING'), ('VALIDATING'), ('REPORTING')
),
installed AS (
    SELECT
        pg_get_expr(i.indpred, i.indrelid) AS guard_definition,
        pg_get_functiondef(
            'ops.f_start_lor_reconciliation(text)'::regprocedure
        ) AS start_definition
    FROM pg_index AS i
    WHERE i.indexrelid =
          'ops.ux_lor_reconciliation_one_unfinished_run'::regclass
)
SELECT
    'ALL_UNFINISHED_STATES_GUARDED_AND_RESUMED' AS check_name,
    CASE WHEN count(*) FILTER (
                  WHERE installed.guard_definition NOT LIKE '%' || required_state.status || '%'
                     OR installed.start_definition NOT LIKE '%' || required_state.status || '%'
              ) = 0
         THEN 'PASS' ELSE 'FAIL' END AS result,
    count(*) FILTER (
        WHERE installed.guard_definition NOT LIKE '%' || required_state.status || '%'
           OR installed.start_definition NOT LIKE '%' || required_state.status || '%'
    ) AS violation_count
FROM required_state
CROSS JOIN installed;

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
    ) AS has_one_run_per_snapshot_guard,
    to_regprocedure('ops.f_start_lor_reconciliation(text)') IS NOT NULL
        AS has_resume_aware_start;
