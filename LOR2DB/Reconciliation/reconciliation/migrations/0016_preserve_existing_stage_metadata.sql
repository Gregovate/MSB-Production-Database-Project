/* ============================================================================
Object group: Preserve existing stage metadata for multi-preview stages
Repository:   LOR2DB/Reconciliation/reconciliation/migrations/
File:         0016_preserve_existing_stage_metadata.sql

Purpose:
  Add an explicit stage-only reconciliation action for a permanent stage that
  legitimately has multiple authoritative background previews. The action
  approves every frozen preview binding in the atomic stage group while
  preventing P1 from choosing one preview name as permanent stage metadata.

Safety boundary:
  - Installation changes control functions, review output, and the gated P1
    definition only.
  - Installation records no operator action and does not call P1 or P2.
  - Installation does not modify ref.stage or ref.stage_lor_binding data.
  - Existing append-only actions and frozen candidates remain unchanged.

Revision history:
  2026-08-03  GAL / OpenAI  Initial preserve-metadata stage action and P1 guard.
============================================================================ */

BEGIN;

ALTER TABLE ops.lor_reconciliation_action
    DROP CONSTRAINT ck_lor_reconciliation_action_type;

ALTER TABLE ops.lor_reconciliation_action
    ADD CONSTRAINT ck_lor_reconciliation_action_type CHECK (action_type IN (
        'RENAME_DISPLAY', 'UPDATE_LOR_LINK', 'REASSOCIATE_DISPLAY',
        'ADD_NEW_DISPLAY', 'SET_RETIRED', 'SET_RECYCLED',
        'RESTORE_TO_LOR_REQUIRED', 'CORRECT_SOURCE_REQUIRED',
        'EXCLUDE_NONPHYSICAL', 'DEFER', 'CANCEL_RECONCILIATION',
        'PRESERVE_EXISTING_STAGE_METADATA'
    ));

CREATE OR REPLACE FUNCTION ops.f_stage_group_can_preserve_existing_metadata(
    p_lor_reconciliation_group_id bigint
)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = pg_catalog, ops, ref
AS $function$
    SELECT
        g.entity_type = 'STAGE'
        AND g.decision_required
        AND count(c.*) = g.member_count
        AND count(c.*) > 1
        AND count(DISTINCT c.resolved_stage_id) = 1
        AND count(*) FILTER (WHERE c.resolved_stage_id IS NULL) = 0
        AND count(DISTINCT c.proposed_stage_key) = 1
        AND count(DISTINCT c.proposed_stage_name)
            FILTER (WHERE c.metadata_authoritative) > 1
    FROM ops.lor_reconciliation_group AS g
    JOIN ops.lor_reconciliation_stage_candidate AS c
      ON c.lor_reconciliation_group_id = g.lor_reconciliation_group_id
    WHERE g.lor_reconciliation_group_id = p_lor_reconciliation_group_id
    GROUP BY
        g.lor_reconciliation_group_id,
        g.entity_type,
        g.decision_required,
        g.member_count;
$function$;

COMMENT ON FUNCTION
    ops.f_stage_group_can_preserve_existing_metadata(bigint) IS
'True only for a decision-required stage group whose complete frozen membership resolves to one existing permanent stage and contains conflicting authoritative preview names.';

CREATE OR REPLACE FUNCTION ops.f_record_lor_stage_preserve_metadata_action(
    p_lor_reconciliation_run_id bigint,
    p_lor_reconciliation_group_id bigint,
    p_reason text,
    p_acted_by_application text DEFAULT NULL
)
RETURNS bigint
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, ops, lor_snap, ref
AS $function$
DECLARE
    v_import_run_id bigint;
    v_status text;
    v_action_id bigint;
