#!/usr/bin/env bash
set -euo pipefail

PROD_CONTAINER="msb-postgres"
PROD_DB="msb"
DB_ACTOR="msbadmin"
IMAGE="postgis/postgis:16-3.5"
NETWORK="msb-stack_default"
TEST_CONTAINER="msb-people-manager-accept-${$}"
TEST_DB="msb"
TEST_PASSWORD="people-manager-accept-${$}-$(date +%s)"
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
DUMP_FILE="${SCRIPT_DIR}/production.dump"
REPORT="/tmp/MSB_People_Manager_Disposable_$(date +%Y%m%d-%H%M%S).txt"
PROD_BEFORE=""
STAMP="$(date +%H%M%S)"

exec > >(tee "$REPORT") 2>&1

echo "========== PEOPLE MANAGER DISPOSABLE ACCEPTANCE =========="
echo "Report: $REPORT"
echo "Production container: $PROD_CONTAINER"
echo "Disposable container: $TEST_CONTAINER"
echo "Production access: pg_dump + SELECT only"
echo

prod_fingerprint() {
    sudo docker exec "$PROD_CONTAINER" \
        psql -X -qAt -v ON_ERROR_STOP=1 -U "$DB_ACTOR" -d "$PROD_DB" -c "
            SELECT md5(
                coalesce(string_agg(row_to_json(p)::text, '' ORDER BY p.person_id), '')
            )
            FROM ref.person p;
        "
}

cleanup() {
    status=$?
    trap - EXIT INT TERM
    set +e

    echo
    echo "--- Production after-check ---"
    if [[ -n "$PROD_BEFORE" ]]; then
        PROD_AFTER="$(prod_fingerprint)"
        echo "Before: $PROD_BEFORE"
        echo "After:  $PROD_AFTER"
        if [[ "$PROD_AFTER" != "$PROD_BEFORE" ]]; then
            echo "FAIL: production ref.person fingerprint changed during disposable acceptance"
            status=97
        else
            echo "PASS: production ref.person fingerprint unchanged"
        fi
    else
        echo "FAIL: production fingerprint was not captured"
        status=98
    fi

    echo
    echo "--- Cleanup ---"
    sudo docker rm -f "$TEST_CONTAINER" >/dev/null 2>&1 || true
    rm -rf "$SCRIPT_DIR" >/dev/null 2>&1 || true
    echo "Disposable container/workdir cleanup attempted"
    echo "Report retained at: $REPORT"
    echo "Exit status: $status"
    exit "$status"
}
trap cleanup EXIT INT TERM

sudo -v

if ! sudo docker inspect "$PROD_CONTAINER" >/dev/null 2>&1; then
    echo "FAIL: production PostgreSQL container $PROD_CONTAINER was not found"
    exit 2
fi

PROD_IMAGE="$(sudo docker inspect "$PROD_CONTAINER" --format '{{.Config.Image}}')"
if [[ "$PROD_IMAGE" != "$IMAGE" ]]; then
    echo "FAIL: production PostgreSQL image is $PROD_IMAGE, expected $IMAGE"
    exit 3
fi

if ! sudo docker network inspect "$NETWORK" >/dev/null 2>&1; then
    echo "FAIL: required Docker network $NETWORK was not found"
    exit 4
fi

SQL001="$SCRIPT_DIR/001_create_people_manager_contract.sql"
SQL002="$SCRIPT_DIR/002_harden_people_search_phone_filter.sql"
for required in "$SQL001" "$SQL002"; do
    if [[ ! -s "$required" ]]; then
        echo "FAIL: required migration missing: $required"
        exit 5
    fi
done

echo "--- Production before-check ---"
PROD_BEFORE="$(prod_fingerprint)"
echo "Fingerprint: $PROD_BEFORE"
sudo docker exec "$PROD_CONTAINER" \
    psql -X -qAt -v ON_ERROR_STOP=1 -U "$DB_ACTOR" -d "$PROD_DB" -c \
    "SELECT 'people=' || count(*) || ', active=' || count(*) FILTER (WHERE active_flag) FROM ref.person;"

