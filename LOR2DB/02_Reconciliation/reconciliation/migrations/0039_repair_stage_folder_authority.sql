/* ============================================================================
Migration: 0039_repair_stage_folder_authority.sql
Issue:     #96 Repair Stage naming source-of-truth violation in ref.stage

Purpose:
  Repair the narrow Stage-name authority defect.

  The governed Google Shared Drive Stage/Sub-stage root under
  G:\Shared drives\Display Folders is the permanent Stage/Sub-stage name.
  The established Google Drive naming grammar is unchanged:

    NN-Name-XY      = Stage root
    NNa-Name-XY     = Sub-stage root
    NN-Name         = Scene under the owning Stage
    NNa-Name        = Scene under the owning Sub-stage
    unprefixed name = Display/shared Display group

  Therefore ref.stage.stage_name and ref.stage.folder_name both store the exact
  governed Stage/Sub-stage root basename, including the Stage key and terminal
  short code.

  Migration 0023 already prevents an LOR Preview name from silently renaming an
  existing permanent Stage. The remaining recurrence path was ADD_NEW_STAGE:
  P1 still synthesized permanent Stage metadata from an LOR Preview/Scene name.

Safety:
  - Uses only the reconciliation run's frozen append-only lor_snap import.
  - Preview/Scene source_name is never permanent Stage naming authority.
  - ADD_NEW_STAGE is unavailable unless exactly one governed Drive root resolves.
  - The governed root is frozen in the append-only action payload and rechecked
    at P1.
  - Existing-row repair is an explicit 29-key allowlist and changes only
    stage_name/folder_name plus normal audit fields.
  - Existing folder_path values are not repaired or normalized by this migration.
  - Stage 12, Stages 39/40, and animation identities 90-94 are excluded.
  - FieldWiring, Procedures, and the shared resolver are outside this migration.
============================================================================ */

BEGIN;

/* --------------------------------------------------------------------------
   Frozen governed-root evidence
---------------------------------------------------------------------------- */
CREATE OR REPLACE FUNCTION ops.f_lor_governed_stage_roots(
    p_import_run_id bigint,
    p_stage_key text
)
RETURNS TABLE (
    folder_path text,
    folder_name text,
    stage_name text,
    evidence_count bigint
)
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = pg_catalog, lor_snap
AS $function$
    WITH raw_evidence AS (
        SELECT p.background_file AS path_text
        FROM lor_snap.previews AS p
        WHERE p.import_run_id = p_import_run_id
          AND lower(btrim(p.stage_id)) = lower(btrim(p_stage_key))
          AND nullif(btrim(p.background_file), '') IS NOT NULL

        UNION ALL

        SELECT s.background_file
        FROM lor_snap.scenes AS s
        WHERE s.import_run_id = p_import_run_id
          AND nullif(btrim(s.background_file), '') IS NOT NULL
          AND (
                lower(btrim(s.stage_id)) = lower(btrim(p_stage_key))
                OR EXISTS (
                    SELECT 1
                    FROM lor_snap.scene_lor_props AS slp
                    WHERE slp.import_run_id = s.import_run_id
                      AND slp.preview_id = s.preview_id
                      AND slp.scene_id = s.scene_id
                      AND lower(btrim(slp.scene_stage_id)) =
                          lower(btrim(p_stage_key))
                )
                OR EXISTS (
                    SELECT 1
                    FROM lor_snap.previews AS p
                    WHERE p.import_run_id = s.import_run_id
                      AND p.id = s.preview_id
                      AND lower(btrim(p.stage_id)) =
                          lower(btrim(p_stage_key))
                )
          )
    ), normalized AS (
        SELECT regexp_replace(
                   replace(btrim(path_text), E'\\', '/'),
                   '/+', '/', 'g'
               ) AS path_text
        FROM raw_evidence
        WHERE btrim(coalesce(p_stage_key, '')) ~ '^[0-9]{2}[A-Za-z]?$'
    ), path_arrays AS (
        SELECT string_to_array(path_text, '/') AS parts
        FROM normalized
    ), governed_paths AS (
        SELECT pa.parts
        FROM path_arrays AS pa
        WHERE cardinality(pa.parts) >= 4
          AND lower(pa.parts[1]) = 'g:'
          AND lower(pa.parts[2]) = 'shared drives'
          AND lower(pa.parts[3]) = 'display folders'
    ), matched AS (
        SELECT gp.parts, root.root_ordinality
        FROM governed_paths AS gp
        CROSS JOIN LATERAL (
            SELECT u.ordinality AS root_ordinality
            FROM unnest(gp.parts) WITH ORDINALITY AS u(part, ordinality)
            WHERE u.ordinality >= 4
              AND u.part ~* (
                    '^' || btrim(p_stage_key) || '-.+-[A-Za-z]{2,3}$'
              )
            ORDER BY u.ordinality
            LIMIT 1
        ) AS root
    ), roots AS (
        SELECT
            array_to_string(
                m.parts[1:(m.root_ordinality::integer)], E'\\'
            ) AS folder_path,
            m.parts[(m.root_ordinality::integer)] AS folder_name
        FROM matched AS m
    ), canonical AS (
        SELECT
            lower(r.folder_path) AS root_key,
            min(r.folder_path) AS folder_path,
            min(r.folder_name) AS folder_name,
            count(*)::bigint AS evidence_count
        FROM roots AS r
        GROUP BY lower(r.folder_path)
    )
    SELECT
        c.folder_path,
        c.folder_name,
        c.folder_name AS stage_name,
        c.evidence_count
    FROM canonical AS c
    WHERE nullif(btrim(c.folder_name), '') IS NOT NULL
    ORDER BY lower(c.folder_path);