BEGIN
    SELECT r.import_run_id, r.status
      INTO v_import_run_id, v_status
    FROM ops.lor_reconciliation_run AS r
    WHERE r.lor_reconciliation_run_id = p_lor_reconciliation_run_id
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Reconciliation run % does not exist',
            p_lor_reconciliation_run_id;
    END IF;

    IF v_status NOT IN ('AWAITING_DECISIONS', 'READY_TO_FINISH') THEN
        RAISE EXCEPTION 'Reconciliation run % does not accept decisions in status %',
            p_lor_reconciliation_run_id, v_status;
    END IF;

    IF NOT EXISTS (
        SELECT 1
        FROM ops.lor_reconciliation_group AS g
        WHERE g.lor_reconciliation_group_id =
                p_lor_reconciliation_group_id
          AND g.lor_reconciliation_run_id =
                p_lor_reconciliation_run_id
          AND g.entity_type = 'STAGE'
    ) THEN
        RAISE EXCEPTION 'Stage group % does not belong to reconciliation run %',
            p_lor_reconciliation_group_id, p_lor_reconciliation_run_id;
    END IF;

    IF NOT coalesce(
        ops.f_stage_group_can_preserve_existing_metadata(
            p_lor_reconciliation_group_id
        ),
        false
    ) THEN
        RAISE EXCEPTION
            'Stage group % is not eligible to preserve existing metadata',
            p_lor_reconciliation_group_id;
    END IF;

    IF nullif(btrim(p_reason), '') IS NULL THEN
        RAISE EXCEPTION 'A nonblank operator reason is required';
    END IF;

    INSERT INTO ops.lor_reconciliation_action (
        lor_reconciliation_run_id,
        lor_reconciliation_group_id,
        import_run_id,
        action_type,
        reason,
        action_payload,
        acted_by_application
    ) VALUES (
        p_lor_reconciliation_run_id,
        p_lor_reconciliation_group_id,
        v_import_run_id,
        'PRESERVE_EXISTING_STAGE_METADATA',
        btrim(p_reason),
        jsonb_build_object(
            'preserve_stage_metadata', true,
            'approve_all_frozen_bindings', true
        ),
        nullif(btrim(p_acted_by_application), '')
    )
    RETURNING lor_reconciliation_action_id INTO v_action_id;

    /* Refresh the same durable counters used by the generic action recorder. */
    WITH latest_action AS (
        SELECT DISTINCT ON (a.lor_reconciliation_group_id)
            a.lor_reconciliation_group_id,
            a.action_type
        FROM ops.lor_reconciliation_action AS a
        WHERE a.lor_reconciliation_run_id = p_lor_reconciliation_run_id
          AND a.lor_reconciliation_group_id IS NOT NULL
        ORDER BY
            a.lor_reconciliation_group_id,
            a.acted_at DESC,
            a.lor_reconciliation_action_id DESC
    ),
    counts AS (
        SELECT
            count(*) FILTER (
                WHERE g.decision_required
                  AND la.lor_reconciliation_group_id IS NULL
            )::integer AS unresolved_count,
            count(*) FILTER (
                WHERE la.action_type = 'DEFER'
            )::integer AS deferred_count,
            count(*) FILTER (
                WHERE la.action_type IN (
                    'CORRECT_SOURCE_REQUIRED', 'RESTORE_TO_LOR_REQUIRED'
                )
                   OR (
                        la.lor_reconciliation_group_id IS NULL
                    AND EXISTS (
                        SELECT 1
                        FROM ops.lor_reconciliation_display_candidate AS c
                        WHERE c.lor_reconciliation_group_id =
                                g.lor_reconciliation_group_id
                          AND c.initial_resolution_state = 'BLOCKED'
                    )
                   )
            )::integer AS blocked_count
        FROM ops.lor_reconciliation_group AS g
        LEFT JOIN latest_action AS la
          ON la.lor_reconciliation_group_id = g.lor_reconciliation_group_id
        WHERE g.lor_reconciliation_run_id = p_lor_reconciliation_run_id
    )
    UPDATE ops.lor_reconciliation_run AS r
       SET unresolved_count = counts.unresolved_count,
           deferred_count = counts.deferred_count,
           blocked_count = counts.blocked_count,
           status = CASE WHEN counts.unresolved_count = 0
                         THEN 'READY_TO_FINISH'
                         ELSE 'AWAITING_DECISIONS' END,
           resumed_at = now(),
           paused_at = CASE WHEN counts.unresolved_count > 0
                            THEN coalesce(r.paused_at, now())
                            ELSE r.paused_at END
    FROM counts
    WHERE r.lor_reconciliation_run_id = p_lor_reconciliation_run_id;

    RETURN v_action_id;
END;
$function$;

COMMENT ON FUNCTION ops.f_record_lor_stage_preserve_metadata_action(
    bigint, bigint, text, text
) IS
'Records the stage-only decision that preserves permanent ref.stage metadata while approving every frozen LOR binding in an eligible multi-preview group.';

