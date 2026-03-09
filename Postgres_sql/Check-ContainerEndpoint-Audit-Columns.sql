-- File: Check-ContainerEndpoint-Audit-Columns.sql
-- =========================================================
-- MSB Production Database
-- Directus Permission Check
-- Purpose:
-- Verify audit columns exist on ref.container_endpoint and that
-- directus_app has column-level SELECT privilege on them.
-- =========================================================

SELECT
    c.column_name,
    c.data_type,
    has_column_privilege('directus_app', 'ref.container_endpoint', c.column_name, 'SELECT') AS directus_app_can_select
FROM information_schema.columns c
WHERE c.table_schema = 'ref'
  AND c.table_name = 'container_endpoint'
  AND c.column_name IN (
      'created_at',
      'created_by',
      'created_by_person_id',
      'updated_at',
      'updated_by',
      'updated_by_person_id'
  )
ORDER BY c.column_name;