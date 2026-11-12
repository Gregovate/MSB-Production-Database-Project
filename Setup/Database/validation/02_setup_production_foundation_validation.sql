/* ============================================================================
MSB Setup Session — production foundation validation
Issue: #122
Type: READ ONLY
Revision: 2026-09-06 V0.1.0

Purpose:
  Validate the installed Setup Session production foundation after 001-007.

Expected result:
  every row in the first result set returns status = PASS.
============================================================================ */

WITH checks(check_name, passed, detail) AS (
    VALUES
        ('2025 Setup Session exists once',
            (SELECT count(*) FROM ops.setup_session WHERE season_year = 2025) = 1,
            (SELECT count(*)::text FROM ops.setup_session WHERE season_year = 2025)),

        ('2025 session status historical verification',
            EXISTS (
                SELECT 1 FROM ops.setup_session
                WHERE season_year = 2025
                  AND session_status = 'HISTORICAL_VERIFICATION'
            ),
            coalesce((
                SELECT session_status FROM ops.setup_session
                WHERE season_year = 2025
                LIMIT 1
            ), 'missing')),

        ('Reusable Setup task count is 46',
            (SELECT count(*) FROM ref.setup_task) = 46,
            (SELECT count(*)::text FROM ref.setup_task)),

        ('2025 annual Setup task count is 46',
            (
                SELECT count(*)
                FROM ops.setup_session_task sst
                JOIN ops.setup_session ss
                  ON ss.setup_session_id = sst.setup_session_id
                WHERE ss.season_year = 2025
            ) = 46,
            (
                SELECT count(*)::text
                FROM ops.setup_session_task sst
                JOIN ops.setup_session ss
                  ON ss.setup_session_id = sst.setup_session_id
                WHERE ss.season_year = 2025
            )),

        ('All 2025 annual tasks remain unverified',
            (
                SELECT count(*) FILTER (WHERE sst.verification_state = 'UNVERIFIED')
                FROM ops.setup_session_task sst
                JOIN ops.setup_session ss
                  ON ss.setup_session_id = sst.setup_session_id
                WHERE ss.season_year = 2025
            ) = 46,
            (
                SELECT count(*) FILTER (WHERE sst.verification_state = 'UNVERIFIED')::text
                FROM ops.setup_session_task sst
                JOIN ops.setup_session ss
                  ON ss.setup_session_id = sst.setup_session_id
                WHERE ss.season_year = 2025
            )),

        ('2025 Display state matches current non-recycled Displays',
            (
                SELECT count(*)
                FROM ops.setup_display_state ds
                JOIN ops.setup_session ss
                  ON ss.setup_session_id = ds.setup_session_id
                WHERE ss.season_year = 2025
            ) = (
                SELECT count(*)
                FROM ref.display d
                JOIN ref.display_status st
                  ON st.display_status_id = d.display_status_id
                WHERE st.display_status_name <> 'RECYCLED'
            ),
            format(
                'state=%s expected_non_recycled=%s',
                (
                    SELECT count(*)
                    FROM ops.setup_display_state ds
                    JOIN ops.setup_session ss
                      ON ss.setup_session_id = ds.setup_session_id
                    WHERE ss.season_year = 2025
                ),
                (
                    SELECT count(*)
                    FROM ref.display d
                    JOIN ref.display_status st
                      ON st.display_status_id = d.display_status_id
                    WHERE st.display_status_name <> 'RECYCLED'
                )
            )),

        ('2025 Container state matches current Containers',
            (
                SELECT count(*)
                FROM ops.setup_container_state cs
                JOIN ops.setup_session ss
                  ON ss.setup_session_id = cs.setup_session_id
                WHERE ss.season_year = 2025
            ) = (SELECT count(*) FROM ref.container),
            format(
                'state=%s current_containers=%s',
                (
                    SELECT count(*)
                    FROM ops.setup_container_state cs
                    JOIN ops.setup_session ss
                      ON ss.setup_session_id = cs.setup_session_id
                    WHERE ss.season_year = 2025
                ),
                (SELECT count(*) FROM ref.container)
            )),

        ('No 2025 movement history invented',
            (
                SELECT count(*)
                FROM ops.setup_movement_event me
                JOIN ops.setup_session ss
                  ON ss.setup_session_id = me.setup_session_id
                WHERE ss.season_year = 2025
            ) = 0,
            (
                SELECT count(*)::text
                FROM ops.setup_movement_event me
                JOIN ops.setup_session ss
                  ON ss.setup_session_id = me.setup_session_id
                WHERE ss.season_year = 2025
            )),

        ('Setup Display state does not snapshot container_id',
            NOT EXISTS (
                SELECT 1 FROM information_schema.columns
                WHERE table_schema = 'ops'
                  AND table_name = 'setup_display_state'
                  AND column_name = 'container_id'
            ),
            CASE WHEN EXISTS (
                SELECT 1 FROM information_schema.columns
                WHERE table_schema = 'ops'
                  AND table_name = 'setup_display_state'
                  AND column_name = 'container_id'
            ) THEN 'unexpected container_id column' ELSE 'no container_id column' END),

        ('Protected app can read Setup tasks',
            has_table_privilege('fieldwiring_app', 'ref.setup_task', 'SELECT'),
            has_table_privilege('fieldwiring_app', 'ref.setup_task', 'SELECT')::text),

        ('Protected app can read annual Setup state',
            has_table_privilege('fieldwiring_app', 'ops.setup_session_task', 'SELECT'),
            has_table_privilege('fieldwiring_app', 'ops.setup_session_task', 'SELECT')::text),

        ('Protected app has no broad Setup task UPDATE',
            NOT has_table_privilege('fieldwiring_app', 'ref.setup_task', 'UPDATE'),
            has_table_privilege('fieldwiring_app', 'ref.setup_task', 'UPDATE')::text),

        ('Protected app has no broad movement INSERT',
            NOT has_table_privilege('fieldwiring_app', 'ops.setup_movement_event', 'INSERT'),
            has_table_privilege('fieldwiring_app', 'ops.setup_movement_event', 'INSERT')::text),

        ('Protected app cannot directly read Directus users',
            NOT has_table_privilege('fieldwiring_app', 'public.directus_users', 'SELECT'),
            has_table_privilege('fieldwiring_app', 'public.directus_users', 'SELECT')::text),

        ('Setup capability lookup exists',
            to_regprocedure('ref.setup_browser_capabilities(text)') IS NOT NULL,
            coalesce(to_regprocedure('ref.setup_browser_capabilities(text)')::text, 'missing')),

        ('Protected app can execute capability lookup',
            has_function_privilege(
                'fieldwiring_app',
                'ref.setup_browser_capabilities(text)',
                'EXECUTE'
            ),
            has_function_privilege(
                'fieldwiring_app',
                'ref.setup_browser_capabilities(text)',
                'EXECUTE'
            )::text),

        ('Protected app can execute Admin session command',
            has_function_privilege(
                'fieldwiring_app',
                'ops.create_setup_session(text,integer,text)',
                'EXECUTE'
            ),
            has_function_privilege(
                'fieldwiring_app',
                'ops.create_setup_session(text,integer,text)',
                'EXECUTE'
            )::text),

        ('Protected app cannot execute internal actor helper',
            NOT has_function_privilege(
                'fieldwiring_app',
                'ref.setup_management_actor(text,boolean)',
                'EXECUTE'
            ),
            has_function_privilege(
                'fieldwiring_app',
                'ref.setup_management_actor(text,boolean)',
                'EXECUTE'
            )::text),

        ('All Setup actor triggers present',
            (
                SELECT count(*)
                FROM pg_trigger t
                JOIN pg_class c ON c.oid = t.tgrelid
                JOIN pg_namespace n ON n.oid = c.relnamespace
                WHERE NOT t.tgisinternal
                  AND n.nspname IN ('ref','ops')
                  AND c.relname LIKE 'setup_%'
                  AND t.tgname LIKE 'trg_%_actor_%'
            ) = 30,
            (
                SELECT count(*)::text
                FROM pg_trigger t
                JOIN pg_class c ON c.oid = t.tgrelid
                JOIN pg_namespace n ON n.oid = c.relnamespace
                WHERE NOT t.tgisinternal
                  AND n.nspname IN ('ref','ops')
                  AND c.relname LIKE 'setup_%'
                  AND t.tgname LIKE 'trg_%_actor_%'
            ))
)
SELECT
    check_name,
    CASE WHEN passed THEN 'PASS' ELSE 'FAIL' END AS status,
    detail
FROM checks
ORDER BY CASE WHEN passed THEN 1 ELSE 0 END, check_name;

/* Informational permanent-data baseline. */
SELECT
    count(*) AS total_displays,
    count(*) FILTER (WHERE d.container_id IS NOT NULL) AS displays_with_container,
    count(*) FILTER (
        WHERE d.container_id IS NOT NULL
          AND c.container_id IS NOT NULL
          AND c.location_code IS NOT NULL
          AND sl.location_code IS NOT NULL
    ) AS resolved_storage_locations,
    (SELECT count(*) FROM ref.container) AS container_rows
FROM ref.display d
LEFT JOIN ref.container c ON c.container_id = d.container_id
LEFT JOIN ref.storage_location sl ON sl.location_code = c.location_code;
