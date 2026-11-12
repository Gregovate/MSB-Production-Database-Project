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


-- Second direction: a governed Catalog edit must immediately mirror the linked
-- current 2026 annual task. Both the Catalog and annual writes are in the
-- existing single disposable validation transaction and will be ROLLED BACK.
DO $catalog_to_annual$
DECLARE
    v record;
    v_catalog_row record;
    expected_min integer;
    expected_max integer;
    expected_minutes integer;
    expected_effort text;
    a record;
BEGIN
    SELECT * INTO STRICT v FROM setup205_estimate_probe;
    SELECT * INTO STRICT v_catalog_row
    FROM ref.setup_task
    WHERE setup_task_id = v.setup_task_id;

    expected_min := v.probe_min + 1;
    expected_max := greatest(v.probe_max, expected_min);
    expected_minutes := v.probe_minutes + 30;
    expected_effort := CASE WHEN v.probe_effort = 'HEAVY' THEN 'MODERATE' ELSE 'HEAVY' END;

    -- Existing Manager command; do not use direct table UPDATE as substitute.
    PERFORM ref.update_setup_task(
        'gliebig@sheboyganlights.org',
        v.setup_task_id,
        v_catalog_row.task_name,
        v_catalog_row.stage_id,
        v_catalog_row.task_action_type,
        v_catalog_row.display_order,
        v_catalog_row.active_flag,
        expected_min,
        expected_max,
        expected_minutes,
        v_catalog_row.completion_point,
        v_catalog_row.readiness_note,
        v_catalog_row.weather_note,
        v_catalog_row.reusable_notes
    );
    -- The reusable Catalog effort is a separate governed command; its update
    -- must also mirror 2026 annual effort within that command transaction.
    PERFORM ref.set_setup_task_effort(
        'gliebig@sheboyganlights.org',
        v.setup_task_id, expected_effort
    );

    SELECT annual_normal_crew_min, annual_normal_crew_max,
           annual_expected_duration_minutes, annual_effort_level
      INTO STRICT a
    FROM ops.setup_session_task
    WHERE setup_session_task_id = v.setup_session_task_id;
    IF a.annual_normal_crew_min IS DISTINCT FROM expected_min
       OR a.annual_normal_crew_max IS DISTINCT FROM expected_max
       OR a.annual_expected_duration_minutes IS DISTINCT FROM expected_minutes
       OR a.annual_effort_level IS DISTINCT FROM expected_effort THEN
        RAISE EXCEPTION 'Catalog edit did not synchronize ALL four 2026 annual estimate fields';
    END IF;
    RAISE NOTICE 'PASS: Catalog min/max/duration/effort updated matching 2026 annual estimates';
END;
$catalog_to_annual$;

-- Same disposable transaction: prove bidirectional estimate learning remains
-- available AFTER Report Work, without touching the reported actual records.
DO $reported_2026$
DECLARE
    v record;
    c record;
    a record;
    original_assignments jsonb;
    original_progress jsonb;
    after_assignments jsonb;
    after_progress jsonb;
    new_min integer;
    new_max integer;
    new_minutes integer;
    new_effort text;
