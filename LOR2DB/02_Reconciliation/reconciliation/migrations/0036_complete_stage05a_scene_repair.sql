/* ============================================================================
Migration: 0036_complete_stage05a_scene_repair.sql

Purpose:
  Complete the Stage 05/05a production-reference repair begun by migration
  0035.  Migration 0035 separated the permanent stages, binding, and display,
  but left the already-existing Mega Star ref.lor_scene row assigned to Stage
  05.  This guarded follow-up moves only that permanent Scene to Stage 05a.

Safety:
  - The repair accepts only the exact known Stage, binding, display, and Scene
    identities.
  - It is idempotent when the Scene is already assigned to Stage 05a.
  - Captured lor_snap data and frozen reconciliation evidence are untouched.
============================================================================ */

BEGIN;

DO $repair$
DECLARE
    v_stage_05 integer;
    v_stage_05a integer;
    v_current_scene_stage integer;
    v_updated_count integer;
BEGIN
    SELECT s.stage_id INTO STRICT v_stage_05
    FROM ref.stage AS s
    WHERE s.stage_id = 35
      AND s.stage_key = '05'
      AND s.stage_name = 'RGB Plus Stage 05 Festive Trees Traditional'
      AND s.folder_name = '05-RGB Plus Stage 05 Festive Trees Traditional'
      AND s.park_order = 5
      AND s.sub_order = 0;

    SELECT s.stage_id INTO STRICT v_stage_05a
    FROM ref.stage AS s
    WHERE s.stage_key = '05a'
      AND s.stage_name = 'RGB Plus Stage 05a Mega Star'
      AND s.folder_name = '05a-RGB Plus Stage 05a Mega Star'
      AND s.park_order = 5
      AND s.sub_order = 1;

    IF v_stage_05 = v_stage_05a THEN
        RAISE EXCEPTION 'Stage 05 and 05a do not have distinct permanent identities';
    END IF;

    IF NOT EXISTS (
        SELECT 1
        FROM ref.stage_lor_binding AS b
        WHERE b.stage_lor_binding_id = 143
          AND b.stage_id = v_stage_05a
          AND b.binding_type = 'SCENE'
          AND b.preview_id = 'fcf5c29c-8d51-46c5-9ad0-cc47a97c75bd'
          AND b.scene_id = 'd57761f7-3527-4b00-a8ce-2eeb70eb3d8c'
          AND b.accepted_source_stage_key = '05a'
    ) THEN
        RAISE EXCEPTION 'Stage 05a Scene binding does not match the repaired incident identity';
    END IF;

    IF NOT EXISTS (
        SELECT 1
        FROM ref.display AS d
        WHERE d.display_id = 869
          AND d.display_name = 'FT-MegaStar'
          AND d.stage_id = v_stage_05a
    ) THEN
        RAISE EXCEPTION 'FT-MegaStar is not assigned to the repaired Stage 05a identity';
    END IF;

    SELECT ls.stage_id INTO STRICT v_current_scene_stage
    FROM ref.lor_scene AS ls
    WHERE ls.preview_uuid = 'fcf5c29c-8d51-46c5-9ad0-cc47a97c75bd'
      AND ls.scene_uuid = 'd57761f7-3527-4b00-a8ce-2eeb70eb3d8c'
      AND ls.scene_name = '05a-Mega Star-MS';

    IF v_current_scene_stage = v_stage_05a THEN
        RAISE NOTICE 'Stage 05a permanent Scene repair is already present; repair skipped';
        RETURN;
    END IF;

    IF v_current_scene_stage <> v_stage_05 THEN
        RAISE EXCEPTION
            'Stage 05a Scene repair guard failed: current stage_id is %, expected %',
            v_current_scene_stage, v_stage_05;
    END IF;

    UPDATE ref.lor_scene AS ls
       SET stage_id = v_stage_05a,
           updated_at = now(),
           updated_by = current_user
     WHERE ls.preview_uuid = 'fcf5c29c-8d51-46c5-9ad0-cc47a97c75bd'
       AND ls.scene_uuid = 'd57761f7-3527-4b00-a8ce-2eeb70eb3d8c'
       AND ls.scene_name = '05a-Mega Star-MS'
       AND ls.stage_id = v_stage_05;

    GET DIAGNOSTICS v_updated_count = ROW_COUNT;
    IF v_updated_count <> 1 THEN
        RAISE EXCEPTION
            'Stage 05a Scene repair changed % rows, expected exactly 1',
            v_updated_count;
    END IF;
END;
$repair$;

COMMIT;

SELECT
    '2026-08-17-complete-stage05a-scene-repair-v1'::text
        AS installed_revision,
    s.stage_id AS stage_05a_id,
    ls.lor_scene_id,
    ls.scene_name
FROM ref.lor_scene AS ls
JOIN ref.stage AS s ON s.stage_id = ls.stage_id
WHERE ls.preview_uuid = 'fcf5c29c-8d51-46c5-9ad0-cc47a97c75bd'
  AND ls.scene_uuid = 'd57761f7-3527-4b00-a8ce-2eeb70eb3d8c'
  AND s.stage_key = '05a';
