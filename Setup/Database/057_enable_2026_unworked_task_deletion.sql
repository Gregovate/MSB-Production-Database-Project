/* ============================================================================
Setup #122 — 2026 launch: unworked task deletion semantics
Revision: 2026-09-24

Purpose:
  - 2026 is the first authoritative Setup-history year.
  - planning-only annual state must not make a mistaken/unneeded task permanent;
  - actual reported/executed work remains protected history;
  - existing material-assignment-before-delete operator behavior is preserved
    and enforced fail-closed at the governed command boundary;
  - add a governed delete for unworked SEASON_ONLY annual tasks.

Authority:
  - reusable Catalog task delete remains ref.delete_setup_reconstruction_task();
  - browser/application roles receive EXECUTE only, never broad table DELETE.
============================================================================ */

BEGIN;

DO $preflight$
BEGIN
    IF to_regprocedure('ref.delete_setup_reconstruction_task(text,bigint)') IS NULL
       OR to_regprocedure('ref.setup_management_actor(text,boolean)') IS NULL
       OR to_regclass('ops.setup_session_task') IS NULL
       OR to_regclass('ops.setup_session_task_dependency') IS NULL
       OR to_regclass('ops.setup_work_day_task') IS NULL
       OR to_regclass('ops.setup_task_progress') IS NULL
       OR to_regclass('ops.setup_movement_event') IS NULL
       OR to_regclass('ref.setup_task_display') IS NULL
       OR to_regclass('ref.setup_task_container_support') IS NULL
       OR to_regclass('ref.setup_task_extra_material') IS NULL THEN
        RAISE EXCEPTION 'Setup #122 2026 task-delete prerequisites are incomplete';
    END IF;

    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'fieldwiring_app') THEN
        RAISE EXCEPTION 'Required application role fieldwiring_app is missing';
    END IF;
END
$preflight$;

