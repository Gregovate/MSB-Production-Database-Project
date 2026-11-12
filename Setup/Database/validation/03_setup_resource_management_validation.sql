/* ============================================================================
MSB Setup Session — reusable equipment/resource management validation
Issue: #122
Mode: READ ONLY — run after migration 008
============================================================================ */

WITH checks AS (
    SELECT
        'Task-resource active flag exists'::text AS check_name,
        CASE WHEN EXISTS (
            SELECT 1
            FROM information_schema.columns
            WHERE table_schema = 'ref'
              AND table_name = 'setup_task_resource'
              AND column_name = 'active_flag'
        ) THEN 'PASS' ELSE 'FAIL' END AS status,
        CASE WHEN EXISTS (
            SELECT 1
            FROM information_schema.columns
            WHERE table_schema = 'ref'
              AND table_name = 'setup_task_resource'
              AND column_name = 'active_flag'
        ) THEN 'active_flag present' ELSE 'active_flag missing' END AS detail

    UNION ALL
    SELECT
        'Create resource command exists',
        CASE WHEN to_regprocedure('ref.create_setup_resource(text,text,text,text)') IS NOT NULL THEN 'PASS' ELSE 'FAIL' END,
        coalesce(to_regprocedure('ref.create_setup_resource(text,text,text,text)')::text, 'missing')

    UNION ALL
    SELECT
        'Set task resource command exists',
        CASE WHEN to_regprocedure('ref.set_setup_task_resource(text,bigint,integer,integer,text,text,boolean)') IS NOT NULL THEN 'PASS' ELSE 'FAIL' END,
        coalesce(to_regprocedure('ref.set_setup_task_resource(text,bigint,integer,integer,text,text,boolean)')::text, 'missing')

    UNION ALL
    SELECT
        'Protected app can execute create resource',
        CASE WHEN has_function_privilege(
            'fieldwiring_app',
            'ref.create_setup_resource(text,text,text,text)',
            'EXECUTE'
        ) THEN 'PASS' ELSE 'FAIL' END,
        has_function_privilege(
            'fieldwiring_app',
            'ref.create_setup_resource(text,text,text,text)',
            'EXECUTE'
        )::text

    UNION ALL
    SELECT
        'Protected app can execute set task resource',
        CASE WHEN has_function_privilege(
            'fieldwiring_app',
            'ref.set_setup_task_resource(text,bigint,integer,integer,text,text,boolean)',
            'EXECUTE'
        ) THEN 'PASS' ELSE 'FAIL' END,
        has_function_privilege(
            'fieldwiring_app',
            'ref.set_setup_task_resource(text,bigint,integer,integer,text,text,boolean)',
            'EXECUTE'
        )::text

    UNION ALL
    SELECT
        'Protected app has no broad task-resource UPDATE',
        CASE WHEN NOT has_table_privilege('fieldwiring_app', 'ref.setup_task_resource', 'UPDATE') THEN 'PASS' ELSE 'FAIL' END,
        has_table_privilege('fieldwiring_app', 'ref.setup_task_resource', 'UPDATE')::text

    UNION ALL
    SELECT
        'Front Entrance structured equipment seeded',
        CASE WHEN (
            SELECT count(*)
            FROM ref.setup_task t
            JOIN ref.setup_task_resource tr ON tr.setup_task_id = t.setup_task_id
            JOIN ref.setup_resource r ON r.setup_resource_id = tr.setup_resource_id
            WHERE t.task_name = 'Erect Front Entrance Arch'
              AND tr.active_flag
              AND r.resource_name IN ('SkyTrak', 'Boom Lift')
        ) = 2 THEN 'PASS' ELSE 'FAIL' END,
        (
            SELECT count(*)::text
            FROM ref.setup_task t
            JOIN ref.setup_task_resource tr ON tr.setup_task_id = t.setup_task_id
            JOIN ref.setup_resource r ON r.setup_resource_id = tr.setup_resource_id
            WHERE t.task_name = 'Erect Front Entrance Arch'
              AND tr.active_flag
              AND r.resource_name IN ('SkyTrak', 'Boom Lift')
        )
)
SELECT check_name, status, detail
FROM checks
ORDER BY check_name;

SELECT
    t.setup_task_id,
    t.task_name,
    r.resource_name,
    r.resource_type,
    tr.quantity_required,
    tr.requirement_type,
    tr.active_flag,
    tr.notes
FROM ref.setup_task t
JOIN ref.setup_task_resource tr ON tr.setup_task_id = t.setup_task_id
JOIN ref.setup_resource r ON r.setup_resource_id = tr.setup_resource_id
WHERE t.task_name IN (
    'Erect Front Entrance Arch',
    'Layout / Erect Frame / Strap Down',
    'Install Skins and Bungees',
    'Install Lighting, Cameras, Mats, Signs, and Finish Setup'
)
ORDER BY t.setup_task_id, r.resource_name;
