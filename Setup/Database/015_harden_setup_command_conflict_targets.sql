/* ============================================================================
MSB Setup Session — harden PL/pgSQL conflict targets before Production
Issue: #122
Status: PRODUCTION CANDIDATE — REVIEW BEFORE APPLY
Revision: 2026-09-07 V0.3.3

Purpose:
  Correct the PostgreSQL ambiguity class found during Manager browser review.
  RETURNS TABLE output names are PL/pgSQL variables, so bare
  ON CONFLICT(column, ...) targets can collide with output-variable names.

  This migration replaces the three remaining governed commands with explicit
  named-constraint conflict targets:
    - ref.set_setup_task_resource
    - ref.set_setup_task_dependency
    - ops.set_setup_work_day_task

  The reusable-task creation command is corrected separately by migration 013.

Security:
  - function signatures remain unchanged;
  - fieldwiring_app retains EXECUTE only;
  - no broad table DML is granted.
============================================================================ */

BEGIN;

DO $preflight$
BEGIN
    IF to_regprocedure('ref.set_setup_task_resource(text,bigint,integer,integer,text,text,boolean)') IS NULL
       OR to_regprocedure('ref.set_setup_task_dependency(text,bigint,bigint,text,boolean)') IS NULL
       OR to_regprocedure('ops.set_setup_work_day_task(text,bigint,bigint,text,text,integer,integer,boolean)') IS NULL THEN
        RAISE EXCEPTION 'Setup migrations 008, 009, and 011 are required before migration 015';
    END IF;

    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'fieldwiring_app') THEN
        RAISE EXCEPTION 'Required application role fieldwiring_app does not exist';
    END IF;
END
$preflight$;