echo
echo "--- Read-only production dump ---"
sudo docker exec "$PROD_CONTAINER" \
    pg_dump -U "$DB_ACTOR" -d "$PROD_DB" -Fc > "$DUMP_FILE"
test -s "$DUMP_FILE"
sudo docker exec -i "$PROD_CONTAINER" pg_restore --list < "$DUMP_FILE" >/dev/null
echo "Production dump captured and structurally validated: $(du -h "$DUMP_FILE" | awk '{print $1}')"

echo
echo "--- Start isolated disposable PostgreSQL ---"
sudo docker run -d \
    --name "$TEST_CONTAINER" \
    --network "$NETWORK" \
    -e POSTGRES_USER="$DB_ACTOR" \
    -e POSTGRES_PASSWORD="$TEST_PASSWORD" \
    -e POSTGRES_DB=postgres \
    "$IMAGE" >/dev/null

ready=0
for _ in $(seq 1 120); do
    if sudo docker exec -e PGPASSWORD="$TEST_PASSWORD" "$TEST_CONTAINER" \
        pg_isready -U "$DB_ACTOR" -d postgres >/dev/null 2>&1; then
        ready=1
        break
    fi
    sleep 1
done
if [[ "$ready" -ne 1 ]]; then
    echo "FAIL: disposable PostgreSQL initialization did not become ready"
    sudo docker logs "$TEST_CONTAINER" || true
    exit 6
fi

sudo docker exec -e PGPASSWORD="$TEST_PASSWORD" "$TEST_CONTAINER" \
    createdb -U "$DB_ACTOR" -T template0 "$TEST_DB"

echo "Disposable PostgreSQL is ready"

echo
echo "--- Restore current Production into disposable database ---"
sudo docker exec -i -e PGPASSWORD="$TEST_PASSWORD" "$TEST_CONTAINER" \
    pg_restore -U "$DB_ACTOR" -d "$TEST_DB" --no-owner --no-acl --exit-on-error \
    < "$DUMP_FILE"
echo "Restore completed"

psql_test() {
    sudo docker exec -i -e PGPASSWORD="$TEST_PASSWORD" "$TEST_CONTAINER" \
        psql -X -v ON_ERROR_STOP=1 -U "$DB_ACTOR" -d "$TEST_DB" "$@"
}

psql_test_quiet() {
    sudo docker exec -i -e PGPASSWORD="$TEST_PASSWORD" "$TEST_CONTAINER" \
        psql -X -qAt -v ON_ERROR_STOP=1 -U "$DB_ACTOR" -d "$TEST_DB" "$@"
}

echo
echo "--- Clone preflight ---"
psql_test <<'SQL'
DO $block$
BEGIN
    IF to_regclass('ref.person') IS NULL
       OR to_regclass('ref.person_xref') IS NULL
       OR to_regclass('public.directus_users') IS NULL
       OR to_regclass('public.directus_roles') IS NULL
       OR to_regclass('public.directus_access') IS NULL
       OR to_regclass('public.directus_policies') IS NULL THEN
        RAISE EXCEPTION 'People Manager dependencies are missing from current clone';
    END IF;

    IF to_regprocedure('ref.resolve_actor()') IS NULL
       OR to_regprocedure('ref.set_actor_on_insert()') IS NULL
       OR to_regprocedure('ref.set_actor_on_update()') IS NULL THEN
        RAISE EXCEPTION 'MSB actor/audit functions are missing from current clone';
    END IF;

    IF (SELECT count(*) FROM ref.person) = 0 THEN
        RAISE EXCEPTION 'Current clone contains no ref.person rows';
    END IF;
END
$block$;

DO $block$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'people_app') THEN
        CREATE ROLE people_app NOLOGIN;
    END IF;
END
$block$;
SQL

echo "Clone preflight passed"

echo
echo "--- Apply People Manager migrations to disposable only ---"
psql_test < "$SQL001"
psql_test < "$SQL002"

