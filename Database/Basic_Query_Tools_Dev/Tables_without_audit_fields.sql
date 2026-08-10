SELECT
    schema_name,
    table_name,
    column_name
FROM (
    SELECT
        n.nspname AS schema_name,
        c.relname AS table_name,
        a.attname AS column_name
    FROM pg_catalog.pg_attribute a
    JOIN pg_catalog.pg_class c
        ON a.attrelid = c.oid
    JOIN pg_catalog.pg_namespace n
        ON c.relnamespace = n.oid
    WHERE
        a.attnum > 0
        AND NOT a.attisdropped
        AND c.relkind = 'r'
) t
WHERE
    schema_name IN ('ref','ops')
    AND column_name IN ('created_at','created_by','updated_at','updated_by')
ORDER BY
    schema_name,
    table_name,
    column_name;