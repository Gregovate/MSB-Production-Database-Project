/* ============================================================================
Object group: Atomic LOR reconciliation Finish/Cancel lifecycle
Repository:   Postgres_sql/Upsert Procedures/reconciliation/
Filename:     0019_create_reconciliation_finish_cancel_lifecycle.sql
Revision:     2026-08-03-reconciliation-finish-cancel-v2

Purpose:
  Install the only operator-facing write entry points for finishing or
  cancelling one already-captured reconciliation run.

Safety boundary:
  - Finish locks the persisted run, freezes unresolved decisions as exceptions,
    calls P1/P3/P2/P4 in dependency order, validates the committed projection,
    and advances the run to REPORTING in the caller's transaction.
  - Cancel is allowed only before promotion, records the cancellation audit,
    deletes the captured snapshot as one unit, and advances to REPORTING.
  - Neither entry point selects or interprets a latest import_run_id.
  - COMPLETED / COMPLETED_WITH_EXCEPTIONS / CANCELLED are reserved for the
    later report publisher because publication is part of completion.

Revision history:
  2026-08-03  GAL / OpenAI  v2: Validate scene membership by its actual scene/display composite key.
  2026-08-03  GAL / OpenAI  Initial atomic Finish/Cancel lifecycle.
============================================================================ */

BEGIN;

