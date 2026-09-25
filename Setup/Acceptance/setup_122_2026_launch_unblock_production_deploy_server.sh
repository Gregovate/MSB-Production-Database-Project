#!/usr/bin/env bash
set -euo pipefail

PROD_CONTAINER="msb-postgres"
PROD_DB="msb"
DB_ACTOR="msbadmin"
REPO_ROOT="/opt/fieldwiring"
SETUP_ROOT="/opt/msb-setup"
PYTHON="/opt/fieldwiring/.venv/bin/python"
SETUP_SERVICE="msb-setup.service"

TARGET_REF="main"
TARGET_SHA="06a6536d92db5c7352beeed496563ed9bfdb7146"
EXPECTED_SETUP_VERSION="V0.3.17-performance-trace"

M057_REL="Setup/Database/057_enable_2026_unworked_task_deletion.sql"
M057_BLOB="053570d192345caa5708ccc61f69674c17c25989"
M058_REL="Setup/Database/058_preserve_catalog_review_on_annual_launch.sql"
M058_BLOB="221498abaea8ab923c06d287ba2d94d80007d5e7"

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
BACKUP_DIR="/home/msbadmin/backups/setup-122-2026-launch"
REPORT_DIR="/home/msbadmin/setup-deployment-reports"
STAMP="$(date +%Y%m%dT%H%M%S)"
BACKUP_FILE="$BACKUP_DIR/msb-pre-setup-122-2026-launch-$STAMP.dump"
REPORT="$REPORT_DIR/Setup_122_2026_Launch_Unblock_Production_Deploy_$STAMP.txt"
CANDIDATE_WORKTREE="/tmp/msb-setup-122-launch-candidate-$STAMP"
DETACHED_PYCACHE="/tmp/msb-setup-122-launch-detached-pycache-$STAMP"
LIVE_PYCACHE="/tmp/msb-setup-122-launch-live-pycache-$STAMP"
ROLLBACK_SQL="/tmp/msb-setup-122-launch-function-rollback-$STAMP.sql"

OLD_HEAD=""
INITIAL_FINGERPRINT=""
FROZEN_FINGERPRINT=""
M057=""
M058=""
BACKUP_CREATED=0
M057_COMMITTED=0
M058_COMMITTED=0
APP_ADVANCED=0
APP_ROLLED_BACK=0
SETUP_STOPPED=0
ROLLBACK_SQL_READY=0
SUCCESS=0

mkdir -p "$REPORT_DIR"
exec > >(tee "$REPORT") 2>&1

echo "========== SETUP #122 2026 LAUNCH-UNBLOCK PRODUCTION DEPLOYMENT =========="
echo "Authority: Gregovate/MSB-Server-Management — docs/server/Production_Database_Change_Deployment_Runbook.md"
echo "Browser-accepted application target: $TARGET_SHA"
echo "Expected Setup version:               $EXPECTED_SETUP_VERSION"
echo "Migration 057:                        $M057_REL"
echo "Migration 058:                        $M058_REL"
echo "2026 Setup Session creation:          FORBIDDEN DURING DEPLOYMENT"
echo "Report:                               $REPORT"
echo

psql_prod() {
    sudo docker exec -i "$PROD_CONTAINER"         psql -X -v ON_ERROR_STOP=1 -U "$DB_ACTOR" -d "$PROD_DB" "$@"
}

setup_fingerprint() {
    sudo docker exec "$PROD_CONTAINER"         psql -X -qAt -v ON_ERROR_STOP=1 -U "$DB_ACTOR" -d "$PROD_DB" -c "
            SELECT md5(
                coalesce((SELECT string_agg(row_to_json(t)::text, '' ORDER BY t.setup_task_id)
                          FROM ref.setup_task t), '') || '|' ||
                coalesce((SELECT string_agg(row_to_json(d)::text, '' ORDER BY d.setup_task_id, d.prerequisite_setup_task_id)
                          FROM ref.setup_task_dependency d), '') || '|' ||
                coalesce((SELECT string_agg(row_to_json(td)::text, '' ORDER BY td.setup_task_id, td.display_id)
                          FROM ref.setup_task_display td), '') || '|' ||
                coalesce((SELECT string_agg(row_to_json(tc)::text, '' ORDER BY tc.setup_task_id, tc.container_id)
                          FROM ref.setup_task_container_support tc), '') || '|' ||
                coalesce((SELECT string_agg(row_to_json(s)::text, '' ORDER BY s.setup_session_id)
                          FROM ops.setup_session s), '') || '|' ||
                coalesce((SELECT string_agg(row_to_json(st)::text, '' ORDER BY st.setup_session_task_id)
                          FROM ops.setup_session_task st), '') || '|' ||
                coalesce((SELECT string_agg(row_to_json(wd)::text, '' ORDER BY wd.setup_work_day_id)
                          FROM ops.setup_work_day wd), '')
            );
        "
}

