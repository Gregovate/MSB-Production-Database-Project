/*
Migration: 0033_approve_stage_key_changes_with_stable_aliases.sql
Purpose:
  Permit an operator-approved canonical StageID change when one or more stable
  LOR bindings still retain previously accepted StageIDs. Preserve permanent
  stage_id, remember each binding's accepted source StageID, expose complete
  frozen evidence, and prevent the same accepted aliases from reopening on
  every later reconciliation.
*/

BEGIN;

ALTER TABLE ref.stage_lor_binding
    ADD COLUMN IF NOT EXISTS accepted_source_stage_key text;

/*
  Migration 0029 intentionally suppresses provenance-only binding updates.
  The accepted source StageID is durable business state, so include it in the
  trigger's material-change comparison before backfilling the new column.
*/
CREATE OR REPLACE FUNCTION ref.trg_stage_lor_binding_require_change()
RETURNS trigger
LANGUAGE plpgsql
AS $function$
BEGIN
    IF NEW.stage_id IS NOT DISTINCT FROM OLD.stage_id
       AND NEW.binding_type IS NOT DISTINCT FROM OLD.binding_type
       AND NEW.preview_id IS NOT DISTINCT FROM OLD.preview_id
       AND NEW.scene_id IS NOT DISTINCT FROM OLD.scene_id
       AND NEW.source_name IS NOT DISTINCT FROM OLD.source_name
       AND NEW.accepted_source_stage_key IS NOT DISTINCT FROM
           OLD.accepted_source_stage_key THEN
        RETURN NULL;
    END IF;
    RETURN NEW;
END;
$function$;

UPDATE ref.stage_lor_binding AS b
   SET accepted_source_stage_key = s.stage_key,
       updated_at = now(),
       updated_by = current_user
FROM ref.stage AS s
WHERE s.stage_id = b.stage_id
  AND b.accepted_source_stage_key IS NULL;

COMMENT ON COLUMN ref.stage_lor_binding.accepted_source_stage_key IS
'Last operator-approved source StageID for this stable LOR preview/scene binding. It may differ from the permanent stage''s canonical stage_key.';