$function$;

COMMENT ON FUNCTION ops.f_lor_governed_stage_roots(bigint, text) IS
'Returns each distinct governed Google Drive Stage/Sub-stage root proven by one frozen lor_snap import for one exact StageID. stage_name and folder_name are the exact governed root basename.';

REVOKE EXECUTE ON FUNCTION
    ops.f_lor_governed_stage_roots(bigint, text) FROM PUBLIC;

/* --------------------------------------------------------------------------
   ADD_NEW_STAGE gate
---------------------------------------------------------------------------- */
CREATE OR REPLACE FUNCTION ops.f_stage_group_can_add_new_stage(
    p_lor_reconciliation_group_id bigint
)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = pg_catalog, ops, lor_snap, ref
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
        AND (
            SELECT count(*)
            FROM ops.f_lor_governed_stage_roots(
                g.import_run_id,
                t.stage_key
            )
        ) = 1
    FROM ops.lor_reconciliation_group AS g
    JOIN ops.lor_reconciliation_stage_candidate AS c
      ON c.lor_reconciliation_group_id = g.lor_reconciliation_group_id
    CROSS JOIN target AS t
    WHERE g.lor_reconciliation_group_id = p_lor_reconciliation_group_id
    GROUP BY g.lor_reconciliation_group_id, g.entity_type,
             g.decision_required, g.member_count, g.import_run_id,
             t.stage_key;
$function$;

COMMENT ON FUNCTION ops.f_stage_group_can_add_new_stage(bigint) IS
'True only when one distinct new StageID has complete frozen candidate evidence and exactly one governed Google Drive Stage/Sub-stage root in that reconciliation import.';

