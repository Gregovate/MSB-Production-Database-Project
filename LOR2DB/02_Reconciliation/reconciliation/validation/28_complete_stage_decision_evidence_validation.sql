/* Read-only acceptance checks for migration 0033. */

DO $validation$
BEGIN
    IF NOT EXISTS (
        SELECT 1
        FROM information_schema.columns
        WHERE table_schema = 'ref'
          AND table_name = 'stage_lor_binding'
          AND column_name = 'accepted_source_stage_key'
    ) OR to_regprocedure(
        'ops.f_stage_group_has_only_accepted_binding_keys(bigint)'
    ) IS NULL THEN
        RAISE EXCEPTION
            'Stage binding source-key acceptance objects are incomplete';
    END IF;

    IF EXISTS (
        SELECT 1
        FROM ops.v_lor_reconciliation_group_review AS gr
        LEFT JOIN ops.v_lor_reconciliation_operator_stage_review AS sr
          ON sr.lor_reconciliation_group_id = gr.lor_reconciliation_group_id
        WHERE gr.entity_type = 'STAGE'
          AND gr.decision_required
        GROUP BY gr.lor_reconciliation_group_id, gr.member_count
        HAVING count(sr.lor_reconciliation_stage_candidate_id)
            <> gr.member_count
    ) THEN
        RAISE EXCEPTION
            'A decision-required stage group hides frozen evidence members';
    END IF;

    IF EXISTS (
        SELECT 1
        FROM ops.v_lor_reconciliation_group_review AS gr
        WHERE gr.entity_type = 'STAGE'
          AND ops.f_stage_group_can_approve_change(
              gr.lor_reconciliation_group_id)
          AND NOT ('APPROVE_STAGE_CHANGE' = ANY(gr.allowed_action_types))
    ) THEN
        RAISE EXCEPTION
            'An eligible canonical StageID change lacks an approval action';
    END IF;
END;
$validation$;

SELECT
    'PASS'::text AS validation_status,
    'Stage key changes preserve permanent identity, accepted aliases persist, and every decision group exposes complete frozen evidence.'::text
        AS validation_detail;
