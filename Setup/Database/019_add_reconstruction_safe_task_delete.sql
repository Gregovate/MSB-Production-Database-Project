/* ============================================================================
MSB Setup Session — reconstruction-safe task delete
Issue: #122
Status: IMPLEMENTATION CANDIDATE — DO NOT APPLY TO PRODUCTION WITHOUT REVIEW
Revision: 2026-09-08 V0.1.0

Purpose:
  Allow Managers to remove mistaken reusable/annual Setup tasks while the task
  exists only in HISTORICAL_VERIFICATION reconstruction and has no meaningful
  execution, scheduling, progress, or movement evidence.

Why this exists:
  The 2025 reconstruction is expected to discover duplicates, bad task
  boundaries, wrong Stage assignments, shorthand interpretation mistakes, and
  provisional tasks that should never have existed. Those mistakes must be
  cheap to correct before a future operational Setup Session depends on them.

Guardrails:
  - Manager authorization is rechecked through ref.setup_management_actor().
  - Any occurrence in a non-HISTORICAL_VERIFICATION Setup Session blocks delete.
  - Work-day assignment, progress, movement, actual dates/crew/duration,
    completion evidence, or planning evidence blocks delete.
  - Seed/reconstruction status such as COMPLETE/VERIFIED alone does not count
    as meaningful execution evidence because the 2025 seed used provisional
    status values before real historical reconstruction.
  - Known reusable-definition relationships are removed with the mistaken task.
  - Any unknown/future FK dependency remains protected by PostgreSQL and causes
    the final task delete to fail closed.
  - fieldwiring_app receives EXECUTE only; no broad table DML is granted.
============================================================================ */

BEGIN;

DO $preflight$
BEGIN
    IF to_regclass('ref.setup_task') IS NULL
       OR to_regclass('ref.setup_task_dependency') IS NULL
       OR to_regclass('ref.setup_task_display') IS NULL
       OR to_regclass('ref.setup_task_container_support') IS NULL
       OR to_regclass('ref.setup_task_captain') IS NULL
       OR to_regclass('ref.setup_task_resource') IS NULL
       OR to_regclass('ops.setup_session') IS NULL
       OR to_regclass('ops.setup_session_task') IS NULL
       OR to_regclass('ops.setup_work_day_task') IS NULL
       OR to_regclass('ops.setup_movement_event') IS NULL
       OR to_regclass('ops.setup_task_progress') IS NULL THEN
        RAISE EXCEPTION 'Setup reconstruction-safe delete dependencies are missing';
    END IF;

    IF to_regprocedure('ref.setup_management_actor(text,boolean)') IS NULL THEN
        RAISE EXCEPTION 'ref.setup_management_actor(text,boolean) is required first';
    END IF;

    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'fieldwiring_app') THEN
        RAISE EXCEPTION 'Required application role fieldwiring_app does not exist';
    END IF;
END
$preflight$;