/* --------------------------------------------------------------------------
   REUSABLE TASK DELETE

   Planning-only state is disposable:
     - annual membership / planned order / planned date
     - work-day / crew assignment
     - annual/reusable prerequisite shells
     - readiness/planning notes

   Protected:
     - reported progress / actual work / completion
     - task-linked movement evidence
     - physical-material ownership/assignment that must be moved first
   -------------------------------------------------------------------------- */
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

    /* Preserve the current operator rule: material must be moved/reassigned
       before deleting the reusable task. Do not silently clean it up here. */
    IF EXISTS (
        SELECT 1 FROM ref.setup_task_display d
        WHERE d.setup_task_id = p_setup_task_id
    ) THEN
        RAISE EXCEPTION USING
            ERRCODE = '23503',
            MESSAGE = 'Setup task still has Display material assignments. Move or reassign them before deleting the task.';
    END IF;

    IF EXISTS (
        SELECT 1 FROM ref.setup_task_container_support c
        WHERE c.setup_task_id = p_setup_task_id
    ) THEN
        RAISE EXCEPTION USING
            ERRCODE = '23503',
            MESSAGE = 'Setup task still has KIT/support Container assignments. Move or remove those assignments before deleting the task.';
    END IF;

    IF EXISTS (
        SELECT 1 FROM ref.setup_task_extra_material m
        WHERE m.setup_task_id = p_setup_task_id
    ) THEN
        RAISE EXCEPTION USING
            ERRCODE = '23503',
            MESSAGE = 'Setup task still has Extra Material requirements. Move or remove those requirements before deleting the task.';
    END IF;

    /* Actual/reporting evidence is the history boundary. */
    IF EXISTS (
        SELECT 1
        FROM ops.setup_task_progress p
        JOIN ops.setup_session_task st
          ON st.setup_session_task_id = p.setup_session_task_id
        WHERE st.setup_task_id = p_setup_task_id
    ) THEN
        RAISE EXCEPTION USING
            ERRCODE = '23503',
            MESSAGE = 'Setup task has reported work/progress and cannot be hard deleted';
    END IF;

    IF EXISTS (
        SELECT 1
        FROM ops.setup_session_task st
        WHERE st.setup_task_id = p_setup_task_id
          AND (
              st.actual_started_at IS NOT NULL
              OR st.actual_completed_at IS NOT NULL
              OR st.actual_crew_count IS NOT NULL
              OR st.actual_duration_minutes IS NOT NULL
              OR nullif(btrim(st.completion_note), '') IS NOT NULL
              OR st.completed_by_person_id IS NOT NULL
          )
    ) THEN
        RAISE EXCEPTION USING
            ERRCODE = '23503',
            MESSAGE = 'Setup task has reported actual work/completion and cannot be hard deleted';
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
            MESSAGE = 'Setup task has movement/execution evidence and cannot be hard deleted';
    END IF;

    PERFORM pg_catalog.set_config(
        'app.directus_user_uuid',
        v_directus_user_id::text,
        true
    );

    /* Planning-only annual relationships are deliberately disposable. */
    DELETE FROM ops.setup_session_task_dependency d
     WHERE d.setup_session_task_id IN (
               SELECT st.setup_session_task_id
               FROM ops.setup_session_task st
               WHERE st.setup_task_id = p_setup_task_id
           )
        OR d.prerequisite_setup_session_task_id IN (
               SELECT st.setup_session_task_id
               FROM ops.setup_session_task st
               WHERE st.setup_task_id = p_setup_task_id
           );

    DELETE FROM ops.setup_work_day_task wdt
     WHERE wdt.setup_session_task_id IN (
               SELECT st.setup_session_task_id
               FROM ops.setup_session_task st
               WHERE st.setup_task_id = p_setup_task_id
           );

    DELETE FROM ops.setup_session_task st
     WHERE st.setup_task_id = p_setup_task_id;
    GET DIAGNOSTICS v_annual = ROW_COUNT;

    DELETE FROM ref.setup_task_dependency d
     WHERE d.setup_task_id = p_setup_task_id
        OR d.prerequisite_setup_task_id = p_setup_task_id;
    GET DIAGNOSTICS v_dependencies = ROW_COUNT;

    /* Material rows are intentionally not deleted here. Preflight above proved
       they are absent before this point. */
    DELETE FROM ref.setup_task_captain c
     WHERE c.setup_task_id = p_setup_task_id;
    GET DIAGNOSTICS v_captains = ROW_COUNT;

    DELETE FROM ref.setup_task_resource r
     WHERE r.setup_task_id = p_setup_task_id;
    GET DIAGNOSTICS v_resources = ROW_COUNT;

    /* Do not CASCADE. Any future child relationship not inventoried here must
       fail closed through its normal FK instead of disappearing silently. */
    DELETE FROM ref.setup_task t
     WHERE t.setup_task_id = p_setup_task_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION USING
            ERRCODE = 'P0002',
            MESSAGE = 'Setup task disappeared before governed delete completed';
    END IF;

    RETURN QUERY
    SELECT
        p_setup_task_id,
        v_annual,
        v_dependencies,
        0,
        0,
        v_captains,
        v_resources,
        v_display_name;
END;
$function$;

REVOKE ALL ON FUNCTION ref.delete_setup_reconstruction_task(text,bigint) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION ref.delete_setup_reconstruction_task(text,bigint) TO fieldwiring_app;

/* --------------------------------------------------------------------------
   SEASON-ONLY TASK DELETE
   -------------------------------------------------------------------------- */
