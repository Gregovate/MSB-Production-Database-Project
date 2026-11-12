#!/usr/bin/env bash
set -euo pipefail
umask 077

PROD_CONTAINER="msb-postgres"
PROD_DB="msb"
DB_ACTOR="msbadmin"
FIELDWIRING_ROOT="/opt/fieldwiring"
PRODUCTION_PYTHON="/opt/fieldwiring/.venv/bin/python"
PRODUCTION_GUNICORN="/opt/fieldwiring/.venv/bin/gunicorn"
FIELDWIRING_SERVICE="fieldwiring.service"
PROCEDURES_SERVICE="msb-procedures.service"
SETUP_SERVICE="msb-setup.service"
PEOPLE_SERVICE="msb-people.service"
PEOPLE_PORT="8796"
PEOPLE_ENV_DIR="/etc/msb-people"
PEOPLE_ENV_FILE="/etc/msb-people/people.env"
PEOPLE_UNIT_FILE="/etc/systemd/system/msb-people.service"
PGPASS_FILE="/var/lib/fieldwiring/.pgpass"
TARGET_REF="agent/people-manager-milestone1-20260908"
TARGET_SHA="54e1192309b96c9838676be51a0bfcdb3ac92e06"
DB_ACCEPTED_SHA="deaa9157282e59e8acd6a7da2a82fc9296e44f20"
BROWSER_ACCEPTED_SHA="4724185fe8cd8831a59c61ea40df61073abbb0c6"
EXPECTED_VERSION="V0.2.0"
PREVIEW_EMAIL="gliebig@sheboyganlights.org"
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
BACKUP_DIR="/home/msbadmin/backups/postgres"
STAMP="$(date +%Y%m%dT%H%M%S)"
BACKUP_FILE="$BACKUP_DIR/msb-pre-people-manager-$STAMP.dump"
REPORT="/tmp/MSB_People_Manager_Production_Deploy_$STAMP.txt"
CANDIDATE_WORKTREE="/tmp/msb-people-production-candidate-$STAMP"
PGPASS_BACKUP="$SCRIPT_DIR/.pgpass.pre-people"
MIGRATION_001=""
MIGRATION_002=""
MIGRATION_003=""
PROD_BEFORE=""
OLD_HEAD=""
APP_PASSWORD=""
DB_CHANGE_STARTED=0
PGPASS_CHANGED=0
APP_ADVANCED=0
SERVICE_INSTALLED=0
UFW_ADDED=0
BACKUP_CREATED=0
SUCCESS=0

exec > >(tee "$REPORT") 2>&1

echo "========== PEOPLE MANAGER PRODUCTION DEPLOYMENT =========="
echo "Authority:        MSB-Server-Management — Production_Database_Change_Deployment_Runbook.md"
echo "Service authority: MSB-Server-Management — Protected_Flask_Application_Service_Deployment.md"
echo "Report:           $REPORT"
echo "Target SHA:       $TARGET_SHA"
echo "DB accepted SHA:  $DB_ACCEPTED_SHA"
echo "Browser accepted: $BROWSER_ACCEPTED_SHA"
echo "Service:          $PEOPLE_SERVICE"
echo "Listener:         192.168.5.9:$PEOPLE_PORT"
echo

prod_person_fingerprint() {
    sudo docker exec "$PROD_CONTAINER" \
        psql -X -qAt -v ON_ERROR_STOP=1 -U "$DB_ACTOR" -d "$PROD_DB" -c "
            SELECT md5(
                coalesce(string_agg(row_to_json(p)::text, '' ORDER BY p.person_id), '')
            )
            FROM ref.person p;
        "
}

psql_prod() {
    sudo docker exec -i "$PROD_CONTAINER" \
        psql -X -v ON_ERROR_STOP=1 -U "$DB_ACTOR" -d "$PROD_DB" "$@"
}

psql_prod_quiet() {
    sudo docker exec -i "$PROD_CONTAINER" \
        psql -X -qAt -v ON_ERROR_STOP=1 -U "$DB_ACTOR" -d "$PROD_DB" "$@"
}

