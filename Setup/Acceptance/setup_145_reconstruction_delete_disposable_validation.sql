\set ON_ERROR_STOP on

/* ============================================================================
Setup #145 — reconstruction delete regression over current Production clone

Purpose:
  Prove that the governed reusable-task delete remains an aggregate cleanup
  command after post-019 schema growth.

Fixture deliberately creates:
  - one clone-only reusable task;
  - one reusable prerequisite relationship;
  - one 2025 HISTORICAL_VERIFICATION annual task shell;
  - the migration-050 REUSABLE_BASELINE annual dependency row;
  - one migration-032 Extra Material requirement and expected-source row.

The single governed Delete Task command must remove all task-owned fixture rows
without deleting the shared prerequisite task, Extra Material catalog item, or
Container.
============================================================================ */

DO $validation$
DECLARE
    v_manager_email text;
    v_directus_user_id uuid;
    v_session_id bigint;
    v_task_id bigint;
    v_session_task_id bigint;
    v_prereq_task_id bigint;
    v_prereq_session_task_id bigint;
    v_material_id integer;
    v_container_id integer;
    v_requirement_id bigint;
BEGIN
    IF EXISTS (
        SELECT 1
        FROM ops.setup_session
        WHERE season_year >= 2026
    ) THEN
        RAISE EXCEPTION
            'Disposable reconstruction-delete validation requires no 2026-or-later Setup Session';
    END IF;

    SELECT lower(u.email), u.id
      INTO v_manager_email, v_directus_user_id
    FROM public.directus_users u
    JOIN LATERAL ref.setup_browser_capabilities(lower(u.email)) c ON true
    WHERE u.status = 'active'
      AND c.can_manage_setup
    ORDER BY c.can_admin_setup DESC, lower(u.email)
    LIMIT 1;

    IF v_manager_email IS NULL OR v_directus_user_id IS NULL THEN
        RAISE EXCEPTION 'No active Setup Manager/Admin identity is available for disposable validation';
    END IF;

    SELECT ss.setup_session_id
      INTO v_session_id
    FROM ops.setup_session ss
    WHERE ss.session_status = 'HISTORICAL_VERIFICATION'
    ORDER BY ss.season_year DESC
    LIMIT 1;

    IF v_session_id IS NULL THEN
        RAISE EXCEPTION 'Historical verification Setup Session is required for reconstruction-delete validation';
    END IF;

    SELECT st.setup_task_id, st.setup_session_task_id
      INTO v_prereq_task_id, v_prereq_session_task_id
    FROM ops.setup_session_task st
    JOIN ref.setup_task t
      ON t.setup_task_id = st.setup_task_id
    WHERE st.setup_session_id = v_session_id
      AND st.setup_task_id IS NOT NULL
      AND t.active_flag
    ORDER BY st.setup_session_task_id
    LIMIT 1;

    IF v_prereq_task_id IS NULL OR v_prereq_session_task_id IS NULL THEN
        RAISE EXCEPTION 'No reusable historical annual task is available as prerequisite fixture';
    END IF;

    SELECT m.setup_extra_material_id
      INTO v_material_id
    FROM ref.setup_extra_material m
    WHERE m.active_flag
    ORDER BY m.setup_extra_material_id
    LIMIT 1;

    SELECT c.container_id
      INTO v_container_id
    FROM ref.container c
    ORDER BY c.container_id
    LIMIT 1;

    IF v_material_id IS NULL OR v_container_id IS NULL THEN
        RAISE EXCEPTION 'Extra Material catalog and Container fixture identities are required';
    END IF;

    PERFORM pg_catalog.set_config(
        'app.directus_user_uuid',
        v_directus_user_id::text,
        true
    );

    INSERT INTO ref.setup_task(
        task_name,
        task_action_type,
        display_order,
        active_flag,
        reusable_notes
    )
    VALUES (
        '[DISPOSABLE #145] reconstruction delete aggregate fixture',
        'WORK',
        999999,
        true,
        'Clone-only fixture; must be removed by this validation.'
    )
    RETURNING setup_task_id INTO v_task_id;

    /* Create the reusable prerequisite first so migration-050's annual-shell
       insert trigger materializes the matching REUSABLE_BASELINE dependency. */
    INSERT INTO ref.setup_task_dependency(
        setup_task_id,
        prerequisite_setup_task_id,
        dependency_note
    )
    VALUES (
        v_task_id,
        v_prereq_task_id,
        '[DISPOSABLE #145] prerequisite fixture'
    );

    INSERT INTO ops.setup_session_task(
        setup_session_id,
        setup_task_id
    )
    VALUES (
        v_session_id,
        v_task_id
    )
    RETURNING setup_session_task_id INTO v_session_task_id;

    IF NOT EXISTS (
        SELECT 1
        FROM ops.setup_session_task_dependency d
        WHERE d.setup_session_task_id = v_session_task_id
          AND d.prerequisite_setup_session_task_id = v_prereq_session_task_id
          AND d.dependency_origin = 'REUSABLE_BASELINE'
    ) THEN
        RAISE EXCEPTION 'Migration-050 annual dependency fixture was not created';
    END IF;

    INSERT INTO ref.setup_task_extra_material(
        setup_task_id,
        setup_extra_material_id,
        quantity_required,
        quantity_uom,
        verification_state,
        notes
    )
    VALUES (
        v_task_id,
        v_material_id,
        1,
        'EA',
        'VERIFIED',
        '[DISPOSABLE #145] task requirement fixture'
    )
    RETURNING setup_task_extra_material_id INTO v_requirement_id;

    INSERT INTO ref.setup_task_extra_material_source(
        setup_task_extra_material_id,
        container_id,
        expected_quantity,
        verification_state,
        notes
    )
    VALUES (
        v_requirement_id,
        v_container_id,
        1,
        'VERIFIED',
        '[DISPOSABLE #145] expected-source fixture'
    );

    /* This is the behavior the operator needs before seeding 2026. */
    PERFORM *
    FROM ref.delete_setup_reconstruction_task(
        v_manager_email,
        v_task_id
    );

    IF EXISTS (
        SELECT 1 FROM ref.setup_task WHERE setup_task_id = v_task_id
    ) THEN
        RAISE EXCEPTION 'Reusable reconstruction task survived governed delete';
    END IF;

    IF EXISTS (
        SELECT 1
        FROM ops.setup_session_task
        WHERE setup_session_task_id = v_session_task_id
           OR setup_task_id = v_task_id
    ) THEN
        RAISE EXCEPTION 'Historical annual reconstruction shell survived governed delete';
    END IF;

    IF EXISTS (
        SELECT 1
        FROM ops.setup_session_task_dependency d
        WHERE d.setup_session_task_id = v_session_task_id
           OR d.prerequisite_setup_session_task_id = v_session_task_id
    ) THEN
        RAISE EXCEPTION 'Annual dependency row survived governed delete';
    END IF;

    IF EXISTS (
        SELECT 1
        FROM ref.setup_task_dependency d
        WHERE d.setup_task_id = v_task_id
           OR d.prerequisite_setup_task_id = v_task_id
    ) THEN
        RAISE EXCEPTION 'Reusable dependency row survived governed delete';
    END IF;

    IF EXISTS (
        SELECT 1
        FROM ref.setup_task_extra_material tm
        WHERE tm.setup_task_id = v_task_id
    ) THEN
        RAISE EXCEPTION 'Task Extra Material requirement survived governed delete';
    END IF;

    IF EXISTS (
        SELECT 1
        FROM ref.setup_task_extra_material_source src
        WHERE src.setup_task_extra_material_id = v_requirement_id
    ) THEN
        RAISE EXCEPTION 'Task Extra Material source survived governed delete';
    END IF;

    /* Relationship cleanup must never delete shared Catalog identities. */
    IF NOT EXISTS (
        SELECT 1 FROM ref.setup_task WHERE setup_task_id = v_prereq_task_id
    ) THEN
        RAISE EXCEPTION 'Shared prerequisite reusable task was incorrectly deleted';
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM ref.setup_extra_material
        WHERE setup_extra_material_id = v_material_id
    ) THEN
        RAISE EXCEPTION 'Shared Extra Material catalog row was incorrectly deleted';
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM ref.container WHERE container_id = v_container_id
    ) THEN
        RAISE EXCEPTION 'Shared Container was incorrectly deleted';
    END IF;

    RAISE NOTICE
        'SETUP_145_RECONSTRUCTION_DELETE_DISPOSABLE_VALIDATION_PASS task=%',
        v_task_id;
END
$validation$;

SELECT 'SETUP_145_RECONSTRUCTION_DELETE_DISPOSABLE_VALIDATION_PASS' AS validation_status;