setup_2026_count() {
    sudo docker exec "$PROD_CONTAINER"         psql -X -qAt -v ON_ERROR_STOP=1 -U "$DB_ACTOR" -d "$PROD_DB"         -c "SELECT count(*) FROM ops.setup_session WHERE season_year=2026;"
}

wait_setup_ready() {
    for _ in $(seq 1 60); do
        if systemctl is-active --quiet "$SETUP_SERVICE"            && curl -fsS http://192.168.5.9:8794/api/health >/dev/null 2>&1; then
            return 0
        fi
        sleep 1
    done
    return 1
}

restart_setup() {
    sudo systemctl restart "$SETUP_SERVICE"
    SETUP_STOPPED=0
    wait_setup_ready
}

capture_function_rollback() {
    {
        echo "\\set ON_ERROR_STOP on"
        echo "BEGIN;"
        sudo docker exec "$PROD_CONTAINER"             psql -X -qAt -v ON_ERROR_STOP=1 -U "$DB_ACTOR" -d "$PROD_DB"             -c "SELECT pg_get_functiondef('ref.delete_setup_reconstruction_task(text,bigint)'::regprocedure);"
        sudo docker exec "$PROD_CONTAINER"             psql -X -qAt -v ON_ERROR_STOP=1 -U "$DB_ACTOR" -d "$PROD_DB"             -c "SELECT pg_get_functiondef('ops.create_setup_session(text,integer,text)'::regprocedure);"
        sudo docker exec "$PROD_CONTAINER"             psql -X -qAt -v ON_ERROR_STOP=1 -U "$DB_ACTOR" -d "$PROD_DB"             -c "SELECT pg_get_functiondef('ref.create_setup_task(text,text,integer,text,integer,integer,integer,integer,text,text,text,text)'::regprocedure);"
        echo "DROP FUNCTION IF EXISTS ops.delete_unworked_setup_season_task(text,bigint);"
        echo "REVOKE ALL ON FUNCTION ref.delete_setup_reconstruction_task(text,bigint) FROM PUBLIC;"
        echo "GRANT EXECUTE ON FUNCTION ref.delete_setup_reconstruction_task(text,bigint) TO fieldwiring_app;"
        echo "REVOKE ALL ON FUNCTION ops.create_setup_session(text,integer,text) FROM PUBLIC;"
        echo "GRANT EXECUTE ON FUNCTION ops.create_setup_session(text,integer,text) TO fieldwiring_app;"
        echo "REVOKE ALL ON FUNCTION ref.create_setup_task(text,text,integer,text,integer,integer,integer,integer,text,text,text,text) FROM PUBLIC;"
        echo "GRANT EXECUTE ON FUNCTION ref.create_setup_task(text,text,integer,text,integer,integer,integer,integer,text,text,text,text) TO fieldwiring_app;"
        echo "COMMIT;"
    } > "$ROLLBACK_SQL"
    test -s "$ROLLBACK_SQL"
    ROLLBACK_SQL_READY=1
}

rollback_functions() {
    if [[ "$ROLLBACK_SQL_READY" -ne 1 || ! -s "$ROLLBACK_SQL" ]]; then
        echo "Function rollback SQL was not captured; cannot perform narrow database rollback automatically."
        return 1
    fi
    echo "Restoring pre-deployment Setup command functions and removing the new season-only delete command"
    psql_prod < "$ROLLBACK_SQL"
}

