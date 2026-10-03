/* ============================================================================
Migration 064 — #205 guarded removal of an accidental Setup Work Day

Purpose:
  - allow an authorized Setup Manager to remove a PLANNED Work Day created by
    mistake;
  - preserve all scheduled/executed history by refusing deletion when any
    assignment or progress exists;
  - remove the day-owned Crew rows only through their existing ON DELETE CASCADE;
  - resequence remaining disposable/unworked Work Days after deletion;
  - preserve least-privilege browser access through one SECURITY DEFINER command.
============================================================================ */

BEGIN;

DO $preflight$
BEGIN
    IF to_regclass('ops.setup_work_day') IS NULL
       OR to_regclass('ops.setup_work_day_crew') IS NULL
       OR to_regclass('ops.setup_work_day_task') IS NULL
       OR to_regclass('ops.setup_task_progress') IS NULL
       OR to_regprocedure('ref.setup_management_actor(text,boolean)') IS NULL
       OR to_regprocedure('ops.resequence_setup_future_work_days(bigint)') IS NULL THEN
        RAISE EXCEPTION 'Accepted Setup Scheduling Board foundation is required before migration 064';
    END IF;

    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'fieldwiring_app') THEN
        RAISE EXCEPTION 'Required application role fieldwiring_app does not exist';
    END IF;
END
$preflight$;

CREATE OR REPLACE FUNCTION ops.remove_empty_setup_work_day(
    p_email text,
    p_setup_work_day_id bigint
)
RETURNS TABLE (
    setup_work_day_id bigint,
    setup_session_id bigint,
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
    v_work_date date;
    v_status text;
BEGIN
    SELECT a.directus_user_id, a.person_id, a.display_name
      INTO v_directus_user_id, v_person_id, v_display_name
    FROM ref.setup_management_actor(p_email, false) a;

    SELECT wd.setup_session_id, wd.work_date, upper(wd.day_status)
      INTO v_session_id, v_work_date, v_status
    FROM ops.setup_work_day wd
    WHERE wd.setup_work_day_id = p_setup_work_day_id
    FOR UPDATE;

    IF v_session_id IS NULL THEN
        RAISE EXCEPTION USING ERRCODE = 'P0002',
            MESSAGE = 'Setup work day was not found';
    END IF;

    IF v_status <> 'PLANNED' THEN
        RAISE EXCEPTION USING ERRCODE = '23514',
            MESSAGE = 'Only an unused PLANNED Setup work day can be removed';
    END IF;

    IF EXISTS (
        SELECT 1
        FROM ops.setup_work_day_task wdt
        WHERE wdt.setup_work_day_id = p_setup_work_day_id
    ) THEN
        RAISE EXCEPTION USING ERRCODE = '23514',
            MESSAGE = 'Move or remove scheduled work before removing this Setup work day';
    END IF;

    IF EXISTS (
        SELECT 1
        FROM ops.setup_task_progress p
        WHERE p.setup_work_day_id = p_setup_work_day_id
    ) THEN
        RAISE EXCEPTION USING ERRCODE = '23514',
            MESSAGE = 'Reported work exists for this Setup work day and it cannot be removed';
    END IF;

    PERFORM pg_catalog.set_config('app.directus_user_uuid', v_directus_user_id::text, true);

    DELETE FROM ops.setup_work_day wd
    WHERE wd.setup_work_day_id = p_setup_work_day_id;

    PERFORM ops.resequence_setup_future_work_days(v_session_id);

    RETURN QUERY
    SELECT p_setup_work_day_id, v_session_id, v_work_date, v_display_name;
END;
$function$;

REVOKE ALL ON FUNCTION ops.remove_empty_setup_work_day(text,bigint) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION ops.remove_empty_setup_work_day(text,bigint) TO fieldwiring_app;

COMMIT;
