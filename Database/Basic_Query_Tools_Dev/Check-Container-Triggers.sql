-- File: Check-Container-Triggers.sql
-- =========================================================
-- MSB Production Database
-- Audit System Repair
-- Step C16 – Verify triggers on ref.container
-- Purpose:
-- Confirm both locked-standard actor triggers now exist on
-- ref.container before inspecting the legacy touch trigger.
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
  AND c.relname = 'container'
ORDER BY t.tgname;