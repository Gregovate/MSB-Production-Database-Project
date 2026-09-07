/* ============================================================================
MSB Setup Session — protected Manager/Admin commands
Issue: #122
Status: IMPLEMENTATION CANDIDATE — DO NOT APPLY TO PRODUCTION WITHOUT REVIEW
Revision: 2026-09-06 V0.1.0

Purpose:
  Provide the narrow server-side write boundary for the first production Setup
  Manager workflow. Follows the accepted Controller Management pattern.

Security:
  - Cloudflare Access authenticates browser user; backend passes trusted email.
  - Directus role/policy data is rechecked inside SECURITY DEFINER functions.
  - Human writes fail closed unless Directus user maps to ref.person.
  - app.directus_user_uuid is transaction-local so existing actor triggers stamp
    the authoritative person identity.
  - fieldwiring_app receives EXECUTE only on narrow commands; no broad table DML.
============================================================================ */

BEGIN;

DO $preflight$
BEGIN
    IF to_regclass('ref.setup_task') IS NULL
       OR to_regclass('ops.setup_session') IS NULL
       OR to_regclass('ops.setup_session_task') IS NULL
       OR to_regclass('ops.setup_display_state') IS NULL
       OR to_regclass('ops.setup_container_state') IS NULL
       OR to_regclass('ref.display') IS NULL
       OR to_regclass('ref.display_status') IS NULL
       OR to_regclass('ref.container') IS NULL
       OR to_regclass('ref.person') IS NULL
       OR to_regclass('ref.season') IS NULL THEN
        RAISE EXCEPTION 'Setup Session core schema and permanent dependencies are required first';
    END IF;

    IF to_regprocedure('ref.setup_browser_capabilities(text)') IS NULL THEN
        RAISE EXCEPTION 'ref.setup_browser_capabilities(text) is required first';
    END IF;

    IF to_regprocedure('ref.set_actor_on_insert()') IS NULL
       OR to_regprocedure('ref.set_actor_on_update()') IS NULL THEN
        RAISE EXCEPTION 'Existing MSB actor/audit functions are required';
    END IF;

    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'fieldwiring_app') THEN
        RAISE EXCEPTION 'Required existing application role fieldwiring_app does not exist';
    END IF;
END
$preflight$;

