#!/usr/bin/env bash
set -euo pipefail

PROD_CONTAINER="msb-postgres"
PROD_DB="msb"
DB_ACTOR="msbadmin"
IMAGE="postgis/postgis:16-3.5"
NETWORK="msb-stack_default"
TEST_CONTAINER="msb-people-manager-accept-${$}"
TEST_PASSWORD="people-manager-accept-${$}-$(date +%s)"
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
DUMP_FILE="$SCRIPT_DIR/production.dump"
REPORT="/tmp/MSB_People_Manager_Disposable_$(date +%Y%m%d-%H%M%S).txt"
PROD_BEFORE=""
STAMP="$(date +%H%M%S)"

exec > >(tee "$REPORT") 2>&1

echo "========== PEOPLE MANAGER DISPOSABLE ACCEPTANCE =========="
echo "Report: $REPORT"
echo "Production access: pg_dump + SELECT only"
echo "Candidate migrations: People 001 + 002 + 003"
echo "Authority: MSB-Server-Management — PostgreSQL_Disposable_Acceptance_Standard.md"
echo

prod_fingerprint() {
    sudo docker exec "$PROD_CONTAINER" psql -X -qAt -v ON_ERROR_STOP=1 \
        -U "$DB_ACTOR" -d "$PROD_DB" -c "SELECT md5(coalesce(string_agg(row_to_json(p)::text,'' ORDER BY p.person_id),'')) FROM ref.person p;"
}

cleanup() {
    status=$?
    trap - EXIT INT TERM
    set +e
    echo
    echo "--- Production after-check ---"
    if [[ -n "$PROD_BEFORE" ]]; then
        PROD_AFTER="$(prod_fingerprint 2>/dev/null)"
        echo "Before: $PROD_BEFORE"
        echo "After:  $PROD_AFTER"
        if [[ "$PROD_AFTER" != "$PROD_BEFORE" ]]; then
            echo "FAIL: production ref.person fingerprint changed"
            status=97
        else
            echo "PASS: production ref.person fingerprint unchanged"
        fi
    fi
    sudo docker rm -f "$TEST_CONTAINER" >/dev/null 2>&1 || true
    rm -f "$DUMP_FILE" >/dev/null 2>&1 || true
    echo "Report retained at: $REPORT"
    echo "Exit status: $status"
    exit "$status"
}
trap cleanup EXIT INT TERM

sudo -v
sudo docker inspect "$PROD_CONTAINER" >/dev/null
[[ "$(sudo docker inspect "$PROD_CONTAINER" --format '{{.Config.Image}}')" == "$IMAGE" ]] || { echo "FAIL: unexpected Production PostgreSQL image"; exit 2; }
sudo docker network inspect "$NETWORK" >/dev/null

SQL001="$SCRIPT_DIR/001_create_people_manager_contract.sql"
SQL002="$SCRIPT_DIR/002_harden_people_search_phone_filter.sql"
SQL003="$SCRIPT_DIR/003_create_people_metadata_contract.sql"
for f in "$SQL001" "$SQL002" "$SQL003"; do [[ -s "$f" ]] || { echo "FAIL: missing migration $f"; exit 3; }; done

PROD_BEFORE="$(prod_fingerprint)"
echo "Production ref.person fingerprint: $PROD_BEFORE"

echo "--- Capture current Production ---"
sudo docker exec "$PROD_CONTAINER" pg_dump -U "$DB_ACTOR" -d "$PROD_DB" -Fc > "$DUMP_FILE"
test -s "$DUMP_FILE"
sudo docker exec -i "$PROD_CONTAINER" pg_restore --list < "$DUMP_FILE" >/dev/null

echo "--- Start disposable PostgreSQL ---"
sudo docker run -d --name "$TEST_CONTAINER" --network "$NETWORK" \
    -e POSTGRES_USER="$DB_ACTOR" -e POSTGRES_PASSWORD="$TEST_PASSWORD" -e POSTGRES_DB=postgres "$IMAGE" >/dev/null
