/* ============================================================================
MSB Setup Session — #205 Scheduling Board annual/schedule foundation
Issue: #205
Status: IMPLEMENTATION CANDIDATE — DISPOSABLE ACCEPTANCE REQUIRED
Revision: 2026-09-17 V0.1.0

Purpose:
  - preserve a stable Setup Day Number independent of weekday/date drift;
  - make annual Setup task occurrences self-contained snapshots of the season plan;
  - support season-only annual tasks without polluting the reusable Catalog;
  - give annual dependencies their own season-scoped identity;
  - link annual exception/gate tasks to existing Work Orders;
  - give scheduled assignments stable identities so actual history can become sticky;
  - constrain the Scheduling Board to Crew A/B/C/D while retaining
    MORNING/AFTERNOON/ALL_DAY;
  - preserve compatibility with the existing V0.3 scheduling/progress surface.

This migration does not create the real 2026 Setup Session.
============================================================================ */

BEGIN;

DO $preflight$
BEGIN
    IF to_regclass('ref.setup_task') IS NULL
       OR to_regclass('ref.setup_task_dependency') IS NULL
       OR to_regclass('ref.lor_scene') IS NULL
       OR to_regclass('ops.setup_session') IS NULL
       OR to_regclass('ops.setup_session_task') IS NULL
       OR to_regclass('ops.setup_work_day') IS NULL
       OR to_regclass('ops.setup_work_day_task') IS NULL
       OR to_regclass('ops.setup_task_progress') IS NULL
       OR to_regclass('ops.work_order') IS NULL
       OR to_regprocedure('ref.setup_management_actor(text,boolean)') IS NULL
       OR to_regprocedure('ops.upsert_setup_work_day(text,integer,date,text,text)') IS NULL
       OR to_regprocedure('ops.set_setup_work_day_task(text,bigint,bigint,text,text,integer,integer,boolean)') IS NULL THEN
        RAISE EXCEPTION 'Accepted Setup scheduling/management foundation is required before migration 050';
    END IF;

    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'fieldwiring_app') THEN
        RAISE EXCEPTION 'Required application role fieldwiring_app does not exist';
    END IF;
END
$preflight$;

/* --------------------------------------------------------------------------
   SETUP DAY NUMBER
   -------------------------------------------------------------------------- */

ALTER TABLE ops.setup_work_day
    ADD COLUMN IF NOT EXISTS setup_day_number integer;

WITH numbered AS (
    SELECT wd.setup_work_day_id,
           row_number() OVER (
               PARTITION BY wd.setup_session_id
               ORDER BY wd.work_date, wd.setup_work_day_id
           )::integer AS setup_day_number
    FROM ops.setup_work_day wd
)
UPDATE ops.setup_work_day wd
   SET setup_day_number = n.setup_day_number
FROM numbered n
WHERE n.setup_work_day_id = wd.setup_work_day_id
  AND wd.setup_day_number IS NULL;

ALTER TABLE ops.setup_work_day
    ALTER COLUMN setup_day_number SET NOT NULL;

ALTER TABLE ops.setup_work_day
    DROP CONSTRAINT IF EXISTS ck_setup_work_day_day_number;
ALTER TABLE ops.setup_work_day
    ADD CONSTRAINT ck_setup_work_day_day_number CHECK (setup_day_number > 0);

ALTER TABLE ops.setup_work_day
    DROP CONSTRAINT IF EXISTS uq_setup_work_day_day_number;
ALTER TABLE ops.setup_work_day
    ADD CONSTRAINT uq_setup_work_day_day_number
    UNIQUE (setup_session_id, setup_day_number);

/* --------------------------------------------------------------------------
   ANNUAL TASK SNAPSHOT + SEASON-ONLY TASKS
   -------------------------------------------------------------------------- */

ALTER TABLE ops.setup_session_task
    ALTER COLUMN setup_task_id DROP NOT NULL;

ALTER TABLE ops.setup_session_task
    ADD COLUMN IF NOT EXISTS task_origin text NOT NULL DEFAULT 'REUSABLE',
    ADD COLUMN IF NOT EXISTS annual_task_name text,
    ADD COLUMN IF NOT EXISTS annual_stage_id integer,
    ADD COLUMN IF NOT EXISTS annual_lor_scene_id bigint,
    ADD COLUMN IF NOT EXISTS annual_task_action_type text,
    ADD COLUMN IF NOT EXISTS annual_normal_crew_min integer,
    ADD COLUMN IF NOT EXISTS annual_normal_crew_max integer,
    ADD COLUMN IF NOT EXISTS annual_expected_duration_minutes integer,
    ADD COLUMN IF NOT EXISTS annual_effort_level text,
    ADD COLUMN IF NOT EXISTS annual_completion_point text,
    ADD COLUMN IF NOT EXISTS annual_readiness_note text,
    ADD COLUMN IF NOT EXISTS annual_weather_note text,
    ADD COLUMN IF NOT EXISTS linked_work_order_id bigint,
    ADD COLUMN IF NOT EXISTS linked_work_order_gate boolean NOT NULL DEFAULT false;

UPDATE ops.setup_session_task st
   SET task_origin = 'REUSABLE',
       annual_task_name = coalesce(st.annual_task_name, t.task_name),
       annual_stage_id = coalesce(st.annual_stage_id, t.stage_id),
       annual_lor_scene_id = coalesce(st.annual_lor_scene_id, t.lor_scene_id),
       annual_task_action_type = coalesce(st.annual_task_action_type, t.task_action_type),
       annual_normal_crew_min = coalesce(st.annual_normal_crew_min, t.normal_crew_min),
       annual_normal_crew_max = coalesce(st.annual_normal_crew_max, t.normal_crew_max),
       annual_expected_duration_minutes = coalesce(st.annual_expected_duration_minutes, t.expected_duration_minutes),
       annual_effort_level = coalesce(st.annual_effort_level, t.effort_level),
       annual_completion_point = coalesce(st.annual_completion_point, t.completion_point),
       annual_readiness_note = coalesce(st.annual_readiness_note, t.readiness_note),
       annual_weather_note = coalesce(st.annual_weather_note, t.weather_note)
FROM ref.setup_task t
WHERE t.setup_task_id = st.setup_task_id;

ALTER TABLE ops.setup_session_task
    DROP CONSTRAINT IF EXISTS ck_setup_session_task_origin;
ALTER TABLE ops.setup_session_task
    ADD CONSTRAINT ck_setup_session_task_origin CHECK (
        task_origin IN ('REUSABLE','SEASON_ONLY')
        AND (
            (task_origin = 'REUSABLE' AND setup_task_id IS NOT NULL)
            OR
            (task_origin = 'SEASON_ONLY' AND setup_task_id IS NULL)
        )
    );

ALTER TABLE ops.setup_session_task
    DROP CONSTRAINT IF EXISTS ck_setup_session_task_annual_name;
ALTER TABLE ops.setup_session_task
    ADD CONSTRAINT ck_setup_session_task_annual_name CHECK (
        nullif(btrim(annual_task_name), '') IS NOT NULL
    );

ALTER TABLE ops.setup_session_task
    DROP CONSTRAINT IF EXISTS ck_setup_session_task_annual_action;
ALTER TABLE ops.setup_session_task
    ADD CONSTRAINT ck_setup_session_task_annual_action CHECK (
        annual_task_action_type IN ('WORK','UNLOAD_CONTAINER','SUPPORT','GATE')
    );

ALTER TABLE ops.setup_session_task
    DROP CONSTRAINT IF EXISTS ck_setup_session_task_annual_crew;
ALTER TABLE ops.setup_session_task
    ADD CONSTRAINT ck_setup_session_task_annual_crew CHECK (
        (annual_normal_crew_min IS NULL OR annual_normal_crew_min >= 0)
        AND (annual_normal_crew_max IS NULL OR annual_normal_crew_max >= 0)
        AND (
            annual_normal_crew_min IS NULL
            OR annual_normal_crew_max IS NULL
            OR annual_normal_crew_min <= annual_normal_crew_max
        )
    );

ALTER TABLE ops.setup_session_task
    DROP CONSTRAINT IF EXISTS ck_setup_session_task_annual_duration;
ALTER TABLE ops.setup_session_task
    ADD CONSTRAINT ck_setup_session_task_annual_duration CHECK (
        annual_expected_duration_minutes IS NULL OR annual_expected_duration_minutes > 0
    );

ALTER TABLE ops.setup_session_task
    DROP CONSTRAINT IF EXISTS ck_setup_session_task_annual_effort;
ALTER TABLE ops.setup_session_task
    ADD CONSTRAINT ck_setup_session_task_annual_effort CHECK (
        annual_effort_level IS NULL
        OR annual_effort_level IN ('LIGHT','MODERATE','HEAVY')
    );

ALTER TABLE ops.setup_session_task
    DROP CONSTRAINT IF EXISTS fk_setup_session_task_annual_stage;
ALTER TABLE ops.setup_session_task
    ADD CONSTRAINT fk_setup_session_task_annual_stage
    FOREIGN KEY (annual_stage_id) REFERENCES ref.stage(stage_id);

ALTER TABLE ops.setup_session_task
    DROP CONSTRAINT IF EXISTS fk_setup_session_task_annual_scene_stage;
