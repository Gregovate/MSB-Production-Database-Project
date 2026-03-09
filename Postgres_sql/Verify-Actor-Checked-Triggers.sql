-- =========================================================
-- MSB Production Database
-- Audit System Repair
-- Step C1 – Verify Actor/Checked Triggers
-- =========================================================

SELECT
    n.nspname  AS trigger_schema,
    c.relname  AS table_name,
    t.tgname   AS trigger_name,
    p.proname  AS function_name,
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
  AND (
       t.tgname ILIKE '%actor%'
    OR t.tgname ILIKE '%audit%'
    OR t.tgname ILIKE '%checked%'
    OR p.proname IN (
         'set_actor_on_insert',
         'set_actor_on_update',
         'resolve_actor',
         'set_checked_actor'
       )
  )
ORDER BY n.nspname, c.relname, t.tgname;