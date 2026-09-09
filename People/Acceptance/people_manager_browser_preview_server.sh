#!/usr/bin/env bash
set -euo pipefail

PROD_CONTAINER="msb-postgres"
PROD_DB="msb"
DB_ACTOR="msbadmin"
IMAGE="postgis/postgis:16-3.5"
NETWORK="msb-stack_default"
FIELDWIRING_ROOT="/opt/fieldwiring"
PRODUCTION_PYTHON="/opt/fieldwiring/.venv/bin/python"
TARGET_REF="agent/people-manager-milestone1-20260908"
TARGET_SHA="2de2d244ec7259e52f9d312587a86ef38c7f512f"
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
PREVIEW_ENTRY="$SCRIPT_DIR/people_manager_browser_preview_entry.py"
PREVIEW_PORT="${1:?preview port argument is required}"
PREVIEW_EMAIL="${2:-gliebig@sheboyganlights.org}"
STAMP="$(date +%Y%m%dT%H%M%S)"
TEST_CONTAINER="msb-people-browser-preview-${$}"
TEST_DB="msb"
TEST_PASSWORD="people-preview-${$}-$(date +%s)"
APP_PASSWORD="peopleapp$(date +%s)${$}"
DUMP_FILE="$SCRIPT_DIR/production.dump"
CANDIDATE_WORKTREE="/tmp/msb-people-browser-preview-candidate-$STAMP"
REPORT="/tmp/MSB_People_Manager_Browser_Preview_$STAMP.txt"
PREVIEW_LOG="/tmp/MSB_People_Manager_Browser_Preview_Flask_$STAMP.log"
PREVIEW_PGID=""
PROD_BEFORE=""
LIVE_HEAD=""

exec > >(tee "$REPORT") 2>&1

echo "========== PEOPLE MANAGER PRE-PRODUCTION BROWSER REVIEW =========="
echo "Authority:       MSB-Server-Management — Pre_Production_Browser_Review_Runbook.md"
echo "Clone authority: MSB-Server-Management — PostgreSQL_Disposable_Acceptance_Standard.md"
echo "Report:          $REPORT"
echo "Candidate SHA:   $TARGET_SHA"
echo "Preview port:    $PREVIEW_PORT"
echo "Preview user:    $PREVIEW_EMAIL"
echo "Production DB:   pg_dump + SELECT only"
echo "Preview writes:  disposable PostgreSQL clone only"
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
    echo "--- Browser preview cleanup ---"
    if [[ -n "$PREVIEW_PGID" ]]; then
        sudo kill -- -"$PREVIEW_PGID" >/dev/null 2>&1 || true
        sleep 1
        sudo kill -KILL -- -"$PREVIEW_PGID" >/dev/null 2>&1 || true
    fi

    sudo docker rm -f "$TEST_CONTAINER" >/dev/null 2>&1 || true

    if sudo git -C "$FIELDWIRING_ROOT" worktree list --porcelain 2>/dev/null | grep -Fq "worktree $CANDIDATE_WORKTREE"; then
        sudo git -C "$FIELDWIRING_ROOT" worktree remove --force "$CANDIDATE_WORKTREE" >/dev/null 2>&1 || true
    fi

    rm -f "$DUMP_FILE" >/dev/null 2>&1 || true
    rm -rf "$SCRIPT_DIR" >/dev/null 2>&1 || true

    echo
    echo "--- Production after-check ---"
    if [[ -n "$PROD_BEFORE" ]]; then
        PROD_AFTER="$(prod_fingerprint 2>/dev/null)"
        echo "Person fingerprint before: $PROD_BEFORE"
        echo "Person fingerprint after:  $PROD_AFTER"
        if [[ "$PROD_AFTER" != "$PROD_BEFORE" ]]; then
            echo "FAIL: production ref.person fingerprint changed during browser preview"
            status=97
        else
            echo "PASS: production ref.person fingerprint unchanged"
        fi
    elif [[ "$status" -eq 0 ]]; then
        echo "FAIL: production ref.person fingerprint was not captured"
        status=98
    else
        echo "SKIP: production ref.person fingerprint after-check; preflight exited before fingerprint capture"
    fi

    if [[ -n "$LIVE_HEAD" ]]; then
        CURRENT_HEAD="$(sudo git -C "$FIELDWIRING_ROOT" rev-parse HEAD 2>/dev/null || true)"
        echo "Production checkout before: $LIVE_HEAD"
        echo "Production checkout after:  $CURRENT_HEAD"
        if [[ "$CURRENT_HEAD" != "$LIVE_HEAD" ]]; then
            echo "FAIL: production checkout moved during browser preview"
            status=95
        else
            echo "PASS: production checkout unchanged"
        fi
    fi

    if systemctl is-active --quiet fieldwiring.service \
       && curl -fsS http://192.168.5.9:8790/api/health >/dev/null 2>&1; then
        echo "PASS: production FieldWiring service remains healthy"
    else
        echo "FAIL: production FieldWiring service/health check failed after preview"
        status=94
    fi

    if ss -ltnH "sport = :$PREVIEW_PORT" | grep -q .; then
        echo "FAIL: preview port $PREVIEW_PORT is still listening after cleanup"
        ss -ltnp "sport = :$PREVIEW_PORT" || true
        status=93
    else
        echo "PASS: preview port $PREVIEW_PORT is no longer listening"
    fi

    echo "Preview Flask log retained at: $PREVIEW_LOG"
    echo "Preview report retained at:    $REPORT"
    echo "Exit status: $status"
    exit "$status"
}
trap cleanup EXIT INT TERM

