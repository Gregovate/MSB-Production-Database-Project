#!/usr/bin/env bash
set -euo pipefail
umask 077

PROD_CONTAINER="msb-postgres"
PROD_DB="msb"
DB_ACTOR="msbadmin"
FIELDWIRING_ROOT="/opt/fieldwiring"
PRODUCTION_PYTHON="/opt/fieldwiring/.venv/bin/python"
PEOPLE_SERVICE="msb-people.service"
PEOPLE_PORT="8796"
TARGET_REF="agent/people-nullable-email-production-20261001"
TARGET_SHA="953f2b71487de80519f4fc2f8005467ca41983e9"
EXPECTED_OLD_VERSION="V0.2.0"
EXPECTED_NEW_VERSION="V0.2.1"
PREVIEW_EMAIL="gliebig@sheboyganlights.org"

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
BACKUP_DIR="/home/msbadmin/backups/postgres"
STAMP="$(date +%Y%m%dT%H%M%S)"
BACKUP_FILE="$BACKUP_DIR/msb-pre-people-nullable-email-$STAMP.dump"
REPORT="/tmp/MSB_People_Nullable_Email_Production_Deploy_$STAMP.txt"
CANDIDATE_WORKTREE="/tmp/msb-people-nullable-email-candidate-$STAMP"
FUNCTION_ROLLBACK="$SCRIPT_DIR/people-functions-pre-004.sql"

OLD_HEAD=""
PROD_BEFORE=""
BACKUP_CREATED=0
FUNCTION_ROLLBACK_CAPTURED=0
MIGRATION_APPLIED=0
APP_ADVANCED=0
SUCCESS=0

exec > >(tee "$REPORT") 2>&1

echo "========== PEOPLE NULLABLE MSB EMAIL PRODUCTION DEPLOYMENT =========="
echo "Authority:   MSB-Server-Management — Production_Database_Change_Deployment_Runbook.md"
echo "Report:      $REPORT"
echo "Target ref:  $TARGET_REF"
echo "Target SHA:  $TARGET_SHA"
echo "Service:     $PEOPLE_SERVICE"
echo "Listener:    192.168.5.9:$PEOPLE_PORT"
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

people_health() {
    curl -fsS "http://192.168.5.9:$PEOPLE_PORT/api/health"
}

wait_people_version() {
    local expected="$1"
    local payload=""
    for _ in $(seq 1 45); do
        if systemctl is-active --quiet "$PEOPLE_SERVICE"; then
            payload="$(people_health 2>/dev/null || true)"
            if [[ "$payload" == *"\"status\":\"ok\""* && "$payload" == *"\"version\":\"$expected\""* ]]; then
                echo "$payload"
                return 0
            fi
        fi
        sleep 1
    done
    return 1
}

