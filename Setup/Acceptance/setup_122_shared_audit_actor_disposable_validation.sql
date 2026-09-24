\set ON_ERROR_STOP on

BEGIN;

DO $validation$
DECLARE
    v_task_id bigint;
    v_person_1 integer;
    v_person_2 integer;
    v_uuid_1 uuid;
    v_uuid_2 uuid;
    v_name_1 text;
    v_name_2 text;
    v_actual_person integer;
    v_actual_name text;
BEGIN
    IF to_regprocedure('ref.set_actor_on_update()') IS NULL
       OR to_regprocedure('ref.resolve_actor()') IS NULL THEN
        RAISE EXCEPTION 'Shared audit actor functions are missing';
    END IF;

    SELECT p.person_id, p.directus_user_id, p.preferred_name
      INTO v_person_1, v_uuid_1, v_name_1
    FROM ref.person p
    WHERE p.directus_user_id IS NOT NULL
      AND nullif(btrim(p.preferred_name), '') IS NOT NULL
    ORDER BY p.person_id
    LIMIT 1;

    SELECT p.person_id, p.directus_user_id, p.preferred_name
      INTO v_person_2, v_uuid_2, v_name_2
    FROM ref.person p
    WHERE p.directus_user_id IS NOT NULL
      AND nullif(btrim(p.preferred_name), '') IS NOT NULL
      AND p.person_id <> v_person_1
    ORDER BY p.person_id
    LIMIT 1;

    IF v_person_1 IS NULL OR v_person_2 IS NULL THEN
        RAISE EXCEPTION 'Two mapped Directus/MSB people are required for audit validation';
    END IF;

    SELECT t.setup_task_id
      INTO v_task_id
    FROM ref.setup_task t
    ORDER BY t.setup_task_id
    LIMIT 1;

    IF v_task_id IS NULL THEN
        RAISE EXCEPTION 'No reusable Setup task is available for audit validation';
    END IF;

    /*
      First actor stamps an ordinary UPDATE where audit fields were not
      explicitly supplied by the caller.
    */
    PERFORM pg_catalog.set_config('app.directus_user_uuid', v_uuid_1::text, true);

    UPDATE ref.setup_task t
       SET task_name = t.task_name
     WHERE t.setup_task_id = v_task_id;

    SELECT t.updated_by_person_id, t.updated_by
      INTO v_actual_person, v_actual_name
    FROM ref.setup_task t
    WHERE t.setup_task_id = v_task_id;

    IF v_actual_person IS DISTINCT FROM v_person_1
       OR v_actual_name IS DISTINCT FROM v_name_1 THEN
        RAISE EXCEPTION
            'First actor was not stamped: expected %/% got %/%',
            v_person_1, v_name_1, v_actual_person, v_actual_name;
    END IF;

    /*
      A second actor performs another ordinary UPDATE. This is the regression
      case: the old function kept actor 1 forever because NEW inherited OLD.
    */
    PERFORM pg_catalog.set_config('app.directus_user_uuid', v_uuid_2::text, true);

    UPDATE ref.setup_task t
       SET task_name = t.task_name
     WHERE t.setup_task_id = v_task_id;

    SELECT t.updated_by_person_id, t.updated_by
      INTO v_actual_person, v_actual_name
    FROM ref.setup_task t
    WHERE t.setup_task_id = v_task_id;

    IF v_actual_person IS DISTINCT FROM v_person_2
       OR v_actual_name IS DISTINCT FROM v_name_2 THEN
        RAISE EXCEPTION
            'Second actor did not replace prior updater: expected %/% got %/%',
            v_person_2, v_name_2, v_actual_person, v_actual_name;
    END IF;

    /*
      Native Directus payload behavior is database-wide infrastructure and is
      validated separately by:
      Database/Acceptance/database_shared_audit_actor_disposable_validation.sql
    */
END
$validation$;

ROLLBACK;

SELECT 'SETUP_122_SHARED_AUDIT_BROWSER_COMMAND_VALIDATION_PASS' AS result;
