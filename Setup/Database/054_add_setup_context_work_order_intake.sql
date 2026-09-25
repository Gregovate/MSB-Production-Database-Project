/* ============================================================================
MSB Setup Session — contextual Work Order Intake handoff
Issue: #172
Status: IMPLEMENTATION CANDIDATE — DO NOT APPLY TO PRODUCTION WITHOUT REVIEW
Revision: 2026-09-22

Purpose:
  Let trusted Production Crew / Managers report a suspected problem or durable
  correction from active Setup context without re-entering the task/location/
  schedule information the application already knows.

Boundary:
  - creates a stage.work_order_intake record only;
  - triage_dropdown remains Submitted ('1');
  - does NOT create ops.work_order;
  - does NOT mutate Setup Catalog, Kit, Procedure, LOR, or material truth;
  - Manager triage remains the authority that may Promote an intake request.
============================================================================ */

BEGIN;

DO $preflight$
BEGIN
    IF to_regclass('stage.work_order_intake') IS NULL
       OR to_regclass('ops.setup_session_task') IS NULL
       OR to_regclass('ops.setup_session') IS NULL
       OR to_regclass('ops.setup_work_day') IS NULL
       OR to_regclass('ops.setup_work_day_task') IS NULL
       OR to_regclass('ops.setup_work_day_crew') IS NULL
       OR to_regclass('ref.stage') IS NULL
       OR to_regclass('ref.lor_scene') IS NULL
       OR to_regclass('ref.person') IS NULL
       OR to_regclass('public.directus_users') IS NULL THEN
        RAISE EXCEPTION 'Current Work Order Intake, Setup schedule, and identity authority are required';
    END IF;

    IF to_regprocedure('ref.setup_browser_capabilities(text)') IS NULL THEN
        RAISE EXCEPTION 'Setup browser capability authority is required';
    END IF;

    IF NOT EXISTS (
        SELECT 1
        FROM information_schema.columns
        WHERE table_schema='stage'
          AND table_name='work_order_intake'
          AND column_name='source_payload'
          AND data_type='jsonb'
    ) THEN
        RAISE EXCEPTION 'Work Order Intake source_payload JSONB contract is required';
    END IF;

    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'fieldwiring_app') THEN
        RAISE EXCEPTION 'Required application role fieldwiring_app does not exist';
    END IF;
END
$preflight$;