wait_existing_services() {
    for _ in $(seq 1 45); do
        if systemctl is-active --quiet "$FIELDWIRING_SERVICE" \
           && systemctl is-active --quiet "$PROCEDURES_SERVICE" \
           && systemctl is-active --quiet "$SETUP_SERVICE" \
           && curl -fsS http://192.168.5.9:8790/api/health >/dev/null 2>&1 \
           && curl -fsS http://192.168.5.9:8792/api/health >/dev/null 2>&1 \
           && curl -fsS http://192.168.5.9:8794/api/health >/dev/null 2>&1; then
            return 0
        fi
        sleep 1
    done
    return 1
}

restart_shared_services() {
    sudo systemctl restart "$FIELDWIRING_SERVICE" "$PROCEDURES_SERVICE"
    wait_existing_services
}

rollback_people_database() {
    echo "Removing People Manager database objects installed by this deployment..."
    psql_prod <<'SQL'
DO $block$
DECLARE
    r record;
BEGIN
    FOR r IN
        SELECT p.oid::regprocedure AS proc
        FROM pg_proc p
        JOIN pg_namespace n ON n.oid = p.pronamespace
        WHERE n.nspname = 'ref'
          AND (
              p.proname LIKE 'people_%'
              OR p.proname LIKE 'set_people_%'
              OR p.proname LIKE 'upsert_people_%'
              OR p.proname IN ('create_person_from_people_manager', 'update_person_from_people_manager')
          )
        ORDER BY p.oid DESC
    LOOP
        EXECUTE format('DROP FUNCTION IF EXISTS %s CASCADE', r.proc);
    END LOOP;
END
$block$;

DROP TABLE IF EXISTS ref.person_setup_role CASCADE;
DROP TABLE IF EXISTS ref.person_qualification CASCADE;
DROP TABLE IF EXISTS ref.person_qualification_type CASCADE;
DROP TABLE IF EXISTS ref.person_capability CASCADE;
DROP TABLE IF EXISTS ref.person_capability_type CASCADE;

DO $block$
BEGIN
    IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'people_app') THEN
        EXECUTE 'DROP OWNED BY people_app';
        EXECUTE 'DROP ROLE people_app';
    END IF;
END
$block$;
SQL
}

cleanup() {
    status=$?
    trap - EXIT INT TERM
    set +e

    if [[ "$status" -ne 0 && "$SUCCESS" -ne 1 ]]; then
        echo
        echo "--- FAIL-CLOSED PEOPLE ROLLBACK ---"

        if [[ "$UFW_ADDED" -eq 1 ]]; then
            echo "Removing newly-added UFW rule for People port $PEOPLE_PORT"
            sudo ufw --force delete allow from 192.168.5.4 to any port "$PEOPLE_PORT" proto tcp >/dev/null 2>&1 || true
        fi

        if [[ "$SERVICE_INSTALLED" -eq 1 ]]; then
            echo "Removing newly-installed $PEOPLE_SERVICE"
            sudo systemctl disable --now "$PEOPLE_SERVICE" >/dev/null 2>&1 || true
            sudo rm -f "$PEOPLE_UNIT_FILE" >/dev/null 2>&1 || true
            sudo rm -rf "$PEOPLE_ENV_DIR" >/dev/null 2>&1 || true
            sudo systemctl daemon-reload >/dev/null 2>&1 || true
        fi

        if [[ "$APP_ADVANCED" -eq 1 && -n "$OLD_HEAD" ]]; then
            echo "Restoring shared checkout to $OLD_HEAD"
            sudo git -C "$FIELDWIRING_ROOT" reset --hard "$OLD_HEAD" >/dev/null 2>&1 || true
            restart_shared_services || true
        fi

        if [[ "$DB_CHANGE_STARTED" -eq 1 ]]; then
            rollback_people_database || true
        fi

        if [[ "$PGPASS_CHANGED" -eq 1 && -f "$PGPASS_BACKUP" ]]; then
            echo "Restoring fieldwiring .pgpass"
            sudo install -o fieldwiring -g fieldwiring -m 0600 "$PGPASS_BACKUP" "$PGPASS_FILE" >/dev/null 2>&1 || true
        fi
    fi

    if sudo git -C "$FIELDWIRING_ROOT" worktree list --porcelain 2>/dev/null | grep -Fq "worktree $CANDIDATE_WORKTREE"; then
        sudo git -C "$FIELDWIRING_ROOT" worktree remove --force "$CANDIDATE_WORKTREE" >/dev/null 2>&1 || true
    fi

    sudo rm -f "$PGPASS_BACKUP" >/dev/null 2>&1 || true
    rm -rf "$SCRIPT_DIR" >/dev/null 2>&1 || true

    echo
    echo "--- Production ref.person fingerprint after-check ---"
    if [[ -n "$PROD_BEFORE" ]]; then
        PROD_AFTER="$(prod_person_fingerprint 2>/dev/null || true)"
        echo "Before: $PROD_BEFORE"
        echo "After:  $PROD_AFTER"
        if [[ -z "$PROD_AFTER" || "$PROD_AFTER" != "$PROD_BEFORE" ]]; then
            echo "FAIL: production ref.person fingerprint changed during deployment"
            status=97
        else
            echo "PASS: production ref.person fingerprint unchanged"
        fi
    fi

    if [[ "$BACKUP_CREATED" -eq 1 && -s "$BACKUP_FILE" ]]; then
        echo "Rollback backup retained at: $BACKUP_FILE"
    else
        echo "Rollback backup: not created before this stop"
    fi
    echo "Deployment report retained at: $REPORT"
    echo "Exit status: $status"
    exit "$status"
}
trap cleanup EXIT INT TERM

