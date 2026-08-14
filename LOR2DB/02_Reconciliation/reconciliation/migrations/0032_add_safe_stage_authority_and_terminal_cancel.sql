/* ============================================================================
Migration: 0032_add_safe_stage_authority_and_terminal_cancel.sql

Purpose:
  Expose explicit authority decisions for unambiguous stage changes and new
  stages while keeping contradictory evidence non-approvable.  New stages are
  created only inside the existing Finish transaction, receive a permanent
  ref.stage.stage_id, and immediately receive their stable LOR bindings.

Safety boundary:
  - Installation records no decisions and changes no production stage rows.
  - Existing frozen candidates remain immutable.
  - Contradictory stage keys/names/folders/orders never receive an approval
    action; only CORRECT_SOURCE_REQUIRED and DEFER remain available.
  - All production writes still occur only through Finish/P1.
  - CANCELLED is a terminal lifecycle state and always receives completed_at;
    existing cancelled audit rows are repaired without changing production.
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
        'PRESERVE_EXISTING_STAGE_METADATA',
        'APPROVE_STAGE_CHANGE', 'ADD_NEW_STAGE'
    ));

CREATE OR REPLACE FUNCTION ops.f_normalize_lor_stage_name(
    p_source_name text,
    p_stage_key text
)
RETURNS text
LANGUAGE sql
IMMUTABLE
SECURITY DEFINER
SET search_path = pg_catalog
AS $function$
    SELECT coalesce(
        nullif(btrim(regexp_replace(
            regexp_replace(
                coalesce(p_source_name, ''),
                '(?i)^\s*(?:(?:show\s+(?:background\s+)?)?stage\s*)?0*'
                    || p_stage_key || '\s*[- ]*\s*',
                ''
            ),
            '\s+(with|w/)\s+.*$', '', 'i'
        )), ''),
        'Stage ' || p_stage_key
    );
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
        AND count(DISTINCT c.proposed_stage_key) = 1
        AND count(DISTINCT ops.f_normalize_lor_stage_name(
            c.source_name, c.proposed_stage_key))
            FILTER (WHERE c.metadata_authoritative) <= 1
        AND count(DISTINCT (
            c.proposed_stage_key || '-' || ops.f_normalize_lor_stage_name(
                c.source_name, c.proposed_stage_key)))
            FILTER (WHERE c.metadata_authoritative) <= 1
        AND count(DISTINCT c.proposed_park_order) <= 1
        AND count(DISTINCT c.proposed_sub_order) <= 1
        AND count(*) FILTER (WHERE c.classification_code IN (
            'SOURCE_FILENAME_MISSING',
            'BINDING_STAGE_KEY_CONFLICT',
            'NEW_STAGE_REQUIRES_AUTHORITATIVE_DECISION'
        )) = 0
        AND count(*) FILTER (
            WHERE c.classification_code = 'BOUND_STAGE_KEY_CHANGED'
        ) > 0
    FROM ops.lor_reconciliation_group AS g
    JOIN ops.lor_reconciliation_stage_candidate AS c
      ON c.lor_reconciliation_group_id = g.lor_reconciliation_group_id
    WHERE g.lor_reconciliation_group_id = p_lor_reconciliation_group_id
    GROUP BY g.lor_reconciliation_group_id, g.entity_type,
             g.decision_required, g.member_count;
$function$;

CREATE OR REPLACE FUNCTION ops.f_stage_group_can_add_new_stage(
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
        AND count(*) FILTER (WHERE c.resolved_stage_id IS NOT NULL) = 0
        AND count(DISTINCT c.proposed_stage_key) = 1
        AND count(*) FILTER (WHERE c.metadata_authoritative) > 0
        AND count(DISTINCT ops.f_normalize_lor_stage_name(
            c.source_name, c.proposed_stage_key))
            FILTER (WHERE c.metadata_authoritative) = 1
        AND count(DISTINCT (
            c.proposed_stage_key || '-' || ops.f_normalize_lor_stage_name(
                c.source_name, c.proposed_stage_key)))
            FILTER (WHERE c.metadata_authoritative) = 1
        AND count(DISTINCT c.proposed_park_order) = 1
        AND count(DISTINCT c.proposed_sub_order) = 1
        AND count(*) FILTER (WHERE c.classification_code <>
            'NEW_STAGE_REQUIRES_AUTHORITATIVE_DECISION') = 0
        AND min(c.proposed_stage_key) NOT IN (
            SELECT s.stage_key FROM ref.stage AS s
            WHERE s.stage_key IS NOT NULL
        )
    FROM ops.lor_reconciliation_group AS g
    JOIN ops.lor_reconciliation_stage_candidate AS c
      ON c.lor_reconciliation_group_id = g.lor_reconciliation_group_id
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
        a.acted_at,
        a.acted_by,
        a.acted_by_application
    FROM ops.lor_reconciliation_action AS a
    WHERE a.lor_reconciliation_group_id IS NOT NULL
    ORDER BY a.lor_reconciliation_group_id, a.acted_at DESC,
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
    g.allowed_action_types
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
'One row per logical group. Safe stage approval actions are derived from complete frozen evidence; contradictory stage groups retain fallback actions only.';

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
WHERE cardinality(c.changed_fields) > 0
   OR c.decision_required
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
            RAISE EXCEPTION 'Stage group % does not contain one consistent existing-stage change',
                p_lor_reconciliation_group_id;
        END IF;
    ELSIF p_action_type = 'ADD_NEW_STAGE' THEN
        IF NOT coalesce(ops.f_stage_group_can_add_new_stage(
            p_lor_reconciliation_group_id), false) THEN
            RAISE EXCEPTION 'Stage group % does not contain one unambiguous new stage',
                p_lor_reconciliation_group_id;
        END IF;
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
        jsonb_build_object('stage_authority_decision', true),
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

/* Preserve the proven existing-stage implementation and wrap it only for the
   new-stage insertion that its frozen resolved_stage_id model cannot express. */
