#!/usr/bin/env bash
set -euo pipefail

PROD_CONTAINER="msb-postgres"
PROD_DB="msb"
DB_ACTOR="msbadmin"
IMAGE="postgis/postgis:16-3.5"
NETWORK="msb-stack_default"
TEST_CONTAINER="msb-controller-management-accept-${$}"
TEST_DB="msb_controller_management_test"
TEST_PASSWORD="controller-management-accept-${$}-$(date +%s)"
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
DUMP_FILE="${SCRIPT_DIR}/production.dump"
REPORT="/tmp/MSB_Controller_Management_Disposable_$(date +%Y%m%d-%H%M%S).txt"
PROD_BEFORE=""

exec > >(tee "$REPORT") 2>&1

echo "========== CONTROLLER MANAGEMENT DISPOSABLE ACCEPTANCE =========="
echo "Report: $REPORT"
echo "Production container: $PROD_CONTAINER"
echo "Disposable container: $TEST_CONTAINER"
echo "Production access: pg_dump + SELECT only"
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

MIGRATION="$SCRIPT_DIR/023_create_controller_management_commands.sql"
if [[ ! -s "$MIGRATION" ]]; then
    echo "FAIL: required migration missing: $MIGRATION"
    exit 5
fi

echo "--- Production before-check ---"
PROD_BEFORE="$(prod_fingerprint)"
echo "Fingerprint: $PROD_BEFORE"
sudo docker exec "$PROD_CONTAINER" \
    psql -X -qAt -v ON_ERROR_STOP=1 -U "$DB_ACTOR" -d "$PROD_DB" -c \
    "SELECT 'controllers=' || count(*) || ', assignments=' || (SELECT count(*) FROM ref.controller_display) FROM ref.controller;"

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
echo "--- Restore current production into disposable database ---"
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
DECLARE
    v_controller_count integer;
BEGIN
    SELECT count(*) INTO v_controller_count FROM ref.controller;
    IF v_controller_count <> 177 THEN
        RAISE EXCEPTION 'Expected 177 Controller rows in current clone, found %', v_controller_count;
    END IF;

    IF to_regprocedure('ref.controller_browser_capabilities(text)') IS NULL
       OR to_regprocedure('ref.request_controller_label(text,bigint)') IS NULL THEN
        RAISE EXCEPTION 'Production Controller browser functions 021/022 are missing from clone';
    END IF;

    IF to_regclass('public.directus_users') IS NULL
       OR to_regclass('ref.person') IS NULL
       OR to_regclass('ref.storage_location') IS NULL THEN
        RAISE EXCEPTION 'Controller management dependencies are missing from clone';
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
-- pg_dump --no-acl intentionally omits production grants. Restore only the
-- already-deployed 021/022 EXECUTE boundary in this disposable clone so the
-- application-role contract matches current production.
GRANT EXECUTE ON FUNCTION ref.controller_browser_capabilities(text) TO fieldwiring_app;
GRANT EXECUTE ON FUNCTION ref.request_controller_label(text,bigint) TO fieldwiring_app;
SQL

echo "Clone preflight passed"

echo
echo "--- Apply candidate migration 023 to disposable only ---"
psql_test < "$MIGRATION"

echo
echo "--- Least-privilege and authorization assertions ---"
psql_test <<'SQL'
DO $block$
DECLARE
    v_manager_email text;
    v_options jsonb;
