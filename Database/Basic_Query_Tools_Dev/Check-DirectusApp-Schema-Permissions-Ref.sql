-- File: Check-DirectusApp-Ref-Schema-Usage.sql
-- =========================================================
-- MSB Production Database
-- Directus Permission Check
-- Purpose:
-- Verify whether directus_app has USAGE on schema ref.
-- =========================================================

SELECT
    'directus_app' AS grantee,
    'ref' AS schema_name,
    has_schema_privilege('directus_app', 'ref', 'USAGE') AS has_usage,
    has_schema_privilege('directus_app', 'ref', 'CREATE') AS has_create;