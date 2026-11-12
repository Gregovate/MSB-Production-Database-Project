--
-- PostgreSQL database dump
--

\restrict wEr6hZXM5sd1EZLTBKaohjVXvnTneS8LdnM1jHe5E9xDvew41l8Pa9d4Pa4Uq3w

-- Dumped from database version 16.9 (Debian 16.9-1.pgdg110+1)
-- Dumped by pg_dump version 18.4

-- Started on 2026-08-08 09:10:52

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET transaction_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

--
-- TOC entry 16 (class 2615 OID 16389)
-- Name: lor_snap; Type: SCHEMA; Schema: -; Owner: msbadmin
--

CREATE SCHEMA lor_snap;


ALTER SCHEMA lor_snap OWNER TO msbadmin;

--
-- TOC entry 43 (class 2615 OID 17193)
-- Name: ops; Type: SCHEMA; Schema: -; Owner: msbadmin
--

CREATE SCHEMA ops;


ALTER SCHEMA ops OWNER TO msbadmin;

--
-- TOC entry 6113 (class 0 OID 0)
-- Dependencies: 43
-- Name: SCHEMA ops; Type: COMMENT; Schema: -; Owner: msbadmin
--

COMMENT ON SCHEMA ops IS 'Operational workflow and audit objects. Reconciliation engine revision 2026-08-06-one-reconciliation-per-snapshot-v4 installed.';


--
-- TOC entry 14 (class 2615 OID 2200)
-- Name: public; Type: SCHEMA; Schema: -; Owner: pg_database_owner
--

CREATE SCHEMA public;


ALTER SCHEMA public OWNER TO pg_database_owner;

--
-- TOC entry 6115 (class 0 OID 0)
-- Dependencies: 14
-- Name: SCHEMA public; Type: COMMENT; Schema: -; Owner: pg_database_owner
--

COMMENT ON SCHEMA public IS 'standard public schema';


--
-- TOC entry 44 (class 2615 OID 16687)
-- Name: ref; Type: SCHEMA; Schema: -; Owner: msbadmin
--

CREATE SCHEMA ref;


ALTER SCHEMA ref OWNER TO msbadmin;

--
-- TOC entry 6117 (class 0 OID 0)
-- Dependencies: 44
-- Name: SCHEMA ref; Type: COMMENT; Schema: -; Owner: msbadmin
--

COMMENT ON SCHEMA ref IS 'Schema for all reference tables (masters) ';


--
-- TOC entry 18 (class 2615 OID 16857)
-- Name: stage; Type: SCHEMA; Schema: -; Owner: msbadmin
--

CREATE SCHEMA stage;


ALTER SCHEMA stage OWNER TO msbadmin;

--
-- TOC entry 2178 (class 1247 OID 18888)
-- Name: display_test_status_enum; Type: TYPE; Schema: ops; Owner: msbadmin
--

CREATE TYPE ops.display_test_status_enum AS ENUM (
    'OK',
    'REPAIR',
    'DEFER'
);


ALTER TYPE ops.display_test_status_enum OWNER TO msbadmin;

--
-- TOC entry 2169 (class 1247 OID 18853)
-- Name: test_result_code; Type: TYPE; Schema: ops; Owner: msbadmin
--

CREATE TYPE ops.test_result_code AS ENUM (
    'OK',
    'REPAIR',
    'DEFER'
);


ALTER TYPE ops.test_result_code OWNER TO msbadmin;

--
-- TOC entry 834 (class 1255 OID 18081)
-- Name: _yn_to_bool(text); Type: FUNCTION; Schema: ops; Owner: msbadmin
--

CREATE FUNCTION ops._yn_to_bool(p_text text) RETURNS boolean
    LANGUAGE sql IMMUTABLE
    AS $$
  select case
    when p_text is null then null
    when upper(btrim(p_text)) in ('Y','YES','TRUE','T','1') then true
    when upper(btrim(p_text)) in ('N','NO','FALSE','F','0') then false
    else null
  end;
$$;


ALTER FUNCTION ops._yn_to_bool(p_text text) OWNER TO msbadmin;

--
-- TOC entry 1149 (class 1255 OID 19138)
-- Name: display_test_session_set_checked_fields(); Type: FUNCTION; Schema: ops; Owner: msbadmin
--

CREATE FUNCTION ops.display_test_session_set_checked_fields() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE
    v_person_id integer;
    v_actor_name text;
BEGIN
    -- Only stamp the first time test_status moves from NULL to a value
    IF OLD.test_status IS NULL
       AND NEW.test_status IS NOT NULL THEN

        SELECT person_id, actor_name
        INTO v_person_id, v_actor_name
        FROM ref.resolve_actor();

        NEW.checked_at := now();

        -- Respect values already stamped by Directus; otherwise fallback to DB actor resolution
        NEW.checked_by := COALESCE(NEW.checked_by, v_actor_name);
        NEW.checked_by_person_id := COALESCE(NEW.checked_by_person_id, v_person_id);
    END IF;

    RETURN NEW;
END;
$$;


ALTER FUNCTION ops.display_test_session_set_checked_fields() OWNER TO msbadmin;

--
-- TOC entry 734 (class 1255 OID 23792)
-- Name: f_build_lor_reconciliation_scene_candidates(bigint); Type: FUNCTION; Schema: ops; Owner: msbadmin
--

CREATE FUNCTION ops.f_build_lor_reconciliation_scene_candidates(p_lor_reconciliation_run_id bigint) RETURNS integer
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'pg_catalog', 'ops', 'lor_snap', 'ref'
    AS $$
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
$$;


ALTER FUNCTION ops.f_build_lor_reconciliation_scene_candidates(p_lor_reconciliation_run_id bigint) OWNER TO msbadmin;

--
-- TOC entry 6122 (class 0 OID 0)
-- Dependencies: 734
-- Name: FUNCTION f_build_lor_reconciliation_scene_candidates(p_lor_reconciliation_run_id bigint); Type: COMMENT; Schema: ops; Owner: msbadmin
--

COMMENT ON FUNCTION ops.f_build_lor_reconciliation_scene_candidates(p_lor_reconciliation_run_id bigint) IS 'Freezes scene definitions and resolved stage identities for one already-captured reconciliation ingest.';


--
-- TOC entry 1224 (class 1255 OID 23794)
-- Name: f_build_lor_reconciliation_scene_display_candidates(bigint); Type: FUNCTION; Schema: ops; Owner: msbadmin
--

CREATE FUNCTION ops.f_build_lor_reconciliation_scene_display_candidates(p_lor_reconciliation_run_id bigint) RETURNS integer
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'pg_catalog', 'ops', 'lor_snap', 'ref'
    AS $$
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
$$;


ALTER FUNCTION ops.f_build_lor_reconciliation_scene_display_candidates(p_lor_reconciliation_run_id bigint) OWNER TO msbadmin;

--
-- TOC entry 6124 (class 0 OID 0)
-- Dependencies: 1224
-- Name: FUNCTION f_build_lor_reconciliation_scene_display_candidates(p_lor_reconciliation_run_id bigint); Type: COMMENT; Schema: ops; Owner: msbadmin
--

COMMENT ON FUNCTION ops.f_build_lor_reconciliation_scene_display_candidates(p_lor_reconciliation_run_id bigint) IS 'Freezes physical-display scene memberships for one captured reconciliation ingest; excluded props never become candidates.';


--
-- TOC entry 616 (class 1255 OID 23656)
-- Name: f_build_lor_reconciliation_stage_candidates(bigint); Type: FUNCTION; Schema: ops; Owner: msbadmin
--

CREATE FUNCTION ops.f_build_lor_reconciliation_stage_candidates(p_lor_reconciliation_run_id bigint) RETURNS integer
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'pg_catalog', 'ops', 'lor_snap', 'ref'
    AS $_$
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
$_$;


ALTER FUNCTION ops.f_build_lor_reconciliation_stage_candidates(p_lor_reconciliation_run_id bigint) OWNER TO msbadmin;

--
-- TOC entry 6126 (class 0 OID 0)
-- Dependencies: 616
-- Name: FUNCTION f_build_lor_reconciliation_stage_candidates(p_lor_reconciliation_run_id bigint); Type: COMMENT; Schema: ops; Owner: msbadmin
--

COMMENT ON FUNCTION ops.f_build_lor_reconciliation_stage_candidates(p_lor_reconciliation_run_id bigint) IS 'Creates immutable stage and LOR-binding candidates for one captured reconciliation run. Existing stages resolve by stable binding or stage key; manifest preview filenames remain separate evidence and preview names cannot silently rename permanent stage metadata.';


--
-- TOC entry 1186 (class 1255 OID 23923)
-- Name: f_freeze_lor_reconciliation_source_evidence(bigint); Type: FUNCTION; Schema: ops; Owner: msbadmin
--

CREATE FUNCTION ops.f_freeze_lor_reconciliation_source_evidence(p_lor_reconciliation_run_id bigint) RETURNS void
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'pg_catalog', 'ops', 'lor_snap'
    AS $$
DECLARE
    v_import_run_id bigint;
    v_recorded_preview_count integer;
    v_recorded_scene_count integer;
    v_actual_preview_count integer;
    v_actual_scene_count integer;
    v_frozen_preview_count integer;
    v_frozen_scene_count integer;
BEGIN
    SELECT r.import_run_id
      INTO v_import_run_id
    FROM ops.lor_reconciliation_run AS r
    WHERE r.lor_reconciliation_run_id = p_lor_reconciliation_run_id
    FOR UPDATE;

    IF v_import_run_id IS NULL THEN
        RAISE EXCEPTION 'Reconciliation run % does not exist',
            p_lor_reconciliation_run_id;
    END IF;

    SELECT ir.preview_count, ir.scene_count
      INTO v_recorded_preview_count, v_recorded_scene_count
    FROM lor_snap.import_run AS ir
    WHERE ir.import_run_id = v_import_run_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Captured import_run_id % no longer exists',
            v_import_run_id;
    END IF;

    SELECT count(*)::integer INTO v_actual_preview_count
    FROM lor_snap.previews WHERE import_run_id = v_import_run_id;

    SELECT count(*)::integer INTO v_actual_scene_count
    FROM lor_snap.scenes WHERE import_run_id = v_import_run_id;

    IF v_recorded_preview_count IS DISTINCT FROM v_actual_preview_count THEN
        RAISE EXCEPTION
            'Captured import_run_id % preview count mismatch: recorded %, actual %',
            v_import_run_id, v_recorded_preview_count, v_actual_preview_count;
    END IF;

    IF v_recorded_scene_count IS DISTINCT FROM v_actual_scene_count THEN
        RAISE EXCEPTION
            'Captured import_run_id % scene count mismatch: recorded %, actual %',
            v_import_run_id, v_recorded_scene_count, v_actual_scene_count;
    END IF;

    INSERT INTO ops.lor_reconciliation_source_run (
        lor_reconciliation_run_id, import_run_id, run_ts, notes,
        parser_version, parser_started_at, parser_completed_at,
        parser_actor, parser_host, source_preview_folder, source_sqlite_path,
        preview_count, scene_count, prop_count, sub_prop_count,
        dmx_channel_count, scene_lor_prop_count, ingest_script_version,
        ingest_actor, ingest_host, ingest_started_at, ingest_completed_at
    )
    SELECT
        p_lor_reconciliation_run_id, ir.import_run_id, ir.run_ts, ir.notes,
        ir.parser_version, ir.parser_started_at, ir.parser_completed_at,
        ir.parser_actor, ir.parser_host, ir.source_preview_folder,
        ir.source_sqlite_path, ir.preview_count, ir.scene_count, ir.prop_count,
        ir.sub_prop_count, ir.dmx_channel_count, ir.scene_lor_prop_count,
        ir.ingest_script_version, ir.ingest_actor, ir.ingest_host,
        ir.ingest_started_at, ir.ingest_completed_at
    FROM lor_snap.import_run AS ir
    WHERE ir.import_run_id = v_import_run_id
    ON CONFLICT (lor_reconciliation_run_id) DO NOTHING;

    INSERT INTO ops.lor_reconciliation_source_preview (
        lor_reconciliation_run_id, import_run_id, int_preview_id,
        preview_id, stage_id, preview_name, preview_revision, brightness,
        background_file, source_filename
    )
    SELECT
        p_lor_reconciliation_run_id, p.import_run_id, p.int_preview_id,
        p.id, p.stage_id, p.name, p.revision, p.brightness,
        p.background_file, p.source_filename
    FROM lor_snap.previews AS p
    WHERE p.import_run_id = v_import_run_id
    ON CONFLICT (lor_reconciliation_run_id, int_preview_id) DO NOTHING;

    IF NOT EXISTS (
        SELECT 1 FROM ops.lor_reconciliation_source_scene
        WHERE lor_reconciliation_run_id = p_lor_reconciliation_run_id
    ) THEN
        INSERT INTO ops.lor_reconciliation_source_scene (
            lor_reconciliation_run_id, import_run_id, int_scene_id, scene_id,
            preview_id, stage_id, scene_name, scene_section, background_file,
            h_scroll, v_scroll, zoom, create_grid_view
        )
        SELECT
            p_lor_reconciliation_run_id, s.import_run_id, s.int_scene_id,
            s.scene_id, s.preview_id, s.stage_id, s.name, s.scene_section,
            s.background_file, s.h_scroll, s.v_scroll, s.zoom,
            s.create_grid_view
        FROM lor_snap.scenes AS s
        WHERE s.import_run_id = v_import_run_id;
    END IF;

    SELECT count(*)::integer INTO v_frozen_preview_count
    FROM ops.lor_reconciliation_source_preview
    WHERE lor_reconciliation_run_id = p_lor_reconciliation_run_id;

    SELECT count(*)::integer INTO v_frozen_scene_count
    FROM ops.lor_reconciliation_source_scene
    WHERE lor_reconciliation_run_id = p_lor_reconciliation_run_id;

    IF v_frozen_preview_count IS DISTINCT FROM v_actual_preview_count
       OR v_frozen_scene_count IS DISTINCT FROM v_actual_scene_count THEN
        RAISE EXCEPTION
            'Frozen evidence count mismatch for reconciliation run %: previews %/%, scenes %/%',
            p_lor_reconciliation_run_id,
            v_frozen_preview_count, v_actual_preview_count,
            v_frozen_scene_count, v_actual_scene_count;
    END IF;
END;
$$;


ALTER FUNCTION ops.f_freeze_lor_reconciliation_source_evidence(p_lor_reconciliation_run_id bigint) OWNER TO msbadmin;

--
-- TOC entry 6128 (class 0 OID 0)
-- Dependencies: 1186
-- Name: FUNCTION f_freeze_lor_reconciliation_source_evidence(p_lor_reconciliation_run_id bigint); Type: COMMENT; Schema: ops; Owner: msbadmin
--

COMMENT ON FUNCTION ops.f_freeze_lor_reconciliation_source_evidence(p_lor_reconciliation_run_id bigint) IS 'Atomically freezes complete ingest provenance and all preview/scene report evidence for one captured reconciliation run.';


--
-- TOC entry 692 (class 1255 OID 24041)
-- Name: f_lor_reconciliation_display_name_changes_report(bigint); Type: FUNCTION; Schema: ops; Owner: msbadmin
--

CREATE FUNCTION ops.f_lor_reconciliation_display_name_changes_report(p_lor_reconciliation_run_id bigint) RETURNS TABLE("Display_id" bigint, "Before" text, "After" text, "Follow-up" text)
    LANGUAGE sql STABLE
    SET search_path TO 'pg_catalog', 'ops'
    AS $$
    SELECT
        a.display_id AS "Display_id",
        a.before_name AS "Before",
        a.after_name AS "After",
        a.follow_up AS "Follow-up"
    FROM ops.v_lor_reconciliation_display_name_change_audit AS a
    WHERE a.lor_reconciliation_run_id = p_lor_reconciliation_run_id
    ORDER BY a.display_id;
$$;


ALTER FUNCTION ops.f_lor_reconciliation_display_name_changes_report(p_lor_reconciliation_run_id bigint) OWNER TO msbadmin;

--
-- TOC entry 6130 (class 0 OID 0)
-- Dependencies: 692
-- Name: FUNCTION f_lor_reconciliation_display_name_changes_report(p_lor_reconciliation_run_id bigint); Type: COMMENT; Schema: ops; Owner: msbadmin
--

COMMENT ON FUNCTION ops.f_lor_reconciliation_display_name_changes_report(p_lor_reconciliation_run_id bigint) IS 'Returns only Display_id, Before, After, and Follow-up for actual committed display-name changes in one reconciliation run.';


--
-- TOC entry 509 (class 1255 OID 23113)
-- Name: f_lor_reconciliation_summary(bigint); Type: FUNCTION; Schema: ops; Owner: msbadmin
--

CREATE FUNCTION ops.f_lor_reconciliation_summary(p_import_run_id bigint) RETURNS TABLE(import_run_id bigint, total_count integer, exact_match_count integer, excluded_nonphysical_count integer, blocking_count integer, preflight_status text)
    LANGUAGE sql STABLE
    AS $$
    SELECT
        p_import_run_id,
        count(*)::integer AS total_count,
        count(*) FILTER (WHERE classification_code = 'EXACT_MATCH')::integer
            AS exact_match_count,
        count(*) FILTER (WHERE classification_code = 'EXCLUDED_NONPHYSICAL')::integer
            AS excluded_nonphysical_count,
        count(*) FILTER (WHERE is_blocking)::integer AS blocking_count,
        CASE
            WHEN NOT EXISTS (
                SELECT 1
                FROM lor_snap.import_run AS ir
                WHERE ir.import_run_id = p_import_run_id
            ) THEN 'IMPORT_RUN_NOT_FOUND'
            WHEN count(*) FILTER (WHERE is_blocking) = 0 THEN 'PASSED'
            ELSE 'BLOCKED'
        END AS preflight_status
    FROM ops.v_lor_display_reconciliation
    WHERE import_run_id = p_import_run_id;
$$;


ALTER FUNCTION ops.f_lor_reconciliation_summary(p_import_run_id bigint) OWNER TO msbadmin;

--
-- TOC entry 6132 (class 0 OID 0)
-- Dependencies: 509
-- Name: FUNCTION f_lor_reconciliation_summary(p_import_run_id bigint); Type: COMMENT; Schema: ops; Owner: msbadmin
--

COMMENT ON FUNCTION ops.f_lor_reconciliation_summary(p_import_run_id bigint) IS 'Returns read-only display reconciliation counts and pass/block status for one explicit immutable LOR import_run_id.';


--
-- TOC entry 485 (class 1255 OID 23559)
-- Name: f_record_lor_reconciliation_action(bigint, bigint, text, text, jsonb, text); Type: FUNCTION; Schema: ops; Owner: msbadmin
--

CREATE FUNCTION ops.f_record_lor_reconciliation_action(p_lor_reconciliation_run_id bigint, p_lor_reconciliation_group_id bigint, p_action_type text, p_reason text, p_reassociation_map jsonb DEFAULT NULL::jsonb, p_acted_by_application text DEFAULT NULL::text) RETURNS bigint
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'pg_catalog', 'ops', 'lor_snap', 'ref'
    AS $$
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
$$;


ALTER FUNCTION ops.f_record_lor_reconciliation_action(p_lor_reconciliation_run_id bigint, p_lor_reconciliation_group_id bigint, p_action_type text, p_reason text, p_reassociation_map jsonb, p_acted_by_application text) OWNER TO msbadmin;

--
-- TOC entry 6134 (class 0 OID 0)
-- Dependencies: 485
-- Name: FUNCTION f_record_lor_reconciliation_action(p_lor_reconciliation_run_id bigint, p_lor_reconciliation_group_id bigint, p_action_type text, p_reason text, p_reassociation_map jsonb, p_acted_by_application text); Type: COMMENT; Schema: ops; Owner: msbadmin
--

COMMENT ON FUNCTION ops.f_record_lor_reconciliation_action(p_lor_reconciliation_run_id bigint, p_lor_reconciliation_group_id bigint, p_action_type text, p_reason text, p_reassociation_map jsonb, p_acted_by_application text) IS 'Records one append-only group action. Atomic reassociation is rejected unless every persisted group member has one valid permanent display target.';


--
-- TOC entry 576 (class 1255 OID 23561)
-- Name: f_record_lor_reconciliation_bulk_action(bigint, bigint[], text, text, text); Type: FUNCTION; Schema: ops; Owner: msbadmin
--

CREATE FUNCTION ops.f_record_lor_reconciliation_bulk_action(p_lor_reconciliation_run_id bigint, p_lor_reconciliation_group_ids bigint[], p_action_type text, p_reason text, p_acted_by_application text DEFAULT NULL::text) RETURNS TABLE(lor_reconciliation_group_id bigint, lor_reconciliation_action_id bigint)
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'pg_catalog', 'ops', 'lor_snap', 'ref'
    AS $$
DECLARE
    v_group_id bigint;
BEGIN
    IF p_lor_reconciliation_group_ids IS NULL
       OR cardinality(p_lor_reconciliation_group_ids) = 0 THEN
        RAISE EXCEPTION 'At least one logical group is required';
    END IF;

    IF p_action_type = 'REASSOCIATE_DISPLAY' THEN
        RAISE EXCEPTION
            'Atomic reassociation requires an individual complete mapping and cannot use the bulk-action function';
    END IF;

    IF cardinality(p_lor_reconciliation_group_ids)
       <> (
            SELECT count(DISTINCT selected_group_id)
            FROM unnest(p_lor_reconciliation_group_ids)
                AS selected(selected_group_id)
          ) THEN
        RAISE EXCEPTION 'The logical-group selection contains duplicate IDs';
    END IF;

    FOREACH v_group_id IN ARRAY p_lor_reconciliation_group_ids
    LOOP
        lor_reconciliation_group_id := v_group_id;
        lor_reconciliation_action_id :=
            ops.f_record_lor_reconciliation_action(
                p_lor_reconciliation_run_id,
                v_group_id,
                p_action_type,
                p_reason,
                NULL,
                p_acted_by_application
            );
        RETURN NEXT;
    END LOOP;
END;
$$;


ALTER FUNCTION ops.f_record_lor_reconciliation_bulk_action(p_lor_reconciliation_run_id bigint, p_lor_reconciliation_group_ids bigint[], p_action_type text, p_reason text, p_acted_by_application text) OWNER TO msbadmin;

--
-- TOC entry 6136 (class 0 OID 0)
-- Dependencies: 576
-- Name: FUNCTION f_record_lor_reconciliation_bulk_action(p_lor_reconciliation_run_id bigint, p_lor_reconciliation_group_ids bigint[], p_action_type text, p_reason text, p_acted_by_application text); Type: COMMENT; Schema: ops; Owner: msbadmin
--

COMMENT ON FUNCTION ops.f_record_lor_reconciliation_bulk_action(p_lor_reconciliation_run_id bigint, p_lor_reconciliation_group_ids bigint[], p_action_type text, p_reason text, p_acted_by_application text) IS 'Records the same permitted action for an operator-selected set of independent logical groups in one transaction. Atomic reassociation remains group-specific.';


--
-- TOC entry 1031 (class 1255 OID 23676)
-- Name: f_record_lor_stage_preserve_metadata_action(bigint, bigint, text, text); Type: FUNCTION; Schema: ops; Owner: msbadmin
--

CREATE FUNCTION ops.f_record_lor_stage_preserve_metadata_action(p_lor_reconciliation_run_id bigint, p_lor_reconciliation_group_id bigint, p_reason text, p_acted_by_application text DEFAULT NULL::text) RETURNS bigint
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'pg_catalog', 'ops', 'lor_snap', 'ref'
    AS $$
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
$$;


ALTER FUNCTION ops.f_record_lor_stage_preserve_metadata_action(p_lor_reconciliation_run_id bigint, p_lor_reconciliation_group_id bigint, p_reason text, p_acted_by_application text) OWNER TO msbadmin;

--
-- TOC entry 6138 (class 0 OID 0)
-- Dependencies: 1031
-- Name: FUNCTION f_record_lor_stage_preserve_metadata_action(p_lor_reconciliation_run_id bigint, p_lor_reconciliation_group_id bigint, p_reason text, p_acted_by_application text); Type: COMMENT; Schema: ops; Owner: msbadmin
--

COMMENT ON FUNCTION ops.f_record_lor_stage_preserve_metadata_action(p_lor_reconciliation_run_id bigint, p_lor_reconciliation_group_id bigint, p_reason text, p_acted_by_application text) IS 'Records the stage-only decision that preserves permanent ref.stage metadata while approving every frozen LOR binding in an eligible multi-preview group.';


--
-- TOC entry 910 (class 1255 OID 23675)
-- Name: f_stage_group_can_preserve_existing_metadata(bigint); Type: FUNCTION; Schema: ops; Owner: msbadmin
--

CREATE FUNCTION ops.f_stage_group_can_preserve_existing_metadata(p_lor_reconciliation_group_id bigint) RETURNS boolean
    LANGUAGE sql STABLE SECURITY DEFINER
    SET search_path TO 'pg_catalog', 'ops', 'ref'
    AS $$
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
$$;


ALTER FUNCTION ops.f_stage_group_can_preserve_existing_metadata(p_lor_reconciliation_group_id bigint) OWNER TO msbadmin;

--
-- TOC entry 6140 (class 0 OID 0)
-- Dependencies: 910
-- Name: FUNCTION f_stage_group_can_preserve_existing_metadata(p_lor_reconciliation_group_id bigint); Type: COMMENT; Schema: ops; Owner: msbadmin
--

COMMENT ON FUNCTION ops.f_stage_group_can_preserve_existing_metadata(p_lor_reconciliation_group_id bigint) IS 'True only for a decision-required stage group whose complete frozen membership resolves to one existing permanent stage and contains conflicting authoritative preview names.';


--
-- TOC entry 820 (class 1255 OID 23557)
-- Name: f_start_lor_display_reconciliation(text); Type: FUNCTION; Schema: ops; Owner: msbadmin
--

CREATE FUNCTION ops.f_start_lor_display_reconciliation(p_started_by_application text DEFAULT NULL::text) RETURNS bigint
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'pg_catalog', 'ops', 'lor_snap', 'ref'
    AS $$
DECLARE
    v_import_run_id bigint;
    v_run_id bigint;
    v_decision_count integer;
    v_blocked_count integer;
    v_old_run record;
    v_old_unresolved integer;
    v_old_deferred integer;
    v_old_blocked integer;
    v_freeze_error text;
BEGIN
    PERFORM pg_advisory_xact_lock(hashtext('ops.lor_reconciliation.start'));

    SELECT cr.import_run_id
      INTO v_import_run_id
    FROM lor_snap.v_current_run AS cr;

    IF v_import_run_id IS NULL THEN
        RAISE EXCEPTION 'No completed LOR snapshot is available';
    END IF;

    INSERT INTO ops.lor_reconciliation_run (
        import_run_id, status, started_by_application
    ) VALUES (
        v_import_run_id, 'PREFLIGHT', nullif(btrim(p_started_by_application), '')
    )
    RETURNING lor_reconciliation_run_id INTO v_run_id;

    FOR v_old_run IN
        SELECT r.lor_reconciliation_run_id, r.import_run_id
        FROM ops.lor_reconciliation_run AS r
        WHERE r.lor_reconciliation_run_id <> v_run_id
          AND r.status IN (
              'STARTING', 'PREFLIGHT', 'AWAITING_DECISIONS',
              'READY_TO_FINISH'
          )
        ORDER BY r.lor_reconciliation_run_id
        FOR UPDATE
    LOOP
        v_freeze_error := NULL;
        BEGIN
            PERFORM ops.f_freeze_lor_reconciliation_source_evidence(
                v_old_run.lor_reconciliation_run_id
            );
        EXCEPTION
            WHEN OTHERS THEN
                v_freeze_error := SQLERRM;
        END;

        INSERT INTO ops.lor_reconciliation_result (
            lor_reconciliation_run_id, import_run_id, entity_type, entity_key,
            result_class, reason_code, operator_message, committed
        )
        SELECT
            gr.lor_reconciliation_run_id, gr.import_run_id, gr.entity_type,
            gr.logical_group_key, 'UNRESOLVED',
            'SUPERSEDED_WITHOUT_REQUIRED_DECISION',
            coalesce(
                gr.operator_message,
                'Required operator decision was incomplete when a later reconciliation attempt started.'
            ),
            false
        FROM ops.v_lor_reconciliation_group_review AS gr
        WHERE gr.lor_reconciliation_run_id =
              v_old_run.lor_reconciliation_run_id
          AND gr.effective_resolution_state = 'UNRESOLVED'
          AND NOT EXISTS (
              SELECT 1
              FROM ops.lor_reconciliation_result AS rr
              WHERE rr.lor_reconciliation_run_id =
                    gr.lor_reconciliation_run_id
                AND rr.entity_type = gr.entity_type
                AND rr.entity_key = gr.logical_group_key
                AND rr.reason_code =
                    'SUPERSEDED_WITHOUT_REQUIRED_DECISION'
          );

        INSERT INTO ops.lor_reconciliation_result (
            lor_reconciliation_run_id, import_run_id, entity_type, entity_key,
            result_class, reason_code, operator_message, committed
        )
        SELECT
            gr.lor_reconciliation_run_id,
            gr.import_run_id,
            gr.entity_type,
            gr.logical_group_key,
            CASE
                WHEN gr.effective_action_type = 'DEFER'
                    THEN 'DEFERRED'
                ELSE 'BLOCKED'
            END,
            CASE
                WHEN gr.effective_action_type = 'DEFER'
                    THEN 'SUPERSEDED_OPERATOR_DEFERRED'
                ELSE 'SUPERSEDED_OPERATOR_CHANGE_NOT_ACCEPTED'
            END,
            coalesce(
                gr.effective_reason,
                'The operator left production unchanged before this attempt was superseded.'
            ),
            false
        FROM ops.v_lor_reconciliation_group_review AS gr
        WHERE gr.lor_reconciliation_run_id =
              v_old_run.lor_reconciliation_run_id
          AND gr.effective_action_type IS NOT NULL
          AND gr.effective_action_type IN (
              'DEFER',
              'CORRECT_SOURCE_REQUIRED',
              'RESTORE_TO_LOR_REQUIRED'
          )
          AND NOT EXISTS (
              SELECT 1
              FROM ops.lor_reconciliation_result AS rr
              WHERE rr.lor_reconciliation_run_id =
                    gr.lor_reconciliation_run_id
                AND rr.entity_type = gr.entity_type
                AND rr.entity_key = gr.logical_group_key
                AND rr.reason_code IN (
                    'SUPERSEDED_OPERATOR_DEFERRED',
                    'SUPERSEDED_OPERATOR_CHANGE_NOT_ACCEPTED'
                )
          );

        SELECT
            count(*) FILTER (
                WHERE gr.effective_resolution_state = 'UNRESOLVED'
            ),
            count(*) FILTER (
                WHERE gr.effective_resolution_state = 'DEFERRED'
            ),
            count(*) FILTER (
                WHERE gr.effective_resolution_state = 'BLOCKED'
            )
          INTO v_old_unresolved, v_old_deferred, v_old_blocked
        FROM ops.v_lor_reconciliation_group_review AS gr
        WHERE gr.lor_reconciliation_run_id =
              v_old_run.lor_reconciliation_run_id;

        INSERT INTO ops.lor_reconciliation_result (
            lor_reconciliation_run_id, import_run_id, entity_type, entity_key,
            result_class, reason_code, operator_message, committed
        ) VALUES (
            v_old_run.lor_reconciliation_run_id,
            v_old_run.import_run_id,
            'RUN',
            v_old_run.lor_reconciliation_run_id::text,
            'SUPERSEDED',
            'SUPERSEDED_BY_LATER_ATTEMPT',
            format(
                'Attempt superseded by reconciliation run %s. Undecided groups: %s. Frozen-source error: %s',
                v_run_id,
                coalesce(v_old_unresolved, 0),
                coalesce(v_freeze_error, 'none')
            ),
            false
        );

        UPDATE ops.lor_reconciliation_run
           SET status = 'SUPERSEDED',
               superseded_at = now(),
               superseded_by_run_id = v_run_id,
               supersession_reason =
                   'A later reconciliation attempt was started.',
               unresolved_count = coalesce(v_old_unresolved, 0),
               deferred_count = coalesce(v_old_deferred, 0),
               blocked_count = coalesce(v_old_blocked, 0),
               failure_message = CASE
                   WHEN v_freeze_error IS NULL THEN failure_message
                   ELSE concat_ws(
                       E'\n', failure_message,
                       'Source evidence freeze failed during supersession: '
                       || v_freeze_error
                   )
               END
         WHERE lor_reconciliation_run_id =
               v_old_run.lor_reconciliation_run_id;
    END LOOP;

    BEGIN

    /*
      The temporary working rows exist only inside this atomic builder. The
      durable candidate and group tables are the sole downstream authority.
    */
    CREATE TEMP TABLE pg_temp._lor_display_candidate_build ON COMMIT DROP AS
    WITH RECURSIVE reconciliation AS (
        SELECT v.*
        FROM ops.v_lor_display_reconciliation AS v
        WHERE v.import_run_id = v_import_run_id
    ),
    projected AS (
        SELECT
            r.import_run_id,
            r.source_prop_id,
            d.stage_id AS current_stage_id,
            st.stage_id AS proposed_stage_id,
            d.string_type AS current_string_type,
            raw.string_type AS proposed_string_type,
            ARRAY_REMOVE(ARRAY[
                CASE WHEN r.display_id IS NULL THEN 'new_display' END,
                CASE WHEN d.display_name IS DISTINCT FROM r.lor_display_name
                    THEN 'display_name' END,
                CASE WHEN d.lor_prop_id IS DISTINCT FROM r.lor_prop_id
                    THEN 'lor_prop_id' END,
                CASE WHEN d.stage_id IS DISTINCT FROM st.stage_id
                    THEN 'stage_id' END,
                CASE WHEN d.string_type IS DISTINCT FROM raw.string_type
                    THEN 'string_type' END
            ]::text[], NULL) AS changed_fields
        FROM reconciliation AS r
        JOIN lor_snap.props AS raw
          ON raw.import_run_id = r.import_run_id
         AND raw.prop_id = r.source_prop_id
         AND raw.raw_prop_id = r.lor_prop_id
        LEFT JOIN ref.display AS d ON d.display_id = r.display_id
        LEFT JOIN ref.stage AS st
          ON st.stage_key = lower(btrim(r.preview_stage_id))
        WHERE nullif(btrim(raw.lor_comment), '') IS NOT NULL
    ),
    identity_edges AS (
        SELECT DISTINCT
            least(r.uuid_display_id, r.name_display_id) AS display_id_a,
            greatest(r.uuid_display_id, r.name_display_id) AS display_id_b
        FROM reconciliation AS r
        WHERE r.uuid_display_id IS NOT NULL
          AND r.name_display_id IS NOT NULL
          AND r.uuid_display_id <> r.name_display_id
    ),
    identity_nodes AS (
        SELECT display_id_a AS display_id FROM identity_edges
        UNION
        SELECT display_id_b AS display_id FROM identity_edges
    ),
    identity_reach AS (
        SELECT n.display_id AS root_display_id, n.display_id
        FROM identity_nodes AS n
        UNION
        SELECT
            ir.root_display_id,
            CASE WHEN ie.display_id_a = ir.display_id
                THEN ie.display_id_b ELSE ie.display_id_a END
        FROM identity_reach AS ir
        JOIN identity_edges AS ie
          ON ie.display_id_a = ir.display_id
          OR ie.display_id_b = ir.display_id
    ),
    identity_components AS (
        SELECT display_id, min(root_display_id) AS component_id
        FROM identity_reach
        GROUP BY display_id
    ),
    classified AS (
        SELECT
            r.*,
            p.current_stage_id,
            p.proposed_stage_id,
            p.current_string_type,
            p.proposed_string_type,
            coalesce(p.changed_fields, ARRAY[]::text[]) AS changed_fields,
            ic.component_id,
            CASE
                WHEN ic.component_id IS NOT NULL
                    THEN format('DISPLAY_IDENTITY:%s', ic.component_id)
                WHEN r.display_id IS NOT NULL
                    THEN format('DISPLAY:%s', r.display_id)
                ELSE format('LOR_PROP:%s', r.lor_prop_id)
            END AS logical_group_key
        FROM reconciliation AS r
        LEFT JOIN projected AS p
          ON p.import_run_id = r.import_run_id
         AND p.source_prop_id = r.source_prop_id
        LEFT JOIN identity_components AS ic ON ic.display_id = r.display_id
    ),
    grouped AS (
        SELECT
            c.*,
            count(*) OVER (PARTITION BY c.logical_group_key)::integer
                AS group_member_count,
            bool_or(c.classification_code = 'NAME_AND_UUID_CHANGED') OVER (
                PARTITION BY c.logical_group_key
            ) AS atomic_identity_group
        FROM classified AS c
    )
    SELECT
        g.*,
        CASE
            WHEN g.source_prop_id IS NOT NULL
                THEN format('PROP:%s', g.source_prop_id)
            ELSE format('MISSING_DISPLAY:%s', g.display_id)
        END AS candidate_key,
        CASE WHEN g.classification_code = 'EXCLUDED_NONPHYSICAL'
            THEN 'EXCLUDED_NONPHYSICAL' ELSE 'PHYSICAL_DISPLAY' END
            AS candidate_class,
        CASE
            WHEN g.classification_code = 'EXCLUDED_NONPHYSICAL' THEN 'EXCLUDED'
            WHEN g.atomic_identity_group THEN 'DECISION_REQUIRED'
            WHEN g.classification_code = 'EXACT_MATCH' THEN 'AUTO_APPROVED'
            WHEN g.classification_code IN (
                'NAME_CHANGED_SAME_UUID', 'UUID_CHANGED_SAME_NAME',
                'NEW_DISPLAY_CANDIDATE', 'ACTIVE_DISPLAY_MISSING_FROM_LOR',
                'NONACTIVE_DISPLAY_PRESENT_IN_LOR'
            ) THEN 'DECISION_REQUIRED'
            ELSE 'BLOCKED'
        END AS initial_resolution_state,
        CASE
            WHEN g.atomic_identity_group THEN true
            WHEN g.classification_code IN (
                'EXACT_MATCH', 'EXCLUDED_NONPHYSICAL'
            ) THEN false
            WHEN g.classification_code IN (
                'NAME_CHANGED_SAME_UUID', 'UUID_CHANGED_SAME_NAME',
                'NEW_DISPLAY_CANDIDATE', 'ACTIVE_DISPLAY_MISSING_FROM_LOR',
                'NONACTIVE_DISPLAY_PRESENT_IN_LOR'
            ) THEN true
            ELSE true
        END AS persistent_decision_required,
        CASE
            WHEN g.atomic_identity_group THEN ARRAY[
                'REASSOCIATE_DISPLAY', 'CORRECT_SOURCE_REQUIRED', 'DEFER'
            ]::text[]
            WHEN g.classification_code = 'EXACT_MATCH'
             AND cardinality(g.changed_fields) > 0
                THEN ARRAY['DEFER']::text[]
            WHEN g.classification_code = 'NAME_CHANGED_SAME_UUID'
                THEN ARRAY['RENAME_DISPLAY', 'CORRECT_SOURCE_REQUIRED', 'DEFER']::text[]
            WHEN g.classification_code = 'UUID_CHANGED_SAME_NAME'
                THEN ARRAY['UPDATE_LOR_LINK', 'CORRECT_SOURCE_REQUIRED', 'DEFER']::text[]
            WHEN g.classification_code = 'NEW_DISPLAY_CANDIDATE'
                THEN ARRAY['ADD_NEW_DISPLAY', 'CORRECT_SOURCE_REQUIRED', 'DEFER']::text[]
            WHEN g.classification_code = 'ACTIVE_DISPLAY_MISSING_FROM_LOR'
                THEN ARRAY[
                    'SET_RETIRED', 'SET_RECYCLED',
                    'RESTORE_TO_LOR_REQUIRED', 'DEFER'
                ]::text[]
            WHEN g.classification_code = 'NONACTIVE_DISPLAY_PRESENT_IN_LOR'
                THEN ARRAY['CORRECT_SOURCE_REQUIRED', 'DEFER']::text[]
            WHEN g.classification_code = 'EXCLUDED_NONPHYSICAL'
                THEN ARRAY[]::text[]
            ELSE ARRAY['CORRECT_SOURCE_REQUIRED', 'DEFER']::text[]
        END AS persistent_allowed_actions
    FROM grouped AS g;

    INSERT INTO ops.lor_reconciliation_group (
        lor_reconciliation_run_id,
        import_run_id,
        entity_type,
        logical_group_key,
        group_kind,
        member_count,
        requires_atomic_decision,
        decision_required,
        allowed_action_types,
        operator_message
    )
    SELECT
        v_run_id,
        v_import_run_id,
        'DISPLAY',
        b.logical_group_key,
        CASE WHEN bool_or(b.atomic_identity_group)
            THEN 'IDENTITY_COMPONENT' ELSE 'SINGLE_CANDIDATE' END,
        count(*)::integer,
        bool_or(b.atomic_identity_group),
        bool_or(b.persistent_decision_required),
        CASE
            WHEN bool_or(b.atomic_identity_group) THEN
                ARRAY['REASSOCIATE_DISPLAY', 'CORRECT_SOURCE_REQUIRED', 'DEFER']::text[]
            ELSE (
                SELECT b_one.persistent_allowed_actions
                FROM pg_temp._lor_display_candidate_build AS b_one
                WHERE b_one.logical_group_key = b.logical_group_key
                ORDER BY b_one.candidate_key
                LIMIT 1
            )
        END,
        CASE
            WHEN bool_or(b.atomic_identity_group) THEN format(
                'Resolve or defer all %s members of this identity dependency group atomically.',
                count(*)
            )
            ELSE max(b.operator_message)
        END
    FROM pg_temp._lor_display_candidate_build AS b
    GROUP BY b.logical_group_key;

    INSERT INTO ops.lor_reconciliation_display_candidate (
        lor_reconciliation_run_id,
        lor_reconciliation_group_id,
        import_run_id,
        candidate_key,
        source_prop_id,
        lor_prop_id,
        display_id,
        uuid_display_id,
        name_display_id,
        classification_code,
        candidate_class,
        initial_resolution_state,
        decision_required,
        is_blocking,
        allowed_action_types,
        changed_fields,
        current_display_name,
        proposed_display_name,
        current_stage_id,
        proposed_stage_id,
        current_string_type,
        proposed_string_type,
        current_display_status_id,
        preview_id,
        preview_name,
        proposed_stage_key,
        location_summary,
        operator_message,
        source_evidence
    )
    SELECT
        v_run_id,
        rg.lor_reconciliation_group_id,
        v_import_run_id,
        b.candidate_key,
        b.source_prop_id,
        b.lor_prop_id,
        b.display_id,
        b.uuid_display_id,
        b.name_display_id,
        b.classification_code,
        b.candidate_class,
        b.initial_resolution_state,
        b.persistent_decision_required,
        b.initial_resolution_state IN ('DECISION_REQUIRED', 'BLOCKED'),
        b.persistent_allowed_actions,
        b.changed_fields,
        b.production_display_name,
        b.lor_display_name,
        b.current_stage_id,
        b.proposed_stage_id,
        b.current_string_type,
        b.proposed_string_type,
        b.display_status_id,
        b.preview_id,
        b.preview_name,
        b.preview_stage_id,
        b.location_summary,
        CASE WHEN b.atomic_identity_group THEN format(
            'This candidate is one of %s members in %s. Record one complete group decision.',
            b.group_member_count,
            b.logical_group_key
        ) ELSE b.operator_message END,
        jsonb_build_object(
            'lor_uuid_row_count', b.lor_uuid_row_count,
            'lor_uuid_name_count', b.lor_uuid_name_count,
            'lor_name_uuid_count', b.lor_name_uuid_count,
            'production_uuid_count', b.production_uuid_count,
            'production_name_count', b.production_name_count,
            'occurrence_count', b.occurrence_count
        )
    FROM pg_temp._lor_display_candidate_build AS b
    JOIN ops.lor_reconciliation_group AS rg
      ON rg.lor_reconciliation_run_id = v_run_id
     AND rg.entity_type = 'DISPLAY'
     AND rg.logical_group_key = b.logical_group_key;

    SELECT
        count(*) FILTER (WHERE g.decision_required),
        count(*) FILTER (
            WHERE EXISTS (
                SELECT 1
                FROM ops.lor_reconciliation_display_candidate AS c
                WHERE c.lor_reconciliation_group_id = g.lor_reconciliation_group_id
                  AND c.initial_resolution_state = 'BLOCKED'
            )
        )
      INTO v_decision_count, v_blocked_count
    FROM ops.lor_reconciliation_group AS g
    WHERE g.lor_reconciliation_run_id = v_run_id;

    UPDATE ops.lor_reconciliation_run
       SET status = CASE WHEN v_decision_count > 0 OR v_blocked_count > 0
                         THEN 'AWAITING_DECISIONS'
                         ELSE 'READY_TO_FINISH' END,
           paused_at = CASE WHEN v_decision_count > 0 OR v_blocked_count > 0
                            THEN now() ELSE NULL END,
           blocked_count = v_blocked_count,
           unresolved_count = v_decision_count
     WHERE lor_reconciliation_run_id = v_run_id;

        RETURN v_run_id;
    EXCEPTION
        WHEN OTHERS THEN
            UPDATE ops.lor_reconciliation_run
               SET status = 'FAILED',
                   failed_at = now(),
                   failure_message = SQLERRM,
                   structural_failure_count = structural_failure_count + 1
             WHERE lor_reconciliation_run_id = v_run_id;
            RETURN v_run_id;
    END;
END;
$$;


ALTER FUNCTION ops.f_start_lor_display_reconciliation(p_started_by_application text) OWNER TO msbadmin;

--
-- TOC entry 6142 (class 0 OID 0)
-- Dependencies: 820
-- Name: FUNCTION f_start_lor_display_reconciliation(p_started_by_application text); Type: COMMENT; Schema: ops; Owner: msbadmin
--

COMMENT ON FUNCTION ops.f_start_lor_display_reconciliation(p_started_by_application text) IS 'Creates a new independent evaluation of the current completed ingest and supersedes, preserves, and reports any interrupted review-stage attempts.';


--
-- TOC entry 525 (class 1255 OID 23658)
-- Name: f_start_lor_reconciliation(text); Type: FUNCTION; Schema: ops; Owner: msbadmin
--

CREATE FUNCTION ops.f_start_lor_reconciliation(p_started_by_application text DEFAULT NULL::text) RETURNS bigint
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'pg_catalog', 'ops', 'lor_snap', 'ref'
    AS $$
DECLARE
    v_run_id bigint;
    v_import_run_id bigint;
    v_existing_status text;
BEGIN
    PERFORM pg_advisory_xact_lock(hashtext('ops.lor_reconciliation.start'));

    SELECT r.lor_reconciliation_run_id
      INTO v_run_id
    FROM ops.lor_reconciliation_run AS r
    WHERE r.status IN (
        'STARTING', 'PREFLIGHT', 'AWAITING_DECISIONS', 'READY_TO_FINISH',
        'PROMOTING', 'VALIDATING', 'REPORTING'
    )
    ORDER BY r.lor_reconciliation_run_id
    LIMIT 1
    FOR UPDATE;

    IF v_run_id IS NOT NULL THEN
        UPDATE ops.lor_reconciliation_run
           SET resumed_at = now()
         WHERE lor_reconciliation_run_id = v_run_id;
        RETURN v_run_id;
    END IF;

    SELECT cr.import_run_id
      INTO v_import_run_id
    FROM lor_snap.v_current_run AS cr;

    IF v_import_run_id IS NULL THEN
        RAISE EXCEPTION 'No completed LOR snapshot is available';
    END IF;

    SELECT r.lor_reconciliation_run_id, r.status
      INTO v_run_id, v_existing_status
    FROM ops.lor_reconciliation_run AS r
    WHERE r.import_run_id = v_import_run_id
    FOR UPDATE;

    IF v_run_id IS NOT NULL THEN
        RAISE EXCEPTION
            'Snapshot % already belongs to reconciliation run % with status %; a second run is prohibited',
            v_import_run_id, v_run_id, v_existing_status;
    END IF;

    v_run_id := ops.f_start_lor_display_reconciliation(
        p_started_by_application
    );
    PERFORM ops.f_freeze_lor_reconciliation_source_evidence(v_run_id);
    PERFORM ops.f_build_lor_reconciliation_stage_candidates(v_run_id);
    PERFORM ops.f_build_lor_reconciliation_scene_candidates(v_run_id);
    PERFORM ops.f_build_lor_reconciliation_scene_display_candidates(v_run_id);
    RETURN v_run_id;
END;
$$;


ALTER FUNCTION ops.f_start_lor_reconciliation(p_started_by_application text) OWNER TO msbadmin;

--
-- TOC entry 6144 (class 0 OID 0)
-- Dependencies: 525
-- Name: FUNCTION f_start_lor_reconciliation(p_started_by_application text); Type: COMMENT; Schema: ops; Owner: msbadmin
--

COMMENT ON FUNCTION ops.f_start_lor_reconciliation(p_started_by_application text) IS 'Returns the one existing unfinished run in any unfinished lifecycle state; otherwise creates exactly one run for the current completed snapshot and freezes/builds its evidence.';


--
-- TOC entry 746 (class 1255 OID 24053)
-- Name: f_sync_lor_reconciliation_counters_on_reporting(); Type: FUNCTION; Schema: ops; Owner: msbadmin
--

CREATE FUNCTION ops.f_sync_lor_reconciliation_counters_on_reporting() RETURNS trigger
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'pg_catalog', 'ops'
    AS $$
BEGIN
    PERFORM *
    FROM ops.f_sync_lor_reconciliation_effective_counters(
        NEW.lor_reconciliation_run_id
    );
    RETURN NEW;
END;
$$;


ALTER FUNCTION ops.f_sync_lor_reconciliation_counters_on_reporting() OWNER TO msbadmin;

--
-- TOC entry 534 (class 1255 OID 24052)
-- Name: f_sync_lor_reconciliation_effective_counters(bigint); Type: FUNCTION; Schema: ops; Owner: msbadmin
--

CREATE FUNCTION ops.f_sync_lor_reconciliation_effective_counters(p_lor_reconciliation_run_id bigint) RETURNS TABLE(unresolved_count integer, deferred_count integer, blocked_count integer)
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'pg_catalog', 'ops'
    AS $$
BEGIN
    IF NOT EXISTS (
        SELECT 1
        FROM ops.lor_reconciliation_run AS r
        WHERE r.lor_reconciliation_run_id = p_lor_reconciliation_run_id
    ) THEN
        RAISE EXCEPTION 'Reconciliation run % does not exist',
            p_lor_reconciliation_run_id;
    END IF;

    RETURN QUERY
    WITH effective_counts AS (
        SELECT
            count(*) FILTER (
                WHERE gr.effective_resolution_state = 'UNRESOLVED'
            )::integer AS unresolved_count,
            count(*) FILTER (
                WHERE gr.effective_resolution_state = 'DEFERRED'
            )::integer AS deferred_count,
            count(*) FILTER (
                WHERE gr.effective_resolution_state = 'BLOCKED'
            )::integer AS blocked_count
        FROM ops.v_lor_reconciliation_group_review AS gr
        WHERE gr.lor_reconciliation_run_id = p_lor_reconciliation_run_id
    ), updated AS (
        UPDATE ops.lor_reconciliation_run AS r
           SET unresolved_count = ec.unresolved_count,
               deferred_count = ec.deferred_count,
               blocked_count = ec.blocked_count
          FROM effective_counts AS ec
         WHERE r.lor_reconciliation_run_id = p_lor_reconciliation_run_id
        RETURNING r.unresolved_count, r.deferred_count, r.blocked_count
    )
    SELECT u.unresolved_count, u.deferred_count, u.blocked_count
    FROM updated AS u;
END;
$$;


ALTER FUNCTION ops.f_sync_lor_reconciliation_effective_counters(p_lor_reconciliation_run_id bigint) OWNER TO msbadmin;

--
-- TOC entry 6147 (class 0 OID 0)
-- Dependencies: 534
-- Name: FUNCTION f_sync_lor_reconciliation_effective_counters(p_lor_reconciliation_run_id bigint); Type: COMMENT; Schema: ops; Owner: msbadmin
--

COMMENT ON FUNCTION ops.f_sync_lor_reconciliation_effective_counters(p_lor_reconciliation_run_id bigint) IS 'Synchronizes one reconciliation run exception counters exclusively from effective logical-group resolution states.';


--
-- TOC entry 1130 (class 1255 OID 23852)
-- Name: p_cancel_lor_reconciliation(bigint, text, text); Type: PROCEDURE; Schema: ops; Owner: msbadmin
--

CREATE PROCEDURE ops.p_cancel_lor_reconciliation(IN p_lor_reconciliation_run_id bigint, IN p_cancellation_reason text, IN p_cancelled_by_application text DEFAULT NULL::text)
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'pg_catalog', 'ops', 'lor_snap', 'ref'
    AS $$
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
$$;


ALTER PROCEDURE ops.p_cancel_lor_reconciliation(IN p_lor_reconciliation_run_id bigint, IN p_cancellation_reason text, IN p_cancelled_by_application text) OWNER TO msbadmin;

--
-- TOC entry 6149 (class 0 OID 0)
-- Dependencies: 1130
-- Name: PROCEDURE p_cancel_lor_reconciliation(IN p_lor_reconciliation_run_id bigint, IN p_cancellation_reason text, IN p_cancelled_by_application text); Type: COMMENT; Schema: ops; Owner: msbadmin
--

COMMENT ON PROCEDURE ops.p_cancel_lor_reconciliation(IN p_lor_reconciliation_run_id bigint, IN p_cancellation_reason text, IN p_cancelled_by_application text) IS 'Only Cancel entry point. Before promotion, atomically records cancellation and deletes the run captured snapshot; report publication performs the terminal CANCELLED transition.';


--
-- TOC entry 1138 (class 1255 OID 24278)
-- Name: p_cleanup_recycled_standalone_display(bigint); Type: FUNCTION; Schema: ops; Owner: msbadmin
--

CREATE FUNCTION ops.p_cleanup_recycled_standalone_display(p_display_id bigint) RETURNS void
    LANGUAGE plpgsql
    AS $$
DECLARE
    v_container_id integer;
    v_container_type_name text;
    v_display_status_name text;
    v_display_name text;
    v_other_display_count integer;
BEGIN
    /*
     * Resolve the display, its lifecycle state, and its current container.
     */
    SELECT
        d.container_id,
        ct.container_type_name,
        ds.display_status_name,
        d.display_name
    INTO
        v_container_id,
        v_container_type_name,
        v_display_status_name,
        v_display_name
    FROM ref.display d
    JOIN ref.display_status ds
      ON ds.display_status_id = d.display_status_id
    LEFT JOIN ref.container c
      ON c.container_id = d.container_id
    LEFT JOIN ref.container_type ct
      ON ct.container_type_id = c.container_type_id
    WHERE d.display_id = p_display_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION
            'Display % does not exist',
            p_display_id;
    END IF;

    /*
     * This cleanup is valid only after the display lifecycle has actually
     * been changed to RECYCLED.
     */
    IF v_display_status_name <> 'RECYCLED' THEN
        RAISE EXCEPTION
            'Display % (%) is %, not RECYCLED',
            p_display_id,
            v_display_name,
            v_display_status_name;
    END IF;

    /*
     * A recycled display without a current container needs no synthetic
     * container cleanup.
     */
    IF v_container_id IS NULL THEN
        RETURN;
    END IF;

    /*
     * Critical safety guard:
     * Never delete a real pallet, bin, box, trailer, crate, etc.
     */
    IF v_container_type_name IS DISTINCT FROM 'Standalone Display' THEN
        RAISE EXCEPTION
            'Display % (%) is assigned to container % of type %. '
            'Automatic container deletion is allowed only for Standalone Display containers.',
            p_display_id,
            v_display_name,
            v_container_id,
            COALESCE(v_container_type_name, '<NULL>');
    END IF;

    /*
     * A synthetic stand-alone container must not contain another display.
     * If it does, stop rather than deleting shared operational data.
     */
    SELECT COUNT(*)
      INTO v_other_display_count
    FROM ref.display d
    WHERE d.container_id = v_container_id
      AND d.display_id <> p_display_id
      AND d.display_status_id <> (
          SELECT display_status_id
          FROM ref.display_status
          WHERE display_status_name = 'RECYCLED'
      );

    IF v_other_display_count > 0 THEN
        RAISE EXCEPTION
            'Standalone container % for display % contains % other non-RECYCLED display(s); cleanup aborted',
            v_container_id,
            p_display_id,
            v_other_display_count;
    END IF;

    /*
     * Remove display-test rows belonging to the stand-alone display.
     *
     * A historical work order FK will intentionally prevent deletion.
     * Such a work order must first be resolved according to the normal
     * work-order workflow, for example "Damaged Beyond Repair".
     */
    DELETE FROM ops.display_test_session dts
    WHERE dts.display_id = p_display_id
      AND EXISTS (
          SELECT 1
          FROM ops.test_session ts
          WHERE ts.test_session_id = dts.test_session_id
            AND ts.container_id = v_container_id
      );

    /*
     * Remove test sessions for the synthetic stand-alone container.
     *
     * At this point the container represents no physical object and must
     * not remain in testing queues.
     */
    DELETE FROM ops.test_session
    WHERE container_id = v_container_id;

    /*
     * Break the current operational display -> container relationship.
     * The display record itself remains as permanent RECYCLED history.
     */
    UPDATE ref.display
       SET container_id = NULL
     WHERE display_id = p_display_id;

    /*
     * Delete the synthetic container.
     *
     * Existing RESTRICT/NO ACTION foreign keys remain the final protection
     * against destroying historical dependencies.
     */
    DELETE FROM ref.container
    WHERE container_id = v_container_id;

END;
$$;


ALTER FUNCTION ops.p_cleanup_recycled_standalone_display(p_display_id bigint) OWNER TO msbadmin;

--
-- TOC entry 1247 (class 1255 OID 23850)
-- Name: p_finish_lor_reconciliation(bigint, text); Type: PROCEDURE; Schema: ops; Owner: msbadmin
--

CREATE PROCEDURE ops.p_finish_lor_reconciliation(IN p_lor_reconciliation_run_id bigint, IN p_finished_by_application text DEFAULT NULL::text)
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'pg_catalog', 'ops', 'lor_snap', 'ref'
    AS $$
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
$$;


ALTER PROCEDURE ops.p_finish_lor_reconciliation(IN p_lor_reconciliation_run_id bigint, IN p_finished_by_application text) OWNER TO msbadmin;

--
-- TOC entry 6152 (class 0 OID 0)
-- Dependencies: 1247
-- Name: PROCEDURE p_finish_lor_reconciliation(IN p_lor_reconciliation_run_id bigint, IN p_finished_by_application text); Type: COMMENT; Schema: ops; Owner: msbadmin
--

COMMENT ON PROCEDURE ops.p_finish_lor_reconciliation(IN p_lor_reconciliation_run_id bigint, IN p_finished_by_application text) IS 'Only Finish entry point. Atomically runs P1/P3/P2/P4 against one captured reconciliation run, validates the projection, and advances it to REPORTING.';


--
-- TOC entry 549 (class 1255 OID 24043)
-- Name: p_publish_lor_reconciliation_report(bigint, text, text, text, text); Type: PROCEDURE; Schema: ops; Owner: msbadmin
--

CREATE PROCEDURE ops.p_publish_lor_reconciliation_report(IN p_lor_reconciliation_run_id bigint, IN p_report_path text, IN p_report_url text, IN p_report_sha256 text, IN p_published_by_application text DEFAULT NULL::text)
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'pg_catalog', 'ops'
    AS $_$
DECLARE
    v_run ops.lor_reconciliation_run%ROWTYPE;
    v_path text := nullif(btrim(p_report_path), '');
    v_url text := nullif(btrim(p_report_url), '');
    v_sha text := lower(nullif(btrim(p_report_sha256), ''));
    v_terminal_status text;
BEGIN
    PERFORM pg_advisory_xact_lock(
        hashtext('ops.lor_reconciliation.report'),
        (p_lor_reconciliation_run_id % 2147483647)::integer
    );

    SELECT * INTO v_run
    FROM ops.lor_reconciliation_run
    WHERE lor_reconciliation_run_id = p_lor_reconciliation_run_id
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Reconciliation run % does not exist',
            p_lor_reconciliation_run_id;
    END IF;

    IF v_path IS NULL OR v_url IS NULL THEN
        RAISE EXCEPTION 'Report path and URL are required';
    END IF;

    IF v_sha IS NULL OR v_sha !~ '^[0-9a-f]{64}$' THEN
        RAISE EXCEPTION 'A lowercase 64-character SHA-256 is required';
    END IF;

    IF v_run.status IN ('COMPLETED', 'COMPLETED_WITH_EXCEPTIONS', 'CANCELLED') THEN
        IF v_run.report_path = v_path
           AND v_run.report_url = v_url
           AND v_run.report_sha256 = v_sha THEN
            RETURN;
        END IF;
        RAISE EXCEPTION 'Reconciliation run % already published to %',
            p_lor_reconciliation_run_id, v_run.report_path;
    END IF;

    IF v_run.status <> 'REPORTING' THEN
        RAISE EXCEPTION 'Reconciliation run % is %, not REPORTING',
            p_lor_reconciliation_run_id, v_run.status;
    END IF;

    IF v_run.validation_state <> 'PASSED' THEN
        RAISE EXCEPTION 'Reconciliation run % validation is %, not PASSED',
            p_lor_reconciliation_run_id, v_run.validation_state;
    END IF;

    IF v_run.cancelled_at IS NOT NULL THEN
        v_terminal_status := 'CANCELLED';
    ELSIF v_run.blocked_count <> 0
       OR v_run.deferred_count <> 0
       OR v_run.unresolved_count <> 0 THEN
        v_terminal_status := 'COMPLETED_WITH_EXCEPTIONS';
    ELSE
        v_terminal_status := 'COMPLETED';
    END IF;

    INSERT INTO ops.lor_reconciliation_result (
        lor_reconciliation_run_id, import_run_id, entity_type, entity_key,
        result_class, reason_code, operator_message, committed
    ) VALUES (
        v_run.lor_reconciliation_run_id, v_run.import_run_id, 'RUN',
        v_run.lor_reconciliation_run_id::text, 'REPORT_PUBLISHED',
        'TIMESTAMPED_HTML_REPORT_PUBLISHED',
        format('HTML report published to %s (SHA-256 %s; application %s).',
               v_path, v_sha,
               coalesce(nullif(btrim(p_published_by_application), ''), 'unspecified')),
        true
    );

    UPDATE ops.lor_reconciliation_run
       SET status = v_terminal_status,
           completed_at = CASE
               WHEN v_terminal_status IN ('COMPLETED', 'COMPLETED_WITH_EXCEPTIONS')
                   THEN now()
               ELSE completed_at
           END,
           report_path = v_path,
           report_url = v_url,
           report_sha256 = v_sha,
           report_published_at = now()
     WHERE lor_reconciliation_run_id = p_lor_reconciliation_run_id;
END;
$_$;


ALTER PROCEDURE ops.p_publish_lor_reconciliation_report(IN p_lor_reconciliation_run_id bigint, IN p_report_path text, IN p_report_url text, IN p_report_sha256 text, IN p_published_by_application text) OWNER TO msbadmin;

--
-- TOC entry 6154 (class 0 OID 0)
-- Dependencies: 549
-- Name: PROCEDURE p_publish_lor_reconciliation_report(IN p_lor_reconciliation_run_id bigint, IN p_report_path text, IN p_report_url text, IN p_report_sha256 text, IN p_published_by_application text); Type: COMMENT; Schema: ops; Owner: msbadmin
--

COMMENT ON PROCEDURE ops.p_publish_lor_reconciliation_report(IN p_lor_reconciliation_run_id bigint, IN p_report_path text, IN p_report_url text, IN p_report_sha256 text, IN p_published_by_application text) IS 'Records a successfully written immutable HTML report and performs the REPORTING-to-terminal transition for one retained reconciliation run.';


--
-- TOC entry 823 (class 1255 OID 18866)
-- Name: p_pull_container(integer, text, text); Type: FUNCTION; Schema: ops; Owner: msbadmin
--

CREATE FUNCTION ops.p_pull_container(p_container_id integer, p_work_location_code text DEFAULT 'Z-FLOOR WORK AREA'::text, p_pulled_by text DEFAULT CURRENT_USER) RETURNS bigint
    LANGUAGE plpgsql
    AS $$
DECLARE
  v_test_session_id bigint;
BEGIN
  SELECT ts.test_session_id
    INTO v_test_session_id
  FROM ops.test_session ts
  WHERE ts.container_id = p_container_id
    AND ts.done_at IS NULL
  ORDER BY ts.pulled_at DESC
  LIMIT 1;

  IF v_test_session_id IS NULL THEN
    RAISE EXCEPTION 'No open test_session found for container_id=%', p_container_id;
  END IF;

  IF NOT EXISTS (
    SELECT 1
    FROM ref.display d
    WHERE d.container_id = p_container_id
  ) THEN
    RETURN v_test_session_id;
  END IF;

  UPDATE ops.test_session
     SET container_test_status_id = 2,
         work_location_code = COALESCE(work_location_code, p_work_location_code),
         pulled_by = COALESCE(pulled_by, p_pulled_by),
         pulled_at = COALESCE(pulled_at, NOW())
   WHERE test_session_id = v_test_session_id;

  INSERT INTO ops.display_test_session
  (
    test_session_id,
    lor_prop_id,
    display_id,
    stage_id,
    is_spare,
    is_display_present,
    checked_at,
    checked_by,
    notes,
    checked_date_text,
    test_status,
    amps_measured,
    light_count,
    display_state
  )
  SELECT
    v_test_session_id,
    d.lor_prop_id,
    d.display_id,
    d.stage_id,
    false,
    NULL,
    NULL,
    NULL,
    NULL,
    NULL,
    NULL,
    NULL,
    NULL,
    NULL
  FROM ref.display d
  WHERE d.container_id = p_container_id
  ON CONFLICT (test_session_id, display_id) DO NOTHING;

  RETURN v_test_session_id;
END;
$$;


ALTER FUNCTION ops.p_pull_container(p_container_id integer, p_work_location_code text, p_pulled_by text) OWNER TO msbadmin;

--
-- TOC entry 1092 (class 1255 OID 19496)
-- Name: p_pull_container(integer, text, text, integer); Type: FUNCTION; Schema: ops; Owner: msbadmin
--

CREATE FUNCTION ops.p_pull_container(p_container_id integer, p_work_location_code text DEFAULT 'Z-FLOOR WORK AREA'::text, p_pulled_by text DEFAULT CURRENT_USER, p_pulled_by_person_id integer DEFAULT NULL::integer) RETURNS bigint
    LANGUAGE plpgsql
    AS $$
DECLARE
    v_test_session_id bigint;
BEGIN
    SELECT ts.test_session_id
      INTO v_test_session_id
    FROM ops.test_session ts
    JOIN ref.season s
      ON s.season_year = ts.season_year
    WHERE ts.container_id = p_container_id
      AND ts.done_at IS NULL
      AND s.active_flag = true
    ORDER BY ts.pulled_at DESC NULLS LAST, ts.test_session_id DESC
    LIMIT 1;

    IF v_test_session_id IS NULL THEN
        RAISE EXCEPTION 'No open active-season test_session found for container_id=%', p_container_id;
    END IF;

    IF NOT EXISTS (
        SELECT 1
        FROM ref.display d
        WHERE d.container_id = p_container_id
    ) THEN
        UPDATE ops.test_session
           SET container_test_status_id = 2,
               work_location_code = COALESCE(work_location_code, p_work_location_code),
               pulled_by = p_pulled_by,
               pulled_by_person_id = p_pulled_by_person_id,
               pulled_at = NOW()
         WHERE test_session_id = v_test_session_id;

        RETURN v_test_session_id;
    END IF;

    UPDATE ops.test_session
       SET container_test_status_id = 2,
           work_location_code = COALESCE(work_location_code, p_work_location_code),
           pulled_by = p_pulled_by,
           pulled_by_person_id = p_pulled_by_person_id,
           pulled_at = NOW()
     WHERE test_session_id = v_test_session_id;

    INSERT INTO ops.display_test_session
    (
        test_session_id,
        lor_prop_id,
        display_id,
        stage_id,
        is_spare,
        is_display_present,
        checked_at,
        checked_by,
        notes,
        checked_date_text,
        test_status,
        amps_measured,
        light_count,
        display_state,
        created_at,
        created_by,
        created_by_person_id,
        updated_at,
        updated_by,
        updated_by_person_id
    )
    SELECT
        v_test_session_id,
        d.lor_prop_id,
        d.display_id,
        d.stage_id,
        false,
        NULL,
        NULL,
        NULL,
        NULL,
        NULL,
        NULL,
        NULL,
        NULL,
        NULL,
        NOW(),
        p_pulled_by,
        p_pulled_by_person_id,
        NOW(),
        p_pulled_by,
        p_pulled_by_person_id
    FROM ref.display d
    WHERE d.container_id = p_container_id
    ON CONFLICT (test_session_id, display_id) DO NOTHING;

    RETURN v_test_session_id;
END;
$$;


ALTER FUNCTION ops.p_pull_container(p_container_id integer, p_work_location_code text, p_pulled_by text, p_pulled_by_person_id integer) OWNER TO msbadmin;

--
-- TOC entry 571 (class 1255 OID 19544)
-- Name: p_pull_container(integer, text, text, bigint); Type: FUNCTION; Schema: ops; Owner: msbadmin
--

CREATE FUNCTION ops.p_pull_container(p_container_id integer, p_work_location_code text DEFAULT 'Z-FLOOR WORK AREA'::text, p_pulled_by text DEFAULT CURRENT_USER, p_pulled_by_person_id bigint DEFAULT NULL::bigint) RETURNS bigint
    LANGUAGE plpgsql
    AS $$
DECLARE
    v_test_session_id bigint;
BEGIN
    SELECT ts.test_session_id
      INTO v_test_session_id
    FROM ops.test_session ts
    JOIN ref.season s
      ON s.season_year = ts.season_year
    WHERE ts.container_id = p_container_id
      AND ts.done_at IS NULL
      AND s.active_flag = true
    ORDER BY ts.pulled_at DESC NULLS LAST, ts.test_session_id DESC
    LIMIT 1;

    IF v_test_session_id IS NULL THEN
        RAISE EXCEPTION 'No open active-season test_session found for container_id=%', p_container_id;
    END IF;

    IF NOT EXISTS (
        SELECT 1
        FROM ref.display d
        WHERE d.container_id = p_container_id
    ) THEN
        UPDATE ops.test_session
           SET container_test_status_id = 2,
               work_location_code = COALESCE(work_location_code, p_work_location_code),
               pulled_by = p_pulled_by,
               pulled_by_person_id = p_pulled_by_person_id,
               pulled_at = NOW()
         WHERE test_session_id = v_test_session_id;

        RETURN v_test_session_id;
    END IF;

    UPDATE ops.test_session
       SET container_test_status_id = 2,
           work_location_code = COALESCE(work_location_code, p_work_location_code),
           pulled_by = p_pulled_by,
           pulled_by_person_id = p_pulled_by_person_id,
           pulled_at = NOW()
     WHERE test_session_id = v_test_session_id;

    INSERT INTO ops.display_test_session
    (
        test_session_id,
        lor_prop_id,
        display_id,
        stage_id,
        is_spare,
        is_display_present,
        checked_at,
        checked_by,
        notes,
        checked_date_text,
        test_status,
        amps_measured,
        light_count,
        display_state,
        created_at,
        created_by,
        created_by_person_id,
        updated_at,
        updated_by,
        updated_by_person_id
    )
    SELECT
        v_test_session_id,
        d.lor_prop_id,
        d.display_id,
        d.stage_id,
        false,
        NULL,
        NULL,
        NULL,
        NULL,
        NULL,
        NULL,
        NULL,
        NULL,
        NULL,
        NOW(),
        p_pulled_by,
        p_pulled_by_person_id,
        NOW(),
        p_pulled_by,
        p_pulled_by_person_id
    FROM ref.display d
    WHERE d.container_id = p_container_id
    ON CONFLICT (test_session_id, display_id) DO NOTHING;

    RETURN v_test_session_id;
END;
$$;


ALTER FUNCTION ops.p_pull_container(p_container_id integer, p_work_location_code text, p_pulled_by text, p_pulled_by_person_id bigint) OWNER TO msbadmin;

--
-- TOC entry 987 (class 1255 OID 19554)
-- Name: p_refresh_test_session(bigint, text, integer); Type: FUNCTION; Schema: ops; Owner: msbadmin
--

CREATE FUNCTION ops.p_refresh_test_session(p_test_session_id bigint, p_refreshed_by text, p_refreshed_by_person_id integer) RETURNS void
    LANGUAGE plpgsql
    AS $$
DECLARE
    v_container_id integer;
    v_add_count integer := 0;
    v_delete_count integer := 0;

    v_recycled_standalone_display_id bigint;
BEGIN
    /*
     * Resolve the container for an active-season test session.
     */
    SELECT ts.container_id
      INTO v_container_id
    FROM ops.test_session ts
    JOIN ref.season s
      ON s.season_year = ts.season_year
    WHERE ts.test_session_id = p_test_session_id
      AND s.active_flag = true;

    IF v_container_id IS NULL THEN
        RAISE EXCEPTION
            'No active-season test_session found for test_session_id=%',
            p_test_session_id;
    END IF;

    /*
     * Add missing display-test rows.
     *
     * RECYCLED displays no longer physically exist and therefore must never
     * be created or recreated as active testing relationships.
     */
    INSERT INTO ops.display_test_session
    (
        test_session_id,
        lor_prop_id,
        display_id,
        stage_id,
        is_spare,
        is_display_present,
        checked_at,
        checked_by,
        notes,
        checked_date_text,
        test_status,
        amps_measured,
        light_count,
        display_state,
        created_at,
        created_by,
        created_by_person_id,
        updated_at,
        updated_by,
        updated_by_person_id
    )
    SELECT
        p_test_session_id,
        d.lor_prop_id,
        d.display_id,
        d.stage_id,
        false,
        NULL,
        NULL,
        NULL,
        NULL,
        NULL,
        NULL,
        NULL,
        NULL,
        NULL,
        NOW(),
        p_refreshed_by,
        p_refreshed_by_person_id,
        NOW(),
        p_refreshed_by,
        p_refreshed_by_person_id
    FROM ref.display d
    JOIN ref.display_status ds
      ON ds.display_status_id = d.display_status_id
    WHERE d.container_id = v_container_id
      AND ds.display_status_name <> 'RECYCLED'
    ON CONFLICT (test_session_id, display_id) DO NOTHING;

    GET DIAGNOSTICS v_add_count = ROW_COUNT;

    /*
     * Remove rows that are no longer valid active testing relationships.
     *
     * Existing cleanup:
     *   Display no longer belongs to this container,
     *   is not marked present,
     *   is marked WRONG_CONTAINER,
     *   and has no work-order dependency.
     *
     * RECYCLED cleanup:
     *   The display no longer physically exists.
     *   Remove its test-session row when no work-order dependency requires
     *   that historical row to remain.
     */
    DELETE FROM ops.display_test_session dts
    WHERE dts.test_session_id = p_test_session_id
      AND
      (
          (
              NOT EXISTS
              (
                  SELECT 1
                  FROM ref.display d
                  WHERE d.display_id = dts.display_id
                    AND d.container_id = v_container_id
              )
              AND dts.is_display_present IS DISTINCT FROM TRUE
              AND dts.test_status = 'WRONG_CONTAINER'
          )
          OR
          EXISTS
          (
              SELECT 1
              FROM ref.display d
              JOIN ref.display_status ds
                ON ds.display_status_id = d.display_status_id
              WHERE d.display_id = dts.display_id
                AND ds.display_status_name = 'RECYCLED'
          )
      )
      AND NOT EXISTS
      (
          SELECT 1
          FROM ops.work_order wo
          WHERE wo.display_test_session_id = dts.display_test_session_id
      );

    GET DIAGNOSTICS v_delete_count = ROW_COUNT;

    /*
     * Complete the normal refresh bookkeeping before any synthetic
     * Standalone Display container is removed.
     *
     * Updating refresh_requested back to FALSE causes the UPDATE trigger
     * to fire again, but tf_after_refresh_test_session() already protects
     * against recursive execution with pg_trigger_depth().
     */
    UPDATE ops.test_session
       SET refresh_requested = FALSE,
           last_refreshed_at = NOW(),
           last_refreshed_by = p_refreshed_by,
           last_refreshed_by_person_id = p_refreshed_by_person_id,
           last_refresh_add_count = v_add_count,
           last_refresh_delete_count = v_delete_count
     WHERE test_session_id = p_test_session_id;

    /*
     * Recycled Standalone Display cleanup.
     *
     * A Standalone Display container is synthetic. It exists only because
     * the stand-alone display must participate in the container-based testing
     * workflow.
     *
     * If the display is RECYCLED, the physical object no longer exists and
     * the synthetic container must also be removed.
     *
     * Do not invoke the cleanup procedure when any display_test_session row
     * for this display/container is referenced by a work order. That historical
     * dependency is an outstanding lifecycle case and must not cause a normal
     * refresh request to fail.
     */
    SELECT d.display_id
      INTO v_recycled_standalone_display_id
    FROM ref.display d
    JOIN ref.display_status ds
      ON ds.display_status_id = d.display_status_id
    JOIN ref.container c
      ON c.container_id = d.container_id
    JOIN ref.container_type ct
      ON ct.container_type_id = c.container_type_id
    WHERE d.container_id = v_container_id
      AND ds.display_status_name = 'RECYCLED'
      AND ct.container_type_name = 'Standalone Display'
      AND NOT EXISTS
      (
          SELECT 1
          FROM ops.display_test_session dts
          JOIN ops.test_session ts
            ON ts.test_session_id = dts.test_session_id
          JOIN ops.work_order wo
            ON wo.display_test_session_id = dts.display_test_session_id
          WHERE dts.display_id = d.display_id
            AND ts.container_id = v_container_id
      )
    LIMIT 1;

    IF v_recycled_standalone_display_id IS NOT NULL THEN
        PERFORM ops.p_cleanup_recycled_standalone_display(
            v_recycled_standalone_display_id
        );
    END IF;

END;
$$;


ALTER FUNCTION ops.p_refresh_test_session(p_test_session_id bigint, p_refreshed_by text, p_refreshed_by_person_id integer) OWNER TO msbadmin;

--
-- TOC entry 6159 (class 0 OID 0)
-- Dependencies: 987
-- Name: FUNCTION p_refresh_test_session(p_test_session_id bigint, p_refreshed_by text, p_refreshed_by_person_id integer); Type: COMMENT; Schema: ops; Owner: msbadmin
--

COMMENT ON FUNCTION ops.p_refresh_test_session(p_test_session_id bigint, p_refreshed_by text, p_refreshed_by_person_id integer) IS 'Updated 3/25/26 to delete safe rows that do not have work orders assigned to them.';


--
-- TOC entry 1167 (class 1255 OID 19110)
-- Name: set_audit_fields(); Type: FUNCTION; Schema: ops; Owner: msbadmin
--

CREATE FUNCTION ops.set_audit_fields() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    NEW.updated_at := now();
    NEW.updated_by := current_user;
    RETURN NEW;
END;
$$;


ALTER FUNCTION ops.set_audit_fields() OWNER TO msbadmin;

--
-- TOC entry 968 (class 1255 OID 19175)
-- Name: set_checked_actor(); Type: FUNCTION; Schema: ops; Owner: msbadmin
--

CREATE FUNCTION ops.set_checked_actor() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE
    v_person_id integer;
    v_actor_name text;
BEGIN
    -- Stamp checked fields whenever test_status changes
    -- to a nonblank value. This makes checked_* represent
    -- the latest person who set the current test status.
    IF NEW.test_status IS DISTINCT FROM OLD.test_status
       AND NEW.test_status IS NOT NULL
       AND btrim(NEW.test_status) <> '' THEN

        SELECT person_id, actor_name
        INTO v_person_id, v_actor_name
        FROM ref.resolve_actor();

        -- Database owns checked_at
        NEW.checked_at := now();

        -- Respect Directus-stamped values if present;
        -- otherwise fall back to DB actor resolution.
        NEW.checked_by := COALESCE(NEW.checked_by, v_actor_name);

        IF to_jsonb(NEW) ? 'checked_by_person_id' THEN
            NEW.checked_by_person_id := COALESCE(NEW.checked_by_person_id, v_person_id);
        END IF;
    END IF;

    RETURN NEW;
END;
$$;


ALTER FUNCTION ops.set_checked_actor() OWNER TO msbadmin;

--
-- TOC entry 574 (class 1255 OID 19297)
-- Name: set_container_search_helper(); Type: FUNCTION; Schema: ops; Owner: msbadmin
--

CREATE FUNCTION ops.set_container_search_helper() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
  SELECT LEFT(c.description, 20)
    INTO NEW.container_search_helper
  FROM ref.container c
  WHERE c.container_id = NEW.container_id;

  RETURN NEW;
END;
$$;


ALTER FUNCTION ops.set_container_search_helper() OWNER TO msbadmin;

--
-- TOC entry 753 (class 1255 OID 19555)
-- Name: tf_after_refresh_test_session(); Type: FUNCTION; Schema: ops; Owner: msbadmin
--

CREATE FUNCTION ops.tf_after_refresh_test_session() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    IF pg_trigger_depth() > 1 THEN
        RETURN NULL;
    END IF;

    IF OLD.refresh_requested = FALSE
       AND NEW.refresh_requested = TRUE THEN

        PERFORM ops.p_refresh_test_session(
            NEW.test_session_id,
            NEW.updated_by,
            NEW.updated_by_person_id
        );
    END IF;

    RETURN NULL;
END;
$$;


ALTER FUNCTION ops.tf_after_refresh_test_session() OWNER TO msbadmin;

--
-- TOC entry 848 (class 1255 OID 19301)
-- Name: tf_after_start_container_pull(); Type: FUNCTION; Schema: ops; Owner: msbadmin
--

CREATE FUNCTION ops.tf_after_start_container_pull() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
  IF pg_trigger_depth() > 1 THEN
    RETURN NULL;
  END IF;

  IF OLD.container_test_status_id = 1
     AND NEW.container_test_status_id = 2
     AND NEW.work_location_code IS NOT NULL THEN

    PERFORM ops.p_pull_container(
      NEW.container_id,
      NEW.work_location_code,
      NEW.updated_by,
      NEW.updated_by_person_id
    );
  END IF;

  RETURN NULL;
END;
$$;


ALTER FUNCTION ops.tf_after_start_container_pull() OWNER TO msbadmin;

--
-- TOC entry 754 (class 1255 OID 19292)
-- Name: tf_start_container_pull(); Type: FUNCTION; Schema: ops; Owner: msbadmin
--

CREATE FUNCTION ops.tf_start_container_pull() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
  -- Require work location only on Not Started -> In Progress
  IF OLD.container_test_status_id = 1
     AND NEW.container_test_status_id = 2 THEN

    IF NEW.work_location_code IS NULL OR btrim(NEW.work_location_code) = '' THEN
      RAISE EXCEPTION 'Work Location Required to Pull Container';
    END IF;
  END IF;

  -- Keep work location only for In Progress (2) and Deferred (8)
  IF NEW.container_test_status_id NOT IN (2, 8) THEN
    NEW.work_location_code := NULL;
  END IF;

  RETURN NEW;
END;
$$;


ALTER FUNCTION ops.tf_start_container_pull() OWNER TO msbadmin;

--
-- TOC entry 904 (class 1255 OID 19560)
-- Name: tf_validate_display_test_session_notes(); Type: FUNCTION; Schema: ops; Owner: msbadmin
--

CREATE FUNCTION ops.tf_validate_display_test_session_notes() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    IF NEW.test_status = 'REPAIR'
       AND NULLIF(BTRIM(COALESCE(NEW.notes, '')), '') IS NULL THEN
        RAISE EXCEPTION 'REPAIR requires a note describing the problem.';
    END IF;

    IF NEW.test_status = 'OK_REPAIRED'
       AND NULLIF(BTRIM(COALESCE(NEW.notes, '')), '') IS NULL THEN
        RAISE EXCEPTION 'OK_REPAIRED requires a note describing the repair.';
    END IF;

    RETURN NEW;
END;
$$;


ALTER FUNCTION ops.tf_validate_display_test_session_notes() OWNER TO msbadmin;

--
-- TOC entry 627 (class 1255 OID 19574)
-- Name: tf_work_order_autofill_completion_on_repair_complete(); Type: FUNCTION; Schema: ops; Owner: msbadmin
--

CREATE FUNCTION ops.tf_work_order_autofill_completion_on_repair_complete() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE
    v_person_id integer;
    v_actor_name text;
BEGIN
    IF NEW.repair_complete IS TRUE
       OR NEW.date_completed IS NOT NULL THEN

        IF NEW.completed_by_person_id IS NULL THEN
            SELECT person_id, actor_name
            INTO v_person_id, v_actor_name
            FROM ref.resolve_actor();

            NEW.completed_by_person_id := COALESCE(v_person_id, NEW.updated_by_person_id);
        END IF;

        IF NEW.repair_complete IS TRUE AND NEW.date_completed IS NULL THEN
            NEW.date_completed := now();
        END IF;

    END IF;

    RETURN NEW;
END;
$$;


ALTER FUNCTION ops.tf_work_order_autofill_completion_on_repair_complete() OWNER TO msbadmin;

--
-- TOC entry 958 (class 1255 OID 24141)
-- Name: trg_auto_approve_safe_uuid_relink(); Type: FUNCTION; Schema: ops; Owner: msbadmin
--

CREATE FUNCTION ops.trg_auto_approve_safe_uuid_relink() RETURNS trigger
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'pg_catalog', 'ops'
    AS $$
BEGIN
    IF NEW.classification_code <> 'UUID_CHANGED_SAME_NAME' THEN
        RETURN NEW;
    END IF;

    IF NOT EXISTS (
        SELECT 1
        FROM ops.lor_reconciliation_group AS g
        WHERE g.lor_reconciliation_group_id =
              NEW.lor_reconciliation_group_id
          AND g.entity_type = 'DISPLAY'
          AND g.group_kind = 'SINGLE_CANDIDATE'
          AND g.member_count = 1
          AND NOT g.requires_atomic_decision
    ) THEN
        RETURN NEW;
    END IF;

    /* Frozen candidates and groups are immutable; approval is append-only. */
    INSERT INTO ops.lor_reconciliation_action (
        lor_reconciliation_run_id,
        lor_reconciliation_group_id,
        import_run_id,
        action_type,
        reason,
        action_payload,
        acted_by_application
    )
    SELECT
        NEW.lor_reconciliation_run_id,
        NEW.lor_reconciliation_group_id,
        NEW.import_run_id,
        'UPDATE_LOR_LINK',
        format(
            'Automatic exact-name UUID relink for display_id %s: the unique ACTIVE display name is unchanged and the new UUID is unique and unclaimed.',
            NEW.display_id
        ),
        jsonb_build_object(
            'policy', 'SAFE_EXACT_NAME_UUID_RELINK',
            'candidate_id', NEW.lor_reconciliation_display_candidate_id
        ),
        'reconciliation:auto-safe-uuid-relink'
    WHERE NOT EXISTS (
        SELECT 1
        FROM ops.lor_reconciliation_action AS a
        WHERE a.lor_reconciliation_group_id =
              NEW.lor_reconciliation_group_id
    );

    RETURN NEW;
END;
$$;


ALTER FUNCTION ops.trg_auto_approve_safe_uuid_relink() OWNER TO msbadmin;

--
-- TOC entry 6169 (class 0 OID 0)
-- Dependencies: 958
-- Name: FUNCTION trg_auto_approve_safe_uuid_relink(); Type: COMMENT; Schema: ops; Owner: msbadmin
--

COMMENT ON FUNCTION ops.trg_auto_approve_safe_uuid_relink() IS 'Appends an automatic UPDATE_LOR_LINK action for only a single, non-atomic UUID_CHANGED_SAME_NAME frozen candidate after the reconciliation preflight uniqueness and collision guards pass.';


--
-- TOC entry 1170 (class 1255 OID 23510)
-- Name: trg_lor_reconciliation_detail_immutable(); Type: FUNCTION; Schema: ops; Owner: msbadmin
--

CREATE FUNCTION ops.trg_lor_reconciliation_detail_immutable() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    RAISE EXCEPTION
        '%.% is immutable; insert a new audit row or superseding action instead',
        TG_TABLE_SCHEMA,
        TG_TABLE_NAME;
END;
$$;


ALTER FUNCTION ops.trg_lor_reconciliation_detail_immutable() OWNER TO msbadmin;

--
-- TOC entry 1278 (class 1255 OID 23942)
-- Name: trg_require_terminal_reconciliation_decisions(); Type: FUNCTION; Schema: ops; Owner: msbadmin
--

CREATE FUNCTION ops.trg_require_terminal_reconciliation_decisions() RETURNS trigger
    LANGUAGE plpgsql
    SET search_path TO 'pg_catalog', 'ops'
    AS $$
BEGIN
    IF NEW.status = 'PROMOTING'
       AND OLD.status IS DISTINCT FROM NEW.status
       AND EXISTS (
           SELECT 1
           FROM ops.v_lor_reconciliation_group_review AS gr
           WHERE gr.lor_reconciliation_run_id = NEW.lor_reconciliation_run_id
             AND gr.effective_resolution_state = 'UNRESOLVED'
       ) THEN
        RAISE EXCEPTION
            'Reconciliation run % still has required decisions without a terminal operator outcome',
            NEW.lor_reconciliation_run_id;
    END IF;

    IF NEW.status = 'PROMOTING'
       AND OLD.status IS DISTINCT FROM NEW.status THEN
        INSERT INTO ops.lor_reconciliation_result (
            lor_reconciliation_run_id, import_run_id, entity_type, entity_key,
            result_class, reason_code, operator_message, committed
        )
        SELECT
            gr.lor_reconciliation_run_id,
            gr.import_run_id,
            gr.entity_type,
            gr.logical_group_key,
            'BLOCKED',
            'OPERATOR_CHANGE_NOT_ACCEPTED',
            coalesce(
                gr.effective_reason,
                'The operator required source correction and left production unchanged.'
            ),
            false
        FROM ops.v_lor_reconciliation_group_review AS gr
        WHERE gr.lor_reconciliation_run_id = NEW.lor_reconciliation_run_id
          AND gr.effective_action_type IN (
              'CORRECT_SOURCE_REQUIRED',
              'RESTORE_TO_LOR_REQUIRED'
          )
          AND NOT EXISTS (
              SELECT 1
              FROM ops.lor_reconciliation_result AS rr
              WHERE rr.lor_reconciliation_run_id =
                    gr.lor_reconciliation_run_id
                AND rr.entity_type = gr.entity_type
                AND rr.entity_key = gr.logical_group_key
                AND rr.reason_code = 'OPERATOR_CHANGE_NOT_ACCEPTED'
          );
    END IF;
    RETURN NEW;
END;
$$;


ALTER FUNCTION ops.trg_require_terminal_reconciliation_decisions() OWNER TO msbadmin;

--
-- TOC entry 1214 (class 1255 OID 17175)
-- Name: apply_display_metadata_from_sheet(); Type: PROCEDURE; Schema: ref; Owner: msbadmin
--

CREATE PROCEDURE ref.apply_display_metadata_from_sheet()
    LANGUAGE plpgsql
    AS $$/*
apply_display_metadata_from_sheet
*/

begin
  -- Direct fields + pallet_id normalization + cast to int
  update ref.display d
  set
    year_built      = m.year_built,
    amps_measured   = m.amps_measured,
    est_light_count = m.est_light_count,
    dumb_controller = m.dumb_controller,
    notes           = m.notes,

    pallet_id = nullif(
                  regexp_replace(coalesce(m.pallet_id_raw,''), '[^0-9]', '', 'g'),
                  ''
                )::integer,

    updated_at      = now(),
    updated_by      = current_user
  from stage.v_sheet_match m
  where m.lor_prop_id = d.lor_prop_id;

  -- Status text -> id
  update ref.display d
  set
    display_status_id = ds.display_status_id,
    updated_at = now(),
    updated_by = current_user
  from stage.v_sheet_match m
  join ref.display_status ds
    on upper(ds.display_status_name) = upper(m.display_status)
  where m.lor_prop_id = d.lor_prop_id
    and m.display_status is not null
    and btrim(m.display_status) <> '';

  -- Theme name -> theme_id
  update ref.display d
  set
    theme_id = t.theme_id,
    updated_at = now(),
    updated_by = current_user
  from stage.v_sheet_match m
  join ref.theme t
    on upper(t.theme_name) = upper(m.theme_name)
  where m.lor_prop_id = d.lor_prop_id
    and m.theme_name is not null
    and btrim(m.theme_name) <> '';

  -- Designer "First Last" -> person_id
  update ref.display d
  set
    designer_id = p.person_id,
    updated_at = now(),
    updated_by = current_user
  from stage.v_sheet_match m
  join ref.person p
    on upper(p.first_name || ' ' || p.last_name) = upper(m.designer_name)
  where m.lor_prop_id = d.lor_prop_id
    and m.designer_name is not null
    and btrim(m.designer_name) <> '';

  -- Frame name -> frame_id (ref.frame.frame_name)
  update ref.display d
  set
    frame_id = f.frame_id,
    updated_at = now(),
    updated_by = current_user
  from stage.v_sheet_match m
  join ref.frame f
    on upper(f.frame_name) = upper(m.frame_name)
  where m.lor_prop_id = d.lor_prop_id
    and m.frame_name is not null
    and btrim(m.frame_name) <> '';

end;
$$;


ALTER PROCEDURE ref.apply_display_metadata_from_sheet() OWNER TO msbadmin;

--
-- TOC entry 508 (class 1255 OID 23664)
-- Name: p1_promote_stage_from_reconciliation(bigint); Type: PROCEDURE; Schema: ref; Owner: msbadmin
--

CREATE PROCEDURE ref.p1_promote_stage_from_reconciliation(IN p_lor_reconciliation_run_id bigint)
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'pg_catalog', 'ops', 'lor_snap', 'ref'
    AS $$
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
$$;


ALTER PROCEDURE ref.p1_promote_stage_from_reconciliation(IN p_lor_reconciliation_run_id bigint) OWNER TO msbadmin;

--
-- TOC entry 6173 (class 0 OID 0)
-- Dependencies: 508
-- Name: PROCEDURE p1_promote_stage_from_reconciliation(IN p_lor_reconciliation_run_id bigint); Type: COMMENT; Schema: ref; Owner: msbadmin
--

COMMENT ON PROCEDURE ref.p1_promote_stage_from_reconciliation(IN p_lor_reconciliation_run_id bigint) IS 'Internal reconciliation-gated P1. Promotes approved frozen stage metadata except where explicitly preserved, binds all approved LOR identities, never selects an ingest, and never deletes stages.';


--
-- TOC entry 935 (class 1255 OID 18341)
-- Name: p1_upsert_stage_from_latest_lor(); Type: PROCEDURE; Schema: ref; Owner: msbadmin
--

CREATE PROCEDURE ref.p1_upsert_stage_from_latest_lor()
    LANGUAGE plpgsql
    AS $_$/*
Procedure: ref.p1_upsert_stage_from_latest_lor

Purpose:
  Upsert ref.stage from the latest LOR snapshot (lor_snap.previews).
  Fully derived from preview names; non-destructive; preserves stage_id stability.

Reads:
  lor_snap.import_run
  lor_snap.previews

Writes:
  ref.stage (UPSERT)
    - inserts missing stage_key
    - updates stage_name/folder_name/order fields for existing stage_key
    - never deletes/truncates

Notes:
  - Uses DISTINCT ON(stage_key) to guarantee one row per stage_key (prevents ON CONFLICT double-hit).
  - stage_key is lower(previews.stage_id) and supports substages like '07a'.

Revision History:
  2026-02-27  GAL  Initial + fix duplicate-stage-key conflict in single insert.

ref.p1_upsert_stage_from_latest_lor

Purpose:
  Upsert ref.stage from the latest lor_snap.previews import.
  LOR is authoritative for stage naming.

Rules:
  - Only accept canonical stage IDs: 0-99 with optional letter suffix (e.g. 07, 07a)
  - stage_key is normalized: lower(btrim(stage_id))
  - stage_name + folder_name derived from preview name

Notes:
  - This does NOT delete stages that are no longer present in LOR.
*/
declare
  v_run_id bigint;
begin
  select max(import_run_id)
    into v_run_id
  from lor_snap.import_run;

  if v_run_id is null then
    raise exception 'No import_run_id found in lor_snap.import_run';
  end if;

  /*
    Choose ONE preview row per stage_key.
    Ordering rule (deterministic):
      - prefer names that start with "Stage"
      - then prefer longer names (more descriptive)
      - then stable tie-breaker by name
  */
  with one_per_stage as (
    select distinct on (lower(p.stage_id))
      lower(p.stage_id) as stage_key,
      p.stage_id        as stage_id_raw,
      p.name            as preview_name
    from lor_snap.previews p
    where p.import_run_id = v_run_id
      and p.stage_id is not null
      and btrim(p.stage_id) <> ''
    order by
      lower(p.stage_id),
      (p.name ~* '^\s*stage\b') desc,
      length(p.name) desc,
      p.name desc
  )
  insert into ref.stage (
      stage_key,
      stage_name,
      short_code,
      folder_name,
      folder_path,
      park_order,
      sub_order,
      created_at,
      created_by,
      updated_at,
      updated_by
  )
  select
      s.stage_key,

      /* stage_name: strip leading "Stage <key>" and trailing "with|w/" */
      coalesce(
        nullif(
          btrim(
            regexp_replace(
              regexp_replace(
                s.preview_name,
                '(?i)^\s*stage\s*0*' || s.stage_id_raw || '\s*',
                ''
              ),
              '\s+(with|w/)\s+.*$',
              '',
              'i'
            )
          ),
          ''
        ),
        'Stage ' || s.stage_id_raw
      ) as stage_name,

      null as short_code,

      /* folder_name: "<stage_key>-<stage_name>" */
      s.stage_key || '-' ||
      coalesce(
        nullif(
          btrim(
            regexp_replace(
              regexp_replace(
                s.preview_name,
                '(?i)^\s*stage\s*0*' || s.stage_id_raw || '\s*',
                ''
              ),
              '\s+(with|w/)\s+.*$',
              '',
              'i'
            )
          ),
          ''
        ),
        'Stage'
      ) as folder_name,

      null as folder_path,

      /* park_order: numeric part */
      ((regexp_match(lower(s.stage_id_raw), '^0*(\d{1,2})'))[1])::int as park_order,

      /* sub_order: a=1, b=2, ... else 0 */
      case
        when lower(s.stage_id_raw) ~ '^\d{1,2}[a-z]$'
          then ascii(substring(lower(s.stage_id_raw) from '[a-z]')) - ascii('a') + 1
        else 0
      end as sub_order,

      now(),
      current_user,
      now(),
      current_user

  from one_per_stage s

  on conflict (stage_key)
  do update set
      stage_name  = excluded.stage_name,
      folder_name = excluded.folder_name,
      park_order  = excluded.park_order,
      sub_order   = excluded.sub_order,
      updated_at  = now(),
      updated_by  = current_user;

end;
$_$;


ALTER PROCEDURE ref.p1_upsert_stage_from_latest_lor() OWNER TO msbadmin;

--
-- TOC entry 6175 (class 0 OID 0)
-- Dependencies: 935
-- Name: PROCEDURE p1_upsert_stage_from_latest_lor(); Type: COMMENT; Schema: ref; Owner: msbadmin
--

COMMENT ON PROCEDURE ref.p1_upsert_stage_from_latest_lor() IS '/*
Procedure: ref.p1_upsert_stage_from_latest_lor

Purpose:
  Upsert ref.stage from the latest LOR snapshot (lor_snap.previews).
  Fully derived from preview names; non-destructive; preserves stage_id stability.

Reads:
  lor_snap.import_run
  lor_snap.previews

Writes:
  ref.stage (UPSERT)
    - inserts missing stage_key
    - updates stage_name/folder_name/order fields for existing stage_key
    - never deletes/truncates

Notes:
  - Uses DISTINCT ON(stage_key) to guarantee one row per stage_key (prevents ON CONFLICT double-hit).
  - stage_key is lower(previews.stage_id) and supports substages like ''07a''.

Revision History:
  2026-02-27  GAL  Initial + fix duplicate-stage-key conflict in single insert.
Revision History:
  2026-02-27  GAL  Initial + fix duplicate-stage-key conflict in single insert.

ref.p1_upsert_stage_from_latest_lor

Purpose:
  Upsert ref.stage from the latest lor_snap.previews import.
  LOR is authoritative for stage naming.

Rules:
  - Only accept canonical stage IDs: 0-99 with optional letter suffix (e.g. 07, 07a)
  - stage_key is normalized: lower(btrim(stage_id))
  - stage_name + folder_name derived from preview name

Notes:
  - This does NOT delete stages that are no longer present in LOR.
*/';


--
-- TOC entry 619 (class 1255 OID 23688)
-- Name: p2_promote_display_from_reconciliation(bigint); Type: PROCEDURE; Schema: ref; Owner: msbadmin
--

CREATE PROCEDURE ref.p2_promote_display_from_reconciliation(IN p_lor_reconciliation_run_id bigint)
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'pg_catalog', 'ops', 'lor_snap', 'ref'
    AS $$
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
                v_active_status_id, v_row.proposed_stage_id,
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
                   stage_id = v_row.proposed_stage_id,
                   string_type = v_row.proposed_string_type
             WHERE d.display_id = v_display_id
               AND (
                   d.lor_prop_id IS DISTINCT FROM v_row.lor_prop_id
                   OR d.display_name IS DISTINCT FROM v_row.proposed_display_name
                   OR d.stage_id IS DISTINCT FROM v_row.proposed_stage_id
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
$$;


ALTER PROCEDURE ref.p2_promote_display_from_reconciliation(IN p_lor_reconciliation_run_id bigint) OWNER TO msbadmin;

--
-- TOC entry 6176 (class 0 OID 0)
-- Dependencies: 619
-- Name: PROCEDURE p2_promote_display_from_reconciliation(IN p_lor_reconciliation_run_id bigint); Type: COMMENT; Schema: ref; Owner: msbadmin
--

COMMENT ON PROCEDURE ref.p2_promote_display_from_reconciliation(IN p_lor_reconciliation_run_id bigint) IS 'Internal reconciliation-gated P2. Revalidates exact raw source rows, rejects nonphysical names, preserves display_id and production-owned metadata, and applies only approved atomic groups.';


--
-- TOC entry 1191 (class 1255 OID 18571)
-- Name: p2_upsert_display_from_latest_lor(); Type: PROCEDURE; Schema: ref; Owner: msbadmin
--

CREATE PROCEDURE ref.p2_upsert_display_from_latest_lor()
    LANGUAGE plpgsql
    AS $_$
/* ============================================================
Procedure: ref.p2_upsert_display_from_latest_lor()

Purpose:
  Upsert NON-SPARE displays into ref.display from latest LOR snapshot.
  Route SPARE items into ref.spare_channel.
  Ensure NO SPARE rows remain in ref.display for latest run set.

Revision History:
  2026-02-27 GAL  Fix CTE scope bug by materializing tmp_classified.
  2026-02-28 GAL  Dedupe lor_prop_id to prevent ON CONFLICT double-update.
  2026-03-01 GAL  Add string_type + color (LOR-owned) to ref.display + ref.spare_channel.
============================================================ */
declare
  v_run_id bigint;

v_active_status_id integer;

v_missing_stage_keys integer;

begin
  /* 1) Latest import */
select
	max(import_run_id)
into
	v_run_id
from
	lor_snap.import_run;

if v_run_id is null then
    raise exception 'No import_run_id found in lor_snap.import_run';
end if;

/* 2) ACTIVE display status */
select
	display_status_id
into
	v_active_status_id
from
	ref.display_status
where
	upper(display_status_name) = 'ACTIVE'
limit 1;

if v_active_status_id is null then
    raise exception 'ACTIVE status not found in ref.display_status';
end if;

/* 3) Guardrail: stage keys must exist */
select
	count(*)
into
	v_missing_stage_keys
from
	(
	select
		distinct lower(btrim(pr.stage_id)) as stage_key
	from
		lor_snap.props p
	join lor_snap.previews pr on
		pr.id = p.preview_id
	where
		p.import_run_id = v_run_id
		and pr.stage_id is not null
		and btrim(pr.stage_id) <> ''
			and lower(btrim(pr.stage_id)) ~ '^0*\d{1,2}[a-z]?$'
  ) k
left join ref.stage s on
	s.stage_key = k.stage_key
where
	s.stage_key is null;

if v_missing_stage_keys > 0 then
    raise exception
      'Missing % stage_key rows in ref.stage for latest import_run_id=% (run p1_upsert_stage first)',
v_missing_stage_keys,
v_run_id;
end if;

/* 4) Materialize a deterministic, deduped classified set for this run */
create temporary table tmp_classified (
    lor_prop_id text,
display_name text,
prop_name text,
prop_comment text,
preview_stage_key text,
string_type text,
color text,
is_spare boolean
  ) on
commit drop;

insert
	into
	tmp_classified (
    lor_prop_id,
	display_name,
	prop_name,
	prop_comment,
	preview_stage_key,
	string_type,
	color,
	is_spare
  )
select
	lr.lor_prop_id,
	lr.display_name,
	lr.prop_name,
	lr.prop_comment,
	lr.preview_stage_key,
	lr.string_type,
	lr.color,
	case
		when lr.display_name ilike '%spare%'
		or coalesce(lr.prop_name, '') ilike '%spare%'
		or coalesce(lr.prop_comment, '') ilike '%spare%'
      then true
		else false
	end as is_spare
from
	(
	select
		distinct on
		(p.prop_id)
      p.prop_id as lor_prop_id,
		coalesce(nullif(btrim(p.lor_comment), ''), p.name) as display_name,
		p.name as prop_name,
		p.lor_comment as prop_comment,
		lower(btrim(pr.stage_id)) as preview_stage_key,
		p.string_type,
		p.color
	from
		lor_snap.props p
	join lor_snap.previews pr
      on
		pr.id = p.preview_id
	where
		p.import_run_id = v_run_id
		and upper(coalesce(nullif(btrim(p.lor_comment), ''), p.name)) not like '%PHANTOM%'
			and pr.stage_id is not null
			and btrim(pr.stage_id) <> ''
				and lower(btrim(pr.stage_id)) ~ '^0*\d{1,2}[a-z]?$'
			order by
				p.prop_id,
				(nullif(btrim(p.lor_comment), '') is not null) desc,
				length(coalesce(p.lor_comment, '')) desc,
				p.name desc
  ) lr;

/* 5) Upsert SPARE into ref.spare_channel */
insert
	into
	ref.spare_channel (
      lor_prop_id,
	display_name,
	inventory_type,
	display_status_id,
	stage_id,
	string_type,
	color
  )
select
	c.lor_prop_id,
	c.display_name,
	'LOR',
	v_active_status_id,
	s.stage_id,
	c.string_type,
	c.color
from
	tmp_classified c
join ref.stage s
    on
	s.stage_key = c.preview_stage_key
where
	c.is_spare = true
  on
	conflict (lor_prop_id)
  do
update
set
	display_name = excluded.display_name,
	inventory_type = excluded.inventory_type,
	display_status_id = excluded.display_status_id,
	stage_id = excluded.stage_id,
	string_type = excluded.string_type,
	color = excluded.color;

/* 6) Ensure SPARE rows are NOT in ref.display (latest run set only) */
-- delete
-- from
-- 	ref.display d
-- 		using tmp_classified c
-- where
-- 	c.is_spare = true
-- 	and d.lor_prop_id = c.lor_prop_id;
/* 6) Do NOT delete production display rows when latest LOR classifies a prop as SPARE.
      SPARE belongs in ref.spare_channel only.
      Conflicts must be reviewed manually. */
perform 1;

/* 7) Promote NON-SPARE into ref.display using 3-step logic
      A. Match existing rows by lor_prop_id
      B. Match remaining rows by display_name
      C. Insert anything still unmatched
*/
/* 7A) Update existing rows matched by lor_prop_id */
update
	ref.display d
set
	display_name = c.display_name,
	inventory_type = 'LOR',
	display_status_id = v_active_status_id,
	stage_id = s.stage_id,
	string_type = c.string_type,
	color = c.color,
	updated_at = now(),
	updated_by = current_user
from
	tmp_classified c
join ref.stage s
  on
	s.stage_key = c.preview_stage_key
where
	c.is_spare = false
	and d.lor_prop_id = c.lor_prop_id;

/* 7B assumes latest tmp_classified has at most one NON-SPARE row per display_name.
   Run duplicate-name preflight before calling p2. */
update
	ref.display d
set
	lor_prop_id = c.lor_prop_id,
	inventory_type = 'LOR',
	display_status_id = v_active_status_id,
	stage_id = s.stage_id,
	string_type = c.string_type,
	color = c.color,
	updated_at = now(),
	updated_by = current_user
from
	tmp_classified c
join ref.stage s
  on
	s.stage_key = c.preview_stage_key
where
	c.is_spare = false
	and upper(btrim(d.display_name)) = upper(btrim(c.display_name))
	and not exists (
	select
		1
	from
		ref.display d2
	where
		d2.lor_prop_id = c.lor_prop_id
  );

/* 7C) Insert brand new rows
      only when neither lor_prop_id nor display_name already exists */
insert
	into
	ref.display (
    lor_prop_id,
	display_name,
	inventory_type,
	display_status_id,
	stage_id,
	string_type,
	color
)
select
	c.lor_prop_id,
	c.display_name,
	'LOR',
	v_active_status_id,
	s.stage_id,
	c.string_type,
	c.color
from
	tmp_classified c
join ref.stage s
  on
	s.stage_key = c.preview_stage_key
where
	c.is_spare = false
	and not exists (
	select
		1
	from
		ref.display d
	where
		d.lor_prop_id = c.lor_prop_id
  )
	and not exists (
	select
		1
	from
		ref.display d
	where
		upper(btrim(d.display_name)) = upper(btrim(c.display_name))
  );
end;

$_$;


ALTER PROCEDURE ref.p2_upsert_display_from_latest_lor() OWNER TO msbadmin;

--
-- TOC entry 6178 (class 0 OID 0)
-- Dependencies: 1191
-- Name: PROCEDURE p2_upsert_display_from_latest_lor(); Type: COMMENT; Schema: ref; Owner: msbadmin
--

COMMENT ON PROCEDURE ref.p2_upsert_display_from_latest_lor() IS '/* ============================================================
Procedure: ref.p2_upsert_display_from_latest_lor()

Purpose:
  Upsert NON-SPARE displays into ref.display from latest LOR snapshot.
  Route SPARE items into ref.spare_channel.
  Ensure NO SPARE rows remain in ref.display for latest run set.

Revision History:
  2026-02-27 GAL  Fix CTE scope bug by materializing tmp_classified.
  2026-02-28 GAL  Dedupe lor_prop_id to prevent ON CONFLICT double-update.
Revision History:
  2026-02-27 GAL  Fix CTE scope bug by materializing tmp_classified.
  2026-02-28 GAL  Dedupe lor_prop_id to prevent ON CONFLICT double-update.
  2026-03-01 GAL  Add string_type + color (LOR-owned) to ref.display + ref.spare_channel.
  2026-03-17  GAL  Revise non-SPARE promotion logic to match by lor_prop_id first, then by display_name, then insert new rows.
============================================================ */';


--
-- TOC entry 1004 (class 1255 OID 23804)
-- Name: p3_promote_scene_from_reconciliation(bigint); Type: PROCEDURE; Schema: ref; Owner: msbadmin
--

CREATE PROCEDURE ref.p3_promote_scene_from_reconciliation(IN p_lor_reconciliation_run_id bigint)
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'pg_catalog', 'ops', 'lor_snap', 'ref'
    AS $$
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
            ;

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
$$;


ALTER PROCEDURE ref.p3_promote_scene_from_reconciliation(IN p_lor_reconciliation_run_id bigint) OWNER TO msbadmin;

--
-- TOC entry 6179 (class 0 OID 0)
-- Dependencies: 1004
-- Name: PROCEDURE p3_promote_scene_from_reconciliation(IN p_lor_reconciliation_run_id bigint); Type: COMMENT; Schema: ref; Owner: msbadmin
--

COMMENT ON PROCEDURE ref.p3_promote_scene_from_reconciliation(IN p_lor_reconciliation_run_id bigint) IS 'Internal reconciliation-gated P3. Synchronizes approved frozen scene definitions and safely removes obsolete current-state scenes.';


--
-- TOC entry 566 (class 1255 OID 23806)
-- Name: p4_promote_scene_display_from_reconciliation(bigint); Type: PROCEDURE; Schema: ref; Owner: msbadmin
--

CREATE PROCEDURE ref.p4_promote_scene_display_from_reconciliation(IN p_lor_reconciliation_run_id bigint)
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'pg_catalog', 'ops', 'lor_snap', 'ref'
    AS $$
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
            ;

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
$$;


ALTER PROCEDURE ref.p4_promote_scene_display_from_reconciliation(IN p_lor_reconciliation_run_id bigint) OWNER TO msbadmin;

--
-- TOC entry 6181 (class 0 OID 0)
-- Dependencies: 566
-- Name: PROCEDURE p4_promote_scene_display_from_reconciliation(IN p_lor_reconciliation_run_id bigint); Type: COMMENT; Schema: ref; Owner: msbadmin
--

COMMENT ON PROCEDURE ref.p4_promote_scene_display_from_reconciliation(IN p_lor_reconciliation_run_id bigint) IS 'Internal reconciliation-gated P4. Synchronizes approved frozen memberships by permanent display_id and conservatively removes obsolete current-state assignments.';


--
-- TOC entry 550 (class 1255 OID 19143)
-- Name: resolve_actor(); Type: FUNCTION; Schema: ref; Owner: msbadmin
--

CREATE FUNCTION ref.resolve_actor() RETURNS TABLE(person_id integer, actor_name text)
    LANGUAGE plpgsql
    AS $$
DECLARE
    v_directus_uuid text;
BEGIN
    v_directus_uuid := current_setting('app.directus_user_uuid', true);

    -- 1) Directus user
    IF v_directus_uuid IS NOT NULL AND btrim(v_directus_uuid) <> '' THEN
        SELECT p.person_id, p.preferred_name
        INTO person_id, actor_name
        FROM ref.person p
        WHERE p.directus_user_id::text = v_directus_uuid
        LIMIT 1;

        IF person_id IS NOT NULL THEN
            RETURN NEXT;
            RETURN;
        END IF;
    END IF;

    -- 2) PostgreSQL mapped login
    SELECT p.person_id, p.preferred_name
    INTO person_id, actor_name
    FROM ref.person p
    WHERE p.pg_login_name = current_user
    LIMIT 1;

    IF person_id IS NOT NULL THEN
        RETURN NEXT;
        RETURN;
    END IF;

    -- 3) fallback
    person_id := NULL;
    actor_name := current_user;

    RETURN NEXT;
    RETURN;
END;
$$;


ALTER FUNCTION ref.resolve_actor() OWNER TO msbadmin;

--
-- TOC entry 1265 (class 1255 OID 19141)
-- Name: set_actor_on_insert(); Type: FUNCTION; Schema: ref; Owner: msbadmin
--

CREATE FUNCTION ref.set_actor_on_insert() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE
    v_person_id integer;
    v_actor_name text;
BEGIN

    SELECT person_id, actor_name
    INTO v_person_id, v_actor_name
    FROM ref.resolve_actor();

    NEW.created_at := COALESCE(NEW.created_at, now());
    NEW.updated_at := COALESCE(NEW.updated_at, NEW.created_at);

    NEW.created_by := COALESCE(NEW.created_by, v_actor_name);
    NEW.updated_by := COALESCE(NEW.updated_by, v_actor_name);

    IF to_jsonb(NEW) ? 'created_by_person_id' THEN
        NEW.created_by_person_id := COALESCE(NEW.created_by_person_id, v_person_id);
    END IF;

    IF to_jsonb(NEW) ? 'updated_by_person_id' THEN
        NEW.updated_by_person_id := COALESCE(NEW.updated_by_person_id, v_person_id);
    END IF;

    RETURN NEW;

END;
$$;


ALTER FUNCTION ref.set_actor_on_insert() OWNER TO msbadmin;

--
-- TOC entry 1219 (class 1255 OID 19173)
-- Name: set_actor_on_update(); Type: FUNCTION; Schema: ref; Owner: msbadmin
--

CREATE FUNCTION ref.set_actor_on_update() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE
    v_person_id integer;
    v_actor_name text;
BEGIN
    SELECT person_id, actor_name
    INTO v_person_id, v_actor_name
    FROM ref.resolve_actor();

    NEW.updated_at := now();

    /*
      Preserve values already stamped by Directus.
      Only fall back to DB actor resolution if those fields are still null.
    */
    NEW.updated_by := COALESCE(NEW.updated_by, v_actor_name);

    IF to_jsonb(NEW) ? 'updated_by_person_id' THEN
        NEW.updated_by_person_id := COALESCE(NEW.updated_by_person_id, v_person_id);
    END IF;

    /*
      Hard fail only if this table has updated_by_person_id and it is still null
      after both Directus stamping and DB fallback resolution.
    */
    IF to_jsonb(NEW) ? 'updated_by_person_id'
       AND NEW.updated_by_person_id IS NULL THEN
        RAISE EXCEPTION
            'Audit actor resolution failed for %.% during update',
            TG_TABLE_SCHEMA,
            TG_TABLE_NAME;
    END IF;

    RETURN NEW;
END;
$$;


ALTER FUNCTION ref.set_actor_on_update() OWNER TO msbadmin;

--
-- TOC entry 877 (class 1255 OID 19111)
-- Name: set_audit_fields(); Type: FUNCTION; Schema: ref; Owner: msbadmin
--

CREATE FUNCTION ref.set_audit_fields() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    NEW.updated_at := now();
    NEW.updated_by := current_user;
    RETURN NEW;
END;
$$;


ALTER FUNCTION ref.set_audit_fields() OWNER TO msbadmin;

--
-- TOC entry 466 (class 1255 OID 16703)
-- Name: set_frame_updated_fields(); Type: FUNCTION; Schema: ref; Owner: msbadmin
--

CREATE FUNCTION ref.set_frame_updated_fields() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
begin
    new.updated_at := now();
    new.updated_by := current_user;
    return new;
end;
$$;


ALTER FUNCTION ref.set_frame_updated_fields() OWNER TO msbadmin;

--
-- TOC entry 723 (class 1255 OID 16722)
-- Name: set_updated_fields(); Type: FUNCTION; Schema: ref; Owner: msbadmin
--

CREATE FUNCTION ref.set_updated_fields() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE
    v_person_id integer;
    v_actor_name text;
BEGIN
    SELECT person_id, actor_name
    INTO v_person_id, v_actor_name
    FROM ref.resolve_actor();

    NEW.updated_at := now();

    -- Respect values already stamped by Directus; otherwise fallback to DB actor resolution
    NEW.updated_by := COALESCE(NEW.updated_by, v_actor_name);
    NEW.updated_by_person_id := COALESCE(NEW.updated_by_person_id, v_person_id);

    RETURN NEW;
END;
$$;


ALTER FUNCTION ref.set_updated_fields() OWNER TO msbadmin;

--
-- TOC entry 959 (class 1255 OID 19847)
-- Name: sync_audit_collection_policy(); Type: FUNCTION; Schema: ref; Owner: msbadmin
--

CREATE FUNCTION ref.sync_audit_collection_policy() RETURNS TABLE(action_taken text, schema_name text, collection_name text, checked_actor_enabled boolean)
    LANGUAGE plpgsql
    AS $$
BEGIN
    RETURN QUERY
    WITH base_tables AS (
        SELECT
            t.table_schema,
            t.table_name
        FROM information_schema.tables t
        WHERE t.table_type = 'BASE TABLE'
          AND t.table_schema IN ('ref', 'ops', 'stage')
          AND t.table_schema <> 'lor_snap'
    ),
    audit_columns AS (
        SELECT
            c.table_schema,
            c.table_name,
            bool_or(c.column_name = 'created_by')           AS has_created_by,
            bool_or(c.column_name = 'created_by_person_id') AS has_created_by_person_id,
            bool_or(c.column_name = 'updated_by')           AS has_updated_by,
            bool_or(c.column_name = 'updated_by_person_id') AS has_updated_by_person_id,
            bool_or(c.column_name = 'checked_by')           AS has_checked_by,
            bool_or(c.column_name = 'checked_by_person_id') AS has_checked_by_person_id
        FROM information_schema.columns c
        WHERE c.table_schema IN ('ref', 'ops', 'stage')
        GROUP BY
            c.table_schema,
            c.table_name
    ),
    eligible_tables AS (
        SELECT
            bt.table_schema,
            bt.table_name,
            ac.has_checked_by,
            ac.has_checked_by_person_id
        FROM base_tables bt
        JOIN audit_columns ac
          ON ac.table_schema = bt.table_schema
         AND ac.table_name   = bt.table_name
        WHERE ac.has_created_by
          AND ac.has_created_by_person_id
          AND ac.has_updated_by
          AND ac.has_updated_by_person_id
    ),
    inserted_rows AS (
        INSERT INTO ref.audit_collection_policy (
            schema_name,
            collection_name,
            insert_actor_enabled,
            update_actor_enabled,
            checked_actor_enabled,
            active_flag,
            notes
        )
        SELECT
            e.table_schema,
            e.table_name,
            true,
            true,
            (e.has_checked_by AND e.has_checked_by_person_id),
            true,
            'Auto-added by ref.sync_audit_collection_policy()'
        FROM eligible_tables e
        WHERE NOT EXISTS (
            SELECT 1
            FROM ref.audit_collection_policy p
            WHERE p.schema_name = e.table_schema
              AND p.collection_name = e.table_name
        )
        RETURNING
            'INSERTED'::text,
            ref.audit_collection_policy.schema_name,
            ref.audit_collection_policy.collection_name,
            ref.audit_collection_policy.checked_actor_enabled
    )
    SELECT *
    FROM inserted_rows
    ORDER BY 2, 3;
END;
$$;


ALTER FUNCTION ref.sync_audit_collection_policy() OWNER TO msbadmin;

--
-- TOC entry 6189 (class 0 OID 0)
-- Dependencies: 959
-- Name: FUNCTION sync_audit_collection_policy(); Type: COMMENT; Schema: ref; Owner: msbadmin
--

COMMENT ON FUNCTION ref.sync_audit_collection_policy() IS '/*
===============================================================================
ref.sync_audit_collection_policy()
-------------------------------------------------------------------------------
Purpose
-------------------------------------------------------------------------------
Synchronize the governance table ref.audit_collection_policy with actual
application tables that support actor-based audit stamping.

This function detects tables that are structurally capable of audit stamping
(because they contain the required audit columns) and inserts missing policy
rows using the system’s standard defaults.

It is intended to eliminate manual errors when onboarding new tables and to
prevent Directus audit hooks from silently skipping collections.

-------------------------------------------------------------------------------
Why this exists
-------------------------------------------------------------------------------
If a table is not present in ref.audit_collection_policy:

• Directus actor-stamping hooks will skip it
• Database triggers may fail or behave inconsistently
• NOT NULL violations can occur for audit columns
• Audit history becomes incomplete or incorrect

This function closes that governance gap.

-------------------------------------------------------------------------------
Scope of tables considered
-------------------------------------------------------------------------------
Only BASE TABLES in the following schemas are evaluated:

  ref
  ops
  stage

The ingestion schema lor_snap is intentionally excluded because those tables:

• Are system-generated snapshots
• Do not contain actor audit columns
• Are not edited by users
• Should never participate in actor stamping

Views, foreign tables, and system schemas are ignored.

-------------------------------------------------------------------------------
Eligibility requirements for inclusion
-------------------------------------------------------------------------------
A table is added ONLY if it physically contains ALL of the following columns:

  created_by
  created_by_person_id
  updated_by
  updated_by_person_id

This ensures that only audit-capable tables are enrolled.

Tables lacking these columns are skipped automatically.

-------------------------------------------------------------------------------
Checked actor behavior
-------------------------------------------------------------------------------
checked_actor_enabled is set to TRUE only if the table ALSO contains:

  checked_by
  checked_by_person_id

This supports specialized workflows (e.g., testing validation) while keeping
the default simple for all other tables.

-------------------------------------------------------------------------------
Defaults applied to newly inserted policy rows
-------------------------------------------------------------------------------
insert_actor_enabled  = TRUE
update_actor_enabled  = TRUE
checked_actor_enabled = TRUE only when checked columns exist
active_flag           = TRUE
notes                 = Auto-added by sync procedure

These defaults reflect the system’s standard audit policy.

-------------------------------------------------------------------------------
Safety guarantees
-------------------------------------------------------------------------------
• Existing rows are NEVER modified
• Only missing rows are inserted
• No audit behavior is changed for existing tables
• Safe to run repeatedly (idempotent)
• Safe to include in deployment scripts

-------------------------------------------------------------------------------
When to run
-------------------------------------------------------------------------------
Run after any schema change that introduces new application tables:

  • Creating new tables
  • Restoring a database
  • Applying migrations
  • Importing structures from development
  • Suspected policy drift

If the function returns zero rows, the system is already in sync.

-------------------------------------------------------------------------------
Usage
-------------------------------------------------------------------------------
SELECT * FROM ref.sync_audit_collection_policy();

The result shows newly inserted policy rows.

-------------------------------------------------------------------------------
Author
-------------------------------------------------------------------------------
MSB Production Database — Governance Utility
Created: 2026-03-11

===============================================================================
*/';


--
-- TOC entry 966 (class 1255 OID 19299)
-- Name: sync_container_search_helper_to_test_session(); Type: FUNCTION; Schema: ref; Owner: msbadmin
--

CREATE FUNCTION ref.sync_container_search_helper_to_test_session() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
  UPDATE ops.test_session ts
     SET container_search_helper = LEFT(NEW.description, 20)
   WHERE ts.container_id = NEW.container_id;

  RETURN NEW;
END;
$$;


ALTER FUNCTION ref.sync_container_search_helper_to_test_session() OWNER TO msbadmin;

--
-- TOC entry 598 (class 1255 OID 16804)
-- Name: tg_touch_row(); Type: FUNCTION; Schema: ref; Owner: msbadmin
--

CREATE FUNCTION ref.tg_touch_row() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
begin
  new.updated_at := now();
  new.updated_by := current_user;
  return new;
end;
$$;


ALTER FUNCTION ref.tg_touch_row() OWNER TO msbadmin;

--
-- TOC entry 1218 (class 1255 OID 24168)
-- Name: trg_lor_scene_display_require_change(); Type: FUNCTION; Schema: ref; Owner: msbadmin
--

CREATE FUNCTION ref.trg_lor_scene_display_require_change() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    IF NEW.lor_scene_id IS NOT DISTINCT FROM OLD.lor_scene_id
       AND NEW.preview_uuid IS NOT DISTINCT FROM OLD.preview_uuid
       AND NEW.display_id IS NOT DISTINCT FROM OLD.display_id
       AND NEW.scene_prop_ordinal IS NOT DISTINCT FROM OLD.scene_prop_ordinal
       AND NEW.scene_role IS NOT DISTINCT FROM OLD.scene_role
       AND NEW.source IS NOT DISTINCT FROM OLD.source THEN
        RETURN NULL;
    END IF;
    RETURN NEW;
END;
$$;


ALTER FUNCTION ref.trg_lor_scene_display_require_change() OWNER TO msbadmin;

--
-- TOC entry 6193 (class 0 OID 0)
-- Dependencies: 1218
-- Name: FUNCTION trg_lor_scene_display_require_change(); Type: COMMENT; Schema: ref; Owner: msbadmin
--

COMMENT ON FUNCTION ref.trg_lor_scene_display_require_change() IS 'Cancels scene/display membership updates when only provenance or audit fields differ.';


--
-- TOC entry 596 (class 1255 OID 24166)
-- Name: trg_lor_scene_require_change(); Type: FUNCTION; Schema: ref; Owner: msbadmin
--

CREATE FUNCTION ref.trg_lor_scene_require_change() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    IF NEW.preview_uuid IS NOT DISTINCT FROM OLD.preview_uuid
       AND NEW.scene_uuid IS NOT DISTINCT FROM OLD.scene_uuid
       AND NEW.stage_id IS NOT DISTINCT FROM OLD.stage_id
       AND NEW.scene_name IS NOT DISTINCT FROM OLD.scene_name
       AND NEW.scene_section IS NOT DISTINCT FROM OLD.scene_section
       AND NEW.background_file IS NOT DISTINCT FROM OLD.background_file
       AND NEW.h_scroll IS NOT DISTINCT FROM OLD.h_scroll
       AND NEW.v_scroll IS NOT DISTINCT FROM OLD.v_scroll
       AND NEW.zoom IS NOT DISTINCT FROM OLD.zoom
       AND NEW.create_grid_view IS NOT DISTINCT FROM OLD.create_grid_view THEN
        RETURN NULL;
    END IF;
    RETURN NEW;
END;
$$;


ALTER FUNCTION ref.trg_lor_scene_require_change() OWNER TO msbadmin;

--
-- TOC entry 6195 (class 0 OID 0)
-- Dependencies: 596
-- Name: FUNCTION trg_lor_scene_require_change(); Type: COMMENT; Schema: ref; Owner: msbadmin
--

COMMENT ON FUNCTION ref.trg_lor_scene_require_change() IS 'Cancels LOR scene updates when only provenance or audit fields differ.';


--
-- TOC entry 1155 (class 1255 OID 18154)
-- Name: trg_set_updated(); Type: FUNCTION; Schema: ref; Owner: msbadmin
--

CREATE FUNCTION ref.trg_set_updated() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
begin
  new.updated_at := now();
  new.updated_by := current_user;
  return new;
end;
$$;


ALTER FUNCTION ref.trg_set_updated() OWNER TO msbadmin;

--
-- TOC entry 1050 (class 1255 OID 24164)
-- Name: trg_stage_lor_binding_require_change(); Type: FUNCTION; Schema: ref; Owner: msbadmin
--

CREATE FUNCTION ref.trg_stage_lor_binding_require_change() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    IF NEW.stage_id IS NOT DISTINCT FROM OLD.stage_id
       AND NEW.binding_type IS NOT DISTINCT FROM OLD.binding_type
       AND NEW.preview_id IS NOT DISTINCT FROM OLD.preview_id
       AND NEW.scene_id IS NOT DISTINCT FROM OLD.scene_id
       AND NEW.source_name IS NOT DISTINCT FROM OLD.source_name THEN
        RETURN NULL;
    END IF;
    RETURN NEW;
END;
$$;


ALTER FUNCTION ref.trg_stage_lor_binding_require_change() OWNER TO msbadmin;

--
-- TOC entry 6198 (class 0 OID 0)
-- Dependencies: 1050
-- Name: FUNCTION trg_stage_lor_binding_require_change(); Type: COMMENT; Schema: ref; Owner: msbadmin
--

COMMENT ON FUNCTION ref.trg_stage_lor_binding_require_change() IS 'Cancels stage/LOR binding updates when only provenance or audit fields differ.';


--
-- TOC entry 1184 (class 1255 OID 20043)
-- Name: p_process_work_order_intake(bigint); Type: FUNCTION; Schema: stage; Owner: msbadmin
--

CREATE FUNCTION stage.p_process_work_order_intake(p_intake_id bigint) RETURNS TABLE(action_taken text, new_work_order_id bigint, assignee_count integer)
    LANGUAGE plpgsql
    AS $$
DECLARE
    v_woi               stage.work_order_intake%ROWTYPE;
    v_new_work_order_id bigint;
    v_problem           text;
    v_notes             text;
    v_photo_url         text;
    v_triage_notes      text;
BEGIN
    SELECT *
      INTO v_woi
      FROM stage.work_order_intake
     WHERE intake_id = p_intake_id
     FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'WOI % not found', p_intake_id;
    END IF;

    v_woi.triage_dropdown := nullif(btrim(v_woi.triage_dropdown), '');

    v_problem      := nullif(btrim(v_woi.problem_raw), '');
    v_notes        := nullif(btrim(v_woi.notes_raw), '');
    v_photo_url    := nullif(btrim(v_woi.photo_url_raw), '');
    v_triage_notes := nullif(btrim(v_woi.triage_notes), '');

    IF v_woi.triage_dropdown = '1' THEN
        action_taken := 'NO_ACTION_SUBMITTED';
        new_work_order_id := NULL;
        assignee_count := 0;
        RETURN NEXT;
        RETURN;
    END IF;

    IF v_woi.triage_dropdown = '4' THEN
        DELETE FROM stage.work_order_intake
         WHERE intake_id = v_woi.intake_id;

        action_taken := 'DENIED_DELETED';
        new_work_order_id := NULL;
        assignee_count := 0;
        RETURN NEXT;
        RETURN;
    END IF;

    IF v_woi.triage_dropdown = '3' THEN

        IF v_problem IS NULL THEN
            RAISE EXCEPTION 'Cannot promote WOI %: problem statement is required', v_woi.intake_id;
        END IF;

        IF char_length(v_problem) > 255 THEN
            RAISE EXCEPTION 'Cannot promote WOI %: problem statement must be 255 characters or less', v_woi.intake_id;
        END IF;

        IF v_woi.urgency_id IS NULL THEN
            RAISE EXCEPTION 'Cannot promote WOI %: urgency_id is required', v_woi.intake_id;
        END IF;

        IF v_woi.task_type_id IS NULL THEN
            RAISE EXCEPTION 'Cannot promote WOI %: task_type_id is required', v_woi.intake_id;
        END IF;

        IF v_woi.stage_id IS NULL AND v_woi.work_area_id IS NULL THEN
            RAISE EXCEPTION 'Cannot promote WOI %: stage_id or work_area_id is required', v_woi.intake_id;
        END IF;

        INSERT INTO ops.work_order (
            stage_id,
            work_area_id,
            task_type_id,
            urgency_id,
            target_year,
            problem,
            notes,
            photo_url,
            source_intake_id,
            source_system,
            source_form_name,
            submitted_by_person_id,
            submitted_at,
            triaged_at,
            triaged_by_person_id,
            triage_notes,
            created_by_person_id,
            updated_by_person_id,
            created_by,
            updated_by
        )
        VALUES (
            v_woi.stage_id,
            v_woi.work_area_id,
            v_woi.task_type_id,
            v_woi.urgency_id,
            v_woi.target_year,
            v_problem,
            v_notes,
            v_photo_url,
            v_woi.intake_id,
            v_woi.source_system,
            v_woi.source_form_name,
            v_woi.submitter_person_id,
            v_woi.submitted_at,
            v_woi.triaged_at,
            v_woi.triaged_by_person_id,
            v_triage_notes,
            COALESCE(v_woi.updated_by_person_id, v_woi.created_by_person_id),
            COALESCE(v_woi.updated_by_person_id, v_woi.created_by_person_id),
            COALESCE(v_woi.updated_by, v_woi.created_by, current_user),
            COALESCE(v_woi.updated_by, v_woi.created_by, current_user)
        )
        RETURNING work_order_id
          INTO v_new_work_order_id;

        DELETE FROM stage.work_order_intake
         WHERE intake_id = v_woi.intake_id;

        action_taken := 'APPROVED_PROMOTED';
        new_work_order_id := v_new_work_order_id;
        assignee_count := 0;
        RETURN NEXT;
        RETURN;
    END IF;

    RAISE EXCEPTION
        'Cannot process WOI %: unsupported triage_dropdown value = %',
        v_woi.intake_id,
        v_woi.triage_dropdown;
END;
$$;


ALTER FUNCTION stage.p_process_work_order_intake(p_intake_id bigint) OWNER TO msbadmin;

--
-- TOC entry 469 (class 1255 OID 17172)
-- Name: reset_display_sheet(); Type: PROCEDURE; Schema: stage; Owner: msbadmin
--

CREATE PROCEDURE stage.reset_display_sheet()
    LANGUAGE plpgsql
    AS $$/*
reset_display_sheet
*/
begin
  truncate table stage.display_sheet_csv;
  truncate table stage.display_sheet_raw;
end;
$$;


ALTER PROCEDURE stage.reset_display_sheet() OWNER TO msbadmin;

--
-- TOC entry 1258 (class 1255 OID 20086)
-- Name: tf_process_work_order_intake_on_triage(); Type: FUNCTION; Schema: stage; Owner: msbadmin
--

CREATE FUNCTION stage.tf_process_work_order_intake_on_triage() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    IF TG_OP = 'UPDATE'
       AND NEW.triage_dropdown IS DISTINCT FROM OLD.triage_dropdown
       AND NEW.triage_dropdown IS NOT NULL
    THEN
        IF NEW.triage_dropdown = '1' THEN
            RETURN NEW;
        END IF;

        PERFORM *
        FROM stage.p_process_work_order_intake(NEW.intake_id);

        RETURN NULL;
    END IF;

    RETURN NEW;
END;
$$;


ALTER FUNCTION stage.tf_process_work_order_intake_on_triage() OWNER TO msbadmin;

--
-- TOC entry 791 (class 1255 OID 20097)
-- Name: tf_resolve_work_order_intake_submitter(); Type: FUNCTION; Schema: stage; Owner: msbadmin
--

CREATE FUNCTION stage.tf_resolve_work_order_intake_submitter() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE
    v_email_norm text;
    v_person_id  bigint;
BEGIN
    IF NEW.submitter_person_id IS NOT NULL THEN
        RETURN NEW;
    END IF;

    v_email_norm := lower(nullif(btrim(NEW.submitter_email_raw), ''));

    IF v_email_norm IS NOT NULL THEN
        SELECT p.person_id
          INTO v_person_id
          FROM ref.person p
         WHERE lower(nullif(btrim(p.email), '')) = v_email_norm
         ORDER BY p.person_id
         LIMIT 1;

        IF v_person_id IS NOT NULL THEN
            NEW.submitter_person_id := v_person_id;
            RETURN NEW;
        END IF;
    END IF;

    IF NEW.created_by_person_id IS NOT NULL THEN
        NEW.submitter_person_id := NEW.created_by_person_id;
    END IF;

    RETURN NEW;
END;
$$;


ALTER FUNCTION stage.tf_resolve_work_order_intake_submitter() OWNER TO msbadmin;

--
-- TOC entry 1028 (class 1255 OID 17139)
-- Name: transform_display_sheet_csv_to_raw(); Type: PROCEDURE; Schema: stage; Owner: msbadmin
--

CREATE PROCEDURE stage.transform_display_sheet_csv_to_raw()
    LANGUAGE plpgsql
    AS $$/*
transform_display_sheet_scv_to_raw
*/
begin
  truncate table stage.display_sheet_raw;

  insert into stage.display_sheet_raw (
    display_name,
    inventory_type,
    display_status,
    designer_name,
    theme_name,
    frame_name,
    pallet_id_raw,
    year_built,
    amps_measured,
    est_light_count,
    dumb_controller,
    notes
  )
  select
    nullif(btrim(display_name),''),
    nullif(btrim(inventory_type),''),
    nullif(btrim(display_status),''),

    nullif(btrim(designer_id),'') as designer_name,
    nullif(btrim(theme_id),'')    as theme_name,
    nullif(btrim(frame_id),'')    as frame_name,

    nullif(btrim(pallet_id),'')   as pallet_id_raw,

    nullif(regexp_replace(btrim(coalesce(year_built,'')), '[^0-9]', '', 'g'), '')::integer,
    nullif(regexp_replace(btrim(coalesce(amps_measured,'')), '[^0-9\.]', '', 'g'), '')::numeric(8,2),
    nullif(regexp_replace(btrim(coalesce(est_light_count,'')), '[^0-9]', '', 'g'), '')::integer,

    nullif(btrim(dumb_controller),''),
    nullif(btrim(notes),'')
  from stage.display_sheet_csv
  where
    nullif(btrim(display_name),'') is not null
    and upper(coalesce(nullif(btrim(inventory_type),''), 'LOR')) <> 'IGNORE';
end;
$$;


ALTER PROCEDURE stage.transform_display_sheet_csv_to_raw() OWNER TO msbadmin;

SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- TOC entry 284 (class 1259 OID 16821)
-- Name: container; Type: TABLE; Schema: ref; Owner: msbadmin
--

CREATE TABLE ref.container (
    container_id integer NOT NULL,
    location_code text,
    container_type_id integer NOT NULL,
    description text,
    is_stackable_override boolean,
    year_built integer,
    notes text,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    created_by text DEFAULT CURRENT_USER NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_by text DEFAULT CURRENT_USER NOT NULL,
    width_in_override integer,
    depth_in_override integer,
    height_in_override integer,
    goes_to text,
    display_pallet boolean,
    testing_after_takedown boolean,
    display_pallet_flag boolean,
    goes_to_endpoint_id integer,
    created_by_person_id bigint,
    updated_by_person_id bigint,
    label_required boolean DEFAULT true NOT NULL,
    print_label boolean DEFAULT false NOT NULL,
    label_print_count_cached integer DEFAULT 0 NOT NULL,
    label_print_last_at_cached timestamp with time zone,
    label_print_last_by_cached_id integer
);


ALTER TABLE ref.container OWNER TO msbadmin;

--
-- TOC entry 6200 (class 0 OID 0)
-- Dependencies: 284
-- Name: COLUMN container.label_required; Type: COMMENT; Schema: ref; Owner: msbadmin
--

COMMENT ON COLUMN ref.container.label_required IS 'Indicates whether this container represents a physical asset that requires printed labels.';


--
-- TOC entry 6201 (class 0 OID 0)
-- Dependencies: 284
-- Name: COLUMN container.print_label; Type: COMMENT; Schema: ref; Owner: msbadmin
--

COMMENT ON COLUMN ref.container.print_label IS 'Operator action flag. Set true to request label printing. Cleared by print service after confirmed successful print and history write.';


--
-- TOC entry 6202 (class 0 OID 0)
-- Dependencies: 284
-- Name: COLUMN container.label_print_count_cached; Type: COMMENT; Schema: ref; Owner: msbadmin
--

COMMENT ON COLUMN ref.container.label_print_count_cached IS 'System-maintained cached count of labels printed for this container. Derived from label batch history.';


--
-- TOC entry 6203 (class 0 OID 0)
-- Dependencies: 284
-- Name: COLUMN container.label_print_last_at_cached; Type: COMMENT; Schema: ref; Owner: msbadmin
--

COMMENT ON COLUMN ref.container.label_print_last_at_cached IS 'System-maintained cached timestamp of the most recent successful label print for this container.';


--
-- TOC entry 293 (class 1259 OID 17051)
-- Name: display; Type: TABLE; Schema: ref; Owner: msbadmin
--

CREATE TABLE ref.display (
    lor_prop_id text NOT NULL,
    display_name text NOT NULL,
    inventory_type text NOT NULL,
    display_status_id integer NOT NULL,
    designer_id integer,
    theme_id integer,
    frame_id integer,
    container_id integer,
    year_built integer,
    amps_measured numeric(8,2),
    est_light_count integer,
    dumb_controller text,
    notes text,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    created_by text DEFAULT CURRENT_USER NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_by text DEFAULT CURRENT_USER NOT NULL,
    stage_id integer,
    display_id bigint NOT NULL,
    string_type text,
    color text,
    created_by_person_id bigint,
    updated_by_person_id bigint,
    label_required boolean DEFAULT true NOT NULL,
    print_label boolean DEFAULT false NOT NULL,
    label_print_count_cached integer DEFAULT 0 NOT NULL,
    label_print_last_at_cached timestamp with time zone,
    label_print_last_by_cached_id integer
);


ALTER TABLE ref.display OWNER TO msbadmin;

--
-- TOC entry 6218 (class 0 OID 0)
-- Dependencies: 293
-- Name: COLUMN display.label_required; Type: COMMENT; Schema: ref; Owner: msbadmin
--

COMMENT ON COLUMN ref.display.label_required IS 'Indicates whether this display represents a physical asset that requires a printed label.';


--
-- TOC entry 6219 (class 0 OID 0)
-- Dependencies: 293
-- Name: COLUMN display.print_label; Type: COMMENT; Schema: ref; Owner: msbadmin
--

COMMENT ON COLUMN ref.display.print_label IS 'Operator action flag. Set true to request label printing. Cleared by print service after confirmed successful print and history write.';


--
-- TOC entry 6220 (class 0 OID 0)
-- Dependencies: 293
-- Name: COLUMN display.label_print_count_cached; Type: COMMENT; Schema: ref; Owner: msbadmin
--

COMMENT ON COLUMN ref.display.label_print_count_cached IS 'System-maintained cached count of labels printed for this display. Derived from label batch history.';


--
-- TOC entry 6221 (class 0 OID 0)
-- Dependencies: 293
-- Name: COLUMN display.label_print_last_at_cached; Type: COMMENT; Schema: ref; Owner: msbadmin
--

COMMENT ON COLUMN ref.display.label_print_last_at_cached IS 'System-maintained cached timestamp of the most recent successful label print for this display.';


--
-- TOC entry 259 (class 1259 OID 16457)
-- Name: dmx_channels; Type: TABLE; Schema: lor_snap; Owner: msbadmin
--

CREATE TABLE lor_snap.dmx_channels (
    import_run_id bigint NOT NULL,
    int_dmx_channel_id bigint NOT NULL,
    prop_id text,
    network text,
    start_universe integer,
    start_channel integer,
    end_channel integer,
    unknown text,
    preview_id text
);


ALTER TABLE lor_snap.dmx_channels OWNER TO msbadmin;

--
-- TOC entry 255 (class 1259 OID 16391)
-- Name: import_run; Type: TABLE; Schema: lor_snap; Owner: msbadmin
--

CREATE TABLE lor_snap.import_run (
    import_run_id bigint NOT NULL,
    run_ts timestamp with time zone DEFAULT now() NOT NULL,
    notes text,
    parser_version text,
    parser_started_at timestamp with time zone,
    parser_completed_at timestamp with time zone,
    parser_actor text,
    parser_host text,
    source_preview_folder text,
    source_sqlite_path text,
    preview_count integer,
    scene_count integer,
    prop_count integer,
    sub_prop_count integer,
    dmx_channel_count integer,
    scene_lor_prop_count integer,
    ingest_script_version text,
    ingest_actor text,
    ingest_host text,
    ingest_started_at timestamp with time zone,
    ingest_completed_at timestamp with time zone
);


ALTER TABLE lor_snap.import_run OWNER TO msbadmin;

--
-- TOC entry 254 (class 1259 OID 16390)
-- Name: import_run_import_run_id_seq; Type: SEQUENCE; Schema: lor_snap; Owner: msbadmin
--

CREATE SEQUENCE lor_snap.import_run_import_run_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE lor_snap.import_run_import_run_id_seq OWNER TO msbadmin;

--
-- TOC entry 6225 (class 0 OID 0)
-- Dependencies: 254
-- Name: import_run_import_run_id_seq; Type: SEQUENCE OWNED BY; Schema: lor_snap; Owner: msbadmin
--

ALTER SEQUENCE lor_snap.import_run_import_run_id_seq OWNED BY lor_snap.import_run.import_run_id;


--
-- TOC entry 256 (class 1259 OID 16400)
-- Name: previews; Type: TABLE; Schema: lor_snap; Owner: msbadmin
--

CREATE TABLE lor_snap.previews (
    import_run_id bigint NOT NULL,
    int_preview_id bigint NOT NULL,
    id text NOT NULL,
    stage_id text,
    name text,
    revision text,
    brightness double precision,
    background_file text,
    source_filename text
);


ALTER TABLE lor_snap.previews OWNER TO msbadmin;

--
-- TOC entry 6227 (class 0 OID 0)
-- Dependencies: 256
-- Name: COLUMN previews.source_filename; Type: COMMENT; Schema: lor_snap; Owner: msbadmin
--

COMMENT ON COLUMN lor_snap.previews.source_filename IS 'Exact .lorprev filename parsed to produce this preview snapshot row.';


--
-- TOC entry 257 (class 1259 OID 16414)
-- Name: props; Type: TABLE; Schema: lor_snap; Owner: msbadmin
--

CREATE TABLE lor_snap.props (
    import_run_id bigint NOT NULL,
    int_prop_id bigint NOT NULL,
    prop_id text NOT NULL,
    name text,
    lor_comment text,
    device_type text,
    bulb_shape text,
    network text,
    uid text,
    start_channel integer,
    end_channel integer,
    unknown text,
    color text,
    custom_bulb_color text,
    dimming_curve_name text,
    individual_channels boolean,
    legacy_sequence_method text,
    max_channels integer,
    opacity double precision,
    master_dimmable boolean,
    preview_bulb_size double precision,
    master_prop_id text,
    separate_ids boolean,
    start_location text,
    string_type text,
    traditional_colors text,
    traditional_type text,
    effect_bulb_size double precision,
    tag text,
    parm1 text,
    parm2 text,
    parm3 text,
    parm4 text,
    parm5 text,
    parm6 text,
    parm7 text,
    parm8 text,
    lights integer,
    preview_id text,
    raw_prop_id text
);


ALTER TABLE lor_snap.props OWNER TO msbadmin;

--
-- TOC entry 6229 (class 0 OID 0)
-- Dependencies: 257
-- Name: COLUMN props.raw_prop_id; Type: COMMENT; Schema: lor_snap; Owner: msbadmin
--

COMMENT ON COLUMN lor_snap.props.raw_prop_id IS 'Original unscoped LOR PropClass UUID from the rebuilt SQLite snapshot. Not globally unique across previews.';


--
-- TOC entry 258 (class 1259 OID 16433)
-- Name: sub_props; Type: TABLE; Schema: lor_snap; Owner: msbadmin
--

CREATE TABLE lor_snap.sub_props (
    import_run_id bigint NOT NULL,
    int_sub_prop_id bigint NOT NULL,
    sub_prop_id text NOT NULL,
    name text,
    lor_comment text,
    device_type text,
    bulb_shape text,
    network text,
    uid text,
    start_channel integer,
    end_channel integer,
    unknown text,
    color text,
    custom_bulb_color text,
    dimming_curve_name text,
    individual_channels boolean,
    legacy_sequence_method text,
    max_channels integer,
    opacity double precision,
    master_dimmable boolean,
    preview_bulb_size double precision,
    rgb_order text,
    master_prop_id text,
    separate_ids boolean,
    start_location text,
    string_type text,
    traditional_colors text,
    traditional_type text,
    effect_bulb_size double precision,
    tag text,
    parm1 text,
    parm2 text,
    parm3 text,
    parm4 text,
    parm5 text,
    parm6 text,
    parm7 text,
    parm8 text,
    lights integer,
    preview_id text,
    raw_prop_id text
);


ALTER TABLE lor_snap.sub_props OWNER TO msbadmin;

--
-- TOC entry 6231 (class 0 OID 0)
-- Dependencies: 258
-- Name: COLUMN sub_props.raw_prop_id; Type: COMMENT; Schema: lor_snap; Owner: msbadmin
--

COMMENT ON COLUMN lor_snap.sub_props.raw_prop_id IS 'Original unscoped LOR PropClass UUID that produced this materialized subprop row. Not globally unique across previews.';


--
-- TOC entry 260 (class 1259 OID 16479)
-- Name: v_current_run; Type: VIEW; Schema: lor_snap; Owner: msbadmin
--

CREATE VIEW lor_snap.v_current_run AS
 SELECT import_run_id,
    run_ts,
    notes,
    parser_version,
    parser_started_at,
    parser_completed_at,
    parser_actor,
    parser_host,
    source_preview_folder,
    source_sqlite_path,
    preview_count,
    scene_count,
    prop_count,
    sub_prop_count,
    dmx_channel_count,
    scene_lor_prop_count,
    ingest_script_version,
    ingest_actor,
    ingest_host,
    ingest_started_at,
    ingest_completed_at
   FROM lor_snap.import_run ir
  ORDER BY import_run_id DESC
 LIMIT 1;


ALTER VIEW lor_snap.v_current_run OWNER TO msbadmin;

--
-- TOC entry 6233 (class 0 OID 0)
-- Dependencies: 260
-- Name: VIEW v_current_run; Type: COMMENT; Schema: lor_snap; Owner: msbadmin
--

COMMENT ON VIEW lor_snap.v_current_run IS 'Latest imported LOR snapshot run with parser, source-folder, ingest, and row-count provenance. Historical nullable provenance remains NULL.';


--
-- TOC entry 264 (class 1259 OID 16497)
-- Name: v_current_dmx_channels; Type: VIEW; Schema: lor_snap; Owner: msbadmin
--

CREATE VIEW lor_snap.v_current_dmx_channels AS
 SELECT dc.import_run_id,
    dc.int_dmx_channel_id,
    dc.prop_id,
    dc.network,
    dc.start_universe,
    dc.start_channel,
    dc.end_channel,
    dc.unknown,
    dc.preview_id
   FROM (lor_snap.dmx_channels dc
     JOIN lor_snap.v_current_run r ON ((r.import_run_id = dc.import_run_id)));


ALTER VIEW lor_snap.v_current_dmx_channels OWNER TO msbadmin;

--
-- TOC entry 261 (class 1259 OID 16483)
-- Name: v_current_previews; Type: VIEW; Schema: lor_snap; Owner: msbadmin
--

CREATE VIEW lor_snap.v_current_previews AS
 SELECT p.import_run_id,
    p.int_preview_id,
    p.id,
    p.stage_id,
    p.name,
    p.revision,
    p.brightness,
    p.background_file,
    p.source_filename
   FROM (lor_snap.previews p
     JOIN lor_snap.v_current_run r ON ((r.import_run_id = p.import_run_id)));


ALTER VIEW lor_snap.v_current_previews OWNER TO msbadmin;

--
-- TOC entry 6236 (class 0 OID 0)
-- Dependencies: 261
-- Name: VIEW v_current_previews; Type: COMMENT; Schema: lor_snap; Owner: msbadmin
--

COMMENT ON VIEW lor_snap.v_current_previews IS 'Preview rows belonging to the latest imported LOR snapshot, including the exact parsed .lorprev source filename.';


--
-- TOC entry 262 (class 1259 OID 16487)
-- Name: v_current_props; Type: VIEW; Schema: lor_snap; Owner: msbadmin
--

CREATE VIEW lor_snap.v_current_props AS
 SELECT p.import_run_id,
    p.int_prop_id,
    p.prop_id,
    p.name,
    p.lor_comment,
    p.device_type,
    p.bulb_shape,
    p.network,
    p.uid,
    p.start_channel,
    p.end_channel,
    p.unknown,
    p.color,
    p.custom_bulb_color,
    p.dimming_curve_name,
    p.individual_channels,
    p.legacy_sequence_method,
    p.max_channels,
    p.opacity,
    p.master_dimmable,
    p.preview_bulb_size,
    p.master_prop_id,
    p.separate_ids,
    p.start_location,
    p.string_type,
    p.traditional_colors,
    p.traditional_type,
    p.effect_bulb_size,
    p.tag,
    p.parm1,
    p.parm2,
    p.parm3,
    p.parm4,
    p.parm5,
    p.parm6,
    p.parm7,
    p.parm8,
    p.lights,
    p.preview_id,
    p.raw_prop_id
   FROM (lor_snap.props p
     JOIN lor_snap.v_current_run r ON ((r.import_run_id = p.import_run_id)));


ALTER VIEW lor_snap.v_current_props OWNER TO msbadmin;

--
-- TOC entry 6238 (class 0 OID 0)
-- Dependencies: 262
-- Name: VIEW v_current_props; Type: COMMENT; Schema: lor_snap; Owner: msbadmin
--

COMMENT ON VIEW lor_snap.v_current_props IS 'Latest completed prop snapshot, including scoped prop_id and original unscoped raw_prop_id.';


--
-- TOC entry 263 (class 1259 OID 16492)
-- Name: v_current_sub_props; Type: VIEW; Schema: lor_snap; Owner: msbadmin
--

CREATE VIEW lor_snap.v_current_sub_props AS
 SELECT sp.import_run_id,
    sp.int_sub_prop_id,
    sp.sub_prop_id,
    sp.name,
    sp.lor_comment,
    sp.device_type,
    sp.bulb_shape,
    sp.network,
    sp.uid,
    sp.start_channel,
    sp.end_channel,
    sp.unknown,
    sp.color,
    sp.custom_bulb_color,
    sp.dimming_curve_name,
    sp.individual_channels,
    sp.legacy_sequence_method,
    sp.max_channels,
    sp.opacity,
    sp.master_dimmable,
    sp.preview_bulb_size,
    sp.rgb_order,
    sp.master_prop_id,
    sp.separate_ids,
    sp.start_location,
    sp.string_type,
    sp.traditional_colors,
    sp.traditional_type,
    sp.effect_bulb_size,
    sp.tag,
    sp.parm1,
    sp.parm2,
    sp.parm3,
    sp.parm4,
    sp.parm5,
    sp.parm6,
    sp.parm7,
    sp.parm8,
    sp.lights,
    sp.preview_id,
    sp.raw_prop_id
   FROM (lor_snap.sub_props sp
     JOIN lor_snap.v_current_run r ON ((r.import_run_id = sp.import_run_id)));


ALTER VIEW lor_snap.v_current_sub_props OWNER TO msbadmin;

--
-- TOC entry 6240 (class 0 OID 0)
-- Dependencies: 263
-- Name: VIEW v_current_sub_props; Type: COMMENT; Schema: lor_snap; Owner: msbadmin
--

COMMENT ON VIEW lor_snap.v_current_sub_props IS 'Latest completed subprop snapshot, including scoped sub_prop_id and original unscoped raw_prop_id.';


--
-- TOC entry 265 (class 1259 OID 16509)
-- Name: preview_wiring_map_v6; Type: VIEW; Schema: lor_snap; Owner: msbadmin
--

CREATE VIEW lor_snap.preview_wiring_map_v6 AS
 SELECT pv.name AS preview_name,
    replace(btrim(p.lor_comment), ' '::text, '-'::text) AS display_name,
    p.name AS lor_name,
    p.network,
    p.uid AS controller,
    p.start_channel,
    p.end_channel,
    p.device_type,
    'PROP'::text AS source,
    p.tag AS lor_tag
   FROM (lor_snap.v_current_props p
     JOIN lor_snap.v_current_previews pv ON ((pv.id = p.preview_id)))
  WHERE ((p.network IS NOT NULL) AND (p.start_channel IS NOT NULL))
UNION ALL
 SELECT pv.name AS preview_name,
    replace(btrim(COALESCE(NULLIF(sp.lor_comment, ''::text), p.lor_comment)), ' '::text, '-'::text) AS display_name,
    sp.name AS lor_name,
    sp.network,
    sp.uid AS controller,
    sp.start_channel,
    sp.end_channel,
    COALESCE(sp.device_type, 'LOR'::text) AS device_type,
    'SUBPROP'::text AS source,
    sp.tag AS lor_tag
   FROM ((lor_snap.v_current_sub_props sp
     JOIN lor_snap.v_current_props p ON ((p.prop_id = sp.master_prop_id)))
     JOIN lor_snap.v_current_previews pv ON ((pv.id = sp.preview_id)))
UNION ALL
 SELECT pv.name AS preview_name,
    replace(btrim(p.lor_comment), ' '::text, '-'::text) AS display_name,
    p.name AS lor_name,
    dc.network,
    (dc.start_universe)::text AS controller,
    dc.start_channel,
    dc.end_channel,
    'DMX'::text AS device_type,
    'DMX'::text AS source,
    p.tag AS lor_tag
   FROM ((lor_snap.v_current_dmx_channels dc
     JOIN lor_snap.v_current_props p ON ((p.prop_id = dc.prop_id)))
     JOIN lor_snap.v_current_previews pv ON ((pv.id = p.preview_id)));


ALTER VIEW lor_snap.preview_wiring_map_v6 OWNER TO msbadmin;

--
-- TOC entry 266 (class 1259 OID 16514)
-- Name: preview_wiring_sorted_v6; Type: VIEW; Schema: lor_snap; Owner: msbadmin
--

CREATE VIEW lor_snap.preview_wiring_sorted_v6 AS
 SELECT preview_name,
    display_name,
    lor_name,
    network,
    controller,
    start_channel,
    end_channel,
    device_type,
    source,
    lor_tag
   FROM lor_snap.preview_wiring_map_v6
  ORDER BY (lower(preview_name)), (lower(display_name)), controller, start_channel;


ALTER VIEW lor_snap.preview_wiring_sorted_v6 OWNER TO msbadmin;

--
-- TOC entry 267 (class 1259 OID 16518)
-- Name: preview_wiring_fieldmap_v6; Type: VIEW; Schema: lor_snap; Owner: msbadmin
--

CREATE VIEW lor_snap.preview_wiring_fieldmap_v6 AS
 WITH map AS (
         SELECT m.preview_name,
            m.source,
            m.lor_name AS channel_name,
            m.display_name,
            m.network,
            m.controller,
            m.start_channel,
            m.end_channel,
                CASE
                    WHEN (m.device_type = 'DMX'::text) THEN 'RGB'::text
                    ELSE NULL::text
                END AS color,
            m.device_type,
            m.lor_tag
           FROM lor_snap.preview_wiring_sorted_v6 m
          WHERE ((m.controller IS NOT NULL) AND (m.start_channel IS NOT NULL) AND (m.device_type <> 'None'::text))
        ), ranked AS (
         SELECT map.preview_name,
            map.source,
            map.channel_name,
            map.display_name,
            map.network,
            map.controller,
            map.start_channel,
            map.end_channel,
            map.color,
            map.device_type,
            map.lor_tag,
            row_number() OVER (PARTITION BY map.preview_name, map.network, map.controller, map.start_channel, map.display_name ORDER BY (map.source = 'PROP'::text) DESC, (lower(map.channel_name))) AS lead_rank
           FROM map
        ), span AS (
         SELECT ranked.preview_name,
            ranked.source,
            ranked.channel_name,
            ranked.display_name,
            ranked.network,
            ranked.controller,
            ranked.start_channel,
            ranked.end_channel,
            ranked.color,
            ranked.device_type,
            ranked.lor_tag,
            ranked.lead_rank,
            sum(
                CASE
                    WHEN (ranked.lead_rank = 1) THEN 1
                    ELSE 0
                END) OVER (PARTITION BY ranked.preview_name, ranked.network, ranked.controller, ranked.start_channel) AS display_span
           FROM ranked
        )
 SELECT preview_name,
    source,
    channel_name,
    display_name,
    network,
    controller,
    start_channel,
    end_channel,
    color,
    device_type,
    lor_tag,
        CASE
            WHEN (lead_rank = 1) THEN 'FIELD'::text
            ELSE 'INTERNAL'::text
        END AS connection_type,
        CASE
            WHEN (display_span > 1) THEN 1
            ELSE 0
        END AS cross_display
   FROM span;


ALTER VIEW lor_snap.preview_wiring_fieldmap_v6 OWNER TO msbadmin;

--
-- TOC entry 268 (class 1259 OID 16523)
-- Name: preview_wiring_fieldlead_v6; Type: VIEW; Schema: lor_snap; Owner: msbadmin
--

CREATE VIEW lor_snap.preview_wiring_fieldlead_v6 AS
 WITH ranked AS (
         SELECT f.preview_name,
            f.source,
            f.channel_name,
            f.display_name,
            f.network,
            f.controller,
            f.start_channel,
            f.end_channel,
            f.color,
            f.device_type,
            f.lor_tag,
            f.connection_type,
            f.cross_display,
            row_number() OVER (PARTITION BY f.preview_name, f.network, f.controller, f.start_channel, f.display_name ORDER BY (f.source = 'PROP'::text) DESC, (lower(f.channel_name))) AS lead_rank
           FROM lor_snap.preview_wiring_fieldmap_v6 f
        )
 SELECT preview_name,
    source,
    channel_name,
    display_name,
    network,
    controller,
    start_channel,
    end_channel,
    color,
    device_type,
    lor_tag,
    connection_type,
    cross_display,
    lead_rank
   FROM ranked
  WHERE (lead_rank = 1);


ALTER VIEW lor_snap.preview_wiring_fieldlead_v6 OWNER TO msbadmin;

--
-- TOC entry 269 (class 1259 OID 16528)
-- Name: preview_wiring_circuit_rollup_v6; Type: VIEW; Schema: lor_snap; Owner: msbadmin
--

CREATE VIEW lor_snap.preview_wiring_circuit_rollup_v6 AS
 SELECT preview_name,
    network,
    controller,
    start_channel,
    count(*) AS display_count,
    string_agg(display_name, ' | '::text ORDER BY (lower(display_name))) AS displays
   FROM lor_snap.preview_wiring_fieldlead_v6
  GROUP BY preview_name, network, controller, start_channel
  ORDER BY network,
        CASE
            WHEN (controller ~* '^[0-9a-f]+$'::text) THEN ((('x'::text || controller))::bit(32))::integer
            ELSE NULL::integer
        END, controller, start_channel;


ALTER VIEW lor_snap.preview_wiring_circuit_rollup_v6 OWNER TO msbadmin;

--
-- TOC entry 270 (class 1259 OID 16532)
-- Name: preview_wiring_fieldonly_v6; Type: VIEW; Schema: lor_snap; Owner: msbadmin
--

CREATE VIEW lor_snap.preview_wiring_fieldonly_v6 AS
 SELECT preview_name,
    source,
    channel_name,
    display_name,
    network,
    controller,
    start_channel,
    end_channel,
    color,
    device_type,
    lor_tag,
    connection_type,
    cross_display
   FROM lor_snap.preview_wiring_fieldmap_v6
  WHERE (connection_type = 'FIELD'::text);


ALTER VIEW lor_snap.preview_wiring_fieldonly_v6 OWNER TO msbadmin;

--
-- TOC entry 418 (class 1259 OID 23021)
-- Name: scene_lor_props; Type: TABLE; Schema: lor_snap; Owner: msbadmin
--

CREATE TABLE lor_snap.scene_lor_props (
    import_run_id integer NOT NULL,
    int_scene_prop_id integer,
    preview_id text NOT NULL,
    prop_id text NOT NULL,
    raw_prop_id text NOT NULL,
    scene_id text,
    preview_stage_id text,
    scene_stage_id text,
    scene_prop_ordinal integer,
    scene_role text,
    source text
);


ALTER TABLE lor_snap.scene_lor_props OWNER TO msbadmin;

--
-- TOC entry 417 (class 1259 OID 23011)
-- Name: scenes; Type: TABLE; Schema: lor_snap; Owner: msbadmin
--

CREATE TABLE lor_snap.scenes (
    import_run_id integer NOT NULL,
    int_scene_id integer,
    scene_id text,
    preview_id text,
    stage_id text,
    name text,
    scene_section text,
    background_file text,
    h_scroll integer,
    v_scroll integer,
    zoom integer,
    create_grid_view text
);


ALTER TABLE lor_snap.scenes OWNER TO msbadmin;

--
-- TOC entry 271 (class 1259 OID 16548)
-- Name: stage_display_assets_v1; Type: VIEW; Schema: lor_snap; Owner: msbadmin
--

CREATE VIEW lor_snap.stage_display_assets_v1 AS
 SELECT pv.stage_id,
    pv.name AS preview_name,
    p.lor_comment AS display_name,
    p.name AS channel_name,
    COALESCE(p.device_type, 'LOR'::text) AS device_type,
    p.network,
    p.uid,
    p.start_channel,
    p.end_channel,
    1 AS has_wiring,
    'PROP'::text AS source
   FROM (lor_snap.v_current_props p
     JOIN lor_snap.v_current_previews pv ON ((pv.id = p.preview_id)))
  WHERE ((p.network IS NOT NULL) AND (p.start_channel IS NOT NULL))
UNION ALL
 SELECT pv.stage_id,
    pv.name AS preview_name,
    COALESCE(NULLIF(sp.lor_comment, ''::text), p.lor_comment) AS display_name,
    sp.name AS channel_name,
    COALESCE(sp.device_type, 'LOR'::text) AS device_type,
    sp.network,
    sp.uid,
    sp.start_channel,
    sp.end_channel,
    1 AS has_wiring,
    'SUBPROP'::text AS source
   FROM ((lor_snap.v_current_sub_props sp
     JOIN lor_snap.v_current_props p ON ((p.prop_id = sp.master_prop_id)))
     JOIN lor_snap.v_current_previews pv ON ((pv.id = sp.preview_id)))
  WHERE ((sp.network IS NOT NULL) AND (sp.start_channel IS NOT NULL))
UNION ALL
 SELECT pv.stage_id,
    pv.name AS preview_name,
    p.lor_comment AS display_name,
    p.name AS channel_name,
    'DMX'::text AS device_type,
    dc.network,
    (dc.start_universe)::text AS uid,
    dc.start_channel,
    dc.end_channel,
    1 AS has_wiring,
    'DMX'::text AS source
   FROM ((lor_snap.v_current_dmx_channels dc
     JOIN lor_snap.v_current_props p ON ((p.prop_id = dc.prop_id)))
     JOIN lor_snap.v_current_previews pv ON ((pv.id = p.preview_id)));


ALTER VIEW lor_snap.stage_display_assets_v1 OWNER TO msbadmin;

--
-- TOC entry 272 (class 1259 OID 16553)
-- Name: stage_display_inventory_only_v1; Type: VIEW; Schema: lor_snap; Owner: msbadmin
--

CREATE VIEW lor_snap.stage_display_inventory_only_v1 AS
 SELECT DISTINCT pv.stage_id,
    pv.name AS preview_name,
    p.lor_comment AS display_name,
    NULL::text AS channel_name,
    COALESCE(p.device_type, 'INV'::text) AS device_type,
    NULL::text AS network,
    NULL::text AS uid,
    NULL::integer AS start_channel,
    NULL::integer AS end_channel,
    0 AS has_wiring,
    'PROP_INV'::text AS source
   FROM (lor_snap.v_current_props p
     JOIN lor_snap.v_current_previews pv ON ((pv.id = p.preview_id)))
  WHERE (((p.network IS NULL) OR (p.start_channel IS NULL)) AND (btrim(COALESCE(p.lor_comment, ''::text)) <> ''::text))
UNION
 SELECT DISTINCT pv.stage_id,
    pv.name AS preview_name,
    COALESCE(NULLIF(sp.lor_comment, ''::text), p.lor_comment) AS display_name,
    NULL::text AS channel_name,
    COALESCE(sp.device_type, 'INV'::text) AS device_type,
    NULL::text AS network,
    NULL::text AS uid,
    NULL::integer AS start_channel,
    NULL::integer AS end_channel,
    0 AS has_wiring,
    'SUBPROP_INV'::text AS source
   FROM ((lor_snap.v_current_sub_props sp
     JOIN lor_snap.v_current_props p ON ((p.prop_id = sp.master_prop_id)))
     JOIN lor_snap.v_current_previews pv ON ((pv.id = sp.preview_id)))
  WHERE (((sp.network IS NULL) OR (sp.start_channel IS NULL)) AND (btrim(COALESCE(COALESCE(NULLIF(sp.lor_comment, ''::text), p.lor_comment), ''::text)) <> ''::text));


ALTER VIEW lor_snap.stage_display_inventory_only_v1 OWNER TO msbadmin;

--
-- TOC entry 273 (class 1259 OID 16558)
-- Name: stage_display_assets_all_v1; Type: VIEW; Schema: lor_snap; Owner: msbadmin
--

CREATE VIEW lor_snap.stage_display_assets_all_v1 AS
 SELECT stage_display_assets_v1.stage_id,
    stage_display_assets_v1.preview_name,
    stage_display_assets_v1.display_name,
    stage_display_assets_v1.channel_name,
    stage_display_assets_v1.device_type,
    stage_display_assets_v1.network,
    stage_display_assets_v1.uid,
    stage_display_assets_v1.start_channel,
    stage_display_assets_v1.end_channel,
    stage_display_assets_v1.has_wiring,
    stage_display_assets_v1.source
   FROM lor_snap.stage_display_assets_v1
UNION ALL
 SELECT stage_display_inventory_only_v1.stage_id,
    stage_display_inventory_only_v1.preview_name,
    stage_display_inventory_only_v1.display_name,
    stage_display_inventory_only_v1.channel_name,
    stage_display_inventory_only_v1.device_type,
    stage_display_inventory_only_v1.network,
    stage_display_inventory_only_v1.uid,
    stage_display_inventory_only_v1.start_channel,
    stage_display_inventory_only_v1.end_channel,
    stage_display_inventory_only_v1.has_wiring,
    stage_display_inventory_only_v1.source
   FROM lor_snap.stage_display_inventory_only_v1;


ALTER VIEW lor_snap.stage_display_assets_all_v1 OWNER TO msbadmin;

--
-- TOC entry 274 (class 1259 OID 16563)
-- Name: stage_display_list_all_v1; Type: VIEW; Schema: lor_snap; Owner: msbadmin
--

CREATE VIEW lor_snap.stage_display_list_all_v1 AS
 WITH base AS (
         SELECT COALESCE(stage_display_assets_all_v1.stage_id, 'Unassigned'::text) AS stage_bucket,
            stage_display_assets_all_v1.preview_name,
            btrim(stage_display_assets_all_v1.display_name) AS display_name,
            stage_display_assets_all_v1.has_wiring
           FROM lor_snap.stage_display_assets_all_v1
          WHERE (btrim(COALESCE(stage_display_assets_all_v1.display_name, ''::text)) <> ''::text)
        ), labeled AS (
         SELECT base.stage_bucket,
            ((base.stage_bucket || ' — '::text) || base.preview_name) AS stage_preview_label,
            base.display_name,
            base.has_wiring
           FROM base
        ), aggregated AS (
         SELECT labeled.stage_bucket,
            labeled.stage_preview_label,
            labeled.display_name,
            max(labeled.has_wiring) AS has_wiring
           FROM labeled
          GROUP BY labeled.stage_bucket, labeled.stage_preview_label, labeled.display_name
        )
 SELECT stage_bucket,
    stage_preview_label,
    display_name,
    has_wiring
   FROM aggregated
  ORDER BY
        CASE
            WHEN (stage_bucket = 'Unassigned'::text) THEN 1
            ELSE 0
        END, (length(stage_bucket)), stage_bucket,
        CASE
            WHEN (stage_preview_label ~~ '%Show Background Stage%'::text) THEN 0
            ELSE 1
        END,
        CASE
            WHEN (stage_preview_label ~~ '%RGB Plus Prop Stage%'::text) THEN 0
            ELSE 1
        END, (lower(stage_preview_label)), (lower(display_name));


ALTER VIEW lor_snap.stage_display_list_all_v1 OWNER TO msbadmin;

--
-- TOC entry 275 (class 1259 OID 16568)
-- Name: stage_display_unassigned_v1; Type: VIEW; Schema: lor_snap; Owner: msbadmin
--

CREATE VIEW lor_snap.stage_display_unassigned_v1 AS
 SELECT display_name
   FROM lor_snap.stage_display_list_all_v1
  WHERE (stage_bucket = 'Unassigned'::text);


ALTER VIEW lor_snap.stage_display_unassigned_v1 OWNER TO msbadmin;

--
-- TOC entry 420 (class 1259 OID 23042)
-- Name: v_current_scene_lor_props; Type: VIEW; Schema: lor_snap; Owner: msbadmin
--

CREATE VIEW lor_snap.v_current_scene_lor_props AS
 SELECT import_run_id,
    int_scene_prop_id,
    preview_id,
    prop_id,
    raw_prop_id,
    scene_id,
    preview_stage_id,
    scene_stage_id,
    scene_prop_ordinal,
    scene_role,
    source
   FROM lor_snap.scene_lor_props slp
  WHERE (import_run_id = ( SELECT max(import_run.import_run_id) AS max
           FROM lor_snap.import_run));


ALTER VIEW lor_snap.v_current_scene_lor_props OWNER TO msbadmin;

--
-- TOC entry 419 (class 1259 OID 23038)
-- Name: v_current_scenes; Type: VIEW; Schema: lor_snap; Owner: msbadmin
--

CREATE VIEW lor_snap.v_current_scenes AS
 SELECT import_run_id,
    int_scene_id,
    scene_id,
    preview_id,
    stage_id,
    name,
    scene_section,
    background_file,
    h_scroll,
    v_scroll,
    zoom,
    create_grid_view
   FROM lor_snap.scenes s
  WHERE (import_run_id = ( SELECT max(import_run.import_run_id) AS max
           FROM lor_snap.import_run));


ALTER VIEW lor_snap.v_current_scenes OWNER TO msbadmin;

--
-- TOC entry 422 (class 1259 OID 23103)
-- Name: v_display_lor_occurrence; Type: VIEW; Schema: lor_snap; Owner: msbadmin
--

CREATE VIEW lor_snap.v_display_lor_occurrence AS
 WITH preview_occurrence AS (
         SELECT p.import_run_id,
            p.raw_prop_id AS lor_prop_id,
            btrim(p.lor_comment) AS display_name,
            upper(btrim(p.lor_comment)) AS display_name_normalized,
            p.preview_id,
            pr.name AS preview_name,
            pr.stage_id AS preview_stage_id,
            NULL::text AS scene_id,
            NULL::text AS scene_name,
            NULL::text AS scene_stage_id,
            'PREVIEW'::text AS location_type
           FROM (lor_snap.props p
             JOIN lor_snap.previews pr ON (((pr.import_run_id = p.import_run_id) AND (pr.id = p.preview_id))))
          WHERE (NULLIF(btrim(p.lor_comment), ''::text) IS NOT NULL)
        ), scene_occurrence AS (
         SELECT (slp.import_run_id)::bigint AS import_run_id,
            slp.raw_prop_id AS lor_prop_id,
            btrim(p.lor_comment) AS display_name,
            upper(btrim(p.lor_comment)) AS display_name_normalized,
            slp.preview_id,
            pr.name AS preview_name,
            pr.stage_id AS preview_stage_id,
            slp.scene_id,
            sc.name AS scene_name,
            COALESCE(slp.scene_stage_id, sc.stage_id) AS scene_stage_id,
            'SCENE'::text AS location_type
           FROM (((lor_snap.scene_lor_props slp
             JOIN lor_snap.props p ON (((p.import_run_id = (slp.import_run_id)::bigint) AND (p.prop_id = slp.prop_id) AND (p.raw_prop_id = slp.raw_prop_id))))
             JOIN lor_snap.previews pr ON (((pr.import_run_id = (slp.import_run_id)::bigint) AND (pr.id = slp.preview_id))))
             LEFT JOIN lor_snap.scenes sc ON (((sc.import_run_id = slp.import_run_id) AND (sc.preview_id = slp.preview_id) AND (sc.scene_id = slp.scene_id))))
          WHERE (NULLIF(btrim(p.lor_comment), ''::text) IS NOT NULL)
        )
 SELECT preview_occurrence.import_run_id,
    preview_occurrence.lor_prop_id,
    preview_occurrence.display_name,
    preview_occurrence.display_name_normalized,
    preview_occurrence.preview_id,
    preview_occurrence.preview_name,
    preview_occurrence.preview_stage_id,
    preview_occurrence.scene_id,
    preview_occurrence.scene_name,
    preview_occurrence.scene_stage_id,
    preview_occurrence.location_type
   FROM preview_occurrence
UNION ALL
 SELECT scene_occurrence.import_run_id,
    scene_occurrence.lor_prop_id,
    scene_occurrence.display_name,
    scene_occurrence.display_name_normalized,
    scene_occurrence.preview_id,
    scene_occurrence.preview_name,
    scene_occurrence.preview_stage_id,
    scene_occurrence.scene_id,
    scene_occurrence.scene_name,
    scene_occurrence.scene_stage_id,
    scene_occurrence.location_type
   FROM scene_occurrence;


ALTER VIEW lor_snap.v_display_lor_occurrence OWNER TO msbadmin;

--
-- TOC entry 6257 (class 0 OID 0)
-- Dependencies: 422
-- Name: VIEW v_display_lor_occurrence; Type: COMMENT; Schema: lor_snap; Owner: msbadmin
--

COMMENT ON VIEW lor_snap.v_display_lor_occurrence IS 'Run-aware evidence of every preview and scene containing an LOR prop. Scene membership is location evidence, not physical-display identity authority.';


--
-- TOC entry 421 (class 1259 OID 23098)
-- Name: v_display_reconciliation_source; Type: VIEW; Schema: lor_snap; Owner: msbadmin
--

CREATE VIEW lor_snap.v_display_reconciliation_source AS
 WITH background_rows AS (
         SELECT p.import_run_id,
            p.preview_id,
            p.prop_id AS source_prop_id,
            btrim(pr.stage_id) AS preview_stage_id,
            pr.name AS preview_name,
            p.raw_prop_id AS lor_prop_id,
            p.name AS prop_name,
            p.lor_comment AS prop_comment,
            btrim(p.lor_comment) AS display_name,
            upper(btrim(p.lor_comment)) AS display_name_normalized,
            p.string_type,
            p.color,
            ((p.lor_comment ~~* '%spare%'::text) OR (COALESCE(p.name, ''::text) ~~* '%spare%'::text) OR (COALESCE(p.lor_comment, ''::text) ~~* '%spare%'::text)) AS is_spare,
            (p.lor_comment ~~* '%phantom%'::text) AS is_phantom
           FROM (lor_snap.props p
             JOIN lor_snap.previews pr ON (((pr.import_run_id = p.import_run_id) AND (pr.id = p.preview_id))))
          WHERE ((pr.stage_id IS NOT NULL) AND (btrim(pr.stage_id) <> ''::text) AND (NULLIF(btrim(p.lor_comment), ''::text) IS NOT NULL) AND (lower(btrim(pr.stage_id)) ~ '^0*[0-9]{1,2}[a-z]?$'::text))
        ), scene_rows AS (
         SELECT slp.import_run_id,
            slp.preview_id,
            p.prop_id AS source_prop_id,
            btrim(COALESCE(slp.scene_stage_id, sc.stage_id)) AS preview_stage_id,
            pr.name AS preview_name,
            slp.raw_prop_id AS lor_prop_id,
            p.name AS prop_name,
            p.lor_comment AS prop_comment,
            btrim(p.lor_comment) AS display_name,
            upper(btrim(p.lor_comment)) AS display_name_normalized,
            p.string_type,
            p.color,
            ((p.lor_comment ~~* '%spare%'::text) OR (COALESCE(p.name, ''::text) ~~* '%spare%'::text) OR (COALESCE(p.lor_comment, ''::text) ~~* '%spare%'::text)) AS is_spare,
            (p.lor_comment ~~* '%phantom%'::text) AS is_phantom
           FROM (((lor_snap.scene_lor_props slp
             JOIN lor_snap.props p ON (((p.import_run_id = slp.import_run_id) AND (p.prop_id = slp.prop_id) AND (p.raw_prop_id = slp.raw_prop_id))))
             JOIN lor_snap.previews pr ON (((pr.import_run_id = slp.import_run_id) AND (pr.id = slp.preview_id))))
             LEFT JOIN lor_snap.scenes sc ON (((sc.import_run_id = slp.import_run_id) AND (sc.preview_id = slp.preview_id) AND (sc.scene_id = slp.scene_id))))
          WHERE ((COALESCE(slp.scene_stage_id, sc.stage_id) IS NOT NULL) AND (btrim(COALESCE(slp.scene_stage_id, sc.stage_id)) <> ''::text) AND (NULLIF(btrim(p.lor_comment), ''::text) IS NOT NULL) AND (lower(btrim(COALESCE(slp.scene_stage_id, sc.stage_id))) ~ '^0*[0-9]{1,2}[a-z]?$'::text) AND (pr.name ~~* '%Master Musical Preview%'::text))
        ), combined_rows AS (
         SELECT br.import_run_id,
            br.preview_id,
            br.source_prop_id,
            br.preview_stage_id,
            br.preview_name,
            br.lor_prop_id,
            br.prop_name,
            br.prop_comment,
            br.display_name,
            br.display_name_normalized,
            br.string_type,
            br.color,
            br.is_spare,
            br.is_phantom,
            1 AS source_preference
           FROM background_rows br
        UNION ALL
         SELECT sr_1.import_run_id,
            sr_1.preview_id,
            sr_1.source_prop_id,
            sr_1.preview_stage_id,
            sr_1.preview_name,
            sr_1.lor_prop_id,
            sr_1.prop_name,
            sr_1.prop_comment,
            sr_1.display_name,
            sr_1.display_name_normalized,
            sr_1.string_type,
            sr_1.color,
            sr_1.is_spare,
            sr_1.is_phantom,
            2 AS source_preference
           FROM scene_rows sr_1
        ), source_rows AS (
         SELECT DISTINCT ON (cr.import_run_id, cr.display_name_normalized, cr.lor_prop_id) cr.import_run_id,
            cr.preview_id,
            cr.source_prop_id,
            cr.preview_stage_id,
            cr.preview_name,
            cr.lor_prop_id,
            cr.prop_name,
            cr.prop_comment,
            cr.display_name,
            cr.display_name_normalized,
            cr.string_type,
            cr.color,
            cr.is_spare,
            cr.is_phantom
           FROM combined_rows cr
          ORDER BY cr.import_run_id, cr.display_name_normalized, cr.lor_prop_id, cr.source_preference, cr.preview_name, cr.preview_id
        ), uuid_counts AS (
         SELECT source_rows.import_run_id,
            source_rows.lor_prop_id,
            (count(*))::integer AS lor_uuid_row_count,
            (count(DISTINCT source_rows.display_name_normalized))::integer AS lor_uuid_name_count
           FROM source_rows
          GROUP BY source_rows.import_run_id, source_rows.lor_prop_id
        ), name_counts AS (
         SELECT source_rows.import_run_id,
            source_rows.display_name_normalized,
            (count(DISTINCT source_rows.lor_prop_id))::integer AS lor_name_uuid_count
           FROM source_rows
          GROUP BY source_rows.import_run_id, source_rows.display_name_normalized
        )
 SELECT sr.import_run_id,
    sr.preview_id,
    sr.preview_stage_id,
    sr.preview_name,
    sr.lor_prop_id,
    sr.prop_name,
    sr.prop_comment,
    sr.display_name,
    sr.display_name_normalized,
    sr.string_type,
    sr.color,
    sr.is_spare,
    sr.is_phantom,
    uc.lor_uuid_row_count,
    uc.lor_uuid_name_count,
    nc.lor_name_uuid_count,
    sr.source_prop_id
   FROM ((source_rows sr
     JOIN uuid_counts uc ON (((uc.import_run_id = sr.import_run_id) AND (uc.lor_prop_id = sr.lor_prop_id))))
     JOIN name_counts nc ON (((nc.import_run_id = sr.import_run_id) AND (NOT (nc.display_name_normalized IS DISTINCT FROM sr.display_name_normalized)))));


ALTER VIEW lor_snap.v_display_reconciliation_source OWNER TO msbadmin;

--
-- TOC entry 6259 (class 0 OID 0)
-- Dependencies: 421
-- Name: VIEW v_display_reconciliation_source; Type: COMMENT; Schema: lor_snap; Owner: msbadmin
--

COMMENT ON VIEW lor_snap.v_display_reconciliation_source IS 'Run-aware physical-display candidates requiring a nonblank LOR comment and canonicalized by normalized display name and raw LOR UUID. source_prop_id identifies the exact canonical snapshot occurrence; lor_prop_id is the preview-independent raw_prop_id proposed for ref.display. Prop/channel names are never substituted for blank comments. Background evidence is preferred; Master Musical scene evidence supplies musical-only displays.';


--
-- TOC entry 291 (class 1259 OID 16991)
-- Name: v_prop_identity; Type: VIEW; Schema: lor_snap; Owner: msbadmin
--

CREATE VIEW lor_snap.v_prop_identity AS
 SELECT import_run_id,
    prop_id,
    uid,
    device_type,
    lor_comment
   FROM lor_snap.props;


ALTER VIEW lor_snap.v_prop_identity OWNER TO msbadmin;

--
-- TOC entry 301 (class 1259 OID 17187)
-- Name: v_props_diff_latest_prev; Type: VIEW; Schema: lor_snap; Owner: msbadmin
--

CREATE VIEW lor_snap.v_props_diff_latest_prev AS
 WITH runs AS (
         SELECT ( SELECT max(import_run.import_run_id) AS max
                   FROM lor_snap.import_run) AS run_new,
            ( SELECT (max(import_run.import_run_id) - 1)
                   FROM lor_snap.import_run) AS run_old
        ), newp AS (
         SELECT props.import_run_id,
            props.int_prop_id,
            props.prop_id,
            props.name,
            props.lor_comment,
            props.device_type,
            props.bulb_shape,
            props.network,
            props.uid,
            props.start_channel,
            props.end_channel,
            props.unknown,
            props.color,
            props.custom_bulb_color,
            props.dimming_curve_name,
            props.individual_channels,
            props.legacy_sequence_method,
            props.max_channels,
            props.opacity,
            props.master_dimmable,
            props.preview_bulb_size,
            props.master_prop_id,
            props.separate_ids,
            props.start_location,
            props.string_type,
            props.traditional_colors,
            props.traditional_type,
            props.effect_bulb_size,
            props.tag,
            props.parm1,
            props.parm2,
            props.parm3,
            props.parm4,
            props.parm5,
            props.parm6,
            props.parm7,
            props.parm8,
            props.lights,
            props.preview_id
           FROM lor_snap.props
          WHERE (props.import_run_id = ( SELECT runs.run_new
                   FROM runs))
        ), oldp AS (
         SELECT props.import_run_id,
            props.int_prop_id,
            props.prop_id,
            props.name,
            props.lor_comment,
            props.device_type,
            props.bulb_shape,
            props.network,
            props.uid,
            props.start_channel,
            props.end_channel,
            props.unknown,
            props.color,
            props.custom_bulb_color,
            props.dimming_curve_name,
            props.individual_channels,
            props.legacy_sequence_method,
            props.max_channels,
            props.opacity,
            props.master_dimmable,
            props.preview_bulb_size,
            props.master_prop_id,
            props.separate_ids,
            props.start_location,
            props.string_type,
            props.traditional_colors,
            props.traditional_type,
            props.effect_bulb_size,
            props.tag,
            props.parm1,
            props.parm2,
            props.parm3,
            props.parm4,
            props.parm5,
            props.parm6,
            props.parm7,
            props.parm8,
            props.lights,
            props.preview_id
           FROM lor_snap.props
          WHERE (props.import_run_id = ( SELECT runs.run_old
                   FROM runs))
        ), j AS (
         SELECT COALESCE(n.prop_id, o.prop_id) AS prop_id,
            (n.prop_id IS NOT NULL) AS in_new,
            (o.prop_id IS NOT NULL) AS in_old,
            n.lor_comment AS new_lor_comment,
            o.lor_comment AS old_lor_comment,
            n.device_type AS new_device_type,
            o.device_type AS old_device_type,
            n.start_channel AS new_start_channel,
            o.start_channel AS old_start_channel,
            n.end_channel AS new_end_channel,
            o.end_channel AS old_end_channel,
            n.network AS new_network,
            o.network AS old_network,
            n.uid AS new_uid,
            o.uid AS old_uid,
            n.name AS new_name,
            o.name AS old_name
           FROM (newp n
             FULL JOIN oldp o USING (prop_id))
        )
 SELECT
        CASE
            WHEN (in_new AND (NOT in_old)) THEN 'ADDED'::text
            WHEN (in_old AND (NOT in_new)) THEN 'REMOVED'::text
            WHEN (in_new AND in_old AND ((new_lor_comment IS DISTINCT FROM old_lor_comment) OR (new_device_type IS DISTINCT FROM old_device_type) OR (new_start_channel IS DISTINCT FROM old_start_channel) OR (new_end_channel IS DISTINCT FROM old_end_channel) OR (new_network IS DISTINCT FROM old_network) OR (new_uid IS DISTINCT FROM old_uid) OR (new_name IS DISTINCT FROM old_name))) THEN 'CHANGED'::text
            ELSE 'SAME'::text
        END AS change_type,
    prop_id,
    old_lor_comment,
    new_lor_comment,
    old_device_type,
    new_device_type,
    old_start_channel,
    new_start_channel,
    old_end_channel,
    new_end_channel,
    old_network,
    new_network,
    old_uid,
    new_uid,
    old_name,
    new_name
   FROM j
  WHERE (NOT (in_new AND in_old AND (NOT (new_lor_comment IS DISTINCT FROM old_lor_comment)) AND (NOT (new_device_type IS DISTINCT FROM old_device_type)) AND (NOT (new_start_channel IS DISTINCT FROM old_start_channel)) AND (NOT (new_end_channel IS DISTINCT FROM old_end_channel)) AND (NOT (new_network IS DISTINCT FROM old_network)) AND (NOT (new_uid IS DISTINCT FROM old_uid)) AND (NOT (new_name IS DISTINCT FROM old_name))));


ALTER VIEW lor_snap.v_props_diff_latest_prev OWNER TO msbadmin;

--
-- TOC entry 409 (class 1259 OID 20710)
-- Name: container_label_batch; Type: TABLE; Schema: ops; Owner: msbadmin
--

CREATE TABLE ops.container_label_batch (
    container_label_batch_id bigint NOT NULL,
    batch_started_at timestamp with time zone DEFAULT now() NOT NULL,
    batch_completed_at timestamp with time zone,
    started_by_person_id integer,
    started_by_text text,
    status text DEFAULT 'PENDING'::text NOT NULL,
    notes text
);


ALTER TABLE ops.container_label_batch OWNER TO msbadmin;

--
-- TOC entry 408 (class 1259 OID 20709)
-- Name: container_label_batch_container_label_batch_id_seq; Type: SEQUENCE; Schema: ops; Owner: msbadmin
--

CREATE SEQUENCE ops.container_label_batch_container_label_batch_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE ops.container_label_batch_container_label_batch_id_seq OWNER TO msbadmin;

--
-- TOC entry 6264 (class 0 OID 0)
-- Dependencies: 408
-- Name: container_label_batch_container_label_batch_id_seq; Type: SEQUENCE OWNED BY; Schema: ops; Owner: msbadmin
--

ALTER SEQUENCE ops.container_label_batch_container_label_batch_id_seq OWNED BY ops.container_label_batch.container_label_batch_id;


--
-- TOC entry 411 (class 1259 OID 20722)
-- Name: container_label_batch_item; Type: TABLE; Schema: ops; Owner: msbadmin
--

CREATE TABLE ops.container_label_batch_item (
    container_label_batch_item_id bigint NOT NULL,
    container_label_batch_id bigint NOT NULL,
    container_id integer NOT NULL,
    qr_url text,
    container_label text,
    label_orientation text NOT NULL,
    printed_flag boolean DEFAULT false NOT NULL,
    printed_at timestamp with time zone,
    container_type_id integer,
    CONSTRAINT ck_container_label_batch_item_orientation CHECK ((label_orientation = ANY (ARRAY['VERTICAL'::text, 'HORIZONTAL'::text])))
);


ALTER TABLE ops.container_label_batch_item OWNER TO msbadmin;

--
-- TOC entry 410 (class 1259 OID 20721)
-- Name: container_label_batch_item_container_label_batch_item_id_seq; Type: SEQUENCE; Schema: ops; Owner: msbadmin
--

CREATE SEQUENCE ops.container_label_batch_item_container_label_batch_item_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE ops.container_label_batch_item_container_label_batch_item_id_seq OWNER TO msbadmin;

--
-- TOC entry 6267 (class 0 OID 0)
-- Dependencies: 410
-- Name: container_label_batch_item_container_label_batch_item_id_seq; Type: SEQUENCE OWNED BY; Schema: ops; Owner: msbadmin
--

ALTER SEQUENCE ops.container_label_batch_item_container_label_batch_item_id_seq OWNED BY ops.container_label_batch_item.container_label_batch_item_id;


--
-- TOC entry 402 (class 1259 OID 20611)
-- Name: container_label_print; Type: TABLE; Schema: ops; Owner: directus_app
--

CREATE TABLE ops.container_label_print (
    container_label_print_id bigint NOT NULL,
    container_id integer NOT NULL,
    printed_at timestamp with time zone DEFAULT now() NOT NULL,
    printed_by_person_id integer,
    printed_by_text text,
    print_method text DEFAULT 'POLLING_SERVICE'::text NOT NULL,
    label_orientation text NOT NULL,
    label_qty integer DEFAULT 2 NOT NULL,
    qr_url text,
    container_label text,
    notes text,
    CONSTRAINT ck_container_label_print_orientation CHECK ((label_orientation = ANY (ARRAY['VERTICAL'::text, 'HORIZONTAL'::text]))),
    CONSTRAINT ck_container_label_print_qty CHECK ((label_qty > 0))
);


ALTER TABLE ops.container_label_print OWNER TO directus_app;

--
-- TOC entry 6269 (class 0 OID 0)
-- Dependencies: 402
-- Name: TABLE container_label_print; Type: COMMENT; Schema: ops; Owner: directus_app
--

COMMENT ON TABLE ops.container_label_print IS 'Successful container label print history. One row per print event per container.';


--
-- TOC entry 6270 (class 0 OID 0)
-- Dependencies: 402
-- Name: COLUMN container_label_print.label_orientation; Type: COMMENT; Schema: ops; Owner: directus_app
--

COMMENT ON COLUMN ops.container_label_print.label_orientation IS 'VERTICAL when container_type_id = 1, otherwise HORIZONTAL.';


--
-- TOC entry 401 (class 1259 OID 20610)
-- Name: container_label_print_container_label_print_id_seq; Type: SEQUENCE; Schema: ops; Owner: directus_app
--

CREATE SEQUENCE ops.container_label_print_container_label_print_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE ops.container_label_print_container_label_print_id_seq OWNER TO directus_app;

--
-- TOC entry 6272 (class 0 OID 0)
-- Dependencies: 401
-- Name: container_label_print_container_label_print_id_seq; Type: SEQUENCE OWNED BY; Schema: ops; Owner: directus_app
--

ALTER SEQUENCE ops.container_label_print_container_label_print_id_seq OWNED BY ops.container_label_print.container_label_print_id;


--
-- TOC entry 405 (class 1259 OID 20675)
-- Name: display_label_batch; Type: TABLE; Schema: ops; Owner: msbadmin
--

CREATE TABLE ops.display_label_batch (
    display_label_batch_id bigint NOT NULL,
    batch_started_at timestamp with time zone DEFAULT now() NOT NULL,
    batch_completed_at timestamp with time zone,
    started_by_person_id integer,
    started_by_text text,
    status text DEFAULT 'PENDING'::text NOT NULL,
    notes text
);


ALTER TABLE ops.display_label_batch OWNER TO msbadmin;

--
-- TOC entry 404 (class 1259 OID 20674)
-- Name: display_label_batch_display_label_batch_id_seq; Type: SEQUENCE; Schema: ops; Owner: msbadmin
--

CREATE SEQUENCE ops.display_label_batch_display_label_batch_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE ops.display_label_batch_display_label_batch_id_seq OWNER TO msbadmin;

--
-- TOC entry 6275 (class 0 OID 0)
-- Dependencies: 404
-- Name: display_label_batch_display_label_batch_id_seq; Type: SEQUENCE OWNED BY; Schema: ops; Owner: msbadmin
--

ALTER SEQUENCE ops.display_label_batch_display_label_batch_id_seq OWNED BY ops.display_label_batch.display_label_batch_id;


--
-- TOC entry 407 (class 1259 OID 20687)
-- Name: display_label_batch_item; Type: TABLE; Schema: ops; Owner: msbadmin
--

CREATE TABLE ops.display_label_batch_item (
    display_label_batch_item_id bigint NOT NULL,
    display_label_batch_id bigint NOT NULL,
    display_id integer NOT NULL,
    qr_url text,
    line1 text,
    line2 text,
    printed_flag boolean DEFAULT false NOT NULL,
    printed_at timestamp with time zone,
    container_id integer,
    display_name text
);


ALTER TABLE ops.display_label_batch_item OWNER TO msbadmin;

--
-- TOC entry 406 (class 1259 OID 20686)
-- Name: display_label_batch_item_display_label_batch_item_id_seq; Type: SEQUENCE; Schema: ops; Owner: msbadmin
--

CREATE SEQUENCE ops.display_label_batch_item_display_label_batch_item_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE ops.display_label_batch_item_display_label_batch_item_id_seq OWNER TO msbadmin;

--
-- TOC entry 6278 (class 0 OID 0)
-- Dependencies: 406
-- Name: display_label_batch_item_display_label_batch_item_id_seq; Type: SEQUENCE OWNED BY; Schema: ops; Owner: msbadmin
--

ALTER SEQUENCE ops.display_label_batch_item_display_label_batch_item_id_seq OWNED BY ops.display_label_batch_item.display_label_batch_item_id;


--
-- TOC entry 400 (class 1259 OID 20591)
-- Name: display_label_print; Type: TABLE; Schema: ops; Owner: directus_app
--

CREATE TABLE ops.display_label_print (
    display_label_print_id bigint NOT NULL,
    display_id bigint NOT NULL,
    printed_at timestamp with time zone DEFAULT now() NOT NULL,
    printed_by_person_id integer,
    printed_by_text text,
    print_method text DEFAULT 'POLLING_SERVICE'::text NOT NULL,
    label_qty integer DEFAULT 1 NOT NULL,
    qr_url text,
    line1 text,
    line2 text,
    notes text,
    CONSTRAINT ck_display_label_print_qty CHECK ((label_qty > 0))
);


ALTER TABLE ops.display_label_print OWNER TO directus_app;

--
-- TOC entry 6280 (class 0 OID 0)
-- Dependencies: 400
-- Name: TABLE display_label_print; Type: COMMENT; Schema: ops; Owner: directus_app
--

COMMENT ON TABLE ops.display_label_print IS 'Successful display label print history. One row per print event per display.';


--
-- TOC entry 6281 (class 0 OID 0)
-- Dependencies: 400
-- Name: COLUMN display_label_print.printed_by_person_id; Type: COMMENT; Schema: ops; Owner: directus_app
--

COMMENT ON COLUMN ops.display_label_print.printed_by_person_id IS 'Optional Directus/person reference when known.';


--
-- TOC entry 6282 (class 0 OID 0)
-- Dependencies: 400
-- Name: COLUMN display_label_print.printed_by_text; Type: COMMENT; Schema: ops; Owner: directus_app
--

COMMENT ON COLUMN ops.display_label_print.printed_by_text IS 'Fallback text identifier for service/manual printing when person_id is not available.';


--
-- TOC entry 6283 (class 0 OID 0)
-- Dependencies: 400
-- Name: COLUMN display_label_print.print_method; Type: COMMENT; Schema: ops; Owner: directus_app
--

COMMENT ON COLUMN ops.display_label_print.print_method IS 'Examples: POLLING_SERVICE, MANUAL_CATCHUP, REPRINT, TEST';


--
-- TOC entry 399 (class 1259 OID 20590)
-- Name: display_label_print_display_label_print_id_seq; Type: SEQUENCE; Schema: ops; Owner: directus_app
--

CREATE SEQUENCE ops.display_label_print_display_label_print_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE ops.display_label_print_display_label_print_id_seq OWNER TO directus_app;

--
-- TOC entry 6285 (class 0 OID 0)
-- Dependencies: 399
-- Name: display_label_print_display_label_print_id_seq; Type: SEQUENCE OWNED BY; Schema: ops; Owner: directus_app
--

ALTER SEQUENCE ops.display_label_print_display_label_print_id_seq OWNED BY ops.display_label_print.display_label_print_id;


--
-- TOC entry 305 (class 1259 OID 17288)
-- Name: display_test_session; Type: TABLE; Schema: ops; Owner: msbadmin
--

CREATE TABLE ops.display_test_session (
    display_test_session_id bigint NOT NULL,
    test_session_id bigint NOT NULL,
    lor_prop_id text NOT NULL,
    is_display_present boolean,
    checked_at timestamp with time zone,
    checked_by text,
    notes text,
    checked_date_text text,
    stage_id integer,
    test_status text,
    amps_measured numeric,
    light_count integer,
    display_state text,
    is_spare boolean DEFAULT false NOT NULL,
    stage_key text,
    display_id bigint,
    created_at timestamp with time zone,
    created_by text,
    updated_at timestamp with time zone,
    updated_by text,
    created_by_person_id integer,
    updated_by_person_id integer,
    checked_by_person_id integer,
    CONSTRAINT chk_display_test_session_state CHECK (((display_state IS NULL) OR (display_state = ANY (ARRAY['PASS'::text, 'FAIL'::text, 'DEFERRED'::text, 'NOT_PRESENT'::text, 'REMOVED_FOR_REPAIR'::text]))))
);


ALTER TABLE ops.display_test_session OWNER TO msbadmin;

--
-- TOC entry 304 (class 1259 OID 17287)
-- Name: display_test_session_display_test_session_id_seq; Type: SEQUENCE; Schema: ops; Owner: msbadmin
--

CREATE SEQUENCE ops.display_test_session_display_test_session_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE ops.display_test_session_display_test_session_id_seq OWNER TO msbadmin;

--
-- TOC entry 6288 (class 0 OID 0)
-- Dependencies: 304
-- Name: display_test_session_display_test_session_id_seq; Type: SEQUENCE OWNED BY; Schema: ops; Owner: msbadmin
--

ALTER SEQUENCE ops.display_test_session_display_test_session_id_seq OWNED BY ops.display_test_session.display_test_session_id;


--
-- TOC entry 437 (class 1259 OID 23486)
-- Name: lor_reconciliation_action; Type: TABLE; Schema: ops; Owner: msbadmin
--

CREATE TABLE ops.lor_reconciliation_action (
    lor_reconciliation_action_id bigint NOT NULL,
    lor_reconciliation_run_id bigint NOT NULL,
    lor_reconciliation_group_id bigint,
    import_run_id bigint NOT NULL,
    action_type text NOT NULL,
    reason text NOT NULL,
    action_payload jsonb DEFAULT '{}'::jsonb NOT NULL,
    acted_at timestamp with time zone DEFAULT now() NOT NULL,
    acted_by text DEFAULT CURRENT_USER NOT NULL,
    acted_by_application text,
    CONSTRAINT ck_lor_reconciliation_action_reason CHECK ((NULLIF(btrim(reason), ''::text) IS NOT NULL)),
    CONSTRAINT ck_lor_reconciliation_action_scope CHECK ((((action_type = 'CANCEL_RECONCILIATION'::text) AND (lor_reconciliation_group_id IS NULL)) OR ((action_type <> 'CANCEL_RECONCILIATION'::text) AND (lor_reconciliation_group_id IS NOT NULL)))),
    CONSTRAINT ck_lor_reconciliation_action_type CHECK ((action_type = ANY (ARRAY['RENAME_DISPLAY'::text, 'UPDATE_LOR_LINK'::text, 'REASSOCIATE_DISPLAY'::text, 'ADD_NEW_DISPLAY'::text, 'SET_RETIRED'::text, 'SET_RECYCLED'::text, 'RESTORE_TO_LOR_REQUIRED'::text, 'CORRECT_SOURCE_REQUIRED'::text, 'EXCLUDE_NONPHYSICAL'::text, 'DEFER'::text, 'CANCEL_RECONCILIATION'::text, 'PRESERVE_EXISTING_STAGE_METADATA'::text])))
);


ALTER TABLE ops.lor_reconciliation_action OWNER TO msbadmin;

--
-- TOC entry 6290 (class 0 OID 0)
-- Dependencies: 437
-- Name: TABLE lor_reconciliation_action; Type: COMMENT; Schema: ops; Owner: msbadmin
--

COMMENT ON TABLE ops.lor_reconciliation_action IS 'Append-only operator decisions. The latest action for a group is effective; prior actions remain immutable audit history.';


--
-- TOC entry 439 (class 1259 OID 23513)
-- Name: lor_reconciliation_action_assignment; Type: TABLE; Schema: ops; Owner: msbadmin
--

CREATE TABLE ops.lor_reconciliation_action_assignment (
    lor_reconciliation_action_assignment_id bigint NOT NULL,
    lor_reconciliation_action_id bigint NOT NULL,
    lor_reconciliation_display_candidate_id bigint NOT NULL,
    target_display_id bigint NOT NULL
);


ALTER TABLE ops.lor_reconciliation_action_assignment OWNER TO msbadmin;

--
-- TOC entry 6292 (class 0 OID 0)
-- Dependencies: 439
-- Name: TABLE lor_reconciliation_action_assignment; Type: COMMENT; Schema: ops; Owner: msbadmin
--

COMMENT ON TABLE ops.lor_reconciliation_action_assignment IS 'Complete candidate-to-permanent-display mapping required by an atomic REASSOCIATE_DISPLAY action.';


--
-- TOC entry 438 (class 1259 OID 23512)
-- Name: lor_reconciliation_action_ass_lor_reconciliation_action_ass_seq; Type: SEQUENCE; Schema: ops; Owner: msbadmin
--

ALTER TABLE ops.lor_reconciliation_action_assignment ALTER COLUMN lor_reconciliation_action_assignment_id ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME ops.lor_reconciliation_action_ass_lor_reconciliation_action_ass_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- TOC entry 425 (class 1259 OID 23184)
-- Name: lor_reconciliation_action_legacy; Type: TABLE; Schema: ops; Owner: msbadmin
--

CREATE TABLE ops.lor_reconciliation_action_legacy (
    lor_reconciliation_action_id bigint NOT NULL,
    import_run_id bigint NOT NULL,
    action_type text NOT NULL,
    display_id bigint NOT NULL,
    lor_prop_id_before text,
    lor_prop_id_after text,
    display_name_before text,
    display_name_after text,
    display_status_id_before integer,
    display_status_id_after integer,
    preview_id text,
    preview_stage_id text,
    reason text NOT NULL,
    acted_at timestamp with time zone DEFAULT now() NOT NULL,
    acted_by text DEFAULT CURRENT_USER NOT NULL,
    CONSTRAINT ck_lor_reconciliation_action_reason CHECK ((btrim(reason) <> ''::text)),
    CONSTRAINT ck_lor_reconciliation_action_type CHECK ((action_type = ANY (ARRAY['RENAME_DISPLAY'::text, 'KEEP_DISPLAY_UPDATE_LOR_LINK'::text, 'REASSOCIATE_DISPLAY'::text, 'ADD_NEW_DISPLAY'::text, 'SET_RECYCLED'::text])))
);


ALTER TABLE ops.lor_reconciliation_action_legacy OWNER TO msbadmin;

--
-- TOC entry 6295 (class 0 OID 0)
-- Dependencies: 425
-- Name: TABLE lor_reconciliation_action_legacy; Type: COMMENT; Schema: ops; Owner: msbadmin
--

COMMENT ON TABLE ops.lor_reconciliation_action_legacy IS 'Historical pre-persistent-run LOR decisions. Retained unchanged for audit; new decisions use ops.lor_reconciliation_action.';


--
-- TOC entry 424 (class 1259 OID 23183)
-- Name: lor_reconciliation_action_legacy_id_seq; Type: SEQUENCE; Schema: ops; Owner: msbadmin
--

ALTER TABLE ops.lor_reconciliation_action_legacy ALTER COLUMN lor_reconciliation_action_id ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME ops.lor_reconciliation_action_legacy_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- TOC entry 436 (class 1259 OID 23485)
-- Name: lor_reconciliation_action_lor_reconciliation_action_id_seq; Type: SEQUENCE; Schema: ops; Owner: msbadmin
--

ALTER TABLE ops.lor_reconciliation_action ALTER COLUMN lor_reconciliation_action_id ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME ops.lor_reconciliation_action_lor_reconciliation_action_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- TOC entry 435 (class 1259 OID 23453)
-- Name: lor_reconciliation_display_candidate; Type: TABLE; Schema: ops; Owner: msbadmin
--

CREATE TABLE ops.lor_reconciliation_display_candidate (
    lor_reconciliation_display_candidate_id bigint NOT NULL,
    lor_reconciliation_run_id bigint NOT NULL,
    lor_reconciliation_group_id bigint NOT NULL,
    import_run_id bigint NOT NULL,
    candidate_key text NOT NULL,
    source_prop_id text,
    lor_prop_id text,
    display_id bigint,
    uuid_display_id bigint,
    name_display_id bigint,
    classification_code text NOT NULL,
    candidate_class text NOT NULL,
    initial_resolution_state text NOT NULL,
    decision_required boolean NOT NULL,
    is_blocking boolean NOT NULL,
    allowed_action_types text[] DEFAULT ARRAY[]::text[] NOT NULL,
    changed_fields text[] DEFAULT ARRAY[]::text[] NOT NULL,
    current_display_name text,
    proposed_display_name text,
    current_stage_id integer,
    proposed_stage_id integer,
    current_string_type text,
    proposed_string_type text,
    current_display_status_id integer,
    preview_id text,
    preview_name text,
    proposed_stage_key text,
    location_summary text,
    operator_message text,
    source_evidence jsonb DEFAULT '{}'::jsonb NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT ck_lor_reconciliation_display_candidate_class CHECK ((candidate_class = ANY (ARRAY['PHYSICAL_DISPLAY'::text, 'EXCLUDED_NONPHYSICAL'::text]))),
    CONSTRAINT ck_lor_reconciliation_display_candidate_state CHECK ((initial_resolution_state = ANY (ARRAY['AUTO_APPROVED'::text, 'DECISION_REQUIRED'::text, 'BLOCKED'::text, 'EXCLUDED'::text])))
);


ALTER TABLE ops.lor_reconciliation_display_candidate OWNER TO msbadmin;

--
-- TOC entry 6299 (class 0 OID 0)
-- Dependencies: 435
-- Name: TABLE lor_reconciliation_display_candidate; Type: COMMENT; Schema: ops; Owner: msbadmin
--

COMMENT ON TABLE ops.lor_reconciliation_display_candidate IS 'Frozen display evaluation for one captured ingest. source_prop_id is the exact scoped snapshot row; lor_prop_id is the raw UUID proposed for ref.display.';


--
-- TOC entry 434 (class 1259 OID 23452)
-- Name: lor_reconciliation_display_ca_lor_reconciliation_display_ca_seq; Type: SEQUENCE; Schema: ops; Owner: msbadmin
--

ALTER TABLE ops.lor_reconciliation_display_candidate ALTER COLUMN lor_reconciliation_display_candidate_id ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME ops.lor_reconciliation_display_ca_lor_reconciliation_display_ca_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- TOC entry 433 (class 1259 OID 23429)
-- Name: lor_reconciliation_group; Type: TABLE; Schema: ops; Owner: msbadmin
--

CREATE TABLE ops.lor_reconciliation_group (
    lor_reconciliation_group_id bigint NOT NULL,
    lor_reconciliation_run_id bigint NOT NULL,
    import_run_id bigint NOT NULL,
    entity_type text NOT NULL,
    logical_group_key text NOT NULL,
    group_kind text NOT NULL,
    member_count integer NOT NULL,
    requires_atomic_decision boolean DEFAULT false NOT NULL,
    decision_required boolean DEFAULT false NOT NULL,
    allowed_action_types text[] DEFAULT ARRAY[]::text[] NOT NULL,
    operator_message text,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT ck_lor_reconciliation_group_atomic CHECK (((NOT requires_atomic_decision) OR (member_count > 1))),
    CONSTRAINT ck_lor_reconciliation_group_entity CHECK ((entity_type = ANY (ARRAY['STAGE'::text, 'DISPLAY'::text, 'SCENE'::text, 'SCENE_DISPLAY'::text]))),
    CONSTRAINT ck_lor_reconciliation_group_kind CHECK ((group_kind = ANY (ARRAY['SINGLE_CANDIDATE'::text, 'IDENTITY_COMPONENT'::text]))),
    CONSTRAINT ck_lor_reconciliation_group_members CHECK ((member_count > 0))
);


ALTER TABLE ops.lor_reconciliation_group OWNER TO msbadmin;

--
-- TOC entry 6302 (class 0 OID 0)
-- Dependencies: 433
-- Name: TABLE lor_reconciliation_group; Type: COMMENT; Schema: ops; Owner: msbadmin
--

COMMENT ON TABLE ops.lor_reconciliation_group IS 'Data-derived inseparable candidate groups. Operator actions target a group so one identity component cannot be partially resolved.';


--
-- TOC entry 432 (class 1259 OID 23428)
-- Name: lor_reconciliation_group_lor_reconciliation_group_id_seq; Type: SEQUENCE; Schema: ops; Owner: msbadmin
--

ALTER TABLE ops.lor_reconciliation_group ALTER COLUMN lor_reconciliation_group_id ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME ops.lor_reconciliation_group_lor_reconciliation_group_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- TOC entry 441 (class 1259 OID 23539)
-- Name: lor_reconciliation_result; Type: TABLE; Schema: ops; Owner: msbadmin
--

CREATE TABLE ops.lor_reconciliation_result (
    lor_reconciliation_result_id bigint NOT NULL,
    lor_reconciliation_run_id bigint NOT NULL,
    import_run_id bigint NOT NULL,
    entity_type text NOT NULL,
    entity_key text NOT NULL,
    result_class text NOT NULL,
    reason_code text NOT NULL,
    operator_message text NOT NULL,
    committed boolean DEFAULT false NOT NULL,
    recorded_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT ck_lor_reconciliation_result_class CHECK ((result_class = ANY (ARRAY['ADDED'::text, 'UPDATED'::text, 'REASSOCIATED'::text, 'STATUS_CHANGED'::text, 'BLOCKED'::text, 'DEFERRED'::text, 'UNRESOLVED'::text, 'VALIDATION'::text, 'CANCELLED'::text, 'FAILED'::text, 'REPORT_PUBLISHED'::text, 'SUPERSEDED'::text])))
);


ALTER TABLE ops.lor_reconciliation_result OWNER TO msbadmin;

--
-- TOC entry 6305 (class 0 OID 0)
-- Dependencies: 441
-- Name: TABLE lor_reconciliation_result; Type: COMMENT; Schema: ops; Owner: msbadmin
--

COMMENT ON TABLE ops.lor_reconciliation_result IS 'Append-only actual outcomes. Proposed changes are never recorded as committed production results.';


--
-- TOC entry 440 (class 1259 OID 23538)
-- Name: lor_reconciliation_result_lor_reconciliation_result_id_seq; Type: SEQUENCE; Schema: ops; Owner: msbadmin
--

ALTER TABLE ops.lor_reconciliation_result ALTER COLUMN lor_reconciliation_result_id ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME ops.lor_reconciliation_result_lor_reconciliation_result_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- TOC entry 431 (class 1259 OID 23405)
-- Name: lor_reconciliation_run; Type: TABLE; Schema: ops; Owner: msbadmin
--

CREATE TABLE ops.lor_reconciliation_run (
    lor_reconciliation_run_id bigint NOT NULL,
    import_run_id bigint NOT NULL,
    status text DEFAULT 'STARTING'::text NOT NULL,
    started_at timestamp with time zone DEFAULT now() NOT NULL,
    started_by text DEFAULT CURRENT_USER NOT NULL,
    started_by_application text,
    paused_at timestamp with time zone,
    resumed_at timestamp with time zone,
    completed_at timestamp with time zone,
    cancelled_at timestamp with time zone,
    failed_at timestamp with time zone,
    structural_failure_count integer DEFAULT 0 NOT NULL,
    blocked_count integer DEFAULT 0 NOT NULL,
    deferred_count integer DEFAULT 0 NOT NULL,
    unresolved_count integer DEFAULT 0 NOT NULL,
    validation_state text DEFAULT 'NOT_RUN'::text NOT NULL,
    report_path text,
    report_url text,
    report_published_at timestamp with time zone,
    cancellation_reason text,
    failure_message text,
    superseded_at timestamp with time zone,
    superseded_by_run_id bigint,
    supersession_reason text,
    report_sha256 text,
    CONSTRAINT ck_lor_reconciliation_report_sha256 CHECK (((report_sha256 IS NULL) OR (report_sha256 ~ '^[0-9a-f]{64}$'::text))),
    CONSTRAINT ck_lor_reconciliation_run_cancellation CHECK (((status <> 'CANCELLED'::text) OR ((cancelled_at IS NOT NULL) AND (NULLIF(btrim(cancellation_reason), ''::text) IS NOT NULL)))),
    CONSTRAINT ck_lor_reconciliation_run_counts CHECK (((structural_failure_count >= 0) AND (blocked_count >= 0) AND (deferred_count >= 0) AND (unresolved_count >= 0))),
    CONSTRAINT ck_lor_reconciliation_run_status CHECK ((status = ANY (ARRAY['STARTING'::text, 'PREFLIGHT'::text, 'AWAITING_DECISIONS'::text, 'READY_TO_FINISH'::text, 'PROMOTING'::text, 'VALIDATING'::text, 'REPORTING'::text, 'COMPLETED'::text, 'COMPLETED_WITH_EXCEPTIONS'::text, 'CANCELLED'::text, 'FAILED'::text, 'SUPERSEDED'::text]))),
    CONSTRAINT ck_lor_reconciliation_run_supersession CHECK (((status <> 'SUPERSEDED'::text) OR ((superseded_at IS NOT NULL) AND (superseded_by_run_id IS NOT NULL) AND (NULLIF(btrim(supersession_reason), ''::text) IS NOT NULL)))),
    CONSTRAINT ck_lor_reconciliation_run_validation CHECK ((validation_state = ANY (ARRAY['NOT_RUN'::text, 'PENDING'::text, 'PASSED'::text, 'FAILED'::text])))
);


ALTER TABLE ops.lor_reconciliation_run OWNER TO msbadmin;

--
-- TOC entry 6308 (class 0 OID 0)
-- Dependencies: 431
-- Name: TABLE lor_reconciliation_run; Type: COMMENT; Schema: ops; Owner: msbadmin
--

COMMENT ON TABLE ops.lor_reconciliation_run IS 'One durable reconciliation attempt. Multiple attempts may independently evaluate the same import; older decisions never govern a later attempt.';


--
-- TOC entry 430 (class 1259 OID 23404)
-- Name: lor_reconciliation_run_lor_reconciliation_run_id_seq; Type: SEQUENCE; Schema: ops; Owner: msbadmin
--

ALTER TABLE ops.lor_reconciliation_run ALTER COLUMN lor_reconciliation_run_id ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME ops.lor_reconciliation_run_lor_reconciliation_run_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- TOC entry 451 (class 1259 OID 23717)
-- Name: lor_reconciliation_scene_candidate; Type: TABLE; Schema: ops; Owner: msbadmin
--

CREATE TABLE ops.lor_reconciliation_scene_candidate (
    lor_reconciliation_scene_candidate_id bigint NOT NULL,
    lor_reconciliation_run_id bigint NOT NULL,
    lor_reconciliation_group_id bigint NOT NULL,
    import_run_id bigint NOT NULL,
    candidate_key text NOT NULL,
    preview_id text NOT NULL,
    scene_id text NOT NULL,
    scene_name text NOT NULL,
    resolved_stage_key text,
    resolved_stage_id integer,
    existing_lor_scene_id bigint,
    scene_section text,
    background_file text,
    h_scroll integer,
    v_scroll integer,
    zoom integer,
    create_grid_view text,
    classification_code text NOT NULL,
    initial_resolution_state text NOT NULL,
    decision_required boolean DEFAULT false NOT NULL,
    is_blocking boolean NOT NULL,
    changed_fields text[] DEFAULT ARRAY[]::text[] NOT NULL,
    operator_message text NOT NULL,
    source_evidence jsonb DEFAULT '{}'::jsonb NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT ck_lor_reconciliation_scene_state CHECK ((initial_resolution_state = ANY (ARRAY['AUTO_APPROVED'::text, 'BLOCKED'::text])))
);


ALTER TABLE ops.lor_reconciliation_scene_candidate OWNER TO msbadmin;

--
-- TOC entry 6311 (class 0 OID 0)
-- Dependencies: 451
-- Name: TABLE lor_reconciliation_scene_candidate; Type: COMMENT; Schema: ops; Owner: msbadmin
--

COMMENT ON TABLE ops.lor_reconciliation_scene_candidate IS 'Frozen scene definitions and resolved permanent stage identities for one captured reconciliation ingest.';


--
-- TOC entry 450 (class 1259 OID 23716)
-- Name: lor_reconciliation_scene_cand_lor_reconciliation_scene_cand_seq; Type: SEQUENCE; Schema: ops; Owner: msbadmin
--

ALTER TABLE ops.lor_reconciliation_scene_candidate ALTER COLUMN lor_reconciliation_scene_candidate_id ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME ops.lor_reconciliation_scene_cand_lor_reconciliation_scene_cand_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- TOC entry 453 (class 1259 OID 23750)
-- Name: lor_reconciliation_scene_display_candidate; Type: TABLE; Schema: ops; Owner: msbadmin
--

CREATE TABLE ops.lor_reconciliation_scene_display_candidate (
    lor_reconciliation_scene_display_candidate_id bigint NOT NULL,
    lor_reconciliation_run_id bigint NOT NULL,
    lor_reconciliation_group_id bigint NOT NULL,
    import_run_id bigint NOT NULL,
    candidate_key text NOT NULL,
    preview_id text NOT NULL,
    scene_id text NOT NULL,
    source_prop_id text NOT NULL,
    source_lor_prop_id text NOT NULL,
    lor_reconciliation_display_candidate_id bigint NOT NULL,
    frozen_display_id bigint,
    existing_lor_scene_id bigint,
    existing_display_id bigint,
    scene_prop_ordinal integer,
    scene_role text,
    membership_source text,
    source_scene_count integer NOT NULL,
    classification_code text NOT NULL,
    initial_resolution_state text NOT NULL,
    decision_required boolean DEFAULT false NOT NULL,
    is_blocking boolean NOT NULL,
    operator_message text NOT NULL,
    source_evidence jsonb DEFAULT '{}'::jsonb NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT ck_lor_reconciliation_scene_display_count CHECK ((source_scene_count > 0)),
    CONSTRAINT ck_lor_reconciliation_scene_display_state CHECK ((initial_resolution_state = ANY (ARRAY['AUTO_APPROVED'::text, 'BLOCKED'::text])))
);


ALTER TABLE ops.lor_reconciliation_scene_display_candidate OWNER TO msbadmin;

--
-- TOC entry 6314 (class 0 OID 0)
-- Dependencies: 453
-- Name: TABLE lor_reconciliation_scene_display_candidate; Type: COMMENT; Schema: ops; Owner: msbadmin
--

COMMENT ON TABLE ops.lor_reconciliation_scene_display_candidate IS 'Frozen physical-display scene memberships. P4 resolves permanent display_id after P2 without creating identity.';


--
-- TOC entry 452 (class 1259 OID 23749)
-- Name: lor_reconciliation_scene_disp_lor_reconciliation_scene_disp_seq; Type: SEQUENCE; Schema: ops; Owner: msbadmin
--

ALTER TABLE ops.lor_reconciliation_scene_display_candidate ALTER COLUMN lor_reconciliation_scene_display_candidate_id ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME ops.lor_reconciliation_scene_disp_lor_reconciliation_scene_disp_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- TOC entry 458 (class 1259 OID 23893)
-- Name: lor_reconciliation_source_preview; Type: TABLE; Schema: ops; Owner: msbadmin
--

CREATE TABLE ops.lor_reconciliation_source_preview (
    lor_reconciliation_source_preview_id bigint NOT NULL,
    lor_reconciliation_run_id bigint NOT NULL,
    import_run_id bigint NOT NULL,
    int_preview_id bigint NOT NULL,
    preview_id text NOT NULL,
    stage_id text,
    preview_name text,
    preview_revision text,
    brightness double precision,
    background_file text,
    source_filename text,
    frozen_at timestamp with time zone DEFAULT now() NOT NULL
);


ALTER TABLE ops.lor_reconciliation_source_preview OWNER TO msbadmin;

--
-- TOC entry 6317 (class 0 OID 0)
-- Dependencies: 458
-- Name: TABLE lor_reconciliation_source_preview; Type: COMMENT; Schema: ops; Owner: msbadmin
--

COMMENT ON TABLE ops.lor_reconciliation_source_preview IS 'Immutable copy of every preview row in the captured ingest, including filename, name, and revision.';


--
-- TOC entry 457 (class 1259 OID 23892)
-- Name: lor_reconciliation_source_pre_lor_reconciliation_source_pre_seq; Type: SEQUENCE; Schema: ops; Owner: msbadmin
--

ALTER TABLE ops.lor_reconciliation_source_preview ALTER COLUMN lor_reconciliation_source_preview_id ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME ops.lor_reconciliation_source_pre_lor_reconciliation_source_pre_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- TOC entry 456 (class 1259 OID 23877)
-- Name: lor_reconciliation_source_run; Type: TABLE; Schema: ops; Owner: msbadmin
--

CREATE TABLE ops.lor_reconciliation_source_run (
    lor_reconciliation_run_id bigint NOT NULL,
    import_run_id bigint NOT NULL,
    run_ts timestamp with time zone NOT NULL,
    notes text,
    parser_version text,
    parser_started_at timestamp with time zone,
    parser_completed_at timestamp with time zone,
    parser_actor text,
    parser_host text,
    source_preview_folder text,
    source_sqlite_path text,
    preview_count integer,
    scene_count integer,
    prop_count integer,
    sub_prop_count integer,
    dmx_channel_count integer,
    scene_lor_prop_count integer,
    ingest_script_version text,
    ingest_actor text,
    ingest_host text,
    ingest_started_at timestamp with time zone,
    ingest_completed_at timestamp with time zone,
    frozen_at timestamp with time zone DEFAULT now() NOT NULL
);


ALTER TABLE ops.lor_reconciliation_source_run OWNER TO msbadmin;

--
-- TOC entry 6320 (class 0 OID 0)
-- Dependencies: 456
-- Name: TABLE lor_reconciliation_source_run; Type: COMMENT; Schema: ops; Owner: msbadmin
--

COMMENT ON TABLE ops.lor_reconciliation_source_run IS 'Immutable typed copy of the complete lor_snap.import_run row captured by Start Reconciliation.';


--
-- TOC entry 460 (class 1259 OID 23909)
-- Name: lor_reconciliation_source_scene; Type: TABLE; Schema: ops; Owner: msbadmin
--

CREATE TABLE ops.lor_reconciliation_source_scene (
    lor_reconciliation_source_scene_row_id bigint NOT NULL,
    lor_reconciliation_run_id bigint NOT NULL,
    import_run_id bigint NOT NULL,
    int_scene_id integer,
    scene_id text,
    preview_id text,
    stage_id text,
    scene_name text,
    scene_section text,
    background_file text,
    h_scroll integer,
    v_scroll integer,
    zoom integer,
    create_grid_view text,
    frozen_at timestamp with time zone DEFAULT now() NOT NULL
);


ALTER TABLE ops.lor_reconciliation_source_scene OWNER TO msbadmin;

--
-- TOC entry 6322 (class 0 OID 0)
-- Dependencies: 460
-- Name: TABLE lor_reconciliation_source_scene; Type: COMMENT; Schema: ops; Owner: msbadmin
--

COMMENT ON TABLE ops.lor_reconciliation_source_scene IS 'Immutable copy of every scene row in the captured ingest for Finish/Cancel reporting.';


--
-- TOC entry 459 (class 1259 OID 23908)
-- Name: lor_reconciliation_source_sce_lor_reconciliation_source_sce_seq; Type: SEQUENCE; Schema: ops; Owner: msbadmin
--

ALTER TABLE ops.lor_reconciliation_source_scene ALTER COLUMN lor_reconciliation_source_scene_row_id ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME ops.lor_reconciliation_source_sce_lor_reconciliation_source_sce_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- TOC entry 448 (class 1259 OID 23615)
-- Name: lor_reconciliation_stage_candidate; Type: TABLE; Schema: ops; Owner: msbadmin
--

CREATE TABLE ops.lor_reconciliation_stage_candidate (
    lor_reconciliation_stage_candidate_id bigint NOT NULL,
    lor_reconciliation_run_id bigint NOT NULL,
    lor_reconciliation_group_id bigint NOT NULL,
    import_run_id bigint NOT NULL,
    candidate_key text NOT NULL,
    binding_type text NOT NULL,
    preview_id text NOT NULL,
    scene_id text,
    source_name text,
    source_stage_key text NOT NULL,
    resolved_stage_id integer,
    binding_stage_id integer,
    stage_key_stage_id integer,
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
    changed_fields text[] DEFAULT ARRAY[]::text[] NOT NULL,
    operator_message text NOT NULL,
    source_evidence jsonb DEFAULT '{}'::jsonb NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT ck_lor_reconciliation_stage_binding_type CHECK ((((binding_type = 'PREVIEW'::text) AND (scene_id IS NULL)) OR ((binding_type = 'SCENE'::text) AND (NULLIF(btrim(scene_id), ''::text) IS NOT NULL)))),
    CONSTRAINT ck_lor_reconciliation_stage_state CHECK ((initial_resolution_state = ANY (ARRAY['AUTO_APPROVED'::text, 'DECISION_REQUIRED'::text, 'BLOCKED'::text])))
);


ALTER TABLE ops.lor_reconciliation_stage_candidate OWNER TO msbadmin;

--
-- TOC entry 6325 (class 0 OID 0)
-- Dependencies: 448
-- Name: TABLE lor_reconciliation_stage_candidate; Type: COMMENT; Schema: ops; Owner: msbadmin
--

COMMENT ON TABLE ops.lor_reconciliation_stage_candidate IS 'Frozen preview/scene-to-stage evidence for one captured reconciliation ingest. P1 consumes these rows without recalculating identity.';


--
-- TOC entry 447 (class 1259 OID 23614)
-- Name: lor_reconciliation_stage_cand_lor_reconciliation_stage_cand_seq; Type: SEQUENCE; Schema: ops; Owner: msbadmin
--

ALTER TABLE ops.lor_reconciliation_stage_candidate ALTER COLUMN lor_reconciliation_stage_candidate_id ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME ops.lor_reconciliation_stage_cand_lor_reconciliation_stage_cand_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- TOC entry 303 (class 1259 OID 17257)
-- Name: test_session; Type: TABLE; Schema: ops; Owner: msbadmin
--

CREATE TABLE ops.test_session (
    test_session_id bigint NOT NULL,
    season_year integer NOT NULL,
    container_id integer NOT NULL,
    container_status_legacy text DEFAULT 'ACTIVE'::text NOT NULL,
    home_location_code text,
    work_location_code text,
    pulled_at timestamp with time zone,
    pulled_by text,
    returned_to_storage_at timestamp with time zone,
    returned_to_storage_by text,
    remaining_notes text,
    done_at timestamp with time zone,
    done_by text,
    notes text,
    tag_state text,
    legacy_flag boolean DEFAULT false NOT NULL,
    container_test_status_id integer DEFAULT 1 NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    created_by text DEFAULT CURRENT_USER NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_by text DEFAULT CURRENT_USER NOT NULL,
    created_by_person_id integer,
    updated_by_person_id integer,
    container_search_helper character varying(20),
    pulled_by_person_id integer,
    refresh_requested boolean DEFAULT false NOT NULL,
    last_refreshed_at timestamp with time zone,
    last_refreshed_by text,
    last_refreshed_by_person_id integer,
    last_refresh_add_count integer DEFAULT 0,
    last_refresh_delete_count integer DEFAULT 0,
    CONSTRAINT chk_test_session_tag_state CHECK (((tag_state IS NULL) OR (tag_state = ANY (ARRAY['GREEN'::text, 'YELLOW'::text, 'RED'::text])))),
    CONSTRAINT test_session_status_check CHECK ((container_status_legacy = ANY (ARRAY['NOT_STARTED'::text, 'IN_PROGRESS'::text, 'DONE'::text])))
);


ALTER TABLE ops.test_session OWNER TO msbadmin;

--
-- TOC entry 302 (class 1259 OID 17256)
-- Name: test_session_test_session_id_seq; Type: SEQUENCE; Schema: ops; Owner: msbadmin
--

CREATE SEQUENCE ops.test_session_test_session_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE ops.test_session_test_session_id_seq OWNER TO msbadmin;

--
-- TOC entry 6329 (class 0 OID 0)
-- Dependencies: 302
-- Name: test_session_test_session_id_seq; Type: SEQUENCE OWNED BY; Schema: ops; Owner: msbadmin
--

ALTER SEQUENCE ops.test_session_test_session_id_seq OWNED BY ops.test_session.test_session_id;


--
-- TOC entry 403 (class 1259 OID 20635)
-- Name: v_container_label_last_print; Type: VIEW; Schema: ops; Owner: msbadmin
--

CREATE VIEW ops.v_container_label_last_print AS
 SELECT DISTINCT ON (container_id) container_id,
    printed_at AS last_printed_at,
    printed_by_person_id,
    printed_by_text,
    print_method,
    label_orientation,
    label_qty,
    container_label
   FROM ops.container_label_print p
  ORDER BY container_id, printed_at DESC, container_label_print_id DESC;


ALTER VIEW ops.v_container_label_last_print OWNER TO msbadmin;

--
-- TOC entry 281 (class 1259 OID 16761)
-- Name: display_status; Type: TABLE; Schema: ref; Owner: msbadmin
--

CREATE TABLE ref.display_status (
    display_status_id integer NOT NULL,
    display_status_name text NOT NULL,
    description text NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    created_by text DEFAULT CURRENT_USER NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_by text DEFAULT CURRENT_USER NOT NULL,
    created_by_person_id bigint,
    updated_by_person_id bigint
);


ALTER TABLE ref.display_status OWNER TO msbadmin;

--
-- TOC entry 423 (class 1259 OID 23108)
-- Name: v_lor_display_reconciliation; Type: VIEW; Schema: ops; Owner: msbadmin
--

CREATE VIEW ops.v_lor_display_reconciliation AS
 WITH production AS (
         SELECT d.display_id,
            d.lor_prop_id,
            d.display_name,
            upper(btrim(d.display_name)) AS display_name_normalized,
            d.display_status_id,
            ds.display_status_name,
            (upper(btrim(ds.display_status_name)) = 'ACTIVE'::text) AS is_active
           FROM (ref.display d
             JOIN ref.display_status ds ON ((ds.display_status_id = d.display_status_id)))
        ), production_counts AS (
         SELECT pr.display_id,
            pr.lor_prop_id,
            pr.display_name,
            pr.display_name_normalized,
            pr.display_status_id,
            pr.display_status_name,
            pr.is_active,
            (count(*) OVER (PARTITION BY pr.lor_prop_id))::integer AS production_uuid_count,
            (count(*) OVER (PARTITION BY pr.display_name_normalized))::integer AS production_name_count
           FROM production pr
        ), source_with_matches AS (
         SELECT src.import_run_id,
            src.preview_id,
            src.preview_stage_id,
            src.preview_name,
            src.lor_prop_id,
            src.prop_name,
            src.prop_comment,
            src.display_name,
            src.display_name_normalized,
            src.string_type,
            src.color,
            src.is_spare,
            src.is_phantom,
            src.lor_uuid_row_count,
            src.lor_uuid_name_count,
            src.lor_name_uuid_count,
            src.source_prop_id,
            uuid_match.display_id AS uuid_display_id,
            uuid_match.display_name AS uuid_display_name,
            uuid_match.display_status_id AS uuid_display_status_id,
            uuid_match.display_status_name AS uuid_display_status_name,
            uuid_match.is_active AS uuid_is_active,
            COALESCE(uuid_match.production_uuid_count, 0) AS production_uuid_count,
            name_match.display_id AS name_display_id,
            name_match.display_name AS name_display_name,
            name_match.display_status_id AS name_display_status_id,
            name_match.display_status_name AS name_display_status_name,
            name_match.is_active AS name_is_active,
            name_match.lor_prop_id AS name_production_lor_prop_id,
            COALESCE(name_match.production_name_count, 0) AS production_name_count
           FROM ((lor_snap.v_display_reconciliation_source src
             LEFT JOIN production_counts uuid_match ON ((uuid_match.lor_prop_id = src.lor_prop_id)))
             LEFT JOIN production_counts name_match ON ((name_match.display_name_normalized = src.display_name_normalized)))
        ), occurrence_summary AS (
         SELECT o.import_run_id,
            o.lor_prop_id,
            (count(*))::integer AS occurrence_count,
            string_agg(DISTINCT
                CASE
                    WHEN (o.location_type = 'SCENE'::text) THEN format('preview "%s", scene "%s"'::text, COALESCE(o.preview_name, o.preview_id), COALESCE(o.scene_name, o.scene_id))
                    ELSE format('preview "%s"'::text, COALESCE(o.preview_name, o.preview_id))
                END, '; '::text ORDER BY
                CASE
                    WHEN (o.location_type = 'SCENE'::text) THEN format('preview "%s", scene "%s"'::text, COALESCE(o.preview_name, o.preview_id), COALESCE(o.scene_name, o.scene_id))
                    ELSE format('preview "%s"'::text, COALESCE(o.preview_name, o.preview_id))
                END) AS location_summary
           FROM lor_snap.v_display_lor_occurrence o
          GROUP BY o.import_run_id, o.lor_prop_id
        ), candidate_rows AS (
         SELECT swm.import_run_id,
            swm.lor_prop_id,
            swm.display_name AS lor_display_name,
            swm.display_name_normalized AS lor_display_name_normalized,
            swm.preview_id,
            swm.preview_name,
            swm.preview_stage_id,
            COALESCE(swm.uuid_display_id, swm.name_display_id) AS display_id,
            COALESCE(swm.uuid_display_name, swm.name_display_name) AS production_display_name,
            COALESCE(swm.uuid_display_status_id, swm.name_display_status_id) AS display_status_id,
            COALESCE(swm.uuid_display_status_name, swm.name_display_status_name) AS display_status_name,
            COALESCE(swm.uuid_is_active, swm.name_is_active) AS is_active,
            swm.lor_uuid_row_count,
            swm.lor_uuid_name_count,
            swm.lor_name_uuid_count,
            swm.production_uuid_count,
            swm.production_name_count,
            swm.uuid_display_id,
            swm.name_display_id,
            COALESCE(os.occurrence_count, 0) AS occurrence_count,
            os.location_summary,
                CASE
                    WHEN (swm.is_spare OR swm.is_phantom) THEN 'EXCLUDED_NONPHYSICAL'::text
                    WHEN ((swm.lor_uuid_name_count > 1) OR (swm.lor_uuid_row_count > 1)) THEN 'DUPLICATE_LOR_UUID'::text
                    WHEN (swm.lor_name_uuid_count > 1) THEN 'DUPLICATE_LOR_NAME'::text
                    WHEN (swm.production_uuid_count > 1) THEN 'DUPLICATE_PRODUCTION_UUID'::text
                    WHEN (swm.production_name_count > 1) THEN 'DUPLICATE_PRODUCTION_NAME'::text
                    WHEN ((swm.uuid_display_id IS NOT NULL) AND (swm.uuid_is_active = false)) THEN 'NONACTIVE_DISPLAY_PRESENT_IN_LOR'::text
                    WHEN ((swm.uuid_display_id IS NOT NULL) AND (swm.name_display_id = swm.uuid_display_id)) THEN 'EXACT_MATCH'::text
                    WHEN ((swm.uuid_display_id IS NOT NULL) AND (swm.name_display_id IS NULL)) THEN 'NAME_CHANGED_SAME_UUID'::text
                    WHEN ((swm.uuid_display_id IS NULL) AND (swm.name_display_id IS NOT NULL) AND (swm.name_is_active = false)) THEN 'NONACTIVE_DISPLAY_PRESENT_IN_LOR'::text
                    WHEN ((swm.uuid_display_id IS NULL) AND (swm.name_display_id IS NOT NULL)) THEN 'UUID_CHANGED_SAME_NAME'::text
                    WHEN ((swm.uuid_display_id IS NULL) AND (swm.name_display_id IS NULL)) THEN 'NEW_DISPLAY_CANDIDATE'::text
                    ELSE 'NAME_AND_UUID_CHANGED'::text
                END AS classification_code,
            swm.source_prop_id
           FROM (source_with_matches swm
             LEFT JOIN occurrence_summary os ON (((os.import_run_id = swm.import_run_id) AND (os.lor_prop_id = swm.lor_prop_id))))
        ), candidate_output AS (
         SELECT cr.import_run_id,
            cr.lor_prop_id,
            cr.lor_display_name,
            cr.lor_display_name_normalized,
            cr.preview_id,
            cr.preview_name,
            cr.preview_stage_id,
            cr.display_id,
            cr.production_display_name,
            cr.display_status_id,
            cr.display_status_name,
            cr.is_active,
            cr.lor_uuid_row_count,
            cr.lor_uuid_name_count,
            cr.lor_name_uuid_count,
            cr.production_uuid_count,
            cr.production_name_count,
            cr.uuid_display_id,
            cr.name_display_id,
            cr.occurrence_count,
            cr.location_summary,
            cr.classification_code,
            (cr.classification_code <> ALL (ARRAY['EXACT_MATCH'::text, 'EXCLUDED_NONPHYSICAL'::text])) AS is_blocking,
                CASE cr.classification_code
                    WHEN 'EXACT_MATCH'::text THEN format('Display "%s" matches production display_id %s.'::text, cr.lor_display_name, cr.display_id)
                    WHEN 'NONACTIVE_DISPLAY_PRESENT_IN_LOR'::text THEN format('Display "%s" is non-active in PostgreSQL but remains in %s. Correct PostgreSQL status or remove it from LOR.'::text, cr.lor_display_name, COALESCE(cr.location_summary, 'the LOR snapshot'::text))
                    WHEN 'ACTIVE_DISPLAY_MISSING_FROM_LOR'::text THEN NULL::text
                    WHEN 'NAME_CHANGED_SAME_UUID'::text THEN format('LOR renamed production display_id %s from "%s" to "%s"; operator approval is required.'::text, cr.display_id, cr.production_display_name, cr.lor_display_name)
                    WHEN 'UUID_CHANGED_SAME_NAME'::text THEN format('Display "%s" has a new LOR UUID; operator approval is required for display_id %s.'::text, cr.lor_display_name, cr.display_id)
                    WHEN 'NEW_DISPLAY_CANDIDATE'::text THEN format('LOR display "%s" is not present in ref.display; operator approval is required to add it.'::text, cr.lor_display_name)
                    WHEN 'EXCLUDED_NONPHYSICAL'::text THEN format('LOR prop "%s" is classified as SPARE or PHANTOM and is excluded from physical-display identity reconciliation.'::text, cr.lor_display_name)
                    ELSE format('Display "%s" has blocking reconciliation classification %s.'::text, cr.lor_display_name, cr.classification_code)
                END AS operator_message,
                CASE cr.classification_code
                    WHEN 'EXACT_MATCH'::text THEN ARRAY['NONE'::text]
                    WHEN 'EXCLUDED_NONPHYSICAL'::text THEN ARRAY['NONE'::text]
                    WHEN 'NONACTIVE_DISPLAY_PRESENT_IN_LOR'::text THEN ARRAY['CORRECT_POSTGRES_STATUS'::text, 'CORRECT_LOR_AND_REINGEST'::text]
                    WHEN 'ACTIVE_DISPLAY_MISSING_FROM_LOR'::text THEN ARRAY['CORRECT_POSTGRES_STATUS'::text, 'CORRECT_LOR_AND_REINGEST'::text]
                    WHEN 'NAME_CHANGED_SAME_UUID'::text THEN ARRAY['APPROVE_LOR_RENAME'::text]
                    WHEN 'UUID_CHANGED_SAME_NAME'::text THEN ARRAY['APPROVE_LOR_UUID_CHANGE'::text]
                    WHEN 'NEW_DISPLAY_CANDIDATE'::text THEN ARRAY['APPROVE_NEW_LOR_DISPLAY'::text]
                    ELSE ARRAY['CORRECT_LOR_AND_REINGEST'::text, 'DEFER'::text]
                END AS allowed_resolution_paths,
            cr.source_prop_id
           FROM candidate_rows cr
        ), run_ids AS (
         SELECT import_run.import_run_id
           FROM lor_snap.import_run
        ), missing_active AS (
         SELECT r.import_run_id,
            pc.lor_prop_id,
            NULL::text AS lor_display_name,
            NULL::text AS lor_display_name_normalized,
            NULL::text AS preview_id,
            NULL::text AS preview_name,
            NULL::text AS preview_stage_id,
            pc.display_id,
            pc.display_name AS production_display_name,
            pc.display_status_id,
            pc.display_status_name,
            pc.is_active,
            0 AS lor_uuid_row_count,
            0 AS lor_uuid_name_count,
            0 AS lor_name_uuid_count,
            pc.production_uuid_count,
            pc.production_name_count,
            NULL::bigint AS uuid_display_id,
            NULL::bigint AS name_display_id,
            0 AS occurrence_count,
            NULL::text AS location_summary,
            'ACTIVE_DISPLAY_MISSING_FROM_LOR'::text AS classification_code,
            true AS is_blocking,
            format('Active PostgreSQL display "%s" (display_id %s) is missing from the authoritative LOR display source. Restore it in LOR or correct its PostgreSQL status.'::text, pc.display_name, pc.display_id) AS operator_message,
            ARRAY['CORRECT_POSTGRES_STATUS'::text, 'CORRECT_LOR_AND_REINGEST'::text] AS allowed_resolution_paths,
            NULL::text AS source_prop_id
           FROM (run_ids r
             CROSS JOIN production_counts pc)
          WHERE (pc.is_active AND (NOT (EXISTS ( SELECT 1
                   FROM lor_snap.v_display_reconciliation_source src
                  WHERE ((src.import_run_id = r.import_run_id) AND (NOT src.is_spare) AND (NOT src.is_phantom) AND ((src.lor_prop_id = pc.lor_prop_id) OR (src.display_name_normalized = pc.display_name_normalized)))))))
        )
 SELECT candidate_output.import_run_id,
    candidate_output.lor_prop_id,
    candidate_output.lor_display_name,
    candidate_output.lor_display_name_normalized,
    candidate_output.preview_id,
    candidate_output.preview_name,
    candidate_output.preview_stage_id,
    candidate_output.display_id,
    candidate_output.production_display_name,
    candidate_output.display_status_id,
    candidate_output.display_status_name,
    candidate_output.is_active,
    candidate_output.lor_uuid_row_count,
    candidate_output.lor_uuid_name_count,
    candidate_output.lor_name_uuid_count,
    candidate_output.production_uuid_count,
    candidate_output.production_name_count,
    candidate_output.uuid_display_id,
    candidate_output.name_display_id,
    candidate_output.occurrence_count,
    candidate_output.location_summary,
    candidate_output.classification_code,
    candidate_output.is_blocking,
    candidate_output.operator_message,
    candidate_output.allowed_resolution_paths,
    candidate_output.source_prop_id
   FROM candidate_output
UNION ALL
 SELECT missing_active.import_run_id,
    missing_active.lor_prop_id,
    missing_active.lor_display_name,
    missing_active.lor_display_name_normalized,
    missing_active.preview_id,
    missing_active.preview_name,
    missing_active.preview_stage_id,
    missing_active.display_id,
    missing_active.production_display_name,
    missing_active.display_status_id,
    missing_active.display_status_name,
    missing_active.is_active,
    missing_active.lor_uuid_row_count,
    missing_active.lor_uuid_name_count,
    missing_active.lor_name_uuid_count,
    missing_active.production_uuid_count,
    missing_active.production_name_count,
    missing_active.uuid_display_id,
    missing_active.name_display_id,
    missing_active.occurrence_count,
    missing_active.location_summary,
    missing_active.classification_code,
    missing_active.is_blocking,
    missing_active.operator_message,
    missing_active.allowed_resolution_paths,
    missing_active.source_prop_id
   FROM missing_active;


ALTER VIEW ops.v_lor_display_reconciliation OWNER TO msbadmin;

--
-- TOC entry 6333 (class 0 OID 0)
-- Dependencies: 423
-- Name: VIEW v_lor_display_reconciliation; Type: COMMENT; Schema: ops; Owner: msbadmin
--

COMMENT ON VIEW ops.v_lor_display_reconciliation IS 'Live bidirectional display preflight by explicit import_run_id. Exact matches pass automatically; identity, status, duplicate, and missing-display discrepancies block.';


--
-- TOC entry 462 (class 1259 OID 24036)
-- Name: v_lor_reconciliation_display_name_change_audit; Type: VIEW; Schema: ops; Owner: msbadmin
--

CREATE VIEW ops.v_lor_reconciliation_display_name_change_audit AS
 WITH latest_action AS (
         SELECT DISTINCT ON (a.lor_reconciliation_group_id) a.lor_reconciliation_group_id,
            a.lor_reconciliation_action_id,
            a.action_type
           FROM ops.lor_reconciliation_action a
          WHERE (a.lor_reconciliation_group_id IS NOT NULL)
          ORDER BY a.lor_reconciliation_group_id, a.acted_at DESC, a.lor_reconciliation_action_id DESC
        ), resolved_candidate AS (
         SELECT c.lor_reconciliation_run_id,
            c.import_run_id,
            c.lor_reconciliation_display_candidate_id,
                CASE
                    WHEN (la.action_type = 'REASSOCIATE_DISPLAY'::text) THEN aa.target_display_id
                    ELSE c.display_id
                END AS target_display_id,
            c.current_display_name,
            c.proposed_display_name
           FROM ((ops.lor_reconciliation_display_candidate c
             LEFT JOIN latest_action la ON ((la.lor_reconciliation_group_id = c.lor_reconciliation_group_id)))
             LEFT JOIN ops.lor_reconciliation_action_assignment aa ON (((aa.lor_reconciliation_action_id = la.lor_reconciliation_action_id) AND (aa.lor_reconciliation_display_candidate_id = c.lor_reconciliation_display_candidate_id))))
          WHERE (c.candidate_class = 'PHYSICAL_DISPLAY'::text)
        )
 SELECT DISTINCT r.lor_reconciliation_run_id,
    r.import_run_id,
    r.recorded_at,
    rc.target_display_id AS display_id,
    rc.current_display_name AS before_name,
    rc.proposed_display_name AS after_name,
    'Print replacement label'::text AS follow_up
   FROM (ops.lor_reconciliation_result r
     JOIN resolved_candidate rc ON (((rc.lor_reconciliation_run_id = r.lor_reconciliation_run_id) AND (rc.import_run_id = r.import_run_id) AND ((rc.target_display_id)::text = r.entity_key))))
  WHERE ((r.entity_type = 'DISPLAY'::text) AND (r.committed IS TRUE) AND (r.result_class = ANY (ARRAY['UPDATED'::text, 'REASSOCIATED'::text])) AND (r.entity_key ~ '^[0-9]+$'::text) AND (rc.current_display_name IS DISTINCT FROM rc.proposed_display_name));


ALTER VIEW ops.v_lor_reconciliation_display_name_change_audit OWNER TO msbadmin;

--
-- TOC entry 6335 (class 0 OID 0)
-- Dependencies: 462
-- Name: VIEW v_lor_reconciliation_display_name_change_audit; Type: COMMENT; Schema: ops; Owner: msbadmin
--

COMMENT ON VIEW ops.v_lor_reconciliation_display_name_change_audit IS 'Committed display-name changes with permanent display_id, frozen before/after names, and the fixed instruction Print replacement label.';


--
-- TOC entry 442 (class 1259 OID 23562)
-- Name: v_lor_reconciliation_group_review; Type: VIEW; Schema: ops; Owner: msbadmin
--

CREATE VIEW ops.v_lor_reconciliation_group_review AS
 WITH latest_action AS (
         SELECT DISTINCT ON (a.lor_reconciliation_group_id) a.lor_reconciliation_group_id,
            a.lor_reconciliation_action_id,
            a.action_type,
            a.reason,
            a.acted_at,
            a.acted_by,
            a.acted_by_application
           FROM ops.lor_reconciliation_action a
          WHERE (a.lor_reconciliation_group_id IS NOT NULL)
          ORDER BY a.lor_reconciliation_group_id, a.acted_at DESC, a.lor_reconciliation_action_id DESC
        )
 SELECT g.lor_reconciliation_group_id,
    g.lor_reconciliation_run_id,
    g.import_run_id,
    g.entity_type,
    g.logical_group_key,
    g.group_kind,
    g.member_count,
    g.requires_atomic_decision,
    g.decision_required,
        CASE
            WHEN (ops.f_stage_group_can_preserve_existing_metadata(g.lor_reconciliation_group_id) AND (NOT ('PRESERVE_EXISTING_STAGE_METADATA'::text = ANY (g.allowed_action_types)))) THEN array_append(g.allowed_action_types, 'PRESERVE_EXISTING_STAGE_METADATA'::text)
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
            WHEN (la.action_type = 'DEFER'::text) THEN 'DEFERRED'::text
            WHEN (la.action_type = 'CORRECT_SOURCE_REQUIRED'::text) THEN 'BLOCKED'::text
            WHEN (la.action_type IS NOT NULL) THEN 'APPROVED'::text
            WHEN g.decision_required THEN 'UNRESOLVED'::text
            ELSE 'AUTO_APPROVED'::text
        END AS effective_resolution_state
   FROM (ops.lor_reconciliation_group g
     LEFT JOIN latest_action la ON ((la.lor_reconciliation_group_id = g.lor_reconciliation_group_id)));


ALTER VIEW ops.v_lor_reconciliation_group_review OWNER TO msbadmin;

--
-- TOC entry 6337 (class 0 OID 0)
-- Dependencies: 442
-- Name: VIEW v_lor_reconciliation_group_review; Type: COMMENT; Schema: ops; Owner: msbadmin
--

COMMENT ON VIEW ops.v_lor_reconciliation_group_review IS 'One row per persisted logical group with its latest append-only action, effective state, and stage-preservation action exposed only for eligible multi-preview stage groups.';


--
-- TOC entry 344 (class 1259 OID 18094)
-- Name: stage; Type: TABLE; Schema: ref; Owner: msbadmin
--

CREATE TABLE ref.stage (
    stage_id integer NOT NULL,
    stage_key text,
    stage_name text,
    short_code text,
    folder_name text,
    folder_path text,
    notes text,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_by text DEFAULT CURRENT_USER NOT NULL,
    park_order integer,
    sub_order integer,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    created_by text DEFAULT CURRENT_USER NOT NULL,
    parent_stage_key text,
    created_by_person_id bigint,
    updated_by_person_id bigint
);


ALTER TABLE ref.stage OWNER TO msbadmin;

--
-- TOC entry 443 (class 1259 OID 23567)
-- Name: v_lor_reconciliation_operator_display_review; Type: VIEW; Schema: ops; Owner: msbadmin
--

CREATE VIEW ops.v_lor_reconciliation_operator_display_review AS
 SELECT gr.lor_reconciliation_run_id,
    gr.import_run_id,
    gr.lor_reconciliation_group_id,
    gr.logical_group_key,
    gr.group_kind,
    gr.member_count,
    gr.requires_atomic_decision,
    gr.effective_resolution_state,
    gr.allowed_action_types,
    gr.effective_action_type,
    gr.effective_reason,
    c.lor_reconciliation_display_candidate_id,
    c.classification_code,
    c.changed_fields,
    c.current_display_name,
    c.proposed_display_name,
    current_stage.stage_key AS current_stage_key,
    current_stage.stage_name AS current_stage_name,
    c.proposed_stage_key,
    proposed_stage.stage_name AS proposed_stage_name,
    c.preview_name,
    c.location_summary,
    c.current_string_type,
    c.proposed_string_type,
    c.operator_message,
    c.display_id,
    c.source_prop_id,
    c.lor_prop_id,
    c.uuid_display_id,
    c.name_display_id,
    c.source_evidence
   FROM (((ops.v_lor_reconciliation_group_review gr
     JOIN ops.lor_reconciliation_display_candidate c ON ((c.lor_reconciliation_group_id = gr.lor_reconciliation_group_id)))
     LEFT JOIN ref.stage current_stage ON ((current_stage.stage_id = c.current_stage_id)))
     LEFT JOIN ref.stage proposed_stage ON ((proposed_stage.stage_id = c.proposed_stage_id)))
  WHERE ((c.candidate_class <> 'EXCLUDED_NONPHYSICAL'::text) AND ((cardinality(c.changed_fields) > 0) OR c.decision_required OR c.is_blocking OR (gr.effective_action_type IS NOT NULL)));


ALTER VIEW ops.v_lor_reconciliation_operator_display_review OWNER TO msbadmin;

--
-- TOC entry 6340 (class 0 OID 0)
-- Dependencies: 443
-- Name: VIEW v_lor_reconciliation_operator_display_review; Type: COMMENT; Schema: ops; Owner: msbadmin
--

COMMENT ON VIEW ops.v_lor_reconciliation_operator_display_review IS 'Directus-ready persisted display review rows. Internal IDs remain available for safe action calls; production writes are not performed.';


--
-- TOC entry 455 (class 1259 OID 23800)
-- Name: v_lor_reconciliation_operator_scene_display_review; Type: VIEW; Schema: ops; Owner: msbadmin
--

CREATE VIEW ops.v_lor_reconciliation_operator_scene_display_review AS
 SELECT lor_reconciliation_run_id,
    import_run_id,
    lor_reconciliation_group_id,
    preview_id,
    scene_id,
    source_prop_id,
    source_lor_prop_id,
    frozen_display_id,
    classification_code,
    is_blocking,
    operator_message,
    source_evidence
   FROM ops.lor_reconciliation_scene_display_candidate c;


ALTER VIEW ops.v_lor_reconciliation_operator_scene_display_review OWNER TO msbadmin;

--
-- TOC entry 454 (class 1259 OID 23796)
-- Name: v_lor_reconciliation_operator_scene_review; Type: VIEW; Schema: ops; Owner: msbadmin
--

CREATE VIEW ops.v_lor_reconciliation_operator_scene_review AS
 SELECT lor_reconciliation_run_id,
    import_run_id,
    lor_reconciliation_group_id,
    preview_id,
    scene_id,
    scene_name,
    resolved_stage_key,
    resolved_stage_id,
    classification_code,
    changed_fields,
    is_blocking,
    operator_message,
    source_evidence
   FROM ops.lor_reconciliation_scene_candidate c;


ALTER VIEW ops.v_lor_reconciliation_operator_scene_review OWNER TO msbadmin;

--
-- TOC entry 449 (class 1259 OID 23659)
-- Name: v_lor_reconciliation_operator_stage_review; Type: VIEW; Schema: ops; Owner: msbadmin
--

CREATE VIEW ops.v_lor_reconciliation_operator_stage_review AS
 SELECT gr.lor_reconciliation_run_id,
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
   FROM (ops.v_lor_reconciliation_group_review gr
     JOIN ops.lor_reconciliation_stage_candidate c ON ((c.lor_reconciliation_group_id = gr.lor_reconciliation_group_id)))
  WHERE ((cardinality(c.changed_fields) > 0) OR c.decision_required OR (gr.effective_action_type IS NOT NULL));


ALTER VIEW ops.v_lor_reconciliation_operator_stage_review OWNER TO msbadmin;

--
-- TOC entry 444 (class 1259 OID 23572)
-- Name: v_lor_reconciliation_run_review; Type: VIEW; Schema: ops; Owner: msbadmin
--

CREATE VIEW ops.v_lor_reconciliation_run_review AS
 SELECT r.lor_reconciliation_run_id,
    r.import_run_id,
    r.status,
    r.started_at,
    r.started_by,
    r.started_by_application,
    (count(DISTINCT g.lor_reconciliation_group_id))::integer AS logical_group_count,
    (count(c.*))::integer AS display_candidate_count,
    (count(DISTINCT g.lor_reconciliation_group_id) FILTER (WHERE (gr.effective_resolution_state = 'AUTO_APPROVED'::text)))::integer AS auto_approved_group_count,
    (count(DISTINCT g.lor_reconciliation_group_id) FILTER (WHERE (gr.effective_resolution_state = 'APPROVED'::text)))::integer AS approved_group_count,
    (count(DISTINCT g.lor_reconciliation_group_id) FILTER (WHERE (gr.effective_resolution_state = 'DEFERRED'::text)))::integer AS deferred_group_count,
    (count(DISTINCT g.lor_reconciliation_group_id) FILTER (WHERE (gr.effective_resolution_state = 'BLOCKED'::text)))::integer AS blocked_group_count,
    (count(DISTINCT g.lor_reconciliation_group_id) FILTER (WHERE (gr.effective_resolution_state = 'UNRESOLVED'::text)))::integer AS unresolved_group_count,
    r.superseded_at,
    r.superseded_by_run_id,
    r.supersession_reason
   FROM (((ops.lor_reconciliation_run r
     LEFT JOIN ops.lor_reconciliation_group g ON ((g.lor_reconciliation_run_id = r.lor_reconciliation_run_id)))
     LEFT JOIN ops.v_lor_reconciliation_group_review gr ON ((gr.lor_reconciliation_group_id = g.lor_reconciliation_group_id)))
     LEFT JOIN ops.lor_reconciliation_display_candidate c ON ((c.lor_reconciliation_group_id = g.lor_reconciliation_group_id)))
  GROUP BY r.lor_reconciliation_run_id, r.import_run_id, r.status, r.started_at, r.started_by, r.started_by_application, r.superseded_at, r.superseded_by_run_id, r.supersession_reason;


ALTER VIEW ops.v_lor_reconciliation_run_review OWNER TO msbadmin;

--
-- TOC entry 6345 (class 0 OID 0)
-- Dependencies: 444
-- Name: VIEW v_lor_reconciliation_run_review; Type: COMMENT; Schema: ops; Owner: msbadmin
--

COMMENT ON VIEW ops.v_lor_reconciliation_run_review IS 'One row per independent reconciliation attempt, including supersession lineage and frozen decision-state counts.';


--
-- TOC entry 461 (class 1259 OID 23927)
-- Name: v_lor_reconciliation_source_run; Type: VIEW; Schema: ops; Owner: msbadmin
--

CREATE VIEW ops.v_lor_reconciliation_source_run AS
 SELECT lor_reconciliation_run_id,
    import_run_id,
    run_ts,
    notes,
    parser_version,
    parser_started_at,
    parser_completed_at,
    parser_actor,
    parser_host,
    source_preview_folder,
    source_sqlite_path,
    preview_count,
    scene_count,
    prop_count,
    sub_prop_count,
    dmx_channel_count,
    scene_lor_prop_count,
    ingest_script_version,
    ingest_actor,
    ingest_host,
    ingest_started_at,
    ingest_completed_at,
    frozen_at,
    ( SELECT count(*) AS count
           FROM ops.lor_reconciliation_source_preview p
          WHERE (p.lor_reconciliation_run_id = sr.lor_reconciliation_run_id)) AS frozen_preview_count,
    ( SELECT count(*) AS count
           FROM ops.lor_reconciliation_source_scene s
          WHERE (s.lor_reconciliation_run_id = sr.lor_reconciliation_run_id)) AS frozen_scene_count
   FROM ops.lor_reconciliation_source_run sr;


ALTER VIEW ops.v_lor_reconciliation_source_run OWNER TO msbadmin;

--
-- TOC entry 363 (class 1259 OID 18813)
-- Name: v_stage_container_contents; Type: VIEW; Schema: ops; Owner: msbadmin
--

CREATE VIEW ops.v_stage_container_contents AS
 SELECT s.stage_name,
    d.container_id,
    ts.container_status_legacy AS container_status,
    d.display_id,
    d.display_name,
    d.string_type,
    d.color
   FROM ((ref.display d
     LEFT JOIN ref.stage s ON ((s.stage_id = d.stage_id)))
     LEFT JOIN ops.test_session ts ON ((ts.container_id = d.container_id)));


ALTER VIEW ops.v_stage_container_contents OWNER TO msbadmin;

--
-- TOC entry 364 (class 1259 OID 18869)
-- Name: v_test_session_container_box; Type: VIEW; Schema: ops; Owner: msbadmin
--

CREATE VIEW ops.v_test_session_container_box AS
 SELECT ts.test_session_id AS id,
    ts.test_session_id,
    ts.season_year,
    ts.container_status_legacy AS status,
    ts.container_id,
    ts.home_location_code,
    ts.work_location_code,
    ts.pulled_at,
    ts.pulled_by,
    ts.returned_to_storage_at,
    ts.returned_to_storage_by,
    ts.done_at,
    ts.done_by,
    ts.remaining_notes,
    ts.notes AS test_session_notes,
    ts.tag_state,
    ts.legacy_flag,
    c.location_code AS container_location_code,
    c.container_type_id,
    c.description AS container_description,
    c.notes AS container_notes,
    c.year_built AS container_year_built,
    c.width_in_override,
    c.depth_in_override,
    c.height_in_override,
    c.goes_to,
    c.display_pallet,
    c.testing_after_takedown,
    c.display_pallet_flag
   FROM (ops.test_session ts
     JOIN ref.container c ON ((c.container_id = ts.container_id)));


ALTER VIEW ops.v_test_session_container_box OWNER TO msbadmin;

--
-- TOC entry 365 (class 1259 OID 18879)
-- Name: v_test_session_container_box_ui; Type: VIEW; Schema: ops; Owner: msbadmin
--

CREATE VIEW ops.v_test_session_container_box_ui AS
 SELECT ts.test_session_id AS id,
    ts.test_session_id,
    ts.season_year,
    ts.container_status_legacy AS status,
    ts.container_id,
    ts.home_location_code,
    ts.work_location_code,
    ts.pulled_at,
    ts.pulled_by,
    ts.done_at,
    ts.done_by,
    ts.remaining_notes,
    ts.notes AS test_session_notes,
    c.location_code AS container_location_code,
    c.container_type_id,
    c.description AS container_description,
    c.notes AS container_notes,
    c.year_built AS container_year_built,
    c.width_in_override,
    c.depth_in_override,
    c.height_in_override,
    c.goes_to,
    c.testing_after_takedown,
    c.display_pallet_flag
   FROM (ops.test_session ts
     JOIN ref.container c ON ((c.container_id = ts.container_id)));


ALTER VIEW ops.v_test_session_container_box_ui OWNER TO msbadmin;

--
-- TOC entry 368 (class 1259 OID 18939)
-- Name: container_test_status; Type: TABLE; Schema: ref; Owner: msbadmin
--

CREATE TABLE ref.container_test_status (
    container_test_status_id integer NOT NULL,
    container_test_status_code text NOT NULL,
    container_test_status_name text NOT NULL,
    sort_order integer DEFAULT 100 NOT NULL,
    active_flag boolean DEFAULT true NOT NULL,
    created_at timestamp with time zone,
    created_by text,
    created_by_person_id integer,
    updated_at timestamp with time zone,
    updated_by text,
    updated_by_person_id integer
);


ALTER TABLE ref.container_test_status OWNER TO msbadmin;

--
-- TOC entry 379 (class 1259 OID 19131)
-- Name: v_test_session_insights; Type: VIEW; Schema: ops; Owner: msbadmin
--

CREATE VIEW ops.v_test_session_insights AS
 SELECT ts.test_session_id,
    ts.container_id,
    ts.home_location_code,
    ts.work_location_code,
    ts.container_test_status_id AS container_test_status_id_num,
    cts.container_test_status_name,
        CASE
            WHEN (ts.container_test_status_id = 2) THEN 1
            WHEN (ts.container_test_status_id = 1) THEN 2
            WHEN (ts.container_test_status_id = 3) THEN 3
            ELSE 9
        END AS status_sort
   FROM (ops.test_session ts
     JOIN ref.container_test_status cts ON ((ts.container_test_status_id = cts.container_test_status_id)))
  WHERE (ts.container_test_status_id <> 4);


ALTER VIEW ops.v_test_session_insights OWNER TO msbadmin;

--
-- TOC entry 374 (class 1259 OID 19008)
-- Name: work_order_assignment; Type: TABLE; Schema: ops; Owner: directus_app
--

CREATE TABLE ops.work_order_assignment (
    work_order_assignment_id bigint NOT NULL,
    work_order_id bigint NOT NULL,
    person_id integer NOT NULL,
    assignment_role text DEFAULT 'ASSIGNEE'::text NOT NULL,
    active_flag boolean DEFAULT true NOT NULL,
    assigned_at timestamp with time zone DEFAULT now() NOT NULL,
    assigned_by_person_id integer,
    unassigned_at timestamp with time zone,
    unassigned_by_person_id integer,
    notes text,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    created_by text DEFAULT CURRENT_USER NOT NULL,
    updated_by text DEFAULT CURRENT_USER NOT NULL,
    created_by_person_id integer,
    updated_by_person_id integer,
    work_order_url text GENERATED ALWAYS AS (('https://db.sheboyganlights.org/admin/content/work_order/'::text || (work_order_id)::text)) STORED
);


ALTER TABLE ops.work_order_assignment OWNER TO directus_app;

--
-- TOC entry 463 (class 1259 OID 24264)
-- Name: v_work_order_assignment_test; Type: VIEW; Schema: ops; Owner: msbadmin
--

CREATE VIEW ops.v_work_order_assignment_test AS
 SELECT work_order_assignment_id,
    work_order_id,
    person_id,
    active_flag,
    ('https://db.sheboyganlights.org/admin/content/work_order/'::text || (work_order_id)::text) AS work_order_url
   FROM ops.work_order_assignment wa;


ALTER VIEW ops.v_work_order_assignment_test OWNER TO msbadmin;

--
-- TOC entry 354 (class 1259 OID 18484)
-- Name: work_order; Type: TABLE; Schema: ops; Owner: directus_app
--

CREATE TABLE ops.work_order (
    work_order_id bigint NOT NULL,
    stage_id integer,
    work_area_id bigint,
    task_type_id bigint NOT NULL,
    urgency_id smallint,
    target_year integer,
    legacy_priority_raw text,
    problem text NOT NULL,
    notes text,
    photo_url text,
    date_completed timestamp with time zone,
    completed_by_person_id integer,
    completion_notes text,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    created_by_person_id integer NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_by_person_id integer NOT NULL,
    display_id bigint,
    display_test_session_id bigint,
    created_by text DEFAULT CURRENT_USER NOT NULL,
    updated_by text DEFAULT CURRENT_USER NOT NULL,
    repair_complete boolean DEFAULT false NOT NULL,
    source_intake_id bigint,
    submitted_by_person_id integer,
    submitted_at timestamp with time zone,
    source_system character varying(30),
    source_form_name character varying(30),
    triaged_at timestamp with time zone,
    triaged_by_person_id bigint,
    triage_notes text,
    is_active boolean DEFAULT true NOT NULL,
    CONSTRAINT ck_work_order_completion_required CHECK (((date_completed IS NULL) OR (completed_by_person_id IS NOT NULL))),
    CONSTRAINT ck_work_order_location_required CHECK (((stage_id IS NOT NULL) OR (work_area_id IS NOT NULL))),
    CONSTRAINT ck_work_order_target_year_reasonable CHECK (((target_year IS NULL) OR ((target_year >= 2000) AND (target_year <= 2100))))
);


ALTER TABLE ops.work_order OWNER TO directus_app;

--
-- TOC entry 6354 (class 0 OID 0)
-- Dependencies: 354
-- Name: COLUMN work_order.source_intake_id; Type: COMMENT; Schema: ops; Owner: directus_app
--

COMMENT ON COLUMN ops.work_order.source_intake_id IS 'Original intake ID for audit/reference only. No FK — intake records are deleted after triage.';


--
-- TOC entry 373 (class 1259 OID 19007)
-- Name: work_order_assignment_work_order_assignment_id_seq; Type: SEQUENCE; Schema: ops; Owner: directus_app
--

ALTER TABLE ops.work_order_assignment ALTER COLUMN work_order_assignment_id ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME ops.work_order_assignment_work_order_assignment_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- TOC entry 378 (class 1259 OID 19069)
-- Name: work_order_outbound_message; Type: TABLE; Schema: ops; Owner: msbadmin
--

CREATE TABLE ops.work_order_outbound_message (
    outbound_message_id bigint NOT NULL,
    work_order_id bigint NOT NULL,
    channel text DEFAULT 'EMAIL'::text NOT NULL,
    template_key text,
    to_address text,
    subject text,
    body_preview text,
    sent_flag boolean DEFAULT false NOT NULL,
    sent_at timestamp with time zone,
    provider_message_id text,
    error_text text,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    created_by_person_id bigint,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_by_person_id bigint,
    created_by text DEFAULT CURRENT_USER NOT NULL,
    updated_by text DEFAULT CURRENT_USER NOT NULL
);


ALTER TABLE ops.work_order_outbound_message OWNER TO msbadmin;

--
-- TOC entry 377 (class 1259 OID 19068)
-- Name: work_order_outbound_message_outbound_message_id_seq; Type: SEQUENCE; Schema: ops; Owner: msbadmin
--

ALTER TABLE ops.work_order_outbound_message ALTER COLUMN outbound_message_id ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME ops.work_order_outbound_message_outbound_message_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- TOC entry 376 (class 1259 OID 19044)
-- Name: work_order_status_history; Type: TABLE; Schema: ops; Owner: msbadmin
--

CREATE TABLE ops.work_order_status_history (
    work_order_status_history_id bigint NOT NULL,
    work_order_id bigint NOT NULL,
    work_order_status_id bigint NOT NULL,
    changed_at timestamp with time zone DEFAULT now() NOT NULL,
    changed_by_person_id bigint,
    notes text
);


ALTER TABLE ops.work_order_status_history OWNER TO msbadmin;

--
-- TOC entry 375 (class 1259 OID 19043)
-- Name: work_order_status_history_work_order_status_history_id_seq; Type: SEQUENCE; Schema: ops; Owner: msbadmin
--

ALTER TABLE ops.work_order_status_history ALTER COLUMN work_order_status_history_id ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME ops.work_order_status_history_work_order_status_history_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- TOC entry 353 (class 1259 OID 18483)
-- Name: work_order_work_order_id_seq; Type: SEQUENCE; Schema: ops; Owner: directus_app
--

CREATE SEQUENCE ops.work_order_work_order_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE ops.work_order_work_order_id_seq OWNER TO directus_app;

--
-- TOC entry 6359 (class 0 OID 0)
-- Dependencies: 353
-- Name: work_order_work_order_id_seq; Type: SEQUENCE OWNED BY; Schema: ops; Owner: directus_app
--

ALTER SEQUENCE ops.work_order_work_order_id_seq OWNED BY ops.work_order.work_order_id;


--
-- TOC entry 338 (class 1259 OID 17944)
-- Name: directus_access; Type: TABLE; Schema: public; Owner: directus_app
--

CREATE TABLE public.directus_access (
    id uuid NOT NULL,
    role uuid,
    "user" uuid,
    policy uuid NOT NULL,
    sort integer
);


ALTER TABLE public.directus_access OWNER TO directus_app;

--
-- TOC entry 312 (class 1259 OID 17382)
-- Name: directus_activity; Type: TABLE; Schema: public; Owner: directus_app
--

CREATE TABLE public.directus_activity (
    id integer NOT NULL,
    action character varying(45) NOT NULL,
    "user" uuid,
    "timestamp" timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    ip character varying(50),
    user_agent text,
    collection character varying(64) NOT NULL,
    item character varying(255) NOT NULL,
    origin character varying(255)
);


ALTER TABLE public.directus_activity OWNER TO directus_app;

--
-- TOC entry 311 (class 1259 OID 17381)
-- Name: directus_activity_id_seq; Type: SEQUENCE; Schema: public; Owner: directus_app
--

CREATE SEQUENCE public.directus_activity_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.directus_activity_id_seq OWNER TO directus_app;

--
-- TOC entry 6360 (class 0 OID 0)
-- Dependencies: 311
-- Name: directus_activity_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: directus_app
--

ALTER SEQUENCE public.directus_activity_id_seq OWNED BY public.directus_activity.id;


--
-- TOC entry 306 (class 1259 OID 17320)
-- Name: directus_collections; Type: TABLE; Schema: public; Owner: directus_app
--

CREATE TABLE public.directus_collections (
    collection character varying(64) NOT NULL,
    icon character varying(64),
    note text,
    display_template character varying(255),
    hidden boolean DEFAULT false NOT NULL,
    singleton boolean DEFAULT false NOT NULL,
    translations json,
    archive_field character varying(64),
    archive_app_filter boolean DEFAULT true NOT NULL,
    archive_value character varying(255),
    unarchive_value character varying(255),
    sort_field character varying(64),
    accountability character varying(255) DEFAULT 'all'::character varying,
    color character varying(255),
    item_duplication_fields json,
    sort integer,
    "group" character varying(64),
    collapse character varying(255) DEFAULT 'open'::character varying NOT NULL,
    preview_url character varying(255),
    versioning boolean DEFAULT false NOT NULL
);


ALTER TABLE public.directus_collections OWNER TO directus_app;

--
-- TOC entry 339 (class 1259 OID 17968)
-- Name: directus_comments; Type: TABLE; Schema: public; Owner: directus_app
--

CREATE TABLE public.directus_comments (
    id uuid NOT NULL,
    collection character varying(64) NOT NULL,
    item character varying(255) NOT NULL,
    comment text NOT NULL,
    date_created timestamp with time zone DEFAULT CURRENT_TIMESTAMP,
    date_updated timestamp with time zone DEFAULT CURRENT_TIMESTAMP,
    user_created uuid,
    user_updated uuid
);


ALTER TABLE public.directus_comments OWNER TO directus_app;

--
-- TOC entry 327 (class 1259 OID 17691)
-- Name: directus_dashboards; Type: TABLE; Schema: public; Owner: directus_app
--

CREATE TABLE public.directus_dashboards (
    id uuid NOT NULL,
    name character varying(255) NOT NULL,
    icon character varying(64) DEFAULT 'dashboard'::character varying NOT NULL,
    note text,
    date_created timestamp with time zone DEFAULT CURRENT_TIMESTAMP,
    user_created uuid,
    color character varying(255)
);


ALTER TABLE public.directus_dashboards OWNER TO directus_app;

--
-- TOC entry 341 (class 1259 OID 18013)
-- Name: directus_deployment_projects; Type: TABLE; Schema: public; Owner: directus_app
--

CREATE TABLE public.directus_deployment_projects (
    id uuid NOT NULL,
    deployment uuid NOT NULL,
    external_id character varying(255) NOT NULL,
    name character varying(255) NOT NULL,
    date_created timestamp with time zone DEFAULT CURRENT_TIMESTAMP,
    user_created uuid,
    url character varying(255),
    framework character varying(255),
    deployable boolean DEFAULT true NOT NULL
);


ALTER TABLE public.directus_deployment_projects OWNER TO directus_app;

--
-- TOC entry 342 (class 1259 OID 18033)
-- Name: directus_deployment_runs; Type: TABLE; Schema: public; Owner: directus_app
--

CREATE TABLE public.directus_deployment_runs (
    id uuid NOT NULL,
    project uuid NOT NULL,
    external_id character varying(255) NOT NULL,
    target character varying(255) NOT NULL,
    date_created timestamp with time zone DEFAULT CURRENT_TIMESTAMP,
    user_created uuid,
    status character varying(255),
    url character varying(255),
    started_at timestamp with time zone,
    completed_at timestamp with time zone
);


ALTER TABLE public.directus_deployment_runs OWNER TO directus_app;

--
-- TOC entry 340 (class 1259 OID 17998)
-- Name: directus_deployments; Type: TABLE; Schema: public; Owner: directus_app
--

CREATE TABLE public.directus_deployments (
    id uuid NOT NULL,
    provider character varying(255) NOT NULL,
    credentials text,
    options text,
    date_created timestamp with time zone DEFAULT CURRENT_TIMESTAMP,
    user_created uuid,
    webhook_ids json,
    webhook_secret character varying(255),
    last_synced_at timestamp with time zone
);


ALTER TABLE public.directus_deployments OWNER TO directus_app;

--
-- TOC entry 336 (class 1259 OID 17900)
-- Name: directus_extensions; Type: TABLE; Schema: public; Owner: directus_app
--

CREATE TABLE public.directus_extensions (
    enabled boolean DEFAULT true NOT NULL,
    id uuid NOT NULL,
    folder character varying(255) NOT NULL,
    source character varying(255) NOT NULL,
    bundle uuid
);


ALTER TABLE public.directus_extensions OWNER TO directus_app;

--
-- TOC entry 310 (class 1259 OID 17359)
-- Name: directus_fields; Type: TABLE; Schema: public; Owner: directus_app
--

CREATE TABLE public.directus_fields (
    id integer NOT NULL,
    collection character varying(64) NOT NULL,
    field character varying(64) NOT NULL,
    special character varying(64),
    interface character varying(64),
    options json,
    display character varying(64),
    display_options json,
    readonly boolean DEFAULT false NOT NULL,
    hidden boolean DEFAULT false NOT NULL,
    sort integer,
    width character varying(30) DEFAULT 'full'::character varying,
    translations json,
    note text,
    conditions json,
    required boolean DEFAULT false,
    "group" character varying(64),
    validation json,
    validation_message text,
    searchable boolean DEFAULT true NOT NULL
);


ALTER TABLE public.directus_fields OWNER TO directus_app;

--
-- TOC entry 309 (class 1259 OID 17358)
-- Name: directus_fields_id_seq; Type: SEQUENCE; Schema: public; Owner: directus_app
--

CREATE SEQUENCE public.directus_fields_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.directus_fields_id_seq OWNER TO directus_app;

--
-- TOC entry 6362 (class 0 OID 0)
-- Dependencies: 309
-- Name: directus_fields_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: directus_app
--

ALTER SEQUENCE public.directus_fields_id_seq OWNED BY public.directus_fields.id;


--
-- TOC entry 314 (class 1259 OID 17406)
-- Name: directus_files; Type: TABLE; Schema: public; Owner: directus_app
--

CREATE TABLE public.directus_files (
    id uuid NOT NULL,
    storage character varying(255) NOT NULL,
    filename_disk character varying(255),
    filename_download character varying(255) NOT NULL,
    title character varying(255),
    type character varying(255),
    folder uuid,
    uploaded_by uuid,
    created_on timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    modified_by uuid,
    modified_on timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    charset character varying(50),
    filesize bigint,
    width integer,
    height integer,
    duration integer,
    embed character varying(200),
    description text,
    location text,
    tags text,
    metadata json,
    focal_point_x integer,
    focal_point_y integer,
    tus_id character varying(64),
    tus_data json,
    uploaded_on timestamp with time zone
);


ALTER TABLE public.directus_files OWNER TO directus_app;

--
-- TOC entry 332 (class 1259 OID 17805)
-- Name: directus_flows; Type: TABLE; Schema: public; Owner: directus_app
--

CREATE TABLE public.directus_flows (
    id uuid NOT NULL,
    name character varying(255) NOT NULL,
    icon character varying(64),
    color character varying(255),
    description text,
    status character varying(255) DEFAULT 'active'::character varying NOT NULL,
    trigger character varying(255),
    accountability character varying(255) DEFAULT 'all'::character varying,
    options json,
    operation uuid,
    date_created timestamp with time zone DEFAULT CURRENT_TIMESTAMP,
    user_created uuid
);


ALTER TABLE public.directus_flows OWNER TO directus_app;

--
-- TOC entry 313 (class 1259 OID 17396)
-- Name: directus_folders; Type: TABLE; Schema: public; Owner: directus_app
--

CREATE TABLE public.directus_folders (
    id uuid NOT NULL,
    name character varying(255) NOT NULL,
    parent uuid
);


ALTER TABLE public.directus_folders OWNER TO directus_app;

--
-- TOC entry 326 (class 1259 OID 17570)
-- Name: directus_migrations; Type: TABLE; Schema: public; Owner: directus_app
--

CREATE TABLE public.directus_migrations (
    version character varying(255) NOT NULL,
    name character varying(255) NOT NULL,
    "timestamp" timestamp with time zone DEFAULT CURRENT_TIMESTAMP
);


ALTER TABLE public.directus_migrations OWNER TO directus_app;

--
-- TOC entry 330 (class 1259 OID 17751)
-- Name: directus_notifications; Type: TABLE; Schema: public; Owner: directus_app
--

CREATE TABLE public.directus_notifications (
    id integer NOT NULL,
    "timestamp" timestamp with time zone DEFAULT CURRENT_TIMESTAMP,
    status character varying(255) DEFAULT 'inbox'::character varying,
    recipient uuid NOT NULL,
    sender uuid,
    subject character varying(255) NOT NULL,
    message text,
    collection character varying(64),
    item character varying(255)
);


ALTER TABLE public.directus_notifications OWNER TO directus_app;

--
-- TOC entry 329 (class 1259 OID 17750)
-- Name: directus_notifications_id_seq; Type: SEQUENCE; Schema: public; Owner: directus_app
--

CREATE SEQUENCE public.directus_notifications_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.directus_notifications_id_seq OWNER TO directus_app;

--
-- TOC entry 6364 (class 0 OID 0)
-- Dependencies: 329
-- Name: directus_notifications_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: directus_app
--

ALTER SEQUENCE public.directus_notifications_id_seq OWNED BY public.directus_notifications.id;


--
-- TOC entry 333 (class 1259 OID 17822)
-- Name: directus_operations; Type: TABLE; Schema: public; Owner: directus_app
--

CREATE TABLE public.directus_operations (
    id uuid NOT NULL,
    name character varying(255),
    key character varying(255) NOT NULL,
    type character varying(255) NOT NULL,
    position_x integer NOT NULL,
    position_y integer NOT NULL,
    options json,
    resolve uuid,
    reject uuid,
    flow uuid NOT NULL,
    date_created timestamp with time zone DEFAULT CURRENT_TIMESTAMP,
    user_created uuid
);


ALTER TABLE public.directus_operations OWNER TO directus_app;

--
-- TOC entry 328 (class 1259 OID 17705)
-- Name: directus_panels; Type: TABLE; Schema: public; Owner: directus_app
--

CREATE TABLE public.directus_panels (
    id uuid NOT NULL,
    dashboard uuid NOT NULL,
    name character varying(255),
    icon character varying(64) DEFAULT NULL::character varying,
    color character varying(10),
    show_header boolean DEFAULT false NOT NULL,
    note text,
    type character varying(255) NOT NULL,
    position_x integer NOT NULL,
    position_y integer NOT NULL,
    width integer NOT NULL,
    height integer NOT NULL,
    options json,
    date_created timestamp with time zone DEFAULT CURRENT_TIMESTAMP,
    user_created uuid
);


ALTER TABLE public.directus_panels OWNER TO directus_app;

--
-- TOC entry 316 (class 1259 OID 17432)
-- Name: directus_permissions; Type: TABLE; Schema: public; Owner: directus_app
--

CREATE TABLE public.directus_permissions (
    id integer NOT NULL,
    collection character varying(64) NOT NULL,
    action character varying(10) NOT NULL,
    permissions json,
    validation json,
    presets json,
    fields text,
    policy uuid NOT NULL
);


ALTER TABLE public.directus_permissions OWNER TO directus_app;

--
-- TOC entry 315 (class 1259 OID 17431)
-- Name: directus_permissions_id_seq; Type: SEQUENCE; Schema: public; Owner: directus_app
--

CREATE SEQUENCE public.directus_permissions_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.directus_permissions_id_seq OWNER TO directus_app;

--
-- TOC entry 6366 (class 0 OID 0)
-- Dependencies: 315
-- Name: directus_permissions_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: directus_app
--

ALTER SEQUENCE public.directus_permissions_id_seq OWNED BY public.directus_permissions.id;


--
-- TOC entry 337 (class 1259 OID 17923)
-- Name: directus_policies; Type: TABLE; Schema: public; Owner: directus_app
--

CREATE TABLE public.directus_policies (
    id uuid NOT NULL,
    name character varying(100) NOT NULL,
    icon character varying(64) DEFAULT 'badge'::character varying NOT NULL,
    description text,
    ip_access text,
    enforce_tfa boolean DEFAULT false NOT NULL,
    admin_access boolean DEFAULT false NOT NULL,
    app_access boolean DEFAULT false NOT NULL
);


ALTER TABLE public.directus_policies OWNER TO directus_app;

--
-- TOC entry 318 (class 1259 OID 17451)
-- Name: directus_presets; Type: TABLE; Schema: public; Owner: directus_app
--

CREATE TABLE public.directus_presets (
    id integer NOT NULL,
    bookmark character varying(255),
    "user" uuid,
    role uuid,
    collection character varying(64),
    search character varying(100),
    layout character varying(100) DEFAULT 'tabular'::character varying,
    layout_query json,
    layout_options json,
    refresh_interval integer,
    filter json,
    icon character varying(64) DEFAULT 'bookmark'::character varying,
    color character varying(255)
);


ALTER TABLE public.directus_presets OWNER TO directus_app;

--
-- TOC entry 317 (class 1259 OID 17450)
-- Name: directus_presets_id_seq; Type: SEQUENCE; Schema: public; Owner: directus_app
--

CREATE SEQUENCE public.directus_presets_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.directus_presets_id_seq OWNER TO directus_app;

--
-- TOC entry 6368 (class 0 OID 0)
-- Dependencies: 317
-- Name: directus_presets_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: directus_app
--

ALTER SEQUENCE public.directus_presets_id_seq OWNED BY public.directus_presets.id;


--
-- TOC entry 320 (class 1259 OID 17476)
-- Name: directus_relations; Type: TABLE; Schema: public; Owner: directus_app
--

CREATE TABLE public.directus_relations (
    id integer NOT NULL,
    many_collection character varying(64) NOT NULL,
    many_field character varying(64) NOT NULL,
    one_collection character varying(64),
    one_field character varying(64),
    one_collection_field character varying(64),
    one_allowed_collections text,
    junction_field character varying(64),
    sort_field character varying(64),
    one_deselect_action character varying(255) DEFAULT 'nullify'::character varying NOT NULL
);


ALTER TABLE public.directus_relations OWNER TO directus_app;

--
-- TOC entry 319 (class 1259 OID 17475)
-- Name: directus_relations_id_seq; Type: SEQUENCE; Schema: public; Owner: directus_app
--

CREATE SEQUENCE public.directus_relations_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.directus_relations_id_seq OWNER TO directus_app;

--
-- TOC entry 6370 (class 0 OID 0)
-- Dependencies: 319
-- Name: directus_relations_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: directus_app
--

ALTER SEQUENCE public.directus_relations_id_seq OWNED BY public.directus_relations.id;


--
-- TOC entry 322 (class 1259 OID 17495)
-- Name: directus_revisions; Type: TABLE; Schema: public; Owner: directus_app
--

CREATE TABLE public.directus_revisions (
    id integer NOT NULL,
    activity integer NOT NULL,
    collection character varying(64) NOT NULL,
    item character varying(255) NOT NULL,
    data json,
    delta json,
    parent integer,
    version uuid
);


ALTER TABLE public.directus_revisions OWNER TO directus_app;

--
-- TOC entry 321 (class 1259 OID 17494)
-- Name: directus_revisions_id_seq; Type: SEQUENCE; Schema: public; Owner: directus_app
--

CREATE SEQUENCE public.directus_revisions_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.directus_revisions_id_seq OWNER TO directus_app;

--
-- TOC entry 6372 (class 0 OID 0)
-- Dependencies: 321
-- Name: directus_revisions_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: directus_app
--

ALTER SEQUENCE public.directus_revisions_id_seq OWNED BY public.directus_revisions.id;


--
-- TOC entry 307 (class 1259 OID 17330)
-- Name: directus_roles; Type: TABLE; Schema: public; Owner: directus_app
--

CREATE TABLE public.directus_roles (
    id uuid NOT NULL,
    name character varying(100) NOT NULL,
    icon character varying(64) DEFAULT 'supervised_user_circle'::character varying NOT NULL,
    description text,
    parent uuid
);


ALTER TABLE public.directus_roles OWNER TO directus_app;

--
-- TOC entry 323 (class 1259 OID 17518)
-- Name: directus_sessions; Type: TABLE; Schema: public; Owner: directus_app
--

CREATE TABLE public.directus_sessions (
    token character varying(64) NOT NULL,
    "user" uuid,
    expires timestamp with time zone NOT NULL,
    ip character varying(255),
    user_agent text,
    share uuid,
    origin character varying(255),
    next_token character varying(64)
);


ALTER TABLE public.directus_sessions OWNER TO directus_app;

--
-- TOC entry 325 (class 1259 OID 17531)
-- Name: directus_settings; Type: TABLE; Schema: public; Owner: directus_app
--

CREATE TABLE public.directus_settings (
    id integer NOT NULL,
    project_name character varying(100) DEFAULT 'Directus'::character varying NOT NULL,
    project_url character varying(255),
    project_color character varying(255) DEFAULT '#6644FF'::character varying NOT NULL,
    project_logo uuid,
    public_foreground uuid,
    public_background uuid,
    public_note text,
    auth_login_attempts integer DEFAULT 25,
    auth_password_policy character varying(100),
    storage_asset_transform character varying(7) DEFAULT 'all'::character varying,
    storage_asset_presets json,
    custom_css text,
    storage_default_folder uuid,
    basemaps json,
    mapbox_key character varying(255),
    module_bar json,
    project_descriptor character varying(100),
    default_language character varying(255) DEFAULT 'en-US'::character varying NOT NULL,
    custom_aspect_ratios json,
    public_favicon uuid,
    default_appearance character varying(255) DEFAULT 'auto'::character varying NOT NULL,
    default_theme_light character varying(255),
    theme_light_overrides json,
    default_theme_dark character varying(255),
    theme_dark_overrides json,
    report_error_url character varying(255),
    report_bug_url character varying(255),
    report_feature_url character varying(255),
    public_registration boolean DEFAULT false NOT NULL,
    public_registration_verify_email boolean DEFAULT true NOT NULL,
    public_registration_role uuid,
    public_registration_email_filter json,
    visual_editor_urls json,
    project_id uuid,
    mcp_enabled boolean DEFAULT false NOT NULL,
    mcp_allow_deletes boolean DEFAULT false NOT NULL,
    mcp_prompts_collection character varying(255) DEFAULT NULL::character varying,
    mcp_system_prompt_enabled boolean DEFAULT true NOT NULL,
    mcp_system_prompt text,
    project_owner character varying(255),
    project_usage character varying(255),
    org_name character varying(255),
    product_updates boolean,
    project_status character varying(255),
    ai_openai_api_key text,
    ai_anthropic_api_key text,
    ai_system_prompt text,
    ai_google_api_key text,
    ai_openai_compatible_api_key text,
    ai_openai_compatible_base_url text,
    ai_openai_compatible_name text,
    ai_openai_compatible_models json,
    ai_openai_compatible_headers json,
    ai_openai_allowed_models json,
    ai_anthropic_allowed_models json,
    ai_google_allowed_models json,
    collaborative_editing_enabled boolean DEFAULT false NOT NULL
);


ALTER TABLE public.directus_settings OWNER TO directus_app;

--
-- TOC entry 324 (class 1259 OID 17530)
-- Name: directus_settings_id_seq; Type: SEQUENCE; Schema: public; Owner: directus_app
--

CREATE SEQUENCE public.directus_settings_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.directus_settings_id_seq OWNER TO directus_app;

--
-- TOC entry 6374 (class 0 OID 0)
-- Dependencies: 324
-- Name: directus_settings_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: directus_app
--

ALTER SEQUENCE public.directus_settings_id_seq OWNED BY public.directus_settings.id;


--
-- TOC entry 331 (class 1259 OID 17771)
-- Name: directus_shares; Type: TABLE; Schema: public; Owner: directus_app
--

CREATE TABLE public.directus_shares (
    id uuid NOT NULL,
    name character varying(255),
    collection character varying(64) NOT NULL,
    item character varying(255) NOT NULL,
    role uuid,
    password character varying(255),
    user_created uuid,
    date_created timestamp with time zone DEFAULT CURRENT_TIMESTAMP,
    date_start timestamp with time zone,
    date_end timestamp with time zone,
    times_used integer DEFAULT 0,
    max_uses integer
);


ALTER TABLE public.directus_shares OWNER TO directus_app;

--
-- TOC entry 334 (class 1259 OID 17856)
-- Name: directus_translations; Type: TABLE; Schema: public; Owner: directus_app
--

CREATE TABLE public.directus_translations (
    id uuid NOT NULL,
    language character varying(255) NOT NULL,
    key character varying(255) NOT NULL,
    value text NOT NULL
);


ALTER TABLE public.directus_translations OWNER TO directus_app;

--
-- TOC entry 308 (class 1259 OID 17341)
-- Name: directus_users; Type: TABLE; Schema: public; Owner: directus_app
--

CREATE TABLE public.directus_users (
    id uuid NOT NULL,
    first_name character varying(50),
    last_name character varying(50),
    email character varying(128),
    password character varying(255),
    location character varying(255),
    title character varying(50),
    description text,
    tags json,
    avatar uuid,
    language character varying(255) DEFAULT NULL::character varying,
    tfa_secret character varying(255),
    status character varying(16) DEFAULT 'active'::character varying NOT NULL,
    role uuid,
    token character varying(255),
    last_access timestamp with time zone,
    last_page character varying(255),
    provider character varying(128) DEFAULT 'default'::character varying NOT NULL,
    external_identifier character varying(255),
    auth_data json,
    email_notifications boolean DEFAULT true,
    appearance character varying(255),
    theme_dark character varying(255),
    theme_light character varying(255),
    theme_light_overrides json,
    theme_dark_overrides json,
    text_direction character varying(255) DEFAULT 'auto'::character varying NOT NULL
);


ALTER TABLE public.directus_users OWNER TO directus_app;

--
-- TOC entry 335 (class 1259 OID 17863)
-- Name: directus_versions; Type: TABLE; Schema: public; Owner: directus_app
--

CREATE TABLE public.directus_versions (
    id uuid NOT NULL,
    key character varying(64) NOT NULL,
    name character varying(255),
    collection character varying(64) NOT NULL,
    item character varying(255) NOT NULL,
    hash character varying(255),
    date_created timestamp with time zone DEFAULT CURRENT_TIMESTAMP,
    date_updated timestamp with time zone DEFAULT CURRENT_TIMESTAMP,
    user_created uuid,
    user_updated uuid,
    delta json
);


ALTER TABLE public.directus_versions OWNER TO directus_app;

--
-- TOC entry 295 (class 1259 OID 17094)
-- Name: display_sheet_raw; Type: TABLE; Schema: stage; Owner: msbadmin
--

CREATE TABLE stage.display_sheet_raw (
    display_name text,
    inventory_type text,
    display_status text,
    designer_name text,
    theme_name text,
    frame_name text,
    pallet_id_raw text,
    year_built integer,
    amps_measured numeric(8,2),
    est_light_count integer,
    dumb_controller text,
    notes text
);


ALTER TABLE stage.display_sheet_raw OWNER TO msbadmin;

--
-- TOC entry 298 (class 1259 OID 17114)
-- Name: rpt_display_name_reconcile; Type: VIEW; Schema: public; Owner: msbadmin
--

CREATE VIEW public.rpt_display_name_reconcile AS
 WITH lor AS (
         SELECT p.prop_id AS lor_prop_id,
            p.lor_comment AS lor_display_name,
            lower(regexp_replace(COALESCE(p.lor_comment, ''::text), '[^a-z0-9]+'::text, ''::text, 'g'::text)) AS lor_key_norm
           FROM lor_snap.props p
          WHERE (p.import_run_id = ( SELECT max(import_run.import_run_id) AS max
                   FROM lor_snap.import_run))
        )
 SELECT s.display_name AS sheet_display_name,
    lower(regexp_replace(COALESCE(s.display_name, ''::text), '[^a-z0-9]+'::text, ''::text, 'g'::text)) AS sheet_key_norm,
    s.inventory_type,
    s.display_status,
    s.designer_name,
    s.theme_name,
    s.pallet_id_raw,
    s.notes,
    l.lor_prop_id,
    l.lor_display_name,
    l.lor_key_norm,
        CASE
            WHEN (l.lor_prop_id IS NULL) THEN 'MISSING_IN_LOR'::text
            WHEN (btrim(COALESCE(s.display_name, ''::text)) = btrim(COALESCE(l.lor_display_name, ''::text))) THEN 'MATCHED'::text
            ELSE 'NAME_DIFF'::text
        END AS match_status
   FROM (stage.display_sheet_raw s
     LEFT JOIN lor l ON ((l.lor_key_norm = lower(regexp_replace(COALESCE(s.display_name, ''::text), '[^a-z0-9]+'::text, ''::text, 'g'::text)))))
  ORDER BY
        CASE
            WHEN (l.lor_prop_id IS NULL) THEN 'MISSING_IN_LOR'::text
            WHEN (btrim(COALESCE(s.display_name, ''::text)) = btrim(COALESCE(l.lor_display_name, ''::text))) THEN 'MATCHED'::text
            ELSE 'NAME_DIFF'::text
        END DESC, s.display_name;


ALTER VIEW public.rpt_display_name_reconcile OWNER TO msbadmin;

--
-- TOC entry 300 (class 1259 OID 17124)
-- Name: rpt_lor_not_in_sheet; Type: VIEW; Schema: public; Owner: msbadmin
--

CREATE VIEW public.rpt_lor_not_in_sheet AS
 WITH lor AS (
         SELECT p.prop_id,
            p.lor_comment,
            lower(regexp_replace(COALESCE(p.lor_comment, ''::text), '[^a-z0-9]+'::text, ''::text, 'g'::text)) AS key_norm
           FROM lor_snap.props p
          WHERE (p.import_run_id = ( SELECT max(import_run.import_run_id) AS max
                   FROM lor_snap.import_run))
        ), sheet AS (
         SELECT DISTINCT lower(regexp_replace(COALESCE(display_sheet_raw.display_name, ''::text), '[^a-z0-9]+'::text, ''::text, 'g'::text)) AS key_norm
           FROM stage.display_sheet_raw
        )
 SELECT l.lor_comment AS lor_display_name,
    l.prop_id AS lor_prop_id
   FROM (lor l
     LEFT JOIN sheet s ON ((s.key_norm = l.key_norm)))
  WHERE (s.key_norm IS NULL)
  ORDER BY l.lor_comment;


ALTER VIEW public.rpt_lor_not_in_sheet OWNER TO msbadmin;

--
-- TOC entry 299 (class 1259 OID 17119)
-- Name: rpt_sheet_lor_unmatched; Type: VIEW; Schema: public; Owner: msbadmin
--

CREATE VIEW public.rpt_sheet_lor_unmatched AS
 WITH lor AS (
         SELECT p.prop_id,
            lower(regexp_replace(COALESCE(p.lor_comment, ''::text), '[^a-z0-9]+'::text, ''::text, 'g'::text)) AS key_norm
           FROM lor_snap.props p
          WHERE (p.import_run_id = ( SELECT max(import_run.import_run_id) AS max
                   FROM lor_snap.import_run))
        )
 SELECT s.display_name,
    s.designer_name,
    s.theme_name,
    s.pallet_id_raw,
    s.notes
   FROM (stage.display_sheet_raw s
     LEFT JOIN lor l ON ((l.key_norm = lower(regexp_replace(COALESCE(s.display_name, ''::text), '[^a-z0-9]+'::text, ''::text, 'g'::text)))))
  WHERE ((upper(COALESCE(s.inventory_type, 'LOR'::text)) = 'LOR'::text) AND (l.prop_id IS NULL))
  ORDER BY s.display_name;


ALTER VIEW public.rpt_sheet_lor_unmatched OWNER TO msbadmin;

--
-- TOC entry 296 (class 1259 OID 17103)
-- Name: v_display_current; Type: VIEW; Schema: public; Owner: msbadmin
--

CREATE VIEW public.v_display_current AS
 SELECT d.lor_prop_id,
    d.display_name,
    d.inventory_type,
    d.display_status_id,
    d.container_id AS pallet_id,
    pal.location_code,
    pr.preview_id,
    pv.id AS preview_guid,
    pv.stage_id,
    pv.name AS preview_name
   FROM (((ref.display d
     JOIN lor_snap.props pr ON (((pr.prop_id = d.lor_prop_id) AND (pr.import_run_id = ( SELECT max(import_run.import_run_id) AS max
           FROM lor_snap.import_run)))))
     JOIN lor_snap.previews pv ON (((pv.import_run_id = pr.import_run_id) AND (pv.id = pr.preview_id))))
     LEFT JOIN ref.container pal ON ((pal.container_id = d.container_id)));


ALTER VIEW public.v_display_current OWNER TO msbadmin;

--
-- TOC entry 384 (class 1259 OID 19212)
-- Name: audit_collection_policy; Type: TABLE; Schema: ref; Owner: msbadmin
--

CREATE TABLE ref.audit_collection_policy (
    audit_collection_policy_id integer NOT NULL,
    schema_name text NOT NULL,
    collection_name text NOT NULL,
    insert_actor_enabled boolean DEFAULT false NOT NULL,
    update_actor_enabled boolean DEFAULT false NOT NULL,
    checked_actor_enabled boolean DEFAULT false NOT NULL,
    active_flag boolean DEFAULT true NOT NULL,
    notes text,
    created_at timestamp with time zone,
    created_by text,
    created_by_person_id bigint,
    updated_at timestamp with time zone,
    updated_by text,
    updated_by_person_id bigint
);


ALTER TABLE ref.audit_collection_policy OWNER TO msbadmin;

--
-- TOC entry 383 (class 1259 OID 19211)
-- Name: audit_collection_policy_audit_collection_policy_id_seq; Type: SEQUENCE; Schema: ref; Owner: msbadmin
--

ALTER TABLE ref.audit_collection_policy ALTER COLUMN audit_collection_policy_id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME ref.audit_collection_policy_audit_collection_policy_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- TOC entry 381 (class 1259 OID 19207)
-- Name: container_container_id_seq; Type: SEQUENCE; Schema: ref; Owner: msbadmin
--

CREATE SEQUENCE ref.container_container_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE ref.container_container_id_seq OWNER TO msbadmin;

--
-- TOC entry 6379 (class 0 OID 0)
-- Dependencies: 381
-- Name: container_container_id_seq; Type: SEQUENCE OWNED BY; Schema: ref; Owner: msbadmin
--

ALTER SEQUENCE ref.container_container_id_seq OWNED BY ref.container.container_id;


--
-- TOC entry 348 (class 1259 OID 18282)
-- Name: container_endpoint; Type: TABLE; Schema: ref; Owner: msbadmin
--

CREATE TABLE ref.container_endpoint (
    endpoint_id integer NOT NULL,
    endpoint_name text NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    created_by text DEFAULT CURRENT_USER NOT NULL,
    created_by_person_id bigint,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_by text DEFAULT CURRENT_USER NOT NULL,
    updated_by_person_id bigint
);


ALTER TABLE ref.container_endpoint OWNER TO msbadmin;

--
-- TOC entry 380 (class 1259 OID 19205)
-- Name: container_endpoint_endpoint_id_seq; Type: SEQUENCE; Schema: ref; Owner: msbadmin
--

CREATE SEQUENCE ref.container_endpoint_endpoint_id_seq
    START WITH 6
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE ref.container_endpoint_endpoint_id_seq OWNER TO msbadmin;

--
-- TOC entry 6382 (class 0 OID 0)
-- Dependencies: 380
-- Name: container_endpoint_endpoint_id_seq; Type: SEQUENCE OWNED BY; Schema: ref; Owner: msbadmin
--

ALTER SEQUENCE ref.container_endpoint_endpoint_id_seq OWNED BY ref.container_endpoint.endpoint_id;


--
-- TOC entry 367 (class 1259 OID 18938)
-- Name: container_test_status_container_test_status_id_seq; Type: SEQUENCE; Schema: ref; Owner: msbadmin
--

ALTER TABLE ref.container_test_status ALTER COLUMN container_test_status_id ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME ref.container_test_status_container_test_status_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- TOC entry 385 (class 1259 OID 19295)
-- Name: container_test_status_id_seq; Type: SEQUENCE; Schema: ref; Owner: msbadmin
--

CREATE SEQUENCE ref.container_test_status_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE ref.container_test_status_id_seq OWNER TO msbadmin;

--
-- TOC entry 283 (class 1259 OID 16806)
-- Name: container_type; Type: TABLE; Schema: ref; Owner: msbadmin
--

CREATE TABLE ref.container_type (
    container_type_id integer NOT NULL,
    container_type_name text NOT NULL,
    notes text,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    created_by text DEFAULT CURRENT_USER NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_by text DEFAULT CURRENT_USER NOT NULL,
    default_width_in integer,
    default_depth_in integer,
    default_height_in integer,
    is_stackable_default boolean,
    created_by_person_id bigint,
    updated_by_person_id bigint
);


ALTER TABLE ref.container_type OWNER TO msbadmin;

--
-- TOC entry 388 (class 1259 OID 20326)
-- Name: display_backup_20260317; Type: TABLE; Schema: ref; Owner: msbadmin
--

CREATE TABLE ref.display_backup_20260317 (
    lor_prop_id text,
    display_name text,
    inventory_type text,
    display_status_id integer,
    designer_id integer,
    theme_id integer,
    frame_id integer,
    container_id integer,
    year_built integer,
    amps_measured numeric(8,2),
    est_light_count integer,
    dumb_controller text,
    notes text,
    created_at timestamp with time zone,
    created_by text,
    updated_at timestamp with time zone,
    updated_by text,
    stage_id integer,
    display_id bigint,
    string_type text,
    color text,
    created_by_person_id bigint,
    updated_by_person_id bigint
);


ALTER TABLE ref.display_backup_20260317 OWNER TO msbadmin;

--
-- TOC entry 392 (class 1259 OID 20431)
-- Name: display_backup_20260318_after_run22_success; Type: TABLE; Schema: ref; Owner: msbadmin
--

CREATE TABLE ref.display_backup_20260318_after_run22_success (
    lor_prop_id text,
    display_name text,
    inventory_type text,
    display_status_id integer,
    designer_id integer,
    theme_id integer,
    frame_id integer,
    container_id integer,
    year_built integer,
    amps_measured numeric(8,2),
    est_light_count integer,
    dumb_controller text,
    notes text,
    created_at timestamp with time zone,
    created_by text,
    updated_at timestamp with time zone,
    updated_by text,
    stage_id integer,
    display_id bigint,
    string_type text,
    color text,
    created_by_person_id bigint,
    updated_by_person_id bigint
);


ALTER TABLE ref.display_backup_20260318_after_run22_success OWNER TO msbadmin;

--
-- TOC entry 394 (class 1259 OID 20453)
-- Name: display_backup_20260319_after_run23_baseline; Type: TABLE; Schema: ref; Owner: msbadmin
--

CREATE TABLE ref.display_backup_20260319_after_run23_baseline (
    lor_prop_id text,
    display_name text,
    inventory_type text,
    display_status_id integer,
    designer_id integer,
    theme_id integer,
    frame_id integer,
    container_id integer,
    year_built integer,
    amps_measured numeric(8,2),
    est_light_count integer,
    dumb_controller text,
    notes text,
    created_at timestamp with time zone,
    created_by text,
    updated_at timestamp with time zone,
    updated_by text,
    stage_id integer,
    display_id bigint,
    string_type text,
    color text,
    created_by_person_id bigint,
    updated_by_person_id bigint
);


ALTER TABLE ref.display_backup_20260319_after_run23_baseline OWNER TO msbadmin;

--
-- TOC entry 398 (class 1259 OID 20534)
-- Name: display_backup_20260319_before_run25_p2; Type: TABLE; Schema: ref; Owner: msbadmin
--

CREATE TABLE ref.display_backup_20260319_before_run25_p2 (
    lor_prop_id text,
    display_name text,
    inventory_type text,
    display_status_id integer,
    designer_id integer,
    theme_id integer,
    frame_id integer,
    container_id integer,
    year_built integer,
    amps_measured numeric(8,2),
    est_light_count integer,
    dumb_controller text,
    notes text,
    created_at timestamp with time zone,
    created_by text,
    updated_at timestamp with time zone,
    updated_by text,
    stage_id integer,
    display_id bigint,
    string_type text,
    color text,
    created_by_person_id bigint,
    updated_by_person_id bigint
);


ALTER TABLE ref.display_backup_20260319_before_run25_p2 OWNER TO msbadmin;

--
-- TOC entry 396 (class 1259 OID 20476)
-- Name: display_backup_20260319_run23_post_p2; Type: TABLE; Schema: ref; Owner: msbadmin
--

CREATE TABLE ref.display_backup_20260319_run23_post_p2 (
    lor_prop_id text,
    display_name text,
    inventory_type text,
    display_status_id integer,
    designer_id integer,
    theme_id integer,
    frame_id integer,
    container_id integer,
    year_built integer,
    amps_measured numeric(8,2),
    est_light_count integer,
    dumb_controller text,
    notes text,
    created_at timestamp with time zone,
    created_by text,
    updated_at timestamp with time zone,
    updated_by text,
    stage_id integer,
    display_id bigint,
    string_type text,
    color text,
    created_by_person_id bigint,
    updated_by_person_id bigint
);


ALTER TABLE ref.display_backup_20260319_run23_post_p2 OWNER TO msbadmin;

--
-- TOC entry 429 (class 1259 OID 23365)
-- Name: display_backup_20260802; Type: TABLE; Schema: ref; Owner: msbadmin
--

CREATE TABLE ref.display_backup_20260802 (
    lor_prop_id text,
    display_name text,
    inventory_type text,
    display_status_id integer,
    designer_id integer,
    theme_id integer,
    frame_id integer,
    container_id integer,
    year_built integer,
    amps_measured numeric(8,2),
    est_light_count integer,
    dumb_controller text,
    notes text,
    created_at timestamp with time zone,
    created_by text,
    updated_at timestamp with time zone,
    updated_by text,
    stage_id integer,
    display_id bigint,
    string_type text,
    color text,
    created_by_person_id bigint,
    updated_by_person_id bigint,
    label_required boolean,
    print_label boolean,
    label_print_count_cached integer,
    label_print_last_at_cached timestamp with time zone,
    label_print_last_by_cached_id integer
);


ALTER TABLE ref.display_backup_20260802 OWNER TO msbadmin;

--
-- TOC entry 362 (class 1259 OID 18722)
-- Name: display_display_id_seq; Type: SEQUENCE; Schema: ref; Owner: msbadmin
--

ALTER TABLE ref.display ALTER COLUMN display_id ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME ref.display_display_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- TOC entry 280 (class 1259 OID 16760)
-- Name: display_status_display_status_id_seq; Type: SEQUENCE; Schema: ref; Owner: msbadmin
--

ALTER TABLE ref.display_status ALTER COLUMN display_status_id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME ref.display_status_display_status_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- TOC entry 366 (class 1259 OID 18907)
-- Name: display_test_status; Type: TABLE; Schema: ref; Owner: msbadmin
--

CREATE TABLE ref.display_test_status (
    test_status_code text NOT NULL,
    sort_order integer NOT NULL,
    label text NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    created_by text DEFAULT CURRENT_USER NOT NULL,
    created_by_person_id bigint,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_by text DEFAULT CURRENT_USER NOT NULL,
    updated_by_person_id bigint
);


ALTER TABLE ref.display_test_status OWNER TO msbadmin;

--
-- TOC entry 277 (class 1259 OID 16706)
-- Name: frame; Type: TABLE; Schema: ref; Owner: msbadmin
--

CREATE TABLE ref.frame (
    frame_id integer NOT NULL,
    frame_name text NOT NULL,
    w_ft integer,
    h_ft integer,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    created_by text DEFAULT CURRENT_USER NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_by text DEFAULT CURRENT_USER NOT NULL,
    created_by_person_id bigint,
    updated_by_person_id bigint,
    CONSTRAINT chk_frame_dimensions CHECK ((((frame_name = ANY (ARRAY['Custom'::text, 'None'::text])) AND (w_ft IS NULL) AND (h_ft IS NULL)) OR ((frame_name <> ALL (ARRAY['Custom'::text, 'None'::text])) AND (w_ft IS NOT NULL) AND (h_ft IS NOT NULL))))
);


ALTER TABLE ref.frame OWNER TO msbadmin;

--
-- TOC entry 276 (class 1259 OID 16705)
-- Name: frame_frame_id_seq; Type: SEQUENCE; Schema: ref; Owner: msbadmin
--

ALTER TABLE ref.frame ALTER COLUMN frame_id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME ref.frame_frame_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- TOC entry 292 (class 1259 OID 17028)
-- Name: inventory_type; Type: TABLE; Schema: ref; Owner: msbadmin
--

CREATE TABLE ref.inventory_type (
    inventory_type text NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    created_by text DEFAULT CURRENT_USER NOT NULL,
    created_by_person_id bigint,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_by text DEFAULT CURRENT_USER NOT NULL,
    updated_by_person_id bigint
);


ALTER TABLE ref.inventory_type OWNER TO msbadmin;

--
-- TOC entry 427 (class 1259 OID 23226)
-- Name: lor_scene; Type: TABLE; Schema: ref; Owner: msbadmin
--

CREATE TABLE ref.lor_scene (
    lor_scene_id bigint NOT NULL,
    preview_uuid text NOT NULL,
    scene_uuid text NOT NULL,
    stage_id integer NOT NULL,
    scene_name text NOT NULL,
    scene_section text,
    background_file text,
    h_scroll integer,
    v_scroll integer,
    zoom integer,
    create_grid_view text,
    source_import_run_id bigint NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    created_by text DEFAULT CURRENT_USER NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_by text DEFAULT CURRENT_USER NOT NULL
);


ALTER TABLE ref.lor_scene OWNER TO msbadmin;

--
-- TOC entry 6399 (class 0 OID 0)
-- Dependencies: 427
-- Name: TABLE lor_scene; Type: COMMENT; Schema: ref; Owner: msbadmin
--

COMMENT ON TABLE ref.lor_scene IS 'Current production LOR scenes. Historical definitions remain in lor_snap.scenes.';


--
-- TOC entry 6400 (class 0 OID 0)
-- Dependencies: 427
-- Name: COLUMN lor_scene.preview_uuid; Type: COMMENT; Schema: ref; Owner: msbadmin
--

COMMENT ON COLUMN ref.lor_scene.preview_uuid IS 'LOR preview identity. Combined with scene_uuid to identify a scene.';


--
-- TOC entry 6401 (class 0 OID 0)
-- Dependencies: 427
-- Name: COLUMN lor_scene.scene_uuid; Type: COMMENT; Schema: ref; Owner: msbadmin
--

COMMENT ON COLUMN ref.lor_scene.scene_uuid IS 'LOR scene identity scoped to preview_uuid; not assumed globally unique.';


--
-- TOC entry 428 (class 1259 OID 23251)
-- Name: lor_scene_display; Type: TABLE; Schema: ref; Owner: msbadmin
--

CREATE TABLE ref.lor_scene_display (
    lor_scene_id bigint NOT NULL,
    preview_uuid text NOT NULL,
    display_id bigint NOT NULL,
    scene_prop_ordinal integer,
    scene_role text,
    source text,
    source_import_run_id bigint NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    created_by text DEFAULT CURRENT_USER NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_by text DEFAULT CURRENT_USER NOT NULL
);


ALTER TABLE ref.lor_scene_display OWNER TO msbadmin;

--
-- TOC entry 6403 (class 0 OID 0)
-- Dependencies: 428
-- Name: TABLE lor_scene_display; Type: COMMENT; Schema: ref; Owner: msbadmin
--

COMMENT ON TABLE ref.lor_scene_display IS 'Current scene assignment for permanent displays; one scene per display within a preview.';


--
-- TOC entry 6404 (class 0 OID 0)
-- Dependencies: 428
-- Name: COLUMN lor_scene_display.preview_uuid; Type: COMMENT; Schema: ref; Owner: msbadmin
--

COMMENT ON COLUMN ref.lor_scene_display.preview_uuid IS 'Duplicated parent preview identity used to enforce one current scene per display per preview.';


--
-- TOC entry 426 (class 1259 OID 23225)
-- Name: lor_scene_lor_scene_id_seq; Type: SEQUENCE; Schema: ref; Owner: msbadmin
--

ALTER TABLE ref.lor_scene ALTER COLUMN lor_scene_id ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME ref.lor_scene_lor_scene_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- TOC entry 282 (class 1259 OID 16805)
-- Name: pallet_type_pallet_type_id_seq; Type: SEQUENCE; Schema: ref; Owner: msbadmin
--

ALTER TABLE ref.container_type ALTER COLUMN container_type_id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME ref.pallet_type_pallet_type_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- TOC entry 288 (class 1259 OID 16953)
-- Name: person; Type: TABLE; Schema: ref; Owner: msbadmin
--

CREATE TABLE ref.person (
    person_id integer NOT NULL,
    first_name text NOT NULL,
    last_name text,
    preferred_name text,
    email text,
    cell_phone text,
    active_flag boolean DEFAULT true NOT NULL,
    is_manager boolean DEFAULT false NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    created_by text DEFAULT CURRENT_USER NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_by text DEFAULT CURRENT_USER NOT NULL,
    is_team boolean DEFAULT false NOT NULL,
    personal_email text,
    directus_user_id uuid,
    pg_login_name character varying(20),
    created_by_person_id bigint,
    updated_by_person_id bigint,
    available_for_work_orders boolean DEFAULT false NOT NULL,
    CONSTRAINT chk_cell_phone_digits_10 CHECK (((cell_phone IS NULL) OR (cell_phone ~ '^\d{10}$'::text))),
    CONSTRAINT chk_person_last_name_if_not_team CHECK (((is_team = true) OR ((last_name IS NOT NULL) AND (btrim(last_name) <> ''::text))))
);


ALTER TABLE ref.person OWNER TO msbadmin;

--
-- TOC entry 382 (class 1259 OID 19209)
-- Name: person_person_id_seq; Type: SEQUENCE; Schema: ref; Owner: msbadmin
--

CREATE SEQUENCE ref.person_person_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE ref.person_person_id_seq OWNER TO msbadmin;

--
-- TOC entry 6409 (class 0 OID 0)
-- Dependencies: 382
-- Name: person_person_id_seq; Type: SEQUENCE OWNED BY; Schema: ref; Owner: msbadmin
--

ALTER SEQUENCE ref.person_person_id_seq OWNED BY ref.person.person_id;


--
-- TOC entry 290 (class 1259 OID 16973)
-- Name: person_xref; Type: TABLE; Schema: ref; Owner: msbadmin
--

CREATE TABLE ref.person_xref (
    source_system text NOT NULL,
    source_user_id text NOT NULL,
    person_id integer NOT NULL,
    email text,
    username text,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    created_by text DEFAULT CURRENT_USER NOT NULL,
    created_by_person_id bigint,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_by text DEFAULT CURRENT_USER NOT NULL,
    updated_by_person_id bigint
);


ALTER TABLE ref.person_xref OWNER TO msbadmin;

--
-- TOC entry 386 (class 1259 OID 19486)
-- Name: season; Type: TABLE; Schema: ref; Owner: msbadmin
--

CREATE TABLE ref.season (
    season_year integer NOT NULL,
    season_name text NOT NULL,
    season_start_date date,
    season_end_date date,
    active_flag boolean DEFAULT true NOT NULL,
    created_at timestamp with time zone,
    created_by text,
    created_by_person_id integer,
    updated_at timestamp with time zone,
    updated_by text,
    updated_by_person_id integer
);


ALTER TABLE ref.season OWNER TO msbadmin;

--
-- TOC entry 355 (class 1259 OID 18556)
-- Name: spare_channel; Type: TABLE; Schema: ref; Owner: msbadmin
--

CREATE TABLE ref.spare_channel (
    lor_prop_id text NOT NULL,
    display_name text NOT NULL,
    inventory_type text NOT NULL,
    display_status_id integer NOT NULL,
    designer_id integer,
    theme_id integer,
    frame_id integer,
    container_id integer,
    year_built integer,
    amps_measured numeric(8,2),
    est_light_count integer,
    dumb_controller text,
    notes text,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    created_by text DEFAULT CURRENT_USER NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_by text DEFAULT CURRENT_USER NOT NULL,
    stage_id integer,
    string_type text,
    color text,
    created_by_person_id bigint,
    updated_by_person_id bigint
);


ALTER TABLE ref.spare_channel OWNER TO msbadmin;

--
-- TOC entry 389 (class 1259 OID 20331)
-- Name: spare_channel_backup_20260317; Type: TABLE; Schema: ref; Owner: msbadmin
--

CREATE TABLE ref.spare_channel_backup_20260317 (
    lor_prop_id text,
    display_name text,
    inventory_type text,
    display_status_id integer,
    designer_id integer,
    theme_id integer,
    frame_id integer,
    container_id integer,
    year_built integer,
    amps_measured numeric(8,2),
    est_light_count integer,
    dumb_controller text,
    notes text,
    created_at timestamp with time zone,
    created_by text,
    updated_at timestamp with time zone,
    updated_by text,
    stage_id integer,
    string_type text,
    color text,
    created_by_person_id bigint,
    updated_by_person_id bigint
);


ALTER TABLE ref.spare_channel_backup_20260317 OWNER TO msbadmin;

--
-- TOC entry 393 (class 1259 OID 20438)
-- Name: spare_channel_backup_20260318_after_run22_success; Type: TABLE; Schema: ref; Owner: msbadmin
--

CREATE TABLE ref.spare_channel_backup_20260318_after_run22_success (
    lor_prop_id text,
    display_name text,
    inventory_type text,
    display_status_id integer,
    designer_id integer,
    theme_id integer,
    frame_id integer,
    container_id integer,
    year_built integer,
    amps_measured numeric(8,2),
    est_light_count integer,
    dumb_controller text,
    notes text,
    created_at timestamp with time zone,
    created_by text,
    updated_at timestamp with time zone,
    updated_by text,
    stage_id integer,
    string_type text,
    color text,
    created_by_person_id bigint,
    updated_by_person_id bigint
);


ALTER TABLE ref.spare_channel_backup_20260318_after_run22_success OWNER TO msbadmin;

--
-- TOC entry 390 (class 1259 OID 20359)
-- Name: spare_channel_backup_20260318_lor_raw_fix; Type: TABLE; Schema: ref; Owner: msbadmin
--

CREATE TABLE ref.spare_channel_backup_20260318_lor_raw_fix (
    lor_prop_id text,
    display_name text,
    inventory_type text,
    display_status_id integer,
    designer_id integer,
    theme_id integer,
    frame_id integer,
    container_id integer,
    year_built integer,
    amps_measured numeric(8,2),
    est_light_count integer,
    dumb_controller text,
    notes text,
    created_at timestamp with time zone,
    created_by text,
    updated_at timestamp with time zone,
    updated_by text,
    stage_id integer,
    string_type text,
    color text,
    created_by_person_id bigint,
    updated_by_person_id bigint
);


ALTER TABLE ref.spare_channel_backup_20260318_lor_raw_fix OWNER TO msbadmin;

--
-- TOC entry 391 (class 1259 OID 20365)
-- Name: spare_channel_backup_20260318_partial_raw_restore; Type: TABLE; Schema: ref; Owner: msbadmin
--

CREATE TABLE ref.spare_channel_backup_20260318_partial_raw_restore (
    lor_prop_id text,
    display_name text,
    inventory_type text,
    display_status_id integer,
    designer_id integer,
    theme_id integer,
    frame_id integer,
    container_id integer,
    year_built integer,
    amps_measured numeric(8,2),
    est_light_count integer,
    dumb_controller text,
    notes text,
    created_at timestamp with time zone,
    created_by text,
    updated_at timestamp with time zone,
    updated_by text,
    stage_id integer,
    string_type text,
    color text,
    created_by_person_id bigint,
    updated_by_person_id bigint
);


ALTER TABLE ref.spare_channel_backup_20260318_partial_raw_restore OWNER TO msbadmin;

--
-- TOC entry 395 (class 1259 OID 20460)
-- Name: spare_channel_backup_20260319_after_run23_baseline; Type: TABLE; Schema: ref; Owner: msbadmin
--

CREATE TABLE ref.spare_channel_backup_20260319_after_run23_baseline (
    lor_prop_id text,
    display_name text,
    inventory_type text,
    display_status_id integer,
    designer_id integer,
    theme_id integer,
    frame_id integer,
    container_id integer,
    year_built integer,
    amps_measured numeric(8,2),
    est_light_count integer,
    dumb_controller text,
    notes text,
    created_at timestamp with time zone,
    created_by text,
    updated_at timestamp with time zone,
    updated_by text,
    stage_id integer,
    string_type text,
    color text,
    created_by_person_id bigint,
    updated_by_person_id bigint
);


ALTER TABLE ref.spare_channel_backup_20260319_after_run23_baseline OWNER TO msbadmin;

--
-- TOC entry 397 (class 1259 OID 20510)
-- Name: spare_channel_backup_20260319_before_run24_p2; Type: TABLE; Schema: ref; Owner: msbadmin
--

CREATE TABLE ref.spare_channel_backup_20260319_before_run24_p2 (
    lor_prop_id text,
    display_name text,
    inventory_type text,
    display_status_id integer,
    designer_id integer,
    theme_id integer,
    frame_id integer,
    container_id integer,
    year_built integer,
    amps_measured numeric(8,2),
    est_light_count integer,
    dumb_controller text,
    notes text,
    created_at timestamp with time zone,
    created_by text,
    updated_at timestamp with time zone,
    updated_by text,
    stage_id integer,
    string_type text,
    color text,
    created_by_person_id bigint,
    updated_by_person_id bigint
);


ALTER TABLE ref.spare_channel_backup_20260319_before_run24_p2 OWNER TO msbadmin;

--
-- TOC entry 345 (class 1259 OID 18103)
-- Name: stage_history; Type: TABLE; Schema: ref; Owner: msbadmin
--

CREATE TABLE ref.stage_history (
    import_run_id integer NOT NULL,
    stage_id integer NOT NULL,
    stage_key text,
    stage_name text,
    short_code text,
    folder_name text,
    folder_path text,
    notes text,
    captured_at timestamp with time zone DEFAULT now() NOT NULL,
    captured_by text DEFAULT CURRENT_USER NOT NULL
);


ALTER TABLE ref.stage_history OWNER TO msbadmin;

--
-- TOC entry 446 (class 1259 OID 23593)
-- Name: stage_lor_binding; Type: TABLE; Schema: ref; Owner: msbadmin
--

CREATE TABLE ref.stage_lor_binding (
    stage_lor_binding_id bigint NOT NULL,
    stage_id integer NOT NULL,
    binding_type text NOT NULL,
    preview_id text NOT NULL,
    scene_id text,
    source_name text,
    first_seen_import_run_id bigint NOT NULL,
    last_seen_import_run_id bigint NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    created_by text DEFAULT CURRENT_USER NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_by text DEFAULT CURRENT_USER NOT NULL,
    CONSTRAINT ck_stage_lor_binding_runs CHECK (((first_seen_import_run_id > 0) AND (last_seen_import_run_id >= first_seen_import_run_id))),
    CONSTRAINT ck_stage_lor_binding_type CHECK ((((binding_type = 'PREVIEW'::text) AND (scene_id IS NULL)) OR ((binding_type = 'SCENE'::text) AND (NULLIF(btrim(scene_id), ''::text) IS NOT NULL))))
);


ALTER TABLE ref.stage_lor_binding OWNER TO msbadmin;

--
-- TOC entry 6421 (class 0 OID 0)
-- Dependencies: 446
-- Name: TABLE stage_lor_binding; Type: COMMENT; Schema: ref; Owner: msbadmin
--

COMMENT ON TABLE ref.stage_lor_binding IS 'Stable LOR preview/scene identities bound to permanent ref.stage.stage_id. Names and stage keys are mutable metadata.';


--
-- TOC entry 445 (class 1259 OID 23592)
-- Name: stage_lor_binding_stage_lor_binding_id_seq; Type: SEQUENCE; Schema: ref; Owner: msbadmin
--

ALTER TABLE ref.stage_lor_binding ALTER COLUMN stage_lor_binding_id ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME ref.stage_lor_binding_stage_lor_binding_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- TOC entry 346 (class 1259 OID 18171)
-- Name: stage_stage_id_seq; Type: SEQUENCE; Schema: ref; Owner: msbadmin
--

CREATE SEQUENCE ref.stage_stage_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE ref.stage_stage_id_seq OWNER TO msbadmin;

--
-- TOC entry 6424 (class 0 OID 0)
-- Dependencies: 346
-- Name: stage_stage_id_seq; Type: SEQUENCE OWNED BY; Schema: ref; Owner: msbadmin
--

ALTER SEQUENCE ref.stage_stage_id_seq OWNED BY ref.stage.stage_id;


--
-- TOC entry 285 (class 1259 OID 16841)
-- Name: storage_location; Type: TABLE; Schema: ref; Owner: msbadmin
--

CREATE TABLE ref.storage_location (
    type_code text NOT NULL,
    rack_row_code text NOT NULL,
    column_num integer,
    shelf_level_code text,
    slot_bin_num integer,
    description text,
    notes text,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    created_by text DEFAULT CURRENT_USER NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_by text DEFAULT CURRENT_USER NOT NULL,
    location_code text GENERATED ALWAYS AS (
CASE
    WHEN (type_code = 'R'::text) THEN ((((((type_code || rack_row_code) || lpad((column_num)::text, 2, '0'::text)) || '-'::text) || shelf_level_code) || '-'::text) || lpad((slot_bin_num)::text, 2, '0'::text))
    WHEN (type_code = 'Z'::text) THEN (('Z-'::text || rack_row_code) ||
    CASE
        WHEN ((shelf_level_code IS NULL) OR (btrim(shelf_level_code) = ''::text)) THEN ''::text
        ELSE ('-'::text || shelf_level_code)
    END)
    ELSE NULL::text
END) STORED NOT NULL,
    created_by_person_id bigint,
    updated_by_person_id bigint,
    is_active boolean DEFAULT true NOT NULL,
    CONSTRAINT chk_location_type CHECK ((type_code = ANY (ARRAY['R'::text, 'Z'::text]))),
    CONSTRAINT ck_storage_location_type_rules CHECK ((((type_code = 'R'::text) AND (rack_row_code IS NOT NULL) AND (column_num IS NOT NULL) AND (shelf_level_code IS NOT NULL) AND (slot_bin_num IS NOT NULL)) OR ((type_code = 'Z'::text) AND (rack_row_code IS NOT NULL) AND (column_num IS NULL) AND (slot_bin_num IS NULL))))
);


ALTER TABLE ref.storage_location OWNER TO msbadmin;

--
-- TOC entry 350 (class 1259 OID 18393)
-- Name: task_type; Type: TABLE; Schema: ref; Owner: msbadmin
--

CREATE TABLE ref.task_type (
    task_type_id bigint NOT NULL,
    task_type_key text NOT NULL,
    task_type_name text NOT NULL,
    active_flag boolean DEFAULT true NOT NULL,
    sort_order integer DEFAULT 100 NOT NULL,
    notes text,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    created_by_person_id bigint,
    updated_by_person_id bigint
);


ALTER TABLE ref.task_type OWNER TO msbadmin;

--
-- TOC entry 349 (class 1259 OID 18392)
-- Name: task_type_task_type_id_seq; Type: SEQUENCE; Schema: ref; Owner: msbadmin
--

CREATE SEQUENCE ref.task_type_task_type_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE ref.task_type_task_type_id_seq OWNER TO msbadmin;

--
-- TOC entry 6428 (class 0 OID 0)
-- Dependencies: 349
-- Name: task_type_task_type_id_seq; Type: SEQUENCE OWNED BY; Schema: ref; Owner: msbadmin
--

ALTER SEQUENCE ref.task_type_task_type_id_seq OWNED BY ref.task_type.task_type_id;


--
-- TOC entry 279 (class 1259 OID 16746)
-- Name: theme; Type: TABLE; Schema: ref; Owner: msbadmin
--

CREATE TABLE ref.theme (
    theme_id integer NOT NULL,
    theme_name text NOT NULL,
    additional_info text,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    created_by text DEFAULT CURRENT_USER NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_by text DEFAULT CURRENT_USER NOT NULL,
    created_by_person_id bigint,
    updated_by_person_id bigint
);


ALTER TABLE ref.theme OWNER TO msbadmin;

--
-- TOC entry 278 (class 1259 OID 16745)
-- Name: theme_theme_pk_seq; Type: SEQUENCE; Schema: ref; Owner: msbadmin
--

ALTER TABLE ref.theme ALTER COLUMN theme_id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME ref.theme_theme_pk_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- TOC entry 387 (class 1259 OID 19624)
-- Name: urgency; Type: TABLE; Schema: ref; Owner: msbadmin
--

CREATE TABLE ref.urgency (
    urgency_id smallint NOT NULL,
    urgency_code text NOT NULL,
    urgency_label text NOT NULL,
    sort_order integer NOT NULL,
    active_flag boolean DEFAULT true NOT NULL
);


ALTER TABLE ref.urgency OWNER TO msbadmin;

--
-- TOC entry 352 (class 1259 OID 18423)
-- Name: work_area; Type: TABLE; Schema: ref; Owner: msbadmin
--

CREATE TABLE ref.work_area (
    work_area_id bigint NOT NULL,
    work_area_key text NOT NULL,
    work_area_name text NOT NULL,
    active_flag boolean DEFAULT true NOT NULL,
    sort_order integer DEFAULT 100 NOT NULL,
    notes text,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    created_by_person_id bigint,
    updated_by_person_id bigint
);


ALTER TABLE ref.work_area OWNER TO msbadmin;

--
-- TOC entry 351 (class 1259 OID 18422)
-- Name: work_area_work_area_id_seq; Type: SEQUENCE; Schema: ref; Owner: msbadmin
--

CREATE SEQUENCE ref.work_area_work_area_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE ref.work_area_work_area_id_seq OWNER TO msbadmin;

--
-- TOC entry 6434 (class 0 OID 0)
-- Dependencies: 351
-- Name: work_area_work_area_id_seq; Type: SEQUENCE OWNED BY; Schema: ref; Owner: msbadmin
--

ALTER SEQUENCE ref.work_area_work_area_id_seq OWNED BY ref.work_area.work_area_id;


--
-- TOC entry 370 (class 1259 OID 18962)
-- Name: work_order_status; Type: TABLE; Schema: ref; Owner: msbadmin
--

CREATE TABLE ref.work_order_status (
    work_order_status_id bigint NOT NULL,
    status_key text NOT NULL,
    status_name text NOT NULL,
    is_terminal boolean DEFAULT false NOT NULL,
    sort_order integer DEFAULT 100 NOT NULL,
    active_flag boolean DEFAULT true NOT NULL,
    notes text,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    created_by text DEFAULT CURRENT_USER NOT NULL,
    updated_by text DEFAULT CURRENT_USER NOT NULL,
    created_by_person_id bigint,
    updated_by_person_id bigint
);


ALTER TABLE ref.work_order_status OWNER TO msbadmin;

--
-- TOC entry 369 (class 1259 OID 18961)
-- Name: work_order_status_work_order_status_id_seq; Type: SEQUENCE; Schema: ref; Owner: msbadmin
--

ALTER TABLE ref.work_order_status ALTER COLUMN work_order_status_id ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME ref.work_order_status_work_order_status_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- TOC entry 294 (class 1259 OID 17088)
-- Name: display_sheet_csv; Type: TABLE; Schema: stage; Owner: msbadmin
--

CREATE TABLE stage.display_sheet_csv (
    display_name text,
    inventory_type text,
    display_status text,
    designer_id text,
    theme_id text,
    frame_id text,
    pallet_id text,
    year_built text,
    amps_measured text,
    est_light_count text,
    dumb_controller text,
    notes text
);


ALTER TABLE stage.display_sheet_csv OWNER TO msbadmin;

--
-- TOC entry 286 (class 1259 OID 16868)
-- Name: location_raw_full; Type: TABLE; Schema: stage; Owner: msbadmin
--

CREATE TABLE stage.location_raw_full (
    storage_id text,
    storage_no text,
    type text,
    location text,
    column_num integer,
    shelf text,
    slot_bin integer,
    description text,
    pallet_fk text,
    msb_sku text,
    notes text
);


ALTER TABLE stage.location_raw_full OWNER TO msbadmin;

--
-- TOC entry 347 (class 1259 OID 18248)
-- Name: pallet_raw_2026; Type: TABLE; Schema: stage; Owner: msbadmin
--

CREATE TABLE stage.pallet_raw_2026 (
    pallet_id integer NOT NULL,
    rack_code text,
    pallet_type text,
    description text,
    stage_id text,
    notes text,
    distribution text,
    display_pallet_flag text,
    testing_after_takedown text,
    year_built text
);


ALTER TABLE stage.pallet_raw_2026 OWNER TO msbadmin;

--
-- TOC entry 343 (class 1259 OID 18067)
-- Name: test_plan_2026_raw; Type: TABLE; Schema: stage; Owner: msbadmin
--

CREATE TABLE stage.test_plan_2026_raw (
    rack_location_text text,
    container_id_text text,
    old_display_name text,
    new_db_display_name text,
    date_tested_text text,
    tested_initials text,
    need_rgb_tested_text text,
    rgb_tested_date_text text,
    rgb_tested_initials text,
    car_counter_testing text,
    controller_testing text,
    laser_light_testing text,
    repair_yes_no_defer text,
    amp_reading_needed_yes_no_na text,
    pallet_label_needed_text text,
    notes text
);


ALTER TABLE stage.test_plan_2026_raw OWNER TO msbadmin;

--
-- TOC entry 297 (class 1259 OID 17108)
-- Name: v_sheet_match; Type: VIEW; Schema: stage; Owner: msbadmin
--

CREATE VIEW stage.v_sheet_match AS
 WITH lor AS (
         SELECT p.prop_id AS lor_prop_id,
            p.lor_comment,
            lower(regexp_replace(COALESCE(p.lor_comment, ''::text), '[^a-z0-9]+'::text, ''::text, 'g'::text)) AS key_norm
           FROM lor_snap.props p
          WHERE (p.import_run_id = ( SELECT max(import_run.import_run_id) AS max
                   FROM lor_snap.import_run))
        )
 SELECT s.display_name,
    s.inventory_type,
    s.display_status,
    s.designer_name,
    s.theme_name,
    s.frame_name,
    s.pallet_id_raw,
    s.year_built,
    s.amps_measured,
    s.est_light_count,
    s.dumb_controller,
    s.notes,
    l.lor_prop_id,
    l.lor_comment AS matched_lor_comment
   FROM (stage.display_sheet_raw s
     LEFT JOIN lor l ON ((l.key_norm = lower(regexp_replace(COALESCE(s.display_name, ''::text), '[^a-z0-9]+'::text, ''::text, 'g'::text)))));


ALTER VIEW stage.v_sheet_match OWNER TO msbadmin;

--
-- TOC entry 359 (class 1259 OID 18688)
-- Name: work_order_completed_raw; Type: TABLE; Schema: stage; Owner: msbadmin
--

CREATE TABLE stage.work_order_completed_raw (
    src_row_num bigint NOT NULL,
    done_raw text,
    priority_raw text,
    task_raw text,
    area_raw text,
    problem_raw text,
    notes_raw text,
    photo_raw text,
    assigned_to_raw text,
    date_added_raw text,
    added_by_raw text,
    date_complete_raw text,
    completed_by_raw text,
    email_sent_raw text,
    source_sheet text DEFAULT 'completed'::text NOT NULL,
    imported_at timestamp with time zone DEFAULT now() NOT NULL
);


ALTER TABLE stage.work_order_completed_raw OWNER TO msbadmin;

--
-- TOC entry 357 (class 1259 OID 18653)
-- Name: work_order_todo_raw; Type: TABLE; Schema: stage; Owner: msbadmin
--

CREATE TABLE stage.work_order_todo_raw (
    src_row_num bigint NOT NULL,
    done_raw text,
    priority_raw text,
    task_raw text,
    area_raw text,
    problem_raw text,
    notes_raw text,
    photo_raw text,
    assigned_to_raw text,
    date_added_raw text,
    added_by_raw text,
    date_complete_raw text,
    completed_by_raw text,
    email_sent_raw text,
    source_sheet text DEFAULT 'todo'::text NOT NULL,
    imported_at timestamp with time zone DEFAULT now() NOT NULL
);


ALTER TABLE stage.work_order_todo_raw OWNER TO msbadmin;

--
-- TOC entry 360 (class 1259 OID 18704)
-- Name: v_work_order_all_raw; Type: VIEW; Schema: stage; Owner: msbadmin
--

CREATE VIEW stage.v_work_order_all_raw AS
 SELECT 'todo'::text AS source_tab,
    NULLIF(btrim(work_order_todo_raw.priority_raw), ''::text) AS priority_raw,
    NULLIF(btrim(work_order_todo_raw.task_raw), ''::text) AS task_type_raw,
    NULLIF(btrim(work_order_todo_raw.area_raw), ''::text) AS work_area_raw,
    NULLIF(btrim(work_order_todo_raw.problem_raw), ''::text) AS problem_raw,
    NULLIF(btrim(work_order_todo_raw.notes_raw), ''::text) AS notes_raw,
    NULLIF(btrim(work_order_todo_raw.photo_raw), ''::text) AS photo_raw,
    NULLIF(btrim(work_order_todo_raw.assigned_to_raw), ''::text) AS assigned_to_raw,
    NULLIF(btrim(work_order_todo_raw.date_added_raw), ''::text) AS date_added_raw,
    NULLIF(btrim(work_order_todo_raw.added_by_raw), ''::text) AS added_by_raw,
    NULLIF(btrim(work_order_todo_raw.date_complete_raw), ''::text) AS date_complete_raw,
    NULLIF(btrim(work_order_todo_raw.completed_by_raw), ''::text) AS completed_by_raw
   FROM stage.work_order_todo_raw
UNION ALL
 SELECT 'completed'::text AS source_tab,
    NULLIF(btrim(work_order_completed_raw.priority_raw), ''::text) AS priority_raw,
    NULLIF(btrim(work_order_completed_raw.task_raw), ''::text) AS task_type_raw,
    NULLIF(btrim(work_order_completed_raw.area_raw), ''::text) AS work_area_raw,
    NULLIF(btrim(work_order_completed_raw.problem_raw), ''::text) AS problem_raw,
    NULLIF(btrim(work_order_completed_raw.notes_raw), ''::text) AS notes_raw,
    NULLIF(btrim(work_order_completed_raw.photo_raw), ''::text) AS photo_raw,
    NULLIF(btrim(work_order_completed_raw.assigned_to_raw), ''::text) AS assigned_to_raw,
    NULLIF(btrim(work_order_completed_raw.date_added_raw), ''::text) AS date_added_raw,
    NULLIF(btrim(work_order_completed_raw.added_by_raw), ''::text) AS added_by_raw,
    NULLIF(btrim(work_order_completed_raw.date_complete_raw), ''::text) AS date_complete_raw,
    NULLIF(btrim(work_order_completed_raw.completed_by_raw), ''::text) AS completed_by_raw
   FROM stage.work_order_completed_raw;


ALTER VIEW stage.v_work_order_all_raw OWNER TO msbadmin;

--
-- TOC entry 287 (class 1259 OID 16889)
-- Name: val_stages_raw; Type: TABLE; Schema: stage; Owner: msbadmin
--

CREATE TABLE stage.val_stages_raw (
    stage_id_text text,
    stage_key text,
    stage_name text,
    short_code text,
    folder_name text,
    folder_path text,
    notes text
);


ALTER TABLE stage.val_stages_raw OWNER TO msbadmin;

--
-- TOC entry 289 (class 1259 OID 16968)
-- Name: val_user_raw; Type: TABLE; Schema: stage; Owner: msbadmin
--

CREATE TABLE stage.val_user_raw (
    "UserID (PK)" integer,
    "First_Name" text,
    "Last_Name" text,
    "Prefered_Name" text,
    "Email" text,
    "Status" text,
    "Cell_Phone" text,
    "Title" text,
    "Committee" text,
    "Full Name" text,
    "Manager" boolean
);


ALTER TABLE stage.val_user_raw OWNER TO msbadmin;

--
-- TOC entry 358 (class 1259 OID 18687)
-- Name: work_order_completed_raw_src_row_num_seq; Type: SEQUENCE; Schema: stage; Owner: msbadmin
--

CREATE SEQUENCE stage.work_order_completed_raw_src_row_num_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE stage.work_order_completed_raw_src_row_num_seq OWNER TO msbadmin;

--
-- TOC entry 6448 (class 0 OID 0)
-- Dependencies: 358
-- Name: work_order_completed_raw_src_row_num_seq; Type: SEQUENCE OWNED BY; Schema: stage; Owner: msbadmin
--

ALTER SEQUENCE stage.work_order_completed_raw_src_row_num_seq OWNED BY stage.work_order_completed_raw.src_row_num;


--
-- TOC entry 372 (class 1259 OID 18976)
-- Name: work_order_intake; Type: TABLE; Schema: stage; Owner: directus_app
--

CREATE TABLE stage.work_order_intake (
    intake_id bigint NOT NULL,
    source_system character varying(30) DEFAULT 'GOOGLE_FORM'::text NOT NULL,
    source_form_name character varying(30),
    source_payload jsonb,
    source_row_hash character varying(64),
    submitter_email_raw character varying(64),
    submitter_name_raw character varying(100),
    submitted_at timestamp with time zone DEFAULT now() NOT NULL,
    priority_raw character varying(10) NOT NULL,
    task_type_raw character varying(50) NOT NULL,
    stage_raw character varying(100),
    problem_raw character varying(255) NOT NULL,
    notes_raw text,
    photo_url_raw character varying(255),
    triaged_at timestamp with time zone,
    triaged_by_person_id integer,
    triage_notes text,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    location_type_raw character varying(20),
    work_area_raw character varying(100),
    submitter_person_id integer,
    stage_id bigint,
    work_area_id bigint,
    task_type_id bigint,
    urgency_id smallint,
    target_year integer,
    created_by text DEFAULT CURRENT_USER NOT NULL,
    updated_by text DEFAULT CURRENT_USER NOT NULL,
    created_by_person_id integer,
    updated_by_person_id integer,
    triage_dropdown character varying(255) DEFAULT '1'::character varying,
    CONSTRAINT ck_work_order_intake_triage_dropdown CHECK (((triage_dropdown)::text = ANY ((ARRAY['1'::character varying, '3'::character varying, '4'::character varying])::text[])))
);


ALTER TABLE stage.work_order_intake OWNER TO directus_app;

--
-- TOC entry 6450 (class 0 OID 0)
-- Dependencies: 372
-- Name: COLUMN work_order_intake.stage_raw; Type: COMMENT; Schema: stage; Owner: directus_app
--

COMMENT ON COLUMN stage.work_order_intake.stage_raw IS 'Raw stage value selected in the Google Form when STAGE branch is used';


--
-- TOC entry 6451 (class 0 OID 0)
-- Dependencies: 372
-- Name: COLUMN work_order_intake.location_type_raw; Type: COMMENT; Schema: stage; Owner: directus_app
--

COMMENT ON COLUMN stage.work_order_intake.location_type_raw IS 'Branch selected in the Google Form: WORK_AREA or STAGE';


--
-- TOC entry 6452 (class 0 OID 0)
-- Dependencies: 372
-- Name: COLUMN work_order_intake.work_area_raw; Type: COMMENT; Schema: stage; Owner: directus_app
--

COMMENT ON COLUMN stage.work_order_intake.work_area_raw IS 'Raw work area selected in the Google Form when WORK_AREA branch is used';


--
-- TOC entry 371 (class 1259 OID 18975)
-- Name: work_order_intake_intake_id_seq; Type: SEQUENCE; Schema: stage; Owner: directus_app
--

ALTER TABLE stage.work_order_intake ALTER COLUMN intake_id ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME stage.work_order_intake_intake_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- TOC entry 356 (class 1259 OID 18652)
-- Name: work_order_todo_raw_src_row_num_seq; Type: SEQUENCE; Schema: stage; Owner: msbadmin
--

CREATE SEQUENCE stage.work_order_todo_raw_src_row_num_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE stage.work_order_todo_raw_src_row_num_seq OWNER TO msbadmin;

--
-- TOC entry 6453 (class 0 OID 0)
-- Dependencies: 356
-- Name: work_order_todo_raw_src_row_num_seq; Type: SEQUENCE OWNED BY; Schema: stage; Owner: msbadmin
--

ALTER SEQUENCE stage.work_order_todo_raw_src_row_num_seq OWNED BY stage.work_order_todo_raw.src_row_num;


--
-- TOC entry 4965 (class 2604 OID 16394)
-- Name: import_run import_run_id; Type: DEFAULT; Schema: lor_snap; Owner: msbadmin
--

ALTER TABLE ONLY lor_snap.import_run ALTER COLUMN import_run_id SET DEFAULT nextval('lor_snap.import_run_import_run_id_seq'::regclass);


--
-- TOC entry 5198 (class 2604 OID 20713)
-- Name: container_label_batch container_label_batch_id; Type: DEFAULT; Schema: ops; Owner: msbadmin
--

ALTER TABLE ONLY ops.container_label_batch ALTER COLUMN container_label_batch_id SET DEFAULT nextval('ops.container_label_batch_container_label_batch_id_seq'::regclass);


--
-- TOC entry 5201 (class 2604 OID 20725)
-- Name: container_label_batch_item container_label_batch_item_id; Type: DEFAULT; Schema: ops; Owner: msbadmin
--

ALTER TABLE ONLY ops.container_label_batch_item ALTER COLUMN container_label_batch_item_id SET DEFAULT nextval('ops.container_label_batch_item_container_label_batch_item_id_seq'::regclass);


--
-- TOC entry 5189 (class 2604 OID 20614)
-- Name: container_label_print container_label_print_id; Type: DEFAULT; Schema: ops; Owner: directus_app
--

ALTER TABLE ONLY ops.container_label_print ALTER COLUMN container_label_print_id SET DEFAULT nextval('ops.container_label_print_container_label_print_id_seq'::regclass);


--
-- TOC entry 5193 (class 2604 OID 20678)
-- Name: display_label_batch display_label_batch_id; Type: DEFAULT; Schema: ops; Owner: msbadmin
--

ALTER TABLE ONLY ops.display_label_batch ALTER COLUMN display_label_batch_id SET DEFAULT nextval('ops.display_label_batch_display_label_batch_id_seq'::regclass);


--
-- TOC entry 5196 (class 2604 OID 20690)
-- Name: display_label_batch_item display_label_batch_item_id; Type: DEFAULT; Schema: ops; Owner: msbadmin
--

ALTER TABLE ONLY ops.display_label_batch_item ALTER COLUMN display_label_batch_item_id SET DEFAULT nextval('ops.display_label_batch_item_display_label_batch_item_id_seq'::regclass);


--
-- TOC entry 5185 (class 2604 OID 20594)
-- Name: display_label_print display_label_print_id; Type: DEFAULT; Schema: ops; Owner: directus_app
--

ALTER TABLE ONLY ops.display_label_print ALTER COLUMN display_label_print_id SET DEFAULT nextval('ops.display_label_print_display_label_print_id_seq'::regclass);


--
-- TOC entry 5032 (class 2604 OID 17291)
-- Name: display_test_session display_test_session_id; Type: DEFAULT; Schema: ops; Owner: msbadmin
--

ALTER TABLE ONLY ops.display_test_session ALTER COLUMN display_test_session_id SET DEFAULT nextval('ops.display_test_session_display_test_session_id_seq'::regclass);


--
-- TOC entry 5021 (class 2604 OID 17260)
-- Name: test_session test_session_id; Type: DEFAULT; Schema: ops; Owner: msbadmin
--

ALTER TABLE ONLY ops.test_session ALTER COLUMN test_session_id SET DEFAULT nextval('ops.test_session_test_session_id_seq'::regclass);


--
-- TOC entry 5127 (class 2604 OID 18487)
-- Name: work_order work_order_id; Type: DEFAULT; Schema: ops; Owner: directus_app
--

ALTER TABLE ONLY ops.work_order ALTER COLUMN work_order_id SET DEFAULT nextval('ops.work_order_work_order_id_seq'::regclass);


--
-- TOC entry 5052 (class 2604 OID 17385)
-- Name: directus_activity id; Type: DEFAULT; Schema: public; Owner: directus_app
--

ALTER TABLE ONLY public.directus_activity ALTER COLUMN id SET DEFAULT nextval('public.directus_activity_id_seq'::regclass);


--
-- TOC entry 5046 (class 2604 OID 17362)
-- Name: directus_fields id; Type: DEFAULT; Schema: public; Owner: directus_app
--

ALTER TABLE ONLY public.directus_fields ALTER COLUMN id SET DEFAULT nextval('public.directus_fields_id_seq'::regclass);


--
-- TOC entry 5083 (class 2604 OID 17754)
-- Name: directus_notifications id; Type: DEFAULT; Schema: public; Owner: directus_app
--

ALTER TABLE ONLY public.directus_notifications ALTER COLUMN id SET DEFAULT nextval('public.directus_notifications_id_seq'::regclass);


--
-- TOC entry 5056 (class 2604 OID 17435)
-- Name: directus_permissions id; Type: DEFAULT; Schema: public; Owner: directus_app
--

ALTER TABLE ONLY public.directus_permissions ALTER COLUMN id SET DEFAULT nextval('public.directus_permissions_id_seq'::regclass);


--
-- TOC entry 5057 (class 2604 OID 17454)
-- Name: directus_presets id; Type: DEFAULT; Schema: public; Owner: directus_app
--

ALTER TABLE ONLY public.directus_presets ALTER COLUMN id SET DEFAULT nextval('public.directus_presets_id_seq'::regclass);


--
-- TOC entry 5060 (class 2604 OID 17479)
-- Name: directus_relations id; Type: DEFAULT; Schema: public; Owner: directus_app
--

ALTER TABLE ONLY public.directus_relations ALTER COLUMN id SET DEFAULT nextval('public.directus_relations_id_seq'::regclass);


--
-- TOC entry 5062 (class 2604 OID 17498)
-- Name: directus_revisions id; Type: DEFAULT; Schema: public; Owner: directus_app
--

ALTER TABLE ONLY public.directus_revisions ALTER COLUMN id SET DEFAULT nextval('public.directus_revisions_id_seq'::regclass);


--
-- TOC entry 5063 (class 2604 OID 17534)
-- Name: directus_settings id; Type: DEFAULT; Schema: public; Owner: directus_app
--

ALTER TABLE ONLY public.directus_settings ALTER COLUMN id SET DEFAULT nextval('public.directus_settings_id_seq'::regclass);


--
-- TOC entry 4983 (class 2604 OID 19208)
-- Name: container container_id; Type: DEFAULT; Schema: ref; Owner: msbadmin
--

ALTER TABLE ONLY ref.container ALTER COLUMN container_id SET DEFAULT nextval('ref.container_container_id_seq'::regclass);


--
-- TOC entry 5112 (class 2604 OID 19206)
-- Name: container_endpoint endpoint_id; Type: DEFAULT; Schema: ref; Owner: msbadmin
--

ALTER TABLE ONLY ref.container_endpoint ALTER COLUMN endpoint_id SET DEFAULT nextval('ref.container_endpoint_endpoint_id_seq'::regclass);


--
-- TOC entry 4997 (class 2604 OID 19210)
-- Name: person person_id; Type: DEFAULT; Schema: ref; Owner: msbadmin
--

ALTER TABLE ONLY ref.person ALTER COLUMN person_id SET DEFAULT nextval('ref.person_person_id_seq'::regclass);


--
-- TOC entry 5105 (class 2604 OID 18188)
-- Name: stage stage_id; Type: DEFAULT; Schema: ref; Owner: msbadmin
--

ALTER TABLE ONLY ref.stage ALTER COLUMN stage_id SET DEFAULT nextval('ref.stage_stage_id_seq'::regclass);


--
-- TOC entry 5117 (class 2604 OID 18396)
-- Name: task_type task_type_id; Type: DEFAULT; Schema: ref; Owner: msbadmin
--

ALTER TABLE ONLY ref.task_type ALTER COLUMN task_type_id SET DEFAULT nextval('ref.task_type_task_type_id_seq'::regclass);


--
-- TOC entry 5122 (class 2604 OID 18426)
-- Name: work_area work_area_id; Type: DEFAULT; Schema: ref; Owner: msbadmin
--

ALTER TABLE ONLY ref.work_area ALTER COLUMN work_area_id SET DEFAULT nextval('ref.work_area_work_area_id_seq'::regclass);


--
-- TOC entry 5141 (class 2604 OID 18691)
-- Name: work_order_completed_raw src_row_num; Type: DEFAULT; Schema: stage; Owner: msbadmin
--

ALTER TABLE ONLY stage.work_order_completed_raw ALTER COLUMN src_row_num SET DEFAULT nextval('stage.work_order_completed_raw_src_row_num_seq'::regclass);


--
-- TOC entry 5138 (class 2604 OID 18656)
-- Name: work_order_todo_raw src_row_num; Type: DEFAULT; Schema: stage; Owner: msbadmin
--

ALTER TABLE ONLY stage.work_order_todo_raw ALTER COLUMN src_row_num SET DEFAULT nextval('stage.work_order_todo_raw_src_row_num_seq'::regclass);


--
-- TOC entry 5310 (class 2606 OID 16463)
-- Name: dmx_channels dmx_channels_pkey; Type: CONSTRAINT; Schema: lor_snap; Owner: msbadmin
--

ALTER TABLE ONLY lor_snap.dmx_channels
    ADD CONSTRAINT dmx_channels_pkey PRIMARY KEY (import_run_id, int_dmx_channel_id);


--
-- TOC entry 5294 (class 2606 OID 16399)
-- Name: import_run import_run_pkey; Type: CONSTRAINT; Schema: lor_snap; Owner: msbadmin
--

ALTER TABLE ONLY lor_snap.import_run
    ADD CONSTRAINT import_run_pkey PRIMARY KEY (import_run_id);


--
-- TOC entry 5296 (class 2606 OID 16408)
-- Name: previews previews_import_run_id_id_key; Type: CONSTRAINT; Schema: lor_snap; Owner: msbadmin
--

ALTER TABLE ONLY lor_snap.previews
    ADD CONSTRAINT previews_import_run_id_id_key UNIQUE (import_run_id, id);


--
-- TOC entry 5298 (class 2606 OID 16406)
-- Name: previews previews_pkey; Type: CONSTRAINT; Schema: lor_snap; Owner: msbadmin
--

ALTER TABLE ONLY lor_snap.previews
    ADD CONSTRAINT previews_pkey PRIMARY KEY (import_run_id, int_preview_id);


--
-- TOC entry 5301 (class 2606 OID 16422)
-- Name: props props_import_run_id_prop_id_key; Type: CONSTRAINT; Schema: lor_snap; Owner: msbadmin
--

ALTER TABLE ONLY lor_snap.props
    ADD CONSTRAINT props_import_run_id_prop_id_key UNIQUE (import_run_id, prop_id);


--
-- TOC entry 5303 (class 2606 OID 16420)
-- Name: props props_pkey; Type: CONSTRAINT; Schema: lor_snap; Owner: msbadmin
--

ALTER TABLE ONLY lor_snap.props
    ADD CONSTRAINT props_pkey PRIMARY KEY (import_run_id, int_prop_id);


--
-- TOC entry 5306 (class 2606 OID 16441)
-- Name: sub_props sub_props_import_run_id_sub_prop_id_key; Type: CONSTRAINT; Schema: lor_snap; Owner: msbadmin
--

ALTER TABLE ONLY lor_snap.sub_props
    ADD CONSTRAINT sub_props_import_run_id_sub_prop_id_key UNIQUE (import_run_id, sub_prop_id);


--
-- TOC entry 5308 (class 2606 OID 16439)
-- Name: sub_props sub_props_pkey; Type: CONSTRAINT; Schema: lor_snap; Owner: msbadmin
--

ALTER TABLE ONLY lor_snap.sub_props
    ADD CONSTRAINT sub_props_pkey PRIMARY KEY (import_run_id, int_sub_prop_id);


--
-- TOC entry 5544 (class 2606 OID 20732)
-- Name: container_label_batch_item container_label_batch_item_container_label_batch_id_contain_key; Type: CONSTRAINT; Schema: ops; Owner: msbadmin
--

ALTER TABLE ONLY ops.container_label_batch_item
    ADD CONSTRAINT container_label_batch_item_container_label_batch_id_contain_key UNIQUE (container_label_batch_id, container_id);


--
-- TOC entry 5546 (class 2606 OID 20730)
-- Name: container_label_batch_item container_label_batch_item_pkey; Type: CONSTRAINT; Schema: ops; Owner: msbadmin
--

ALTER TABLE ONLY ops.container_label_batch_item
    ADD CONSTRAINT container_label_batch_item_pkey PRIMARY KEY (container_label_batch_item_id);


--
-- TOC entry 5541 (class 2606 OID 20719)
-- Name: container_label_batch container_label_batch_pkey; Type: CONSTRAINT; Schema: ops; Owner: msbadmin
--

ALTER TABLE ONLY ops.container_label_batch
    ADD CONSTRAINT container_label_batch_pkey PRIMARY KEY (container_label_batch_id);


--
-- TOC entry 5526 (class 2606 OID 20623)
-- Name: container_label_print container_label_print_pkey; Type: CONSTRAINT; Schema: ops; Owner: directus_app
--

ALTER TABLE ONLY ops.container_label_print
    ADD CONSTRAINT container_label_print_pkey PRIMARY KEY (container_label_print_id);


--
-- TOC entry 5533 (class 2606 OID 20697)
-- Name: display_label_batch_item display_label_batch_item_display_label_batch_id_display_id_key; Type: CONSTRAINT; Schema: ops; Owner: msbadmin
--

ALTER TABLE ONLY ops.display_label_batch_item
    ADD CONSTRAINT display_label_batch_item_display_label_batch_id_display_id_key UNIQUE (display_label_batch_id, display_id);


--
-- TOC entry 5535 (class 2606 OID 20695)
-- Name: display_label_batch_item display_label_batch_item_pkey; Type: CONSTRAINT; Schema: ops; Owner: msbadmin
--

ALTER TABLE ONLY ops.display_label_batch_item
    ADD CONSTRAINT display_label_batch_item_pkey PRIMARY KEY (display_label_batch_item_id);


--
-- TOC entry 5530 (class 2606 OID 20684)
-- Name: display_label_batch display_label_batch_pkey; Type: CONSTRAINT; Schema: ops; Owner: msbadmin
--

ALTER TABLE ONLY ops.display_label_batch
    ADD CONSTRAINT display_label_batch_pkey PRIMARY KEY (display_label_batch_id);


--
-- TOC entry 5522 (class 2606 OID 20602)
-- Name: display_label_print display_label_print_pkey; Type: CONSTRAINT; Schema: ops; Owner: directus_app
--

ALTER TABLE ONLY ops.display_label_print
    ADD CONSTRAINT display_label_print_pkey PRIMARY KEY (display_label_print_id);


--
-- TOC entry 5371 (class 2606 OID 17296)
-- Name: display_test_session display_test_session_pkey; Type: CONSTRAINT; Schema: ops; Owner: msbadmin
--

ALTER TABLE ONLY ops.display_test_session
    ADD CONSTRAINT display_test_session_pkey PRIMARY KEY (display_test_session_id);


--
-- TOC entry 5598 (class 2606 OID 23517)
-- Name: lor_reconciliation_action_assignment lor_reconciliation_action_assignment_pkey; Type: CONSTRAINT; Schema: ops; Owner: msbadmin
--

ALTER TABLE ONLY ops.lor_reconciliation_action_assignment
    ADD CONSTRAINT lor_reconciliation_action_assignment_pkey PRIMARY KEY (lor_reconciliation_action_assignment_id);


--
-- TOC entry 5561 (class 2606 OID 23194)
-- Name: lor_reconciliation_action_legacy lor_reconciliation_action_legacy_pkey; Type: CONSTRAINT; Schema: ops; Owner: msbadmin
--

ALTER TABLE ONLY ops.lor_reconciliation_action_legacy
    ADD CONSTRAINT lor_reconciliation_action_legacy_pkey PRIMARY KEY (lor_reconciliation_action_id);


--
-- TOC entry 5596 (class 2606 OID 23498)
-- Name: lor_reconciliation_action lor_reconciliation_action_pkey; Type: CONSTRAINT; Schema: ops; Owner: msbadmin
--

ALTER TABLE ONLY ops.lor_reconciliation_action
    ADD CONSTRAINT lor_reconciliation_action_pkey PRIMARY KEY (lor_reconciliation_action_id);


--
-- TOC entry 5591 (class 2606 OID 23465)
-- Name: lor_reconciliation_display_candidate lor_reconciliation_display_candidate_pkey; Type: CONSTRAINT; Schema: ops; Owner: msbadmin
--

ALTER TABLE ONLY ops.lor_reconciliation_display_candidate
    ADD CONSTRAINT lor_reconciliation_display_candidate_pkey PRIMARY KEY (lor_reconciliation_display_candidate_id);


--
-- TOC entry 5585 (class 2606 OID 23443)
-- Name: lor_reconciliation_group lor_reconciliation_group_pkey; Type: CONSTRAINT; Schema: ops; Owner: msbadmin
--

ALTER TABLE ONLY ops.lor_reconciliation_group
    ADD CONSTRAINT lor_reconciliation_group_pkey PRIMARY KEY (lor_reconciliation_group_id);


--
-- TOC entry 5604 (class 2606 OID 23548)
-- Name: lor_reconciliation_result lor_reconciliation_result_pkey; Type: CONSTRAINT; Schema: ops; Owner: msbadmin
--

ALTER TABLE ONLY ops.lor_reconciliation_result
    ADD CONSTRAINT lor_reconciliation_result_pkey PRIMARY KEY (lor_reconciliation_result_id);


--
-- TOC entry 5579 (class 2606 OID 23423)
-- Name: lor_reconciliation_run lor_reconciliation_run_pkey; Type: CONSTRAINT; Schema: ops; Owner: msbadmin
--

ALTER TABLE ONLY ops.lor_reconciliation_run
    ADD CONSTRAINT lor_reconciliation_run_pkey PRIMARY KEY (lor_reconciliation_run_id);


--
-- TOC entry 5618 (class 2606 OID 23728)
-- Name: lor_reconciliation_scene_candidate lor_reconciliation_scene_candidate_pkey; Type: CONSTRAINT; Schema: ops; Owner: msbadmin
--

ALTER TABLE ONLY ops.lor_reconciliation_scene_candidate
    ADD CONSTRAINT lor_reconciliation_scene_candidate_pkey PRIMARY KEY (lor_reconciliation_scene_candidate_id);


--
-- TOC entry 5624 (class 2606 OID 23761)
-- Name: lor_reconciliation_scene_display_candidate lor_reconciliation_scene_display_candidate_pkey; Type: CONSTRAINT; Schema: ops; Owner: msbadmin
--

ALTER TABLE ONLY ops.lor_reconciliation_scene_display_candidate
    ADD CONSTRAINT lor_reconciliation_scene_display_candidate_pkey PRIMARY KEY (lor_reconciliation_scene_display_candidate_id);


--
-- TOC entry 5632 (class 2606 OID 23900)
-- Name: lor_reconciliation_source_preview lor_reconciliation_source_preview_pkey; Type: CONSTRAINT; Schema: ops; Owner: msbadmin
--

ALTER TABLE ONLY ops.lor_reconciliation_source_preview
    ADD CONSTRAINT lor_reconciliation_source_preview_pkey PRIMARY KEY (lor_reconciliation_source_preview_id);


--
-- TOC entry 5628 (class 2606 OID 23884)
-- Name: lor_reconciliation_source_run lor_reconciliation_source_run_pkey; Type: CONSTRAINT; Schema: ops; Owner: msbadmin
--

ALTER TABLE ONLY ops.lor_reconciliation_source_run
    ADD CONSTRAINT lor_reconciliation_source_run_pkey PRIMARY KEY (lor_reconciliation_run_id);


--
-- TOC entry 5637 (class 2606 OID 23916)
-- Name: lor_reconciliation_source_scene lor_reconciliation_source_scene_pkey; Type: CONSTRAINT; Schema: ops; Owner: msbadmin
--

ALTER TABLE ONLY ops.lor_reconciliation_source_scene
    ADD CONSTRAINT lor_reconciliation_source_scene_pkey PRIMARY KEY (lor_reconciliation_source_scene_row_id);


--
-- TOC entry 5612 (class 2606 OID 23626)
-- Name: lor_reconciliation_stage_candidate lor_reconciliation_stage_candidate_pkey; Type: CONSTRAINT; Schema: ops; Owner: msbadmin
--

ALTER TABLE ONLY ops.lor_reconciliation_stage_candidate
    ADD CONSTRAINT lor_reconciliation_stage_candidate_pkey PRIMARY KEY (lor_reconciliation_stage_candidate_id);


--
-- TOC entry 5366 (class 2606 OID 17267)
-- Name: test_session test_session_pkey; Type: CONSTRAINT; Schema: ops; Owner: msbadmin
--

ALTER TABLE ONLY ops.test_session
    ADD CONSTRAINT test_session_pkey PRIMARY KEY (test_session_id);


--
-- TOC entry 5550 (class 2606 OID 20779)
-- Name: container_label_batch_item uq_container_label_batch_item_batch_container; Type: CONSTRAINT; Schema: ops; Owner: msbadmin
--

ALTER TABLE ONLY ops.container_label_batch_item
    ADD CONSTRAINT uq_container_label_batch_item_batch_container UNIQUE (container_label_batch_id, container_id);


--
-- TOC entry 5539 (class 2606 OID 20761)
-- Name: display_label_batch_item uq_display_label_batch_item_batch_display; Type: CONSTRAINT; Schema: ops; Owner: msbadmin
--

ALTER TABLE ONLY ops.display_label_batch_item
    ADD CONSTRAINT uq_display_label_batch_item_batch_display UNIQUE (display_label_batch_id, display_id);


--
-- TOC entry 5373 (class 2606 OID 18748)
-- Name: display_test_session uq_display_per_session_display_id; Type: CONSTRAINT; Schema: ops; Owner: msbadmin
--

ALTER TABLE ONLY ops.display_test_session
    ADD CONSTRAINT uq_display_per_session_display_id UNIQUE (test_session_id, display_id);


--
-- TOC entry 5368 (class 2606 OID 19543)
-- Name: test_session uq_test_session_season_container; Type: CONSTRAINT; Schema: ops; Owner: msbadmin
--

ALTER TABLE ONLY ops.test_session
    ADD CONSTRAINT uq_test_session_season_container UNIQUE (season_year, container_id);


--
-- TOC entry 5600 (class 2606 OID 23519)
-- Name: lor_reconciliation_action_assignment ux_lor_reconciliation_assignment_candidate; Type: CONSTRAINT; Schema: ops; Owner: msbadmin
--

ALTER TABLE ONLY ops.lor_reconciliation_action_assignment
    ADD CONSTRAINT ux_lor_reconciliation_assignment_candidate UNIQUE (lor_reconciliation_action_id, lor_reconciliation_display_candidate_id);


--
-- TOC entry 5602 (class 2606 OID 23521)
-- Name: lor_reconciliation_action_assignment ux_lor_reconciliation_assignment_target; Type: CONSTRAINT; Schema: ops; Owner: msbadmin
--

ALTER TABLE ONLY ops.lor_reconciliation_action_assignment
    ADD CONSTRAINT ux_lor_reconciliation_assignment_target UNIQUE (lor_reconciliation_action_id, target_display_id);


--
-- TOC entry 5593 (class 2606 OID 23467)
-- Name: lor_reconciliation_display_candidate ux_lor_reconciliation_display_candidate; Type: CONSTRAINT; Schema: ops; Owner: msbadmin
--

ALTER TABLE ONLY ops.lor_reconciliation_display_candidate
    ADD CONSTRAINT ux_lor_reconciliation_display_candidate UNIQUE (lor_reconciliation_run_id, candidate_key);


--
-- TOC entry 5587 (class 2606 OID 23445)
-- Name: lor_reconciliation_group ux_lor_reconciliation_group_key; Type: CONSTRAINT; Schema: ops; Owner: msbadmin
--

ALTER TABLE ONLY ops.lor_reconciliation_group
    ADD CONSTRAINT ux_lor_reconciliation_group_key UNIQUE (lor_reconciliation_run_id, entity_type, logical_group_key);


--
-- TOC entry 5582 (class 2606 OID 24237)
-- Name: lor_reconciliation_run ux_lor_reconciliation_run_import; Type: CONSTRAINT; Schema: ops; Owner: msbadmin
--

ALTER TABLE ONLY ops.lor_reconciliation_run
    ADD CONSTRAINT ux_lor_reconciliation_run_import UNIQUE (import_run_id);


--
-- TOC entry 6455 (class 0 OID 0)
-- Dependencies: 5582
-- Name: CONSTRAINT ux_lor_reconciliation_run_import ON lor_reconciliation_run; Type: COMMENT; Schema: ops; Owner: msbadmin
--

COMMENT ON CONSTRAINT ux_lor_reconciliation_run_import ON ops.lor_reconciliation_run IS 'A committed LOR snapshot is permanently owned by exactly one reconciliation run, including terminal CANCELLED and FAILED runs.';


--
-- TOC entry 5620 (class 2606 OID 23730)
-- Name: lor_reconciliation_scene_candidate ux_lor_reconciliation_scene_candidate; Type: CONSTRAINT; Schema: ops; Owner: msbadmin
--

ALTER TABLE ONLY ops.lor_reconciliation_scene_candidate
    ADD CONSTRAINT ux_lor_reconciliation_scene_candidate UNIQUE (lor_reconciliation_run_id, candidate_key);


--
-- TOC entry 5626 (class 2606 OID 23763)
-- Name: lor_reconciliation_scene_display_candidate ux_lor_reconciliation_scene_display_candidate; Type: CONSTRAINT; Schema: ops; Owner: msbadmin
--

ALTER TABLE ONLY ops.lor_reconciliation_scene_display_candidate
    ADD CONSTRAINT ux_lor_reconciliation_scene_display_candidate UNIQUE (lor_reconciliation_run_id, candidate_key);


--
-- TOC entry 5634 (class 2606 OID 23902)
-- Name: lor_reconciliation_source_preview ux_lor_reconciliation_source_preview; Type: CONSTRAINT; Schema: ops; Owner: msbadmin
--

ALTER TABLE ONLY ops.lor_reconciliation_source_preview
    ADD CONSTRAINT ux_lor_reconciliation_source_preview UNIQUE (lor_reconciliation_run_id, int_preview_id);


--
-- TOC entry 5630 (class 2606 OID 23886)
-- Name: lor_reconciliation_source_run ux_lor_reconciliation_source_run_import; Type: CONSTRAINT; Schema: ops; Owner: msbadmin
--

ALTER TABLE ONLY ops.lor_reconciliation_source_run
    ADD CONSTRAINT ux_lor_reconciliation_source_run_import UNIQUE (lor_reconciliation_run_id, import_run_id);


--
-- TOC entry 5614 (class 2606 OID 23628)
-- Name: lor_reconciliation_stage_candidate ux_lor_reconciliation_stage_candidate; Type: CONSTRAINT; Schema: ops; Owner: msbadmin
--

ALTER TABLE ONLY ops.lor_reconciliation_stage_candidate
    ADD CONSTRAINT ux_lor_reconciliation_stage_candidate UNIQUE (lor_reconciliation_run_id, candidate_key);


--
-- TOC entry 5504 (class 2606 OID 19019)
-- Name: work_order_assignment work_order_assignment_pkey; Type: CONSTRAINT; Schema: ops; Owner: directus_app
--

ALTER TABLE ONLY ops.work_order_assignment
    ADD CONSTRAINT work_order_assignment_pkey PRIMARY KEY (work_order_assignment_id);


--
-- TOC entry 5510 (class 2606 OID 19079)
-- Name: work_order_outbound_message work_order_outbound_message_pkey; Type: CONSTRAINT; Schema: ops; Owner: msbadmin
--

ALTER TABLE ONLY ops.work_order_outbound_message
    ADD CONSTRAINT work_order_outbound_message_pkey PRIMARY KEY (outbound_message_id);


--
-- TOC entry 5475 (class 2606 OID 18493)
-- Name: work_order work_order_pkey; Type: CONSTRAINT; Schema: ops; Owner: directus_app
--

ALTER TABLE ONLY ops.work_order
    ADD CONSTRAINT work_order_pkey PRIMARY KEY (work_order_id);


--
-- TOC entry 5507 (class 2606 OID 19051)
-- Name: work_order_status_history work_order_status_history_pkey; Type: CONSTRAINT; Schema: ops; Owner: msbadmin
--

ALTER TABLE ONLY ops.work_order_status_history
    ADD CONSTRAINT work_order_status_history_pkey PRIMARY KEY (work_order_status_history_id);


--
-- TOC entry 5439 (class 2606 OID 17948)
-- Name: directus_access directus_access_pkey; Type: CONSTRAINT; Schema: public; Owner: directus_app
--

ALTER TABLE ONLY public.directus_access
    ADD CONSTRAINT directus_access_pkey PRIMARY KEY (id);


--
-- TOC entry 5390 (class 2606 OID 17390)
-- Name: directus_activity directus_activity_pkey; Type: CONSTRAINT; Schema: public; Owner: directus_app
--

ALTER TABLE ONLY public.directus_activity
    ADD CONSTRAINT directus_activity_pkey PRIMARY KEY (id);


--
-- TOC entry 5376 (class 2606 OID 17329)
-- Name: directus_collections directus_collections_pkey; Type: CONSTRAINT; Schema: public; Owner: directus_app
--

ALTER TABLE ONLY public.directus_collections
    ADD CONSTRAINT directus_collections_pkey PRIMARY KEY (collection);


--
-- TOC entry 5441 (class 2606 OID 17976)
-- Name: directus_comments directus_comments_pkey; Type: CONSTRAINT; Schema: public; Owner: directus_app
--

ALTER TABLE ONLY public.directus_comments
    ADD CONSTRAINT directus_comments_pkey PRIMARY KEY (id);


--
-- TOC entry 5413 (class 2606 OID 17699)
-- Name: directus_dashboards directus_dashboards_pkey; Type: CONSTRAINT; Schema: public; Owner: directus_app
--

ALTER TABLE ONLY public.directus_dashboards
    ADD CONSTRAINT directus_dashboards_pkey PRIMARY KEY (id);


--
-- TOC entry 5447 (class 2606 OID 18032)
-- Name: directus_deployment_projects directus_deployment_projects_deployment_external_id_unique; Type: CONSTRAINT; Schema: public; Owner: directus_app
--

ALTER TABLE ONLY public.directus_deployment_projects
    ADD CONSTRAINT directus_deployment_projects_deployment_external_id_unique UNIQUE (deployment, external_id);


--
-- TOC entry 5449 (class 2606 OID 18020)
-- Name: directus_deployment_projects directus_deployment_projects_pkey; Type: CONSTRAINT; Schema: public; Owner: directus_app
--

ALTER TABLE ONLY public.directus_deployment_projects
    ADD CONSTRAINT directus_deployment_projects_pkey PRIMARY KEY (id);


--
-- TOC entry 5451 (class 2606 OID 18040)
-- Name: directus_deployment_runs directus_deployment_runs_pkey; Type: CONSTRAINT; Schema: public; Owner: directus_app
--

ALTER TABLE ONLY public.directus_deployment_runs
    ADD CONSTRAINT directus_deployment_runs_pkey PRIMARY KEY (id);


--
-- TOC entry 5443 (class 2606 OID 18005)
-- Name: directus_deployments directus_deployments_pkey; Type: CONSTRAINT; Schema: public; Owner: directus_app
--

ALTER TABLE ONLY public.directus_deployments
    ADD CONSTRAINT directus_deployments_pkey PRIMARY KEY (id);


--
-- TOC entry 5445 (class 2606 OID 18007)
-- Name: directus_deployments directus_deployments_provider_unique; Type: CONSTRAINT; Schema: public; Owner: directus_app
--

ALTER TABLE ONLY public.directus_deployments
    ADD CONSTRAINT directus_deployments_provider_unique UNIQUE (provider);


--
-- TOC entry 5435 (class 2606 OID 17909)
-- Name: directus_extensions directus_extensions_pkey; Type: CONSTRAINT; Schema: public; Owner: directus_app
--

ALTER TABLE ONLY public.directus_extensions
    ADD CONSTRAINT directus_extensions_pkey PRIMARY KEY (id);


--
-- TOC entry 5388 (class 2606 OID 17370)
-- Name: directus_fields directus_fields_pkey; Type: CONSTRAINT; Schema: public; Owner: directus_app
--

ALTER TABLE ONLY public.directus_fields
    ADD CONSTRAINT directus_fields_pkey PRIMARY KEY (id);


--
-- TOC entry 5395 (class 2606 OID 17415)
-- Name: directus_files directus_files_pkey; Type: CONSTRAINT; Schema: public; Owner: directus_app
--

ALTER TABLE ONLY public.directus_files
    ADD CONSTRAINT directus_files_pkey PRIMARY KEY (id);


--
-- TOC entry 5421 (class 2606 OID 17816)
-- Name: directus_flows directus_flows_operation_unique; Type: CONSTRAINT; Schema: public; Owner: directus_app
--

ALTER TABLE ONLY public.directus_flows
    ADD CONSTRAINT directus_flows_operation_unique UNIQUE (operation);


--
-- TOC entry 5423 (class 2606 OID 17814)
-- Name: directus_flows directus_flows_pkey; Type: CONSTRAINT; Schema: public; Owner: directus_app
--

ALTER TABLE ONLY public.directus_flows
    ADD CONSTRAINT directus_flows_pkey PRIMARY KEY (id);


--
-- TOC entry 5393 (class 2606 OID 17400)
-- Name: directus_folders directus_folders_pkey; Type: CONSTRAINT; Schema: public; Owner: directus_app
--

ALTER TABLE ONLY public.directus_folders
    ADD CONSTRAINT directus_folders_pkey PRIMARY KEY (id);


--
-- TOC entry 5411 (class 2606 OID 17577)
-- Name: directus_migrations directus_migrations_pkey; Type: CONSTRAINT; Schema: public; Owner: directus_app
--

ALTER TABLE ONLY public.directus_migrations
    ADD CONSTRAINT directus_migrations_pkey PRIMARY KEY (version);


--
-- TOC entry 5417 (class 2606 OID 17759)
-- Name: directus_notifications directus_notifications_pkey; Type: CONSTRAINT; Schema: public; Owner: directus_app
--

ALTER TABLE ONLY public.directus_notifications
    ADD CONSTRAINT directus_notifications_pkey PRIMARY KEY (id);


--
-- TOC entry 5425 (class 2606 OID 17829)
-- Name: directus_operations directus_operations_pkey; Type: CONSTRAINT; Schema: public; Owner: directus_app
--

ALTER TABLE ONLY public.directus_operations
    ADD CONSTRAINT directus_operations_pkey PRIMARY KEY (id);


--
-- TOC entry 5427 (class 2606 OID 17838)
-- Name: directus_operations directus_operations_reject_unique; Type: CONSTRAINT; Schema: public; Owner: directus_app
--

ALTER TABLE ONLY public.directus_operations
    ADD CONSTRAINT directus_operations_reject_unique UNIQUE (reject);


--
-- TOC entry 5429 (class 2606 OID 17831)
-- Name: directus_operations directus_operations_resolve_unique; Type: CONSTRAINT; Schema: public; Owner: directus_app
--

ALTER TABLE ONLY public.directus_operations
    ADD CONSTRAINT directus_operations_resolve_unique UNIQUE (resolve);


--
-- TOC entry 5415 (class 2606 OID 17714)
-- Name: directus_panels directus_panels_pkey; Type: CONSTRAINT; Schema: public; Owner: directus_app
--

ALTER TABLE ONLY public.directus_panels
    ADD CONSTRAINT directus_panels_pkey PRIMARY KEY (id);


--
-- TOC entry 5397 (class 2606 OID 17439)
-- Name: directus_permissions directus_permissions_pkey; Type: CONSTRAINT; Schema: public; Owner: directus_app
--

ALTER TABLE ONLY public.directus_permissions
    ADD CONSTRAINT directus_permissions_pkey PRIMARY KEY (id);


--
-- TOC entry 5437 (class 2606 OID 17933)
-- Name: directus_policies directus_policies_pkey; Type: CONSTRAINT; Schema: public; Owner: directus_app
--

ALTER TABLE ONLY public.directus_policies
    ADD CONSTRAINT directus_policies_pkey PRIMARY KEY (id);


--
-- TOC entry 5399 (class 2606 OID 17459)
-- Name: directus_presets directus_presets_pkey; Type: CONSTRAINT; Schema: public; Owner: directus_app
--

ALTER TABLE ONLY public.directus_presets
    ADD CONSTRAINT directus_presets_pkey PRIMARY KEY (id);


--
-- TOC entry 5401 (class 2606 OID 17483)
-- Name: directus_relations directus_relations_pkey; Type: CONSTRAINT; Schema: public; Owner: directus_app
--

ALTER TABLE ONLY public.directus_relations
    ADD CONSTRAINT directus_relations_pkey PRIMARY KEY (id);


--
-- TOC entry 5405 (class 2606 OID 17502)
-- Name: directus_revisions directus_revisions_pkey; Type: CONSTRAINT; Schema: public; Owner: directus_app
--

ALTER TABLE ONLY public.directus_revisions
    ADD CONSTRAINT directus_revisions_pkey PRIMARY KEY (id);


--
-- TOC entry 5378 (class 2606 OID 17340)
-- Name: directus_roles directus_roles_pkey; Type: CONSTRAINT; Schema: public; Owner: directus_app
--

ALTER TABLE ONLY public.directus_roles
    ADD CONSTRAINT directus_roles_pkey PRIMARY KEY (id);


--
-- TOC entry 5407 (class 2606 OID 17524)
-- Name: directus_sessions directus_sessions_pkey; Type: CONSTRAINT; Schema: public; Owner: directus_app
--

ALTER TABLE ONLY public.directus_sessions
    ADD CONSTRAINT directus_sessions_pkey PRIMARY KEY (token);


--
-- TOC entry 5409 (class 2606 OID 17542)
-- Name: directus_settings directus_settings_pkey; Type: CONSTRAINT; Schema: public; Owner: directus_app
--

ALTER TABLE ONLY public.directus_settings
    ADD CONSTRAINT directus_settings_pkey PRIMARY KEY (id);


--
-- TOC entry 5419 (class 2606 OID 17779)
-- Name: directus_shares directus_shares_pkey; Type: CONSTRAINT; Schema: public; Owner: directus_app
--

ALTER TABLE ONLY public.directus_shares
    ADD CONSTRAINT directus_shares_pkey PRIMARY KEY (id);


--
-- TOC entry 5431 (class 2606 OID 17862)
-- Name: directus_translations directus_translations_pkey; Type: CONSTRAINT; Schema: public; Owner: directus_app
--

ALTER TABLE ONLY public.directus_translations
    ADD CONSTRAINT directus_translations_pkey PRIMARY KEY (id);


--
-- TOC entry 5380 (class 2606 OID 17741)
-- Name: directus_users directus_users_email_unique; Type: CONSTRAINT; Schema: public; Owner: directus_app
--

ALTER TABLE ONLY public.directus_users
    ADD CONSTRAINT directus_users_email_unique UNIQUE (email);


--
-- TOC entry 5382 (class 2606 OID 17739)
-- Name: directus_users directus_users_external_identifier_unique; Type: CONSTRAINT; Schema: public; Owner: directus_app
--

ALTER TABLE ONLY public.directus_users
    ADD CONSTRAINT directus_users_external_identifier_unique UNIQUE (external_identifier);


--
-- TOC entry 5384 (class 2606 OID 17350)
-- Name: directus_users directus_users_pkey; Type: CONSTRAINT; Schema: public; Owner: directus_app
--

ALTER TABLE ONLY public.directus_users
    ADD CONSTRAINT directus_users_pkey PRIMARY KEY (id);


--
-- TOC entry 5386 (class 2606 OID 17749)
-- Name: directus_users directus_users_token_unique; Type: CONSTRAINT; Schema: public; Owner: directus_app
--

ALTER TABLE ONLY public.directus_users
    ADD CONSTRAINT directus_users_token_unique UNIQUE (token);


--
-- TOC entry 5433 (class 2606 OID 17871)
-- Name: directus_versions directus_versions_pkey; Type: CONSTRAINT; Schema: public; Owner: directus_app
--

ALTER TABLE ONLY public.directus_versions
    ADD CONSTRAINT directus_versions_pkey PRIMARY KEY (id);


--
-- TOC entry 5512 (class 2606 OID 19222)
-- Name: audit_collection_policy audit_collection_policy_pkey; Type: CONSTRAINT; Schema: ref; Owner: msbadmin
--

ALTER TABLE ONLY ref.audit_collection_policy
    ADD CONSTRAINT audit_collection_policy_pkey PRIMARY KEY (audit_collection_policy_id);


--
-- TOC entry 5461 (class 2606 OID 18288)
-- Name: container_endpoint container_endpoint_pkey; Type: CONSTRAINT; Schema: ref; Owner: msbadmin
--

ALTER TABLE ONLY ref.container_endpoint
    ADD CONSTRAINT container_endpoint_pkey PRIMARY KEY (endpoint_id);


--
-- TOC entry 5486 (class 2606 OID 18949)
-- Name: container_test_status container_test_status_container_test_status_code_key; Type: CONSTRAINT; Schema: ref; Owner: msbadmin
--

ALTER TABLE ONLY ref.container_test_status
    ADD CONSTRAINT container_test_status_container_test_status_code_key UNIQUE (container_test_status_code);


--
-- TOC entry 5488 (class 2606 OID 18947)
-- Name: container_test_status container_test_status_pkey; Type: CONSTRAINT; Schema: ref; Owner: msbadmin
--

ALTER TABLE ONLY ref.container_test_status
    ADD CONSTRAINT container_test_status_pkey PRIMARY KEY (container_test_status_id);


--
-- TOC entry 5351 (class 2606 OID 18845)
-- Name: display display_pkey; Type: CONSTRAINT; Schema: ref; Owner: msbadmin
--

ALTER TABLE ONLY ref.display
    ADD CONSTRAINT display_pkey PRIMARY KEY (display_id);


--
-- TOC entry 5322 (class 2606 OID 16773)
-- Name: display_status display_status_display_status_name_key; Type: CONSTRAINT; Schema: ref; Owner: msbadmin
--

ALTER TABLE ONLY ref.display_status
    ADD CONSTRAINT display_status_display_status_name_key UNIQUE (display_status_name);


--
-- TOC entry 5324 (class 2606 OID 16771)
-- Name: display_status display_status_pkey; Type: CONSTRAINT; Schema: ref; Owner: msbadmin
--

ALTER TABLE ONLY ref.display_status
    ADD CONSTRAINT display_status_pkey PRIMARY KEY (display_status_id);


--
-- TOC entry 5484 (class 2606 OID 18913)
-- Name: display_test_status display_test_status_pkey; Type: CONSTRAINT; Schema: ref; Owner: msbadmin
--

ALTER TABLE ONLY ref.display_test_status
    ADD CONSTRAINT display_test_status_pkey PRIMARY KEY (test_status_code);


--
-- TOC entry 5312 (class 2606 OID 16716)
-- Name: frame frame_pkey; Type: CONSTRAINT; Schema: ref; Owner: msbadmin
--

ALTER TABLE ONLY ref.frame
    ADD CONSTRAINT frame_pkey PRIMARY KEY (frame_id);


--
-- TOC entry 5349 (class 2606 OID 17034)
-- Name: inventory_type inventory_type_pkey; Type: CONSTRAINT; Schema: ref; Owner: msbadmin
--

ALTER TABLE ONLY ref.inventory_type
    ADD CONSTRAINT inventory_type_pkey PRIMARY KEY (inventory_type);


--
-- TOC entry 5566 (class 2606 OID 23236)
-- Name: lor_scene lor_scene_pkey; Type: CONSTRAINT; Schema: ref; Owner: msbadmin
--

ALTER TABLE ONLY ref.lor_scene
    ADD CONSTRAINT lor_scene_pkey PRIMARY KEY (lor_scene_id);


--
-- TOC entry 5330 (class 2606 OID 16831)
-- Name: container pallet_pkey; Type: CONSTRAINT; Schema: ref; Owner: msbadmin
--

ALTER TABLE ONLY ref.container
    ADD CONSTRAINT pallet_pkey PRIMARY KEY (container_id);


--
-- TOC entry 5326 (class 2606 OID 16818)
-- Name: container_type pallet_type_pallet_type_name_key; Type: CONSTRAINT; Schema: ref; Owner: msbadmin
--

ALTER TABLE ONLY ref.container_type
    ADD CONSTRAINT pallet_type_pallet_type_name_key UNIQUE (container_type_name);


--
-- TOC entry 5328 (class 2606 OID 16816)
-- Name: container_type pallet_type_pkey; Type: CONSTRAINT; Schema: ref; Owner: msbadmin
--

ALTER TABLE ONLY ref.container_type
    ADD CONSTRAINT pallet_type_pkey PRIMARY KEY (container_type_id);


--
-- TOC entry 5340 (class 2606 OID 16966)
-- Name: person person_pkey; Type: CONSTRAINT; Schema: ref; Owner: msbadmin
--

ALTER TABLE ONLY ref.person
    ADD CONSTRAINT person_pkey PRIMARY KEY (person_id);


--
-- TOC entry 5574 (class 2606 OID 23261)
-- Name: lor_scene_display pk_lor_scene_display; Type: CONSTRAINT; Schema: ref; Owner: msbadmin
--

ALTER TABLE ONLY ref.lor_scene_display
    ADD CONSTRAINT pk_lor_scene_display PRIMARY KEY (lor_scene_id, display_id);


--
-- TOC entry 5347 (class 2606 OID 16986)
-- Name: person_xref pk_person_xref; Type: CONSTRAINT; Schema: ref; Owner: msbadmin
--

ALTER TABLE ONLY ref.person_xref
    ADD CONSTRAINT pk_person_xref PRIMARY KEY (source_system, source_user_id);


--
-- TOC entry 5353 (class 2606 OID 18741)
-- Name: display ref_display_display_id_uk; Type: CONSTRAINT; Schema: ref; Owner: msbadmin
--

ALTER TABLE ONLY ref.display
    ADD CONSTRAINT ref_display_display_id_uk UNIQUE (display_id);


--
-- TOC entry 5516 (class 2606 OID 19493)
-- Name: season season_pkey; Type: CONSTRAINT; Schema: ref; Owner: msbadmin
--

ALTER TABLE ONLY ref.season
    ADD CONSTRAINT season_pkey PRIMARY KEY (season_year);


--
-- TOC entry 5478 (class 2606 OID 18566)
-- Name: spare_channel spare_channel_pkey; Type: CONSTRAINT; Schema: ref; Owner: msbadmin
--

ALTER TABLE ONLY ref.spare_channel
    ADD CONSTRAINT spare_channel_pkey PRIMARY KEY (lor_prop_id);


--
-- TOC entry 5459 (class 2606 OID 18111)
-- Name: stage_history stage_history_pkey; Type: CONSTRAINT; Schema: ref; Owner: msbadmin
--

ALTER TABLE ONLY ref.stage_history
    ADD CONSTRAINT stage_history_pkey PRIMARY KEY (import_run_id, stage_id);


--
-- TOC entry 5607 (class 2606 OID 23605)
-- Name: stage_lor_binding stage_lor_binding_pkey; Type: CONSTRAINT; Schema: ref; Owner: msbadmin
--

ALTER TABLE ONLY ref.stage_lor_binding
    ADD CONSTRAINT stage_lor_binding_pkey PRIMARY KEY (stage_lor_binding_id);


--
-- TOC entry 5455 (class 2606 OID 18102)
-- Name: stage stage_pkey; Type: CONSTRAINT; Schema: ref; Owner: msbadmin
--

ALTER TABLE ONLY ref.stage
    ADD CONSTRAINT stage_pkey PRIMARY KEY (stage_id);


--
-- TOC entry 5333 (class 2606 OID 18906)
-- Name: storage_location storage_location_pkey; Type: CONSTRAINT; Schema: ref; Owner: msbadmin
--

ALTER TABLE ONLY ref.storage_location
    ADD CONSTRAINT storage_location_pkey PRIMARY KEY (location_code);


--
-- TOC entry 5463 (class 2606 OID 18404)
-- Name: task_type task_type_pkey; Type: CONSTRAINT; Schema: ref; Owner: msbadmin
--

ALTER TABLE ONLY ref.task_type
    ADD CONSTRAINT task_type_pkey PRIMARY KEY (task_type_id);


--
-- TOC entry 5318 (class 2606 OID 16756)
-- Name: theme theme_pkey; Type: CONSTRAINT; Schema: ref; Owner: msbadmin
--

ALTER TABLE ONLY ref.theme
    ADD CONSTRAINT theme_pkey PRIMARY KEY (theme_id);


--
-- TOC entry 5320 (class 2606 OID 16758)
-- Name: theme theme_theme_name_key; Type: CONSTRAINT; Schema: ref; Owner: msbadmin
--

ALTER TABLE ONLY ref.theme
    ADD CONSTRAINT theme_theme_name_key UNIQUE (theme_name);


--
-- TOC entry 5514 (class 2606 OID 19224)
-- Name: audit_collection_policy uq_audit_collection_policy; Type: CONSTRAINT; Schema: ref; Owner: msbadmin
--

ALTER TABLE ONLY ref.audit_collection_policy
    ADD CONSTRAINT uq_audit_collection_policy UNIQUE (schema_name, collection_name);


--
-- TOC entry 5314 (class 2606 OID 16718)
-- Name: frame uq_frame_code; Type: CONSTRAINT; Schema: ref; Owner: msbadmin
--

ALTER TABLE ONLY ref.frame
    ADD CONSTRAINT uq_frame_code UNIQUE (frame_name);


--
-- TOC entry 5316 (class 2606 OID 16720)
-- Name: frame uq_frame_size; Type: CONSTRAINT; Schema: ref; Owner: msbadmin
--

ALTER TABLE ONLY ref.frame
    ADD CONSTRAINT uq_frame_size UNIQUE (w_ft, h_ft);


--
-- TOC entry 5335 (class 2606 OID 16854)
-- Name: storage_location uq_location_parts; Type: CONSTRAINT; Schema: ref; Owner: msbadmin
--

ALTER TABLE ONLY ref.storage_location
    ADD CONSTRAINT uq_location_parts UNIQUE (type_code, rack_row_code, column_num, shelf_level_code, slot_bin_num);


--
-- TOC entry 5576 (class 2606 OID 23263)
-- Name: lor_scene_display uq_lor_scene_display_preview_display; Type: CONSTRAINT; Schema: ref; Owner: msbadmin
--

ALTER TABLE ONLY ref.lor_scene_display
    ADD CONSTRAINT uq_lor_scene_display_preview_display UNIQUE (preview_uuid, display_id);


--
-- TOC entry 5568 (class 2606 OID 23240)
-- Name: lor_scene uq_lor_scene_id_preview; Type: CONSTRAINT; Schema: ref; Owner: msbadmin
--

ALTER TABLE ONLY ref.lor_scene
    ADD CONSTRAINT uq_lor_scene_id_preview UNIQUE (lor_scene_id, preview_uuid);


--
-- TOC entry 5570 (class 2606 OID 23238)
-- Name: lor_scene uq_lor_scene_preview_scene; Type: CONSTRAINT; Schema: ref; Owner: msbadmin
--

ALTER TABLE ONLY ref.lor_scene
    ADD CONSTRAINT uq_lor_scene_preview_scene UNIQUE (preview_uuid, scene_uuid);


--
-- TOC entry 5342 (class 2606 OID 19130)
-- Name: person uq_person_directus_user_id; Type: CONSTRAINT; Schema: ref; Owner: msbadmin
--

ALTER TABLE ONLY ref.person
    ADD CONSTRAINT uq_person_directus_user_id UNIQUE (directus_user_id);


--
-- TOC entry 5355 (class 2606 OID 18734)
-- Name: display uq_ref_display_display_id; Type: CONSTRAINT; Schema: ref; Owner: msbadmin
--

ALTER TABLE ONLY ref.display
    ADD CONSTRAINT uq_ref_display_display_id UNIQUE (display_id);


--
-- TOC entry 5457 (class 2606 OID 18163)
-- Name: stage uq_ref_stage_stage_key; Type: CONSTRAINT; Schema: ref; Owner: msbadmin
--

ALTER TABLE ONLY ref.stage
    ADD CONSTRAINT uq_ref_stage_stage_key UNIQUE (stage_key);


--
-- TOC entry 5518 (class 2606 OID 19631)
-- Name: urgency urgency_pkey; Type: CONSTRAINT; Schema: ref; Owner: msbadmin
--

ALTER TABLE ONLY ref.urgency
    ADD CONSTRAINT urgency_pkey PRIMARY KEY (urgency_id);


--
-- TOC entry 5520 (class 2606 OID 19633)
-- Name: urgency urgency_urgency_code_key; Type: CONSTRAINT; Schema: ref; Owner: msbadmin
--

ALTER TABLE ONLY ref.urgency
    ADD CONSTRAINT urgency_urgency_code_key UNIQUE (urgency_code);


--
-- TOC entry 5357 (class 2606 OID 18843)
-- Name: display ux_display_lor_prop_id; Type: CONSTRAINT; Schema: ref; Owner: msbadmin
--

ALTER TABLE ONLY ref.display
    ADD CONSTRAINT ux_display_lor_prop_id UNIQUE (lor_prop_id);


--
-- TOC entry 5467 (class 2606 OID 18434)
-- Name: work_area work_area_pkey; Type: CONSTRAINT; Schema: ref; Owner: msbadmin
--

ALTER TABLE ONLY ref.work_area
    ADD CONSTRAINT work_area_pkey PRIMARY KEY (work_area_id);


--
-- TOC entry 5491 (class 2606 OID 18973)
-- Name: work_order_status work_order_status_pkey; Type: CONSTRAINT; Schema: ref; Owner: msbadmin
--

ALTER TABLE ONLY ref.work_order_status
    ADD CONSTRAINT work_order_status_pkey PRIMARY KEY (work_order_status_id);


--
-- TOC entry 5482 (class 2606 OID 18697)
-- Name: work_order_completed_raw work_order_completed_raw_pkey; Type: CONSTRAINT; Schema: stage; Owner: msbadmin
--

ALTER TABLE ONLY stage.work_order_completed_raw
    ADD CONSTRAINT work_order_completed_raw_pkey PRIMARY KEY (src_row_num);


--
-- TOC entry 5499 (class 2606 OID 18987)
-- Name: work_order_intake work_order_intake_pkey; Type: CONSTRAINT; Schema: stage; Owner: directus_app
--

ALTER TABLE ONLY stage.work_order_intake
    ADD CONSTRAINT work_order_intake_pkey PRIMARY KEY (intake_id);


--
-- TOC entry 5480 (class 2606 OID 18662)
-- Name: work_order_todo_raw work_order_todo_raw_pkey; Type: CONSTRAINT; Schema: stage; Owner: msbadmin
--

ALTER TABLE ONLY stage.work_order_todo_raw
    ADD CONSTRAINT work_order_todo_raw_pkey PRIMARY KEY (src_row_num);


--
-- TOC entry 5299 (class 1259 OID 23350)
-- Name: idx_lor_snap_props_run_raw_prop_id; Type: INDEX; Schema: lor_snap; Owner: msbadmin
--

CREATE INDEX idx_lor_snap_props_run_raw_prop_id ON lor_snap.props USING btree (import_run_id, raw_prop_id);


--
-- TOC entry 5304 (class 1259 OID 23351)
-- Name: idx_lor_snap_sub_props_run_raw_prop_id; Type: INDEX; Schema: lor_snap; Owner: msbadmin
--

CREATE INDEX idx_lor_snap_sub_props_run_raw_prop_id ON lor_snap.sub_props USING btree (import_run_id, raw_prop_id);


--
-- TOC entry 5556 (class 1259 OID 23034)
-- Name: ix_lor_snap_scene_lor_props_run; Type: INDEX; Schema: lor_snap; Owner: msbadmin
--

CREATE INDEX ix_lor_snap_scene_lor_props_run ON lor_snap.scene_lor_props USING btree (import_run_id);


--
-- TOC entry 5557 (class 1259 OID 23037)
-- Name: ix_lor_snap_scene_lor_props_run_preview; Type: INDEX; Schema: lor_snap; Owner: msbadmin
--

CREATE INDEX ix_lor_snap_scene_lor_props_run_preview ON lor_snap.scene_lor_props USING btree (import_run_id, preview_id);


--
-- TOC entry 5558 (class 1259 OID 23036)
-- Name: ix_lor_snap_scene_lor_props_run_prop; Type: INDEX; Schema: lor_snap; Owner: msbadmin
--

CREATE INDEX ix_lor_snap_scene_lor_props_run_prop ON lor_snap.scene_lor_props USING btree (import_run_id, prop_id);


--
-- TOC entry 5559 (class 1259 OID 23035)
-- Name: ix_lor_snap_scene_lor_props_run_scene; Type: INDEX; Schema: lor_snap; Owner: msbadmin
--

CREATE INDEX ix_lor_snap_scene_lor_props_run_scene ON lor_snap.scene_lor_props USING btree (import_run_id, scene_id);


--
-- TOC entry 5553 (class 1259 OID 23031)
-- Name: ix_lor_snap_scenes_run; Type: INDEX; Schema: lor_snap; Owner: msbadmin
--

CREATE INDEX ix_lor_snap_scenes_run ON lor_snap.scenes USING btree (import_run_id);


--
-- TOC entry 5554 (class 1259 OID 23033)
-- Name: ix_lor_snap_scenes_run_preview; Type: INDEX; Schema: lor_snap; Owner: msbadmin
--

CREATE INDEX ix_lor_snap_scenes_run_preview ON lor_snap.scenes USING btree (import_run_id, preview_id);


--
-- TOC entry 5555 (class 1259 OID 23032)
-- Name: ix_lor_snap_scenes_run_scene; Type: INDEX; Schema: lor_snap; Owner: msbadmin
--

CREATE INDEX ix_lor_snap_scenes_run_scene ON lor_snap.scenes USING btree (import_run_id, scene_id);


--
-- TOC entry 5547 (class 1259 OID 20743)
-- Name: idx_container_batch_item_batch; Type: INDEX; Schema: ops; Owner: msbadmin
--

CREATE INDEX idx_container_batch_item_batch ON ops.container_label_batch_item USING btree (container_label_batch_id);


--
-- TOC entry 5548 (class 1259 OID 20781)
-- Name: idx_container_label_batch_item_batch; Type: INDEX; Schema: ops; Owner: msbadmin
--

CREATE INDEX idx_container_label_batch_item_batch ON ops.container_label_batch_item USING btree (container_label_batch_id);


--
-- TOC entry 5542 (class 1259 OID 20720)
-- Name: idx_container_label_batch_status; Type: INDEX; Schema: ops; Owner: msbadmin
--

CREATE INDEX idx_container_label_batch_status ON ops.container_label_batch USING btree (status);


--
-- TOC entry 5527 (class 1259 OID 20629)
-- Name: idx_container_label_print_container_id; Type: INDEX; Schema: ops; Owner: directus_app
--

CREATE INDEX idx_container_label_print_container_id ON ops.container_label_print USING btree (container_id);


--
-- TOC entry 5528 (class 1259 OID 20630)
-- Name: idx_container_label_print_printed_at; Type: INDEX; Schema: ops; Owner: directus_app
--

CREATE INDEX idx_container_label_print_printed_at ON ops.container_label_print USING btree (printed_at DESC);


--
-- TOC entry 5536 (class 1259 OID 20708)
-- Name: idx_display_batch_item_batch; Type: INDEX; Schema: ops; Owner: msbadmin
--

CREATE INDEX idx_display_batch_item_batch ON ops.display_label_batch_item USING btree (display_label_batch_id);


--
-- TOC entry 5537 (class 1259 OID 20762)
-- Name: idx_display_label_batch_item_batch; Type: INDEX; Schema: ops; Owner: msbadmin
--

CREATE INDEX idx_display_label_batch_item_batch ON ops.display_label_batch_item USING btree (display_label_batch_id);


--
-- TOC entry 5531 (class 1259 OID 20685)
-- Name: idx_display_label_batch_status; Type: INDEX; Schema: ops; Owner: msbadmin
--

CREATE INDEX idx_display_label_batch_status ON ops.display_label_batch USING btree (status);


--
-- TOC entry 5523 (class 1259 OID 20793)
-- Name: idx_display_label_print_display_id; Type: INDEX; Schema: ops; Owner: directus_app
--

CREATE INDEX idx_display_label_print_display_id ON ops.display_label_print USING btree (display_id);


--
-- TOC entry 5524 (class 1259 OID 20609)
-- Name: idx_display_label_print_printed_at; Type: INDEX; Schema: ops; Owner: directus_app
--

CREATE INDEX idx_display_label_print_printed_at ON ops.display_label_print USING btree (printed_at DESC);


--
-- TOC entry 5594 (class 1259 OID 23509)
-- Name: ix_lor_reconciliation_action_group_latest; Type: INDEX; Schema: ops; Owner: msbadmin
--

CREATE INDEX ix_lor_reconciliation_action_group_latest ON ops.lor_reconciliation_action USING btree (lor_reconciliation_group_id, acted_at DESC, lor_reconciliation_action_id DESC);


--
-- TOC entry 5588 (class 1259 OID 23483)
-- Name: ix_lor_reconciliation_display_candidate_group; Type: INDEX; Schema: ops; Owner: msbadmin
--

CREATE INDEX ix_lor_reconciliation_display_candidate_group ON ops.lor_reconciliation_display_candidate USING btree (lor_reconciliation_group_id);


--
-- TOC entry 5589 (class 1259 OID 23484)
-- Name: ix_lor_reconciliation_display_candidate_review; Type: INDEX; Schema: ops; Owner: msbadmin
--

CREATE INDEX ix_lor_reconciliation_display_candidate_review ON ops.lor_reconciliation_display_candidate USING btree (lor_reconciliation_run_id, decision_required, is_blocking);


--
-- TOC entry 5583 (class 1259 OID 23451)
-- Name: ix_lor_reconciliation_group_review; Type: INDEX; Schema: ops; Owner: msbadmin
--

CREATE INDEX ix_lor_reconciliation_group_review ON ops.lor_reconciliation_group USING btree (lor_reconciliation_run_id, decision_required, entity_type);


--
-- TOC entry 5577 (class 1259 OID 23427)
-- Name: ix_lor_reconciliation_run_status; Type: INDEX; Schema: ops; Owner: msbadmin
--

CREATE INDEX ix_lor_reconciliation_run_status ON ops.lor_reconciliation_run USING btree (status, started_at DESC);


--
-- TOC entry 5615 (class 1259 OID 23746)
-- Name: ix_lor_reconciliation_scene_candidate_group; Type: INDEX; Schema: ops; Owner: msbadmin
--

CREATE INDEX ix_lor_reconciliation_scene_candidate_group ON ops.lor_reconciliation_scene_candidate USING btree (lor_reconciliation_group_id);


--
-- TOC entry 5616 (class 1259 OID 23747)
-- Name: ix_lor_reconciliation_scene_candidate_identity; Type: INDEX; Schema: ops; Owner: msbadmin
--

CREATE INDEX ix_lor_reconciliation_scene_candidate_identity ON ops.lor_reconciliation_scene_candidate USING btree (lor_reconciliation_run_id, preview_id, scene_id);


--
-- TOC entry 5621 (class 1259 OID 23789)
-- Name: ix_lor_reconciliation_scene_display_candidate_group; Type: INDEX; Schema: ops; Owner: msbadmin
--

CREATE INDEX ix_lor_reconciliation_scene_display_candidate_group ON ops.lor_reconciliation_scene_display_candidate USING btree (lor_reconciliation_group_id);


--
-- TOC entry 5622 (class 1259 OID 23790)
-- Name: ix_lor_reconciliation_scene_display_identity; Type: INDEX; Schema: ops; Owner: msbadmin
--

CREATE INDEX ix_lor_reconciliation_scene_display_identity ON ops.lor_reconciliation_scene_display_candidate USING btree (lor_reconciliation_run_id, preview_id, scene_id);


--
-- TOC entry 5635 (class 1259 OID 23922)
-- Name: ix_lor_reconciliation_source_scene_run; Type: INDEX; Schema: ops; Owner: msbadmin
--

CREATE INDEX ix_lor_reconciliation_source_scene_run ON ops.lor_reconciliation_source_scene USING btree (lor_reconciliation_run_id);


--
-- TOC entry 5610 (class 1259 OID 23654)
-- Name: ix_lor_reconciliation_stage_candidate_group; Type: INDEX; Schema: ops; Owner: msbadmin
--

CREATE INDEX ix_lor_reconciliation_stage_candidate_group ON ops.lor_reconciliation_stage_candidate USING btree (lor_reconciliation_group_id);


--
-- TOC entry 5361 (class 1259 OID 18956)
-- Name: ix_test_session_container_test_status; Type: INDEX; Schema: ops; Owner: msbadmin
--

CREATE INDEX ix_test_session_container_test_status ON ops.test_session USING btree (container_test_status_id);


--
-- TOC entry 5362 (class 1259 OID 17286)
-- Name: ix_test_session_pallet; Type: INDEX; Schema: ops; Owner: msbadmin
--

CREATE INDEX ix_test_session_pallet ON ops.test_session USING btree (container_id);


--
-- TOC entry 5363 (class 1259 OID 18082)
-- Name: ix_test_session_season_status; Type: INDEX; Schema: ops; Owner: msbadmin
--

CREATE INDEX ix_test_session_season_status ON ops.test_session USING btree (season_year, container_status_legacy);


--
-- TOC entry 5364 (class 1259 OID 17285)
-- Name: ix_test_session_status; Type: INDEX; Schema: ops; Owner: msbadmin
--

CREATE INDEX ix_test_session_status ON ops.test_session USING btree (season_year, container_status_legacy);


--
-- TOC entry 5500 (class 1259 OID 19866)
-- Name: ix_woa_person; Type: INDEX; Schema: ops; Owner: directus_app
--

CREATE INDEX ix_woa_person ON ops.work_order_assignment USING btree (person_id);


--
-- TOC entry 5501 (class 1259 OID 19041)
-- Name: ix_woa_work_order; Type: INDEX; Schema: ops; Owner: directus_app
--

CREATE INDEX ix_woa_work_order ON ops.work_order_assignment USING btree (work_order_id);


--
-- TOC entry 5508 (class 1259 OID 19095)
-- Name: ix_woom_work_order; Type: INDEX; Schema: ops; Owner: msbadmin
--

CREATE INDEX ix_woom_work_order ON ops.work_order_outbound_message USING btree (work_order_id, created_at DESC);


--
-- TOC entry 5468 (class 1259 OID 18528)
-- Name: ix_work_order_open; Type: INDEX; Schema: ops; Owner: directus_app
--

CREATE INDEX ix_work_order_open ON ops.work_order USING btree (date_completed) WHERE (date_completed IS NULL);


--
-- TOC entry 5469 (class 1259 OID 19799)
-- Name: ix_work_order_stage_open; Type: INDEX; Schema: ops; Owner: directus_app
--

CREATE INDEX ix_work_order_stage_open ON ops.work_order USING btree (stage_id) WHERE (date_completed IS NULL);


--
-- TOC entry 5470 (class 1259 OID 18531)
-- Name: ix_work_order_target_year; Type: INDEX; Schema: ops; Owner: directus_app
--

CREATE INDEX ix_work_order_target_year ON ops.work_order USING btree (target_year);


--
-- TOC entry 5471 (class 1259 OID 19772)
-- Name: ix_work_order_urgency_open; Type: INDEX; Schema: ops; Owner: directus_app
--

CREATE INDEX ix_work_order_urgency_open ON ops.work_order USING btree (urgency_id) WHERE (date_completed IS NULL);


--
-- TOC entry 5472 (class 1259 OID 18530)
-- Name: ix_work_order_work_area_open; Type: INDEX; Schema: ops; Owner: directus_app
--

CREATE INDEX ix_work_order_work_area_open ON ops.work_order USING btree (work_area_id) WHERE (date_completed IS NULL);


--
-- TOC entry 5505 (class 1259 OID 19067)
-- Name: ix_wosh_work_order; Type: INDEX; Schema: ops; Owner: msbadmin
--

CREATE INDEX ix_wosh_work_order ON ops.work_order_status_history USING btree (work_order_id, changed_at DESC);


--
-- TOC entry 5374 (class 1259 OID 18350)
-- Name: ux_display_test_session_session_prop; Type: INDEX; Schema: ops; Owner: msbadmin
--

CREATE UNIQUE INDEX ux_display_test_session_session_prop ON ops.display_test_session USING btree (test_session_id, lor_prop_id);


--
-- TOC entry 5562 (class 1259 OID 23215)
-- Name: ux_lor_reconciliation_action_legacy_run_decision; Type: INDEX; Schema: ops; Owner: msbadmin
--

CREATE UNIQUE INDEX ux_lor_reconciliation_action_legacy_run_decision ON ops.lor_reconciliation_action_legacy USING btree (import_run_id, action_type, display_id);


--
-- TOC entry 5580 (class 1259 OID 24238)
-- Name: ux_lor_reconciliation_one_unfinished_run; Type: INDEX; Schema: ops; Owner: msbadmin
--

CREATE UNIQUE INDEX ux_lor_reconciliation_one_unfinished_run ON ops.lor_reconciliation_run USING btree ((1)) WHERE (status = ANY (ARRAY['STARTING'::text, 'PREFLIGHT'::text, 'AWAITING_DECISIONS'::text, 'READY_TO_FINISH'::text, 'PROMOTING'::text, 'VALIDATING'::text, 'REPORTING'::text]));


--
-- TOC entry 6456 (class 0 OID 0)
-- Dependencies: 5580
-- Name: INDEX ux_lor_reconciliation_one_unfinished_run; Type: COMMENT; Schema: ops; Owner: msbadmin
--

COMMENT ON INDEX ops.ux_lor_reconciliation_one_unfinished_run IS 'Only one unfinished reconciliation run may exist; every unfinished lifecycle state must continue that run before another snapshot can start.';


--
-- TOC entry 5369 (class 1259 OID 18349)
-- Name: ux_test_session_season_container; Type: INDEX; Schema: ops; Owner: msbadmin
--

CREATE UNIQUE INDEX ux_test_session_season_container ON ops.test_session USING btree (season_year, container_id);


--
-- TOC entry 5502 (class 1259 OID 19865)
-- Name: ux_woa_active; Type: INDEX; Schema: ops; Owner: directus_app
--

CREATE UNIQUE INDEX ux_woa_active ON ops.work_order_assignment USING btree (work_order_id, person_id) WHERE (active_flag = true);


--
-- TOC entry 5473 (class 1259 OID 18772)
-- Name: ux_work_order_open_per_checklist_line; Type: INDEX; Schema: ops; Owner: directus_app
--

CREATE UNIQUE INDEX ux_work_order_open_per_checklist_line ON ops.work_order USING btree (display_test_session_id) WHERE ((display_test_session_id IS NOT NULL) AND (date_completed IS NULL));


--
-- TOC entry 5391 (class 1259 OID 17994)
-- Name: directus_activity_timestamp_index; Type: INDEX; Schema: public; Owner: directus_app
--

CREATE INDEX directus_activity_timestamp_index ON public.directus_activity USING btree ("timestamp");


--
-- TOC entry 5402 (class 1259 OID 17996)
-- Name: directus_revisions_activity_index; Type: INDEX; Schema: public; Owner: directus_app
--

CREATE INDEX directus_revisions_activity_index ON public.directus_revisions USING btree (activity);


--
-- TOC entry 5403 (class 1259 OID 17995)
-- Name: directus_revisions_parent_index; Type: INDEX; Schema: public; Owner: directus_app
--

CREATE INDEX directus_revisions_parent_index ON public.directus_revisions USING btree (parent);


--
-- TOC entry 5338 (class 1259 OID 17192)
-- Name: idx_person_personal_email; Type: INDEX; Schema: ref; Owner: msbadmin
--

CREATE INDEX idx_person_personal_email ON ref.person USING btree (personal_email);


--
-- TOC entry 5571 (class 1259 OID 23281)
-- Name: ix_lor_scene_display_display; Type: INDEX; Schema: ref; Owner: msbadmin
--

CREATE INDEX ix_lor_scene_display_display ON ref.lor_scene_display USING btree (display_id);


--
-- TOC entry 5572 (class 1259 OID 23282)
-- Name: ix_lor_scene_display_source_run; Type: INDEX; Schema: ref; Owner: msbadmin
--

CREATE INDEX ix_lor_scene_display_source_run ON ref.lor_scene_display USING btree (source_import_run_id);


--
-- TOC entry 5563 (class 1259 OID 23280)
-- Name: ix_lor_scene_source_run; Type: INDEX; Schema: ref; Owner: msbadmin
--

CREATE INDEX ix_lor_scene_source_run ON ref.lor_scene USING btree (source_import_run_id);


--
-- TOC entry 5564 (class 1259 OID 23279)
-- Name: ix_lor_scene_stage; Type: INDEX; Schema: ref; Owner: msbadmin
--

CREATE INDEX ix_lor_scene_stage ON ref.lor_scene USING btree (stage_id);


--
-- TOC entry 5344 (class 1259 OID 16988)
-- Name: ix_person_xref_email; Type: INDEX; Schema: ref; Owner: msbadmin
--

CREATE INDEX ix_person_xref_email ON ref.person_xref USING btree (lower(email));


--
-- TOC entry 5345 (class 1259 OID 16987)
-- Name: ix_person_xref_person_id; Type: INDEX; Schema: ref; Owner: msbadmin
--

CREATE INDEX ix_person_xref_person_id ON ref.person_xref USING btree (person_id);


--
-- TOC entry 5452 (class 1259 OID 18161)
-- Name: ix_ref_stage_parent; Type: INDEX; Schema: ref; Owner: msbadmin
--

CREATE INDEX ix_ref_stage_parent ON ref.stage USING btree (parent_stage_key);


--
-- TOC entry 5605 (class 1259 OID 23613)
-- Name: ix_stage_lor_binding_stage; Type: INDEX; Schema: ref; Owner: msbadmin
--

CREATE INDEX ix_stage_lor_binding_stage ON ref.stage_lor_binding USING btree (stage_id);


--
-- TOC entry 5453 (class 1259 OID 18131)
-- Name: ix_stage_order; Type: INDEX; Schema: ref; Owner: msbadmin
--

CREATE INDEX ix_stage_order ON ref.stage USING btree (park_order, sub_order);


--
-- TOC entry 5476 (class 1259 OID 18567)
-- Name: spare_channel_lor_prop_id_idx; Type: INDEX; Schema: ref; Owner: msbadmin
--

CREATE UNIQUE INDEX spare_channel_lor_prop_id_idx ON ref.spare_channel USING btree (lor_prop_id);


--
-- TOC entry 5331 (class 1259 OID 18749)
-- Name: ux_container_location_code_non_zone; Type: INDEX; Schema: ref; Owner: msbadmin
--

CREATE UNIQUE INDEX ux_container_location_code_non_zone ON ref.container USING btree (location_code) WHERE ((location_code IS NOT NULL) AND (location_code !~~ 'Z-%'::text));


--
-- TOC entry 5336 (class 1259 OID 18332)
-- Name: ux_location_rack_slot; Type: INDEX; Schema: ref; Owner: msbadmin
--

CREATE UNIQUE INDEX ux_location_rack_slot ON ref.storage_location USING btree (rack_row_code, column_num, shelf_level_code, slot_bin_num) WHERE (type_code = 'R'::text);


--
-- TOC entry 5343 (class 1259 OID 16967)
-- Name: ux_person_email; Type: INDEX; Schema: ref; Owner: msbadmin
--

CREATE UNIQUE INDEX ux_person_email ON ref.person USING btree (lower(email)) WHERE ((email IS NOT NULL) AND (btrim(email) <> ''::text));


--
-- TOC entry 5358 (class 1259 OID 18583)
-- Name: ux_ref_display_display_name; Type: INDEX; Schema: ref; Owner: msbadmin
--

CREATE UNIQUE INDEX ux_ref_display_display_name ON ref.display USING btree (upper(btrim(display_name))) WHERE ((display_name IS NOT NULL) AND (btrim(display_name) <> ''::text));


--
-- TOC entry 5359 (class 1259 OID 17255)
-- Name: ux_ref_display_lor_prop_id; Type: INDEX; Schema: ref; Owner: msbadmin
--

CREATE UNIQUE INDEX ux_ref_display_lor_prop_id ON ref.display USING btree (lor_prop_id);


--
-- TOC entry 5360 (class 1259 OID 18731)
-- Name: ux_ref_display_name; Type: INDEX; Schema: ref; Owner: msbadmin
--

CREATE UNIQUE INDEX ux_ref_display_name ON ref.display USING btree (display_name);


--
-- TOC entry 5608 (class 1259 OID 23611)
-- Name: ux_stage_lor_binding_preview; Type: INDEX; Schema: ref; Owner: msbadmin
--

CREATE UNIQUE INDEX ux_stage_lor_binding_preview ON ref.stage_lor_binding USING btree (preview_id) WHERE (binding_type = 'PREVIEW'::text);


--
-- TOC entry 5609 (class 1259 OID 23612)
-- Name: ux_stage_lor_binding_scene; Type: INDEX; Schema: ref; Owner: msbadmin
--

CREATE UNIQUE INDEX ux_stage_lor_binding_scene ON ref.stage_lor_binding USING btree (preview_id, scene_id) WHERE (binding_type = 'SCENE'::text);


--
-- TOC entry 5337 (class 1259 OID 18315)
-- Name: ux_storage_location_code; Type: INDEX; Schema: ref; Owner: msbadmin
--

CREATE UNIQUE INDEX ux_storage_location_code ON ref.storage_location USING btree (location_code);


--
-- TOC entry 5464 (class 1259 OID 18405)
-- Name: ux_task_type_key; Type: INDEX; Schema: ref; Owner: msbadmin
--

CREATE UNIQUE INDEX ux_task_type_key ON ref.task_type USING btree (upper(btrim(task_type_key)));


--
-- TOC entry 5465 (class 1259 OID 18435)
-- Name: ux_work_area_key; Type: INDEX; Schema: ref; Owner: msbadmin
--

CREATE UNIQUE INDEX ux_work_area_key ON ref.work_area USING btree (upper(btrim(work_area_key)));


--
-- TOC entry 5489 (class 1259 OID 18974)
-- Name: ux_work_order_status_key; Type: INDEX; Schema: ref; Owner: msbadmin
--

CREATE UNIQUE INDEX ux_work_order_status_key ON ref.work_order_status USING btree (upper(btrim(status_key)));


--
-- TOC entry 5492 (class 1259 OID 19003)
-- Name: ix_intake_submitted_at; Type: INDEX; Schema: stage; Owner: directus_app
--

CREATE INDEX ix_intake_submitted_at ON stage.work_order_intake USING btree (submitted_at DESC);


--
-- TOC entry 5493 (class 1259 OID 19654)
-- Name: ix_work_order_intake_stage_id; Type: INDEX; Schema: stage; Owner: directus_app
--

CREATE INDEX ix_work_order_intake_stage_id ON stage.work_order_intake USING btree (stage_id);


--
-- TOC entry 5494 (class 1259 OID 19876)
-- Name: ix_work_order_intake_submitter_person; Type: INDEX; Schema: stage; Owner: directus_app
--

CREATE INDEX ix_work_order_intake_submitter_person ON stage.work_order_intake USING btree (submitter_person_id);


--
-- TOC entry 5495 (class 1259 OID 19656)
-- Name: ix_work_order_intake_task_type_id; Type: INDEX; Schema: stage; Owner: directus_app
--

CREATE INDEX ix_work_order_intake_task_type_id ON stage.work_order_intake USING btree (task_type_id);


--
-- TOC entry 5496 (class 1259 OID 19657)
-- Name: ix_work_order_intake_urgency_id; Type: INDEX; Schema: stage; Owner: directus_app
--

CREATE INDEX ix_work_order_intake_urgency_id ON stage.work_order_intake USING btree (urgency_id);


--
-- TOC entry 5497 (class 1259 OID 19655)
-- Name: ix_work_order_intake_work_area_id; Type: INDEX; Schema: stage; Owner: directus_app
--

CREATE INDEX ix_work_order_intake_work_area_id ON stage.work_order_intake USING btree (work_area_id);


--
-- TOC entry 5862 (class 2620 OID 19556)
-- Name: test_session trg_after_refresh_test_session; Type: TRIGGER; Schema: ops; Owner: msbadmin
--

CREATE TRIGGER trg_after_refresh_test_session AFTER UPDATE ON ops.test_session FOR EACH ROW EXECUTE FUNCTION ops.tf_after_refresh_test_session();


--
-- TOC entry 5863 (class 2620 OID 19303)
-- Name: test_session trg_after_start_container_pull; Type: TRIGGER; Schema: ops; Owner: msbadmin
--

CREATE TRIGGER trg_after_start_container_pull AFTER UPDATE ON ops.test_session FOR EACH ROW EXECUTE FUNCTION ops.tf_after_start_container_pull();


--
-- TOC entry 5903 (class 2620 OID 24142)
-- Name: lor_reconciliation_display_candidate trg_auto_approve_safe_uuid_relink; Type: TRIGGER; Schema: ops; Owner: msbadmin
--

CREATE TRIGGER trg_auto_approve_safe_uuid_relink AFTER INSERT ON ops.lor_reconciliation_display_candidate FOR EACH ROW EXECUTE FUNCTION ops.trg_auto_approve_safe_uuid_relink();


--
-- TOC entry 5868 (class 2620 OID 19144)
-- Name: display_test_session trg_display_test_session_set_actor_insert; Type: TRIGGER; Schema: ops; Owner: msbadmin
--

CREATE TRIGGER trg_display_test_session_set_actor_insert BEFORE INSERT ON ops.display_test_session FOR EACH ROW EXECUTE FUNCTION ref.set_actor_on_insert();


--
-- TOC entry 5869 (class 2620 OID 19191)
-- Name: display_test_session trg_display_test_session_set_actor_update; Type: TRIGGER; Schema: ops; Owner: msbadmin
--

CREATE TRIGGER trg_display_test_session_set_actor_update BEFORE UPDATE ON ops.display_test_session FOR EACH ROW EXECUTE FUNCTION ref.set_actor_on_update();


--
-- TOC entry 5870 (class 2620 OID 19176)
-- Name: display_test_session trg_display_test_session_set_checked_actor; Type: TRIGGER; Schema: ops; Owner: msbadmin
--

CREATE TRIGGER trg_display_test_session_set_checked_actor BEFORE UPDATE ON ops.display_test_session FOR EACH ROW EXECUTE FUNCTION ops.set_checked_actor();


--
-- TOC entry 5906 (class 2620 OID 23537)
-- Name: lor_reconciliation_action_assignment trg_lor_reconciliation_action_assignment_immutable; Type: TRIGGER; Schema: ops; Owner: msbadmin
--

CREATE TRIGGER trg_lor_reconciliation_action_assignment_immutable BEFORE DELETE OR UPDATE ON ops.lor_reconciliation_action_assignment FOR EACH ROW EXECUTE FUNCTION ops.trg_lor_reconciliation_detail_immutable();


--
-- TOC entry 5905 (class 2620 OID 23511)
-- Name: lor_reconciliation_action trg_lor_reconciliation_action_immutable; Type: TRIGGER; Schema: ops; Owner: msbadmin
--

CREATE TRIGGER trg_lor_reconciliation_action_immutable BEFORE DELETE OR UPDATE ON ops.lor_reconciliation_action FOR EACH ROW EXECUTE FUNCTION ops.trg_lor_reconciliation_detail_immutable();


--
-- TOC entry 5904 (class 2620 OID 23555)
-- Name: lor_reconciliation_display_candidate trg_lor_reconciliation_display_candidate_immutable; Type: TRIGGER; Schema: ops; Owner: msbadmin
--

CREATE TRIGGER trg_lor_reconciliation_display_candidate_immutable BEFORE DELETE OR UPDATE ON ops.lor_reconciliation_display_candidate FOR EACH ROW EXECUTE FUNCTION ops.trg_lor_reconciliation_detail_immutable();


--
-- TOC entry 5902 (class 2620 OID 23554)
-- Name: lor_reconciliation_group trg_lor_reconciliation_group_immutable; Type: TRIGGER; Schema: ops; Owner: msbadmin
--

CREATE TRIGGER trg_lor_reconciliation_group_immutable BEFORE DELETE OR UPDATE ON ops.lor_reconciliation_group FOR EACH ROW EXECUTE FUNCTION ops.trg_lor_reconciliation_detail_immutable();


--
-- TOC entry 5907 (class 2620 OID 23556)
-- Name: lor_reconciliation_result trg_lor_reconciliation_result_immutable; Type: TRIGGER; Schema: ops; Owner: msbadmin
--

CREATE TRIGGER trg_lor_reconciliation_result_immutable BEFORE DELETE OR UPDATE ON ops.lor_reconciliation_result FOR EACH ROW EXECUTE FUNCTION ops.trg_lor_reconciliation_detail_immutable();


--
-- TOC entry 5910 (class 2620 OID 23748)
-- Name: lor_reconciliation_scene_candidate trg_lor_reconciliation_scene_candidate_immutable; Type: TRIGGER; Schema: ops; Owner: msbadmin
--

CREATE TRIGGER trg_lor_reconciliation_scene_candidate_immutable BEFORE DELETE OR UPDATE ON ops.lor_reconciliation_scene_candidate FOR EACH ROW EXECUTE FUNCTION ops.trg_lor_reconciliation_detail_immutable();


--
-- TOC entry 5911 (class 2620 OID 23791)
-- Name: lor_reconciliation_scene_display_candidate trg_lor_reconciliation_scene_display_candidate_immutable; Type: TRIGGER; Schema: ops; Owner: msbadmin
--

CREATE TRIGGER trg_lor_reconciliation_scene_display_candidate_immutable BEFORE DELETE OR UPDATE ON ops.lor_reconciliation_scene_display_candidate FOR EACH ROW EXECUTE FUNCTION ops.trg_lor_reconciliation_detail_immutable();


--
-- TOC entry 5913 (class 2620 OID 23925)
-- Name: lor_reconciliation_source_preview trg_lor_reconciliation_source_preview_immutable; Type: TRIGGER; Schema: ops; Owner: msbadmin
--

CREATE TRIGGER trg_lor_reconciliation_source_preview_immutable BEFORE DELETE OR UPDATE ON ops.lor_reconciliation_source_preview FOR EACH ROW EXECUTE FUNCTION ops.trg_lor_reconciliation_detail_immutable();


--
-- TOC entry 5912 (class 2620 OID 23924)
-- Name: lor_reconciliation_source_run trg_lor_reconciliation_source_run_immutable; Type: TRIGGER; Schema: ops; Owner: msbadmin
--

CREATE TRIGGER trg_lor_reconciliation_source_run_immutable BEFORE DELETE OR UPDATE ON ops.lor_reconciliation_source_run FOR EACH ROW EXECUTE FUNCTION ops.trg_lor_reconciliation_detail_immutable();


--
-- TOC entry 5914 (class 2620 OID 23926)
-- Name: lor_reconciliation_source_scene trg_lor_reconciliation_source_scene_immutable; Type: TRIGGER; Schema: ops; Owner: msbadmin
--

CREATE TRIGGER trg_lor_reconciliation_source_scene_immutable BEFORE DELETE OR UPDATE ON ops.lor_reconciliation_source_scene FOR EACH ROW EXECUTE FUNCTION ops.trg_lor_reconciliation_detail_immutable();


--
-- TOC entry 5909 (class 2620 OID 23655)
-- Name: lor_reconciliation_stage_candidate trg_lor_reconciliation_stage_candidate_immutable; Type: TRIGGER; Schema: ops; Owner: msbadmin
--

CREATE TRIGGER trg_lor_reconciliation_stage_candidate_immutable BEFORE DELETE OR UPDATE ON ops.lor_reconciliation_stage_candidate FOR EACH ROW EXECUTE FUNCTION ops.trg_lor_reconciliation_detail_immutable();


--
-- TOC entry 5900 (class 2620 OID 23943)
-- Name: lor_reconciliation_run trg_require_terminal_reconciliation_decisions; Type: TRIGGER; Schema: ops; Owner: msbadmin
--

CREATE TRIGGER trg_require_terminal_reconciliation_decisions BEFORE UPDATE OF status ON ops.lor_reconciliation_run FOR EACH ROW EXECUTE FUNCTION ops.trg_require_terminal_reconciliation_decisions();


--
-- TOC entry 5864 (class 2620 OID 19298)
-- Name: test_session trg_set_container_search_helper; Type: TRIGGER; Schema: ops; Owner: msbadmin
--

CREATE TRIGGER trg_set_container_search_helper BEFORE INSERT OR UPDATE OF container_id ON ops.test_session FOR EACH ROW EXECUTE FUNCTION ops.set_container_search_helper();


--
-- TOC entry 5865 (class 2620 OID 19302)
-- Name: test_session trg_start_container_pull; Type: TRIGGER; Schema: ops; Owner: msbadmin
--

CREATE TRIGGER trg_start_container_pull BEFORE UPDATE ON ops.test_session FOR EACH ROW EXECUTE FUNCTION ops.tf_start_container_pull();


--
-- TOC entry 5901 (class 2620 OID 24054)
-- Name: lor_reconciliation_run trg_sync_lor_reconciliation_counters_on_reporting; Type: TRIGGER; Schema: ops; Owner: msbadmin
--

CREATE TRIGGER trg_sync_lor_reconciliation_counters_on_reporting AFTER UPDATE OF status ON ops.lor_reconciliation_run FOR EACH ROW WHEN (((new.status = 'REPORTING'::text) AND (old.status IS DISTINCT FROM new.status))) EXECUTE FUNCTION ops.f_sync_lor_reconciliation_counters_on_reporting();


--
-- TOC entry 5866 (class 2620 OID 19145)
-- Name: test_session trg_test_session_set_actor_insert; Type: TRIGGER; Schema: ops; Owner: msbadmin
--

CREATE TRIGGER trg_test_session_set_actor_insert BEFORE INSERT ON ops.test_session FOR EACH ROW EXECUTE FUNCTION ref.set_actor_on_insert();


--
-- TOC entry 5867 (class 2620 OID 19192)
-- Name: test_session trg_test_session_set_actor_update; Type: TRIGGER; Schema: ops; Owner: msbadmin
--

CREATE TRIGGER trg_test_session_set_actor_update BEFORE UPDATE ON ops.test_session FOR EACH ROW EXECUTE FUNCTION ref.set_actor_on_update();


--
-- TOC entry 5871 (class 2620 OID 19561)
-- Name: display_test_session trg_validate_display_test_session_notes; Type: TRIGGER; Schema: ops; Owner: msbadmin
--

CREATE TRIGGER trg_validate_display_test_session_notes BEFORE INSERT OR UPDATE OF test_status, notes ON ops.display_test_session FOR EACH ROW EXECUTE FUNCTION ops.tf_validate_display_test_session_notes();


--
-- TOC entry 5890 (class 2620 OID 19825)
-- Name: work_order_assignment trg_work_order_assignment_set_actor_insert; Type: TRIGGER; Schema: ops; Owner: directus_app
--

CREATE TRIGGER trg_work_order_assignment_set_actor_insert BEFORE INSERT ON ops.work_order_assignment FOR EACH ROW EXECUTE FUNCTION ref.set_actor_on_insert();


--
-- TOC entry 5891 (class 2620 OID 19826)
-- Name: work_order_assignment trg_work_order_assignment_set_actor_update; Type: TRIGGER; Schema: ops; Owner: directus_app
--

CREATE TRIGGER trg_work_order_assignment_set_actor_update BEFORE UPDATE ON ops.work_order_assignment FOR EACH ROW EXECUTE FUNCTION ref.set_actor_on_update();


--
-- TOC entry 5879 (class 2620 OID 19575)
-- Name: work_order trg_work_order_autofill_completion_on_repair_complete; Type: TRIGGER; Schema: ops; Owner: directus_app
--

CREATE TRIGGER trg_work_order_autofill_completion_on_repair_complete BEFORE UPDATE ON ops.work_order FOR EACH ROW EXECUTE FUNCTION ops.tf_work_order_autofill_completion_on_repair_complete();


--
-- TOC entry 5893 (class 2620 OID 19119)
-- Name: work_order_outbound_message trg_work_order_outbound_message_set_updated; Type: TRIGGER; Schema: ops; Owner: msbadmin
--

CREATE TRIGGER trg_work_order_outbound_message_set_updated BEFORE UPDATE ON ops.work_order_outbound_message FOR EACH ROW EXECUTE FUNCTION ref.set_updated_fields();


--
-- TOC entry 5880 (class 2620 OID 19823)
-- Name: work_order trg_work_order_set_actor_insert; Type: TRIGGER; Schema: ops; Owner: directus_app
--

CREATE TRIGGER trg_work_order_set_actor_insert BEFORE INSERT ON ops.work_order FOR EACH ROW EXECUTE FUNCTION ref.set_actor_on_insert();


--
-- TOC entry 5881 (class 2620 OID 19824)
-- Name: work_order trg_work_order_set_actor_update; Type: TRIGGER; Schema: ops; Owner: directus_app
--

CREATE TRIGGER trg_work_order_set_actor_update BEFORE UPDATE ON ops.work_order FOR EACH ROW EXECUTE FUNCTION ref.set_actor_on_update();


--
-- TOC entry 5892 (class 2620 OID 19124)
-- Name: work_order_status_history trg_work_order_status_history_set_updated; Type: TRIGGER; Schema: ops; Owner: msbadmin
--

CREATE TRIGGER trg_work_order_status_history_set_updated BEFORE UPDATE ON ops.work_order_status_history FOR EACH ROW EXECUTE FUNCTION ref.set_updated_fields();


--
-- TOC entry 5894 (class 2620 OID 19226)
-- Name: audit_collection_policy trg_audit_collection_policy_set_actor_insert; Type: TRIGGER; Schema: ref; Owner: msbadmin
--

CREATE TRIGGER trg_audit_collection_policy_set_actor_insert BEFORE INSERT ON ref.audit_collection_policy FOR EACH ROW EXECUTE FUNCTION ref.set_actor_on_insert();


--
-- TOC entry 5895 (class 2620 OID 19225)
-- Name: audit_collection_policy trg_audit_collection_policy_set_actor_update; Type: TRIGGER; Schema: ref; Owner: msbadmin
--

CREATE TRIGGER trg_audit_collection_policy_set_actor_update BEFORE UPDATE ON ref.audit_collection_policy FOR EACH ROW EXECUTE FUNCTION ref.set_actor_on_update();


--
-- TOC entry 5873 (class 2620 OID 19172)
-- Name: container_endpoint trg_container_endpoint_set_actor_insert; Type: TRIGGER; Schema: ref; Owner: msbadmin
--

CREATE TRIGGER trg_container_endpoint_set_actor_insert BEFORE INSERT ON ref.container_endpoint FOR EACH ROW EXECUTE FUNCTION ref.set_actor_on_insert();


--
-- TOC entry 5874 (class 2620 OID 19174)
-- Name: container_endpoint trg_container_endpoint_set_actor_update; Type: TRIGGER; Schema: ref; Owner: msbadmin
--

CREATE TRIGGER trg_container_endpoint_set_actor_update BEFORE UPDATE ON ref.container_endpoint FOR EACH ROW EXECUTE FUNCTION ref.set_actor_on_update();


--
-- TOC entry 5853 (class 2620 OID 19177)
-- Name: container trg_container_set_actor_insert; Type: TRIGGER; Schema: ref; Owner: msbadmin
--

CREATE TRIGGER trg_container_set_actor_insert BEFORE INSERT ON ref.container FOR EACH ROW EXECUTE FUNCTION ref.set_actor_on_insert();


--
-- TOC entry 5854 (class 2620 OID 19178)
-- Name: container trg_container_set_actor_update; Type: TRIGGER; Schema: ref; Owner: msbadmin
--

CREATE TRIGGER trg_container_set_actor_update BEFORE UPDATE ON ref.container FOR EACH ROW EXECUTE FUNCTION ref.set_actor_on_update();


--
-- TOC entry 5884 (class 2620 OID 19195)
-- Name: container_test_status trg_container_test_status_set_actor_insert; Type: TRIGGER; Schema: ref; Owner: msbadmin
--

CREATE TRIGGER trg_container_test_status_set_actor_insert BEFORE INSERT ON ref.container_test_status FOR EACH ROW EXECUTE FUNCTION ref.set_actor_on_insert();


--
-- TOC entry 5885 (class 2620 OID 19196)
-- Name: container_test_status trg_container_test_status_set_actor_update; Type: TRIGGER; Schema: ref; Owner: msbadmin
--

CREATE TRIGGER trg_container_test_status_set_actor_update BEFORE UPDATE ON ref.container_test_status FOR EACH ROW EXECUTE FUNCTION ref.set_actor_on_update();


--
-- TOC entry 5851 (class 2620 OID 19183)
-- Name: container_type trg_container_type_set_actor_insert; Type: TRIGGER; Schema: ref; Owner: msbadmin
--

CREATE TRIGGER trg_container_type_set_actor_insert BEFORE INSERT ON ref.container_type FOR EACH ROW EXECUTE FUNCTION ref.set_actor_on_insert();


--
-- TOC entry 5852 (class 2620 OID 19184)
-- Name: container_type trg_container_type_set_actor_update; Type: TRIGGER; Schema: ref; Owner: msbadmin
--

CREATE TRIGGER trg_container_type_set_actor_update BEFORE UPDATE ON ref.container_type FOR EACH ROW EXECUTE FUNCTION ref.set_actor_on_update();


--
-- TOC entry 5861 (class 2620 OID 19180)
-- Name: display trg_display_set_actor_update; Type: TRIGGER; Schema: ref; Owner: msbadmin
--

CREATE TRIGGER trg_display_set_actor_update BEFORE UPDATE ON ref.display FOR EACH ROW EXECUTE FUNCTION ref.set_actor_on_update();


--
-- TOC entry 5849 (class 2620 OID 19185)
-- Name: display_status trg_display_status_set_actor_insert; Type: TRIGGER; Schema: ref; Owner: msbadmin
--

CREATE TRIGGER trg_display_status_set_actor_insert BEFORE INSERT ON ref.display_status FOR EACH ROW EXECUTE FUNCTION ref.set_actor_on_insert();


--
-- TOC entry 5850 (class 2620 OID 19186)
-- Name: display_status trg_display_status_set_actor_update; Type: TRIGGER; Schema: ref; Owner: msbadmin
--

CREATE TRIGGER trg_display_status_set_actor_update BEFORE UPDATE ON ref.display_status FOR EACH ROW EXECUTE FUNCTION ref.set_actor_on_update();


--
-- TOC entry 5882 (class 2620 OID 19197)
-- Name: display_test_status trg_display_test_status_set_actor_insert; Type: TRIGGER; Schema: ref; Owner: msbadmin
--

CREATE TRIGGER trg_display_test_status_set_actor_insert BEFORE INSERT ON ref.display_test_status FOR EACH ROW EXECUTE FUNCTION ref.set_actor_on_insert();


--
-- TOC entry 5883 (class 2620 OID 19198)
-- Name: display_test_status trg_display_test_status_set_actor_update; Type: TRIGGER; Schema: ref; Owner: msbadmin
--

CREATE TRIGGER trg_display_test_status_set_actor_update BEFORE UPDATE ON ref.display_test_status FOR EACH ROW EXECUTE FUNCTION ref.set_actor_on_update();


--
-- TOC entry 5845 (class 2620 OID 19187)
-- Name: frame trg_frame_set_actor_insert; Type: TRIGGER; Schema: ref; Owner: msbadmin
--

CREATE TRIGGER trg_frame_set_actor_insert BEFORE INSERT ON ref.frame FOR EACH ROW EXECUTE FUNCTION ref.set_actor_on_insert();


--
-- TOC entry 5846 (class 2620 OID 19188)
-- Name: frame trg_frame_set_actor_update; Type: TRIGGER; Schema: ref; Owner: msbadmin
--

CREATE TRIGGER trg_frame_set_actor_update BEFORE UPDATE ON ref.frame FOR EACH ROW EXECUTE FUNCTION ref.set_actor_on_update();


--
-- TOC entry 5859 (class 2620 OID 19199)
-- Name: inventory_type trg_inventory_type_set_actor_insert; Type: TRIGGER; Schema: ref; Owner: msbadmin
--

CREATE TRIGGER trg_inventory_type_set_actor_insert BEFORE INSERT ON ref.inventory_type FOR EACH ROW EXECUTE FUNCTION ref.set_actor_on_insert();


--
-- TOC entry 5860 (class 2620 OID 19200)
-- Name: inventory_type trg_inventory_type_set_actor_update; Type: TRIGGER; Schema: ref; Owner: msbadmin
--

CREATE TRIGGER trg_inventory_type_set_actor_update BEFORE UPDATE ON ref.inventory_type FOR EACH ROW EXECUTE FUNCTION ref.set_actor_on_update();


--
-- TOC entry 5899 (class 2620 OID 24169)
-- Name: lor_scene_display trg_lor_scene_display_require_change; Type: TRIGGER; Schema: ref; Owner: msbadmin
--

CREATE TRIGGER trg_lor_scene_display_require_change BEFORE UPDATE ON ref.lor_scene_display FOR EACH ROW EXECUTE FUNCTION ref.trg_lor_scene_display_require_change();


--
-- TOC entry 5898 (class 2620 OID 24167)
-- Name: lor_scene trg_lor_scene_require_change; Type: TRIGGER; Schema: ref; Owner: msbadmin
--

CREATE TRIGGER trg_lor_scene_require_change BEFORE UPDATE ON ref.lor_scene FOR EACH ROW EXECUTE FUNCTION ref.trg_lor_scene_require_change();


--
-- TOC entry 5857 (class 2620 OID 19189)
-- Name: person trg_person_set_actor_insert; Type: TRIGGER; Schema: ref; Owner: msbadmin
--

CREATE TRIGGER trg_person_set_actor_insert BEFORE INSERT ON ref.person FOR EACH ROW EXECUTE FUNCTION ref.set_actor_on_insert();


--
-- TOC entry 5858 (class 2620 OID 19190)
-- Name: person trg_person_set_actor_update; Type: TRIGGER; Schema: ref; Owner: msbadmin
--

CREATE TRIGGER trg_person_set_actor_update BEFORE UPDATE ON ref.person FOR EACH ROW EXECUTE FUNCTION ref.set_actor_on_update();


--
-- TOC entry 5896 (class 2620 OID 19494)
-- Name: season trg_season_set_actor_insert; Type: TRIGGER; Schema: ref; Owner: msbadmin
--

CREATE TRIGGER trg_season_set_actor_insert BEFORE INSERT ON ref.season FOR EACH ROW EXECUTE FUNCTION ref.set_actor_on_insert();


--
-- TOC entry 5897 (class 2620 OID 19495)
-- Name: season trg_season_set_actor_update; Type: TRIGGER; Schema: ref; Owner: msbadmin
--

CREATE TRIGGER trg_season_set_actor_update BEFORE UPDATE ON ref.season FOR EACH ROW EXECUTE FUNCTION ref.set_actor_on_update();


--
-- TOC entry 5908 (class 2620 OID 24165)
-- Name: stage_lor_binding trg_stage_lor_binding_require_change; Type: TRIGGER; Schema: ref; Owner: msbadmin
--

CREATE TRIGGER trg_stage_lor_binding_require_change BEFORE UPDATE ON ref.stage_lor_binding FOR EACH ROW EXECUTE FUNCTION ref.trg_stage_lor_binding_require_change();


--
-- TOC entry 5872 (class 2620 OID 19182)
-- Name: stage trg_stage_set_actor_update; Type: TRIGGER; Schema: ref; Owner: msbadmin
--

CREATE TRIGGER trg_stage_set_actor_update BEFORE UPDATE ON ref.stage FOR EACH ROW EXECUTE FUNCTION ref.set_actor_on_update();


--
-- TOC entry 5856 (class 2620 OID 19181)
-- Name: storage_location trg_storage_location_set_actor_update; Type: TRIGGER; Schema: ref; Owner: msbadmin
--

CREATE TRIGGER trg_storage_location_set_actor_update BEFORE UPDATE ON ref.storage_location FOR EACH ROW EXECUTE FUNCTION ref.set_actor_on_update();


--
-- TOC entry 5855 (class 2620 OID 19300)
-- Name: container trg_sync_container_search_helper_to_test_session; Type: TRIGGER; Schema: ref; Owner: msbadmin
--

CREATE TRIGGER trg_sync_container_search_helper_to_test_session AFTER UPDATE OF description ON ref.container FOR EACH ROW WHEN ((old.description IS DISTINCT FROM new.description)) EXECUTE FUNCTION ref.sync_container_search_helper_to_test_session();


--
-- TOC entry 5875 (class 2620 OID 19201)
-- Name: task_type trg_task_type_set_actor_insert; Type: TRIGGER; Schema: ref; Owner: msbadmin
--

CREATE TRIGGER trg_task_type_set_actor_insert BEFORE INSERT ON ref.task_type FOR EACH ROW EXECUTE FUNCTION ref.set_actor_on_insert();


--
-- TOC entry 5876 (class 2620 OID 19202)
-- Name: task_type trg_task_type_set_actor_update; Type: TRIGGER; Schema: ref; Owner: msbadmin
--

CREATE TRIGGER trg_task_type_set_actor_update BEFORE UPDATE ON ref.task_type FOR EACH ROW EXECUTE FUNCTION ref.set_actor_on_update();


--
-- TOC entry 5847 (class 2620 OID 19193)
-- Name: theme trg_theme_set_actor_insert; Type: TRIGGER; Schema: ref; Owner: msbadmin
--

CREATE TRIGGER trg_theme_set_actor_insert BEFORE INSERT ON ref.theme FOR EACH ROW EXECUTE FUNCTION ref.set_actor_on_insert();


--
-- TOC entry 5848 (class 2620 OID 19194)
-- Name: theme trg_theme_set_actor_update; Type: TRIGGER; Schema: ref; Owner: msbadmin
--

CREATE TRIGGER trg_theme_set_actor_update BEFORE UPDATE ON ref.theme FOR EACH ROW EXECUTE FUNCTION ref.set_actor_on_update();


--
-- TOC entry 5877 (class 2620 OID 19203)
-- Name: work_area trg_work_area_set_actor_insert; Type: TRIGGER; Schema: ref; Owner: msbadmin
--

CREATE TRIGGER trg_work_area_set_actor_insert BEFORE INSERT ON ref.work_area FOR EACH ROW EXECUTE FUNCTION ref.set_actor_on_insert();


--
-- TOC entry 5878 (class 2620 OID 19204)
-- Name: work_area trg_work_area_set_actor_update; Type: TRIGGER; Schema: ref; Owner: msbadmin
--

CREATE TRIGGER trg_work_area_set_actor_update BEFORE UPDATE ON ref.work_area FOR EACH ROW EXECUTE FUNCTION ref.set_actor_on_update();


--
-- TOC entry 5886 (class 2620 OID 20088)
-- Name: work_order_intake trg_process_work_order_intake_on_triage; Type: TRIGGER; Schema: stage; Owner: directus_app
--

CREATE TRIGGER trg_process_work_order_intake_on_triage AFTER UPDATE OF triage_dropdown ON stage.work_order_intake FOR EACH ROW EXECUTE FUNCTION stage.tf_process_work_order_intake_on_triage();


--
-- TOC entry 5887 (class 2620 OID 20098)
-- Name: work_order_intake trg_resolve_work_order_intake_submitter; Type: TRIGGER; Schema: stage; Owner: directus_app
--

CREATE TRIGGER trg_resolve_work_order_intake_submitter BEFORE INSERT OR UPDATE OF submitter_email_raw, submitter_person_id, created_by_person_id ON stage.work_order_intake FOR EACH ROW EXECUTE FUNCTION stage.tf_resolve_work_order_intake_submitter();


--
-- TOC entry 5888 (class 2620 OID 19845)
-- Name: work_order_intake trg_work_order_intake_set_actor_insert; Type: TRIGGER; Schema: stage; Owner: directus_app
--

CREATE TRIGGER trg_work_order_intake_set_actor_insert BEFORE INSERT ON stage.work_order_intake FOR EACH ROW EXECUTE FUNCTION ref.set_actor_on_insert();


--
-- TOC entry 5889 (class 2620 OID 19846)
-- Name: work_order_intake trg_work_order_intake_set_actor_update; Type: TRIGGER; Schema: stage; Owner: directus_app
--

CREATE TRIGGER trg_work_order_intake_set_actor_update BEFORE UPDATE ON stage.work_order_intake FOR EACH ROW EXECUTE FUNCTION ref.set_actor_on_update();


--
-- TOC entry 5644 (class 2606 OID 16464)
-- Name: dmx_channels dmx_channels_import_run_id_fkey; Type: FK CONSTRAINT; Schema: lor_snap; Owner: msbadmin
--

ALTER TABLE ONLY lor_snap.dmx_channels
    ADD CONSTRAINT dmx_channels_import_run_id_fkey FOREIGN KEY (import_run_id) REFERENCES lor_snap.import_run(import_run_id) ON DELETE CASCADE;


--
-- TOC entry 5645 (class 2606 OID 16474)
-- Name: dmx_channels dmx_channels_import_run_id_preview_id_fkey; Type: FK CONSTRAINT; Schema: lor_snap; Owner: msbadmin
--

ALTER TABLE ONLY lor_snap.dmx_channels
    ADD CONSTRAINT dmx_channels_import_run_id_preview_id_fkey FOREIGN KEY (import_run_id, preview_id) REFERENCES lor_snap.previews(import_run_id, id) ON DELETE RESTRICT;


--
-- TOC entry 5646 (class 2606 OID 16469)
-- Name: dmx_channels dmx_channels_import_run_id_prop_id_fkey; Type: FK CONSTRAINT; Schema: lor_snap; Owner: msbadmin
--

ALTER TABLE ONLY lor_snap.dmx_channels
    ADD CONSTRAINT dmx_channels_import_run_id_prop_id_fkey FOREIGN KEY (import_run_id, prop_id) REFERENCES lor_snap.props(import_run_id, prop_id) ON DELETE RESTRICT;


--
-- TOC entry 5807 (class 2606 OID 23026)
-- Name: scene_lor_props fk_scene_lor_props_import_run; Type: FK CONSTRAINT; Schema: lor_snap; Owner: msbadmin
--

ALTER TABLE ONLY lor_snap.scene_lor_props
    ADD CONSTRAINT fk_scene_lor_props_import_run FOREIGN KEY (import_run_id) REFERENCES lor_snap.import_run(import_run_id);


--
-- TOC entry 5806 (class 2606 OID 23016)
-- Name: scenes fk_scenes_import_run; Type: FK CONSTRAINT; Schema: lor_snap; Owner: msbadmin
--

ALTER TABLE ONLY lor_snap.scenes
    ADD CONSTRAINT fk_scenes_import_run FOREIGN KEY (import_run_id) REFERENCES lor_snap.import_run(import_run_id);


--
-- TOC entry 5638 (class 2606 OID 16409)
-- Name: previews previews_import_run_id_fkey; Type: FK CONSTRAINT; Schema: lor_snap; Owner: msbadmin
--

ALTER TABLE ONLY lor_snap.previews
    ADD CONSTRAINT previews_import_run_id_fkey FOREIGN KEY (import_run_id) REFERENCES lor_snap.import_run(import_run_id) ON DELETE CASCADE;


--
-- TOC entry 5639 (class 2606 OID 16423)
-- Name: props props_import_run_id_fkey; Type: FK CONSTRAINT; Schema: lor_snap; Owner: msbadmin
--

ALTER TABLE ONLY lor_snap.props
    ADD CONSTRAINT props_import_run_id_fkey FOREIGN KEY (import_run_id) REFERENCES lor_snap.import_run(import_run_id) ON DELETE CASCADE;


--
-- TOC entry 5640 (class 2606 OID 16428)
-- Name: props props_import_run_id_preview_id_fkey; Type: FK CONSTRAINT; Schema: lor_snap; Owner: msbadmin
--

ALTER TABLE ONLY lor_snap.props
    ADD CONSTRAINT props_import_run_id_preview_id_fkey FOREIGN KEY (import_run_id, preview_id) REFERENCES lor_snap.previews(import_run_id, id) ON DELETE RESTRICT;


--
-- TOC entry 5641 (class 2606 OID 16442)
-- Name: sub_props sub_props_import_run_id_fkey; Type: FK CONSTRAINT; Schema: lor_snap; Owner: msbadmin
--

ALTER TABLE ONLY lor_snap.sub_props
    ADD CONSTRAINT sub_props_import_run_id_fkey FOREIGN KEY (import_run_id) REFERENCES lor_snap.import_run(import_run_id) ON DELETE CASCADE;


--
-- TOC entry 5642 (class 2606 OID 16447)
-- Name: sub_props sub_props_import_run_id_master_prop_id_fkey; Type: FK CONSTRAINT; Schema: lor_snap; Owner: msbadmin
--

ALTER TABLE ONLY lor_snap.sub_props
    ADD CONSTRAINT sub_props_import_run_id_master_prop_id_fkey FOREIGN KEY (import_run_id, master_prop_id) REFERENCES lor_snap.props(import_run_id, prop_id) ON DELETE RESTRICT;


--
-- TOC entry 5643 (class 2606 OID 16452)
-- Name: sub_props sub_props_import_run_id_preview_id_fkey; Type: FK CONSTRAINT; Schema: lor_snap; Owner: msbadmin
--

ALTER TABLE ONLY lor_snap.sub_props
    ADD CONSTRAINT sub_props_import_run_id_preview_id_fkey FOREIGN KEY (import_run_id, preview_id) REFERENCES lor_snap.previews(import_run_id, id) ON DELETE RESTRICT;


--
-- TOC entry 5802 (class 2606 OID 20738)
-- Name: container_label_batch_item container_label_batch_item_container_id_fkey; Type: FK CONSTRAINT; Schema: ops; Owner: msbadmin
--

ALTER TABLE ONLY ops.container_label_batch_item
    ADD CONSTRAINT container_label_batch_item_container_id_fkey FOREIGN KEY (container_id) REFERENCES ref.container(container_id) ON UPDATE CASCADE ON DELETE RESTRICT;


--
-- TOC entry 5803 (class 2606 OID 20733)
-- Name: container_label_batch_item container_label_batch_item_container_label_batch_id_fkey; Type: FK CONSTRAINT; Schema: ops; Owner: msbadmin
--

ALTER TABLE ONLY ops.container_label_batch_item
    ADD CONSTRAINT container_label_batch_item_container_label_batch_id_fkey FOREIGN KEY (container_label_batch_id) REFERENCES ops.container_label_batch(container_label_batch_id) ON DELETE CASCADE;


--
-- TOC entry 5797 (class 2606 OID 20703)
-- Name: display_label_batch_item display_label_batch_item_display_id_fkey; Type: FK CONSTRAINT; Schema: ops; Owner: msbadmin
--

ALTER TABLE ONLY ops.display_label_batch_item
    ADD CONSTRAINT display_label_batch_item_display_id_fkey FOREIGN KEY (display_id) REFERENCES ref.display(display_id) ON UPDATE CASCADE ON DELETE RESTRICT;


--
-- TOC entry 5798 (class 2606 OID 20698)
-- Name: display_label_batch_item display_label_batch_item_display_label_batch_id_fkey; Type: FK CONSTRAINT; Schema: ops; Owner: msbadmin
--

ALTER TABLE ONLY ops.display_label_batch_item
    ADD CONSTRAINT display_label_batch_item_display_label_batch_id_fkey FOREIGN KEY (display_label_batch_id) REFERENCES ops.display_label_batch(display_label_batch_id) ON DELETE CASCADE;


--
-- TOC entry 5689 (class 2606 OID 17299)
-- Name: display_test_session display_test_session_test_session_id_fkey; Type: FK CONSTRAINT; Schema: ops; Owner: msbadmin
--

ALTER TABLE ONLY ops.display_test_session
    ADD CONSTRAINT display_test_session_test_session_id_fkey FOREIGN KEY (test_session_id) REFERENCES ops.test_session(test_session_id) ON DELETE CASCADE;


--
-- TOC entry 5804 (class 2606 OID 20768)
-- Name: container_label_batch_item fk_container_label_batch_item_batch; Type: FK CONSTRAINT; Schema: ops; Owner: msbadmin
--

ALTER TABLE ONLY ops.container_label_batch_item
    ADD CONSTRAINT fk_container_label_batch_item_batch FOREIGN KEY (container_label_batch_id) REFERENCES ops.container_label_batch(container_label_batch_id) ON DELETE CASCADE;


--
-- TOC entry 5805 (class 2606 OID 20773)
-- Name: container_label_batch_item fk_container_label_batch_item_container; Type: FK CONSTRAINT; Schema: ops; Owner: msbadmin
--

ALTER TABLE ONLY ops.container_label_batch_item
    ADD CONSTRAINT fk_container_label_batch_item_container FOREIGN KEY (container_id) REFERENCES ref.container(container_id) ON UPDATE CASCADE ON DELETE RESTRICT;


--
-- TOC entry 5801 (class 2606 OID 20763)
-- Name: container_label_batch fk_container_label_batch_person; Type: FK CONSTRAINT; Schema: ops; Owner: msbadmin
--

ALTER TABLE ONLY ops.container_label_batch
    ADD CONSTRAINT fk_container_label_batch_person FOREIGN KEY (started_by_person_id) REFERENCES ref.person(person_id) ON UPDATE CASCADE ON DELETE SET NULL;


--
-- TOC entry 5794 (class 2606 OID 20812)
-- Name: container_label_print fk_container_label_print_container; Type: FK CONSTRAINT; Schema: ops; Owner: directus_app
--

ALTER TABLE ONLY ops.container_label_print
    ADD CONSTRAINT fk_container_label_print_container FOREIGN KEY (container_id) REFERENCES ref.container(container_id) ON DELETE SET NULL;


--
-- TOC entry 5795 (class 2606 OID 20668)
-- Name: container_label_print fk_container_label_print_person; Type: FK CONSTRAINT; Schema: ops; Owner: directus_app
--

ALTER TABLE ONLY ops.container_label_print
    ADD CONSTRAINT fk_container_label_print_person FOREIGN KEY (printed_by_person_id) REFERENCES ref.person(person_id) ON UPDATE CASCADE ON DELETE SET NULL;


--
-- TOC entry 5799 (class 2606 OID 20750)
-- Name: display_label_batch_item fk_display_label_batch_item_batch; Type: FK CONSTRAINT; Schema: ops; Owner: msbadmin
--

ALTER TABLE ONLY ops.display_label_batch_item
    ADD CONSTRAINT fk_display_label_batch_item_batch FOREIGN KEY (display_label_batch_id) REFERENCES ops.display_label_batch(display_label_batch_id) ON DELETE CASCADE;


--
-- TOC entry 5800 (class 2606 OID 20755)
-- Name: display_label_batch_item fk_display_label_batch_item_display; Type: FK CONSTRAINT; Schema: ops; Owner: msbadmin
--

ALTER TABLE ONLY ops.display_label_batch_item
    ADD CONSTRAINT fk_display_label_batch_item_display FOREIGN KEY (display_id) REFERENCES ref.display(display_id) ON UPDATE CASCADE ON DELETE RESTRICT;


--
-- TOC entry 5796 (class 2606 OID 20745)
-- Name: display_label_batch fk_display_label_batch_person; Type: FK CONSTRAINT; Schema: ops; Owner: msbadmin
--

ALTER TABLE ONLY ops.display_label_batch
    ADD CONSTRAINT fk_display_label_batch_person FOREIGN KEY (started_by_person_id) REFERENCES ref.person(person_id) ON UPDATE CASCADE ON DELETE SET NULL;


--
-- TOC entry 5792 (class 2606 OID 20817)
-- Name: display_label_print fk_display_label_print_display; Type: FK CONSTRAINT; Schema: ops; Owner: directus_app
--

ALTER TABLE ONLY ops.display_label_print
    ADD CONSTRAINT fk_display_label_print_display FOREIGN KEY (display_id) REFERENCES ref.display(display_id) ON DELETE SET NULL;


--
-- TOC entry 5793 (class 2606 OID 20663)
-- Name: display_label_print fk_display_label_print_person; Type: FK CONSTRAINT; Schema: ops; Owner: directus_app
--

ALTER TABLE ONLY ops.display_label_print
    ADD CONSTRAINT fk_display_label_print_person FOREIGN KEY (printed_by_person_id) REFERENCES ref.person(person_id) ON UPDATE CASCADE ON DELETE SET NULL;


--
-- TOC entry 5690 (class 2606 OID 19267)
-- Name: display_test_session fk_display_test_session_checked_by_person; Type: FK CONSTRAINT; Schema: ops; Owner: msbadmin
--

ALTER TABLE ONLY ops.display_test_session
    ADD CONSTRAINT fk_display_test_session_checked_by_person FOREIGN KEY (checked_by_person_id) REFERENCES ref.person(person_id);


--
-- TOC entry 5691 (class 2606 OID 19257)
-- Name: display_test_session fk_display_test_session_created_by_person; Type: FK CONSTRAINT; Schema: ops; Owner: msbadmin
--

ALTER TABLE ONLY ops.display_test_session
    ADD CONSTRAINT fk_display_test_session_created_by_person FOREIGN KEY (created_by_person_id) REFERENCES ref.person(person_id);


--
-- TOC entry 5692 (class 2606 OID 18933)
-- Name: display_test_session fk_display_test_session_stage; Type: FK CONSTRAINT; Schema: ops; Owner: msbadmin
--

ALTER TABLE ONLY ops.display_test_session
    ADD CONSTRAINT fk_display_test_session_stage FOREIGN KEY (stage_id) REFERENCES ref.stage(stage_id);


--
-- TOC entry 5693 (class 2606 OID 18928)
-- Name: display_test_session fk_display_test_session_test_status; Type: FK CONSTRAINT; Schema: ops; Owner: msbadmin
--

ALTER TABLE ONLY ops.display_test_session
    ADD CONSTRAINT fk_display_test_session_test_status FOREIGN KEY (test_status) REFERENCES ref.display_test_status(test_status_code);


--
-- TOC entry 5694 (class 2606 OID 19262)
-- Name: display_test_session fk_display_test_session_updated_by_person; Type: FK CONSTRAINT; Schema: ops; Owner: msbadmin
--

ALTER TABLE ONLY ops.display_test_session
    ADD CONSTRAINT fk_display_test_session_updated_by_person FOREIGN KEY (updated_by_person_id) REFERENCES ref.person(person_id);


--
-- TOC entry 5808 (class 2606 OID 23200)
-- Name: lor_reconciliation_action_legacy fk_lor_reconciliation_action_display; Type: FK CONSTRAINT; Schema: ops; Owner: msbadmin
--

ALTER TABLE ONLY ops.lor_reconciliation_action_legacy
    ADD CONSTRAINT fk_lor_reconciliation_action_display FOREIGN KEY (display_id) REFERENCES ref.display(display_id);


--
-- TOC entry 5822 (class 2606 OID 23504)
-- Name: lor_reconciliation_action fk_lor_reconciliation_action_group; Type: FK CONSTRAINT; Schema: ops; Owner: msbadmin
--

ALTER TABLE ONLY ops.lor_reconciliation_action
    ADD CONSTRAINT fk_lor_reconciliation_action_group FOREIGN KEY (lor_reconciliation_group_id) REFERENCES ops.lor_reconciliation_group(lor_reconciliation_group_id);


--
-- TOC entry 5823 (class 2606 OID 23499)
-- Name: lor_reconciliation_action fk_lor_reconciliation_action_run; Type: FK CONSTRAINT; Schema: ops; Owner: msbadmin
--

ALTER TABLE ONLY ops.lor_reconciliation_action
    ADD CONSTRAINT fk_lor_reconciliation_action_run FOREIGN KEY (lor_reconciliation_run_id) REFERENCES ops.lor_reconciliation_run(lor_reconciliation_run_id);


--
-- TOC entry 5809 (class 2606 OID 23195)
-- Name: lor_reconciliation_action_legacy fk_lor_reconciliation_action_run; Type: FK CONSTRAINT; Schema: ops; Owner: msbadmin
--

ALTER TABLE ONLY ops.lor_reconciliation_action_legacy
    ADD CONSTRAINT fk_lor_reconciliation_action_run FOREIGN KEY (import_run_id) REFERENCES lor_snap.import_run(import_run_id);


--
-- TOC entry 5810 (class 2606 OID 23210)
-- Name: lor_reconciliation_action_legacy fk_lor_reconciliation_action_status_after; Type: FK CONSTRAINT; Schema: ops; Owner: msbadmin
--

ALTER TABLE ONLY ops.lor_reconciliation_action_legacy
    ADD CONSTRAINT fk_lor_reconciliation_action_status_after FOREIGN KEY (display_status_id_after) REFERENCES ref.display_status(display_status_id);


--
-- TOC entry 5811 (class 2606 OID 23205)
-- Name: lor_reconciliation_action_legacy fk_lor_reconciliation_action_status_before; Type: FK CONSTRAINT; Schema: ops; Owner: msbadmin
--

ALTER TABLE ONLY ops.lor_reconciliation_action_legacy
    ADD CONSTRAINT fk_lor_reconciliation_action_status_before FOREIGN KEY (display_status_id_before) REFERENCES ref.display_status(display_status_id);


--
-- TOC entry 5824 (class 2606 OID 23522)
-- Name: lor_reconciliation_action_assignment fk_lor_reconciliation_assignment_action; Type: FK CONSTRAINT; Schema: ops; Owner: msbadmin
--

ALTER TABLE ONLY ops.lor_reconciliation_action_assignment
    ADD CONSTRAINT fk_lor_reconciliation_assignment_action FOREIGN KEY (lor_reconciliation_action_id) REFERENCES ops.lor_reconciliation_action(lor_reconciliation_action_id);


--
-- TOC entry 5825 (class 2606 OID 23527)
-- Name: lor_reconciliation_action_assignment fk_lor_reconciliation_assignment_candidate; Type: FK CONSTRAINT; Schema: ops; Owner: msbadmin
--

ALTER TABLE ONLY ops.lor_reconciliation_action_assignment
    ADD CONSTRAINT fk_lor_reconciliation_assignment_candidate FOREIGN KEY (lor_reconciliation_display_candidate_id) REFERENCES ops.lor_reconciliation_display_candidate(lor_reconciliation_display_candidate_id);


--
-- TOC entry 5826 (class 2606 OID 23532)
-- Name: lor_reconciliation_action_assignment fk_lor_reconciliation_assignment_display; Type: FK CONSTRAINT; Schema: ops; Owner: msbadmin
--

ALTER TABLE ONLY ops.lor_reconciliation_action_assignment
    ADD CONSTRAINT fk_lor_reconciliation_assignment_display FOREIGN KEY (target_display_id) REFERENCES ref.display(display_id);


--
-- TOC entry 5819 (class 2606 OID 23478)
-- Name: lor_reconciliation_display_candidate fk_lor_reconciliation_display_candidate_display; Type: FK CONSTRAINT; Schema: ops; Owner: msbadmin
--

ALTER TABLE ONLY ops.lor_reconciliation_display_candidate
    ADD CONSTRAINT fk_lor_reconciliation_display_candidate_display FOREIGN KEY (display_id) REFERENCES ref.display(display_id);


--
-- TOC entry 5820 (class 2606 OID 23473)
-- Name: lor_reconciliation_display_candidate fk_lor_reconciliation_display_candidate_group; Type: FK CONSTRAINT; Schema: ops; Owner: msbadmin
--

ALTER TABLE ONLY ops.lor_reconciliation_display_candidate
    ADD CONSTRAINT fk_lor_reconciliation_display_candidate_group FOREIGN KEY (lor_reconciliation_group_id) REFERENCES ops.lor_reconciliation_group(lor_reconciliation_group_id);


--
-- TOC entry 5821 (class 2606 OID 23468)
-- Name: lor_reconciliation_display_candidate fk_lor_reconciliation_display_candidate_run; Type: FK CONSTRAINT; Schema: ops; Owner: msbadmin
--

ALTER TABLE ONLY ops.lor_reconciliation_display_candidate
    ADD CONSTRAINT fk_lor_reconciliation_display_candidate_run FOREIGN KEY (lor_reconciliation_run_id) REFERENCES ops.lor_reconciliation_run(lor_reconciliation_run_id);


--
-- TOC entry 5818 (class 2606 OID 23446)
-- Name: lor_reconciliation_group fk_lor_reconciliation_group_run; Type: FK CONSTRAINT; Schema: ops; Owner: msbadmin
--

ALTER TABLE ONLY ops.lor_reconciliation_group
    ADD CONSTRAINT fk_lor_reconciliation_group_run FOREIGN KEY (lor_reconciliation_run_id) REFERENCES ops.lor_reconciliation_run(lor_reconciliation_run_id);


--
-- TOC entry 5827 (class 2606 OID 23549)
-- Name: lor_reconciliation_result fk_lor_reconciliation_result_run; Type: FK CONSTRAINT; Schema: ops; Owner: msbadmin
--

ALTER TABLE ONLY ops.lor_reconciliation_result
    ADD CONSTRAINT fk_lor_reconciliation_result_run FOREIGN KEY (lor_reconciliation_run_id) REFERENCES ops.lor_reconciliation_run(lor_reconciliation_run_id);


--
-- TOC entry 5680 (class 2606 OID 19527)
-- Name: test_session fk_test_session_container; Type: FK CONSTRAINT; Schema: ops; Owner: msbadmin
--

ALTER TABLE ONLY ops.test_session
    ADD CONSTRAINT fk_test_session_container FOREIGN KEY (container_id) REFERENCES ref.container(container_id);


--
-- TOC entry 5681 (class 2606 OID 18951)
-- Name: test_session fk_test_session_container_test_status; Type: FK CONSTRAINT; Schema: ops; Owner: msbadmin
--

ALTER TABLE ONLY ops.test_session
    ADD CONSTRAINT fk_test_session_container_test_status FOREIGN KEY (container_test_status_id) REFERENCES ref.container_test_status(container_test_status_id);


--
-- TOC entry 5682 (class 2606 OID 19247)
-- Name: test_session fk_test_session_created_by_person; Type: FK CONSTRAINT; Schema: ops; Owner: msbadmin
--

ALTER TABLE ONLY ops.test_session
    ADD CONSTRAINT fk_test_session_created_by_person FOREIGN KEY (created_by_person_id) REFERENCES ref.person(person_id);


--
-- TOC entry 5683 (class 2606 OID 19532)
-- Name: test_session fk_test_session_home_location; Type: FK CONSTRAINT; Schema: ops; Owner: msbadmin
--

ALTER TABLE ONLY ops.test_session
    ADD CONSTRAINT fk_test_session_home_location FOREIGN KEY (home_location_code) REFERENCES ref.storage_location(location_code);


--
-- TOC entry 5684 (class 2606 OID 19549)
-- Name: test_session fk_test_session_last_refreshed_by_person; Type: FK CONSTRAINT; Schema: ops; Owner: msbadmin
--

ALTER TABLE ONLY ops.test_session
    ADD CONSTRAINT fk_test_session_last_refreshed_by_person FOREIGN KEY (last_refreshed_by_person_id) REFERENCES ref.person(person_id);


--
-- TOC entry 5685 (class 2606 OID 19497)
-- Name: test_session fk_test_session_pulled_by_person; Type: FK CONSTRAINT; Schema: ops; Owner: msbadmin
--

ALTER TABLE ONLY ops.test_session
    ADD CONSTRAINT fk_test_session_pulled_by_person FOREIGN KEY (pulled_by_person_id) REFERENCES ref.person(person_id);


--
-- TOC entry 5686 (class 2606 OID 19522)
-- Name: test_session fk_test_session_season; Type: FK CONSTRAINT; Schema: ops; Owner: msbadmin
--

ALTER TABLE ONLY ops.test_session
    ADD CONSTRAINT fk_test_session_season FOREIGN KEY (season_year) REFERENCES ref.season(season_year);


--
-- TOC entry 5687 (class 2606 OID 19252)
-- Name: test_session fk_test_session_updated_by_person; Type: FK CONSTRAINT; Schema: ops; Owner: msbadmin
--

ALTER TABLE ONLY ops.test_session
    ADD CONSTRAINT fk_test_session_updated_by_person FOREIGN KEY (updated_by_person_id) REFERENCES ref.person(person_id);


--
-- TOC entry 5688 (class 2606 OID 19537)
-- Name: test_session fk_test_session_work_location; Type: FK CONSTRAINT; Schema: ops; Owner: msbadmin
--

ALTER TABLE ONLY ops.test_session
    ADD CONSTRAINT fk_test_session_work_location FOREIGN KEY (work_location_code) REFERENCES ref.storage_location(location_code);


--
-- TOC entry 5776 (class 2606 OID 19923)
-- Name: work_order_assignment fk_woa_assigned_by; Type: FK CONSTRAINT; Schema: ops; Owner: directus_app
--

ALTER TABLE ONLY ops.work_order_assignment
    ADD CONSTRAINT fk_woa_assigned_by FOREIGN KEY (assigned_by_person_id) REFERENCES ref.person(person_id);


--
-- TOC entry 5777 (class 2606 OID 19918)
-- Name: work_order_assignment fk_woa_person; Type: FK CONSTRAINT; Schema: ops; Owner: directus_app
--

ALTER TABLE ONLY ops.work_order_assignment
    ADD CONSTRAINT fk_woa_person FOREIGN KEY (person_id) REFERENCES ref.person(person_id);


--
-- TOC entry 5778 (class 2606 OID 19928)
-- Name: work_order_assignment fk_woa_unassigned_by; Type: FK CONSTRAINT; Schema: ops; Owner: directus_app
--

ALTER TABLE ONLY ops.work_order_assignment
    ADD CONSTRAINT fk_woa_unassigned_by FOREIGN KEY (unassigned_by_person_id) REFERENCES ref.person(person_id);


--
-- TOC entry 5779 (class 2606 OID 24067)
-- Name: work_order_assignment fk_woa_work_order; Type: FK CONSTRAINT; Schema: ops; Owner: directus_app
--

ALTER TABLE ONLY ops.work_order_assignment
    ADD CONSTRAINT fk_woa_work_order FOREIGN KEY (work_order_id) REFERENCES ops.work_order(work_order_id) ON DELETE CASCADE;


--
-- TOC entry 5785 (class 2606 OID 19085)
-- Name: work_order_outbound_message fk_woom_created_by; Type: FK CONSTRAINT; Schema: ops; Owner: msbadmin
--

ALTER TABLE ONLY ops.work_order_outbound_message
    ADD CONSTRAINT fk_woom_created_by FOREIGN KEY (created_by_person_id) REFERENCES ref.person(person_id);


--
-- TOC entry 5786 (class 2606 OID 19090)
-- Name: work_order_outbound_message fk_woom_updated_by; Type: FK CONSTRAINT; Schema: ops; Owner: msbadmin
--

ALTER TABLE ONLY ops.work_order_outbound_message
    ADD CONSTRAINT fk_woom_updated_by FOREIGN KEY (updated_by_person_id) REFERENCES ref.person(person_id);


--
-- TOC entry 5787 (class 2606 OID 19080)
-- Name: work_order_outbound_message fk_woom_work_order; Type: FK CONSTRAINT; Schema: ops; Owner: msbadmin
--

ALTER TABLE ONLY ops.work_order_outbound_message
    ADD CONSTRAINT fk_woom_work_order FOREIGN KEY (work_order_id) REFERENCES ops.work_order(work_order_id) ON DELETE CASCADE;


--
-- TOC entry 5780 (class 2606 OID 19933)
-- Name: work_order_assignment fk_work_order_assignment_created_by_person; Type: FK CONSTRAINT; Schema: ops; Owner: directus_app
--

ALTER TABLE ONLY ops.work_order_assignment
    ADD CONSTRAINT fk_work_order_assignment_created_by_person FOREIGN KEY (created_by_person_id) REFERENCES ref.person(person_id);


--
-- TOC entry 5781 (class 2606 OID 19938)
-- Name: work_order_assignment fk_work_order_assignment_updated_by_person; Type: FK CONSTRAINT; Schema: ops; Owner: directus_app
--

ALTER TABLE ONLY ops.work_order_assignment
    ADD CONSTRAINT fk_work_order_assignment_updated_by_person FOREIGN KEY (updated_by_person_id) REFERENCES ref.person(person_id);


--
-- TOC entry 5751 (class 2606 OID 19903)
-- Name: work_order fk_work_order_completed_by; Type: FK CONSTRAINT; Schema: ops; Owner: directus_app
--

ALTER TABLE ONLY ops.work_order
    ADD CONSTRAINT fk_work_order_completed_by FOREIGN KEY (completed_by_person_id) REFERENCES ref.person(person_id);


--
-- TOC entry 5752 (class 2606 OID 19908)
-- Name: work_order fk_work_order_created_by; Type: FK CONSTRAINT; Schema: ops; Owner: directus_app
--

ALTER TABLE ONLY ops.work_order
    ADD CONSTRAINT fk_work_order_created_by FOREIGN KEY (created_by_person_id) REFERENCES ref.person(person_id);


--
-- TOC entry 5753 (class 2606 OID 18762)
-- Name: work_order fk_work_order_display; Type: FK CONSTRAINT; Schema: ops; Owner: directus_app
--

ALTER TABLE ONLY ops.work_order
    ADD CONSTRAINT fk_work_order_display FOREIGN KEY (display_id) REFERENCES ref.display(display_id);


--
-- TOC entry 5754 (class 2606 OID 18767)
-- Name: work_order fk_work_order_display_test_session; Type: FK CONSTRAINT; Schema: ops; Owner: directus_app
--

ALTER TABLE ONLY ops.work_order
    ADD CONSTRAINT fk_work_order_display_test_session FOREIGN KEY (display_test_session_id) REFERENCES ops.display_test_session(display_test_session_id);


--
-- TOC entry 5788 (class 2606 OID 19282)
-- Name: work_order_outbound_message fk_work_order_outbound_message_created_by_person; Type: FK CONSTRAINT; Schema: ops; Owner: msbadmin
--

ALTER TABLE ONLY ops.work_order_outbound_message
    ADD CONSTRAINT fk_work_order_outbound_message_created_by_person FOREIGN KEY (created_by_person_id) REFERENCES ref.person(person_id);


--
-- TOC entry 5789 (class 2606 OID 19287)
-- Name: work_order_outbound_message fk_work_order_outbound_message_updated_by_person; Type: FK CONSTRAINT; Schema: ops; Owner: msbadmin
--

ALTER TABLE ONLY ops.work_order_outbound_message
    ADD CONSTRAINT fk_work_order_outbound_message_updated_by_person FOREIGN KEY (updated_by_person_id) REFERENCES ref.person(person_id);


--
-- TOC entry 5755 (class 2606 OID 19814)
-- Name: work_order fk_work_order_stage; Type: FK CONSTRAINT; Schema: ops; Owner: directus_app
--

ALTER TABLE ONLY ops.work_order
    ADD CONSTRAINT fk_work_order_stage FOREIGN KEY (stage_id) REFERENCES ref.stage(stage_id);


--
-- TOC entry 5756 (class 2606 OID 20038)
-- Name: work_order fk_work_order_submitted_by_person; Type: FK CONSTRAINT; Schema: ops; Owner: directus_app
--

ALTER TABLE ONLY ops.work_order
    ADD CONSTRAINT fk_work_order_submitted_by_person FOREIGN KEY (submitted_by_person_id) REFERENCES ref.person(person_id);


--
-- TOC entry 5757 (class 2606 OID 18504)
-- Name: work_order fk_work_order_task_type; Type: FK CONSTRAINT; Schema: ops; Owner: directus_app
--

ALTER TABLE ONLY ops.work_order
    ADD CONSTRAINT fk_work_order_task_type FOREIGN KEY (task_type_id) REFERENCES ref.task_type(task_type_id);


--
-- TOC entry 5758 (class 2606 OID 20089)
-- Name: work_order fk_work_order_triaged_by_person; Type: FK CONSTRAINT; Schema: ops; Owner: directus_app
--

ALTER TABLE ONLY ops.work_order
    ADD CONSTRAINT fk_work_order_triaged_by_person FOREIGN KEY (triaged_by_person_id) REFERENCES ref.person(person_id);


--
-- TOC entry 5759 (class 2606 OID 19913)
-- Name: work_order fk_work_order_updated_by; Type: FK CONSTRAINT; Schema: ops; Owner: directus_app
--

ALTER TABLE ONLY ops.work_order
    ADD CONSTRAINT fk_work_order_updated_by FOREIGN KEY (updated_by_person_id) REFERENCES ref.person(person_id);


--
-- TOC entry 5760 (class 2606 OID 19787)
-- Name: work_order fk_work_order_urgency; Type: FK CONSTRAINT; Schema: ops; Owner: directus_app
--

ALTER TABLE ONLY ops.work_order
    ADD CONSTRAINT fk_work_order_urgency FOREIGN KEY (urgency_id) REFERENCES ref.urgency(urgency_id);


--
-- TOC entry 5761 (class 2606 OID 18499)
-- Name: work_order fk_work_order_work_area; Type: FK CONSTRAINT; Schema: ops; Owner: directus_app
--

ALTER TABLE ONLY ops.work_order
    ADD CONSTRAINT fk_work_order_work_area FOREIGN KEY (work_area_id) REFERENCES ref.work_area(work_area_id);


--
-- TOC entry 5782 (class 2606 OID 19062)
-- Name: work_order_status_history fk_wosh_changed_by; Type: FK CONSTRAINT; Schema: ops; Owner: msbadmin
--

ALTER TABLE ONLY ops.work_order_status_history
    ADD CONSTRAINT fk_wosh_changed_by FOREIGN KEY (changed_by_person_id) REFERENCES ref.person(person_id);


--
-- TOC entry 5783 (class 2606 OID 19057)
-- Name: work_order_status_history fk_wosh_status; Type: FK CONSTRAINT; Schema: ops; Owner: msbadmin
--

ALTER TABLE ONLY ops.work_order_status_history
    ADD CONSTRAINT fk_wosh_status FOREIGN KEY (work_order_status_id) REFERENCES ref.work_order_status(work_order_status_id);


--
-- TOC entry 5784 (class 2606 OID 19052)
-- Name: work_order_status_history fk_wosh_work_order; Type: FK CONSTRAINT; Schema: ops; Owner: msbadmin
--

ALTER TABLE ONLY ops.work_order_status_history
    ADD CONSTRAINT fk_wosh_work_order FOREIGN KEY (work_order_id) REFERENCES ops.work_order(work_order_id) ON DELETE CASCADE;


--
-- TOC entry 5817 (class 2606 OID 23933)
-- Name: lor_reconciliation_run lor_reconciliation_run_superseded_by_run_id_fkey; Type: FK CONSTRAINT; Schema: ops; Owner: msbadmin
--

ALTER TABLE ONLY ops.lor_reconciliation_run
    ADD CONSTRAINT lor_reconciliation_run_superseded_by_run_id_fkey FOREIGN KEY (superseded_by_run_id) REFERENCES ops.lor_reconciliation_run(lor_reconciliation_run_id);


--
-- TOC entry 5834 (class 2606 OID 23736)
-- Name: lor_reconciliation_scene_candidate lor_reconciliation_scene_candi_lor_reconciliation_group_id_fkey; Type: FK CONSTRAINT; Schema: ops; Owner: msbadmin
--

ALTER TABLE ONLY ops.lor_reconciliation_scene_candidate
    ADD CONSTRAINT lor_reconciliation_scene_candi_lor_reconciliation_group_id_fkey FOREIGN KEY (lor_reconciliation_group_id) REFERENCES ops.lor_reconciliation_group(lor_reconciliation_group_id);


--
-- TOC entry 5835 (class 2606 OID 23731)
-- Name: lor_reconciliation_scene_candidate lor_reconciliation_scene_candida_lor_reconciliation_run_id_fkey; Type: FK CONSTRAINT; Schema: ops; Owner: msbadmin
--

ALTER TABLE ONLY ops.lor_reconciliation_scene_candidate
    ADD CONSTRAINT lor_reconciliation_scene_candida_lor_reconciliation_run_id_fkey FOREIGN KEY (lor_reconciliation_run_id) REFERENCES ops.lor_reconciliation_run(lor_reconciliation_run_id);


--
-- TOC entry 5836 (class 2606 OID 23741)
-- Name: lor_reconciliation_scene_candidate lor_reconciliation_scene_candidate_resolved_stage_id_fkey; Type: FK CONSTRAINT; Schema: ops; Owner: msbadmin
--

ALTER TABLE ONLY ops.lor_reconciliation_scene_candidate
    ADD CONSTRAINT lor_reconciliation_scene_candidate_resolved_stage_id_fkey FOREIGN KEY (resolved_stage_id) REFERENCES ref.stage(stage_id);


--
-- TOC entry 5837 (class 2606 OID 23774)
-- Name: lor_reconciliation_scene_display_candidate lor_reconciliation_scene_disp_lor_reconciliation_display_c_fkey; Type: FK CONSTRAINT; Schema: ops; Owner: msbadmin
--

ALTER TABLE ONLY ops.lor_reconciliation_scene_display_candidate
    ADD CONSTRAINT lor_reconciliation_scene_disp_lor_reconciliation_display_c_fkey FOREIGN KEY (lor_reconciliation_display_candidate_id) REFERENCES ops.lor_reconciliation_display_candidate(lor_reconciliation_display_candidate_id);


--
-- TOC entry 5838 (class 2606 OID 23769)
-- Name: lor_reconciliation_scene_display_candidate lor_reconciliation_scene_displ_lor_reconciliation_group_id_fkey; Type: FK CONSTRAINT; Schema: ops; Owner: msbadmin
--

ALTER TABLE ONLY ops.lor_reconciliation_scene_display_candidate
    ADD CONSTRAINT lor_reconciliation_scene_displ_lor_reconciliation_group_id_fkey FOREIGN KEY (lor_reconciliation_group_id) REFERENCES ops.lor_reconciliation_group(lor_reconciliation_group_id);


--
-- TOC entry 5839 (class 2606 OID 23784)
-- Name: lor_reconciliation_scene_display_candidate lor_reconciliation_scene_display_candi_existing_display_id_fkey; Type: FK CONSTRAINT; Schema: ops; Owner: msbadmin
--

ALTER TABLE ONLY ops.lor_reconciliation_scene_display_candidate
    ADD CONSTRAINT lor_reconciliation_scene_display_candi_existing_display_id_fkey FOREIGN KEY (existing_display_id) REFERENCES ref.display(display_id);


--
-- TOC entry 5840 (class 2606 OID 23779)
-- Name: lor_reconciliation_scene_display_candidate lor_reconciliation_scene_display_candida_frozen_display_id_fkey; Type: FK CONSTRAINT; Schema: ops; Owner: msbadmin
--

ALTER TABLE ONLY ops.lor_reconciliation_scene_display_candidate
    ADD CONSTRAINT lor_reconciliation_scene_display_candida_frozen_display_id_fkey FOREIGN KEY (frozen_display_id) REFERENCES ref.display(display_id);


--
-- TOC entry 5841 (class 2606 OID 23764)
-- Name: lor_reconciliation_scene_display_candidate lor_reconciliation_scene_display_lor_reconciliation_run_id_fkey; Type: FK CONSTRAINT; Schema: ops; Owner: msbadmin
--

ALTER TABLE ONLY ops.lor_reconciliation_scene_display_candidate
    ADD CONSTRAINT lor_reconciliation_scene_display_lor_reconciliation_run_id_fkey FOREIGN KEY (lor_reconciliation_run_id) REFERENCES ops.lor_reconciliation_run(lor_reconciliation_run_id);


--
-- TOC entry 5843 (class 2606 OID 23903)
-- Name: lor_reconciliation_source_preview lor_reconciliation_source_previe_lor_reconciliation_run_id_fkey; Type: FK CONSTRAINT; Schema: ops; Owner: msbadmin
--

ALTER TABLE ONLY ops.lor_reconciliation_source_preview
    ADD CONSTRAINT lor_reconciliation_source_previe_lor_reconciliation_run_id_fkey FOREIGN KEY (lor_reconciliation_run_id) REFERENCES ops.lor_reconciliation_run(lor_reconciliation_run_id);


--
-- TOC entry 5842 (class 2606 OID 23887)
-- Name: lor_reconciliation_source_run lor_reconciliation_source_run_lor_reconciliation_run_id_fkey; Type: FK CONSTRAINT; Schema: ops; Owner: msbadmin
--

ALTER TABLE ONLY ops.lor_reconciliation_source_run
    ADD CONSTRAINT lor_reconciliation_source_run_lor_reconciliation_run_id_fkey FOREIGN KEY (lor_reconciliation_run_id) REFERENCES ops.lor_reconciliation_run(lor_reconciliation_run_id);


--
-- TOC entry 5844 (class 2606 OID 23917)
-- Name: lor_reconciliation_source_scene lor_reconciliation_source_scene_lor_reconciliation_run_id_fkey; Type: FK CONSTRAINT; Schema: ops; Owner: msbadmin
--

ALTER TABLE ONLY ops.lor_reconciliation_source_scene
    ADD CONSTRAINT lor_reconciliation_source_scene_lor_reconciliation_run_id_fkey FOREIGN KEY (lor_reconciliation_run_id) REFERENCES ops.lor_reconciliation_run(lor_reconciliation_run_id);


--
-- TOC entry 5829 (class 2606 OID 23634)
-- Name: lor_reconciliation_stage_candidate lor_reconciliation_stage_candi_lor_reconciliation_group_id_fkey; Type: FK CONSTRAINT; Schema: ops; Owner: msbadmin
--

ALTER TABLE ONLY ops.lor_reconciliation_stage_candidate
    ADD CONSTRAINT lor_reconciliation_stage_candi_lor_reconciliation_group_id_fkey FOREIGN KEY (lor_reconciliation_group_id) REFERENCES ops.lor_reconciliation_group(lor_reconciliation_group_id);


--
-- TOC entry 5830 (class 2606 OID 23629)
-- Name: lor_reconciliation_stage_candidate lor_reconciliation_stage_candida_lor_reconciliation_run_id_fkey; Type: FK CONSTRAINT; Schema: ops; Owner: msbadmin
--

ALTER TABLE ONLY ops.lor_reconciliation_stage_candidate
    ADD CONSTRAINT lor_reconciliation_stage_candida_lor_reconciliation_run_id_fkey FOREIGN KEY (lor_reconciliation_run_id) REFERENCES ops.lor_reconciliation_run(lor_reconciliation_run_id);


--
-- TOC entry 5831 (class 2606 OID 23644)
-- Name: lor_reconciliation_stage_candidate lor_reconciliation_stage_candidate_binding_stage_id_fkey; Type: FK CONSTRAINT; Schema: ops; Owner: msbadmin
--

ALTER TABLE ONLY ops.lor_reconciliation_stage_candidate
    ADD CONSTRAINT lor_reconciliation_stage_candidate_binding_stage_id_fkey FOREIGN KEY (binding_stage_id) REFERENCES ref.stage(stage_id);


--
-- TOC entry 5832 (class 2606 OID 23639)
-- Name: lor_reconciliation_stage_candidate lor_reconciliation_stage_candidate_resolved_stage_id_fkey; Type: FK CONSTRAINT; Schema: ops; Owner: msbadmin
--

ALTER TABLE ONLY ops.lor_reconciliation_stage_candidate
    ADD CONSTRAINT lor_reconciliation_stage_candidate_resolved_stage_id_fkey FOREIGN KEY (resolved_stage_id) REFERENCES ref.stage(stage_id);


--
-- TOC entry 5833 (class 2606 OID 23649)
-- Name: lor_reconciliation_stage_candidate lor_reconciliation_stage_candidate_stage_key_stage_id_fkey; Type: FK CONSTRAINT; Schema: ops; Owner: msbadmin
--

ALTER TABLE ONLY ops.lor_reconciliation_stage_candidate
    ADD CONSTRAINT lor_reconciliation_stage_candidate_stage_key_stage_id_fkey FOREIGN KEY (stage_key_stage_id) REFERENCES ref.stage(stage_id);


--
-- TOC entry 5695 (class 2606 OID 18742)
-- Name: display_test_session ops_display_test_session_display_id_fk; Type: FK CONSTRAINT; Schema: ops; Owner: msbadmin
--

ALTER TABLE ONLY ops.display_test_session
    ADD CONSTRAINT ops_display_test_session_display_id_fk FOREIGN KEY (display_id) REFERENCES ref.display(display_id);


--
-- TOC entry 5733 (class 2606 OID 17959)
-- Name: directus_access directus_access_policy_foreign; Type: FK CONSTRAINT; Schema: public; Owner: directus_app
--

ALTER TABLE ONLY public.directus_access
    ADD CONSTRAINT directus_access_policy_foreign FOREIGN KEY (policy) REFERENCES public.directus_policies(id) ON DELETE CASCADE;


--
-- TOC entry 5734 (class 2606 OID 17949)
-- Name: directus_access directus_access_role_foreign; Type: FK CONSTRAINT; Schema: public; Owner: directus_app
--

ALTER TABLE ONLY public.directus_access
    ADD CONSTRAINT directus_access_role_foreign FOREIGN KEY (role) REFERENCES public.directus_roles(id) ON DELETE CASCADE;


--
-- TOC entry 5735 (class 2606 OID 17954)
-- Name: directus_access directus_access_user_foreign; Type: FK CONSTRAINT; Schema: public; Owner: directus_app
--

ALTER TABLE ONLY public.directus_access
    ADD CONSTRAINT directus_access_user_foreign FOREIGN KEY ("user") REFERENCES public.directus_users(id) ON DELETE CASCADE;


--
-- TOC entry 5696 (class 2606 OID 17743)
-- Name: directus_collections directus_collections_group_foreign; Type: FK CONSTRAINT; Schema: public; Owner: directus_app
--

ALTER TABLE ONLY public.directus_collections
    ADD CONSTRAINT directus_collections_group_foreign FOREIGN KEY ("group") REFERENCES public.directus_collections(collection);


--
-- TOC entry 5736 (class 2606 OID 17977)
-- Name: directus_comments directus_comments_user_created_foreign; Type: FK CONSTRAINT; Schema: public; Owner: directus_app
--

ALTER TABLE ONLY public.directus_comments
    ADD CONSTRAINT directus_comments_user_created_foreign FOREIGN KEY (user_created) REFERENCES public.directus_users(id) ON DELETE SET NULL;


--
-- TOC entry 5737 (class 2606 OID 17982)
-- Name: directus_comments directus_comments_user_updated_foreign; Type: FK CONSTRAINT; Schema: public; Owner: directus_app
--

ALTER TABLE ONLY public.directus_comments
    ADD CONSTRAINT directus_comments_user_updated_foreign FOREIGN KEY (user_updated) REFERENCES public.directus_users(id);


--
-- TOC entry 5717 (class 2606 OID 17700)
-- Name: directus_dashboards directus_dashboards_user_created_foreign; Type: FK CONSTRAINT; Schema: public; Owner: directus_app
--

ALTER TABLE ONLY public.directus_dashboards
    ADD CONSTRAINT directus_dashboards_user_created_foreign FOREIGN KEY (user_created) REFERENCES public.directus_users(id) ON DELETE SET NULL;


--
-- TOC entry 5739 (class 2606 OID 18021)
-- Name: directus_deployment_projects directus_deployment_projects_deployment_foreign; Type: FK CONSTRAINT; Schema: public; Owner: directus_app
--

ALTER TABLE ONLY public.directus_deployment_projects
    ADD CONSTRAINT directus_deployment_projects_deployment_foreign FOREIGN KEY (deployment) REFERENCES public.directus_deployments(id) ON DELETE CASCADE;


--
-- TOC entry 5740 (class 2606 OID 18026)
-- Name: directus_deployment_projects directus_deployment_projects_user_created_foreign; Type: FK CONSTRAINT; Schema: public; Owner: directus_app
--

ALTER TABLE ONLY public.directus_deployment_projects
    ADD CONSTRAINT directus_deployment_projects_user_created_foreign FOREIGN KEY (user_created) REFERENCES public.directus_users(id) ON DELETE SET NULL;


--
-- TOC entry 5741 (class 2606 OID 18041)
-- Name: directus_deployment_runs directus_deployment_runs_project_foreign; Type: FK CONSTRAINT; Schema: public; Owner: directus_app
--

ALTER TABLE ONLY public.directus_deployment_runs
    ADD CONSTRAINT directus_deployment_runs_project_foreign FOREIGN KEY (project) REFERENCES public.directus_deployment_projects(id) ON DELETE CASCADE;


--
-- TOC entry 5742 (class 2606 OID 18046)
-- Name: directus_deployment_runs directus_deployment_runs_user_created_foreign; Type: FK CONSTRAINT; Schema: public; Owner: directus_app
--

ALTER TABLE ONLY public.directus_deployment_runs
    ADD CONSTRAINT directus_deployment_runs_user_created_foreign FOREIGN KEY (user_created) REFERENCES public.directus_users(id) ON DELETE SET NULL;


--
-- TOC entry 5738 (class 2606 OID 18008)
-- Name: directus_deployments directus_deployments_user_created_foreign; Type: FK CONSTRAINT; Schema: public; Owner: directus_app
--

ALTER TABLE ONLY public.directus_deployments
    ADD CONSTRAINT directus_deployments_user_created_foreign FOREIGN KEY (user_created) REFERENCES public.directus_users(id) ON DELETE SET NULL;


--
-- TOC entry 5700 (class 2606 OID 17656)
-- Name: directus_files directus_files_folder_foreign; Type: FK CONSTRAINT; Schema: public; Owner: directus_app
--

ALTER TABLE ONLY public.directus_files
    ADD CONSTRAINT directus_files_folder_foreign FOREIGN KEY (folder) REFERENCES public.directus_folders(id) ON DELETE SET NULL;


--
-- TOC entry 5701 (class 2606 OID 17593)
-- Name: directus_files directus_files_modified_by_foreign; Type: FK CONSTRAINT; Schema: public; Owner: directus_app
--

ALTER TABLE ONLY public.directus_files
    ADD CONSTRAINT directus_files_modified_by_foreign FOREIGN KEY (modified_by) REFERENCES public.directus_users(id);


--
-- TOC entry 5702 (class 2606 OID 17588)
-- Name: directus_files directus_files_uploaded_by_foreign; Type: FK CONSTRAINT; Schema: public; Owner: directus_app
--

ALTER TABLE ONLY public.directus_files
    ADD CONSTRAINT directus_files_uploaded_by_foreign FOREIGN KEY (uploaded_by) REFERENCES public.directus_users(id);


--
-- TOC entry 5725 (class 2606 OID 17817)
-- Name: directus_flows directus_flows_user_created_foreign; Type: FK CONSTRAINT; Schema: public; Owner: directus_app
--

ALTER TABLE ONLY public.directus_flows
    ADD CONSTRAINT directus_flows_user_created_foreign FOREIGN KEY (user_created) REFERENCES public.directus_users(id) ON DELETE SET NULL;


--
-- TOC entry 5699 (class 2606 OID 17598)
-- Name: directus_folders directus_folders_parent_foreign; Type: FK CONSTRAINT; Schema: public; Owner: directus_app
--

ALTER TABLE ONLY public.directus_folders
    ADD CONSTRAINT directus_folders_parent_foreign FOREIGN KEY (parent) REFERENCES public.directus_folders(id);


--
-- TOC entry 5720 (class 2606 OID 17760)
-- Name: directus_notifications directus_notifications_recipient_foreign; Type: FK CONSTRAINT; Schema: public; Owner: directus_app
--

ALTER TABLE ONLY public.directus_notifications
    ADD CONSTRAINT directus_notifications_recipient_foreign FOREIGN KEY (recipient) REFERENCES public.directus_users(id) ON DELETE CASCADE;


--
-- TOC entry 5721 (class 2606 OID 17765)
-- Name: directus_notifications directus_notifications_sender_foreign; Type: FK CONSTRAINT; Schema: public; Owner: directus_app
--

ALTER TABLE ONLY public.directus_notifications
    ADD CONSTRAINT directus_notifications_sender_foreign FOREIGN KEY (sender) REFERENCES public.directus_users(id);


--
-- TOC entry 5726 (class 2606 OID 17844)
-- Name: directus_operations directus_operations_flow_foreign; Type: FK CONSTRAINT; Schema: public; Owner: directus_app
--

ALTER TABLE ONLY public.directus_operations
    ADD CONSTRAINT directus_operations_flow_foreign FOREIGN KEY (flow) REFERENCES public.directus_flows(id) ON DELETE CASCADE;


--
-- TOC entry 5727 (class 2606 OID 17839)
-- Name: directus_operations directus_operations_reject_foreign; Type: FK CONSTRAINT; Schema: public; Owner: directus_app
--

ALTER TABLE ONLY public.directus_operations
    ADD CONSTRAINT directus_operations_reject_foreign FOREIGN KEY (reject) REFERENCES public.directus_operations(id);


--
-- TOC entry 5728 (class 2606 OID 17832)
-- Name: directus_operations directus_operations_resolve_foreign; Type: FK CONSTRAINT; Schema: public; Owner: directus_app
--

ALTER TABLE ONLY public.directus_operations
    ADD CONSTRAINT directus_operations_resolve_foreign FOREIGN KEY (resolve) REFERENCES public.directus_operations(id);


--
-- TOC entry 5729 (class 2606 OID 17849)
-- Name: directus_operations directus_operations_user_created_foreign; Type: FK CONSTRAINT; Schema: public; Owner: directus_app
--

ALTER TABLE ONLY public.directus_operations
    ADD CONSTRAINT directus_operations_user_created_foreign FOREIGN KEY (user_created) REFERENCES public.directus_users(id) ON DELETE SET NULL;


--
-- TOC entry 5718 (class 2606 OID 17715)
-- Name: directus_panels directus_panels_dashboard_foreign; Type: FK CONSTRAINT; Schema: public; Owner: directus_app
--

ALTER TABLE ONLY public.directus_panels
    ADD CONSTRAINT directus_panels_dashboard_foreign FOREIGN KEY (dashboard) REFERENCES public.directus_dashboards(id) ON DELETE CASCADE;


--
-- TOC entry 5719 (class 2606 OID 17720)
-- Name: directus_panels directus_panels_user_created_foreign; Type: FK CONSTRAINT; Schema: public; Owner: directus_app
--

ALTER TABLE ONLY public.directus_panels
    ADD CONSTRAINT directus_panels_user_created_foreign FOREIGN KEY (user_created) REFERENCES public.directus_users(id) ON DELETE SET NULL;


--
-- TOC entry 5703 (class 2606 OID 17939)
-- Name: directus_permissions directus_permissions_policy_foreign; Type: FK CONSTRAINT; Schema: public; Owner: directus_app
--

ALTER TABLE ONLY public.directus_permissions
    ADD CONSTRAINT directus_permissions_policy_foreign FOREIGN KEY (policy) REFERENCES public.directus_policies(id) ON DELETE CASCADE;


--
-- TOC entry 5704 (class 2606 OID 17671)
-- Name: directus_presets directus_presets_role_foreign; Type: FK CONSTRAINT; Schema: public; Owner: directus_app
--

ALTER TABLE ONLY public.directus_presets
    ADD CONSTRAINT directus_presets_role_foreign FOREIGN KEY (role) REFERENCES public.directus_roles(id) ON DELETE CASCADE;


--
-- TOC entry 5705 (class 2606 OID 17666)
-- Name: directus_presets directus_presets_user_foreign; Type: FK CONSTRAINT; Schema: public; Owner: directus_app
--

ALTER TABLE ONLY public.directus_presets
    ADD CONSTRAINT directus_presets_user_foreign FOREIGN KEY ("user") REFERENCES public.directus_users(id) ON DELETE CASCADE;


--
-- TOC entry 5706 (class 2606 OID 17676)
-- Name: directus_revisions directus_revisions_activity_foreign; Type: FK CONSTRAINT; Schema: public; Owner: directus_app
--

ALTER TABLE ONLY public.directus_revisions
    ADD CONSTRAINT directus_revisions_activity_foreign FOREIGN KEY (activity) REFERENCES public.directus_activity(id) ON DELETE CASCADE;


--
-- TOC entry 5707 (class 2606 OID 17623)
-- Name: directus_revisions directus_revisions_parent_foreign; Type: FK CONSTRAINT; Schema: public; Owner: directus_app
--

ALTER TABLE ONLY public.directus_revisions
    ADD CONSTRAINT directus_revisions_parent_foreign FOREIGN KEY (parent) REFERENCES public.directus_revisions(id);


--
-- TOC entry 5708 (class 2606 OID 17888)
-- Name: directus_revisions directus_revisions_version_foreign; Type: FK CONSTRAINT; Schema: public; Owner: directus_app
--

ALTER TABLE ONLY public.directus_revisions
    ADD CONSTRAINT directus_revisions_version_foreign FOREIGN KEY (version) REFERENCES public.directus_versions(id) ON DELETE CASCADE;


--
-- TOC entry 5697 (class 2606 OID 17934)
-- Name: directus_roles directus_roles_parent_foreign; Type: FK CONSTRAINT; Schema: public; Owner: directus_app
--

ALTER TABLE ONLY public.directus_roles
    ADD CONSTRAINT directus_roles_parent_foreign FOREIGN KEY (parent) REFERENCES public.directus_roles(id);


--
-- TOC entry 5709 (class 2606 OID 17795)
-- Name: directus_sessions directus_sessions_share_foreign; Type: FK CONSTRAINT; Schema: public; Owner: directus_app
--

ALTER TABLE ONLY public.directus_sessions
    ADD CONSTRAINT directus_sessions_share_foreign FOREIGN KEY (share) REFERENCES public.directus_shares(id) ON DELETE CASCADE;


--
-- TOC entry 5710 (class 2606 OID 17681)
-- Name: directus_sessions directus_sessions_user_foreign; Type: FK CONSTRAINT; Schema: public; Owner: directus_app
--

ALTER TABLE ONLY public.directus_sessions
    ADD CONSTRAINT directus_sessions_user_foreign FOREIGN KEY ("user") REFERENCES public.directus_users(id) ON DELETE CASCADE;


--
-- TOC entry 5711 (class 2606 OID 17633)
-- Name: directus_settings directus_settings_project_logo_foreign; Type: FK CONSTRAINT; Schema: public; Owner: directus_app
--

ALTER TABLE ONLY public.directus_settings
    ADD CONSTRAINT directus_settings_project_logo_foreign FOREIGN KEY (project_logo) REFERENCES public.directus_files(id);


--
-- TOC entry 5712 (class 2606 OID 17643)
-- Name: directus_settings directus_settings_public_background_foreign; Type: FK CONSTRAINT; Schema: public; Owner: directus_app
--

ALTER TABLE ONLY public.directus_settings
    ADD CONSTRAINT directus_settings_public_background_foreign FOREIGN KEY (public_background) REFERENCES public.directus_files(id);


--
-- TOC entry 5713 (class 2606 OID 17895)
-- Name: directus_settings directus_settings_public_favicon_foreign; Type: FK CONSTRAINT; Schema: public; Owner: directus_app
--

ALTER TABLE ONLY public.directus_settings
    ADD CONSTRAINT directus_settings_public_favicon_foreign FOREIGN KEY (public_favicon) REFERENCES public.directus_files(id);


--
-- TOC entry 5714 (class 2606 OID 17638)
-- Name: directus_settings directus_settings_public_foreground_foreign; Type: FK CONSTRAINT; Schema: public; Owner: directus_app
--

ALTER TABLE ONLY public.directus_settings
    ADD CONSTRAINT directus_settings_public_foreground_foreign FOREIGN KEY (public_foreground) REFERENCES public.directus_files(id);


--
-- TOC entry 5715 (class 2606 OID 17918)
-- Name: directus_settings directus_settings_public_registration_role_foreign; Type: FK CONSTRAINT; Schema: public; Owner: directus_app
--

ALTER TABLE ONLY public.directus_settings
    ADD CONSTRAINT directus_settings_public_registration_role_foreign FOREIGN KEY (public_registration_role) REFERENCES public.directus_roles(id) ON DELETE SET NULL;


--
-- TOC entry 5716 (class 2606 OID 17731)
-- Name: directus_settings directus_settings_storage_default_folder_foreign; Type: FK CONSTRAINT; Schema: public; Owner: directus_app
--

ALTER TABLE ONLY public.directus_settings
    ADD CONSTRAINT directus_settings_storage_default_folder_foreign FOREIGN KEY (storage_default_folder) REFERENCES public.directus_folders(id) ON DELETE SET NULL;


--
-- TOC entry 5722 (class 2606 OID 17780)
-- Name: directus_shares directus_shares_collection_foreign; Type: FK CONSTRAINT; Schema: public; Owner: directus_app
--

ALTER TABLE ONLY public.directus_shares
    ADD CONSTRAINT directus_shares_collection_foreign FOREIGN KEY (collection) REFERENCES public.directus_collections(collection) ON DELETE CASCADE;


--
-- TOC entry 5723 (class 2606 OID 17785)
-- Name: directus_shares directus_shares_role_foreign; Type: FK CONSTRAINT; Schema: public; Owner: directus_app
--

ALTER TABLE ONLY public.directus_shares
    ADD CONSTRAINT directus_shares_role_foreign FOREIGN KEY (role) REFERENCES public.directus_roles(id) ON DELETE CASCADE;


--
-- TOC entry 5724 (class 2606 OID 17790)
-- Name: directus_shares directus_shares_user_created_foreign; Type: FK CONSTRAINT; Schema: public; Owner: directus_app
--

ALTER TABLE ONLY public.directus_shares
    ADD CONSTRAINT directus_shares_user_created_foreign FOREIGN KEY (user_created) REFERENCES public.directus_users(id) ON DELETE SET NULL;


--
-- TOC entry 5698 (class 2606 OID 17686)
-- Name: directus_users directus_users_role_foreign; Type: FK CONSTRAINT; Schema: public; Owner: directus_app
--

ALTER TABLE ONLY public.directus_users
    ADD CONSTRAINT directus_users_role_foreign FOREIGN KEY (role) REFERENCES public.directus_roles(id) ON DELETE SET NULL;


--
-- TOC entry 5730 (class 2606 OID 17872)
-- Name: directus_versions directus_versions_collection_foreign; Type: FK CONSTRAINT; Schema: public; Owner: directus_app
--

ALTER TABLE ONLY public.directus_versions
    ADD CONSTRAINT directus_versions_collection_foreign FOREIGN KEY (collection) REFERENCES public.directus_collections(collection) ON DELETE CASCADE;


--
-- TOC entry 5731 (class 2606 OID 17877)
-- Name: directus_versions directus_versions_user_created_foreign; Type: FK CONSTRAINT; Schema: public; Owner: directus_app
--

ALTER TABLE ONLY public.directus_versions
    ADD CONSTRAINT directus_versions_user_created_foreign FOREIGN KEY (user_created) REFERENCES public.directus_users(id) ON DELETE SET NULL;


--
-- TOC entry 5732 (class 2606 OID 17882)
-- Name: directus_versions directus_versions_user_updated_foreign; Type: FK CONSTRAINT; Schema: public; Owner: directus_app
--

ALTER TABLE ONLY public.directus_versions
    ADD CONSTRAINT directus_versions_user_updated_foreign FOREIGN KEY (user_updated) REFERENCES public.directus_users(id);


--
-- TOC entry 5790 (class 2606 OID 19227)
-- Name: audit_collection_policy fk_audit_collection_policy_created_by_person; Type: FK CONSTRAINT; Schema: ref; Owner: msbadmin
--

ALTER TABLE ONLY ref.audit_collection_policy
    ADD CONSTRAINT fk_audit_collection_policy_created_by_person FOREIGN KEY (created_by_person_id) REFERENCES ref.person(person_id);


--
-- TOC entry 5791 (class 2606 OID 19232)
-- Name: audit_collection_policy fk_audit_collection_policy_updated_by_person; Type: FK CONSTRAINT; Schema: ref; Owner: msbadmin
--

ALTER TABLE ONLY ref.audit_collection_policy
    ADD CONSTRAINT fk_audit_collection_policy_updated_by_person FOREIGN KEY (updated_by_person_id) REFERENCES ref.person(person_id);


--
-- TOC entry 5655 (class 2606 OID 19324)
-- Name: container fk_container_created_by_person; Type: FK CONSTRAINT; Schema: ref; Owner: msbadmin
--

ALTER TABLE ONLY ref.container
    ADD CONSTRAINT fk_container_created_by_person FOREIGN KEY (created_by_person_id) REFERENCES ref.person(person_id);


--
-- TOC entry 5745 (class 2606 OID 19242)
-- Name: container_endpoint fk_container_endpoint_created_by_person; Type: FK CONSTRAINT; Schema: ref; Owner: msbadmin
--

ALTER TABLE ONLY ref.container_endpoint
    ADD CONSTRAINT fk_container_endpoint_created_by_person FOREIGN KEY (created_by_person_id) REFERENCES ref.person(person_id);


--
-- TOC entry 5746 (class 2606 OID 19237)
-- Name: container_endpoint fk_container_endpoint_updated_by_person; Type: FK CONSTRAINT; Schema: ref; Owner: msbadmin
--

ALTER TABLE ONLY ref.container_endpoint
    ADD CONSTRAINT fk_container_endpoint_updated_by_person FOREIGN KEY (updated_by_person_id) REFERENCES ref.person(person_id);


--
-- TOC entry 5656 (class 2606 OID 18915)
-- Name: container fk_container_goes_to_endpoint; Type: FK CONSTRAINT; Schema: ref; Owner: msbadmin
--

ALTER TABLE ONLY ref.container
    ADD CONSTRAINT fk_container_goes_to_endpoint FOREIGN KEY (goes_to_endpoint_id) REFERENCES ref.container_endpoint(endpoint_id);


--
-- TOC entry 5657 (class 2606 OID 21095)
-- Name: container fk_container_label_print_last_by_cached_person; Type: FK CONSTRAINT; Schema: ref; Owner: msbadmin
--

ALTER TABLE ONLY ref.container
    ADD CONSTRAINT fk_container_label_print_last_by_cached_person FOREIGN KEY (label_print_last_by_cached_id) REFERENCES ref.person(person_id) ON UPDATE CASCADE ON DELETE SET NULL;


--
-- TOC entry 5653 (class 2606 OID 19334)
-- Name: container_type fk_container_type_created_by_person; Type: FK CONSTRAINT; Schema: ref; Owner: msbadmin
--

ALTER TABLE ONLY ref.container_type
    ADD CONSTRAINT fk_container_type_created_by_person FOREIGN KEY (created_by_person_id) REFERENCES ref.person(person_id);


--
-- TOC entry 5654 (class 2606 OID 19339)
-- Name: container_type fk_container_type_updated_by_person; Type: FK CONSTRAINT; Schema: ref; Owner: msbadmin
--

ALTER TABLE ONLY ref.container_type
    ADD CONSTRAINT fk_container_type_updated_by_person FOREIGN KEY (updated_by_person_id) REFERENCES ref.person(person_id);


--
-- TOC entry 5658 (class 2606 OID 19329)
-- Name: container fk_container_updated_by_person; Type: FK CONSTRAINT; Schema: ref; Owner: msbadmin
--

ALTER TABLE ONLY ref.container
    ADD CONSTRAINT fk_container_updated_by_person FOREIGN KEY (updated_by_person_id) REFERENCES ref.person(person_id);


--
-- TOC entry 5670 (class 2606 OID 19344)
-- Name: display fk_display_created_by_person; Type: FK CONSTRAINT; Schema: ref; Owner: msbadmin
--

ALTER TABLE ONLY ref.display
    ADD CONSTRAINT fk_display_created_by_person FOREIGN KEY (created_by_person_id) REFERENCES ref.person(person_id);


--
-- TOC entry 5671 (class 2606 OID 17204)
-- Name: display fk_display_designer; Type: FK CONSTRAINT; Schema: ref; Owner: msbadmin
--

ALTER TABLE ONLY ref.display
    ADD CONSTRAINT fk_display_designer FOREIGN KEY (designer_id) REFERENCES ref.person(person_id) ON DELETE SET NULL;


--
-- TOC entry 5672 (class 2606 OID 17199)
-- Name: display fk_display_frame; Type: FK CONSTRAINT; Schema: ref; Owner: msbadmin
--

ALTER TABLE ONLY ref.display
    ADD CONSTRAINT fk_display_frame FOREIGN KEY (frame_id) REFERENCES ref.frame(frame_id);


--
-- TOC entry 5673 (class 2606 OID 17062)
-- Name: display fk_display_inventory_type; Type: FK CONSTRAINT; Schema: ref; Owner: msbadmin
--

ALTER TABLE ONLY ref.display
    ADD CONSTRAINT fk_display_inventory_type FOREIGN KEY (inventory_type) REFERENCES ref.inventory_type(inventory_type);


--
-- TOC entry 5674 (class 2606 OID 21090)
-- Name: display fk_display_label_print_last_by_cached_person; Type: FK CONSTRAINT; Schema: ref; Owner: msbadmin
--

ALTER TABLE ONLY ref.display
    ADD CONSTRAINT fk_display_label_print_last_by_cached_person FOREIGN KEY (label_print_last_by_cached_id) REFERENCES ref.person(person_id) ON UPDATE CASCADE ON DELETE SET NULL;


--
-- TOC entry 5675 (class 2606 OID 17077)
-- Name: display fk_display_pallet; Type: FK CONSTRAINT; Schema: ref; Owner: msbadmin
--

ALTER TABLE ONLY ref.display
    ADD CONSTRAINT fk_display_pallet FOREIGN KEY (container_id) REFERENCES ref.container(container_id);


--
-- TOC entry 5676 (class 2606 OID 17067)
-- Name: display fk_display_status; Type: FK CONSTRAINT; Schema: ref; Owner: msbadmin
--

ALTER TABLE ONLY ref.display
    ADD CONSTRAINT fk_display_status FOREIGN KEY (display_status_id) REFERENCES ref.display_status(display_status_id);


--
-- TOC entry 5651 (class 2606 OID 19354)
-- Name: display_status fk_display_status_created_by_person; Type: FK CONSTRAINT; Schema: ref; Owner: msbadmin
--

ALTER TABLE ONLY ref.display_status
    ADD CONSTRAINT fk_display_status_created_by_person FOREIGN KEY (created_by_person_id) REFERENCES ref.person(person_id);


--
-- TOC entry 5652 (class 2606 OID 19359)
-- Name: display_status fk_display_status_updated_by_person; Type: FK CONSTRAINT; Schema: ref; Owner: msbadmin
--

ALTER TABLE ONLY ref.display_status
    ADD CONSTRAINT fk_display_status_updated_by_person FOREIGN KEY (updated_by_person_id) REFERENCES ref.person(person_id);


--
-- TOC entry 5764 (class 2606 OID 19364)
-- Name: display_test_status fk_display_test_status_created_by_person; Type: FK CONSTRAINT; Schema: ref; Owner: msbadmin
--

ALTER TABLE ONLY ref.display_test_status
    ADD CONSTRAINT fk_display_test_status_created_by_person FOREIGN KEY (created_by_person_id) REFERENCES ref.person(person_id);


--
-- TOC entry 5765 (class 2606 OID 19369)
-- Name: display_test_status fk_display_test_status_updated_by_person; Type: FK CONSTRAINT; Schema: ref; Owner: msbadmin
--

ALTER TABLE ONLY ref.display_test_status
    ADD CONSTRAINT fk_display_test_status_updated_by_person FOREIGN KEY (updated_by_person_id) REFERENCES ref.person(person_id);


--
-- TOC entry 5677 (class 2606 OID 17194)
-- Name: display fk_display_theme; Type: FK CONSTRAINT; Schema: ref; Owner: msbadmin
--

ALTER TABLE ONLY ref.display
    ADD CONSTRAINT fk_display_theme FOREIGN KEY (theme_id) REFERENCES ref.theme(theme_id);


--
-- TOC entry 5678 (class 2606 OID 19349)
-- Name: display fk_display_updated_by_person; Type: FK CONSTRAINT; Schema: ref; Owner: msbadmin
--

ALTER TABLE ONLY ref.display
    ADD CONSTRAINT fk_display_updated_by_person FOREIGN KEY (updated_by_person_id) REFERENCES ref.person(person_id);


--
-- TOC entry 5647 (class 2606 OID 19374)
-- Name: frame fk_frame_created_by_person; Type: FK CONSTRAINT; Schema: ref; Owner: msbadmin
--

ALTER TABLE ONLY ref.frame
    ADD CONSTRAINT fk_frame_created_by_person FOREIGN KEY (created_by_person_id) REFERENCES ref.person(person_id);


--
-- TOC entry 5648 (class 2606 OID 19379)
-- Name: frame fk_frame_updated_by_person; Type: FK CONSTRAINT; Schema: ref; Owner: msbadmin
--

ALTER TABLE ONLY ref.frame
    ADD CONSTRAINT fk_frame_updated_by_person FOREIGN KEY (updated_by_person_id) REFERENCES ref.person(person_id);


--
-- TOC entry 5668 (class 2606 OID 19384)
-- Name: inventory_type fk_inventory_type_created_by_person; Type: FK CONSTRAINT; Schema: ref; Owner: msbadmin
--

ALTER TABLE ONLY ref.inventory_type
    ADD CONSTRAINT fk_inventory_type_created_by_person FOREIGN KEY (created_by_person_id) REFERENCES ref.person(person_id);


--
-- TOC entry 5669 (class 2606 OID 19389)
-- Name: inventory_type fk_inventory_type_updated_by_person; Type: FK CONSTRAINT; Schema: ref; Owner: msbadmin
--

ALTER TABLE ONLY ref.inventory_type
    ADD CONSTRAINT fk_inventory_type_updated_by_person FOREIGN KEY (updated_by_person_id) REFERENCES ref.person(person_id);


--
-- TOC entry 5814 (class 2606 OID 23269)
-- Name: lor_scene_display fk_lor_scene_display_display; Type: FK CONSTRAINT; Schema: ref; Owner: msbadmin
--

ALTER TABLE ONLY ref.lor_scene_display
    ADD CONSTRAINT fk_lor_scene_display_display FOREIGN KEY (display_id) REFERENCES ref.display(display_id);


--
-- TOC entry 5815 (class 2606 OID 23274)
-- Name: lor_scene_display fk_lor_scene_display_import_run; Type: FK CONSTRAINT; Schema: ref; Owner: msbadmin
--

ALTER TABLE ONLY ref.lor_scene_display
    ADD CONSTRAINT fk_lor_scene_display_import_run FOREIGN KEY (source_import_run_id) REFERENCES lor_snap.import_run(import_run_id);


--
-- TOC entry 5816 (class 2606 OID 23264)
-- Name: lor_scene_display fk_lor_scene_display_scene; Type: FK CONSTRAINT; Schema: ref; Owner: msbadmin
--

ALTER TABLE ONLY ref.lor_scene_display
    ADD CONSTRAINT fk_lor_scene_display_scene FOREIGN KEY (lor_scene_id, preview_uuid) REFERENCES ref.lor_scene(lor_scene_id, preview_uuid) ON DELETE CASCADE;


--
-- TOC entry 5812 (class 2606 OID 23246)
-- Name: lor_scene fk_lor_scene_import_run; Type: FK CONSTRAINT; Schema: ref; Owner: msbadmin
--

ALTER TABLE ONLY ref.lor_scene
    ADD CONSTRAINT fk_lor_scene_import_run FOREIGN KEY (source_import_run_id) REFERENCES lor_snap.import_run(import_run_id);


--
-- TOC entry 5813 (class 2606 OID 23241)
-- Name: lor_scene fk_lor_scene_stage; Type: FK CONSTRAINT; Schema: ref; Owner: msbadmin
--

ALTER TABLE ONLY ref.lor_scene
    ADD CONSTRAINT fk_lor_scene_stage FOREIGN KEY (stage_id) REFERENCES ref.stage(stage_id);


--
-- TOC entry 5659 (class 2606 OID 18316)
-- Name: container fk_pallet_location; Type: FK CONSTRAINT; Schema: ref; Owner: msbadmin
--

ALTER TABLE ONLY ref.container
    ADD CONSTRAINT fk_pallet_location FOREIGN KEY (location_code) REFERENCES ref.storage_location(location_code);


--
-- TOC entry 5663 (class 2606 OID 19394)
-- Name: person fk_person_created_by_person; Type: FK CONSTRAINT; Schema: ref; Owner: msbadmin
--

ALTER TABLE ONLY ref.person
    ADD CONSTRAINT fk_person_created_by_person FOREIGN KEY (created_by_person_id) REFERENCES ref.person(person_id);


--
-- TOC entry 5664 (class 2606 OID 19399)
-- Name: person fk_person_updated_by_person; Type: FK CONSTRAINT; Schema: ref; Owner: msbadmin
--

ALTER TABLE ONLY ref.person
    ADD CONSTRAINT fk_person_updated_by_person FOREIGN KEY (updated_by_person_id) REFERENCES ref.person(person_id);


--
-- TOC entry 5665 (class 2606 OID 19404)
-- Name: person_xref fk_person_xref_created_by_person; Type: FK CONSTRAINT; Schema: ref; Owner: msbadmin
--

ALTER TABLE ONLY ref.person_xref
    ADD CONSTRAINT fk_person_xref_created_by_person FOREIGN KEY (created_by_person_id) REFERENCES ref.person(person_id);


--
-- TOC entry 5666 (class 2606 OID 19409)
-- Name: person_xref fk_person_xref_updated_by_person; Type: FK CONSTRAINT; Schema: ref; Owner: msbadmin
--

ALTER TABLE ONLY ref.person_xref
    ADD CONSTRAINT fk_person_xref_updated_by_person FOREIGN KEY (updated_by_person_id) REFERENCES ref.person(person_id);


--
-- TOC entry 5762 (class 2606 OID 19414)
-- Name: spare_channel fk_spare_channel_created_by_person; Type: FK CONSTRAINT; Schema: ref; Owner: msbadmin
--

ALTER TABLE ONLY ref.spare_channel
    ADD CONSTRAINT fk_spare_channel_created_by_person FOREIGN KEY (created_by_person_id) REFERENCES ref.person(person_id);


--
-- TOC entry 5763 (class 2606 OID 19419)
-- Name: spare_channel fk_spare_channel_updated_by_person; Type: FK CONSTRAINT; Schema: ref; Owner: msbadmin
--

ALTER TABLE ONLY ref.spare_channel
    ADD CONSTRAINT fk_spare_channel_updated_by_person FOREIGN KEY (updated_by_person_id) REFERENCES ref.person(person_id);


--
-- TOC entry 5743 (class 2606 OID 19424)
-- Name: stage fk_stage_created_by_person; Type: FK CONSTRAINT; Schema: ref; Owner: msbadmin
--

ALTER TABLE ONLY ref.stage
    ADD CONSTRAINT fk_stage_created_by_person FOREIGN KEY (created_by_person_id) REFERENCES ref.person(person_id);


--
-- TOC entry 5744 (class 2606 OID 19429)
-- Name: stage fk_stage_updated_by_person; Type: FK CONSTRAINT; Schema: ref; Owner: msbadmin
--

ALTER TABLE ONLY ref.stage
    ADD CONSTRAINT fk_stage_updated_by_person FOREIGN KEY (updated_by_person_id) REFERENCES ref.person(person_id);


--
-- TOC entry 5661 (class 2606 OID 19434)
-- Name: storage_location fk_storage_location_created_by_person; Type: FK CONSTRAINT; Schema: ref; Owner: msbadmin
--

ALTER TABLE ONLY ref.storage_location
    ADD CONSTRAINT fk_storage_location_created_by_person FOREIGN KEY (created_by_person_id) REFERENCES ref.person(person_id);


--
-- TOC entry 5662 (class 2606 OID 19439)
-- Name: storage_location fk_storage_location_updated_by_person; Type: FK CONSTRAINT; Schema: ref; Owner: msbadmin
--

ALTER TABLE ONLY ref.storage_location
    ADD CONSTRAINT fk_storage_location_updated_by_person FOREIGN KEY (updated_by_person_id) REFERENCES ref.person(person_id);


--
-- TOC entry 5747 (class 2606 OID 19444)
-- Name: task_type fk_task_type_created_by_person; Type: FK CONSTRAINT; Schema: ref; Owner: msbadmin
--

ALTER TABLE ONLY ref.task_type
    ADD CONSTRAINT fk_task_type_created_by_person FOREIGN KEY (created_by_person_id) REFERENCES ref.person(person_id);


--
-- TOC entry 5748 (class 2606 OID 19449)
-- Name: task_type fk_task_type_updated_by_person; Type: FK CONSTRAINT; Schema: ref; Owner: msbadmin
--

ALTER TABLE ONLY ref.task_type
    ADD CONSTRAINT fk_task_type_updated_by_person FOREIGN KEY (updated_by_person_id) REFERENCES ref.person(person_id);


--
-- TOC entry 5649 (class 2606 OID 19454)
-- Name: theme fk_theme_created_by_person; Type: FK CONSTRAINT; Schema: ref; Owner: msbadmin
--

ALTER TABLE ONLY ref.theme
    ADD CONSTRAINT fk_theme_created_by_person FOREIGN KEY (created_by_person_id) REFERENCES ref.person(person_id);


--
-- TOC entry 5650 (class 2606 OID 19459)
-- Name: theme fk_theme_updated_by_person; Type: FK CONSTRAINT; Schema: ref; Owner: msbadmin
--

ALTER TABLE ONLY ref.theme
    ADD CONSTRAINT fk_theme_updated_by_person FOREIGN KEY (updated_by_person_id) REFERENCES ref.person(person_id);


--
-- TOC entry 5749 (class 2606 OID 19464)
-- Name: work_area fk_work_area_created_by_person; Type: FK CONSTRAINT; Schema: ref; Owner: msbadmin
--

ALTER TABLE ONLY ref.work_area
    ADD CONSTRAINT fk_work_area_created_by_person FOREIGN KEY (created_by_person_id) REFERENCES ref.person(person_id);


--
-- TOC entry 5750 (class 2606 OID 19469)
-- Name: work_area fk_work_area_updated_by_person; Type: FK CONSTRAINT; Schema: ref; Owner: msbadmin
--

ALTER TABLE ONLY ref.work_area
    ADD CONSTRAINT fk_work_area_updated_by_person FOREIGN KEY (updated_by_person_id) REFERENCES ref.person(person_id);


--
-- TOC entry 5766 (class 2606 OID 19474)
-- Name: work_order_status fk_work_order_status_created_by_person; Type: FK CONSTRAINT; Schema: ref; Owner: msbadmin
--

ALTER TABLE ONLY ref.work_order_status
    ADD CONSTRAINT fk_work_order_status_created_by_person FOREIGN KEY (created_by_person_id) REFERENCES ref.person(person_id);


--
-- TOC entry 5767 (class 2606 OID 19479)
-- Name: work_order_status fk_work_order_status_updated_by_person; Type: FK CONSTRAINT; Schema: ref; Owner: msbadmin
--

ALTER TABLE ONLY ref.work_order_status
    ADD CONSTRAINT fk_work_order_status_updated_by_person FOREIGN KEY (updated_by_person_id) REFERENCES ref.person(person_id);


--
-- TOC entry 5660 (class 2606 OID 16834)
-- Name: container pallet_pallet_type_id_fkey; Type: FK CONSTRAINT; Schema: ref; Owner: msbadmin
--

ALTER TABLE ONLY ref.container
    ADD CONSTRAINT pallet_pallet_type_id_fkey FOREIGN KEY (container_type_id) REFERENCES ref.container_type(container_type_id);


--
-- TOC entry 5667 (class 2606 OID 16980)
-- Name: person_xref person_xref_person_id_fkey; Type: FK CONSTRAINT; Schema: ref; Owner: msbadmin
--

ALTER TABLE ONLY ref.person_xref
    ADD CONSTRAINT person_xref_person_id_fkey FOREIGN KEY (person_id) REFERENCES ref.person(person_id);


--
-- TOC entry 5679 (class 2606 OID 18335)
-- Name: display ref_display_stage_id_fkey; Type: FK CONSTRAINT; Schema: ref; Owner: msbadmin
--

ALTER TABLE ONLY ref.display
    ADD CONSTRAINT ref_display_stage_id_fkey FOREIGN KEY (stage_id) REFERENCES ref.stage(stage_id) DEFERRABLE INITIALLY DEFERRED;


--
-- TOC entry 5828 (class 2606 OID 23606)
-- Name: stage_lor_binding stage_lor_binding_stage_id_fkey; Type: FK CONSTRAINT; Schema: ref; Owner: msbadmin
--

ALTER TABLE ONLY ref.stage_lor_binding
    ADD CONSTRAINT stage_lor_binding_stage_id_fkey FOREIGN KEY (stage_id) REFERENCES ref.stage(stage_id);


--
-- TOC entry 5768 (class 2606 OID 19943)
-- Name: work_order_intake fk_intake_triaged_by; Type: FK CONSTRAINT; Schema: stage; Owner: directus_app
--

ALTER TABLE ONLY stage.work_order_intake
    ADD CONSTRAINT fk_intake_triaged_by FOREIGN KEY (triaged_by_person_id) REFERENCES ref.person(person_id);


--
-- TOC entry 5769 (class 2606 OID 19987)
-- Name: work_order_intake fk_work_order_intake_created_by_person; Type: FK CONSTRAINT; Schema: stage; Owner: directus_app
--

ALTER TABLE ONLY stage.work_order_intake
    ADD CONSTRAINT fk_work_order_intake_created_by_person FOREIGN KEY (created_by_person_id) REFERENCES ref.person(person_id);


--
-- TOC entry 5770 (class 2606 OID 19634)
-- Name: work_order_intake fk_work_order_intake_stage; Type: FK CONSTRAINT; Schema: stage; Owner: directus_app
--

ALTER TABLE ONLY stage.work_order_intake
    ADD CONSTRAINT fk_work_order_intake_stage FOREIGN KEY (stage_id) REFERENCES ref.stage(stage_id);


--
-- TOC entry 5771 (class 2606 OID 19948)
-- Name: work_order_intake fk_work_order_intake_submitter_person; Type: FK CONSTRAINT; Schema: stage; Owner: directus_app
--

ALTER TABLE ONLY stage.work_order_intake
    ADD CONSTRAINT fk_work_order_intake_submitter_person FOREIGN KEY (submitter_person_id) REFERENCES ref.person(person_id);


--
-- TOC entry 5772 (class 2606 OID 19644)
-- Name: work_order_intake fk_work_order_intake_task_type; Type: FK CONSTRAINT; Schema: stage; Owner: directus_app
--

ALTER TABLE ONLY stage.work_order_intake
    ADD CONSTRAINT fk_work_order_intake_task_type FOREIGN KEY (task_type_id) REFERENCES ref.task_type(task_type_id);


--
-- TOC entry 5773 (class 2606 OID 19992)
-- Name: work_order_intake fk_work_order_intake_updated_by_person; Type: FK CONSTRAINT; Schema: stage; Owner: directus_app
--

ALTER TABLE ONLY stage.work_order_intake
    ADD CONSTRAINT fk_work_order_intake_updated_by_person FOREIGN KEY (updated_by_person_id) REFERENCES ref.person(person_id);


--
-- TOC entry 5774 (class 2606 OID 19649)
-- Name: work_order_intake fk_work_order_intake_urgency; Type: FK CONSTRAINT; Schema: stage; Owner: directus_app
--

ALTER TABLE ONLY stage.work_order_intake
    ADD CONSTRAINT fk_work_order_intake_urgency FOREIGN KEY (urgency_id) REFERENCES ref.urgency(urgency_id);


--
-- TOC entry 5775 (class 2606 OID 19639)
-- Name: work_order_intake fk_work_order_intake_work_area; Type: FK CONSTRAINT; Schema: stage; Owner: directus_app
--

ALTER TABLE ONLY stage.work_order_intake
    ADD CONSTRAINT fk_work_order_intake_work_area FOREIGN KEY (work_area_id) REFERENCES ref.work_area(work_area_id);


--
-- TOC entry 6112 (class 0 OID 0)
-- Dependencies: 16
-- Name: SCHEMA lor_snap; Type: ACL; Schema: -; Owner: msbadmin
--

GRANT USAGE ON SCHEMA lor_snap TO directus_app;
GRANT USAGE ON SCHEMA lor_snap TO lor_preflight_app;


--
-- TOC entry 6114 (class 0 OID 0)
-- Dependencies: 43
-- Name: SCHEMA ops; Type: ACL; Schema: -; Owner: msbadmin
--

GRANT USAGE ON SCHEMA ops TO directus_app;
GRANT USAGE ON SCHEMA ops TO printservice;
GRANT USAGE ON SCHEMA ops TO lor_preflight_app;


--
-- TOC entry 6116 (class 0 OID 0)
-- Dependencies: 14
-- Name: SCHEMA public; Type: ACL; Schema: -; Owner: pg_database_owner
--

GRANT ALL ON SCHEMA public TO directus_app;


--
-- TOC entry 6118 (class 0 OID 0)
-- Dependencies: 44
-- Name: SCHEMA ref; Type: ACL; Schema: -; Owner: msbadmin
--

GRANT USAGE ON SCHEMA ref TO directus_app;
GRANT USAGE ON SCHEMA ref TO printservice;
GRANT USAGE ON SCHEMA ref TO lor_preflight_app;


--
-- TOC entry 6119 (class 0 OID 0)
-- Dependencies: 18
-- Name: SCHEMA stage; Type: ACL; Schema: -; Owner: msbadmin
--

GRANT USAGE ON SCHEMA stage TO directus_app;


--
-- TOC entry 6120 (class 0 OID 0)
-- Dependencies: 834
-- Name: FUNCTION _yn_to_bool(p_text text); Type: ACL; Schema: ops; Owner: msbadmin
--

GRANT ALL ON FUNCTION ops._yn_to_bool(p_text text) TO directus_app;


--
-- TOC entry 6121 (class 0 OID 0)
-- Dependencies: 1149
-- Name: FUNCTION display_test_session_set_checked_fields(); Type: ACL; Schema: ops; Owner: msbadmin
--

GRANT ALL ON FUNCTION ops.display_test_session_set_checked_fields() TO directus_app;


--
-- TOC entry 6123 (class 0 OID 0)
-- Dependencies: 734
-- Name: FUNCTION f_build_lor_reconciliation_scene_candidates(p_lor_reconciliation_run_id bigint); Type: ACL; Schema: ops; Owner: msbadmin
--

REVOKE ALL ON FUNCTION ops.f_build_lor_reconciliation_scene_candidates(p_lor_reconciliation_run_id bigint) FROM PUBLIC;
GRANT ALL ON FUNCTION ops.f_build_lor_reconciliation_scene_candidates(p_lor_reconciliation_run_id bigint) TO directus_app;


--
-- TOC entry 6125 (class 0 OID 0)
-- Dependencies: 1224
-- Name: FUNCTION f_build_lor_reconciliation_scene_display_candidates(p_lor_reconciliation_run_id bigint); Type: ACL; Schema: ops; Owner: msbadmin
--

REVOKE ALL ON FUNCTION ops.f_build_lor_reconciliation_scene_display_candidates(p_lor_reconciliation_run_id bigint) FROM PUBLIC;
GRANT ALL ON FUNCTION ops.f_build_lor_reconciliation_scene_display_candidates(p_lor_reconciliation_run_id bigint) TO directus_app;


--
-- TOC entry 6127 (class 0 OID 0)
-- Dependencies: 616
-- Name: FUNCTION f_build_lor_reconciliation_stage_candidates(p_lor_reconciliation_run_id bigint); Type: ACL; Schema: ops; Owner: msbadmin
--

REVOKE ALL ON FUNCTION ops.f_build_lor_reconciliation_stage_candidates(p_lor_reconciliation_run_id bigint) FROM PUBLIC;
GRANT ALL ON FUNCTION ops.f_build_lor_reconciliation_stage_candidates(p_lor_reconciliation_run_id bigint) TO directus_app;


--
-- TOC entry 6129 (class 0 OID 0)
-- Dependencies: 1186
-- Name: FUNCTION f_freeze_lor_reconciliation_source_evidence(p_lor_reconciliation_run_id bigint); Type: ACL; Schema: ops; Owner: msbadmin
--

REVOKE ALL ON FUNCTION ops.f_freeze_lor_reconciliation_source_evidence(p_lor_reconciliation_run_id bigint) FROM PUBLIC;
GRANT ALL ON FUNCTION ops.f_freeze_lor_reconciliation_source_evidence(p_lor_reconciliation_run_id bigint) TO directus_app;


--
-- TOC entry 6131 (class 0 OID 0)
-- Dependencies: 692
-- Name: FUNCTION f_lor_reconciliation_display_name_changes_report(p_lor_reconciliation_run_id bigint); Type: ACL; Schema: ops; Owner: msbadmin
--

GRANT ALL ON FUNCTION ops.f_lor_reconciliation_display_name_changes_report(p_lor_reconciliation_run_id bigint) TO directus_app;
GRANT ALL ON FUNCTION ops.f_lor_reconciliation_display_name_changes_report(p_lor_reconciliation_run_id bigint) TO lor_preflight_app;


--
-- TOC entry 6133 (class 0 OID 0)
-- Dependencies: 509
-- Name: FUNCTION f_lor_reconciliation_summary(p_import_run_id bigint); Type: ACL; Schema: ops; Owner: msbadmin
--

GRANT ALL ON FUNCTION ops.f_lor_reconciliation_summary(p_import_run_id bigint) TO directus_app;


--
-- TOC entry 6135 (class 0 OID 0)
-- Dependencies: 485
-- Name: FUNCTION f_record_lor_reconciliation_action(p_lor_reconciliation_run_id bigint, p_lor_reconciliation_group_id bigint, p_action_type text, p_reason text, p_reassociation_map jsonb, p_acted_by_application text); Type: ACL; Schema: ops; Owner: msbadmin
--

REVOKE ALL ON FUNCTION ops.f_record_lor_reconciliation_action(p_lor_reconciliation_run_id bigint, p_lor_reconciliation_group_id bigint, p_action_type text, p_reason text, p_reassociation_map jsonb, p_acted_by_application text) FROM PUBLIC;
GRANT ALL ON FUNCTION ops.f_record_lor_reconciliation_action(p_lor_reconciliation_run_id bigint, p_lor_reconciliation_group_id bigint, p_action_type text, p_reason text, p_reassociation_map jsonb, p_acted_by_application text) TO directus_app;
GRANT ALL ON FUNCTION ops.f_record_lor_reconciliation_action(p_lor_reconciliation_run_id bigint, p_lor_reconciliation_group_id bigint, p_action_type text, p_reason text, p_reassociation_map jsonb, p_acted_by_application text) TO lor_preflight_app;


--
-- TOC entry 6137 (class 0 OID 0)
-- Dependencies: 576
-- Name: FUNCTION f_record_lor_reconciliation_bulk_action(p_lor_reconciliation_run_id bigint, p_lor_reconciliation_group_ids bigint[], p_action_type text, p_reason text, p_acted_by_application text); Type: ACL; Schema: ops; Owner: msbadmin
--

REVOKE ALL ON FUNCTION ops.f_record_lor_reconciliation_bulk_action(p_lor_reconciliation_run_id bigint, p_lor_reconciliation_group_ids bigint[], p_action_type text, p_reason text, p_acted_by_application text) FROM PUBLIC;
GRANT ALL ON FUNCTION ops.f_record_lor_reconciliation_bulk_action(p_lor_reconciliation_run_id bigint, p_lor_reconciliation_group_ids bigint[], p_action_type text, p_reason text, p_acted_by_application text) TO directus_app;
GRANT ALL ON FUNCTION ops.f_record_lor_reconciliation_bulk_action(p_lor_reconciliation_run_id bigint, p_lor_reconciliation_group_ids bigint[], p_action_type text, p_reason text, p_acted_by_application text) TO lor_preflight_app;


--
-- TOC entry 6139 (class 0 OID 0)
-- Dependencies: 1031
-- Name: FUNCTION f_record_lor_stage_preserve_metadata_action(p_lor_reconciliation_run_id bigint, p_lor_reconciliation_group_id bigint, p_reason text, p_acted_by_application text); Type: ACL; Schema: ops; Owner: msbadmin
--

REVOKE ALL ON FUNCTION ops.f_record_lor_stage_preserve_metadata_action(p_lor_reconciliation_run_id bigint, p_lor_reconciliation_group_id bigint, p_reason text, p_acted_by_application text) FROM PUBLIC;
GRANT ALL ON FUNCTION ops.f_record_lor_stage_preserve_metadata_action(p_lor_reconciliation_run_id bigint, p_lor_reconciliation_group_id bigint, p_reason text, p_acted_by_application text) TO directus_app;


--
-- TOC entry 6141 (class 0 OID 0)
-- Dependencies: 910
-- Name: FUNCTION f_stage_group_can_preserve_existing_metadata(p_lor_reconciliation_group_id bigint); Type: ACL; Schema: ops; Owner: msbadmin
--

REVOKE ALL ON FUNCTION ops.f_stage_group_can_preserve_existing_metadata(p_lor_reconciliation_group_id bigint) FROM PUBLIC;
GRANT ALL ON FUNCTION ops.f_stage_group_can_preserve_existing_metadata(p_lor_reconciliation_group_id bigint) TO directus_app;
GRANT ALL ON FUNCTION ops.f_stage_group_can_preserve_existing_metadata(p_lor_reconciliation_group_id bigint) TO lor_preflight_app;


--
-- TOC entry 6143 (class 0 OID 0)
-- Dependencies: 820
-- Name: FUNCTION f_start_lor_display_reconciliation(p_started_by_application text); Type: ACL; Schema: ops; Owner: msbadmin
--

REVOKE ALL ON FUNCTION ops.f_start_lor_display_reconciliation(p_started_by_application text) FROM PUBLIC;
GRANT ALL ON FUNCTION ops.f_start_lor_display_reconciliation(p_started_by_application text) TO directus_app;


--
-- TOC entry 6145 (class 0 OID 0)
-- Dependencies: 525
-- Name: FUNCTION f_start_lor_reconciliation(p_started_by_application text); Type: ACL; Schema: ops; Owner: msbadmin
--

REVOKE ALL ON FUNCTION ops.f_start_lor_reconciliation(p_started_by_application text) FROM PUBLIC;
GRANT ALL ON FUNCTION ops.f_start_lor_reconciliation(p_started_by_application text) TO directus_app;
GRANT ALL ON FUNCTION ops.f_start_lor_reconciliation(p_started_by_application text) TO lor_preflight_app;


--
-- TOC entry 6146 (class 0 OID 0)
-- Dependencies: 746
-- Name: FUNCTION f_sync_lor_reconciliation_counters_on_reporting(); Type: ACL; Schema: ops; Owner: msbadmin
--

GRANT ALL ON FUNCTION ops.f_sync_lor_reconciliation_counters_on_reporting() TO directus_app;


--
-- TOC entry 6148 (class 0 OID 0)
-- Dependencies: 534
-- Name: FUNCTION f_sync_lor_reconciliation_effective_counters(p_lor_reconciliation_run_id bigint); Type: ACL; Schema: ops; Owner: msbadmin
--

REVOKE ALL ON FUNCTION ops.f_sync_lor_reconciliation_effective_counters(p_lor_reconciliation_run_id bigint) FROM PUBLIC;
GRANT ALL ON FUNCTION ops.f_sync_lor_reconciliation_effective_counters(p_lor_reconciliation_run_id bigint) TO directus_app;


--
-- TOC entry 6150 (class 0 OID 0)
-- Dependencies: 1130
-- Name: PROCEDURE p_cancel_lor_reconciliation(IN p_lor_reconciliation_run_id bigint, IN p_cancellation_reason text, IN p_cancelled_by_application text); Type: ACL; Schema: ops; Owner: msbadmin
--

REVOKE ALL ON PROCEDURE ops.p_cancel_lor_reconciliation(IN p_lor_reconciliation_run_id bigint, IN p_cancellation_reason text, IN p_cancelled_by_application text) FROM PUBLIC;
GRANT ALL ON PROCEDURE ops.p_cancel_lor_reconciliation(IN p_lor_reconciliation_run_id bigint, IN p_cancellation_reason text, IN p_cancelled_by_application text) TO directus_app;
GRANT ALL ON PROCEDURE ops.p_cancel_lor_reconciliation(IN p_lor_reconciliation_run_id bigint, IN p_cancellation_reason text, IN p_cancelled_by_application text) TO lor_preflight_app;


--
-- TOC entry 6151 (class 0 OID 0)
-- Dependencies: 1138
-- Name: FUNCTION p_cleanup_recycled_standalone_display(p_display_id bigint); Type: ACL; Schema: ops; Owner: msbadmin
--

GRANT ALL ON FUNCTION ops.p_cleanup_recycled_standalone_display(p_display_id bigint) TO directus_app;


--
-- TOC entry 6153 (class 0 OID 0)
-- Dependencies: 1247
-- Name: PROCEDURE p_finish_lor_reconciliation(IN p_lor_reconciliation_run_id bigint, IN p_finished_by_application text); Type: ACL; Schema: ops; Owner: msbadmin
--

REVOKE ALL ON PROCEDURE ops.p_finish_lor_reconciliation(IN p_lor_reconciliation_run_id bigint, IN p_finished_by_application text) FROM PUBLIC;
GRANT ALL ON PROCEDURE ops.p_finish_lor_reconciliation(IN p_lor_reconciliation_run_id bigint, IN p_finished_by_application text) TO directus_app;
GRANT ALL ON PROCEDURE ops.p_finish_lor_reconciliation(IN p_lor_reconciliation_run_id bigint, IN p_finished_by_application text) TO lor_preflight_app;


--
-- TOC entry 6155 (class 0 OID 0)
-- Dependencies: 549
-- Name: PROCEDURE p_publish_lor_reconciliation_report(IN p_lor_reconciliation_run_id bigint, IN p_report_path text, IN p_report_url text, IN p_report_sha256 text, IN p_published_by_application text); Type: ACL; Schema: ops; Owner: msbadmin
--

REVOKE ALL ON PROCEDURE ops.p_publish_lor_reconciliation_report(IN p_lor_reconciliation_run_id bigint, IN p_report_path text, IN p_report_url text, IN p_report_sha256 text, IN p_published_by_application text) FROM PUBLIC;
GRANT ALL ON PROCEDURE ops.p_publish_lor_reconciliation_report(IN p_lor_reconciliation_run_id bigint, IN p_report_path text, IN p_report_url text, IN p_report_sha256 text, IN p_published_by_application text) TO directus_app;
GRANT ALL ON PROCEDURE ops.p_publish_lor_reconciliation_report(IN p_lor_reconciliation_run_id bigint, IN p_report_path text, IN p_report_url text, IN p_report_sha256 text, IN p_published_by_application text) TO lor_preflight_app;


--
-- TOC entry 6156 (class 0 OID 0)
-- Dependencies: 823
-- Name: FUNCTION p_pull_container(p_container_id integer, p_work_location_code text, p_pulled_by text); Type: ACL; Schema: ops; Owner: msbadmin
--

GRANT ALL ON FUNCTION ops.p_pull_container(p_container_id integer, p_work_location_code text, p_pulled_by text) TO directus_app;


--
-- TOC entry 6157 (class 0 OID 0)
-- Dependencies: 1092
-- Name: FUNCTION p_pull_container(p_container_id integer, p_work_location_code text, p_pulled_by text, p_pulled_by_person_id integer); Type: ACL; Schema: ops; Owner: msbadmin
--

GRANT ALL ON FUNCTION ops.p_pull_container(p_container_id integer, p_work_location_code text, p_pulled_by text, p_pulled_by_person_id integer) TO directus_app;


--
-- TOC entry 6158 (class 0 OID 0)
-- Dependencies: 571
-- Name: FUNCTION p_pull_container(p_container_id integer, p_work_location_code text, p_pulled_by text, p_pulled_by_person_id bigint); Type: ACL; Schema: ops; Owner: msbadmin
--

GRANT ALL ON FUNCTION ops.p_pull_container(p_container_id integer, p_work_location_code text, p_pulled_by text, p_pulled_by_person_id bigint) TO directus_app;


--
-- TOC entry 6160 (class 0 OID 0)
-- Dependencies: 987
-- Name: FUNCTION p_refresh_test_session(p_test_session_id bigint, p_refreshed_by text, p_refreshed_by_person_id integer); Type: ACL; Schema: ops; Owner: msbadmin
--

GRANT ALL ON FUNCTION ops.p_refresh_test_session(p_test_session_id bigint, p_refreshed_by text, p_refreshed_by_person_id integer) TO directus_app;


--
-- TOC entry 6161 (class 0 OID 0)
-- Dependencies: 1167
-- Name: FUNCTION set_audit_fields(); Type: ACL; Schema: ops; Owner: msbadmin
--

GRANT ALL ON FUNCTION ops.set_audit_fields() TO directus_app;


--
-- TOC entry 6162 (class 0 OID 0)
-- Dependencies: 968
-- Name: FUNCTION set_checked_actor(); Type: ACL; Schema: ops; Owner: msbadmin
--

GRANT ALL ON FUNCTION ops.set_checked_actor() TO directus_app;


--
-- TOC entry 6163 (class 0 OID 0)
-- Dependencies: 574
-- Name: FUNCTION set_container_search_helper(); Type: ACL; Schema: ops; Owner: msbadmin
--

GRANT ALL ON FUNCTION ops.set_container_search_helper() TO directus_app;


--
-- TOC entry 6164 (class 0 OID 0)
-- Dependencies: 753
-- Name: FUNCTION tf_after_refresh_test_session(); Type: ACL; Schema: ops; Owner: msbadmin
--

GRANT ALL ON FUNCTION ops.tf_after_refresh_test_session() TO directus_app;


--
-- TOC entry 6165 (class 0 OID 0)
-- Dependencies: 848
-- Name: FUNCTION tf_after_start_container_pull(); Type: ACL; Schema: ops; Owner: msbadmin
--

GRANT ALL ON FUNCTION ops.tf_after_start_container_pull() TO directus_app;


--
-- TOC entry 6166 (class 0 OID 0)
-- Dependencies: 754
-- Name: FUNCTION tf_start_container_pull(); Type: ACL; Schema: ops; Owner: msbadmin
--

GRANT ALL ON FUNCTION ops.tf_start_container_pull() TO directus_app;


--
-- TOC entry 6167 (class 0 OID 0)
-- Dependencies: 904
-- Name: FUNCTION tf_validate_display_test_session_notes(); Type: ACL; Schema: ops; Owner: msbadmin
--

GRANT ALL ON FUNCTION ops.tf_validate_display_test_session_notes() TO directus_app;


--
-- TOC entry 6168 (class 0 OID 0)
-- Dependencies: 627
-- Name: FUNCTION tf_work_order_autofill_completion_on_repair_complete(); Type: ACL; Schema: ops; Owner: msbadmin
--

GRANT ALL ON FUNCTION ops.tf_work_order_autofill_completion_on_repair_complete() TO directus_app;


--
-- TOC entry 6170 (class 0 OID 0)
-- Dependencies: 958
-- Name: FUNCTION trg_auto_approve_safe_uuid_relink(); Type: ACL; Schema: ops; Owner: msbadmin
--

REVOKE ALL ON FUNCTION ops.trg_auto_approve_safe_uuid_relink() FROM PUBLIC;
GRANT ALL ON FUNCTION ops.trg_auto_approve_safe_uuid_relink() TO directus_app;


--
-- TOC entry 6171 (class 0 OID 0)
-- Dependencies: 1170
-- Name: FUNCTION trg_lor_reconciliation_detail_immutable(); Type: ACL; Schema: ops; Owner: msbadmin
--

GRANT ALL ON FUNCTION ops.trg_lor_reconciliation_detail_immutable() TO directus_app;


--
-- TOC entry 6172 (class 0 OID 0)
-- Dependencies: 1278
-- Name: FUNCTION trg_require_terminal_reconciliation_decisions(); Type: ACL; Schema: ops; Owner: msbadmin
--

REVOKE ALL ON FUNCTION ops.trg_require_terminal_reconciliation_decisions() FROM PUBLIC;
GRANT ALL ON FUNCTION ops.trg_require_terminal_reconciliation_decisions() TO directus_app;


--
-- TOC entry 6174 (class 0 OID 0)
-- Dependencies: 508
-- Name: PROCEDURE p1_promote_stage_from_reconciliation(IN p_lor_reconciliation_run_id bigint); Type: ACL; Schema: ref; Owner: msbadmin
--

REVOKE ALL ON PROCEDURE ref.p1_promote_stage_from_reconciliation(IN p_lor_reconciliation_run_id bigint) FROM PUBLIC;
GRANT ALL ON PROCEDURE ref.p1_promote_stage_from_reconciliation(IN p_lor_reconciliation_run_id bigint) TO directus_app;


--
-- TOC entry 6177 (class 0 OID 0)
-- Dependencies: 619
-- Name: PROCEDURE p2_promote_display_from_reconciliation(IN p_lor_reconciliation_run_id bigint); Type: ACL; Schema: ref; Owner: msbadmin
--

REVOKE ALL ON PROCEDURE ref.p2_promote_display_from_reconciliation(IN p_lor_reconciliation_run_id bigint) FROM PUBLIC;
GRANT ALL ON PROCEDURE ref.p2_promote_display_from_reconciliation(IN p_lor_reconciliation_run_id bigint) TO directus_app;


--
-- TOC entry 6180 (class 0 OID 0)
-- Dependencies: 1004
-- Name: PROCEDURE p3_promote_scene_from_reconciliation(IN p_lor_reconciliation_run_id bigint); Type: ACL; Schema: ref; Owner: msbadmin
--

REVOKE ALL ON PROCEDURE ref.p3_promote_scene_from_reconciliation(IN p_lor_reconciliation_run_id bigint) FROM PUBLIC;
GRANT ALL ON PROCEDURE ref.p3_promote_scene_from_reconciliation(IN p_lor_reconciliation_run_id bigint) TO directus_app;


--
-- TOC entry 6182 (class 0 OID 0)
-- Dependencies: 566
-- Name: PROCEDURE p4_promote_scene_display_from_reconciliation(IN p_lor_reconciliation_run_id bigint); Type: ACL; Schema: ref; Owner: msbadmin
--

REVOKE ALL ON PROCEDURE ref.p4_promote_scene_display_from_reconciliation(IN p_lor_reconciliation_run_id bigint) FROM PUBLIC;
GRANT ALL ON PROCEDURE ref.p4_promote_scene_display_from_reconciliation(IN p_lor_reconciliation_run_id bigint) TO directus_app;


--
-- TOC entry 6183 (class 0 OID 0)
-- Dependencies: 550
-- Name: FUNCTION resolve_actor(); Type: ACL; Schema: ref; Owner: msbadmin
--

GRANT ALL ON FUNCTION ref.resolve_actor() TO directus_app;
GRANT ALL ON FUNCTION ref.resolve_actor() TO printservice;


--
-- TOC entry 6184 (class 0 OID 0)
-- Dependencies: 1265
-- Name: FUNCTION set_actor_on_insert(); Type: ACL; Schema: ref; Owner: msbadmin
--

GRANT ALL ON FUNCTION ref.set_actor_on_insert() TO directus_app;


--
-- TOC entry 6185 (class 0 OID 0)
-- Dependencies: 1219
-- Name: FUNCTION set_actor_on_update(); Type: ACL; Schema: ref; Owner: msbadmin
--

GRANT ALL ON FUNCTION ref.set_actor_on_update() TO directus_app;


--
-- TOC entry 6186 (class 0 OID 0)
-- Dependencies: 877
-- Name: FUNCTION set_audit_fields(); Type: ACL; Schema: ref; Owner: msbadmin
--

GRANT ALL ON FUNCTION ref.set_audit_fields() TO directus_app;


--
-- TOC entry 6187 (class 0 OID 0)
-- Dependencies: 466
-- Name: FUNCTION set_frame_updated_fields(); Type: ACL; Schema: ref; Owner: msbadmin
--

GRANT ALL ON FUNCTION ref.set_frame_updated_fields() TO directus_app;


--
-- TOC entry 6188 (class 0 OID 0)
-- Dependencies: 723
-- Name: FUNCTION set_updated_fields(); Type: ACL; Schema: ref; Owner: msbadmin
--

GRANT ALL ON FUNCTION ref.set_updated_fields() TO directus_app;


--
-- TOC entry 6190 (class 0 OID 0)
-- Dependencies: 959
-- Name: FUNCTION sync_audit_collection_policy(); Type: ACL; Schema: ref; Owner: msbadmin
--

GRANT ALL ON FUNCTION ref.sync_audit_collection_policy() TO directus_app;


--
-- TOC entry 6191 (class 0 OID 0)
-- Dependencies: 966
-- Name: FUNCTION sync_container_search_helper_to_test_session(); Type: ACL; Schema: ref; Owner: msbadmin
--

GRANT ALL ON FUNCTION ref.sync_container_search_helper_to_test_session() TO directus_app;


--
-- TOC entry 6192 (class 0 OID 0)
-- Dependencies: 598
-- Name: FUNCTION tg_touch_row(); Type: ACL; Schema: ref; Owner: msbadmin
--

GRANT ALL ON FUNCTION ref.tg_touch_row() TO directus_app;


--
-- TOC entry 6194 (class 0 OID 0)
-- Dependencies: 1218
-- Name: FUNCTION trg_lor_scene_display_require_change(); Type: ACL; Schema: ref; Owner: msbadmin
--

GRANT ALL ON FUNCTION ref.trg_lor_scene_display_require_change() TO directus_app;


--
-- TOC entry 6196 (class 0 OID 0)
-- Dependencies: 596
-- Name: FUNCTION trg_lor_scene_require_change(); Type: ACL; Schema: ref; Owner: msbadmin
--

GRANT ALL ON FUNCTION ref.trg_lor_scene_require_change() TO directus_app;


--
-- TOC entry 6197 (class 0 OID 0)
-- Dependencies: 1155
-- Name: FUNCTION trg_set_updated(); Type: ACL; Schema: ref; Owner: msbadmin
--

GRANT ALL ON FUNCTION ref.trg_set_updated() TO directus_app;


--
-- TOC entry 6199 (class 0 OID 0)
-- Dependencies: 1050
-- Name: FUNCTION trg_stage_lor_binding_require_change(); Type: ACL; Schema: ref; Owner: msbadmin
--

GRANT ALL ON FUNCTION ref.trg_stage_lor_binding_require_change() TO directus_app;


--
-- TOC entry 6204 (class 0 OID 0)
-- Dependencies: 284
-- Name: TABLE container; Type: ACL; Schema: ref; Owner: msbadmin
--

GRANT SELECT,INSERT,REFERENCES,DELETE,UPDATE ON TABLE ref.container TO directus_app;
GRANT SELECT,UPDATE ON TABLE ref.container TO printservice;


--
-- TOC entry 6205 (class 0 OID 0)
-- Dependencies: 284 6204
-- Name: COLUMN container.location_code; Type: ACL; Schema: ref; Owner: msbadmin
--

GRANT UPDATE(location_code) ON TABLE ref.container TO directus_app;


--
-- TOC entry 6206 (class 0 OID 0)
-- Dependencies: 284 6204
-- Name: COLUMN container.container_type_id; Type: ACL; Schema: ref; Owner: msbadmin
--

GRANT UPDATE(container_type_id) ON TABLE ref.container TO directus_app;


--
-- TOC entry 6207 (class 0 OID 0)
-- Dependencies: 284 6204
-- Name: COLUMN container.description; Type: ACL; Schema: ref; Owner: msbadmin
--

GRANT UPDATE(description) ON TABLE ref.container TO directus_app;


--
-- TOC entry 6208 (class 0 OID 0)
-- Dependencies: 284 6204
-- Name: COLUMN container.is_stackable_override; Type: ACL; Schema: ref; Owner: msbadmin
--

GRANT UPDATE(is_stackable_override) ON TABLE ref.container TO directus_app;


--
-- TOC entry 6209 (class 0 OID 0)
-- Dependencies: 284 6204
-- Name: COLUMN container.year_built; Type: ACL; Schema: ref; Owner: msbadmin
--

GRANT UPDATE(year_built) ON TABLE ref.container TO directus_app;


--
-- TOC entry 6210 (class 0 OID 0)
-- Dependencies: 284 6204
-- Name: COLUMN container.notes; Type: ACL; Schema: ref; Owner: msbadmin
--

GRANT UPDATE(notes) ON TABLE ref.container TO directus_app;


--
-- TOC entry 6211 (class 0 OID 0)
-- Dependencies: 284 6204
-- Name: COLUMN container.width_in_override; Type: ACL; Schema: ref; Owner: msbadmin
--

GRANT UPDATE(width_in_override) ON TABLE ref.container TO directus_app;


--
-- TOC entry 6212 (class 0 OID 0)
-- Dependencies: 284 6204
-- Name: COLUMN container.depth_in_override; Type: ACL; Schema: ref; Owner: msbadmin
--

GRANT UPDATE(depth_in_override) ON TABLE ref.container TO directus_app;


--
-- TOC entry 6213 (class 0 OID 0)
-- Dependencies: 284 6204
-- Name: COLUMN container.height_in_override; Type: ACL; Schema: ref; Owner: msbadmin
--

GRANT UPDATE(height_in_override) ON TABLE ref.container TO directus_app;


--
-- TOC entry 6214 (class 0 OID 0)
-- Dependencies: 284 6204
-- Name: COLUMN container.goes_to; Type: ACL; Schema: ref; Owner: msbadmin
--

GRANT UPDATE(goes_to) ON TABLE ref.container TO directus_app;


--
-- TOC entry 6215 (class 0 OID 0)
-- Dependencies: 284 6204
-- Name: COLUMN container.display_pallet; Type: ACL; Schema: ref; Owner: msbadmin
--

GRANT UPDATE(display_pallet) ON TABLE ref.container TO directus_app;


--
-- TOC entry 6216 (class 0 OID 0)
-- Dependencies: 284 6204
-- Name: COLUMN container.testing_after_takedown; Type: ACL; Schema: ref; Owner: msbadmin
--

GRANT UPDATE(testing_after_takedown) ON TABLE ref.container TO directus_app;


--
-- TOC entry 6217 (class 0 OID 0)
-- Dependencies: 284 6204
-- Name: COLUMN container.display_pallet_flag; Type: ACL; Schema: ref; Owner: msbadmin
--

GRANT UPDATE(display_pallet_flag) ON TABLE ref.container TO directus_app;


--
-- TOC entry 6222 (class 0 OID 0)
-- Dependencies: 293
-- Name: TABLE display; Type: ACL; Schema: ref; Owner: msbadmin
--

GRANT SELECT,REFERENCES,UPDATE ON TABLE ref.display TO directus_app;
GRANT SELECT,UPDATE ON TABLE ref.display TO printservice;
GRANT SELECT ON TABLE ref.display TO lor_preflight_app;


--
-- TOC entry 6223 (class 0 OID 0)
-- Dependencies: 259
-- Name: TABLE dmx_channels; Type: ACL; Schema: lor_snap; Owner: msbadmin
--

GRANT SELECT ON TABLE lor_snap.dmx_channels TO directus_app;


--
-- TOC entry 6224 (class 0 OID 0)
-- Dependencies: 255
-- Name: TABLE import_run; Type: ACL; Schema: lor_snap; Owner: msbadmin
--

GRANT SELECT ON TABLE lor_snap.import_run TO directus_app;


--
-- TOC entry 6226 (class 0 OID 0)
-- Dependencies: 254
-- Name: SEQUENCE import_run_import_run_id_seq; Type: ACL; Schema: lor_snap; Owner: msbadmin
--

GRANT SELECT,USAGE ON SEQUENCE lor_snap.import_run_import_run_id_seq TO directus_app;


--
-- TOC entry 6228 (class 0 OID 0)
-- Dependencies: 256
-- Name: TABLE previews; Type: ACL; Schema: lor_snap; Owner: msbadmin
--

GRANT SELECT ON TABLE lor_snap.previews TO directus_app;


--
-- TOC entry 6230 (class 0 OID 0)
-- Dependencies: 257
-- Name: TABLE props; Type: ACL; Schema: lor_snap; Owner: msbadmin
--

GRANT SELECT ON TABLE lor_snap.props TO directus_app;


--
-- TOC entry 6232 (class 0 OID 0)
-- Dependencies: 258
-- Name: TABLE sub_props; Type: ACL; Schema: lor_snap; Owner: msbadmin
--

GRANT SELECT ON TABLE lor_snap.sub_props TO directus_app;


--
-- TOC entry 6234 (class 0 OID 0)
-- Dependencies: 260
-- Name: TABLE v_current_run; Type: ACL; Schema: lor_snap; Owner: msbadmin
--

GRANT SELECT ON TABLE lor_snap.v_current_run TO directus_app;
GRANT SELECT ON TABLE lor_snap.v_current_run TO lor_preflight_app;


--
-- TOC entry 6235 (class 0 OID 0)
-- Dependencies: 264
-- Name: TABLE v_current_dmx_channels; Type: ACL; Schema: lor_snap; Owner: msbadmin
--

GRANT SELECT ON TABLE lor_snap.v_current_dmx_channels TO directus_app;


--
-- TOC entry 6237 (class 0 OID 0)
-- Dependencies: 261
-- Name: TABLE v_current_previews; Type: ACL; Schema: lor_snap; Owner: msbadmin
--

GRANT SELECT ON TABLE lor_snap.v_current_previews TO directus_app;


--
-- TOC entry 6239 (class 0 OID 0)
-- Dependencies: 262
-- Name: TABLE v_current_props; Type: ACL; Schema: lor_snap; Owner: msbadmin
--

GRANT SELECT ON TABLE lor_snap.v_current_props TO directus_app;


--
-- TOC entry 6241 (class 0 OID 0)
-- Dependencies: 263
-- Name: TABLE v_current_sub_props; Type: ACL; Schema: lor_snap; Owner: msbadmin
--

GRANT SELECT ON TABLE lor_snap.v_current_sub_props TO directus_app;


--
-- TOC entry 6242 (class 0 OID 0)
-- Dependencies: 265
-- Name: TABLE preview_wiring_map_v6; Type: ACL; Schema: lor_snap; Owner: msbadmin
--

GRANT SELECT ON TABLE lor_snap.preview_wiring_map_v6 TO directus_app;


--
-- TOC entry 6243 (class 0 OID 0)
-- Dependencies: 266
-- Name: TABLE preview_wiring_sorted_v6; Type: ACL; Schema: lor_snap; Owner: msbadmin
--

GRANT SELECT ON TABLE lor_snap.preview_wiring_sorted_v6 TO directus_app;


--
-- TOC entry 6244 (class 0 OID 0)
-- Dependencies: 267
-- Name: TABLE preview_wiring_fieldmap_v6; Type: ACL; Schema: lor_snap; Owner: msbadmin
--

GRANT SELECT ON TABLE lor_snap.preview_wiring_fieldmap_v6 TO directus_app;


--
-- TOC entry 6245 (class 0 OID 0)
-- Dependencies: 268
-- Name: TABLE preview_wiring_fieldlead_v6; Type: ACL; Schema: lor_snap; Owner: msbadmin
--

GRANT SELECT ON TABLE lor_snap.preview_wiring_fieldlead_v6 TO directus_app;


--
-- TOC entry 6246 (class 0 OID 0)
-- Dependencies: 269
-- Name: TABLE preview_wiring_circuit_rollup_v6; Type: ACL; Schema: lor_snap; Owner: msbadmin
--

GRANT SELECT ON TABLE lor_snap.preview_wiring_circuit_rollup_v6 TO directus_app;


--
-- TOC entry 6247 (class 0 OID 0)
-- Dependencies: 270
-- Name: TABLE preview_wiring_fieldonly_v6; Type: ACL; Schema: lor_snap; Owner: msbadmin
--

GRANT SELECT ON TABLE lor_snap.preview_wiring_fieldonly_v6 TO directus_app;


--
-- TOC entry 6248 (class 0 OID 0)
-- Dependencies: 418
-- Name: TABLE scene_lor_props; Type: ACL; Schema: lor_snap; Owner: msbadmin
--

GRANT SELECT ON TABLE lor_snap.scene_lor_props TO directus_app;


--
-- TOC entry 6249 (class 0 OID 0)
-- Dependencies: 417
-- Name: TABLE scenes; Type: ACL; Schema: lor_snap; Owner: msbadmin
--

GRANT SELECT ON TABLE lor_snap.scenes TO directus_app;


--
-- TOC entry 6250 (class 0 OID 0)
-- Dependencies: 271
-- Name: TABLE stage_display_assets_v1; Type: ACL; Schema: lor_snap; Owner: msbadmin
--

GRANT SELECT ON TABLE lor_snap.stage_display_assets_v1 TO directus_app;


--
-- TOC entry 6251 (class 0 OID 0)
-- Dependencies: 272
-- Name: TABLE stage_display_inventory_only_v1; Type: ACL; Schema: lor_snap; Owner: msbadmin
--

GRANT SELECT ON TABLE lor_snap.stage_display_inventory_only_v1 TO directus_app;


--
-- TOC entry 6252 (class 0 OID 0)
-- Dependencies: 273
-- Name: TABLE stage_display_assets_all_v1; Type: ACL; Schema: lor_snap; Owner: msbadmin
--

GRANT SELECT ON TABLE lor_snap.stage_display_assets_all_v1 TO directus_app;


--
-- TOC entry 6253 (class 0 OID 0)
-- Dependencies: 274
-- Name: TABLE stage_display_list_all_v1; Type: ACL; Schema: lor_snap; Owner: msbadmin
--

GRANT SELECT ON TABLE lor_snap.stage_display_list_all_v1 TO directus_app;


--
-- TOC entry 6254 (class 0 OID 0)
-- Dependencies: 275
-- Name: TABLE stage_display_unassigned_v1; Type: ACL; Schema: lor_snap; Owner: msbadmin
--

GRANT SELECT ON TABLE lor_snap.stage_display_unassigned_v1 TO directus_app;


--
-- TOC entry 6255 (class 0 OID 0)
-- Dependencies: 420
-- Name: TABLE v_current_scene_lor_props; Type: ACL; Schema: lor_snap; Owner: msbadmin
--

GRANT SELECT ON TABLE lor_snap.v_current_scene_lor_props TO directus_app;


--
-- TOC entry 6256 (class 0 OID 0)
-- Dependencies: 419
-- Name: TABLE v_current_scenes; Type: ACL; Schema: lor_snap; Owner: msbadmin
--

GRANT SELECT ON TABLE lor_snap.v_current_scenes TO directus_app;


--
-- TOC entry 6258 (class 0 OID 0)
-- Dependencies: 422
-- Name: TABLE v_display_lor_occurrence; Type: ACL; Schema: lor_snap; Owner: msbadmin
--

GRANT SELECT ON TABLE lor_snap.v_display_lor_occurrence TO directus_app;


--
-- TOC entry 6260 (class 0 OID 0)
-- Dependencies: 421
-- Name: TABLE v_display_reconciliation_source; Type: ACL; Schema: lor_snap; Owner: msbadmin
--

GRANT SELECT ON TABLE lor_snap.v_display_reconciliation_source TO directus_app;


--
-- TOC entry 6261 (class 0 OID 0)
-- Dependencies: 291
-- Name: TABLE v_prop_identity; Type: ACL; Schema: lor_snap; Owner: msbadmin
--

GRANT SELECT ON TABLE lor_snap.v_prop_identity TO directus_app;


--
-- TOC entry 6262 (class 0 OID 0)
-- Dependencies: 301
-- Name: TABLE v_props_diff_latest_prev; Type: ACL; Schema: lor_snap; Owner: msbadmin
--

GRANT SELECT ON TABLE lor_snap.v_props_diff_latest_prev TO directus_app;


--
-- TOC entry 6263 (class 0 OID 0)
-- Dependencies: 409
-- Name: TABLE container_label_batch; Type: ACL; Schema: ops; Owner: msbadmin
--

GRANT SELECT,INSERT,REFERENCES,UPDATE ON TABLE ops.container_label_batch TO directus_app;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE ops.container_label_batch TO printservice;


--
-- TOC entry 6265 (class 0 OID 0)
-- Dependencies: 408
-- Name: SEQUENCE container_label_batch_container_label_batch_id_seq; Type: ACL; Schema: ops; Owner: msbadmin
--

GRANT SELECT,USAGE ON SEQUENCE ops.container_label_batch_container_label_batch_id_seq TO directus_app;
GRANT SELECT,USAGE ON SEQUENCE ops.container_label_batch_container_label_batch_id_seq TO printservice;


--
-- TOC entry 6266 (class 0 OID 0)
-- Dependencies: 411
-- Name: TABLE container_label_batch_item; Type: ACL; Schema: ops; Owner: msbadmin
--

GRANT SELECT,INSERT,REFERENCES,UPDATE ON TABLE ops.container_label_batch_item TO directus_app;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE ops.container_label_batch_item TO printservice;


--
-- TOC entry 6268 (class 0 OID 0)
-- Dependencies: 410
-- Name: SEQUENCE container_label_batch_item_container_label_batch_item_id_seq; Type: ACL; Schema: ops; Owner: msbadmin
--

GRANT SELECT,USAGE ON SEQUENCE ops.container_label_batch_item_container_label_batch_item_id_seq TO directus_app;
GRANT SELECT,USAGE ON SEQUENCE ops.container_label_batch_item_container_label_batch_item_id_seq TO printservice;


--
-- TOC entry 6271 (class 0 OID 0)
-- Dependencies: 402
-- Name: TABLE container_label_print; Type: ACL; Schema: ops; Owner: directus_app
--

GRANT SELECT,INSERT,UPDATE ON TABLE ops.container_label_print TO printservice;


--
-- TOC entry 6273 (class 0 OID 0)
-- Dependencies: 401
-- Name: SEQUENCE container_label_print_container_label_print_id_seq; Type: ACL; Schema: ops; Owner: directus_app
--

GRANT SELECT,USAGE ON SEQUENCE ops.container_label_print_container_label_print_id_seq TO printservice;


--
-- TOC entry 6274 (class 0 OID 0)
-- Dependencies: 405
-- Name: TABLE display_label_batch; Type: ACL; Schema: ops; Owner: msbadmin
--

GRANT SELECT,INSERT,REFERENCES,UPDATE ON TABLE ops.display_label_batch TO directus_app;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE ops.display_label_batch TO printservice;


--
-- TOC entry 6276 (class 0 OID 0)
-- Dependencies: 404
-- Name: SEQUENCE display_label_batch_display_label_batch_id_seq; Type: ACL; Schema: ops; Owner: msbadmin
--

GRANT SELECT,USAGE ON SEQUENCE ops.display_label_batch_display_label_batch_id_seq TO directus_app;
GRANT SELECT,USAGE ON SEQUENCE ops.display_label_batch_display_label_batch_id_seq TO printservice;


--
-- TOC entry 6277 (class 0 OID 0)
-- Dependencies: 407
-- Name: TABLE display_label_batch_item; Type: ACL; Schema: ops; Owner: msbadmin
--

GRANT SELECT,INSERT,REFERENCES,UPDATE ON TABLE ops.display_label_batch_item TO directus_app;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE ops.display_label_batch_item TO printservice;


--
-- TOC entry 6279 (class 0 OID 0)
-- Dependencies: 406
-- Name: SEQUENCE display_label_batch_item_display_label_batch_item_id_seq; Type: ACL; Schema: ops; Owner: msbadmin
--

GRANT SELECT,USAGE ON SEQUENCE ops.display_label_batch_item_display_label_batch_item_id_seq TO directus_app;
GRANT SELECT,USAGE ON SEQUENCE ops.display_label_batch_item_display_label_batch_item_id_seq TO printservice;


--
-- TOC entry 6284 (class 0 OID 0)
-- Dependencies: 400
-- Name: TABLE display_label_print; Type: ACL; Schema: ops; Owner: directus_app
--

GRANT SELECT,INSERT,UPDATE ON TABLE ops.display_label_print TO printservice;


--
-- TOC entry 6286 (class 0 OID 0)
-- Dependencies: 399
-- Name: SEQUENCE display_label_print_display_label_print_id_seq; Type: ACL; Schema: ops; Owner: directus_app
--

GRANT SELECT,USAGE ON SEQUENCE ops.display_label_print_display_label_print_id_seq TO printservice;


--
-- TOC entry 6287 (class 0 OID 0)
-- Dependencies: 305
-- Name: TABLE display_test_session; Type: ACL; Schema: ops; Owner: msbadmin
--

GRANT SELECT,INSERT,REFERENCES,DELETE,UPDATE ON TABLE ops.display_test_session TO directus_app;


--
-- TOC entry 6289 (class 0 OID 0)
-- Dependencies: 304
-- Name: SEQUENCE display_test_session_display_test_session_id_seq; Type: ACL; Schema: ops; Owner: msbadmin
--

GRANT SELECT,USAGE ON SEQUENCE ops.display_test_session_display_test_session_id_seq TO directus_app;


--
-- TOC entry 6291 (class 0 OID 0)
-- Dependencies: 437
-- Name: TABLE lor_reconciliation_action; Type: ACL; Schema: ops; Owner: msbadmin
--

GRANT SELECT,INSERT,UPDATE ON TABLE ops.lor_reconciliation_action TO directus_app;
GRANT SELECT ON TABLE ops.lor_reconciliation_action TO lor_preflight_app;


--
-- TOC entry 6293 (class 0 OID 0)
-- Dependencies: 439
-- Name: TABLE lor_reconciliation_action_assignment; Type: ACL; Schema: ops; Owner: msbadmin
--

GRANT SELECT,INSERT,UPDATE ON TABLE ops.lor_reconciliation_action_assignment TO directus_app;


--
-- TOC entry 6294 (class 0 OID 0)
-- Dependencies: 438
-- Name: SEQUENCE lor_reconciliation_action_ass_lor_reconciliation_action_ass_seq; Type: ACL; Schema: ops; Owner: msbadmin
--

GRANT SELECT,USAGE ON SEQUENCE ops.lor_reconciliation_action_ass_lor_reconciliation_action_ass_seq TO directus_app;


--
-- TOC entry 6296 (class 0 OID 0)
-- Dependencies: 425
-- Name: TABLE lor_reconciliation_action_legacy; Type: ACL; Schema: ops; Owner: msbadmin
--

GRANT SELECT,INSERT,UPDATE ON TABLE ops.lor_reconciliation_action_legacy TO directus_app;


--
-- TOC entry 6297 (class 0 OID 0)
-- Dependencies: 424
-- Name: SEQUENCE lor_reconciliation_action_legacy_id_seq; Type: ACL; Schema: ops; Owner: msbadmin
--

GRANT SELECT,USAGE ON SEQUENCE ops.lor_reconciliation_action_legacy_id_seq TO directus_app;


--
-- TOC entry 6298 (class 0 OID 0)
-- Dependencies: 436
-- Name: SEQUENCE lor_reconciliation_action_lor_reconciliation_action_id_seq; Type: ACL; Schema: ops; Owner: msbadmin
--

GRANT SELECT,USAGE ON SEQUENCE ops.lor_reconciliation_action_lor_reconciliation_action_id_seq TO directus_app;


--
-- TOC entry 6300 (class 0 OID 0)
-- Dependencies: 435
-- Name: TABLE lor_reconciliation_display_candidate; Type: ACL; Schema: ops; Owner: msbadmin
--

GRANT SELECT,INSERT,UPDATE ON TABLE ops.lor_reconciliation_display_candidate TO directus_app;


--
-- TOC entry 6301 (class 0 OID 0)
-- Dependencies: 434
-- Name: SEQUENCE lor_reconciliation_display_ca_lor_reconciliation_display_ca_seq; Type: ACL; Schema: ops; Owner: msbadmin
--

GRANT SELECT,USAGE ON SEQUENCE ops.lor_reconciliation_display_ca_lor_reconciliation_display_ca_seq TO directus_app;


--
-- TOC entry 6303 (class 0 OID 0)
-- Dependencies: 433
-- Name: TABLE lor_reconciliation_group; Type: ACL; Schema: ops; Owner: msbadmin
--

GRANT SELECT,INSERT,UPDATE ON TABLE ops.lor_reconciliation_group TO directus_app;
GRANT SELECT ON TABLE ops.lor_reconciliation_group TO lor_preflight_app;


--
-- TOC entry 6304 (class 0 OID 0)
-- Dependencies: 432
-- Name: SEQUENCE lor_reconciliation_group_lor_reconciliation_group_id_seq; Type: ACL; Schema: ops; Owner: msbadmin
--

GRANT SELECT,USAGE ON SEQUENCE ops.lor_reconciliation_group_lor_reconciliation_group_id_seq TO directus_app;


--
-- TOC entry 6306 (class 0 OID 0)
-- Dependencies: 441
-- Name: TABLE lor_reconciliation_result; Type: ACL; Schema: ops; Owner: msbadmin
--

GRANT SELECT,INSERT,UPDATE ON TABLE ops.lor_reconciliation_result TO directus_app;
GRANT SELECT ON TABLE ops.lor_reconciliation_result TO lor_preflight_app;


--
-- TOC entry 6307 (class 0 OID 0)
-- Dependencies: 440
-- Name: SEQUENCE lor_reconciliation_result_lor_reconciliation_result_id_seq; Type: ACL; Schema: ops; Owner: msbadmin
--

GRANT SELECT,USAGE ON SEQUENCE ops.lor_reconciliation_result_lor_reconciliation_result_id_seq TO directus_app;


--
-- TOC entry 6309 (class 0 OID 0)
-- Dependencies: 431
-- Name: TABLE lor_reconciliation_run; Type: ACL; Schema: ops; Owner: msbadmin
--

GRANT SELECT,INSERT,UPDATE ON TABLE ops.lor_reconciliation_run TO directus_app;
GRANT SELECT ON TABLE ops.lor_reconciliation_run TO lor_preflight_app;


--
-- TOC entry 6310 (class 0 OID 0)
-- Dependencies: 430
-- Name: SEQUENCE lor_reconciliation_run_lor_reconciliation_run_id_seq; Type: ACL; Schema: ops; Owner: msbadmin
--

GRANT SELECT,USAGE ON SEQUENCE ops.lor_reconciliation_run_lor_reconciliation_run_id_seq TO directus_app;


--
-- TOC entry 6312 (class 0 OID 0)
-- Dependencies: 451
-- Name: TABLE lor_reconciliation_scene_candidate; Type: ACL; Schema: ops; Owner: msbadmin
--

GRANT SELECT,INSERT,UPDATE ON TABLE ops.lor_reconciliation_scene_candidate TO directus_app;


--
-- TOC entry 6313 (class 0 OID 0)
-- Dependencies: 450
-- Name: SEQUENCE lor_reconciliation_scene_cand_lor_reconciliation_scene_cand_seq; Type: ACL; Schema: ops; Owner: msbadmin
--

GRANT SELECT,USAGE ON SEQUENCE ops.lor_reconciliation_scene_cand_lor_reconciliation_scene_cand_seq TO directus_app;


--
-- TOC entry 6315 (class 0 OID 0)
-- Dependencies: 453
-- Name: TABLE lor_reconciliation_scene_display_candidate; Type: ACL; Schema: ops; Owner: msbadmin
--

GRANT SELECT,INSERT,UPDATE ON TABLE ops.lor_reconciliation_scene_display_candidate TO directus_app;


--
-- TOC entry 6316 (class 0 OID 0)
-- Dependencies: 452
-- Name: SEQUENCE lor_reconciliation_scene_disp_lor_reconciliation_scene_disp_seq; Type: ACL; Schema: ops; Owner: msbadmin
--

GRANT SELECT,USAGE ON SEQUENCE ops.lor_reconciliation_scene_disp_lor_reconciliation_scene_disp_seq TO directus_app;


--
-- TOC entry 6318 (class 0 OID 0)
-- Dependencies: 458
-- Name: TABLE lor_reconciliation_source_preview; Type: ACL; Schema: ops; Owner: msbadmin
--

GRANT SELECT,INSERT,UPDATE ON TABLE ops.lor_reconciliation_source_preview TO directus_app;
GRANT SELECT ON TABLE ops.lor_reconciliation_source_preview TO lor_preflight_app;


--
-- TOC entry 6319 (class 0 OID 0)
-- Dependencies: 457
-- Name: SEQUENCE lor_reconciliation_source_pre_lor_reconciliation_source_pre_seq; Type: ACL; Schema: ops; Owner: msbadmin
--

GRANT SELECT,USAGE ON SEQUENCE ops.lor_reconciliation_source_pre_lor_reconciliation_source_pre_seq TO directus_app;


--
-- TOC entry 6321 (class 0 OID 0)
-- Dependencies: 456
-- Name: TABLE lor_reconciliation_source_run; Type: ACL; Schema: ops; Owner: msbadmin
--

GRANT SELECT,INSERT,UPDATE ON TABLE ops.lor_reconciliation_source_run TO directus_app;
GRANT SELECT ON TABLE ops.lor_reconciliation_source_run TO lor_preflight_app;


--
-- TOC entry 6323 (class 0 OID 0)
-- Dependencies: 460
-- Name: TABLE lor_reconciliation_source_scene; Type: ACL; Schema: ops; Owner: msbadmin
--

GRANT SELECT,INSERT,UPDATE ON TABLE ops.lor_reconciliation_source_scene TO directus_app;
GRANT SELECT ON TABLE ops.lor_reconciliation_source_scene TO lor_preflight_app;


--
-- TOC entry 6324 (class 0 OID 0)
-- Dependencies: 459
-- Name: SEQUENCE lor_reconciliation_source_sce_lor_reconciliation_source_sce_seq; Type: ACL; Schema: ops; Owner: msbadmin
--

GRANT SELECT,USAGE ON SEQUENCE ops.lor_reconciliation_source_sce_lor_reconciliation_source_sce_seq TO directus_app;


--
-- TOC entry 6326 (class 0 OID 0)
-- Dependencies: 448
-- Name: TABLE lor_reconciliation_stage_candidate; Type: ACL; Schema: ops; Owner: msbadmin
--

GRANT SELECT,INSERT,UPDATE ON TABLE ops.lor_reconciliation_stage_candidate TO directus_app;


--
-- TOC entry 6327 (class 0 OID 0)
-- Dependencies: 447
-- Name: SEQUENCE lor_reconciliation_stage_cand_lor_reconciliation_stage_cand_seq; Type: ACL; Schema: ops; Owner: msbadmin
--

GRANT SELECT,USAGE ON SEQUENCE ops.lor_reconciliation_stage_cand_lor_reconciliation_stage_cand_seq TO directus_app;


--
-- TOC entry 6328 (class 0 OID 0)
-- Dependencies: 303
-- Name: TABLE test_session; Type: ACL; Schema: ops; Owner: msbadmin
--

GRANT SELECT,INSERT,REFERENCES,DELETE,UPDATE ON TABLE ops.test_session TO directus_app;


--
-- TOC entry 6330 (class 0 OID 0)
-- Dependencies: 302
-- Name: SEQUENCE test_session_test_session_id_seq; Type: ACL; Schema: ops; Owner: msbadmin
--

GRANT SELECT,USAGE ON SEQUENCE ops.test_session_test_session_id_seq TO directus_app;


--
-- TOC entry 6331 (class 0 OID 0)
-- Dependencies: 403
-- Name: TABLE v_container_label_last_print; Type: ACL; Schema: ops; Owner: msbadmin
--

GRANT SELECT,INSERT,REFERENCES,UPDATE ON TABLE ops.v_container_label_last_print TO directus_app;


--
-- TOC entry 6332 (class 0 OID 0)
-- Dependencies: 281
-- Name: TABLE display_status; Type: ACL; Schema: ref; Owner: msbadmin
--

GRANT SELECT,INSERT,REFERENCES,DELETE,UPDATE ON TABLE ref.display_status TO directus_app;


--
-- TOC entry 6334 (class 0 OID 0)
-- Dependencies: 423
-- Name: TABLE v_lor_display_reconciliation; Type: ACL; Schema: ops; Owner: msbadmin
--

GRANT SELECT,INSERT,UPDATE ON TABLE ops.v_lor_display_reconciliation TO directus_app;


--
-- TOC entry 6336 (class 0 OID 0)
-- Dependencies: 462
-- Name: TABLE v_lor_reconciliation_display_name_change_audit; Type: ACL; Schema: ops; Owner: msbadmin
--

GRANT SELECT,INSERT,UPDATE ON TABLE ops.v_lor_reconciliation_display_name_change_audit TO directus_app;
GRANT SELECT ON TABLE ops.v_lor_reconciliation_display_name_change_audit TO lor_preflight_app;


--
-- TOC entry 6338 (class 0 OID 0)
-- Dependencies: 442
-- Name: TABLE v_lor_reconciliation_group_review; Type: ACL; Schema: ops; Owner: msbadmin
--

GRANT SELECT,INSERT,UPDATE ON TABLE ops.v_lor_reconciliation_group_review TO directus_app;
GRANT SELECT ON TABLE ops.v_lor_reconciliation_group_review TO lor_preflight_app;


--
-- TOC entry 6339 (class 0 OID 0)
-- Dependencies: 344
-- Name: TABLE stage; Type: ACL; Schema: ref; Owner: msbadmin
--

GRANT SELECT,REFERENCES ON TABLE ref.stage TO directus_app;
GRANT SELECT ON TABLE ref.stage TO lor_preflight_app;


--
-- TOC entry 6341 (class 0 OID 0)
-- Dependencies: 443
-- Name: TABLE v_lor_reconciliation_operator_display_review; Type: ACL; Schema: ops; Owner: msbadmin
--

GRANT SELECT,INSERT,UPDATE ON TABLE ops.v_lor_reconciliation_operator_display_review TO directus_app;
GRANT SELECT ON TABLE ops.v_lor_reconciliation_operator_display_review TO lor_preflight_app;


--
-- TOC entry 6342 (class 0 OID 0)
-- Dependencies: 455
-- Name: TABLE v_lor_reconciliation_operator_scene_display_review; Type: ACL; Schema: ops; Owner: msbadmin
--

GRANT SELECT,INSERT,UPDATE ON TABLE ops.v_lor_reconciliation_operator_scene_display_review TO directus_app;
GRANT SELECT ON TABLE ops.v_lor_reconciliation_operator_scene_display_review TO lor_preflight_app;


--
-- TOC entry 6343 (class 0 OID 0)
-- Dependencies: 454
-- Name: TABLE v_lor_reconciliation_operator_scene_review; Type: ACL; Schema: ops; Owner: msbadmin
--

GRANT SELECT,INSERT,UPDATE ON TABLE ops.v_lor_reconciliation_operator_scene_review TO directus_app;
GRANT SELECT ON TABLE ops.v_lor_reconciliation_operator_scene_review TO lor_preflight_app;


--
-- TOC entry 6344 (class 0 OID 0)
-- Dependencies: 449
-- Name: TABLE v_lor_reconciliation_operator_stage_review; Type: ACL; Schema: ops; Owner: msbadmin
--

GRANT SELECT,INSERT,UPDATE ON TABLE ops.v_lor_reconciliation_operator_stage_review TO directus_app;
GRANT SELECT ON TABLE ops.v_lor_reconciliation_operator_stage_review TO lor_preflight_app;


--
-- TOC entry 6346 (class 0 OID 0)
-- Dependencies: 444
-- Name: TABLE v_lor_reconciliation_run_review; Type: ACL; Schema: ops; Owner: msbadmin
--

GRANT SELECT,INSERT,UPDATE ON TABLE ops.v_lor_reconciliation_run_review TO directus_app;
GRANT SELECT ON TABLE ops.v_lor_reconciliation_run_review TO lor_preflight_app;


--
-- TOC entry 6347 (class 0 OID 0)
-- Dependencies: 461
-- Name: TABLE v_lor_reconciliation_source_run; Type: ACL; Schema: ops; Owner: msbadmin
--

GRANT SELECT,INSERT,UPDATE ON TABLE ops.v_lor_reconciliation_source_run TO directus_app;


--
-- TOC entry 6348 (class 0 OID 0)
-- Dependencies: 363
-- Name: TABLE v_stage_container_contents; Type: ACL; Schema: ops; Owner: msbadmin
--

GRANT SELECT,REFERENCES ON TABLE ops.v_stage_container_contents TO directus_app;


--
-- TOC entry 6349 (class 0 OID 0)
-- Dependencies: 364
-- Name: TABLE v_test_session_container_box; Type: ACL; Schema: ops; Owner: msbadmin
--

GRANT SELECT,INSERT,REFERENCES,UPDATE ON TABLE ops.v_test_session_container_box TO directus_app;


--
-- TOC entry 6350 (class 0 OID 0)
-- Dependencies: 365
-- Name: TABLE v_test_session_container_box_ui; Type: ACL; Schema: ops; Owner: msbadmin
--

GRANT SELECT,INSERT,REFERENCES,UPDATE ON TABLE ops.v_test_session_container_box_ui TO directus_app;


--
-- TOC entry 6351 (class 0 OID 0)
-- Dependencies: 368
-- Name: TABLE container_test_status; Type: ACL; Schema: ref; Owner: msbadmin
--

GRANT SELECT,INSERT,REFERENCES,DELETE,UPDATE ON TABLE ref.container_test_status TO directus_app;


--
-- TOC entry 6352 (class 0 OID 0)
-- Dependencies: 379
-- Name: TABLE v_test_session_insights; Type: ACL; Schema: ops; Owner: msbadmin
--

GRANT SELECT,INSERT,REFERENCES,UPDATE ON TABLE ops.v_test_session_insights TO directus_app;


--
-- TOC entry 6353 (class 0 OID 0)
-- Dependencies: 463
-- Name: TABLE v_work_order_assignment_test; Type: ACL; Schema: ops; Owner: msbadmin
--

GRANT SELECT,INSERT,UPDATE ON TABLE ops.v_work_order_assignment_test TO directus_app;


--
-- TOC entry 6355 (class 0 OID 0)
-- Dependencies: 378
-- Name: TABLE work_order_outbound_message; Type: ACL; Schema: ops; Owner: msbadmin
--

GRANT SELECT,INSERT,REFERENCES,DELETE,UPDATE ON TABLE ops.work_order_outbound_message TO directus_app;


--
-- TOC entry 6356 (class 0 OID 0)
-- Dependencies: 377
-- Name: SEQUENCE work_order_outbound_message_outbound_message_id_seq; Type: ACL; Schema: ops; Owner: msbadmin
--

GRANT SELECT,USAGE ON SEQUENCE ops.work_order_outbound_message_outbound_message_id_seq TO directus_app;


--
-- TOC entry 6357 (class 0 OID 0)
-- Dependencies: 376
-- Name: TABLE work_order_status_history; Type: ACL; Schema: ops; Owner: msbadmin
--

GRANT SELECT,INSERT,REFERENCES,DELETE,UPDATE ON TABLE ops.work_order_status_history TO directus_app;


--
-- TOC entry 6358 (class 0 OID 0)
-- Dependencies: 375
-- Name: SEQUENCE work_order_status_history_work_order_status_history_id_seq; Type: ACL; Schema: ops; Owner: msbadmin
--

GRANT SELECT,USAGE ON SEQUENCE ops.work_order_status_history_work_order_status_history_id_seq TO directus_app;


--
-- TOC entry 6361 (class 0 OID 0)
-- Dependencies: 311
-- Name: SEQUENCE directus_activity_id_seq; Type: ACL; Schema: public; Owner: directus_app
--

GRANT SELECT,USAGE ON SEQUENCE public.directus_activity_id_seq TO msbadmin;


--
-- TOC entry 6363 (class 0 OID 0)
-- Dependencies: 309
-- Name: SEQUENCE directus_fields_id_seq; Type: ACL; Schema: public; Owner: directus_app
--

GRANT SELECT,USAGE ON SEQUENCE public.directus_fields_id_seq TO msbadmin;


--
-- TOC entry 6365 (class 0 OID 0)
-- Dependencies: 329
-- Name: SEQUENCE directus_notifications_id_seq; Type: ACL; Schema: public; Owner: directus_app
--

GRANT SELECT,USAGE ON SEQUENCE public.directus_notifications_id_seq TO msbadmin;


--
-- TOC entry 6367 (class 0 OID 0)
-- Dependencies: 315
-- Name: SEQUENCE directus_permissions_id_seq; Type: ACL; Schema: public; Owner: directus_app
--

GRANT SELECT,USAGE ON SEQUENCE public.directus_permissions_id_seq TO msbadmin;


--
-- TOC entry 6369 (class 0 OID 0)
-- Dependencies: 317
-- Name: SEQUENCE directus_presets_id_seq; Type: ACL; Schema: public; Owner: directus_app
--

GRANT SELECT,USAGE ON SEQUENCE public.directus_presets_id_seq TO msbadmin;


--
-- TOC entry 6371 (class 0 OID 0)
-- Dependencies: 319
-- Name: SEQUENCE directus_relations_id_seq; Type: ACL; Schema: public; Owner: directus_app
--

GRANT SELECT,USAGE ON SEQUENCE public.directus_relations_id_seq TO msbadmin;


--
-- TOC entry 6373 (class 0 OID 0)
-- Dependencies: 321
-- Name: SEQUENCE directus_revisions_id_seq; Type: ACL; Schema: public; Owner: directus_app
--

GRANT SELECT,USAGE ON SEQUENCE public.directus_revisions_id_seq TO msbadmin;


--
-- TOC entry 6375 (class 0 OID 0)
-- Dependencies: 324
-- Name: SEQUENCE directus_settings_id_seq; Type: ACL; Schema: public; Owner: directus_app
--

GRANT SELECT,USAGE ON SEQUENCE public.directus_settings_id_seq TO msbadmin;


--
-- TOC entry 6376 (class 0 OID 0)
-- Dependencies: 295
-- Name: TABLE display_sheet_raw; Type: ACL; Schema: stage; Owner: msbadmin
--

GRANT SELECT ON TABLE stage.display_sheet_raw TO directus_app;


--
-- TOC entry 6377 (class 0 OID 0)
-- Dependencies: 384
-- Name: TABLE audit_collection_policy; Type: ACL; Schema: ref; Owner: msbadmin
--

GRANT SELECT,INSERT,REFERENCES,DELETE,UPDATE ON TABLE ref.audit_collection_policy TO directus_app;


--
-- TOC entry 6378 (class 0 OID 0)
-- Dependencies: 383
-- Name: SEQUENCE audit_collection_policy_audit_collection_policy_id_seq; Type: ACL; Schema: ref; Owner: msbadmin
--

GRANT SELECT,USAGE ON SEQUENCE ref.audit_collection_policy_audit_collection_policy_id_seq TO directus_app;


--
-- TOC entry 6380 (class 0 OID 0)
-- Dependencies: 381
-- Name: SEQUENCE container_container_id_seq; Type: ACL; Schema: ref; Owner: msbadmin
--

GRANT SELECT,USAGE ON SEQUENCE ref.container_container_id_seq TO directus_app;


--
-- TOC entry 6381 (class 0 OID 0)
-- Dependencies: 348
-- Name: TABLE container_endpoint; Type: ACL; Schema: ref; Owner: msbadmin
--

GRANT SELECT,INSERT,REFERENCES,DELETE,UPDATE ON TABLE ref.container_endpoint TO directus_app;


--
-- TOC entry 6383 (class 0 OID 0)
-- Dependencies: 380
-- Name: SEQUENCE container_endpoint_endpoint_id_seq; Type: ACL; Schema: ref; Owner: msbadmin
--

GRANT SELECT,USAGE ON SEQUENCE ref.container_endpoint_endpoint_id_seq TO directus_app;


--
-- TOC entry 6384 (class 0 OID 0)
-- Dependencies: 367
-- Name: SEQUENCE container_test_status_container_test_status_id_seq; Type: ACL; Schema: ref; Owner: msbadmin
--

GRANT ALL ON SEQUENCE ref.container_test_status_container_test_status_id_seq TO directus_app;


--
-- TOC entry 6385 (class 0 OID 0)
-- Dependencies: 385
-- Name: SEQUENCE container_test_status_id_seq; Type: ACL; Schema: ref; Owner: msbadmin
--

GRANT SELECT,USAGE ON SEQUENCE ref.container_test_status_id_seq TO directus_app;


--
-- TOC entry 6386 (class 0 OID 0)
-- Dependencies: 283
-- Name: TABLE container_type; Type: ACL; Schema: ref; Owner: msbadmin
--

GRANT SELECT,INSERT,REFERENCES,DELETE,UPDATE ON TABLE ref.container_type TO directus_app;


--
-- TOC entry 6387 (class 0 OID 0)
-- Dependencies: 388
-- Name: TABLE display_backup_20260317; Type: ACL; Schema: ref; Owner: msbadmin
--

GRANT SELECT,REFERENCES ON TABLE ref.display_backup_20260317 TO directus_app;


--
-- TOC entry 6388 (class 0 OID 0)
-- Dependencies: 392
-- Name: TABLE display_backup_20260318_after_run22_success; Type: ACL; Schema: ref; Owner: msbadmin
--

GRANT SELECT,REFERENCES ON TABLE ref.display_backup_20260318_after_run22_success TO directus_app;


--
-- TOC entry 6389 (class 0 OID 0)
-- Dependencies: 394
-- Name: TABLE display_backup_20260319_after_run23_baseline; Type: ACL; Schema: ref; Owner: msbadmin
--

GRANT SELECT,REFERENCES ON TABLE ref.display_backup_20260319_after_run23_baseline TO directus_app;


--
-- TOC entry 6390 (class 0 OID 0)
-- Dependencies: 398
-- Name: TABLE display_backup_20260319_before_run25_p2; Type: ACL; Schema: ref; Owner: msbadmin
--

GRANT SELECT,REFERENCES ON TABLE ref.display_backup_20260319_before_run25_p2 TO directus_app;


--
-- TOC entry 6391 (class 0 OID 0)
-- Dependencies: 396
-- Name: TABLE display_backup_20260319_run23_post_p2; Type: ACL; Schema: ref; Owner: msbadmin
--

GRANT SELECT,REFERENCES ON TABLE ref.display_backup_20260319_run23_post_p2 TO directus_app;


--
-- TOC entry 6392 (class 0 OID 0)
-- Dependencies: 429
-- Name: TABLE display_backup_20260802; Type: ACL; Schema: ref; Owner: msbadmin
--

GRANT SELECT ON TABLE ref.display_backup_20260802 TO directus_app;


--
-- TOC entry 6393 (class 0 OID 0)
-- Dependencies: 362
-- Name: SEQUENCE display_display_id_seq; Type: ACL; Schema: ref; Owner: msbadmin
--

GRANT ALL ON SEQUENCE ref.display_display_id_seq TO directus_app;


--
-- TOC entry 6394 (class 0 OID 0)
-- Dependencies: 280
-- Name: SEQUENCE display_status_display_status_id_seq; Type: ACL; Schema: ref; Owner: msbadmin
--

GRANT ALL ON SEQUENCE ref.display_status_display_status_id_seq TO directus_app;


--
-- TOC entry 6395 (class 0 OID 0)
-- Dependencies: 366
-- Name: TABLE display_test_status; Type: ACL; Schema: ref; Owner: msbadmin
--

GRANT SELECT,INSERT,REFERENCES,DELETE,UPDATE ON TABLE ref.display_test_status TO directus_app;


--
-- TOC entry 6396 (class 0 OID 0)
-- Dependencies: 277
-- Name: TABLE frame; Type: ACL; Schema: ref; Owner: msbadmin
--

GRANT SELECT,INSERT,REFERENCES,DELETE,UPDATE ON TABLE ref.frame TO directus_app;


--
-- TOC entry 6397 (class 0 OID 0)
-- Dependencies: 276
-- Name: SEQUENCE frame_frame_id_seq; Type: ACL; Schema: ref; Owner: msbadmin
--

GRANT ALL ON SEQUENCE ref.frame_frame_id_seq TO directus_app;


--
-- TOC entry 6398 (class 0 OID 0)
-- Dependencies: 292
-- Name: TABLE inventory_type; Type: ACL; Schema: ref; Owner: msbadmin
--

GRANT SELECT,INSERT,REFERENCES,DELETE,UPDATE ON TABLE ref.inventory_type TO directus_app;


--
-- TOC entry 6402 (class 0 OID 0)
-- Dependencies: 427
-- Name: TABLE lor_scene; Type: ACL; Schema: ref; Owner: msbadmin
--

GRANT SELECT ON TABLE ref.lor_scene TO directus_app;
GRANT SELECT ON TABLE ref.lor_scene TO lor_preflight_app;


--
-- TOC entry 6405 (class 0 OID 0)
-- Dependencies: 428
-- Name: TABLE lor_scene_display; Type: ACL; Schema: ref; Owner: msbadmin
--

GRANT SELECT ON TABLE ref.lor_scene_display TO directus_app;


--
-- TOC entry 6406 (class 0 OID 0)
-- Dependencies: 426
-- Name: SEQUENCE lor_scene_lor_scene_id_seq; Type: ACL; Schema: ref; Owner: msbadmin
--

GRANT SELECT,USAGE ON SEQUENCE ref.lor_scene_lor_scene_id_seq TO directus_app;


--
-- TOC entry 6407 (class 0 OID 0)
-- Dependencies: 282
-- Name: SEQUENCE pallet_type_pallet_type_id_seq; Type: ACL; Schema: ref; Owner: msbadmin
--

GRANT ALL ON SEQUENCE ref.pallet_type_pallet_type_id_seq TO directus_app;


--
-- TOC entry 6408 (class 0 OID 0)
-- Dependencies: 288
-- Name: TABLE person; Type: ACL; Schema: ref; Owner: msbadmin
--

GRANT SELECT,INSERT,REFERENCES,DELETE,UPDATE ON TABLE ref.person TO directus_app;
GRANT SELECT ON TABLE ref.person TO printservice;


--
-- TOC entry 6410 (class 0 OID 0)
-- Dependencies: 382
-- Name: SEQUENCE person_person_id_seq; Type: ACL; Schema: ref; Owner: msbadmin
--

GRANT SELECT,USAGE ON SEQUENCE ref.person_person_id_seq TO directus_app;


--
-- TOC entry 6411 (class 0 OID 0)
-- Dependencies: 290
-- Name: TABLE person_xref; Type: ACL; Schema: ref; Owner: msbadmin
--

GRANT SELECT,REFERENCES ON TABLE ref.person_xref TO directus_app;


--
-- TOC entry 6412 (class 0 OID 0)
-- Dependencies: 386
-- Name: TABLE season; Type: ACL; Schema: ref; Owner: msbadmin
--

GRANT SELECT,REFERENCES ON TABLE ref.season TO directus_app;


--
-- TOC entry 6413 (class 0 OID 0)
-- Dependencies: 355
-- Name: TABLE spare_channel; Type: ACL; Schema: ref; Owner: msbadmin
--

GRANT SELECT,REFERENCES ON TABLE ref.spare_channel TO directus_app;


--
-- TOC entry 6414 (class 0 OID 0)
-- Dependencies: 389
-- Name: TABLE spare_channel_backup_20260317; Type: ACL; Schema: ref; Owner: msbadmin
--

GRANT SELECT,REFERENCES ON TABLE ref.spare_channel_backup_20260317 TO directus_app;


--
-- TOC entry 6415 (class 0 OID 0)
-- Dependencies: 393
-- Name: TABLE spare_channel_backup_20260318_after_run22_success; Type: ACL; Schema: ref; Owner: msbadmin
--

GRANT SELECT,REFERENCES ON TABLE ref.spare_channel_backup_20260318_after_run22_success TO directus_app;


--
-- TOC entry 6416 (class 0 OID 0)
-- Dependencies: 390
-- Name: TABLE spare_channel_backup_20260318_lor_raw_fix; Type: ACL; Schema: ref; Owner: msbadmin
--

GRANT SELECT,REFERENCES ON TABLE ref.spare_channel_backup_20260318_lor_raw_fix TO directus_app;


--
-- TOC entry 6417 (class 0 OID 0)
-- Dependencies: 391
-- Name: TABLE spare_channel_backup_20260318_partial_raw_restore; Type: ACL; Schema: ref; Owner: msbadmin
--

GRANT SELECT,REFERENCES ON TABLE ref.spare_channel_backup_20260318_partial_raw_restore TO directus_app;


--
-- TOC entry 6418 (class 0 OID 0)
-- Dependencies: 395
-- Name: TABLE spare_channel_backup_20260319_after_run23_baseline; Type: ACL; Schema: ref; Owner: msbadmin
--

GRANT SELECT,REFERENCES ON TABLE ref.spare_channel_backup_20260319_after_run23_baseline TO directus_app;


--
-- TOC entry 6419 (class 0 OID 0)
-- Dependencies: 397
-- Name: TABLE spare_channel_backup_20260319_before_run24_p2; Type: ACL; Schema: ref; Owner: msbadmin
--

GRANT SELECT,REFERENCES ON TABLE ref.spare_channel_backup_20260319_before_run24_p2 TO directus_app;


--
-- TOC entry 6420 (class 0 OID 0)
-- Dependencies: 345
-- Name: TABLE stage_history; Type: ACL; Schema: ref; Owner: msbadmin
--

GRANT SELECT,REFERENCES ON TABLE ref.stage_history TO directus_app;


--
-- TOC entry 6422 (class 0 OID 0)
-- Dependencies: 446
-- Name: TABLE stage_lor_binding; Type: ACL; Schema: ref; Owner: msbadmin
--

GRANT SELECT ON TABLE ref.stage_lor_binding TO directus_app;


--
-- TOC entry 6423 (class 0 OID 0)
-- Dependencies: 445
-- Name: SEQUENCE stage_lor_binding_stage_lor_binding_id_seq; Type: ACL; Schema: ref; Owner: msbadmin
--

GRANT SELECT,USAGE ON SEQUENCE ref.stage_lor_binding_stage_lor_binding_id_seq TO directus_app;


--
-- TOC entry 6425 (class 0 OID 0)
-- Dependencies: 346
-- Name: SEQUENCE stage_stage_id_seq; Type: ACL; Schema: ref; Owner: msbadmin
--

GRANT ALL ON SEQUENCE ref.stage_stage_id_seq TO directus_app;


--
-- TOC entry 6426 (class 0 OID 0)
-- Dependencies: 285
-- Name: TABLE storage_location; Type: ACL; Schema: ref; Owner: msbadmin
--

GRANT SELECT,INSERT,REFERENCES,DELETE,UPDATE ON TABLE ref.storage_location TO directus_app;


--
-- TOC entry 6427 (class 0 OID 0)
-- Dependencies: 350
-- Name: TABLE task_type; Type: ACL; Schema: ref; Owner: msbadmin
--

GRANT SELECT,INSERT,REFERENCES,DELETE,UPDATE ON TABLE ref.task_type TO directus_app;


--
-- TOC entry 6429 (class 0 OID 0)
-- Dependencies: 349
-- Name: SEQUENCE task_type_task_type_id_seq; Type: ACL; Schema: ref; Owner: msbadmin
--

GRANT ALL ON SEQUENCE ref.task_type_task_type_id_seq TO directus_app;


--
-- TOC entry 6430 (class 0 OID 0)
-- Dependencies: 279
-- Name: TABLE theme; Type: ACL; Schema: ref; Owner: msbadmin
--

GRANT SELECT,INSERT,REFERENCES,DELETE,UPDATE ON TABLE ref.theme TO directus_app;


--
-- TOC entry 6431 (class 0 OID 0)
-- Dependencies: 278
-- Name: SEQUENCE theme_theme_pk_seq; Type: ACL; Schema: ref; Owner: msbadmin
--

GRANT ALL ON SEQUENCE ref.theme_theme_pk_seq TO directus_app;


--
-- TOC entry 6432 (class 0 OID 0)
-- Dependencies: 387
-- Name: TABLE urgency; Type: ACL; Schema: ref; Owner: msbadmin
--

GRANT SELECT,REFERENCES ON TABLE ref.urgency TO directus_app;


--
-- TOC entry 6433 (class 0 OID 0)
-- Dependencies: 352
-- Name: TABLE work_area; Type: ACL; Schema: ref; Owner: msbadmin
--

GRANT SELECT,INSERT,REFERENCES,DELETE,UPDATE ON TABLE ref.work_area TO directus_app;


--
-- TOC entry 6435 (class 0 OID 0)
-- Dependencies: 351
-- Name: SEQUENCE work_area_work_area_id_seq; Type: ACL; Schema: ref; Owner: msbadmin
--

GRANT ALL ON SEQUENCE ref.work_area_work_area_id_seq TO directus_app;


--
-- TOC entry 6436 (class 0 OID 0)
-- Dependencies: 370
-- Name: TABLE work_order_status; Type: ACL; Schema: ref; Owner: msbadmin
--

GRANT SELECT,INSERT,REFERENCES,DELETE,UPDATE ON TABLE ref.work_order_status TO directus_app;


--
-- TOC entry 6437 (class 0 OID 0)
-- Dependencies: 369
-- Name: SEQUENCE work_order_status_work_order_status_id_seq; Type: ACL; Schema: ref; Owner: msbadmin
--

GRANT ALL ON SEQUENCE ref.work_order_status_work_order_status_id_seq TO directus_app;


--
-- TOC entry 6438 (class 0 OID 0)
-- Dependencies: 294
-- Name: TABLE display_sheet_csv; Type: ACL; Schema: stage; Owner: msbadmin
--

GRANT SELECT ON TABLE stage.display_sheet_csv TO directus_app;


--
-- TOC entry 6439 (class 0 OID 0)
-- Dependencies: 286
-- Name: TABLE location_raw_full; Type: ACL; Schema: stage; Owner: msbadmin
--

GRANT SELECT ON TABLE stage.location_raw_full TO directus_app;


--
-- TOC entry 6440 (class 0 OID 0)
-- Dependencies: 347
-- Name: TABLE pallet_raw_2026; Type: ACL; Schema: stage; Owner: msbadmin
--

GRANT SELECT ON TABLE stage.pallet_raw_2026 TO directus_app;


--
-- TOC entry 6441 (class 0 OID 0)
-- Dependencies: 343
-- Name: TABLE test_plan_2026_raw; Type: ACL; Schema: stage; Owner: msbadmin
--

GRANT SELECT ON TABLE stage.test_plan_2026_raw TO directus_app;


--
-- TOC entry 6442 (class 0 OID 0)
-- Dependencies: 297
-- Name: TABLE v_sheet_match; Type: ACL; Schema: stage; Owner: msbadmin
--

GRANT SELECT ON TABLE stage.v_sheet_match TO directus_app;


--
-- TOC entry 6443 (class 0 OID 0)
-- Dependencies: 359
-- Name: TABLE work_order_completed_raw; Type: ACL; Schema: stage; Owner: msbadmin
--

GRANT SELECT ON TABLE stage.work_order_completed_raw TO directus_app;


--
-- TOC entry 6444 (class 0 OID 0)
-- Dependencies: 357
-- Name: TABLE work_order_todo_raw; Type: ACL; Schema: stage; Owner: msbadmin
--

GRANT SELECT ON TABLE stage.work_order_todo_raw TO directus_app;


--
-- TOC entry 6445 (class 0 OID 0)
-- Dependencies: 360
-- Name: TABLE v_work_order_all_raw; Type: ACL; Schema: stage; Owner: msbadmin
--

GRANT SELECT ON TABLE stage.v_work_order_all_raw TO directus_app;


--
-- TOC entry 6446 (class 0 OID 0)
-- Dependencies: 287
-- Name: TABLE val_stages_raw; Type: ACL; Schema: stage; Owner: msbadmin
--

GRANT SELECT ON TABLE stage.val_stages_raw TO directus_app;


--
-- TOC entry 6447 (class 0 OID 0)
-- Dependencies: 289
-- Name: TABLE val_user_raw; Type: ACL; Schema: stage; Owner: msbadmin
--

GRANT SELECT ON TABLE stage.val_user_raw TO directus_app;


--
-- TOC entry 6449 (class 0 OID 0)
-- Dependencies: 358
-- Name: SEQUENCE work_order_completed_raw_src_row_num_seq; Type: ACL; Schema: stage; Owner: msbadmin
--

GRANT ALL ON SEQUENCE stage.work_order_completed_raw_src_row_num_seq TO directus_app;


--
-- TOC entry 6454 (class 0 OID 0)
-- Dependencies: 356
-- Name: SEQUENCE work_order_todo_raw_src_row_num_seq; Type: ACL; Schema: stage; Owner: msbadmin
--

GRANT ALL ON SEQUENCE stage.work_order_todo_raw_src_row_num_seq TO directus_app;


--
-- TOC entry 3697 (class 826 OID 17316)
-- Name: DEFAULT PRIVILEGES FOR SEQUENCES; Type: DEFAULT ACL; Schema: lor_snap; Owner: msbadmin
--

ALTER DEFAULT PRIVILEGES FOR ROLE msbadmin IN SCHEMA lor_snap GRANT SELECT,USAGE ON SEQUENCES TO directus_app;


--
-- TOC entry 3698 (class 826 OID 17312)
-- Name: DEFAULT PRIVILEGES FOR TABLES; Type: DEFAULT ACL; Schema: lor_snap; Owner: msbadmin
--

ALTER DEFAULT PRIVILEGES FOR ROLE msbadmin IN SCHEMA lor_snap GRANT SELECT ON TABLES TO directus_app;


--
-- TOC entry 3703 (class 826 OID 17317)
-- Name: DEFAULT PRIVILEGES FOR SEQUENCES; Type: DEFAULT ACL; Schema: ops; Owner: msbadmin
--

ALTER DEFAULT PRIVILEGES FOR ROLE msbadmin IN SCHEMA ops GRANT SELECT,USAGE ON SEQUENCES TO directus_app;


--
-- TOC entry 3705 (class 826 OID 18829)
-- Name: DEFAULT PRIVILEGES FOR FUNCTIONS; Type: DEFAULT ACL; Schema: ops; Owner: msbadmin
--

ALTER DEFAULT PRIVILEGES FOR ROLE msbadmin IN SCHEMA ops GRANT ALL ON FUNCTIONS TO directus_app;


--
-- TOC entry 3700 (class 826 OID 17313)
-- Name: DEFAULT PRIVILEGES FOR TABLES; Type: DEFAULT ACL; Schema: ops; Owner: msbadmin
--

ALTER DEFAULT PRIVILEGES FOR ROLE msbadmin IN SCHEMA ops GRANT SELECT,INSERT,UPDATE ON TABLES TO directus_app;


--
-- TOC entry 3702 (class 826 OID 17318)
-- Name: DEFAULT PRIVILEGES FOR SEQUENCES; Type: DEFAULT ACL; Schema: ref; Owner: msbadmin
--

ALTER DEFAULT PRIVILEGES FOR ROLE msbadmin IN SCHEMA ref GRANT SELECT,USAGE ON SEQUENCES TO directus_app;


--
-- TOC entry 3704 (class 826 OID 18828)
-- Name: DEFAULT PRIVILEGES FOR FUNCTIONS; Type: DEFAULT ACL; Schema: ref; Owner: msbadmin
--

ALTER DEFAULT PRIVILEGES FOR ROLE msbadmin IN SCHEMA ref GRANT ALL ON FUNCTIONS TO directus_app;


--
-- TOC entry 3699 (class 826 OID 17314)
-- Name: DEFAULT PRIVILEGES FOR TABLES; Type: DEFAULT ACL; Schema: ref; Owner: msbadmin
--

ALTER DEFAULT PRIVILEGES FOR ROLE msbadmin IN SCHEMA ref GRANT SELECT ON TABLES TO directus_app;


--
-- TOC entry 3706 (class 826 OID 17319)
-- Name: DEFAULT PRIVILEGES FOR SEQUENCES; Type: DEFAULT ACL; Schema: stage; Owner: msbadmin
--

ALTER DEFAULT PRIVILEGES FOR ROLE msbadmin IN SCHEMA stage GRANT ALL ON SEQUENCES TO directus_app;


--
-- TOC entry 3701 (class 826 OID 17315)
-- Name: DEFAULT PRIVILEGES FOR TABLES; Type: DEFAULT ACL; Schema: stage; Owner: msbadmin
--

ALTER DEFAULT PRIVILEGES FOR ROLE msbadmin IN SCHEMA stage GRANT SELECT ON TABLES TO directus_app;


-- Completed on 2026-08-08 09:11:00

--
-- PostgreSQL database dump complete
--

\unrestrict wEr6hZXM5sd1EZLTBKaohjVXvnTneS8LdnM1jHe5E9xDvew41l8Pa9d4Pa4Uq3w