BEGIN
    IF NOT has_function_privilege('fieldwiring_app', 'ref.create_controller(text,integer,integer,text,integer,text,text,text,integer,text,boolean,text,text,boolean,text,integer,integer,text,text,text)', 'EXECUTE') THEN
        RAISE EXCEPTION 'fieldwiring_app cannot execute create_controller';
    END IF;
    IF NOT has_function_privilege('fieldwiring_app', 'ref.update_controller(text,bigint,integer,integer,text,integer,text,text,text,integer,text,boolean,text,text,boolean,text,integer,integer,text,text,text)', 'EXECUTE') THEN
        RAISE EXCEPTION 'fieldwiring_app cannot execute update_controller';
    END IF;
    IF NOT has_function_privilege('fieldwiring_app', 'ref.assign_controller_display(text,bigint,bigint,bigint,text,text,boolean)', 'EXECUTE') THEN
        RAISE EXCEPTION 'fieldwiring_app cannot execute assign_controller_display';
    END IF;
    IF has_table_privilege('fieldwiring_app', 'ref.controller', 'INSERT')
       OR has_table_privilege('fieldwiring_app', 'ref.controller', 'UPDATE')
       OR has_table_privilege('fieldwiring_app', 'ref.controller', 'DELETE')
       OR has_table_privilege('fieldwiring_app', 'ref.controller_display', 'INSERT')
       OR has_table_privilege('fieldwiring_app', 'ref.controller_display', 'UPDATE')
       OR has_table_privilege('fieldwiring_app', 'ref.controller_display', 'DELETE') THEN
        RAISE EXCEPTION 'fieldwiring_app unexpectedly has broad Controller table DML';
    END IF;
    IF to_regprocedure('ref.delete_controller(text,bigint)') IS NOT NULL THEN
        RAISE EXCEPTION 'Unexpected normal Controller DELETE command exists';
    END IF;

    SELECT u.email INTO v_manager_email
    FROM public.directus_users u
    JOIN ref.person p ON p.directus_user_id = u.id
    JOIN LATERAL ref.controller_browser_capabilities(u.email) c ON true
    WHERE u.status = 'active' AND c.can_manage_controllers
    ORDER BY u.email
    LIMIT 1;
    IF v_manager_email IS NULL THEN
        RAISE EXCEPTION 'No active Manager/Admin mapped to ref.person for acceptance';
    END IF;

    SELECT ref.controller_management_options(v_manager_email) INTO v_options;
    IF jsonb_array_length(v_options->'models') = 0
       OR jsonb_array_length(v_options->'statuses') = 0 THEN
        RAISE EXCEPTION 'Controller management options are incomplete';
    END IF;
END
$block$;
SQL

echo "Least-privilege and authorization assertions passed"

MANAGER_ROW="$(psql_test_quiet -F '|' -c "
    SELECT u.email, p.person_id
    FROM public.directus_users u
    JOIN ref.person p ON p.directus_user_id = u.id
    JOIN LATERAL ref.controller_browser_capabilities(u.email) c ON true
    WHERE u.status = 'active' AND c.can_manage_controllers
    ORDER BY u.email
    LIMIT 1;
")"
if [[ -z "$MANAGER_ROW" ]]; then
    echo "FAIL: no mapped Manager/Admin acceptance actor"
    exit 7
fi
IFS='|' read -r MANAGER_EMAIL MANAGER_PERSON_ID <<< "$MANAGER_ROW"
echo "Manager acceptance actor: $MANAGER_EMAIL -> person_id $MANAGER_PERSON_ID"

if psql_test_quiet -c "SET ROLE fieldwiring_app; INSERT INTO ref.controller(controller_model_id,controller_status_id) SELECT min(controller_model_id),min(controller_status_id) FROM ref.controller_model,ref.controller_status;" >/dev/null 2>&1; then
    echo "FAIL: direct fieldwiring_app Controller INSERT unexpectedly succeeded"
    exit 8
else
    echo "PASS: direct fieldwiring_app Controller INSERT denied"
fi

if psql_test_quiet -c "SET ROLE fieldwiring_app; SELECT * FROM ref.create_controller('nobody@example.invalid',1,1,NULL,NULL,'UNKNOWN',NULL,NULL,NULL,NULL,NULL,'FIELD_VERIFICATION_REQUIRED',NULL,true,NULL,NULL,NULL,NULL,'UNKNOWN',NULL);" >/dev/null 2>&1; then
    echo "FAIL: unauthorized Controller create unexpectedly succeeded"
    exit 9
else
    echo "PASS: unauthorized Controller create denied"
