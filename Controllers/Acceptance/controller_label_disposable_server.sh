#!/usr/bin/env bash
set -euo pipefail

PROD_CONTAINER="msb-postgres"
PROD_DB="msb"
DB_ACTOR="msbadmin"
IMAGE="postgis/postgis:16-3.5"
NETWORK="msb-stack_default"
TEST_CONTAINER="msb-controller-label-accept-${$}"
TEST_DB="msb_controller_label_test"
TEST_PASSWORD="controller-accept-${$}-$(date +%s)"
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
DUMP_FILE="${SCRIPT_DIR}/production.dump"
REPORT="/tmp/MSB_Controller_Label_Disposable_$(date +%Y%m%d-%H%M%S).txt"
PROD_BEFORE=""

exec > >(tee "$REPORT") 2>&1

echo "========== CONTROLLER LABEL DISPOSABLE ACCEPTANCE =========="
echo "Report: $REPORT"
echo "Production container: $PROD_CONTAINER"
echo "Disposable container: $TEST_CONTAINER"
echo "Image: $IMAGE"
echo

prod_fingerprint() {
    sudo docker exec "$PROD_CONTAINER" \
        psql -X -qAt -v ON_ERROR_STOP=1 -U "$DB_ACTOR" -d "$PROD_DB" -c "
            SELECT md5(
                coalesce((
                    SELECT string_agg(row_to_json(c)::text, '' ORDER BY c.controller_id)
                    FROM ref.controller c
                ), '') || '|' ||
                coalesce((
                    SELECT string_agg(row_to_json(cd)::text, '' ORDER BY cd.controller_id, cd.display_id)
                    FROM ref.controller_display cd
                ), '') || '|' ||
                coalesce((
                    SELECT string_agg(row_to_json(h)::text, '' ORDER BY h.controller_firmware_history_id)
                    FROM ref.controller_firmware_history h
                ), '')
            );
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
            echo "FAIL: production Controller fingerprint changed during disposable acceptance"
            status=97
        else
            echo "PASS: production Controller fingerprint unchanged"
        fi
    else
        echo "Production fingerprint was not captured; review required"
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

for required in docker pg_dump psql; do
    command -v "$required" >/dev/null 2>&1 || true
done

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

for sql_file in \
    "$SCRIPT_DIR/021_create_controller_browser_authorization_contract.sql" \
    "$SCRIPT_DIR/022_create_controller_label_request_command.sql"; do
    if [[ ! -s "$sql_file" ]]; then
        echo "FAIL: required migration missing: $sql_file"
        exit 5
    fi
done

echo "--- Production before-check ---"
PROD_BEFORE="$(prod_fingerprint)"
echo "Fingerprint: $PROD_BEFORE"
sudo docker exec "$PROD_CONTAINER" \
    psql -X -qAt -v ON_ERROR_STOP=1 -U "$DB_ACTOR" -d "$PROD_DB" -c \
    "SELECT 'controllers=' || count(*) FROM ref.controller;"

echo
echo "--- Read-only production dump ---"
sudo docker exec "$PROD_CONTAINER" \
    pg_dump -U "$DB_ACTOR" -d "$PROD_DB" -Fc > "$DUMP_FILE"
test -s "$DUMP_FILE"
echo "Production dump captured: $(du -h "$DUMP_FILE" | awk '{print $1}')"

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
    if sudo docker logs "$TEST_CONTAINER" 2>&1 | grep -q "PostgreSQL init process complete; ready for start up"; then
        ready=1
        break
    fi
    sleep 1
done
if [[ "$ready" -ne 1 ]]; then
    echo "FAIL: disposable PostgreSQL initialization did not complete"
    sudo docker logs "$TEST_CONTAINER" || true
    exit 6
fi

for _ in $(seq 1 60); do
    if sudo docker exec -e PGPASSWORD="$TEST_PASSWORD" "$TEST_CONTAINER" \
        pg_isready -U "$DB_ACTOR" -d postgres >/dev/null 2>&1; then
        break
    fi
    sleep 1
done

sudo docker exec -e PGPASSWORD="$TEST_PASSWORD" "$TEST_CONTAINER" \
    createdb -U "$DB_ACTOR" -T template0 "$TEST_DB"

echo "Disposable PostgreSQL is ready"

echo
echo "--- Restore current production into disposable database ---"
cat "$DUMP_FILE" | sudo docker exec -i -e PGPASSWORD="$TEST_PASSWORD" "$TEST_CONTAINER" \
    pg_restore -U "$DB_ACTOR" -d "$TEST_DB" --no-owner --no-acl --exit-on-error

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
DECLARE
    v_controller_count integer;
BEGIN
    SELECT count(*) INTO v_controller_count FROM ref.controller;
    IF v_controller_count <> 177 THEN
        RAISE EXCEPTION 'Expected 177 Controller rows in current clone, found %', v_controller_count;
    END IF;

    IF to_regprocedure('ref.resolve_actor()') IS NULL
       OR to_regprocedure('ref.set_actor_on_update()') IS NULL THEN
        RAISE EXCEPTION 'Existing actor/audit functions are missing from clone';
    END IF;

    IF to_regclass('public.directus_users') IS NULL
       OR to_regclass('public.directus_roles') IS NULL
       OR to_regclass('public.directus_access') IS NULL
       OR to_regclass('public.directus_policies') IS NULL THEN
        RAISE EXCEPTION 'Directus authorization tables are missing from clone';
    END IF;
END
$block$;

DO $block$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'fieldwiring_app') THEN
        CREATE ROLE fieldwiring_app NOLOGIN;
    END IF;
