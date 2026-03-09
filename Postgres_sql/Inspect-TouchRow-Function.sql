-- File: Inspect-TouchRow-Function.sql
-- =========================================================
-- MSB Production Database
-- Audit System Repair
-- Step C17 – Inspect legacy pallet touch function
-- Purpose:
-- Determine what tg_touch_row() actually does before deciding
-- whether the legacy pallet trigger can be removed.
-- =========================================================

SELECT
    n.nspname AS function_schema,
    p.proname AS function_name,
    pg_get_functiondef(p.oid) AS function_definition
FROM pg_proc p
JOIN pg_namespace n
  ON n.oid = p.pronamespace
WHERE p.proname = 'tg_touch_row';