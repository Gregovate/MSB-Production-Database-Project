/* ============================================================================
MSB Setup Session — Report Correction -> existing Work Order Intake
Issues: #172, #122
Status: IMPLEMENTATION CANDIDATE — DO NOT APPLY TO PRODUCTION WITHOUT REVIEW
Revision: 2026-09-26 — reconciled onto current #175/#132 Production baseline

Purpose:
  Let trusted Production Crew / Managers report a suspected Setup correction
  from the exact live scheduled assignment while preserving the current
  Work Order Intake / Manager triage boundary.

Boundary:
  - exact setup_work_day_task_id is required and authoritative;
  - scheduled day/shift/crew/Captain are derived server-side;
  - current Procedure identity is captured by the protected backend when available;
  - PostgreSQL prepares/authorizes the Intake payload but does not insert it;
  - protected Setup backend creates the Intake through the Directus Items API;
  - Directus items.create remains the existing manager-notification boundary;
  - triage_dropdown remains Submitted ('1');
  - does NOT create ops.work_order;
  - does NOT mutate Setup Catalog, Kit, Procedure, LOR, scheduling, or material truth;
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
       OR to_regclass('ref.person') IS NULL THEN
        RAISE EXCEPTION
            'Current Work Order Intake, Setup schedule, and identity authority are required';
    END IF;

    IF to_regprocedure('ref.setup_execution_actor(text,bigint)') IS NULL THEN
        RAISE EXCEPTION
            'Migration 061 Setup execution actor authority is required before migration 062';
    END IF;

    IF NOT EXISTS (
        SELECT 1
        FROM information_schema.columns
        WHERE table_schema = 'stage'
          AND table_name = 'work_order_intake'
          AND column_name = 'source_payload'
          AND data_type = 'jsonb'
    ) THEN
        RAISE EXCEPTION 'Work Order Intake source_payload JSONB contract is required';
    END IF;

    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'fieldwiring_app') THEN
        RAISE EXCEPTION 'Required application role fieldwiring_app does not exist';
    END IF;
END
$preflight$;

CREATE OR REPLACE FUNCTION ops.prepare_setup_work_order_intake(
    p_email text,
    p_setup_session_task_id bigint,
    p_setup_work_day_task_id bigint,
    p_problem text,
    p_suggested_correction_evidence text DEFAULT NULL,
    p_procedure_context jsonb DEFAULT NULL
)
RETURNS TABLE (
    intake_payload jsonb,
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
    v_problem text := nullif(btrim(p_problem), '');
    v_suggestion text := nullif(btrim(p_suggested_correction_evidence), '');
    v_procedure jsonb := coalesce(p_procedure_context, '{}'::jsonb);
    v_procedure_summary text;

    v_session_id bigint;
    v_season_year integer;
    v_setup_task_id bigint;
    v_task_origin text;
    v_task_name text;
    v_stage_id integer;
    v_stage_key text;
    v_stage_name text;
    v_scene_id bigint;
    v_scene_name text;

    v_work_day_id bigint;
    v_setup_day_number integer;
    v_work_date date;
    v_shift text;
    v_crew_id bigint;
    v_crew_code text;
    v_captain_person_id integer;
    v_captain_display_name text;

    v_directus_user_id uuid;
    v_person_id integer;
    v_display_name text;

    v_stage_raw text;
    v_notes text;
    v_payload jsonb;
    v_submitted_at timestamptz := clock_timestamp();
BEGIN
    IF p_setup_session_task_id IS NULL OR p_setup_work_day_task_id IS NULL THEN
        RAISE EXCEPTION USING ERRCODE = '22023',
            MESSAGE = 'Exact Setup annual task and scheduled assignment are required';
    END IF;

    IF v_problem IS NULL THEN
        RAISE EXCEPTION USING ERRCODE = '22023',
            MESSAGE = 'What did you find? is required';
    END IF;

    IF char_length(v_problem) > 255 THEN
        RAISE EXCEPTION USING ERRCODE = '22023',
            MESSAGE = 'Finding must be 255 characters or less';
    END IF;

    IF v_suggestion IS NOT NULL AND char_length(v_suggestion) > 2000 THEN
        RAISE EXCEPTION USING ERRCODE = '22023',
            MESSAGE = 'Suggested correction / evidence must be 2000 characters or less';
    END IF;

    IF jsonb_typeof(v_procedure) <> 'object'
       OR octet_length(v_procedure::text) > 4000 THEN
        RAISE EXCEPTION USING ERRCODE = '22023',
            MESSAGE = 'Procedure context must be a bounded JSON object';
    END IF;

    SELECT
        st.setup_session_id,
        ss.season_year,
        st.setup_task_id,
        st.task_origin,
        st.annual_task_name,
        st.annual_stage_id,
        s.stage_key,
        s.stage_name,
        st.annual_lor_scene_id,
        ls.scene_name,
        wdt.setup_work_day_id,
        wd.setup_day_number,
        wd.work_date,
        wdt.shift_code,
        wdt.setup_work_day_crew_id,
        coalesce(c.crew_code, wdt.crew_lane),
        c.captain_person_id,
        coalesce(
            nullif(btrim(cp.preferred_name), ''),
            nullif(btrim(pg_catalog.concat_ws(' ', cp.first_name, cp.last_name)), ''),
            nullif(btrim(cp.email), '')
        )
      INTO
        v_session_id,
        v_season_year,
        v_setup_task_id,
        v_task_origin,
        v_task_name,
        v_stage_id,
        v_stage_key,
        v_stage_name,
        v_scene_id,
        v_scene_name,
        v_work_day_id,
        v_setup_day_number,
        v_work_date,
        v_shift,
        v_crew_id,
        v_crew_code,
        v_captain_person_id,
        v_captain_display_name
    FROM ops.setup_work_day_task wdt
    JOIN ops.setup_session_task st
      ON st.setup_session_task_id = wdt.setup_session_task_id
    JOIN ops.setup_session ss
      ON ss.setup_session_id = st.setup_session_id
    JOIN ops.setup_work_day wd
      ON wd.setup_work_day_id = wdt.setup_work_day_id
     AND wd.setup_session_id = st.setup_session_id
    LEFT JOIN ops.setup_work_day_crew c
      ON c.setup_work_day_crew_id = wdt.setup_work_day_crew_id
    LEFT JOIN ref.person cp
      ON cp.person_id = c.captain_person_id
    LEFT JOIN ref.stage s
      ON s.stage_id = st.annual_stage_id
    LEFT JOIN ref.lor_scene ls
      ON ls.lor_scene_id = st.annual_lor_scene_id
    WHERE wdt.setup_work_day_task_id = p_setup_work_day_task_id
      AND wdt.setup_session_task_id = p_setup_session_task_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION USING ERRCODE = '22023',
            MESSAGE = 'Scheduled assignment does not belong to this Setup task';
    END IF;

    SELECT a.directus_user_id, a.person_id, a.display_name
      INTO v_directus_user_id, v_person_id, v_display_name
    FROM ref.setup_execution_actor(p_email, v_setup_task_id) a;

    v_stage_raw := CASE
        WHEN v_stage_id IS NULL THEN NULL
        ELSE left(
            concat_ws(
                ' — ',
                CASE
                    WHEN v_stage_key IS NULL THEN NULL
                    ELSE 'Stage ' || v_stage_key
                END,
                v_stage_name
            ),
            100
        )
    END;

    v_procedure_summary := nullif(btrim(v_procedure ->> 'summary'), '');

    v_payload := jsonb_strip_nulls(jsonb_build_object(
        'source', 'SETUP',
        'season_year', v_season_year,
        'setup_session_id', v_session_id,
        'setup_session_task_id', p_setup_session_task_id,
        'setup_task_id', v_setup_task_id,
        'task_origin', v_task_origin,
        'task_name', v_task_name,
        'stage_id', v_stage_id,
        'stage_key', v_stage_key,
        'stage_name', v_stage_name,
        'lor_scene_id', v_scene_id,
        'scene_name', v_scene_name,
        'setup_work_day_id', v_work_day_id,
        'setup_day_number', v_setup_day_number,
        'work_date', v_work_date,
        'setup_work_day_task_id', p_setup_work_day_task_id,
        'shift_code', v_shift,
        'setup_work_day_crew_id', v_crew_id,
        'crew_code', v_crew_code,
        'captain_person_id', v_captain_person_id,
        'captain_display_name', v_captain_display_name,
        'procedure_context', v_procedure,
        'suggested_correction_evidence', v_suggestion,
        'reporter_person_id', v_person_id,
        'reporter_email', lower(btrim(p_email)),
        'submitted_at', v_submitted_at
    ));

    v_notes := concat_ws(E'\n',
        'Automatically captured Setup context:',
        'Setup provenance: session_id=' || v_session_id::text
            || '; annual_task_id=' || p_setup_session_task_id::text
            || '; reusable_task_id=' || coalesce(v_setup_task_id::text, 'SEASON_ONLY')
            || '; assignment_id=' || p_setup_work_day_task_id::text
            || '; work_day_id=' || v_work_day_id::text
            || '; crew_id=' || coalesce(v_crew_id::text, 'NULL')
            || '; stage_id=' || coalesce(v_stage_id::text, 'NULL')
            || '; scene_id=' || coalesce(v_scene_id::text, 'NULL')
            || '; captain_person_id=' || coalesce(v_captain_person_id::text, 'NULL'),
        'Task: ' || coalesce(v_task_name, '(unnamed)'),
        CASE
            WHEN v_stage_id IS NULL THEN
                'Area: Site-wide / Infrastructure'
            ELSE
                'Area: ' || coalesce(v_stage_raw, 'Stage ' || v_stage_id::text)
                || coalesce(' / ' || v_scene_name, '')
        END,
        'Work: Day ' || coalesce(v_setup_day_number::text, '?')
            || ' · ' || coalesce(v_work_date::text, '?')
            || coalesce(' · ' || v_shift, '')
            || coalesce(' · Crew ' || v_crew_code, ''),
        CASE
            WHEN v_captain_person_id IS NULL THEN NULL
            ELSE 'Captain: '
                || coalesce(v_captain_display_name, 'Person ' || v_captain_person_id::text)
                || ' (person_id=' || v_captain_person_id::text || ')'
        END,
        CASE
            WHEN v_procedure_summary IS NULL THEN NULL
            ELSE 'Procedure: ' || v_procedure_summary
        END,
        CASE
            WHEN v_suggestion IS NULL THEN NULL
            ELSE 'Suggested correction / evidence: ' || v_suggestion
        END
    );

    RETURN QUERY
    SELECT
        jsonb_strip_nulls(jsonb_build_object(
            'source_system', 'SETUP',
            'source_form_name', 'SETUP_CORRECTION',
            'source_payload', v_payload,
            'submitter_email_raw', lower(btrim(p_email)),
            'submitter_name_raw', nullif(btrim(v_display_name), ''),
            'submitted_at', v_submitted_at,
            'priority_raw', '3',
            'task_type_raw', 'Setup field correction',
            'stage_raw', v_stage_raw,
            'problem_raw', v_problem,
            'notes_raw', v_notes,
            'location_type_raw', CASE WHEN v_stage_id IS NULL THEN NULL ELSE 'STAGE' END,
            'submitter_person_id', v_person_id,
            'stage_id', v_stage_id,
            'target_year', v_season_year,
            'triage_dropdown', '1'
        )),
        p_setup_session_task_id,
        p_setup_work_day_task_id,
        'SUBMITTED'::text,
        coalesce(nullif(btrim(v_display_name), ''), lower(btrim(p_email)));
END;
$function$;

REVOKE ALL ON FUNCTION ops.prepare_setup_work_order_intake(
    text,bigint,bigint,text,text,jsonb
) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION ops.prepare_setup_work_order_intake(
    text,bigint,bigint,text,text,jsonb
) TO fieldwiring_app;

COMMIT;

SELECT
    to_regprocedure(
        'ops.prepare_setup_work_order_intake(text,bigint,bigint,text,text,jsonb)'
    ) IS NOT NULL AS setup_intake_prepare_ready,
    has_function_privilege(
        'fieldwiring_app',
        'ops.prepare_setup_work_order_intake(text,bigint,bigint,text,text,jsonb)',
        'EXECUTE'
    ) AS app_can_submit_setup_intake,
    has_table_privilege(
        'fieldwiring_app',
        'stage.work_order_intake',
        'INSERT'
    ) AS app_has_forbidden_direct_intake_insert;
