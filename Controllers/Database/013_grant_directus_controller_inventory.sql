/* ============================================================================
Controller Inventory — Directus database-role grants
Issue: #110

Purpose:
  Allow Directus managers to maintain the permanent Controller Inventory while
  enforcing the no-delete rule at the PostgreSQL role boundary.

Directus application policy should mirror this database contract:
  READ   yes
  CREATE yes
  UPDATE yes
  DELETE no

This script grants the database login role used by Directus (directus_app).
It does not configure Directus collection/policy metadata itself.
============================================================================ */

BEGIN;

DO $role_check$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'directus_app') THEN
        RAISE EXCEPTION 'Required PostgreSQL role directus_app does not exist';
    END IF;
END
$role_check$;

GRANT USAGE ON SCHEMA ref TO directus_app;

GRANT SELECT, INSERT, UPDATE ON
    ref.controller,
    ref.controller_model,
    ref.controller_status,
    ref.controller_firmware_version,
    ref.controller_display,
    ref.controller_firmware_history
TO directus_app;

-- Explicit hard backstop: Controller Inventory is retained, not deleted.
REVOKE DELETE, TRUNCATE ON
    ref.controller,
    ref.controller_model,
    ref.controller_status,
    ref.controller_firmware_version,
    ref.controller_display,
    ref.controller_firmware_history
FROM directus_app;

-- Directus needs lookup reads to render governed foreign-key choices.
GRANT SELECT ON
    ref.display,
    ref.person,
    ref.storage_location,
    ref.label_template
TO directus_app;

-- Identity sequences owned only by the Controller Inventory subsystem.
GRANT USAGE, SELECT ON SEQUENCE
    ref.controller_controller_id_seq,
    ref.controller_model_controller_model_id_seq,
    ref.controller_status_controller_status_id_seq,
    ref.controller_firmware_version_controller_firmware_version_id_seq,
    ref.controller_firmware_history_controller_firmware_history_id_seq
TO directus_app;

COMMIT;

SELECT
    has_table_privilege('directus_app', 'ref.controller', 'SELECT') AS controller_read,
    has_table_privilege('directus_app', 'ref.controller', 'INSERT') AS controller_create,
    has_table_privilege('directus_app', 'ref.controller', 'UPDATE') AS controller_update,
    has_table_privilege('directus_app', 'ref.controller', 'DELETE') AS controller_delete;
