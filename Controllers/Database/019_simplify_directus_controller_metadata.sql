/* ============================================================================
Controller Inventory — simplify Directus Controller metadata
Issue: #110

Architecture decision:
  Directus is retained primarily for authentication/authorization and only
  secondarily for simple one-table maintenance. Multi-table Controller
  workflows belong in the purpose-built Controller application.

Purpose:
  Remove the complex reverse relationship workspaces added during the Directus
  management experiment while preserving simple Controller M2O lookups,
  booleans, metadata fields, and ordinary Controller create/read/update rights.

Changes:
  - remove Controller.display_assignments O2M alias;
  - remove Controller.firmware_history O2M alias;
  - remove reverse Directus relation metadata that drives those aliases;
  - remove Manager DELETE permission on controller_display;
  - revoke PostgreSQL DELETE on ref.controller_display from directus_app;
  - preserve ref.controller_display composite PK unchanged;
  - preserve all Controller assignment/history data unchanged.
============================================================================ */

BEGIN;

DO $preflight$
BEGIN
    IF to_regclass('public.directus_fields') IS NULL
       OR to_regclass('public.directus_relations') IS NULL
       OR to_regclass('public.directus_permissions') IS NULL
       OR to_regclass('public.directus_policies') IS NULL THEN
        RAISE EXCEPTION 'Required Directus metadata tables are missing';
    END IF;
END
$preflight$;

DELETE FROM public.directus_relations
WHERE many_collection='controller_display'
  AND many_field='controller_id'
  AND one_collection='controller'
  AND one_field='display_assignments';

DELETE FROM public.directus_relations
WHERE many_collection='controller_firmware_history'
  AND many_field='controller_id'
  AND one_collection='controller'
  AND one_field='firmware_history';

DELETE FROM public.directus_fields
WHERE collection='controller'
  AND field IN ('display_assignments','firmware_history');

DELETE FROM public.directus_permissions dp
USING public.directus_policies p
WHERE dp.policy=p.id
  AND p.name='Manager'
  AND dp.collection='controller_display'
  AND dp.action='delete';

REVOKE DELETE ON ref.controller_display FROM directus_app;

DO $assertions$
BEGIN
    IF EXISTS (
        SELECT 1 FROM public.directus_fields
        WHERE collection='controller' AND field IN ('display_assignments','firmware_history')
    ) THEN
        RAISE EXCEPTION 'Complex Controller reverse aliases still exist';
    END IF;

    IF has_table_privilege('directus_app','ref.controller_display','DELETE') THEN
        RAISE EXCEPTION 'directus_app should not retain assignment DELETE after simplification';
    END IF;

    IF NOT EXISTS (
        SELECT 1
        FROM pg_constraint c
        WHERE c.conrelid='ref.controller_display'::regclass
          AND c.contype='p'
          AND pg_get_constraintdef(c.oid)='PRIMARY KEY (controller_id, display_id)'
    ) THEN
        RAISE EXCEPTION 'Controller assignment composite PK changed unexpectedly';
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM public.directus_fields
        WHERE collection='controller' AND field='controller_model_id' AND interface='select-dropdown-m2o'
    ) THEN
        RAISE EXCEPTION 'Simple Controller model lookup should remain configured';
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM public.directus_fields
        WHERE collection='controller' AND field='print_label' AND interface='boolean'
    ) THEN
        RAISE EXCEPTION 'Simple Controller print_label boolean should remain configured';
    END IF;
END
$assertions$;

COMMIT;

SELECT
    EXISTS (
        SELECT 1 FROM public.directus_fields
        WHERE collection='controller' AND field='display_assignments'
    ) AS display_assignments_present,
    EXISTS (
        SELECT 1 FROM public.directus_fields
        WHERE collection='controller' AND field='firmware_history'
    ) AS firmware_history_present,
    has_table_privilege('directus_app','ref.controller_display','DELETE') AS directus_assignment_delete,
    (SELECT count(*) FROM ref.controller_display) AS assignment_rows,
    (SELECT count(*) FROM ref.controller_firmware_history) AS firmware_history_rows;
