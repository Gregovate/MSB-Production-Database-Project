\set ON_ERROR_STOP on

/*
Database-wide disposable validation for the shared audit contract.
Runs only on a disposable current-Production clone.

The migration under test may add missing audit columns/policies/triggers in the
clone. Fixture DML below is rolled back. Historical Production audit values are
not reconstructed or rewritten.
*/

BEGIN;

DO $contract$
DECLARE
    v_bad_function text;
    v_bad_table text;
BEGIN
    IF to_regprocedure('ref.resolve_actor()') IS NULL
       OR to_regprocedure('ref.set_actor_on_insert()') IS NULL
       OR to_regprocedure('ref.set_actor_on_update()') IS NULL
       OR to_regprocedure('ref.set_updated_fields()') IS NULL
       OR to_regprocedure('ref.sync_audit_collection_policy()') IS NULL THEN
        RAISE EXCEPTION 'Shared database audit functions are missing';
    END IF;

    /*
      No UPDATE trigger function may retain the stale-actor COALESCE pattern.
      INSERT is intentionally outside this check because INSERT has no OLD row.
    */
    SELECT n.nspname || '.' || p.proname
      INTO v_bad_function
    FROM pg_proc AS p
    JOIN pg_namespace AS n
      ON n.oid = p.pronamespace
    WHERE p.prorettype = 'trigger'::regtype
      AND p.proname <> 'set_actor_on_insert'
      AND p.prosrc ~* 'COALESCE[[:space:]]*[(][[:space:]]*NEW[.]updated_by'
    ORDER BY n.nspname, p.proname
    LIMIT 1;

    IF v_bad_function IS NOT NULL THEN
        RAISE EXCEPTION
            'Stale UPDATE audit COALESCE pattern remains in %',
            v_bad_function;
    END IF;

    /*
      Every table participating in the shared actor-trigger system must now
      contain the complete Foundation audit contract.
    */
    WITH shared_audit_tables AS (
        SELECT DISTINCT
            n.nspname AS schema_name,
            c.relname AS table_name
        FROM pg_trigger AS t
        JOIN pg_proc AS p
          ON p.oid = t.tgfoid
        JOIN pg_class AS c
          ON c.oid = t.tgrelid
        JOIN pg_namespace AS n
          ON n.oid = c.relnamespace
        WHERE NOT t.tgisinternal
          AND n.nspname IN ('ref', 'ops', 'stage')
          AND p.proname IN (
              'set_actor_on_insert',
              'set_actor_on_update',
              'set_updated_fields'
          )
    )
    SELECT s.schema_name || '.' || s.table_name
      INTO v_bad_table
    FROM shared_audit_tables AS s
    WHERE EXISTS (
        SELECT 1
        FROM (
            VALUES
                ('created_at'),
                ('created_by'),
                ('created_by_person_id'),
                ('updated_at'),
                ('updated_by'),
                ('updated_by_person_id')
        ) AS required(column_name)
        WHERE NOT EXISTS (
            SELECT 1
            FROM information_schema.columns AS col
            WHERE col.table_schema = s.schema_name
              AND col.table_name = s.table_name
              AND col.column_name = required.column_name
        )
    )
    ORDER BY s.schema_name, s.table_name
    LIMIT 1;

    IF v_bad_table IS NOT NULL THEN
        RAISE EXCEPTION
            'Shared audit table lacks complete six-field Foundation contract: %',
            v_bad_table;
    END IF;

    /*
      Any table using a shared UPDATE actor trigger must have an active update
      actor policy. ref.sync_audit_collection_policy() is the enrollment
      mechanism; this assertion prevents future table additions from silently
      missing that step.
    */
    WITH shared_update_tables AS (
        SELECT DISTINCT
            n.nspname AS schema_name,
            c.relname AS table_name
        FROM pg_trigger AS t
        JOIN pg_proc AS p
          ON p.oid = t.tgfoid
        JOIN pg_class AS c
          ON c.oid = t.tgrelid
        JOIN pg_namespace AS n
          ON n.oid = c.relnamespace
        WHERE NOT t.tgisinternal
          AND n.nspname IN ('ref', 'ops', 'stage')
          AND p.proname IN ('set_actor_on_update', 'set_updated_fields')
    )
    SELECT s.schema_name || '.' || s.table_name
      INTO v_bad_table
    FROM shared_update_tables AS s
    WHERE NOT EXISTS (
        SELECT 1
        FROM ref.audit_collection_policy AS a
        WHERE a.schema_name = s.schema_name
          AND a.collection_name = s.table_name
          AND a.active_flag = true
          AND a.update_actor_enabled = true
    )
    ORDER BY s.schema_name, s.table_name
    LIMIT 1;

    IF v_bad_table IS NOT NULL THEN
        RAISE EXCEPTION
            'Shared UPDATE audit table lacks active update-actor policy: %',
            v_bad_table;
    END IF;

    /*
      Known legacy gaps discovered by #122 must be structurally complete.
    */
    IF NOT EXISTS (
        SELECT 1
        FROM pg_trigger AS t
        JOIN pg_proc AS p ON p.oid = t.tgfoid
        WHERE t.tgrelid = 'ops.work_order_status_history'::regclass
          AND NOT t.tgisinternal
          AND p.proname = 'set_actor_on_insert'
    ) THEN
        RAISE EXCEPTION
            'ops.work_order_status_history is missing shared INSERT actor trigger';
    END IF;

    IF NOT EXISTS (
        SELECT 1
        FROM pg_constraint
        WHERE conrelid = 'ops.work_order_status_history'::regclass
          AND conname = 'fk_wosh_created_by_person'
    ) OR NOT EXISTS (
        SELECT 1
        FROM pg_constraint
        WHERE conrelid = 'ops.work_order_status_history'::regclass
          AND conname = 'fk_wosh_updated_by_person'
    ) THEN
        RAISE EXCEPTION
            'ops.work_order_status_history is missing audit-person foreign keys';
    END IF;

    /*
      The synchronizer itself must require the complete six-field contract.
    */
    SELECT 'ref.sync_audit_collection_policy'
      INTO v_bad_function
    WHERE pg_get_functiondef('ref.sync_audit_collection_policy()'::regprocedure)
          NOT LIKE '%has_created_at%'
       OR pg_get_functiondef('ref.sync_audit_collection_policy()'::regprocedure)
          NOT LIKE '%has_updated_at%'
       OR pg_get_functiondef('ref.sync_audit_collection_policy()'::regprocedure)
          NOT LIKE '%has_created_by_person_id%'
       OR pg_get_functiondef('ref.sync_audit_collection_policy()'::regprocedure)
          NOT LIKE '%has_updated_by_person_id%';

    IF v_bad_function IS NOT NULL THEN
        RAISE EXCEPTION
            'Audit policy synchronizer does not enforce complete six-field contract';
    END IF;
