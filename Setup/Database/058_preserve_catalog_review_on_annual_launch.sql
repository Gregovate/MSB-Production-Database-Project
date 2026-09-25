/* ============================================================================
Setup #122 — preserve accepted Catalog review when launching annual planning
Revision: 2026-09-24

Purpose:
  - the reconstructed reusable Catalog has already been reviewed before launch;
  - a new real PLANNING/ACTIVE annual Session must not make every accepted
    reusable task appear UNVERIFIED again;
  - HISTORICAL_VERIFICATION keeps its review semantics;
  - reusable tasks added after launch follow the same Session-status rule.

Boundary:
  - this does not rewrite existing annual history;
  - this changes only future inserts performed by the two governed commands.
============================================================================ */

BEGIN;

DO $preflight$
BEGIN
    IF to_regprocedure('ops.create_setup_session(text,integer,text)') IS NULL
       OR to_regprocedure('ref.create_setup_task(text,text,integer,text,integer,integer,integer,integer,text,text,text,text)') IS NULL
       OR to_regclass('ops.setup_session_task') IS NULL THEN
        RAISE EXCEPTION 'Setup #122 annual launch verification prerequisites are incomplete';
    END IF;

    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'fieldwiring_app') THEN
        RAISE EXCEPTION 'Required application role fieldwiring_app is missing';
    END IF;
END
$preflight$;