CREATE OR REPLACE FUNCTION ref.set_setup_task_resource(
    p_email text,
    p_setup_task_id bigint,
    p_setup_resource_id integer,
    p_quantity_required integer DEFAULT 1,
    p_requirement_type text DEFAULT 'REQUIRED',
    p_notes text DEFAULT NULL,
    p_active_flag boolean DEFAULT true
)
RETURNS TABLE (
    setup_task_id bigint,
    setup_resource_id integer,
    active_flag boolean,
    operator_display_name text
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, ref
AS $function$
DECLARE
    v_directus_user_id uuid;
    v_person_id integer;
    v_display_name text;
    v_requirement text := upper(btrim(coalesce(p_requirement_type, 'REQUIRED')));
    v_active boolean := coalesce(p_active_flag, true);
BEGIN
    SELECT a.directus_user_id, a.person_id, a.display_name
      INTO v_directus_user_id, v_person_id, v_display_name
    FROM ref.setup_management_actor(p_email, false) AS a;

    IF p_setup_task_id IS NULL
       OR NOT EXISTS (SELECT 1 FROM ref.setup_task t WHERE t.setup_task_id = p_setup_task_id) THEN
        RAISE EXCEPTION USING ERRCODE = 'P0002', MESSAGE = 'Setup task was not found';
    END IF;

    IF p_setup_resource_id IS NULL
       OR NOT EXISTS (
            SELECT 1
            FROM ref.setup_resource r
            WHERE r.setup_resource_id = p_setup_resource_id
              AND r.active_flag
       ) THEN
        RAISE EXCEPTION USING ERRCODE = 'P0002', MESSAGE = 'Active Setup resource was not found';
    END IF;

    IF p_quantity_required IS NULL OR p_quantity_required <= 0 THEN
        RAISE EXCEPTION USING ERRCODE = '22023', MESSAGE = 'Setup resource quantity must be greater than zero';
    END IF;

    IF v_requirement NOT IN ('REQUIRED', 'PREFERRED') THEN
        RAISE EXCEPTION USING ERRCODE = '22023', MESSAGE = 'Setup resource requirement must be REQUIRED or PREFERRED';
    END IF;

    PERFORM pg_catalog.set_config('app.directus_user_uuid', v_directus_user_id::text, true);

    INSERT INTO ref.setup_task_resource(
        setup_task_id,
        setup_resource_id,
        quantity_required,
        requirement_type,
        notes,
        active_flag
    ) VALUES (
        p_setup_task_id,
        p_setup_resource_id,
        p_quantity_required,
        v_requirement,
        nullif(btrim(p_notes), ''),
        v_active
    )
    ON CONFLICT ON CONSTRAINT pk_setup_task_resource
    DO UPDATE SET
        quantity_required = EXCLUDED.quantity_required,
        requirement_type = EXCLUDED.requirement_type,
        notes = EXCLUDED.notes,
        active_flag = EXCLUDED.active_flag;

    RETURN QUERY
    SELECT p_setup_task_id, p_setup_resource_id, v_active, v_display_name;
END;
$function$;

REVOKE ALL ON FUNCTION ref.set_setup_task_resource(
    text,bigint,integer,integer,text,text,boolean
) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION ref.set_setup_task_resource(
    text,bigint,integer,integer,text,text,boolean
) TO fieldwiring_app;

CREATE OR REPLACE FUNCTION ref.set_setup_task_dependency(
    p_email text,
    p_setup_task_id bigint,
    p_prerequisite_setup_task_id bigint,
    p_dependency_note text,
    p_active boolean DEFAULT true
)
RETURNS TABLE (
    setup_task_id bigint,
    prerequisite_setup_task_id bigint,
    active boolean,
    operator_display_name text
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, ref
AS $function$
DECLARE
    v_directus_user_id uuid;
    v_person_id integer;
    v_display_name text;
BEGIN
    SELECT a.directus_user_id, a.person_id, a.display_name
      INTO v_directus_user_id, v_person_id, v_display_name
    FROM ref.setup_management_actor(p_email, false) AS a;

    IF p_setup_task_id = p_prerequisite_setup_task_id THEN
        RAISE EXCEPTION USING ERRCODE = '22023',
            MESSAGE = 'A Setup task cannot depend on itself';
    END IF;

    IF NOT EXISTS (SELECT 1 FROM ref.setup_task t WHERE t.setup_task_id = p_setup_task_id)
       OR NOT EXISTS (SELECT 1 FROM ref.setup_task t WHERE t.setup_task_id = p_prerequisite_setup_task_id) THEN
        RAISE EXCEPTION USING ERRCODE = 'P0002', MESSAGE = 'Setup task or prerequisite was not found';
    END IF;

    IF coalesce(p_active, true) THEN
        IF EXISTS (
            WITH RECURSIVE prerequisite_chain(setup_task_id) AS (
                SELECT d.prerequisite_setup_task_id
                FROM ref.setup_task_dependency d
                WHERE d.setup_task_id = p_prerequisite_setup_task_id
                UNION
                SELECT d.prerequisite_setup_task_id
                FROM ref.setup_task_dependency d
                JOIN prerequisite_chain c
                  ON d.setup_task_id = c.setup_task_id
            )
            SELECT 1 FROM prerequisite_chain WHERE setup_task_id = p_setup_task_id
        ) THEN
            RAISE EXCEPTION USING ERRCODE = '23514',
                MESSAGE = 'Prerequisite would create a circular Setup dependency';
        END IF;
    END IF;

    PERFORM pg_catalog.set_config('app.directus_user_uuid', v_directus_user_id::text, true);

    IF coalesce(p_active, true) THEN
        INSERT INTO ref.setup_task_dependency(
            setup_task_id,
            prerequisite_setup_task_id,
            dependency_note
        ) VALUES (
            p_setup_task_id,
            p_prerequisite_setup_task_id,
            nullif(btrim(p_dependency_note), '')
        )
        ON CONFLICT ON CONSTRAINT pk_setup_task_dependency
        DO UPDATE SET dependency_note = EXCLUDED.dependency_note;
    ELSE
        DELETE FROM ref.setup_task_dependency d
        WHERE d.setup_task_id = p_setup_task_id
          AND d.prerequisite_setup_task_id = p_prerequisite_setup_task_id;
    END IF;

    RETURN QUERY
    SELECT p_setup_task_id, p_prerequisite_setup_task_id,
           coalesce(p_active, true), v_display_name;
END;
$function$;

REVOKE ALL ON FUNCTION ref.set_setup_task_dependency(
    text,bigint,bigint,text,boolean
) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION ref.set_setup_task_dependency(
    text,bigint,bigint,text,boolean
) TO fieldwiring_app;

CREATE OR REPLACE FUNCTION ops.set_setup_work_day_task(
    p_email text,
    p_setup_work_day_id bigint,
    p_setup_session_task_id bigint,
    p_shift_code text,
    p_crew_lane text,
    p_sort_order integer,
    p_planned_crew_count integer,
    p_active boolean DEFAULT true
)
RETURNS TABLE (
    setup_work_day_id bigint,
    setup_session_task_id bigint,
    active boolean,
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
    v_shift text := upper(btrim(coalesce(p_shift_code, 'ALL_DAY')));
    v_lane text := upper(btrim(coalesce(nullif(p_crew_lane, ''), 'A')));
BEGIN
    SELECT a.directus_user_id, a.person_id, a.display_name
      INTO v_directus_user_id, v_person_id, v_display_name
    FROM ref.setup_management_actor(p_email, false) AS a;

    IF v_shift NOT IN ('MORNING','AFTERNOON','ALL_DAY') THEN
        RAISE EXCEPTION USING ERRCODE = '22023',
            MESSAGE = 'Shift must be MORNING, AFTERNOON, or ALL_DAY';
    END IF;
    IF length(v_lane) > 24 THEN
        RAISE EXCEPTION USING ERRCODE = '22023', MESSAGE = 'Crew lane is too long';
    END IF;
    IF p_planned_crew_count IS NOT NULL AND p_planned_crew_count < 0 THEN
        RAISE EXCEPTION USING ERRCODE = '22023', MESSAGE = 'Planned crew count cannot be negative';
    END IF;
    IF NOT EXISTS (
        SELECT 1
        FROM ops.setup_work_day wd
        JOIN ops.setup_session_task st ON st.setup_session_id = wd.setup_session_id
        WHERE wd.setup_work_day_id = p_setup_work_day_id
          AND st.setup_session_task_id = p_setup_session_task_id
    ) THEN
        RAISE EXCEPTION USING ERRCODE = '22023',
            MESSAGE = 'Scheduled task must belong to the same Setup Session as the work day';
    END IF;

    PERFORM pg_catalog.set_config('app.directus_user_uuid', v_directus_user_id::text, true);

    IF coalesce(p_active, true) THEN
        INSERT INTO ops.setup_work_day_task(
            setup_work_day_id,
            setup_session_task_id,
            shift_code,
            crew_lane,
            sort_order,
            planned_crew_count
        ) VALUES (
            p_setup_work_day_id,
            p_setup_session_task_id,
            v_shift,
            v_lane,
            coalesce(p_sort_order, 100),
            p_planned_crew_count
        )
        ON CONFLICT ON CONSTRAINT pk_setup_work_day_task
        DO UPDATE SET shift_code = EXCLUDED.shift_code,
                      crew_lane = EXCLUDED.crew_lane,
                      sort_order = EXCLUDED.sort_order,
                      planned_crew_count = EXCLUDED.planned_crew_count;

        UPDATE ops.setup_session_task st
           SET execution_status = CASE
               WHEN st.execution_status IN ('NOT_READY','READY') THEN 'PLANNED'
               ELSE st.execution_status
           END,
               planned_date = (
                   SELECT wd.work_date
                   FROM ops.setup_work_day wd
                   WHERE wd.setup_work_day_id = p_setup_work_day_id
               )
         WHERE st.setup_session_task_id = p_setup_session_task_id;
    ELSE
        DELETE FROM ops.setup_work_day_task wdt
        WHERE wdt.setup_work_day_id = p_setup_work_day_id
          AND wdt.setup_session_task_id = p_setup_session_task_id;

        IF NOT EXISTS (
            SELECT 1
            FROM ops.setup_work_day_task wdt
            WHERE wdt.setup_session_task_id = p_setup_session_task_id
        ) THEN
            UPDATE ops.setup_session_task st
               SET execution_status = CASE
                       WHEN st.execution_status = 'PLANNED' THEN 'READY'
                       ELSE st.execution_status
                   END,
                   planned_date = NULL
             WHERE st.setup_session_task_id = p_setup_session_task_id;
        END IF;
    END IF;

    RETURN QUERY
    SELECT p_setup_work_day_id, p_setup_session_task_id,
           coalesce(p_active, true), v_display_name;
END;
$function$;

REVOKE ALL ON FUNCTION ops.set_setup_work_day_task(
    text,bigint,bigint,text,text,integer,integer,boolean
) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION ops.set_setup_work_day_task(
    text,bigint,bigint,text,text,integer,integer,boolean
) TO fieldwiring_app;

COMMIT;

SELECT
    pg_get_functiondef('ref.set_setup_task_resource(text,bigint,integer,integer,text,text,boolean)'::regprocedure)
        LIKE '%ON CONFLICT ON CONSTRAINT pk_setup_task_resource%' AS resource_conflict_hardened,
    pg_get_functiondef('ref.set_setup_task_dependency(text,bigint,bigint,text,boolean)'::regprocedure)
        LIKE '%ON CONFLICT ON CONSTRAINT pk_setup_task_dependency%' AS dependency_conflict_hardened,
    pg_get_functiondef('ops.set_setup_work_day_task(text,bigint,bigint,text,text,integer,integer,boolean)'::regprocedure)
        LIKE '%ON CONFLICT ON CONSTRAINT pk_setup_work_day_task%' AS scheduling_conflict_hardened;
