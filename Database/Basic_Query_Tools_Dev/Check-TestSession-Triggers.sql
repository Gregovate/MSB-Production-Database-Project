-- File: Check-TestSession-Triggers.sql
-- =========================================================
-- MSB Production Database
-- Audit System Repair
-- Step C7 – Check triggers on ops.test_session
-- Purpose:
-- Verify exactly which triggers currently exist on ops.test_session
-- before normalizing the insert actor trigger on that table.
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
  AND n.nspname = 'ops'
  AND c.relname = 'test_session'
ORDER BY t.tgname;