fi

echo
echo "--- Clone-only Add Controller + real-person audit proof ---"
MODEL_ID="$(psql_test_quiet -c "SELECT controller_model_id FROM ref.controller_model ORDER BY controller_model_id LIMIT 1;")"
AVAILABLE_STATUS_ID="$(psql_test_quiet -c "SELECT controller_status_id FROM ref.controller_status WHERE controller_status_name='AVAILABLE';")"
CREATE_ROW="$(psql_test_quiet -F '|' -c "
    SET ROLE fieldwiring_app;
    SELECT controller_id, operator_display_name
    FROM ref.create_controller(
        '$MANAGER_EMAIL',$MODEL_ID,$AVAILABLE_STATUS_ID,
        NULL,NULL,'UNKNOWN',NULL,'DISPOSABLE-ONLY',2026,NULL,NULL,
        'FIELD_VERIFICATION_REQUIRED','Disposable acceptance Controller',true,
        NULL,NULL,NULL,NULL,'UNKNOWN',NULL
    );
    RESET ROLE;
")"
IFS='|' read -r NEW_CONTROLLER_ID CREATE_ACTOR <<< "$CREATE_ROW"
if [[ -z "$NEW_CONTROLLER_ID" || "$NEW_CONTROLLER_ID" -le 1177 ]]; then
    echo "FAIL: expected PostgreSQL-generated Controller ID above 1177, got: $CREATE_ROW"
    exit 10
fi
AUDIT_PERSON="$(psql_test_quiet -c "SELECT created_by_person_id FROM ref.controller WHERE controller_id=$NEW_CONTROLLER_ID;")"
if [[ "$AUDIT_PERSON" != "$MANAGER_PERSON_ID" ]]; then
    echo "FAIL: created_by_person_id mismatch: expected $MANAGER_PERSON_ID got $AUDIT_PERSON"
    exit 11
fi
echo "PASS: created clone-only CTRL $NEW_CONTROLLER_ID; audit person=$AUDIT_PERSON; actor=$CREATE_ACTOR"

echo
echo "--- Programmed configuration / duplicate-address / fixed-count proof ---"
CONFIG_ROW="$(psql_test_quiet -F '|' -c "
    SELECT c.controller_model_id,c.lor_network,c.lor_uid_start,c.lor_uid_count
    FROM ref.controller c
    WHERE c.lor_network IS NOT NULL AND c.lor_uid_start IS NOT NULL AND c.lor_uid_count IS NOT NULL
    ORDER BY c.controller_id
    LIMIT 1;
")"
IFS='|' read -r CONFIG_MODEL CONFIG_NETWORK CONFIG_UID CONFIG_COUNT <<< "$CONFIG_ROW"
if [[ -z "$CONFIG_MODEL" ]]; then
    echo "FAIL: no existing programmed Controller configuration available for duplicate-address proof"
    exit 12
fi

psql_test_quiet -c "
    SET ROLE fieldwiring_app;
    SELECT * FROM ref.update_controller(
        '$MANAGER_EMAIL',$NEW_CONTROLLER_ID,$CONFIG_MODEL,$AVAILABLE_STATUS_ID,
        NULL,NULL,'UNKNOWN',NULL,'DISPOSABLE-ONLY',2026,NULL,NULL,
        'FIELD_VERIFICATION_REQUIRED','Duplicate address is intentionally allowed',true,
        '$CONFIG_NETWORK',$CONFIG_UID,$CONFIG_COUNT,NULL,'RECORDED_UNVERIFIED','Disposable duplicate-address proof'
    );
    RESET ROLE;
" >/dev/null
MATCH_COUNT="$(psql_test_quiet -c "SELECT count(*) FROM ref.controller WHERE controller_model_id=$CONFIG_MODEL AND lor_network='$CONFIG_NETWORK' AND lor_uid_start=$CONFIG_UID AND lor_uid_count=$CONFIG_COUNT;")"
if [[ "$MATCH_COUNT" -lt 2 ]]; then
    echo "FAIL: duplicate Network/UID programming was not retained"
    exit 13