sudo -v
mkdir -p "$BACKUP_DIR"

if ! sudo docker inspect "$PROD_CONTAINER" >/dev/null 2>&1; then
    echo "FAIL: production PostgreSQL container $PROD_CONTAINER was not found"
    exit 2
fi

if ! sudo -u fieldwiring -H test -x "$PRODUCTION_PYTHON" \
   || ! sudo -u fieldwiring -H test -x "$PRODUCTION_GUNICORN"; then
    echo "FAIL: fieldwiring cannot execute the documented shared Python/Gunicorn runtime"
    exit 3
fi

if ! sudo test -f "$PGPASS_FILE"; then
    echo "FAIL: documented fieldwiring .pgpass is missing"
    exit 3
fi
if [[ "$(sudo stat -c '%U:%G %a' "$PGPASS_FILE")" != "fieldwiring:fieldwiring 600" ]]; then
    echo "FAIL: fieldwiring .pgpass owner/mode does not match accepted runtime contract"
    sudo stat -c '%U:%G %a %n' "$PGPASS_FILE"
    exit 3
fi

if ! wait_existing_services; then
    echo "FAIL: one or more existing Production services are unhealthy before People deployment"
    exit 4
fi

echo "PASS: existing FieldWiring / Procedures / Setup services healthy"

if ss -ltnH "sport = :$PEOPLE_PORT" | grep -q .; then
    echo "FAIL: proposed People listener $PEOPLE_PORT is already in use"
    ss -ltnp "sport = :$PEOPLE_PORT" || true
    exit 5
fi
if systemctl cat "$PEOPLE_SERVICE" >/dev/null 2>&1 \
   || [[ -e "$PEOPLE_UNIT_FILE" ]] \
   || [[ -e "$PEOPLE_ENV_DIR" ]]; then
    echo "FAIL: People service/environment already exists; stop for reconciliation"
    exit 6
fi
if sudo ufw status | grep -Eq "(^|[[:space:]])$PEOPLE_PORT/tcp([[:space:]]|$)"; then
    echo "FAIL: UFW already contains a rule for port $PEOPLE_PORT; stop for reconciliation"
    sudo ufw status numbered
    exit 7
fi

OLD_HEAD="$(sudo git -C "$FIELDWIRING_ROOT" rev-parse HEAD)"
echo "Verified live checkout: $OLD_HEAD"
if [[ -n "$(sudo git -C "$FIELDWIRING_ROOT" status --porcelain)" ]]; then
    echo "FAIL: live shared checkout has uncommitted changes"
    sudo git -C "$FIELDWIRING_ROOT" status -sb
    exit 8
fi

PROD_BEFORE="$(prod_person_fingerprint)"
echo "Pre-deploy ref.person fingerprint: $PROD_BEFORE"

echo
echo "--- Fetch and verify exact accepted target ---"
sudo git -C "$FIELDWIRING_ROOT" fetch origin "$TARGET_REF"
for sha in "$TARGET_SHA" "$DB_ACCEPTED_SHA" "$BROWSER_ACCEPTED_SHA"; do
    sudo git -C "$FIELDWIRING_ROOT" cat-file -e "$sha^{commit}"
