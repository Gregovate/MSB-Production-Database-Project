-- File: Check-InventoryType-Triggers.sql
-- =========================================================
-- MSB Production Database
-- Audit System Repair
-- Step C46 – Check triggers on ref.inventory_type
-- Purpose:
-- Verify which triggers exist on ref.inventory_type
-- before adding actor insert/update triggers.
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
  AND c.relname = 'inventory_type'
ORDER BY t.tgname;