fi
echo "PASS: intentional duplicate Network/UID programming accepted"

FIXED_ROW="$(psql_test_quiet -F '|' -c "
    SELECT controller_model_id,lor_uid_capacity
    FROM ref.controller_model
    WHERE lor_uid_requires_full_capacity AND lor_uid_capacity > 1
    ORDER BY lor_uid_capacity
    LIMIT 1;
")"
IFS='|' read -r FIXED_MODEL FIXED_COUNT <<< "$FIXED_ROW"
if [[ -n "$FIXED_MODEL" ]]; then
    BAD_COUNT=$((FIXED_COUNT - 1))
    if psql_test_quiet -c "
        SET ROLE fieldwiring_app;
        SELECT * FROM ref.update_controller(
            '$MANAGER_EMAIL',$NEW_CONTROLLER_ID,$FIXED_MODEL,$AVAILABLE_STATUS_ID,
            NULL,NULL,'UNKNOWN',NULL,'DISPOSABLE-ONLY',2026,NULL,NULL,
            'FIELD_VERIFICATION_REQUIRED',NULL,true,
            'Aux N',33,$BAD_COUNT,NULL,'RECORDED_UNVERIFIED','Invalid fixed-count proof'
        );
    " >/dev/null 2>&1; then
        echo "FAIL: fixed-capacity model accepted invalid UID count $BAD_COUNT"
        exit 14
    else
        echo "PASS: fixed-capacity model rejected invalid UID count"
    fi
fi

echo
echo "--- Assignment / M:N / reassign / unassign lifecycle proof ---"
readarray -t DISPLAY_IDS < <(psql_test_quiet -c "SELECT display_id FROM ref.display WHERE display_status_id=1 ORDER BY display_id LIMIT 3;")
if [[ "${#DISPLAY_IDS[@]}" -lt 3 ]]; then
    echo "FAIL: fewer than three active Displays available for assignment acceptance"
    exit 15
fi
D1="${DISPLAY_IDS[0]}"
D2="${DISPLAY_IDS[1]}"
D3="${DISPLAY_IDS[2]}"

psql_test_quiet -c "
    SET ROLE fieldwiring_app;
    SELECT * FROM ref.assign_controller_display('$MANAGER_EMAIL',$NEW_CONTROLLER_ID,$D1,NULL,'Disposable assignment 1',NULL,true);
    SELECT * FROM ref.assign_controller_display('$MANAGER_EMAIL',$NEW_CONTROLLER_ID,$D2,NULL,'Disposable assignment 2',NULL,true);
    RESET ROLE;
" >/dev/null
ASSIGN_COUNT="$(psql_test_quiet -c "SELECT count(*) FROM ref.controller_display WHERE controller_id=$NEW_CONTROLLER_ID;")"
STATUS_NAME="$(psql_test_quiet -c "SELECT s.controller_status_name FROM ref.controller c JOIN ref.controller_status s USING(controller_status_id) WHERE c.controller_id=$NEW_CONTROLLER_ID;")"
if [[ "$ASSIGN_COUNT" != "2" || "$STATUS_NAME" != "DEPLOYED" ]]; then
    echo "FAIL: M:N assignment/status proof failed: assignments=$ASSIGN_COUNT status=$STATUS_NAME"
    exit 16
fi
echo "PASS: one Controller assigned to two Displays and AVAILABLE -> DEPLOYED transition applied"

psql_test_quiet -c "
    SET ROLE fieldwiring_app;
    SELECT * FROM ref.reassign_controller_display('$MANAGER_EMAIL',$NEW_CONTROLLER_ID,$D1,$D3,NULL,'Atomic replacement',NULL);
    RESET ROLE;
