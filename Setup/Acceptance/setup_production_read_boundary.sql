-- Read-only exporter used by permission-sensitive disposable acceptance.
-- Restore strips ACLs; replay only effective SELECT/USAGE as the clone role.
-- No passwords, Production ACL mutations, or application DML grants.
BEGIN READ ONLY;
SELECT statement FROM (
    SELECT 10 AS ord, format('GRANT USAGE ON SCHEMA %I TO fieldwiring_app;', nspname) AS statement
    FROM pg_namespace
    WHERE nspname IN ('ref','ops','lor_snap')
      AND has_schema_privilege('fieldwiring_app', oid, 'USAGE')
    UNION ALL
    SELECT 20, format('GRANT SELECT ON TABLE %I.%I TO fieldwiring_app;', n.nspname,c.relname)
    FROM pg_class c JOIN pg_namespace n ON n.oid=c.relnamespace
    WHERE n.nspname IN ('ref','ops','lor_snap') AND c.relkind IN ('r','p','v','m','f')
      AND has_table_privilege('fieldwiring_app',c.oid,'SELECT')
    UNION ALL
    SELECT 30, format('GRANT SELECT (%s) ON TABLE %I.%I TO fieldwiring_app;',
                     string_agg(format('%I',a.attname),',' ORDER BY a.attnum),n.nspname,c.relname)
    FROM pg_class c JOIN pg_namespace n ON n.oid=c.relnamespace
    JOIN pg_attribute a ON a.attrelid=c.oid AND a.attnum>0 AND NOT a.attisdropped
    WHERE n.nspname IN ('ref','ops','lor_snap') AND c.relkind IN ('r','p','v','m','f')
      AND NOT has_table_privilege('fieldwiring_app',c.oid,'SELECT')
      AND has_column_privilege('fieldwiring_app',c.oid,a.attnum,'SELECT')
    GROUP BY n.nspname,c.relname
) reads ORDER BY ord,statement;
ROLLBACK;