CREATE OR REPLACE VIEW ops.v_lor_reconciliation_group_review AS
WITH latest_action AS (
    SELECT DISTINCT ON (a.lor_reconciliation_group_id)
        a.lor_reconciliation_group_id,
        a.lor_reconciliation_action_id,
        a.action_type,
        a.reason,
        a.acted_at,
        a.acted_by,
        a.acted_by_application
    FROM ops.lor_reconciliation_action AS a
    WHERE a.lor_reconciliation_group_id IS NOT NULL
    ORDER BY
        a.lor_reconciliation_group_id,
        a.acted_at DESC,
        a.lor_reconciliation_action_id DESC
)
SELECT
    g.lor_reconciliation_group_id,
    g.lor_reconciliation_run_id,
    g.import_run_id,
    g.entity_type,
    g.logical_group_key,
    g.group_kind,
    g.member_count,
    g.requires_atomic_decision,
    g.decision_required,
    CASE
        WHEN ops.f_stage_group_can_preserve_existing_metadata(
                g.lor_reconciliation_group_id
             )
         AND NOT (
             'PRESERVE_EXISTING_STAGE_METADATA' =
                ANY(g.allowed_action_types)
         )
        THEN array_append(
            g.allowed_action_types,
            'PRESERVE_EXISTING_STAGE_METADATA'
        )
        ELSE g.allowed_action_types
    END AS allowed_action_types,
    g.operator_message,
    la.lor_reconciliation_action_id AS effective_action_id,
    la.action_type AS effective_action_type,
    la.reason AS effective_reason,
    la.acted_at,
    la.acted_by,
    la.acted_by_application,
    CASE
        WHEN la.action_type = 'DEFER' THEN 'DEFERRED'
        WHEN la.action_type = 'CORRECT_SOURCE_REQUIRED' THEN 'BLOCKED'
        WHEN la.action_type IS NOT NULL THEN 'APPROVED'
        WHEN g.decision_required THEN 'UNRESOLVED'
        ELSE 'AUTO_APPROVED'
    END AS effective_resolution_state
FROM ops.lor_reconciliation_group AS g
LEFT JOIN latest_action AS la
  ON la.lor_reconciliation_group_id = g.lor_reconciliation_group_id;

COMMENT ON VIEW ops.v_lor_reconciliation_group_review IS
'One row per persisted logical group with its latest append-only action, effective state, and stage-preservation action exposed only for eligible multi-preview stage groups.';

