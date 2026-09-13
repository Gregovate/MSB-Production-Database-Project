/*
Filename: setup_display_ownership_browser_seed.sql
Issue: #141

DISPOSABLE BROWSER PREVIEW ONLY.

Purpose:
  Prepare Stage 26 Magic Igloo for operator review of the real first-use Display
  ownership workflow. This seed makes the three representative reusable work
  packages material-bearing through the governed Manager command, but deliberately
  creates NO ref.setup_task_display ownership rows.

Expected browser state after this seed:
  - Stage 26 resolver source Displays remain unchanged;
  - the three representative tasks are eligible ownership targets;
  - Display ownership is UNINITIALIZED_MULTI;
  - Manager can initialize all resolved Displays to the selected/default task;
  - Manager can then drag individual Displays between the three tasks.
*/

\set ON_ERROR_STOP on

DO $seed$
DECLARE
    v_manager_email text;
    v_stage_id integer;
    v_frame_task_id bigint;
    v_skins_task_id bigint;
    v_finish_task_id bigint;
    v_source_count integer;
    v_existing_owner_count integer;
    v_2026_before integer;
    v_2026_after integer;
BEGIN
    IF to_regprocedure('ref.set_setup_task_display_material_requirement(text,bigint,boolean)') IS NULL THEN
        RAISE EXCEPTION 'Governed Display-material requirement command is missing';
    END IF;

    IF to_regprocedure('ref.set_setup_task_display_owner(text,bigint,bigint,bigint)') IS NULL THEN
        RAISE EXCEPTION 'Migration 028 Display-owner command is missing';
    END IF;

    SELECT lower(u.email)
      INTO v_manager_email
    FROM public.directus_users AS u
    JOIN ref.person AS p
      ON p.directus_user_id = u.id
    JOIN LATERAL ref.setup_browser_capabilities(lower(u.email)) AS c ON true
    WHERE u.status = 'active'
      AND coalesce(c.can_manage_setup, false)
    ORDER BY u.email
    LIMIT 1;

    IF v_manager_email IS NULL THEN
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

    SELECT count(*)
      INTO v_2026_before
    FROM ops.setup_session AS ss
    WHERE ss.season_year = 2026;

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

    SELECT count(*)
      INTO v_existing_owner_count
    FROM ref.setup_task_display AS td
    JOIN magic_igloo_source_displays AS src
      ON src.display_id = td.display_id;

    IF v_existing_owner_count <> 0 THEN
        RAISE EXCEPTION 'Browser seed requires uninitialized Stage 26 ownership; found % existing owner rows', v_existing_owner_count;
    END IF;

    PERFORM * FROM ref.set_setup_task_display_material_requirement(v_manager_email, v_frame_task_id, true);
    PERFORM * FROM ref.set_setup_task_display_material_requirement(v_manager_email, v_skins_task_id, true);
    PERFORM * FROM ref.set_setup_task_display_material_requirement(v_manager_email, v_finish_task_id, true);

    IF EXISTS (
        SELECT 1
        FROM ref.setup_task_display AS td
        JOIN magic_igloo_source_displays AS src
          ON src.display_id = td.display_id
    ) THEN
        RAISE EXCEPTION 'Browser seed must not create explicit Display ownership rows';
    END IF;

    IF EXISTS (
        SELECT 1
        FROM ref.setup_task AS t
        WHERE t.setup_task_id IN (v_frame_task_id, v_skins_task_id, v_finish_task_id)
          AND NOT t.requires_display_material
    ) THEN
        RAISE EXCEPTION 'Browser seed did not make all three representative tasks material-bearing';
    END IF;

    SELECT count(*)
      INTO v_2026_after
    FROM ops.setup_session AS ss
    WHERE ss.season_year = 2026;

    IF v_2026_after <> v_2026_before THEN
        RAISE EXCEPTION 'Browser seed must not create a 2026 Setup Session';
    END IF;

    RAISE NOTICE 'Magic Igloo browser seed ready: stage_id=%, source_displays=%, tasks=%/%/%',
        v_stage_id, v_source_count, v_frame_task_id, v_skins_task_id, v_finish_task_id;
END
$seed$;

SELECT
    'SETUP_DISPLAY_OWNERSHIP_BROWSER_SEED_PASS' AS result,
    count(*) FILTER (WHERE t.requires_display_material) AS eligible_tasks,
    (SELECT count(*) FROM ref.setup_task_display td
      JOIN ref.setup_task t2 ON t2.setup_task_id = td.setup_task_id
      WHERE t2.stage_id = s.stage_id) AS explicit_owner_rows
FROM ref.stage AS s
JOIN ref.setup_task AS t
  ON t.stage_id = s.stage_id
WHERE s.stage_key = '26'
  AND t.task_name IN (
      'Layout / Erect Frame / Strap Down',
      'Install Skins and Bungees',
      'Install Lighting, Cameras, Mats, Signs, and Finish Setup'
  )
GROUP BY s.stage_id;
