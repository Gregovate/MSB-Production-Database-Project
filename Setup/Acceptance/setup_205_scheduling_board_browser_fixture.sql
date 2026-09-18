\set ON_ERROR_STOP on

/* ============================================================================
#205 disposable browser fixture — 2026 Scheduling Board

This file is ONLY for run_setup_disposable_browser_preview.ps1.
It intentionally creates a disposable 2026 Setup Session and representative
work-day/task data inside the disposable current-Production clone.

It must never be applied to Production.
============================================================================ */

DO $fixture$
DECLARE
    v_manager_email text;
    v_session_id bigint;
    v_day1 bigint;
    v_day2 bigint;
    v_day3 bigint;
    v_day1_crew_a bigint;
    v_day2_crew_a bigint;
    v_day2_crew_b bigint;
    v_day3_crew_a bigint;
    v_day3_crew_b bigint;
    v_day3_crew_c bigint;
    v_day3_crew_d bigint;
    v_day3_crew_e bigint;
    v_frame bigint;
    v_skins bigint;
    v_lights bigint;
    v_wo372 bigint;
    v_wo156 bigint;
    v_gate372 bigint;
    v_gate156 bigint;
    v_task bigint;
    v_readiness_task bigint;
    v_stage_id integer;
    v_sort integer := 10;
