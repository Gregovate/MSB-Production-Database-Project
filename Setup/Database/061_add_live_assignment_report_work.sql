/* ============================================================================
MSB Setup Session — live Report Work / continuation execution
Issues: #132, #175, #122
Status: IMPLEMENTATION CANDIDATE — DO NOT APPLY TO PRODUCTION WITHOUT REVIEW
Revision: 2026-09-25

Purpose:
  - allow Production Crew (plus Managers/Administrators) to report actual Setup work;
  - require actual work date, elapsed duration, and percent complete for each new work report;
  - keep actual work date distinct from scheduled Work Day and report-entry timestamp;
  - bind scheduled work reports to the exact setup_work_day_task_id;
  - derive work-day / shift identity from the scheduled assignment instead of
    trusting duplicated browser-entered context;
  - preserve the original assignment as historical evidence once work exists;
  - leave an incomplete annual task IN_PROGRESS so #205 can surface
    NEEDS_SCHEDULING_AGAIN when no future continuation exists.
============================================================================ */

BEGIN;

DO $preflight$
BEGIN
    IF to_regclass('ops.setup_task_progress') IS NULL
       OR to_regclass('ops.setup_session_task') IS NULL
       OR to_regclass('ops.setup_work_day') IS NULL
       OR to_regclass('ops.setup_work_day_task') IS NULL
       OR to_regclass('ref.person') IS NULL
       OR to_regclass('public.directus_users') IS NULL THEN
        RAISE EXCEPTION 'Current Setup execution / scheduling tables are required';
    END IF;

    IF to_regprocedure('ref.setup_browser_capabilities(text)') IS NULL
       OR to_regprocedure('ops.record_setup_task_progress(text,bigint,bigint,text,integer,integer,text,text,boolean)') IS NULL THEN
        RAISE EXCEPTION 'Current Setup authorization/progress command is required before migration 059';
    END IF;

    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'fieldwiring_app') THEN
        RAISE EXCEPTION 'Required application role fieldwiring_app does not exist';
    END IF;
END
$preflight$;

ALTER TABLE ops.setup_task_progress
    ADD COLUMN IF NOT EXISTS performed_on date;

COMMENT ON COLUMN ops.setup_task_progress.performed_on IS
    'Calendar date when this work period actually occurred. May differ from the scheduled Setup Work Day and from recorded_at; NULL is retained only for older evidence.';

ALTER TABLE ops.setup_task_progress
    ADD COLUMN IF NOT EXISTS duration_minutes integer;

ALTER TABLE ops.setup_task_progress
    DROP CONSTRAINT IF EXISTS ck_setup_task_progress_duration;
ALTER TABLE ops.setup_task_progress
    ADD CONSTRAINT ck_setup_task_progress_duration CHECK (
        duration_minutes IS NULL OR duration_minutes > 0
    );

COMMENT ON COLUMN ops.setup_task_progress.duration_minutes IS
    'Elapsed duration for this reported work period in total minutes. NULL is retained only for older progress evidence.';

ALTER TABLE ops.setup_task_progress
    ADD COLUMN IF NOT EXISTS percent_complete integer;

ALTER TABLE ops.setup_task_progress
    DROP CONSTRAINT IF EXISTS ck_setup_task_progress_percent_complete;
ALTER TABLE ops.setup_task_progress
    ADD CONSTRAINT ck_setup_task_progress_percent_complete CHECK (
        percent_complete IS NULL OR percent_complete BETWEEN 1 AND 100
    );

COMMENT ON COLUMN ops.setup_task_progress.percent_complete IS
    'Operator-estimated cumulative percent complete for the annual task after this work report. 100 explicitly completes the annual task.';

