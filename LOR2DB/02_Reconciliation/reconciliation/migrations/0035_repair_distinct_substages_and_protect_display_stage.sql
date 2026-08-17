/* ============================================================================
Migration: 0035_repair_distinct_substages_and_protect_display_stage.sql

Purpose:
  Repair the Stage 05/05a production split damaged by reconciliation run 7/8,
  and prevent a permanent stage from being renamed when its frozen evidence
  simultaneously contains the existing main key and a distinct substage key.

Safety:
  - The data repair runs only when the complete, known damaged state matches.
  - Run 7/8 frozen candidates and immutable reports remain unchanged as audit
    evidence of the incident.
  - A canonical stage rename now requires every member to present one key.
  - P2 resolves a stage by the approved source key at Finish time and refuses
    to clear a non-null production stage assignment.
============================================================================ */

BEGIN;

/* A rename is valid only when every member of the permanent stage agrees on
   the same source key.  Mixed 05/05a (or NN/NNa) evidence is not a rename. */
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
        AND count(DISTINCT c.source_stage_key) = 1
        AND count(*) FILTER (
            WHERE b.accepted_source_stage_key IS DISTINCT FROM
                c.source_stage_key
        ) > 0
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

/* Return the one source key that represents a new permanent stage.  This is
   either an entirely unresolved one-key group, or the noncanonical key in a
   two-key group whose other key still equals the resolved permanent stage. */
CREATE OR REPLACE FUNCTION ops.f_stage_group_new_stage_key(
    p_lor_reconciliation_group_id bigint
)
RETURNS text
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = pg_catalog, ops, ref
AS $function$
    WITH evidence AS (
        SELECT c.*, s.stage_key AS resolved_stage_key
        FROM ops.lor_reconciliation_stage_candidate AS c
        LEFT JOIN ref.stage AS s ON s.stage_id = c.resolved_stage_id
        WHERE c.lor_reconciliation_group_id = p_lor_reconciliation_group_id
    ), candidate_key AS (
        SELECT CASE
            WHEN count(*) FILTER (WHERE resolved_stage_id IS NOT NULL) = 0
             AND count(DISTINCT source_stage_key) = 1
                THEN min(source_stage_key)
            WHEN count(DISTINCT resolved_stage_id) = 1
             AND count(*) FILTER (WHERE resolved_stage_id IS NULL) = 0
             AND count(DISTINCT source_stage_key) = 2
             AND count(*) FILTER (
                    WHERE source_stage_key = resolved_stage_key
                 ) > 0
             AND count(DISTINCT source_stage_key) FILTER (
                    WHERE source_stage_key IS DISTINCT FROM resolved_stage_key
                 ) = 1
                THEN min(source_stage_key) FILTER (
                    WHERE source_stage_key IS DISTINCT FROM resolved_stage_key
                )
            ELSE NULL
        END AS stage_key
        FROM evidence
    )
    SELECT ck.stage_key
    FROM candidate_key AS ck
    WHERE ck.stage_key IS NOT NULL
      AND NOT EXISTS (
          SELECT 1 FROM ref.stage AS s WHERE s.stage_key = ck.stage_key
      );
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
    WITH target AS (
        SELECT ops.f_stage_group_new_stage_key(
            p_lor_reconciliation_group_id
        ) AS stage_key
    )
    SELECT
        g.entity_type = 'STAGE'
        AND g.decision_required
        AND t.stage_key IS NOT NULL
        AND count(c.*) = g.member_count
        AND count(c.*) > 0
        AND count(*) FILTER (WHERE c.source_stage_key = t.stage_key) > 0
        AND count(DISTINCT c.proposed_park_order) FILTER (
            WHERE c.source_stage_key = t.stage_key
        ) = 1
        AND count(DISTINCT c.proposed_sub_order) FILTER (
            WHERE c.source_stage_key = t.stage_key
        ) = 1
        AND count(*) FILTER (
            WHERE c.source_stage_key = t.stage_key
              AND c.classification_code IN (
                  'SOURCE_FILENAME_MISSING', 'BINDING_STAGE_KEY_CONFLICT'
              )
        ) = 0
    FROM ops.lor_reconciliation_group AS g
    JOIN ops.lor_reconciliation_stage_candidate AS c
      ON c.lor_reconciliation_group_id = g.lor_reconciliation_group_id
    CROSS JOIN target AS t
    WHERE g.lor_reconciliation_group_id = p_lor_reconciliation_group_id
    GROUP BY g.lor_reconciliation_group_id, g.entity_type,
             g.decision_required, g.member_count, t.stage_key;
$function$;

