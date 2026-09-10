\set ON_ERROR_STOP on

DO $validation$
DECLARE
    v_display_setup_default text;
    v_task_display_rows bigint;
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_schema = 'ref' AND table_name = 'setup_task'
          AND column_name = 'is_display_setup_step'
          AND data_type = 'boolean' AND is_nullable = 'NO'
    ) THEN
        RAISE EXCEPTION 'ref.setup_task.is_display_setup_step boolean NOT NULL is missing';
    END IF;

    IF EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_schema = 'ref' AND table_name = 'setup_task'
          AND column_name = 'requires_display_material'
    ) THEN
        RAISE EXCEPTION 'Rejected requires_display_material column must not exist in corrected candidate';
    END IF;

    IF to_regclass('ref.setup_task_material_source') IS NULL THEN
        RAISE EXCEPTION 'ref.setup_task_material_source is missing';
    END IF;

    SELECT column_default INTO v_display_setup_default
    FROM information_schema.columns
    WHERE table_schema = 'ref' AND table_name = 'setup_task'
      AND column_name = 'is_display_setup_step';

    IF v_display_setup_default IS DISTINCT FROM 'false' THEN
        RAISE EXCEPTION 'Display Setup default is not FALSE: %', v_display_setup_default;
    END IF;

    IF EXISTS (SELECT 1 FROM ref.setup_task WHERE is_display_setup_step) THEN
        RAISE EXCEPTION 'Migration 026 must not infer/backfill Display Setup classification';
    END IF;

    IF EXISTS (SELECT 1 FROM ref.setup_task_material_source) THEN
        RAISE EXCEPTION 'Migration 026 must not infer/backfill material sources from work scope';
    END IF;

    SELECT count(*) INTO v_task_display_rows FROM ref.setup_task_display;
    IF v_task_display_rows <> 0 THEN
        RAISE EXCEPTION
            'Disposable current-Production clone unexpectedly has % ref.setup_task_display rows; inventory before proceeding',
            v_task_display_rows;
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
        'ref.set_setup_task_material_source(text,bigint,text,text,boolean)',
        'EXECUTE'
    ) THEN
        RAISE EXCEPTION 'fieldwiring_app cannot execute governed material-source command';
    END IF;

    IF has_table_privilege('fieldwiring_app', 'ref.setup_task', 'UPDATE') THEN
        RAISE EXCEPTION 'fieldwiring_app unexpectedly has broad ref.setup_task UPDATE';
    END IF;

    IF has_table_privilege('fieldwiring_app', 'ref.setup_task_material_source', 'INSERT')
       OR has_table_privilege('fieldwiring_app', 'ref.setup_task_material_source', 'UPDATE')
       OR has_table_privilege('fieldwiring_app', 'ref.setup_task_material_source', 'DELETE') THEN
        RAISE EXCEPTION 'fieldwiring_app unexpectedly has direct material-source write privilege';
    END IF;

    IF EXISTS (SELECT 1 FROM ops.setup_session WHERE season_year >= 2026) THEN
        RAISE EXCEPTION 'A 2026-or-later Setup Session exists during reconstruction acceptance';
    END IF;

    RAISE NOTICE 'SETUP_EXPLICIT_LOR_MATERIAL_SOURCE_DISPOSABLE_VALIDATION_PASS';
END
$validation$;