END
$contract$;

DO $validation$
DECLARE
    v_person_1 integer;
    v_person_2 integer;
    v_uuid_1 uuid;
    v_uuid_2 uuid;
    v_name_1 text;
    v_name_2 text;
    v_actual_person integer;
    v_actual_name text;
BEGIN
    SELECT p.person_id, p.directus_user_id, p.preferred_name
      INTO v_person_1, v_uuid_1, v_name_1
    FROM ref.person AS p
    WHERE p.directus_user_id IS NOT NULL
      AND nullif(btrim(p.preferred_name), '') IS NOT NULL
    ORDER BY p.person_id
    LIMIT 1;

    SELECT p.person_id, p.directus_user_id, p.preferred_name
      INTO v_person_2, v_uuid_2, v_name_2
    FROM ref.person AS p
    WHERE p.directus_user_id IS NOT NULL
      AND nullif(btrim(p.preferred_name), '') IS NOT NULL
      AND p.person_id <> v_person_1
    ORDER BY p.person_id
    LIMIT 1;

    IF v_person_1 IS NULL OR v_person_2 IS NULL THEN
        RAISE EXCEPTION
            'Two mapped Directus/MSB people are required for shared audit validation';
    END IF;

    CREATE TEMP TABLE audit_actor_probe (
        probe_id integer PRIMARY KEY,
        payload text NOT NULL,
        created_at timestamptz NOT NULL DEFAULT now(),
        created_by text NOT NULL DEFAULT current_user,
        created_by_person_id integer,
        updated_at timestamptz NOT NULL DEFAULT now(),
        updated_by text NOT NULL DEFAULT current_user,
        updated_by_person_id integer
    ) ON COMMIT DROP;

    CREATE TRIGGER trg_audit_actor_probe
    BEFORE UPDATE ON audit_actor_probe
    FOR EACH ROW EXECUTE FUNCTION ref.set_actor_on_update();

    INSERT INTO audit_actor_probe(
        probe_id,
        payload,
        created_by,
        created_by_person_id,
        updated_by,
        updated_by_person_id
    )
    VALUES (
        1,
        'initial',
        v_name_1,
        v_person_1,
        v_name_1,
        v_person_1
    );

    /*
      Actor 1 updates, then actor 2 updates the same row. The second actor must
      replace the first even though OLD contains non-null audit values.
    */
    PERFORM pg_catalog.set_config('app.directus_user_uuid', v_uuid_1::text, true);

    UPDATE audit_actor_probe
       SET payload = 'actor-1'
     WHERE probe_id = 1;

    SELECT updated_by_person_id, updated_by
      INTO v_actual_person, v_actual_name
    FROM audit_actor_probe
    WHERE probe_id = 1;

    IF v_actual_person IS DISTINCT FROM v_person_1
       OR v_actual_name IS DISTINCT FROM v_name_1 THEN
        RAISE EXCEPTION
            'set_actor_on_update actor-1 stamp failed: expected %/% got %/%',
            v_person_1, v_name_1, v_actual_person, v_actual_name;
    END IF;

    PERFORM pg_catalog.set_config('app.directus_user_uuid', v_uuid_2::text, true);

    UPDATE audit_actor_probe
       SET payload = 'actor-2'
     WHERE probe_id = 1;

    SELECT updated_by_person_id, updated_by
      INTO v_actual_person, v_actual_name
    FROM audit_actor_probe
    WHERE probe_id = 1;

    IF v_actual_person IS DISTINCT FROM v_person_2
       OR v_actual_name IS DISTINCT FROM v_name_2 THEN
        RAISE EXCEPTION
            'set_actor_on_update failed to replace prior updater: expected %/% got %/%',
            v_person_2, v_name_2, v_actual_person, v_actual_name;
    END IF;

    /*
      Exercise the legacy shared Work Order updater too.
    */
    CREATE TEMP TABLE audit_updated_fields_probe (
        probe_id integer PRIMARY KEY,
        payload text NOT NULL,
        created_at timestamptz NOT NULL DEFAULT now(),
        created_by text NOT NULL DEFAULT current_user,
        created_by_person_id integer,
        updated_at timestamptz NOT NULL DEFAULT now(),
        updated_by text NOT NULL DEFAULT current_user,
        updated_by_person_id integer
    ) ON COMMIT DROP;

    CREATE TRIGGER trg_audit_updated_fields_probe
    BEFORE UPDATE ON audit_updated_fields_probe
    FOR EACH ROW EXECUTE FUNCTION ref.set_updated_fields();

    INSERT INTO audit_updated_fields_probe(
        probe_id,
        payload,
        created_by,
        created_by_person_id,
        updated_by,
        updated_by_person_id
    )
    VALUES (
        1,
        'initial',
        v_name_1,
        v_person_1,
        v_name_1,
        v_person_1
    );

    PERFORM pg_catalog.set_config('app.directus_user_uuid', v_uuid_2::text, true);

    UPDATE audit_updated_fields_probe
       SET payload = 'actor-2'
     WHERE probe_id = 1;

    SELECT updated_by_person_id, updated_by
      INTO v_actual_person, v_actual_name
    FROM audit_updated_fields_probe
    WHERE probe_id = 1;

    IF v_actual_person IS DISTINCT FROM v_person_2
       OR v_actual_name IS DISTINCT FROM v_name_2 THEN
        RAISE EXCEPTION
            'set_updated_fields failed to replace prior updater: expected %/% got %/%',
            v_person_2, v_name_2, v_actual_person, v_actual_name;
    END IF;
