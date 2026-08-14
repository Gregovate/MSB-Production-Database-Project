/* ============================================================================
Object:       Current P1 stage promotion entry procedure
Revision:     2026-08-14-after-0032

Purpose:
  Canonical repair/inspection definition of the public P1 entry procedure
  installed by migration 0032. The preserved existing-stage implementation
  remains `ref.p1_promote_stage_from_reconciliation_before_0032(bigint)`.

Safety:
  Installing this definition does not call P1 or modify production rows. New
  stages are inserted only when Finish calls P1 for an explicitly approved,
  unambiguous ADD_NEW_STAGE group.
============================================================================ */

BEGIN;

CREATE OR REPLACE PROCEDURE ref.p1_promote_stage_from_reconciliation(
    p_lor_reconciliation_run_id bigint
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, ops, lor_snap, ref
AS $procedure$
DECLARE
    v_import_run_id bigint;
    v_group record;
    v_binding record;
    v_stage_id integer;
BEGIN
    SELECT r.import_run_id INTO v_import_run_id
    FROM ops.lor_reconciliation_run AS r
    WHERE r.lor_reconciliation_run_id = p_lor_reconciliation_run_id
    FOR UPDATE;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Reconciliation run % does not exist',
            p_lor_reconciliation_run_id;
    END IF;

    FOR v_group IN
        SELECT
            gr.lor_reconciliation_group_id,
            min(c.proposed_stage_key) AS stage_key,
            min(ops.f_normalize_lor_stage_name(
                c.source_name, c.proposed_stage_key))
                FILTER (WHERE c.metadata_authoritative)
                AS stage_name,
            min(c.proposed_stage_key || '-' ||
                ops.f_normalize_lor_stage_name(
                    c.source_name, c.proposed_stage_key))
                FILTER (WHERE c.metadata_authoritative)
                AS folder_name,
            min(c.proposed_park_order) AS park_order,
            min(c.proposed_sub_order) AS sub_order
        FROM ops.v_lor_reconciliation_group_review AS gr
        JOIN ops.lor_reconciliation_stage_candidate AS c
          ON c.lor_reconciliation_group_id = gr.lor_reconciliation_group_id
        WHERE gr.lor_reconciliation_run_id = p_lor_reconciliation_run_id
          AND gr.effective_action_type = 'ADD_NEW_STAGE'
          AND gr.effective_resolution_state = 'APPROVED'
          AND ops.f_stage_group_can_add_new_stage(
                gr.lor_reconciliation_group_id)
        GROUP BY gr.lor_reconciliation_group_id
    LOOP
        IF EXISTS (
            SELECT 1 FROM ref.stage_lor_binding AS b
            JOIN ops.lor_reconciliation_stage_candidate AS c
              ON c.binding_type = b.binding_type
             AND c.preview_id = b.preview_id
             AND c.scene_id IS NOT DISTINCT FROM b.scene_id
            WHERE c.lor_reconciliation_group_id =
                v_group.lor_reconciliation_group_id
        ) THEN
            RAISE EXCEPTION 'A stable LOR binding for new stage group % was created after preflight',
                v_group.lor_reconciliation_group_id;
        END IF;

        INSERT INTO ref.stage (
            stage_key, stage_name, folder_name, park_order, sub_order
        ) VALUES (
            v_group.stage_key, v_group.stage_name, v_group.folder_name,
            v_group.park_order, v_group.sub_order
        ) RETURNING stage_id INTO v_stage_id;

        INSERT INTO ops.lor_reconciliation_result (
            lor_reconciliation_run_id, import_run_id, entity_type,
            entity_key, result_class, reason_code, operator_message, committed
        ) VALUES (
            p_lor_reconciliation_run_id, v_import_run_id, 'STAGE',
            v_stage_id::text, 'ADDED', 'P1_ADD_NEW_STAGE',
            format('ADDED: Stage %s as permanent stage_id %s.',
                v_group.stage_key, v_stage_id), true
        );

        FOR v_binding IN
            SELECT c.*
            FROM ops.lor_reconciliation_stage_candidate AS c
            WHERE c.lor_reconciliation_group_id =
                v_group.lor_reconciliation_group_id
            ORDER BY c.lor_reconciliation_stage_candidate_id
        LOOP
            INSERT INTO ref.stage_lor_binding (
                stage_id, binding_type, preview_id, scene_id, source_name,
                first_seen_import_run_id, last_seen_import_run_id
            ) VALUES (
                v_stage_id, v_binding.binding_type, v_binding.preview_id,
                v_binding.scene_id, v_binding.source_name,
                v_import_run_id, v_import_run_id
            );

            INSERT INTO ops.lor_reconciliation_result (
                lor_reconciliation_run_id, import_run_id, entity_type,
                entity_key, result_class, reason_code,
                operator_message, committed
            ) VALUES (
                p_lor_reconciliation_run_id, v_import_run_id, 'STAGE',
                v_binding.candidate_key, 'ADDED', 'P1_STAGE_LOR_BINDING',
                format('ADDED: %s binding %s%s to new permanent stage_id %s.',
                    v_binding.binding_type, v_binding.preview_id,
                    CASE WHEN v_binding.scene_id IS NULL THEN ''
                         ELSE '/' || v_binding.scene_id END,
                    v_stage_id), true
            );
        END LOOP;
    END LOOP;

    CALL ref.p1_promote_stage_from_reconciliation_before_0032(
        p_lor_reconciliation_run_id
    );
END;
$procedure$;

COMMENT ON PROCEDURE ref.p1_promote_stage_from_reconciliation(bigint) IS
'Reconciliation-gated P1. Adds explicitly approved unambiguous new stages, then delegates existing-stage metadata/binding promotion to the preserved implementation.';

REVOKE EXECUTE ON PROCEDURE
    ref.p1_promote_stage_from_reconciliation(bigint) FROM PUBLIC;

COMMIT;
