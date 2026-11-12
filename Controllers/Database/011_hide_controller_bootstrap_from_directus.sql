/* ============================================================================
Hide Controller bootstrap/stage objects from Directus
Issue: #110

Purpose:
  Keep engineering bootstrap provenance in stage.* while preventing the
  Directus database role from discovering or exposing Controller bootstrap
  tables/views to managers.

Scope:
  - affects only stage relations whose names begin controller_ or v_controller_
  - leaves permanent ref.controller* objects untouched
  - does not drop any stage data
============================================================================ */

BEGIN;

DO $revoke_stage_controller$
DECLARE
    r record;
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'directus_app') THEN
        RAISE EXCEPTION 'Role directus_app does not exist';
    END IF;

    FOR r IN
        SELECT c.relname, c.relkind
        FROM pg_class AS c
        JOIN pg_namespace AS n ON n.oid = c.relnamespace
        WHERE n.nspname = 'stage'
          AND (c.relname LIKE 'controller\_%' ESCAPE '\\'
               OR c.relname LIKE 'v\_controller\_%' ESCAPE '\\')
          AND c.relkind IN ('r','p','v','m','S')
        ORDER BY c.relname
    LOOP
        IF r.relkind = 'S' THEN
            EXECUTE format(
                'REVOKE ALL PRIVILEGES ON SEQUENCE stage.%I FROM directus_app',
                r.relname
            );
        ELSE
            EXECUTE format(
                'REVOKE ALL PRIVILEGES ON TABLE stage.%I FROM directus_app',
                r.relname
            );
        END IF;
    END LOOP;
END
$revoke_stage_controller$;

-- Directus does not need the bootstrap ordering helper either.
DO $revoke_stage_functions$
DECLARE
    r record;
BEGIN
    FOR r IN
        SELECT p.oid::regprocedure AS proc
        FROM pg_proc AS p
        JOIN pg_namespace AS n ON n.oid = p.pronamespace
        WHERE n.nspname = 'stage'
          AND p.proname LIKE '%controller%bootstrap%'
    LOOP
        EXECUTE format('REVOKE ALL PRIVILEGES ON FUNCTION %s FROM directus_app', r.proc);
    END LOOP;
END
$revoke_stage_functions$;

COMMIT;

SELECT
    n.nspname AS schema_name,
    c.relname AS relation_name,
    c.relkind,
    has_table_privilege('directus_app', format('%I.%I', n.nspname, c.relname), 'SELECT') AS directus_can_select
FROM pg_class AS c
JOIN pg_namespace AS n ON n.oid = c.relnamespace
WHERE n.nspname = 'stage'
  AND (c.relname LIKE 'controller\_%' ESCAPE '\\'
       OR c.relname LIKE 'v\_controller\_%' ESCAPE '\\')
  AND c.relkind IN ('r','p','v','m')
ORDER BY c.relname;
