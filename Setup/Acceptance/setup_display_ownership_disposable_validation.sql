/*
Filename: setup_display_ownership_disposable_validation.sql
Issue: #141

DISPOSABLE DATABASE ONLY.

Purpose:
  Prove the task-specific Display ownership foundation against the representative
  Stage 26 Magic Igloo scope without changing LOR membership,
  ref.display.container_id, Container/KIT relationships, or annual Session data.

Required candidate state:
  - migration 025 already installed in the current Production clone;
  - migration 028 applied to the disposable clone before this validation.
*/

\set ON_ERROR_STOP on

DO $validation$
DECLARE
    v_manager_email text;
    v_manager_person_id integer;
    v_stage_id integer;
    v_frame_task_id bigint;
    v_skins_task_id bigint;
    v_finish_task_id bigint;
    v_move_display_id bigint;
    v_source_count integer;
    v_frame_count integer;
    v_skins_count integer;
    v_2026_before integer;
    v_2026_after integer;
    v_container_before text;
    v_container_after text;
    v_lor_before text;
    v_lor_after text;
BEGIN
    IF to_regclass('ref.setup_task_display') IS NULL
       OR to_regclass('ref.setup_task') IS NULL
       OR to_regclass('ref.lor_scene') IS NULL
       OR to_regclass('ref.lor_scene_display') IS NULL
       OR to_regclass('ref.display') IS NULL
       OR to_regclass('ref.display_status') IS NULL
       OR to_regclass('ref.stage') IS NULL THEN
        RAISE EXCEPTION 'Required Setup/LOR Display ownership objects are missing';
    END IF;

    IF to_regprocedure('ref.set_setup_task_display_owner(text,bigint,bigint,bigint)') IS NULL THEN
        RAISE EXCEPTION 'Migration 028 governed Display-owner command is missing';
    END IF;

    IF NOT has_function_privilege(
        'fieldwiring_app',
        'ref.set_setup_task_display_owner(text,bigint,bigint,bigint)',
        'EXECUTE'
    ) THEN
        RAISE EXCEPTION 'fieldwiring_app cannot execute governed Display-owner command';
    END IF;

    IF NOT EXISTS (
        SELECT 1
        FROM pg_indexes
        WHERE schemaname = 'ref'
          AND tablename = 'setup_task_display'
          AND indexname = 'ux_setup_task_display_one_owner'
          AND indexdef ILIKE '%UNIQUE%display_id%'
    ) THEN
        RAISE EXCEPTION 'Exclusive Display-owner unique index is missing';
    END IF;

    SELECT lower(u.email), p.person_id
      INTO v_manager_email, v_manager_person_id
    FROM public.directus_users AS u
    JOIN ref.person AS p
      ON p.directus_user_id = u.id
    JOIN LATERAL ref.setup_browser_capabilities(lower(u.email)) AS c ON true
    WHERE u.status = 'active'
      AND coalesce(c.can_manage_setup, false)
    ORDER BY u.email
    LIMIT 1;

    IF v_manager_email IS NULL OR v_manager_person_id IS NULL THEN
        RAISE EXCEPTION 'No active mapped Setup Manager is available in the disposable clone';
    END IF;

    SELECT s.stage_id
      INTO v_stage_id
    FROM ref.stage AS s
    WHERE s.stage_key = '26'
    LIMIT 1;

    IF v_stage_id IS NULL THEN
        RAISE EXCEPTION 'Stage 26 Magic Igloo was not found';
    END IF;

    SELECT t.setup_task_id
      INTO v_frame_task_id
    FROM ref.setup_task AS t
    WHERE t.stage_id = v_stage_id
      AND t.task_name = 'Layout / Erect Frame / Strap Down'
      AND t.active_flag
    ORDER BY t.setup_task_id
    LIMIT 1;

    SELECT t.setup_task_id
      INTO v_skins_task_id
    FROM ref.setup_task AS t
    WHERE t.stage_id = v_stage_id
      AND t.task_name = 'Install Skins and Bungees'
      AND t.active_flag
    ORDER BY t.setup_task_id
    LIMIT 1;

    SELECT t.setup_task_id
      INTO v_finish_task_id
    FROM ref.setup_task AS t
    WHERE t.stage_id = v_stage_id
      AND t.task_name = 'Install Lighting, Cameras, Mats, Signs, and Finish Setup'
      AND t.active_flag
    ORDER BY t.setup_task_id
    LIMIT 1;

    IF v_frame_task_id IS NULL OR v_skins_task_id IS NULL OR v_finish_task_id IS NULL THEN
        RAISE EXCEPTION 'Representative Stage 26 Magic Igloo reusable work packages are incomplete';
    END IF;

    /* Clone-only setup: make all three representative work packages eligible. */
    PERFORM * FROM ref.set_setup_task_display_material_requirement(v_manager_email, v_frame_task_id, true);
    PERFORM * FROM ref.set_setup_task_display_material_requirement(v_manager_email, v_skins_task_id, true);
    PERFORM * FROM ref.set_setup_task_display_material_requirement(v_manager_email, v_finish_task_id, true);

    CREATE TEMP TABLE magic_igloo_source_displays (
        display_id bigint PRIMARY KEY
    ) ON COMMIT DROP;

    INSERT INTO magic_igloo_source_displays(display_id)
    SELECT DISTINCT lsd.display_id
    FROM ref.lor_scene AS ls
    JOIN ref.lor_scene_display AS lsd
      ON lsd.lor_scene_id = ls.lor_scene_id
    JOIN ref.display AS d
      ON d.display_id = lsd.display_id
    JOIN ref.display_status AS ds
      ON ds.display_status_id = d.display_status_id
    WHERE ls.stage_id = v_stage_id
      AND upper(ds.display_status_name) = 'ACTIVE'
      AND (
          lower(btrim(ls.scene_name)) = 'root'
          OR ls.scene_name !~ '^[[:space:]]*[0-9]{2}[A-Za-z]?-'
          OR ls.scene_name ~ '-[A-Za-z]{2}[[:space:]]*$'
      )
    ORDER BY lsd.display_id;

    SELECT count(*) INTO v_source_count FROM magic_igloo_source_displays;
    IF v_source_count < 1 THEN
        RAISE EXCEPTION 'Stage 26 current Stage-level resolver source set is empty';
    END IF;

    IF EXISTS (
        SELECT 1
        FROM ref.setup_task_display AS td
        JOIN magic_igloo_source_displays AS src
          ON src.display_id = td.display_id
    ) THEN
        RAISE EXCEPTION 'Current Production clone already has explicit Stage 26 Display ownership; update acceptance assumptions before continuing';
    END IF;

    SELECT count(*)
      INTO v_2026_before
    FROM ops.setup_session AS ss
    WHERE ss.season_year = 2026;

    SELECT md5(coalesce(string_agg(
               src.display_id::text || ':' || coalesce(d.container_id::text, 'NULL'),
               '|' ORDER BY src.display_id
           ), ''))
      INTO v_container_before
    FROM magic_igloo_source_displays AS src
    JOIN ref.display AS d
      ON d.display_id = src.display_id;

    SELECT md5(coalesce(string_agg(
               ls.lor_scene_id::text || ':' || lsd.display_id::text,
               '|' ORDER BY ls.lor_scene_id, lsd.display_id
           ), ''))
      INTO v_lor_before
    FROM ref.lor_scene AS ls
    JOIN ref.lor_scene_display AS lsd
      ON lsd.lor_scene_id = ls.lor_scene_id
    WHERE ls.stage_id = v_stage_id;

    /* Initialize the current/default material task as owner of the source set. */
    FOR v_move_display_id IN
        SELECT src.display_id
        FROM magic_igloo_source_displays AS src
        ORDER BY src.display_id
    LOOP
        PERFORM *
        FROM ref.set_setup_task_display_owner(
            v_manager_email,
            v_move_display_id,
            v_frame_task_id,
            NULL
        );
    END LOOP;

    SELECT count(*)
      INTO v_frame_count
    FROM ref.setup_task_display AS td
    JOIN magic_igloo_source_displays AS src
      ON src.display_id = td.display_id
    WHERE td.setup_task_id = v_frame_task_id;

    IF v_frame_count <> v_source_count THEN
        RAISE EXCEPTION 'Initialization coverage mismatch: frame task owns %, source set has %', v_frame_count, v_source_count;
    END IF;

    IF EXISTS (
        SELECT td.display_id
        FROM ref.setup_task_display AS td
        JOIN magic_igloo_source_displays AS src
          ON src.display_id = td.display_id
        GROUP BY td.display_id
        HAVING count(*) <> 1
    ) THEN
        RAISE EXCEPTION 'A Stage 26 resolved Display does not have exactly one explicit owner after initialization';
    END IF;

    SELECT min(src.display_id)
      INTO v_move_display_id
    FROM magic_igloo_source_displays AS src;

    PERFORM *
    FROM ref.set_setup_task_display_owner(
        v_manager_email,
        v_move_display_id,
        v_skins_task_id,
        v_frame_task_id
    );

    SELECT count(*)
      INTO v_frame_count
    FROM ref.setup_task_display AS td
    JOIN magic_igloo_source_displays AS src
      ON src.display_id = td.display_id
    WHERE td.setup_task_id = v_frame_task_id;

    SELECT count(*)
      INTO v_skins_count
    FROM ref.setup_task_display AS td
    JOIN magic_igloo_source_displays AS src
      ON src.display_id = td.display_id
    WHERE td.setup_task_id = v_skins_task_id;

    IF v_frame_count <> v_source_count - 1 OR v_skins_count <> 1 THEN
        RAISE EXCEPTION 'Move did not transfer exactly one Display: frame=% skins=% source=%', v_frame_count, v_skins_count, v_source_count;
    END IF;

    IF EXISTS (
        SELECT td.display_id
        FROM ref.setup_task_display AS td
        JOIN magic_igloo_source_displays AS src
          ON src.display_id = td.display_id
        GROUP BY td.display_id
        HAVING count(*) <> 1
    ) THEN
        RAISE EXCEPTION 'A resolved Display has zero/multiple explicit owners after move';
    END IF;

    /* A stale browser/client cannot claim a second owner without refreshing. */
    BEGIN
        PERFORM *
        FROM ref.set_setup_task_display_owner(
            v_manager_email,
            v_move_display_id,
            v_finish_task_id,
            NULL
        );
        RAISE EXCEPTION 'Expected duplicate-owner protection did not fire';
    EXCEPTION
        WHEN unique_violation THEN
            NULL;
    END;

    IF EXISTS (
        SELECT 1
        FROM ref.setup_task_display AS td
        JOIN magic_igloo_source_displays AS src
          ON src.display_id = td.display_id
        WHERE td.created_by_person_id IS NULL
           OR td.updated_by_person_id IS NULL
    ) THEN
        RAISE EXCEPTION 'Display ownership writes were not actor-attributed';
    END IF;

    SELECT md5(coalesce(string_agg(
               src.display_id::text || ':' || coalesce(d.container_id::text, 'NULL'),
               '|' ORDER BY src.display_id
           ), ''))
      INTO v_container_after
    FROM magic_igloo_source_displays AS src
    JOIN ref.display AS d
      ON d.display_id = src.display_id;

    SELECT md5(coalesce(string_agg(
               ls.lor_scene_id::text || ':' || lsd.display_id::text,
               '|' ORDER BY ls.lor_scene_id, lsd.display_id
           ), ''))
      INTO v_lor_after
    FROM ref.lor_scene AS ls
    JOIN ref.lor_scene_display AS lsd
      ON lsd.lor_scene_id = ls.lor_scene_id
    WHERE ls.stage_id = v_stage_id;

    IF v_container_after IS DISTINCT FROM v_container_before THEN
        RAISE EXCEPTION 'Display ownership changed ref.display.container_id state';
    END IF;

    IF v_lor_after IS DISTINCT FROM v_lor_before THEN
        RAISE EXCEPTION 'Display ownership changed LOR Stage/Scene membership';
    END IF;

    SELECT count(*)
      INTO v_2026_after
    FROM ops.setup_session AS ss
    WHERE ss.season_year = 2026;

    IF v_2026_after <> v_2026_before THEN
        RAISE EXCEPTION 'Issue #141 acceptance must not create a 2026 Setup Session';
    END IF;
END
$validation$;

SELECT
    s.stage_key,
    t.task_name,
    count(td.display_id) AS owned_displays
FROM ref.setup_task AS t
JOIN ref.stage AS s
  ON s.stage_id = t.stage_id
LEFT JOIN ref.setup_task_display AS td
  ON td.setup_task_id = t.setup_task_id
WHERE s.stage_key = '26'
  AND t.task_name IN (
      'Layout / Erect Frame / Strap Down',
      'Install Skins and Bungees',
      'Install Lighting, Cameras, Mats, Signs, and Finish Setup'
  )
GROUP BY s.stage_key, t.setup_task_id, t.task_name, t.display_order
ORDER BY t.display_order, t.setup_task_id;

SELECT 'SETUP_DISPLAY_OWNERSHIP_DISPOSABLE_VALIDATION_PASS' AS result;
