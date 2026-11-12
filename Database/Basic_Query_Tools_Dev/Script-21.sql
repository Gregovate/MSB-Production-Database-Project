SELECT
    table_schema,
    table_name,
    string_agg(privilege_type, ', ' ORDER BY privilege_type) AS privileges
FROM information_schema.role_table_grants
WHERE grantee = 'directus_app'
GROUP BY table_schema, table_name
ORDER BY table_schema, table_name;