CREATE OR REPLACE PROCEDURE ref.p1_promote_stage_from_reconciliation(
    p_lor_reconciliation_run_id bigint
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, ops, lor_snap, ref
AS $procedure$
DECLARE
    v_import_run_id bigint;
    v_status text;
    v_unresolved integer;
    v_bad_source integer;
    v_stage record;
    v_binding record;
BEGIN
    SELECT r.import_run_id, r.status
      INTO v_import_run_id, v_status
    FROM ops.lor_reconciliation_run AS r
    WHERE r.lor_reconciliation_run_id = p_lor_reconciliation_run_id
    FOR UPDATE;

    IF v_import_run_id IS NULL THEN
        RAISE EXCEPTION 'Reconciliation run % does not exist',
            p_lor_reconciliation_run_id;
    END IF;

    IF v_status NOT IN ('READY_TO_FINISH', 'PROMOTING') THEN
        RAISE EXCEPTION 'Reconciliation run % is %, not ready for P1',
            p_lor_reconciliation_run_id, v_status;
    END IF;

    SELECT count(*) INTO v_unresolved
    FROM ops.v_lor_reconciliation_group_review AS gr
    WHERE gr.lor_reconciliation_run_id = p_lor_reconciliation_run_id
      AND gr.entity_type = 'STAGE'
      AND gr.effective_resolution_state = 'UNRESOLVED';

    IF v_unresolved > 0 THEN
        RAISE EXCEPTION 'Reconciliation run % has % unresolved stage groups',
            p_lor_reconciliation_run_id, v_unresolved;
    END IF;

    SELECT count(*) INTO v_bad_source
    FROM ops.lor_reconciliation_stage_candidate AS c
    WHERE c.lor_reconciliation_run_id = p_lor_reconciliation_run_id
      AND NOT (
          (c.binding_type = 'PREVIEW' AND EXISTS (
              SELECT 1 FROM lor_snap.previews AS p
              WHERE p.import_run_id = v_import_run_id
                AND p.id = c.preview_id
                AND lower(btrim(p.stage_id)) = c.source_stage_key
                AND btrim(p.name) IS NOT DISTINCT FROM c.source_name
          ))
          OR
          (c.binding_type = 'SCENE' AND EXISTS (
              SELECT 1
              FROM lor_snap.scenes AS s
              JOIN lor_snap.scene_lor_props AS slp
                ON slp.import_run_id = s.import_run_id
               AND slp.preview_id = s.preview_id
               AND slp.scene_id = s.scene_id
              WHERE s.import_run_id = v_import_run_id
                AND s.preview_id = c.preview_id
                AND s.scene_id = c.scene_id
                AND lower(btrim(coalesce(slp.scene_stage_id, s.stage_id))) =
                    c.source_stage_key
                AND btrim(s.name) IS NOT DISTINCT FROM c.source_name
          ))
      );

    IF v_bad_source > 0 THEN
        RAISE EXCEPTION '% frozen stage candidates no longer match captured import_run_id %',
            v_bad_source, v_import_run_id;
    END IF;

    FOR v_stage IN
        SELECT
            c.resolved_stage_id,
            min(c.proposed_stage_key) AS proposed_stage_key,
            min(c.proposed_stage_name) FILTER (WHERE c.metadata_authoritative)
                AS proposed_stage_name,
            min(c.proposed_folder_name) FILTER (WHERE c.metadata_authoritative)
                AS proposed_folder_name,
            min(c.proposed_park_order) AS proposed_park_order,
            min(c.proposed_sub_order) AS proposed_sub_order
        FROM ops.lor_reconciliation_stage_candidate AS c
        JOIN ops.v_lor_reconciliation_group_review AS gr
          ON gr.lor_reconciliation_group_id = c.lor_reconciliation_group_id
        WHERE c.lor_reconciliation_run_id = p_lor_reconciliation_run_id
          AND c.resolved_stage_id IS NOT NULL
          AND gr.effective_resolution_state IN ('AUTO_APPROVED', 'APPROVED')
          AND gr.effective_action_type IS DISTINCT FROM
                'PRESERVE_EXISTING_STAGE_METADATA'
        GROUP BY c.resolved_stage_id
        HAVING count(DISTINCT c.proposed_stage_key) = 1
    LOOP
        UPDATE ref.stage AS s
           SET stage_key = v_stage.proposed_stage_key,
               stage_name = coalesce(v_stage.proposed_stage_name, s.stage_name),
               folder_name = coalesce(v_stage.proposed_folder_name, s.folder_name),
               park_order = v_stage.proposed_park_order,
               sub_order = v_stage.proposed_sub_order,
               updated_at = now(),
               updated_by = current_user
         WHERE s.stage_id = v_stage.resolved_stage_id
           AND (
               s.stage_key IS DISTINCT FROM v_stage.proposed_stage_key
               OR (v_stage.proposed_stage_name IS NOT NULL
                   AND s.stage_name IS DISTINCT FROM v_stage.proposed_stage_name)
               OR (v_stage.proposed_folder_name IS NOT NULL
                   AND s.folder_name IS DISTINCT FROM v_stage.proposed_folder_name)
               OR s.park_order IS DISTINCT FROM v_stage.proposed_park_order
               OR s.sub_order IS DISTINCT FROM v_stage.proposed_sub_order
           );

        IF FOUND THEN
            INSERT INTO ops.lor_reconciliation_result (
                lor_reconciliation_run_id, import_run_id, entity_type,
                entity_key, result_class, reason_code, operator_message, committed
            ) VALUES (
                p_lor_reconciliation_run_id, v_import_run_id, 'STAGE',
                v_stage.resolved_stage_id::text, 'UPDATED',
                'P1_STAGE_METADATA',
                format('UPDATED: Stage %s metadata and preserved permanent stage_id %s.',
                    v_stage.proposed_stage_key, v_stage.resolved_stage_id),
                true
            );
        END IF;
    END LOOP;

    FOR v_binding IN
        SELECT c.*
        FROM ops.lor_reconciliation_stage_candidate AS c
        JOIN ops.v_lor_reconciliation_group_review AS gr
          ON gr.lor_reconciliation_group_id = c.lor_reconciliation_group_id
        WHERE c.lor_reconciliation_run_id = p_lor_reconciliation_run_id
          AND c.resolved_stage_id IS NOT NULL
          AND gr.effective_resolution_state IN ('AUTO_APPROVED', 'APPROVED')
    LOOP
        INSERT INTO ref.stage_lor_binding (
            stage_id, binding_type, preview_id, scene_id, source_name,
            first_seen_import_run_id, last_seen_import_run_id
        ) VALUES (
            v_binding.resolved_stage_id, v_binding.binding_type,
            v_binding.preview_id, v_binding.scene_id, v_binding.source_name,
            v_import_run_id, v_import_run_id
        )
        ON CONFLICT DO NOTHING;

        IF FOUND THEN
            INSERT INTO ops.lor_reconciliation_result (
                lor_reconciliation_run_id, import_run_id, entity_type,
                entity_key, result_class, reason_code, operator_message, committed
            ) VALUES (
                p_lor_reconciliation_run_id, v_import_run_id, 'STAGE',
                v_binding.candidate_key, 'ADDED', 'P1_STAGE_LOR_BINDING',
                format('ADDED: %s binding %s%s to permanent stage_id %s.',
                    v_binding.binding_type,
                    v_binding.preview_id,
                    CASE WHEN v_binding.scene_id IS NULL THEN ''
                         ELSE '/' || v_binding.scene_id END,
                    v_binding.resolved_stage_id),
                true
            );
        END IF;

        UPDATE ref.stage_lor_binding AS b
           SET source_name = v_binding.source_name,
               last_seen_import_run_id = v_import_run_id,
               updated_at = now(),
               updated_by = current_user
         WHERE b.binding_type = v_binding.binding_type
           AND b.preview_id = v_binding.preview_id
           AND b.scene_id IS NOT DISTINCT FROM v_binding.scene_id
           AND b.stage_id = v_binding.resolved_stage_id
           AND (
               b.source_name IS DISTINCT FROM v_binding.source_name
               OR b.last_seen_import_run_id IS DISTINCT FROM v_import_run_id
           );

        IF FOUND THEN
            INSERT INTO ops.lor_reconciliation_result (
                lor_reconciliation_run_id, import_run_id, entity_type,
                entity_key, result_class, reason_code, operator_message, committed
            ) VALUES (
                p_lor_reconciliation_run_id, v_import_run_id, 'STAGE',
                v_binding.candidate_key, 'UPDATED', 'P1_STAGE_LOR_BINDING',
                format('UPDATED: %s binding %s%s for permanent stage_id %s.',
                    v_binding.binding_type,
                    v_binding.preview_id,
                    CASE WHEN v_binding.scene_id IS NULL THEN ''
                         ELSE '/' || v_binding.scene_id END,
                    v_binding.resolved_stage_id),
                true
            );
        END IF;
    END LOOP;
END;
$procedure$;

COMMENT ON PROCEDURE ref.p1_promote_stage_from_reconciliation(bigint) IS
'Internal reconciliation-gated P1. Promotes approved frozen stage metadata except where explicitly preserved, binds all approved LOR identities, never selects an ingest, and never deletes stages.';

REVOKE EXECUTE ON FUNCTION
    ops.f_stage_group_can_preserve_existing_metadata(bigint) FROM PUBLIC;
REVOKE EXECUTE ON FUNCTION
    ops.f_record_lor_stage_preserve_metadata_action(bigint,bigint,text,text)
    FROM PUBLIC;
REVOKE EXECUTE ON PROCEDURE
    ref.p1_promote_stage_from_reconciliation(bigint) FROM PUBLIC;

COMMIT;

SELECT
    '2026-08-03-preserve-existing-stage-metadata-v1'::text
        AS installed_revision,
    to_regprocedure(
        'ops.f_stage_group_can_preserve_existing_metadata(bigint)'
    ) IS NOT NULL AS has_stage_eligibility_function,
    to_regprocedure(
        'ops.f_record_lor_stage_preserve_metadata_action(bigint,bigint,text,text)'
    ) IS NOT NULL AS has_stage_preserve_action_function,
    to_regprocedure(
        'ref.p1_promote_stage_from_reconciliation(bigint)'
    ) IS NOT NULL AS has_updated_p1_procedure;
