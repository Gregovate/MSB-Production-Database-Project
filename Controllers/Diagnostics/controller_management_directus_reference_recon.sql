/* ============================================================================
Controller Inventory — Directus reference-form comparison reconnaissance
Issue: #110

READ ONLY. This script does not create, update, delete, grant, or revoke.

Purpose:
  Compare the raw Controller collection metadata against mature MSB Directus
  collections already used operationally so Controller Management can copy the
  established interaction patterns instead of guessing Directus 11.17 metadata.
============================================================================ */

\echo '=== Directus relations table/version shape ==='
SELECT
    to_regclass('public.directus_relations') AS directus_relations;

SELECT
    ordinal_position,
    column_name,
    data_type
FROM information_schema.columns
WHERE table_schema = 'public'
  AND table_name = 'directus_relations'
ORDER BY ordinal_position;

\echo '=== Reference collection presentation metadata ==='
SELECT
    collection,
    icon,
    note,
    display_template,
    hidden,
    singleton,
    sort,
    "group",
    collapse,
    preview_url
FROM public.directus_collections
WHERE collection IN (
    'controller',
    'controller_display',
    'display',
    'container',
    'storage_location',
    'person',
    'label_template'
)
ORDER BY collection;

\echo '=== Reference Directus field interfaces/options ==='
SELECT
    collection,
    field,
    special,
    interface,
    options,
    display,
    display_options,
    readonly,
    hidden,
    sort,
    width,
    note,
    conditions,
    required,
    "group",
    validation,
    validation_message,
    searchable
FROM public.directus_fields
WHERE collection IN (
    'controller',
    'controller_display',
    'display',
    'container',
    'storage_location',
    'person',
    'label_template'
)
ORDER BY collection, COALESCE(sort, 999999), id;

\echo '=== Focused mature lookup/boolean/audit field examples ==='
SELECT
    collection,
    field,
    special,
    interface,
    options,
    display,
    display_options,
    readonly,
    hidden,
    sort,
    width,
    "group"
FROM public.directus_fields
WHERE collection IN ('display','container')
  AND (
      field ILIKE '%status%'
      OR field ILIKE '%location%'
      OR field ILIKE '%type%'
      OR field ILIKE '%person%'
      OR field ILIKE '%print%'
      OR field ILIKE '%label%'
      OR field ILIKE 'created_%'
      OR field ILIKE 'updated_%'
      OR special ILIKE '%boolean%'
      OR interface IS NOT NULL
  )
ORDER BY collection, COALESCE(sort, 999999), id;

\echo '=== Directus relations touching Controller or reference collections ==='
SELECT *
FROM public.directus_relations
WHERE many_collection IN (
    'controller',
    'controller_display',
    'display',
    'container',
    'storage_location',
    'person',
    'label_template'
)
   OR one_collection IN (
    'controller',
    'controller_display',
    'display',
    'container',
    'storage_location',
    'person',
    'label_template'
)
ORDER BY many_collection, many_field, one_collection;

\echo '=== PostgreSQL FK map for Controller management fields ==='
SELECT
    tc.table_name,
    kcu.column_name,
    ccu.table_schema AS foreign_table_schema,
    ccu.table_name AS foreign_table_name,
    ccu.column_name AS foreign_column_name,
    tc.constraint_name
FROM information_schema.table_constraints tc
JOIN information_schema.key_column_usage kcu
  ON kcu.constraint_name = tc.constraint_name
 AND kcu.constraint_schema = tc.constraint_schema
JOIN information_schema.constraint_column_usage ccu
  ON ccu.constraint_name = tc.constraint_name
 AND ccu.constraint_schema = tc.constraint_schema
WHERE tc.constraint_type = 'FOREIGN KEY'
  AND tc.table_schema = 'ref'
  AND tc.table_name IN ('controller','controller_display','controller_firmware_history')
ORDER BY tc.table_name, kcu.ordinal_position, tc.constraint_name;

\echo '=== Controller physical columns missing Directus field metadata ==='
SELECT
    c.ordinal_position,
    c.column_name,
    c.data_type,
    c.is_nullable,
    c.column_default,
    CASE WHEN df.field IS NULL THEN 'MISSING_METADATA' ELSE 'REGISTERED' END AS directus_state
FROM information_schema.columns c
LEFT JOIN public.directus_fields df
  ON df.collection = 'controller'
 AND df.field = c.column_name
WHERE c.table_schema = 'ref'
  AND c.table_name = 'controller'
ORDER BY c.ordinal_position;
