\set ON_ERROR_STOP on

/* ============================================================================
#122 integrated disposable validation — 2026 Setup dress rehearsal

Runs only against a disposable current-Production clone after migrations 053
and 054. This validation may create a disposable 2026 Session, schedule one
task, record one Production Crew work period, and submit one Work Order Intake
request. The disposable acceptance runner destroys this database afterward.

NEVER APPLY THIS FILE TO PRODUCTION.
============================================================================ */

DO $validation$
DECLARE
    v_admin_email text;
    v_crew_email text;
    v_crew_person_id integer;
    v_session_id bigint;
    v_session_task_id bigint;
    v_setup_task_id bigint;
    v_day_id bigint;
    v_crew_id bigint;
    v_assignment_id bigint;
    v_progress_id bigint;
    v_intake_id bigint;
    v_duration integer;
    v_progress_actor integer;
    v_progress_assignment bigint;
    v_triage text;
    v_active_work_order_count integer;
BEGIN
    IF to_regprocedure(
        'ops.record_setup_task_progress(text,bigint,bigint,text,integer,integer,integer,text,text,boolean)'
    ) IS NULL THEN
        RAISE EXCEPTION '#132 duration-aware progress command is missing';
    END IF;

    IF to_regprocedure(
        'ops.record_setup_task_progress(text,bigint,bigint,text,integer,integer,text,text,boolean)'
    ) IS NOT NULL THEN
        RAISE EXCEPTION 'Old pre-#132 progress command is still installed';
    END IF;

    IF to_regprocedure(
        'ops.submit_setup_work_order_intake(text,bigint,text,text,bigint,bigint,text)'
    ) IS NULL THEN
        RAISE EXCEPTION '#172 Setup Work Order Intake command is missing';
    END IF;

    IF NOT EXISTS (
        SELECT 1
        FROM information_schema.columns
        WHERE table_schema='ops'
          AND table_name='setup_task_progress'
          AND column_name='duration_minutes'
    ) THEN
        RAISE EXCEPTION '#132 duration_minutes column is missing';
    END IF;

    IF has_table_privilege('fieldwiring_app','ops.setup_task_progress','INSERT')
       OR has_table_privilege('fieldwiring_app','ops.setup_task_progress','UPDATE')
       OR has_table_privilege('fieldwiring_app','ops.setup_task_progress','DELETE')
       OR has_table_privilege('fieldwiring_app','stage.work_order_intake','INSERT')
       OR has_table_privilege('fieldwiring_app','stage.work_order_intake','UPDATE')
       OR has_table_privilege('fieldwiring_app','stage.work_order_intake','DELETE') THEN
        RAISE EXCEPTION 'Forbidden broad Report Work / Work Order Intake DML detected';
    END IF;

    SELECT lower(u.email)
      INTO v_admin_email
    FROM public.directus_users u
    JOIN ref.person p
      ON p.directus_user_id = u.id
    JOIN LATERAL ref.setup_browser_capabilities(lower(u.email)) c ON true
    WHERE u.status='active'
      AND c.can_admin_setup
    ORDER BY lower(u.email)
    LIMIT 1;

    IF v_admin_email IS NULL THEN
        RAISE EXCEPTION 'No active Setup Administrator is available';
    END IF;

    SELECT lower(u.email), p.person_id
      INTO v_crew_email, v_crew_person_id
    FROM public.directus_users u
    JOIN ref.person p
      ON p.directus_user_id = u.id
    JOIN LATERAL ref.setup_browser_capabilities(lower(u.email)) c ON true
    WHERE u.status='active'
      AND c.can_read_setup
      AND NOT c.can_manage_setup
      AND (
          c.role_name = 'Production Crew'
          OR 'Production Crew' = ANY(coalesce(c.policy_names, ARRAY[]::text[]))
      )
    ORDER BY lower(u.email)
    LIMIT 1;

    IF v_crew_email IS NULL OR v_crew_person_id IS NULL THEN
        RAISE EXCEPTION 'No active Production Crew identity is available';
    END IF;

    IF EXISTS (SELECT 1 FROM ops.setup_session WHERE season_year=2026) THEN
        RAISE EXCEPTION 'Integrated dress-rehearsal validation expected no pre-existing 2026 Setup Session';
    END IF;

    SELECT setup_session_id
      INTO v_session_id
    FROM ops.create_setup_session(v_admin_email, 2026, 'PLANNING');

    SELECT st.setup_session_task_id, st.setup_task_id
      INTO v_session_task_id, v_setup_task_id
    FROM ops.setup_session_task st
    WHERE st.setup_session_id = v_session_id
      AND st.setup_task_id IS NOT NULL
      AND st.included_flag
      AND st.execution_status NOT IN ('COMPLETE','DEFERRED')
    ORDER BY st.planned_order NULLS LAST, st.setup_session_task_id
    LIMIT 1;

    IF v_session_task_id IS NULL OR v_setup_task_id IS NULL THEN
        RAISE EXCEPTION 'Disposable 2026 Session has no reusable task available for integration validation';
    END IF;

    SELECT setup_work_day_id
      INTO v_day_id
    FROM ops.upsert_setup_work_day(
        v_admin_email,
        2026,
        current_date + 1,
        1,
        'PLANNED',
        NULL,
        'Disposable #122 integration validation',
        'Created only inside disposable acceptance.'
    );

    SELECT c.setup_work_day_crew_id
      INTO v_crew_id
    FROM ops.setup_work_day_crew c
    WHERE c.setup_work_day_id = v_day_id
      AND c.crew_number = 1;

    IF v_crew_id IS NULL THEN
        RAISE EXCEPTION 'Default Crew A was not created for disposable work day';
    END IF;

    SELECT setup_work_day_task_id
      INTO v_assignment_id
    FROM ops.create_setup_work_day_assignment(
        v_admin_email,
        v_day_id,
        v_session_task_id,
        'MORNING',
        v_crew_id,
        10
    );

    IF v_assignment_id IS NULL THEN
        RAISE EXCEPTION 'Disposable scheduled assignment was not created';
    END IF;

    /* Production Crew must not acquire Manager scheduling authority. */
    BEGIN
        PERFORM *
        FROM ops.upsert_setup_work_day(
            v_crew_email,
            2026,
            current_date + 2,
            2,
            'PLANNED',
            NULL,
            NULL,
            'This scheduling write must be denied.'
        );
        RAISE EXCEPTION 'Production Crew unexpectedly created a Setup work day';
    EXCEPTION
        WHEN insufficient_privilege THEN
            NULL;
    END;

    SELECT setup_task_progress_id
      INTO v_progress_id
    FROM ops.record_setup_task_progress(
        v_crew_email,
        v_session_task_id,
        v_day_id,
        'MORNING',
        4,
        95,
        NULL,
        NULL,
        'Disposable #122 Production Crew progress proof.',
        false
    );

    SELECT p.duration_minutes,
           p.created_by_person_id,
           p.setup_work_day_task_id
      INTO v_duration,
           v_progress_actor,
           v_progress_assignment
    FROM ops.setup_task_progress p
    WHERE p.setup_task_progress_id = v_progress_id;

    IF v_duration IS DISTINCT FROM 95 THEN
        RAISE EXCEPTION 'Report Work duration was not preserved: %', v_duration;
    END IF;

    IF v_progress_actor IS DISTINCT FROM v_crew_person_id THEN
        RAISE EXCEPTION 'Report Work actor mismatch: expected %, observed %',
            v_crew_person_id, v_progress_actor;
    END IF;

    IF v_progress_assignment IS DISTINCT FROM v_assignment_id THEN
        RAISE EXCEPTION 'Report Work did not retain exact scheduled assignment: expected %, observed %',
            v_assignment_id, v_progress_assignment;
    END IF;

    SELECT intake_id
      INTO v_intake_id
    FROM ops.submit_setup_work_order_intake(
        v_crew_email,
        v_session_task_id,
        'Disposable rehearsal field finding.',
        'Manager should review this suggested correction.',
        v_assignment_id,
        v_day_id,
        'MORNING'
    );

    SELECT woi.triage_dropdown
      INTO v_triage
    FROM stage.work_order_intake woi
    WHERE woi.intake_id = v_intake_id;

    IF v_triage IS DISTINCT FROM '1' THEN
        RAISE EXCEPTION 'Setup field finding did not remain in Submitted triage: %', v_triage;
    END IF;

    IF NOT EXISTS (
        SELECT 1
        FROM stage.work_order_intake woi
        WHERE woi.intake_id = v_intake_id
          AND woi.source_system = 'SETUP'
          AND woi.source_form_name = 'SETUP_TASK'
          AND (woi.source_payload->>'setup_session_task_id')::bigint = v_session_task_id
          AND (woi.source_payload->>'setup_work_day_task_id')::bigint = v_assignment_id
          AND (woi.source_payload->>'reporter_person_id')::integer = v_crew_person_id
    ) THEN
        RAISE EXCEPTION 'Setup Work Order Intake provenance/context was not preserved';
    END IF;

    SELECT count(*)
      INTO v_active_work_order_count
    FROM ops.work_order wo
    WHERE wo.source_intake_id = v_intake_id;

    IF v_active_work_order_count <> 0 THEN
        RAISE EXCEPTION 'Human Setup field finding incorrectly created an active Work Order';
    END IF;

    RAISE NOTICE
        'SETUP #122 INTEGRATED DISPOSABLE PASS admin=% crew=% session=% task=% assignment=% progress=% intake=%',
        v_admin_email,
        v_crew_email,
        v_session_id,
        v_session_task_id,
        v_assignment_id,
        v_progress_id,
        v_intake_id;
END
$validation$;

SELECT
    'SETUP_122_2026_DRESS_REHEARSAL_DISPOSABLE_PASS' AS result;
