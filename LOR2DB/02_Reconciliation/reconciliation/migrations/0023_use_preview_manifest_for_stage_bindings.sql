/* ============================================================================
Migration: 0023_use_preview_manifest_for_stage_bindings.sql
Purpose:
  Correct stage-candidate generation so multiple approved preview files may
  bind to the same permanent stage without being misclassified as competing
  stage renames.

Rules:
  - source_filename is frozen as candidate evidence for each preview.
  - Existing stage identity resolves only through a stable LOR binding or the
    canonical stage key already stored in ref.stage.
  - A preview's descriptive Name never renames an existing permanent stage.
  - Distinct preview files for one stage remain distinct bindings, regardless
    of controller, schedule, equipment, or purpose.
  - New or conflicting stage identity still requires operator review.

Safety boundary:
  - Replaces candidate-builder logic only.
  - Records no decisions and calls no promotion procedure.
  - Does not modify ref.stage, ref.stage_lor_binding, or any production row.

Revision history:
  2026-08-03  GAL / OpenAI  Use manifest filename evidence and remove false
                            multi-preview stage metadata conflicts.
============================================================================ */

BEGIN;

CREATE OR REPLACE FUNCTION ops.f_build_lor_reconciliation_stage_candidates(
    p_lor_reconciliation_run_id bigint
)
RETURNS integer
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, ops, lor_snap, ref
AS $function$
DECLARE
    v_import_run_id bigint;
    v_run_status text;
    v_existing_count integer;
    v_inserted_count integer;
    v_unresolved_count integer;
    v_deferred_count integer;
    v_blocked_count integer;
