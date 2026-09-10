\set ON_ERROR_STOP on

DO $validation$
DECLARE
    v_display_setup_default text;
    v_scope_material_default text;
BEGIN
    IF NOT EXISTS (
        SELECT 1
        FROM information_schema.columns
        WHERE table_schema = 'ref'
          AND table_name = 'setup_task'
          AND column_name = 'is_display_setup_step'
          AND data_type = 'boolean'
          AND is_nullable = 'NO'
    ) THEN
        RAISE EXCEPTION 'ref.setup_task.is_display_setup_step boolean NOT NULL is missing';
    END IF;

    IF NOT EXISTS (
        SELECT 1
        FROM information_schema.columns
        WHERE table_schema = 'ref'
          AND table_name = 'setup_task'
          AND column_name = 'requires_display_material'
          AND data_type = 'boolean'
          AND is_nullable = 'NO'
    ) THEN
        RAISE EXCEPTION 'ref.setup_task.requires_display_material boolean NOT NULL is missing';
    END IF;

    SELECT column_default
      INTO v_display_setup_default
    FROM information_schema.columns
    WHERE table_schema = 'ref'
      AND table_name = 'setup_task'
      AND column_name = 'is_display_setup_step';

    SELECT column_default
      INTO v_scope_material_default
    FROM information_schema.columns
    WHERE table_schema = 'ref'
      AND table_name = 'setup_task'
      AND column_name = 'requires_display_material';

    IF v_display_setup_default IS DISTINCT FROM 'false'
       OR v_scope_material_default IS DISTINCT FROM 'false' THEN
        RAISE EXCEPTION 'Display Setup/material defaults are not both FALSE: display_setup=% scope_material=%',
            v_display_setup_default, v_scope_material_default;
    END IF;

    IF EXISTS (
        SELECT 1
        FROM ref.setup_task
        WHERE is_display_setup_step
           OR requires_display_material
    ) THEN
        RAISE EXCEPTION 'Migration 025 must not infer/backfill Display Setup/material flags';
    END IF;

    IF NOT has_function_privilege(
        'fieldwiring_app',
        'ref.set_setup_task_display_setup_step(text,bigint,boolean)',
        'EXECUTE'
    ) THEN
        RAISE EXCEPTION 'fieldwiring_app cannot execute governed Display Setup classifier';
    END IF;

    IF NOT has_function_privilege(
        'fieldwiring_app',
        'ref.set_setup_task_display_material_requirement(text,bigint,boolean)',
        'EXECUTE'
    ) THEN
        RAISE EXCEPTION 'fieldwiring_app cannot execute governed Display material switch';
    END IF;

    IF has_table_privilege('fieldwiring_app', 'ref.setup_task', 'UPDATE') THEN
        RAISE EXCEPTION 'fieldwiring_app unexpectedly has broad ref.setup_task UPDATE';
    END IF;

    IF EXISTS (
        SELECT 1
        FROM ref.setup_task t
        LEFT JOIN ref.lor_scene ls
          ON ls.lor_scene_id = t.lor_scene_id
         AND ls.stage_id = t.stage_id
        WHERE t.active_flag
          AND t.lor_scene_id IS NOT NULL
          AND ls.lor_scene_id IS NULL
    ) THEN
        RAISE EXCEPTION 'Active reusable task has invalid Stage/Scene pairing';
    END IF;

    IF EXISTS (SELECT 1 FROM ops.setup_session WHERE season_year >= 2026) THEN
        RAISE EXCEPTION 'A 2026-or-later Setup Session exists during reconstruction acceptance';
    END IF;

    RAISE NOTICE 'SETUP_DISPLAY_MATERIAL_DISPOSABLE_VALIDATION_PASS';
END
$validation$;