sudo -v

if [[ ! "$PREVIEW_PORT" =~ ^[0-9]+$ ]] || (( PREVIEW_PORT < 1024 || PREVIEW_PORT > 65535 )); then
    echo "FAIL: preview port must be an integer from 1024 through 65535"
    exit 2
fi
if [[ "$PREVIEW_PORT" == "8794" ]]; then
    echo "FAIL: preview port 8794 is the live Production Setup listener"
    exit 3
fi
if [[ "$PREVIEW_PORT" == "8055" || "$PREVIEW_PORT" == "8790" || "$PREVIEW_PORT" == "8792" ]]; then
    echo "FAIL: preview port conflicts with a governed Production listener"
    exit 3
fi
if [[ ! "$PREVIEW_EMAIL" =~ ^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+$ ]]; then
    echo "FAIL: preview operator email is not valid"
    exit 4
fi
if [[ ! -s "$PREVIEW_ENTRY" ]]; then
    echo "FAIL: preview entry file is missing: $PREVIEW_ENTRY"
    exit 5
fi
if ss -ltnH "sport = :$PREVIEW_PORT" | grep -q .; then
    echo "FAIL: preview port $PREVIEW_PORT is already listening on msb-prod-db"
    ss -ltnp "sport = :$PREVIEW_PORT" || true
    exit 6
fi
if ! sudo docker inspect "$PROD_CONTAINER" >/dev/null 2>&1; then
    echo "FAIL: production PostgreSQL container was not found"
    exit 7
fi
if [[ "$(sudo docker inspect "$PROD_CONTAINER" --format '{{.Config.Image}}')" != "$IMAGE" ]]; then
    echo "FAIL: production PostgreSQL image does not match $IMAGE"
    exit 8
fi
if ! sudo docker network inspect "$NETWORK" >/dev/null 2>&1; then
    echo "FAIL: Docker network $NETWORK was not found"
    exit 9
fi
# Server Management runtime boundary: msbadmin cannot traverse protected
# application paths. Validate the production Python runtime as fieldwiring.
if ! sudo -u fieldwiring -H test -x "$PRODUCTION_PYTHON"; then
    echo "FAIL: fieldwiring runtime account cannot execute documented production Python: $PRODUCTION_PYTHON"
    exit 10
fi
if ! systemctl is-active --quiet fieldwiring.service; then
    echo "FAIL: production FieldWiring service is not active before preview"
    exit 11
fi
if ! curl -fsS http://192.168.5.9:8790/api/health >/dev/null; then
    echo "FAIL: production FieldWiring health check failed before preview"
    exit 12
fi

LIVE_HEAD="$(sudo git -C "$FIELDWIRING_ROOT" rev-parse HEAD)"
if [[ -n "$(sudo git -C "$FIELDWIRING_ROOT" status --porcelain)" ]]; then
    echo "FAIL: live shared checkout has uncommitted changes"
    sudo git -C "$FIELDWIRING_ROOT" status -sb
    exit 13
fi

echo "Production checkout remains: $LIVE_HEAD"
PROD_BEFORE="$(prod_fingerprint)"
echo "Production ref.person fingerprint: $PROD_BEFORE"