cleanup() {
    status=$?
    trap - EXIT HUP INT TERM
    set +e

    if [[ "$status" -ne 0 && "$SUCCESS" -ne 1 ]]; then
        echo
        echo "--- FAIL-CLOSED RECOVERY ---"

        if [[ "$APP_ADVANCED" -eq 1 && -n "$OLD_HEAD" ]]; then
            echo "Restoring Setup checkout to verified prior SHA $OLD_HEAD"
            sudo git -C "$SETUP_ROOT" reset --hard "$OLD_HEAD" || true
            APP_ADVANCED=0
            APP_ROLLED_BACK=1
        fi

        if [[ "$M057_COMMITTED" -eq 1 || "$M058_COMMITTED" -eq 1 ]]; then
            if rollback_functions; then
                echo "Setup command-function migration rollback: PASS"
                M057_COMMITTED=0
                M058_COMMITTED=0
            else
                echo "WARNING: automatic command-function rollback failed."
                echo "Do not continue Production work until the retained rollback archive/report are reviewed."
                status=98
            fi
        else
            echo "No #122 launch migration reached committed-success state."
        fi

        if [[ "$SETUP_STOPPED" -eq 1 || "$APP_ROLLED_BACK" -eq 1 ]]; then
            echo "Restarting Setup service after recovery"
            restart_setup || { echo "WARNING: Setup service restart failed during recovery"; status=99; }
        fi
    fi

    if sudo git -C "$REPO_ROOT" worktree list --porcelain 2>/dev/null | grep -Fq "worktree $CANDIDATE_WORKTREE"; then
        sudo git -C "$REPO_ROOT" worktree remove --force "$CANDIDATE_WORKTREE" >/dev/null 2>&1 || true
    fi
    sudo git -C "$REPO_ROOT" worktree prune >/dev/null 2>&1 || true
    sudo rm -rf "$DETACHED_PYCACHE" "$LIVE_PYCACHE" >/dev/null 2>&1 || true
    rm -f "$ROLLBACK_SQL" >/dev/null 2>&1 || true
    rm -rf "$SCRIPT_DIR" >/dev/null 2>&1 || true

    echo
    echo "--- Production after-check ---"
    if [[ -n "$FROZEN_FINGERPRINT" ]]; then
        AFTER_FINGERPRINT="$(setup_fingerprint 2>/dev/null || true)"
        echo "Frozen Setup fingerprint: $FROZEN_FINGERPRINT"
        echo "Final Setup fingerprint:  $AFTER_FINGERPRINT"
        if [[ -z "$AFTER_FINGERPRINT" || "$AFTER_FINGERPRINT" != "$FROZEN_FINGERPRINT" ]]; then
            echo "FAIL: governed Setup data fingerprint changed during deployment"
            status=97
        else
            echo "PASS: governed Setup data fingerprint unchanged"
        fi
    fi

    FINAL_2026="$(setup_2026_count 2>/dev/null || true)"
    echo "Final 2026 Setup Session count: ${FINAL_2026:-unknown}"
    if [[ -n "$FINAL_2026" && "$FINAL_2026" != "0" ]]; then
        echo "FAIL: deployment created or observed a real 2026 Setup Session"
        status=96
    fi

    if [[ "$BACKUP_CREATED" -eq 1 && -s "$BACKUP_FILE" ]]; then
        echo "Rollback backup retained at: $BACKUP_FILE"
        echo "Rollback SHA256: ${BACKUP_SHA:-unknown}"
    else
        echo "Rollback backup: not created before this stop"
    fi

    echo "Deployment report retained at: $REPORT"
    echo "Exit status: $status"
    exit "$status"
}
trap cleanup EXIT HUP INT TERM

sudo -v
mkdir -p "$BACKUP_DIR" "$REPORT_DIR"

echo "--- Verify Production runtime and live checkout ---"
if ! sudo docker inspect "$PROD_CONTAINER" >/dev/null 2>&1; then
    echo "FAIL: Production PostgreSQL container not found"
    exit 2
fi
if [[ "$(sudo docker inspect "$PROD_CONTAINER" --format '{{.Config.Image}}')" != "postgis/postgis:16-3.5" ]]; then
    echo "FAIL: Production PostgreSQL image is not postgis/postgis:16-3.5"
    exit 3
