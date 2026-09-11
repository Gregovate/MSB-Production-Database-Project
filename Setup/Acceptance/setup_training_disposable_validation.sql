\set ON_ERROR_STOP on

DO $validation$
DECLARE
    v_manager_email text;
    v_person_id integer;
    v_inactive_person_id integer;
    v_safe_task bigint;
    v_safe_annual bigint;
    v_block_task bigint;
    v_block_annual bigint;
    v_deleted_count integer;
    v_state text;
    v_role text;
    v_blocked boolean := false;
    v_inactive_blocked boolean := false;
BEGIN
    SELECT lower(u.email)
      INTO v_manager_email
    FROM public.directus_users u
    JOIN ref.person p
      ON p.directus_user_id = u.id
    JOIN LATERAL ref.setup_browser_capabilities(u.email) c ON true
    WHERE u.status = 'active'
      AND c.can_manage_setup
    ORDER BY c.can_admin_setup DESC, u.email
    LIMIT 1;

    IF v_manager_email IS NULL THEN
        RAISE EXCEPTION 'No active Setup Manager with ref.person mapping was found in the cloned Production data';
    END IF;

    IF NOT has_function_privilege(
        'fieldwiring_app',
        'ref.delete_setup_reconstruction_task(text,bigint)',
        'EXECUTE'
    ) THEN
        RAISE EXCEPTION 'fieldwiring_app cannot execute reconstruction-safe task delete';
    END IF;

    IF NOT has_function_privilege(
        'fieldwiring_app',
        'ref.set_setup_task_captain(text,bigint,integer,text,integer,text,boolean)',
        'EXECUTE'
    ) THEN
        RAISE EXCEPTION 'fieldwiring_app cannot execute Captain management command';
    END IF;

    IF NOT has_function_privilege(
        'fieldwiring_app',
        'ref.setup_task_captain_list(bigint)',
        'EXECUTE'
    ) OR NOT has_function_privilege(
        'fieldwiring_app',
        'ref.setup_captain_person_list()',
        'EXECUTE'
    ) THEN
        RAISE EXCEPTION 'fieldwiring_app lacks Captain read projection execute privilege';
    END IF;

    IF has_table_privilege('fieldwiring_app', 'ref.setup_task', 'DELETE')
       OR has_table_privilege('fieldwiring_app', 'ref.setup_task_captain', 'INSERT')
       OR has_table_privilege('fieldwiring_app', 'ref.setup_task_captain', 'UPDATE')
       OR has_table_privilege('fieldwiring_app', 'ref.setup_task_captain', 'DELETE')
       OR has_table_privilege('fieldwiring_app', 'ops.setup_session_task', 'UPDATE') THEN
        RAISE EXCEPTION 'fieldwiring_app unexpectedly has broad Setup table DML';
    END IF;

    IF EXISTS (
        SELECT 1
        FROM ref.setup_captain_person_list() c
        JOIN ref.person p
          ON p.person_id = c.person_id
        WHERE NOT p.active_flag
    ) THEN
        RAISE EXCEPTION 'Captain person projection exposed an inactive ref.person row';
    END IF;

    SELECT person_id
      INTO v_person_id
    FROM ref.setup_captain_person_list()
    ORDER BY person_id
    LIMIT 1;

    IF v_person_id IS NULL THEN
        RAISE EXCEPTION 'Captain person projection returned no candidate person';
    END IF;

    INSERT INTO ref.person(first_name, last_name, active_flag)
    VALUES ('[DISPOSABLE]', 'Inactive Captain Candidate', false)
    RETURNING person_id INTO v_inactive_person_id;

    IF EXISTS (
        SELECT 1
        FROM ref.setup_captain_person_list()
        WHERE person_id = v_inactive_person_id
    ) THEN
        RAISE EXCEPTION 'Disposable inactive person was exposed by Captain person projection';
    END IF;

    SELECT setup_task_id
      INTO v_safe_task
    FROM ref.create_setup_task(
        v_manager_email,
        '[DISPOSABLE] Setup reconstruction safe delete',
        NULL,
        'WORK',
        9990,
        NULL,
        NULL,
        NULL,
        NULL,
        NULL,
        NULL,
        'Disposable acceptance only; never Production.'
    );

    SELECT st.setup_session_task_id
      INTO v_safe_annual
    FROM ops.setup_session_task st
    JOIN ops.setup_session ss
      ON ss.setup_session_id = st.setup_session_id
    WHERE st.setup_task_id = v_safe_task
      AND ss.session_status = 'HISTORICAL_VERIFICATION'
    ORDER BY ss.season_year
    LIMIT 1;

    IF v_safe_annual IS NULL THEN
        RAISE EXCEPTION 'Disposable reusable task did not receive a historical annual shell';
    END IF;

    BEGIN
        PERFORM *
        FROM ref.set_setup_task_captain(
            v_manager_email,
            v_safe_task,
            v_inactive_person_id,
            'CAPTAIN',
            10,
            'Inactive person must be refused',
            true
        );
    EXCEPTION
        WHEN invalid_parameter_value THEN
            v_inactive_blocked := true;
    END;

    IF NOT v_inactive_blocked THEN
        RAISE EXCEPTION 'Inactive person was unexpectedly accepted for a Captain assignment';
    END IF;

    PERFORM *
    FROM ref.set_setup_task_captain(
        v_manager_email,
        v_safe_task,
        v_person_id,
        'CAPTAIN',
        10,
        'Disposable Captain validation',
        true
    );

    SELECT captain_role
      INTO v_role
    FROM ref.setup_task_captain_list(v_safe_task)
    WHERE person_id = v_person_id;

    IF v_role IS DISTINCT FROM 'CAPTAIN' THEN
        RAISE EXCEPTION 'Captain assignment did not persist through governed command';
    END IF;

    PERFORM *
    FROM ref.set_setup_task_captain(
        v_manager_email,
        v_safe_task,
        v_person_id,
        'ADVISOR',
        20,
        'Disposable role update',
        true
    );

    SELECT captain_role
      INTO v_role
    FROM ref.setup_task_captain_list(v_safe_task)
    WHERE person_id = v_person_id;

    IF v_role IS DISTINCT FROM 'ADVISOR' THEN
        RAISE EXCEPTION 'Captain role update did not persist';
    END IF;

    PERFORM *
    FROM ops.update_setup_session_task_review(
        v_manager_email,
        v_safe_annual,
        'ASSIGNED',
        NULL,
        NULL,
        NULL,
        NULL,
        'Disposable ASSIGNED-state validation'
    );

    SELECT verification_state
      INTO v_state
    FROM ops.setup_session_task
    WHERE setup_session_task_id = v_safe_annual;

    IF v_state IS DISTINCT FROM 'ASSIGNED' THEN
        RAISE EXCEPTION 'ASSIGNED reconciliation state did not persist';
    END IF;

    PERFORM *
    FROM ref.set_setup_task_captain(
        v_manager_email,
        v_safe_task,
        v_person_id,
        'ADVISOR',
        20,
        NULL,
        false
    );

    IF EXISTS (
        SELECT 1 FROM ref.setup_task_captain WHERE setup_task_id = v_safe_task
    ) THEN
        RAISE EXCEPTION 'Captain removal command did not remove assignment';
    END IF;

    SELECT deleted_annual_rows
      INTO v_deleted_count
    FROM ref.delete_setup_reconstruction_task(v_manager_email, v_safe_task);

    IF v_deleted_count < 1
       OR EXISTS (SELECT 1 FROM ref.setup_task WHERE setup_task_id = v_safe_task)
       OR EXISTS (SELECT 1 FROM ops.setup_session_task WHERE setup_task_id = v_safe_task) THEN
        RAISE EXCEPTION 'Reconstruction-safe delete did not remove the disposable task and annual shell';
    END IF;

    SELECT setup_task_id
      INTO v_block_task
    FROM ref.create_setup_task(
        v_manager_email,
        '[DISPOSABLE] Setup reconstruction history block',
        NULL,
        'WORK',
        9991,
        NULL,
        NULL,
        NULL,
        NULL,
        NULL,
        NULL,
        'Disposable acceptance only; never Production.'
    );

    SELECT st.setup_session_task_id
      INTO v_block_annual
    FROM ops.setup_session_task st
    JOIN ops.setup_session ss
      ON ss.setup_session_id = st.setup_session_id
    WHERE st.setup_task_id = v_block_task
      AND ss.session_status = 'HISTORICAL_VERIFICATION'
    ORDER BY ss.season_year
    LIMIT 1;

    UPDATE ops.setup_session_task
       SET planned_date = DATE '2025-10-01'
     WHERE setup_session_task_id = v_block_annual;

    BEGIN
        PERFORM *
        FROM ref.delete_setup_reconstruction_task(v_manager_email, v_block_task);
    EXCEPTION
        WHEN foreign_key_violation THEN
            v_blocked := true;
    END;

    IF NOT v_blocked THEN
        RAISE EXCEPTION 'Reconstruction delete did not refuse annual planning history';
    END IF;

    IF NOT EXISTS (SELECT 1 FROM ref.setup_task WHERE setup_task_id = v_block_task) THEN
        RAISE EXCEPTION 'History-blocked task was unexpectedly deleted';
    END IF;

    BEGIN
        PERFORM *
        FROM ref.set_setup_task_captain(
            v_manager_email,
            v_block_task,
            v_person_id,
            'NOT_A_ROLE',
            100,
            NULL,
            true
        );
        RAISE EXCEPTION 'Invalid Captain role was unexpectedly accepted';
    EXCEPTION
        WHEN invalid_parameter_value THEN
            NULL;
    END;

    RAISE NOTICE 'DISPOSABLE_SETUP_TRAINING_VALIDATION_PASS manager=% safe_task=% blocked_task=%',
        v_manager_email, v_safe_task, v_block_task;
END
$validation$;

SELECT
    'PASS' AS validation_status,
    has_function_privilege(
        'fieldwiring_app',
        'ref.delete_setup_reconstruction_task(text,bigint)',
        'EXECUTE'
    ) AS delete_execute,
    has_function_privilege(
        'fieldwiring_app',
        'ref.set_setup_task_captain(text,bigint,integer,text,integer,text,boolean)',
        'EXECUTE'
    ) AS captain_execute,
    NOT has_table_privilege('fieldwiring_app', 'ref.setup_task', 'DELETE') AS no_broad_task_delete,
    NOT has_table_privilege('fieldwiring_app', 'ref.setup_task_captain', 'INSERT') AS no_broad_captain_insert,
    NOT has_table_privilege('fieldwiring_app', 'ops.setup_session_task', 'UPDATE') AS no_broad_annual_update;
