/* ============================================================================
File:        20_display_name_changes_report_validation.sql
Validation:  Display Name Changes reconciliation report
Migration:   0024_create_display_name_changes_report.sql

Purpose:
  Verify the installed report exposes only committed display-name changes,
  preserves permanent ref.display.display_id, excludes unchanged names, and
  returns the documented four operator-facing columns.

Safety:
  - Read-only.
  - Does not record decisions.
  - Does not call P1, P2, P3, P4, Finish, or promotion.
  - Does not modify lor_snap, ops, ref, or production data.

Expected Results:
  Result Grid 1: Every check is PASS.
  Result Grid 2: Current committed report rows, if any, with only the four
                 documented columns plus reconciliation_run for validation.

Revision History:
  2026-08-03  GAL / OpenAI  Initial validation.
============================================================================ */

/* Result Grid 1: Installation, authority, and exclusion checks. */
WITH object_definition AS (
    SELECT
        pg_get_viewdef(
            'ops.v_lor_reconciliation_display_name_change_audit'::regclass,
            true
        ) AS view_definition,
        pg_get_functiondef(
            'ops.f_lor_reconciliation_display_name_changes_report(bigint)'::regprocedure
        ) AS function_definition
),
checks AS (
    SELECT
        'report objects installed'::text AS check_name,
        CASE
            WHEN to_regclass(
                'ops.v_lor_reconciliation_display_name_change_audit'
            ) IS NOT NULL
             AND to_regprocedure(
                'ops.f_lor_reconciliation_display_name_changes_report(bigint)'
             ) IS NOT NULL
            THEN 'PASS' ELSE 'FAIL'
        END AS result,
        ''::text AS detail

    UNION ALL

    SELECT
        'report requires committed production results',
        CASE
            WHEN view_definition ILIKE '%committed%true%'
            THEN 'PASS' ELSE 'FAIL'
        END,
        'Proposed and merely approved changes are excluded.'
    FROM object_definition

    UNION ALL

    SELECT
        'unchanged display names are excluded',
        CASE
            WHEN NOT EXISTS (
                SELECT 1
                FROM ops.v_lor_reconciliation_display_name_change_audit AS a
                WHERE a.before_name IS NOT DISTINCT FROM a.after_name
            )
            THEN 'PASS' ELSE 'FAIL'
        END,
        'Every report row is an actual display-name change.'

    UNION ALL

    SELECT
        'follow-up instruction is fixed',
        CASE
            WHEN NOT EXISTS (
                SELECT 1
                FROM ops.v_lor_reconciliation_display_name_change_audit AS a
                WHERE a.follow_up <> 'Preprint replacement label'
            )
            THEN 'PASS' ELSE 'FAIL'
        END,
        'Every changed display requires a replacement label.'

    UNION ALL

    SELECT
        'operator function exposes exact four-column contract',
        CASE
            WHEN pg_get_function_result(
                'ops.f_lor_reconciliation_display_name_changes_report(bigint)'::regprocedure
            ) =
            'TABLE("Display_id" bigint, "Before" text, "After" text, "Follow-up" text)'
            THEN 'PASS' ELSE 'FAIL'
        END,
        pg_get_function_result(
            'ops.f_lor_reconciliation_display_name_changes_report(bigint)'::regprocedure
        )

    UNION ALL

    SELECT
        'uncommitted active-run candidates do not appear',
        CASE
            WHEN NOT EXISTS (
                SELECT 1
                FROM ops.lor_reconciliation_run AS r
                JOIN ops.v_lor_reconciliation_display_name_change_audit AS a
                  ON a.lor_reconciliation_run_id = r.lor_reconciliation_run_id
                WHERE r.status IN (
                    'STARTING', 'PREFLIGHT', 'AWAITING_DECISIONS',
                    'READY_TO_FINISH'
                )
            )
            THEN 'PASS' ELSE 'FAIL'
        END,
        'Run 3 remains absent until P2 records an actual committed result.'
)
SELECT check_name, result, detail
FROM checks
ORDER BY check_name;


/* Result Grid 2: Actual committed display-name report rows, if any. */
SELECT
    a.lor_reconciliation_run_id AS reconciliation_run,
    a.display_id AS "Display_id",
    a.before_name AS "Before",
    a.after_name AS "After",
    a.follow_up AS "Follow-up"
FROM ops.v_lor_reconciliation_display_name_change_audit AS a
ORDER BY a.lor_reconciliation_run_id, a.display_id;
