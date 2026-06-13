SELECT
    n.nspname AS schema_name,
    c.relname AS table_name,
    a.attnum  AS column_order,
    a.attname AS column_name,
    pg_catalog.format_type(a.atttypid, a.atttypmod) AS data_type,
    CASE
        WHEN a.attnotnull THEN 'NO'
        ELSE 'YES'
    END AS is_nullable,
    pg_get_expr(ad.adbin, ad.adrelid) AS default_value
FROM pg_catalog.pg_attribute a
JOIN pg_catalog.pg_class c
  ON a.attrelid = c.oid
JOIN pg_catalog.pg_namespace n
  ON c.relnamespace = n.oid
LEFT JOIN pg_catalog.pg_attrdef ad
  ON a.attrelid = ad.adrelid
 AND a.attnum = ad.adnum
WHERE
    a.attnum > 0
    AND NOT a.attisdropped
    AND c.relkind = 'r'
    AND n.nspname IN ('ref','ops','lor_snap','stage')
ORDER BY
    n.nspname,
    c.relname,
    a.attnum;