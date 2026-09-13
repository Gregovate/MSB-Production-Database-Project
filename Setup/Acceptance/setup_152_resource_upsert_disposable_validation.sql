/*
Filename: setup_152_resource_upsert_disposable_validation.sql
Issue: #152

DISPOSABLE CURRENT-PRODUCTION CLONE ONLY.

Purpose:
  Prove the forward repair of ref.set_setup_task_resource(...) against a
  current Production clone.

  Exercise the complete affected mutation path:
    Add -> Update -> Remove/deactivate -> Re-add

All proof mutations are rolled back.
*/

\set ON_ERROR_STOP on

BEGIN;

DO $validation$
DECLARE
    v_manager_email text;
    v_task_id bigint;
    v_resource_id integer;
    v_function_def text;
BEGIN
    IF to_regprocedure(
        'ref.set_setup_task_resource(text,bigint,integer,integer,text,text,boolean)'
    ) IS NULL THEN
        RAISE EXCEPTION 'Task-resource command is missing';
    END IF;

    SELECT pg_get_functiondef(
        'ref.set_setup_task_resource(text,bigint,integer,integer,text,text,boolean)'::regprocedure
    )
    INTO v_function_def;

    IF position(
        'ON CONFLICT ON CONSTRAINT pk_setup_task_resource'
        IN v_function_def
    ) = 0 THEN
        RAISE EXCEPTION 'Named task-resource conflict target is not installed';
    END IF;

    IF position(
        'ON CONFLICT (setup_task_id, setup_resource_id)'
        IN v_function_def
    ) > 0 THEN
        RAISE EXCEPTION 'Ambiguous bare-column task-resource conflict target remains installed';
    END IF;

    IF NOT has_function_privilege(
        'fieldwiring_app',
        'ref.set_setup_task_resource(text,bigint,integer,integer,text,text,boolean)',
        'EXECUTE'
    ) THEN
        RAISE EXCEPTION 'fieldwiring_app lacks narrow task-resource EXECUTE';
    END IF;

    IF has_table_privilege(
        'fieldwiring_app',
        'ref.setup_task_resource',
        'INSERT'
    )
    OR has_table_privilege(
        'fieldwiring_app',
        'ref.setup_task_resource',
        'UPDATE'
    )
    OR has_table_privilege(
        'fieldwiring_app',
        'ref.setup_task_resource',
        'DELETE'
    ) THEN
        RAISE EXCEPTION 'fieldwiring_app has forbidden broad task-resource DML';
    END IF;

    SELECT lower(u.email)
      INTO v_manager_email
    FROM public.directus_users AS u
    JOIN ref.person AS p
      ON p.directus_user_id = u.id
    JOIN LATERAL ref.setup_browser_capabilities(lower(u.email)) AS c
      ON true
    WHERE u.status = 'active'
      AND coalesce(c.can_manage_setup, false)
    ORDER BY u.email
    LIMIT 1;

    IF v_manager_email IS NULL THEN
        RAISE EXCEPTION
            'No active mapped Setup Manager is available in the disposable clone';
    END IF;

    /*
    Pick a real active task/resource combination that is not currently related.
    Nothing is invented and the surrounding transaction is rolled back.
    */
    SELECT
        t.setup_task_id,
        r.setup_resource_id
      INTO
        v_task_id,
        v_resource_id
    FROM ref.setup_task AS t
    CROSS JOIN ref.setup_resource AS r
    WHERE t.active_flag
      AND r.active_flag
      AND NOT EXISTS (
            SELECT 1
            FROM ref.setup_task_resource AS tr
            WHERE tr.setup_task_id = t.setup_task_id
              AND tr.setup_resource_id = r.setup_resource_id
      )
    ORDER BY t.setup_task_id, r.setup_resource_id
    LIMIT 1;

    IF v_task_id IS NULL OR v_resource_id IS NULL THEN
        RAISE EXCEPTION
            'No unused active task/resource pair is available for disposable proof';
    END IF;

    /* ADD */
    PERFORM *
    FROM ref.set_setup_task_resource(
        v_manager_email,
        v_task_id,
        v_resource_id,
        2,
        'REQUIRED',
        'Disposable #152 add proof.',
        true
    );

    IF NOT EXISTS (
        SELECT 1
        FROM ref.setup_task_resource AS tr
        WHERE tr.setup_task_id = v_task_id
          AND tr.setup_resource_id = v_resource_id
          AND tr.active_flag
          AND tr.quantity_required = 2
          AND tr.requirement_type = 'REQUIRED'
          AND tr.notes = 'Disposable #152 add proof.'
    ) THEN
        RAISE EXCEPTION 'Task-resource ADD proof failed';
    END IF;

    /* UPDATE */
    PERFORM *
    FROM ref.set_setup_task_resource(
        v_manager_email,
        v_task_id,
        v_resource_id,
        3,
        'PREFERRED',
        'Disposable #152 update proof.',
        true
    );

    IF NOT EXISTS (
        SELECT 1
        FROM ref.setup_task_resource AS tr
        WHERE tr.setup_task_id = v_task_id
          AND tr.setup_resource_id = v_resource_id
          AND tr.active_flag
          AND tr.quantity_required = 3
          AND tr.requirement_type = 'PREFERRED'
          AND tr.notes = 'Disposable #152 update proof.'
    ) THEN
        RAISE EXCEPTION 'Task-resource UPDATE proof failed';
    END IF;

    /* REMOVE / DEACTIVATE */
    PERFORM *
    FROM ref.set_setup_task_resource(
        v_manager_email,
        v_task_id,
        v_resource_id,
        3,
        'PREFERRED',
        'Disposable #152 remove proof.',
        false
    );

    IF NOT EXISTS (
        SELECT 1
        FROM ref.setup_task_resource AS tr
        WHERE tr.setup_task_id = v_task_id
          AND tr.setup_resource_id = v_resource_id
          AND NOT tr.active_flag
    ) THEN
        RAISE EXCEPTION 'Task-resource REMOVE/deactivate proof failed';
    END IF;

    /* RE-ADD */
    PERFORM *
    FROM ref.set_setup_task_resource(
        v_manager_email,
        v_task_id,
        v_resource_id,
        1,
        'REQUIRED',
        'Disposable #152 re-add proof.',
        true
    );

    IF NOT EXISTS (
        SELECT 1
        FROM ref.setup_task_resource AS tr
        WHERE tr.setup_task_id = v_task_id
          AND tr.setup_resource_id = v_resource_id
          AND tr.active_flag
          AND tr.quantity_required = 1
          AND tr.requirement_type = 'REQUIRED'
          AND tr.notes = 'Disposable #152 re-add proof.'
    ) THEN
        RAISE EXCEPTION 'Task-resource RE-ADD proof failed';
    END IF;

    RAISE NOTICE
        '#152 task-resource behavioral proof passed: task %, resource %',
        v_task_id,
        v_resource_id;
END
$validation$;

ROLLBACK;

SELECT 'SETUP_152_RESOURCE_UPSERT_DISPOSABLE_VALIDATION_PASS' AS result;