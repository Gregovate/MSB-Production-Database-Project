/* ============================================================================
MSB Setup Session — scope, dependency, lightweight scheduling, and field execution
Issue: #122
Status: IMPLEMENTATION CANDIDATE — DO NOT APPLY TO PRODUCTION WITHOUT REVIEW
Revision: 2026-09-07 V0.2.0

Purpose:
  Add the next browser-review layer proven necessary during Manager testing:
  - explicit Stage-level vs current LOR Scene task scope;
  - governed prerequisite maintenance with cycle prevention;
  - lightweight work-day scheduling by Morning/Afternoon/All Day;
  - Captain/Manager progress and completion recording;
  - durable completion actor/note and multi-period progress evidence.

Guardrails:
  - Scene scope is explicit Manager-maintained reusable organization. It is not
    inferred from task names.
  - The annual 2025 review uses the same reusable scope; no separate historical
    Scene snapshot is introduced merely to preserve the prior lack of grouping.
  - Completion commands are available only to Managers or a person explicitly
    assigned as CAPTAIN/ALTERNATE for the reusable task.
  - Browser/app writes remain SECURITY DEFINER commands; fieldwiring_app receives
    no broad table INSERT/UPDATE/DELETE.
  - This migration does not install Container/Display movement write commands.
============================================================================ */

BEGIN;

DO $preflight$
BEGIN
    IF to_regclass('ref.setup_task') IS NULL
       OR to_regclass('ref.setup_task_dependency') IS NULL
       OR to_regclass('ref.setup_task_captain') IS NULL
       OR to_regclass('ref.lor_scene') IS NULL
       OR to_regclass('ops.setup_session') IS NULL
       OR to_regclass('ops.setup_session_task') IS NULL
       OR to_regclass('ops.setup_work_day') IS NULL
       OR to_regclass('ops.setup_work_day_task') IS NULL
       OR to_regclass('ref.person') IS NULL THEN
        RAISE EXCEPTION 'Setup core, current LOR Scene projection, and person authority are required';
    END IF;

    IF to_regprocedure('ref.setup_management_actor(text,boolean)') IS NULL
       OR to_regprocedure('ref.setup_browser_capabilities(text)') IS NULL THEN
        RAISE EXCEPTION 'Setup authorization/management functions are required first';
    END IF;

    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'fieldwiring_app') THEN
        RAISE EXCEPTION 'Required application role fieldwiring_app does not exist';
    END IF;
END
$preflight$;

/* --------------------------------------------------------------------------
   REUSABLE TASK SCOPE: STAGE-LEVEL OR CURRENT LOR SCENE
   -------------------------------------------------------------------------- */

CREATE UNIQUE INDEX IF NOT EXISTS uq_lor_scene_id_stage
    ON ref.lor_scene(lor_scene_id, stage_id);

ALTER TABLE ref.setup_task
    ADD COLUMN IF NOT EXISTS lor_scene_id bigint;

ALTER TABLE ref.setup_task
    DROP CONSTRAINT IF EXISTS ck_setup_task_scene_requires_stage;
ALTER TABLE ref.setup_task
    ADD CONSTRAINT ck_setup_task_scene_requires_stage CHECK (
        lor_scene_id IS NULL OR stage_id IS NOT NULL
    );

ALTER TABLE ref.setup_task
    DROP CONSTRAINT IF EXISTS fk_setup_task_scene_stage;
ALTER TABLE ref.setup_task
    ADD CONSTRAINT fk_setup_task_scene_stage
    FOREIGN KEY (lor_scene_id, stage_id)
    REFERENCES ref.lor_scene(lor_scene_id, stage_id);

CREATE INDEX IF NOT EXISTS ix_setup_task_scene_order
    ON ref.setup_task(stage_id, lor_scene_id, display_order, setup_task_id);