CREATE OR REPLACE PROCEDURE ops.p_finish_lor_reconciliation(
    p_lor_reconciliation_run_id bigint,
    p_finished_by_application text DEFAULT NULL
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, ops, lor_snap, ref
AS $procedure$
DECLARE
    v_import_run_id bigint;
    v_status text;
    v_structural_failures integer;
    v_unresolved integer;
    v_deferred integer;
    v_blocked integer;
    v_invalid_scene_count integer;
    v_invalid_membership_count integer;
BEGIN
    PERFORM pg_advisory_xact_lock(
        hashtext('ops.lor_reconciliation.finish'),
        (p_lor_reconciliation_run_id % 2147483647)::integer
    );

    SELECT r.import_run_id, r.status, r.structural_failure_count
      INTO v_import_run_id, v_status, v_structural_failures
    FROM ops.lor_reconciliation_run AS r
    WHERE r.lor_reconciliation_run_id = p_lor_reconciliation_run_id
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Reconciliation run % does not exist',
            p_lor_reconciliation_run_id;
    END IF;

    IF v_status NOT IN ('AWAITING_DECISIONS', 'READY_TO_FINISH') THEN
        RAISE EXCEPTION 'Reconciliation run % is %, not finishable',
            p_lor_reconciliation_run_id, v_status;
    END IF;

    IF v_structural_failures <> 0 THEN
        RAISE EXCEPTION 'Reconciliation run % has % structural failures',
            p_lor_reconciliation_run_id, v_structural_failures;
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM lor_snap.import_run AS ir
        WHERE ir.import_run_id = v_import_run_id
    ) THEN
        RAISE EXCEPTION 'Captured import_run_id % no longer exists',
            v_import_run_id;
    END IF;

    /* Persist unresolved review groups as blocked exceptions exactly once. */
    INSERT INTO ops.lor_reconciliation_result (
        lor_reconciliation_run_id, import_run_id, entity_type, entity_key,
        result_class, reason_code, operator_message, committed
    )
    SELECT
        g.lor_reconciliation_run_id, g.import_run_id, g.entity_type,
        g.logical_group_key, 'UNRESOLVED', 'FINISH_WITHOUT_REQUIRED_DECISION',
        coalesce(g.operator_message,
            'Required operator decision was unresolved at Finish; production was left unchanged.'),
        false
    FROM ops.lor_reconciliation_group AS g
    WHERE g.lor_reconciliation_run_id = p_lor_reconciliation_run_id
      AND g.decision_required
      AND NOT EXISTS (
          SELECT 1
          FROM ops.lor_reconciliation_action AS a
          WHERE a.lor_reconciliation_run_id = g.lor_reconciliation_run_id
            AND a.lor_reconciliation_group_id = g.lor_reconciliation_group_id
      )
      AND NOT EXISTS (
          SELECT 1
          FROM ops.lor_reconciliation_result AS rr
          WHERE rr.lor_reconciliation_run_id = g.lor_reconciliation_run_id
            AND rr.entity_type = g.entity_type
            AND rr.entity_key = g.logical_group_key
            AND rr.reason_code = 'FINISH_WITHOUT_REQUIRED_DECISION'
      );

    /* Persist frozen blocking candidates and explicit deferrals for reporting. */
    INSERT INTO ops.lor_reconciliation_result (
        lor_reconciliation_run_id, import_run_id, entity_type, entity_key,
        result_class, reason_code, operator_message, committed
    )
    SELECT b.run_id, b.import_run_id, b.entity_type, b.entity_key,
           'BLOCKED', 'FROZEN_CANDIDATE_BLOCKED', b.operator_message, false
    FROM (
        SELECT lor_reconciliation_run_id AS run_id, import_run_id,
               'STAGE'::text AS entity_type, candidate_key AS entity_key,
               operator_message
        FROM ops.lor_reconciliation_stage_candidate WHERE is_blocking
        UNION ALL
        SELECT lor_reconciliation_run_id, import_run_id, 'DISPLAY',
               candidate_key, operator_message
        FROM ops.lor_reconciliation_display_candidate WHERE is_blocking
        UNION ALL
        SELECT lor_reconciliation_run_id, import_run_id, 'SCENE',
               candidate_key, operator_message
        FROM ops.lor_reconciliation_scene_candidate WHERE is_blocking
        UNION ALL
        SELECT lor_reconciliation_run_id, import_run_id, 'SCENE_DISPLAY',
               candidate_key, operator_message
        FROM ops.lor_reconciliation_scene_display_candidate WHERE is_blocking
    ) AS b
    WHERE b.run_id = p_lor_reconciliation_run_id
      AND NOT EXISTS (
          SELECT 1 FROM ops.lor_reconciliation_result AS rr
          WHERE rr.lor_reconciliation_run_id = b.run_id
            AND rr.entity_type = b.entity_type
            AND rr.entity_key = b.entity_key
            AND rr.reason_code = 'FROZEN_CANDIDATE_BLOCKED'
      );

    INSERT INTO ops.lor_reconciliation_result (
        lor_reconciliation_run_id, import_run_id, entity_type, entity_key,
        result_class, reason_code, operator_message, committed
    )
    SELECT gr.lor_reconciliation_run_id, gr.import_run_id, gr.entity_type,
           gr.logical_group_key, 'DEFERRED', 'OPERATOR_DEFERRED_GROUP',
           coalesce(gr.effective_reason,
                    'Operator deferred this logical group; production was left unchanged.'),
           false
    FROM ops.v_lor_reconciliation_group_review AS gr
    WHERE gr.lor_reconciliation_run_id = p_lor_reconciliation_run_id
      AND gr.effective_resolution_state = 'DEFERRED'
      AND NOT EXISTS (
          SELECT 1 FROM ops.lor_reconciliation_result AS rr
          WHERE rr.lor_reconciliation_run_id = gr.lor_reconciliation_run_id
            AND rr.entity_type = gr.entity_type
            AND rr.entity_key = gr.logical_group_key
            AND rr.reason_code = 'OPERATOR_DEFERRED_GROUP'
      );

    SELECT
        count(*) FILTER (WHERE gr.effective_resolution_state = 'UNRESOLVED'),
        count(*) FILTER (WHERE gr.effective_resolution_state = 'DEFERRED')
      INTO v_unresolved, v_deferred
    FROM ops.v_lor_reconciliation_group_review AS gr
    WHERE gr.lor_reconciliation_run_id = p_lor_reconciliation_run_id;

    SELECT count(*) INTO v_blocked
    FROM (
        SELECT gr.lor_reconciliation_group_id
        FROM ops.v_lor_reconciliation_group_review AS gr
        WHERE gr.lor_reconciliation_run_id = p_lor_reconciliation_run_id
          AND gr.effective_resolution_state = 'BLOCKED'
        UNION
        SELECT c.lor_reconciliation_group_id
        FROM ops.lor_reconciliation_stage_candidate AS c
        WHERE c.lor_reconciliation_run_id = p_lor_reconciliation_run_id
          AND c.is_blocking
        UNION
        SELECT c.lor_reconciliation_group_id
        FROM ops.lor_reconciliation_display_candidate AS c
        WHERE c.lor_reconciliation_run_id = p_lor_reconciliation_run_id
          AND c.is_blocking
        UNION
        SELECT c.lor_reconciliation_group_id
        FROM ops.lor_reconciliation_scene_candidate AS c
        WHERE c.lor_reconciliation_run_id = p_lor_reconciliation_run_id
          AND c.is_blocking
        UNION
        SELECT c.lor_reconciliation_group_id
        FROM ops.lor_reconciliation_scene_display_candidate AS c
        WHERE c.lor_reconciliation_run_id = p_lor_reconciliation_run_id
          AND c.is_blocking
    ) AS blocked_groups;

    UPDATE ops.lor_reconciliation_run
       SET status = 'PROMOTING',
           resumed_at = now(),
           paused_at = NULL,
           unresolved_count = coalesce(v_unresolved, 0),
           deferred_count = coalesce(v_deferred, 0),
           blocked_count = coalesce(v_blocked, 0),
           validation_state = 'PENDING',
           failure_message = NULL
     WHERE lor_reconciliation_run_id = p_lor_reconciliation_run_id;

    CALL ref.p1_promote_stage_from_reconciliation(p_lor_reconciliation_run_id);
    CALL ref.p3_promote_scene_from_reconciliation(p_lor_reconciliation_run_id);
    CALL ref.p2_promote_display_from_reconciliation(p_lor_reconciliation_run_id);
    CALL ref.p4_promote_scene_display_from_reconciliation(p_lor_reconciliation_run_id);

    UPDATE ops.lor_reconciliation_run
       SET status = 'VALIDATING'
     WHERE lor_reconciliation_run_id = p_lor_reconciliation_run_id;

    SELECT count(*)
      INTO v_invalid_scene_count
    FROM ops.lor_reconciliation_scene_candidate AS c
    LEFT JOIN ref.lor_scene AS s
      ON s.preview_uuid = c.preview_id
     AND s.scene_uuid = c.scene_id
    WHERE c.lor_reconciliation_run_id = p_lor_reconciliation_run_id
      AND c.initial_resolution_state = 'AUTO_APPROVED'
      AND NOT c.is_blocking
      AND (
          s.lor_scene_id IS NULL
          OR s.source_import_run_id <> v_import_run_id
          OR s.scene_name IS DISTINCT FROM c.scene_name
      );

    SELECT count(*)
      INTO v_invalid_membership_count
    FROM ops.lor_reconciliation_scene_display_candidate AS c
    JOIN ops.lor_reconciliation_display_candidate AS dc
      ON dc.lor_reconciliation_display_candidate_id =
         c.lor_reconciliation_display_candidate_id
    JOIN ops.v_lor_reconciliation_group_review AS display_group
      ON display_group.lor_reconciliation_group_id =
         dc.lor_reconciliation_group_id
    LEFT JOIN ref.display AS d ON d.lor_prop_id = c.source_lor_prop_id
    LEFT JOIN ref.lor_scene AS s
      ON s.preview_uuid = c.preview_id
     AND s.scene_uuid = c.scene_id
    LEFT JOIN ref.lor_scene_display AS sd
      ON sd.lor_scene_id = s.lor_scene_id
     AND sd.display_id = d.display_id
    WHERE c.lor_reconciliation_run_id = p_lor_reconciliation_run_id
      AND c.initial_resolution_state = 'AUTO_APPROVED'
      AND NOT c.is_blocking
      AND display_group.effective_resolution_state IN ('AUTO_APPROVED', 'APPROVED')
      AND (d.display_id IS NULL OR s.lor_scene_id IS NULL
           OR sd.lor_scene_id IS NULL);

    IF v_invalid_scene_count <> 0 OR v_invalid_membership_count <> 0 THEN
        RAISE EXCEPTION
            'Post-write validation failed: invalid scenes %, invalid memberships %',
            v_invalid_scene_count, v_invalid_membership_count;
    END IF;

    INSERT INTO ops.lor_reconciliation_result (
        lor_reconciliation_run_id, import_run_id, entity_type, entity_key,
        result_class, reason_code, operator_message, committed
    ) VALUES (
        p_lor_reconciliation_run_id, v_import_run_id, 'RUN',
        p_lor_reconciliation_run_id::text, 'VALIDATION',
        'FINISH_POST_WRITE_VALIDATION_PASSED',
        format('Atomic P1-P4 promotion passed post-write validation (application %s).',
               coalesce(nullif(btrim(p_finished_by_application), ''), 'unspecified')),
        true
    );

    UPDATE ops.lor_reconciliation_run
       SET status = 'REPORTING',
           validation_state = 'PASSED'
     WHERE lor_reconciliation_run_id = p_lor_reconciliation_run_id;
