-- File: Check-ContainerTestStatus-Triggers.sql
-- =========================================================
-- MSB Production Database
-- Audit System Repair
-- Step C44 – Check triggers on ref.container_test_status
-- Purpose:
-- Verify exactly which triggers currently exist on ref.container_test_status
-- before adding insert/update actor triggers.
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
  AND c.relname = 'container_test_status'
ORDER BY t.tgname;