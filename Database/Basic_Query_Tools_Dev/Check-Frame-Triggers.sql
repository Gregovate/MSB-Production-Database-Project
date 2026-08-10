-- File: Check-Frame-Triggers.sql
-- =========================================================
-- MSB Production Database
-- Audit System Repair
-- Step C37 – Check triggers on ref.frame
-- Purpose:
-- Verify exactly which triggers currently exist on ref.frame
-- before deciding whether this table needs update-only or insert+update.
-- =========================================================

SELECT
    t.tgname AS trigger_name,
    p.proname AS function_name,
    pn.nspname AS function_schema
FROM pg_trigger t
JOIN pg_class c
  ON c.oid = t.tgrelid
JOIN pg_namespace n
  ON n.oid = c.relnamespace
JOIN pg_proc p
  ON p.oid = t.tgfoid
JOIN pg_namespace pn
  ON pn.oid = p.pronamespace
WHERE NOT t.tgisinternal
  AND n.nspname = 'ref'
  AND c.relname = 'frame'
ORDER BY t.tgname;