" >/dev/null
ASSIGN_COUNT="$(psql_test_quiet -c "SELECT count(*) FROM ref.controller_display WHERE controller_id=$NEW_CONTROLLER_ID;")"
OLD_EXISTS="$(psql_test_quiet -c "SELECT count(*) FROM ref.controller_display WHERE controller_id=$NEW_CONTROLLER_ID AND display_id=$D1;")"
NEW_EXISTS="$(psql_test_quiet -c "SELECT count(*) FROM ref.controller_display WHERE controller_id=$NEW_CONTROLLER_ID AND display_id=$D3;")"
if [[ "$ASSIGN_COUNT" != "2" || "$OLD_EXISTS" != "0" || "$NEW_EXISTS" != "1" ]]; then
    echo "FAIL: atomic reassignment proof failed"
    exit 17
fi
echo "PASS: replacement preserved other assignment and moved only selected relationship"

psql_test_quiet -c "
    SET ROLE fieldwiring_app;
    SELECT * FROM ref.unassign_controller_display('$MANAGER_EMAIL',$NEW_CONTROLLER_ID,$D2,true);
    RESET ROLE;
" >/dev/null
STATUS_NAME="$(psql_test_quiet -c "SELECT s.controller_status_name FROM ref.controller c JOIN ref.controller_status s USING(controller_status_id) WHERE c.controller_id=$NEW_CONTROLLER_ID;")"
if [[ "$STATUS_NAME" != "DEPLOYED" ]]; then
    echo "FAIL: non-final unassign changed Controller status unexpectedly: $STATUS_NAME"
    exit 18
fi

psql_test_quiet -c "
    SET ROLE fieldwiring_app;
    SELECT * FROM ref.unassign_controller_display('$MANAGER_EMAIL',$NEW_CONTROLLER_ID,$D3,true);
    RESET ROLE;
" >/dev/null
ASSIGN_COUNT="$(psql_test_quiet -c "SELECT count(*) FROM ref.controller_display WHERE controller_id=$NEW_CONTROLLER_ID;")"
STATUS_NAME="$(psql_test_quiet -c "SELECT s.controller_status_name FROM ref.controller c JOIN ref.controller_status s USING(controller_status_id) WHERE c.controller_id=$NEW_CONTROLLER_ID;")"
if [[ "$ASSIGN_COUNT" != "0" || "$STATUS_NAME" != "AVAILABLE" ]]; then
    echo "FAIL: final unassign lifecycle proof failed: assignments=$ASSIGN_COUNT status=$STATUS_NAME"
    exit 19
fi
echo "PASS: final unassign preserved Controller asset and returned DEPLOYED -> AVAILABLE"

echo
echo "--- REPAIR assignment guard proof ---"
REPAIR_STATUS_ID="$(psql_test_quiet -c "SELECT controller_status_id FROM ref.controller_status WHERE controller_status_name='REPAIR';")"
psql_test_quiet -c "
    SET ROLE fieldwiring_app;
    SELECT * FROM ref.update_controller(
        '$MANAGER_EMAIL',$NEW_CONTROLLER_ID,$CONFIG_MODEL,$REPAIR_STATUS_ID,
        NULL,NULL,'UNKNOWN',NULL,'DISPOSABLE-ONLY',2026,NULL,NULL,
        'FIELD_VERIFICATION_REQUIRED',NULL,true,
        '$CONFIG_NETWORK',$CONFIG_UID,$CONFIG_COUNT,NULL,'RECORDED_UNVERIFIED','Repair assignment guard'
    );
    RESET ROLE;
" >/dev/null
if psql_test_quiet -c "SET ROLE fieldwiring_app; SELECT * FROM ref.assign_controller_display('$MANAGER_EMAIL',$NEW_CONTROLLER_ID,$D1,NULL,NULL,NULL,true);" >/dev/null 2>&1; then
    echo "FAIL: REPAIR Controller assignment unexpectedly succeeded"
    exit 20
else
    echo "PASS: REPAIR Controller assignment denied until status is explicitly changed"
fi

echo
echo "CONTROLLER MANAGEMENT DISPOSABLE ACCEPTANCE: PASS"
