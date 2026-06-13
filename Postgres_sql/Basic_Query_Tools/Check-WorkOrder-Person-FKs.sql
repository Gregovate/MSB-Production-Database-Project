-- File: Check-WorkOrder-Person-FKs.sql
-- =========================================================
-- MSB Production Database
-- Foreign Key Audit
-- Purpose:
-- Check FK constraints on ops.work_order person-link columns.
-- =========================================================

SELECT
    tc.constraint_name,
    tc.table_schema,
    tc.table_name,
    kcu.column_name,
    ccu.table_schema AS foreign_table_schema,
    ccu.table_name   AS foreign_table_name,
    ccu.column_name  AS foreign_column_name
FROM information_schema.table_constraints tc
JOIN information_schema.key_column_usage kcu
  ON tc.constraint_name = kcu.constraint_name
 AND tc.table_schema    = kcu.table_schema
 AND tc.table_name      = kcu.table_name
JOIN information_schema.constraint_column_usage ccu
  ON ccu.constraint_name = tc.constraint_name
 AND ccu.table_schema    = tc.table_schema
WHERE tc.constraint_type = 'FOREIGN KEY'
  AND tc.table_schema = 'ops'
  AND tc.table_name = 'work_order'
  AND kcu.column_name IN ('created_by_person_id', 'updated_by_person_id')
ORDER BY kcu.column_name;