SELECT
    n.nspname AS schema_name,
    c.relname AS table_name,
    con.conname AS constraint_name,
    pg_get_constraintdef(con.oid) AS definition
FROM pg_constraint con
JOIN pg_class c
  ON con.conrelid = c.oid
JOIN pg_namespace n
  ON c.relnamespace = n.oid
WHERE n.nspname IN ('ops', 'ref')
  AND con.contype = 'f'
ORDER BY
    n.nspname,
    c.relname,
    con.conname;