/* Record the exact new source key.  The P1 wrapper below consumes this frozen
   payload and moves only bindings/candidates carrying that key. */
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
            RAISE EXCEPTION 'Stage group % is not a unanimous canonical StageID change',
                p_lor_reconciliation_group_id;
        END IF;
        SELECT min(c.source_stage_key) INTO v_target_stage_key
        FROM ops.lor_reconciliation_stage_candidate AS c
        WHERE c.lor_reconciliation_group_id =
            p_lor_reconciliation_group_id;
    ELSIF p_action_type = 'ADD_NEW_STAGE' THEN
        IF NOT coalesce(ops.f_stage_group_can_add_new_stage(
            p_lor_reconciliation_group_id), false) THEN
            RAISE EXCEPTION 'Stage group % does not contain one distinct new stage',
                p_lor_reconciliation_group_id;
        END IF;
        v_target_stage_key := ops.f_stage_group_new_stage_key(
            p_lor_reconciliation_group_id
        );
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
                          AND v_counts.blocked_count = 0
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

/* Consume ADD_NEW_STAGE without delegating it through the pre-0032 wrapper,
   because that historical wrapper correctly rejected stable bindings but did
   not know about an operator-approved split. */
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

/* P2 resolves P1-created stages by source key and refuses unresolved stage
   assignments instead of turning a permanent stage_id into NULL. */
