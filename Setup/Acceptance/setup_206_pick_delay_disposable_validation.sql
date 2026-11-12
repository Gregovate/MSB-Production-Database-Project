\set ON_ERROR_STOP on

BEGIN;

DO $validation$
DECLARE
    v_session_id bigint;
    v_assignment_id bigint;
    v_session_task_id bigint;
    v_container_id integer;
    v_delay_id bigint;
BEGIN
    IF to_regclass('ops.setup_pick_list_delay') IS NULL THEN
        RAISE EXCEPTION 'Pick Delay table is missing';
    END IF;

    IF to_regprocedure(
        'ops.set_setup_pick_list_delay(text,integer,integer,bigint[],text,boolean)'
    ) IS NULL THEN
        RAISE EXCEPTION 'Pick Delay command is missing';
    END IF;

    SELECT ss.setup_session_id
      INTO v_session_id
    FROM ops.setup_session ss
    WHERE ss.season_year = 2026
      AND ss.session_status <> 'COMPLETE';

    IF v_session_id IS NULL THEN
        RAISE EXCEPTION 'Open 2026 Setup Session is required for #206 Pick Delay validation';
    END IF;

    SELECT wdt.setup_work_day_task_id, wdt.setup_session_task_id
      INTO v_assignment_id, v_session_task_id
    FROM ops.setup_work_day_task wdt
    JOIN ops.setup_work_day wd
      ON wd.setup_work_day_id = wdt.setup_work_day_id
    WHERE wd.setup_session_id = v_session_id
    ORDER BY wd.work_date DESC, wdt.setup_work_day_task_id DESC
    LIMIT 1;

    IF v_assignment_id IS NULL THEN
        RAISE EXCEPTION 'At least one 2026 assignment is required for Pick Delay schedule-release validation';
    END IF;

    SELECT c.container_id
      INTO v_container_id
    FROM ref.container c
    ORDER BY c.container_id
    LIMIT 1;

    SELECT r.setup_pick_list_delay_id
      INTO v_delay_id
    FROM ops.set_setup_pick_list_delay(
        'gliebig@sheboyganlights.org',
        2026,
        v_container_id,
        ARRAY[v_session_task_id]::bigint[],
        '[PREVIEW ONLY] Pick Delay validation',
        true
    ) r;

    IF v_delay_id IS NULL OR NOT EXISTS (
        SELECT 1
        FROM ops.setup_pick_list_delay d
        WHERE d.setup_pick_list_delay_id = v_delay_id
          AND d.setup_session_id = v_session_id
          AND d.container_id = v_container_id
          AND d.release_setup_session_task_ids = ARRAY[v_session_task_id]::bigint[]
    ) THEN
        RAISE EXCEPTION 'Pick Delay command did not persist expected transient state';
    END IF;

    UPDATE ops.setup_work_day_task
       SET setup_session_task_id = setup_session_task_id
     WHERE setup_work_day_task_id = v_assignment_id;

    IF EXISTS (
        SELECT 1
        FROM ops.setup_pick_list_delay d
        WHERE d.setup_pick_list_delay_id = v_delay_id
    ) THEN
        RAISE EXCEPTION 'Scheduling trigger did not remove the Pick Delay';
    END IF;

    PERFORM ops.set_setup_pick_list_delay(
        'gliebig@sheboyganlights.org',
        2026,
        v_container_id,
        ARRAY[v_session_task_id]::bigint[],
        '[PREVIEW ONLY] explicit resume validation',
        true
    );

    PERFORM ops.set_setup_pick_list_delay(
        'gliebig@sheboyganlights.org',
        2026,
        v_container_id,
        ARRAY[]::bigint[],
        NULL,
        false
    );

    IF EXISTS (
        SELECT 1
        FROM ops.setup_pick_list_delay d
        WHERE d.setup_session_id = v_session_id
          AND d.container_id = v_container_id
    ) THEN
        RAISE EXCEPTION 'Explicit Resume Pick did not delete transient Pick Delay state';
    END IF;
END;
$validation$;

DO $privilege$
BEGIN
    IF has_table_privilege(
        'fieldwiring_app',
        'ops.setup_pick_list_delay',
        'INSERT'
    ) OR has_table_privilege(
        'fieldwiring_app',
        'ops.setup_pick_list_delay',
        'UPDATE'
    ) OR has_table_privilege(
        'fieldwiring_app',
        'ops.setup_pick_list_delay',
        'DELETE'
    ) THEN
        RAISE EXCEPTION 'fieldwiring_app has forbidden broad Pick Delay DML';
    END IF;

    IF NOT has_table_privilege(
        'fieldwiring_app',
        'ops.setup_pick_list_delay',
        'SELECT'
    ) THEN
        RAISE EXCEPTION 'fieldwiring_app cannot read Pick Delays';
    END IF;

    IF NOT has_function_privilege(
        'fieldwiring_app',
        'ops.set_setup_pick_list_delay(text,integer,integer,bigint[],text,boolean)',
        'EXECUTE'
    ) THEN
        RAISE EXCEPTION 'fieldwiring_app cannot execute governed Pick Delay command';
    END IF;
END;
$privilege$;

ROLLBACK;

SELECT 'SETUP_206_PICK_DELAY_DISPOSABLE_VALIDATION_PASS' AS result;
