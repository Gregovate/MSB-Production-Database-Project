/* ============================================================================
Object:       Current P1 stage promotion entry procedure
Revision:     2026-08-17-distinct-substage-safe-p1-v2

Purpose:
  Canonical inspection/repair definition installed by migration 0035. It
  treats simultaneous main/substage source keys as distinct stages and permits
  a true canonical rename only when every stable binding agrees.

Safety:
  Installing this definition replaces P1 only. It does not call P1, start a
  reconciliation, or modify production rows.
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
    v_change record;
    v_stage_id integer;
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

    FOR v_group IN
        SELECT
            gr.lor_reconciliation_group_id,
            a.action_payload ->> 'target_stage_key' AS stage_key,
            coalesce(
                min(ops.f_normalize_lor_stage_name(
                    c.source_name, c.source_stage_key
                )) FILTER (
                    WHERE c.source_stage_key =
                        a.action_payload ->> 'target_stage_key'
                      AND c.metadata_authoritative
                ),
                'RGB Plus Stage ' ||
                    (a.action_payload ->> 'target_stage_key') || ' ' ||
                    min(regexp_replace(
                        ops.f_normalize_lor_stage_name(
                            c.source_name, c.source_stage_key
                        ),
                        '-[[:alnum:]]{1,4}$', ''
                    )) FILTER (
                        WHERE c.source_stage_key =
                            a.action_payload ->> 'target_stage_key'
                    )
            ) AS stage_name,
            min(c.proposed_park_order) FILTER (
                WHERE c.source_stage_key =
                    a.action_payload ->> 'target_stage_key'
            ) AS park_order,
            min(c.proposed_sub_order) FILTER (
                WHERE c.source_stage_key =
                    a.action_payload ->> 'target_stage_key'
            ) AS sub_order
        FROM ops.v_lor_reconciliation_group_review AS gr
        JOIN ops.lor_reconciliation_action AS a
          ON a.lor_reconciliation_action_id = gr.effective_action_id
        JOIN ops.lor_reconciliation_stage_candidate AS c
          ON c.lor_reconciliation_group_id = gr.lor_reconciliation_group_id
        WHERE gr.lor_reconciliation_run_id = p_lor_reconciliation_run_id
          AND gr.effective_action_type = 'ADD_NEW_STAGE'
          AND gr.effective_resolution_state = 'APPROVED'
          AND ops.f_stage_group_can_add_new_stage(
                gr.lor_reconciliation_group_id)
        GROUP BY gr.lor_reconciliation_group_id, a.action_payload
    LOOP
        IF nullif(btrim(v_group.stage_key), '') IS NULL THEN
            RAISE EXCEPTION 'Approved new-stage group % has no target StageID',
                v_group.lor_reconciliation_group_id;
        END IF;
        IF EXISTS (
            SELECT 1 FROM ref.stage AS s WHERE s.stage_key = v_group.stage_key
        ) THEN
            RAISE EXCEPTION 'Approved new StageID % already exists',
                v_group.stage_key;
        END IF;

        INSERT INTO ref.stage (
            stage_key, stage_name, folder_name, park_order, sub_order
        ) VALUES (
            v_group.stage_key, v_group.stage_name,
            v_group.stage_key || '-' || v_group.stage_name,
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
              AND c.source_stage_key = v_group.stage_key
            ORDER BY c.lor_reconciliation_stage_candidate_id
        LOOP
            IF v_binding.binding_type = 'PREVIEW' THEN
                UPDATE ref.stage_lor_binding AS b
                   SET stage_id = v_stage_id,
                       source_name = v_binding.source_name,
                       last_seen_import_run_id = v_import_run_id,
                       accepted_source_stage_key = v_group.stage_key,
                       updated_at = now(), updated_by = current_user
                 WHERE b.binding_type = 'PREVIEW'
                   AND b.preview_id = v_binding.preview_id;
                IF NOT FOUND THEN
                    INSERT INTO ref.stage_lor_binding (
                        stage_id, binding_type, preview_id, scene_id,
                        source_name, first_seen_import_run_id,
                        last_seen_import_run_id, accepted_source_stage_key
                    ) VALUES (
                        v_stage_id, 'PREVIEW', v_binding.preview_id, NULL,
                        v_binding.source_name, v_import_run_id,
                        v_import_run_id, v_group.stage_key
                    );
                END IF;
            ELSE
                INSERT INTO ref.stage_lor_binding (
                    stage_id, binding_type, preview_id, scene_id, source_name,
                    first_seen_import_run_id, last_seen_import_run_id,
                    accepted_source_stage_key
                ) VALUES (
                    v_stage_id, 'SCENE', v_binding.preview_id,
                    v_binding.scene_id, v_binding.source_name,
                    v_import_run_id, v_import_run_id, v_group.stage_key
                )
                ON CONFLICT (preview_id, scene_id)
                    WHERE binding_type = 'SCENE'
                DO UPDATE SET
                    stage_id = EXCLUDED.stage_id,
                    source_name = EXCLUDED.source_name,
                    last_seen_import_run_id = EXCLUDED.last_seen_import_run_id,
                    accepted_source_stage_key =
                        EXCLUDED.accepted_source_stage_key,
                    updated_at = now(), updated_by = current_user;
            END IF;
        END LOOP;
    END LOOP;

    /* Original existing-stage behavior remains authoritative for ordinary
       exact bindings, preservation decisions, and new stable bindings. */
    CALL ref.p1_promote_stage_from_reconciliation_before_0032(
        p_lor_reconciliation_run_id
    );

    FOR v_change IN
        SELECT
            gr.lor_reconciliation_group_id,
            min(c.resolved_stage_id) AS stage_id,
            a.action_payload ->> 'target_stage_key' AS target_stage_key,
            min(c.proposed_park_order) AS park_order,
            min(c.proposed_sub_order) AS sub_order
        FROM ops.v_lor_reconciliation_group_review AS gr
        JOIN ops.lor_reconciliation_action AS a
          ON a.lor_reconciliation_action_id = gr.effective_action_id
        JOIN ops.lor_reconciliation_stage_candidate AS c
          ON c.lor_reconciliation_group_id = gr.lor_reconciliation_group_id
        WHERE gr.lor_reconciliation_run_id = p_lor_reconciliation_run_id
          AND gr.effective_action_type = 'APPROVE_STAGE_CHANGE'
          AND gr.effective_resolution_state = 'APPROVED'
          AND ops.f_stage_group_can_approve_change(
                gr.lor_reconciliation_group_id)
        GROUP BY gr.lor_reconciliation_group_id, a.action_payload
    LOOP
        SELECT s.stage_key INTO v_old_stage_key
        FROM ref.stage AS s
        WHERE s.stage_id = v_change.stage_id
        FOR UPDATE;

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
               updated_at = now(), updated_by = current_user
         WHERE s.stage_id = v_change.stage_id;

        INSERT INTO ops.lor_reconciliation_result (
            lor_reconciliation_run_id, import_run_id, entity_type,
            entity_key, result_class, reason_code, operator_message, committed
        ) VALUES (
            p_lor_reconciliation_run_id, v_import_run_id, 'STAGE',
            v_change.stage_id::text, 'UPDATED',
            'P1_APPROVED_STAGE_KEY_CHANGE',
            format('UPDATED: Stage %s to canonical StageID %s and preserved permanent stage_id %s.',
                v_old_stage_key, v_change.target_stage_key,
                v_change.stage_id), true
        );
    END LOOP;

    UPDATE ref.stage_lor_binding AS b
       SET accepted_source_stage_key = c.source_stage_key,
           updated_at = now(), updated_by = current_user
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
'Reconciliation-gated P1. Treats simultaneous main/substage keys as distinct permanent stages, requires unanimous evidence for a true canonical rename, and preserves stable bindings.';


REVOKE EXECUTE ON PROCEDURE
    ref.p1_promote_stage_from_reconciliation(bigint) FROM PUBLIC;

COMMIT;
