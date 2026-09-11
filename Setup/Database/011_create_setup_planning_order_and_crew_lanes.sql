/* ============================================================================
MSB Setup Session — reusable/annual planning order and parallel crew lanes
Issue: #122
Status: IMPLEMENTATION CANDIDATE — DO NOT APPLY TO PRODUCTION WITHOUT REVIEW
Revision: 2026-09-07 V0.3.1

Purpose:
  Add the final planning model established during Manager browser review:
  - a reusable global Setup planning baseline that carries forward;
  - an annual planned-order override independent of calendar dates;
  - rolling-horizon scheduling without requiring every task to have a date;
  - parallel crew lanes on scheduled work (Crew A/B/C/etc.);
  - explicit support for Park Infrastructure reusable tasks by using the
    existing valid no-Stage/no-Scene task scope.

Design rules:
  - Stage/Scene display_order remains normal precedence inside that area.
  - baseline_plan_order is the reusable whole-Setup starting order.
  - planned_order is the annual Manager-adjustable whole-Setup order.
  - work-day/shift/crew-lane assignment is a short-horizon commitment only.
  - absence from a work day is a normal UNSCHEDULED state, not an error.
  - a no-Stage/no-Scene task is Site-wide / Park Infrastructure work; it is not
    an invitation to fabricate LOR Stage/Scene identity.
============================================================================ */

BEGIN;

DO $preflight$
BEGIN
    IF to_regclass('ref.setup_task') IS NULL
       OR to_regclass('ops.setup_session') IS NULL
       OR to_regclass('ops.setup_session_task') IS NULL
       OR to_regclass('ops.setup_work_day_task') IS NULL
       OR to_regprocedure('ref.setup_management_actor(text,boolean)') IS NULL
       OR to_regprocedure('ops.set_setup_work_day_task(text,bigint,bigint,text,integer,integer,boolean)') IS NULL THEN
        RAISE EXCEPTION 'Setup V0.2 scope/schedule foundation is required before migration 011';
    END IF;

    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'fieldwiring_app') THEN
        RAISE EXCEPTION 'Required application role fieldwiring_app does not exist';
    END IF;
END
$preflight$;

/* --------------------------------------------------------------------------
   REUSABLE AND ANNUAL WHOLE-SETUP ORDER
   -------------------------------------------------------------------------- */

ALTER TABLE ref.setup_task
    ADD COLUMN IF NOT EXISTS baseline_plan_order integer;

ALTER TABLE ref.setup_task
    DROP CONSTRAINT IF EXISTS ck_setup_task_baseline_plan_order;
ALTER TABLE ref.setup_task
    ADD CONSTRAINT ck_setup_task_baseline_plan_order CHECK (
        baseline_plan_order IS NULL OR baseline_plan_order >= 0
    );

ALTER TABLE ops.setup_session_task
    ADD COLUMN IF NOT EXISTS planned_order integer;

ALTER TABLE ops.setup_session_task
    DROP CONSTRAINT IF EXISTS ck_setup_session_task_planned_order;
ALTER TABLE ops.setup_session_task
    ADD CONSTRAINT ck_setup_session_task_planned_order CHECK (
        planned_order IS NULL OR planned_order >= 0
    );

/* Existing tasks receive a deterministic starting baseline. Leave 10..90 open
   for high-priority Command Center / Park Infrastructure work discovered during
   review. */
WITH ordered AS (
    SELECT
        t.setup_task_id,
        90 + row_number() OVER (
            ORDER BY
                s.park_order NULLS LAST,
                s.sub_order NULLS LAST,
                s.stage_key NULLS LAST,
                t.lor_scene_id NULLS FIRST,
                t.display_order,
                t.setup_task_id
        ) * 10 AS initial_order
    FROM ref.setup_task t
    LEFT JOIN ref.stage s ON s.stage_id = t.stage_id
    WHERE t.active_flag
)
UPDATE ref.setup_task t
   SET baseline_plan_order = o.initial_order
FROM ordered o
WHERE o.setup_task_id = t.setup_task_id
  AND t.baseline_plan_order IS NULL;

UPDATE ops.setup_session_task st
   SET planned_order = t.baseline_plan_order
