-- File: Check-ContainerEndpoint-ID-Default.sql
-- =========================================================
-- MSB Production Database
-- Directus / PostgreSQL PK Check
-- Purpose:
-- Verify whether ref.container_endpoint.endpoint_id is backed by
-- an identity or sequence default for automatic ID generation.
-- =========================================================

SELECT
    c.column_name,
    c.data_type,
    c.column_default,
    c.is_nullable,
    c.is_identity,
    c.identity_generation
FROM information_schema.columns c
WHERE c.table_schema = 'ref'
  AND c.table_name = 'container_endpoint'
  AND c.column_name = 'endpoint_id';