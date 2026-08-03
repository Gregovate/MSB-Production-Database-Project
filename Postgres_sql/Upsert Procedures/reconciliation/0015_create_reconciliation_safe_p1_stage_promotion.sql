/* ============================================================================
Object group: Reconciliation-safe P1 stage promotion
Repository:   Postgres_sql/Upsert Procedures/reconciliation/
File:         0015_create_reconciliation_safe_p1_stage_promotion.sql

Purpose:
  Add the durable stage-to-LOR identity binding, freeze stage candidates from
  each reconciliation run's already-captured V7 ingest, and install the P1
  promotion procedure that consumes only those frozen candidates.

Safety boundary:
  - Installation creates control/reference objects and backfills stage
    candidates for existing open reconciliation runs.
  - Installation does not call P1 and does not modify ref.stage rows.
  - P1 cannot select a latest ingest; it accepts a reconciliation-run ID and
    verifies every source row against that run's captured import_run_id.
  - P1 leaves blocked and deferred groups unchanged and never deletes stages.

Revision history:
  2026-08-02  GAL / OpenAI  Initial persistent stage binding, frozen candidate,
                           and reconciliation-gated P1 implementation.
============================================================================ */

BEGIN;

CREATE TABLE IF NOT EXISTS ref.stage_lor_binding (
    stage_lor_binding_id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    stage_id integer NOT NULL REFERENCES ref.stage(stage_id),
    binding_type text NOT NULL,
    preview_id text NOT NULL,
    scene_id text,
    source_name text,
    first_seen_import_run_id bigint NOT NULL,
    last_seen_import_run_id bigint NOT NULL,
    created_at timestamptz NOT NULL DEFAULT now(),
    created_by text NOT NULL DEFAULT current_user,
    updated_at timestamptz NOT NULL DEFAULT now(),
    updated_by text NOT NULL DEFAULT current_user,
    CONSTRAINT ck_stage_lor_binding_type CHECK (
        (binding_type = 'PREVIEW' AND scene_id IS NULL)
        OR
        (binding_type = 'SCENE' AND nullif(btrim(scene_id), '') IS NOT NULL)
    ),
    CONSTRAINT ck_stage_lor_binding_runs CHECK (
        first_seen_import_run_id > 0
        AND last_seen_import_run_id >= first_seen_import_run_id
    )
);

CREATE UNIQUE INDEX IF NOT EXISTS ux_stage_lor_binding_preview
    ON ref.stage_lor_binding (preview_id)
    WHERE binding_type = 'PREVIEW';

CREATE UNIQUE INDEX IF NOT EXISTS ux_stage_lor_binding_scene
    ON ref.stage_lor_binding (preview_id, scene_id)
    WHERE binding_type = 'SCENE';

CREATE INDEX IF NOT EXISTS ix_stage_lor_binding_stage
    ON ref.stage_lor_binding (stage_id);

COMMENT ON TABLE ref.stage_lor_binding IS
'Stable LOR preview/scene identities bound to permanent ref.stage.stage_id. Names and stage keys are mutable metadata.';

CREATE TABLE IF NOT EXISTS ops.lor_reconciliation_stage_candidate (
    lor_reconciliation_stage_candidate_id bigint
        GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    lor_reconciliation_run_id bigint NOT NULL
        REFERENCES ops.lor_reconciliation_run(lor_reconciliation_run_id),
    lor_reconciliation_group_id bigint NOT NULL
        REFERENCES ops.lor_reconciliation_group(lor_reconciliation_group_id),
    import_run_id bigint NOT NULL,
    candidate_key text NOT NULL,
    binding_type text NOT NULL,
    preview_id text NOT NULL,
    scene_id text,
    source_name text,
    source_stage_key text NOT NULL,
    resolved_stage_id integer REFERENCES ref.stage(stage_id),
    binding_stage_id integer REFERENCES ref.stage(stage_id),
    stage_key_stage_id integer REFERENCES ref.stage(stage_id),
    current_stage_key text,
    proposed_stage_key text NOT NULL,
    current_stage_name text,
    proposed_stage_name text,
    current_folder_name text,
    proposed_folder_name text,
    current_park_order integer,
    proposed_park_order integer,
    current_sub_order integer,
    proposed_sub_order integer,
    metadata_authoritative boolean NOT NULL,
    classification_code text NOT NULL,
    initial_resolution_state text NOT NULL,
    decision_required boolean NOT NULL,
    is_blocking boolean NOT NULL,
    changed_fields text[] NOT NULL DEFAULT ARRAY[]::text[],
    operator_message text NOT NULL,
    source_evidence jsonb NOT NULL DEFAULT '{}'::jsonb,
    created_at timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT ux_lor_reconciliation_stage_candidate
        UNIQUE (lor_reconciliation_run_id, candidate_key),
    CONSTRAINT ck_lor_reconciliation_stage_binding_type CHECK (
        (binding_type = 'PREVIEW' AND scene_id IS NULL)
        OR
        (binding_type = 'SCENE' AND nullif(btrim(scene_id), '') IS NOT NULL)
    ),
    CONSTRAINT ck_lor_reconciliation_stage_state CHECK (
        initial_resolution_state IN ('AUTO_APPROVED', 'DECISION_REQUIRED', 'BLOCKED')
    )
);

CREATE INDEX IF NOT EXISTS ix_lor_reconciliation_stage_candidate_group
    ON ops.lor_reconciliation_stage_candidate (lor_reconciliation_group_id);