CREATE OR REPLACE PROCEDURE ref.p2_promote_display_from_reconciliation(
    p_lor_reconciliation_run_id bigint
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, ops, lor_snap, ref
AS $procedure$
DECLARE
    v_import_run_id bigint;
    v_status text;
    v_active_status_id integer;
    v_retired_status_id integer;
    v_recycled_status_id integer;
    v_bad_source integer;
    v_row record;
    v_display_id bigint;
    v_old_name text;
    v_old_uuid text;
    v_old_stage integer;
    v_old_string_type text;
    v_old_status integer;
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

    IF v_status NOT IN ('READY_TO_FINISH', 'PROMOTING') THEN
        RAISE EXCEPTION 'Reconciliation run % is %, not ready for P2',
            p_lor_reconciliation_run_id, v_status;
    END IF;

    SELECT ds.display_status_id INTO v_active_status_id
    FROM ref.display_status AS ds
    WHERE upper(btrim(ds.display_status_name)) = 'ACTIVE';
    SELECT ds.display_status_id INTO v_retired_status_id
    FROM ref.display_status AS ds
    WHERE upper(btrim(ds.display_status_name)) = 'RETIRED';
    SELECT ds.display_status_id INTO v_recycled_status_id
    FROM ref.display_status AS ds
    WHERE upper(btrim(ds.display_status_name)) = 'RECYCLED';

    IF v_active_status_id IS NULL OR v_retired_status_id IS NULL
       OR v_recycled_status_id IS NULL THEN
        RAISE EXCEPTION 'ACTIVE, RETIRED, and RECYCLED display statuses are required';
    END IF;

    /* Permit idempotency validation to call P2 twice in one transaction. */
    DROP TABLE IF EXISTS pg_temp._lor_p2_plan;

    /* Build the complete effective write plan once from frozen state. */
    CREATE TEMP TABLE pg_temp._lor_p2_plan ON COMMIT DROP AS
    WITH latest_action AS (
        SELECT DISTINCT ON (a.lor_reconciliation_group_id)
            a.lor_reconciliation_group_id,
            a.lor_reconciliation_action_id,
            a.action_type
        FROM ops.lor_reconciliation_action AS a
        WHERE a.lor_reconciliation_run_id = p_lor_reconciliation_run_id
          AND a.lor_reconciliation_group_id IS NOT NULL
        ORDER BY a.lor_reconciliation_group_id,
                 a.acted_at DESC,
                 a.lor_reconciliation_action_id DESC
    )
    SELECT
        c.*,
        coalesce(stage_by_key.stage_id, c.proposed_stage_id)
            AS effective_stage_id,
        la.lor_reconciliation_action_id,
        la.action_type,
        CASE
            WHEN la.action_type = 'REASSOCIATE_DISPLAY' THEN aa.target_display_id
            ELSE c.display_id
        END AS target_display_id
    FROM ops.lor_reconciliation_display_candidate AS c
    JOIN ops.lor_reconciliation_group AS g
      ON g.lor_reconciliation_group_id = c.lor_reconciliation_group_id
    LEFT JOIN latest_action AS la
      ON la.lor_reconciliation_group_id = c.lor_reconciliation_group_id
    LEFT JOIN ops.lor_reconciliation_action_assignment AS aa
      ON aa.lor_reconciliation_action_id = la.lor_reconciliation_action_id
     AND aa.lor_reconciliation_display_candidate_id =
            c.lor_reconciliation_display_candidate_id
    LEFT JOIN ref.stage AS stage_by_key
      ON stage_by_key.stage_key = nullif(btrim(c.proposed_stage_key), '')
    WHERE c.lor_reconciliation_run_id = p_lor_reconciliation_run_id
      AND c.candidate_class = 'PHYSICAL_DISPLAY'
      AND (
          (NOT g.decision_required AND c.initial_resolution_state = 'AUTO_APPROVED')
          OR la.action_type IN (
              'RENAME_DISPLAY', 'UPDATE_LOR_LINK', 'REASSOCIATE_DISPLAY',
              'ADD_NEW_DISPLAY', 'SET_RETIRED', 'SET_RECYCLED'
          )
      );

    IF EXISTS (
        SELECT 1 FROM pg_temp._lor_p2_plan AS p
        WHERE p.action_type = 'REASSOCIATE_DISPLAY'
          AND p.target_display_id IS NULL
    ) THEN
        RAISE EXCEPTION 'An approved reassociation is missing a frozen target mapping';
    END IF;

    /* A stage created by P1 in this same Finish transaction is resolved by
       source StageID here.  Never turn a known assignment into NULL merely
       because the frozen preflight row predates that permanent stage. */
    IF EXISTS (
        SELECT 1 FROM pg_temp._lor_p2_plan AS p
        WHERE nullif(btrim(p.proposed_stage_key), '') IS NOT NULL
          AND p.effective_stage_id IS NULL
    ) THEN
        RAISE EXCEPTION 'P2 cannot resolve one or more approved source StageIDs to permanent stages';
    END IF;

    /* Final write guard: every source-backed plan row must still match Run N. */
    SELECT count(*) INTO v_bad_source
    FROM pg_temp._lor_p2_plan AS p
    WHERE p.source_prop_id IS NOT NULL
      AND NOT EXISTS (
          SELECT 1
          FROM lor_snap.props AS raw
          WHERE raw.import_run_id = v_import_run_id
            AND raw.prop_id = p.source_prop_id
            AND raw.raw_prop_id = p.lor_prop_id
            AND nullif(btrim(raw.lor_comment), '') IS NOT NULL
            AND btrim(raw.lor_comment) = p.proposed_display_name
            AND raw.string_type IS NOT DISTINCT FROM p.proposed_string_type
      );

    IF v_bad_source > 0 THEN
        RAISE EXCEPTION '% P2 candidates fail the captured raw-source guard for import_run_id %',
            v_bad_source, v_import_run_id;
    END IF;

    IF EXISTS (
        SELECT 1 FROM pg_temp._lor_p2_plan AS p
        WHERE p.source_prop_id IS NOT NULL
          AND (
              p.proposed_display_name IS NULL
              OR upper(btrim(p.proposed_display_name)) LIKE '%SPARE%'
              OR upper(btrim(p.proposed_display_name)) LIKE '%PHANTOM%'
          )
    ) THEN
        RAISE EXCEPTION 'P2 plan contains a blank, SPARE, or PHANTOM display';
    END IF;

    /*
      Immediate unique indexes make a chained rename/UUID swap impossible in
      one direct update. Vacate only the approved reassociation targets inside
      this transaction, then assign all final values below. A failure rolls the
      complete group and its temporary values back.
    */
    UPDATE ref.display AS d
       SET display_name = format('__LOR_RECON_%s_%s__',
                                 p_lor_reconciliation_run_id, d.display_id),
           lor_prop_id = format('__LOR_RECON_UUID_%s_%s__',
                                p_lor_reconciliation_run_id, d.display_id)
    WHERE EXISTS (
        SELECT 1
        FROM pg_temp._lor_p2_plan AS p
        WHERE p.action_type = 'REASSOCIATE_DISPLAY'
          AND p.target_display_id = d.display_id
          AND (
              d.display_name IS DISTINCT FROM p.proposed_display_name
              OR d.lor_prop_id IS DISTINCT FROM p.lor_prop_id
          )
    );

    FOR v_row IN
        SELECT * FROM pg_temp._lor_p2_plan
        ORDER BY lor_reconciliation_display_candidate_id
    LOOP
        IF v_row.action_type = 'ADD_NEW_DISPLAY' THEN
            INSERT INTO ref.display (
                lor_prop_id, display_name, inventory_type, display_status_id,
                stage_id, string_type
            ) VALUES (
                v_row.lor_prop_id, v_row.proposed_display_name, 'LOR',
                v_active_status_id, v_row.effective_stage_id,
                v_row.proposed_string_type
            ) RETURNING display_id INTO v_display_id;

            INSERT INTO ops.lor_reconciliation_result (
                lor_reconciliation_run_id, import_run_id, entity_type,
                entity_key, result_class, reason_code, operator_message, committed
            ) VALUES (
                p_lor_reconciliation_run_id, v_import_run_id, 'DISPLAY',
                v_display_id::text, 'ADDED', 'P2_ADD_NEW_DISPLAY',
                format('ADDED: display_id %s as %s.',
                       v_display_id, v_row.proposed_display_name), true
            );
            CONTINUE;
        END IF;

        v_display_id := v_row.target_display_id;
        SELECT d.display_name, d.lor_prop_id, d.stage_id, d.string_type,
               d.display_status_id
          INTO v_old_name, v_old_uuid, v_old_stage, v_old_string_type,
               v_old_status
        FROM ref.display AS d
        WHERE d.display_id = v_display_id;

        IF NOT FOUND THEN
            RAISE EXCEPTION 'P2 target display_id % does not exist', v_display_id;
        END IF;

        IF v_row.action_type = 'SET_RETIRED' THEN
            UPDATE ref.display SET display_status_id = v_retired_status_id
            WHERE display_id = v_display_id
              AND display_status_id IS DISTINCT FROM v_retired_status_id;
        ELSIF v_row.action_type = 'SET_RECYCLED' THEN
            UPDATE ref.display SET display_status_id = v_recycled_status_id
            WHERE display_id = v_display_id
              AND display_status_id IS DISTINCT FROM v_recycled_status_id;
        ELSE
            UPDATE ref.display AS d
               SET lor_prop_id = v_row.lor_prop_id,
                   display_name = v_row.proposed_display_name,
                   stage_id = v_row.effective_stage_id,
                   string_type = v_row.proposed_string_type
             WHERE d.display_id = v_display_id
               AND (
                   d.lor_prop_id IS DISTINCT FROM v_row.lor_prop_id
                   OR d.display_name IS DISTINCT FROM v_row.proposed_display_name
                   OR d.stage_id IS DISTINCT FROM v_row.effective_stage_id
                   OR d.string_type IS DISTINCT FROM v_row.proposed_string_type
               );
        END IF;

        IF FOUND THEN
            INSERT INTO ops.lor_reconciliation_result (
                lor_reconciliation_run_id, import_run_id, entity_type,
                entity_key, result_class, reason_code, operator_message, committed
            ) VALUES (
                p_lor_reconciliation_run_id, v_import_run_id, 'DISPLAY',
                v_display_id::text,
                CASE
                    WHEN v_row.action_type = 'REASSOCIATE_DISPLAY' THEN 'REASSOCIATED'
                    WHEN v_row.action_type IN ('SET_RETIRED', 'SET_RECYCLED')
                        THEN 'STATUS_CHANGED'
                    ELSE 'UPDATED'
                END,
                'P2_' || coalesce(v_row.action_type, 'AUTO_APPROVED'),
                format('P2 applied approved fields to display_id %s (%s).',
                       v_display_id,
                       coalesce(v_row.proposed_display_name, v_old_name)),
                true
            );
        END IF;
    END LOOP;
END;
$procedure$;

COMMENT ON PROCEDURE ref.p2_promote_display_from_reconciliation(bigint) IS
'Internal reconciliation-gated P2. Resolves P1-created stages by approved source StageID, refuses unresolved stage assignments, preserves display_id and production-owned metadata, and applies only approved atomic groups. Canonical revision 2026-08-17-stage-safe-p2-v2.';

/* Known-state repair.  The assertions prevent this from becoming a broad or
   guessed production edit. */
DO $repair$
DECLARE
    v_new_stage_id integer;
    v_restored_count integer;
BEGIN
    IF EXISTS (
        SELECT 1 FROM ref.stage AS s
        WHERE s.stage_key = '05'
          AND s.stage_name = 'RGB Plus Stage 05 Festive Trees Traditional'
    ) AND EXISTS (
        SELECT 1 FROM ref.stage AS s WHERE s.stage_key = '05a'
    ) THEN
        RAISE NOTICE 'Stage 05/05a repair is already present; data repair skipped';
        RETURN;
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM ref.stage AS s
        WHERE s.stage_id = 35
          AND s.stage_key = '05a'
          AND s.stage_name = 'RGB Plus Stage 05 Festive Trees Traditional'
          AND s.park_order = 5
          AND s.sub_order = 1
    ) OR EXISTS (
        SELECT 1 FROM ref.stage AS s
        WHERE s.stage_key IN ('05', '05a') AND s.stage_id <> 35
    ) THEN
        RAISE EXCEPTION 'Stage 05/05a repair guard failed: permanent-stage state is not the known damaged state';
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM ref.stage_lor_binding AS b
        WHERE b.stage_lor_binding_id = 142 AND b.stage_id = 35
          AND b.binding_type = 'SCENE'
          AND b.scene_id = 'd4eeafb3-c355-44df-ab9e-e7566b29e0e7'
          AND b.accepted_source_stage_key = '05'
    ) OR NOT EXISTS (
        SELECT 1 FROM ref.stage_lor_binding AS b
        WHERE b.stage_lor_binding_id = 143 AND b.stage_id = 35
          AND b.binding_type = 'SCENE'
          AND b.scene_id = 'd57761f7-3527-4b00-a8ce-2eeb70eb3d8c'
          AND b.accepted_source_stage_key = '05a'
    ) THEN
        RAISE EXCEPTION 'Stage 05/05a repair guard failed: stable bindings 142/143 do not match incident evidence';
    END IF;

    IF (
        SELECT count(DISTINCT c.display_id)
        FROM ops.lor_reconciliation_display_candidate AS c
        WHERE c.lor_reconciliation_run_id = 8
          AND c.current_stage_id = 35
          AND c.proposed_stage_id IS NULL
          AND 'stage_id' = ANY(c.changed_fields)
          AND c.display_id IS NOT NULL
    ) <> 50 THEN
        RAISE EXCEPTION 'Stage 05/05a repair guard failed: run 8 does not expose the expected 50 cleared Stage 05 displays';
    END IF;

    UPDATE ref.stage
       SET stage_key = '05',
           folder_name = '05-RGB Plus Stage 05 Festive Trees Traditional',
           park_order = 5,
           sub_order = 0,
           updated_at = now(),
           updated_by = current_user
     WHERE stage_id = 35;

    INSERT INTO ref.stage (
        stage_key, stage_name, folder_name, park_order, sub_order
    ) VALUES (
        '05a', 'RGB Plus Stage 05a Mega Star',
        '05a-RGB Plus Stage 05a Mega Star', 5, 1
    ) RETURNING stage_id INTO v_new_stage_id;

    UPDATE ref.stage_lor_binding
       SET stage_id = v_new_stage_id,
           accepted_source_stage_key = '05a',
           updated_at = now(), updated_by = current_user
     WHERE stage_lor_binding_id = 143;

    UPDATE ref.display AS d
       SET stage_id = 35,
           updated_at = now(), updated_by = current_user
     WHERE d.stage_id IS NULL
       AND EXISTS (
           SELECT 1
           FROM ops.lor_reconciliation_display_candidate AS c
           WHERE c.lor_reconciliation_run_id = 8
             AND c.display_id = d.display_id
             AND c.current_stage_id = 35
             AND c.proposed_stage_id IS NULL
             AND 'stage_id' = ANY(c.changed_fields)
       );
    GET DIAGNOSTICS v_restored_count = ROW_COUNT;
    IF v_restored_count <> 50 THEN
        RAISE EXCEPTION 'Stage 05 repair restored % displays, expected exactly 50',
            v_restored_count;
    END IF;

    UPDATE ref.display
       SET stage_id = v_new_stage_id,
           updated_at = now(), updated_by = current_user
     WHERE display_id = 869
       AND display_name = 'FT-MegaStar';
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Stage 05a repair did not find display_id 869 FT-MegaStar';
    END IF;
END;
$repair$;

REVOKE EXECUTE ON FUNCTION
    ops.f_stage_group_new_stage_key(bigint) FROM PUBLIC;
REVOKE EXECUTE ON FUNCTION
    ops.f_stage_group_can_approve_change(bigint) FROM PUBLIC;
REVOKE EXECUTE ON FUNCTION
    ops.f_stage_group_can_add_new_stage(bigint) FROM PUBLIC;
REVOKE EXECUTE ON PROCEDURE
    ref.p1_promote_stage_from_reconciliation(bigint) FROM PUBLIC;
REVOKE EXECUTE ON PROCEDURE
    ref.p2_promote_display_from_reconciliation(bigint) FROM PUBLIC;

COMMIT;

SELECT
    '2026-08-17-distinct-substages-and-stage05-repair-v1'::text
        AS installed_revision,
    (SELECT stage_id FROM ref.stage WHERE stage_key = '05') AS stage_05_id,
    (SELECT stage_id FROM ref.stage WHERE stage_key = '05a') AS stage_05a_id;