echo
echo "--- Fetch exact disposable-accepted People metadata runtime plus test repair ---"
sudo git -C "$FIELDWIRING_ROOT" fetch origin "$TARGET_REF"
sudo git -C "$FIELDWIRING_ROOT" cat-file -e "$TARGET_SHA^{commit}"
sudo git -C "$FIELDWIRING_ROOT" worktree add --detach "$CANDIDATE_WORKTREE" "$TARGET_SHA"

MIGRATION_001="$CANDIDATE_WORKTREE/People/Database/001_create_people_manager_contract.sql"
MIGRATION_002="$CANDIDATE_WORKTREE/People/Database/002_harden_people_search_phone_filter.sql"
MIGRATION_003="$CANDIDATE_WORKTREE/People/Database/003_create_people_metadata_contract.sql"
APP_DIR="$CANDIDATE_WORKTREE/People/Application"
TEST_FILE="$CANDIDATE_WORKTREE/People/Application/test_people_manager_contract.py"
for f in "$MIGRATION_001" "$MIGRATION_002" "$MIGRATION_003" "$APP_DIR/backend.py" "$APP_DIR/index.html" "$TEST_FILE"; do
    [[ -s "$f" ]] || { echo "FAIL: exact accepted candidate file missing: $f"; exit 14; }
done

echo "Exact browser-review candidate worktree: $CANDIDATE_WORKTREE"

echo
echo "--- Detached candidate regression in documented production Python ---"
sudo -u fieldwiring -H bash -c \
    "cd '$CANDIDATE_WORKTREE' && '$PRODUCTION_PYTHON' -m pytest -q -p no:cacheprovider People/Application/test_people_manager_contract.py"
echo "DETACHED PEOPLE CANDIDATE REGRESSION: PASS"

echo
echo "--- Capture current Production into disposable clone ---"
sudo docker exec "$PROD_CONTAINER" \
    pg_dump -U "$DB_ACTOR" -d "$PROD_DB" -Fc > "$DUMP_FILE"
test -s "$DUMP_FILE"
sudo docker exec -i "$PROD_CONTAINER" pg_restore --list < "$DUMP_FILE" >/dev/null
echo "Production dump captured and validated: $(du -h "$DUMP_FILE" | awk '{print $1}')"

sudo docker run -d \
    --name "$TEST_CONTAINER" \
    --network "$NETWORK" \
    -e POSTGRES_USER="$DB_ACTOR" \
    -e POSTGRES_PASSWORD="$TEST_PASSWORD" \
    -e POSTGRES_DB=postgres \
    "$IMAGE" >/dev/null

ready=0
pid1=""
for _ in $(seq 1 120); do
    if [[ "$(sudo docker inspect "$TEST_CONTAINER" --format '{{.State.Running}}' 2>/dev/null || true)" != "true" ]]; then
        break
    fi
    pid1="$(sudo docker exec "$TEST_CONTAINER" sh -c 'cat /proc/1/comm' 2>/dev/null | tr -d '\r\n' || true)"
    if [[ "$pid1" == "postgres" ]] && sudo docker exec -e PGPASSWORD="$TEST_PASSWORD" "$TEST_CONTAINER" pg_isready -U "$DB_ACTOR" -d postgres >/dev/null 2>&1; then
        ready=1
        break
    fi
    sleep 1
done
if [[ "$ready" -ne 1 ]]; then
    echo "FAIL: disposable PostgreSQL did not reach final post-init ready state"
    echo "Observed PID 1 command: ${pid1:-unknown}"
    sudo docker logs "$TEST_CONTAINER" || true
    exit 15
fi

echo "Disposable PostgreSQL final server ready"
sudo docker exec -e PGPASSWORD="$TEST_PASSWORD" "$TEST_CONTAINER" createdb -U "$DB_ACTOR" -T template0 "$TEST_DB"
sudo docker exec -i -e PGPASSWORD="$TEST_PASSWORD" "$TEST_CONTAINER" pg_restore -U "$DB_ACTOR" -d "$TEST_DB" --no-owner --no-acl --exit-on-error < "$DUMP_FILE"
echo "Disposable production clone restored"

psql_test() {
    sudo docker exec -i -e PGPASSWORD="$TEST_PASSWORD" "$TEST_CONTAINER" psql -X -v ON_ERROR_STOP=1 -U "$DB_ACTOR" -d "$TEST_DB" "$@"
}

