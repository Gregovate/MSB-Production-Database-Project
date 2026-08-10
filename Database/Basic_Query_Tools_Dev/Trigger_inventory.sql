SELECT
    n.nspname AS schema_name,
    c.relname AS table_name,
    t.tgname  AS trigger_name
FROM pg_trigger t
JOIN pg_class c
  ON t.tgrelid = c.oid
JOIN pg_namespace n
  ON c.relnamespace = n.oid
WHERE n.nspname IN ('ops','ref')
  AND NOT t.tgisinternal
ORDER BY
    n.nspname,
    c.relname;