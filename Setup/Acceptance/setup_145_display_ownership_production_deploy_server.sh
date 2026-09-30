#!/usr/bin/env bash
set -euo pipefail

PROD_CONTAINER="msb-postgres"
PROD_DB="msb"
DB_ACTOR="msbadmin"
REPO_ROOT="/opt/fieldwiring"
SETUP_ROOT="/opt/msb-setup"
PYTHON="/opt/fieldwiring/.venv/bin/python"

SETUP_SERVICE="msb-setup.service"
DISPLAY_SERVICE="msb-display-folders.service"
GOOGLE_SERVICE="msb-setup-google-links.service"
FIELDWIRING_SERVICE="fieldwiring.service"
PROCEDURES_SERVICE="msb-procedures.service"

TARGET_REF="main"
TARGET_SHA="1b08bdd26156b67ba89ea484fdc035b0b09ffc28"
MERGE_SHA="80f6ebbcbf2946eddb1b3fe04383a2d43f61b845"
EXPECTED_SETUP_VERSION="V0.3.16-stale-ownership-cleanup"
MIGRATION_REL="Setup/Database/052_add_stale_display_ownership_cleanup.sql"
MIGRATION_BLOB="5fbe22f7af8218a0d9ca29ca25d7d53e389e7042"

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
BACKUP_DIR="/home/msbadmin/backups/setup-145"
REPORT_DIR="/home/msbadmin/setup-deployment-reports"
STAMP="$(date +%Y%m%dT%H%M%S)"
BACKUP_FILE="$BACKUP_DIR/msb-pre-setup-145-display-ownership-$STAMP.dump"
REPORT="$REPORT_DIR/Setup_145_Display_Ownership_Production_Deploy_$STAMP.txt"
CANDIDATE_WORKTREE="/tmp/msb-setup-145-display-owner-candidate-$STAMP"
NEGATIVE_BODY="/tmp/msb-setup-145-display-owner-negative-$STAMP.txt"
DETACHED_PYCACHE="/tmp/msb-setup-145-detached-pycache-$STAMP"
LIVE_PYCACHE="/tmp/msb-setup-145-live-pycache-$STAMP"

OLD_HEAD=""
INITIAL_FINGERPRINT=""
FROZEN_FINGERPRINT=""
M052=""
BACKUP_CREATED=0
DB_MIGRATION_COMMITTED=0
APP_ADVANCED=0
APP_ROLLED_BACK=0
SETUP_STOPPED=0
SUCCESS=0

mkdir -p "$REPORT_DIR"
exec > >(tee "$REPORT") 2>&1

echo "========== SETUP #145 DISPLAY OWNERSHIP PRODUCTION DEPLOYMENT =========="
echo "Authority: Gregovate/MSB-Server-Management — docs/server/Production_Database_Change_Deployment_Runbook.md"
echo "Merged main commit:      $MERGE_SHA"
echo "Browser-accepted target: $TARGET_SHA"
echo "Expected Setup version:  $EXPECTED_SETUP_VERSION"
echo "Migration:               $MIGRATION_REL"
echo "Migration Git blob:      $MIGRATION_BLOB"
echo "Report:                  $REPORT"
echo

psql_prod() {
    sudo docker exec -i "$PROD_CONTAINER" \
        psql -X -v ON_ERROR_STOP=1 -U "$DB_ACTOR" -d "$PROD_DB" "$@"
}