psql_test_quiet() {
    sudo docker exec -i -e PGPASSWORD="$TEST_PASSWORD" "$TEST_CONTAINER" psql -X -qAt -v ON_ERROR_STOP=1 -U "$DB_ACTOR" -d "$TEST_DB" "$@"
}

echo
echo "--- Apply exact accepted People migrations 001-003 to disposable clone ---"
psql_test -c "CREATE ROLE people_app LOGIN PASSWORD '$APP_PASSWORD';"
psql_test < "$MIGRATION_001"
psql_test < "$MIGRATION_002"
psql_test < "$MIGRATION_003"
echo "People candidate migrations 001-003 applied to disposable clone only"

echo
echo "--- Validate preview authorization and least-privilege boundary ---"
MANAGE_OK="$(psql_test_quiet -c "SELECT can_manage_people FROM ref.people_browser_capabilities('$PREVIEW_EMAIL');")"
if [[ "$MANAGE_OK" != "t" ]]; then
    echo "FAIL: preview operator $PREVIEW_EMAIL does not have People Manager capability"
    exit 16
fi

ACTOR_PERSON_ID="$(psql_test_quiet -c "SELECT person_id FROM ref.people_management_actor('$PREVIEW_EMAIL');")"
if [[ ! "$ACTOR_PERSON_ID" =~ ^[0-9]+$ ]]; then
    echo "FAIL: preview operator is not mapped to a governed ref.person actor"
    exit 17
fi

psql_test <<'SQL'
DO $block$
BEGIN
    IF has_table_privilege('people_app', 'ref.person', 'SELECT')
       OR has_table_privilege('people_app', 'ref.person', 'INSERT')
       OR has_table_privilege('people_app', 'ref.person', 'UPDATE')
       OR has_table_privilege('people_app', 'ref.person', 'DELETE')
       OR has_table_privilege('people_app', 'ref.person_capability_type', 'SELECT')
       OR has_table_privilege('people_app', 'ref.person_capability', 'SELECT')
       OR has_table_privilege('people_app', 'ref.person_qualification_type', 'SELECT')
       OR has_table_privilege('people_app', 'ref.person_qualification', 'SELECT')
       OR has_table_privilege('people_app', 'ref.person_setup_role', 'SELECT')
       OR has_table_privilege('people_app', 'ref.setup_task', 'SELECT')
       OR has_table_privilege('people_app', 'ref.setup_task_captain', 'SELECT') THEN
        RAISE EXCEPTION 'Preview people_app unexpectedly has direct People/Setup table privileges';
    END IF;
    IF has_table_privilege('people_app', 'public.directus_users', 'SELECT')
       OR has_table_privilege('people_app', 'public.directus_roles', 'SELECT')
       OR has_table_privilege('people_app', 'public.directus_access', 'SELECT')
       OR has_table_privilege('people_app', 'public.directus_policies', 'SELECT') THEN
        RAISE EXCEPTION 'Preview people_app unexpectedly has direct Directus system-table access';
    END IF;
    IF NOT has_function_privilege('people_app', 'ref.people_search(text,text,boolean)', 'EXECUTE')
       OR NOT has_function_privilege('people_app', 'ref.people_person_detail(text,integer)', 'EXECUTE')
       OR NOT has_function_privilege('people_app', 'ref.people_person_dependencies(text,integer)', 'EXECUTE')
       OR NOT has_function_privilege('people_app', 'ref.people_duplicate_candidates(text,text,text,text,text,text,integer)', 'EXECUTE')
       OR NOT has_function_privilege('people_app', 'ref.people_email_candidates(text,text,text,integer)', 'EXECUTE')
       OR NOT has_function_privilege('people_app', 'ref.create_person_from_people_manager(text,text,text,text,text,text,text,boolean,boolean,boolean)', 'EXECUTE')
       OR NOT has_function_privilege('people_app', 'ref.update_person_from_people_manager(text,integer,text,text,text,text,text,text,boolean,timestamptz,boolean,boolean)', 'EXECUTE')
       OR NOT has_function_privilege('people_app', 'ref.people_capability_catalog(text,boolean)', 'EXECUTE')
       OR NOT has_function_privilege('people_app', 'ref.people_qualification_catalog(text,boolean)', 'EXECUTE')
       OR NOT has_function_privilege('people_app', 'ref.people_person_capabilities(text,integer,boolean)', 'EXECUTE')
       OR NOT has_function_privilege('people_app', 'ref.people_person_qualifications(text,integer,boolean)', 'EXECUTE')
       OR NOT has_function_privilege('people_app', 'ref.people_person_setup_roles(text,integer)', 'EXECUTE')
       OR NOT has_function_privilege('people_app', 'ref.people_person_task_leadership(text,integer)', 'EXECUTE')
       OR NOT has_function_privilege('people_app', 'ref.upsert_people_capability_type(text,integer,text,text,text,boolean,integer)', 'EXECUTE')
       OR NOT has_function_privilege('people_app', 'ref.set_people_person_capability(text,integer,integer,boolean,text)', 'EXECUTE')
       OR NOT has_function_privilege('people_app', 'ref.upsert_people_qualification_type(text,integer,text,text,boolean,integer)', 'EXECUTE')
       OR NOT has_function_privilege('people_app', 'ref.upsert_people_person_qualification(text,bigint,integer,integer,date,date,date,text,text,text,boolean,text)', 'EXECUTE')
       OR NOT has_function_privilege('people_app', 'ref.set_people_person_setup_role(text,integer,text,boolean,text)', 'EXECUTE') THEN
        RAISE EXCEPTION 'Preview people_app is missing approved People function execution';
    END IF;