echo
echo "--- Least-privilege assertions ---"
psql_test <<'SQL'
DO $block$
BEGIN
    IF NOT has_function_privilege('people_app', 'ref.people_search(text,text,boolean)', 'EXECUTE')
       OR NOT has_function_privilege('people_app', 'ref.people_person_detail(text,integer)', 'EXECUTE')
       OR NOT has_function_privilege('people_app', 'ref.people_duplicate_candidates(text,text,text,text,text,text,integer)', 'EXECUTE')
       OR NOT has_function_privilege('people_app', 'ref.people_email_candidates(text,text,text,integer)', 'EXECUTE')
       OR NOT has_function_privilege('people_app', 'ref.create_person_from_people_manager(text,text,text,text,text,text,text,boolean,boolean,boolean)', 'EXECUTE')
       OR NOT has_function_privilege('people_app', 'ref.update_person_from_people_manager(text,integer,text,text,text,text,text,text,boolean,timestamptz,boolean,boolean)', 'EXECUTE') THEN
        RAISE EXCEPTION 'people_app is missing one or more approved function EXECUTE grants';
    END IF;

    IF has_table_privilege('people_app', 'ref.person', 'SELECT')
       OR has_table_privilege('people_app', 'ref.person', 'INSERT')
       OR has_table_privilege('people_app', 'ref.person', 'UPDATE')
       OR has_table_privilege('people_app', 'ref.person', 'DELETE') THEN
        RAISE EXCEPTION 'people_app unexpectedly has direct ref.person table privileges';
    END IF;

    IF has_table_privilege('people_app', 'public.directus_users', 'SELECT')
       OR has_table_privilege('people_app', 'public.directus_roles', 'SELECT')
       OR has_table_privilege('people_app', 'public.directus_access', 'SELECT')
       OR has_table_privilege('people_app', 'public.directus_policies', 'SELECT') THEN
        RAISE EXCEPTION 'people_app unexpectedly has direct Directus system-table read access';
    END IF;
END
$block$;
SQL

echo "Least-privilege assertions passed"

MANAGER_ROW="$(psql_test_quiet -F '|' -c "
    SELECT u.email, p.person_id
    FROM public.directus_users u
    JOIN ref.person p ON p.directus_user_id = u.id
    JOIN LATERAL ref.people_browser_capabilities(u.email) c ON true
    WHERE u.status = 'active' AND c.can_manage_people
    ORDER BY u.email
    LIMIT 1;
")"
if [[ -z "$MANAGER_ROW" ]]; then
    echo "FAIL: no active mapped Manager/Admin acceptance actor"
    exit 7
fi
IFS='|' read -r MANAGER_EMAIL MANAGER_PERSON_ID <<< "$MANAGER_ROW"
echo "Manager acceptance actor: $MANAGER_EMAIL -> person_id $MANAGER_PERSON_ID"

if psql_test_quiet -c "SET ROLE people_app; INSERT INTO ref.person(first_name,last_name,email) VALUES ('Forbidden','Direct','forbidden${STAMP}@sheboyganlights.org');" >/dev/null 2>&1; then
    echo "FAIL: direct people_app ref.person INSERT unexpectedly succeeded"
    exit 8
else
    echo "PASS: direct people_app ref.person INSERT denied"
fi

if psql_test_quiet -c "SET ROLE people_app; SELECT * FROM ref.people_search('nobody@example.invalid','',false);" >/dev/null 2>&1; then
    echo "FAIL: unauthorized People search unexpectedly succeeded"
    exit 9
else
    echo "PASS: unauthorized People search denied"
fi

echo
echo "--- Search hardening proof ---"
SEARCH_TOTAL="$(psql_test_quiet -c "SET ROLE people_app; SELECT count(*) FROM ref.people_search('$MANAGER_EMAIL','zzzz-no-such-person-${STAMP}',true);")"
if [[ "$SEARCH_TOTAL" != "0" ]]; then
    echo "FAIL: non-numeric no-match search returned $SEARCH_TOTAL rows; empty phone-token guard failed"
    exit 10
