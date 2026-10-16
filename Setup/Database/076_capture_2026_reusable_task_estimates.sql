-- #205 / #122: 2026 Scheduling Board estimate capture.
-- 2026 linked task estimate sync is TWO-WAY: annual -> Catalog via existing
-- governed Planning Info function, Catalog -> annual via guarded trigger.
-- Later seasons do not inherit 2026 synchronization before the 2027 review.
-- Function and trigger migration only; no data backfill.
BEGIN;

DO $preflight$
BEGIN
    IF to_regprocedure('ops.update_setup_scheduling_task_planning_info(text,bigint,integer,integer,integer,text,text,text,text)') IS NULL
       OR to_regclass('ops.setup_session') IS NULL
       OR to_regclass('ops.setup_session_task') IS NULL
       OR to_regclass('ref.setup_task') IS NULL
       OR NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'fieldwiring_app') THEN
        RAISE EXCEPTION 'Existing Setup Planning Info function and annual/reusable schema are required';
    END IF;
END;
$preflight$;

CREATE OR REPLACE FUNCTION ops.update_setup_scheduling_task_planning_info(
    p_email text,
    p_setup_session_task_id bigint,
    p_normal_crew_min integer,
    p_normal_crew_max integer,
    p_expected_duration_minutes integer,
    p_effort_level text,
    p_readiness_note text,
    p_weather_note text,
    p_completion_point text
)
RETURNS TABLE (
    setup_session_task_id bigint,
    task_origin text,
    setup_task_id bigint,
    annual_readiness_state text,
    operator_display_name text
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, ops, ref
AS $function$
DECLARE
    v_directus_user_id uuid;
    v_actor_person_id integer;
    v_display_name text;
    v_setup_task_id bigint;
    v_origin text;
    v_season_year integer;
    v_old_readiness text;
    v_old_weather text;
    v_old_completion text;
    v_has_actual boolean;
    v_new_readiness text := nullif(btrim(p_readiness_note), '');
    v_effort text := upper(nullif(btrim(p_effort_level), ''));
    v_state text;
BEGIN
    SELECT a.directus_user_id, a.person_id, a.display_name
      INTO v_directus_user_id, v_actor_person_id, v_display_name
    FROM ref.setup_management_actor(p_email, false) a;

    IF p_normal_crew_min IS NOT NULL AND p_normal_crew_min < 0
       OR p_normal_crew_max IS NOT NULL AND p_normal_crew_max < 0
       OR (
           p_normal_crew_min IS NOT NULL
           AND p_normal_crew_max IS NOT NULL
           AND p_normal_crew_min > p_normal_crew_max
       ) THEN
        RAISE EXCEPTION USING ERRCODE = '22023',
            MESSAGE = 'Setup crew guidance is invalid';
    END IF;

    IF p_expected_duration_minutes IS NOT NULL AND p_expected_duration_minutes <= 0 THEN
        RAISE EXCEPTION USING ERRCODE = '22023',
            MESSAGE = 'Expected duration must be greater than zero or blank';
    END IF;

    IF v_effort IS NOT NULL AND v_effort NOT IN ('LIGHT','MODERATE','HEAVY') THEN
        RAISE EXCEPTION USING ERRCODE = '22023',
            MESSAGE = 'Setup effort must be LIGHT, MODERATE, HEAVY, or blank';
    END IF;

    SELECT st.setup_task_id,
           st.task_origin,
           ss.season_year,
           st.annual_readiness_note,
           st.annual_weather_note,
           st.annual_completion_point,
           st.annual_readiness_state
      INTO v_setup_task_id, v_origin, v_season_year, v_old_readiness, v_old_weather, v_old_completion, v_state
    FROM ops.setup_session_task st
    JOIN ops.setup_session ss ON ss.setup_session_id = st.setup_session_id
    WHERE st.setup_session_task_id = p_setup_session_task_id;

    IF v_origin IS NULL THEN
        RAISE EXCEPTION USING ERRCODE = 'P0002',
            MESSAGE = 'Annual Setup task was not found';
    END IF;

    v_has_actual := EXISTS (
        SELECT 1 FROM ops.setup_task_progress p
        WHERE p.setup_session_task_id = p_setup_session_task_id
    ) OR EXISTS (
        SELECT 1 FROM ops.setup_session_task st
        WHERE st.setup_session_task_id = p_setup_session_task_id
          AND (st.actual_started_at IS NOT NULL OR st.actual_completed_at IS NOT NULL)
    );
    IF v_has_actual AND NOT (
        v_origin = 'REUSABLE' AND v_season_year = 2026
        AND v_old_readiness IS NOT DISTINCT FROM v_new_readiness
        AND v_old_weather IS NOT DISTINCT FROM nullif(btrim(p_weather_note), '')
        AND v_old_completion IS NOT DISTINCT FROM nullif(btrim(p_completion_point), '')
    ) THEN
        RAISE EXCEPTION USING ERRCODE = '23514',
            MESSAGE = 'Actual work exists; only 2026 reusable task estimates may be revised. Historical readiness and completion evidence is protected.';
    END IF;

    IF v_old_readiness IS DISTINCT FROM v_new_readiness THEN
        v_state := CASE WHEN v_new_readiness IS NULL THEN 'READY' ELSE 'NOT_READY' END;
    END IF;

    PERFORM pg_catalog.set_config('app.directus_user_uuid', v_directus_user_id::text, true);

    IF v_origin = 'REUSABLE' THEN
        -- During 2026, scheduling fills in first-pass reusable task estimates.
        -- Later seasons must not silently promote their evolving estimates
        -- back into the Catalog until the 2027 review establishes that rule.
        -- Catalog readiness/weather/completion fields retain prior behavior.
        UPDATE ref.setup_task t
           SET normal_crew_min = CASE WHEN v_season_year = 2026 THEN p_normal_crew_min ELSE t.normal_crew_min END,
               normal_crew_max = CASE WHEN v_season_year = 2026 THEN p_normal_crew_max ELSE t.normal_crew_max END,
               expected_duration_minutes = CASE WHEN v_season_year = 2026 THEN p_expected_duration_minutes ELSE t.expected_duration_minutes END,
               effort_level = CASE WHEN v_season_year = 2026 THEN v_effort ELSE t.effort_level END,
               readiness_note = CASE WHEN v_has_actual THEN t.readiness_note ELSE v_new_readiness END,
               weather_note = CASE WHEN v_has_actual THEN t.weather_note ELSE nullif(btrim(p_weather_note), '') END,
               completion_point = CASE WHEN v_has_actual THEN t.completion_point ELSE nullif(btrim(p_completion_point), '') END
         WHERE t.setup_task_id = v_setup_task_id;

        IF NOT FOUND THEN
            RAISE EXCEPTION USING ERRCODE = 'P0002',
                MESSAGE = 'Reusable Setup task was not found';
        END IF;
    END IF;

    UPDATE ops.setup_session_task st
       SET annual_normal_crew_min = p_normal_crew_min,
           annual_normal_crew_max = p_normal_crew_max,
           annual_expected_duration_minutes = p_expected_duration_minutes,
           annual_effort_level = v_effort,
           annual_readiness_note = CASE WHEN v_has_actual THEN st.annual_readiness_note ELSE v_new_readiness END,
           annual_readiness_state = v_state,
           annual_weather_note = CASE WHEN v_has_actual THEN st.annual_weather_note ELSE nullif(btrim(p_weather_note), '') END,
           annual_completion_point = CASE WHEN v_has_actual THEN st.annual_completion_point ELSE nullif(btrim(p_completion_point), '') END
     WHERE st.setup_session_task_id = p_setup_session_task_id;

    RETURN QUERY
    SELECT p_setup_session_task_id,
           v_origin,
           v_setup_task_id,
           v_state,
           v_display_name;
END;
$function$;

REVOKE ALL ON FUNCTION ops.update_setup_scheduling_task_planning_info(
    text,bigint,integer,integer,integer,text,text,text,text
) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION ops.update_setup_scheduling_task_planning_info(
    text,bigint,integer,integer,integer,text,text,text,text
) TO fieldwiring_app;

COMMENT ON FUNCTION ops.update_setup_scheduling_task_planning_info(text,bigint,integer,integer,integer,text,text,text,text) IS
    'Manager Planning Info: 2026 reusable-origin task estimates atomically update annual plus Catalog; later annual estimates stay annual until reviewed. Actual history remains protected.';


-- #205 two-way 2026 reconciliation: Catalog -> linked annual planning.
-- Catalog editor and effort command both update ref.setup_task. This single
-- trigger therefore protects both authorized paths, in their SQL transaction.
-- Recorded actual work fields and old-year annual snapshots are untouched.
CREATE OR REPLACE FUNCTION ref.sync_setup_task_estimates_to_2026()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, ref, ops
AS $sync$
DECLARE
    v_session_task_id bigint;
BEGIN
    SELECT st.setup_session_task_id INTO v_session_task_id
    FROM ops.setup_session_task st
    JOIN ops.setup_session ss ON ss.setup_session_id = st.setup_session_id
    WHERE st.setup_task_id = NEW.setup_task_id
      AND st.task_origin = 'REUSABLE'
      AND ss.season_year = 2026
      AND ss.session_status <> 'HISTORICAL_VERIFICATION'
      AND NOT EXISTS (
          SELECT 1 FROM ops.setup_session newer
          WHERE newer.session_status <> 'HISTORICAL_VERIFICATION'
            AND newer.season_year > ss.season_year
      )
    ORDER BY st.setup_session_task_id
    LIMIT 1;

    IF v_session_task_id IS NULL THEN RETURN NEW; END IF;

    -- Only task estimate columns are mirrored. Actual crew, duration,
    -- progress, work dates and reported evidence are deliberately untouched,
    -- even where the 2026 annual task already has a Report Work record.
    -- This temporary 2026 learning contract stops when a newer season exists.

    UPDATE ops.setup_session_task st
       SET annual_normal_crew_min = NEW.normal_crew_min,
           annual_normal_crew_max = NEW.normal_crew_max,
           annual_expected_duration_minutes = NEW.expected_duration_minutes,
           annual_effort_level = NEW.effort_level
     WHERE st.setup_session_task_id = v_session_task_id
       AND (st.annual_normal_crew_min, st.annual_normal_crew_max,
            st.annual_expected_duration_minutes, st.annual_effort_level)
           IS DISTINCT FROM
           (NEW.normal_crew_min, NEW.normal_crew_max,
            NEW.expected_duration_minutes, NEW.effort_level);
    RETURN NEW;
END;
$sync$;

REVOKE ALL ON FUNCTION ref.sync_setup_task_estimates_to_2026() FROM PUBLIC;

DROP TRIGGER IF EXISTS trg_setup_task_sync_2026_planning ON ref.setup_task;
CREATE TRIGGER trg_setup_task_sync_2026_planning
AFTER UPDATE OF normal_crew_min, normal_crew_max,
                expected_duration_minutes, effort_level
ON ref.setup_task
FOR EACH ROW
WHEN (
    (OLD.normal_crew_min, OLD.normal_crew_max,
     OLD.expected_duration_minutes, OLD.effort_level)
      IS DISTINCT FROM
    (NEW.normal_crew_min, NEW.normal_crew_max,
     NEW.expected_duration_minutes, NEW.effort_level)
)
EXECUTE FUNCTION ref.sync_setup_task_estimates_to_2026();

COMMENT ON FUNCTION ref.sync_setup_task_estimates_to_2026() IS
    '2026 only: Catalog estimate changes mirror linked current annual planning in one transaction; preserve task-level actual work and prevent mirroring into later seasons.';

COMMIT;
