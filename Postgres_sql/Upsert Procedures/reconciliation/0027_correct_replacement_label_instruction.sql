/* ============================================================================
File:       0027_correct_replacement_label_instruction.sql
Migration:  Correct operator replacement-label wording

Purpose:
  Change the fixed operator-facing follow-up instruction from the incorrect
  "Preprint replacement label" to "Print replacement label".

Safety Boundary:
  - Replaces one read-only reporting view definition.
  - Does not change reconciliation evidence or production data.
  - Does not call P1, P2, P3, P4, Finish, or report publication.

Revision History:
  2026-08-03  GAL / OpenAI  Correct replacement-label instruction.
============================================================================ */

BEGIN;

CREATE OR REPLACE VIEW ops.v_lor_reconciliation_display_name_change_audit AS
WITH latest_action AS (
    SELECT DISTINCT ON (a.lor_reconciliation_group_id)
        a.lor_reconciliation_group_id,
        a.lor_reconciliation_action_id,
        a.action_type
    FROM ops.lor_reconciliation_action AS a
    WHERE a.lor_reconciliation_group_id IS NOT NULL
    ORDER BY a.lor_reconciliation_group_id, a.acted_at DESC,
             a.lor_reconciliation_action_id DESC
),
resolved_candidate AS (
    SELECT
        c.lor_reconciliation_run_id,
        c.import_run_id,
        c.lor_reconciliation_display_candidate_id,
        CASE WHEN la.action_type = 'REASSOCIATE_DISPLAY'
             THEN aa.target_display_id ELSE c.display_id END AS target_display_id,
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
    'Print replacement label'::text AS follow_up
FROM ops.lor_reconciliation_result AS r
JOIN resolved_candidate AS rc
  ON rc.lor_reconciliation_run_id = r.lor_reconciliation_run_id
 AND rc.import_run_id = r.import_run_id
 AND rc.target_display_id::text = r.entity_key
WHERE r.entity_type = 'DISPLAY'
  AND r.committed IS TRUE
  AND r.result_class IN ('UPDATED', 'REASSOCIATED')
  AND r.entity_key ~ '^[0-9]+$'
  AND rc.current_display_name IS DISTINCT FROM rc.proposed_display_name;

COMMENT ON VIEW ops.v_lor_reconciliation_display_name_change_audit IS
'Committed display-name changes with permanent display_id, frozen before/after names, and the fixed instruction Print replacement label.';

COMMIT;

SELECT
    '2026-08-03-correct-replacement-label-instruction-v1'::text
        AS installed_revision,
    NOT EXISTS (
        SELECT 1
        FROM ops.v_lor_reconciliation_display_name_change_audit
        WHERE follow_up <> 'Print replacement label'
    ) AS uses_correct_label_instruction;