END
$validation$;

/*
Native Directus does not use the browser-command app.directus_user_uuid path.
Its audit hook stamps updated_by / updated_by_person_id in the DML payload.
Prove that a same-person repeat update is preserved correctly as directus_app.
*/
DO $role_setup$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'directus_app') THEN
        CREATE ROLE directus_app NOLOGIN;
    END IF;
END
$role_setup$;

CREATE TEMP TABLE directus_audit_probe (
    probe_id integer PRIMARY KEY,
    payload text NOT NULL,
    created_at timestamptz NOT NULL DEFAULT now(),
    created_by text NOT NULL,
    created_by_person_id integer,
    updated_at timestamptz NOT NULL DEFAULT now(),
    updated_by text NOT NULL,
    updated_by_person_id integer
) ON COMMIT DROP;

CREATE TRIGGER trg_directus_audit_probe
BEFORE UPDATE ON directus_audit_probe
FOR EACH ROW EXECUTE FUNCTION ref.set_actor_on_update();

INSERT INTO directus_audit_probe(
    probe_id,
    payload,
    created_by,
    created_by_person_id,
    updated_by,
    updated_by_person_id
)
SELECT
    1,
    'initial',
    p.preferred_name,
    p.person_id,
    p.preferred_name,
    p.person_id
FROM ref.person AS p
WHERE p.directus_user_id IS NOT NULL
  AND nullif(btrim(p.preferred_name), '') IS NOT NULL