ALTER TABLE ops.setup_session_task
    ADD CONSTRAINT fk_setup_session_task_annual_scene_stage
    FOREIGN KEY (annual_lor_scene_id, annual_stage_id)
    REFERENCES ref.lor_scene(lor_scene_id, stage_id);

ALTER TABLE ops.setup_session_task
    DROP CONSTRAINT IF EXISTS fk_setup_session_task_work_order;
ALTER TABLE ops.setup_session_task
    ADD CONSTRAINT fk_setup_session_task_work_order
    FOREIGN KEY (linked_work_order_id) REFERENCES ops.work_order(work_order_id);

ALTER TABLE ops.setup_session_task
    DROP CONSTRAINT IF EXISTS ck_setup_session_task_work_order_gate;
ALTER TABLE ops.setup_session_task
    ADD CONSTRAINT ck_setup_session_task_work_order_gate CHECK (
        linked_work_order_gate IS NOT TRUE OR linked_work_order_id IS NOT NULL
    );

/* Scheduling needs only Work Order identity/problem/completion state. Do not
   grant fieldwiring_app broad SELECT on the authoritative Work Order table. */
CREATE OR REPLACE VIEW ops.setup_scheduling_work_order_gate AS
SELECT wo.work_order_id,
       wo.problem,
       wo.date_completed
FROM ops.work_order wo;

REVOKE ALL ON ops.setup_scheduling_work_order_gate FROM PUBLIC;
GRANT SELECT ON ops.setup_scheduling_work_order_gate TO fieldwiring_app;

CREATE OR REPLACE FUNCTION ops.populate_setup_session_task_snapshot()
RETURNS trigger
LANGUAGE plpgsql
AS $function$
DECLARE
    v_task ref.setup_task%ROWTYPE;
BEGIN
    IF NEW.setup_task_id IS NOT NULL THEN
        NEW.task_origin := 'REUSABLE';
        SELECT * INTO v_task
        FROM ref.setup_task t
        WHERE t.setup_task_id = NEW.setup_task_id;

        IF NOT FOUND THEN
            RAISE EXCEPTION USING ERRCODE = '23503', MESSAGE = 'Reusable Setup task was not found';
        END IF;

        NEW.annual_task_name := coalesce(NEW.annual_task_name, v_task.task_name);
        NEW.annual_stage_id := coalesce(NEW.annual_stage_id, v_task.stage_id);
        NEW.annual_lor_scene_id := coalesce(NEW.annual_lor_scene_id, v_task.lor_scene_id);
        NEW.annual_task_action_type := coalesce(NEW.annual_task_action_type, v_task.task_action_type);
        NEW.annual_normal_crew_min := coalesce(NEW.annual_normal_crew_min, v_task.normal_crew_min);
        NEW.annual_normal_crew_max := coalesce(NEW.annual_normal_crew_max, v_task.normal_crew_max);
        NEW.annual_expected_duration_minutes := coalesce(
            NEW.annual_expected_duration_minutes,
            v_task.expected_duration_minutes
        );
        NEW.annual_effort_level := coalesce(NEW.annual_effort_level, v_task.effort_level);
        NEW.annual_completion_point := coalesce(NEW.annual_completion_point, v_task.completion_point);
        NEW.annual_readiness_note := coalesce(NEW.annual_readiness_note, v_task.readiness_note);
        NEW.annual_weather_note := coalesce(NEW.annual_weather_note, v_task.weather_note);
    ELSE
        NEW.task_origin := 'SEASON_ONLY';
        NEW.annual_task_action_type := coalesce(NEW.annual_task_action_type, 'WORK');
    END IF;

    RETURN NEW;
END;
$function$;

DROP TRIGGER IF EXISTS trg_setup_session_task_snapshot ON ops.setup_session_task;
CREATE TRIGGER trg_setup_session_task_snapshot
BEFORE INSERT ON ops.setup_session_task
FOR EACH ROW EXECUTE FUNCTION ops.populate_setup_session_task_snapshot();

/* Existing planned-order trigger must also support season-only annual tasks. */
CREATE OR REPLACE FUNCTION ops.default_setup_session_task_planned_order()
RETURNS trigger
LANGUAGE plpgsql
AS $function$
BEGIN
    IF NEW.planned_order IS NULL AND NEW.setup_task_id IS NOT NULL THEN
        SELECT t.baseline_plan_order
          INTO NEW.planned_order
        FROM ref.setup_task t
        WHERE t.setup_task_id = NEW.setup_task_id;
    END IF;

    IF NEW.planned_order IS NULL THEN
        SELECT coalesce(max(st.planned_order), 0) + 10
          INTO NEW.planned_order
        FROM ops.setup_session_task st
        WHERE st.setup_session_id = NEW.setup_session_id;
    END IF;
    RETURN NEW;
END;
$function$;

/* --------------------------------------------------------------------------
   ANNUAL DEPENDENCIES
   -------------------------------------------------------------------------- */

CREATE TABLE IF NOT EXISTS ops.setup_session_task_dependency (
    setup_session_task_id bigint NOT NULL,
    prerequisite_setup_session_task_id bigint NOT NULL,
    dependency_origin text NOT NULL DEFAULT 'ANNUAL',
    dependency_note text,
    sort_order integer NOT NULL DEFAULT 100,
    created_at timestamptz NOT NULL DEFAULT now(),
    created_by text NOT NULL DEFAULT current_user,
    updated_at timestamptz NOT NULL DEFAULT now(),
    updated_by text NOT NULL DEFAULT current_user,
    created_by_person_id integer,
    updated_by_person_id integer,

    CONSTRAINT pk_setup_session_task_dependency
        PRIMARY KEY (setup_session_task_id, prerequisite_setup_session_task_id),
    CONSTRAINT fk_setup_session_task_dependency_task
        FOREIGN KEY (setup_session_task_id)
        REFERENCES ops.setup_session_task(setup_session_task_id),
    CONSTRAINT fk_setup_session_task_dependency_prerequisite
        FOREIGN KEY (prerequisite_setup_session_task_id)
        REFERENCES ops.setup_session_task(setup_session_task_id),
    CONSTRAINT fk_setup_session_task_dependency_created_by_person
        FOREIGN KEY (created_by_person_id) REFERENCES ref.person(person_id),
    CONSTRAINT fk_setup_session_task_dependency_updated_by_person
        FOREIGN KEY (updated_by_person_id) REFERENCES ref.person(person_id),
    CONSTRAINT ck_setup_session_task_dependency_not_self
        CHECK (setup_session_task_id <> prerequisite_setup_session_task_id),
    CONSTRAINT ck_setup_session_task_dependency_origin
        CHECK (dependency_origin IN ('REUSABLE_BASELINE','ANNUAL'))
);

DROP TRIGGER IF EXISTS trg_setup_session_task_dependency_actor_insert
    ON ops.setup_session_task_dependency;
CREATE TRIGGER trg_setup_session_task_dependency_actor_insert
BEFORE INSERT ON ops.setup_session_task_dependency
FOR EACH ROW EXECUTE FUNCTION ref.set_actor_on_insert();

DROP TRIGGER IF EXISTS trg_setup_session_task_dependency_actor_update
    ON ops.setup_session_task_dependency;
CREATE TRIGGER trg_setup_session_task_dependency_actor_update
BEFORE UPDATE ON ops.setup_session_task_dependency
FOR EACH ROW EXECUTE FUNCTION ref.set_actor_on_update();

CREATE INDEX IF NOT EXISTS ix_setup_session_task_dependency_prerequisite
    ON ops.setup_session_task_dependency(prerequisite_setup_session_task_id, setup_session_task_id);

INSERT INTO ops.setup_session_task_dependency(
    setup_session_task_id,
    prerequisite_setup_session_task_id,
    dependency_origin,
    dependency_note
)
SELECT st.setup_session_task_id,
       pst.setup_session_task_id,
       'REUSABLE_BASELINE',
       d.dependency_note
FROM ref.setup_task_dependency d
JOIN ops.setup_session_task st
  ON st.setup_task_id = d.setup_task_id
JOIN ops.setup_session_task pst
  ON pst.setup_session_id = st.setup_session_id
 AND pst.setup_task_id = d.prerequisite_setup_task_id
ON CONFLICT ON CONSTRAINT pk_setup_session_task_dependency DO NOTHING;

CREATE OR REPLACE FUNCTION ops.seed_setup_session_task_dependencies_after_insert()
RETURNS trigger
LANGUAGE plpgsql
AS $function$
BEGIN
    IF NEW.setup_task_id IS NULL THEN
        RETURN NEW;
    END IF;

    INSERT INTO ops.setup_session_task_dependency(
        setup_session_task_id,
        prerequisite_setup_session_task_id,
        dependency_origin,
        dependency_note
    )
    SELECT NEW.setup_session_task_id,
           pst.setup_session_task_id,
           'REUSABLE_BASELINE',
           d.dependency_note
    FROM ref.setup_task_dependency d
    JOIN ops.setup_session_task pst
      ON pst.setup_session_id = NEW.setup_session_id
     AND pst.setup_task_id = d.prerequisite_setup_task_id
    WHERE d.setup_task_id = NEW.setup_task_id
    ON CONFLICT ON CONSTRAINT pk_setup_session_task_dependency DO NOTHING;

    INSERT INTO ops.setup_session_task_dependency(
        setup_session_task_id,
        prerequisite_setup_session_task_id,
        dependency_origin,
        dependency_note
    )
    SELECT dst.setup_session_task_id,
           NEW.setup_session_task_id,
           'REUSABLE_BASELINE',
           d.dependency_note
    FROM ref.setup_task_dependency d
    JOIN ops.setup_session_task dst
      ON dst.setup_session_id = NEW.setup_session_id
     AND dst.setup_task_id = d.setup_task_id
    WHERE d.prerequisite_setup_task_id = NEW.setup_task_id
    ON CONFLICT ON CONSTRAINT pk_setup_session_task_dependency DO NOTHING;

    RETURN NEW;