fi
if ! sudo git -C "$REPO_ROOT" worktree list --porcelain | grep -Fq "worktree $SETUP_ROOT"; then
    echo "FAIL: $SETUP_ROOT is not registered as a worktree of $REPO_ROOT"
    exit 4
fi
if [[ -n "$(sudo git -C "$REPO_ROOT" status --porcelain)" ]]; then
    echo "FAIL: shared repository checkout has uncommitted changes"
    sudo git -C "$REPO_ROOT" status -sb
    exit 5
fi

OLD_HEAD="$(sudo git -C "$SETUP_ROOT" rev-parse HEAD)"
echo "Verified live Setup checkout: $OLD_HEAD"
if [[ -n "$(sudo git -C "$SETUP_ROOT" status --porcelain)" ]]; then
    echo "FAIL: live Setup checkout has uncommitted changes"
    sudo git -C "$SETUP_ROOT" status -sb
    exit 6
fi
if ! systemctl is-active --quiet "$SETUP_SERVICE"; then
    echo "FAIL: msb-setup.service is not active before deployment"
    exit 7
fi

SETUP_PRE="$(curl -fsS http://192.168.5.9:8794/api/health)"
echo "Pre-deploy Setup health: $SETUP_PRE"
if [[ "$SETUP_PRE" != *"\"status\":\"ok\""* || "$SETUP_PRE" != *"\"data_mode\":\"postgres\""* ]]; then
    echo "FAIL: current Setup runtime health is not acceptable"
    exit 8
fi

INITIAL_FINGERPRINT="$(setup_fingerprint)"
[[ -n "$INITIAL_FINGERPRINT" ]] || { echo "FAIL: initial Setup fingerprint is empty"; exit 9; }
echo "Initial Setup fingerprint: $INITIAL_FINGERPRINT"

if [[ "$(setup_2026_count)" != "0" ]]; then
    echo "FAIL: real 2026 Setup Session already exists before launch-unblock deployment"
    exit 10
fi
echo "2026 Setup Session preflight: PASS (0 rows)"

echo
echo "--- Fetch and verify merged main + exact accepted target ---"
sudo git -C "$REPO_ROOT" fetch origin "$TARGET_REF:refs/remotes/origin/$TARGET_REF"
sudo git -C "$REPO_ROOT" cat-file -e "$TARGET_SHA^{commit}"

if ! sudo git -C "$REPO_ROOT" merge-base --is-ancestor "$TARGET_SHA" "origin/$TARGET_REF"; then
    echo "FAIL: exact browser-accepted target is not contained in merged origin/main"
    exit 11
fi
if ! sudo git -C "$REPO_ROOT" merge-base --is-ancestor "$OLD_HEAD" "$TARGET_SHA"; then
    echo "FAIL: exact browser-accepted target is not a forward descendant of verified live Setup checkout"
    echo "Live:   $OLD_HEAD"
    echo "Target: $TARGET_SHA"
    exit 12
fi
echo "Target ancestry: PASS ($OLD_HEAD -> $TARGET_SHA)"

ACTUAL_M057_BLOB="$(sudo git -C "$REPO_ROOT" rev-parse "$TARGET_SHA:$M057_REL")"
ACTUAL_M058_BLOB="$(sudo git -C "$REPO_ROOT" rev-parse "$TARGET_SHA:$M058_REL")"
if [[ "$ACTUAL_M057_BLOB" != "$M057_BLOB" ]]; then
    echo "FAIL: migration 057 Git blob identity mismatch"
    echo "Expected: $M057_BLOB"
    echo "Actual:   $ACTUAL_M057_BLOB"
    exit 13
fi
if [[ "$ACTUAL_M058_BLOB" != "$M058_BLOB" ]]; then
    echo "FAIL: migration 058 Git blob identity mismatch"
    echo "Expected: $M058_BLOB"
    echo "Actual:   $ACTUAL_M058_BLOB"
    exit 14
fi
echo "Migration 057 blob: PASS ($ACTUAL_M057_BLOB)"
echo "Migration 058 blob: PASS ($ACTUAL_M058_BLOB)"