fi
echo "PASS: non-numeric no-match search does not degrade to match-all"

FIRST_NAME="Acceptance"
LAST_NAME="Clone${STAMP}"
STANDARD_EMAIL="a$(echo "$LAST_NAME" | tr '[:upper:]' '[:lower:]')@sheboyganlights.org"
ALTERNATE_EMAIL="ac$(echo "$LAST_NAME" | tr '[:upper:]' '[:lower:]')@sheboyganlights.org"
PERSONAL_ONE="acceptance.${STAMP}.one@example.invalid"
PERSONAL_TWO="acceptance.${STAMP}.two@example.invalid"

echo
echo "--- Casual-volunteer create + reserved identity + actor audit ---"
CREATE_ROW="$(psql_test_quiet -F '|' -c "
    SET ROLE people_app;
    SELECT person_id,reserved_email
    FROM ref.create_person_from_people_manager(
        '$MANAGER_EMAIL','$FIRST_NAME','$LAST_NAME',NULL,NULL,
        '$PERSONAL_ONE','9205550001',true,false,false
    );
")"
IFS='|' read -r PERSON_ONE_ID CREATED_EMAIL <<< "$CREATE_ROW"
if [[ -z "$PERSON_ONE_ID" || "$CREATED_EMAIL" != "$STANDARD_EMAIL" ]]; then
    echo "FAIL: standard reserved email create mismatch: $CREATE_ROW expected $STANDARD_EMAIL"
    exit 11
fi
AUDIT_PERSON="$(psql_test_quiet -c "SELECT created_by_person_id FROM ref.person WHERE person_id=$PERSON_ONE_ID;")"
if [[ "$AUDIT_PERSON" != "$MANAGER_PERSON_ID" ]]; then
    echo "FAIL: created_by_person_id mismatch: expected $MANAGER_PERSON_ID got $AUDIT_PERSON"
    exit 12
fi
echo "PASS: clone-only person $PERSON_ONE_ID reserved $CREATED_EMAIL; audit person=$AUDIT_PERSON"

echo
echo "--- MSB email collision candidate proof ---"
CANDIDATE_ROW="$(psql_test_quiet -F '|' -c "
    SET ROLE people_app;
    SELECT candidate_email,is_standard,is_available,coalesce(conflicting_source,'')
    FROM ref.people_email_candidates('$MANAGER_EMAIL','$FIRST_NAME','$LAST_NAME',NULL)
    ORDER BY candidate_rank
    LIMIT 2;
")"
echo "$CANDIDATE_ROW"
FIRST_CANDIDATE="$(printf '%s\n' "$CANDIDATE_ROW" | sed -n '1p')"
SECOND_CANDIDATE="$(printf '%s\n' "$CANDIDATE_ROW" | sed -n '2p')"
if [[ "$FIRST_CANDIDATE" != "$STANDARD_EMAIL|t|f|PERSON" ]]; then
    echo "FAIL: standard candidate was not reported as an existing Person collision"
    exit 13
fi
if [[ "$SECOND_CANDIDATE" != "$ALTERNATE_EMAIL|f|t|" ]]; then
    echo "FAIL: expected additional-first-name-character alternate to be available"
    exit 14
fi
echo "PASS: collision suggests explicit additional-first-name-character alternate"

echo
echo "--- Duplicate review gate ---"
if psql_test_quiet -c "
    SET ROLE people_app;
    SELECT * FROM ref.create_person_from_people_manager(
        '$MANAGER_EMAIL','$FIRST_NAME','$LAST_NAME',NULL,'$ALTERNATE_EMAIL',
        '$PERSONAL_TWO','9205550002',true,false,true
    );
" >/dev/null 2>&1; then
    echo "FAIL: duplicate-name create succeeded without duplicate review acknowledgement"
    exit 15
else
    echo "PASS: duplicate-name create blocked before acknowledgement"
fi