CREATE OR REPLACE FUNCTION ops.f_stage_group_has_only_accepted_binding_keys(
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
        AND count(c.*) = g.member_count
        AND count(c.*) > 0
        AND count(*) FILTER (WHERE c.resolved_stage_id IS NULL) = 0
        AND count(*) FILTER (WHERE b.stage_lor_binding_id IS NULL) = 0
        AND count(*) FILTER (
            WHERE b.accepted_source_stage_key IS DISTINCT FROM
                c.source_stage_key
        ) = 0
        AND count(*) FILTER (WHERE c.classification_code IN (
            'SOURCE_FILENAME_MISSING',
            'BINDING_STAGE_KEY_CONFLICT',
            'NEW_STAGE_REQUIRES_AUTHORITATIVE_DECISION'
        )) = 0
    FROM ops.lor_reconciliation_group AS g
    JOIN ops.lor_reconciliation_stage_candidate AS c
      ON c.lor_reconciliation_group_id = g.lor_reconciliation_group_id
    LEFT JOIN ref.stage_lor_binding AS b
      ON b.binding_type = c.binding_type
     AND b.preview_id = c.preview_id
     AND b.scene_id IS NOT DISTINCT FROM c.scene_id
     AND b.stage_id = c.resolved_stage_id
    WHERE g.lor_reconciliation_group_id = p_lor_reconciliation_group_id
    GROUP BY g.lor_reconciliation_group_id, g.entity_type, g.member_count;
$function$;

CREATE OR REPLACE FUNCTION ops.f_stage_group_can_approve_change(
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
        AND count(c.*) > 0
        AND count(DISTINCT c.resolved_stage_id) = 1
        AND count(*) FILTER (WHERE c.resolved_stage_id IS NULL) = 0
        AND count(*) FILTER (WHERE b.stage_lor_binding_id IS NULL) = 0
        AND count(*) FILTER (
            WHERE b.accepted_source_stage_key IS DISTINCT FROM
                c.source_stage_key
        ) > 0
        AND count(DISTINCT c.proposed_stage_key) FILTER (
            WHERE b.accepted_source_stage_key IS DISTINCT FROM
                c.source_stage_key
        ) = 1
        AND count(*) FILTER (
            WHERE c.stage_key_stage_id IS NOT NULL
              AND c.stage_key_stage_id <> c.resolved_stage_id
        ) = 0
        AND count(*) FILTER (WHERE c.classification_code IN (
            'SOURCE_FILENAME_MISSING',
            'BINDING_STAGE_KEY_CONFLICT',
            'NEW_STAGE_REQUIRES_AUTHORITATIVE_DECISION'
        )) = 0
    FROM ops.lor_reconciliation_group AS g
    JOIN ops.lor_reconciliation_stage_candidate AS c
      ON c.lor_reconciliation_group_id = g.lor_reconciliation_group_id
    LEFT JOIN ref.stage_lor_binding AS b
      ON b.binding_type = c.binding_type
     AND b.preview_id = c.preview_id
     AND b.scene_id IS NOT DISTINCT FROM c.scene_id
     AND b.stage_id = c.resolved_stage_id
    WHERE g.lor_reconciliation_group_id = p_lor_reconciliation_group_id
    GROUP BY g.lor_reconciliation_group_id, g.entity_type,
             g.decision_required, g.member_count;
$function$;

CREATE OR REPLACE VIEW ops.v_lor_reconciliation_group_review AS
WITH latest_action AS (
    SELECT DISTINCT ON (a.lor_reconciliation_group_id)
        a.lor_reconciliation_group_id,
        a.lor_reconciliation_action_id,
        a.action_type,
        a.reason,
        a.action_payload,
        a.acted_at,
        a.acted_by,
        a.acted_by_application
    FROM ops.lor_reconciliation_action AS a
    WHERE a.lor_reconciliation_group_id IS NOT NULL
    ORDER BY a.lor_reconciliation_group_id, a.acted_at DESC,
             a.lor_reconciliation_action_id DESC
), accepted_binding_keys AS (
    SELECT
        g.lor_reconciliation_group_id,
        ops.f_stage_group_has_only_accepted_binding_keys(
            g.lor_reconciliation_group_id
        ) AS all_keys_accepted
    FROM ops.lor_reconciliation_group AS g
    WHERE g.entity_type = 'STAGE'
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
    g.decision_required AND NOT coalesce(abk.all_keys_accepted, false)
        AS decision_required,
    CASE WHEN coalesce(abk.all_keys_accepted, false)
        THEN ARRAY[]::text[] ELSE g.allowed_action_types END
        || CASE WHEN ops.f_stage_group_can_preserve_existing_metadata(
                g.lor_reconciliation_group_id)
            THEN ARRAY['PRESERVE_EXISTING_STAGE_METADATA']::text[]
            ELSE ARRAY[]::text[] END
        || CASE WHEN ops.f_stage_group_can_approve_change(
                g.lor_reconciliation_group_id)
            THEN ARRAY['APPROVE_STAGE_CHANGE']::text[]
            ELSE ARRAY[]::text[] END
        || CASE WHEN ops.f_stage_group_can_add_new_stage(
                g.lor_reconciliation_group_id)
            THEN ARRAY['ADD_NEW_STAGE']::text[]
            ELSE ARRAY[]::text[] END
        AS allowed_action_types,
    CASE WHEN coalesce(abk.all_keys_accepted, false)
        THEN 'Stable LOR bindings retain previously approved source StageIDs for this permanent stage.'
        ELSE g.operator_message END AS operator_message,
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
        WHEN coalesce(abk.all_keys_accepted, false) THEN 'AUTO_APPROVED'
        WHEN g.decision_required THEN 'UNRESOLVED'
        ELSE 'AUTO_APPROVED'
    END AS effective_resolution_state
FROM ops.lor_reconciliation_group AS g
LEFT JOIN latest_action AS la
  ON la.lor_reconciliation_group_id = g.lor_reconciliation_group_id
LEFT JOIN accepted_binding_keys AS abk
  ON abk.lor_reconciliation_group_id = g.lor_reconciliation_group_id;

CREATE OR REPLACE VIEW ops.v_lor_reconciliation_operator_stage_review AS
SELECT
    gr.lor_reconciliation_run_id,
    gr.import_run_id,
    gr.lor_reconciliation_group_id,
    gr.logical_group_key,
    gr.member_count,
    gr.effective_resolution_state,
    gr.effective_action_type,
    gr.effective_reason,
    c.lor_reconciliation_stage_candidate_id,
    c.binding_type,
    c.preview_id,
    c.scene_id,
    c.source_name,
    c.classification_code,
    c.changed_fields,
    c.resolved_stage_id,
    c.current_stage_key,
    c.proposed_stage_key,
    c.current_stage_name,
    CASE WHEN c.metadata_authoritative
        THEN ops.f_normalize_lor_stage_name(
            c.source_name, c.proposed_stage_key)
        ELSE c.proposed_stage_name END AS proposed_stage_name,
    c.current_folder_name,
    CASE WHEN c.metadata_authoritative
        THEN c.proposed_stage_key || '-' ||
            ops.f_normalize_lor_stage_name(
                c.source_name, c.proposed_stage_key)
        ELSE c.proposed_folder_name END AS proposed_folder_name,
    c.operator_message,
    c.source_evidence,
    c.source_stage_key,
    c.metadata_authoritative
FROM ops.v_lor_reconciliation_group_review AS gr
JOIN ops.lor_reconciliation_stage_candidate AS c
  ON c.lor_reconciliation_group_id = gr.lor_reconciliation_group_id
WHERE gr.decision_required
   OR gr.effective_action_type IS NOT NULL;

CREATE OR REPLACE FUNCTION ops.f_record_lor_stage_authority_action(
    p_lor_reconciliation_run_id bigint,
    p_lor_reconciliation_group_id bigint,
    p_action_type text,
    p_reason text,
    p_acted_by_application text DEFAULT NULL
)
RETURNS bigint
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, ops, ref
AS $function$
DECLARE
    v_import_run_id bigint;
    v_status text;
    v_action_id bigint;
    v_counts record;
    v_target_stage_key text;
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
    IF nullif(btrim(p_reason), '') IS NULL THEN
        RAISE EXCEPTION 'A nonblank operator reason is required';
    END IF;

    IF p_action_type = 'APPROVE_STAGE_CHANGE' THEN
        IF NOT coalesce(ops.f_stage_group_can_approve_change(
            p_lor_reconciliation_group_id), false) THEN
            RAISE EXCEPTION 'Stage group % does not contain one operator-selectable canonical StageID change',
                p_lor_reconciliation_group_id;
        END IF;

        SELECT min(c.proposed_stage_key)
          INTO v_target_stage_key
        FROM ops.lor_reconciliation_stage_candidate AS c
        JOIN ref.stage_lor_binding AS b
          ON b.binding_type = c.binding_type
         AND b.preview_id = c.preview_id
         AND b.scene_id IS NOT DISTINCT FROM c.scene_id
         AND b.stage_id = c.resolved_stage_id
        WHERE c.lor_reconciliation_group_id =
            p_lor_reconciliation_group_id
          AND b.accepted_source_stage_key IS DISTINCT FROM
            c.source_stage_key;
    ELSIF p_action_type = 'ADD_NEW_STAGE' THEN
        IF NOT coalesce(ops.f_stage_group_can_add_new_stage(
            p_lor_reconciliation_group_id), false) THEN
            RAISE EXCEPTION 'Stage group % does not contain one unambiguous new stage',
                p_lor_reconciliation_group_id;
        END IF;

        SELECT min(c.proposed_stage_key)
          INTO v_target_stage_key
        FROM ops.lor_reconciliation_stage_candidate AS c
        WHERE c.lor_reconciliation_group_id =
            p_lor_reconciliation_group_id;
    ELSE
        RAISE EXCEPTION 'Action % is not a stage authority action', p_action_type;
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM ops.lor_reconciliation_group AS g
        WHERE g.lor_reconciliation_group_id = p_lor_reconciliation_group_id
          AND g.lor_reconciliation_run_id = p_lor_reconciliation_run_id
          AND g.entity_type = 'STAGE'
    ) THEN
        RAISE EXCEPTION 'Stage group % does not belong to reconciliation run %',
            p_lor_reconciliation_group_id, p_lor_reconciliation_run_id;
    END IF;

    INSERT INTO ops.lor_reconciliation_action (
        lor_reconciliation_run_id, lor_reconciliation_group_id,
        import_run_id, action_type, reason, action_payload,
        acted_by_application
    ) VALUES (
        p_lor_reconciliation_run_id, p_lor_reconciliation_group_id,
        v_import_run_id, p_action_type, btrim(p_reason),
        jsonb_build_object(
            'stage_authority_decision', true,
            'target_stage_key', v_target_stage_key
        ),
        nullif(btrim(p_acted_by_application), '')
    ) RETURNING lor_reconciliation_action_id INTO v_action_id;

    SELECT * INTO v_counts
    FROM ops.f_sync_lor_reconciliation_effective_counters(
        p_lor_reconciliation_run_id
    );

    UPDATE ops.lor_reconciliation_run AS r
       SET status = CASE WHEN v_counts.unresolved_count = 0
                         THEN 'READY_TO_FINISH'
                         ELSE 'AWAITING_DECISIONS' END,
           resumed_at = now(),
           paused_at = CASE WHEN v_counts.unresolved_count > 0
                            THEN coalesce(r.paused_at, now())
                            ELSE r.paused_at END
     WHERE r.lor_reconciliation_run_id = p_lor_reconciliation_run_id;

    RETURN v_action_id;
END;
$function$;

ALTER PROCEDURE ref.p1_promote_stage_from_reconciliation(bigint)
    RENAME TO p1_promote_stage_from_reconciliation_before_0033;

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

REVOKE EXECUTE ON FUNCTION
    ops.f_stage_group_has_only_accepted_binding_keys(bigint) FROM PUBLIC;
REVOKE EXECUTE ON FUNCTION
    ops.f_stage_group_can_approve_change(bigint) FROM PUBLIC;
REVOKE EXECUTE ON PROCEDURE
    ref.p1_promote_stage_from_reconciliation_before_0033(bigint) FROM PUBLIC;
REVOKE EXECUTE ON PROCEDURE
    ref.p1_promote_stage_from_reconciliation(bigint) FROM PUBLIC;

COMMIT;

SELECT
    '2026-08-16-approved-stage-key-aliases-v1'::text
        AS installed_revision,
    to_regprocedure(
        'ops.f_stage_group_has_only_accepted_binding_keys(bigint)'
    ) IS NOT NULL AS has_binding_key_acceptance_gate,
    true AS complete_stage_evidence_view_installed;
