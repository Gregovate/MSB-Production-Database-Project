/* ============================================================================
Controller Inventory — validate simplified Directus Controller metadata
Issue: #110

READ ONLY.
============================================================================ */

\echo '=== Simplified Controller Directus boundary ==='
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
    has_table_privilege('directus_app','ref.controller','SELECT') AS controller_read,
    has_table_privilege('directus_app','ref.controller','INSERT') AS controller_create,
    has_table_privilege('directus_app','ref.controller','UPDATE') AS controller_update,
    has_table_privilege('directus_app','ref.controller','DELETE') AS controller_delete;

\echo '=== Simple Controller controls retained ==='
SELECT field, interface, readonly, hidden, "group"
FROM public.directus_fields
WHERE collection='controller'
  AND field IN (
      'controller_model_id',
      'controller_status_id',
      'current_location_code',
      'installed_firmware_version_id',
      'label_required',
      'print_label',
      'lor_network',
      'management_ip'
  )
ORDER BY field;

\echo '=== Assignment key unchanged ==='
SELECT c.conname, pg_get_constraintdef(c.oid) AS definition
FROM pg_constraint c
WHERE c.conrelid='ref.controller_display'::regclass
  AND c.contype='p';

\echo '=== Validation assertions ==='
DO $assertions$
BEGIN
    IF EXISTS (
        SELECT 1 FROM public.directus_fields
        WHERE collection='controller' AND field IN ('display_assignments','firmware_history')
    ) THEN
        RAISE EXCEPTION 'Complex reverse Controller aliases should not be present';
    END IF;

    IF has_table_privilege('directus_app','ref.controller_display','DELETE') THEN
        RAISE EXCEPTION 'Directus assignment DELETE should be revoked';
    END IF;

    IF NOT has_table_privilege('directus_app','ref.controller','SELECT')
       OR NOT has_table_privilege('directus_app','ref.controller','INSERT')
       OR NOT has_table_privilege('directus_app','ref.controller','UPDATE')
       OR has_table_privilege('directus_app','ref.controller','DELETE') THEN
        RAISE EXCEPTION 'Controller simple CRUD/no-delete boundary is incorrect';
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint c
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
        RAISE EXCEPTION 'Controller model lookup is not configured';
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM public.directus_fields
        WHERE collection='controller' AND field='print_label' AND interface='boolean'
    ) THEN
        RAISE EXCEPTION 'Controller print_label boolean is not configured';
    END IF;
END
$assertions$;

\echo 'DIRECTUS CONTROLLER SIMPLIFICATION: PASS'