END
$block$;
SQL

APP_SEARCH_COUNT="$(psql_test_quiet -c "SET ROLE people_app; SELECT count(*) FROM ref.people_search('$PREVIEW_EMAIL','',false);")"
if [[ ! "$APP_SEARCH_COUNT" =~ ^[0-9]+$ ]]; then
    echo "FAIL: preview people_app could not execute governed People search"
    exit 18
fi

echo "Preview operator: $PREVIEW_EMAIL -> person_id $ACTOR_PERSON_ID"
echo "Disposable authorization/write boundary: PASS"

TEST_IP="$(sudo docker inspect "$TEST_CONTAINER" --format '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}')"
if [[ -z "$TEST_IP" ]]; then
    echo "FAIL: could not resolve disposable PostgreSQL container IP"
    exit 19
fi

DSN="host=$TEST_IP port=5432 dbname=$TEST_DB user=people_app password=$APP_PASSWORD"

echo
echo "--- Verify documented Python runtime can load People dependencies ---"
sudo -u fieldwiring -H "$PRODUCTION_PYTHON" -c "import flask, psycopg2; print('People preview Python dependencies: PASS')"

echo
echo "--- Start exact People Manager browser-review candidate ---"
PREVIEW_PGID="$(
    sudo -u fieldwiring -H env \
        PEOPLE_DATABASE_DSN="$DSN" \
        MSB_PREVIEW_APP_DIR="$APP_DIR" \
        MSB_PREVIEW_OPERATOR_EMAIL="$PREVIEW_EMAIL" \
        MSB_PREVIEW_HOST="127.0.0.1" \
        MSB_PREVIEW_PORT="$PREVIEW_PORT" \
        MSB_PREVIEW_ENTRY="$PREVIEW_ENTRY" \
        MSB_PREVIEW_LOG="$PREVIEW_LOG" \
        bash -c '
            setsid /opt/fieldwiring/.venv/bin/python "$MSB_PREVIEW_ENTRY" \
                > "$MSB_PREVIEW_LOG" 2>&1 &
            echo $!
        '
)"

if [[ ! "$PREVIEW_PGID" =~ ^[0-9]+$ ]]; then
    echo "FAIL: preview Flask process did not return a valid process-group ID: $PREVIEW_PGID"
    exit 20
fi

preview_ready=0
for _ in $(seq 1 30); do
    if curl -fsS "http://127.0.0.1:$PREVIEW_PORT/api/health" >/dev/null 2>&1; then
        preview_ready=1
        break
    fi
    sleep 1
done
if [[ "$preview_ready" -ne 1 ]]; then
    echo "FAIL: People Manager preview did not become healthy"
    tail -n 100 "$PREVIEW_LOG" || true
    exit 21
fi