CREATE_TWO="$(psql_test_quiet -F '|' -c "
    SET ROLE people_app;
    SELECT person_id,reserved_email
    FROM ref.create_person_from_people_manager(
        '$MANAGER_EMAIL','$FIRST_NAME','$LAST_NAME',NULL,'$ALTERNATE_EMAIL',
        '$PERSONAL_TWO','9205550002',true,true,true
    );
")"
IFS='|' read -r PERSON_TWO_ID CREATED_TWO_EMAIL <<< "$CREATE_TWO"
if [[ -z "$PERSON_TWO_ID" || "$CREATED_TWO_EMAIL" != "$ALTERNATE_EMAIL" ]]; then
    echo "FAIL: reviewed duplicate/alternate create did not succeed as expected"
    exit 16
fi
echo "PASS: explicit duplicate + alternate review permits intentional separate person"

echo
echo "--- Exact MSB email remains hard conflict ---"
if psql_test_quiet -c "
    SET ROLE people_app;
    SELECT * FROM ref.create_person_from_people_manager(
        '$MANAGER_EMAIL','Different','Human${STAMP}',NULL,'$STANDARD_EMAIL',
        'different.${STAMP}@example.invalid','9205550003',true,true,true
    );
" >/dev/null 2>&1; then
    echo "FAIL: exact reserved MSB email collision unexpectedly succeeded"
    exit 17
else
    echo "PASS: exact reserved MSB email collision denied"
fi

echo
echo "--- Inactive/reactivate + optimistic concurrency ---"
TS_BEFORE="$(psql_test_quiet -c "SELECT updated_at FROM ref.person WHERE person_id=$PERSON_TWO_ID;")"
psql_test_quiet -c "
    SET ROLE people_app;
    SELECT * FROM ref.update_person_from_people_manager(
        '$MANAGER_EMAIL',$PERSON_TWO_ID,'$FIRST_NAME','$LAST_NAME',NULL,'$ALTERNATE_EMAIL',
        '$PERSONAL_TWO','9205550002',false,'$TS_BEFORE',false,true
    );
" >/dev/null
if [[ "$(psql_test_quiet -c "SELECT active_flag FROM ref.person WHERE person_id=$PERSON_TWO_ID;")" != "f" ]]; then
    echo "FAIL: person was not marked inactive"
    exit 18
fi

if psql_test_quiet -c "
    SET ROLE people_app;
    SELECT * FROM ref.update_person_from_people_manager(
        '$MANAGER_EMAIL',$PERSON_TWO_ID,'$FIRST_NAME','$LAST_NAME',NULL,'$ALTERNATE_EMAIL',
        '$PERSONAL_TWO','9205550002',true,'$TS_BEFORE',false,true
    );
" >/dev/null 2>&1; then
    echo "FAIL: stale optimistic-concurrency update unexpectedly succeeded"
    exit 19
else
    echo "PASS: stale optimistic-concurrency update denied"
fi

TS_INACTIVE="$(psql_test_quiet -c "SELECT updated_at FROM ref.person WHERE person_id=$PERSON_TWO_ID;")"
psql_test_quiet -c "
    SET ROLE people_app;
    SELECT * FROM ref.update_person_from_people_manager(
        '$MANAGER_EMAIL',$PERSON_TWO_ID,'$FIRST_NAME','$LAST_NAME',NULL,'$ALTERNATE_EMAIL',
        '$PERSONAL_TWO','9205550002',true,'$TS_INACTIVE',false,true
    );
" >/dev/null
if [[ "$(psql_test_quiet -c "SELECT active_flag FROM ref.person WHERE person_id=$PERSON_TWO_ID;")" != "t" ]]; then
    echo "FAIL: person was not reactivated"
    exit 20
fi
echo "PASS: inactive identity preserved and same person_id reactivated"

