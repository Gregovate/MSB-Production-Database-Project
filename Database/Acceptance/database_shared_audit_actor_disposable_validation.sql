\set ON_ERROR_STOP on

/*
Database-wide disposable validation for shared UPDATE audit attribution.
Runs only on a disposable current-Production clone and rolls back all fixture DML.
*/

BEGIN;

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
    v_bad_function text;
BEGIN
    IF to_regprocedure('ref.resolve_actor()') IS NULL
       OR to_regprocedure('ref.set_actor_on_update()') IS NULL
       OR to_regprocedure('ref.set_updated_fields()') IS NULL THEN
        RAISE EXCEPTION 'Shared database audit actor functions are missing';
    END IF;

    /*
      No UPDATE trigger function may retain the stale-actor COALESCE pattern.
      The INSERT actor function is intentionally outside this check.
    */
    SELECT n.nspname || '.' || p.proname
      INTO v_bad_function
    FROM pg_proc AS p
    JOIN pg_namespace AS n
      ON n.oid = p.pronamespace
    WHERE p.prorettype = 'trigger'::regtype
      AND p.proname <> 'set_actor_on_insert'
      AND p.prosrc ~* 'COALESCE[[:space:]]*\\([[:space:]]*NEW\\.updated_by'
    ORDER BY n.nspname, p.proname
    LIMIT 1;

    IF v_bad_function IS NOT NULL THEN
        RAISE EXCEPTION
            'Stale UPDATE audit COALESCE pattern remains in %',
            v_bad_function;
    END IF;

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
        updated_by,
        updated_by_person_id
    )
    VALUES (1, 'initial', v_name_1, v_person_1);

    /*
      Actor 1 updates, then actor 2 updates the same row. The second actor must
      replace the first even though OLD contains non-null audit values.
    */
    PERFORM pg_catalog.set_config('app.directus_user_uuid', v_uuid_1::text, true);
    UPDATE audit_actor_probe SET payload = 'actor-1' WHERE probe_id = 1;

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
    UPDATE audit_actor_probe SET payload = 'actor-2' WHERE probe_id = 1;

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
        updated_by,
        updated_by_person_id
    )
    VALUES (1, 'initial', v_name_1, v_person_1);

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

ROLLBACK;

SELECT 'DATABASE_SHARED_AUDIT_ACTOR_DISPOSABLE_VALIDATION_PASS' AS result;
