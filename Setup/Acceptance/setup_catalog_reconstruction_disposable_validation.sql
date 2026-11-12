\set ON_ERROR_STOP on

DO $validation$
DECLARE
    v_active_count integer;
    v_new_annual_count integer;
BEGIN
    IF NOT EXISTS (
        SELECT 1
        FROM information_schema.columns
        WHERE table_schema = 'ref'
          AND table_name = 'setup_task'
          AND column_name = 'effort_level'
    ) THEN
        RAISE EXCEPTION 'effort_level column is missing';
    END IF;

    IF NOT has_function_privilege(
        'fieldwiring_app',
        'ref.set_setup_task_effort(text,bigint,text)',
        'EXECUTE'
    ) THEN
        RAISE EXCEPTION 'fieldwiring_app cannot execute governed effort editor';
    END IF;

    IF has_table_privilege('fieldwiring_app', 'ref.setup_task', 'UPDATE') THEN
        RAISE EXCEPTION 'fieldwiring_app unexpectedly has broad ref.setup_task UPDATE';
    END IF;

    SELECT count(*) INTO v_active_count
    FROM ref.setup_task
    WHERE active_flag;

    IF v_active_count <> 185 THEN
        RAISE EXCEPTION 'Expected 185 active reusable Setup tasks, found %', v_active_count;
    END IF;

    IF EXISTS (
        SELECT 1
        FROM ref.setup_task
        WHERE setup_task_id IN (40, 58)
          AND active_flag
    ) THEN
        RAISE EXCEPTION 'Provisional tasks 40/58 are still active';
    END IF;

    IF NOT EXISTS (
        SELECT 1
        FROM ref.setup_task
        WHERE setup_task_id = 51
          AND active_flag
          AND task_name = 'Deliver and Set Up Command Center Trailer'
    ) THEN
        RAISE EXCEPTION 'Accepted Command Center task 51 was not preserved';
    END IF;

    IF (
        SELECT count(*)
        FROM ref.setup_task
        WHERE active_flag
          AND task_name = 'Locate Power & Network'
    ) <> 10 THEN
        RAISE EXCEPTION 'Expected 10 normalized Locate Power & Network tasks';
    END IF;

    IF (
        SELECT count(*)
        FROM ref.setup_task
        WHERE active_flag
          AND task_name = 'Layout Panels'
    ) <> 4 THEN
        RAISE EXCEPTION 'Expected 4 normalized Layout Panels tasks';
    END IF;

    IF EXISTS (
        SELECT 1
        FROM ref.setup_task
        WHERE active_flag
          AND (
              task_name IN (
                  'Locate Underground Network and Power',
                  'Locate underground network and power',
                  'Locate Power and Network',
                  'Locates',
                  'Locates / Field Cleared',
                  'Winter Wonderland Locate Power & Network',
                  'Winter Wonderland Layout Panels',
                  'Lay out Frying Santa panels',
                  'Lay out Santa''s Station panel locations',
                  'Panel-location marking'
              )
              OR task_name ILIKE '%Quarry%'
          )
    ) THEN
        RAISE EXCEPTION 'Legacy locate/layout/Quarry naming remains active';
    END IF;

    IF EXISTS (
        SELECT 1
        FROM ref.setup_task
        WHERE active_flag
          AND task_name IN (
              'Deliver Horse & Sleigh to park',
              'Bring Frosty to park',
              'Deliver boxes for inside Santa''s Station',
              'OMW locating/fix',
              'OMW network locating',
              'Finish OMW panels',
              'Panel-location marking',
              'Lay cords - multiple areas'
          )
    ) THEN
        RAISE EXCEPTION 'Aggregate/continuation/pure-logistics evidence leaked into reusable catalog';
    END IF;

    IF (
        SELECT count(*)
        FROM ref.setup_task
        WHERE active_flag
          AND effort_level = 'LIGHT'
    ) <> 8 THEN
        RAISE EXCEPTION 'Expected 8 LIGHT effort tasks';
    END IF;

    IF (
        SELECT count(*)
        FROM ref.setup_task
        WHERE active_flag
          AND effort_level = 'MODERATE'
    ) <> 12 THEN
        RAISE EXCEPTION 'Expected 12 MODERATE effort tasks';
    END IF;

    IF (
        SELECT count(*)
        FROM ref.setup_task
        WHERE active_flag
          AND effort_level = 'HEAVY'
    ) <> 4 THEN
        RAISE EXCEPTION 'Expected 4 HEAVY effort tasks';
    END IF;

    IF (
        SELECT count(*)
        FROM ref.setup_task
        WHERE active_flag
          AND effort_level IS NULL
    ) <> 161 THEN
        RAISE EXCEPTION 'Expected 161 reusable tasks with effort not yet reviewed';
    END IF;

    IF EXISTS (
        SELECT 1
        FROM ref.setup_task t
        LEFT JOIN ref.lor_scene ls
          ON ls.lor_scene_id = t.lor_scene_id
         AND ls.stage_id = t.stage_id
        WHERE t.active_flag
          AND t.lor_scene_id IS NOT NULL
          AND ls.lor_scene_id IS NULL
    ) THEN
        RAISE EXCEPTION 'Active reusable task has invalid Stage/Scene pairing';
    END IF;

    IF (SELECT count(*) FROM ref.setup_task_dependency) <> 0 THEN
        RAISE EXCEPTION 'Dependencies are not empty before the reviewed predecessor pass';
    END IF;

    SELECT count(*) INTO v_new_annual_count
    FROM ops.setup_session_task
    WHERE setup_task_id > 69;

    IF v_new_annual_count <> 0 THEN
        RAISE EXCEPTION 'Reconstruction fabricated annual 2025 rows for newly created reusable tasks';
    END IF;

    IF EXISTS (
        SELECT 1
        FROM ops.setup_session_task st
        JOIN ops.setup_session ss
          ON ss.setup_session_id = st.setup_session_id
        WHERE st.setup_task_id IN (40, 58)
          AND ss.session_status = 'HISTORICAL_VERIFICATION'
          AND st.included_flag
    ) THEN
        RAISE EXCEPTION 'Retired provisional tasks remain included in historical review';
    END IF;

    IF EXISTS (SELECT 1 FROM ops.setup_session WHERE season_year >= 2026) THEN
        RAISE EXCEPTION 'A 2026-or-later Setup Session exists during reconstruction acceptance';
    END IF;

    RAISE NOTICE 'SETUP_CATALOG_RECONSTRUCTION_VALIDATION_PASS active=%', v_active_count;
END
$validation$;

SELECT
    count(*) AS active_tasks,
    count(*) FILTER (WHERE effort_level = 'LIGHT') AS light_tasks,
    count(*) FILTER (WHERE effort_level = 'MODERATE') AS moderate_tasks,
    count(*) FILTER (WHERE effort_level = 'HEAVY') AS heavy_tasks,
    count(*) FILTER (WHERE effort_level IS NULL) AS effort_unreviewed
FROM ref.setup_task
WHERE active_flag;

SELECT
    t.baseline_plan_order,
    s.stage_key,
    s.stage_name,
    ls.scene_name,
    t.setup_task_id,
    t.task_name,
    t.task_action_type,
    t.display_order,
    t.effort_level
FROM ref.setup_task t
LEFT JOIN ref.stage s
  ON s.stage_id = t.stage_id
LEFT JOIN ref.lor_scene ls
  ON ls.lor_scene_id = t.lor_scene_id
WHERE t.active_flag
ORDER BY t.baseline_plan_order, t.setup_task_id;

SELECT 'SETUP_CATALOG_RECONSTRUCTION_VALIDATION_PASS' AS validation_status;
