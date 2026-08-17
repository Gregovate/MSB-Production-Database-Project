/* ============================================================================
Validation: Complete Stage 05a Scene repair

Safety: Read-only.  This script changes no production or audit data.
============================================================================ */

DO $validation$
DECLARE
    v_stage_05 integer;
    v_stage_05a integer;
BEGIN
    SELECT s.stage_id INTO STRICT v_stage_05
    FROM ref.stage AS s
    WHERE s.stage_id = 35
      AND s.stage_key = '05';

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
          AND b.scene_id = 'd57761f7-3527-4b00-a8ce-2eeb70eb3d8c'
          AND b.accepted_source_stage_key = '05a'
    ) THEN
        RAISE EXCEPTION 'Stage 05a binding is not assigned to the permanent Stage 05a identity';
    END IF;

    IF NOT EXISTS (
        SELECT 1
        FROM ref.display AS d
        WHERE d.display_id = 869
          AND d.display_name = 'FT-MegaStar'
          AND d.stage_id = v_stage_05a
    ) THEN
        RAISE EXCEPTION 'FT-MegaStar is not assigned to permanent Stage 05a';
    END IF;

    IF NOT EXISTS (
        SELECT 1
        FROM ref.lor_scene AS ls
        WHERE ls.preview_uuid = 'fcf5c29c-8d51-46c5-9ad0-cc47a97c75bd'
          AND ls.scene_uuid = 'd57761f7-3527-4b00-a8ce-2eeb70eb3d8c'
          AND ls.scene_name = '05a-Mega Star-MS'
          AND ls.stage_id = v_stage_05a
    ) THEN
        RAISE EXCEPTION 'Mega Star permanent Scene is not assigned to Stage 05a';
    END IF;

    IF NOT EXISTS (
        SELECT 1
        FROM ref.lor_scene AS ls
        WHERE ls.preview_uuid = 'fcf5c29c-8d51-46c5-9ad0-cc47a97c75bd'
          AND ls.scene_uuid = 'd4eeafb3-c355-44df-ab9e-e7566b29e0e7'
          AND ls.scene_name = '05-Festive Trees-FT'
          AND ls.stage_id = v_stage_05
    ) THEN
        RAISE EXCEPTION 'Festive Trees permanent Scene is not preserved on Stage 05';
    END IF;
END;
$validation$;

SELECT
    'PASS'::text AS validation_status,
    'Stage 05a binding, display, and permanent Scene share one distinct stage identity; Stage 05 remains separate.'::text
        AS validation_detail;
