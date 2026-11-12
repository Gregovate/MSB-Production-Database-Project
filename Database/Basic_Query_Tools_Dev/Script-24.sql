-- File: Check-TestSession-Triggers.sql
-- =========================================================
-- MSB Production Database
-- Audit System Repair
-- Step C9 – Verify triggers on ops.test_session
-- Purpose:
-- Confirm the insert actor trigger rename succeeded and review the
-- current trigger set on this one table before changing anything else.
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