ORDER BY p.person_id
LIMIT 1;

/*
The disposable clone is restored with --no-acl, so recreate only the minimum
Production-equivalent privilege boundary needed for this native Directus actor
probe. Production grants directus_app schema access; the probe also pins
resolve_actor() execution explicitly rather than relying on default PUBLIC
function privileges.
*/
GRANT USAGE ON SCHEMA ref TO directus_app;
GRANT EXECUTE ON FUNCTION ref.resolve_actor() TO directus_app;
GRANT SELECT ON ref.person TO directus_app;
GRANT SELECT, UPDATE ON directus_audit_probe TO directus_app;

SELECT pg_catalog.set_config('app.directus_user_uuid', '', true);

SET LOCAL ROLE directus_app;

UPDATE directus_audit_probe AS d
   SET payload = 'same-directus-actor',
       updated_by = d.updated_by,
       updated_by_person_id = d.updated_by_person_id
 WHERE d.probe_id = 1;

RESET ROLE;

DO $directus_assert$
DECLARE
    v_person integer;
    v_name text;
    v_expected_person integer;
    v_expected_name text;
BEGIN
    SELECT d.updated_by_person_id, d.updated_by
      INTO v_person, v_name
    FROM directus_audit_probe AS d
    WHERE d.probe_id = 1;

    SELECT p.person_id, p.preferred_name
      INTO v_expected_person, v_expected_name
    FROM ref.person AS p
    WHERE p.directus_user_id IS NOT NULL
      AND nullif(btrim(p.preferred_name), '') IS NOT NULL
    ORDER BY p.person_id
    LIMIT 1;

    IF v_person IS DISTINCT FROM v_expected_person
       OR v_name IS DISTINCT FROM v_expected_name THEN
        RAISE EXCEPTION
            'Native Directus same-actor payload was not preserved: expected %/% got %/%',
            v_expected_person, v_expected_name, v_person, v_name;
    END IF;
END
$directus_assert$;

ROLLBACK;

SELECT 'DATABASE_SHARED_AUDIT_ACTOR_DISPOSABLE_VALIDATION_PASS' AS result;
