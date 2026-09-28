\set ON_ERROR_STOP on
BEGIN;

DO $validation$
DECLARE
    v_manager_email text;
    v_task_id bigint;
    v_material_id integer;
    v_container_id integer;
    v_requirement_id bigint;
    v_source_id bigint;
    v_material_name text;
    v_deleted_source_count integer;
    v_catalog_before integer;
    v_container_before integer;
BEGIN
    IF to_regprocedure(
        'ref.delete_setup_task_extra_material(text,bigint,bigint)'
    ) IS NULL THEN
        RAISE EXCEPTION 'Governed Extra Material requirement delete command is missing';
    END IF;

    SELECT lower(u.email)
      INTO v_manager_email
    FROM public.directus_users AS u
    JOIN ref.person AS p
      ON p.directus_user_id = u.id
    JOIN LATERAL ref.setup_browser_capabilities(u.email) AS capabilities
      ON true
    WHERE u.status='active'
      AND capabilities.can_manage_setup
    ORDER BY u.email
    LIMIT 1;

    IF v_manager_email IS NULL THEN
        RAISE EXCEPTION 'No active Setup Manager identity is available';
    END IF;

    SELECT t.setup_task_id
      INTO v_task_id
    FROM ref.setup_task AS t
    WHERE t.active_flag
    ORDER BY t.setup_task_id
    LIMIT 1;

    SELECT m.setup_extra_material_id
      INTO v_material_id
    FROM ref.setup_extra_material AS m
    WHERE m.active_flag
    ORDER BY m.setup_extra_material_id
    LIMIT 1;

    SELECT c.container_id
      INTO v_container_id
    FROM ref.container AS c
    ORDER BY c.container_id
    LIMIT 1;

    IF v_task_id IS NULL OR v_material_id IS NULL OR v_container_id IS NULL THEN
        RAISE EXCEPTION 'Disposable validation requires one active task, material, and Container';
    END IF;

    SELECT count(*) INTO v_catalog_before
    FROM ref.setup_extra_material
    WHERE setup_extra_material_id = v_material_id;

    SELECT count(*) INTO v_container_before
    FROM ref.container
    WHERE container_id = v_container_id;

    SELECT result.setup_task_extra_material_id
      INTO v_requirement_id
    FROM ref.set_setup_task_extra_material(
        v_manager_email,
        NULL,
        v_task_id,
        v_material_id,
        1,
        'EA',
        '[DISPOSABLE #206 HARD DELETE]',
        NULL,
        NULL,
        NULL,
        'EXACT',
        'UNVERIFIED',
        '[PREVIEW ONLY] #206 hard-delete validation',
        true
    ) AS result;

    SELECT result.setup_task_extra_material_source_id
      INTO v_source_id
    FROM ref.set_setup_task_extra_material_source(
        v_manager_email,
        NULL,
        v_requirement_id,
        v_container_id,
        1,
        'UNVERIFIED',
        '[PREVIEW ONLY] #206 hard-delete validation source',
        true
    ) AS result;

    IF NOT EXISTS (
        SELECT 1
        FROM ref.setup_task_extra_material
        WHERE setup_task_extra_material_id = v_requirement_id
    ) OR NOT EXISTS (
        SELECT 1
        FROM ref.setup_task_extra_material_source
        WHERE setup_task_extra_material_source_id = v_source_id
    ) THEN
        RAISE EXCEPTION 'Disposable requirement/source fixture was not created';
    END IF;

    SELECT result.deleted_source_count, result.material_name
      INTO v_deleted_source_count, v_material_name
    FROM ref.delete_setup_task_extra_material(
        v_manager_email,
        v_task_id,
        v_requirement_id
    ) AS result;

    IF v_deleted_source_count <> 1 THEN
        RAISE EXCEPTION
            'Expected hard delete to remove one task-source row; got %',
            v_deleted_source_count;
    END IF;

    IF EXISTS (
        SELECT 1
        FROM ref.setup_task_extra_material
        WHERE setup_task_extra_material_id = v_requirement_id
    ) THEN
        RAISE EXCEPTION 'Mistaken task Extra Material requirement still exists after hard delete';
    END IF;

    IF EXISTS (
        SELECT 1
        FROM ref.setup_task_extra_material_source
        WHERE setup_task_extra_material_source_id = v_source_id
    ) THEN
        RAISE EXCEPTION 'Task-source row still exists after parent requirement hard delete';
    END IF;

    IF (SELECT count(*) FROM ref.setup_extra_material WHERE setup_extra_material_id=v_material_id)
       <> v_catalog_before THEN
        RAISE EXCEPTION 'Hard delete changed Extra Material catalog identity';
    END IF;

    IF (SELECT count(*) FROM ref.container WHERE container_id=v_container_id)
       <> v_container_before THEN
        RAISE EXCEPTION 'Hard delete changed Container identity';
    END IF;

    IF NOT has_function_privilege(
        'fieldwiring_app',
        'ref.delete_setup_task_extra_material(text,bigint,bigint)',
        'EXECUTE'
    ) THEN
        RAISE EXCEPTION 'fieldwiring_app cannot execute governed requirement delete';
    END IF;

    IF has_table_privilege('fieldwiring_app','ref.setup_task_extra_material','DELETE')
       OR has_table_privilege('fieldwiring_app','ref.setup_task_extra_material_source','DELETE') THEN
        RAISE EXCEPTION 'fieldwiring_app has forbidden broad Extra Material DELETE privilege';
    END IF;
END
$validation$;

ROLLBACK;

SELECT 'SETUP_206_EXTRA_MATERIAL_LIFECYCLE_DISPOSABLE_VALIDATION_PASS' AS result;
