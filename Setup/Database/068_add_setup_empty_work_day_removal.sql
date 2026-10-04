-- Setup #205: safe removal of accidental empty Setup work days.
-- A work day may be deleted only when it is still an empty PLANNED shell:
-- exactly one Crew A, Captain TBD, and no assignments/progress.
-- Planned staffing counts and day notes are planning metadata and do not make
-- the day historical; deleting the work day intentionally discards them.

BEGIN;

CREATE OR REPLACE FUNCTION ops.reject_past_setup_work_day_insert()
RETURNS trigger
LANGUAGE plpgsql
SET search_path = pg_catalog, ops
AS $function$
BEGIN
    IF NEW.work_date < current_date THEN
        RAISE EXCEPTION USING ERRCODE = '22023',
            MESSAGE = 'Setup work days cannot be added in the past';
    END IF;
    RETURN NEW;
END;
$function$;

DROP TRIGGER IF EXISTS trg_setup_work_day_reject_past_insert ON ops.setup_work_day;
CREATE TRIGGER trg_setup_work_day_reject_past_insert
BEFORE INSERT ON ops.setup_work_day
FOR EACH ROW EXECUTE FUNCTION ops.reject_past_setup_work_day_insert();

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
    v_crew_count integer;
    v_crew_number integer;
    v_crew_code text;
    v_captain_person_id integer;
BEGIN
    SELECT a.directus_user_id, a.person_id, a.display_name
      INTO v_directus_user_id, v_person_id, v_display_name
    FROM ref.setup_management_actor(p_email, false) a;

    SELECT wd.setup_session_id,
           wd.setup_day_number,
           wd.work_date,
           wd.day_status
      INTO v_session_id,
           v_day_number,
           v_work_date,
           v_day_status
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

    SELECT count(*)::integer,
           min(c.crew_number),
           min(c.crew_code),
           min(c.captain_person_id)
      INTO v_crew_count,
           v_crew_number,
           v_crew_code,
           v_captain_person_id
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

SELECT
    to_regprocedure('ops.remove_empty_setup_work_day(text,bigint)') IS NOT NULL
        AS empty_work_day_removal_ready,
    to_regprocedure('ops.reject_past_setup_work_day_insert()') IS NOT NULL
        AS past_work_day_insert_guard_ready;
