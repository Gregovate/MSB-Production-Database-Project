-- File: Check-PersonLink-FK-Gaps.sql
-- =========================================================
-- MSB Production Database
-- Foreign Key Audit
-- Purpose:
-- Find audit actor person-link columns in ref/ops that do not yet
-- have foreign key constraints to ref.person.
-- =========================================================

WITH fk_cols AS (
    SELECT
        tc.table_schema,
        tc.table_name,
        kcu.column_name
    FROM information_schema.table_constraints tc
    JOIN information_schema.key_column_usage kcu
      ON tc.constraint_name = kcu.constraint_name
     AND tc.table_schema    = kcu.table_schema
     AND tc.table_name      = kcu.table_name
    WHERE tc.constraint_type = 'FOREIGN KEY'
      AND tc.table_schema IN ('ref', 'ops')
)
SELECT
    c.table_schema,
    c.table_name,
    c.column_name,
    c.data_type
FROM information_schema.columns c
LEFT JOIN fk_cols fk
  ON fk.table_schema = c.table_schema
 AND fk.table_name   = c.table_name
 AND fk.column_name  = c.column_name
WHERE c.table_schema IN ('ref', 'ops')
  AND c.column_name IN (
      'created_by_person_id',
      'updated_by_person_id',
      'checked_by_person_id'
  )
  AND fk.column_name IS NULL
ORDER BY c.table_schema, c.table_name, c.column_name;