-- #88 Container Movement report prerequisite. Migration 070 is reserved for
-- the separate, unmerged guided-contents workflow; this does not require it.
-- No structure, master data, movement events, or write privileges change.
-- Production application requires the database-changing deployment runbook.
BEGIN;
SET LOCAL lock_timeout = '3s';
SET LOCAL statement_timeout = '30s';

DO $preflight$
BEGIN
    IF to_regclass('ref.container_type') IS NULL
       OR NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'fieldwiring_app') THEN
        RAISE EXCEPTION 'Container type reference and Setup runtime role are required';
    END IF;
END
$preflight$;

GRANT SELECT (container_type_id, container_type_name)
    ON TABLE ref.container_type TO fieldwiring_app;

COMMIT;

SELECT has_column_privilege('fieldwiring_app', 'ref.container_type',
                           'container_type_id', 'SELECT') AS can_read_type_id,
       has_column_privilege('fieldwiring_app', 'ref.container_type',
                           'container_type_name', 'SELECT') AS can_read_type_name;
