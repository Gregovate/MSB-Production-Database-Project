/* ============================================================================
MSB Setup Session — Production Crew Report Work + per-period duration
Issue: #132
Status: IMPLEMENTATION CANDIDATE — DO NOT APPLY TO PRODUCTION WITHOUT REVIEW
Revision: 2026-09-22

Purpose:
  - make actual Setup work reporting a Production Crew capability;
  - preserve Manager/Administrator reporting capability;
  - do not use Captain assignment as the authorization gate;
  - add positive elapsed duration to each new progress/work-period record;
  - preserve existing progress history with NULL duration where older evidence
    did not capture it;
  - keep all browser writes behind narrow SECURITY DEFINER commands.
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
        RAISE EXCEPTION 'Current Setup progress / person / Directus authority is required';
    END IF;

    IF to_regprocedure('ref.setup_browser_capabilities(text)') IS NULL
       OR to_regprocedure('ops.record_setup_task_progress(text,bigint,bigint,text,integer,integer,text,text,boolean)') IS NULL THEN
        RAISE EXCEPTION 'Current Setup authorization/progress command is required before #132';
    END IF;

    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'fieldwiring_app') THEN
        RAISE EXCEPTION 'Required application role fieldwiring_app does not exist';
    END IF;
END
$preflight$;

ALTER TABLE ops.setup_task_progress
    ADD COLUMN IF NOT EXISTS duration_minutes integer;

ALTER TABLE ops.setup_task_progress
    DROP CONSTRAINT IF EXISTS ck_setup_task_progress_duration;
ALTER TABLE ops.setup_task_progress
    ADD CONSTRAINT ck_setup_task_progress_duration CHECK (
        duration_minutes IS NULL OR duration_minutes > 0
    );

COMMENT ON COLUMN ops.setup_task_progress.duration_minutes IS
    'Elapsed duration for this work period in total minutes. NULL is retained only for pre-#132 historical rows.';

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
    p_setup_work_day_id bigint,
    p_shift_code text,
    p_crew_count integer,
    p_duration_minutes integer,
    p_completed_quantity integer,
    p_completed_units text,
    p_progress_note text,
    p_mark_complete boolean DEFAULT false
)
RETURNS TABLE (
    setup_task_progress_id bigint,
    setup_session_task_id bigint,
    execution_status text,
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
    v_directus_user_id uuid;
    v_person_id integer;
    v_display_name text;
    v_shift text := upper(btrim(coalesce(p_shift_code, 'ALL_DAY')));
    v_progress_id bigint;
    v_recorded_at timestamptz := now();
    v_status text;
    v_assignment_id bigint;
    v_total_duration integer;
BEGIN
    SELECT st.setup_task_id, st.setup_session_id
      INTO v_setup_task_id, v_setup_session_id
    FROM ops.setup_session_task st
    WHERE st.setup_session_task_id = p_setup_session_task_id;

    IF v_setup_session_id IS NULL THEN
        RAISE EXCEPTION USING ERRCODE = 'P0002',
            MESSAGE = 'Annual Setup task was not found';
    END IF;

    SELECT a.directus_user_id, a.person_id, a.display_name
      INTO v_directus_user_id, v_person_id, v_display_name
    FROM ref.setup_execution_actor(p_email, v_setup_task_id) a;

    IF p_crew_count IS NULL OR p_crew_count <= 0 THEN
        RAISE EXCEPTION USING ERRCODE = '22023',
            MESSAGE = 'Crew size must be at least 1';
    END IF;

    IF p_duration_minutes IS NULL OR p_duration_minutes <= 0 THEN
        RAISE EXCEPTION USING ERRCODE = '22023',
            MESSAGE = 'Elapsed work duration must be greater than zero';
    END IF;

    IF v_shift NOT IN ('MORNING','AFTERNOON','ALL_DAY') THEN
        RAISE EXCEPTION USING ERRCODE = '22023',
            MESSAGE = 'Shift must be MORNING, AFTERNOON, or ALL_DAY';
    END IF;

    IF p_completed_quantity IS NOT NULL AND p_completed_quantity <= 0 THEN
        RAISE EXCEPTION USING ERRCODE = '22023',
            MESSAGE = 'Completed quantity must be greater than zero';
    END IF;

    IF p_setup_work_day_id IS NOT NULL THEN
        IF NOT EXISTS (
            SELECT 1
            FROM ops.setup_work_day wd
            WHERE wd.setup_work_day_id = p_setup_work_day_id
              AND wd.setup_session_id = v_setup_session_id
        ) THEN
            RAISE EXCEPTION USING ERRCODE = '22023',
                MESSAGE = 'Progress work day must belong to the same Setup Session';
        END IF;

        SELECT wdt.setup_work_day_task_id
          INTO v_assignment_id
        FROM ops.setup_work_day_task wdt
        WHERE wdt.setup_work_day_id = p_setup_work_day_id
          AND wdt.setup_session_task_id = p_setup_session_task_id
          AND wdt.shift_code = v_shift
        LIMIT 1;
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
        shift_code,
        crew_count,
        duration_minutes,
        completed_quantity,
        completed_units,
        progress_note,
        marks_task_complete,
        recorded_at
    ) VALUES (
        p_setup_session_task_id,
        p_setup_work_day_id,
        v_assignment_id,
        v_shift,
        p_crew_count,
        p_duration_minutes,
        p_completed_quantity,
        nullif(btrim(p_completed_units), ''),
        nullif(btrim(p_progress_note), ''),
        coalesce(p_mark_complete, false),
        v_recorded_at
    )
    RETURNING ops.setup_task_progress.setup_task_progress_id
      INTO v_progress_id;

    SELECT sum(p.duration_minutes)
      INTO v_total_duration
    FROM ops.setup_task_progress p
    WHERE p.setup_session_task_id = p_setup_session_task_id
      AND p.duration_minutes IS NOT NULL;

    UPDATE ops.setup_session_task st
       SET actual_started_at = coalesce(st.actual_started_at, v_recorded_at),
           actual_duration_minutes = v_total_duration,
           execution_status = CASE
               WHEN coalesce(p_mark_complete, false) THEN 'COMPLETE'
               WHEN st.execution_status = 'COMPLETE' THEN st.execution_status
               ELSE 'IN_PROGRESS'
           END,
           actual_completed_at = CASE
               WHEN coalesce(p_mark_complete, false) THEN v_recorded_at
               ELSE st.actual_completed_at
           END,
           actual_crew_count = CASE
               WHEN coalesce(p_mark_complete, false) THEN p_crew_count
               ELSE st.actual_crew_count
           END,
           completion_note = CASE
               WHEN coalesce(p_mark_complete, false)
                   THEN nullif(btrim(p_progress_note), '')
               ELSE st.completion_note
           END,
           completed_by_person_id = CASE
               WHEN coalesce(p_mark_complete, false) THEN v_person_id
               ELSE st.completed_by_person_id
           END
     WHERE st.setup_session_task_id = p_setup_session_task_id
     RETURNING st.execution_status INTO v_status;

    IF v_assignment_id IS NOT NULL THEN
        UPDATE ops.setup_work_day_task wdt
           SET actual_crew_count = p_crew_count,
               started_at = coalesce(wdt.started_at, v_recorded_at),
               completed_at = CASE
                   WHEN coalesce(p_mark_complete, false) THEN v_recorded_at
                   ELSE wdt.completed_at
               END,
               notes = CASE
                   WHEN nullif(btrim(p_progress_note), '') IS NOT NULL
                       THEN p_progress_note
                   ELSE wdt.notes
               END
         WHERE wdt.setup_work_day_task_id = v_assignment_id;
    END IF;

    RETURN QUERY
    SELECT v_progress_id,
           p_setup_session_task_id,
           v_status,
           v_recorded_at,
           v_display_name;
END;
$function$;

REVOKE ALL ON FUNCTION ops.record_setup_task_progress(
    text,bigint,bigint,text,integer,integer,integer,text,text,boolean
) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION ops.record_setup_task_progress(
    text,bigint,bigint,text,integer,integer,integer,text,text,boolean
) TO fieldwiring_app;

COMMIT;

SELECT
    EXISTS (
        SELECT 1
        FROM information_schema.columns
        WHERE table_schema = 'ops'
          AND table_name = 'setup_task_progress'
          AND column_name = 'duration_minutes'
    ) AS duration_column_ready,
    to_regprocedure(
        'ops.record_setup_task_progress(text,bigint,bigint,text,integer,integer,integer,text,text,boolean)'
    ) IS NOT NULL AS duration_progress_command_ready,
    to_regprocedure(
        'ops.record_setup_task_progress(text,bigint,bigint,text,integer,integer,text,text,boolean)'
    ) IS NULL AS old_progress_command_removed;