echo
echo "--- Detached exact-candidate regression in Production runtime ---"
sudo git -C "$REPO_ROOT" worktree add --detach "$CANDIDATE_WORKTREE" "$TARGET_SHA"
M057="$CANDIDATE_WORKTREE/$M057_REL"
M058="$CANDIDATE_WORKTREE/$M058_REL"
[[ -s "$M057" ]] || { echo "FAIL: exact target is missing migration 057"; exit 15; }
[[ -s "$M058" ]] || { echo "FAIL: exact target is missing migration 058"; exit 16; }

sudo -u fieldwiring -H env PYTHONPYCACHEPREFIX="$DETACHED_PYCACHE" bash -c     "cd '$CANDIDATE_WORKTREE' && '$PYTHON' -m pytest -q -p no:cacheprovider Setup/Application"
echo "DETACHED EXACT-TARGET SETUP REGRESSION: PASS"

echo
echo "--- Freeze Setup writes for bounded Production mutation window ---"
sudo systemctl stop "$SETUP_SERVICE"
SETUP_STOPPED=1
if systemctl is-active --quiet "$SETUP_SERVICE"; then
    echo "FAIL: Setup service did not stop"
    exit 17
fi
echo "msb-setup.service stopped: PASS"

FROZEN_FINGERPRINT="$(setup_fingerprint)"
echo "Initial fingerprint: $INITIAL_FINGERPRINT"
echo "Frozen fingerprint:  $FROZEN_FINGERPRINT"
if [[ "$FROZEN_FINGERPRINT" != "$INITIAL_FINGERPRINT" ]]; then
    echo "FAIL: Setup data changed before write freeze; stop before mutation"
    exit 18
fi
echo "WRITE-FREEZE FINGERPRINT STABILITY: PASS"

echo
echo "--- Create and validate rollback PostgreSQL archive ---"
sudo docker exec "$PROD_CONTAINER"     pg_dump -U "$DB_ACTOR" -d "$PROD_DB" -Fc > "$BACKUP_FILE"
test -s "$BACKUP_FILE"
BACKUP_CREATED=1
BACKUP_SHA="$(sha256sum "$BACKUP_FILE" | awk '{print $1}')"
sudo docker exec -i "$PROD_CONTAINER" pg_restore --list < "$BACKUP_FILE" >/dev/null
echo "Rollback archive: $BACKUP_FILE"
echo "SHA256:          $BACKUP_SHA"
echo "ROLLBACK ARCHIVE VALIDATION: PASS"

echo
echo "--- Production database preflight for migrations 057 / 058 ---"
psql_prod <<'SQL'
DO $preflight$
BEGIN
    IF to_regprocedure('ref.delete_setup_reconstruction_task(text,bigint)') IS NULL
       OR to_regprocedure('ref.setup_management_actor(text,boolean)') IS NULL
       OR to_regprocedure('ops.create_setup_session(text,integer,text)') IS NULL
       OR to_regprocedure('ref.create_setup_task(text,text,integer,text,integer,integer,integer,integer,text,text,text,text)') IS NULL
       OR to_regclass('ops.setup_session_task') IS NULL
       OR to_regclass('ops.setup_work_day_task') IS NULL
       OR to_regclass('ops.setup_task_progress') IS NULL
       OR to_regclass('ops.setup_movement_event') IS NULL
       OR to_regclass('ref.setup_task_display') IS NULL
       OR to_regclass('ref.setup_task_container_support') IS NULL
       OR to_regclass('ref.setup_task_extra_material') IS NULL THEN
        RAISE EXCEPTION 'Setup #122 2026 launch prerequisites are incomplete';
    END IF;

    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname='fieldwiring_app') THEN
        RAISE EXCEPTION 'Required fieldwiring_app role does not exist';
    END IF;

    IF to_regprocedure('ops.delete_unworked_setup_season_task(text,bigint)') IS NOT NULL THEN
        RAISE EXCEPTION 'Migration 057 season-only delete command already exists; reconcile prior/partial deployment before continuing';
    END IF;

    IF EXISTS (SELECT 1 FROM ops.setup_session WHERE season_year=2026) THEN
        RAISE EXCEPTION 'Real 2026 Setup Session exists before launch-unblock deployment';
    END IF;

    IF has_table_privilege('fieldwiring_app','ops.setup_session_task','DELETE')
       OR has_table_privilege('fieldwiring_app','ops.setup_work_day_task','DELETE')
       OR has_table_privilege('fieldwiring_app','ref.setup_task','DELETE')
       OR has_table_privilege('fieldwiring_app','ref.setup_task_display','DELETE')
       OR has_table_privilege('fieldwiring_app','ref.setup_task_container_support','DELETE') THEN
        RAISE EXCEPTION 'fieldwiring_app unexpectedly has broad Setup DELETE privilege';
    END IF;