CREATE OR REPLACE FUNCTION ref.setup_execution_actor(
    p_email text,
    p_setup_task_id bigint
)
RETURNS TABLE (
    directus_user_id uuid,
    person_id integer,
    display_name text,
    can_manage_setup boolean
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
    v_role_name text;
    v_policy_names text[];
    v_can_read boolean := false;
    v_can_manage boolean := false;
    v_can_report boolean := false;
BEGIN
    IF v_email IS NULL OR v_email = '' THEN
        RAISE EXCEPTION USING ERRCODE = '42501',
            MESSAGE = 'Authenticated Setup operator email is required';
    END IF;

    SELECT u.id,
           c.display_name,
           c.role_name,
           c.policy_names,
           c.can_read_setup,
           c.can_manage_setup
      INTO v_directus_user_id,
           v_display_name,
           v_role_name,
           v_policy_names,
           v_can_read,
           v_can_manage
    FROM public.directus_users u
    JOIN LATERAL ref.setup_browser_capabilities(v_email) c ON true
    WHERE u.status = 'active'
      AND lower(u.email) = v_email
    LIMIT 1;

    IF v_directus_user_id IS NULL OR coalesce(v_can_read, false) IS NOT TRUE THEN
        RAISE EXCEPTION USING ERRCODE = '42501',
            MESSAGE = 'Setup execution access is not authorized for this account';
    END IF;

    v_can_report :=
        coalesce(v_can_manage, false)
        OR coalesce(v_role_name = 'Production Crew', false)
        OR 'Production Crew' = ANY(coalesce(v_policy_names, ARRAY[]::text[]));

    IF v_can_report IS NOT TRUE THEN
        RAISE EXCEPTION USING ERRCODE = '42501',
            MESSAGE = 'Setup work reporting requires Production Crew or Manager access';
    END IF;

    SELECT p.person_id
      INTO v_person_id
    FROM ref.person p
    WHERE p.directus_user_id = v_directus_user_id
    LIMIT 1;

    IF v_person_id IS NULL THEN
        RAISE EXCEPTION USING ERRCODE = '42501',
            MESSAGE = 'Authenticated Setup operator is not mapped to an MSB person';
    END IF;

    RETURN QUERY
    SELECT v_directus_user_id,
           v_person_id,
           coalesce(nullif(btrim(v_display_name), ''), v_email),
           coalesce(v_can_manage, false);
END;
$function$;

REVOKE ALL ON FUNCTION ref.setup_execution_actor(text,bigint) FROM PUBLIC;
REVOKE ALL ON FUNCTION ref.setup_execution_actor(text,bigint) FROM fieldwiring_app;

REVOKE ALL ON FUNCTION ops.record_setup_task_progress(
    text,bigint,bigint,text,integer,integer,text,text,boolean
) FROM PUBLIC;
REVOKE ALL ON FUNCTION ops.record_setup_task_progress(
    text,bigint,bigint,text,integer,integer,text,text,boolean
) FROM fieldwiring_app;

DROP FUNCTION ops.record_setup_task_progress(
    text,bigint,bigint,text,integer,integer,text,text,boolean
);

CREATE FUNCTION ops.record_setup_task_progress(
    p_email text,
    p_setup_session_task_id bigint,
    p_performed_on date,
    p_crew_count integer,
    p_duration_minutes integer,
    p_percent_complete integer,
    p_completed_quantity integer,
    p_completed_units text,
    p_progress_note text,
    p_setup_work_day_task_id bigint DEFAULT NULL,
    p_setup_work_day_id bigint DEFAULT NULL,
    p_shift_code text DEFAULT NULL
)
RETURNS TABLE (
    setup_task_progress_id bigint,
    setup_session_task_id bigint,
    setup_work_day_task_id bigint,
    execution_status text,
    percent_complete integer,
    performed_on date,
    recorded_at timestamptz,
    operator_display_name text
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, ops, ref
AS $function$
DECLARE
    v_setup_task_id bigint;
    v_setup_session_id bigint;
    v_current_status text;
    v_directus_user_id uuid;
    v_person_id integer;
    v_display_name text;
    v_work_day_id bigint := p_setup_work_day_id;
    v_shift text := upper(btrim(coalesce(p_shift_code, 'ALL_DAY')));
    v_assignment_id bigint := p_setup_work_day_task_id;
    v_progress_id bigint;
    v_recorded_at timestamptz := now();
    v_status text;
    v_previous_percent integer;
    v_total_duration integer;
BEGIN
    SELECT st.setup_task_id, st.setup_session_id, st.execution_status
      INTO v_setup_task_id, v_setup_session_id, v_current_status
    FROM ops.setup_session_task st
    WHERE st.setup_session_task_id = p_setup_session_task_id;

    IF v_setup_session_id IS NULL THEN
        RAISE EXCEPTION USING ERRCODE = 'P0002',
            MESSAGE = 'Annual Setup task was not found';
    END IF;

    SELECT a.directus_user_id, a.person_id, a.display_name
      INTO v_directus_user_id, v_person_id, v_display_name
    FROM ref.setup_execution_actor(p_email, v_setup_task_id) a;

    IF p_performed_on IS NULL THEN
        RAISE EXCEPTION USING ERRCODE = '22023',
            MESSAGE = 'Work performed date is required';
    END IF;

    IF p_performed_on > current_date THEN
        RAISE EXCEPTION USING ERRCODE = '22023',
            MESSAGE = 'Work performed date cannot be in the future';
    END IF;

    IF p_crew_count IS NULL OR p_crew_count <= 0 THEN
        RAISE EXCEPTION USING ERRCODE = '22023',
            MESSAGE = 'Crew size must be at least 1';
    END IF;

    IF p_duration_minutes IS NULL OR p_duration_minutes <= 0 THEN
        RAISE EXCEPTION USING ERRCODE = '22023',
            MESSAGE = 'Elapsed work duration must be greater than zero';
    END IF;

    IF p_percent_complete IS NULL OR p_percent_complete < 1 OR p_percent_complete > 100 THEN
        RAISE EXCEPTION USING ERRCODE = '22023',
            MESSAGE = 'Percent complete must be between 1 and 100';
    END IF;

    IF p_completed_quantity IS NOT NULL AND p_completed_quantity <= 0 THEN
        RAISE EXCEPTION USING ERRCODE = '22023',
            MESSAGE = 'Completed quantity must be greater than zero';
    END IF;

    IF v_current_status = 'COMPLETE' AND p_percent_complete < 100 THEN
        RAISE EXCEPTION USING ERRCODE = '23514',
            MESSAGE = 'Completed Setup work cannot be reopened by recording a lower percent';
    END IF;

    SELECT max(p.percent_complete)
      INTO v_previous_percent
    FROM ops.setup_task_progress p
    WHERE p.setup_session_task_id = p_setup_session_task_id
      AND p.percent_complete IS NOT NULL;

    IF v_previous_percent IS NOT NULL AND p_percent_complete < v_previous_percent THEN
        RAISE EXCEPTION USING ERRCODE = '22023',
            MESSAGE = format(
                'Percent complete cannot move backward from %s%% to %s%%',
                v_previous_percent,
                p_percent_complete
            );
    END IF;

    IF v_assignment_id IS NOT NULL THEN
        SELECT wdt.setup_work_day_id, wdt.shift_code
          INTO v_work_day_id, v_shift
        FROM ops.setup_work_day_task wdt
        JOIN ops.setup_work_day wd
          ON wd.setup_work_day_id = wdt.setup_work_day_id
        WHERE wdt.setup_work_day_task_id = v_assignment_id
          AND wdt.setup_session_task_id = p_setup_session_task_id
          AND wd.setup_session_id = v_setup_session_id;

        IF v_work_day_id IS NULL THEN
            RAISE EXCEPTION USING ERRCODE = '22023',
                MESSAGE = 'Scheduled assignment does not belong to this annual Setup task/session';
        END IF;
    ELSE
        IF v_work_day_id IS NOT NULL
           AND NOT EXISTS (
               SELECT 1
               FROM ops.setup_work_day wd
               WHERE wd.setup_work_day_id = v_work_day_id
                 AND wd.setup_session_id = v_setup_session_id
           ) THEN
            RAISE EXCEPTION USING ERRCODE = '22023',
                MESSAGE = 'Progress work day must belong to the same Setup Session';
        END IF;

        IF v_shift NOT IN ('MORNING','AFTERNOON','ALL_DAY') THEN
            RAISE EXCEPTION USING ERRCODE = '22023',
                MESSAGE = 'Shift must be MORNING, AFTERNOON, or ALL_DAY';
        END IF;
    END IF;

    PERFORM pg_catalog.set_config(
        'app.directus_user_uuid',
        v_directus_user_id::text,
        true
    );

    INSERT INTO ops.setup_task_progress(
        setup_session_task_id,
        setup_work_day_id,
        setup_work_day_task_id,
        performed_on,
        shift_code,
        crew_count,
        duration_minutes,
        percent_complete,
        completed_quantity,
        completed_units,
        progress_note,
        marks_task_complete,
        recorded_at
    ) VALUES (
        p_setup_session_task_id,
        v_work_day_id,
        v_assignment_id,
        p_performed_on,
        v_shift,
        p_crew_count,
        p_duration_minutes,
        p_percent_complete,
        p_completed_quantity,
        nullif(btrim(p_completed_units), ''),
        nullif(btrim(p_progress_note), ''),
        p_percent_complete = 100,
        v_recorded_at
    )
    RETURNING ops.setup_task_progress.setup_task_progress_id
      INTO v_progress_id;

    SELECT sum(p.duration_minutes)
      INTO v_total_duration
    FROM ops.setup_task_progress p
    WHERE p.setup_session_task_id = p_setup_session_task_id
      AND p.duration_minutes IS NOT NULL;

    /*
      performed_on is the authoritative calendar date for the work period.
      recorded_at remains the entry/audit timestamp. Do not fabricate start/end
      timestamps merely because the report is being entered now.
    */
    UPDATE ops.setup_session_task st
       SET actual_duration_minutes = v_total_duration,
           execution_status = CASE
               WHEN p_percent_complete = 100 THEN 'COMPLETE'
               ELSE 'IN_PROGRESS'
           END,
           actual_crew_count = CASE
               WHEN p_percent_complete = 100 THEN p_crew_count
               ELSE st.actual_crew_count
           END,
           completion_note = CASE
               WHEN p_percent_complete = 100
                   THEN nullif(btrim(p_progress_note), '')
               ELSE st.completion_note
           END,
           completed_by_person_id = CASE
               WHEN p_percent_complete = 100 THEN v_person_id
               ELSE st.completed_by_person_id
           END
     WHERE st.setup_session_task_id = p_setup_session_task_id
     RETURNING st.execution_status INTO v_status;

    IF v_assignment_id IS NOT NULL THEN
        UPDATE ops.setup_work_day_task wdt
           SET actual_crew_count = p_crew_count,
               notes = CASE
                   WHEN nullif(btrim(p_progress_note), '') IS NOT NULL
                       THEN p_progress_note
                   ELSE wdt.notes
               END
         WHERE wdt.setup_work_day_task_id = v_assignment_id;
    END IF;

    /* Preserve IN_PROGRESS/COMPLETE while refreshing planned_date from any
       remaining future unworked assignment. */
    PERFORM ops.refresh_setup_session_task_schedule_state(p_setup_session_task_id);

    RETURN QUERY
    SELECT v_progress_id,
           p_setup_session_task_id,
           v_assignment_id,
           v_status,
           p_percent_complete,
           p_performed_on,
           v_recorded_at,
           v_display_name;
END;
$function$;

REVOKE ALL ON FUNCTION ops.record_setup_task_progress(
    text,bigint,date,integer,integer,integer,integer,text,text,bigint,bigint,text
) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION ops.record_setup_task_progress(
    text,bigint,date,integer,integer,integer,integer,text,text,bigint,bigint,text
) TO fieldwiring_app;

COMMIT;

SELECT
    EXISTS (
        SELECT 1
        FROM information_schema.columns
        WHERE table_schema = 'ops'
          AND table_name = 'setup_task_progress'
          AND column_name = 'performed_on'
    ) AS performed_on_column_ready,
    EXISTS (
        SELECT 1
        FROM information_schema.columns
        WHERE table_schema = 'ops'
          AND table_name = 'setup_task_progress'
          AND column_name = 'duration_minutes'
    ) AS duration_column_ready,
    EXISTS (
        SELECT 1
        FROM information_schema.columns
        WHERE table_schema = 'ops'
          AND table_name = 'setup_task_progress'
          AND column_name = 'percent_complete'
    ) AS percent_complete_column_ready,
    to_regprocedure(
        'ops.record_setup_task_progress(text,bigint,date,integer,integer,integer,integer,text,text,bigint,bigint,text)'
    ) IS NOT NULL AS assignment_progress_command_ready,
    to_regprocedure(
        'ops.record_setup_task_progress(text,bigint,bigint,text,integer,integer,text,text,boolean)'
    ) IS NULL AS old_progress_command_removed;
