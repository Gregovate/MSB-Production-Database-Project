/* Read-only acceptance checks for migration 0032. */

DO $validation$
DECLARE
    v_constraint text;
    v_cancel_trigger_present boolean;
BEGIN
    IF to_regprocedure(
        'ops.f_normalize_lor_stage_name(text,text)'
    ) IS NULL OR to_regprocedure(
        'ops.f_stage_group_can_approve_change(bigint)'
    ) IS NULL OR to_regprocedure(
        'ops.f_stage_group_can_add_new_stage(bigint)'
    ) IS NULL OR to_regprocedure(
        'ops.f_record_lor_stage_authority_action(bigint,bigint,text,text,text)'
    ) IS NULL THEN
        RAISE EXCEPTION 'Migration 0032 stage authority functions are incomplete';
    END IF;

    IF ops.f_normalize_lor_stage_name(
        'Show Stage 40-CommandCenter-CC', '40'
    ) <> 'CommandCenter-CC' OR ops.f_normalize_lor_stage_name(
        'Show Background Stage 05a Magic Star MS', '05a'
    ) <> 'Magic Star MS' THEN
        RAISE EXCEPTION 'Stage-name normalization does not match LOR naming forms';
    END IF;

    IF to_regprocedure(
        'ref.p1_promote_stage_from_reconciliation_before_0032(bigint)'
    ) IS NULL OR to_regprocedure(
        'ref.p1_promote_stage_from_reconciliation(bigint)'
    ) IS NULL THEN
        RAISE EXCEPTION 'Migration 0032 P1 wrapper/preserved implementation is incomplete';
    END IF;

    SELECT EXISTS (
        SELECT 1
        FROM pg_trigger AS t
        JOIN pg_class AS c ON c.oid = t.tgrelid
        JOIN pg_namespace AS n ON n.oid = c.relnamespace
        WHERE n.nspname = 'ops'
          AND c.relname = 'lor_reconciliation_run'
          AND t.tgname = 'trg_set_cancelled_reconciliation_completed_at'
          AND NOT t.tgisinternal
    ) INTO v_cancel_trigger_present;

    IF to_regprocedure(
        'ops.f_set_cancelled_reconciliation_completed_at()'
    ) IS NULL OR NOT v_cancel_trigger_present THEN
        RAISE EXCEPTION 'Cancelled-run terminal timestamp guard is incomplete';
    END IF;

    IF EXISTS (
        SELECT 1
        FROM ops.lor_reconciliation_run AS r
        WHERE r.status = 'CANCELLED'
          AND r.completed_at IS NULL
    ) THEN
        RAISE EXCEPTION 'A CANCELLED reconciliation is missing completed_at';
    END IF;

    SELECT pg_get_constraintdef(c.oid)
      INTO v_constraint
    FROM pg_constraint AS c
    JOIN pg_class AS t ON t.oid = c.conrelid
    JOIN pg_namespace AS n ON n.oid = t.relnamespace
    WHERE n.nspname = 'ops'
      AND t.relname = 'lor_reconciliation_action'
      AND c.conname = 'ck_lor_reconciliation_action_type';

    IF v_constraint NOT LIKE '%APPROVE_STAGE_CHANGE%'
       OR v_constraint NOT LIKE '%ADD_NEW_STAGE%' THEN
        RAISE EXCEPTION 'Stage authority action constraint is incomplete';
    END IF;

    IF EXISTS (
        SELECT 1
        FROM ops.v_lor_reconciliation_group_review AS gr
        WHERE gr.entity_type = 'STAGE'
          AND (
              'APPROVE_STAGE_CHANGE' = ANY(gr.allowed_action_types)
              AND NOT ops.f_stage_group_can_approve_change(
                  gr.lor_reconciliation_group_id)
              OR
              'ADD_NEW_STAGE' = ANY(gr.allowed_action_types)
              AND NOT ops.f_stage_group_can_add_new_stage(
                  gr.lor_reconciliation_group_id)
          )
    ) THEN
        RAISE EXCEPTION 'A stage approval action escaped its evidence gate';
    END IF;

    IF EXISTS (
        SELECT 1
        FROM ops.lor_reconciliation_group AS g
        JOIN ops.lor_reconciliation_stage_candidate AS c
          ON c.lor_reconciliation_group_id = g.lor_reconciliation_group_id
        JOIN ops.v_lor_reconciliation_group_review AS gr
          ON gr.lor_reconciliation_group_id = g.lor_reconciliation_group_id
        WHERE g.entity_type = 'STAGE'
        GROUP BY g.lor_reconciliation_group_id, gr.allowed_action_types
        HAVING (
            count(DISTINCT c.source_stage_key) > 1
            OR count(DISTINCT c.proposed_stage_name)
               FILTER (WHERE c.metadata_authoritative) > 1
        ) AND (
            'APPROVE_STAGE_CHANGE' = ANY(gr.allowed_action_types)
            OR 'ADD_NEW_STAGE' = ANY(gr.allowed_action_types)
        )
    ) THEN
        RAISE EXCEPTION 'Contradictory frozen stage evidence is approvable';
    END IF;
END;
$validation$;

SELECT
    'PASS'::text AS validation_status,
    'Safe stage authority is evidence-gated; CANCELLED runs are terminal.'::text
        AS validation_detail;