done
if ! sudo git -C "$FIELDWIRING_ROOT" merge-base --is-ancestor "$OLD_HEAD" "$TARGET_SHA"; then
    echo "FAIL: accepted target is not a fast-forward descendant of the verified live checkout"
    exit 9
fi
if ! sudo git -C "$FIELDWIRING_ROOT" merge-base --is-ancestor "$BROWSER_ACCEPTED_SHA" "$TARGET_SHA"; then
    echo "FAIL: target is not a descendant of the browser-accepted candidate"
    exit 10
fi
if ! sudo git -C "$FIELDWIRING_ROOT" diff --quiet "$DB_ACCEPTED_SHA" "$TARGET_SHA" -- People/Database People/Application/backend.py People/Application/people.js; then
    echo "FAIL: People database/API behavior changed after disposable acceptance"
    sudo git -C "$FIELDWIRING_ROOT" diff --name-only "$DB_ACCEPTED_SHA" "$TARGET_SHA" -- People/Database People/Application/backend.py People/Application/people.js
    exit 11
fi
if ! sudo git -C "$FIELDWIRING_ROOT" diff --quiet "$BROWSER_ACCEPTED_SHA" "$TARGET_SHA" -- People/Application People/Database; then
    echo "FAIL: People runtime changed after browser acceptance"
    sudo git -C "$FIELDWIRING_ROOT" diff --name-only "$BROWSER_ACCEPTED_SHA" "$TARGET_SHA" -- People/Application People/Database
    exit 12
fi
echo "Verified acceptance ancestry and unchanged accepted runtime boundary"

echo
echo "--- Detached production-runtime candidate regression ---"
sudo git -C "$FIELDWIRING_ROOT" worktree add --detach "$CANDIDATE_WORKTREE" "$TARGET_SHA"
MIGRATION_001="$CANDIDATE_WORKTREE/People/Database/001_create_people_manager_contract.sql"
MIGRATION_002="$CANDIDATE_WORKTREE/People/Database/002_harden_people_search_phone_filter.sql"
MIGRATION_003="$CANDIDATE_WORKTREE/People/Database/003_create_people_metadata_contract.sql"
for f in "$MIGRATION_001" "$MIGRATION_002" "$MIGRATION_003" "$CANDIDATE_WORKTREE/People/Application/backend.py" "$CANDIDATE_WORKTREE/People/Application/test_people_manager_contract.py"; do
    [[ -s "$f" ]] || { echo "FAIL: accepted target file missing: $f"; exit 13; }
done
sudo -u fieldwiring -H bash -c \
    "cd '$CANDIDATE_WORKTREE' && '$PRODUCTION_PYTHON' -m pytest -q -p no:cacheprovider People/Application/test_people_manager_contract.py FieldWiring/Application Procedures/Application"
echo "DETACHED CANDIDATE REGRESSION: PASS"

echo
echo "--- Create and validate rollback PostgreSQL archive ---"
sudo docker exec "$PROD_CONTAINER" \
    pg_dump -U "$DB_ACTOR" -d "$PROD_DB" -Fc > "$BACKUP_FILE"
test -s "$BACKUP_FILE"
BACKUP_CREATED=1
BACKUP_SHA="$(sha256sum "$BACKUP_FILE" | awk '{print $1}')"
sudo docker exec -i "$PROD_CONTAINER" pg_restore --list < "$BACKUP_FILE" >/dev/null
echo "Rollback archive: $BACKUP_FILE"
echo "SHA256:          $BACKUP_SHA"
echo "ROLLBACK ARCHIVE VALIDATION: PASS"

echo
echo "--- Production People database preflight ---"
psql_prod <<'SQL'
DO $block$
DECLARE
    v_existing_functions integer;
BEGIN
    IF to_regclass('ref.person') IS NULL THEN
        RAISE EXCEPTION 'ref.person is required';
    END IF;
    IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'people_app') THEN
        RAISE EXCEPTION 'people_app role already exists; stop for reconciliation';
    END IF;
    IF to_regclass('ref.person_capability_type') IS NOT NULL
       OR to_regclass('ref.person_capability') IS NOT NULL
       OR to_regclass('ref.person_qualification_type') IS NOT NULL
       OR to_regclass('ref.person_qualification') IS NOT NULL
       OR to_regclass('ref.person_setup_role') IS NOT NULL THEN
        RAISE EXCEPTION 'One or more People metadata tables already exist; stop for reconciliation';
    END IF;
    SELECT count(*) INTO v_existing_functions
    FROM pg_proc p
    JOIN pg_namespace n ON n.oid = p.pronamespace
    WHERE n.nspname = 'ref'
      AND (
          p.proname LIKE 'people_%'
          OR p.proname LIKE 'set_people_%'
          OR p.proname LIKE 'upsert_people_%'
          OR p.proname IN ('create_person_from_people_manager', 'update_person_from_people_manager')
      );
    IF v_existing_functions <> 0 THEN
        RAISE EXCEPTION 'One or more People Manager functions already exist; stop for reconciliation';
    END IF;