ALTER PROCEDURE ref.p1_promote_stage_from_reconciliation(bigint)
    RENAME TO p1_promote_stage_from_reconciliation_before_0032;

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

/* Report publication historically assigned CANCELLED without completed_at.
   Keep cancelled_at as the cancellation event time and completed_at as the
   terminal lifecycle time.  The trigger also protects every future caller,
   including report-publication retries. */
CREATE OR REPLACE FUNCTION ops.f_set_cancelled_reconciliation_completed_at()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, ops
AS $function$
BEGIN
    IF NEW.status = 'CANCELLED' AND NEW.completed_at IS NULL THEN
        NEW.completed_at := coalesce(
            NEW.report_published_at,
            NEW.cancelled_at,
            clock_timestamp()
        );
    END IF;
    RETURN NEW;
END;
$function$;

DROP TRIGGER IF EXISTS trg_set_cancelled_reconciliation_completed_at
    ON ops.lor_reconciliation_run;

CREATE TRIGGER trg_set_cancelled_reconciliation_completed_at
BEFORE INSERT OR UPDATE OF status, completed_at, cancelled_at,
    report_published_at
ON ops.lor_reconciliation_run
FOR EACH ROW
EXECUTE FUNCTION ops.f_set_cancelled_reconciliation_completed_at();

UPDATE ops.lor_reconciliation_run
   SET completed_at = coalesce(report_published_at, cancelled_at)
 WHERE status = 'CANCELLED'
   AND completed_at IS NULL
   AND cancelled_at IS NOT NULL;

REVOKE EXECUTE ON FUNCTION ops.f_stage_group_can_approve_change(bigint)
    FROM PUBLIC;
REVOKE EXECUTE ON FUNCTION ops.f_normalize_lor_stage_name(text,text)
    FROM PUBLIC;
REVOKE EXECUTE ON FUNCTION ops.f_stage_group_can_add_new_stage(bigint)
    FROM PUBLIC;
REVOKE EXECUTE ON FUNCTION ops.f_record_lor_stage_authority_action(
    bigint,bigint,text,text,text) FROM PUBLIC;
REVOKE EXECUTE ON FUNCTION
    ops.f_set_cancelled_reconciliation_completed_at() FROM PUBLIC;
REVOKE EXECUTE ON PROCEDURE
    ref.p1_promote_stage_from_reconciliation_before_0032(bigint) FROM PUBLIC;
REVOKE EXECUTE ON PROCEDURE
    ref.p1_promote_stage_from_reconciliation(bigint) FROM PUBLIC;

COMMIT;

SELECT
    '2026-08-14-safe-stage-authority-terminal-cancel-v2'::text
        AS installed_revision,
    to_regprocedure(
        'ops.f_record_lor_stage_authority_action(bigint,bigint,text,text,text)'
    ) IS NOT NULL AS has_stage_authority_recorder,
    to_regprocedure(
        'ref.p1_promote_stage_from_reconciliation_before_0032(bigint)'
    ) IS NOT NULL AS preserved_prior_p1;