END;
$function$;

DROP TRIGGER IF EXISTS trg_setup_session_task_seed_dependencies
    ON ops.setup_session_task;
CREATE TRIGGER trg_setup_session_task_seed_dependencies
AFTER INSERT ON ops.setup_session_task
FOR EACH ROW EXECUTE FUNCTION ops.seed_setup_session_task_dependencies_after_insert();

/* --------------------------------------------------------------------------
   SEASON TASK + ANNUAL DEPENDENCY COMMANDS
   -------------------------------------------------------------------------- */

CREATE OR REPLACE FUNCTION ops.create_setup_season_task(
    p_email text,
    p_season_year integer,
    p_task_name text,
    p_stage_id integer,
    p_lor_scene_id bigint,
    p_task_action_type text,
    p_planned_order integer,
    p_normal_crew_min integer,
    p_normal_crew_max integer,
    p_expected_duration_minutes integer,
    p_effort_level text,
    p_completion_point text,
    p_readiness_note text,
    p_weather_note text,
    p_linked_work_order_id bigint,
    p_linked_work_order_gate boolean,
    p_annual_notes text
)
RETURNS TABLE (
    setup_session_task_id bigint,
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
    v_session_task_id bigint;
    v_name text := nullif(btrim(p_task_name), '');
    v_action text := upper(btrim(coalesce(p_task_action_type, 'WORK')));
    v_effort text := upper(nullif(btrim(p_effort_level), ''));
BEGIN
    SELECT a.directus_user_id, a.person_id, a.display_name
      INTO v_directus_user_id, v_person_id, v_display_name
    FROM ref.setup_management_actor(p_email, false) a;

    IF v_name IS NULL THEN
        RAISE EXCEPTION USING ERRCODE = '22023', MESSAGE = 'Season task name is required';
    END IF;
    IF v_action NOT IN ('WORK','UNLOAD_CONTAINER','SUPPORT','GATE') THEN
        RAISE EXCEPTION USING ERRCODE = '22023', MESSAGE = 'Invalid season task type';
    END IF;
    IF v_effort IS NOT NULL AND v_effort NOT IN ('LIGHT','MODERATE','HEAVY') THEN
        RAISE EXCEPTION USING ERRCODE = '22023',
            MESSAGE = 'Setup effort must be LIGHT, MODERATE, HEAVY, or blank';
    END IF;

    SELECT ss.setup_session_id INTO v_session_id
    FROM ops.setup_session ss
    WHERE ss.season_year = p_season_year
      AND ss.session_status <> 'COMPLETE';
    IF v_session_id IS NULL THEN
        RAISE EXCEPTION USING ERRCODE = 'P0002',
            MESSAGE = 'Open Setup Session was not found for this season';
    END IF;

    IF p_lor_scene_id IS NOT NULL AND NOT EXISTS (
        SELECT 1 FROM ref.lor_scene ls
        WHERE ls.lor_scene_id = p_lor_scene_id
          AND ls.stage_id = p_stage_id
    ) THEN
        RAISE EXCEPTION USING ERRCODE = '22023',
            MESSAGE = 'Selected Scene does not belong to the selected Stage';
    END IF;

    IF p_linked_work_order_id IS NOT NULL
       AND NOT EXISTS (
           SELECT 1 FROM ops.work_order wo
           WHERE wo.work_order_id = p_linked_work_order_id
       ) THEN
        RAISE EXCEPTION USING ERRCODE = '23503', MESSAGE = 'Linked Work Order was not found';
    END IF;

    PERFORM pg_catalog.set_config('app.directus_user_uuid', v_directus_user_id::text, true);

    INSERT INTO ops.setup_session_task(
        setup_session_id,
        setup_task_id,
        task_origin,
        annual_task_name,
        annual_stage_id,
        annual_lor_scene_id,
        annual_task_action_type,
        planned_order,
        annual_normal_crew_min,
        annual_normal_crew_max,
        annual_expected_duration_minutes,
        annual_effort_level,
        annual_completion_point,
        annual_readiness_note,
        annual_weather_note,
        linked_work_order_id,
        linked_work_order_gate,
        annual_notes,
        verification_state,
        execution_status
    ) VALUES (
        v_session_id,
        NULL,
        'SEASON_ONLY',
        v_name,
        p_stage_id,
        p_lor_scene_id,
        v_action,
        p_planned_order,
        p_normal_crew_min,
        p_normal_crew_max,
        p_expected_duration_minutes,
        v_effort,
        nullif(btrim(p_completion_point), ''),
        nullif(btrim(p_readiness_note), ''),
        nullif(btrim(p_weather_note), ''),
        p_linked_work_order_id,
        coalesce(p_linked_work_order_gate, false),
        nullif(btrim(p_annual_notes), ''),
        'VERIFIED',
        CASE WHEN v_action = 'GATE' THEN 'NOT_READY' ELSE 'READY' END
    )
    RETURNING ops.setup_session_task.setup_session_task_id INTO v_session_task_id;

    RETURN QUERY SELECT v_session_task_id, v_display_name;
END;
$function$;

REVOKE ALL ON FUNCTION ops.create_setup_season_task(
    text,integer,text,integer,bigint,text,integer,integer,integer,integer,text,
    text,text,text,bigint,boolean,text
) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION ops.create_setup_season_task(
    text,integer,text,integer,bigint,text,integer,integer,integer,integer,text,
    text,text,text,bigint,boolean,text
) TO fieldwiring_app;

CREATE OR REPLACE FUNCTION ops.update_setup_annual_task_definition(
    p_email text,
    p_setup_session_task_id bigint,
    p_task_name text,
    p_stage_id integer,
    p_lor_scene_id bigint,
    p_task_action_type text,
    p_normal_crew_min integer,
    p_normal_crew_max integer,
    p_expected_duration_minutes integer,
    p_effort_level text,
    p_completion_point text,
    p_readiness_note text,
    p_weather_note text,
    p_linked_work_order_id bigint,
    p_linked_work_order_gate boolean,
    p_annual_notes text
)
RETURNS TABLE (
    setup_session_task_id bigint,
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
    v_name text := nullif(btrim(p_task_name), '');
    v_action text := upper(btrim(coalesce(p_task_action_type, 'WORK')));
    v_effort text := upper(nullif(btrim(p_effort_level), ''));
BEGIN
    SELECT a.directus_user_id, a.person_id, a.display_name
      INTO v_directus_user_id, v_person_id, v_display_name
    FROM ref.setup_management_actor(p_email, false) a;

    IF v_name IS NULL THEN
        RAISE EXCEPTION USING ERRCODE = '22023', MESSAGE = 'Annual task name is required';
    END IF;
    IF v_action NOT IN ('WORK','UNLOAD_CONTAINER','SUPPORT','GATE') THEN
        RAISE EXCEPTION USING ERRCODE = '22023', MESSAGE = 'Invalid annual task type';
    END IF;
    IF v_effort IS NOT NULL AND v_effort NOT IN ('LIGHT','MODERATE','HEAVY') THEN
        RAISE EXCEPTION USING ERRCODE = '22023',
            MESSAGE = 'Setup effort must be LIGHT, MODERATE, HEAVY, or blank';
    END IF;
    IF p_lor_scene_id IS NOT NULL AND NOT EXISTS (
        SELECT 1 FROM ref.lor_scene ls
        WHERE ls.lor_scene_id = p_lor_scene_id
          AND ls.stage_id = p_stage_id
    ) THEN
        RAISE EXCEPTION USING ERRCODE = '22023',
            MESSAGE = 'Selected Scene does not belong to the selected Stage';
    END IF;
    IF p_linked_work_order_id IS NOT NULL
       AND NOT EXISTS (SELECT 1 FROM ops.work_order wo WHERE wo.work_order_id = p_linked_work_order_id) THEN
        RAISE EXCEPTION USING ERRCODE = '23503', MESSAGE = 'Linked Work Order was not found';
    END IF;

    PERFORM pg_catalog.set_config('app.directus_user_uuid', v_directus_user_id::text, true);

    UPDATE ops.setup_session_task st
       SET annual_task_name = v_name,
           annual_stage_id = p_stage_id,
           annual_lor_scene_id = p_lor_scene_id,
           annual_task_action_type = v_action,
           annual_normal_crew_min = p_normal_crew_min,
           annual_normal_crew_max = p_normal_crew_max,
           annual_expected_duration_minutes = p_expected_duration_minutes,
           annual_effort_level = v_effort,
           annual_completion_point = nullif(btrim(p_completion_point), ''),
           annual_readiness_note = nullif(btrim(p_readiness_note), ''),
           annual_weather_note = nullif(btrim(p_weather_note), ''),
           linked_work_order_id = p_linked_work_order_id,
           linked_work_order_gate = coalesce(p_linked_work_order_gate, false),
           annual_notes = nullif(btrim(p_annual_notes), '')
     WHERE st.setup_session_task_id = p_setup_session_task_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION USING ERRCODE = 'P0002', MESSAGE = 'Annual Setup task was not found';
    END IF;

    RETURN QUERY SELECT p_setup_session_task_id, v_display_name;
END;
$function$;

REVOKE ALL ON FUNCTION ops.update_setup_annual_task_definition(
    text,bigint,text,integer,bigint,text,integer,integer,integer,text,
    text,text,text,bigint,boolean,text
) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION ops.update_setup_annual_task_definition(
    text,bigint,text,integer,bigint,text,integer,integer,integer,text,
    text,text,text,bigint,boolean,text
) TO fieldwiring_app;

CREATE OR REPLACE FUNCTION ops.set_setup_session_task_dependency(
    p_email text,
    p_setup_session_task_id bigint,
    p_prerequisite_setup_session_task_id bigint,
    p_dependency_note text,
    p_active boolean DEFAULT true
)
RETURNS TABLE (
    setup_session_task_id bigint,
    prerequisite_setup_session_task_id bigint,
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
    v_session_id bigint;
    v_prereq_session_id bigint;
BEGIN
    SELECT a.directus_user_id, a.person_id, a.display_name
      INTO v_directus_user_id, v_person_id, v_display_name
    FROM ref.setup_management_actor(p_email, false) a;

    SELECT st.setup_session_id INTO v_session_id
    FROM ops.setup_session_task st
    WHERE st.setup_session_task_id = p_setup_session_task_id;
    SELECT st.setup_session_id INTO v_prereq_session_id
    FROM ops.setup_session_task st
    WHERE st.setup_session_task_id = p_prerequisite_setup_session_task_id;

    IF v_session_id IS NULL OR v_prereq_session_id IS NULL THEN
        RAISE EXCEPTION USING ERRCODE = 'P0002', MESSAGE = 'Annual Setup task or prerequisite was not found';
    END IF;
    IF v_session_id <> v_prereq_session_id THEN
        RAISE EXCEPTION USING ERRCODE = '22023', MESSAGE = 'Annual prerequisite must belong to the same Setup Session';
    END IF;
    IF p_setup_session_task_id = p_prerequisite_setup_session_task_id THEN
        RAISE EXCEPTION USING ERRCODE = '22023', MESSAGE = 'An annual Setup task cannot depend on itself';
    END IF;

    IF coalesce(p_active, true) AND EXISTS (
        WITH RECURSIVE chain(setup_session_task_id) AS (
            SELECT d.prerequisite_setup_session_task_id
            FROM ops.setup_session_task_dependency d
            WHERE d.setup_session_task_id = p_prerequisite_setup_session_task_id
            UNION
            SELECT d.prerequisite_setup_session_task_id
            FROM ops.setup_session_task_dependency d
            JOIN chain c ON d.setup_session_task_id = c.setup_session_task_id
        )
        SELECT 1
        FROM chain c
        WHERE c.setup_session_task_id = p_setup_session_task_id
    ) THEN
        RAISE EXCEPTION USING ERRCODE = '23514',
            MESSAGE = 'Annual prerequisite would create a circular Setup dependency';
    END IF;

    PERFORM pg_catalog.set_config('app.directus_user_uuid', v_directus_user_id::text, true);

    IF coalesce(p_active, true) THEN
        INSERT INTO ops.setup_session_task_dependency(
            setup_session_task_id,
            prerequisite_setup_session_task_id,
            dependency_origin,
            dependency_note
        ) VALUES (
            p_setup_session_task_id,
            p_prerequisite_setup_session_task_id,
            'ANNUAL',
            nullif(btrim(p_dependency_note), '')
        )
        ON CONFLICT ON CONSTRAINT pk_setup_session_task_dependency
        DO UPDATE SET dependency_origin = 'ANNUAL',
                      dependency_note = EXCLUDED.dependency_note;
    ELSE
        DELETE FROM ops.setup_session_task_dependency d
        WHERE d.setup_session_task_id = p_setup_session_task_id
          AND d.prerequisite_setup_session_task_id = p_prerequisite_setup_session_task_id;
    END IF;

    RETURN QUERY
    SELECT p_setup_session_task_id, p_prerequisite_setup_session_task_id,
           coalesce(p_active, true), v_display_name;
END;
$function$;

REVOKE ALL ON FUNCTION ops.set_setup_session_task_dependency(text,bigint,bigint,text,boolean) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION ops.set_setup_session_task_dependency(text,bigint,bigint,text,boolean) TO fieldwiring_app;

/* --------------------------------------------------------------------------
   WORK-DAY CREWS — DYNAMIC PER-DAY LANES, NO PERSON ROSTERS
   -------------------------------------------------------------------------- */

CREATE OR REPLACE FUNCTION ops.setup_crew_code(p_number integer)
RETURNS text
LANGUAGE plpgsql
IMMUTABLE
STRICT
AS $function$
DECLARE
    v_n integer := p_number;
    v_code text := '';
    v_digit integer;
BEGIN
    IF v_n < 1 THEN
        RAISE EXCEPTION USING ERRCODE = '22023',
            MESSAGE = 'Setup crew number must be greater than zero';
    END IF;

    WHILE v_n > 0 LOOP
        v_n := v_n - 1;
        v_digit := v_n % 26;
        v_code := chr(65 + v_digit) || v_code;
        v_n := v_n / 26;
    END LOOP;

    RETURN v_code;
END;
$function$;

CREATE TABLE IF NOT EXISTS ops.setup_work_day_crew (
    setup_work_day_crew_id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    setup_work_day_id bigint NOT NULL,
    crew_number integer NOT NULL,
    crew_code text NOT NULL,
    am_planned_crew_count integer,
    pm_planned_crew_count integer,
    created_at timestamptz NOT NULL DEFAULT now(),
    created_by text NOT NULL DEFAULT current_user,
    updated_at timestamptz NOT NULL DEFAULT now(),
    updated_by text NOT NULL DEFAULT current_user,
    created_by_person_id integer,
    updated_by_person_id integer,

    CONSTRAINT fk_setup_work_day_crew_day
        FOREIGN KEY (setup_work_day_id)
        REFERENCES ops.setup_work_day(setup_work_day_id)
        ON DELETE CASCADE,
    CONSTRAINT fk_setup_work_day_crew_created_by_person
        FOREIGN KEY (created_by_person_id) REFERENCES ref.person(person_id),
    CONSTRAINT fk_setup_work_day_crew_updated_by_person
        FOREIGN KEY (updated_by_person_id) REFERENCES ref.person(person_id),
    CONSTRAINT uq_setup_work_day_crew_number
        UNIQUE (setup_work_day_id, crew_number),
    CONSTRAINT uq_setup_work_day_crew_code
        UNIQUE (setup_work_day_id, crew_code),
    CONSTRAINT ck_setup_work_day_crew_number CHECK (crew_number > 0),
    CONSTRAINT ck_setup_work_day_crew_code CHECK (
        crew_code = ops.setup_crew_code(crew_number)
    ),
    CONSTRAINT ck_setup_work_day_crew_am_count CHECK (
        am_planned_crew_count IS NULL OR am_planned_crew_count >= 0
    ),
    CONSTRAINT ck_setup_work_day_crew_pm_count CHECK (
        pm_planned_crew_count IS NULL OR pm_planned_crew_count >= 0
    )
);

DROP TRIGGER IF EXISTS trg_setup_work_day_crew_actor_insert ON ops.setup_work_day_crew;
CREATE TRIGGER trg_setup_work_day_crew_actor_insert
BEFORE INSERT ON ops.setup_work_day_crew
FOR EACH ROW EXECUTE FUNCTION ref.set_actor_on_insert();

DROP TRIGGER IF EXISTS trg_setup_work_day_crew_actor_update ON ops.setup_work_day_crew;
CREATE TRIGGER trg_setup_work_day_crew_actor_update
BEFORE UPDATE ON ops.setup_work_day_crew
FOR EACH ROW EXECUTE FUNCTION ref.set_actor_on_update();

CREATE INDEX IF NOT EXISTS ix_setup_work_day_crew_day_order
    ON ops.setup_work_day_crew(setup_work_day_id, crew_number);

INSERT INTO ops.setup_work_day_crew(setup_work_day_id, crew_number, crew_code)
SELECT wd.setup_work_day_id, 1, 'A'
FROM ops.setup_work_day wd
ON CONFLICT (setup_work_day_id, crew_number) DO NOTHING;

INSERT INTO ops.setup_work_day_crew(setup_work_day_id, crew_number, crew_code)
SELECT DISTINCT
       wdt.setup_work_day_id,
       CASE upper(wdt.crew_lane)
           WHEN 'A' THEN 1
           WHEN 'B' THEN 2
           WHEN 'C' THEN 3
           WHEN 'D' THEN 4
           ELSE 1
       END,
       CASE upper(wdt.crew_lane)
           WHEN 'A' THEN 'A'
           WHEN 'B' THEN 'B'
           WHEN 'C' THEN 'C'
           WHEN 'D' THEN 'D'
           ELSE 'A'
       END
FROM ops.setup_work_day_task wdt
ON CONFLICT (setup_work_day_id, crew_number) DO NOTHING;

ALTER TABLE ops.setup_work_day_task
    ADD COLUMN IF NOT EXISTS setup_work_day_crew_id bigint;

UPDATE ops.setup_work_day_task wdt
   SET setup_work_day_crew_id = c.setup_work_day_crew_id
FROM ops.setup_work_day_crew c
WHERE wdt.setup_work_day_crew_id IS NULL
  AND c.setup_work_day_id = wdt.setup_work_day_id
  AND c.crew_code = upper(wdt.crew_lane);

ALTER TABLE ops.setup_work_day_task
    DROP CONSTRAINT IF EXISTS fk_setup_work_day_task_crew;
ALTER TABLE ops.setup_work_day_task
    ADD CONSTRAINT fk_setup_work_day_task_crew
    FOREIGN KEY (setup_work_day_crew_id)
    REFERENCES ops.setup_work_day_crew(setup_work_day_crew_id);

CREATE INDEX IF NOT EXISTS ix_setup_work_day_task_crew_identity
    ON ops.setup_work_day_task(setup_work_day_crew_id, shift_code, sort_order)
    WHERE setup_work_day_crew_id IS NOT NULL;

CREATE OR REPLACE FUNCTION ops.add_setup_work_day_crew(
    p_email text,
    p_setup_work_day_id bigint
)
RETURNS TABLE (
    setup_work_day_crew_id bigint,
    crew_number integer,
    crew_code text,
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
    v_number integer;
    v_id bigint;
    v_code text;
BEGIN
    SELECT a.directus_user_id, a.person_id, a.display_name
      INTO v_directus_user_id, v_person_id, v_display_name
    FROM ref.setup_management_actor(p_email, false) a;

    IF NOT EXISTS (
        SELECT 1 FROM ops.setup_work_day wd
        WHERE wd.setup_work_day_id = p_setup_work_day_id
    ) THEN
        RAISE EXCEPTION USING ERRCODE = 'P0002',
            MESSAGE = 'Setup work day was not found';
    END IF;

    SELECT coalesce(max(c.crew_number), 0) + 1
      INTO v_number
    FROM ops.setup_work_day_crew c
    WHERE c.setup_work_day_id = p_setup_work_day_id;

    v_code := ops.setup_crew_code(v_number);
    PERFORM pg_catalog.set_config('app.directus_user_uuid', v_directus_user_id::text, true);

    INSERT INTO ops.setup_work_day_crew(setup_work_day_id, crew_number, crew_code)
    VALUES (p_setup_work_day_id, v_number, v_code)
    RETURNING ops.setup_work_day_crew.setup_work_day_crew_id INTO v_id;

    RETURN QUERY SELECT v_id, v_number, v_code, v_display_name;
END;
$function$;

REVOKE ALL ON FUNCTION ops.add_setup_work_day_crew(text,bigint) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION ops.add_setup_work_day_crew(text,bigint) TO fieldwiring_app;

CREATE OR REPLACE FUNCTION ops.update_setup_work_day_crew(
    p_email text,
    p_setup_work_day_crew_id bigint,
    p_am_planned_crew_count integer,
    p_pm_planned_crew_count integer
)
RETURNS TABLE (
    setup_work_day_crew_id bigint,
    am_planned_crew_count integer,
    pm_planned_crew_count integer,
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
BEGIN
    SELECT a.directus_user_id, a.person_id, a.display_name
      INTO v_directus_user_id, v_person_id, v_display_name
    FROM ref.setup_management_actor(p_email, false) a;

    IF p_am_planned_crew_count IS NOT NULL AND p_am_planned_crew_count < 0
       OR p_pm_planned_crew_count IS NOT NULL AND p_pm_planned_crew_count < 0 THEN
        RAISE EXCEPTION USING ERRCODE = '22023',
            MESSAGE = 'Planned shift crew count cannot be negative';
    END IF;

    PERFORM pg_catalog.set_config('app.directus_user_uuid', v_directus_user_id::text, true);

    UPDATE ops.setup_work_day_crew c
       SET am_planned_crew_count = p_am_planned_crew_count,
           pm_planned_crew_count = p_pm_planned_crew_count
     WHERE c.setup_work_day_crew_id = p_setup_work_day_crew_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION USING ERRCODE = 'P0002',
            MESSAGE = 'Setup work-day crew was not found';
    END IF;

    RETURN QUERY
    SELECT c.setup_work_day_crew_id,
           c.am_planned_crew_count,
           c.pm_planned_crew_count,
           v_display_name
    FROM ops.setup_work_day_crew c
    WHERE c.setup_work_day_crew_id = p_setup_work_day_crew_id;
END;
$function$;

REVOKE ALL ON FUNCTION ops.update_setup_work_day_crew(text,bigint,integer,integer) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION ops.update_setup_work_day_crew(text,bigint,integer,integer) TO fieldwiring_app;

CREATE OR REPLACE FUNCTION ops.remove_setup_work_day_crew(
    p_email text,
    p_setup_work_day_crew_id bigint
)
RETURNS TABLE (
    setup_work_day_crew_id bigint,
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
    v_number integer;
BEGIN
    SELECT a.directus_user_id, a.person_id, a.display_name
      INTO v_directus_user_id, v_person_id, v_display_name
    FROM ref.setup_management_actor(p_email, false) a;

    SELECT c.crew_number INTO v_number
    FROM ops.setup_work_day_crew c
    WHERE c.setup_work_day_crew_id = p_setup_work_day_crew_id;

    IF v_number IS NULL THEN
        RAISE EXCEPTION USING ERRCODE = 'P0002',
            MESSAGE = 'Setup work-day crew was not found';
    END IF;
    IF v_number = 1 THEN
        RAISE EXCEPTION USING ERRCODE = '23514',
            MESSAGE = 'Crew A is the default crew for a Setup work day and cannot be removed';
    END IF;
    IF EXISTS (
        SELECT 1 FROM ops.setup_work_day_task wdt
        WHERE wdt.setup_work_day_crew_id = p_setup_work_day_crew_id
    ) THEN
        RAISE EXCEPTION USING ERRCODE = '23514',
            MESSAGE = 'Move or remove this crew''s scheduled work before removing the crew';
    END IF;

    PERFORM pg_catalog.set_config('app.directus_user_uuid', v_directus_user_id::text, true);

    DELETE FROM ops.setup_work_day_crew c
    WHERE c.setup_work_day_crew_id = p_setup_work_day_crew_id;

    RETURN QUERY SELECT p_setup_work_day_crew_id, v_display_name;
END;
$function$;

REVOKE ALL ON FUNCTION ops.remove_setup_work_day_crew(text,bigint) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION ops.remove_setup_work_day_crew(text,bigint) TO fieldwiring_app;

GRANT SELECT ON ops.setup_work_day_crew TO fieldwiring_app;

/* --------------------------------------------------------------------------
   STABLE SCHEDULE ASSIGNMENT IDENTITY + HISTORICAL STICKINESS
   -------------------------------------------------------------------------- */

ALTER TABLE ops.setup_work_day_task
    ADD COLUMN IF NOT EXISTS setup_work_day_task_id bigint GENERATED ALWAYS AS IDENTITY;

ALTER TABLE ops.setup_work_day_task
    DROP CONSTRAINT IF EXISTS pk_setup_work_day_task;
ALTER TABLE ops.setup_work_day_task
    ADD CONSTRAINT pk_setup_work_day_task PRIMARY KEY (setup_work_day_task_id);

ALTER TABLE ops.setup_work_day_task
    DROP CONSTRAINT IF EXISTS uq_setup_work_day_task_task_shift;
ALTER TABLE ops.setup_work_day_task
    ADD CONSTRAINT uq_setup_work_day_task_task_shift
    UNIQUE (setup_work_day_id, setup_session_task_id, shift_code);

ALTER TABLE ops.setup_work_day_task
    DROP CONSTRAINT IF EXISTS ck_setup_work_day_task_crew_lane;
ALTER TABLE ops.setup_work_day_task
    ADD CONSTRAINT ck_setup_work_day_task_crew_lane CHECK (
        crew_lane ~ '^[A-Z]+$'
    );

ALTER TABLE ops.setup_task_progress
    ADD COLUMN IF NOT EXISTS setup_work_day_task_id bigint;

ALTER TABLE ops.setup_task_progress
    DROP CONSTRAINT IF EXISTS fk_setup_task_progress_assignment;
ALTER TABLE ops.setup_task_progress
    ADD CONSTRAINT fk_setup_task_progress_assignment
    FOREIGN KEY (setup_work_day_task_id)
    REFERENCES ops.setup_work_day_task(setup_work_day_task_id);

UPDATE ops.setup_task_progress p
   SET setup_work_day_task_id = wdt.setup_work_day_task_id
FROM ops.setup_work_day_task wdt
WHERE p.setup_work_day_task_id IS NULL
  AND p.setup_work_day_id = wdt.setup_work_day_id
  AND p.setup_session_task_id = wdt.setup_session_task_id
  AND p.shift_code = wdt.shift_code;

CREATE INDEX IF NOT EXISTS ix_setup_task_progress_assignment
    ON ops.setup_task_progress(setup_work_day_task_id, setup_task_progress_id)
    WHERE setup_work_day_task_id IS NOT NULL;

CREATE OR REPLACE FUNCTION ops.refresh_setup_session_task_schedule_state(
    p_setup_session_task_id bigint
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, ops
AS $function$
DECLARE
    v_next_date date;
    v_has_assignment boolean;
BEGIN
    SELECT min(wd.work_date),
           count(*) > 0
      INTO v_next_date, v_has_assignment
    FROM ops.setup_work_day_task wdt
    JOIN ops.setup_work_day wd
      ON wd.setup_work_day_id = wdt.setup_work_day_id
    WHERE wdt.setup_session_task_id = p_setup_session_task_id
      AND wd.day_status <> 'CANCELLED'
      AND wd.work_date >= current_date
      AND wdt.actual_crew_count IS NULL
      AND wdt.started_at IS NULL
      AND wdt.completed_at IS NULL
      AND NOT EXISTS (
          SELECT 1
          FROM ops.setup_task_progress p
          WHERE p.setup_work_day_task_id = wdt.setup_work_day_task_id
             OR (
                 p.setup_work_day_task_id IS NULL
                 AND p.setup_work_day_id = wdt.setup_work_day_id
                 AND p.setup_session_task_id = wdt.setup_session_task_id
                 AND p.shift_code = wdt.shift_code
             )
      );

    UPDATE ops.setup_session_task st
       SET planned_date = v_next_date,
           execution_status = CASE
               WHEN st.execution_status IN ('COMPLETE','DEFERRED','IN_PROGRESS') THEN st.execution_status
               WHEN v_has_assignment THEN 'PLANNED'
               WHEN st.execution_status = 'PLANNED' THEN 'READY'
               ELSE st.execution_status
           END
     WHERE st.setup_session_task_id = p_setup_session_task_id;
END;
$function$;

REVOKE ALL ON FUNCTION ops.refresh_setup_session_task_schedule_state(bigint) FROM PUBLIC;
REVOKE ALL ON FUNCTION ops.refresh_setup_session_task_schedule_state(bigint) FROM fieldwiring_app;

CREATE OR REPLACE FUNCTION ops.create_setup_work_day_assignment(
    p_email text,
    p_setup_work_day_id bigint,
    p_setup_session_task_id bigint,
    p_shift_code text,
    p_crew_lane text,
    p_sort_order integer,
    p_planned_crew_count integer
)
RETURNS TABLE (
    setup_work_day_task_id bigint,
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
    v_lane text := upper(btrim(coalesce(p_crew_lane, 'A')));
    v_assignment_id bigint;
BEGIN
    SELECT a.directus_user_id, a.person_id, a.display_name
      INTO v_directus_user_id, v_person_id, v_display_name
    FROM ref.setup_management_actor(p_email, false) a;

    IF v_shift NOT IN ('MORNING','AFTERNOON','ALL_DAY') THEN
        RAISE EXCEPTION USING ERRCODE = '22023', MESSAGE = 'Invalid Setup shift';
    END IF;
    IF v_lane NOT IN ('A','B','C','D') THEN
        RAISE EXCEPTION USING ERRCODE = '22023', MESSAGE = 'Crew lane must be A, B, C, or D';
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
    RETURNING ops.setup_work_day_task.setup_work_day_task_id INTO v_assignment_id;

    PERFORM ops.refresh_setup_session_task_schedule_state(p_setup_session_task_id);
    RETURN QUERY SELECT v_assignment_id, v_display_name;
END;
$function$;

REVOKE ALL ON FUNCTION ops.create_setup_work_day_assignment(
    text,bigint,bigint,text,text,integer,integer
) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION ops.create_setup_work_day_assignment(
    text,bigint,bigint,text,text,integer,integer
) TO fieldwiring_app;

CREATE OR REPLACE FUNCTION ops.update_setup_work_day_assignment(
    p_email text,
    p_setup_work_day_task_id bigint,
    p_setup_work_day_id bigint,
    p_shift_code text,
    p_crew_lane text,
    p_sort_order integer,
    p_planned_crew_count integer
)
RETURNS TABLE (
    setup_work_day_task_id bigint,
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
    v_lane text := upper(btrim(coalesce(p_crew_lane, 'A')));
    v_session_task_id bigint;
BEGIN
    SELECT a.directus_user_id, a.person_id, a.display_name
      INTO v_directus_user_id, v_person_id, v_display_name
    FROM ref.setup_management_actor(p_email, false) a;

    SELECT wdt.setup_session_task_id INTO v_session_task_id
    FROM ops.setup_work_day_task wdt
    WHERE wdt.setup_work_day_task_id = p_setup_work_day_task_id;
    IF v_session_task_id IS NULL THEN
        RAISE EXCEPTION USING ERRCODE = 'P0002', MESSAGE = 'Scheduled Setup assignment was not found';
    END IF;

    IF EXISTS (
        SELECT 1
        FROM ops.setup_work_day_task wdt
        WHERE wdt.setup_work_day_task_id = p_setup_work_day_task_id
          AND (
              wdt.actual_crew_count IS NOT NULL
              OR wdt.started_at IS NOT NULL
              OR wdt.completed_at IS NOT NULL
          )
    ) OR EXISTS (
        SELECT 1
        FROM ops.setup_task_progress p
        JOIN ops.setup_work_day_task wdt
          ON wdt.setup_work_day_task_id = p_setup_work_day_task_id
        WHERE p.setup_work_day_task_id = p_setup_work_day_task_id
           OR (
               p.setup_work_day_task_id IS NULL
               AND p.setup_work_day_id = wdt.setup_work_day_id
               AND p.setup_session_task_id = wdt.setup_session_task_id
               AND p.shift_code = wdt.shift_code
           )
    ) THEN
        RAISE EXCEPTION USING ERRCODE = '23514',
            MESSAGE = 'Actual work exists for this assignment; preserve it as history and schedule a continuation instead';
    END IF;

    IF v_shift NOT IN ('MORNING','AFTERNOON','ALL_DAY') THEN
        RAISE EXCEPTION USING ERRCODE = '22023', MESSAGE = 'Invalid Setup shift';
    END IF;
    IF v_lane NOT IN ('A','B','C','D') THEN
        RAISE EXCEPTION USING ERRCODE = '22023', MESSAGE = 'Crew lane must be A, B, C, or D';
    END IF;
    IF NOT EXISTS (
        SELECT 1
        FROM ops.setup_work_day wd
        JOIN ops.setup_session_task st ON st.setup_session_id = wd.setup_session_id
        WHERE wd.setup_work_day_id = p_setup_work_day_id
          AND st.setup_session_task_id = v_session_task_id
    ) THEN
        RAISE EXCEPTION USING ERRCODE = '22023',
            MESSAGE = 'Scheduled task must belong to the same Setup Session as the work day';
    END IF;

    PERFORM pg_catalog.set_config('app.directus_user_uuid', v_directus_user_id::text, true);

    UPDATE ops.setup_work_day_task wdt
       SET setup_work_day_id = p_setup_work_day_id,
           shift_code = v_shift,
           crew_lane = v_lane,
           sort_order = coalesce(p_sort_order, wdt.sort_order),
           planned_crew_count = p_planned_crew_count
     WHERE wdt.setup_work_day_task_id = p_setup_work_day_task_id;

    PERFORM ops.refresh_setup_session_task_schedule_state(v_session_task_id);
    RETURN QUERY SELECT p_setup_work_day_task_id, v_display_name;
END;
$function$;

REVOKE ALL ON FUNCTION ops.update_setup_work_day_assignment(
    text,bigint,bigint,text,text,integer,integer
) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION ops.update_setup_work_day_assignment(
    text,bigint,bigint,text,text,integer,integer
) TO fieldwiring_app;


/* #205 board commands use explicit per-work-day crew identity and AM/PM only.
   The older lane/planned-count signatures remain for legacy compatibility. */
CREATE OR REPLACE FUNCTION ops.create_setup_work_day_assignment(
    p_email text,
    p_setup_work_day_id bigint,
    p_setup_session_task_id bigint,
    p_shift_code text,
    p_setup_work_day_crew_id bigint,
    p_sort_order integer
)
RETURNS TABLE (
    setup_work_day_task_id bigint,
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
    v_shift text := upper(btrim(coalesce(p_shift_code, 'MORNING')));
    v_lane text;
    v_assignment_id bigint;
BEGIN
    SELECT a.directus_user_id, a.person_id, a.display_name
      INTO v_directus_user_id, v_person_id, v_display_name
    FROM ref.setup_management_actor(p_email, false) a;

    IF v_shift NOT IN ('MORNING','AFTERNOON') THEN
        RAISE EXCEPTION USING ERRCODE = '22023',
            MESSAGE = 'New Scheduling Board assignments must use Morning or Afternoon';
    END IF;

    SELECT c.crew_code INTO v_lane
    FROM ops.setup_work_day_crew c
    WHERE c.setup_work_day_crew_id = p_setup_work_day_crew_id
      AND c.setup_work_day_id = p_setup_work_day_id;

    IF v_lane IS NULL THEN
        RAISE EXCEPTION USING ERRCODE = '22023',
            MESSAGE = 'Selected crew does not belong to the selected Setup work day';
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

    IF EXISTS (
        SELECT 1
        FROM ops.setup_work_day_task wdt
        WHERE wdt.setup_work_day_id = p_setup_work_day_id
          AND wdt.setup_session_task_id = p_setup_session_task_id
    ) THEN
        RAISE EXCEPTION USING ERRCODE = '23505',
            MESSAGE = 'This task is already scheduled on this Setup work day; move the existing assignment instead';
    END IF;

    PERFORM pg_catalog.set_config('app.directus_user_uuid', v_directus_user_id::text, true);

    INSERT INTO ops.setup_work_day_task(
        setup_work_day_id,
        setup_session_task_id,
        shift_code,
        crew_lane,
        setup_work_day_crew_id,
        sort_order,
        planned_crew_count
    ) VALUES (
        p_setup_work_day_id,
        p_setup_session_task_id,
        v_shift,
        v_lane,
        p_setup_work_day_crew_id,
        coalesce(p_sort_order, 100),
        NULL
    )
    RETURNING ops.setup_work_day_task.setup_work_day_task_id INTO v_assignment_id;

    PERFORM ops.refresh_setup_session_task_schedule_state(p_setup_session_task_id);
    RETURN QUERY SELECT v_assignment_id, v_display_name;
END;
$function$;

REVOKE ALL ON FUNCTION ops.create_setup_work_day_assignment(
    text,bigint,bigint,text,bigint,integer
) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION ops.create_setup_work_day_assignment(
    text,bigint,bigint,text,bigint,integer
) TO fieldwiring_app;

CREATE OR REPLACE FUNCTION ops.update_setup_work_day_assignment(
    p_email text,
    p_setup_work_day_task_id bigint,
    p_setup_work_day_id bigint,
    p_shift_code text,
    p_setup_work_day_crew_id bigint,
    p_sort_order integer
)
RETURNS TABLE (
    setup_work_day_task_id bigint,
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
    v_shift text := upper(btrim(coalesce(p_shift_code, 'MORNING')));
    v_lane text;
    v_session_task_id bigint;
BEGIN
    SELECT a.directus_user_id, a.person_id, a.display_name
      INTO v_directus_user_id, v_person_id, v_display_name
    FROM ref.setup_management_actor(p_email, false) a;

    SELECT wdt.setup_session_task_id INTO v_session_task_id
    FROM ops.setup_work_day_task wdt
    WHERE wdt.setup_work_day_task_id = p_setup_work_day_task_id;
    IF v_session_task_id IS NULL THEN
        RAISE EXCEPTION USING ERRCODE = 'P0002',
            MESSAGE = 'Scheduled Setup assignment was not found';
    END IF;

    IF EXISTS (
        SELECT 1
        FROM ops.setup_work_day_task wdt
        WHERE wdt.setup_work_day_task_id = p_setup_work_day_task_id
          AND (
              wdt.actual_crew_count IS NOT NULL
              OR wdt.started_at IS NOT NULL
              OR wdt.completed_at IS NOT NULL
          )
    ) OR EXISTS (
        SELECT 1
        FROM ops.setup_task_progress p
        JOIN ops.setup_work_day_task wdt
          ON wdt.setup_work_day_task_id = p_setup_work_day_task_id
        WHERE p.setup_work_day_task_id = p_setup_work_day_task_id
           OR (
               p.setup_work_day_task_id IS NULL
               AND p.setup_work_day_id = wdt.setup_work_day_id
               AND p.setup_session_task_id = wdt.setup_session_task_id
               AND p.shift_code = wdt.shift_code
           )
    ) THEN
        RAISE EXCEPTION USING ERRCODE = '23514',
            MESSAGE = 'Actual work exists for this assignment; preserve it as history and schedule a continuation instead';
    END IF;

    IF v_shift NOT IN ('MORNING','AFTERNOON') THEN
        RAISE EXCEPTION USING ERRCODE = '22023',
            MESSAGE = 'New Scheduling Board assignments must use Morning or Afternoon';
    END IF;

    SELECT c.crew_code INTO v_lane
    FROM ops.setup_work_day_crew c
    WHERE c.setup_work_day_crew_id = p_setup_work_day_crew_id
      AND c.setup_work_day_id = p_setup_work_day_id;

    IF v_lane IS NULL THEN
        RAISE EXCEPTION USING ERRCODE = '22023',
            MESSAGE = 'Selected crew does not belong to the selected Setup work day';
    END IF;

    IF NOT EXISTS (
        SELECT 1
        FROM ops.setup_work_day wd
        JOIN ops.setup_session_task st ON st.setup_session_id = wd.setup_session_id
        WHERE wd.setup_work_day_id = p_setup_work_day_id
          AND st.setup_session_task_id = v_session_task_id
    ) THEN
        RAISE EXCEPTION USING ERRCODE = '22023',
            MESSAGE = 'Scheduled task must belong to the same Setup Session as the work day';
    END IF;

    IF EXISTS (
        SELECT 1
        FROM ops.setup_work_day_task other
        WHERE other.setup_work_day_id = p_setup_work_day_id
          AND other.setup_session_task_id = v_session_task_id
          AND other.setup_work_day_task_id <> p_setup_work_day_task_id
    ) THEN
        RAISE EXCEPTION USING ERRCODE = '23505',
            MESSAGE = 'This task is already scheduled on this Setup work day';
    END IF;

    PERFORM pg_catalog.set_config('app.directus_user_uuid', v_directus_user_id::text, true);

    UPDATE ops.setup_work_day_task wdt
       SET setup_work_day_id = p_setup_work_day_id,
           shift_code = v_shift,
           crew_lane = v_lane,
           setup_work_day_crew_id = p_setup_work_day_crew_id,
           sort_order = coalesce(p_sort_order, wdt.sort_order),
           planned_crew_count = NULL
     WHERE wdt.setup_work_day_task_id = p_setup_work_day_task_id;

    PERFORM ops.refresh_setup_session_task_schedule_state(v_session_task_id);
    RETURN QUERY SELECT p_setup_work_day_task_id, v_display_name;
END;
$function$;

REVOKE ALL ON FUNCTION ops.update_setup_work_day_assignment(
    text,bigint,bigint,text,bigint,integer
) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION ops.update_setup_work_day_assignment(
    text,bigint,bigint,text,bigint,integer
) TO fieldwiring_app;

CREATE OR REPLACE FUNCTION ops.remove_setup_work_day_assignment(
    p_email text,
    p_setup_work_day_task_id bigint
)
RETURNS TABLE (
    setup_work_day_task_id bigint,
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
    v_session_task_id bigint;
BEGIN
    SELECT a.directus_user_id, a.person_id, a.display_name
      INTO v_directus_user_id, v_person_id, v_display_name
    FROM ref.setup_management_actor(p_email, false) a;

    SELECT wdt.setup_session_task_id INTO v_session_task_id
    FROM ops.setup_work_day_task wdt
    WHERE wdt.setup_work_day_task_id = p_setup_work_day_task_id;
    IF v_session_task_id IS NULL THEN
        RAISE EXCEPTION USING ERRCODE = 'P0002', MESSAGE = 'Scheduled Setup assignment was not found';
    END IF;

    IF EXISTS (
        SELECT 1
        FROM ops.setup_work_day_task wdt
        WHERE wdt.setup_work_day_task_id = p_setup_work_day_task_id
          AND (
              wdt.actual_crew_count IS NOT NULL
              OR wdt.started_at IS NOT NULL
              OR wdt.completed_at IS NOT NULL
          )
    ) OR EXISTS (
        SELECT 1
        FROM ops.setup_task_progress p
        JOIN ops.setup_work_day_task wdt
          ON wdt.setup_work_day_task_id = p_setup_work_day_task_id
        WHERE p.setup_work_day_task_id = p_setup_work_day_task_id
           OR (
               p.setup_work_day_task_id IS NULL
               AND p.setup_work_day_id = wdt.setup_work_day_id
               AND p.setup_session_task_id = wdt.setup_session_task_id
               AND p.shift_code = wdt.shift_code
           )
    ) THEN
        RAISE EXCEPTION USING ERRCODE = '23514',
            MESSAGE = 'Actual work exists for this assignment; historical work cannot be removed';
    END IF;

    PERFORM pg_catalog.set_config('app.directus_user_uuid', v_directus_user_id::text, true);

    DELETE FROM ops.setup_work_day_task wdt
    WHERE wdt.setup_work_day_task_id = p_setup_work_day_task_id;

    PERFORM ops.refresh_setup_session_task_schedule_state(v_session_task_id);
    RETURN QUERY SELECT p_setup_work_day_task_id, v_display_name;
END;
$function$;

REVOKE ALL ON FUNCTION ops.remove_setup_work_day_assignment(text,bigint) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION ops.remove_setup_work_day_assignment(text,bigint) TO fieldwiring_app;

/* Preserve the old command for compatibility, but route it through the new
   assignment identity. The #205 board uses the explicit assignment commands. */
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
    v_existing_id bigint;
    v_display_name text;
BEGIN
    SELECT wdt.setup_work_day_task_id
      INTO v_existing_id
    FROM ops.setup_work_day_task wdt
    WHERE wdt.setup_work_day_id = p_setup_work_day_id
      AND wdt.setup_session_task_id = p_setup_session_task_id
      AND wdt.shift_code = upper(btrim(coalesce(p_shift_code, 'ALL_DAY')))
    LIMIT 1;

    IF coalesce(p_active, true) THEN
        IF v_existing_id IS NULL THEN
            SELECT a.setup_work_day_task_id, a.operator_display_name
              INTO v_existing_id, v_display_name
            FROM ops.create_setup_work_day_assignment(
                p_email, p_setup_work_day_id, p_setup_session_task_id,
                p_shift_code, p_crew_lane, p_sort_order, p_planned_crew_count
            ) a;
        ELSE
            SELECT a.operator_display_name
              INTO v_display_name
            FROM ops.update_setup_work_day_assignment(
                p_email, v_existing_id, p_setup_work_day_id,
                p_shift_code, p_crew_lane, p_sort_order, p_planned_crew_count
            ) a;
        END IF;
    ELSE
        IF v_existing_id IS NOT NULL THEN
            SELECT a.operator_display_name
              INTO v_display_name
            FROM ops.remove_setup_work_day_assignment(p_email, v_existing_id) a;
        ELSE
            SELECT a.display_name INTO v_display_name
            FROM ref.setup_management_actor(p_email, false) a;
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

/* --------------------------------------------------------------------------
   WORK-DAY UPSERT WITH DAY NUMBER + EXISTING WEATHER/VOLUNTEER NOTES
   -------------------------------------------------------------------------- */

CREATE OR REPLACE FUNCTION ops.upsert_setup_work_day(
    p_email text,
    p_season_year integer,
    p_work_date date,
    p_setup_day_number integer,
    p_day_status text,
    p_weather_note text,
    p_volunteer_note text,
    p_notes text
)
RETURNS TABLE (
    setup_work_day_id bigint,
    setup_day_number integer,
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
    v_day_number integer;
    v_conflict_date date;
    v_status text := upper(btrim(coalesce(p_day_status, 'PLANNED')));
BEGIN
    SELECT a.directus_user_id, a.person_id, a.display_name
      INTO v_directus_user_id, v_person_id, v_display_name
    FROM ref.setup_management_actor(p_email, false) a;

    SELECT ss.setup_session_id INTO v_session_id
    FROM ops.setup_session ss
    WHERE ss.season_year = p_season_year;
    IF v_session_id IS NULL THEN
        RAISE EXCEPTION USING ERRCODE = 'P0002', MESSAGE = 'Setup Session was not found for this season';
    END IF;
    IF p_work_date IS NULL THEN
        RAISE EXCEPTION USING ERRCODE = '22023', MESSAGE = 'Work date is required';
    END IF;
    IF extract(year FROM p_work_date)::integer <> p_season_year THEN
        RAISE EXCEPTION USING ERRCODE = '22023',
            MESSAGE = 'Setup work date must be in the selected Setup Session year';
    END IF;
    IF v_status NOT IN ('PLANNED','ACTIVE','COMPLETE','CANCELLED') THEN
        RAISE EXCEPTION USING ERRCODE = '22023', MESSAGE = 'Invalid Setup work-day status';
    END IF;
    IF p_setup_day_number IS NOT NULL AND p_setup_day_number <= 0 THEN
        RAISE EXCEPTION USING ERRCODE = '22023', MESSAGE = 'Setup Day Number must be greater than zero';
    END IF;

    IF p_setup_day_number IS NOT NULL THEN
        SELECT wd.work_date
          INTO v_conflict_date
        FROM ops.setup_work_day wd
        WHERE wd.setup_session_id = v_session_id
          AND wd.setup_day_number = p_setup_day_number
          AND wd.work_date <> p_work_date
        LIMIT 1;

        IF v_conflict_date IS NOT NULL THEN
            RAISE EXCEPTION USING ERRCODE = '22023',
                MESSAGE = format(
                    'Setup Day %s is already assigned to %s',
                    p_setup_day_number,
                    v_conflict_date
                );
        END IF;
    END IF;

    SELECT wd.setup_work_day_id, wd.setup_day_number
      INTO v_day_id, v_day_number
    FROM ops.setup_work_day wd
    WHERE wd.setup_session_id = v_session_id
      AND wd.work_date = p_work_date;

    IF v_day_number IS NULL THEN
        v_day_number := p_setup_day_number;
    END IF;
    IF v_day_number IS NULL THEN
        SELECT coalesce(max(wd.setup_day_number), 0) + 1
          INTO v_day_number
        FROM ops.setup_work_day wd
        WHERE wd.setup_session_id = v_session_id;
    END IF;
    IF p_setup_day_number IS NOT NULL THEN
        v_day_number := p_setup_day_number;
    END IF;

    PERFORM pg_catalog.set_config('app.directus_user_uuid', v_directus_user_id::text, true);

    INSERT INTO ops.setup_work_day(
        setup_session_id,
        work_date,
        setup_day_number,
        day_status,
        weather_note,
        volunteer_note,
        notes
    ) VALUES (
        v_session_id,
        p_work_date,
        v_day_number,
        v_status,
        nullif(btrim(p_weather_note), ''),
        nullif(btrim(p_volunteer_note), ''),
        nullif(btrim(p_notes), '')
    )
    ON CONFLICT (setup_session_id, work_date)
    DO UPDATE SET setup_day_number = EXCLUDED.setup_day_number,
                  day_status = EXCLUDED.day_status,
                  weather_note = EXCLUDED.weather_note,
                  volunteer_note = EXCLUDED.volunteer_note,
                  notes = EXCLUDED.notes
    RETURNING ops.setup_work_day.setup_work_day_id,
              ops.setup_work_day.setup_day_number
         INTO v_day_id, v_day_number;

    INSERT INTO ops.setup_work_day_crew(setup_work_day_id, crew_number, crew_code)
    VALUES (v_day_id, 1, 'A')
    ON CONFLICT (setup_work_day_id, crew_number) DO NOTHING;

    RETURN QUERY SELECT v_day_id, v_day_number, v_display_name;
END;
$function$;

REVOKE ALL ON FUNCTION ops.upsert_setup_work_day(
    text,integer,date,integer,text,text,text,text
) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION ops.upsert_setup_work_day(
    text,integer,date,integer,text,text,text,text
) TO fieldwiring_app;

/* --------------------------------------------------------------------------
   PROGRESS -> EXACT SCHEDULE ASSIGNMENT LINK

   #132 owns duration and Production Crew execution authorization. #205 only
   makes existing progress evidence retain the exact scheduled assignment when
   one exists, so day/shift/crew-lane history cannot become ambiguous.
   -------------------------------------------------------------------------- */

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
    v_assignment_id bigint;
BEGIN
    SELECT st.setup_task_id, st.setup_session_id
      INTO v_setup_task_id, v_setup_session_id
    FROM ops.setup_session_task st
    WHERE st.setup_session_task_id = p_setup_session_task_id;

    IF v_setup_session_id IS NULL THEN
        RAISE EXCEPTION USING ERRCODE = 'P0002', MESSAGE = 'Annual Setup task was not found';
    END IF;

    /* Existing execution authorization remains intact here. #132 owns the
       accepted Production Crew authorization correction. Managers can already
       report season-only annual tasks because they do not require a reusable
       task identity for the Manager branch of setup_execution_actor(). */
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

    PERFORM pg_catalog.set_config('app.directus_user_uuid', v_directus_user_id::text, true);

    INSERT INTO ops.setup_task_progress(
        setup_session_task_id,
        setup_work_day_id,
        setup_work_day_task_id,
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
        v_assignment_id,
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

    IF v_assignment_id IS NOT NULL THEN
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
         WHERE wdt.setup_work_day_task_id = v_assignment_id;
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

/* Read surface for the protected Setup application. */
GRANT SELECT ON ops.setup_session_task_dependency TO fieldwiring_app;

COMMIT;

SELECT
    to_regclass('ops.setup_session_task_dependency') IS NOT NULL AS annual_dependency_ready,
    to_regclass('ops.setup_work_day_crew') IS NOT NULL AS work_day_crew_ready,
    EXISTS (
        SELECT 1
        FROM information_schema.columns
        WHERE table_schema='ops' AND table_name='setup_work_day'
          AND column_name='setup_day_number'
    ) AS setup_day_number_ready,
    EXISTS (
        SELECT 1
        FROM information_schema.columns
        WHERE table_schema='ops' AND table_name='setup_work_day_task'
          AND column_name='setup_work_day_task_id'
    ) AS assignment_identity_ready,
    to_regprocedure('ops.create_setup_season_task(text,integer,text,integer,bigint,text,integer,integer,integer,integer,text,text,text,text,bigint,boolean,text)') IS NOT NULL
        AS season_task_command_ready;
