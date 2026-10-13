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
TARGET_REF="main"
ACCEPTED_RUNTIME_SHA="f6f581dce0e65b6b9be0cff62478719550e3fefe"
MIGRATION_REL="People/Database/005_reconcile_directus_person_identity.sql"
MIGRATION_BLOB="cee689bc615db74f7f34feb15228e4fd87991ec7"
TARGET_SHA="${1:?merged main target SHA is required}"
EXPECTED_OLD_VERSION="V0.2.1"
EXPECTED_NEW_VERSION="V0.2.2"
PREVIEW_EMAIL="gliebig@sheboyganlights.org"

CONTROL=(
  sudo python3 /opt/msb-maintenance/msb_maintenance_controller.py
  --config /etc/msb-maintenance/config.json
)

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
STAMP="$(date +%Y%m%dT%H%M%S)"
BACKUP_DIR="/home/msbadmin/backups/postgres"
BACKUP_FILE="$BACKUP_DIR/msb-pre-people-identity-reconcile-$STAMP.dump"
REPORT="/tmp/MSB_People_Identity_Reconcile_Production_Deploy_$STAMP.txt"
CANDIDATE_WORKTREE="/tmp/msb-people-identity-reconcile-candidate-$STAMP"
FUNCTION_ROLLBACK="$SCRIPT_DIR/pre-005-function-rollback.sql"

OLD_HEAD=""
FROZEN_PERSON_FP=""
FROZEN_DIRECTUS_FP=""
BACKUP_CREATED=0
MIGRATION_APPLIED=0
APP_ADVANCED=0
MAINTENANCE_STARTED=0
ROLLBACK_CAPTURED=0
SUCCESS=0

exec > >(tee "$REPORT") 2>&1

echo "========== PEOPLE IDENTITY RECONCILIATION PRODUCTION DEPLOYMENT =========="
echo "Issue:       #385"
echo "Authority:   MSB-Server-Management — Production_Database_Change_Deployment_Runbook.md"
echo "Maintenance: MSB-Server-Management — Production_Database_Maintenance_Mode.md"
echo "Target ref:          $TARGET_REF"
echo "Accepted runtime:    $ACCEPTED_RUNTIME_SHA"
echo "Merged-main target:  $TARGET_SHA"
echo "Migration:           $MIGRATION_REL"
echo "Migration blob:      $MIGRATION_BLOB"
echo "Expected version:    $EXPECTED_NEW_VERSION"
echo "Report:              $REPORT"
echo

controller() {
    "${CONTROL[@]}" "$@"
}

psql_prod() {
    sudo docker exec -i "$PROD_CONTAINER" \
        psql -X -v ON_ERROR_STOP=1 -U "$DB_ACTOR" -d "$PROD_DB" "$@"
}

psql_q() {
    sudo docker exec -i "$PROD_CONTAINER" \
        psql -X -qAt -v ON_ERROR_STOP=1 -U "$DB_ACTOR" -d "$PROD_DB" "$@"
}

people_health() {
    curl -fsS "http://192.168.5.9:$PEOPLE_PORT/api/health"
}

person_fingerprint() {
    psql_q -c "
      SELECT md5(coalesce(string_agg(row_to_json(p)::text,'' ORDER BY p.person_id),''))
      FROM ref.person p;
    "
}

directus_identity_fingerprint() {
    psql_q -c "
      SELECT md5(coalesce(string_agg(
        row_to_json(x)::text,'' ORDER BY x.id
      ),''))
      FROM (
        SELECT u.id,u.email,u.status,u.provider,u.external_identifier,u.role
        FROM public.directus_users u
      ) x;
    "
}

require_online() {
    local payload
    payload="$(controller status)"
    python3 -c '
import json,sys
d=json.load(sys.stdin)
assert d.get("state")=="ONLINE", d
assert d.get("live",{}).get("database_fenced") is False, d
assert not d.get("last_error"), d
' <<< "$payload"
}

require_maintenance() {
    local payload
    payload="$(controller status)"
    python3 -c '
import json,sys
d=json.load(sys.stdin)
assert d.get("state")=="MAINTENANCE", d
assert d.get("gates",{}).get("freeze_proof",{}).get("ok") is True, d
assert d.get("live",{}).get("database_fenced") is True, d
assert not d.get("last_error"), d
' <<< "$payload"
}