FROM ref.setup_task t
WHERE t.setup_task_id = st.setup_task_id
  AND st.planned_order IS NULL;

CREATE INDEX IF NOT EXISTS ix_setup_task_baseline_plan_order
    ON ref.setup_task(baseline_plan_order, setup_task_id)
    WHERE active_flag;

CREATE INDEX IF NOT EXISTS ix_setup_session_task_planned_order
    ON ops.setup_session_task(setup_session_id, planned_order, setup_session_task_id)
    WHERE included_flag;

/* New reusable tasks automatically append to the reusable baseline when the
   calling command did not supply an order. */
CREATE OR REPLACE FUNCTION ref.default_setup_task_baseline_order()
RETURNS trigger
LANGUAGE plpgsql
AS $function$
BEGIN
    IF NEW.baseline_plan_order IS NULL THEN
        SELECT coalesce(max(t.baseline_plan_order), 0) + 10
          INTO NEW.baseline_plan_order
        FROM ref.setup_task t
        WHERE t.active_flag;
    END IF;
    RETURN NEW;
END;
$function$;

DROP TRIGGER IF EXISTS trg_setup_task_default_baseline_order ON ref.setup_task;
CREATE TRIGGER trg_setup_task_default_baseline_order
BEFORE INSERT ON ref.setup_task
FOR EACH ROW EXECUTE FUNCTION ref.default_setup_task_baseline_order();

/* New annual occurrences inherit the reusable baseline. This applies both when
   a new annual session is created and when a reusable task is added later. */
CREATE OR REPLACE FUNCTION ops.default_setup_session_task_planned_order()
RETURNS trigger
LANGUAGE plpgsql
AS $function$
BEGIN
    IF NEW.planned_order IS NULL THEN
        SELECT t.baseline_plan_order
          INTO NEW.planned_order
        FROM ref.setup_task t
        WHERE t.setup_task_id = NEW.setup_task_id;

        IF NEW.planned_order IS NULL THEN
            SELECT coalesce(max(st.planned_order), 0) + 10
              INTO NEW.planned_order
            FROM ops.setup_session_task st
            WHERE st.setup_session_id = NEW.setup_session_id;
        END IF;
    END IF;
    RETURN NEW;
END;
$function$;

DROP TRIGGER IF EXISTS trg_setup_session_task_default_planned_order ON ops.setup_session_task;
CREATE TRIGGER trg_setup_session_task_default_planned_order
BEFORE INSERT ON ops.setup_session_task
FOR EACH ROW EXECUTE FUNCTION ops.default_setup_session_task_planned_order();

