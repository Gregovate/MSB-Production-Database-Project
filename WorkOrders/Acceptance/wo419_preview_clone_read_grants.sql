-- WO419-CG01 | Disposable Work Management browser reader grants | CLONE ONLY
-- This is a clone-only acceptance fixture, NOT a Production migration.
-- Apply via the existing Server Management disposable-clone runner *after*
-- restoring the current Production dump and creating clone login fieldwiring_app.
-- Full-table SELECT is intentionally limited to the disposable testing role.
-- NEVER apply to Production. The eventual Production app needs governed
-- least-privilege reader views/commands and a dedicated permission review.
BEGIN;

DO $$
BEGIN
    IF current_database() = 'msb'
       OR current_database() NOT LIKE 'msb\_%' ESCAPE '\'
       OR current_setting('msb.wo419_preview_authorized', true)
          IS DISTINCT FROM 'approved_disposable_clone' THEN
        RAISE EXCEPTION
            'WO419 HOLD: clone-only grants require a separate msb_* disposable database and approved runner session marker';
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname='fieldwiring_app') THEN
        RAISE EXCEPTION 'WO419 HOLD: clone application role fieldwiring_app not installed';
    END IF;
    IF to_regprocedure('ref.setup_browser_capabilities(text)') IS NULL THEN
        RAISE EXCEPTION 'WO419 HOLD: current Setup capability contract missing on clone';
    END IF;
END
$$;

GRANT USAGE ON SCHEMA ref, ops, stage TO fieldwiring_app;

GRANT SELECT ON
    ref.person,
    ref.stage,
    ref.work_area,
    ref.work_order_status,
    ref.task_type,
    ref.container,
    ref.display,
    ref.setup_task,
    ref.setup_task_container_support,
    ref.setup_task_display,
    ref.setup_task_extra_material,
    ref.setup_extra_material,
    ref.lor_scene,
    ref.lor_scene_display,
    ops.work_order,
    ops.work_order_assignment,
    ops.work_order_status_history,
    stage.work_order_intake
TO fieldwiring_app;

GRANT EXECUTE ON FUNCTION ref.setup_browser_capabilities(text)
TO fieldwiring_app;

COMMIT;

-- Applying this file is not evidence of browser/identity acceptance.
-- This is *not* a role/grant migration authorized on the live msb database.