wait_people_version() {
    local expected="$1"
    local payload=""
    for _ in $(seq 1 60); do
        if systemctl is-active --quiet "$PEOPLE_SERVICE"; then
            payload="$(people_health 2>/dev/null || true)"
            if [[ "$payload" == *"\"status\":\"ok\""* \
               && "$payload" == *"\"version\":\"$expected\""* ]]; then
                echo "$payload"
                return 0
            fi
        fi
        sleep 1
    done
    return 1
}

capture_function_rollback() {
    {
      for signature in \
        "ref.resolve_actor()" \
        "ref.setup_management_actor(text,boolean)" \
        "ref.setup_movement_actor(text)" \
        "ref.setup_execution_actor(text,bigint)" \
        "ref.setup_inventory_actor(text,boolean)" \
        "ref.people_management_actor(text)" \
        "ref.controller_management_actor(text)" \
        "ref.request_controller_label(text,bigint)"; do
          psql_q -c "SELECT pg_get_functiondef('$signature'::regprocedure);"
          echo
      done
      echo "DROP FUNCTION IF EXISTS ref.directus_person_identity_reconciliation_report();"
      echo "DROP FUNCTION IF EXISTS ref.reconcile_directus_person_identity(text);"
    } > "$FUNCTION_ROLLBACK"
    test -s "$FUNCTION_ROLLBACK"
    ROLLBACK_CAPTURED=1
}

rollback_database_functions() {
    if [[ "$MIGRATION_APPLIED" -eq 1 && "$ROLLBACK_CAPTURED" -eq 1 ]]; then
        echo "Restoring exact pre-005 function definitions"
        psql_prod < "$FUNCTION_ROLLBACK"
        MIGRATION_APPLIED=0
        local fp
        fp="$(person_fingerprint)"
        [[ "$fp" == "$FROZEN_PERSON_FP" ]]
        echo "PASS: pre-005 function rollback restored; Person fingerprint unchanged"
    fi
}

cleanup() {
    status=$?
    trap - EXIT HUP INT TERM
    set +e

    if [[ "$status" -ne 0 && "$SUCCESS" -ne 1 ]]; then
        echo
        echo "--- FAIL-CLOSED RECOVERY ---"
        rollback_ok=1

        if [[ "$APP_ADVANCED" -eq 1 && -n "$OLD_HEAD" ]]; then
            echo "Restoring shared checkout to $OLD_HEAD while maintenance remains active"
            sudo git -C "$FIELDWIRING_ROOT" reset --hard "$OLD_HEAD" >/dev/null 2>&1 || rollback_ok=0
            APP_ADVANCED=0
        fi

        if [[ "$MIGRATION_APPLIED" -eq 1 ]]; then
            rollback_database_functions >/dev/null 2>&1 || rollback_ok=0
        fi

        if [[ "$MAINTENANCE_STARTED" -eq 1 ]]; then
            if [[ "$rollback_ok" -eq 1 ]]; then
                echo "Returning Production to service after successful rollback"
                controller off >/dev/null 2>&1 || rollback_ok=0
                if [[ "$rollback_ok" -eq 1 ]]; then
                    MAINTENANCE_STARTED=0
                    wait_people_version "$EXPECTED_OLD_VERSION" >/dev/null 2>&1 || rollback_ok=0
                fi
            fi

            if [[ "$rollback_ok" -ne 1 ]]; then
                echo "FAIL-CLOSED: recovery incomplete; leaving Issue #37 maintenance controller engaged for reviewed recovery"
                status=98
            fi
        fi
    fi

    if sudo git -C "$FIELDWIRING_ROOT" worktree list --porcelain 2>/dev/null | grep -Fq "worktree $CANDIDATE_WORKTREE"; then
        sudo git -C "$FIELDWIRING_ROOT" worktree remove --force "$CANDIDATE_WORKTREE" >/dev/null 2>&1 || true
    fi
    sudo git -C "$FIELDWIRING_ROOT" worktree prune >/dev/null 2>&1 || true
    rm -f "$FUNCTION_ROLLBACK" >/dev/null 2>&1 || true
    rm -rf "$SCRIPT_DIR" >/dev/null 2>&1 || true

    echo
    if [[ "$BACKUP_CREATED" -eq 1 && -s "$BACKUP_FILE" ]]; then
        echo "Rollback backup retained at: $BACKUP_FILE"
    else
        echo "Rollback backup: not created before this stop"
    fi
    echo "Deployment report retained at: $REPORT"
    echo "Exit status: $status"
    exit "$status"
}
trap cleanup EXIT HUP INT TERM