CREATE OR REPLACE FUNCTION ref.set_setup_task_scope(
    p_email text,
    p_setup_task_id bigint,
    p_stage_id integer,
    p_lor_scene_id bigint
)
RETURNS TABLE (
    setup_task_id bigint,
    stage_id integer,
    lor_scene_id bigint,
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

    IF NOT EXISTS (
        SELECT 1 FROM ref.setup_task t WHERE t.setup_task_id = p_setup_task_id
    ) THEN
        RAISE EXCEPTION USING ERRCODE = 'P0002', MESSAGE = 'Setup task was not found';
    END IF;

    IF p_lor_scene_id IS NOT NULL THEN
        IF p_stage_id IS NULL THEN
            RAISE EXCEPTION USING ERRCODE = '22023',
                MESSAGE = 'Scene-scoped Setup task requires a Stage';
        END IF;
        IF NOT EXISTS (
            SELECT 1
            FROM ref.lor_scene s
            WHERE s.lor_scene_id = p_lor_scene_id
              AND s.stage_id = p_stage_id
        ) THEN
            RAISE EXCEPTION USING ERRCODE = '22023',
                MESSAGE = 'Selected Scene does not belong to the selected Stage';
        END IF;
    END IF;

    PERFORM pg_catalog.set_config('app.directus_user_uuid', v_directus_user_id::text, true);

    UPDATE ref.setup_task t
       SET stage_id = p_stage_id,
           lor_scene_id = p_lor_scene_id
     WHERE t.setup_task_id = p_setup_task_id;

    RETURN QUERY
    SELECT p_setup_task_id, p_stage_id, p_lor_scene_id, v_display_name;
END;
$function$;

REVOKE ALL ON FUNCTION ref.set_setup_task_scope(text,bigint,integer,bigint) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION ref.set_setup_task_scope(text,bigint,integer,bigint) TO fieldwiring_app;

/* Preserve the installed create/update signatures. If the Stage changes through
   the existing reusable-task editor, clear stale Scene scope rather than permit
   a cross-Stage Scene mismatch. */
CREATE OR REPLACE FUNCTION ref.update_setup_task(
    p_email text,
    p_setup_task_id bigint,
    p_task_name text,
    p_stage_id integer,
    p_task_action_type text,
    p_display_order integer,
    p_active_flag boolean,
    p_normal_crew_min integer,
    p_normal_crew_max integer,
    p_expected_duration_minutes integer,
    p_completion_point text,
    p_readiness_note text,
    p_weather_note text,
    p_reusable_notes text
)
RETURNS TABLE (
    setup_task_id bigint,
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
    v_name text := nullif(btrim(p_task_name), '');
    v_action text := upper(btrim(coalesce(p_task_action_type, 'WORK')));
BEGIN
    SELECT a.directus_user_id, a.person_id, a.display_name
      INTO v_directus_user_id, v_person_id, v_display_name
    FROM ref.setup_management_actor(p_email, false) AS a;

    IF v_name IS NULL THEN
        RAISE EXCEPTION USING ERRCODE = '22023', MESSAGE = 'Setup task name is required';
    END IF;

    PERFORM pg_catalog.set_config('app.directus_user_uuid', v_directus_user_id::text, true);

    UPDATE ref.setup_task t
       SET task_name = v_name,
           lor_scene_id = CASE
               WHEN t.stage_id IS DISTINCT FROM p_stage_id THEN NULL
               ELSE t.lor_scene_id
           END,
           stage_id = p_stage_id,
           task_action_type = v_action,
           display_order = coalesce(p_display_order, t.display_order),
           active_flag = coalesce(p_active_flag, t.active_flag),
           normal_crew_min = p_normal_crew_min,
           normal_crew_max = p_normal_crew_max,
           expected_duration_minutes = p_expected_duration_minutes,
           completion_point = nullif(btrim(p_completion_point), ''),
           readiness_note = nullif(btrim(p_readiness_note), ''),
           weather_note = nullif(btrim(p_weather_note), ''),
           reusable_notes = nullif(btrim(p_reusable_notes), '')
     WHERE t.setup_task_id = p_setup_task_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION USING ERRCODE = 'P0002', MESSAGE = 'Setup task was not found';
    END IF;

    RETURN QUERY SELECT p_setup_task_id, v_display_name;
END;
$function$;

REVOKE ALL ON FUNCTION ref.update_setup_task(
    text, bigint, text, integer, text, integer, boolean, integer, integer,
    integer, text, text, text, text
) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION ref.update_setup_task(
    text, bigint, text, integer, text, integer, boolean, integer, integer,
    integer, text, text, text, text
) TO fieldwiring_app;

/* --------------------------------------------------------------------------
   MANAGER PREREQUISITE MAINTENANCE
   -------------------------------------------------------------------------- */

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

    IF NOT EXISTS (SELECT 1 FROM ref.setup_task WHERE setup_task_id = p_setup_task_id)
       OR NOT EXISTS (SELECT 1 FROM ref.setup_task WHERE setup_task_id = p_prerequisite_setup_task_id) THEN
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
        ON CONFLICT (setup_task_id, prerequisite_setup_task_id)
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

REVOKE ALL ON FUNCTION ref.set_setup_task_dependency(text,bigint,bigint,text,boolean) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION ref.set_setup_task_dependency(text,bigint,bigint,text,boolean) TO fieldwiring_app;

/* --------------------------------------------------------------------------
   LIGHTWEIGHT WORK-DAY / SHIFT SCHEDULING
   -------------------------------------------------------------------------- */

ALTER TABLE ops.setup_work_day_task
    ADD COLUMN IF NOT EXISTS shift_code text NOT NULL DEFAULT 'ALL_DAY';

ALTER TABLE ops.setup_work_day_task
    DROP CONSTRAINT IF EXISTS ck_setup_work_day_task_shift;
ALTER TABLE ops.setup_work_day_task
    ADD CONSTRAINT ck_setup_work_day_task_shift CHECK (
        shift_code IN ('MORNING','AFTERNOON','ALL_DAY')
    );

CREATE INDEX IF NOT EXISTS ix_setup_work_day_task_shift_order
    ON ops.setup_work_day_task(setup_work_day_id, shift_code, sort_order, setup_session_task_id);

CREATE OR REPLACE FUNCTION ops.upsert_setup_work_day(
    p_email text,
    p_season_year integer,
    p_work_date date,
    p_day_status text DEFAULT 'PLANNED',
    p_notes text DEFAULT NULL
)
RETURNS TABLE (
    setup_work_day_id bigint,
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
    v_day_id bigint;
    v_status text := upper(btrim(coalesce(p_day_status, 'PLANNED')));
BEGIN
    SELECT a.directus_user_id, a.person_id, a.display_name
      INTO v_directus_user_id, v_person_id, v_display_name
    FROM ref.setup_management_actor(p_email, false) AS a;

    IF p_work_date IS NULL THEN
        RAISE EXCEPTION USING ERRCODE = '22023', MESSAGE = 'Work date is required';
    END IF;
    IF v_status NOT IN ('PLANNED','ACTIVE','COMPLETE','CANCELLED') THEN
        RAISE EXCEPTION USING ERRCODE = '22023', MESSAGE = 'Invalid Setup work-day status';
    END IF;

    SELECT s.setup_session_id INTO v_session_id
    FROM ops.setup_session s
    WHERE s.season_year = p_season_year;
    IF v_session_id IS NULL THEN
        RAISE EXCEPTION USING ERRCODE = 'P0002', MESSAGE = 'Setup Session was not found for this season';
    END IF;

    PERFORM pg_catalog.set_config('app.directus_user_uuid', v_directus_user_id::text, true);

    INSERT INTO ops.setup_work_day(setup_session_id, work_date, day_status, notes)
    VALUES (v_session_id, p_work_date, v_status, nullif(btrim(p_notes), ''))
    ON CONFLICT (setup_session_id, work_date)
    DO UPDATE SET day_status = EXCLUDED.day_status,
                  notes = EXCLUDED.notes
    RETURNING ops.setup_work_day.setup_work_day_id INTO v_day_id;

    RETURN QUERY SELECT v_day_id, v_display_name;
END;
$function$;

REVOKE ALL ON FUNCTION ops.upsert_setup_work_day(text,integer,date,text,text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION ops.upsert_setup_work_day(text,integer,date,text,text) TO fieldwiring_app;

CREATE OR REPLACE FUNCTION ops.set_setup_work_day_task(
    p_email text,
    p_setup_work_day_id bigint,
    p_setup_session_task_id bigint,
    p_shift_code text,
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
BEGIN
    SELECT a.directus_user_id, a.person_id, a.display_name
      INTO v_directus_user_id, v_person_id, v_display_name
    FROM ref.setup_management_actor(p_email, false) AS a;

    IF v_shift NOT IN ('MORNING','AFTERNOON','ALL_DAY') THEN
        RAISE EXCEPTION USING ERRCODE = '22023', MESSAGE = 'Shift must be MORNING, AFTERNOON, or ALL_DAY';
    END IF;
    IF p_planned_crew_count IS NOT NULL AND p_planned_crew_count < 0 THEN
        RAISE EXCEPTION USING ERRCODE = '22023', MESSAGE = 'Planned crew count cannot be negative';
    END IF;
    IF NOT EXISTS (
        SELECT 1
        FROM ops.setup_work_day wd
        JOIN ops.setup_session_task st
          ON st.setup_session_id = wd.setup_session_id
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
            sort_order,
            planned_crew_count
        ) VALUES (
            p_setup_work_day_id,
            p_setup_session_task_id,
            v_shift,
            coalesce(p_sort_order, 100),
            p_planned_crew_count
        )
        ON CONFLICT (setup_work_day_id, setup_session_task_id)
        DO UPDATE SET shift_code = EXCLUDED.shift_code,
                      sort_order = EXCLUDED.sort_order,
                      planned_crew_count = EXCLUDED.planned_crew_count;

        UPDATE ops.setup_session_task st
           SET execution_status = CASE
               WHEN st.execution_status IN ('NOT_READY','READY') THEN 'PLANNED'
               ELSE st.execution_status
           END,
               planned_date = (
                   SELECT wd.work_date FROM ops.setup_work_day wd
                   WHERE wd.setup_work_day_id = p_setup_work_day_id
               )
         WHERE st.setup_session_task_id = p_setup_session_task_id;
    ELSE
        DELETE FROM ops.setup_work_day_task wdt
        WHERE wdt.setup_work_day_id = p_setup_work_day_id
          AND wdt.setup_session_task_id = p_setup_session_task_id;
    END IF;

    RETURN QUERY
    SELECT p_setup_work_day_id, p_setup_session_task_id,
           coalesce(p_active, true), v_display_name;
END;
$function$;

REVOKE ALL ON FUNCTION ops.set_setup_work_day_task(text,bigint,bigint,text,integer,integer,boolean) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION ops.set_setup_work_day_task(text,bigint,bigint,text,integer,integer,boolean) TO fieldwiring_app;

/* --------------------------------------------------------------------------
   CAPTAIN / MANAGER EXECUTION AND MULTI-PERIOD PROGRESS
   -------------------------------------------------------------------------- */

ALTER TABLE ops.setup_session_task
    ADD COLUMN IF NOT EXISTS completion_note text;
ALTER TABLE ops.setup_session_task
    ADD COLUMN IF NOT EXISTS completed_by_person_id integer;

ALTER TABLE ops.setup_session_task
    DROP CONSTRAINT IF EXISTS fk_setup_session_task_completed_by_person;
ALTER TABLE ops.setup_session_task
    ADD CONSTRAINT fk_setup_session_task_completed_by_person
    FOREIGN KEY (completed_by_person_id) REFERENCES ref.person(person_id);

CREATE TABLE IF NOT EXISTS ops.setup_task_progress (
    setup_task_progress_id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    setup_session_task_id bigint NOT NULL,
    setup_work_day_id bigint,
    shift_code text NOT NULL DEFAULT 'ALL_DAY',
    crew_count integer NOT NULL,
    completed_quantity integer,
    completed_units text,
    progress_note text,
    marks_task_complete boolean NOT NULL DEFAULT false,
    recorded_at timestamptz NOT NULL DEFAULT now(),
    created_at timestamptz NOT NULL DEFAULT now(),
    created_by text NOT NULL DEFAULT current_user,
    updated_at timestamptz NOT NULL DEFAULT now(),
    updated_by text NOT NULL DEFAULT current_user,
    created_by_person_id integer,
    updated_by_person_id integer,

    CONSTRAINT fk_setup_task_progress_session_task
        FOREIGN KEY (setup_session_task_id)
        REFERENCES ops.setup_session_task(setup_session_task_id),
    CONSTRAINT fk_setup_task_progress_work_day
        FOREIGN KEY (setup_work_day_id)
        REFERENCES ops.setup_work_day(setup_work_day_id),
    CONSTRAINT fk_setup_task_progress_created_by_person
        FOREIGN KEY (created_by_person_id) REFERENCES ref.person(person_id),
    CONSTRAINT fk_setup_task_progress_updated_by_person
        FOREIGN KEY (updated_by_person_id) REFERENCES ref.person(person_id),
    CONSTRAINT ck_setup_task_progress_shift CHECK (
        shift_code IN ('MORNING','AFTERNOON','ALL_DAY')
    ),
    CONSTRAINT ck_setup_task_progress_crew CHECK (crew_count > 0),
    CONSTRAINT ck_setup_task_progress_quantity CHECK (
        completed_quantity IS NULL OR completed_quantity > 0
    )
);

CREATE INDEX IF NOT EXISTS ix_setup_task_progress_task_time
    ON ops.setup_task_progress(setup_session_task_id, recorded_at, setup_task_progress_id);

DROP TRIGGER IF EXISTS trg_setup_task_progress_actor_insert ON ops.setup_task_progress;
CREATE TRIGGER trg_setup_task_progress_actor_insert
BEFORE INSERT ON ops.setup_task_progress
FOR EACH ROW EXECUTE FUNCTION ref.set_actor_on_insert();

DROP TRIGGER IF EXISTS trg_setup_task_progress_actor_update ON ops.setup_task_progress;
CREATE TRIGGER trg_setup_task_progress_actor_update
BEFORE UPDATE ON ops.setup_task_progress
FOR EACH ROW EXECUTE FUNCTION ref.set_actor_on_update();

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
    v_can_read boolean := false;
    v_can_manage boolean := false;
BEGIN
    IF v_email IS NULL OR v_email = '' THEN
        RAISE EXCEPTION USING ERRCODE = '42501', MESSAGE = 'Authenticated Setup operator email is required';
    END IF;

    SELECT u.id, c.display_name, c.can_read_setup, c.can_manage_setup
      INTO v_directus_user_id, v_display_name, v_can_read, v_can_manage
    FROM public.directus_users u
    JOIN LATERAL ref.setup_browser_capabilities(v_email) c ON true
    WHERE u.status = 'active'
      AND lower(u.email) = v_email
    LIMIT 1;

    IF v_directus_user_id IS NULL OR coalesce(v_can_read, false) IS NOT TRUE THEN
        RAISE EXCEPTION USING ERRCODE = '42501', MESSAGE = 'Setup execution access is not authorized for this account';
    END IF;

    SELECT p.person_id INTO v_person_id
    FROM ref.person p
    WHERE p.directus_user_id = v_directus_user_id
    LIMIT 1;

    IF v_person_id IS NULL THEN
        RAISE EXCEPTION USING ERRCODE = '42501', MESSAGE = 'Authenticated Setup operator is not mapped to an MSB person';
    END IF;

    IF coalesce(v_can_manage, false) IS NOT TRUE
       AND NOT EXISTS (
           SELECT 1
           FROM ref.setup_task_captain c
           WHERE c.setup_task_id = p_setup_task_id
             AND c.person_id = v_person_id
             AND c.captain_role IN ('CAPTAIN','ALTERNATE')
       ) THEN
        RAISE EXCEPTION USING ERRCODE = '42501',
            MESSAGE = 'Only an assigned Captain/Alternate or Setup Manager can record task progress';
    END IF;

    RETURN QUERY
    SELECT v_directus_user_id, v_person_id,
           coalesce(nullif(btrim(v_display_name), ''), v_email),
           coalesce(v_can_manage, false);
END;
$function$;

REVOKE ALL ON FUNCTION ref.setup_execution_actor(text,bigint) FROM PUBLIC;
REVOKE ALL ON FUNCTION ref.setup_execution_actor(text,bigint) FROM fieldwiring_app;

CREATE OR REPLACE FUNCTION ops.record_setup_task_progress(
    p_email text,
    p_setup_session_task_id bigint,
    p_setup_work_day_id bigint,
    p_shift_code text,
    p_crew_count integer,
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
BEGIN
    SELECT st.setup_task_id, st.setup_session_id
      INTO v_setup_task_id, v_setup_session_id
    FROM ops.setup_session_task st
    WHERE st.setup_session_task_id = p_setup_session_task_id;

    IF v_setup_task_id IS NULL THEN
        RAISE EXCEPTION USING ERRCODE = 'P0002', MESSAGE = 'Annual Setup task was not found';
    END IF;

    SELECT a.directus_user_id, a.person_id, a.display_name
      INTO v_directus_user_id, v_person_id, v_display_name
    FROM ref.setup_execution_actor(p_email, v_setup_task_id) a;

    IF p_crew_count IS NULL OR p_crew_count <= 0 THEN
        RAISE EXCEPTION USING ERRCODE = '22023', MESSAGE = 'Crew size must be at least 1';
    END IF;
    IF v_shift NOT IN ('MORNING','AFTERNOON','ALL_DAY') THEN
        RAISE EXCEPTION USING ERRCODE = '22023', MESSAGE = 'Shift must be MORNING, AFTERNOON, or ALL_DAY';
    END IF;
    IF p_completed_quantity IS NOT NULL AND p_completed_quantity <= 0 THEN
        RAISE EXCEPTION USING ERRCODE = '22023', MESSAGE = 'Completed quantity must be greater than zero';
    END IF;

    IF p_setup_work_day_id IS NOT NULL AND NOT EXISTS (
        SELECT 1
        FROM ops.setup_work_day wd
        WHERE wd.setup_work_day_id = p_setup_work_day_id
          AND wd.setup_session_id = v_setup_session_id
    ) THEN
        RAISE EXCEPTION USING ERRCODE = '22023',
            MESSAGE = 'Progress work day must belong to the same Setup Session';
    END IF;

    PERFORM pg_catalog.set_config('app.directus_user_uuid', v_directus_user_id::text, true);

    INSERT INTO ops.setup_task_progress(
        setup_session_task_id,
        setup_work_day_id,
        shift_code,
        crew_count,
        completed_quantity,
        completed_units,
        progress_note,
        marks_task_complete,
        recorded_at
    ) VALUES (
        p_setup_session_task_id,
        p_setup_work_day_id,
        v_shift,
        p_crew_count,
        p_completed_quantity,
        nullif(btrim(p_completed_units), ''),
        nullif(btrim(p_progress_note), ''),
        coalesce(p_mark_complete, false),
        v_recorded_at
    )
    RETURNING ops.setup_task_progress.setup_task_progress_id INTO v_progress_id;

    UPDATE ops.setup_session_task st
       SET actual_started_at = coalesce(st.actual_started_at, v_recorded_at),
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

    IF p_setup_work_day_id IS NOT NULL THEN
        UPDATE ops.setup_work_day_task wdt
           SET actual_crew_count = p_crew_count,
               started_at = coalesce(wdt.started_at, v_recorded_at),
               completed_at = CASE
                   WHEN coalesce(p_mark_complete, false) THEN v_recorded_at
                   ELSE wdt.completed_at
               END,
               notes = CASE
                   WHEN nullif(btrim(p_progress_note), '') IS NOT NULL THEN p_progress_note
                   ELSE wdt.notes
               END
         WHERE wdt.setup_work_day_id = p_setup_work_day_id
           AND wdt.setup_session_task_id = p_setup_session_task_id;
    END IF;

    RETURN QUERY
    SELECT v_progress_id, p_setup_session_task_id, v_status, v_recorded_at, v_display_name;
END;
$function$;

REVOKE ALL ON FUNCTION ops.record_setup_task_progress(
    text,bigint,bigint,text,integer,integer,text,text,boolean
) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION ops.record_setup_task_progress(
    text,bigint,bigint,text,integer,integer,text,text,boolean
) TO fieldwiring_app;

/* Read surfaces required by the protected Setup application. */
GRANT SELECT ON ref.lor_scene TO fieldwiring_app;
GRANT SELECT ON ops.setup_task_progress TO fieldwiring_app;

/* Known reusable resource inventory from browser review. These are two distinct
   planning resources; individual tasks may require one of them rather than both. */
INSERT INTO ref.setup_resource(resource_name, resource_type, notes)
VALUES
    ('Short Stake Pounder','EQUIPMENT','Powered stake pounder; short configuration.'),
    ('Tall Stake Pounder','EQUIPMENT','Powered stake pounder; tall configuration.')
ON CONFLICT (resource_name) DO NOTHING;

COMMIT;