CREATE OR REPLACE FUNCTION ops.create_setup_session(
    p_email text,
    p_season_year integer,
    p_session_status text DEFAULT 'PLANNING'
)
RETURNS TABLE (
    setup_session_id bigint,
    seeded_task_count integer,
    seeded_display_count integer,
    seeded_container_count integer,
    operator_display_name text
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, ops, ref
AS $function$
DECLARE
    v_directus_user_id uuid;
    v_person_id integer;
    v_display_name text;
    v_session_id bigint;
    v_status text := upper(btrim(coalesce(p_session_status, 'PLANNING')));
    v_task_count integer := 0;
    v_display_count integer := 0;
    v_container_count integer := 0;
BEGIN
    SELECT a.directus_user_id, a.person_id, a.display_name
      INTO v_directus_user_id, v_person_id, v_display_name
    FROM ref.setup_management_actor(p_email, true) AS a;

    IF NOT EXISTS (
        SELECT 1 FROM ref.season s WHERE s.season_year = p_season_year
    ) THEN
        RAISE EXCEPTION USING ERRCODE = '22023',
            MESSAGE = format('Season %s does not exist in ref.season', p_season_year);
    END IF;

    IF v_status NOT IN ('HISTORICAL_VERIFICATION', 'PLANNING', 'ACTIVE') THEN
        RAISE EXCEPTION USING ERRCODE = '22023',
            MESSAGE = 'New Setup Session status must be HISTORICAL_VERIFICATION, PLANNING, or ACTIVE';
    END IF;

    IF EXISTS (
        SELECT 1 FROM ops.setup_session s WHERE s.season_year = p_season_year
    ) THEN
        RAISE EXCEPTION USING ERRCODE = '23505',
            MESSAGE = format('Setup Session for season %s already exists', p_season_year);
    END IF;

    PERFORM pg_catalog.set_config(
        'app.directus_user_uuid',
        v_directus_user_id::text,
        true
    );

    INSERT INTO ops.setup_session(season_year, session_status)
    VALUES (p_season_year, v_status)
    RETURNING ops.setup_session.setup_session_id INTO v_session_id;

    INSERT INTO ops.setup_session_task(
        setup_session_id,
        setup_task_id,
        verification_state
    )
    SELECT
        v_session_id,
        t.setup_task_id,
        CASE
            WHEN v_status = 'HISTORICAL_VERIFICATION' THEN 'UNVERIFIED'
            ELSE 'VERIFIED'
        END
    FROM ref.setup_task t
    WHERE t.active_flag
    ORDER BY t.display_order, t.setup_task_id;
    GET DIAGNOSTICS v_task_count = ROW_COUNT;

    /* Seed annual position mode only. Do NOT copy container_id into annual state. */
    INSERT INTO ops.setup_display_state(setup_session_id, display_id)
    SELECT v_session_id, d.display_id
    FROM ref.display d
    JOIN ref.display_status ds
      ON ds.display_status_id = d.display_status_id
    WHERE ds.display_status_name <> 'RECYCLED'
    ORDER BY d.display_id;
    GET DIAGNOSTICS v_display_count = ROW_COUNT;

    INSERT INTO ops.setup_container_state(setup_session_id, container_id)
    SELECT v_session_id, c.container_id
    FROM ref.container c
    ORDER BY c.container_id;
    GET DIAGNOSTICS v_container_count = ROW_COUNT;

    RETURN QUERY
    SELECT v_session_id, v_task_count, v_display_count, v_container_count, v_display_name;
END;
$function$;

REVOKE ALL ON FUNCTION ops.create_setup_session(text, integer, text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION ops.create_setup_session(text, integer, text) TO fieldwiring_app;

CREATE OR REPLACE FUNCTION ref.create_setup_task(
    p_email text,
    p_task_name text,
    p_stage_id integer,
    p_task_action_type text,
    p_display_order integer,
    p_normal_crew_min integer,
    p_normal_crew_max integer,
    p_expected_duration_minutes integer,
    p_completion_point text,
    p_readiness_note text,
    p_weather_note text,
    p_reusable_notes text
)
RETURNS TABLE (
    setup_task_id bigint,
    operator_display_name text
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, ref, ops
AS $function$
DECLARE
    v_directus_user_id uuid;
    v_person_id integer;
    v_display_name text;
    v_task_id bigint;
    v_name text := nullif(btrim(p_task_name), '');
    v_action text := upper(btrim(coalesce(p_task_action_type, 'WORK')));
BEGIN
    SELECT a.directus_user_id, a.person_id, a.display_name
      INTO v_directus_user_id, v_person_id, v_display_name
    FROM ref.setup_management_actor(p_email, false) AS a;

    IF v_name IS NULL THEN
        RAISE EXCEPTION USING ERRCODE = '22023', MESSAGE = 'Setup task name is required';
    END IF;

    PERFORM pg_catalog.set_config(
        'app.directus_user_uuid',
        v_directus_user_id::text,
        true
    );

    INSERT INTO ref.setup_task(
        task_name,
        stage_id,
        task_action_type,
        display_order,
        normal_crew_min,
        normal_crew_max,
        expected_duration_minutes,
        completion_point,
        readiness_note,
        weather_note,
        reusable_notes
    ) VALUES (
        v_name,
        p_stage_id,
        v_action,
        coalesce(p_display_order, 100),
        p_normal_crew_min,
        p_normal_crew_max,
        p_expected_duration_minutes,
        nullif(btrim(p_completion_point), ''),
        nullif(btrim(p_readiness_note), ''),
        nullif(btrim(p_weather_note), ''),
        nullif(btrim(p_reusable_notes), '')
    )
    RETURNING ref.setup_task.setup_task_id INTO v_task_id;

    /* New reusable work is automatically presented in any still-open Setup
       Session. Naming the unique constraint avoids PL/pgSQL output-column
       ambiguity while retaining the original idempotent behavior. */
    INSERT INTO ops.setup_session_task(
        setup_session_id,
        setup_task_id,
        verification_state
    )
    SELECT
        s.setup_session_id,
        v_task_id,
        CASE
            WHEN s.session_status = 'HISTORICAL_VERIFICATION' THEN 'UNVERIFIED'
            ELSE 'VERIFIED'
        END
    FROM ops.setup_session s
    WHERE s.session_status <> 'COMPLETE'
    ON CONFLICT ON CONSTRAINT uq_setup_session_task DO NOTHING;

    RETURN QUERY SELECT v_task_id, v_display_name;
END;
$function$;

REVOKE ALL ON FUNCTION ref.create_setup_task(
    text, text, integer, text, integer, integer, integer, integer,
    text, text, text, text
) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION ref.create_setup_task(
    text, text, integer, text, integer, integer, integer, integer,
    text, text, text, text
) TO fieldwiring_app;

COMMIT;

SELECT
    to_regprocedure('ops.create_setup_session(text,integer,text)') IS NOT NULL
        AS create_session_ready,
    to_regprocedure('ref.create_setup_task(text,text,integer,text,integer,integer,integer,integer,text,text,text,text)') IS NOT NULL
        AS create_reusable_task_ready;
