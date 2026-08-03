/* ============================================================================
Object: Correct installed reconciliation action recorder
Filename: 0018_correct_reconciliation_action_jsonb_count.sql

Purpose:
  Replace the installed action recorder with the repository-approved definition.
  PostgreSQL does not provide jsonb_object_length(jsonb); reassociation member
  validation counts jsonb_each_text() rows instead.

Safety:
  This migration replaces one function definition only. It does not call the
  function, record an action, run P1/P2, or modify ref.stage/ref.display rows.
============================================================================ */

BEGIN;

CREATE OR REPLACE FUNCTION ops.f_record_lor_reconciliation_action(
    p_lor_reconciliation_run_id bigint,
    p_lor_reconciliation_group_id bigint,
    p_action_type text,
    p_reason text,
    p_reassociation_map jsonb DEFAULT NULL,
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
    v_allowed_actions text[];
    v_action_id bigint;
    v_member_count integer;
    v_mapping_count integer;
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

    SELECT g.allowed_action_types, g.member_count
      INTO v_allowed_actions, v_member_count
    FROM ops.lor_reconciliation_group AS g
    WHERE g.lor_reconciliation_group_id = p_lor_reconciliation_group_id
      AND g.lor_reconciliation_run_id = p_lor_reconciliation_run_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Group % does not belong to reconciliation run %',
            p_lor_reconciliation_group_id, p_lor_reconciliation_run_id;
    END IF;

    IF NOT (p_action_type = ANY(v_allowed_actions)) THEN
        RAISE EXCEPTION 'Action % is not allowed for group %; allowed actions are %',
            p_action_type, p_lor_reconciliation_group_id, v_allowed_actions;
    END IF;

    IF nullif(btrim(p_reason), '') IS NULL THEN
        RAISE EXCEPTION 'A nonblank operator reason is required';
    END IF;

    IF p_action_type = 'REASSOCIATE_DISPLAY' THEN
        IF p_reassociation_map IS NULL
           OR jsonb_typeof(p_reassociation_map) <> 'object' THEN
            RAISE EXCEPTION
                'REASSOCIATE_DISPLAY requires a JSON object mapping every candidate ID to one target display_id';
        END IF;

        SELECT count(*)::integer
          INTO v_mapping_count
        FROM jsonb_each_text(p_reassociation_map);

        IF v_mapping_count <> v_member_count THEN
            RAISE EXCEPTION
                'Reassociation map has % members; group % requires exactly %',
                v_mapping_count, p_lor_reconciliation_group_id, v_member_count;
        END IF;

        IF EXISTS (
            SELECT 1
            FROM jsonb_each_text(p_reassociation_map) AS m(candidate_id, target_id)
            LEFT JOIN ops.lor_reconciliation_display_candidate AS c
              ON c.lor_reconciliation_display_candidate_id =
                    m.candidate_id::bigint
             AND c.lor_reconciliation_group_id = p_lor_reconciliation_group_id
            LEFT JOIN ref.display AS d ON d.display_id = m.target_id::bigint
            WHERE c.lor_reconciliation_display_candidate_id IS NULL
               OR d.display_id IS NULL
        ) THEN
            RAISE EXCEPTION
                'Reassociation map contains a candidate outside group % or an unknown target display_id',
                p_lor_reconciliation_group_id;
        END IF;

        IF (
            SELECT count(DISTINCT m.target_id::bigint)
            FROM jsonb_each_text(p_reassociation_map) AS m(candidate_id, target_id)
        ) <> v_member_count THEN
            RAISE EXCEPTION
                'Each reassociation member must map to a different permanent display_id';
        END IF;

        IF EXISTS (
            SELECT 1
            FROM jsonb_each_text(p_reassociation_map) AS m(candidate_id, target_id)
            WHERE NOT EXISTS (
                SELECT 1
                FROM ops.lor_reconciliation_display_candidate AS member
                WHERE member.lor_reconciliation_group_id =
                        p_lor_reconciliation_group_id
                  AND m.target_id::bigint IN (
                        member.display_id,
                        member.uuid_display_id,
                        member.name_display_id
                  )
            )
        ) THEN
            RAISE EXCEPTION
                'A reassociation target is not part of the derived identity component';
        END IF;
    ELSIF p_reassociation_map IS NOT NULL THEN
        RAISE EXCEPTION 'Only REASSOCIATE_DISPLAY accepts a reassociation map';
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
        p_action_type,
        btrim(p_reason),
        CASE WHEN p_reassociation_map IS NULL
             THEN '{}'::jsonb
             ELSE jsonb_build_object('reassociation_map', p_reassociation_map)
        END,
        nullif(btrim(p_acted_by_application), '')
    )
    RETURNING lor_reconciliation_action_id INTO v_action_id;

    IF p_action_type = 'REASSOCIATE_DISPLAY' THEN
        INSERT INTO ops.lor_reconciliation_action_assignment (
            lor_reconciliation_action_id,
            lor_reconciliation_display_candidate_id,
            target_display_id
        )
        SELECT
            v_action_id,
            m.candidate_id::bigint,
            m.target_id::bigint
        FROM jsonb_each_text(p_reassociation_map)
            AS m(candidate_id, target_id);
    END IF;

    /* Refresh durable run counters from the latest action for every group. */
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
                            THEN coalesce(r.paused_at, now()) ELSE r.paused_at END
    FROM counts
    WHERE r.lor_reconciliation_run_id = p_lor_reconciliation_run_id;

    RETURN v_action_id;
END;
$function$;

REVOKE EXECUTE ON FUNCTION ops.f_record_lor_reconciliation_action(
    bigint, bigint, text, text, jsonb, text
) FROM PUBLIC;

COMMENT ON SCHEMA ops IS
'Operational workflow and audit objects. Reconciliation engine revision 2026-08-03-action-jsonb-count-fix installed.';

COMMIT;

SELECT
    '2026-08-03-action-jsonb-count-fix'::text AS installed_revision,
    position(
        'jsonb_object_length' IN
        pg_get_functiondef(
            'ops.f_record_lor_reconciliation_action(bigint,bigint,text,text,jsonb,text)'::regprocedure
        )
    ) = 0 AS invalid_jsonb_function_removed;

