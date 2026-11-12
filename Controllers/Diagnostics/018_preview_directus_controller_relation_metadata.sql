/* ============================================================================
Controller Inventory — Directus relation metadata PREVIEW
Issue: #110

ROLLBACK ONLY. This script intentionally leaves no persistent change.

Purpose:
  Prove the Directus relation map required by the Controller management UI.
  PostgreSQL FKs are authoritative; this metadata teaches Directus how to render
  those governed relationships.
============================================================================ */

BEGIN;

\echo '=== RELATION PREVIEW preflight ==='
DO $preflight$
DECLARE
    relation_id_default text;
BEGIN
    IF to_regclass('public.directus_relations') IS NULL
       OR to_regclass('public.directus_fields') IS NULL THEN
        RAISE EXCEPTION 'Directus relation/field metadata tables are missing';
    END IF;

    SELECT column_default INTO relation_id_default
    FROM information_schema.columns
    WHERE table_schema='public'
      AND table_name='directus_relations'
      AND column_name='id';

    IF relation_id_default IS NULL THEN
        RAISE EXCEPTION 'directus_relations.id has no default; do not guess IDs';
    END IF;
END
$preflight$;

\echo '=== RELATION PREVIEW Controller reverse aliases ==='
INSERT INTO public.directus_fields
    (collection, field, special, interface, options, display, display_options,
     readonly, hidden, sort, width, note, required, "group", searchable)
SELECT
    'controller', v.field, 'o2m', 'list-o2m', v.options::json,
    'related-values', v.display_options::json,
    false, v.hidden, v.sort, 'full', v.note, false, v.group_name, true
FROM (VALUES
    ('display_assignments', '{"enableCreate":true}', '{"template":"{{display_id.display_name}}"}', false, 1,
     'Current physical Controller-to-Display assignments.', 'Display_Assignments'),
    ('firmware_history', '{"enableCreate":true}', '{"template":"{{controller_firmware_version_id.firmware_version}}"}', false, 6,
     'Recorded firmware history for this physical Controller.', 'Firmware')
) AS v(field, options, display_options, hidden, sort, note, group_name)
WHERE NOT EXISTS (
    SELECT 1 FROM public.directus_fields f
    WHERE f.collection='controller' AND f.field=v.field
);

\echo '=== RELATION PREVIEW relation map ==='
INSERT INTO public.directus_relations
    (many_collection, many_field, one_collection, one_field, one_deselect_action)
SELECT v.many_collection, v.many_field, v.one_collection, v.one_field, v.deselect_action
FROM (VALUES
    ('controller', 'controller_model_id', 'controller_model', NULL, 'nullify'),
    ('controller', 'controller_status_id', 'controller_status', NULL, 'nullify'),
    ('controller', 'installed_firmware_version_id', 'controller_firmware_version', NULL, 'nullify'),
    ('controller', 'current_location_code', 'storage_location', NULL, 'nullify'),
    ('controller', 'firmware_verified_by_person_id', 'person', NULL, 'nullify'),
    ('controller', 'programmed_config_verified_by_person_id', 'person', NULL, 'nullify'),
    ('controller', 'label_print_last_by_cached_id', 'person', NULL, 'nullify'),
    ('controller', 'label_template_id', 'label_template', NULL, 'nullify'),
    ('controller', 'created_by_person_id', 'person', NULL, 'nullify'),
    ('controller', 'updated_by_person_id', 'person', NULL, 'nullify'),
    ('controller_display', 'controller_id', 'controller', 'display_assignments', 'delete'),
    ('controller_display', 'display_id', 'display', NULL, 'nullify'),
    ('controller_display', 'wiring_source_display_id', 'display', NULL, 'nullify'),
    ('controller_firmware_history', 'controller_id', 'controller', 'firmware_history', 'delete'),
    ('controller_firmware_history', 'controller_firmware_version_id', 'controller_firmware_version', NULL, 'nullify'),
    ('controller_firmware_history', 'verified_by_person_id', 'person', NULL, 'nullify')
) AS v(many_collection, many_field, one_collection, one_field, deselect_action)
WHERE NOT EXISTS (
    SELECT 1
    FROM public.directus_relations r
    WHERE r.many_collection=v.many_collection
      AND r.many_field=v.many_field
      AND r.one_collection=v.one_collection
      AND COALESCE(r.one_field,'')=COALESCE(v.one_field,'')
);

\echo '=== RELATION PREVIEW result ==='
SELECT id, many_collection, many_field, one_collection, one_field, one_deselect_action
FROM public.directus_relations
WHERE many_collection IN ('controller','controller_display','controller_firmware_history')
   OR one_collection='controller'
ORDER BY many_collection, many_field, id;

\echo '=== RELATION PREVIEW expected invariant ==='
DO $assertions$
DECLARE
    expected_count integer := 16;
    found_count integer;
BEGIN
    SELECT count(*) INTO found_count
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

    IF found_count <> expected_count THEN
        RAISE EXCEPTION 'Expected % Controller relation mappings, found %', expected_count, found_count;
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM public.directus_relations
        WHERE many_collection='controller_display'
          AND many_field='controller_id'
          AND one_collection='controller'
          AND one_field='display_assignments'
          AND one_deselect_action='delete'
    ) THEN
        RAISE EXCEPTION 'Display assignment reverse relation/unassign behavior is not configured';
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM public.directus_relations
        WHERE many_collection='controller_firmware_history'
          AND many_field='controller_id'
          AND one_collection='controller'
          AND one_field='firmware_history'
    ) THEN
        RAISE EXCEPTION 'Firmware history reverse relation is not configured';
    END IF;
END
$assertions$;

\echo '=== RELATION PREVIEW PASS — rolling back ==='
ROLLBACK;

\echo '=== POST-ROLLBACK proof ==='
SELECT
    EXISTS (
        SELECT 1 FROM public.directus_relations
        WHERE many_collection='controller' AND many_field='controller_model_id'
    ) AS controller_model_relation_persisted,
    EXISTS (
        SELECT 1 FROM public.directus_fields
        WHERE collection='controller' AND field='firmware_history'
    ) AS firmware_history_alias_persisted;