ready=0
pid1=""
for _ in $(seq 1 120); do
    [[ "$(sudo docker inspect "$TEST_CONTAINER" --format '{{.State.Running}}' 2>/dev/null || true)" == "true" ]] || break
    pid1="$(sudo docker exec "$TEST_CONTAINER" sh -c 'cat /proc/1/comm' 2>/dev/null | tr -d '\r\n' || true)"
    if [[ "$pid1" == "postgres" ]] && sudo docker exec -e PGPASSWORD="$TEST_PASSWORD" "$TEST_CONTAINER" pg_isready -U "$DB_ACTOR" -d postgres >/dev/null 2>&1; then ready=1; break; fi
    sleep 1
done
[[ "$ready" == "1" ]] || { echo "FAIL: disposable PostgreSQL final server not ready; PID1=${pid1:-unknown}"; sudo docker logs "$TEST_CONTAINER" || true; exit 4; }
sudo docker exec -e PGPASSWORD="$TEST_PASSWORD" "$TEST_CONTAINER" createdb -U "$DB_ACTOR" -T template0 "$PROD_DB"
sudo docker exec -i -e PGPASSWORD="$TEST_PASSWORD" "$TEST_CONTAINER" pg_restore -U "$DB_ACTOR" -d "$PROD_DB" --no-owner --no-acl --exit-on-error < "$DUMP_FILE"
echo "Restore completed"

psql_test() {
    sudo docker exec -i -e PGPASSWORD="$TEST_PASSWORD" "$TEST_CONTAINER" psql -X -v ON_ERROR_STOP=1 -U "$DB_ACTOR" -d "$PROD_DB" "$@"
}
psql_q() {
    sudo docker exec -i -e PGPASSWORD="$TEST_PASSWORD" "$TEST_CONTAINER" psql -X -qAt -v ON_ERROR_STOP=1 -U "$DB_ACTOR" -d "$PROD_DB" "$@"
}

psql_test <<'SQL'
DO $b$
BEGIN
  IF to_regclass('ref.person') IS NULL OR to_regclass('ref.setup_task_captain') IS NULL THEN RAISE EXCEPTION 'People/Setup clone dependencies missing'; END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname='people_app') THEN CREATE ROLE people_app NOLOGIN; END IF;
END
$b$;
SQL

psql_test < "$SQL001"
psql_test < "$SQL002"
psql_test < "$SQL003"
echo "PASS: migrations 001 + 002 + 003 applied to disposable clone"

psql_test <<'SQL'
DO $b$
BEGIN
  IF has_table_privilege('people_app','ref.person','INSERT')
     OR has_table_privilege('people_app','ref.person_capability','INSERT')
     OR has_table_privilege('people_app','ref.person_qualification','INSERT')
     OR has_table_privilege('people_app','ref.person_setup_role','INSERT')
     OR has_table_privilege('people_app','ref.setup_task_captain','INSERT') THEN
    RAISE EXCEPTION 'people_app has unexpected direct DML';
  END IF;
  IF NOT has_function_privilege('people_app','ref.set_people_person_capability(text,integer,integer,boolean,text)','EXECUTE')
     OR NOT has_function_privilege('people_app','ref.upsert_people_person_qualification(text,bigint,integer,integer,date,date,date,text,text,text,boolean,text)','EXECUTE')
     OR NOT has_function_privilege('people_app','ref.set_people_person_setup_role(text,integer,text,boolean,text)','EXECUTE')
     OR NOT has_function_privilege('people_app','ref.people_person_task_leadership(text,integer)','EXECUTE') THEN
    RAISE EXCEPTION 'people_app missing metadata function grants';
  END IF;
END
$b$;
SQL
echo "PASS: least-privilege metadata boundary"

MANAGER_ROW="$(psql_q -F '|' -c "SELECT u.email,p.person_id FROM public.directus_users u JOIN ref.person p ON p.directus_user_id=u.id JOIN LATERAL ref.people_browser_capabilities(u.email) c ON true WHERE u.status='active' AND c.can_manage_people ORDER BY u.email LIMIT 1;")"
[[ -n "$MANAGER_ROW" ]] || { echo "FAIL: no mapped People Manager actor"; exit 5; }
IFS='|' read -r MANAGER_EMAIL MANAGER_PERSON_ID <<< "$MANAGER_ROW"
echo "Acceptance actor: $MANAGER_EMAIL -> person_id $MANAGER_PERSON_ID"

