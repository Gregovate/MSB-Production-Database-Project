-- File: Inspect-SetActorOnUpdate-Function.sql
-- =========================================================
-- MSB Production Database
-- Audit System Repair
-- Step C41 – Inspect ref.set_actor_on_update function
-- Purpose:
-- Determine whether ref.set_actor_on_update already sets updated_at,
-- updated_by, and updated_by_person_id, or whether it is intended to
-- coexist with ref.set_updated_fields on UPDATE.
-- =========================================================

SELECT
    n.nspname AS function_schema,
    p.proname AS function_name,
    pg_get_functiondef(p.oid) AS function_definition
FROM pg_proc p
JOIN pg_namespace n
  ON n.oid = p.pronamespace
WHERE n.nspname = 'ref'
  AND p.proname = 'set_actor_on_update';