HEALTH="$(curl -fsS "http://127.0.0.1:$PREVIEW_PORT/api/health")"
ACCESS="$(curl -fsS "http://127.0.0.1:$PREVIEW_PORT/api/access")"
PEOPLE_CODE="$(curl -sS -o /tmp/people-preview-list-$STAMP.json -w '%{http_code}' "http://127.0.0.1:$PREVIEW_PORT/api/people")"
CAP_CODE="$(curl -sS -o /tmp/people-preview-cap-$STAMP.json -w '%{http_code}' "http://127.0.0.1:$PREVIEW_PORT/api/catalogs/capabilities")"
QUAL_CODE="$(curl -sS -o /tmp/people-preview-qual-$STAMP.json -w '%{http_code}' "http://127.0.0.1:$PREVIEW_PORT/api/catalogs/qualifications")"
ROLE_CODE="$(curl -sS -o /tmp/people-preview-role-$STAMP.json -w '%{http_code}' "http://127.0.0.1:$PREVIEW_PORT/api/people/$ACTOR_PERSON_ID/setup-roles")"
LEAD_CODE="$(curl -sS -o /tmp/people-preview-lead-$STAMP.json -w '%{http_code}' "http://127.0.0.1:$PREVIEW_PORT/api/people/$ACTOR_PERSON_ID/leadership")"

if [[ "$PEOPLE_CODE" != "200" || "$CAP_CODE" != "200" || "$QUAL_CODE" != "200" || "$ROLE_CODE" != "200" || "$LEAD_CODE" != "200" ]]; then
    echo "FAIL: People Manager preview API readiness failed"
    echo "people=$PEOPLE_CODE capabilities=$CAP_CODE qualifications=$QUAL_CODE setup_roles=$ROLE_CODE leadership=$LEAD_CODE"
    for f in /tmp/people-preview-list-$STAMP.json /tmp/people-preview-cap-$STAMP.json /tmp/people-preview-qual-$STAMP.json /tmp/people-preview-role-$STAMP.json /tmp/people-preview-lead-$STAMP.json; do
        [[ -s "$f" ]] && cat "$f" || true
    done
    rm -f /tmp/people-preview-list-$STAMP.json /tmp/people-preview-cap-$STAMP.json /tmp/people-preview-qual-$STAMP.json /tmp/people-preview-role-$STAMP.json /tmp/people-preview-lead-$STAMP.json
    exit 22
fi
rm -f /tmp/people-preview-list-$STAMP.json /tmp/people-preview-cap-$STAMP.json /tmp/people-preview-qual-$STAMP.json /tmp/people-preview-role-$STAMP.json /tmp/people-preview-lead-$STAMP.json

echo "Preview health: $HEALTH"
echo "Preview access: $ACCESS"
echo "Preview People metadata APIs: PASS"
echo
echo "============================================================"
echo "BROWSER REVIEW READY"
echo "Open on the Windows workstation:"
echo "  http://127.0.0.1:$PREVIEW_PORT/"
echo
echo "Exact browser-review candidate: $TARGET_SHA"
echo "Runtime application/database accepted at: deaa9157282e59e8acd6a7da2a82fc9296e44f20"
echo "Preview identity:                   $PREVIEW_EMAIL"
echo "Production checkout and ref.person remain unchanged."
echo "Every browser write goes to the disposable current-Production clone."
echo
echo "People review checklist:"
echo "  1. Search by name/email/phone and try Include inactive."
echo "  2. Add a clone-only person; Build email and Save person."
echo "  3. Edit/deactivate/reactivate the same clone-only person."
echo "  4. Add a capability catalog item, assign it to the person, edit notes, deactivate/reactivate it."
echo "  5. Add a qualification type and person qualification; exercise completed/valid/expiry dates, role, certificate, evidence, notes, and active state."
echo "  6. Toggle Setup Volunteer, Takedown Volunteer, Captain Candidate, and Advisor Candidate; reopen the person and confirm state persists."
echo "  7. Open a person with existing reusable-task Captain/Alternate/Advisor assignments and confirm leadership is visible but not editable here."
echo "  8. Open a Directus-linked person; confirm protected MSB email/identity behavior remains correct."
echo "  9. Re-test an existing inactive person: activate and save without a false stale-record conflict."
echo " 10. Trigger duplicate-name/contact and MSB-email collision review paths."
echo " 11. Confirm there is no person delete action and no merge action in this candidate."
echo
echo "Suggested clone-only last name for easy review: Preview$STAMP"
echo
echo "When review is finished, return to this PowerShell window and press ENTER."
echo "============================================================"
echo

read -r -p "Press ENTER to stop and clean up the People Manager browser preview... " _unused

echo "Browser review session ended by operator. Cleaning up."