BEGIN
    SELECT lower(u.email)
      INTO v_manager_email
    FROM public.directus_users u
    JOIN ref.person p
      ON p.directus_user_id = u.id
    JOIN LATERAL ref.setup_browser_capabilities(u.email) c ON true
    WHERE u.status = 'active'
      AND c.can_admin_setup
    ORDER BY u.email
    LIMIT 1;

    IF v_manager_email IS NULL THEN
        RAISE EXCEPTION 'Disposable #205 browser fixture requires an active Setup Administrator';
    END IF;

    IF NOT EXISTS (SELECT 1 FROM ref.season WHERE season_year = 2026) THEN
        RAISE EXCEPTION 'Disposable #205 browser fixture requires ref.season 2026';
    END IF;

    IF EXISTS (SELECT 1 FROM ops.setup_session WHERE season_year = 2026) THEN
        RAISE EXCEPTION 'Disposable #205 browser fixture expected no pre-existing 2026 Setup Session';
    END IF;

    SELECT setup_session_id
      INTO v_session_id
    FROM ops.create_setup_session(v_manager_email, 2026, 'PLANNING');

    /* Mark the reusable annual work set READY for board review unless it is
       already complete/deferred. This is disposable presentation state only. */
    UPDATE ops.setup_session_task st
       SET execution_status = 'READY'
     WHERE st.setup_session_id = v_session_id
       AND st.execution_status = 'NOT_READY';

    /* Disposable presentation state: most work is ready so the finder is useful,
       but keep one real readiness-condition example blocked for operator review. */
    UPDATE ops.setup_session_task st
       SET annual_readiness_state = 'READY'
     WHERE st.setup_session_id = v_session_id;

    SELECT st.setup_session_task_id
      INTO v_readiness_task
    FROM ops.setup_session_task st
    WHERE st.setup_session_id = v_session_id
      AND nullif(btrim(st.annual_readiness_note), '') IS NOT NULL
      AND st.task_origin = 'REUSABLE'
    ORDER BY st.planned_order NULLS LAST, st.setup_session_task_id
    LIMIT 1;

    IF v_readiness_task IS NOT NULL THEN
        PERFORM *
        FROM ops.set_setup_annual_task_readiness(
            v_manager_email,
            v_readiness_task,
            false
        );
    END IF;

    SELECT st.setup_session_task_id, st.annual_stage_id
      INTO v_frame, v_stage_id
    FROM ops.setup_session_task st
    WHERE st.setup_session_id = v_session_id
      AND st.annual_task_name = 'Layout / Erect Frame / Strap Down'
    ORDER BY st.setup_session_task_id
    LIMIT 1;

    SELECT st.setup_session_task_id
      INTO v_skins
    FROM ops.setup_session_task st
    WHERE st.setup_session_id = v_session_id
      AND st.annual_stage_id = v_stage_id
      AND st.annual_task_name = 'Install Skins and Bungees'
    ORDER BY st.setup_session_task_id
    LIMIT 1;

    SELECT st.setup_session_task_id
      INTO v_lights
    FROM ops.setup_session_task st
    WHERE st.setup_session_id = v_session_id
      AND st.annual_stage_id = v_stage_id
      AND st.annual_task_name = 'Install Lighting, Cameras, Mats, Signs, and Finish Setup'
    ORDER BY st.setup_session_task_id
    LIMIT 1;

    SELECT wo.work_order_id INTO v_wo372
    FROM ops.work_order wo
    WHERE wo.work_order_id = 372;

    SELECT wo.work_order_id INTO v_wo156
    FROM ops.work_order wo
    WHERE wo.work_order_id = 156;

    IF v_frame IS NULL OR v_skins IS NULL OR v_lights IS NULL THEN
        RAISE EXCEPTION
            'Disposable #205 fixture could not resolve Magic Igloo Frame / Skins / Lighting annual tasks';
    END IF;

    IF v_wo372 IS NULL OR v_wo156 IS NULL THEN
        RAISE EXCEPTION
            'Disposable #205 fixture requires existing Work Orders 372 and 156';
    END IF;

    SELECT setup_session_task_id
      INTO v_gate372
    FROM ops.create_setup_season_task(
        v_manager_email,
        2026,
        '2026 ONLY — Magic Igloo Weld Repairs',
        (SELECT annual_stage_id FROM ops.setup_session_task WHERE setup_session_task_id = v_frame),
        (SELECT annual_lor_scene_id FROM ops.setup_session_task WHERE setup_session_task_id = v_frame),
        'GATE',
        (SELECT planned_order + 1 FROM ops.setup_session_task WHERE setup_session_task_id = v_frame),
        NULL,
        NULL,
        NULL,
        NULL,
        'Work Order 372 completed before skins are installed.',
        'Repair stop after frame erection and before skins.',
        NULL,
        372,
        true,
        'Disposable #205 Magic Igloo annual-only gate proof.'
    );

    SELECT setup_session_task_id
      INTO v_gate156
    FROM ops.create_setup_season_task(
        v_manager_email,
        2026,
        '2026 ONLY — Magic Igloo Manufacturer Skin Repairs',
        (SELECT annual_stage_id FROM ops.setup_session_task WHERE setup_session_task_id = v_skins),
        (SELECT annual_lor_scene_id FROM ops.setup_session_task WHERE setup_session_task_id = v_skins),
        'GATE',
        (SELECT planned_order + 1 FROM ops.setup_session_task WHERE setup_session_task_id = v_skins),
        NULL,
        NULL,
        NULL,
        NULL,
        'Work Order 156 completed before lighting installation continues.',
        'Manufacturer repair stop after skins and before lights.',
        NULL,
        156,
        true,
        'Disposable #205 Magic Igloo annual-only gate proof.'
    );

    PERFORM *
    FROM ops.set_setup_session_task_dependency(
        v_manager_email, v_gate372, v_frame,
        '2026 annual repair gate after frame erection.', true
    );

    PERFORM *
    FROM ops.set_setup_session_task_dependency(
        v_manager_email, v_skins, v_gate372,
        'Skins wait for 2026 weld repair gate.', true
    );

    PERFORM *
    FROM ops.set_setup_session_task_dependency(
        v_manager_email, v_gate156, v_skins,
        '2026 manufacturer repair gate after skin installation.', true
    );

    PERFORM *
    FROM ops.set_setup_session_task_dependency(
        v_manager_email, v_lights, v_gate156,
        'Lighting waits for 2026 manufacturer skin repair gate.', true
    );

    SELECT setup_work_day_id
      INTO v_day1
    FROM ops.upsert_setup_work_day(
        v_manager_email,
        2026,
        DATE '2026-10-05',
        1,
        'PLANNED',
        NULL,
        'Disposable Monday planning proof',
        'Day 1 — early locating/layout work may begin before full park closure.'
    );

    SELECT setup_work_day_id
      INTO v_day2
    FROM ops.upsert_setup_work_day(
        v_manager_email,
        2026,
        DATE '2026-10-06',
        2,
        'PLANNED',
        NULL,
        'Disposable Tuesday planning proof',
        NULL
    );

    SELECT setup_work_day_id
      INTO v_day3
    FROM ops.upsert_setup_work_day(
        v_manager_email,
        2026,
        DATE '2026-10-10',
        3,
        'PLANNED',
        NULL,
        'Saturday usually has stronger volunteer turnout',
        'Day 3 intentionally skips calendar dates; Day Number counts MSB Setup work days.'
    );

    /* Each work day starts with Crew A. Add only the crews needed that day. */
    SELECT setup_work_day_crew_id INTO v_day1_crew_a
    FROM ops.setup_work_day_crew
    WHERE setup_work_day_id = v_day1 AND crew_number = 1;

    SELECT setup_work_day_crew_id INTO v_day2_crew_a
    FROM ops.setup_work_day_crew
    WHERE setup_work_day_id = v_day2 AND crew_number = 1;

    SELECT setup_work_day_crew_id INTO v_day3_crew_a
    FROM ops.setup_work_day_crew
    WHERE setup_work_day_id = v_day3 AND crew_number = 1;

    SELECT setup_work_day_crew_id INTO v_day2_crew_b
    FROM ops.add_setup_work_day_crew(v_manager_email, v_day2);

    SELECT setup_work_day_crew_id INTO v_day3_crew_b
    FROM ops.add_setup_work_day_crew(v_manager_email, v_day3);
    SELECT setup_work_day_crew_id INTO v_day3_crew_c
    FROM ops.add_setup_work_day_crew(v_manager_email, v_day3);
    SELECT setup_work_day_crew_id INTO v_day3_crew_d
    FROM ops.add_setup_work_day_crew(v_manager_email, v_day3);
    SELECT setup_work_day_crew_id INTO v_day3_crew_e
    FROM ops.add_setup_work_day_crew(v_manager_email, v_day3);

    PERFORM * FROM ops.update_setup_work_day_crew(v_manager_email, v_day1_crew_a, 6, 4);
    PERFORM * FROM ops.update_setup_work_day_crew(v_manager_email, v_day2_crew_a, 4, 3);
    PERFORM * FROM ops.update_setup_work_day_crew(v_manager_email, v_day2_crew_b, 3, 5);
    PERFORM * FROM ops.update_setup_work_day_crew(v_manager_email, v_day3_crew_a, 6, 5);

    /* Stack three representative Locate tasks into Day 1 Crew A / Morning. */
    FOR v_task IN
        SELECT st.setup_session_task_id
        FROM ops.setup_session_task st
        WHERE st.setup_session_id = v_session_id
          AND st.task_origin = 'REUSABLE'
          AND st.annual_task_name ILIKE 'Locate%'
          AND st.execution_status NOT IN ('COMPLETE','DEFERRED')
        ORDER BY st.planned_order NULLS LAST, st.setup_session_task_id
        LIMIT 3
    LOOP
        PERFORM *
        FROM ops.create_setup_work_day_assignment(
            v_manager_email,
            v_day1,
            v_task,
            'MORNING',
            v_day1_crew_a,
            v_sort
        );
        v_sort := v_sort + 10;
    END LOOP;

    /* Day 2 has two crews; place one task on Crew B / Afternoon. */
    SELECT st.setup_session_task_id
      INTO v_task
    FROM ops.setup_session_task st
    WHERE st.setup_session_id = v_session_id
      AND st.task_origin = 'REUSABLE'
      AND st.setup_session_task_id NOT IN (
          SELECT wdt.setup_session_task_id
          FROM ops.setup_work_day_task wdt
          WHERE wdt.setup_work_day_id = v_day1
      )
      AND st.execution_status NOT IN ('COMPLETE','DEFERRED')
    ORDER BY st.planned_order NULLS LAST, st.setup_session_task_id
    LIMIT 1;

    IF v_task IS NOT NULL THEN
        PERFORM *
        FROM ops.create_setup_work_day_assignment(
            v_manager_email,
            v_day2,
            v_task,
            'AFTERNOON',
            v_day2_crew_b,
            10
        );
    END IF;

    /* Day 3 intentionally has five available crew lanes but no obligation to use all of them. */

    RAISE NOTICE
        'DISPOSABLE #205 BROWSER FIXTURE READY session=% day1=% day2=% day3=% gate372=% gate156=%',
        v_session_id, v_day1, v_day2, v_day3, v_gate372, v_gate156;
END
$fixture$;

SELECT
    ss.season_year,
    ss.setup_session_id,
    ss.session_status,
    count(DISTINCT st.setup_session_task_id) AS annual_tasks,
    count(DISTINCT wd.setup_work_day_id) AS work_days,
    count(DISTINCT c.setup_work_day_crew_id) AS work_day_crews,
    count(DISTINCT wdt.setup_work_day_task_id) AS assignments
FROM ops.setup_session ss
LEFT JOIN ops.setup_session_task st
  ON st.setup_session_id = ss.setup_session_id
LEFT JOIN ops.setup_work_day wd
  ON wd.setup_session_id = ss.setup_session_id
LEFT JOIN ops.setup_work_day_crew c
  ON c.setup_work_day_id = wd.setup_work_day_id
LEFT JOIN ops.setup_work_day_task wdt
  ON wdt.setup_work_day_id = wd.setup_work_day_id
WHERE ss.season_year = 2026
GROUP BY ss.season_year, ss.setup_session_id, ss.session_status;
