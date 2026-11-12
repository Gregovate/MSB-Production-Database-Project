-- File: Check-Directus-Metadata-Gaps-Audit-Fields.sql
-- =========================================================
-- MSB Production Database
-- Directus Metadata Audit
-- Purpose:
-- Find audit columns that exist in Postgres but do not yet have
-- matching directus_fields metadata rows.
-- =========================================================

WITH target_tables AS (
    SELECT 'ref' AS table_schema, 'container' AS table_name UNION ALL
    SELECT 'ref', 'container_endpoint' UNION ALL
    SELECT 'ref', 'container_test_status' UNION ALL
    SELECT 'ref', 'container_type' UNION ALL
    SELECT 'ref', 'display' UNION ALL
    SELECT 'ref', 'display_status' UNION ALL
    SELECT 'ref', 'display_test_status' UNION ALL
    SELECT 'ref', 'frame' UNION ALL
    SELECT 'ref', 'inventory_type' UNION ALL
    SELECT 'ref', 'person' UNION ALL
    SELECT 'ref', 'stage' UNION ALL
    SELECT 'ref', 'storage_location' UNION ALL
    SELECT 'ref', 'task_type' UNION ALL
    SELECT 'ref', 'theme' UNION ALL
    SELECT 'ref', 'work_area' UNION ALL
    SELECT 'ops', 'display_test_session' UNION ALL
    SELECT 'ops', 'test_session'
),
audit_columns AS (
    SELECT
        c.table_schema,
        c.table_name,
        c.column_name
    FROM information_schema.columns c
    JOIN target_tables t
      ON t.table_schema = c.table_schema
     AND t.table_name   = c.table_name
    WHERE c.column_name IN (
        'created_at',
        'created_by',
        'created_by_person_id',
        'updated_at',
        'updated_by',
        'updated_by_person_id',
        'checked_at',
        'checked_by',
        'checked_by_person_id'
    )
)
SELECT
    a.table_schema,
    a.table_name,
    a.column_name,
    df.field AS directus_field_exists
FROM audit_columns a
LEFT JOIN directus_fields df
  ON df.collection = a.table_name
 AND df.field = a.column_name
WHERE df.field IS NULL
ORDER BY a.table_schema, a.table_name, a.column_name;