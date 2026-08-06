-- File: Find-Ref-Tables-Missing-Actor-Triggers.sql
-- =========================================================
-- MSB Production Database
-- Audit System Repair
-- Step C11 – Find ref tables missing actor triggers
-- Purpose:
-- Identify ref tables that appear to use audit columns but do not yet
-- have locked-standard actor triggers attached.
-- =========================================================

WITH ref_tables AS (
    SELECT
        c.table_schema,
        c.table_name
    FROM information_schema.columns c
    WHERE c.table_schema = 'ref'
      AND c.column_name IN ('created_by', 'updated_by')
    GROUP BY c.table_schema, c.table_name
    HAVING COUNT(DISTINCT c.column_name) = 2
),
actor_triggers AS (
    SELECT
        n.nspname AS table_schema,
        c.relname AS table_name,
        MAX(CASE WHEN t.tgname = 'trg_' || c.relname || '_set_actor_insert' THEN 1 ELSE 0 END) AS has_actor_insert,
        MAX(CASE WHEN t.tgname = 'trg_' || c.relname || '_set_actor_update' THEN 1 ELSE 0 END) AS has_actor_update
    FROM pg_trigger t
    JOIN pg_class c
      ON c.oid = t.tgrelid
    JOIN pg_namespace n
      ON n.oid = c.relnamespace
    WHERE NOT t.tgisinternal
      AND n.nspname = 'ref'
    GROUP BY n.nspname, c.relname
)
SELECT
    r.table_schema,
    r.table_name,
    COALESCE(a.has_actor_insert, 0) AS has_actor_insert,
    COALESCE(a.has_actor_update, 0) AS has_actor_update
FROM ref_tables r
LEFT JOIN actor_triggers a
  ON a.table_schema = r.table_schema
 AND a.table_name   = r.table_name
WHERE COALESCE(a.has_actor_insert, 0) = 0
   OR COALESCE(a.has_actor_update, 0) = 0
ORDER BY r.table_name;