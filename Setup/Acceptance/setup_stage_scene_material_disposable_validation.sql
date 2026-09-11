/*
Filename: setup_stage_scene_material_disposable_validation.sql
Issue: #122
PR: #144

DISPOSABLE DATABASE ONLY.

Purpose:
  Prove that the established LOR Scene/group naming classification partitions
  the current Production-derived LOR membership into the operator-confirmed
  Stage-level versus real child-Scene material sets for Stages 00,01,02,13,16.

This script performs validation only. Run migration 025 in the disposable clone
before this validation.
*/

\set ON_ERROR_STOP on

DO $validation$
DECLARE
    r record;
    v_expected record;
    v_required_relation text;
BEGIN
    IF to_regclass('ref.setup_task') IS NULL
       OR to_regclass('ref.lor_scene') IS NULL
       OR to_regclass('ref.lor_scene_display') IS NULL
       OR to_regclass('ref.display') IS NULL
       OR to_regclass('ref.display_status') IS NULL THEN
        RAISE EXCEPTION 'Required Setup/LOR objects are missing';
    END IF;

    IF NOT EXISTS (
        SELECT 1
        FROM information_schema.columns
        WHERE table_schema = 'ref'
          AND table_name = 'setup_task'
          AND column_name = 'requires_display_material'
          AND is_nullable = 'NO'
    ) THEN
        RAISE EXCEPTION 'Migration 025 requires_display_material column is not installed as NOT NULL';
    END IF;

    IF to_regprocedure('ref.set_setup_task_display_material_requirement(text,bigint,boolean)') IS NULL THEN
        RAISE EXCEPTION 'Governed Display-material setter is missing';
    END IF;

    IF NOT has_function_privilege(
        'fieldwiring_app',
        'ref.set_setup_task_display_material_requirement(text,bigint,boolean)',
        'EXECUTE'
    ) THEN
        RAISE EXCEPTION 'fieldwiring_app cannot execute governed Display-material setter';
    END IF;

    FOREACH v_required_relation IN ARRAY ARRAY[
        'ref.setup_task',
        'ref.stage',
        'ref.lor_scene',
        'ref.lor_scene_display',
        'ref.setup_task_display',
        'ref.display',
        'ref.display_status',
        'ref.container',
        'ref.setup_task_container_support',
        'ops.setup_session',
        'ops.setup_display_state',
        'ops.setup_container_state'
    ]
    LOOP
        IF NOT has_table_privilege('fieldwiring_app', v_required_relation, 'SELECT') THEN
            RAISE EXCEPTION
                'fieldwiring_app cannot read % required by automatic material resolution',
                v_required_relation;
        END IF;
    END LOOP;

    IF has_table_privilege('fieldwiring_app', 'ref.display_status', 'UPDATE') THEN
        RAISE EXCEPTION 'Automatic material resolver must not grant UPDATE on ref.display_status';
    END IF;

    CREATE TEMP TABLE expected_material_partition (
        stage_key text PRIMARY KEY,
        expected_stage_level integer NOT NULL,
        expected_scene_level integer NOT NULL,
        expected_total integer NOT NULL
    ) ON COMMIT DROP;

    INSERT INTO expected_material_partition VALUES
        ('00', 11,  0, 11),
        ('01',  7,  7, 14),
        ('02', 10, 22, 32),
        ('13',  9, 29, 38),
        ('16', 66,  0, 66);

    CREATE TEMP TABLE actual_material_partition ON COMMIT DROP AS
    WITH classified_membership AS (
        SELECT DISTINCT
            s.stage_key,
            lsd.display_id,
            CASE
                WHEN lower(btrim(ls.scene_name)) = 'root' THEN 'STAGE'
                WHEN ls.scene_name !~ '^[[:space:]]*[0-9]{2}[A-Za-z]?-' THEN 'STAGE'
                WHEN ls.scene_name ~ '-[A-Za-z]{2}[[:space:]]*$' THEN 'STAGE'
                ELSE 'SCENE'
            END AS material_scope
        FROM ref.lor_scene AS ls
        JOIN ref.stage AS s
          ON s.stage_id = ls.stage_id
        JOIN ref.lor_scene_display AS lsd
          ON lsd.lor_scene_id = ls.lor_scene_id
        JOIN ref.display AS d
          ON d.display_id = lsd.display_id
        JOIN ref.display_status AS ds
          ON ds.display_status_id = d.display_status_id
        WHERE s.stage_key IN ('00','01','02','13','16')
          AND upper(ds.display_status_name) = 'ACTIVE'
    ),
    per_display AS (
        SELECT
            stage_key,
            display_id,
            bool_or(material_scope = 'STAGE') AS in_stage,
            bool_or(material_scope = 'SCENE') AS in_scene
        FROM classified_membership
        GROUP BY stage_key, display_id
    )
    SELECT
        stage_key,
        count(*) FILTER (WHERE in_stage) :: integer AS stage_level_count,
        count(*) FILTER (WHERE in_scene) :: integer AS scene_level_count,
        count(*) :: integer AS total_count,
        count(*) FILTER (WHERE in_stage AND in_scene) :: integer AS overlap_count
    FROM per_display
    GROUP BY stage_key;

    FOR v_expected IN
        SELECT * FROM expected_material_partition ORDER BY stage_key
    LOOP
        SELECT * INTO r
        FROM actual_material_partition
        WHERE stage_key = v_expected.stage_key;

        IF NOT FOUND THEN
            RAISE EXCEPTION 'Stage % missing from material partition', v_expected.stage_key;
        END IF;

        IF r.stage_level_count <> v_expected.expected_stage_level
           OR r.scene_level_count <> v_expected.expected_scene_level
           OR r.total_count <> v_expected.expected_total
           OR r.overlap_count <> 0 THEN
            RAISE EXCEPTION
                'Stage % material partition mismatch: stage=% scene=% total=% overlap=% expected stage=% scene=% total=%',
                v_expected.stage_key,
                r.stage_level_count,
                r.scene_level_count,
                r.total_count,
                r.overlap_count,
                v_expected.expected_stage_level,
                v_expected.expected_scene_level,
                v_expected.expected_total;
        END IF;
    END LOOP;
