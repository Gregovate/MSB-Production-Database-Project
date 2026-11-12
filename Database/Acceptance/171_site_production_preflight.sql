-- #171/#230 under #122: read-only inventory for approved PR #319 release.
-- Run as the existing local administrator through docker exec / psql.
-- No candidate migration, command invocation, fixture, grant or maintenance change.
\set ON_ERROR_STOP on
\pset pager off
BEGIN ISOLATION LEVEL REPEATABLE READ READ ONLY;
SET LOCAL statement_timeout = '30s';
SELECT json_build_object('database',current_database(),
    'read_only',current_setting('transaction_read_only'),
    'postgis', (SELECT extversion FROM pg_extension WHERE extname='postgis'));

-- Discover existing objects before deciding whether initial bootstrap is legal.
SELECT json_build_object('relation',n.nspname||'.'||c.relname,'kind',c.relkind,
    'columns',(SELECT json_agg(json_build_object(
        'name',a.attname,'type',format_type(a.atttypid,a.atttypmod),
        'not_null',a.attnotnull,'identity',a.attidentity) ORDER BY a.attnum)
      FROM pg_attribute a WHERE a.attrelid=c.oid AND a.attnum>0 AND NOT a.attisdropped))
FROM pg_class c JOIN pg_namespace n ON n.oid=c.relnamespace
WHERE n.nspname IN ('ref','ops') AND c.relkind IN ('r','p','v')
  AND (c.relname ~ '^(site_|linkiq_)' OR c.relname ~ '(gis|locate)')
ORDER BY n.nspname,c.relname;

-- psql executes SELECT statements only, generated from quoted catalog identifiers.
SELECT format('SELECT json_build_object(''table'',%L,''rows'',count(*)) FROM %I.%I;',
    n.nspname||'.'||c.relname,n.nspname,c.relname)
FROM pg_class c JOIN pg_namespace n ON n.oid=c.relnamespace
WHERE n.nspname IN ('ref','ops') AND c.relkind IN ('r','p')
  AND c.relname ~ '^(site_|linkiq_)'
ORDER BY n.nspname,c.relname
\gexec

SELECT json_build_object('function',p.oid::regprocedure::text,
    'body_md5',md5(p.prosrc),'security_definer',p.prosecdef,
    'owner',pg_get_userbyid(p.proowner),'settings',p.proconfig)
FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace
WHERE n.nspname='ref' AND p.proname ~ '^site_'
ORDER BY p.oid::regprocedure::text;

-- Existing Directus-backed capability, not a new preview identity or grant.
SELECT json_build_object('operator','gliebig@sheboyganlights.org',
    'can_read_setup',can_read_setup,'can_manage_setup',can_manage_setup)
FROM ref.setup_browser_capabilities('gliebig@sheboyganlights.org');

SELECT format('SELECT json_build_object(''source_batch'',to_jsonb(b)-''source_metadata'') FROM %I.%I b ORDER BY source_sha256;',
    n.nspname,c.relname)
FROM pg_class c JOIN pg_namespace n ON n.oid=c.relnamespace
WHERE n.nspname='ops' AND c.relname='site_source_batch' AND c.relkind='r'
\gexec
ROLLBACK;
\echo PR319 GIS/FLW READ-ONLY INVENTORY COMPLETE
