/* ============================================================================
MSB Setup Session V0.3 — Production promotion preflight
Issue: #122
Mode: READ ONLY
Revision: 2026-09-07

Purpose:
  Prove the Production database is still at the accepted Setup foundation
  (through 007), that the 2025 historical-verification session is the only Setup
  session, and that the durable V0.3 promotion can proceed without colliding
  with partial prior installs or duplicate reconstruction tasks.
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
        RAISE EXCEPTION '2026 Setup Session already exists; stop before V0.3 Production promotion';
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
      OR to_regprocedure('ops.set_setup_session_task_planned_order(text,bigint,integer,text)') IS NOT NULL THEN
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
        RAISE EXCEPTION 'One or more V0.3 reconstruction tasks already exist; stop and inventory before promotion';
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
    'READY_FOR_CONTROLLED_V03_PROMOTION' AS preflight_status,
    false AS creates_2026_session,
    false AS enables_movement_writes;