sudo -v
mkdir -p "$BACKUP_DIR"

echo "--- ONLINE Production preflight ---"
sudo docker inspect "$PROD_CONTAINER" >/dev/null
systemctl is-active --quiet "$PEOPLE_SERVICE" || { echo "FAIL: $PEOPLE_SERVICE is not active"; exit 2; }
systemctl is-enabled --quiet "$PEOPLE_SERVICE" || { echo "FAIL: $PEOPLE_SERVICE is not enabled"; exit 2; }

OLD_HEALTH="$(people_health)"
echo "Current People health: $OLD_HEALTH"
if [[ "$OLD_HEALTH" != *"\"version\":\"$EXPECTED_OLD_VERSION\""* ]]; then
    echo "FAIL: expected live People $EXPECTED_OLD_VERSION"
    exit 3
fi

OLD_HEAD="$(sudo git -C "$FIELDWIRING_ROOT" rev-parse HEAD)"
echo "Verified live checkout: $OLD_HEAD"
if [[ -n "$(sudo git -C "$FIELDWIRING_ROOT" status --porcelain)" ]]; then
    echo "FAIL: live shared checkout has uncommitted changes"
    exit 4
fi

require_online
echo "PASS: Issue #37 controller is healthy ONLINE"

echo
echo "--- Fetch and verify exact merged-main target ---"
sudo git -C "$FIELDWIRING_ROOT" fetch origin \
    "+refs/heads/main:refs/remotes/origin/main"
REMOTE_MAIN="$(sudo git -C "$FIELDWIRING_ROOT" rev-parse origin/main)"
[[ "$REMOTE_MAIN" == "$TARGET_SHA" ]] || {
    echo "FAIL: requested SHA is not current origin/main"
    echo "origin/main: $REMOTE_MAIN"
    echo "requested:   $TARGET_SHA"
    exit 5
}
sudo git -C "$FIELDWIRING_ROOT" cat-file -e "$TARGET_SHA^{commit}"
sudo git -C "$FIELDWIRING_ROOT" cat-file -e "$ACCEPTED_RUNTIME_SHA^{commit}"
sudo git -C "$FIELDWIRING_ROOT" merge-base --is-ancestor "$OLD_HEAD" "$TARGET_SHA" || {
    echo "FAIL: target is not a fast-forward descendant of live checkout"
    exit 6
}
sudo git -C "$FIELDWIRING_ROOT" merge-base --is-ancestor "$ACCEPTED_RUNTIME_SHA" "$TARGET_SHA" || {
    echo "FAIL: merged main does not contain accepted runtime candidate"
    exit 7
}
if ! sudo git -C "$FIELDWIRING_ROOT" diff --quiet "$ACCEPTED_RUNTIME_SHA" "$TARGET_SHA" -- People/Application People/Database; then
    echo "FAIL: People runtime changed after accepted candidate"
    sudo git -C "$FIELDWIRING_ROOT" diff --name-only "$ACCEPTED_RUNTIME_SHA" "$TARGET_SHA" -- People/Application People/Database
    exit 8
fi

ACTUAL_BLOB="$(sudo git -C "$FIELDWIRING_ROOT" rev-parse "$TARGET_SHA:$MIGRATION_REL")"
[[ "$ACTUAL_BLOB" == "$MIGRATION_BLOB" ]] || {
    echo "FAIL: migration 005 blob mismatch"
    echo "expected: $MIGRATION_BLOB"
    echo "actual:   $ACTUAL_BLOB"
    exit 9
}
echo "PASS: exact merged-main runtime and migration identity"

echo
echo "--- Detached exact-target regression ---"
sudo git -C "$FIELDWIRING_ROOT" worktree add --detach "$CANDIDATE_WORKTREE" "$TARGET_SHA"
M005="$CANDIDATE_WORKTREE/$MIGRATION_REL"
for required in \
    "$M005" \
    "$CANDIDATE_WORKTREE/People/Application/backend.py" \
    "$CANDIDATE_WORKTREE/People/Application/test_people_manager_contract.py" \
    "$CANDIDATE_WORKTREE/People/Application/test_people_shared_tablet_identity_contract.py"; do
    [[ -s "$required" ]] || { echo "FAIL: missing accepted file $required"; exit 10; }