END
$block$;
SQL
echo "DATABASE PREFLIGHT: PASS"

echo
echo "--- Create dedicated People application login and secured libpq credential ---"
DB_CHANGE_STARTED=1
APP_PASSWORD="$(openssl rand -hex 32)"
psql_prod <<SQL
CREATE ROLE people_app LOGIN PASSWORD '$APP_PASSWORD';
SQL
sudo cp -a "$PGPASS_FILE" "$PGPASS_BACKUP"
sudo chmod 0600 "$PGPASS_BACKUP"
PGPASS_NEW="$SCRIPT_DIR/.pgpass.new"
sudo cat "$PGPASS_FILE" > "$PGPASS_NEW"
printf '\n127.0.0.1:5432:msb:people_app:%s\n' "$APP_PASSWORD" >> "$PGPASS_NEW"
sudo install -o fieldwiring -g fieldwiring -m 0600 "$PGPASS_NEW" "$PGPASS_FILE"
rm -f "$PGPASS_NEW"
PGPASS_CHANGED=1
APP_PASSWORD=""
echo "PASS: people_app created and credential installed without logging password"

echo
echo "--- Apply accepted People migrations 001-003 ---"
sudo docker exec -i "$PROD_CONTAINER" psql -X -v ON_ERROR_STOP=1 -U "$DB_ACTOR" -d "$PROD_DB" < "$MIGRATION_001"
sudo docker exec -i "$PROD_CONTAINER" psql -X -v ON_ERROR_STOP=1 -U "$DB_ACTOR" -d "$PROD_DB" < "$MIGRATION_002"
sudo docker exec -i "$PROD_CONTAINER" psql -X -v ON_ERROR_STOP=1 -U "$DB_ACTOR" -d "$PROD_DB" < "$MIGRATION_003"
echo "People migrations 001-003: APPLIED"

echo
echo "--- Validate People least-privilege production boundary ---"
psql_prod <<'SQL'
DO $block$
BEGIN
    IF NOT has_schema_privilege('people_app', 'ref', 'USAGE') THEN
        RAISE EXCEPTION 'people_app lacks ref schema usage';
    END IF;
    IF has_table_privilege('people_app', 'ref.person', 'SELECT')
       OR has_table_privilege('people_app', 'ref.person', 'INSERT')
       OR has_table_privilege('people_app', 'ref.person', 'UPDATE')
       OR has_table_privilege('people_app', 'ref.person', 'DELETE')
       OR has_table_privilege('people_app', 'ref.person_capability', 'SELECT')
       OR has_table_privilege('people_app', 'ref.person_qualification', 'SELECT')
       OR has_table_privilege('people_app', 'ref.person_setup_role', 'SELECT')
       OR has_table_privilege('people_app', 'ref.setup_task_captain', 'SELECT') THEN
        RAISE EXCEPTION 'people_app unexpectedly has direct People/Setup table access';
    END IF;
    IF has_table_privilege('people_app', 'public.directus_users', 'SELECT')
       OR has_table_privilege('people_app', 'public.directus_roles', 'SELECT')
       OR has_table_privilege('people_app', 'public.directus_access', 'SELECT')
       OR has_table_privilege('people_app', 'public.directus_policies', 'SELECT') THEN
        RAISE EXCEPTION 'people_app unexpectedly has direct Directus table access';
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
        RAISE EXCEPTION 'people_app is missing one or more approved People command privileges';
    END IF;
    IF has_function_privilege('people_app', 'ref.people_management_actor(text)', 'EXECUTE') THEN
        RAISE EXCEPTION 'people_app must not execute internal people_management_actor';
    END IF;
END
$block$;
SQL

