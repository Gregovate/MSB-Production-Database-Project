-- File: Check-Person-Triggers.sql
-- =========================================================
-- MSB Production Database
-- Audit System Repair
-- Step C38 – Check triggers on ref.person
-- Purpose:
-- Verify exactly which triggers currently exist on ref.person
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
  AND c.relname = 'person'
ORDER BY t.tgname;