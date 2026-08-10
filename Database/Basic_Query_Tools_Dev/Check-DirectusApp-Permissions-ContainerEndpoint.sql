-- File: Check-DirectusApp-Permissions-ContainerEndpoint.sql
-- =========================================================
-- MSB Production Database
-- Directus Permission Check
-- Purpose:
-- Verify PostgreSQL grants for directus_app on ref.container_endpoint.
-- =========================================================

SELECT
    grantee,
    table_schema,
    table_name,
    privilege_type
FROM information_schema.role_table_grants
WHERE grantee = 'directus_app'
  AND table_schema = 'ref'
  AND table_name = 'container_endpoint'
ORDER BY privilege_type;