CREATE OR REPLACE FUNCTION ref.delete_setup_reconstruction_task(
    p_email text,
    p_setup_task_id bigint
)
RETURNS TABLE (
    setup_task_id bigint,
    deleted_annual_rows integer,
    deleted_dependency_rows integer,
    deleted_display_rows integer,
    deleted_support_container_rows integer,
    deleted_captain_rows integer,
    deleted_resource_rows integer,
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
    v_annual integer := 0;
    v_dependencies integer := 0;
    v_displays integer := 0;
    v_support integer := 0;
    v_captains integer := 0;
    v_resources integer := 0;
BEGIN
    SELECT a.directus_user_id, a.person_id, a.display_name
      INTO v_directus_user_id, v_person_id, v_display_name
    FROM ref.setup_management_actor(p_email, false) AS a;

    IF NOT EXISTS (
        SELECT 1
        FROM ref.setup_task t
        WHERE t.setup_task_id = p_setup_task_id
    ) THEN
        RAISE EXCEPTION USING
            ERRCODE = 'P0002',
            MESSAGE = 'Setup task was not found';
    END IF;

    /* Once an operational/future session contains this reusable task, hard
       delete is no longer the correction tool. Preserve the reusable identity
       and use season removal/retirement instead. */
    IF EXISTS (
        SELECT 1
        FROM ops.setup_session_task st
        JOIN ops.setup_session ss
          ON ss.setup_session_id = st.setup_session_id
        WHERE st.setup_task_id = p_setup_task_id
          AND ss.session_status <> 'HISTORICAL_VERIFICATION'
    ) THEN
        RAISE EXCEPTION USING
            ERRCODE = '23503',
            MESSAGE = 'Setup task is already present in an operational/planning season and cannot be hard deleted';
    END IF;

    /* Meaningful annual execution/planning evidence blocks destructive delete. */
    IF EXISTS (
        SELECT 1
        FROM ops.setup_session_task st
        WHERE st.setup_task_id = p_setup_task_id
          AND (
              st.actual_started_at IS NOT NULL
              OR st.actual_completed_at IS NOT NULL
              OR st.actual_crew_count IS NOT NULL
              OR st.actual_duration_minutes IS NOT NULL
              OR st.planned_date IS NOT NULL
              OR nullif(btrim(st.plan_change_reason), '') IS NOT NULL
              OR nullif(btrim(st.completion_note), '') IS NOT NULL
              OR st.completed_by_person_id IS NOT NULL
          )
    ) THEN
        RAISE EXCEPTION USING
            ERRCODE = '23503',
            MESSAGE = 'Setup task has annual planning/execution evidence and cannot be hard deleted';
    END IF;

    IF EXISTS (
        SELECT 1
        FROM ops.setup_work_day_task wdt
        JOIN ops.setup_session_task st
          ON st.setup_session_task_id = wdt.setup_session_task_id
        WHERE st.setup_task_id = p_setup_task_id
    ) THEN
        RAISE EXCEPTION USING
            ERRCODE = '23503',
            MESSAGE = 'Setup task has work-day assignment history and cannot be hard deleted';
    END IF;

    IF EXISTS (
        SELECT 1
        FROM ops.setup_task_progress p
        JOIN ops.setup_session_task st
          ON st.setup_session_task_id = p.setup_session_task_id
        WHERE st.setup_task_id = p_setup_task_id
    ) THEN
        RAISE EXCEPTION USING
            ERRCODE = '23503',
            MESSAGE = 'Setup task has recorded progress and cannot be hard deleted';
    END IF;

    IF EXISTS (
        SELECT 1
        FROM ops.setup_movement_event me
        JOIN ops.setup_session_task st
          ON st.setup_session_task_id = me.setup_session_task_id
        WHERE st.setup_task_id = p_setup_task_id
    ) THEN
        RAISE EXCEPTION USING
            ERRCODE = '23503',
            MESSAGE = 'Setup task has movement history and cannot be hard deleted';
    END IF;

    PERFORM pg_catalog.set_config(
        'app.directus_user_uuid',
        v_directus_user_id::text,
        true
    );

    /* Annual rows are reconstruction shells only because all meaningful
       annual child/evidence rows were proven absent above. */
    DELETE FROM ops.setup_session_task st
     WHERE st.setup_task_id = p_setup_task_id;
    GET DIAGNOSTICS v_annual = ROW_COUNT;

    DELETE FROM ref.setup_task_dependency d
     WHERE d.setup_task_id = p_setup_task_id
        OR d.prerequisite_setup_task_id = p_setup_task_id;
    GET DIAGNOSTICS v_dependencies = ROW_COUNT;

    DELETE FROM ref.setup_task_display td
     WHERE td.setup_task_id = p_setup_task_id;
    GET DIAGNOSTICS v_displays = ROW_COUNT;

    DELETE FROM ref.setup_task_container_support tc
     WHERE tc.setup_task_id = p_setup_task_id;
    GET DIAGNOSTICS v_support = ROW_COUNT;

    DELETE FROM ref.setup_task_captain c
     WHERE c.setup_task_id = p_setup_task_id;
    GET DIAGNOSTICS v_captains = ROW_COUNT;

    DELETE FROM ref.setup_task_resource tr
     WHERE tr.setup_task_id = p_setup_task_id;
    GET DIAGNOSTICS v_resources = ROW_COUNT;

    /* Do not CASCADE. A new/future relationship not inventoried here must stop
       the delete through its normal FK instead of being silently discarded. */
    DELETE FROM ref.setup_task t
     WHERE t.setup_task_id = p_setup_task_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION USING
            ERRCODE = 'P0002',
            MESSAGE = 'Setup task disappeared before reconstruction delete completed';
    END IF;

    RETURN QUERY
    SELECT
        p_setup_task_id,
        v_annual,
        v_dependencies,
        v_displays,
        v_support,
        v_captains,
        v_resources,
        v_display_name;
END;
$function$;

REVOKE ALL ON FUNCTION ref.delete_setup_reconstruction_task(text,bigint) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION ref.delete_setup_reconstruction_task(text,bigint) TO fieldwiring_app;

COMMIT;
