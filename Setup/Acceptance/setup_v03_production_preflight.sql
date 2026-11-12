/* ============================================================================
MSB Setup Session V0.3.4 — Production promotion preflight
Issue: #122
Mode: READ ONLY
Revision: 2026-09-07

Purpose:
  Prove the Production database is still at the accepted Setup foundation
  (through 007), that the 2025 historical-verification session is the only Setup
  session, that existing historical operational dates do not violate the new
  session-year rule, and that the durable V0.3.4 promotion can proceed without
  colliding with partial prior installs or duplicate reconstruction tasks.

Promotion boundary after PASS:
  - durable migrations/commands only;
  - 2025 confirmed reconstruction only;
  - no disposable preview seed 012;
  - no fake schedule rows or READY resets;
  - no 2026 Setup Session;
  - no movement/scanning write commands.
============================================================================ */

\set ON_ERROR_STOP on

SELECT current_database() AS database_name,
       current_user AS database_user,
       now() AS checked_at;

DO $preflight$
DECLARE
    v_2025_count integer;
    v_2026_count integer;
    v_stage40 integer;
    v_stage02 integer;
    v_fred_scene_count integer;
    v_mega_scene_count integer;
    v_bad_work_days integer;
    v_bad_planned_dates integer;
    v_bad_actual_starts integer;
    v_bad_actual_completions integer;
    v_bad_movement_times integer;
