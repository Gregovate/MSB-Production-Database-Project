/* ============================================================================
MSB Setup Session — protected application read grants
Issue: #122
Revision: 2026-09-06 V0.1.0

Purpose:
  Allow the protected Setup backend to read only the Setup/reference data it
  presents. Browser authorization is still resolved through
  ref.setup_browser_capabilities(text).

Security:
  - No INSERT/UPDATE/DELETE grants are added.
  - Directus system tables remain hidden from fieldwiring_app.
  - Setup writes continue to use narrow SECURITY DEFINER commands.
============================================================================ */

BEGIN;

DO $preflight$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'fieldwiring_app') THEN
        RAISE EXCEPTION 'Required existing application role fieldwiring_app does not exist';
    END IF;

    IF to_regclass('ref.setup_task') IS NULL
       OR to_regclass('ops.setup_session') IS NULL
       OR to_regclass('ops.setup_session_task') IS NULL THEN
        RAISE EXCEPTION 'Setup core schema must be installed before read grants';
    END IF;
END
$preflight$;

GRANT USAGE ON SCHEMA ref, ops TO fieldwiring_app;

GRANT SELECT ON TABLE
    ref.season,
    ref.stage,
    ref.setup_task,
    ref.setup_task_dependency,
    ref.setup_task_display,
    ref.setup_task_container_support,
    ref.setup_task_captain,
    ref.setup_resource,
    ref.setup_task_resource,
    ops.setup_session,
    ops.setup_session_task,
    ops.setup_work_day,
    ops.setup_work_day_task,
    ops.setup_container_state,
    ops.setup_display_state,
    ops.setup_movement_event,
    ops.setup_movement_event_display
TO fieldwiring_app;

COMMIT;

SELECT
    has_table_privilege('fieldwiring_app', 'ref.setup_task', 'SELECT')
        AS can_read_setup_task,
    has_table_privilege('fieldwiring_app', 'ops.setup_session_task', 'SELECT')
        AS can_read_setup_session_task,
    has_table_privilege('fieldwiring_app', 'ops.setup_movement_event', 'SELECT')
        AS can_read_setup_movement,
    has_table_privilege('fieldwiring_app', 'ref.setup_task', 'UPDATE')
        AS broad_setup_task_update,
    has_table_privilege('fieldwiring_app', 'ops.setup_movement_event', 'INSERT')
        AS broad_movement_insert;
