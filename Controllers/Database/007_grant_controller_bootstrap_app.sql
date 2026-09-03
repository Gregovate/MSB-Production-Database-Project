/* ============================================================================
Controller Inventory bootstrap application least-privilege grants
Issue: #110

Precondition:
  Existing LOGIN role controller_inventory_app has been created separately and,
  for person attribution, mapped through ref.person.pg_login_name under the
  existing audit model.

Scope:
  The bootstrap browser may edit only stage.controller_bootstrap*.
  Permanent ref.controller promotion is intentionally NOT granted here.
============================================================================ */

BEGIN;

DO $role_check$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_roles
        WHERE rolname = 'controller_inventory_app'
          AND rolcanlogin
    ) THEN
        RAISE EXCEPTION
            'Required LOGIN role controller_inventory_app does not exist';
    END IF;
END
$role_check$;

GRANT CONNECT ON DATABASE msb TO controller_inventory_app;
GRANT USAGE ON SCHEMA stage, ref TO controller_inventory_app;

GRANT SELECT, INSERT, UPDATE, DELETE ON
    stage.controller_bootstrap,
    stage.controller_bootstrap_display
TO controller_inventory_app;

GRANT SELECT ON
    stage.v_controller_bootstrap_review,
    ref.display,
    ref.controller_model,
    ref.controller_status,
    ref.controller_firmware_version,
    ref.controller,
    ref.controller_display
TO controller_inventory_app;

GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA stage
TO controller_inventory_app;

GRANT EXECUTE ON FUNCTION stage.prepare_controller_bootstrap_order()
TO controller_inventory_app;

-- Actor triggers on the stage tables call the existing shared audit functions.
GRANT EXECUTE ON FUNCTION ref.set_actor_on_insert()
TO controller_inventory_app;
GRANT EXECUTE ON FUNCTION ref.set_actor_on_update()
TO controller_inventory_app;
GRANT EXECUTE ON FUNCTION ref.resolve_actor()
TO controller_inventory_app;

-- No INSERT/UPDATE/DELETE grant on ref.controller* is provided to the browser.
-- No DDL privilege is granted.

COMMIT;