done
sudo -u fieldwiring -H bash -c \
    "cd '$CANDIDATE_WORKTREE' && '$PRODUCTION_PYTHON' -m pytest -q -p no:cacheprovider People/Application/test_people_manager_contract.py People/Application/test_people_shared_tablet_identity_contract.py"
echo "DETACHED PEOPLE V0.2.2 REGRESSION: PASS"

echo
echo "--- Database preflight before maintenance ---"
if [[ "$(psql_q -c "SELECT to_regprocedure('ref.reconcile_directus_person_identity(text)') IS NULL;")" != "t" ]]; then
    echo "FAIL: migration 005 reconciliation function already exists"
    exit 11
fi
for signature in \
    "ref.resolve_actor()" \
    "ref.setup_management_actor(text,boolean)" \
    "ref.setup_movement_actor(text)" \
    "ref.setup_execution_actor(text,bigint)" \
    "ref.setup_inventory_actor(text,boolean)" \
    "ref.people_management_actor(text)" \
    "ref.controller_management_actor(text)" \
    "ref.request_controller_label(text,bigint)"; do
    [[ "$(psql_q -c "SELECT to_regprocedure('$signature') IS NOT NULL;")" == "t" ]] || {
        echo "FAIL: required pre-005 function missing: $signature"
        exit 12
    }
done
echo "DATABASE PREFLIGHT: PASS"

echo
echo "--- ENTER Issue #37 maintenance ---"
controller stage "People #385 pre-maintenance" >/dev/null || true
controller on >/dev/null
MAINTENANCE_STARTED=1
require_maintenance
echo "PASS: MAINTENANCE + freeze_proof"

FROZEN_PERSON_FP="$(person_fingerprint)"
FROZEN_DIRECTUS_FP="$(directus_identity_fingerprint)"
echo "Frozen ref.person fingerprint:        $FROZEN_PERSON_FP"
echo "Frozen Directus identity fingerprint: $FROZEN_DIRECTUS_FP"

echo
echo "--- Controller-validated rollback snapshot ---"
SNAPSHOT_JSON="$(controller snapshot "$BACKUP_FILE")"
python3 -c '
import json,sys,os
d=json.load(sys.stdin)
s=d.get("snapshot") or d
assert s.get("validated") is True, d
p=s.get("path")
assert p and os.path.exists(p) and os.path.getsize(p)>0, d
print("Snapshot:", p)
print("SHA256:", s.get("sha256"))
' <<< "$SNAPSHOT_JSON"
BACKUP_CREATED=1

capture_function_rollback
echo "PASS: exact pre-005 function rollback definitions captured"

echo
echo "--- Apply migration 005 only ---"
controller stage "People #385 apply migration 005" >/dev/null || true
psql_prod < "$M005"
MIGRATION_APPLIED=1
echo "MIGRATION 005: COMMITTED"

echo
echo "--- Validate database/security contract while frozen ---"
POST_PERSON_FP="$(person_fingerprint)"
POST_DIRECTUS_FP="$(directus_identity_fingerprint)"
[[ "$POST_PERSON_FP" == "$FROZEN_PERSON_FP" ]] || {
    echo "FAIL: migration 005 changed ref.person rows"
    exit 13
}
[[ "$POST_DIRECTUS_FP" == "$FROZEN_DIRECTUS_FP" ]] || {
    echo "FAIL: migration 005 changed Directus user/role identity rows"
    exit 14
}

psql_prod <<'SQL'
DO $b$
DECLARE
    v_def text;
