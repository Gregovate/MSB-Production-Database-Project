-- File: Check-Directus-Fields-ContainerEndpoint.sql
-- =========================================================
-- MSB Production Database
-- Directus Metadata Check
-- Purpose:
-- Verify whether Directus metadata contains the audit fields for
-- the container_endpoint collection.
-- =========================================================

SELECT
    collection,
    field,
    special,
    interface,
    readonly,
    hidden
FROM directus_fields
WHERE collection = 'container_endpoint'
  AND field IN (
      'created_at',
      'created_by',
      'created_by_person_id',
      'updated_at',
      'updated_by',
      'updated_by_person_id'
  )
ORDER BY field;