FIRST="Acceptance"
LAST="Metadata${STAMP}"
MSB_EMAIL="a$(echo "$LAST" | tr '[:upper:]' '[:lower:]')@sheboyganlights.org"
CREATE_ROW="$(psql_q -F '|' -c "SET ROLE people_app; SELECT person_id,reserved_email FROM ref.create_person_from_people_manager('$MANAGER_EMAIL','$FIRST','$LAST',NULL,NULL,'acceptance.${STAMP}@example.invalid','9205550001',true,false,false);")"
IFS='|' read -r PERSON_ID CREATED_EMAIL <<< "$CREATE_ROW"
[[ "$CREATED_EMAIL" == "$MSB_EMAIL" && "$PERSON_ID" =~ ^[0-9]+$ ]] || { echo "FAIL: clone person create/email: $CREATE_ROW"; exit 6; }
echo "PASS: clone person create and reserved email"

TS="$(psql_q -c "SELECT updated_at FROM ref.person WHERE person_id=$PERSON_ID;")"
psql_q -c "SET ROLE people_app; SELECT * FROM ref.update_person_from_people_manager('$MANAGER_EMAIL',$PERSON_ID,'$FIRST','$LAST',NULL,'$MSB_EMAIL','acceptance.${STAMP}@example.invalid','9205550001',false,'$TS',false,false);" >/dev/null
[[ "$(psql_q -c "SELECT active_flag FROM ref.person WHERE person_id=$PERSON_ID;")" == "f" ]] || { echo "FAIL: deactivate person"; exit 7; }
TS="$(psql_q -c "SELECT updated_at FROM ref.person WHERE person_id=$PERSON_ID;")"
psql_q -c "SET ROLE people_app; SELECT * FROM ref.update_person_from_people_manager('$MANAGER_EMAIL',$PERSON_ID,'$FIRST','$LAST',NULL,'$MSB_EMAIL','acceptance.${STAMP}@example.invalid','9205550001',true,'$TS',false,false);" >/dev/null
[[ "$(psql_q -c "SELECT active_flag FROM ref.person WHERE person_id=$PERSON_ID;")" == "t" ]] || { echo "FAIL: reactivate person"; exit 8; }
echo "PASS: same person_id deactivate/reactivate"

CAP_ID="$(psql_q -c "SET ROLE people_app; SELECT person_capability_type_id FROM ref.upsert_people_capability_type('$MANAGER_EMAIL',NULL,'Acceptance Welding ${STAMP}','TRADE','clone only',true,10);")"
psql_q -c "SET ROLE people_app; SELECT * FROM ref.set_people_person_capability('$MANAGER_EMAIL',$PERSON_ID,$CAP_ID,true,'clone only');" >/dev/null
CAP_ROW="$(psql_q -F '|' -c "SET ROLE people_app; SELECT capability_category,active_flag FROM ref.people_person_capabilities('$MANAGER_EMAIL',$PERSON_ID,true) WHERE person_capability_type_id=$CAP_ID;")"
[[ "$CAP_ROW" == "TRADE|t" ]] || { echo "FAIL: capability readback $CAP_ROW"; exit 9; }
echo "PASS: capability catalog + person capability"

