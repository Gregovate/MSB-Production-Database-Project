-- File: Check-Ref-ForeignKey-Gaps.sql
-- =========================================================
-- MSB Production Database
-- Foreign Key Audit
-- Purpose:
-- Find ref-schema columns ending in _id that are not the table's
-- own primary key and do not currently have a foreign key constraint.
-- =========================================================

WITH pk_cols AS (
    SELECT
        tc.table_schema,
        tc.table_name,
        kcu.column_name
    FROM information_schema.table_constraints tc
    JOIN information_schema.key_column_usage kcu
      ON tc.constraint_name = kcu.constraint_name
     AND tc.table_schema    = kcu.table_schema
     AND tc.table_name      = kcu.table_name
    WHERE tc.constraint_type = 'PRIMARY KEY'
      AND tc.table_schema = 'ref'
),
fk_cols AS (
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
      AND tc.table_schema = 'ref'
)
SELECT
    c.table_schema,
    c.table_name,
    c.column_name,
    c.data_type
FROM information_schema.columns c
LEFT JOIN pk_cols pk
  ON pk.table_schema = c.table_schema
 AND pk.table_name   = c.table_name
 AND pk.column_name  = c.column_name
LEFT JOIN fk_cols fk
  ON fk.table_schema = c.table_schema
 AND fk.table_name   = c.table_name
 AND fk.column_name  = c.column_name
WHERE c.table_schema = 'ref'
  AND c.column_name LIKE '%\_id' ESCAPE '\'
  AND pk.column_name IS NULL
  AND fk.column_name IS NULL
ORDER BY c.table_name, c.column_name;