CREATE OR REPLACE FUNCTION ref.set_setup_task_baseline_order(
    p_email text,
    p_setup_task_id bigint,
    p_baseline_plan_order integer
)
RETURNS TABLE (
    setup_task_id bigint,
    baseline_plan_order integer,
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

    IF p_baseline_plan_order IS NULL OR p_baseline_plan_order < 0 THEN
        RAISE EXCEPTION USING ERRCODE = '22023',
            MESSAGE = 'Reusable Setup baseline order must be zero or greater';
    END IF;

    PERFORM pg_catalog.set_config('app.directus_user_uuid', v_directus_user_id::text, true);

    UPDATE ref.setup_task t
       SET baseline_plan_order = p_baseline_plan_order
     WHERE t.setup_task_id = p_setup_task_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION USING ERRCODE = 'P0002', MESSAGE = 'Setup task was not found';
    END IF;

    RETURN QUERY SELECT p_setup_task_id, p_baseline_plan_order, v_display_name;
END;
$function$;

REVOKE ALL ON FUNCTION ref.set_setup_task_baseline_order(text,bigint,integer) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION ref.set_setup_task_baseline_order(text,bigint,integer) TO fieldwiring_app;

CREATE OR REPLACE FUNCTION ops.set_setup_session_task_planned_order(
    p_email text,
    p_setup_session_task_id bigint,
    p_planned_order integer,
    p_plan_change_reason text DEFAULT NULL
)
RETURNS TABLE (
    setup_session_task_id bigint,
    planned_order integer,
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
    FROM ref.setup_management_actor(p_email, false) AS a;

    IF p_planned_order IS NULL OR p_planned_order < 0 THEN
        RAISE EXCEPTION USING ERRCODE = '22023',
            MESSAGE = 'Annual Setup planned order must be zero or greater';
    END IF;

    PERFORM pg_catalog.set_config('app.directus_user_uuid', v_directus_user_id::text, true);

    UPDATE ops.setup_session_task st
       SET planned_order = p_planned_order,
           plan_change_reason = CASE
               WHEN nullif(btrim(p_plan_change_reason), '') IS NOT NULL
                   THEN nullif(btrim(p_plan_change_reason), '')
               ELSE st.plan_change_reason
           END
     WHERE st.setup_session_task_id = p_setup_session_task_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION USING ERRCODE = 'P0002', MESSAGE = 'Annual Setup task was not found';
    END IF;

    RETURN QUERY SELECT p_setup_session_task_id, p_planned_order, v_display_name;
END;
$function$;

REVOKE ALL ON FUNCTION ops.set_setup_session_task_planned_order(text,bigint,integer,text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION ops.set_setup_session_task_planned_order(text,bigint,integer,text) TO fieldwiring_app;

/* Explicit promotion is intentionally separate from ordinary annual reordering.
   A one-off year (road work, unusual access, equipment constraints) may keep an
   annual override without contaminating the reusable baseline. */
CREATE OR REPLACE FUNCTION ops.promote_setup_session_order_to_baseline(
    p_email text,
    p_season_year integer
)
RETURNS TABLE (
    updated_task_count integer,
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
    v_count integer := 0;
BEGIN
    SELECT a.directus_user_id, a.person_id, a.display_name
      INTO v_directus_user_id, v_person_id, v_display_name
    FROM ref.setup_management_actor(p_email, false) AS a;

    PERFORM pg_catalog.set_config('app.directus_user_uuid', v_directus_user_id::text, true);

    UPDATE ref.setup_task t
       SET baseline_plan_order = st.planned_order
    FROM ops.setup_session_task st
    JOIN ops.setup_session ss ON ss.setup_session_id = st.setup_session_id
    WHERE ss.season_year = p_season_year
      AND st.setup_task_id = t.setup_task_id
      AND st.included_flag
      AND st.planned_order IS NOT NULL
      AND t.active_flag;

    GET DIAGNOSTICS v_count = ROW_COUNT;
    RETURN QUERY SELECT v_count, v_display_name;
END;
$function$;

REVOKE ALL ON FUNCTION ops.promote_setup_session_order_to_baseline(text,integer) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION ops.promote_setup_session_order_to_baseline(text,integer) TO fieldwiring_app;

/* --------------------------------------------------------------------------
   PARALLEL CREW LANES
   -------------------------------------------------------------------------- */

ALTER TABLE ops.setup_work_day_task
    ADD COLUMN IF NOT EXISTS crew_lane text NOT NULL DEFAULT 'A';

ALTER TABLE ops.setup_work_day_task
    DROP CONSTRAINT IF EXISTS ck_setup_work_day_task_crew_lane;
ALTER TABLE ops.setup_work_day_task
    ADD CONSTRAINT ck_setup_work_day_task_crew_lane CHECK (
        nullif(btrim(crew_lane), '') IS NOT NULL
        AND length(btrim(crew_lane)) <= 24
    );

CREATE INDEX IF NOT EXISTS ix_setup_work_day_task_crew_lane
    ON ops.setup_work_day_task(setup_work_day_id, shift_code, crew_lane, sort_order, setup_session_task_id);

/* Migration 009 exposed the pre-crew-lane scheduling command. The V0.3 command
   supersedes it; do not leave both signatures callable. */
DROP FUNCTION IF EXISTS ops.set_setup_work_day_task(
    text,bigint,bigint,text,integer,integer,boolean
);

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
        ON CONFLICT (setup_work_day_id, setup_session_task_id)
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

REVOKE ALL ON FUNCTION ops.set_setup_work_day_task(text,bigint,bigint,text,text,integer,integer,boolean) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION ops.set_setup_work_day_task(text,bigint,bigint,text,text,integer,integer,boolean) TO fieldwiring_app;

COMMIT;

SELECT
    '2026-09-07-setup-planning-order-crew-lanes-v0.3.1' AS applied_revision,
    current_user AS applied_by;
