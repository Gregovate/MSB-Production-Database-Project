/* ============================================================================
Object group: Reconciliation-safe P3/P4 scene promotion
Filename:     0018_create_reconciliation_safe_scene_promotion.sql

Purpose:
  Freeze scene-definition and scene-display membership candidates for each
  reconciliation run, then install the internal P3 and P4 procedures that
  synchronize the production current-state scene projection.

Safety boundary:
  - Installation creates control objects, replaces the unified start function,
    and backfills frozen candidates for existing open reconciliation runs.
  - Installation does not call P1, P2, P3, or P4.
  - P3/P4 accept only a reconciliation-run ID and never select the latest run.
  - Blocked/deferred previews are preserved rather than partially synchronized.

Revision history:
  2026-08-03  GAL / OpenAI  Initial frozen scene and membership candidates,
                           reconciliation-gated P3/P4, guarded current-state
                           deletion, and same-run idempotency support.
============================================================================ */

BEGIN;

CREATE TABLE IF NOT EXISTS ops.lor_reconciliation_scene_candidate (
    lor_reconciliation_scene_candidate_id bigint
        GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    lor_reconciliation_run_id bigint NOT NULL
        REFERENCES ops.lor_reconciliation_run(lor_reconciliation_run_id),
    lor_reconciliation_group_id bigint NOT NULL
        REFERENCES ops.lor_reconciliation_group(lor_reconciliation_group_id),
    import_run_id bigint NOT NULL,
    candidate_key text NOT NULL,
    preview_id text NOT NULL,
    scene_id text NOT NULL,
    scene_name text NOT NULL,
    resolved_stage_key text,
    resolved_stage_id integer REFERENCES ref.stage(stage_id),
    existing_lor_scene_id bigint,
    scene_section text,
    background_file text,
    h_scroll integer,
    v_scroll integer,
    zoom integer,
    create_grid_view text,
    classification_code text NOT NULL,
    initial_resolution_state text NOT NULL,
    decision_required boolean NOT NULL DEFAULT false,
    is_blocking boolean NOT NULL,
    changed_fields text[] NOT NULL DEFAULT ARRAY[]::text[],
    operator_message text NOT NULL,
    source_evidence jsonb NOT NULL DEFAULT '{}'::jsonb,
    created_at timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT ux_lor_reconciliation_scene_candidate
        UNIQUE (lor_reconciliation_run_id, candidate_key),
    CONSTRAINT ck_lor_reconciliation_scene_state CHECK (
        initial_resolution_state IN ('AUTO_APPROVED', 'BLOCKED')
    )
);

CREATE INDEX IF NOT EXISTS ix_lor_reconciliation_scene_candidate_group
    ON ops.lor_reconciliation_scene_candidate(lor_reconciliation_group_id);

CREATE INDEX IF NOT EXISTS ix_lor_reconciliation_scene_candidate_identity
    ON ops.lor_reconciliation_scene_candidate
       (lor_reconciliation_run_id, preview_id, scene_id);

DROP TRIGGER IF EXISTS trg_lor_reconciliation_scene_candidate_immutable
    ON ops.lor_reconciliation_scene_candidate;
CREATE TRIGGER trg_lor_reconciliation_scene_candidate_immutable
BEFORE UPDATE OR DELETE ON ops.lor_reconciliation_scene_candidate
FOR EACH ROW EXECUTE FUNCTION ops.trg_lor_reconciliation_detail_immutable();

COMMENT ON TABLE ops.lor_reconciliation_scene_candidate IS
'Frozen scene definitions and resolved permanent stage identities for one captured reconciliation ingest.';

CREATE TABLE IF NOT EXISTS ops.lor_reconciliation_scene_display_candidate (
    lor_reconciliation_scene_display_candidate_id bigint
        GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    lor_reconciliation_run_id bigint NOT NULL
        REFERENCES ops.lor_reconciliation_run(lor_reconciliation_run_id),
    lor_reconciliation_group_id bigint NOT NULL
        REFERENCES ops.lor_reconciliation_group(lor_reconciliation_group_id),
    import_run_id bigint NOT NULL,
    candidate_key text NOT NULL,
    preview_id text NOT NULL,
    scene_id text NOT NULL,
    source_prop_id text NOT NULL,
    source_lor_prop_id text NOT NULL,
    lor_reconciliation_display_candidate_id bigint NOT NULL
        REFERENCES ops.lor_reconciliation_display_candidate(
            lor_reconciliation_display_candidate_id
        ),
    frozen_display_id bigint REFERENCES ref.display(display_id),
    existing_lor_scene_id bigint,
    existing_display_id bigint REFERENCES ref.display(display_id),
    scene_prop_ordinal integer,
    scene_role text,
    membership_source text,
    source_scene_count integer NOT NULL,
    classification_code text NOT NULL,
    initial_resolution_state text NOT NULL,
    decision_required boolean NOT NULL DEFAULT false,
    is_blocking boolean NOT NULL,
    operator_message text NOT NULL,
    source_evidence jsonb NOT NULL DEFAULT '{}'::jsonb,
    created_at timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT ux_lor_reconciliation_scene_display_candidate
        UNIQUE (lor_reconciliation_run_id, candidate_key),
    CONSTRAINT ck_lor_reconciliation_scene_display_state CHECK (
        initial_resolution_state IN ('AUTO_APPROVED', 'BLOCKED')
    ),
    CONSTRAINT ck_lor_reconciliation_scene_display_count CHECK (
        source_scene_count > 0
    )
);

