\set ON_ERROR_STOP on

/* ============================================================================
Setup #122 — 2026 launch unblock disposable validation
Candidate behavior:
  - fresh 2026 annual Session seeds the exact active reusable Catalog once;
  - planning-only state does not block deletion;
  - material assignments must be moved/reassigned before reusable deletion;
  - reported work blocks deletion;
  - unworked season-only work can be deleted safely.
Disposable current-Production clone only.
============================================================================ */

DO $validation$
DECLARE
    v_admin_email text;
    v_session_id bigint;
    v_seeded integer;
    v_active integer;
    v_stage_id integer;
    v_kit_container_id integer;
    v_day_id bigint;
    v_crew_id bigint;
    v_reusable_task_id bigint;
    v_reusable_session_task_id bigint;
    v_material_task_id bigint;
    v_material_session_task_id bigint;
    v_season_task_id bigint;
    v_worked_season_task_id bigint;
    v_existing_session_task_id bigint;
    v_material_blocked boolean := false;
    v_reported_work_blocked boolean := false;
BEGIN
    SELECT lower(u.email)
      INTO v_admin_email
    FROM public.directus_users u
    JOIN ref.person p
      ON p.directus_user_id = u.id
    JOIN LATERAL ref.setup_browser_capabilities(lower(u.email)) c ON true
    WHERE u.status = 'active'
      AND c.can_admin_setup
    ORDER BY lower(u.email)
    LIMIT 1;

    IF v_admin_email IS NULL THEN
        RAISE EXCEPTION 'No active Setup Administrator with ref.person mapping was found';
    END IF;

    IF EXISTS (
        SELECT 1 FROM ops.setup_session WHERE season_year = 2026
    ) THEN
        RAISE EXCEPTION 'Disposable #122 launch validation requires Production clone to begin with no 2026 Setup Session';
    END IF;

    IF NOT has_function_privilege(
        'fieldwiring_app',
        'ops.create_setup_session(text,integer,text)',
        'EXECUTE'
    ) OR NOT has_function_privilege(
        'fieldwiring_app',
        'ref.delete_setup_reconstruction_task(text,bigint)',
        'EXECUTE'
    ) OR NOT has_function_privilege(
        'fieldwiring_app',
        'ops.delete_unworked_setup_season_task(text,bigint)',
        'EXECUTE'
    ) THEN
        RAISE EXCEPTION 'fieldwiring_app lacks one or more governed #122 launch commands';
    END IF;

    IF has_table_privilege('fieldwiring_app', 'ops.setup_session_task', 'DELETE')
       OR has_table_privilege('fieldwiring_app', 'ops.setup_work_day_task', 'DELETE')
       OR has_table_privilege('fieldwiring_app', 'ref.setup_task', 'DELETE')
       OR has_table_privilege('fieldwiring_app', 'ref.setup_task_display', 'DELETE')
       OR has_table_privilege('fieldwiring_app', 'ref.setup_task_container_support', 'DELETE') THEN
        RAISE EXCEPTION 'fieldwiring_app unexpectedly has broad task/material DELETE privilege';
    END IF;

    SELECT count(*)::integer
      INTO v_active
    FROM ref.setup_task t
    WHERE t.active_flag;

    SELECT setup_session_id, seeded_task_count
      INTO v_session_id, v_seeded
    FROM ops.create_setup_session(v_admin_email, 2026, 'PLANNING');

    IF v_seeded <> v_active THEN
        RAISE EXCEPTION
            '2026 seed count % does not equal active reusable Catalog count %',
            v_seeded, v_active;
    END IF;

    IF (
        SELECT count(*)::integer
        FROM ops.setup_session_task st
        WHERE st.setup_session_id = v_session_id
          AND st.task_origin = 'REUSABLE'
    ) <> v_active THEN
        RAISE EXCEPTION '2026 reusable annual row count does not equal active Catalog count';
    END IF;

    IF EXISTS (
        SELECT st.setup_task_id
        FROM ops.setup_session_task st
        WHERE st.setup_session_id = v_session_id
          AND st.task_origin = 'REUSABLE'
        GROUP BY st.setup_task_id
        HAVING count(*) <> 1
    ) THEN
        RAISE EXCEPTION '2026 reusable seed contains a duplicate task identity';
    END IF;

    IF EXISTS (
        SELECT 1
        FROM ops.setup_session_task st
        JOIN ref.setup_task t ON t.setup_task_id = st.setup_task_id
        WHERE st.setup_session_id = v_session_id
          AND st.task_origin = 'REUSABLE'
          AND NOT t.active_flag
    ) THEN
        RAISE EXCEPTION '2026 reusable seed contains an inactive Catalog task';
    END IF;

    IF EXISTS (
        SELECT 1
        FROM ref.setup_task t
        WHERE t.active_flag
          AND NOT EXISTS (
              SELECT 1
              FROM ops.setup_session_task st
              WHERE st.setup_session_id = v_session_id
                AND st.setup_task_id = t.setup_task_id
                AND st.task_origin = 'REUSABLE'
          )
    ) THEN
        RAISE EXCEPTION 'At least one active reusable Catalog task did not seed into 2026';
    END IF;

    IF EXISTS (
        SELECT 1
        FROM ref.setup_task_dependency d
        JOIN ref.setup_task t ON t.setup_task_id = d.setup_task_id AND t.active_flag
        JOIN ref.setup_task p ON p.setup_task_id = d.prerequisite_setup_task_id AND p.active_flag
        JOIN ops.setup_session_task st
          ON st.setup_session_id = v_session_id
         AND st.setup_task_id = d.setup_task_id
        JOIN ops.setup_session_task pst
          ON pst.setup_session_id = v_session_id
         AND pst.setup_task_id = d.prerequisite_setup_task_id
        WHERE NOT EXISTS (
            SELECT 1
            FROM ops.setup_session_task_dependency ad
            WHERE ad.setup_session_task_id = st.setup_session_task_id
              AND ad.prerequisite_setup_session_task_id = pst.setup_session_task_id
        )
    ) THEN
        RAISE EXCEPTION 'At least one active reusable prerequisite failed to seed into 2026';
    END IF;

    SELECT min(stage_id)
      INTO v_stage_id
    FROM ref.stage;

    SELECT min(container_id)
      INTO v_kit_container_id
    FROM ref.container
    WHERE container_type_id = 2;

    IF v_stage_id IS NULL OR v_kit_container_id IS NULL THEN
        RAISE EXCEPTION 'Stage and Kit Box fixtures are required';
    END IF;

    SELECT setup_work_day_id
      INTO v_day_id
    FROM ops.upsert_setup_work_day(
        v_admin_email,
        2026,
        DATE '2026-10-01',
        NULL,
        'PLANNED',
        NULL,
        'Disposable #122 validation',
        'Planning-only deletion proof'
    );

    SELECT setup_work_day_crew_id
      INTO v_crew_id
    FROM ops.setup_work_day_crew
    WHERE setup_work_day_id = v_day_id
      AND crew_number = 1;

    IF v_crew_id IS NULL THEN
        RAISE EXCEPTION 'Default Crew A was not created for disposable 2026 work day';
    END IF;

    /* Planning-only reusable task: seed into open 2026, schedule it, then
       fully delete it. Planning is not protected history. */
    SELECT setup_task_id
      INTO v_reusable_task_id
    FROM ref.create_setup_task(
        v_admin_email,
        '[DISPOSABLE #122] unworked reusable delete',
        v_stage_id,
        'WORK',
        999910,
        1,
        2,
        60,
        'Disposable validation complete',
        NULL,
        NULL,
        'Clone-only #122 planning deletion fixture'
    );

    SELECT st.setup_session_task_id
      INTO v_reusable_session_task_id
    FROM ops.setup_session_task st
    WHERE st.setup_session_id = v_session_id
      AND st.setup_task_id = v_reusable_task_id;

    IF v_reusable_session_task_id IS NULL THEN
        RAISE EXCEPTION 'New reusable task did not automatically enter open 2026 Session';
    END IF;

    PERFORM *
    FROM ops.create_setup_work_day_assignment(
        v_admin_email,
        v_day_id,
        v_reusable_session_task_id,
        'MORNING',
        v_crew_id,
        999910
    );

    PERFORM *
    FROM ref.delete_setup_reconstruction_task(
        v_admin_email,
        v_reusable_task_id
    );

    IF EXISTS (
        SELECT 1 FROM ref.setup_task WHERE setup_task_id = v_reusable_task_id
    ) OR EXISTS (
        SELECT 1 FROM ops.setup_session_task WHERE setup_task_id = v_reusable_task_id
    ) OR EXISTS (
        SELECT 1 FROM ops.setup_work_day_task
        WHERE setup_session_task_id = v_reusable_session_task_id
    ) THEN
        RAISE EXCEPTION 'Planning-only reusable task was not fully deleted';
    END IF;

    /* Material guard: existing material assignment must be moved first. */
    SELECT setup_task_id
      INTO v_material_task_id
    FROM ref.create_setup_task(
        v_admin_email,
        '[DISPOSABLE #122] material delete guard',
        v_stage_id,
        'WORK',
        999920,
        1,
        2,
        30,
        'Disposable validation complete',
        NULL,
        NULL,
        'Clone-only #122 material guard fixture'
    );

    SELECT st.setup_session_task_id
      INTO v_material_session_task_id
    FROM ops.setup_session_task st
    WHERE st.setup_session_id = v_session_id
      AND st.setup_task_id = v_material_task_id;

    PERFORM *
    FROM ref.set_setup_task_kit_box_assignment(
        v_admin_email,
        v_material_task_id,
        v_kit_container_id,
        true,
        '[DISPOSABLE #122] material guard'
    );

    BEGIN
        PERFORM *
        FROM ref.delete_setup_reconstruction_task(
            v_admin_email,
            v_material_task_id
        );
    EXCEPTION
        WHEN foreign_key_violation THEN
            IF SQLERRM LIKE '%KIT/support Container assignments%' THEN
                v_material_blocked := true;
            END IF;
    END;

    IF NOT v_material_blocked THEN
        RAISE EXCEPTION 'Reusable delete did not fail closed while Kit material remained assigned';
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM ref.setup_task WHERE setup_task_id = v_material_task_id
    ) THEN
        RAISE EXCEPTION 'Material-blocked task was deleted unexpectedly';
    END IF;

    PERFORM *
    FROM ref.set_setup_task_kit_box_assignment(
        v_admin_email,
        v_material_task_id,
        v_kit_container_id,
        false,
        NULL
    );

    PERFORM *
    FROM ref.delete_setup_reconstruction_task(
        v_admin_email,
        v_material_task_id
    );

    IF EXISTS (
        SELECT 1 FROM ref.setup_task WHERE setup_task_id = v_material_task_id
    ) THEN
        RAISE EXCEPTION 'Reusable task survived after material was deliberately unassigned';
    END IF;

    /* Unworked season-only work can be planned and fully removed. */
    SELECT setup_session_task_id
      INTO v_season_task_id
    FROM ops.create_setup_season_task(
        v_admin_email,
        2026,
        '[DISPOSABLE #122] 2026-only delete',
        v_stage_id,
        NULL,
        'WORK',
        999930,
        1,
        2,
        45,
        'LIGHT',
        'Disposable validation complete',
        NULL,
        NULL,
        NULL,
        false,
        'Clone-only season task'
    );

    PERFORM *
    FROM ops.create_setup_work_day_assignment(
        v_admin_email,
        v_day_id,
        v_season_task_id,
        'AFTERNOON',
        v_crew_id,
        999930
    );

    SELECT st.setup_session_task_id
      INTO v_existing_session_task_id
    FROM ops.setup_session_task st
    WHERE st.setup_session_id = v_session_id
      AND st.task_origin = 'REUSABLE'
    ORDER BY st.setup_session_task_id
    LIMIT 1;

    PERFORM *
    FROM ops.set_setup_session_task_dependency(
        v_admin_email,
        v_season_task_id,
        v_existing_session_task_id,
        '[DISPOSABLE #122] planning dependency',
        true
    );

    PERFORM *
    FROM ops.delete_unworked_setup_season_task(
        v_admin_email,
        v_season_task_id
    );

    IF EXISTS (
        SELECT 1
        FROM ops.setup_session_task
        WHERE setup_session_task_id = v_season_task_id
    ) OR EXISTS (
        SELECT 1
        FROM ops.setup_work_day_task
        WHERE setup_session_task_id = v_season_task_id
    ) OR EXISTS (
        SELECT 1
        FROM ops.setup_session_task_dependency d
        WHERE d.setup_session_task_id = v_season_task_id
           OR d.prerequisite_setup_session_task_id = v_season_task_id
    ) THEN
        RAISE EXCEPTION 'Unworked season-only task or planning relationships survived governed delete';
    END IF;

    /* Reported work is the history boundary and must block hard deletion. */
    SELECT setup_session_task_id
      INTO v_worked_season_task_id
    FROM ops.create_setup_season_task(
        v_admin_email,
        2026,
        '[DISPOSABLE #122] worked season task',
        v_stage_id,
        NULL,
        'WORK',
        999940,
        1,
        2,
        30,
        'LIGHT',
        'Disposable validation complete',
        NULL,
        NULL,
        NULL,
        false,
        'Clone-only reported-work guard'
    );

    PERFORM *
    FROM ops.create_setup_work_day_assignment(
        v_admin_email,
        v_day_id,
        v_worked_season_task_id,
        'AFTERNOON',
        v_crew_id,
        999940
    );

    PERFORM *
    FROM ops.record_setup_task_progress(
        v_admin_email,
        v_worked_season_task_id,
        v_day_id,
        'AFTERNOON',
        1,
        NULL,
        NULL,
        '[DISPOSABLE #122] reported-work guard',
        false
    );

    BEGIN
        PERFORM *
        FROM ops.delete_unworked_setup_season_task(
            v_admin_email,
            v_worked_season_task_id
        );
    EXCEPTION
        WHEN foreign_key_violation THEN
            IF SQLERRM LIKE '%reported work/progress%' THEN
                v_reported_work_blocked := true;
            END IF;
    END;

    IF NOT v_reported_work_blocked THEN
        RAISE EXCEPTION 'Reported work did not block season-only task deletion';
    END IF;

    IF NOT EXISTS (
        SELECT 1
        FROM ops.setup_session_task
        WHERE setup_session_task_id = v_worked_season_task_id
    ) THEN
        RAISE EXCEPTION 'Worked season-only task was deleted unexpectedly';
    END IF;

    RAISE NOTICE
        'SETUP_122_2026_LAUNCH_UNBLOCK_DISPOSABLE_VALIDATION_PASS session=% seeded=% active=%',
        v_session_id, v_seeded, v_active;
END
$validation$;

SELECT 'SETUP_122_2026_LAUNCH_UNBLOCK_DISPOSABLE_VALIDATION_PASS' AS validation_status;