BEGIN
    SELECT r.import_run_id, r.status
      INTO v_import_run_id, v_run_status
    FROM ops.lor_reconciliation_run AS r
    WHERE r.lor_reconciliation_run_id = p_lor_reconciliation_run_id
    FOR UPDATE;

    IF v_import_run_id IS NULL THEN
        RAISE EXCEPTION 'Reconciliation run % does not exist',
            p_lor_reconciliation_run_id;
    END IF;

    IF v_run_status IN ('CANCELLED', 'COMPLETED', 'COMPLETED_WITH_EXCEPTIONS') THEN
        RAISE EXCEPTION 'Reconciliation run % is closed with status %',
            p_lor_reconciliation_run_id, v_run_status;
    END IF;

    SELECT count(*)
      INTO v_existing_count
    FROM ops.lor_reconciliation_stage_candidate AS c
    WHERE c.lor_reconciliation_run_id = p_lor_reconciliation_run_id;

    IF v_existing_count > 0 THEN
        RETURN v_existing_count;
    END IF;

    CREATE TEMP TABLE pg_temp._lor_stage_candidate_build ON COMMIT DROP AS
    WITH populated_scenes AS (
        SELECT DISTINCT
            s.preview_id,
            s.scene_id,
            btrim(s.name) AS source_name,
            lower(btrim(coalesce(slp.scene_stage_id, s.stage_id))) AS scene_stage_key
        FROM lor_snap.scenes AS s
        JOIN lor_snap.scene_lor_props AS slp
          ON slp.import_run_id = s.import_run_id
         AND slp.preview_id = s.preview_id
         AND slp.scene_id = s.scene_id
        WHERE s.import_run_id = v_import_run_id
          AND nullif(btrim(coalesce(slp.scene_stage_id, s.stage_id)), '') IS NOT NULL
    ),
    preview_profile AS (
        SELECT
            p.id AS preview_id,
            btrim(p.name) AS preview_name,
            lower(btrim(p.stage_id)) AS preview_stage_key,
            p.name ILIKE '%master musical preview%' AS is_shared_preview,
            p.source_filename
        FROM lor_snap.previews AS p
        WHERE p.import_run_id = v_import_run_id
    ),
    evidence AS (
        SELECT
            'PREVIEW'::text AS binding_type,
            pp.preview_id,
            NULL::text AS scene_id,
            pp.preview_name AS source_name,
            pp.preview_stage_key AS source_stage_key,
            true AS metadata_authoritative,
            pp.source_filename
        FROM preview_profile AS pp
        WHERE NOT pp.is_shared_preview
          AND pp.preview_stage_key ~ '^(0|[0-9]{1,2})[a-z]?$'

        UNION ALL

        SELECT
            'SCENE',
            ps.preview_id,
            ps.scene_id,
            ps.source_name,
            ps.scene_stage_key,
            false,
            pp.source_filename
        FROM populated_scenes AS ps
        JOIN preview_profile AS pp ON pp.preview_id = ps.preview_id
        WHERE pp.is_shared_preview
          AND ps.scene_stage_key ~ '^(0|[0-9]{1,2})[a-z]?$'
    ),
    resolved AS (
        SELECT
            e.binding_type,
            e.preview_id,
            e.scene_id,
            e.source_name,
            e.source_stage_key,
            /*
              GAL 2026-08-03: A preview name is descriptive file metadata, not
              authority to rename a permanent stage that already resolves by
              stable binding or stage key. Only a genuinely new stage retains
              preview-derived metadata for operator review.
            */
            (
                e.metadata_authoritative
                AND coalesce(b.stage_id, sk.stage_id) IS NULL
            ) AS metadata_authoritative,
            e.source_filename,
            b.stage_id AS binding_stage_id,
            sk.stage_id AS stage_key_stage_id,
            coalesce(b.stage_id, sk.stage_id) AS resolved_stage_id,
            rs.stage_key AS current_stage_key,
            rs.stage_name AS current_stage_name,
            rs.folder_name AS current_folder_name,
            rs.park_order AS current_park_order,
            rs.sub_order AS current_sub_order
        FROM evidence AS e
        LEFT JOIN ref.stage_lor_binding AS b
          ON b.binding_type = e.binding_type
         AND b.preview_id = e.preview_id
         AND b.scene_id IS NOT DISTINCT FROM e.scene_id
        LEFT JOIN ref.stage AS sk ON sk.stage_key = e.source_stage_key
        LEFT JOIN ref.stage AS rs ON rs.stage_id = coalesce(b.stage_id, sk.stage_id)
    ),
    proposed AS (
        SELECT
            r.*,
            CASE WHEN r.metadata_authoritative THEN
                coalesce(
                    nullif(btrim(regexp_replace(
                        regexp_replace(
                            r.source_name,
                            '(?i)^\\s*stage\\s*0*' ||
                                regexp_replace(r.source_stage_key, '([a-z])$', '\\1') ||
                                '\\s*',
                            ''
                        ),
                        '\\s+(with|w/)\\s+.*$', '', 'i'
                    )), ''),
                    'Stage ' || r.source_stage_key
                )
            END AS proposed_stage_name,
            (regexp_match(r.source_stage_key, '^0*([0-9]{1,2})'))[1]::integer
                AS proposed_park_order,
            CASE WHEN r.source_stage_key ~ '^[0-9]{1,2}[a-z]$'
                THEN ascii(right(r.source_stage_key, 1)) - ascii('a') + 1
                ELSE 0 END AS proposed_sub_order
        FROM resolved AS r
    ),
    classified AS (
        SELECT
            p.*,
            CASE WHEN p.metadata_authoritative THEN
                p.source_stage_key || '-' || p.proposed_stage_name
            END AS proposed_folder_name,
            CASE
                WHEN nullif(btrim(p.source_filename), '') IS NULL
                    THEN 'SOURCE_FILENAME_MISSING'
                WHEN p.binding_stage_id IS NOT NULL
                 AND p.stage_key_stage_id IS NOT NULL
                 AND p.binding_stage_id <> p.stage_key_stage_id
                    THEN 'BINDING_STAGE_KEY_CONFLICT'
                WHEN p.resolved_stage_id IS NULL
                    THEN 'NEW_STAGE_REQUIRES_AUTHORITATIVE_DECISION'
                WHEN p.binding_stage_id IS NULL
                    THEN 'BOOTSTRAP_BINDING_TO_EXISTING_STAGE'
                WHEN p.current_stage_key IS DISTINCT FROM p.source_stage_key
                    THEN 'BOUND_STAGE_KEY_CHANGED'
                WHEN p.metadata_authoritative
                 AND (
                    p.current_stage_name IS DISTINCT FROM p.proposed_stage_name
                    OR p.current_folder_name IS DISTINCT FROM
                        p.source_stage_key || '-' || p.proposed_stage_name
                    OR p.current_park_order IS DISTINCT FROM p.proposed_park_order
                    OR p.current_sub_order IS DISTINCT FROM p.proposed_sub_order
                 ) THEN 'BOUND_STAGE_METADATA_CHANGED'
                ELSE 'EXACT_STAGE_BINDING'
            END AS classification_code
        FROM proposed AS p
    )
    SELECT
        c.*,
        CASE
            WHEN c.binding_type = 'PREVIEW'
                THEN format('PREVIEW:%s', c.preview_id)
            ELSE format('SCENE:%s:%s', c.preview_id, c.scene_id)
        END AS candidate_key,
        CASE WHEN c.resolved_stage_id IS NOT NULL
            THEN format('STAGE:%s', c.resolved_stage_id)
            ELSE format('UNRESOLVED_STAGE_KEY:%s', c.source_stage_key)
        END AS logical_group_key,
        CASE WHEN c.classification_code IN (
            'SOURCE_FILENAME_MISSING',
            'BINDING_STAGE_KEY_CONFLICT',
            'BOUND_STAGE_KEY_CHANGED',
            'NEW_STAGE_REQUIRES_AUTHORITATIVE_DECISION'
        ) THEN 'DECISION_REQUIRED' ELSE 'AUTO_APPROVED' END
            AS initial_resolution_state,
        c.classification_code IN (
            'SOURCE_FILENAME_MISSING',
            'BINDING_STAGE_KEY_CONFLICT',
            'BOUND_STAGE_KEY_CHANGED',
            'NEW_STAGE_REQUIRES_AUTHORITATIVE_DECISION'
        ) AS decision_required,
        ARRAY_REMOVE(ARRAY[
            CASE WHEN c.current_stage_key IS DISTINCT FROM c.source_stage_key
                THEN 'stage_key' END,
            CASE WHEN c.metadata_authoritative
                       AND c.current_stage_name IS DISTINCT FROM c.proposed_stage_name
                THEN 'stage_name' END,
            CASE WHEN c.metadata_authoritative
                       AND c.current_folder_name IS DISTINCT FROM
                           c.source_stage_key || '-' || c.proposed_stage_name
                THEN 'folder_name' END,
            CASE WHEN c.metadata_authoritative
                       AND c.current_park_order IS DISTINCT FROM c.proposed_park_order
                THEN 'park_order' END,
            CASE WHEN c.metadata_authoritative
                       AND c.current_sub_order IS DISTINCT FROM c.proposed_sub_order
                THEN 'sub_order' END,
            CASE WHEN c.binding_stage_id IS NULL THEN 'lor_binding' END
        ]::text[], NULL) AS changed_fields
    FROM classified AS c;

    INSERT INTO ops.lor_reconciliation_group (
        lor_reconciliation_run_id, import_run_id, entity_type,
        logical_group_key, group_kind, member_count,
        requires_atomic_decision, decision_required,
        allowed_action_types, operator_message
    )
    SELECT
        p_lor_reconciliation_run_id,
        v_import_run_id,
        'STAGE',
        b.logical_group_key,
        CASE WHEN count(*) > 1
            THEN 'IDENTITY_COMPONENT' ELSE 'SINGLE_CANDIDATE' END,
        count(*)::integer,
        count(*) > 1,
        bool_or(b.decision_required)
            OR count(DISTINCT b.source_stage_key) > 1
            OR count(DISTINCT b.proposed_stage_name)
                FILTER (WHERE b.metadata_authoritative) > 1,
        CASE WHEN bool_or(b.decision_required)
                   OR count(DISTINCT b.source_stage_key) > 1
                   OR count(DISTINCT b.proposed_stage_name)
                       FILTER (WHERE b.metadata_authoritative) > 1
            THEN ARRAY['CORRECT_SOURCE_REQUIRED', 'DEFER']::text[]
            ELSE ARRAY[]::text[] END,
        CASE WHEN count(DISTINCT b.source_stage_key) > 1
                   OR count(DISTINCT b.proposed_stage_name)
                       FILTER (WHERE b.metadata_authoritative) > 1
            THEN 'Multiple bindings assigned to one permanent stage contain contradictory stage metadata.'
            WHEN bool_or(b.decision_required)
            THEN 'Stage identity evidence conflicts or identifies a new stage; production remains unchanged.'
            ELSE 'Stage and all stable LOR bindings are approved from captured source evidence.'
        END
    FROM pg_temp._lor_stage_candidate_build AS b
    GROUP BY b.logical_group_key;

    INSERT INTO ops.lor_reconciliation_stage_candidate (
        lor_reconciliation_run_id, lor_reconciliation_group_id,
        import_run_id, candidate_key, binding_type, preview_id, scene_id,
        source_name, source_stage_key, resolved_stage_id, binding_stage_id,
        stage_key_stage_id, current_stage_key, proposed_stage_key,
        current_stage_name, proposed_stage_name,
        current_folder_name, proposed_folder_name,
        current_park_order, proposed_park_order,
        current_sub_order, proposed_sub_order,
        metadata_authoritative, classification_code,
        initial_resolution_state, decision_required, is_blocking,
        changed_fields, operator_message, source_evidence
    )
    SELECT
        p_lor_reconciliation_run_id,
        g.lor_reconciliation_group_id,
        v_import_run_id,
        b.candidate_key,
        b.binding_type,
        b.preview_id,
        b.scene_id,
        b.source_name,
        b.source_stage_key,
        b.resolved_stage_id,
        b.binding_stage_id,
        b.stage_key_stage_id,
        b.current_stage_key,
        b.source_stage_key,
        b.current_stage_name,
        b.proposed_stage_name,
        b.current_folder_name,
        b.proposed_folder_name,
        b.current_park_order,
        b.proposed_park_order,
        b.current_sub_order,
        b.proposed_sub_order,
        b.metadata_authoritative,
        b.classification_code,
        b.initial_resolution_state,
        b.decision_required,
        b.decision_required,
        b.changed_fields,
        CASE b.classification_code
            WHEN 'SOURCE_FILENAME_MISSING' THEN
                'The captured preview manifest is missing the original .lorprev filename.'
            WHEN 'BINDING_STAGE_KEY_CONFLICT' THEN
                'Stable LOR binding and current stage_key resolve to different permanent stages.'
            WHEN 'BOUND_STAGE_KEY_CHANGED' THEN
                'Stable preview identity now declares a different canonical StageID; production remains unchanged.'
            WHEN 'NEW_STAGE_REQUIRES_AUTHORITATIVE_DECISION' THEN
                'No existing permanent stage or stable binding resolves this source stage.'
            ELSE 'Captured source resolves to permanent stage_id ' || b.resolved_stage_id || '.'
        END,
        jsonb_build_object(
            'binding_stage_id', b.binding_stage_id,
            'stage_key_stage_id', b.stage_key_stage_id,
            'metadata_authoritative', b.metadata_authoritative,
            'source_filename', b.source_filename
        )
    FROM pg_temp._lor_stage_candidate_build AS b
    JOIN ops.lor_reconciliation_group AS g
      ON g.lor_reconciliation_run_id = p_lor_reconciliation_run_id
     AND g.entity_type = 'STAGE'
     AND g.logical_group_key = b.logical_group_key;

    GET DIAGNOSTICS v_inserted_count = ROW_COUNT;

    SELECT
        count(*) FILTER (WHERE gr.effective_resolution_state = 'UNRESOLVED'),
        count(*) FILTER (WHERE gr.effective_resolution_state = 'DEFERRED'),
        count(*) FILTER (WHERE gr.effective_resolution_state = 'BLOCKED')
      INTO v_unresolved_count, v_deferred_count, v_blocked_count
    FROM ops.v_lor_reconciliation_group_review AS gr
    WHERE gr.lor_reconciliation_run_id = p_lor_reconciliation_run_id;

    UPDATE ops.lor_reconciliation_run
       SET unresolved_count = v_unresolved_count,
           deferred_count = v_deferred_count,
           blocked_count = v_blocked_count,
           status = CASE
               WHEN v_unresolved_count = 0 AND v_blocked_count = 0
                   THEN 'READY_TO_FINISH'
               ELSE 'AWAITING_DECISIONS'
           END,
           paused_at = CASE
               WHEN v_unresolved_count > 0 OR v_blocked_count > 0 THEN now()
               ELSE NULL
           END
     WHERE lor_reconciliation_run_id = p_lor_reconciliation_run_id
       AND status IN ('PREFLIGHT', 'AWAITING_DECISIONS', 'READY_TO_FINISH');

    RETURN v_inserted_count;
END;
$function$;

COMMENT ON FUNCTION ops.f_build_lor_reconciliation_stage_candidates(bigint) IS
'Creates immutable stage and LOR-binding candidates for one captured reconciliation run. Existing stages resolve by stable binding or stage key; manifest preview filenames remain separate evidence and preview names cannot silently rename permanent stage metadata.';


COMMIT;

SELECT
    '2026-08-03-preview-manifest-stage-bindings-v1'::text AS installed_revision,
    to_regprocedure('ops.f_build_lor_reconciliation_stage_candidates(bigint)')
        IS NOT NULL AS has_corrected_stage_builder;