/* --------------------------------------------------------------------------
   Freeze governed root into the existing append-only Stage authority action.
---------------------------------------------------------------------------- */
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
SET search_path = pg_catalog, ops, lor_snap, ref
AS $function$
DECLARE
    v_import_run_id bigint;
    v_status text;
    v_action_id bigint;
    v_counts record;
    v_target_stage_key text;
    v_root record;
    v_action_payload jsonb;
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

        v_action_payload := jsonb_build_object(
            'stage_authority_decision', true,
            'target_stage_key', v_target_stage_key
        );

    ELSIF p_action_type = 'ADD_NEW_STAGE' THEN
        IF NOT coalesce(ops.f_stage_group_can_add_new_stage(
            p_lor_reconciliation_group_id), false) THEN
            RAISE EXCEPTION
                'Stage group % does not have one distinct new StageID with one governed Drive root',
                p_lor_reconciliation_group_id;
        END IF;

        v_target_stage_key := ops.f_stage_group_new_stage_key(
            p_lor_reconciliation_group_id
        );

        SELECT r.* INTO STRICT v_root
        FROM ops.f_lor_governed_stage_roots(
            v_import_run_id,
            v_target_stage_key
        ) AS r;

        v_action_payload := jsonb_build_object(
            'stage_authority_decision', true,
            'target_stage_key', v_target_stage_key,
            'governed_stage_name', v_root.stage_name,
            'governed_folder_name', v_root.folder_name,
            'governed_folder_path', v_root.folder_path,
            'governed_root_evidence_count', v_root.evidence_count
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
        v_action_payload,
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

/* --------------------------------------------------------------------------
   Existing operator Stage review, but governed root supplies proposed name for
   ADD_NEW_STAGE instead of an LOR Preview/Scene source name.
---------------------------------------------------------------------------- */
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
    coalesce(root.stage_name, c.proposed_stage_name) AS proposed_stage_name,
    c.current_folder_name,
    coalesce(root.folder_name, c.proposed_folder_name) AS proposed_folder_name,
    c.operator_message,
    c.source_evidence,
    c.source_stage_key,
    c.metadata_authoritative
FROM ops.v_lor_reconciliation_group_review AS gr
JOIN ops.lor_reconciliation_stage_candidate AS c
  ON c.lor_reconciliation_group_id = gr.lor_reconciliation_group_id
LEFT JOIN LATERAL (
    SELECT r.*
    FROM ops.f_lor_governed_stage_roots(
        c.import_run_id,
        c.source_stage_key
    ) AS r
    WHERE (
        SELECT count(*)
        FROM ops.f_lor_governed_stage_roots(
            c.import_run_id,
            c.source_stage_key
        )
    ) = 1
) AS root ON true
WHERE cardinality(c.changed_fields) > 0
   OR c.decision_required
   OR gr.effective_action_type IS NOT NULL;

COMMENT ON VIEW ops.v_lor_reconciliation_operator_stage_review IS
'Operator Stage review. When one governed Drive root is frozen for a source StageID, proposed Stage/folder names are the exact governed root basename.';

/* --------------------------------------------------------------------------
   P1: ADD_NEW_STAGE consumes governed root authority only.
---------------------------------------------------------------------------- */
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
    v_bad_new_stage_authority integer;
BEGIN
    SELECT r.import_run_id INTO v_import_run_id
    FROM ops.lor_reconciliation_run AS r
    WHERE r.lor_reconciliation_run_id = p_lor_reconciliation_run_id
    FOR UPDATE;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Reconciliation run % does not exist',
            p_lor_reconciliation_run_id;
    END IF;

    SELECT count(*) INTO v_bad_new_stage_authority
    FROM ops.v_lor_reconciliation_group_review AS gr
    JOIN ops.lor_reconciliation_action AS a
      ON a.lor_reconciliation_action_id = gr.effective_action_id
    WHERE gr.lor_reconciliation_run_id = p_lor_reconciliation_run_id
      AND gr.effective_action_type = 'ADD_NEW_STAGE'
      AND gr.effective_resolution_state = 'APPROVED'
      AND (
          NOT coalesce(ops.f_stage_group_can_add_new_stage(
              gr.lor_reconciliation_group_id), false)
          OR (
              SELECT count(*)
              FROM ops.f_lor_governed_stage_roots(
                  v_import_run_id,
                  a.action_payload ->> 'target_stage_key'
              ) AS r
              WHERE r.stage_name =
                        a.action_payload ->> 'governed_stage_name'
                AND r.folder_name =
                        a.action_payload ->> 'governed_folder_name'
                AND r.folder_path =
                        a.action_payload ->> 'governed_folder_path'
          ) <> 1
      );

    IF v_bad_new_stage_authority > 0 THEN
        RAISE EXCEPTION
            'Reconciliation run % has % approved new-stage action(s) without matching frozen governed Drive authority',
            p_lor_reconciliation_run_id, v_bad_new_stage_authority;
    END IF;

    FOR v_group IN
        SELECT
            gr.lor_reconciliation_group_id,
            a.action_payload ->> 'target_stage_key' AS stage_key,
            root.stage_name,
            root.folder_name,
            root.folder_path,
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
        CROSS JOIN LATERAL ops.f_lor_governed_stage_roots(
            v_import_run_id,
            a.action_payload ->> 'target_stage_key'
        ) AS root
        WHERE gr.lor_reconciliation_run_id = p_lor_reconciliation_run_id
          AND gr.effective_action_type = 'ADD_NEW_STAGE'
          AND gr.effective_resolution_state = 'APPROVED'
          AND ops.f_stage_group_can_add_new_stage(
                gr.lor_reconciliation_group_id)
          AND root.stage_name =
                a.action_payload ->> 'governed_stage_name'
          AND root.folder_name =
                a.action_payload ->> 'governed_folder_name'
          AND root.folder_path =
                a.action_payload ->> 'governed_folder_path'
        GROUP BY
            gr.lor_reconciliation_group_id,
            a.action_payload,
            root.stage_name,
            root.folder_name,
            root.folder_path
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
        IF v_group.stage_name IS DISTINCT FROM v_group.folder_name THEN
            RAISE EXCEPTION
                'Governed Stage name % does not match governed folder name % for StageID %',
                v_group.stage_name, v_group.folder_name, v_group.stage_key;
        END IF;

        INSERT INTO ref.stage (
            stage_key, stage_name, folder_name, folder_path,
            park_order, sub_order
        ) VALUES (
            v_group.stage_key,
            v_group.stage_name,
            v_group.folder_name,
            v_group.folder_path,
            v_group.park_order,
            v_group.sub_order
        ) RETURNING stage_id INTO v_stage_id;

        INSERT INTO ops.lor_reconciliation_result (
            lor_reconciliation_run_id, import_run_id, entity_type,
            entity_key, result_class, reason_code, operator_message, committed
        ) VALUES (
            p_lor_reconciliation_run_id, v_import_run_id, 'STAGE',
            v_stage_id::text, 'ADDED', 'P1_ADD_NEW_STAGE',
            format(
                'ADDED: Stage %s from governed root %s; permanent stage_id %s.',
                v_group.stage_key, v_group.stage_name, v_stage_id
            ), true
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

    /* Existing-stage behavior remains authoritative for ordinary exact
       bindings, preservation decisions, and stable bindings. */
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
               stage_name = CASE
                   WHEN s.stage_name LIKE v_old_stage_key || '-%'
                   THEN v_change.target_stage_key ||
                        substr(s.stage_name, length(v_old_stage_key) + 1)
                   ELSE s.stage_name
               END,
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
'Reconciliation-gated P1. New Stage/Sub-stage rows require exactly one frozen governed Drive root and store that exact root basename as both stage_name and folder_name.';

REVOKE EXECUTE ON PROCEDURE
    ref.p1_promote_stage_from_reconciliation(bigint) FROM PUBLIC;

/* --------------------------------------------------------------------------
   Controlled existing-row Stage-name repair.
   This intentionally does not alter folder_path.
---------------------------------------------------------------------------- */
CREATE TEMP TABLE pg_temp._stage_folder_authority_repair (
    stage_key text PRIMARY KEY,
    governed_root_name text NOT NULL
) ON COMMIT DROP;

INSERT INTO pg_temp._stage_folder_authority_repair (
    stage_key, governed_root_name
) VALUES
    ('00', '00-HWY 42-HW'),
    ('01', '01-Front Entrance-FE'),
    ('02', '02-Triangle-TR'),
    ('03', '03-Welcome Area-WA'),
    ('04', '04-Food Collection-FC'),
    ('05', '05-Festive Trees-FT'),
    ('05a','05a-Mega Star-MS'),
    ('06', '06-Post Office-PO'),
    ('07', '07-Whoville-WV'),
    ('07a','07a-Who Forest-WF'),
    ('08', '08-Elf Choir-EC'),
    ('09', '09-Global Warming-GW'),
    ('10', '10-Stars-ST'),
    ('11', '11-Sledders-SL'),
    ('13', '13-Winter Wonderland-WW'),
    ('14', '14-Icicle Tunnel-IT'),
    ('15', '15-Church-Bells-CH'),
    ('16', '16-Northern Lights-NL'),
    ('17', '17-Candyland-CL'),
    ('18', '18-Dancing Forest-DF'),
    ('19', '19-Santa''s Workshop-SW'),
    ('20', '20-Snow Storm-SS'),
    ('21', '21-Polar Bear Playground-PB'),
    ('22', '22-Glistening Grove-GG'),
    ('23', '23-Peanuts-PN'),
    ('24', '24-Traditional Christmas-TC'),
    ('25', '25-Racing Arches-RA'),
    ('26', '26-Magic Igloo-MI'),
    ('30', '30-Santa''s Station-QV');

DO $repair_guard$
DECLARE
    v_count integer;
    v_bad text;
BEGIN
    SELECT count(*) INTO v_count
    FROM pg_temp._stage_folder_authority_repair;
    IF v_count <> 29 THEN
        RAISE EXCEPTION 'Stage authority repair expected 29 target rows; found %',
            v_count;
    END IF;

    SELECT string_agg(x.stage_key, ', ' ORDER BY x.stage_key)
      INTO v_bad
    FROM (
        SELECT t.stage_key
        FROM pg_temp._stage_folder_authority_repair AS t
        LEFT JOIN ref.stage AS s ON s.stage_key = t.stage_key
        GROUP BY t.stage_key
        HAVING count(s.stage_id) <> 1
    ) AS x;

    IF v_bad IS NOT NULL THEN
        RAISE EXCEPTION
            'Stage authority repair target key(s) are missing or non-unique: %',
            v_bad;
    END IF;

    IF EXISTS (
        SELECT 1
        FROM pg_temp._stage_folder_authority_repair
        WHERE stage_key IN ('12', '39', '40', '90', '91', '92', '93', '94')
    ) THEN
        RAISE EXCEPTION 'Excluded Stage key entered the controlled repair set';
    END IF;
END;
$repair_guard$;

UPDATE ref.stage AS s
   SET stage_name = t.governed_root_name,
       folder_name = t.governed_root_name,
       updated_at = now(),
       updated_by = current_user
FROM pg_temp._stage_folder_authority_repair AS t
WHERE s.stage_key = t.stage_key
  AND (
      s.stage_name IS DISTINCT FROM t.governed_root_name
      OR s.folder_name IS DISTINCT FROM t.governed_root_name
  );

COMMIT;

SELECT
    '2026-08-30-stage-root-name-authority-v2'::text AS installed_revision,
    to_regprocedure('ops.f_lor_governed_stage_roots(bigint,text)') IS NOT NULL
        AS has_governed_root_resolver,
    to_regprocedure('ref.p1_promote_stage_from_reconciliation(bigint)')
        IS NOT NULL AS has_safe_p1;