CREATE OR REPLACE FUNCTION ref.setup_management_actor(
    p_email text,
    p_require_admin boolean DEFAULT false
)
RETURNS TABLE (
    directus_user_id uuid,
    person_id integer,
    display_name text,
    can_admin_setup boolean
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = pg_catalog, ref
AS $function$
DECLARE
    v_email text := lower(btrim(p_email));
    v_directus_user_id uuid;
    v_person_id integer;
    v_display_name text;
    v_can_manage boolean := false;
    v_can_admin boolean := false;
BEGIN
    IF v_email IS NULL OR v_email = '' THEN
        RAISE EXCEPTION USING
            ERRCODE = '42501',
            MESSAGE = 'Authenticated Setup operator email is required';
    END IF;

    SELECT
        u.id,
        c.display_name,
        c.can_manage_setup,
        c.can_admin_setup
      INTO
        v_directus_user_id,
        v_display_name,
        v_can_manage,
        v_can_admin
    FROM public.directus_users AS u
    JOIN LATERAL ref.setup_browser_capabilities(v_email) AS c ON true
    WHERE u.status = 'active'
      AND lower(u.email) = v_email
    LIMIT 1;

    IF v_directus_user_id IS NULL OR coalesce(v_can_manage, false) IS NOT TRUE THEN
        RAISE EXCEPTION USING
            ERRCODE = '42501',
            MESSAGE = 'Setup maintenance is not authorized for this account';
    END IF;

    IF coalesce(p_require_admin, false) AND coalesce(v_can_admin, false) IS NOT TRUE THEN
        RAISE EXCEPTION USING
            ERRCODE = '42501',
            MESSAGE = 'Setup Session creation requires Administrator access';
    END IF;

    SELECT p.person_id
      INTO v_person_id
    FROM ref.person AS p
    WHERE p.directus_user_id = v_directus_user_id
    LIMIT 1;

    IF v_person_id IS NULL THEN
        RAISE EXCEPTION USING
            ERRCODE = '42501',
            MESSAGE = 'Authenticated Setup operator is not mapped to an MSB person';
    END IF;

    RETURN QUERY
    SELECT
        v_directus_user_id,
        v_person_id,
        coalesce(nullif(btrim(v_display_name), ''), v_email),
        coalesce(v_can_admin, false);
END;
$function$;

REVOKE ALL ON FUNCTION ref.setup_management_actor(text, boolean) FROM PUBLIC;
REVOKE ALL ON FUNCTION ref.setup_management_actor(text, boolean) FROM fieldwiring_app;

/* --------------------------------------------------------------------------
   ADMIN: CREATE ONE ANNUAL SETUP SESSION
   -------------------------------------------------------------------------- */

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

    INSERT INTO ops.setup_session_task(setup_session_id, setup_task_id)
    SELECT v_session_id, t.setup_task_id
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

/* --------------------------------------------------------------------------
   MANAGER: CREATE / UPDATE REUSABLE TASKS
   -------------------------------------------------------------------------- */

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

    /* New reusable work is automatically presented in any still-open Setup Session. */
    INSERT INTO ops.setup_session_task(setup_session_id, setup_task_id)
    SELECT s.setup_session_id, v_task_id
    FROM ops.setup_session s
    WHERE s.session_status <> 'COMPLETE'
    ON CONFLICT (setup_session_id, setup_task_id) DO NOTHING;

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

CREATE OR REPLACE FUNCTION ref.update_setup_task(
    p_email text,
    p_setup_task_id bigint,
    p_task_name text,
    p_stage_id integer,
    p_task_action_type text,
    p_display_order integer,
    p_active_flag boolean,
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
SET search_path = pg_catalog, ref
AS $function$
DECLARE
    v_directus_user_id uuid;
    v_person_id integer;
    v_display_name text;
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

    UPDATE ref.setup_task t
       SET task_name = v_name,
           stage_id = p_stage_id,
           task_action_type = v_action,
           display_order = coalesce(p_display_order, t.display_order),
           active_flag = coalesce(p_active_flag, t.active_flag),
           normal_crew_min = p_normal_crew_min,
           normal_crew_max = p_normal_crew_max,
           expected_duration_minutes = p_expected_duration_minutes,
           completion_point = nullif(btrim(p_completion_point), ''),
           readiness_note = nullif(btrim(p_readiness_note), ''),
           weather_note = nullif(btrim(p_weather_note), ''),
           reusable_notes = nullif(btrim(p_reusable_notes), '')
     WHERE t.setup_task_id = p_setup_task_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION USING ERRCODE = 'P0002', MESSAGE = 'Setup task was not found';
    END IF;

    RETURN QUERY SELECT p_setup_task_id, v_display_name;
END;
$function$;

REVOKE ALL ON FUNCTION ref.update_setup_task(
    text, bigint, text, integer, text, integer, boolean, integer, integer,
    integer, text, text, text, text
) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION ref.update_setup_task(
    text, bigint, text, integer, text, integer, boolean, integer, integer,
    integer, text, text, text, text
) TO fieldwiring_app;

/* --------------------------------------------------------------------------
   MANAGER: ANNUAL VERIFICATION / ACTUALS
   -------------------------------------------------------------------------- */

CREATE OR REPLACE FUNCTION ops.update_setup_session_task_review(
    p_email text,
    p_setup_session_task_id bigint,
    p_verification_state text,
    p_actual_started_at timestamptz,
    p_actual_completed_at timestamptz,
    p_actual_crew_count integer,
    p_actual_duration_minutes integer,
    p_annual_notes text
)
RETURNS TABLE (
    setup_session_task_id bigint,
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
    v_verification text := upper(btrim(coalesce(p_verification_state, 'UNVERIFIED')));
BEGIN
    SELECT a.directus_user_id, a.person_id, a.display_name
      INTO v_directus_user_id, v_person_id, v_display_name
    FROM ref.setup_management_actor(p_email, false) AS a;

    IF v_verification NOT IN ('UNVERIFIED', 'VERIFIED', 'NEEDS_CORRECTION') THEN
        RAISE EXCEPTION USING ERRCODE = '22023', MESSAGE = 'Invalid Setup verification state';
    END IF;

    PERFORM pg_catalog.set_config(
        'app.directus_user_uuid',
        v_directus_user_id::text,
        true
    );

    UPDATE ops.setup_session_task st
       SET verification_state = v_verification,
           actual_started_at = p_actual_started_at,
           actual_completed_at = p_actual_completed_at,
           actual_crew_count = p_actual_crew_count,
           actual_duration_minutes = p_actual_duration_minutes,
           annual_notes = nullif(btrim(p_annual_notes), '')
     WHERE st.setup_session_task_id = p_setup_session_task_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION USING ERRCODE = 'P0002', MESSAGE = 'Setup annual task was not found';
    END IF;

    RETURN QUERY SELECT p_setup_session_task_id, v_display_name;
END;
$function$;

REVOKE ALL ON FUNCTION ops.update_setup_session_task_review(
    text, bigint, text, timestamptz, timestamptz, integer, integer, text
) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION ops.update_setup_session_task_review(
    text, bigint, text, timestamptz, timestamptz, integer, integer, text
) TO fieldwiring_app;

COMMIT;
