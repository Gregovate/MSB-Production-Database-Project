/* ============================================================================
MSB Setup Session — fix reconstruction-safe delete annual dependency ordering
Issues: #145 / #122
Status: IMPLEMENTATION CANDIDATE — DO NOT APPLY TO PRODUCTION WITHOUT REVIEW
Revision: 2026-09-22

Purpose:
  Repair the governed reusable-task delete command for task-owned relationships
  added after migration 019:
  - migration 032 added reusable task Extra Material requirements and source rows;
  - migration 050 added annual setup_session_task_dependency rows.

Observed failure:
  Deleting a reconstruction mistake such as reusable "See Work Order 372"
  failed on fk_setup_session_task_dependency_task because migration 019
  attempted to delete ops.setup_session_task before deleting annual dependency
  rows that referenced that shell.

Boundary:
  - preserve every existing hard-delete guard;
  - after those guards pass, remove task-owned reconstruction relationships in
    explicit FK-safe order, including Extra Material source/requirement rows;
  - delete only annual dependency rows attached to annual shells for the
    reusable task after all work/progress/movement evidence guards pass;
  - preserve shared Catalog objects (Displays, Containers, Resources, people,
    Extra Material catalog rows); delete only their task relationship rows;
  - keep unknown/future relationships fail-closed;
  - no CASCADE;
  - no broad fieldwiring_app table DML.
============================================================================ */

BEGIN;

DO $preflight$
BEGIN
    IF to_regclass('ops.setup_session_task_dependency') IS NULL THEN
        RAISE EXCEPTION
            'ops.setup_session_task_dependency is required before #145 delete-order repair';
    END IF;

    IF to_regclass('ref.setup_task_extra_material') IS NULL
       OR to_regclass('ref.setup_task_extra_material_source') IS NULL THEN
        RAISE EXCEPTION
            'Setup Extra Material task relationship tables are required before #145 delete-order repair';
    END IF;

    IF to_regprocedure('ref.delete_setup_reconstruction_task(text,bigint)') IS NULL THEN
        RAISE EXCEPTION
            'Existing reconstruction-safe Setup delete command is required';
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

    /* Annual dependency rows introduced by the Scheduling Board reference
       the annual task shell from both sides. The shell cannot be removed until
       those dependency rows are removed first. All meaningful work/progress/
       movement evidence was already proven absent above, so these are safe
       reconstruction/planning relationship shells, not execution history. */
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

    /* Migration 032 added task-owned Extra Material requirements with source
       rows beneath them. These are reusable task relationship/configuration
       rows, not independent historical evidence. Delete the source children
       first, then the task requirement rows. Shared Containers and the
       ref.setup_extra_material catalog remain untouched. */
    DELETE FROM ref.setup_task_extra_material_source src
     WHERE src.setup_task_extra_material_id IN (
               SELECT tm.setup_task_extra_material_id
               FROM ref.setup_task_extra_material tm
               WHERE tm.setup_task_id = p_setup_task_id
           );

    DELETE FROM ref.setup_task_extra_material tm
     WHERE tm.setup_task_id = p_setup_task_id;

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

SELECT
    to_regprocedure('ref.delete_setup_reconstruction_task(text,bigint)') IS NOT NULL
        AS reconstruction_delete_ready,
    has_function_privilege(
        'fieldwiring_app',
        'ref.delete_setup_reconstruction_task(text,bigint)',
        'EXECUTE'
    ) AS app_can_execute_delete,
    has_table_privilege(
        'fieldwiring_app',
        'ops.setup_session_task_dependency',
        'DELETE'
    ) AS app_has_forbidden_direct_annual_dependency_delete;
