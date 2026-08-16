/* ============================================================================
Object:       Current P1 stage promotion entry procedure
Revision:     2026-08-16-after-0033

Purpose:
  Canonical repair/inspection definition of the public P1 entry procedure
  installed by migration 0033. The migration 0032 implementation remains
  `ref.p1_promote_stage_from_reconciliation_before_0033(bigint)`.

Safety:
  Installing this definition does not call P1 or modify production rows. Finish
  calls P1 only after all operator decisions have been recorded. Explicitly
  approved canonical StageID changes preserve permanent stage_id, and accepted
  per-binding source StageIDs prevent the same alias from reopening later.
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
    v_change record;
    v_old_stage_key text;
BEGIN
    SELECT r.import_run_id INTO v_import_run_id
    FROM ops.lor_reconciliation_run AS r
    WHERE r.lor_reconciliation_run_id = p_lor_reconciliation_run_id
    FOR UPDATE;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Reconciliation run % does not exist',
            p_lor_reconciliation_run_id;
    END IF;

    CALL ref.p1_promote_stage_from_reconciliation_before_0033(
        p_lor_reconciliation_run_id
    );

    FOR v_change IN
        SELECT
            gr.lor_reconciliation_group_id,
            min(c.resolved_stage_id) AS stage_id,
            a.action_payload ->> 'target_stage_key' AS target_stage_key,
            min(c.proposed_park_order) FILTER (
                WHERE c.proposed_stage_key =
                    a.action_payload ->> 'target_stage_key'
            ) AS park_order,
            min(c.proposed_sub_order) FILTER (
                WHERE c.proposed_stage_key =
                    a.action_payload ->> 'target_stage_key'
            ) AS sub_order
        FROM ops.v_lor_reconciliation_group_review AS gr
        JOIN ops.lor_reconciliation_action AS a
          ON a.lor_reconciliation_action_id = gr.effective_action_id
        JOIN ops.lor_reconciliation_stage_candidate AS c
          ON c.lor_reconciliation_group_id = gr.lor_reconciliation_group_id
        WHERE gr.lor_reconciliation_run_id = p_lor_reconciliation_run_id
          AND gr.effective_action_type = 'APPROVE_STAGE_CHANGE'
          AND gr.effective_resolution_state = 'APPROVED'
        GROUP BY gr.lor_reconciliation_group_id, a.action_payload
    LOOP
        IF nullif(btrim(v_change.target_stage_key), '') IS NULL THEN
            RAISE EXCEPTION 'Approved stage group % has no target StageID',
                v_change.lor_reconciliation_group_id;
        END IF;

        SELECT s.stage_key INTO v_old_stage_key
        FROM ref.stage AS s
        WHERE s.stage_id = v_change.stage_id
        FOR UPDATE;

        IF EXISTS (
            SELECT 1 FROM ref.stage AS s
            WHERE s.stage_key = v_change.target_stage_key
              AND s.stage_id <> v_change.stage_id
        ) THEN
            RAISE EXCEPTION 'Approved StageID % already belongs to another permanent stage',
                v_change.target_stage_key;
        END IF;

        UPDATE ref.stage AS s
           SET stage_key = v_change.target_stage_key,
               folder_name = CASE
                   WHEN s.folder_name LIKE v_old_stage_key || '-%'
                   THEN v_change.target_stage_key ||
                        substr(s.folder_name, length(v_old_stage_key) + 1)
                   ELSE s.folder_name
               END,
               park_order = v_change.park_order,
               sub_order = v_change.sub_order,
               updated_at = now(),
               updated_by = current_user
         WHERE s.stage_id = v_change.stage_id
           AND (
               s.stage_key IS DISTINCT FROM v_change.target_stage_key
               OR s.park_order IS DISTINCT FROM v_change.park_order
               OR s.sub_order IS DISTINCT FROM v_change.sub_order
           );

        IF FOUND THEN
            INSERT INTO ops.lor_reconciliation_result (
                lor_reconciliation_run_id, import_run_id, entity_type,
                entity_key, result_class, reason_code,
                operator_message, committed
            ) VALUES (
                p_lor_reconciliation_run_id, v_import_run_id, 'STAGE',
                v_change.stage_id::text, 'UPDATED',
                'P1_APPROVED_STAGE_KEY_CHANGE',
                format(
                    'UPDATED: Stage %s to canonical StageID %s and preserved permanent stage_id %s.',
                    v_old_stage_key, v_change.target_stage_key,
                    v_change.stage_id
                ),
                true
            );
        END IF;
    END LOOP;

    UPDATE ref.stage_lor_binding AS b
       SET accepted_source_stage_key = c.source_stage_key,
           updated_at = now(),
           updated_by = current_user
    FROM ops.lor_reconciliation_stage_candidate AS c
    JOIN ops.v_lor_reconciliation_group_review AS gr
      ON gr.lor_reconciliation_group_id = c.lor_reconciliation_group_id
    WHERE gr.lor_reconciliation_run_id = p_lor_reconciliation_run_id
      AND gr.effective_resolution_state IN ('AUTO_APPROVED', 'APPROVED')
      AND b.binding_type = c.binding_type
      AND b.preview_id = c.preview_id
      AND b.scene_id IS NOT DISTINCT FROM c.scene_id
      AND b.accepted_source_stage_key IS DISTINCT FROM c.source_stage_key;
END;
$procedure$;

COMMENT ON PROCEDURE ref.p1_promote_stage_from_reconciliation(bigint) IS
'Reconciliation-gated P1. Preserves permanent stage identity, applies explicitly approved canonical StageID/substage changes, remembers accepted per-binding source StageIDs, and delegates established/new-stage promotion to the preserved implementation.';

REVOKE EXECUTE ON PROCEDURE
    ref.p1_promote_stage_from_reconciliation(bigint) FROM PUBLIC;

COMMIT;
