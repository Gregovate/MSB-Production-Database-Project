-- Setup #205 / #122: Correct daily planned crew-size edits after actual work.
-- Operator-confirmed October 16, 2026. Recorded actual crew/work remains protected.
-- Replaces only the existing SECURITY DEFINER function, not data or history.
-- 074 is reserved on the parked notification branch; use independent 075.
BEGIN;

DO $preflight$
BEGIN
    IF to_regprocedure('ops.update_setup_work_day_crew(text,bigint,integer,integer,integer)') IS NULL
       OR to_regclass('ops.setup_work_day_crew') IS NULL
       OR to_regclass('ops.setup_work_day_task') IS NULL
       OR NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'fieldwiring_app') THEN
        RAISE EXCEPTION 'Accepted Setup crew command and fieldwiring_app role are required before #205 planned-count correction';
    END IF;
END;
$preflight$;

CREATE OR REPLACE FUNCTION ops.update_setup_work_day_crew(
    p_email text,
    p_setup_work_day_crew_id bigint,
    p_am_planned_crew_count integer,
    p_pm_planned_crew_count integer,
    p_captain_person_id integer
)
RETURNS TABLE (
    setup_work_day_crew_id bigint,
    am_planned_crew_count integer,
    pm_planned_crew_count integer,
    captain_person_id integer,
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
    v_current_am integer;
    v_current_pm integer;
    v_current_captain integer;
BEGIN
    SELECT a.directus_user_id, a.person_id, a.display_name
      INTO v_directus_user_id, v_person_id, v_display_name
    FROM ref.setup_management_actor(p_email, false) a;

    IF (p_am_planned_crew_count IS NOT NULL AND p_am_planned_crew_count < 0)
       OR (p_pm_planned_crew_count IS NOT NULL AND p_pm_planned_crew_count < 0) THEN
        RAISE EXCEPTION USING ERRCODE = '22023',
            MESSAGE = 'Planned shift crew count cannot be negative';
    END IF;

    IF p_captain_person_id IS NOT NULL
       AND NOT EXISTS (
           SELECT 1
           FROM ref.person p
           WHERE p.person_id = p_captain_person_id
             AND p.active_flag
       ) THEN
        RAISE EXCEPTION USING ERRCODE = '22023',
            MESSAGE = 'Selected Crew Captain must be an active person';
    END IF;

    SELECT c.am_planned_crew_count,
           c.pm_planned_crew_count,
           c.captain_person_id
      INTO v_current_am, v_current_pm, v_current_captain
    FROM ops.setup_work_day_crew c
    WHERE c.setup_work_day_crew_id = p_setup_work_day_crew_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION USING ERRCODE = 'P0002',
            MESSAGE = 'Setup work-day crew was not found';
    END IF;

    -- #205: Daily AM/PM planned counts remain mutable despite reported actual
    -- work. Actual task crew counts and progress are stored separately and
    -- must never be altered by this planning-only function.
    -- Keep Captain identity protected by its separate historical-work gate.

    IF p_captain_person_id IS DISTINCT FROM v_current_captain
       AND EXISTS (
           SELECT 1
           FROM ops.setup_work_day_task wdt
           WHERE wdt.setup_work_day_crew_id = p_setup_work_day_crew_id
             AND (
                 wdt.actual_crew_count IS NOT NULL
                 OR wdt.started_at IS NOT NULL
                 OR wdt.completed_at IS NOT NULL
                 OR EXISTS (
                     SELECT 1
                     FROM ops.setup_task_progress p
                     WHERE p.setup_work_day_task_id = wdt.setup_work_day_task_id
                 )
             )
       ) THEN
        RAISE EXCEPTION USING ERRCODE = '23514',
            MESSAGE = 'Actual work exists for this crew; preserve the Crew Captain as history';
    END IF;

    PERFORM pg_catalog.set_config('app.directus_user_uuid', v_directus_user_id::text, true);

    UPDATE ops.setup_work_day_crew c
       SET am_planned_crew_count = p_am_planned_crew_count,
           pm_planned_crew_count = p_pm_planned_crew_count,
           captain_person_id = p_captain_person_id
     WHERE c.setup_work_day_crew_id = p_setup_work_day_crew_id;

    RETURN QUERY
    SELECT c.setup_work_day_crew_id,
           c.am_planned_crew_count,
           c.pm_planned_crew_count,
           c.captain_person_id,
           v_display_name
    FROM ops.setup_work_day_crew c
    WHERE c.setup_work_day_crew_id = p_setup_work_day_crew_id;
END;
$function$;

REVOKE ALL ON FUNCTION ops.update_setup_work_day_crew(text,bigint,integer,integer,integer) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION ops.update_setup_work_day_crew(text,bigint,integer,integer,integer) TO fieldwiring_app;

COMMENT ON FUNCTION ops.update_setup_work_day_crew(text,bigint,integer,integer,integer) IS
    'Manager crew command: planned AM/PM staffing may be revised after work; Captain changes remain history-locked and actual task counts/progress are immutable.';

COMMIT;
