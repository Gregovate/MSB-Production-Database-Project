-- Setup #205: safe removal of accidental empty Setup work days.
-- A work day may be deleted only when it is still a truly empty PLANNED shell:
-- exactly Crew A, Captain TBD, no staffing counts, no assignments/progress, and no notes.

BEGIN;

CREATE OR REPLACE FUNCTION ops.remove_empty_setup_work_day(
    p_email text,
    p_setup_work_day_id bigint
)
RETURNS TABLE (
    setup_work_day_id bigint,
    setup_day_number integer,
    work_date date,
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
    v_day_number integer;
    v_work_date date;
    v_day_status text;
    v_weather_note text;
    v_volunteer_note text;
    v_notes text;
    v_crew_count integer;
    v_crew_number integer;
    v_crew_code text;
    v_captain_person_id integer;
    v_am_planned_crew_count integer;
    v_pm_planned_crew_count integer;
BEGIN
    SELECT a.directus_user_id, a.person_id, a.display_name
      INTO v_directus_user_id, v_person_id, v_display_name
    FROM ref.setup_management_actor(p_email, false) a;

    SELECT wd.setup_session_id,
           wd.setup_day_number,
           wd.work_date,
           wd.day_status,
           wd.weather_note,
           wd.volunteer_note,
           wd.notes
      INTO v_session_id,
           v_day_number,
           v_work_date,
           v_day_status,
           v_weather_note,
           v_volunteer_note,
           v_notes
    FROM ops.setup_work_day wd
    WHERE wd.setup_work_day_id = p_setup_work_day_id
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION USING ERRCODE = 'P0002',
            MESSAGE = 'Setup work day was not found';
    END IF;

    IF v_day_status <> 'PLANNED' THEN
        RAISE EXCEPTION USING ERRCODE = '23514',
            MESSAGE = 'Only an empty Planned Setup work day can be removed';
    END IF;

    IF nullif(btrim(v_weather_note), '') IS NOT NULL
       OR nullif(btrim(v_volunteer_note), '') IS NOT NULL
       OR nullif(btrim(v_notes), '') IS NOT NULL THEN
        RAISE EXCEPTION USING ERRCODE = '23514',
            MESSAGE = 'Remove the Setup work-day notes before deleting the day';
    END IF;

    SELECT count(*)::integer,
           min(c.crew_number),
           min(c.crew_code),
           min(c.captain_person_id),
           min(c.am_planned_crew_count),
           min(c.pm_planned_crew_count)
      INTO v_crew_count,
           v_crew_number,
           v_crew_code,
           v_captain_person_id,
           v_am_planned_crew_count,
           v_pm_planned_crew_count
    FROM ops.setup_work_day_crew c
    WHERE c.setup_work_day_id = p_setup_work_day_id;

    IF v_crew_count <> 1
       OR v_crew_number <> 1
       OR v_crew_code <> 'A' THEN
        RAISE EXCEPTION USING ERRCODE = '23514',
            MESSAGE = 'Only a Setup work day with exactly the default Crew A can be removed';
    END IF;

    IF v_captain_person_id IS NOT NULL THEN
        RAISE EXCEPTION USING ERRCODE = '23514',
            MESSAGE = 'A Setup work day with an assigned Captain cannot be removed';
    END IF;

    IF v_am_planned_crew_count IS NOT NULL
       OR v_pm_planned_crew_count IS NOT NULL THEN
        RAISE EXCEPTION USING ERRCODE = '23514',
            MESSAGE = 'A Setup work day with planned staffing cannot be removed';
    END IF;

    IF EXISTS (
        SELECT 1
        FROM ops.setup_work_day_task wdt
        WHERE wdt.setup_work_day_id = p_setup_work_day_id
    ) THEN
        RAISE EXCEPTION USING ERRCODE = '23514',
            MESSAGE = 'Move or remove scheduled tasks before deleting the Setup work day';
    END IF;

    IF EXISTS (
        SELECT 1
        FROM ops.setup_task_progress p
        WHERE p.setup_work_day_id = p_setup_work_day_id
    ) THEN
        RAISE EXCEPTION USING ERRCODE = '23514',
            MESSAGE = 'Reported work exists for this Setup work day; preserve it as history';
    END IF;

    PERFORM pg_catalog.set_config('app.directus_user_uuid', v_directus_user_id::text, true);

    DELETE FROM ops.setup_work_day wd
    WHERE wd.setup_work_day_id = p_setup_work_day_id;

    PERFORM ops.resequence_setup_future_work_days(v_session_id);

    RETURN QUERY
    SELECT p_setup_work_day_id, v_day_number, v_work_date, v_display_name;
END;
$function$;

REVOKE ALL ON FUNCTION ops.remove_empty_setup_work_day(text,bigint) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION ops.remove_empty_setup_work_day(text,bigint) TO fieldwiring_app;

COMMIT;

SELECT to_regprocedure('ops.remove_empty_setup_work_day(text,bigint)') IS NOT NULL
    AS empty_work_day_removal_ready;
