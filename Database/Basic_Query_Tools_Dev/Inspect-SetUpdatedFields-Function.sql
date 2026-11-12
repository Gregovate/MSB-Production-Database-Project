-- File: Inspect-SetUpdatedFields-Function.sql
-- =========================================================
-- MSB Production Database
-- Audit System Repair
-- Step C40 – Inspect legacy ref.set_updated_fields function
-- Purpose:
-- Determine whether the legacy update trigger only sets updated_at
-- or whether it also overwrites updated_by and conflicts with the
-- new actor audit system.
-- =========================================================

SELECT
    n.nspname AS function_schema,
    p.proname AS function_name,
    pg_get_functiondef(p.oid) AS function_definition
FROM pg_proc p
JOIN pg_namespace n
  ON n.oid = p.pronamespace
WHERE n.nspname = 'ref'
  AND p.proname = 'set_updated_fields';