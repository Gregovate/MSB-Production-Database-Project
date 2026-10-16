-- #205 / #122 disposable-only validation, after migrations 075 and 076.
-- Use current-Production disposable clone and existing authenticated Manager.
-- NEVER execute against Production. No durable writes; rollback restores the
-- annual task and reusable Catalog row after proving an atomic 2026 dual-save.

CREATE TEMP TABLE setup205_estimate_probe ON COMMIT PRESERVE ROWS AS
SELECT st.setup_session_task_id, st.setup_task_id,
       st.annual_normal_crew_min AS old_annual_min,
       st.annual_normal_crew_max AS old_annual_max,
       st.annual_expected_duration_minutes AS old_annual_minutes,
       st.annual_effort_level AS old_annual_effort,
       t.normal_crew_min AS old_catalog_min,
       t.normal_crew_max AS old_catalog_max,
       t.expected_duration_minutes AS old_catalog_minutes,
       t.effort_level AS old_catalog_effort,
       st.annual_readiness_note, st.annual_weather_note,
       st.annual_completion_point,
       greatest(coalesce(st.annual_normal_crew_min,0),
                coalesce(t.normal_crew_min,0),1) + 1 AS probe_min,
       greatest(coalesce(st.annual_normal_crew_max,0),
                coalesce(t.normal_crew_max,0),
                coalesce(st.annual_normal_crew_min,0),
                coalesce(t.normal_crew_min,0),1) + 2 AS probe_max,
       greatest(coalesce(st.annual_expected_duration_minutes,0),
                coalesce(t.expected_duration_minutes,0),60) + 15 AS probe_minutes,
       CASE WHEN st.annual_effort_level = 'LIGHT' THEN 'MODERATE'
            ELSE 'LIGHT' END AS probe_effort
FROM ops.setup_session_task st
JOIN ops.setup_session ss ON ss.setup_session_id = st.setup_session_id
JOIN ref.setup_task t ON t.setup_task_id = st.setup_task_id
WHERE ss.season_year = 2026
  AND st.task_origin = 'REUSABLE'
  AND st.setup_task_id IS NOT NULL
  AND st.actual_started_at IS NULL
  AND st.actual_completed_at IS NULL
  AND NOT EXISTS (
      SELECT 1 FROM ops.setup_task_progress p
      WHERE p.setup_session_task_id = st.setup_session_task_id
  )
ORDER BY st.setup_session_task_id
LIMIT 1;

DO $preflight$
BEGIN
    IF (SELECT count(*) FROM setup205_estimate_probe) <> 1 THEN
        RAISE EXCEPTION 'No 2026 reusable annual task without actual history exists for disposable estimate validation';
    END IF;
END;
$preflight$;

BEGIN;

DO $validate$
DECLARE
    v record;
    saved record;
    a record;
    c record;
BEGIN
    SELECT * INTO STRICT v FROM setup205_estimate_probe;

    SELECT * INTO STRICT saved
    FROM ops.update_setup_scheduling_task_planning_info(
        'gliebig@sheboyganlights.org',
        v.setup_session_task_id,
        v.probe_min, v.probe_max, v.probe_minutes, v.probe_effort,
        v.annual_readiness_note, v.annual_weather_note,
        v.annual_completion_point
    );
    IF saved.task_origin <> 'REUSABLE' OR saved.setup_task_id <> v.setup_task_id THEN
        RAISE EXCEPTION '2026 Planning Info changed identity or did not return linked reusable task';
    END IF;

    SELECT annual_normal_crew_min AS crew_min,
           annual_normal_crew_max AS crew_max,
           annual_expected_duration_minutes AS duration_minutes,
           annual_effort_level AS effort_level
      INTO STRICT a
    FROM ops.setup_session_task
    WHERE setup_session_task_id = v.setup_session_task_id;

    SELECT normal_crew_min AS crew_min, normal_crew_max AS crew_max,
           expected_duration_minutes AS duration_minutes, effort_level
      INTO STRICT c
    FROM ref.setup_task
    WHERE setup_task_id = v.setup_task_id;

    IF a.crew_min IS DISTINCT FROM v.probe_min
       OR a.crew_max IS DISTINCT FROM v.probe_max
       OR a.duration_minutes IS DISTINCT FROM v.probe_minutes
       OR a.effort_level IS DISTINCT FROM v.probe_effort THEN
        RAISE EXCEPTION '2026 annual task estimates were not saved correctly';
    END IF;
    IF c.crew_min IS DISTINCT FROM a.crew_min
       OR c.crew_max IS DISTINCT FROM a.crew_max
       OR c.duration_minutes IS DISTINCT FROM a.duration_minutes
       OR c.effort_level IS DISTINCT FROM a.effort_level THEN
        RAISE EXCEPTION '2026 Catalog estimates did not match annual Planning Info within the same transaction';
    END IF;

    RAISE NOTICE 'PASS: 2026 reusable annual plus Catalog estimates saved atomically for task %', v.setup_session_task_id;
END;
$validate$;

ROLLBACK;

DO $rollback_check$
DECLARE
    v record;
BEGIN
    SELECT * INTO STRICT v FROM setup205_estimate_probe;
    IF EXISTS (
        SELECT 1 FROM ops.setup_session_task st
        WHERE st.setup_session_task_id = v.setup_session_task_id
          AND (st.annual_normal_crew_min IS DISTINCT FROM v.old_annual_min
           OR st.annual_normal_crew_max IS DISTINCT FROM v.old_annual_max
           OR st.annual_expected_duration_minutes IS DISTINCT FROM v.old_annual_minutes
           OR st.annual_effort_level IS DISTINCT FROM v.old_annual_effort)
    ) OR EXISTS (
        SELECT 1 FROM ref.setup_task t
        WHERE t.setup_task_id = v.setup_task_id
          AND (t.normal_crew_min IS DISTINCT FROM v.old_catalog_min
           OR t.normal_crew_max IS DISTINCT FROM v.old_catalog_max
           OR t.expected_duration_minutes IS DISTINCT FROM v.old_catalog_minutes
           OR t.effort_level IS DISTINCT FROM v.old_catalog_effort)
    ) THEN
        RAISE EXCEPTION '2026 dual-save test was not rolled back';
    END IF;
    RAISE NOTICE 'PASS: 2026 annual and Catalog values unchanged after disposable rollback';
END;
$rollback_check$;

DROP TABLE setup205_estimate_probe;