META_ROWS="$(psql_prod_quiet -c "SELECT (SELECT count(*) FROM ref.person_capability) + (SELECT count(*) FROM ref.person_qualification) + (SELECT count(*) FROM ref.person_setup_role);")"
if [[ "$META_ROWS" != "0" ]]; then
    echo "FAIL: People metadata migrations unexpectedly seeded $META_ROWS relationship rows"
    exit 14
fi
DB_AFTER="$(prod_person_fingerprint)"
if [[ "$DB_AFTER" != "$PROD_BEFORE" ]]; then
    echo "FAIL: ref.person data changed while installing People schema/functions"
    exit 15
fi
echo "PASS: least privilege, no metadata seed rows, ref.person unchanged"

echo
echo "--- Validate fieldwiring runtime can authenticate as people_app ---"
sudo -u fieldwiring -H env PGPASSFILE="$PGPASS_FILE" "$PRODUCTION_PYTHON" - <<'PY'
import psycopg2
conn = psycopg2.connect("host=127.0.0.1 port=5432 dbname=msb user=people_app")
try:
    with conn.cursor() as cur:
        cur.execute("select current_user")
        assert cur.fetchone()[0] == "people_app"
finally:
    conn.close()
print("people_app libpq authentication: PASS")
PY

echo
echo "--- Fast-forward shared Production checkout ---"
sudo git -C "$FIELDWIRING_ROOT" merge --ff-only "$TARGET_SHA"
APP_ADVANCED=1
DEPLOYED_HEAD="$(sudo git -C "$FIELDWIRING_ROOT" rev-parse HEAD)"
if [[ "$DEPLOYED_HEAD" != "$TARGET_SHA" ]]; then
    echo "FAIL: deployed checkout is $DEPLOYED_HEAD, expected $TARGET_SHA"
    exit 16
fi
if ! restart_shared_services; then
    echo "FAIL: existing shared services did not recover after checkout advance"
    exit 17
fi
echo "PASS: shared checkout advanced and existing services healthy"

echo
echo "--- Install permanent People service ---"
sudo install -d -o root -g fieldwiring -m 0750 "$PEOPLE_ENV_DIR"
ENV_TMP="$SCRIPT_DIR/people.env"
cat > "$ENV_TMP" <<'EOF'
PEOPLE_DATABASE_DSN="host=127.0.0.1 port=5432 dbname=msb user=people_app"
EOF
sudo install -o root -g fieldwiring -m 0640 "$ENV_TMP" "$PEOPLE_ENV_FILE"

UNIT_TMP="$SCRIPT_DIR/msb-people.service"
cat > "$UNIT_TMP" <<EOF
[Unit]
Description=MSB People Manager
After=network-online.target docker.service
Wants=network-online.target
Requires=docker.service

[Service]
Type=simple
User=fieldwiring
Group=fieldwiring
WorkingDirectory=$FIELDWIRING_ROOT/People/Application
Environment=HOME=/var/lib/fieldwiring
Environment=PGPASSFILE=$PGPASS_FILE
EnvironmentFile=$PEOPLE_ENV_FILE
ExecStart=$PRODUCTION_GUNICORN --workers 2 --threads 2 --bind 192.168.5.9:$PEOPLE_PORT --timeout 120 --access-logfile - --error-logfile - backend:app
Restart=on-failure
RestartSec=3

[Install]
WantedBy=multi-user.target
EOF
sudo install -o root -g root -m 0644 "$UNIT_TMP" "$PEOPLE_UNIT_FILE"
SERVICE_INSTALLED=1
sudo systemctl daemon-reload
sudo systemctl enable --now "$PEOPLE_SERVICE"

people_ready=0
for _ in $(seq 1 45); do
    if systemctl is-active --quiet "$PEOPLE_SERVICE" \
       && curl -fsS "http://192.168.5.9:$PEOPLE_PORT/api/health" >/tmp/msb-people-health-$STAMP.json 2>/dev/null; then
        people_ready=1
        break
    fi
    sleep 1
done
if [[ "$people_ready" -ne 1 ]]; then
    echo "FAIL: People service did not become healthy"
    sudo systemctl status "$PEOPLE_SERVICE" --no-pager -l || true
    sudo journalctl -u "$PEOPLE_SERVICE" -n 100 --no-pager || true
    exit 18
fi