BEGIN
    IF to_regprocedure('ref.reconcile_directus_person_identity(text)') IS NULL
       OR to_regprocedure('ref.directus_person_identity_reconciliation_report()') IS NULL THEN
        RAISE EXCEPTION 'Identity reconciliation functions are missing';
    END IF;

    IF has_function_privilege('fieldwiring_app','ref.reconcile_directus_person_identity(text)','EXECUTE')
       OR has_function_privilege('people_app','ref.reconcile_directus_person_identity(text)','EXECUTE')
       OR has_function_privilege('directus_app','ref.reconcile_directus_person_identity(text)','EXECUTE') THEN
        RAISE EXCEPTION 'Internal identity reconciler leaked to application roles';
    END IF;

    SELECT pg_get_functiondef('ref.reconcile_directus_person_identity(text)'::regprocedure)
      INTO v_def;

    IF v_def NOT LIKE '%tablet-%@sheboyganlights.org%'
       OR v_def NOT LIKE '%Shared tablet accounts are Browser-only device identities%' THEN
        RAISE EXCEPTION 'Shared-tablet Browser-only exclusion is missing';
    END IF;
END
$b$;
SQL

echo "PASS: migration 005 changed functions only; tablet device accounts remain non-human Browser-only identities"

echo
echo "--- Promote merged main while maintenance remains active ---"
sudo git -C "$FIELDWIRING_ROOT" merge --ff-only "$TARGET_SHA"
APP_ADVANCED=1
DEPLOYED_HEAD="$(sudo git -C "$FIELDWIRING_ROOT" rev-parse HEAD)"
[[ "$DEPLOYED_HEAD" == "$TARGET_SHA" ]] || { echo "FAIL: checkout did not reach target"; exit 15; }
echo "PASS: shared checkout at $DEPLOYED_HEAD"

echo
echo "--- RETURN TO SERVICE ---"
controller stage "People #385 validation complete" >/dev/null || true
controller off >/dev/null
MAINTENANCE_STARTED=0
require_online
echo "PASS: Issue #37 controller ONLINE"

NEW_HEALTH="$(wait_people_version "$EXPECTED_NEW_VERSION")" || {
    echo "FAIL: People did not become healthy as $EXPECTED_NEW_VERSION"
    sudo systemctl status "$PEOPLE_SERVICE" --no-pager -l || true
    exit 16
}
echo "People health: $NEW_HEALTH"
[[ "$NEW_HEALTH" == *"\"identity_reconciliation_contract\":true"* ]] || {
    echo "FAIL: People health does not expose identity reconciliation contract"
    exit 17
}

echo
echo "--- Validate live auth boundary ---"
NO_ID_CODE="$(curl -sS -o /tmp/msb-people-noid-$STAMP.json -w '%{http_code}' \
    "http://192.168.5.9:$PEOPLE_PORT/api/access")"
[[ "$NO_ID_CODE" == "401" ]] || {
    echo "FAIL: missing identity returned HTTP $NO_ID_CODE"
    exit 18
}
rm -f /tmp/msb-people-noid-$STAMP.json

WITH_ID_CODE="$(curl -sS \
    -H "Cf-Access-Authenticated-User-Email: $PREVIEW_EMAIL" \
    -o /tmp/msb-people-withid-$STAMP.json \
    -w '%{http_code}' \
    "http://192.168.5.9:$PEOPLE_PORT/api/access")"
[[ "$WITH_ID_CODE" == "200" ]] || {
    echo "FAIL: accepted Manager identity returned HTTP $WITH_ID_CODE"
    exit 19
}
grep -q '"can_manage_people":true' /tmp/msb-people-withid-$STAMP.json || {
    echo "FAIL: accepted Manager identity is not authorized"
    exit 20
}
rm -f /tmp/msb-people-withid-$STAMP.json
echo "PASS: missing identity -> 401; Manager identity -> authorized"

FINAL_HEAD="$(sudo git -C "$FIELDWIRING_ROOT" rev-parse HEAD)"
[[ "$FINAL_HEAD" == "$TARGET_SHA" ]] || { echo "FAIL: final checkout drifted"; exit 21; }

SUCCESS=1
echo
echo "PEOPLE IDENTITY RECONCILIATION PRODUCTION DEPLOYMENT: PASS"
echo "Visible version:       $EXPECTED_NEW_VERSION"
echo "Final checkout:        $FINAL_HEAD"
echo "Migration:             $MIGRATION_REL"
echo "Frozen Person FP:      $FROZEN_PERSON_FP"
echo "Frozen Directus FP:    $FROZEN_DIRECTUS_FP"
echo "Rollback snapshot:     $BACKUP_FILE"
echo "Deployment report:     $REPORT"
