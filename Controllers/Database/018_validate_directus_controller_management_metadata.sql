/* ============================================================================
Controller Inventory — Validate Directus management metadata
Issue: #110
READ ONLY.
============================================================================ */

\echo '=== Controller collection ==='
SELECT collection, icon, note, display_template, hidden, sort, collapse
FROM public.directus_collections
WHERE collection IN (
  'controller','controller_display','controller_model','controller_status',
  'controller_firmware_version','controller_firmware_history'
)
ORDER BY collection;

\echo '=== Controller management fields ==='
SELECT field, special, interface, readonly, hidden, sort, width, "group", required
FROM public.directus_fields
WHERE collection='controller'
ORDER BY CASE WHEN "group" IS NULL THEN 0 ELSE 1 END, "group", sort NULLS LAST, field;

\echo '=== Controller relations ==='
SELECT many_collection, many_field, one_collection, one_field, one_deselect_action
FROM public.directus_relations
WHERE many_collection IN ('controller','controller_display','controller_firmware_history')
   OR one_collection='controller'
ORDER BY many_collection, many_field, one_collection;

\echo '=== Permission boundary ==='
SELECT
    has_table_privilege('directus_app','ref.controller','SELECT') AS controller_read,
    has_table_privilege('directus_app','ref.controller','INSERT') AS controller_create,
    has_table_privilege('directus_app','ref.controller','UPDATE') AS controller_update,
    has_table_privilege('directus_app','ref.controller','DELETE') AS controller_delete,
    has_table_privilege('directus_app','ref.controller_display','DELETE') AS assignment_delete;

SELECT dp.collection, dp.action, p.name AS policy_name, dp.fields
FROM public.directus_permissions dp
JOIN public.directus_policies p ON p.id=dp.policy
WHERE dp.collection IN ('controller','controller_display')
ORDER BY dp.collection, p.name, dp.action;

\echo '=== Backup proof ==='
SELECT
  to_regclass('stage.controller_directus_collections_backup_20260831') AS collections_backup,
  to_regclass('stage.controller_directus_fields_backup_20260831') AS fields_backup,
  to_regclass('stage.controller_directus_relations_backup_20260831') AS relations_backup,
  to_regclass('stage.controller_directus_permissions_backup_20260831') AS permissions_backup;

\echo '=== Validation assertions ==='
DO $assertions$
DECLARE
    relation_count integer;
BEGIN
    IF has_table_privilege('directus_app','ref.controller','DELETE') THEN
        RAISE EXCEPTION 'FAIL: Controller DELETE is allowed';
    END IF;
    IF NOT has_table_privilege('directus_app','ref.controller_display','DELETE') THEN
        RAISE EXCEPTION 'FAIL: Controller assignment DELETE is not allowed';
    END IF;
    IF NOT EXISTS (
      SELECT 1 FROM public.directus_fields
      WHERE collection='controller' AND field='print_label'
        AND interface='boolean' AND readonly=false
    ) THEN
      RAISE EXCEPTION 'FAIL: print_label is not an editable boolean';
    END IF;
    IF NOT EXISTS (
      SELECT 1 FROM public.directus_fields
      WHERE collection='controller' AND field='display_assignments'
        AND interface='list-o2m'
    ) THEN
      RAISE EXCEPTION 'FAIL: display_assignments workspace missing';
    END IF;
    IF NOT EXISTS (
      SELECT 1 FROM public.directus_fields
      WHERE collection='controller' AND field='lor_uid_start' AND readonly=true
    ) THEN
      RAISE EXCEPTION 'FAIL: lor_uid_start must remain read-only';
    END IF;

    SELECT count(*) INTO relation_count
    FROM (VALUES
        ('controller', 'controller_model_id', 'controller_model'),
        ('controller', 'controller_status_id', 'controller_status'),
        ('controller', 'installed_firmware_version_id', 'controller_firmware_version'),
        ('controller', 'current_location_code', 'storage_location'),
        ('controller', 'firmware_verified_by_person_id', 'person'),
        ('controller', 'programmed_config_verified_by_person_id', 'person'),
        ('controller', 'label_print_last_by_cached_id', 'person'),
        ('controller', 'label_template_id', 'label_template'),
        ('controller', 'created_by_person_id', 'person'),
        ('controller', 'updated_by_person_id', 'person'),
        ('controller_display', 'controller_id', 'controller'),
        ('controller_display', 'display_id', 'display'),
        ('controller_display', 'wiring_source_display_id', 'display'),
        ('controller_firmware_history', 'controller_id', 'controller'),
        ('controller_firmware_history', 'controller_firmware_version_id', 'controller_firmware_version'),
        ('controller_firmware_history', 'verified_by_person_id', 'person')
    ) AS v(many_collection, many_field, one_collection)
    WHERE EXISTS (
      SELECT 1 FROM public.directus_relations r
      WHERE r.many_collection=v.many_collection
        AND r.many_field=v.many_field
        AND r.one_collection=v.one_collection
    );

    IF relation_count <> 16 THEN
      RAISE EXCEPTION 'FAIL: expected 16 relation mappings, found %', relation_count;
    END IF;
END
$assertions$;

\echo 'DIRECTUS CONTROLLER MANAGEMENT METADATA: PASS'