BEGIN
    IF current_database() <> 'msb' THEN
        RAISE EXCEPTION 'Expected Production database msb; connected to %', current_database();
    END IF;

    SELECT count(*) INTO v_2025_count
    FROM ops.setup_session
    WHERE season_year = 2025
      AND session_status = 'HISTORICAL_VERIFICATION';
    IF v_2025_count <> 1 THEN
        RAISE EXCEPTION 'Expected exactly one 2025 HISTORICAL_VERIFICATION Setup Session; found %', v_2025_count;
    END IF;

    SELECT count(*) INTO v_2026_count
    FROM ops.setup_session
    WHERE season_year = 2026;
    IF v_2026_count <> 0 THEN
        RAISE EXCEPTION '2026 Setup Session already exists; stop before V0.3.4 Production promotion';
    END IF;

    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'fieldwiring_app') THEN
        RAISE EXCEPTION 'Required application role fieldwiring_app is missing';
    END IF;

    /* Fail if Production is in a partial post-007 state. */
    IF EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_schema = 'ref' AND table_name = 'setup_task_resource' AND column_name = 'active_flag'
    ) OR EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_schema = 'ref' AND table_name = 'setup_task' AND column_name = 'lor_scene_id'
    ) OR EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_schema = 'ref' AND table_name = 'setup_task' AND column_name = 'baseline_plan_order'
    ) OR EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_schema = 'ops' AND table_name = 'setup_session_task' AND column_name = 'planned_order'
    ) OR EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_schema = 'ops' AND table_name = 'setup_work_day_task' AND column_name = 'shift_code'
    ) OR EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_schema = 'ops' AND table_name = 'setup_work_day_task' AND column_name = 'crew_lane'
    ) OR to_regprocedure('ref.create_setup_resource(text,text,text,text)') IS NOT NULL
      OR to_regprocedure('ref.set_setup_task_scope(text,bigint,integer,bigint)') IS NOT NULL
      OR to_regprocedure('ops.set_setup_session_task_planned_order(text,bigint,integer,text)') IS NOT NULL
      OR to_regprocedure('ops.enforce_setup_work_day_session_year()') IS NOT NULL
      OR to_regprocedure('ops.enforce_setup_session_task_operational_year()') IS NOT NULL
      OR to_regprocedure('ops.enforce_setup_movement_event_session_year()') IS NOT NULL THEN
        RAISE EXCEPTION 'Production contains one or more post-007 Setup objects. Stop and inventory the partial state before promotion.';
    END IF;

    SELECT stage_id INTO v_stage40
    FROM ref.stage
    WHERE stage_key = '40';
    IF v_stage40 IS NULL THEN
        RAISE EXCEPTION 'Stage 40 CommandCenter is missing';
    END IF;

    SELECT stage_id INTO v_stage02
    FROM ref.stage
    WHERE stage_key = '02';
    IF v_stage02 IS NULL THEN
        RAISE EXCEPTION 'Stage 02 is missing';
    END IF;

    SELECT count(*) INTO v_fred_scene_count
    FROM ref.lor_scene
    WHERE stage_id = v_stage02
      AND scene_name = '02-Fred''s Stars';
    SELECT count(*) INTO v_mega_scene_count
    FROM ref.lor_scene
    WHERE stage_id = v_stage02
      AND scene_name = '02-Mega Tree';
    IF v_fred_scene_count <> 1 OR v_mega_scene_count <> 1 THEN
        RAISE EXCEPTION 'Expected exactly one current Fred''s Stars Scene and one Mega Tree Scene; found Fred %, Mega %',
            v_fred_scene_count, v_mega_scene_count;
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM ref.setup_resource WHERE resource_name = 'Boom Lift'
    ) THEN
        RAISE EXCEPTION 'Boom Lift resource is missing';
    END IF;

    IF EXISTS (
        SELECT 1
        FROM ref.setup_task
        WHERE task_name IN (
            'Install Fred''s Stars',
            'Install Stage 02 Panels',
            'Deliver and Set Up Command Center Trailer',
            'Install WiFi Antenna',
            'Install Gateway and Test Internet Connection',
            'Deploy Hotspots',
            'Remove Street Lights',
            'Convert Street Lights to Show Power',
            'Turn On Site Breakers'
        )
    ) THEN
        RAISE EXCEPTION 'One or more V0.3.4 reconstruction tasks already exist; stop and inventory before promotion';
    END IF;

    /* Existing Production rows must already be compatible with the generic
       Setup-session-year rule before triggers are installed. */
    SELECT count(*) INTO v_bad_work_days
    FROM ops.setup_work_day wd
    JOIN ops.setup_session ss ON ss.setup_session_id = wd.setup_session_id
    WHERE extract(year FROM wd.work_date)::integer <> ss.season_year;

    SELECT count(*) INTO v_bad_planned_dates
    FROM ops.setup_session_task st
    JOIN ops.setup_session ss ON ss.setup_session_id = st.setup_session_id
    WHERE st.planned_date IS NOT NULL
      AND extract(year FROM st.planned_date)::integer <> ss.season_year;

    SELECT count(*) INTO v_bad_actual_starts
    FROM ops.setup_session_task st
    JOIN ops.setup_session ss ON ss.setup_session_id = st.setup_session_id
    WHERE st.actual_started_at IS NOT NULL
      AND extract(year FROM (st.actual_started_at AT TIME ZONE 'America/Chicago'))::integer <> ss.season_year;

    SELECT count(*) INTO v_bad_actual_completions
    FROM ops.setup_session_task st
    JOIN ops.setup_session ss ON ss.setup_session_id = st.setup_session_id
    WHERE st.actual_completed_at IS NOT NULL
      AND extract(year FROM (st.actual_completed_at AT TIME ZONE 'America/Chicago'))::integer <> ss.season_year;

    SELECT count(*) INTO v_bad_movement_times
    FROM ops.setup_movement_event me
    JOIN ops.setup_session ss ON ss.setup_session_id = me.setup_session_id
    WHERE me.occurred_at IS NOT NULL
      AND extract(year FROM (me.occurred_at AT TIME ZONE 'America/Chicago'))::integer <> ss.season_year;

    IF v_bad_work_days <> 0
       OR v_bad_planned_dates <> 0
       OR v_bad_actual_starts <> 0
       OR v_bad_actual_completions <> 0
       OR v_bad_movement_times <> 0 THEN
        RAISE EXCEPTION 'Existing Setup data violates session-year guard: work_days %, planned_dates %, actual_starts %, actual_completions %, movement_times %',
            v_bad_work_days,
            v_bad_planned_dates,
            v_bad_actual_starts,
            v_bad_actual_completions,
            v_bad_movement_times;
    END IF;
END
$preflight$;

SELECT
    ss.setup_session_id,
    ss.season_year,
    ss.session_status,
    (SELECT count(*) FROM ref.setup_task t WHERE t.active_flag) AS active_reusable_tasks,
    (SELECT count(*) FROM ops.setup_session_task st WHERE st.setup_session_id = ss.setup_session_id) AS annual_2025_tasks,
    (SELECT count(*) FROM ops.setup_session_task st WHERE st.setup_session_id = ss.setup_session_id AND st.verification_state = 'UNVERIFIED') AS annual_2025_unverified,
    (SELECT count(*) FROM ops.setup_work_day wd WHERE wd.setup_session_id = ss.setup_session_id) AS existing_work_days,
    (SELECT count(*) FROM ops.setup_movement_event me WHERE me.setup_session_id = ss.setup_session_id) AS existing_movement_events
FROM ops.setup_session ss
WHERE ss.season_year = 2025;

SELECT
    'READY_FOR_CONTROLLED_V034_PROMOTION' AS preflight_status,
    true AS production_backed_2025_review,
    true AS session_year_guard_required,
    true AS future_baseline_admin_only,
    false AS creates_2026_session,
    false AS enables_movement_writes;