CREATE OR REPLACE FUNCTION ops.submit_setup_work_order_intake(
    p_email text,
    p_setup_session_task_id bigint,
    p_problem text,
    p_suggested_change text DEFAULT NULL,
    p_setup_work_day_task_id bigint DEFAULT NULL,
    p_setup_work_day_id bigint DEFAULT NULL,
    p_shift_code text DEFAULT NULL
)
RETURNS TABLE (
    intake_id bigint,
    setup_session_task_id bigint,
    setup_work_day_task_id bigint,
    triage_state text,
    operator_display_name text
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, ops, ref, stage
AS $function$
DECLARE
    v_email text := lower(btrim(p_email));
    v_problem text := nullif(btrim(p_problem), '');
    v_suggestion text := nullif(btrim(p_suggested_change), '');
    v_directus_user_id uuid;
    v_person_id integer;
    v_display_name text;
    v_role_name text;
    v_policy_names text[];
    v_can_manage boolean := false;
    v_can_report boolean := false;

    v_session_id bigint;
    v_season_year integer;
    v_setup_task_id bigint;
    v_task_name text;
    v_stage_id integer;
    v_stage_key text;
    v_stage_name text;
    v_scene_id bigint;
    v_scene_name text;

    v_assignment_id bigint := p_setup_work_day_task_id;
    v_work_day_id bigint := p_setup_work_day_id;
    v_setup_day_number integer;
    v_work_date date;
    v_shift text := nullif(upper(btrim(p_shift_code)), '');
    v_crew_id bigint;
    v_crew_code text;

    v_stage_raw text;
    v_notes text;
    v_payload jsonb;
    v_intake_id bigint;
BEGIN
    IF v_email IS NULL OR v_email = '' THEN
        RAISE EXCEPTION USING ERRCODE='42501',
            MESSAGE='Authenticated Setup operator email is required';
    END IF;

    IF v_problem IS NULL THEN
        RAISE EXCEPTION USING ERRCODE='22023',
            MESSAGE='What did you find? is required';
    END IF;

    IF char_length(v_problem) > 255 THEN
        RAISE EXCEPTION USING ERRCODE='22023',
            MESSAGE='Problem description must be 255 characters or less';
    END IF;

    SELECT u.id,
           c.display_name,
           c.role_name,
           c.policy_names,
           c.can_manage_setup
      INTO v_directus_user_id,
           v_display_name,
           v_role_name,
           v_policy_names,
           v_can_manage
    FROM public.directus_users u
    JOIN LATERAL ref.setup_browser_capabilities(v_email) c ON true
    WHERE u.status='active'
      AND lower(u.email)=v_email
      AND c.can_read_setup
    LIMIT 1;

    v_can_report :=
        coalesce(v_can_manage, false)
        OR coalesce(v_role_name = 'Production Crew', false)
        OR 'Production Crew' = ANY(coalesce(v_policy_names, ARRAY[]::text[]));

    IF v_directus_user_id IS NULL OR v_can_report IS NOT TRUE THEN
        RAISE EXCEPTION USING ERRCODE='42501',
            MESSAGE='Setup problem reporting requires Production Crew or Manager access';
    END IF;

    SELECT p.person_id
      INTO v_person_id
    FROM ref.person p
    WHERE p.directus_user_id = v_directus_user_id
    LIMIT 1;

    IF v_person_id IS NULL THEN
        RAISE EXCEPTION USING ERRCODE='42501',
            MESSAGE='Authenticated Setup operator is not mapped to an MSB person';
    END IF;

    SELECT st.setup_session_id,
           ss.season_year,
           st.setup_task_id,
           st.annual_task_name,
           st.annual_stage_id,
           s.stage_key,
           s.stage_name,
           st.annual_lor_scene_id,
           ls.scene_name
      INTO v_session_id,
           v_season_year,
           v_setup_task_id,
           v_task_name,
           v_stage_id,
           v_stage_key,
           v_stage_name,
           v_scene_id,
           v_scene_name
    FROM ops.setup_session_task st
    JOIN ops.setup_session ss
      ON ss.setup_session_id = st.setup_session_id
    LEFT JOIN ref.stage s
      ON s.stage_id = st.annual_stage_id
    LEFT JOIN ref.lor_scene ls
      ON ls.lor_scene_id = st.annual_lor_scene_id
    WHERE st.setup_session_task_id = p_setup_session_task_id;

    IF v_session_id IS NULL THEN
        RAISE EXCEPTION USING ERRCODE='P0002',
            MESSAGE='Annual Setup task was not found';
    END IF;

    IF v_assignment_id IS NOT NULL THEN
        SELECT wdt.setup_work_day_id,
               wd.setup_day_number,
               wd.work_date,
               wdt.shift_code,
               wdt.setup_work_day_crew_id,
               coalesce(c.crew_code, wdt.crew_lane)
          INTO v_work_day_id,
               v_setup_day_number,
               v_work_date,
               v_shift,
               v_crew_id,
               v_crew_code
        FROM ops.setup_work_day_task wdt
        JOIN ops.setup_work_day wd
          ON wd.setup_work_day_id = wdt.setup_work_day_id
        LEFT JOIN ops.setup_work_day_crew c
          ON c.setup_work_day_crew_id = wdt.setup_work_day_crew_id
        WHERE wdt.setup_work_day_task_id = v_assignment_id
          AND wdt.setup_session_task_id = p_setup_session_task_id
          AND wd.setup_session_id = v_session_id;

        IF NOT FOUND THEN
            RAISE EXCEPTION USING ERRCODE='22023',
                MESSAGE='Scheduled assignment does not belong to this Setup task';
        END IF;
    ELSIF v_work_day_id IS NOT NULL THEN
        SELECT wd.setup_day_number, wd.work_date
          INTO v_setup_day_number, v_work_date
        FROM ops.setup_work_day wd
        WHERE wd.setup_work_day_id = v_work_day_id
          AND wd.setup_session_id = v_session_id;

        IF NOT FOUND THEN
            RAISE EXCEPTION USING ERRCODE='22023',
                MESSAGE='Work day does not belong to this Setup Session';
        END IF;
    END IF;

    IF v_shift IS NOT NULL
       AND v_shift NOT IN ('MORNING','AFTERNOON','ALL_DAY') THEN
        RAISE EXCEPTION USING ERRCODE='22023',
            MESSAGE='Shift must be MORNING, AFTERNOON, or ALL_DAY';
    END IF;

    v_stage_raw := CASE
        WHEN v_stage_id IS NULL THEN NULL
        ELSE left(
            concat_ws(' — ',
                CASE WHEN v_stage_key IS NULL THEN NULL ELSE 'Stage ' || v_stage_key END,
                v_stage_name
            ),
            100
        )
    END;

    v_payload := jsonb_strip_nulls(jsonb_build_object(
        'source', 'SETUP',
        'season_year', v_season_year,
        'setup_session_id', v_session_id,
        'setup_session_task_id', p_setup_session_task_id,
        'setup_task_id', v_setup_task_id,
        'task_name', v_task_name,
        'stage_id', v_stage_id,
        'stage_key', v_stage_key,
        'stage_name', v_stage_name,
        'lor_scene_id', v_scene_id,
        'scene_name', v_scene_name,
        'setup_work_day_id', v_work_day_id,
        'setup_day_number', v_setup_day_number,
        'work_date', v_work_date,
        'setup_work_day_task_id', v_assignment_id,
        'shift_code', v_shift,
        'setup_work_day_crew_id', v_crew_id,
        'crew_code', v_crew_code,
        'suggested_change', v_suggestion,
        'reporter_person_id', v_person_id,
        'reporter_email', v_email
    ));

    v_notes := concat_ws(E'\n',
        'Automatically captured Setup context:',
        'Season: ' || v_season_year::text,
        'Task: ' || coalesce(v_task_name, '(unnamed)'),
        CASE
            WHEN v_stage_id IS NULL THEN 'Area: Site-wide / Infrastructure'
            ELSE 'Area: ' || coalesce(v_stage_raw, 'Stage ' || v_stage_id::text)
                 || coalesce(' / ' || v_scene_name, '')
        END,
        CASE
            WHEN v_work_date IS NULL THEN NULL
            ELSE 'Work: Day ' || coalesce(v_setup_day_number::text, '?')
                 || ' · ' || v_work_date::text
                 || coalesce(' · ' || v_shift, '')
                 || coalesce(' · Crew ' || v_crew_code, '')
        END,
        CASE
            WHEN v_suggestion IS NULL THEN NULL
            ELSE 'Suggested change: ' || v_suggestion
        END
    );

    PERFORM pg_catalog.set_config(
        'app.directus_user_uuid',
        v_directus_user_id::text,
        true
    );

    INSERT INTO stage.work_order_intake(
        source_system,
        source_form_name,
        source_payload,
        submitter_email_raw,
        submitter_name_raw,
        priority_raw,
        task_type_raw,
        stage_raw,
        problem_raw,
        notes_raw,
        location_type_raw,
        submitter_person_id,
        stage_id,
        target_year,
        triage_dropdown
    )
    VALUES (
        'SETUP',
        'SETUP_TASK',
        v_payload,
        v_email,
        nullif(btrim(v_display_name), ''),
        '3',
        'Setup field finding',
        v_stage_raw,
        v_problem,
        v_notes,
        CASE WHEN v_stage_id IS NULL THEN NULL ELSE 'STAGE' END,
        v_person_id,
        v_stage_id,
        v_season_year,
        '1'
    )
    RETURNING stage.work_order_intake.intake_id
      INTO v_intake_id;

    RETURN QUERY
    SELECT v_intake_id,
           p_setup_session_task_id,
           v_assignment_id,
           'SUBMITTED'::text,
           coalesce(nullif(btrim(v_display_name), ''), v_email);
END;
$function$;

REVOKE ALL ON FUNCTION ops.submit_setup_work_order_intake(
    text,bigint,text,text,bigint,bigint,text
) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION ops.submit_setup_work_order_intake(
    text,bigint,text,text,bigint,bigint,text
) TO fieldwiring_app;

COMMIT;

SELECT
    to_regprocedure(
        'ops.submit_setup_work_order_intake(text,bigint,text,text,bigint,bigint,text)'
    ) IS NOT NULL AS setup_intake_command_ready,
    has_function_privilege(
        'fieldwiring_app',
        'ops.submit_setup_work_order_intake(text,bigint,text,text,bigint,bigint,text)',
        'EXECUTE'
    ) AS app_can_submit_setup_intake,
    has_table_privilege(
        'fieldwiring_app',
        'stage.work_order_intake',
        'INSERT'
    ) AS app_has_forbidden_direct_intake_insert;