cleanup() {
    status=$?
    trap - EXIT INT TERM
    set +e

    if [[ "$status" -ne 0 && "$SUCCESS" -ne 1 ]]; then
        echo
        echo "--- FAIL-CLOSED ROLLBACK ---"

        if [[ "$APP_ADVANCED" -eq 1 && -n "$OLD_HEAD" ]]; then
            echo "Restoring shared checkout to $OLD_HEAD"
            sudo git -C "$FIELDWIRING_ROOT" reset --hard "$OLD_HEAD" >/dev/null 2>&1 || true
        fi

        if [[ "$MIGRATION_APPLIED" -eq 1 && "$FUNCTION_ROLLBACK_CAPTURED" -eq 1 && -s "$FUNCTION_ROLLBACK" ]]; then
            echo "Restoring pre-004 People Manager function definitions"
            psql_prod < "$FUNCTION_ROLLBACK" >/dev/null 2>&1 || true
        fi

        if [[ "$APP_ADVANCED" -eq 1 || "$MIGRATION_APPLIED" -eq 1 ]]; then
            sudo systemctl restart "$PEOPLE_SERVICE" >/dev/null 2>&1 || true
            wait_people_version "$EXPECTED_OLD_VERSION" >/dev/null 2>&1 || true
        fi
    fi

    if sudo git -C "$FIELDWIRING_ROOT" worktree list --porcelain 2>/dev/null | grep -Fq "worktree $CANDIDATE_WORKTREE"; then
        sudo git -C "$FIELDWIRING_ROOT" worktree remove --force "$CANDIDATE_WORKTREE" >/dev/null 2>&1 || true
    fi

    rm -f "$FUNCTION_ROLLBACK" >/dev/null 2>&1 || true
    rm -rf "$SCRIPT_DIR" >/dev/null 2>&1 || true

    echo
    echo "--- Production ref.person fingerprint after-check ---"
    if [[ -n "$PROD_BEFORE" ]]; then
        PROD_AFTER="$(prod_person_fingerprint 2>/dev/null || true)"
        echo "Before: $PROD_BEFORE"
        echo "After:  $PROD_AFTER"
        if [[ -z "$PROD_AFTER" || "$PROD_AFTER" != "$PROD_BEFORE" ]]; then
            echo "FAIL: Production ref.person fingerprint changed"
            status=97
        else
            echo "PASS: Production ref.person fingerprint unchanged"
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

echo "--- Existing Production People runtime preflight ---"
sudo docker inspect "$PROD_CONTAINER" >/dev/null
systemctl is-active --quiet "$PEOPLE_SERVICE" || { echo "FAIL: $PEOPLE_SERVICE is not active"; exit 2; }
systemctl is-enabled --quiet "$PEOPLE_SERVICE" || { echo "FAIL: $PEOPLE_SERVICE is not enabled"; exit 2; }
systemctl cat "$PEOPLE_SERVICE" >/dev/null || { echo "FAIL: People systemd unit is missing"; exit 2; }
ss -ltnH "sport = :$PEOPLE_PORT" | grep -q . || { echo "FAIL: People listener $PEOPLE_PORT is not active"; exit 2; }

OLD_HEALTH="$(people_health)"
if [[ "$OLD_HEALTH" != *"\"version\":\"$EXPECTED_OLD_VERSION\""* ]]; then
    echo "FAIL: expected live People $EXPECTED_OLD_VERSION, got: $OLD_HEALTH"
    exit 3
fi
echo "Current People health: $OLD_HEALTH"

if ! psql_prod_quiet -c "SELECT 1 FROM pg_roles WHERE rolname='people_app';" | grep -qx 1; then
    echo "FAIL: existing people_app PostgreSQL role is missing"
    exit 4
fi

for signature in \
    "ref.create_person_from_people_manager(text,text,text,text,text,text,text,boolean,boolean,boolean)" \
    "ref.update_person_from_people_manager(text,integer,text,text,text,text,text,text,boolean,timestamptz,boolean,boolean)"; do
    psql_prod_quiet -c "SELECT to_regprocedure('$signature') IS NOT NULL;" | grep -qx t || {
        echo "FAIL: required People function missing: $signature"
        exit 4
    }
done

OLD_HEAD="$(sudo git -C "$FIELDWIRING_ROOT" rev-parse HEAD)"
echo "Verified live checkout: $OLD_HEAD"
if [[ -n "$(sudo git -C "$FIELDWIRING_ROOT" status --porcelain)" ]]; then
    echo "FAIL: live shared checkout has uncommitted changes"
    sudo git -C "$FIELDWIRING_ROOT" status -sb
    exit 5
fi

PROD_BEFORE="$(prod_person_fingerprint)"
echo "Pre-deploy ref.person fingerprint: $PROD_BEFORE"

echo
echo "--- Fetch and verify exact accepted runtime target ---"
sudo git -C "$FIELDWIRING_ROOT" fetch origin "$TARGET_REF"
sudo git -C "$FIELDWIRING_ROOT" cat-file -e "$TARGET_SHA^{commit}"

if ! sudo git -C "$FIELDWIRING_ROOT" merge-base --is-ancestor "$OLD_HEAD" "$TARGET_SHA"; then
    echo "FAIL: accepted target is not a fast-forward descendant of verified live checkout"
    exit 6
fi

echo
echo "--- Detached Production-runtime regression ---"
sudo git -C "$FIELDWIRING_ROOT" worktree add --detach "$CANDIDATE_WORKTREE" "$TARGET_SHA"
MIGRATION_004="$CANDIDATE_WORKTREE/People/Database/004_stop_automatic_msb_email_generation.sql"
TEST_FILE="$CANDIDATE_WORKTREE/People/Application/test_people_manager_contract.py"

for f in "$MIGRATION_004" "$TEST_FILE" "$CANDIDATE_WORKTREE/People/Application/backend.py" "$CANDIDATE_WORKTREE/People/Application/people.js" "$CANDIDATE_WORKTREE/People/Application/index.html"; do
    [[ -s "$f" ]] || { echo "FAIL: accepted runtime file missing: $f"; exit 7; }
done

sudo -u fieldwiring -H bash -c \
    "cd '$CANDIDATE_WORKTREE' && '$PRODUCTION_PYTHON' -m pytest -q -p no:cacheprovider People/Application/test_people_manager_contract.py"
echo "DETACHED PEOPLE CANDIDATE REGRESSION: PASS"

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
echo "--- Capture exact pre-004 function rollback definitions ---"
{
    psql_prod_quiet -c "SELECT pg_get_functiondef('ref.create_person_from_people_manager(text,text,text,text,text,text,text,boolean,boolean,boolean)'::regprocedure);"
    echo
    psql_prod_quiet -c "SELECT pg_get_functiondef('ref.update_person_from_people_manager(text,integer,text,text,text,text,text,text,boolean,timestamptz,boolean,boolean)'::regprocedure);"
} > "$FUNCTION_ROLLBACK"
test -s "$FUNCTION_ROLLBACK"
FUNCTION_ROLLBACK_CAPTURED=1
echo "PASS: pre-004 function definitions captured"

echo
echo "--- Migration 004 preflight ---"
if psql_prod_quiet -c "
    SELECT pg_get_functiondef('ref.create_person_from_people_manager(text,text,text,text,text,text,text,boolean,boolean,boolean)'::regprocedure)
           LIKE '%v_reserved := v_standard_email%';
" | grep -qx t; then
    echo "PASS: live create function still contains automatic MSB email generation"
else
    echo "FAIL: live create function no longer matches expected pre-004 behavior; reconcile before deploying"
    exit 8
fi

if ! psql_prod_quiet -c "
    SELECT has_function_privilege(
        'people_app',
        'ref.create_person_from_people_manager(text,text,text,text,text,text,text,boolean,boolean,boolean)',
        'EXECUTE'
    )
    AND has_function_privilege(
        'people_app',
        'ref.update_person_from_people_manager(text,integer,text,text,text,text,text,text,boolean,timestamptz,boolean,boolean)',
        'EXECUTE'
    );
" | grep -qx t; then
    echo "FAIL: people_app lacks expected governed function EXECUTE before migration"
    exit 9
fi

echo
echo "--- Apply accepted migration 004 only ---"
psql_prod < "$MIGRATION_004"
MIGRATION_APPLIED=1
echo "Migration 004: APPLIED"

DB_AFTER="$(prod_person_fingerprint)"
if [[ "$DB_AFTER" != "$PROD_BEFORE" ]]; then
    echo "FAIL: ref.person changed while replacing People functions"
    exit 10
fi

if psql_prod_quiet -c "
    SELECT pg_get_functiondef('ref.create_person_from_people_manager(text,text,text,text,text,text,text,boolean,boolean,boolean)'::regprocedure)
           NOT LIKE '%v_standard_email%';
" | grep -qx t; then
    echo "PASS: create function no longer generates MSB email"
else
    echo "FAIL: migration 004 create-function validation failed"
    exit 11
fi

if ! psql_prod_quiet -c "
    SELECT has_function_privilege(
        'people_app',
        'ref.create_person_from_people_manager(text,text,text,text,text,text,text,boolean,boolean,boolean)',
        'EXECUTE'
    )
    AND has_function_privilege(
        'people_app',
        'ref.update_person_from_people_manager(text,integer,text,text,text,text,text,text,boolean,timestamptz,boolean,boolean)',
        'EXECUTE'
    );
" | grep -qx t; then
    echo "FAIL: migration 004 changed people_app EXECUTE boundary"
    exit 12
fi
echo "PASS: migration 004 changed functions only; ref.person unchanged; EXECUTE boundary preserved"

echo
echo "--- Fast-forward shared Production checkout to exact runtime candidate ---"
sudo git -C "$FIELDWIRING_ROOT" merge --ff-only "$TARGET_SHA"
APP_ADVANCED=1
DEPLOYED_HEAD="$(sudo git -C "$FIELDWIRING_ROOT" rev-parse HEAD)"
[[ "$DEPLOYED_HEAD" == "$TARGET_SHA" ]] || { echo "FAIL: checkout did not reach target"; exit 13; }

sudo systemctl restart "$PEOPLE_SERVICE"
NEW_HEALTH="$(wait_people_version "$EXPECTED_NEW_VERSION")" || {
    echo "FAIL: People service did not become healthy as $EXPECTED_NEW_VERSION"
    sudo systemctl status "$PEOPLE_SERVICE" --no-pager -l || true
    sudo journalctl -u "$PEOPLE_SERVICE" -n 100 --no-pager || true
    exit 14
}
echo "People health: $NEW_HEALTH"
echo "PASS: $PEOPLE_SERVICE active/enabled at $EXPECTED_NEW_VERSION"

echo
echo "--- Validate live authentication/authorization boundary ---"
NO_ID_CODE="$(curl -sS -o /tmp/msb-people-noid-$STAMP.json -w '%{http_code}' "http://192.168.5.9:$PEOPLE_PORT/api/access")"
[[ "$NO_ID_CODE" == "401" ]] || {
    echo "FAIL: /api/access without Cloudflare identity returned $NO_ID_CODE"
    cat /tmp/msb-people-noid-$STAMP.json || true
    exit 15
}
rm -f /tmp/msb-people-noid-$STAMP.json

WITH_ID_CODE="$(curl -sS -H "Cf-Access-Authenticated-User-Email: $PREVIEW_EMAIL" -o /tmp/msb-people-withid-$STAMP.json -w '%{http_code}' "http://192.168.5.9:$PEOPLE_PORT/api/access")"
[[ "$WITH_ID_CODE" == "200" ]] || {
    echo "FAIL: accepted Manager identity returned HTTP $WITH_ID_CODE"
    cat /tmp/msb-people-withid-$STAMP.json || true
    exit 16
}
grep -q '"can_manage_people":true' /tmp/msb-people-withid-$STAMP.json || {
    echo "FAIL: accepted Manager identity did not resolve can_manage_people=true"
    cat /tmp/msb-people-withid-$STAMP.json || true
    exit 17
}
rm -f /tmp/msb-people-withid-$STAMP.json
echo "PASS: missing identity -> 401; accepted Manager identity -> authorized"

FINAL_FP="$(prod_person_fingerprint)"
[[ "$FINAL_FP" == "$PROD_BEFORE" ]] || { echo "FAIL: final ref.person fingerprint changed"; exit 18; }

FINAL_HEAD="$(sudo git -C "$FIELDWIRING_ROOT" rev-parse HEAD)"
[[ "$FINAL_HEAD" == "$TARGET_SHA" ]] || { echo "FAIL: final checkout changed unexpectedly"; exit 19; }

echo
echo "PEOPLE NULLABLE MSB EMAIL PRODUCTION DEPLOYMENT: PASS"
echo "Final checkout: $FINAL_HEAD"
echo "ref.person fingerprint unchanged: $FINAL_FP"
echo "You may now use the live People Manager to clear generated/bogus Sheboygan Lights emails on unlinked People."
SUCCESS=1