END
$preflight$;
SQL
echo "DATABASE PREFLIGHT: PASS"

capture_function_rollback
echo "NARROW FUNCTION ROLLBACK CAPTURE: PASS"

PRE_MIGRATION_FINGERPRINT="$(setup_fingerprint)"
if [[ "$PRE_MIGRATION_FINGERPRINT" != "$FROZEN_FINGERPRINT" ]]; then
    echo "FAIL: Setup data changed after freeze and before migration"
    exit 19
fi

echo
echo "--- Apply reviewed migration 057 ---"
psql_prod < "$M057"
M057_COMMITTED=1
echo "MIGRATION 057: COMMITTED"

echo
echo "--- Apply reviewed migration 058 ---"
psql_prod < "$M058"
M058_COMMITTED=1
echo "MIGRATION 058: COMMITTED"

echo
echo "--- Validate #122 launch least-privilege / no-session contract ---"
psql_prod <<'SQL'
DO $validate$
BEGIN
    IF to_regprocedure('ops.delete_unworked_setup_season_task(text,bigint)') IS NULL THEN
        RAISE EXCEPTION 'Migration 057 season-only delete command is missing';
    END IF;

    IF NOT has_function_privilege(
        'fieldwiring_app',
        'ref.delete_setup_reconstruction_task(text,bigint)',
        'EXECUTE'
    ) OR NOT has_function_privilege(
        'fieldwiring_app',
        'ops.delete_unworked_setup_season_task(text,bigint)',
        'EXECUTE'
    ) OR NOT has_function_privilege(
        'fieldwiring_app',
        'ops.create_setup_session(text,integer,text)',
        'EXECUTE'
    ) OR NOT has_function_privilege(
        'fieldwiring_app',
        'ref.create_setup_task(text,text,integer,text,integer,integer,integer,integer,text,text,text,text)',
        'EXECUTE'
    ) THEN
        RAISE EXCEPTION 'fieldwiring_app lacks one or more governed #122 launch commands';
    END IF;

    IF has_table_privilege('fieldwiring_app','ops.setup_session_task','DELETE')
       OR has_table_privilege('fieldwiring_app','ops.setup_work_day_task','DELETE')
       OR has_table_privilege('fieldwiring_app','ref.setup_task','DELETE')
       OR has_table_privilege('fieldwiring_app','ref.setup_task_display','DELETE')
       OR has_table_privilege('fieldwiring_app','ref.setup_task_container_support','DELETE') THEN
        RAISE EXCEPTION 'Launch migrations introduced forbidden broad Setup DELETE privilege';
    END IF;

    IF EXISTS (SELECT 1 FROM ops.setup_session WHERE season_year=2026) THEN
        RAISE EXCEPTION 'Launch migrations created a real 2026 Setup Session';
    END IF;
END
$validate$;
SQL
echo "MIGRATION 057/058 SECURITY CONTRACT: PASS"

POST_DB_FINGERPRINT="$(setup_fingerprint)"
echo "Frozen fingerprint:  $FROZEN_FINGERPRINT"
echo "Post-DB fingerprint: $POST_DB_FINGERPRINT"
if [[ "$POST_DB_FINGERPRINT" != "$FROZEN_FINGERPRINT" ]]; then
    echo "FAIL: migrations 057/058 changed governed Setup data"
    exit 20
fi
echo "PASS: migrations 057/058 changed no governed Setup data"

echo
echo "--- Fast-forward dedicated Setup checkout to exact accepted SHA ---"
sudo git -C "$SETUP_ROOT" merge --ff-only "$TARGET_SHA"
APP_ADVANCED=1

