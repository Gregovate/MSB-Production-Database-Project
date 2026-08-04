/* ============================================================================
File:       0024_create_display_name_changes_report.sql
Migration:  Display Name Changes reconciliation report

Purpose:
  Implement the documented operator-facing Display Name Changes report from
  frozen reconciliation candidates and actual committed P2 results.

Report Contract:
  The run-scoped report returns only:
    Display_id | Before | After | Follow-up

  Follow-up is always:
    Preprint replacement label

Authority:
  - ref.display.display_id is the permanent display identity.
  - Candidate IDs, UUID evidence, group IDs, and classifications remain internal.
  - Only committed production results appear. Proposed or merely approved changes
    never appear as completed report rows.

Safety Boundary:
  - Defines read-only reporting objects only.
  - Does not record decisions.
  - Does not call P1, P2, P3, P4, Finish, or promotion.
  - Does not modify reconciliation working data or production data.

Revision History:
  2026-08-03  GAL / OpenAI  Initial committed display-name change report.
============================================================================ */

BEGIN;

/*
  Resolve each frozen display candidate to the permanent ref.display.display_id
  that P2 actually targeted. Atomic reassociations use the effective action's
  frozen assignment; ordinary candidates retain their frozen display_id.
*/
CREATE OR REPLACE VIEW ops.v_lor_reconciliation_display_name_change_audit AS
WITH latest_action AS (
    SELECT DISTINCT ON (a.lor_reconciliation_group_id)
        a.lor_reconciliation_group_id,
        a.lor_reconciliation_action_id,
        a.action_type
    FROM ops.lor_reconciliation_action AS a
    WHERE a.lor_reconciliation_group_id IS NOT NULL
    ORDER BY
        a.lor_reconciliation_group_id,
        a.acted_at DESC,
        a.lor_reconciliation_action_id DESC
),
resolved_candidate AS (
    SELECT
        c.lor_reconciliation_run_id,
        c.import_run_id,
        c.lor_reconciliation_display_candidate_id,
        CASE
            WHEN la.action_type = 'REASSOCIATE_DISPLAY'
                THEN aa.target_display_id
            ELSE c.display_id
        END AS target_display_id,
        c.current_display_name,
        c.proposed_display_name
    FROM ops.lor_reconciliation_display_candidate AS c
    LEFT JOIN latest_action AS la
      ON la.lor_reconciliation_group_id = c.lor_reconciliation_group_id
    LEFT JOIN ops.lor_reconciliation_action_assignment AS aa
      ON aa.lor_reconciliation_action_id = la.lor_reconciliation_action_id
     AND aa.lor_reconciliation_display_candidate_id =
            c.lor_reconciliation_display_candidate_id
    WHERE c.candidate_class = 'PHYSICAL_DISPLAY'
)
SELECT DISTINCT
    r.lor_reconciliation_run_id,
    r.import_run_id,
    r.recorded_at,
    rc.target_display_id AS display_id,
    rc.current_display_name AS before_name,
    rc.proposed_display_name AS after_name,
    'Preprint replacement label'::text AS follow_up
FROM ops.lor_reconciliation_result AS r
JOIN resolved_candidate AS rc
  ON rc.lor_reconciliation_run_id = r.lor_reconciliation_run_id
 AND rc.import_run_id = r.import_run_id
 AND rc.target_display_id = r.entity_key::bigint
WHERE r.entity_type = 'DISPLAY'
  AND r.committed IS TRUE
  AND r.result_class IN ('UPDATED', 'REASSOCIATED')
  AND r.entity_key ~ '^[0-9]+$'
  AND rc.current_display_name IS DISTINCT FROM rc.proposed_display_name;

COMMENT ON VIEW ops.v_lor_reconciliation_display_name_change_audit IS
'Committed display-name changes with permanent ref.display.display_id and frozen before/after names. Internal reconciliation keys remain excluded from operator output.';

/*
  Run-scoped operator report. Quoted output names intentionally match the
  documented human-readable four-column report exactly.
*/
CREATE OR REPLACE FUNCTION ops.f_lor_reconciliation_display_name_changes_report(
    p_lor_reconciliation_run_id bigint
)
RETURNS TABLE (
    "Display_id" bigint,
    "Before" text,
    "After" text,
    "Follow-up" text
)
LANGUAGE sql
STABLE
SET search_path = pg_catalog, ops
AS $function$
    SELECT
        a.display_id AS "Display_id",
        a.before_name AS "Before",
        a.after_name AS "After",
        a.follow_up AS "Follow-up"
    FROM ops.v_lor_reconciliation_display_name_change_audit AS a
    WHERE a.lor_reconciliation_run_id = p_lor_reconciliation_run_id
    ORDER BY a.display_id;
$function$;

COMMENT ON FUNCTION
    ops.f_lor_reconciliation_display_name_changes_report(bigint) IS
'Returns only Display_id, Before, After, and Follow-up for actual committed display-name changes in one reconciliation run.';

COMMIT;

SELECT
    '2026-08-03-display-name-changes-report-v1'::text AS installed_revision,
    to_regclass(
        'ops.v_lor_reconciliation_display_name_change_audit'
    ) IS NOT NULL AS has_committed_name_change_audit,
    to_regprocedure(
        'ops.f_lor_reconciliation_display_name_changes_report(bigint)'
    ) IS NOT NULL AS has_display_name_changes_report;
