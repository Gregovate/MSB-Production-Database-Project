/*
Filename: setup_assignment_layer_disposable_validation.sql
Issue: #141

DISPOSABLE CURRENT-PRODUCTION CLONE ONLY.

Purpose:
  Validate the corrected assignment layer from the real untouched Production
  starting state. Unlike the rejected V0.3.12 browser seed, this validation does
  NOT pre-enable Magic Igloo material flags before exercising assignment.

All test mutations are rolled back so the same disposable clone remains in the
untouched state for operator browser review.
*/

\set ON_ERROR_STOP on

BEGIN;

DO $validation$
DECLARE
    v_manager_email text;
    v_stage_id integer;
    v_frame_task_id bigint;
    v_skins_task_id bigint;
    v_finish_task_id bigint;
    v_display_id bigint;
    v_source_count integer;
    v_2026_before integer;
    v_2026_after integer;
    v_arch_rows_before integer;
    v_arch_rows_after integer;
    v_nonkit_rejected boolean := false;
BEGIN
    IF to_regprocedure('ref.set_setup_task_display_owner(text,bigint,bigint,bigint)') IS NULL THEN
        RAISE EXCEPTION 'Corrected Display-owner command is missing';
    END IF;
    IF to_regprocedure('ref.set_setup_task_kit_box_assignment(text,bigint,integer,boolean,text)') IS NULL THEN
        RAISE EXCEPTION 'Kit Box assignment command is missing';
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

    SELECT t.setup_task_id INTO v_frame_task_id
    FROM ref.setup_task AS t
    WHERE t.stage_id = v_stage_id
      AND t.task_name = 'Layout / Erect Frame / Strap Down'
      AND t.active_flag
    ORDER BY t.setup_task_id
    LIMIT 1;

    SELECT t.setup_task_id INTO v_skins_task_id
    FROM ref.setup_task AS t
    WHERE t.stage_id = v_stage_id
      AND t.task_name = 'Install Skins and Bungees'
      AND t.active_flag
    ORDER BY t.setup_task_id
    LIMIT 1;

    SELECT t.setup_task_id INTO v_finish_task_id
    FROM ref.setup_task AS t
    WHERE t.stage_id = v_stage_id
      AND t.task_name = 'Install Lighting, Cameras, Mats, Signs, and Finish Setup'
      AND t.active_flag
    ORDER BY t.setup_task_id
    LIMIT 1;

    IF v_frame_task_id IS NULL OR v_skins_task_id IS NULL OR v_finish_task_id IS NULL THEN
        RAISE EXCEPTION 'Representative Magic Igloo tasks are incomplete';
    END IF;

    /* This is the exact first-use condition that the rejected seed concealed. */
    IF EXISTS (
        SELECT 1
        FROM ref.setup_task AS t
        WHERE t.setup_task_id IN (v_frame_task_id, v_skins_task_id, v_finish_task_id)
          AND t.requires_display_material
    ) THEN
        RAISE EXCEPTION 'Untouched-clone validation requires the three Magic Igloo proof tasks to begin material=false';
    END IF;

    IF EXISTS (
        SELECT 1
        FROM ref.setup_task_display AS td
        JOIN ref.setup_task AS t
          ON t.setup_task_id = td.setup_task_id
        WHERE t.stage_id = v_stage_id
    ) THEN
        RAISE EXCEPTION 'Untouched-clone validation requires Stage 26 to begin with no explicit Display ownership rows';
    END IF;

    SELECT count(*) INTO v_2026_before
    FROM ops.setup_session AS ss
    WHERE ss.season_year = 2026;

    SELECT count(*) INTO v_arch_rows_before
    FROM ref.setup_task_container_support AS tc
    WHERE tc.container_id = 34;

    CREATE TEMP TABLE proof_source_display (
        display_id bigint PRIMARY KEY,
        container_id integer
    ) ON COMMIT DROP;

    INSERT INTO proof_source_display(display_id, container_id)
    SELECT DISTINCT d.display_id, d.container_id
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
    ORDER BY d.display_id;

    SELECT count(*), min(display_id)
      INTO v_source_count, v_display_id
    FROM proof_source_display;

    IF v_source_count < 1 OR v_display_id IS NULL THEN
        RAISE EXCEPTION 'Stage 26 current LOR source set is empty';
    END IF;

    /*
    First assignment must work while the frame task is still material=false and
    must establish the flag automatically.
    */
    PERFORM *
    FROM ref.set_setup_task_display_owner(
        v_manager_email,
        v_display_id,
        v_frame_task_id,
        NULL
    );

    IF NOT EXISTS (
        SELECT 1 FROM ref.setup_task
        WHERE setup_task_id = v_frame_task_id
          AND requires_display_material
    ) THEN
        RAISE EXCEPTION 'First Display assignment did not automatically enable the target task material flag';
    END IF;

    IF NOT EXISTS (
        SELECT 1
        FROM ref.setup_task_display
        WHERE display_id = v_display_id
          AND setup_task_id = v_frame_task_id
    ) THEN
        RAISE EXCEPTION 'First Display assignment row was not created';
    END IF;

    /* Moving to another previously-false task must auto-enable that task too. */
    PERFORM *
    FROM ref.set_setup_task_display_owner(
        v_manager_email,
        v_display_id,
        v_skins_task_id,
        v_frame_task_id
    );

    IF NOT EXISTS (
        SELECT 1 FROM ref.setup_task
        WHERE setup_task_id = v_skins_task_id
          AND requires_display_material
    ) THEN
        RAISE EXCEPTION 'Display move did not automatically enable the destination task material flag';
    END IF;

    IF (SELECT count(*) FROM ref.setup_task_display WHERE display_id = v_display_id) <> 1 THEN
        RAISE EXCEPTION 'Display ownership is not exclusive after move';
    END IF;

    IF EXISTS (
        SELECT 1
        FROM proof_source_display AS src
        JOIN ref.display AS d
          ON d.display_id = src.display_id
        WHERE d.container_id IS DISTINCT FROM src.container_id
    ) THEN
        RAISE EXCEPTION 'Display assignment changed ref.display.container_id';
    END IF;

    /* Kit Box 35 is a real Production Kit Box and may support multiple tasks. */
    IF NOT EXISTS (
        SELECT 1
        FROM ref.container AS c
        WHERE c.container_id = 35
          AND c.container_type_id = 2
    ) THEN
        RAISE EXCEPTION 'Proof Kit Box container 35 is missing or is no longer type 2';
    END IF;

    PERFORM *
    FROM ref.set_setup_task_kit_box_assignment(
        v_manager_email,
        v_frame_task_id,
        35,
        true,
        'Disposable #141 assignment proof.'
    );

    PERFORM *
    FROM ref.set_setup_task_kit_box_assignment(
        v_manager_email,
        v_skins_task_id,
        35,
        true,
        'Disposable #141 shared-Kit proof.'
    );

    IF (
        SELECT count(*)
        FROM ref.setup_task_container_support AS tc
        WHERE tc.container_id = 35
          AND tc.relationship_type = 'KIT'
          AND tc.setup_task_id IN (v_frame_task_id, v_skins_task_id)
    ) <> 2 THEN
        RAISE EXCEPTION 'Kit Box 35 did not retain many-to-many task assignments';
    END IF;

    /* Non-Kit Container 34 must never be accepted through the KIT command. */
    BEGIN
        PERFORM *
        FROM ref.set_setup_task_kit_box_assignment(
            v_manager_email,
            v_frame_task_id,
            34,
            true,
            'Must be rejected.'
        );
    EXCEPTION
        WHEN check_violation THEN
            v_nonkit_rejected := true;
    END;

    IF NOT v_nonkit_rejected THEN
        RAISE EXCEPTION 'Non-Kit container 34 was incorrectly accepted as a KIT assignment';
    END IF;

    SELECT count(*) INTO v_arch_rows_after
    FROM ref.setup_task_container_support AS tc
    WHERE tc.container_id = 34;

    IF v_arch_rows_after <> v_arch_rows_before THEN
        RAISE EXCEPTION 'Existing Arch Trailer SUPPORT / REQUIRED_CONTAINER relationships changed';
    END IF;

    SELECT count(*) INTO v_2026_after
    FROM ops.setup_session AS ss
    WHERE ss.season_year = 2026;

    IF v_2026_after <> v_2026_before THEN
        RAISE EXCEPTION '#141 assignment validation created or changed a 2026 Setup Session';
    END IF;

    RAISE NOTICE 'Corrected #141 assignment proof passed: Stage 26 source Displays=%, proof Display=%, shared Kit Box=35',
        v_source_count, v_display_id;
END
$validation$;

ROLLBACK;

SELECT 'SETUP_ASSIGNMENT_LAYER_DISPOSABLE_VALIDATION_PASS' AS result;