setup_fingerprint() {
    sudo docker exec "$PROD_CONTAINER" \
        psql -X -qAt -v ON_ERROR_STOP=1 -U "$DB_ACTOR" -d "$PROD_DB" -c "
            SELECT md5(
                coalesce((SELECT string_agg(row_to_json(t)::text, '' ORDER BY t.setup_task_id)
                          FROM ref.setup_task t), '') || '|' ||
                coalesce((SELECT string_agg(row_to_json(d)::text, '' ORDER BY d.setup_task_id, d.prerequisite_setup_task_id)
                          FROM ref.setup_task_dependency d), '') || '|' ||
                coalesce((SELECT string_agg(row_to_json(td)::text, '' ORDER BY td.setup_task_id, td.display_id)
                          FROM ref.setup_task_display td), '') || '|' ||
                coalesce((SELECT string_agg(row_to_json(tc)::text, '' ORDER BY tc.setup_task_id, tc.container_id)
                          FROM ref.setup_task_container_support tc), '') || '|' ||
                coalesce((SELECT string_agg(row_to_json(r)::text, '' ORDER BY r.setup_resource_id)
                          FROM ref.setup_resource r), '') || '|' ||
                coalesce((SELECT string_agg(row_to_json(tr)::text, '' ORDER BY tr.setup_task_id, tr.setup_resource_id)
                          FROM ref.setup_task_resource tr), '') || '|' ||
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
    sudo docker exec "$PROD_CONTAINER" \
        psql -X -qAt -v ON_ERROR_STOP=1 -U "$DB_ACTOR" -d "$PROD_DB" \
        -c "SELECT count(*) FROM ops.setup_session WHERE season_year=2026;"
}

wait_setup_ready() {
    for _ in $(seq 1 60); do
        if systemctl is-active --quiet "$SETUP_SERVICE" \
           && curl -fsS http://192.168.5.9:8794/api/health >/dev/null 2>&1; then
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

rollback_migration_052() {
    psql_prod <<'SQL'
BEGIN;
DROP FUNCTION IF EXISTS ref.clear_setup_task_display_owner(text,bigint,bigint);
COMMIT;
SQL
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

        if [[ "$DB_MIGRATION_COMMITTED" -eq 1 ]]; then
            echo "Removing only migration 052 function"
            rollback_migration_052 || true
            DB_MIGRATION_COMMITTED=0
        fi

        if [[ "$SETUP_STOPPED" -eq 1 || "$APP_ROLLED_BACK" -eq 1 ]]; then
            echo "Restarting Setup service after recovery"
            restart_setup || true
        fi
    fi

    if sudo git -C "$REPO_ROOT" worktree list --porcelain 2>/dev/null | grep -Fq "worktree $CANDIDATE_WORKTREE"; then
        sudo git -C "$REPO_ROOT" worktree remove --force "$CANDIDATE_WORKTREE" >/dev/null 2>&1 || true
    fi
    sudo git -C "$REPO_ROOT" worktree prune >/dev/null 2>&1 || true
    sudo rm -rf "$DETACHED_PYCACHE" "$LIVE_PYCACHE" >/dev/null 2>&1 || true
    rm -f "$NEGATIVE_BODY" >/dev/null 2>&1 || true
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

for service in "$SETUP_SERVICE" "$DISPLAY_SERVICE" "$GOOGLE_SERVICE" "$FIELDWIRING_SERVICE" "$PROCEDURES_SERVICE"; do
    if ! systemctl is-active --quiet "$service"; then
        echo "FAIL: required Production service is not active before deployment: $service"
        exit 7
    fi
done

SETUP_PRE="$(curl -fsS http://192.168.5.9:8794/api/health)"
FW_PRE="$(curl -fsS http://192.168.5.9:8790/api/health)"
PR_PRE="$(curl -fsS http://192.168.5.9:8792/api/health)"
echo "Pre-deploy Setup health:       $SETUP_PRE"
echo "Pre-deploy FieldWiring health: $FW_PRE"
echo "Pre-deploy Procedures health:  $PR_PRE"

INITIAL_FINGERPRINT="$(setup_fingerprint)"
[[ -n "$INITIAL_FINGERPRINT" ]] || { echo "FAIL: initial Setup fingerprint is empty"; exit 8; }
echo "Initial Setup fingerprint: $INITIAL_FINGERPRINT"

if [[ "$(setup_2026_count)" != "0" ]]; then
    echo "FAIL: real 2026 Setup Session exists before #145 deployment"
    exit 9
fi
echo "2026 Setup Session preflight: PASS (0 rows)"

echo
echo "--- Fetch and verify merged main + exact accepted target ---"
sudo git -C "$REPO_ROOT" fetch origin "$TARGET_REF:refs/remotes/origin/$TARGET_REF"
sudo git -C "$REPO_ROOT" cat-file -e "$TARGET_SHA^{commit}"
sudo git -C "$REPO_ROOT" cat-file -e "$MERGE_SHA^{commit}"

if ! sudo git -C "$REPO_ROOT" merge-base --is-ancestor "$TARGET_SHA" "origin/$TARGET_REF"; then
    echo "FAIL: exact browser-accepted target is not contained in merged origin/main"
    exit 10
fi
if ! sudo git -C "$REPO_ROOT" merge-base --is-ancestor "$MERGE_SHA" "origin/$TARGET_REF"; then
    echo "FAIL: recorded PR #232 merge commit is not contained in origin/main"
    exit 11
fi
if ! sudo git -C "$REPO_ROOT" merge-base --is-ancestor "$OLD_HEAD" "$TARGET_SHA"; then
    echo "FAIL: exact accepted target is not a forward descendant of verified live Setup checkout"
    echo "Live:   $OLD_HEAD"
    echo "Target: $TARGET_SHA"
    exit 12
fi
echo "Target ancestry: PASS"

ACTUAL_MIGRATION_BLOB="$(sudo git -C "$REPO_ROOT" rev-parse "$TARGET_SHA:$MIGRATION_REL")"
if [[ "$ACTUAL_MIGRATION_BLOB" != "$MIGRATION_BLOB" ]]; then
    echo "FAIL: migration 052 Git blob identity mismatch"
    echo "Expected: $MIGRATION_BLOB"
    echo "Actual:   $ACTUAL_MIGRATION_BLOB"
    exit 13
fi
echo "Migration 052 Git blob identity: PASS ($ACTUAL_MIGRATION_BLOB)"

echo
echo "--- Detached exact-candidate regression in Production runtime ---"
sudo git -C "$REPO_ROOT" worktree add --detach "$CANDIDATE_WORKTREE" "$TARGET_SHA"
M052="$CANDIDATE_WORKTREE/$MIGRATION_REL"
[[ -s "$M052" ]] || { echo "FAIL: exact target is missing migration 052"; exit 14; }

sudo -u fieldwiring -H env PYTHONPYCACHEPREFIX="$DETACHED_PYCACHE" bash -c \
    "cd '$CANDIDATE_WORKTREE' && '$PYTHON' -m pytest -q -p no:cacheprovider Setup/Application"
echo "DETACHED SETUP CANDIDATE REGRESSION: PASS"

echo
echo "--- Freeze Setup writes for bounded Production mutation window ---"
sudo systemctl stop "$SETUP_SERVICE"
SETUP_STOPPED=1
if systemctl is-active --quiet "$SETUP_SERVICE"; then
    echo "FAIL: Setup service did not stop"
    exit 15
fi
echo "msb-setup.service stopped: PASS"

FROZEN_FINGERPRINT="$(setup_fingerprint)"
echo "Initial fingerprint: $INITIAL_FINGERPRINT"
echo "Frozen fingerprint:  $FROZEN_FINGERPRINT"
if [[ "$FROZEN_FINGERPRINT" != "$INITIAL_FINGERPRINT" ]]; then
    echo "FAIL: Setup data changed before write freeze; stop before mutation"
    exit 16
fi
echo "WRITE-FREEZE FINGERPRINT STABILITY: PASS"

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
echo "--- Production database preflight for migration 052 ---"
psql_prod <<'SQL'
DO $preflight$
BEGIN
    IF to_regclass('ref.setup_task_display') IS NULL
       OR to_regclass('ref.setup_task') IS NULL
       OR to_regclass('ref.ux_setup_task_display_one_owner') IS NULL
       OR to_regprocedure('ref.setup_management_actor(text,boolean)') IS NULL
       OR to_regprocedure('ref.set_setup_task_display_owner(text,bigint,bigint,bigint)') IS NULL THEN
        RAISE EXCEPTION 'Accepted Setup Display ownership foundation is incomplete';
    END IF;

    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname='fieldwiring_app') THEN
        RAISE EXCEPTION 'Required fieldwiring_app role does not exist';
    END IF;

    IF to_regprocedure('ref.clear_setup_task_display_owner(text,bigint,bigint)') IS NOT NULL THEN
        RAISE EXCEPTION 'Migration 052 function already exists; reconcile before deployment';
    END IF;

    IF EXISTS (SELECT 1 FROM ops.setup_session WHERE season_year=2026) THEN
        RAISE EXCEPTION 'Real 2026 Setup Session exists before #145 deployment';
    END IF;

    IF has_table_privilege('fieldwiring_app','ref.setup_task_display','INSERT')
       OR has_table_privilege('fieldwiring_app','ref.setup_task_display','UPDATE')
       OR has_table_privilege('fieldwiring_app','ref.setup_task_display','DELETE') THEN
        RAISE EXCEPTION 'fieldwiring_app unexpectedly has broad setup_task_display DML';
    END IF;
END
$preflight$;
SQL
echo "DATABASE PREFLIGHT: PASS"

PRE_MIGRATION_FINGERPRINT="$(setup_fingerprint)"
if [[ "$PRE_MIGRATION_FINGERPRINT" != "$FROZEN_FINGERPRINT" ]]; then
    echo "FAIL: Setup data changed after freeze and before migration"
    exit 17
fi

echo
echo "--- Apply reviewed migration 052 ---"
psql_prod < "$M052"
DB_MIGRATION_COMMITTED=1
echo "MIGRATION 052: COMMITTED"

echo
echo "--- Validate migration 052 least-privilege contract ---"
psql_prod <<'SQL'
DO $validate$
BEGIN
    IF to_regprocedure('ref.clear_setup_task_display_owner(text,bigint,bigint)') IS NULL THEN
        RAISE EXCEPTION 'Migration 052 function is missing';
    END IF;

    IF NOT has_function_privilege(
        'fieldwiring_app',
        'ref.clear_setup_task_display_owner(text,bigint,bigint)',
        'EXECUTE'
    ) THEN
        RAISE EXCEPTION 'fieldwiring_app lacks required EXECUTE on ownership clear command';
    END IF;

    IF has_table_privilege('fieldwiring_app','ref.setup_task_display','INSERT')
       OR has_table_privilege('fieldwiring_app','ref.setup_task_display','UPDATE')
       OR has_table_privilege('fieldwiring_app','ref.setup_task_display','DELETE') THEN
        RAISE EXCEPTION 'Migration 052 introduced forbidden broad setup_task_display DML';
    END IF;

    IF EXISTS (SELECT 1 FROM ops.setup_session WHERE season_year=2026) THEN
        RAISE EXCEPTION 'Migration 052 created a real 2026 Setup Session';
    END IF;
END
$validate$;
SQL
echo "MIGRATION 052 SECURITY CONTRACT: PASS"

POST_DB_FINGERPRINT="$(setup_fingerprint)"
echo "Frozen fingerprint:  $FROZEN_FINGERPRINT"
echo "Post-DB fingerprint: $POST_DB_FINGERPRINT"
if [[ "$POST_DB_FINGERPRINT" != "$FROZEN_FINGERPRINT" ]]; then
    echo "FAIL: migration 052 changed governed Setup data"
    exit 18
fi
echo "PASS: migration 052 changed no governed Setup data"

echo
echo "--- Fast-forward dedicated Setup checkout to exact accepted SHA ---"
sudo git -C "$SETUP_ROOT" merge --ff-only "$TARGET_SHA"
APP_ADVANCED=1

DEPLOYED_HEAD="$(sudo git -C "$SETUP_ROOT" rev-parse HEAD)"
if [[ "$DEPLOYED_HEAD" != "$TARGET_SHA" ]]; then
    echo "FAIL: deployed Setup checkout is $DEPLOYED_HEAD, expected $TARGET_SHA"
    exit 19
fi
if [[ -n "$(sudo git -C "$SETUP_ROOT" status --porcelain)" ]]; then
    echo "FAIL: deployed Setup checkout is dirty"
    exit 20
fi
echo "Setup checkout advanced exactly to $DEPLOYED_HEAD"

echo
echo "--- Live regression while Setup service remains stopped ---"
sudo -u fieldwiring -H env PYTHONPYCACHEPREFIX="$LIVE_PYCACHE" bash -c \
    "cd '$SETUP_ROOT' && '$PYTHON' -m pytest -q -p no:cacheprovider Setup/Application"
echo "LIVE SETUP REGRESSION: PASS"

FINAL_FROZEN_FINGERPRINT="$(setup_fingerprint)"
FINAL_2026="$(setup_2026_count)"
if [[ "$FINAL_FROZEN_FINGERPRINT" != "$FROZEN_FINGERPRINT" ]]; then
    echo "FAIL: governed Setup data changed before service restart"
    exit 21
fi
if [[ "$FINAL_2026" != "0" ]]; then
    echo "FAIL: a real 2026 Setup Session exists before service restart"
    exit 22
fi
echo "FINAL FROZEN INVARIANTS: PASS"

echo
echo "--- Restart and verify Setup Production runtime ---"
restart_setup

SETUP_POST="$(curl -fsS http://192.168.5.9:8794/api/health)"
echo "Post-deploy Setup health: $SETUP_POST"
if [[ "$SETUP_POST" != *"\"status\":\"ok\""* \
   || "$SETUP_POST" != *"\"data_mode\":\"postgres\""* \
   || "$SETUP_POST" != *"\"version\":\"$EXPECTED_SETUP_VERSION\""* ]]; then
    echo "FAIL: Setup health/version does not match expected Production runtime"
    exit 23
fi
echo "SETUP HEALTH / VERSION: PASS"

OWNERSHIP_JS="$(curl -fsS http://192.168.5.9:8794/setup_display_ownership.js)"
if [[ "$OWNERSHIP_JS" != *"contextmenu"* \
   || "$OWNERSHIP_JS" != *"Remove stale ownership"* \
   || "$OWNERSHIP_JS" != *"shown as Missing owner until you assign it again"* ]]; then
    echo "FAIL: deployed Display Ownership asset does not contain accepted #145 behavior"
    exit 24
fi
echo "DEPLOYED DISPLAY OWNERSHIP ASSET: PASS"

NEGATIVE_CODE="$(curl -sS -o "$NEGATIVE_BODY" -w '%{http_code}' \
    -X DELETE \
    -H 'Content-Type: application/json' \
    -H 'X-MSB-Setup-Command: 1' \
    --data '{"season_year":2025,"expected_setup_task_id":1}' \
    http://192.168.5.9:8794/api/setup/tasks/1/display-ownership/1)"
echo "Unauthenticated ownership DELETE status: $NEGATIVE_CODE"
if [[ "$NEGATIVE_CODE" != "401" ]]; then
    echo "FAIL: new protected ownership DELETE endpoint did not reject unauthenticated request"
    cat "$NEGATIVE_BODY" || true
    exit 25
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
echo "SETUP_145_DISPLAY_OWNERSHIP_PRODUCTION_DEPLOYMENT_PASS"
echo "Accepted target SHA: $TARGET_SHA"
echo "Merged main commit:  $MERGE_SHA"
echo "Rollback archive:    $BACKUP_FILE"
echo "Rollback SHA256:     $BACKUP_SHA"
echo "Deployment report:   $REPORT"