DROP TRIGGER IF EXISTS trg_lor_reconciliation_stage_candidate_immutable
    ON ops.lor_reconciliation_stage_candidate;
CREATE TRIGGER trg_lor_reconciliation_stage_candidate_immutable
BEFORE UPDATE OR DELETE ON ops.lor_reconciliation_stage_candidate
FOR EACH ROW EXECUTE FUNCTION ops.trg_lor_reconciliation_detail_immutable();

COMMENT ON TABLE ops.lor_reconciliation_stage_candidate IS
'Frozen preview/scene-to-stage evidence for one captured reconciliation ingest. P1 consumes these rows without recalculating identity.';

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
            p.name ILIKE '%master musical preview%' AS is_shared_preview
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
            true AS metadata_authoritative
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
            false
        FROM populated_scenes AS ps
        JOIN preview_profile AS pp ON pp.preview_id = ps.preview_id
        WHERE pp.is_shared_preview
          AND ps.scene_stage_key ~ '^(0|[0-9]{1,2})[a-z]?$'
    ),
    resolved AS (
        SELECT
            e.*,
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
            'BINDING_STAGE_KEY_CONFLICT',
            'NEW_STAGE_REQUIRES_AUTHORITATIVE_DECISION'
        ) THEN 'DECISION_REQUIRED' ELSE 'AUTO_APPROVED' END
            AS initial_resolution_state,
        c.classification_code IN (
            'BINDING_STAGE_KEY_CONFLICT',
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
            WHEN 'BINDING_STAGE_KEY_CONFLICT' THEN
                'Stable LOR binding and current stage_key resolve to different permanent stages.'
            WHEN 'NEW_STAGE_REQUIRES_AUTHORITATIVE_DECISION' THEN
                'No existing permanent stage or stable binding resolves this source stage.'
            ELSE 'Captured source resolves to permanent stage_id ' || b.resolved_stage_id || '.'
        END,
        jsonb_build_object(
            'binding_stage_id', b.binding_stage_id,
            'stage_key_stage_id', b.stage_key_stage_id,
            'metadata_authoritative', b.metadata_authoritative
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
'Freezes canonical dedicated-preview and shared-preview-scene stage evidence for the reconciliation run''s captured ingest. Existing frozen rows are reused.';

CREATE OR REPLACE FUNCTION ops.f_start_lor_reconciliation(
    p_started_by_application text DEFAULT NULL
)
RETURNS bigint
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, ops, lor_snap, ref
AS $function$
DECLARE
    v_run_id bigint;
BEGIN
    /* The V7 display builder captures the latest completed ingest exactly once. */
    v_run_id := ops.f_start_lor_display_reconciliation(
        p_started_by_application
    );

    PERFORM ops.f_build_lor_reconciliation_stage_candidates(v_run_id);
    RETURN v_run_id;
END;
$function$;

COMMENT ON FUNCTION ops.f_start_lor_reconciliation(text) IS
'Unified reconciliation start: automatically captures one completed V7 ingest and freezes both display and stage candidate working sets for that same run.';

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
    c.proposed_stage_name,
    c.current_folder_name,
    c.proposed_folder_name,
    c.operator_message,
    c.source_evidence
FROM ops.v_lor_reconciliation_group_review AS gr
JOIN ops.lor_reconciliation_stage_candidate AS c
  ON c.lor_reconciliation_group_id = gr.lor_reconciliation_group_id
WHERE cardinality(c.changed_fields) > 0
   OR c.decision_required
   OR gr.effective_action_type IS NOT NULL;

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

    /* Re-read captured identities immediately before any production write. */
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
'Internal reconciliation-gated P1. Promotes approved frozen stage metadata and stable LOR bindings for the captured ingest; never selects an ingest or deletes stages.';

REVOKE EXECUTE ON FUNCTION ops.f_build_lor_reconciliation_stage_candidates(bigint)
    FROM PUBLIC;
REVOKE EXECUTE ON FUNCTION ops.f_start_lor_reconciliation(text)
    FROM PUBLIC;
REVOKE EXECUTE ON PROCEDURE ref.p1_promote_stage_from_reconciliation(bigint)
    FROM PUBLIC;

/* Backfill stage candidates for existing open runs without performing P1. */
DO $backfill$
DECLARE
    v_run_id bigint;
BEGIN
    FOR v_run_id IN
        SELECT r.lor_reconciliation_run_id
        FROM ops.lor_reconciliation_run AS r
        WHERE r.status IN (
            'STARTING', 'PREFLIGHT', 'AWAITING_DECISIONS',
            'READY_TO_FINISH', 'PROMOTING'
        )
        ORDER BY r.lor_reconciliation_run_id
    LOOP
        PERFORM ops.f_build_lor_reconciliation_stage_candidates(v_run_id);
    END LOOP;
END;
$backfill$;

COMMIT;

SELECT
    '2026-08-02-reconciliation-safe-p1-v1'::text AS installed_revision,
    to_regclass('ref.stage_lor_binding') IS NOT NULL AS has_stage_binding_table,
    to_regclass('ops.lor_reconciliation_stage_candidate') IS NOT NULL
        AS has_stage_candidate_table,
    to_regprocedure('ops.f_build_lor_reconciliation_stage_candidates(bigint)')
        IS NOT NULL AS has_stage_builder,
    to_regprocedure('ops.f_start_lor_reconciliation(text)')
        IS NOT NULL AS has_unified_start_function,
    to_regprocedure('ref.p1_promote_stage_from_reconciliation(bigint)')
        IS NOT NULL AS has_p1_procedure;