QUAL_TYPE_ID="$(psql_q -c "SET ROLE people_app; SELECT person_qualification_type_id FROM ref.upsert_people_qualification_type('$MANAGER_EMAIL',NULL,'Acceptance Lift Training ${STAMP}','clone only',true,10);")"
QUAL_ID="$(psql_q -c "SET ROLE people_app; SELECT person_qualification_id FROM ref.upsert_people_person_qualification('$MANAGER_EMAIL',NULL,$PERSON_ID,$QUAL_TYPE_ID,DATE '2026-08-18',DATE '2026-08-18',DATE '2029-08-18','TRAINER','ACCEPT-${STAMP}','clone://evidence/${STAMP}',true,'clone only');")"
QUAL_ROW="$(psql_q -F '|' -c "SET ROLE people_app; SELECT completed_on,valid_from,expires_on,qualification_role,certificate_number,evidence_reference FROM ref.people_person_qualifications('$MANAGER_EMAIL',$PERSON_ID,true) WHERE person_qualification_id=$QUAL_ID;")"
[[ "$QUAL_ROW" == "2026-08-18|2026-08-18|2029-08-18|TRAINER|ACCEPT-${STAMP}|clone://evidence/${STAMP}" ]] || { echo "FAIL: qualification readback $QUAL_ROW"; exit 10; }
echo "PASS: formal qualification dates and evidence"

for ROLE in SETUP_VOLUNTEER TAKEDOWN_VOLUNTEER CAPTAIN_CANDIDATE ADVISOR_CANDIDATE; do
  psql_q -c "SET ROLE people_app; SELECT * FROM ref.set_people_person_setup_role('$MANAGER_EMAIL',$PERSON_ID,'$ROLE',true,'clone only');" >/dev/null
done
[[ "$(psql_q -c "SET ROLE people_app; SELECT count(*) FROM ref.people_person_setup_roles('$MANAGER_EMAIL',$PERSON_ID) WHERE active_flag;")" == "4" ]] || { echo "FAIL: Setup/Takedown role count"; exit 11; }
echo "PASS: Setup/Takedown participation and eligibility roles"

TASK_ID="$(psql_q -c "SELECT setup_task_id FROM ref.setup_task ORDER BY setup_task_id LIMIT 1;")"
[[ "$TASK_ID" =~ ^[0-9]+$ ]] || { echo "FAIL: no reusable Setup task in clone"; exit 12; }
psql_q -c "INSERT INTO ref.setup_task_captain(setup_task_id,person_id,captain_role,sort_order,notes) VALUES ($TASK_ID,$PERSON_ID,'ADVISOR',999,'clone leadership');" >/dev/null
LEAD="$(psql_q -F '|' -c "SET ROLE people_app; SELECT setup_task_id,captain_role FROM ref.people_person_task_leadership('$MANAGER_EMAIL',$PERSON_ID) WHERE setup_task_id=$TASK_ID;")"
[[ "$LEAD" == "$TASK_ID|ADVISOR" ]] || { echo "FAIL: leadership visibility $LEAD"; exit 13; }
if psql_q -c "SET ROLE people_app; INSERT INTO ref.setup_task_captain(setup_task_id,person_id,captain_role) VALUES ($TASK_ID,$MANAGER_PERSON_ID,'ADVISOR');" >/dev/null 2>&1; then echo "FAIL: people_app direct Captain write succeeded"; exit 14; fi
echo "PASS: leadership visible but not directly writable by people_app"

AUDIT="$(psql_q -F '|' -c "SELECT (SELECT created_by_person_id FROM ref.person_capability WHERE person_id=$PERSON_ID AND person_capability_type_id=$CAP_ID),(SELECT created_by_person_id FROM ref.person_qualification WHERE person_qualification_id=$QUAL_ID),(SELECT created_by_person_id FROM ref.person_setup_role WHERE person_id=$PERSON_ID AND setup_role='SETUP_VOLUNTEER');")"
[[ "$AUDIT" == "$MANAGER_PERSON_ID|$MANAGER_PERSON_ID|$MANAGER_PERSON_ID" ]] || { echo "FAIL: metadata actor audit $AUDIT"; exit 15; }
echo "PASS: metadata actor/audit stamping"

if psql_q -c "SELECT 1 FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace WHERE n.nspname='ref' AND p.proname IN ('delete_person','people_delete_person') LIMIT 1;" | grep -q 1; then echo "FAIL: normal People delete function exists"; exit 16; fi
echo "PASS: no normal People delete function exists"

echo
echo "PEOPLE MANAGER DISPOSABLE ACCEPTANCE: PASS"
