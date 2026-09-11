/* ============================================================================
MSB Setup Session — Scene/material field-context read grants
Issue: #122
Status: IMPLEMENTATION CANDIDATE — DO NOT APPLY TO PRODUCTION WITHOUT REVIEW
Revision: 2026-09-07 V0.3.2

Purpose:
  Make the Setup Captain field-context resolver self-contained. Scene-scoped
  tasks now derive current physical Displays through ref.lor_scene_display and
  then resolve the permanent Display -> Container -> home-location relationship.

Security:
  Read-only grants only. No new DML is granted.
============================================================================ */

BEGIN;

DO $preflight$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'fieldwiring_app') THEN
        RAISE EXCEPTION 'Required application role fieldwiring_app does not exist';
    END IF;

    IF to_regclass('ref.display') IS NULL
       OR to_regclass('ref.container') IS NULL
       OR to_regclass('ref.lor_scene') IS NULL
       OR to_regclass('ref.lor_scene_display') IS NULL THEN
        RAISE EXCEPTION 'Permanent Display/Container/Scene field-context tables are required';
    END IF;
END
$preflight$;

GRANT USAGE ON SCHEMA ref TO fieldwiring_app;
GRANT SELECT ON TABLE
    ref.display,
    ref.container,
    ref.lor_scene,
    ref.lor_scene_display
TO fieldwiring_app;

COMMIT;

SELECT
    has_table_privilege('fieldwiring_app', 'ref.lor_scene_display', 'SELECT')
        AS can_read_scene_display,
    has_table_privilege('fieldwiring_app', 'ref.display', 'UPDATE')
        AS broad_display_update,
    has_table_privilege('fieldwiring_app', 'ref.container', 'UPDATE')
        AS broad_container_update;