CREATE INDEX IF NOT EXISTS ix_lor_reconciliation_scene_display_candidate_group
    ON ops.lor_reconciliation_scene_display_candidate(
        lor_reconciliation_group_id
    );

CREATE INDEX IF NOT EXISTS ix_lor_reconciliation_scene_display_identity
    ON ops.lor_reconciliation_scene_display_candidate
       (lor_reconciliation_run_id, preview_id, scene_id);

DROP TRIGGER IF EXISTS trg_lor_reconciliation_scene_display_candidate_immutable
    ON ops.lor_reconciliation_scene_display_candidate;
CREATE TRIGGER trg_lor_reconciliation_scene_display_candidate_immutable
BEFORE UPDATE OR DELETE ON ops.lor_reconciliation_scene_display_candidate
FOR EACH ROW EXECUTE FUNCTION ops.trg_lor_reconciliation_detail_immutable();

COMMENT ON TABLE ops.lor_reconciliation_scene_display_candidate IS
'Frozen physical-display scene memberships. P4 resolves permanent display_id after P2 without creating identity.';

CREATE OR REPLACE FUNCTION ops.f_build_lor_reconciliation_scene_candidates(
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
BEGIN
    SELECT r.import_run_id, r.status
      INTO v_import_run_id, v_run_status
    FROM ops.lor_reconciliation_run AS r
    WHERE r.lor_reconciliation_run_id = p_lor_reconciliation_run_id
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Reconciliation run % does not exist',
            p_lor_reconciliation_run_id;
    END IF;

    IF v_run_status IN ('CANCELLED', 'COMPLETED', 'COMPLETED_WITH_EXCEPTIONS') THEN
        RAISE EXCEPTION 'Reconciliation run % is closed with status %',
            p_lor_reconciliation_run_id, v_run_status;
    END IF;

    SELECT count(*) INTO v_existing_count
    FROM ops.lor_reconciliation_scene_candidate AS c
    WHERE c.lor_reconciliation_run_id = p_lor_reconciliation_run_id;

    IF v_existing_count > 0 THEN
        RETURN v_existing_count;
    END IF;

    CREATE TEMP TABLE pg_temp._lor_scene_build ON COMMIT DROP AS
    WITH preview_profile AS (
        SELECT
            p.id AS preview_id,
            btrim(p.name) AS preview_name,
            lower(nullif(btrim(p.stage_id), '')) AS preview_stage_key,
            (
                p.name ILIKE '%master musical preview%'
                OR count(DISTINCT lower(btrim(s.stage_id))) FILTER (
                    WHERE nullif(btrim(s.stage_id), '') IS NOT NULL
                ) > 1
            ) AS is_shared_preview
        FROM lor_snap.previews AS p
        LEFT JOIN lor_snap.scenes AS s
          ON s.import_run_id = p.import_run_id
         AND s.preview_id = p.id
        WHERE p.import_run_id = v_import_run_id
        GROUP BY p.id, p.name, p.stage_id
    ),
    source_scene AS (
        SELECT
            s.preview_id,
            s.scene_id,
            btrim(s.name) AS scene_name,
            pp.preview_name,
            pp.is_shared_preview,
            CASE WHEN pp.is_shared_preview
                 THEN CASE WHEN (
                     SELECT count(DISTINCT lower(btrim(coalesce(
                                slp.scene_stage_id, s.stage_id
                            ))))
                     FROM lor_snap.scene_lor_props AS slp
                     WHERE slp.import_run_id = s.import_run_id
                       AND slp.preview_id = s.preview_id
                       AND slp.scene_id = s.scene_id
                       AND nullif(btrim(coalesce(
                               slp.scene_stage_id, s.stage_id
                           )), '') IS NOT NULL
                 ) = 1 THEN (
                     SELECT min(lower(btrim(coalesce(
                                slp.scene_stage_id, s.stage_id
                            ))))
                     FROM lor_snap.scene_lor_props AS slp
                     WHERE slp.import_run_id = s.import_run_id
                       AND slp.preview_id = s.preview_id
                       AND slp.scene_id = s.scene_id
                 ) END
                 ELSE pp.preview_stage_key
            END AS resolved_stage_key,
            to_jsonb(s)->>'scene_section' AS scene_section,
            to_jsonb(s)->>'background_file' AS background_file,
            nullif(to_jsonb(s)->>'h_scroll', '')::integer AS h_scroll,
            nullif(to_jsonb(s)->>'v_scroll', '')::integer AS v_scroll,
            nullif(to_jsonb(s)->>'zoom', '')::integer AS zoom,
            to_jsonb(s)->>'create_grid_view' AS create_grid_view
        FROM lor_snap.scenes AS s
        JOIN preview_profile AS pp ON pp.preview_id = s.preview_id
        WHERE s.import_run_id = v_import_run_id
    ),
    resolved AS (
        SELECT
            ss.*,
            sc.resolved_stage_id,
            ls.lor_scene_id AS existing_lor_scene_id,
            ls.stage_id AS existing_stage_id,
            ls.scene_name AS existing_scene_name,
            ls.scene_section AS existing_scene_section,
            ls.background_file AS existing_background_file,
            ls.h_scroll AS existing_h_scroll,
            ls.v_scroll AS existing_v_scroll,
            ls.zoom AS existing_zoom,
            ls.create_grid_view AS existing_create_grid_view
        FROM source_scene AS ss
        LEFT JOIN ops.lor_reconciliation_stage_candidate AS sc
          ON sc.lor_reconciliation_run_id = p_lor_reconciliation_run_id
         AND (
             (NOT ss.is_shared_preview
              AND sc.binding_type = 'PREVIEW'
              AND sc.preview_id = ss.preview_id
              AND sc.scene_id IS NULL)
             OR
             (ss.is_shared_preview
              AND sc.binding_type = 'SCENE'
              AND sc.preview_id = ss.preview_id
              AND sc.scene_id = ss.scene_id)
         )
        LEFT JOIN ref.lor_scene AS ls
          ON ls.preview_uuid = ss.preview_id
         AND ls.scene_uuid = ss.scene_id
    )
    SELECT
        r.*,
        CASE
            WHEN r.resolved_stage_key IS NULL OR r.resolved_stage_id IS NULL
                THEN 'BLOCKED_SCENE_STAGE_NOT_RESOLVED'
            WHEN r.existing_lor_scene_id IS NULL THEN 'ADD_SCENE'
            WHEN r.existing_stage_id IS DISTINCT FROM r.resolved_stage_id
              OR r.existing_scene_name IS DISTINCT FROM r.scene_name
              OR r.existing_scene_section IS DISTINCT FROM r.scene_section
              OR r.existing_background_file IS DISTINCT FROM r.background_file
              OR r.existing_h_scroll IS DISTINCT FROM r.h_scroll
              OR r.existing_v_scroll IS DISTINCT FROM r.v_scroll
              OR r.existing_zoom IS DISTINCT FROM r.zoom
              OR r.existing_create_grid_view IS DISTINCT FROM r.create_grid_view
                THEN 'UPDATE_SCENE'
            ELSE 'UNCHANGED_SCENE'
        END AS classification_code,
        (r.resolved_stage_key IS NULL OR r.resolved_stage_id IS NULL) AS is_blocking
    FROM resolved AS r;

    INSERT INTO ops.lor_reconciliation_group (
        lor_reconciliation_run_id, import_run_id, entity_type,
        logical_group_key, group_kind, member_count,
        requires_atomic_decision, decision_required, allowed_action_types,
        operator_message
    )
    SELECT
        p_lor_reconciliation_run_id, v_import_run_id, 'SCENE',
        'SCENE:' || b.preview_id || ':' || b.scene_id,
        'SINGLE_CANDIDATE', 1, false, false, ARRAY[]::text[],
        CASE WHEN b.is_blocking
             THEN 'Scene stage identity is unresolved; scene and dependent memberships are blocked.'
             ELSE 'Scene is automatically approved from captured source and resolved stage evidence.'
        END
    FROM pg_temp._lor_scene_build AS b
    ON CONFLICT (lor_reconciliation_run_id, entity_type, logical_group_key)
    DO NOTHING;

    INSERT INTO ops.lor_reconciliation_scene_candidate (
        lor_reconciliation_run_id, lor_reconciliation_group_id, import_run_id,
        candidate_key, preview_id, scene_id, scene_name,
        resolved_stage_key, resolved_stage_id, existing_lor_scene_id,
        scene_section, background_file, h_scroll, v_scroll, zoom,
        create_grid_view, classification_code, initial_resolution_state,
        is_blocking, changed_fields, operator_message, source_evidence
    )
    SELECT
        p_lor_reconciliation_run_id, g.lor_reconciliation_group_id,
        v_import_run_id, 'SCENE:' || b.preview_id || ':' || b.scene_id,
        b.preview_id, b.scene_id, b.scene_name, b.resolved_stage_key,
        b.resolved_stage_id, b.existing_lor_scene_id, b.scene_section,
        b.background_file, b.h_scroll, b.v_scroll, b.zoom,
        b.create_grid_view, b.classification_code,
        CASE WHEN b.is_blocking THEN 'BLOCKED' ELSE 'AUTO_APPROVED' END,
        b.is_blocking,
        array_remove(ARRAY[
            CASE WHEN b.existing_lor_scene_id IS NULL THEN 'scene' END,
            CASE WHEN b.existing_stage_id IS DISTINCT FROM b.resolved_stage_id THEN 'stage_id' END,
            CASE WHEN b.existing_scene_name IS DISTINCT FROM b.scene_name THEN 'scene_name' END,
            CASE WHEN b.existing_scene_section IS DISTINCT FROM b.scene_section THEN 'scene_section' END,
            CASE WHEN b.existing_background_file IS DISTINCT FROM b.background_file THEN 'background_file' END,
            CASE WHEN b.existing_h_scroll IS DISTINCT FROM b.h_scroll THEN 'h_scroll' END,
            CASE WHEN b.existing_v_scroll IS DISTINCT FROM b.v_scroll THEN 'v_scroll' END,
            CASE WHEN b.existing_zoom IS DISTINCT FROM b.zoom THEN 'zoom' END,
            CASE WHEN b.existing_create_grid_view IS DISTINCT FROM b.create_grid_view THEN 'create_grid_view' END
        ]::text[], NULL),
        CASE WHEN b.is_blocking
             THEN 'No approved permanent stage_id is available for this scene.'
             ELSE b.classification_code || ' for permanent stage_id ' || b.resolved_stage_id || '.'
        END,
        jsonb_build_object(
            'preview_name', b.preview_name,
            'is_shared_preview', b.is_shared_preview,
            'resolved_stage_key', b.resolved_stage_key
        )
    FROM pg_temp._lor_scene_build AS b
    JOIN ops.lor_reconciliation_group AS g
      ON g.lor_reconciliation_run_id = p_lor_reconciliation_run_id
     AND g.entity_type = 'SCENE'
     AND g.logical_group_key = 'SCENE:' || b.preview_id || ':' || b.scene_id;

    GET DIAGNOSTICS v_inserted_count = ROW_COUNT;
    RETURN v_inserted_count;
END;
$function$;

COMMENT ON FUNCTION ops.f_build_lor_reconciliation_scene_candidates(bigint) IS
'Freezes scene definitions and resolved stage identities for one already-captured reconciliation ingest.';

CREATE OR REPLACE FUNCTION ops.f_build_lor_reconciliation_scene_display_candidates(
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
BEGIN
    SELECT r.import_run_id, r.status
      INTO v_import_run_id, v_run_status
    FROM ops.lor_reconciliation_run AS r
    WHERE r.lor_reconciliation_run_id = p_lor_reconciliation_run_id
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Reconciliation run % does not exist',
            p_lor_reconciliation_run_id;
    END IF;

    IF v_run_status IN ('CANCELLED', 'COMPLETED', 'COMPLETED_WITH_EXCEPTIONS') THEN
        RAISE EXCEPTION 'Reconciliation run % is closed with status %',
            p_lor_reconciliation_run_id, v_run_status;
    END IF;

    SELECT count(*) INTO v_existing_count
    FROM ops.lor_reconciliation_scene_display_candidate AS c
    WHERE c.lor_reconciliation_run_id = p_lor_reconciliation_run_id;

    IF v_existing_count > 0 THEN
        RETURN v_existing_count;
    END IF;

    CREATE TEMP TABLE pg_temp._lor_scene_display_build ON COMMIT DROP AS
    WITH physical_source AS (
        SELECT DISTINCT
            slp.preview_id,
            slp.scene_id,
            slp.prop_id AS source_prop_id,
            slp.raw_prop_id AS source_lor_prop_id,
            nullif(to_jsonb(slp)->>'scene_prop_ordinal', '')::integer
                AS scene_prop_ordinal,
            to_jsonb(slp)->>'scene_role' AS scene_role,
            to_jsonb(slp)->>'source' AS membership_source,
            dc.lor_reconciliation_display_candidate_id,
            dc.display_id AS frozen_display_id
        FROM lor_snap.scene_lor_props AS slp
        JOIN ops.lor_reconciliation_display_candidate AS dc
          ON dc.lor_reconciliation_run_id = p_lor_reconciliation_run_id
         AND dc.import_run_id = slp.import_run_id
         AND dc.source_prop_id = slp.prop_id
         AND dc.lor_prop_id = slp.raw_prop_id
         AND dc.candidate_class = 'PHYSICAL_DISPLAY'
        WHERE slp.import_run_id = v_import_run_id
    ),
    membership_count AS (
        SELECT
            ps.preview_id,
            ps.lor_reconciliation_display_candidate_id,
            count(DISTINCT ps.scene_id) AS source_scene_count
        FROM physical_source AS ps
        GROUP BY ps.preview_id,
                 ps.lor_reconciliation_display_candidate_id
    ),
    counted AS (
        SELECT
            ps.*,
            mc.source_scene_count
        FROM physical_source AS ps
        JOIN membership_count AS mc
          ON mc.preview_id = ps.preview_id
         AND mc.lor_reconciliation_display_candidate_id =
                ps.lor_reconciliation_display_candidate_id
    )
    SELECT
        c.*,
        sc.existing_lor_scene_id,
        current_membership.display_id AS existing_display_id,
        CASE
            WHEN sc.lor_reconciliation_scene_candidate_id IS NULL
                THEN 'BLOCKED_PARENT_SCENE_NOT_FROZEN'
            WHEN c.source_scene_count > 1
                THEN 'BLOCKED_MULTIPLE_SCENES_PER_PREVIEW_DISPLAY'
            WHEN current_membership.display_id IS NULL
                THEN 'ADD_SCENE_DISPLAY'
            WHEN sc.existing_lor_scene_id IS NOT NULL
             AND current_membership.lor_scene_id = sc.existing_lor_scene_id
                THEN 'UNCHANGED_SCENE_DISPLAY'
            ELSE 'REASSOCIATE_SCENE_DISPLAY'
        END AS classification_code,
        (sc.lor_reconciliation_scene_candidate_id IS NULL
         OR c.source_scene_count > 1
         OR sc.is_blocking) AS is_blocking
    FROM counted AS c
    LEFT JOIN ops.lor_reconciliation_scene_candidate AS sc
      ON sc.lor_reconciliation_run_id = p_lor_reconciliation_run_id
     AND sc.preview_id = c.preview_id
     AND sc.scene_id = c.scene_id
    LEFT JOIN ref.lor_scene_display AS current_membership
      ON current_membership.preview_uuid = c.preview_id
     AND current_membership.display_id = c.frozen_display_id;

    INSERT INTO ops.lor_reconciliation_group (
        lor_reconciliation_run_id, import_run_id, entity_type,
        logical_group_key, group_kind, member_count,
        requires_atomic_decision, decision_required, allowed_action_types,
        operator_message
    )
    SELECT
        p_lor_reconciliation_run_id, v_import_run_id, 'SCENE_DISPLAY',
        'SCENE_DISPLAY:' || b.preview_id || ':' ||
            b.lor_reconciliation_display_candidate_id,
        'SINGLE_CANDIDATE', 1, false, false, ARRAY[]::text[],
        CASE WHEN b.is_blocking
             THEN 'Scene membership is blocked and its current production assignment will be preserved.'
             ELSE 'Scene membership is automatically approved from captured physical-display evidence.'
        END
    FROM pg_temp._lor_scene_display_build AS b
    ON CONFLICT (lor_reconciliation_run_id, entity_type, logical_group_key)
    DO NOTHING;

    INSERT INTO ops.lor_reconciliation_scene_display_candidate (
        lor_reconciliation_run_id, lor_reconciliation_group_id, import_run_id,
        candidate_key, preview_id, scene_id, source_prop_id,
        source_lor_prop_id, lor_reconciliation_display_candidate_id,
        frozen_display_id, existing_lor_scene_id, existing_display_id,
        scene_prop_ordinal, scene_role, membership_source, source_scene_count,
        classification_code, initial_resolution_state, is_blocking,
        operator_message, source_evidence
    )
    SELECT
        p_lor_reconciliation_run_id, g.lor_reconciliation_group_id,
        v_import_run_id,
        'SCENE_DISPLAY:' || b.preview_id || ':' || b.scene_id || ':' ||
            b.lor_reconciliation_display_candidate_id,
        b.preview_id, b.scene_id, b.source_prop_id, b.source_lor_prop_id,
        b.lor_reconciliation_display_candidate_id, b.frozen_display_id,
        b.existing_lor_scene_id, b.existing_display_id,
        b.scene_prop_ordinal, b.scene_role, b.membership_source,
        b.source_scene_count, b.classification_code,
        CASE WHEN b.is_blocking THEN 'BLOCKED' ELSE 'AUTO_APPROVED' END,
        b.is_blocking,
        CASE WHEN b.is_blocking
             THEN b.classification_code || '; existing production membership is preserved.'
             ELSE b.classification_code || ' from captured scene membership.'
        END,
        jsonb_build_object('source_lor_prop_id', b.source_lor_prop_id)
    FROM pg_temp._lor_scene_display_build AS b
    JOIN ops.lor_reconciliation_group AS g
      ON g.lor_reconciliation_run_id = p_lor_reconciliation_run_id
     AND g.entity_type = 'SCENE_DISPLAY'
     AND g.logical_group_key = 'SCENE_DISPLAY:' || b.preview_id || ':' ||
         b.lor_reconciliation_display_candidate_id;

    GET DIAGNOSTICS v_inserted_count = ROW_COUNT;
    RETURN v_inserted_count;
END;
$function$;

COMMENT ON FUNCTION ops.f_build_lor_reconciliation_scene_display_candidates(bigint) IS
'Freezes physical-display scene memberships for one captured reconciliation ingest; excluded props never become candidates.';

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
    v_run_id := ops.f_start_lor_display_reconciliation(
        p_started_by_application
    );
    PERFORM ops.f_build_lor_reconciliation_stage_candidates(v_run_id);
    PERFORM ops.f_build_lor_reconciliation_scene_candidates(v_run_id);
    PERFORM ops.f_build_lor_reconciliation_scene_display_candidates(v_run_id);
    RETURN v_run_id;
END;
$function$;

COMMENT ON FUNCTION ops.f_start_lor_reconciliation(text) IS
'Unified reconciliation start: captures one completed ingest and freezes display, stage, scene, and scene-membership working sets for that same run.';

CREATE OR REPLACE VIEW ops.v_lor_reconciliation_operator_scene_review AS
SELECT
    c.lor_reconciliation_run_id,
    c.import_run_id,
    c.lor_reconciliation_group_id,
    c.preview_id,
    c.scene_id,
    c.scene_name,
    c.resolved_stage_key,
    c.resolved_stage_id,
    c.classification_code,
    c.changed_fields,
    c.is_blocking,
    c.operator_message,
    c.source_evidence
FROM ops.lor_reconciliation_scene_candidate AS c;

CREATE OR REPLACE VIEW ops.v_lor_reconciliation_operator_scene_display_review AS
SELECT
    c.lor_reconciliation_run_id,
    c.import_run_id,
    c.lor_reconciliation_group_id,
    c.preview_id,
    c.scene_id,
    c.source_prop_id,
    c.source_lor_prop_id,
    c.frozen_display_id,
    c.classification_code,
    c.is_blocking,
    c.operator_message,
    c.source_evidence
FROM ops.lor_reconciliation_scene_display_candidate AS c;

CREATE OR REPLACE PROCEDURE ref.p3_promote_scene_from_reconciliation(
    p_lor_reconciliation_run_id bigint
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, ops, lor_snap, ref
AS $procedure$
DECLARE
    v_import_run_id bigint;
    v_status text;
    v_bad_source integer;
    v_row record;
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
        RAISE EXCEPTION 'Reconciliation run % is %, not ready for P3',
            p_lor_reconciliation_run_id, v_status;
    END IF;

    SELECT count(*) INTO v_bad_source
    FROM ops.lor_reconciliation_scene_candidate AS c
    WHERE c.lor_reconciliation_run_id = p_lor_reconciliation_run_id
      AND NOT EXISTS (
          SELECT 1
          FROM lor_snap.scenes AS s
          WHERE s.import_run_id = v_import_run_id
            AND s.preview_id = c.preview_id
            AND s.scene_id = c.scene_id
            AND btrim(s.name) = c.scene_name
            AND (to_jsonb(s)->>'scene_section') IS NOT DISTINCT FROM c.scene_section
            AND (to_jsonb(s)->>'background_file') IS NOT DISTINCT FROM c.background_file
            AND nullif(to_jsonb(s)->>'h_scroll', '')::integer IS NOT DISTINCT FROM c.h_scroll
            AND nullif(to_jsonb(s)->>'v_scroll', '')::integer IS NOT DISTINCT FROM c.v_scroll
            AND nullif(to_jsonb(s)->>'zoom', '')::integer IS NOT DISTINCT FROM c.zoom
            AND (to_jsonb(s)->>'create_grid_view') IS NOT DISTINCT FROM c.create_grid_view
      );

    IF v_bad_source > 0 THEN
        RAISE EXCEPTION '% P3 candidates fail the captured raw-source guard for import_run_id %',
            v_bad_source, v_import_run_id;
    END IF;

    FOR v_row IN
        SELECT c.*
        FROM ops.lor_reconciliation_scene_candidate AS c
        WHERE c.lor_reconciliation_run_id = p_lor_reconciliation_run_id
          AND c.initial_resolution_state = 'AUTO_APPROVED'
          AND NOT c.is_blocking
        ORDER BY c.lor_reconciliation_scene_candidate_id
    LOOP
        INSERT INTO ref.lor_scene (
            preview_uuid, scene_uuid, stage_id, scene_name, scene_section,
            background_file, h_scroll, v_scroll, zoom, create_grid_view,
            source_import_run_id
        ) VALUES (
            v_row.preview_id, v_row.scene_id, v_row.resolved_stage_id,
            v_row.scene_name, v_row.scene_section, v_row.background_file,
            v_row.h_scroll, v_row.v_scroll, v_row.zoom,
            v_row.create_grid_view, v_import_run_id
        )
        ON CONFLICT (preview_uuid, scene_uuid) DO UPDATE
           SET stage_id = EXCLUDED.stage_id,
               scene_name = EXCLUDED.scene_name,
               scene_section = EXCLUDED.scene_section,
               background_file = EXCLUDED.background_file,
               h_scroll = EXCLUDED.h_scroll,
               v_scroll = EXCLUDED.v_scroll,
               zoom = EXCLUDED.zoom,
               create_grid_view = EXCLUDED.create_grid_view,
               source_import_run_id = EXCLUDED.source_import_run_id,
               updated_at = now(),
               updated_by = current_user
         WHERE ref.lor_scene.stage_id IS DISTINCT FROM EXCLUDED.stage_id
            OR ref.lor_scene.scene_name IS DISTINCT FROM EXCLUDED.scene_name
            OR ref.lor_scene.scene_section IS DISTINCT FROM EXCLUDED.scene_section
            OR ref.lor_scene.background_file IS DISTINCT FROM EXCLUDED.background_file
            OR ref.lor_scene.h_scroll IS DISTINCT FROM EXCLUDED.h_scroll
            OR ref.lor_scene.v_scroll IS DISTINCT FROM EXCLUDED.v_scroll
            OR ref.lor_scene.zoom IS DISTINCT FROM EXCLUDED.zoom
            OR ref.lor_scene.create_grid_view IS DISTINCT FROM EXCLUDED.create_grid_view
            OR ref.lor_scene.source_import_run_id IS DISTINCT FROM EXCLUDED.source_import_run_id;

        IF FOUND THEN
            INSERT INTO ops.lor_reconciliation_result (
                lor_reconciliation_run_id, import_run_id, entity_type,
                entity_key, result_class, reason_code, operator_message, committed
            ) VALUES (
                p_lor_reconciliation_run_id, v_import_run_id, 'SCENE',
                v_row.candidate_key,
                CASE WHEN v_row.existing_lor_scene_id IS NULL THEN 'ADDED' ELSE 'UPDATED' END,
                'P3_' || v_row.classification_code,
                format('P3 synchronized scene %s/%s to permanent stage_id %s.',
                       v_row.preview_id, v_row.scene_id, v_row.resolved_stage_id),
                true
            );
        END IF;
    END LOOP;

    /* Never delete from a preview containing a blocked frozen scene. */
    FOR v_row IN
        DELETE FROM ref.lor_scene AS ls
        WHERE (
            NOT EXISTS (
                SELECT 1 FROM lor_snap.previews AS p
                WHERE p.import_run_id = v_import_run_id
                  AND p.id = ls.preview_uuid
            )
            OR (
                NOT EXISTS (
                    SELECT 1
                    FROM ops.lor_reconciliation_scene_candidate AS blocked
                    WHERE blocked.lor_reconciliation_run_id = p_lor_reconciliation_run_id
                      AND blocked.preview_id = ls.preview_uuid
                      AND blocked.is_blocking
                )
                AND NOT EXISTS (
                    SELECT 1
                    FROM ops.lor_reconciliation_scene_candidate AS current_scene
                    WHERE current_scene.lor_reconciliation_run_id = p_lor_reconciliation_run_id
                      AND current_scene.preview_id = ls.preview_uuid
                      AND current_scene.scene_id = ls.scene_uuid
                )
            )
        )
        RETURNING ls.preview_uuid, ls.scene_uuid, ls.lor_scene_id
    LOOP
        INSERT INTO ops.lor_reconciliation_result (
            lor_reconciliation_run_id, import_run_id, entity_type,
            entity_key, result_class, reason_code, operator_message, committed
        ) VALUES (
            p_lor_reconciliation_run_id, v_import_run_id, 'SCENE',
            'SCENE:' || v_row.preview_uuid || ':' || v_row.scene_uuid,
            'UPDATED', 'P3_REMOVE_OBSOLETE_SCENE',
            format('P3 removed obsolete current-state scene %s/%s (lor_scene_id %s).',
                   v_row.preview_uuid, v_row.scene_uuid, v_row.lor_scene_id), true
        );
    END LOOP;
END;
$procedure$;

COMMENT ON PROCEDURE ref.p3_promote_scene_from_reconciliation(bigint) IS
'Internal reconciliation-gated P3. Synchronizes approved frozen scene definitions and safely removes obsolete current-state scenes.';

CREATE OR REPLACE PROCEDURE ref.p4_promote_scene_display_from_reconciliation(
    p_lor_reconciliation_run_id bigint
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, ops, lor_snap, ref
AS $procedure$
DECLARE
    v_import_run_id bigint;
    v_status text;
    v_bad_source integer;
    v_row record;
    v_display_id bigint;
    v_lor_scene_id bigint;
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
        RAISE EXCEPTION 'Reconciliation run % is %, not ready for P4',
            p_lor_reconciliation_run_id, v_status;
    END IF;

    SELECT count(*) INTO v_bad_source
    FROM ops.lor_reconciliation_scene_display_candidate AS c
    WHERE c.lor_reconciliation_run_id = p_lor_reconciliation_run_id
      AND NOT EXISTS (
          SELECT 1 FROM lor_snap.scene_lor_props AS slp
          WHERE slp.import_run_id = v_import_run_id
            AND slp.preview_id = c.preview_id
            AND slp.scene_id = c.scene_id
            AND slp.prop_id = c.source_prop_id
            AND slp.raw_prop_id = c.source_lor_prop_id
      );

    IF v_bad_source > 0 THEN
        RAISE EXCEPTION '% P4 candidates fail the captured raw-source guard for import_run_id %',
            v_bad_source, v_import_run_id;
    END IF;

    FOR v_row IN
        SELECT c.*
        FROM ops.lor_reconciliation_scene_display_candidate AS c
        JOIN ops.lor_reconciliation_display_candidate AS dc
          ON dc.lor_reconciliation_display_candidate_id =
             c.lor_reconciliation_display_candidate_id
        JOIN ops.v_lor_reconciliation_group_review AS display_group
          ON display_group.lor_reconciliation_group_id =
             dc.lor_reconciliation_group_id
        WHERE c.lor_reconciliation_run_id = p_lor_reconciliation_run_id
          AND c.initial_resolution_state = 'AUTO_APPROVED'
          AND NOT c.is_blocking
          AND display_group.effective_resolution_state IN ('AUTO_APPROVED', 'APPROVED')
        ORDER BY c.lor_reconciliation_scene_display_candidate_id
    LOOP
        SELECT d.display_id INTO v_display_id
        FROM ref.display AS d
        WHERE d.lor_prop_id = v_row.source_lor_prop_id;

        IF v_display_id IS NULL THEN
            RAISE EXCEPTION 'P4 cannot resolve permanent display for frozen source UUID %',
                v_row.source_lor_prop_id;
        END IF;

        SELECT ls.lor_scene_id INTO v_lor_scene_id
        FROM ref.lor_scene AS ls
        WHERE ls.preview_uuid = v_row.preview_id
          AND ls.scene_uuid = v_row.scene_id;

        IF v_lor_scene_id IS NULL THEN
            RAISE EXCEPTION 'P4 cannot resolve promoted scene %/%',
                v_row.preview_id, v_row.scene_id;
        END IF;

        INSERT INTO ref.lor_scene_display (
            lor_scene_id, preview_uuid, display_id, scene_prop_ordinal,
            scene_role, source, source_import_run_id
        ) VALUES (
            v_lor_scene_id, v_row.preview_id, v_display_id,
            v_row.scene_prop_ordinal, v_row.scene_role,
            v_row.membership_source, v_import_run_id
        )
        ON CONFLICT (preview_uuid, display_id) DO UPDATE
           SET lor_scene_id = EXCLUDED.lor_scene_id,
               scene_prop_ordinal = EXCLUDED.scene_prop_ordinal,
               scene_role = EXCLUDED.scene_role,
               source = EXCLUDED.source,
               source_import_run_id = EXCLUDED.source_import_run_id,
               updated_at = now(),
               updated_by = current_user
         WHERE ref.lor_scene_display.lor_scene_id IS DISTINCT FROM EXCLUDED.lor_scene_id
            OR ref.lor_scene_display.scene_prop_ordinal IS DISTINCT FROM EXCLUDED.scene_prop_ordinal
            OR ref.lor_scene_display.scene_role IS DISTINCT FROM EXCLUDED.scene_role
            OR ref.lor_scene_display.source IS DISTINCT FROM EXCLUDED.source
            OR ref.lor_scene_display.source_import_run_id IS DISTINCT FROM EXCLUDED.source_import_run_id;

        IF FOUND THEN
            INSERT INTO ops.lor_reconciliation_result (
                lor_reconciliation_run_id, import_run_id, entity_type,
                entity_key, result_class, reason_code, operator_message, committed
            ) VALUES (
                p_lor_reconciliation_run_id, v_import_run_id, 'SCENE_DISPLAY',
                v_row.candidate_key,
                CASE WHEN v_row.existing_display_id IS NULL THEN 'ADDED' ELSE 'REASSOCIATED' END,
                'P4_' || v_row.classification_code,
                format('P4 synchronized display_id %s to scene %s/%s.',
                       v_display_id, v_row.preview_id, v_row.scene_id), true
            );
        END IF;
    END LOOP;

    /* Conservative deletion: any blocked/deferred item preserves its preview. */
    FOR v_row IN
        DELETE FROM ref.lor_scene_display AS lsd
        WHERE NOT EXISTS (
                  SELECT 1 FROM lor_snap.previews AS p
                  WHERE p.import_run_id = v_import_run_id
                    AND p.id = lsd.preview_uuid
              )
           OR (
               NOT EXISTS (
                   SELECT 1
                   FROM ops.lor_reconciliation_scene_display_candidate AS blocked
                   WHERE blocked.lor_reconciliation_run_id = p_lor_reconciliation_run_id
                     AND blocked.preview_id = lsd.preview_uuid
                     AND blocked.is_blocking
               )
               AND NOT EXISTS (
                   SELECT 1
                   FROM ops.lor_reconciliation_scene_display_candidate AS held
                   JOIN ops.lor_reconciliation_display_candidate AS dc
                     ON dc.lor_reconciliation_display_candidate_id =
                        held.lor_reconciliation_display_candidate_id
                   JOIN ops.v_lor_reconciliation_group_review AS dgr
                     ON dgr.lor_reconciliation_group_id =
                        dc.lor_reconciliation_group_id
                   WHERE held.lor_reconciliation_run_id =
                         p_lor_reconciliation_run_id
                     AND held.preview_id = lsd.preview_uuid
                     AND dgr.effective_resolution_state NOT IN (
                         'AUTO_APPROVED', 'APPROVED'
                     )
               )
               AND NOT EXISTS (
                   SELECT 1
                   FROM ops.lor_reconciliation_scene_display_candidate AS current_member
                   JOIN ref.display AS d
                     ON d.lor_prop_id = current_member.source_lor_prop_id
                   WHERE current_member.lor_reconciliation_run_id = p_lor_reconciliation_run_id
                     AND current_member.preview_id = lsd.preview_uuid
                     AND d.display_id = lsd.display_id
               )
           )
        RETURNING lsd.preview_uuid, lsd.display_id, lsd.lor_scene_id
    LOOP
        INSERT INTO ops.lor_reconciliation_result (
            lor_reconciliation_run_id, import_run_id, entity_type,
            entity_key, result_class, reason_code, operator_message, committed
        ) VALUES (
            p_lor_reconciliation_run_id, v_import_run_id, 'SCENE_DISPLAY',
            'SCENE_DISPLAY:' || v_row.preview_uuid || ':' || v_row.display_id,
            'UPDATED', 'P4_REMOVE_OBSOLETE_MEMBERSHIP',
            format('P4 removed obsolete current-state membership for display_id %s in preview %s.',
                   v_row.display_id, v_row.preview_uuid), true
        );
    END LOOP;
END;
$procedure$;

COMMENT ON PROCEDURE ref.p4_promote_scene_display_from_reconciliation(bigint) IS
'Internal reconciliation-gated P4. Synchronizes approved frozen memberships by permanent display_id and conservatively removes obsolete current-state assignments.';

REVOKE EXECUTE ON FUNCTION
    ops.f_build_lor_reconciliation_scene_candidates(bigint) FROM PUBLIC;
REVOKE EXECUTE ON FUNCTION
    ops.f_build_lor_reconciliation_scene_display_candidates(bigint) FROM PUBLIC;
REVOKE EXECUTE ON FUNCTION ops.f_start_lor_reconciliation(text) FROM PUBLIC;
REVOKE EXECUTE ON PROCEDURE
    ref.p3_promote_scene_from_reconciliation(bigint) FROM PUBLIC;
REVOKE EXECUTE ON PROCEDURE
    ref.p4_promote_scene_display_from_reconciliation(bigint) FROM PUBLIC;

/* Freeze missing scene working sets for an existing open development run. */
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
        PERFORM ops.f_build_lor_reconciliation_scene_candidates(v_run_id);
        PERFORM ops.f_build_lor_reconciliation_scene_display_candidates(v_run_id);
    END LOOP;
END;
$backfill$;

COMMENT ON SCHEMA ops IS
'Operational workflow and audit objects. Reconciliation engine revision 2026-08-03-safe-scenes-v1 installed.';

COMMIT;

SELECT
    '2026-08-03-reconciliation-safe-scenes-v1'::text AS installed_revision,
    to_regclass('ops.lor_reconciliation_scene_candidate') IS NOT NULL
        AS has_scene_candidate_table,
    to_regclass('ops.lor_reconciliation_scene_display_candidate') IS NOT NULL
        AS has_membership_candidate_table,
    to_regprocedure('ops.f_build_lor_reconciliation_scene_candidates(bigint)')
        IS NOT NULL AS has_scene_builder,
    to_regprocedure('ops.f_build_lor_reconciliation_scene_display_candidates(bigint)')
        IS NOT NULL AS has_membership_builder,
    to_regprocedure('ref.p3_promote_scene_from_reconciliation(bigint)')
        IS NOT NULL AS has_p3_procedure,
    to_regprocedure('ref.p4_promote_scene_display_from_reconciliation(bigint)')
        IS NOT NULL AS has_p4_procedure;