END;
$procedure$;

COMMENT ON PROCEDURE ops.p_finish_lor_reconciliation(bigint,text) IS
'Only Finish entry point. Atomically runs P1/P3/P2/P4 against one captured reconciliation run, validates the projection, and advances it to REPORTING.';

CREATE OR REPLACE PROCEDURE ops.p_cancel_lor_reconciliation(
    p_lor_reconciliation_run_id bigint,
    p_cancellation_reason text,
    p_cancelled_by_application text DEFAULT NULL
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, ops, lor_snap, ref
AS $procedure$
DECLARE
    v_import_run_id bigint;
    v_status text;
    v_reason text := nullif(btrim(p_cancellation_reason), '');
BEGIN
    IF v_reason IS NULL THEN
        RAISE EXCEPTION 'Cancellation reason is required';
    END IF;

    PERFORM pg_advisory_xact_lock(
        hashtext('ops.lor_reconciliation.cancel'),
        (p_lor_reconciliation_run_id % 2147483647)::integer
    );

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
        RAISE EXCEPTION 'Reconciliation run % is %, not cancellable',
            p_lor_reconciliation_run_id, v_status;
    END IF;

    IF EXISTS (
        SELECT 1 FROM ops.lor_reconciliation_result AS rr
        WHERE rr.lor_reconciliation_run_id = p_lor_reconciliation_run_id
          AND rr.committed
          AND rr.result_class IN (
              'ADDED', 'UPDATED', 'REASSOCIATED', 'STATUS_CHANGED'
          )
    ) THEN
        RAISE EXCEPTION
            'Reconciliation run % has committed production results and cannot be cancelled',
            p_lor_reconciliation_run_id;
    END IF;

    IF EXISTS (
        SELECT 1 FROM ref.lor_scene AS s
        WHERE s.source_import_run_id = v_import_run_id
        UNION ALL
        SELECT 1 FROM ref.lor_scene_display AS sd
        WHERE sd.source_import_run_id = v_import_run_id
    ) THEN
        RAISE EXCEPTION
            'Captured import_run_id % is referenced by production scene data',
            v_import_run_id;
    END IF;

    INSERT INTO ops.lor_reconciliation_action (
        lor_reconciliation_run_id, import_run_id,
        lor_reconciliation_group_id, action_type, reason,
        acted_by_application
    ) VALUES (
        p_lor_reconciliation_run_id, v_import_run_id,
        NULL, 'CANCEL_RECONCILIATION', v_reason,
        nullif(btrim(p_cancelled_by_application), '')
    );

    INSERT INTO ops.lor_reconciliation_result (
        lor_reconciliation_run_id, import_run_id, entity_type, entity_key,
        result_class, reason_code, operator_message, committed
    ) VALUES (
        p_lor_reconciliation_run_id, v_import_run_id, 'RUN',
        p_lor_reconciliation_run_id::text, 'CANCELLED',
        'CANCELLED_BEFORE_PROMOTION',
        format('Reconciliation cancelled before promotion; captured import_run_id %s was deleted. Reason: %s',
               v_import_run_id, v_reason),
        true
    );

    DELETE FROM lor_snap.scene_lor_props
     WHERE import_run_id = v_import_run_id;
    DELETE FROM lor_snap.scenes
     WHERE import_run_id = v_import_run_id;
    DELETE FROM lor_snap.import_run
     WHERE import_run_id = v_import_run_id;

    IF FOUND IS FALSE THEN
        RAISE EXCEPTION 'Captured import_run_id % was not deleted',
            v_import_run_id;
    END IF;

    UPDATE ops.lor_reconciliation_run
       SET status = 'REPORTING',
           cancelled_at = now(),
           cancellation_reason = v_reason,
           validation_state = 'PASSED',
           unresolved_count = 0,
           deferred_count = 0,
           blocked_count = 0
     WHERE lor_reconciliation_run_id = p_lor_reconciliation_run_id;
END;
$procedure$;

COMMENT ON PROCEDURE ops.p_cancel_lor_reconciliation(bigint,text,text) IS
'Only Cancel entry point. Before promotion, atomically records cancellation and deletes the run captured snapshot; report publication performs the terminal CANCELLED transition.';

REVOKE EXECUTE ON PROCEDURE
    ops.p_finish_lor_reconciliation(bigint,text) FROM PUBLIC;
REVOKE EXECUTE ON PROCEDURE
    ops.p_cancel_lor_reconciliation(bigint,text,text) FROM PUBLIC;

COMMENT ON SCHEMA ops IS
'Operational workflow and audit objects. Reconciliation engine revision 2026-08-03-finish-cancel-v1 installed.';

COMMIT;

SELECT
    '2026-08-03-reconciliation-finish-cancel-v2'::text AS installed_revision,
    to_regprocedure('ops.p_finish_lor_reconciliation(bigint,text)') IS NOT NULL
        AS has_finish_procedure,
    to_regprocedure('ops.p_cancel_lor_reconciliation(bigint,text,text)') IS NOT NULL
        AS has_cancel_procedure;
