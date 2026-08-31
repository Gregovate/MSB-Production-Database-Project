/* ============================================================================
Controller Inventory bootstrap application role validation
Issue: #110

Read-only acceptance check. Run after 007 grant script.
============================================================================ */

BEGIN;
SET LOCAL ROLE controller_inventory_app;
SET TRANSACTION READ WRITE;

SELECT
    has_schema_privilege(current_user, 'stage', 'USAGE') AS stage_usage,
    has_table_privilege(current_user, 'stage.controller_bootstrap', 'SELECT') AS can_read_stage,
    has_table_privilege(current_user, 'stage.controller_bootstrap', 'INSERT') AS can_insert_stage,
    has_table_privilege(current_user, 'stage.controller_bootstrap', 'UPDATE') AS can_update_stage,
    has_table_privilege(current_user, 'stage.controller_bootstrap', 'DELETE') AS can_delete_stage,
    has_table_privilege(current_user, 'ref.display', 'SELECT') AS can_read_display,
    has_table_privilege(current_user, 'ref.controller', 'SELECT') AS can_read_controller,
    has_table_privilege(current_user, 'ref.controller', 'INSERT') AS can_insert_controller,
    has_table_privilege(current_user, 'ref.controller', 'UPDATE') AS can_update_controller,
    has_table_privilege(current_user, 'ref.controller', 'DELETE') AS can_delete_controller;

-- Browser-facing review query under the actual least-privilege role.
SELECT count(*) AS review_rows
FROM stage.v_controller_bootstrap_review;

ROLLBACK;
