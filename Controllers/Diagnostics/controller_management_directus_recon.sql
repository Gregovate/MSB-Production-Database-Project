/* ============================================================================
Controller Inventory — Directus management reconnaissance
Issue: #110

READ ONLY. This script does not create, update, delete, grant, or revoke.

Purpose:
  Establish why the permanent ref.controller* subsystem is not yet available as
  a usable Manager maintenance surface in Directus, without guessing Directus
  11.x metadata structure.
============================================================================ */

\echo '=== PostgreSQL Controller tables ==='
SELECT
    to_regclass('ref.controller') AS controller,
    to_regclass('ref.controller_display') AS controller_display,
    to_regclass('ref.controller_model') AS controller_model,
    to_regclass('ref.controller_status') AS controller_status,
    to_regclass('ref.controller_firmware_version') AS controller_firmware_version,
    to_regclass('ref.controller_firmware_history') AS controller_firmware_history;

\echo '=== directus_app database privileges ==='
SELECT
    table_name,
    has_table_privilege('directus_app', format('ref.%I', table_name), 'SELECT') AS can_select,
    has_table_privilege('directus_app', format('ref.%I', table_name), 'INSERT') AS can_insert,
    has_table_privilege('directus_app', format('ref.%I', table_name), 'UPDATE') AS can_update,
    has_table_privilege('directus_app', format('ref.%I', table_name), 'DELETE') AS can_delete
FROM (VALUES
    ('controller'),
    ('controller_display'),
    ('controller_model'),
    ('controller_status'),
    ('controller_firmware_version'),
    ('controller_firmware_history')
) AS x(table_name)
ORDER BY table_name;

\echo '=== Directus metadata tables present ==='
SELECT
    to_regclass('public.directus_collections') AS directus_collections,
    to_regclass('public.directus_fields') AS directus_fields,
    to_regclass('public.directus_permissions') AS directus_permissions,
    to_regclass('public.directus_policies') AS directus_policies,
    to_regclass('public.directus_access') AS directus_access;

\echo '=== Directus metadata table columns (version-shape evidence) ==='
SELECT
    table_name,
    ordinal_position,
    column_name,
    data_type
FROM information_schema.columns
WHERE table_schema = 'public'
  AND table_name IN (
      'directus_collections',
      'directus_fields',
      'directus_permissions',
      'directus_policies',
      'directus_access'
  )
ORDER BY table_name, ordinal_position;

\echo '=== Controller-related Directus collections ==='
SELECT *
FROM public.directus_collections
WHERE collection ILIKE '%controller%'
ORDER BY collection;

\echo '=== Controller-related Directus fields ==='
SELECT *
FROM public.directus_fields
WHERE collection ILIKE '%controller%'
ORDER BY collection, id;

\echo '=== Controller-related Directus permissions ==='
SELECT *
FROM public.directus_permissions
WHERE collection ILIKE '%controller%'
ORDER BY collection, action, id;

\echo '=== Directus policies ==='
SELECT *
FROM public.directus_policies
ORDER BY name, id;

\echo '=== Directus policy/role access links ==='
SELECT *
FROM public.directus_access
ORDER BY id;