HEALTH="$(cat /tmp/msb-people-health-$STAMP.json)"
rm -f /tmp/msb-people-health-$STAMP.json
if [[ "$HEALTH" != *"\"status\":\"ok\""* || "$HEALTH" != *"\"version\":\"$EXPECTED_VERSION\""* ]]; then
    echo "FAIL: unexpected People health payload: $HEALTH"
    exit 19
fi
if ! systemctl is-enabled --quiet "$PEOPLE_SERVICE"; then
    echo "FAIL: People service is active but not enabled"
    exit 20
fi
echo "People health: $HEALTH"
echo "PASS: $PEOPLE_SERVICE active, enabled, V0.2.0"

echo
echo "--- Validate People authentication boundary ---"
NO_ID_CODE="$(curl -sS -o /tmp/msb-people-noid-$STAMP.json -w '%{http_code}' "http://192.168.5.9:$PEOPLE_PORT/api/access")"
if [[ "$NO_ID_CODE" != "401" ]]; then
    echo "FAIL: People /api/access without Cloudflare identity returned HTTP $NO_ID_CODE, expected 401"
    cat /tmp/msb-people-noid-$STAMP.json || true
    rm -f /tmp/msb-people-noid-$STAMP.json
    exit 21
fi
rm -f /tmp/msb-people-noid-$STAMP.json
WITH_ID_CODE="$(curl -sS -H "Cf-Access-Authenticated-User-Email: $PREVIEW_EMAIL" -o /tmp/msb-people-withid-$STAMP.json -w '%{http_code}' "http://192.168.5.9:$PEOPLE_PORT/api/access")"
if [[ "$WITH_ID_CODE" != "200" ]]; then
    echo "FAIL: accepted Manager identity could not access People backend; HTTP $WITH_ID_CODE"
    cat /tmp/msb-people-withid-$STAMP.json || true
    rm -f /tmp/msb-people-withid-$STAMP.json
    exit 22
fi
if ! grep -q '"can_manage_people":true' /tmp/msb-people-withid-$STAMP.json; then
    echo "FAIL: accepted Manager identity did not resolve can_manage_people=true"
    cat /tmp/msb-people-withid-$STAMP.json || true
    rm -f /tmp/msb-people-withid-$STAMP.json
    exit 23
fi
rm -f /tmp/msb-people-withid-$STAMP.json
echo "PASS: missing identity -> 401; accepted Manager identity -> authorized"

echo
echo "--- Add source-limited UFW rule for Synology only ---"
sudo ufw allow from 192.168.5.4 to any port "$PEOPLE_PORT" proto tcp comment 'Synology to MSB People'
UFW_ADDED=1
if ! sudo ufw status | grep -E "${PEOPLE_PORT}/tcp[[:space:]]+ALLOW([[:space:]]+IN)?[[:space:]]+192\.168\.5\.4" >/dev/null; then
    echo "FAIL: expected source-limited People UFW rule was not found"
    sudo ufw status numbered
    exit 24
fi
echo "PASS: UFW $PEOPLE_PORT/tcp allows only Synology 192.168.5.4"

echo
echo "--- Final Production regression ---"
if ! wait_existing_services; then
    echo "FAIL: existing Production services unhealthy at final regression"
    exit 25
fi
FINAL_HEAD="$(sudo git -C "$FIELDWIRING_ROOT" rev-parse HEAD)"
if [[ "$FINAL_HEAD" != "$TARGET_SHA" ]]; then
    echo "FAIL: final shared checkout moved unexpectedly: $FINAL_HEAD"
    exit 26
fi
FINAL_FP="$(prod_person_fingerprint)"
if [[ "$FINAL_FP" != "$PROD_BEFORE" ]]; then
    echo "FAIL: final ref.person fingerprint changed"
    exit 27
fi
if ! systemctl is-active --quiet "$PEOPLE_SERVICE" \
   || ! curl -fsS "http://192.168.5.9:$PEOPLE_PORT/api/health" >/dev/null; then
    echo "FAIL: People service failed final health check"
    exit 28
fi

echo "PASS: FieldWiring / Procedures / Setup / People all healthy"
echo "PASS: final checkout = $TARGET_SHA"
echo "PASS: ref.person fingerprint unchanged"
echo
echo "PEOPLE MANAGER PRODUCTION BACKEND DEPLOYMENT: PASS"
echo "Next governed step: Synology protected /people/ route deployment."
SUCCESS=1