echo
echo "--- Directus-linked system email protection ---"
MANAGER_CHANGED_EMAIL="peopleaccept${STAMP}@sheboyganlights.org"
if psql_test_quiet -c "
    SET ROLE people_app;
    SELECT * FROM ref.update_person_from_people_manager(
        '$MANAGER_EMAIL',$MANAGER_PERSON_ID,
        (SELECT first_name FROM ref.person WHERE person_id=$MANAGER_PERSON_ID),
        (SELECT last_name FROM ref.person WHERE person_id=$MANAGER_PERSON_ID),
        (SELECT preferred_name FROM ref.person WHERE person_id=$MANAGER_PERSON_ID),
        '$MANAGER_CHANGED_EMAIL',
        (SELECT personal_email FROM ref.person WHERE person_id=$MANAGER_PERSON_ID),
        (SELECT cell_phone FROM ref.person WHERE person_id=$MANAGER_PERSON_ID),
        (SELECT active_flag FROM ref.person WHERE person_id=$MANAGER_PERSON_ID),
        (SELECT updated_at FROM ref.person WHERE person_id=$MANAGER_PERSON_ID),
        true,true
    );
" >/dev/null 2>&1; then
    echo "FAIL: Directus-linked MSB email change unexpectedly succeeded"
    exit 21
else
    echo "PASS: Directus-linked MSB email change denied"
fi

echo
echo "--- Dynamic relationship visibility ---"
psql_test_quiet -c "
    INSERT INTO ref.person_xref(source_system,source_user_id,person_id)
    VALUES ('PEOPLE_ACCEPTANCE','clone-${STAMP}',$PERSON_ONE_ID);
" >/dev/null
DEP_COUNT="$(psql_test_quiet -c "
    SET ROLE people_app;
    SELECT coalesce(sum(reference_count),0)
    FROM ref.people_person_dependencies('$MANAGER_EMAIL',$PERSON_ONE_ID)
    WHERE schema_name='ref' AND table_name='person_xref' AND column_name='person_id';
")"
if [[ "$DEP_COUNT" -lt 1 ]]; then
    echo "FAIL: dynamic person dependency report did not surface ref.person_xref"
    exit 22
fi
echo "PASS: dynamic relationship report surfaced clone-only ref.person_xref dependency"

echo
echo "--- Protected fields remain unchanged ---"
PROTECTED_ROW="$(psql_test_quiet -F '|' -c "
    SELECT directus_user_id::text,coalesce(pg_login_name,''),is_manager,is_team,available_for_work_orders
    FROM ref.person WHERE person_id=$PERSON_ONE_ID;
")"
if [[ "$PROTECTED_ROW" != "| |f|f|f" && "$PROTECTED_ROW" != "||f|f|f" ]]; then
    # The first accepted form depends on psql's rendering of an empty text field.
    # Any non-empty identity/authorization value is a failure for this clone-only person.
    IFS='|' read -r P_DID P_PG P_MANAGER P_TEAM P_WO <<< "$PROTECTED_ROW"
    if [[ -n "$P_DID" || -n "$P_PG" || "$P_MANAGER" != "f" || "$P_TEAM" != "f" || "$P_WO" != "f" ]]; then
        echo "FAIL: protected identity/authorization fields changed unexpectedly: $PROTECTED_ROW"
        exit 23
    fi
fi
echo "PASS: protected identity/authorization fields remain untouched"

echo
echo "--- Candidate database command inventory ---"
psql_test -c "
    SELECT p.proname, pg_get_function_identity_arguments(p.oid) AS args
    FROM pg_proc p
    JOIN pg_namespace n ON n.oid=p.pronamespace
    WHERE n.nspname='ref' AND p.proname LIKE 'people_%'
    ORDER BY p.proname;
"

if psql_test_quiet -c "
    SELECT 1
    FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace
    WHERE n.nspname='ref'
      AND p.proname IN ('delete_person','people_delete_person')
    LIMIT 1;
" | grep -q 1; then
    echo "FAIL: a normal People delete function exists"
    exit 24
fi
echo "PASS: no normal People delete function exists"

echo
echo "PEOPLE MANAGER DISPOSABLE ACCEPTANCE: PASS"
