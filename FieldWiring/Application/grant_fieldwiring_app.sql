/* ============================================================================
Object:       FieldWiring application least-privilege grants
Filename:     grant_fieldwiring_app.sql
Revision:     2026-08-30 V0.2.0

Purpose:
  Grant the existing login role fieldwiring_app only the read access required
  by the FieldWiring production browser/API, including the read-only permanent
  Controller Inventory browser.

Security contract:
  - FieldWiring is read-only.
  - No INSERT, UPDATE, DELETE, TRUNCATE, DDL, function, or procedure execution
    is granted by this script.
  - The application also opens every PostgreSQL session as read-only.
  - default_transaction_read_only is set on the login as an independent DB
    backstop.
  - No stage.controller_* bootstrap relation is granted.
============================================================================ */

BEGIN;

DO $block$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'fieldwiring_app') THEN
        RAISE EXCEPTION
            'Role fieldwiring_app does not exist; create the LOGIN separately with a secured password';
    END IF;
END;
$block$;

ALTER ROLE fieldwiring_app SET default_transaction_read_only = on;

GRANT CONNECT ON DATABASE msb TO fieldwiring_app;
GRANT USAGE ON SCHEMA ref, lor_snap TO fieldwiring_app;

GRANT SELECT ON
    ref.display,
    ref.stage,
    ref.lor_scene,
    ref.lor_scene_display,
    ref.person,
    ref.controller,
    ref.controller_model,
    ref.controller_status,
    ref.controller_firmware_version,
    ref.controller_display,
    ref.controller_firmware_history,
    lor_snap.v_current_props,
    lor_snap.v_current_previews,
    lor_snap.v_current_scenes,
    lor_snap.v_current_scene_lor_props,
    lor_snap.preview_wiring_fieldlead_v6,
    lor_snap.v_current_run,
    lor_snap.v_current_dmx_channels
TO fieldwiring_app;

COMMIT;

SELECT
    '2026-08-30-fieldwiring-app-grants-v0.2.0' AS applied_revision,
    current_user AS applied_by;