DEPLOYED_HEAD="$(sudo git -C "$SETUP_ROOT" rev-parse HEAD)"
if [[ "$DEPLOYED_HEAD" != "$TARGET_SHA" ]]; then
    echo "FAIL: deployed Setup checkout is $DEPLOYED_HEAD, expected $TARGET_SHA"
    exit 21
fi
if [[ -n "$(sudo git -C "$SETUP_ROOT" status --porcelain)" ]]; then
    echo "FAIL: deployed Setup checkout is dirty"
    exit 22
fi
echo "Setup checkout advanced exactly to $DEPLOYED_HEAD"

echo
echo "--- Live regression while Setup service remains stopped ---"
sudo -u fieldwiring -H env PYTHONPYCACHEPREFIX="$LIVE_PYCACHE" bash -c     "cd '$SETUP_ROOT' && '$PYTHON' -m pytest -q -p no:cacheprovider Setup/Application"
echo "LIVE SETUP REGRESSION: PASS"

FINAL_FROZEN_FINGERPRINT="$(setup_fingerprint)"
FINAL_2026="$(setup_2026_count)"
if [[ "$FINAL_FROZEN_FINGERPRINT" != "$FROZEN_FINGERPRINT" ]]; then
    echo "FAIL: governed Setup data changed before service restart"
    exit 23
fi
if [[ "$FINAL_2026" != "0" ]]; then
    echo "FAIL: a real 2026 Setup Session exists before service restart"
    exit 24
fi
echo "FINAL FROZEN INVARIANTS: PASS"

echo
echo "--- Restart and verify Setup Production runtime ---"
restart_setup

SETUP_POST="$(curl -fsS http://192.168.5.9:8794/api/health)"
echo "Post-deploy Setup health: $SETUP_POST"
if [[ "$SETUP_POST" != *"\"status\":\"ok\""*    || "$SETUP_POST" != *"\"data_mode\":\"postgres\""*    || "$SETUP_POST" != *"\"version\":\"$EXPECTED_SETUP_VERSION\""* ]]; then
    echo "FAIL: Setup health/version does not match expected Production runtime"
    exit 25
fi
echo "SETUP HEALTH / VERSION: PASS"

echo
echo "--- Verify protected launch command/API surface ---"
UNAUTH_CODE="$(curl -sS -o /dev/null -w '%{http_code}'     -X POST     -H 'Content-Type: application/json'     -H 'X-MSB-Setup-Command: 1'     --data '{"season_year":2026,"session_status":"PLANNING"}'     http://192.168.5.9:8794/api/setup/sessions)"
echo "Unauthenticated create-session status: $UNAUTH_CODE"
if [[ "$UNAUTH_CODE" != "401" && "$UNAUTH_CODE" != "404" ]]; then
    echo "FAIL: Setup launch command surface did not reject unauthenticated request"
    exit 26
fi
echo "PROTECTED API NEGATIVE PATH: PASS"

FINAL_HEAD="$(sudo git -C "$SETUP_ROOT" rev-parse HEAD)"
FINAL_STATUS="$(sudo git -C "$SETUP_ROOT" status --porcelain)"
FINAL_FINGERPRINT="$(setup_fingerprint)"
FINAL_2026="$(setup_2026_count)"

echo
echo "--- Final Production invariants ---"
echo "Final Setup SHA:          $FINAL_HEAD"
echo "Final Setup fingerprint:  $FINAL_FINGERPRINT"
echo "2026 Setup Session count: $FINAL_2026"

[[ "$FINAL_HEAD" == "$TARGET_SHA" ]]
[[ -z "$FINAL_STATUS" ]]
[[ "$FINAL_FINGERPRINT" == "$FROZEN_FINGERPRINT" ]]
[[ "$FINAL_2026" == "0" ]]
systemctl is-active --quiet "$SETUP_SERVICE"

SUCCESS=1
echo
echo "SETUP_122_2026_LAUNCH_UNBLOCK_PRODUCTION_DEPLOYMENT_PASS"
echo "Accepted target SHA: $TARGET_SHA"
echo "Rollback archive:    $BACKUP_FILE"
echo "Rollback SHA256:     $BACKUP_SHA"
echo "Deployment report:   $REPORT"
