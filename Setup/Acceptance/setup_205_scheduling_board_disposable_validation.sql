\set ON_ERROR_STOP on

BEGIN;

DO $validation$
DECLARE
    v_admin_email text;
    v_year integer;
    v_session_id bigint;
    v_task_a bigint;
    v_task_b bigint;
    v_gate bigint;
    v_work_order_id bigint;
    v_day1 bigint;
    v_day2 bigint;
    v_day1_number integer;
    v_day2_number integer;
    v_a_morning bigint;
    v_a_afternoon bigint;
    v_b_stack bigint;
    v_continuation bigint;
    v_progress_id bigint;
    v_cycle_blocked boolean := false;
    v_bad_lane_blocked boolean := false;
    v_move_locked boolean := false;
    v_remove_locked boolean := false;
    v_season_name text := '[DISPOSABLE #205] Annual Work Order Gate';
    v_count integer;
BEGIN
    SELECT lower(u.email)
      INTO v_admin_email
    FROM public.directus_users u
    JOIN ref.person p
      ON p.directus_user_id = u.id
    JOIN LATERAL ref.setup_browser_capabilities(u.email) c ON true
    WHERE u.status = 'active'
      AND c.can_admin_setup
    ORDER BY u.email
    LIMIT 1;

    IF v_admin_email IS NULL THEN
        RAISE EXCEPTION 'No active Setup Administrator with ref.person mapping was found in cloned Production data';
    END IF;

    SELECT s.season_year
      INTO v_year
    FROM ref.season s
    WHERE NOT EXISTS (
        SELECT 1
        FROM ops.setup_session ss
        WHERE ss.season_year = s.season_year
    )
      AND s.season_year >= 2026
    ORDER BY s.season_year
    LIMIT 1;

    IF v_year IS NULL THEN
        RAISE EXCEPTION 'No season without a Setup Session is available for disposable #205 validation';
    END IF;

    IF NOT has_function_privilege(
        'fieldwiring_app',
        'ops.create_setup_season_task(text,integer,text,integer,bigint,text,integer,integer,integer,integer,text,text,text,bigint,boolean,text)',
        'EXECUTE'
    ) OR NOT has_function_privilege(
        'fieldwiring_app',
        'ops.create_setup_work_day_assignment(text,bigint,bigint,text,text,integer,integer)',
        'EXECUTE'
    ) OR NOT has_function_privilege(
        'fieldwiring_app',
        'ops.update_setup_work_day_assignment(text,bigint,bigint,text,text,integer,integer)',
        'EXECUTE'
    ) OR NOT has_function_privilege(
        'fieldwiring_app',
        'ops.remove_setup_work_day_assignment(text,bigint)',
        'EXECUTE'
    ) THEN
        RAISE EXCEPTION 'fieldwiring_app lacks one or more governed #205 commands';
    END IF;

    IF has_table_privilege('fieldwiring_app', 'ops.setup_work_day_task', 'INSERT')
       OR has_table_privilege('fieldwiring_app', 'ops.setup_work_day_task', 'UPDATE')
       OR has_table_privilege('fieldwiring_app', 'ops.setup_work_day_task', 'DELETE')
       OR has_table_privilege('fieldwiring_app', 'ops.setup_session_task_dependency', 'INSERT')
       OR has_table_privilege('fieldwiring_app', 'ops.setup_session_task_dependency', 'UPDATE')
       OR has_table_privilege('fieldwiring_app', 'ops.setup_session_task_dependency', 'DELETE') THEN
        RAISE EXCEPTION 'fieldwiring_app unexpectedly has broad #205 table DML';
    END IF;

    SELECT setup_session_id
      INTO v_session_id
    FROM ops.create_setup_session(v_admin_email, v_year, 'PLANNING');

    SELECT st.setup_session_task_id
      INTO v_task_a
    FROM ops.setup_session_task st
    WHERE st.setup_session_id = v_session_id
      AND st.task_origin = 'REUSABLE'
    ORDER BY st.planned_order NULLS LAST, st.setup_session_task_id
    LIMIT 1;

    SELECT st.setup_session_task_id
      INTO v_task_b
    FROM ops.setup_session_task st
    WHERE st.setup_session_id = v_session_id
      AND st.task_origin = 'REUSABLE'
      AND st.setup_session_task_id <> v_task_a
    ORDER BY st.planned_order NULLS LAST, st.setup_session_task_id
    LIMIT 1;

    IF v_task_a IS NULL OR v_task_b IS NULL THEN
        RAISE EXCEPTION 'Disposable annual session did not seed at least two reusable task snapshots';
    END IF;

    IF EXISTS (
        SELECT 1
        FROM ops.setup_session_task st
        WHERE st.setup_session_id = v_session_id
          AND st.task_origin = 'REUSABLE'
          AND (
              st.setup_task_id IS NULL
              OR nullif(btrim(st.annual_task_name), '') IS NULL
              OR st.annual_task_action_type IS NULL
          )
    ) THEN
        RAISE EXCEPTION 'Reusable annual snapshot fields were not populated';
    END IF;

    SELECT min(wo.work_order_id)
      INTO v_work_order_id
    FROM ops.work_order wo;

    IF v_work_order_id IS NULL THEN
        RAISE EXCEPTION 'No existing Work Order is available for disposable annual gate validation';
    END IF;

    SELECT setup_session_task_id
      INTO v_gate
    FROM ops.create_setup_season_task(
        v_admin_email,
        v_year,
        v_season_name,
        NULL,
        NULL,
        'GATE',
        25,
        NULL,
        NULL,
        NULL,
        'Existing Work Order must be complete before downstream Setup continues.',
        'Annual repair hold.',
        NULL,
        v_work_order_id,
        true,
        'Disposable #205 Work Order gate validation.'
    );

    IF NOT EXISTS (
        SELECT 1
        FROM ops.setup_session_task st
        WHERE st.setup_session_task_id = v_gate
          AND st.setup_task_id IS NULL
          AND st.task_origin = 'SEASON_ONLY'
          AND st.linked_work_order_id = v_work_order_id
          AND st.linked_work_order_gate
    ) THEN
        RAISE EXCEPTION 'Season-only Work Order gate did not persist correctly';
    END IF;

    IF EXISTS (
        SELECT 1
        FROM ref.setup_task t
        WHERE t.task_name = v_season_name
    ) THEN
        RAISE EXCEPTION 'Season-only annual task polluted the Reusable Task Catalog';
    END IF;

    PERFORM *
    FROM ops.set_setup_session_task_dependency(
        v_admin_email,
        v_gate,
        v_task_a,
        'Disposable annual gate waits for prior Setup step.',
        true
    );

    PERFORM *
    FROM ops.set_setup_session_task_dependency(
        v_admin_email,
        v_task_b,
        v_gate,
        'Disposable downstream task waits for annual gate.',
        true
    );

    BEGIN
        PERFORM *
        FROM ops.set_setup_session_task_dependency(
            v_admin_email,
            v_gate,
            v_task_b,
            'Must fail as a cycle.',
            true
        );
    EXCEPTION
        WHEN check_violation THEN
            v_cycle_blocked := true;
    END;

    IF NOT v_cycle_blocked THEN
        RAISE EXCEPTION 'Annual dependency cycle was unexpectedly accepted';
    END IF;

    SELECT setup_work_day_id, setup_day_number
      INTO v_day1, v_day1_number
    FROM ops.upsert_setup_work_day(
        v_admin_email,
        v_year,
        make_date(v_year, 10, 5),
        1,
        'PLANNED',
        NULL,
        'Disposable day 1',
        'Disposable #205 validation'
    );

    SELECT setup_work_day_id, setup_day_number
      INTO v_day2, v_day2_number
    FROM ops.upsert_setup_work_day(
        v_admin_email,
        v_year,
        make_date(v_year, 10, 6),
        2,
        'PLANNED',
        NULL,
        'Disposable day 2',
        'Disposable #205 validation'
    );

    IF v_day1_number <> 1 OR v_day2_number <> 2 THEN
        RAISE EXCEPTION 'Setup Day Number did not persist';
    END IF;

    IF upper(to_char(make_date(v_year, 10, 5), 'Dy')) IS NULL THEN
        RAISE EXCEPTION 'DOW derivation failed unexpectedly';
    END IF;

    SELECT setup_work_day_task_id
      INTO v_a_morning
    FROM ops.create_setup_work_day_assignment(
        v_admin_email, v_day1, v_task_a, 'MORNING', 'D', 10, 4
    );

    SELECT setup_work_day_task_id
      INTO v_a_afternoon
    FROM ops.create_setup_work_day_assignment(
        v_admin_email, v_day1, v_task_a, 'AFTERNOON', 'D', 10, 4
    );

    SELECT setup_work_day_task_id
      INTO v_b_stack
    FROM ops.create_setup_work_day_assignment(
        v_admin_email, v_day1, v_task_b, 'MORNING', 'D', 20, 3
    );

    IF (
        SELECT count(*)
        FROM ops.setup_work_day_task wdt
        WHERE wdt.setup_work_day_id = v_day1
          AND wdt.setup_session_task_id = v_task_a
    ) <> 2 THEN
        RAISE EXCEPTION 'Same annual task could not occupy distinct Morning/Afternoon assignments';
    END IF;

    IF (
        SELECT count(*)
        FROM ops.setup_work_day_task wdt
        WHERE wdt.setup_work_day_id = v_day1
          AND wdt.shift_code = 'MORNING'
          AND wdt.crew_lane = 'D'
    ) < 2 THEN
        RAISE EXCEPTION 'Stacked tasks in one crew/shift were not preserved';
    END IF;

    BEGIN
        PERFORM *
        FROM ops.create_setup_work_day_assignment(
            v_admin_email, v_day2, v_task_b, 'MORNING', 'E', 10, 3
        );
    EXCEPTION
        WHEN invalid_parameter_value THEN
            v_bad_lane_blocked := true;
    END;

    IF NOT v_bad_lane_blocked THEN
        RAISE EXCEPTION 'Unsupported Crew E lane was unexpectedly accepted';
    END IF;

    PERFORM *
    FROM ops.update_setup_work_day_assignment(
        v_admin_email,
        v_b_stack,
        v_day2,
        'MORNING',
        'C',
        10,
        3
    );

    IF NOT EXISTS (
        SELECT 1
        FROM ops.setup_work_day_task
        WHERE setup_work_day_task_id = v_b_stack
          AND setup_work_day_id = v_day2
          AND shift_code = 'MORNING'
          AND crew_lane = 'C'
    ) THEN
        RAISE EXCEPTION 'Future unworked assignment did not move';
    END IF;

    PERFORM * FROM ops.remove_setup_work_day_assignment(v_admin_email, v_b_stack);

    IF EXISTS (
        SELECT 1 FROM ops.setup_work_day_task WHERE setup_work_day_task_id = v_b_stack
    ) THEN
        RAISE EXCEPTION 'Future unworked assignment did not remove';
    END IF;

    SELECT setup_task_progress_id
      INTO v_progress_id
    FROM ops.record_setup_task_progress(
        v_admin_email,
        v_task_a,
        v_day1,
        'MORNING',
        4,
        NULL,
        NULL,
        'Disposable actual work creates historical stickiness.',
        false
    );

    IF NOT EXISTS (
        SELECT 1
        FROM ops.setup_task_progress p
        WHERE p.setup_task_progress_id = v_progress_id
          AND p.setup_work_day_task_id = v_a_morning
    ) THEN
        RAISE EXCEPTION 'Progress did not retain exact scheduled-assignment identity';
    END IF;

    BEGIN
        PERFORM *
        FROM ops.update_setup_work_day_assignment(
            v_admin_email,
            v_a_morning,
            v_day2,
            'MORNING',
            'A',
            10,
            4
        );
    EXCEPTION
        WHEN check_violation THEN
            v_move_locked := true;
    END;

    BEGIN
        PERFORM *
        FROM ops.remove_setup_work_day_assignment(v_admin_email, v_a_morning);
    EXCEPTION
        WHEN check_violation THEN
            v_remove_locked := true;
    END;

    IF NOT v_move_locked OR NOT v_remove_locked THEN
        RAISE EXCEPTION 'Actual assignment did not become historically sticky';
    END IF;

    SELECT setup_work_day_task_id
      INTO v_continuation
    FROM ops.create_setup_work_day_assignment(
        v_admin_email, v_day2, v_task_a, 'AFTERNOON', 'B', 10, 4
    );

    IF v_continuation IS NULL THEN
        RAISE EXCEPTION 'Incomplete annual task could not receive a later continuation assignment';
    END IF;

    /* Prove that a fresh annual seed does not regenerate the season-only task.
       Reuse the same disposable season so the test does not require a second
       ref.season row. All mutations are rolled back at the end. */
    DELETE FROM ops.setup_task_progress p
    USING ops.setup_session_task st
    WHERE p.setup_session_task_id = st.setup_session_task_id
      AND st.setup_session_id = v_session_id;

    DELETE FROM ops.setup_session_task_dependency d
    USING ops.setup_session_task st
    WHERE d.setup_session_task_id = st.setup_session_task_id
      AND st.setup_session_id = v_session_id;

    DELETE FROM ops.setup_work_day_task wdt
    USING ops.setup_work_day wd
    WHERE wdt.setup_work_day_id = wd.setup_work_day_id
      AND wd.setup_session_id = v_session_id;

    DELETE FROM ops.setup_work_day
    WHERE setup_session_id = v_session_id;

    DELETE FROM ops.setup_display_state
    WHERE setup_session_id = v_session_id;

    DELETE FROM ops.setup_container_state
    WHERE setup_session_id = v_session_id;

    DELETE FROM ops.setup_session_task
    WHERE setup_session_id = v_session_id;

    DELETE FROM ops.setup_session
    WHERE setup_session_id = v_session_id;

    SELECT setup_session_id
      INTO v_session_id
    FROM ops.create_setup_session(v_admin_email, v_year, 'PLANNING');

    SELECT count(*)
      INTO v_count
    FROM ops.setup_session_task st
    WHERE st.setup_session_id = v_session_id
      AND st.annual_task_name = v_season_name;

    IF v_count <> 0 THEN
        RAISE EXCEPTION 'Fresh annual seed incorrectly regenerated a season-only task';
    END IF;

    RAISE NOTICE 'DISPOSABLE_SETUP_205_VALIDATION_PASS year=% admin=%', v_year, v_admin_email;
END
$validation$;

ROLLBACK;

SELECT
    'PASS' AS validation_status,
    to_regclass('ops.setup_session_task_dependency') IS NOT NULL AS annual_dependency_table,
    has_function_privilege(
        'fieldwiring_app',
        'ops.create_setup_work_day_assignment(text,bigint,bigint,text,text,integer,integer)',
        'EXECUTE'
    ) AS assignment_execute,
    NOT has_table_privilege('fieldwiring_app', 'ops.setup_work_day_task', 'INSERT') AS no_broad_assignment_insert;