END
$block$;
GRANT USAGE ON SCHEMA ref TO fieldwiring_app;
SQL

echo "Clone preflight passed"

echo
echo "--- Apply candidate migrations 021 / 022 to disposable only ---"
psql_test < "$SCRIPT_DIR/021_create_controller_browser_authorization_contract.sql"
psql_test < "$SCRIPT_DIR/022_create_controller_label_request_command.sql"

echo
echo "--- Capability and least-privilege assertions ---"
psql_test <<'SQL'
DO $block$
DECLARE
    v_email text;
    v_print boolean;
    v_manage boolean;
BEGIN
    IF NOT has_function_privilege(
        'fieldwiring_app',
        'ref.controller_browser_capabilities(text)',
        'EXECUTE'
    ) THEN
        RAISE EXCEPTION 'fieldwiring_app cannot execute capability function';
    END IF;

    IF NOT has_function_privilege(
        'fieldwiring_app',
        'ref.request_controller_label(text,bigint)',
        'EXECUTE'
    ) THEN
        RAISE EXCEPTION 'fieldwiring_app cannot execute Controller label command';
    END IF;

    IF has_table_privilege('fieldwiring_app', 'ref.controller', 'UPDATE') THEN
        RAISE EXCEPTION 'fieldwiring_app unexpectedly has direct Controller UPDATE';
    END IF;

    SELECT u.email INTO v_email
    FROM public.directus_users u
    JOIN public.directus_roles r ON r.id = u.role
    WHERE u.status = 'active' AND r.name = 'Production Crew'
    ORDER BY u.email
    LIMIT 1;
    IF v_email IS NULL THEN
        RAISE EXCEPTION 'No active Production Crew user exists for capability acceptance';
    END IF;
    SELECT c.can_print_label, c.can_manage_controllers
      INTO v_print, v_manage
    FROM ref.controller_browser_capabilities(v_email) c;
    IF v_print IS DISTINCT FROM true OR v_manage IS DISTINCT FROM false THEN
        RAISE EXCEPTION 'Production Crew capability mismatch for %: print %, manage %', v_email, v_print, v_manage;
    END IF;

    SELECT u.email INTO v_email
    FROM public.directus_users u
    JOIN public.directus_roles r ON r.id = u.role
    WHERE u.status = 'active' AND r.name = 'Manager'
    ORDER BY u.email
    LIMIT 1;
    IF v_email IS NULL THEN
        RAISE EXCEPTION 'No active Manager user exists for capability acceptance';
    END IF;
    SELECT c.can_print_label, c.can_manage_controllers
      INTO v_print, v_manage
    FROM ref.controller_browser_capabilities(v_email) c;
    IF v_print IS DISTINCT FROM true OR v_manage IS DISTINCT FROM true THEN
        RAISE EXCEPTION 'Manager capability mismatch for %: print %, manage %', v_email, v_print, v_manage;
    END IF;

    SELECT u.email INTO v_email
    FROM public.directus_users u
    JOIN public.directus_roles r ON r.id = u.role
    WHERE u.status = 'active' AND r.name = 'Administrator'
    ORDER BY u.email
    LIMIT 1;
    IF v_email IS NULL THEN
        RAISE EXCEPTION 'No active Administrator user exists for capability acceptance';
    END IF;
    SELECT c.can_print_label, c.can_manage_controllers
      INTO v_print, v_manage
    FROM ref.controller_browser_capabilities(v_email) c;
    IF v_print IS DISTINCT FROM true OR v_manage IS DISTINCT FROM true THEN
        RAISE EXCEPTION 'Administrator capability mismatch for %: print %, manage %', v_email, v_print, v_manage;
    END IF;

    SELECT u.email INTO v_email
    FROM public.directus_users u
    JOIN public.directus_roles r ON r.id = u.role
    WHERE u.status = 'active' AND r.name = 'MSB Browser'
    ORDER BY u.email
    LIMIT 1;
    IF v_email IS NULL THEN
        RAISE EXCEPTION 'No active MSB Browser user exists for capability acceptance';
    END IF;
    SELECT c.can_print_label, c.can_manage_controllers
      INTO v_print, v_manage
    FROM ref.controller_browser_capabilities(v_email) c;
    IF v_print IS DISTINCT FROM false OR v_manage IS DISTINCT FROM false THEN
        RAISE EXCEPTION 'MSB Browser capability mismatch for %: print %, manage %', v_email, v_print, v_manage;
    END IF;
END
$block$;
SQL

echo "Capability matrix and least-privilege assertions passed"

