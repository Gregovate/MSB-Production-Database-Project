/* ============================================================================
MSB Setup Session — production installation preflight
Issue: #122
Type: READ ONLY
Revision: 2026-09-06 V0.1.0

Purpose:
  Prove the existing Production Database dependencies and type contracts needed
  before applying any Setup Session DDL.

Expected result:
  every row returns status = PASS.
============================================================================ */

WITH checks(check_name, passed, detail) AS (
    VALUES
        ('PostgreSQL 16+',
            current_setting('server_version_num')::integer >= 160000,
            current_setting('server_version')),

        ('ref.season exists',
            to_regclass('ref.season') IS NOT NULL,
            coalesce(to_regclass('ref.season')::text, 'missing')),
        ('ref.stage exists',
            to_regclass('ref.stage') IS NOT NULL,
            coalesce(to_regclass('ref.stage')::text, 'missing')),
        ('ref.person exists',
            to_regclass('ref.person') IS NOT NULL,
            coalesce(to_regclass('ref.person')::text, 'missing')),
        ('ref.display exists',
            to_regclass('ref.display') IS NOT NULL,
            coalesce(to_regclass('ref.display')::text, 'missing')),
        ('ref.display_status exists',
            to_regclass('ref.display_status') IS NOT NULL,
            coalesce(to_regclass('ref.display_status')::text, 'missing')),
        ('ref.container exists',
            to_regclass('ref.container') IS NOT NULL,
            coalesce(to_regclass('ref.container')::text, 'missing')),
        ('ref.storage_location exists',
            to_regclass('ref.storage_location') IS NOT NULL,
            coalesce(to_regclass('ref.storage_location')::text, 'missing')),

        ('actor insert function exists',
            to_regprocedure('ref.set_actor_on_insert()') IS NOT NULL,
            coalesce(to_regprocedure('ref.set_actor_on_insert()')::text, 'missing')),
        ('actor update function exists',
            to_regprocedure('ref.set_actor_on_update()') IS NOT NULL,
            coalesce(to_regprocedure('ref.set_actor_on_update()')::text, 'missing')),
        ('resolve actor function exists',
            to_regprocedure('ref.resolve_actor()') IS NOT NULL,
            coalesce(to_regprocedure('ref.resolve_actor()')::text, 'missing')),

        ('Directus users exists',
            to_regclass('public.directus_users') IS NOT NULL,
            coalesce(to_regclass('public.directus_users')::text, 'missing')),
        ('Directus roles exists',
            to_regclass('public.directus_roles') IS NOT NULL,
            coalesce(to_regclass('public.directus_roles')::text, 'missing')),
        ('Directus access exists',
            to_regclass('public.directus_access') IS NOT NULL,
            coalesce(to_regclass('public.directus_access')::text, 'missing')),
        ('Directus policies exists',
            to_regclass('public.directus_policies') IS NOT NULL,
            coalesce(to_regclass('public.directus_policies')::text, 'missing')),

        ('fieldwiring_app role exists',
            EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'fieldwiring_app'),
            coalesce((SELECT rolname FROM pg_roles WHERE rolname = 'fieldwiring_app'), 'missing')),

        ('2025 season exists',
            EXISTS (SELECT 1 FROM ref.season WHERE season_year = 2025),
            coalesce((SELECT season_year::text FROM ref.season WHERE season_year = 2025 LIMIT 1), 'missing')),

        ('Production Crew Directus role exists',
            EXISTS (SELECT 1 FROM public.directus_roles WHERE name = 'Production Crew'),
            coalesce((SELECT name FROM public.directus_roles WHERE name = 'Production Crew' LIMIT 1), 'missing')),
        ('Manager Directus role exists',
            EXISTS (SELECT 1 FROM public.directus_roles WHERE name = 'Manager'),
            coalesce((SELECT name FROM public.directus_roles WHERE name = 'Manager' LIMIT 1), 'missing')),
        ('Administrator Directus role exists',
            EXISTS (SELECT 1 FROM public.directus_roles WHERE name = 'Administrator'),
            coalesce((SELECT name FROM public.directus_roles WHERE name = 'Administrator' LIMIT 1), 'missing')),

        ('ref.stage.stage_id integer',
            EXISTS (
                SELECT 1 FROM information_schema.columns
                WHERE table_schema='ref' AND table_name='stage'
                  AND column_name='stage_id' AND data_type='integer'
            ),
            coalesce((
                SELECT data_type FROM information_schema.columns
                WHERE table_schema='ref' AND table_name='stage' AND column_name='stage_id'
            ), 'missing')),
        ('ref.display.display_id bigint',
            EXISTS (
                SELECT 1 FROM information_schema.columns
                WHERE table_schema='ref' AND table_name='display'
                  AND column_name='display_id' AND data_type='bigint'
            ),
            coalesce((
                SELECT data_type FROM information_schema.columns
                WHERE table_schema='ref' AND table_name='display' AND column_name='display_id'
            ), 'missing')),
        ('ref.container.container_id integer',
            EXISTS (
                SELECT 1 FROM information_schema.columns
                WHERE table_schema='ref' AND table_name='container'
                  AND column_name='container_id' AND data_type='integer'
            ),
            coalesce((
                SELECT data_type FROM information_schema.columns
                WHERE table_schema='ref' AND table_name='container' AND column_name='container_id'
            ), 'missing')),
        ('ref.person.person_id integer',
            EXISTS (
                SELECT 1 FROM information_schema.columns
                WHERE table_schema='ref' AND table_name='person'
                  AND column_name='person_id' AND data_type='integer'
            ),
            coalesce((
                SELECT data_type FROM information_schema.columns
                WHERE table_schema='ref' AND table_name='person' AND column_name='person_id'
            ), 'missing')),
        ('ref.season.season_year integer',
            EXISTS (
                SELECT 1 FROM information_schema.columns
                WHERE table_schema='ref' AND table_name='season'
                  AND column_name='season_year' AND data_type='integer'
            ),
            coalesce((
                SELECT data_type FROM information_schema.columns
                WHERE table_schema='ref' AND table_name='season' AND column_name='season_year'
            ), 'missing')),

        ('Setup namespace currently empty',
            NOT EXISTS (
                SELECT 1
                FROM information_schema.tables
                WHERE table_schema IN ('ref','ops')
                  AND table_name LIKE 'setup_%'
            ),
            coalesce((
                SELECT string_agg(table_schema || '.' || table_name, ', ' ORDER BY table_schema, table_name)
                FROM information_schema.tables
                WHERE table_schema IN ('ref','ops')
                  AND table_name LIKE 'setup_%'
            ), 'no setup tables'))
)
SELECT
    check_name,
    CASE WHEN passed THEN 'PASS' ELSE 'FAIL' END AS status,
    detail
FROM checks
ORDER BY CASE WHEN passed THEN 1 ELSE 0 END, check_name;

/* Supporting current-state counts; informational only. */
SELECT
    (SELECT count(*) FROM ref.stage) AS stage_rows,
    (SELECT count(*) FROM ref.display) AS display_rows,
    (SELECT count(*) FROM ref.container) AS container_rows,
    (SELECT count(*) FROM ref.person) AS person_rows,
    (SELECT count(*) FROM ref.season) AS season_rows;
