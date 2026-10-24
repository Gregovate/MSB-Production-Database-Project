-- #171/#230 under #122. Read-only catalog inventory; run the whole script in DBeaver.
-- No equipment values, credentials, user roster, migrations or grants are changed/read.
-- One JSON result; absent proposed objects are reported rather than queried directly.
BEGIN TRANSACTION ISOLATION LEVEL REPEATABLE READ READ ONLY;
SET LOCAL statement_timeout = '20s';
WITH objects AS (
    SELECT c.oid, n.nspname AS schema_name, c.relname AS object_name,
           c.relkind, c.relacl, c.relrowsecurity, c.relforcerowsecurity
    FROM pg_catalog.pg_class c
    JOIN pg_catalog.pg_namespace n ON n.oid = c.relnamespace
    WHERE n.nspname IN ('ref', 'ops')
      AND c.relkind IN ('r','p','v','m','f')
      AND c.relname ~* '(site_|waypoint|panel|circuit|meter|fuse|disconnect|power|season)'
), functions AS (
    SELECT p.oid, n.nspname, p.proname, p.prosecdef, p.proconfig, p.proacl
    FROM pg_catalog.pg_proc p
    JOIN pg_catalog.pg_namespace n ON n.oid = p.pronamespace
    WHERE n.nspname IN ('ref', 'ops') AND p.prokind = 'f'
      AND (p.proname ~* '(site_|waypoint|panel|circuit|power)'
           OR p.proname IN ('setup_browser_capabilities',
                           'controller_browser_capabilities',
                           'setup_inventory_actor'))
)
SELECT jsonb_pretty(jsonb_build_object(
    'database', current_database(),
    'server_version', current_setting('server_version'),
    'transaction_read_only', current_setting('transaction_read_only'),
    'captured_at', statement_timestamp(),
    'extensions', (SELECT jsonb_agg(jsonb_build_object('name', extname, 'version', extversion))
                   FROM pg_catalog.pg_extension WHERE extname IN ('postgis','pgcrypto')),
    'objects', COALESCE((SELECT jsonb_agg(jsonb_build_object(
        'schema', o.schema_name, 'name', o.object_name, 'kind', o.relkind,
        'acl', o.relacl, 'rls', o.relrowsecurity, 'force_rls', o.relforcerowsecurity,
        'columns', (SELECT jsonb_agg(jsonb_build_object(
            'name', a.attname, 'type', pg_catalog.format_type(a.atttypid,a.atttypmod),
            'not_null', a.attnotnull, 'identity', a.attidentity,
            'generated', a.attgenerated,
            'default', pg_catalog.pg_get_expr(d.adbin,d.adrelid)
            ) ORDER BY a.attnum)
            FROM pg_catalog.pg_attribute a
            LEFT JOIN pg_catalog.pg_attrdef d ON d.adrelid=a.attrelid AND d.adnum=a.attnum
            WHERE a.attrelid=o.oid AND a.attnum>0 AND NOT a.attisdropped),
        'constraints', (SELECT jsonb_agg(pg_catalog.pg_get_constraintdef(k.oid) ORDER BY k.conname)
                        FROM pg_catalog.pg_constraint k WHERE k.conrelid=o.oid),
        'indexes', (SELECT jsonb_agg(pg_catalog.pg_get_indexdef(i.indexrelid))
                    FROM pg_catalog.pg_index i WHERE i.indrelid=o.oid),
        'triggers', (SELECT jsonb_agg(pg_catalog.pg_get_triggerdef(t.oid))
                     FROM pg_catalog.pg_trigger t WHERE t.tgrelid=o.oid AND NOT t.tgisinternal)
        ) ORDER BY o.schema_name,o.object_name) FROM objects o), '[]'::jsonb),
    'functions', COALESCE((SELECT jsonb_agg(jsonb_build_object(
        'schema', f.nspname, 'name', f.proname,
        'arguments', pg_catalog.pg_get_function_identity_arguments(f.oid),
        'security_definer', f.prosecdef, 'settings', f.proconfig, 'acl', f.proacl,
        'definition', pg_catalog.pg_get_functiondef(f.oid)
        ) ORDER BY f.nspname,f.proname,f.oid) FROM functions f), '[]'::jsonb)
)) AS panel_circuit_schema_inventory;
ROLLBACK;
