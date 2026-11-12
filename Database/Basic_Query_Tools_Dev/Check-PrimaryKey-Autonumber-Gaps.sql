-- File: Check-PrimaryKey-Autonumber-Gaps.sql
-- =========================================================
-- MSB Production Database
-- PK / Sequence Audit
-- Purpose:
-- Find integer primary key columns in ref/ops that do not have
-- an identity or sequence default.
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
    JOIN information_schema.columns c
      ON c.table_schema = kcu.table_schema
     AND c.table_name   = kcu.table_name
     AND c.column_name  = kcu.column_name
    WHERE tc.constraint_type = 'PRIMARY KEY'
      AND tc.table_schema IN ('ref', 'ops')
      AND c.data_type IN ('smallint', 'integer', 'bigint')
)
SELECT
    c.table_schema,
    c.table_name,
    c.column_name,
    c.data_type,
    c.column_default,
    c.is_identity,
    c.identity_generation
FROM pk_cols pk
JOIN information_schema.columns c
  ON c.table_schema = pk.table_schema
 AND c.table_name   = pk.table_name
 AND c.column_name  = pk.column_name
WHERE COALESCE(c.column_default, '') = ''
  AND COALESCE(c.is_identity, 'NO') = 'NO'
ORDER BY c.table_schema, c.table_name;