BEGIN
    SELECT st.setup_session_task_id, st.setup_task_id,
           st.annual_readiness_note, st.annual_weather_note,
           st.annual_completion_point,
           t.task_name, t.stage_id, t.task_action_type,
           t.display_order, t.active_flag,
           t.normal_crew_min AS catalog_min, t.normal_crew_max AS catalog_max,
           t.expected_duration_minutes AS catalog_minutes, t.effort_level AS catalog_effort,
           t.completion_point AS catalog_completion, t.readiness_note AS catalog_readiness,
           t.weather_note AS catalog_weather, t.reusable_notes AS catalog_notes
    INTO v
    FROM ops.setup_session_task st
    JOIN ops.setup_session ss ON ss.setup_session_id = st.setup_session_id
    JOIN ref.setup_task t ON t.setup_task_id = st.setup_task_id
    WHERE ss.season_year = 2026 AND st.task_origin = 'REUSABLE'
      AND (st.actual_started_at IS NOT NULL OR st.actual_completed_at IS NOT NULL
        OR EXISTS (SELECT 1 FROM ops.setup_task_progress p
                   WHERE p.setup_session_task_id = st.setup_session_task_id))
    ORDER BY st.setup_session_task_id LIMIT 1;
    IF v.setup_session_task_id IS NULL THEN
        RAISE EXCEPTION 'No reported 2026 reusable task: history-safe two-way sync cannot be certified';
    END IF;

    SELECT coalesce(jsonb_agg(to_jsonb(wdt) ORDER BY wdt.setup_work_day_task_id), '[]'::jsonb)
    INTO original_assignments
    FROM ops.setup_work_day_task wdt WHERE wdt.setup_session_task_id = v.setup_session_task_id;
    SELECT coalesce(jsonb_agg(to_jsonb(p) ORDER BY to_jsonb(p)::text), '[]'::jsonb)
    INTO original_progress
    FROM ops.setup_task_progress p WHERE p.setup_session_task_id = v.setup_session_task_id;

    new_min := greatest(coalesce(v.catalog_min,0),1) + 1;
    new_max := greatest(coalesce(v.catalog_max,0),new_min) + 1;
    new_minutes := greatest(coalesce(v.catalog_minutes,0),60) + 15;
    new_effort := CASE WHEN v.catalog_effort = 'LIGHT' THEN 'MODERATE' ELSE 'LIGHT' END;

    -- Catalog -> reported 2026 annual. Both governed Catalog calls execute
    -- in this one rollback-protected transaction.
    PERFORM ref.update_setup_task(
        'gliebig@sheboyganlights.org', v.setup_task_id,
        v.task_name, v.stage_id, v.task_action_type,
        v.display_order, v.active_flag,
        new_min, new_max, new_minutes,
        v.catalog_completion, v.catalog_readiness, v.catalog_weather, v.catalog_notes
    );
    PERFORM ref.set_setup_task_effort(
        'gliebig@sheboyganlights.org',v.setup_task_id,new_effort
    );
    SELECT annual_normal_crew_min AS crew_min, annual_normal_crew_max AS crew_max,
           annual_expected_duration_minutes AS minutes, annual_effort_level AS effort
    INTO STRICT a
    FROM ops.setup_session_task WHERE setup_session_task_id = v.setup_session_task_id;
    IF a.crew_min IS DISTINCT FROM new_min OR a.crew_max IS DISTINCT FROM new_max
       OR a.minutes IS DISTINCT FROM new_minutes OR a.effort IS DISTINCT FROM new_effort THEN
        RAISE EXCEPTION 'Catalog-to-annual estimate mirror failed on reported 2026 task';
    END IF;

    -- Annual -> Catalog after actual work: estimates-only; no historical
    -- readiness/weather/completion changes or Report Work changes.
    new_min := new_min + 1;
    new_max := greatest(new_max,new_min) + 1;
    new_minutes := new_minutes + 15;
    PERFORM ops.update_setup_scheduling_task_planning_info(
        'gliebig@sheboyganlights.org',v.setup_session_task_id,
        new_min,new_max,new_minutes,new_effort,
        v.annual_readiness_note,v.annual_weather_note,v.annual_completion_point
    );
    SELECT normal_crew_min AS crew_min, normal_crew_max AS crew_max,
           expected_duration_minutes AS minutes, effort_level AS effort
    INTO STRICT c FROM ref.setup_task WHERE setup_task_id = v.setup_task_id;
    IF c.crew_min IS DISTINCT FROM new_min OR c.crew_max IS DISTINCT FROM new_max
       OR c.minutes IS DISTINCT FROM new_minutes OR c.effort IS DISTINCT FROM new_effort THEN
        RAISE EXCEPTION 'Annual-to-Catalog estimate mirror failed on reported 2026 task';
    END IF;

    SELECT coalesce(jsonb_agg(to_jsonb(wdt) ORDER BY wdt.setup_work_day_task_id), '[]'::jsonb)
    INTO after_assignments
    FROM ops.setup_work_day_task wdt WHERE wdt.setup_session_task_id = v.setup_session_task_id;
    SELECT coalesce(jsonb_agg(to_jsonb(p) ORDER BY to_jsonb(p)::text), '[]'::jsonb)
    INTO after_progress
    FROM ops.setup_task_progress p WHERE p.setup_session_task_id = v.setup_session_task_id;
    IF after_assignments IS DISTINCT FROM original_assignments
       OR after_progress IS DISTINCT FROM original_progress THEN
        RAISE EXCEPTION '2026 estimate sync modified reported assignment or progress history';
    END IF;

    -- Attempted non-estimate history change MUST still fail.
    BEGIN
        PERFORM ops.update_setup_scheduling_task_planning_info(
            'gliebig@sheboyganlights.org',v.setup_session_task_id,
            new_min,new_max,new_minutes,new_effort,
            coalesce(v.annual_readiness_note,'') || ' unauthorized history edit',
            v.annual_weather_note,v.annual_completion_point
        );
        RAISE EXCEPTION 'Unexpected acceptance of reported readiness-history edit';
    EXCEPTION WHEN check_violation THEN
        RAISE NOTICE 'PASS: reported task readiness remains locked';
    END;
    RAISE NOTICE 'PASS: reported 2026 annual/Catalog estimate changes synchronized both directions with actual unchanged';
END;
$reported_2026$;

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