END
$validation$;

WITH classified_membership AS (
    SELECT DISTINCT
        s.stage_key,
        lsd.display_id,
        CASE
            WHEN lower(btrim(ls.scene_name)) = 'root' THEN 'STAGE'
            WHEN ls.scene_name !~ '^[[:space:]]*[0-9]{2}[A-Za-z]?-' THEN 'STAGE'
            WHEN ls.scene_name ~ '-[A-Za-z]{2}[[:space:]]*$' THEN 'STAGE'
            ELSE 'SCENE'
        END AS material_scope
    FROM ref.lor_scene AS ls
    JOIN ref.stage AS s
      ON s.stage_id = ls.stage_id
    JOIN ref.lor_scene_display AS lsd
      ON lsd.lor_scene_id = ls.lor_scene_id
    JOIN ref.display AS d
      ON d.display_id = lsd.display_id
    JOIN ref.display_status AS ds
      ON ds.display_status_id = d.display_status_id
    WHERE s.stage_key IN ('00','01','02','13','16')
      AND upper(ds.display_status_name) = 'ACTIVE'
),
per_display AS (
    SELECT
        stage_key,
        display_id,
        bool_or(material_scope = 'STAGE') AS in_stage,
        bool_or(material_scope = 'SCENE') AS in_scene
    FROM classified_membership
    GROUP BY stage_key, display_id
)
SELECT
    stage_key,
    count(*) FILTER (WHERE in_stage) AS stage_level_displays,
    count(*) FILTER (WHERE in_scene) AS scene_displays,
    count(*) AS total_displays,
    count(*) FILTER (WHERE in_stage AND in_scene) AS overlap_displays
FROM per_display
GROUP BY stage_key
ORDER BY stage_key;

SELECT 'SETUP_STAGE_SCENE_MATERIAL_DISPOSABLE_VALIDATION_PASS' AS result;