echo
echo "--- Clone-only Controller label command / audit proof ---"
ACTOR_ROW="$(psql_test_quiet -F '|' -c "
    SELECT u.email, p.person_id
    FROM public.directus_users u
    JOIN ref.person p ON p.directus_user_id = u.id
    JOIN LATERAL ref.controller_browser_capabilities(u.email) c ON true
    WHERE u.status = 'active'
      AND c.can_print_label
    ORDER BY c.can_manage_controllers DESC, u.email
    LIMIT 1;
")"
if [[ -z "$ACTOR_ROW" ]]; then
    echo "FAIL: no authorized Controller label user is mapped to ref.person"
    exit 7
fi
IFS='|' read -r ACTOR_EMAIL ACTOR_PERSON_ID <<< "$ACTOR_ROW"

TEST_CONTROLLER_ID="$(psql_test_quiet -c "
    SELECT controller_id
    FROM ref.controller
    WHERE print_label = false
    ORDER BY controller_id
    LIMIT 1;
")"
if [[ -z "$TEST_CONTROLLER_ID" ]]; then
    echo "FAIL: no Controller with print_label=false exists in disposable clone"
    exit 8
fi

echo "Clone-only test controller: $TEST_CONTROLLER_ID"
echo "Authorized mapped operator: $ACTOR_EMAIL -> person_id $ACTOR_PERSON_ID"

if psql_test_quiet -c "SET ROLE fieldwiring_app; UPDATE ref.controller SET print_label = true WHERE controller_id = $TEST_CONTROLLER_ID;" >/dev/null 2>&1; then
    echo "FAIL: direct fieldwiring_app UPDATE unexpectedly succeeded"
    exit 9
else
    echo "PASS: direct fieldwiring_app Controller UPDATE denied"
fi

if psql_test_quiet -c "SET ROLE fieldwiring_app; SELECT * FROM ref.request_controller_label('nobody@example.invalid', $TEST_CONTROLLER_ID);" >/dev/null 2>&1; then
    echo "FAIL: unauthorized Controller label request unexpectedly succeeded"
    exit 10
else
    echo "PASS: unauthorized Controller label request denied"
fi

FIRST_RESULT="$(psql_test_quiet -F '|' -c "
    SET ROLE fieldwiring_app;
    SELECT controller_id, print_label, request_already_pending, updated_by_person_id
    FROM ref.request_controller_label('$ACTOR_EMAIL', $TEST_CONTROLLER_ID);
    RESET ROLE;
")"
IFS='|' read -r FIRST_ID FIRST_PRINT FIRST_PENDING FIRST_PERSON <<< "$FIRST_RESULT"
if [[ "$FIRST_ID" != "$TEST_CONTROLLER_ID" || "$FIRST_PRINT" != "t" || "$FIRST_PENDING" != "f" || "$FIRST_PERSON" != "$ACTOR_PERSON_ID" ]]; then
    echo "FAIL: first label request result mismatch: $FIRST_RESULT"
    exit 11
fi

AUDIT_ROW="$(psql_test_quiet -F '|' -c "
    SELECT print_label, updated_by_person_id, updated_by
    FROM ref.controller
    WHERE controller_id = $TEST_CONTROLLER_ID;
")"
IFS='|' read -r AUDIT_PRINT AUDIT_PERSON AUDIT_NAME <<< "$AUDIT_ROW"
if [[ "$AUDIT_PRINT" != "t" || "$AUDIT_PERSON" != "$ACTOR_PERSON_ID" || -z "$AUDIT_NAME" || "$AUDIT_NAME" == "fieldwiring_app" ]]; then
    echo "FAIL: audit actor mismatch after label request: $AUDIT_ROW"
    exit 12
fi

echo "PASS: label request wrote clone-only print_label and stamped mapped person $AUDIT_PERSON ($AUDIT_NAME)"

BEFORE_SECOND="$(psql_test_quiet -c "SELECT updated_at::text FROM ref.controller WHERE controller_id = $TEST_CONTROLLER_ID;")"
SECOND_RESULT="$(psql_test_quiet -F '|' -c "
    SET ROLE fieldwiring_app;
    SELECT controller_id, print_label, request_already_pending, updated_by_person_id
    FROM ref.request_controller_label('$ACTOR_EMAIL', $TEST_CONTROLLER_ID);
    RESET ROLE;
")"
AFTER_SECOND="$(psql_test_quiet -c "SELECT updated_at::text FROM ref.controller WHERE controller_id = $TEST_CONTROLLER_ID;")"
IFS='|' read -r SECOND_ID SECOND_PRINT SECOND_PENDING SECOND_PERSON <<< "$SECOND_RESULT"
if [[ "$SECOND_ID" != "$TEST_CONTROLLER_ID" || "$SECOND_PRINT" != "t" || "$SECOND_PENDING" != "t" ]]; then
    echo "FAIL: idempotent second label request mismatch: $SECOND_RESULT"
    exit 13
fi
if [[ "$AFTER_SECOND" != "$BEFORE_SECOND" ]]; then
    echo "FAIL: idempotent second request changed updated_at"
    exit 14
fi

echo "PASS: repeated pending request is idempotent and does not restamp audit time"

echo
echo "CONTROLLER LABEL DISPOSABLE ACCEPTANCE: PASS"