CREATE OR REPLACE FUNCTION ops.delete_unworked_setup_season_task(
    p_email text,
    p_setup_session_task_id bigint
)
RETURNS TABLE (
    setup_session_task_id bigint,
    deleted_assignment_rows integer,
    deleted_dependency_rows integer,
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
    v_origin text;
    v_assignments integer := 0;
    v_dependencies integer := 0;
BEGIN
    SELECT a.directus_user_id, a.person_id, a.display_name
      INTO v_directus_user_id, v_person_id, v_display_name
    FROM ref.setup_management_actor(p_email, false) AS a;

    SELECT st.task_origin
      INTO v_origin
    FROM ops.setup_session_task st
    WHERE st.setup_session_task_id = p_setup_session_task_id;

    IF v_origin IS NULL THEN
        RAISE EXCEPTION USING
            ERRCODE = 'P0002',
            MESSAGE = 'Annual Setup task was not found';
    END IF;

    IF v_origin <> 'SEASON_ONLY' THEN
        RAISE EXCEPTION USING
            ERRCODE = '22023',
            MESSAGE = 'Reusable-origin annual work must be deleted through the Reusable Task Catalog';
    END IF;

    IF EXISTS (
        SELECT 1 FROM ops.setup_task_progress p
        WHERE p.setup_session_task_id = p_setup_session_task_id
    ) THEN
        RAISE EXCEPTION USING
            ERRCODE = '23503',
            MESSAGE = 'Season-only Setup task has reported work/progress and cannot be deleted';
    END IF;

    IF EXISTS (
        SELECT 1
        FROM ops.setup_session_task st
        WHERE st.setup_session_task_id = p_setup_session_task_id
          AND (
              st.actual_started_at IS NOT NULL
              OR st.actual_completed_at IS NOT NULL
              OR st.actual_crew_count IS NOT NULL
              OR st.actual_duration_minutes IS NOT NULL
              OR nullif(btrim(st.completion_note), '') IS NOT NULL
              OR st.completed_by_person_id IS NOT NULL
          )
    ) THEN
        RAISE EXCEPTION USING
            ERRCODE = '23503',
            MESSAGE = 'Season-only Setup task has reported actual work/completion and cannot be deleted';
    END IF;

    IF EXISTS (
        SELECT 1 FROM ops.setup_movement_event me
        WHERE me.setup_session_task_id = p_setup_session_task_id
    ) THEN
        RAISE EXCEPTION USING
            ERRCODE = '23503',
            MESSAGE = 'Season-only Setup task has movement/execution evidence and cannot be deleted';
    END IF;

    PERFORM pg_catalog.set_config(
        'app.directus_user_uuid',
        v_directus_user_id::text,
        true
    );

    DELETE FROM ops.setup_session_task_dependency d
     WHERE d.setup_session_task_id = p_setup_session_task_id
        OR d.prerequisite_setup_session_task_id = p_setup_session_task_id;
    GET DIAGNOSTICS v_dependencies = ROW_COUNT;

    DELETE FROM ops.setup_work_day_task wdt
     WHERE wdt.setup_session_task_id = p_setup_session_task_id;
    GET DIAGNOSTICS v_assignments = ROW_COUNT;

    DELETE FROM ops.setup_session_task st
     WHERE st.setup_session_task_id = p_setup_session_task_id
       AND st.task_origin = 'SEASON_ONLY';

    IF NOT FOUND THEN
        RAISE EXCEPTION USING
            ERRCODE = 'P0002',
            MESSAGE = 'Season-only Setup task disappeared before governed delete completed';
    END IF;

    RETURN QUERY
    SELECT
        p_setup_session_task_id,
        v_assignments,
        v_dependencies,
        v_display_name;
END;
$function$;

REVOKE ALL ON FUNCTION ops.delete_unworked_setup_season_task(text,bigint) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION ops.delete_unworked_setup_season_task(text,bigint) TO fieldwiring_app;

COMMIT;

SELECT
    to_regprocedure('ref.delete_setup_reconstruction_task(text,bigint)') IS NOT NULL
        AS reusable_delete_ready,
    to_regprocedure('ops.delete_unworked_setup_season_task(text,bigint)') IS NOT NULL
        AS season_delete_ready,
    has_function_privilege(
        'fieldwiring_app',
        'ref.delete_setup_reconstruction_task(text,bigint)',
        'EXECUTE'
    ) AS app_can_delete_unworked_reusable,
    has_function_privilege(
        'fieldwiring_app',
        'ops.delete_unworked_setup_season_task(text,bigint)',
        'EXECUTE'
    ) AS app_can_delete_unworked_season_task;
