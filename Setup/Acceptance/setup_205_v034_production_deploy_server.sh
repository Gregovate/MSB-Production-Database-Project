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
ACCEPTED_CANDIDATE_SHA="e103eedbf8caaf580ce6fe5df392fbd68c0cb7f4"
TARGET_SHA="e103eedbf8caaf580ce6fe5df392fbd68c0cb7f4"
EXPECTED_PRE_VERSION="V0.3.33-material-status-review-fixes"
EXPECTED_POST_VERSION="V0.3.34-scheduling-readiness-fixes"

MIGRATION_REL="Setup/Database/067_fix_setup_annual_hold_command.sql"
MIGRATION_BLOB="ee2e9417efc22a9821258df0522a7f518117b5e8"
VALIDATION_REL="Setup/Acceptance/setup_205_annual_hold_disposable_validation.sql"
VALIDATION_BLOB="6348a824e0393af954c92087b34acbb2767ec64f"

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
STAMP="$(date +%Y%m%dT%H%M%S)"
BACKUP_DIR="/home/msbadmin/backups/setup-205"
REPORT_DIR="/home/msbadmin/setup-deployment-reports"
BACKUP_FILE="$BACKUP_DIR/msb-pre-setup-205-v034-$STAMP.dump"
REPORT="$REPORT_DIR/Setup_205_V034_Production_Deploy_$STAMP.txt"
CANDIDATE_WORKTREE="/tmp/msb-setup-205-v034-candidate-$STAMP"
DETACHED_PYCACHE="/tmp/msb-setup-205-v034-detached-pycache-$STAMP"
LIVE_PYCACHE="/tmp/msb-setup-205-v034-live-pycache-$STAMP"

OLD_HEAD=""
INITIAL_FINGERPRINT=""
FROZEN_FINGERPRINT=""
INITIAL_2026_COUNT=""
BACKUP_CREATED=0
DB_MIGRATION_COMMITTED=0
APP_ADVANCED=0
SETUP_STOPPED=0
SUCCESS=0
BACKUP_SHA=""

mkdir -p "$REPORT_DIR"
exec > >(tee "$REPORT") 2>&1

echo "========== SETUP #205 V0.3.34 PRODUCTION DEPLOYMENT =========="
echo "Authority: Gregovate/MSB-Server-Management — docs/server/Production_Database_Change_Deployment_Runbook.md"
echo "Authority: Gregovate/MSB-Server-Management — docs/server/Setup_Production_Runtime.md"
echo "Accepted candidate SHA: $ACCEPTED_CANDIDATE_SHA"
echo "Expected Setup version: $EXPECTED_PRE_VERSION -> $EXPECTED_POST_VERSION"
echo "Migration: $MIGRATION_REL"
echo "Migration blob: $MIGRATION_BLOB"
echo "Validation: $VALIDATION_REL"
echo "Validation blob: $VALIDATION_BLOB"
echo "Server Management #37 maintenance page/write-freeze service is not yet implemented."
echo "This bounded deployment uses the established manually announced window and stops msb-setup.service during mutation."
echo "Report: $REPORT"
echo

psql_prod() {
    sudo docker exec -i "$PROD_CONTAINER" \
        psql -X -v ON_ERROR_STOP=1 -U "$DB_ACTOR" -d "$PROD_DB" "$@"
}

setup_fingerprint() {
    sudo docker exec "$PROD_CONTAINER" \
        psql -X -qAt -v ON_ERROR_STOP=1 -U "$DB_ACTOR" -d "$PROD_DB" -c "
            SELECT md5(
                coalesce((SELECT string_agg(row_to_json(t)::text, '' ORDER BY t.setup_task_id) FROM ref.setup_task t), '') || '|' ||
                coalesce((SELECT string_agg(row_to_json(d)::text, '' ORDER BY d.setup_task_id, d.prerequisite_setup_task_id) FROM ref.setup_task_dependency d), '') || '|' ||
                coalesce((SELECT string_agg(row_to_json(td)::text, '' ORDER BY td.setup_task_id, td.display_id) FROM ref.setup_task_display td), '') || '|' ||
                coalesce((SELECT string_agg(row_to_json(tc)::text, '' ORDER BY tc.setup_task_id, tc.container_id) FROM ref.setup_task_container_support tc), '') || '|' ||
                coalesce((SELECT string_agg(row_to_json(s)::text, '' ORDER BY s.setup_session_id) FROM ops.setup_session s), '') || '|' ||
                coalesce((SELECT string_agg(row_to_json(st)::text, '' ORDER BY st.setup_session_task_id) FROM ops.setup_session_task st), '') || '|' ||
                coalesce((SELECT string_agg(row_to_json(wd)::text, '' ORDER BY wd.setup_work_day_id) FROM ops.setup_work_day wd), '') || '|' ||
                coalesce((SELECT string_agg(row_to_json(wt)::text, '' ORDER BY wt.setup_work_day_task_id) FROM ops.setup_work_day_task wt), '') || '|' ||
                coalesce((SELECT string_agg(row_to_json(o)::text, '' ORDER BY o.setup_pick_list_override_id) FROM ops.setup_pick_list_override o), '') || '|' ||
                coalesce((SELECT string_agg(row_to_json(d)::text, '' ORDER BY d.setup_pick_list_delay_id) FROM ops.setup_pick_list_delay d), '') || '|' ||
                coalesce((SELECT string_agg(row_to_json(me)::text, '' ORDER BY me.setup_movement_event_id) FROM ops.setup_movement_event me), '') || '|' ||
                coalesce((SELECT string_agg(row_to_json(cs)::text, '' ORDER BY cs.setup_session_id, cs.container_id) FROM ops.setup_container_state cs), '') || '|' ||
                coalesce((SELECT string_agg(row_to_json(ds)::text, '' ORDER BY ds.setup_session_id, ds.display_id) FROM ops.setup_display_state ds), '')
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

cleanup() {
    status=$?
    trap - EXIT HUP INT TERM
    set +e

    if [[ "$status" -ne 0 && "$SUCCESS" -ne 1 ]]; then
        echo
        echo "--- FAIL-CLOSED RECOVERY ---"

        if [[ "$APP_ADVANCED" -eq 1 && -n "$OLD_HEAD" ]]; then
            echo "Restoring Setup checkout to prior SHA $OLD_HEAD"
            sudo git -C "$SETUP_ROOT" checkout --detach "$OLD_HEAD" || true
            APP_ADVANCED=0
        fi

        if [[ "$SETUP_STOPPED" -eq 1 || -n "$OLD_HEAD" ]]; then
            echo "Restarting Setup service after recovery"
            restart_setup || true
        fi

        if [[ "$DB_MIGRATION_COMMITTED" -eq 1 ]]; then
            echo "Migration 067 reached committed state and is intentionally not auto-restored."
            echo "The new annual-hold function is not used by the prior V0.3.33 application and is left installed for governed recovery review."
            echo "Use the retained rollback archive only through a separately governed recovery decision if database rollback is required."
        else
            echo "Migration 067 did not reach committed-success state."
        fi
    fi

    WORKTREE_LIST="$(sudo git -C "$REPO_ROOT" worktree list --porcelain 2>/dev/null || true)"
    if [[ "$WORKTREE_LIST" == *"worktree $CANDIDATE_WORKTREE"* ]]; then
        sudo git -C "$REPO_ROOT" worktree remove --force "$CANDIDATE_WORKTREE" >/dev/null 2>&1 || true
    fi
    sudo git -C "$REPO_ROOT" worktree prune >/dev/null 2>&1 || true
    sudo rm -rf "$DETACHED_PYCACHE" "$LIVE_PYCACHE" >/dev/null 2>&1 || true
    rm -rf "$SCRIPT_DIR" >/dev/null 2>&1 || true

    echo
    echo "--- Production after-check ---"
    if [[ -n "$FROZEN_FINGERPRINT" ]]; then
        AFTER_FINGERPRINT="$(setup_fingerprint 2>/dev/null || true)"
        echo "Frozen Setup fingerprint: $FROZEN_FINGERPRINT"
        echo "Final Setup fingerprint:  $AFTER_FINGERPRINT"
        if [[ -z "$AFTER_FINGERPRINT" || "$AFTER_FINGERPRINT" != "$FROZEN_FINGERPRINT" ]]; then
            echo "FAIL: governed Setup business rows changed during deployment"
            status=97
        else
            echo "PASS: governed Setup business rows unchanged"
        fi
    fi

    if [[ -n "$INITIAL_2026_COUNT" ]]; then
        FINAL_2026_COUNT="$(setup_2026_count 2>/dev/null || true)"
        echo "2026 Setup Session count before: $INITIAL_2026_COUNT"
        echo "2026 Setup Session count after:  $FINAL_2026_COUNT"
        if [[ -z "$FINAL_2026_COUNT" || "$FINAL_2026_COUNT" != "$INITIAL_2026_COUNT" ]]; then
            echo "FAIL: 2026 Setup Session count changed during deployment"
            status=96
        else
            echo "PASS: 2026 Setup Session count unchanged"
        fi
    fi

    if [[ "$BACKUP_CREATED" -eq 1 && -s "$BACKUP_FILE" ]]; then
        echo "Rollback PostgreSQL archive retained at: $BACKUP_FILE"
        echo "Rollback SHA256: ${BACKUP_SHA:-unknown}"
    else
        echo "Rollback PostgreSQL archive: not created before this stop"
    fi

    echo "Deployment report retained at: $REPORT"
    echo "Exit status: $status"
    exit "$status"
}
trap cleanup EXIT HUP INT TERM

sudo -v
mkdir -p "$BACKUP_DIR" "$REPORT_DIR"

echo "--- Verify current Production runtime ---"
sudo docker inspect "$PROD_CONTAINER" >/dev/null
[[ "$(sudo docker inspect "$PROD_CONTAINER" --format '{{.Config.Image}}')" == "postgis/postgis:16-3.5" ]]
WORKTREE_LIST="$(sudo git -C "$REPO_ROOT" worktree list --porcelain)"
[[ "$WORKTREE_LIST" == *"worktree $SETUP_ROOT"* ]]
[[ -z "$(sudo git -C "$REPO_ROOT" status --porcelain)" ]]
[[ -z "$(sudo git -C "$SETUP_ROOT" status --porcelain)" ]]
systemctl is-active --quiet "$SETUP_SERVICE"

OLD_HEAD="$(sudo git -C "$SETUP_ROOT" rev-parse HEAD)"
echo "Verified live Setup checkout: $OLD_HEAD"

SETUP_PRE="$(curl -fsS http://192.168.5.9:8794/api/health)"
echo "Pre-deploy Setup health: $SETUP_PRE"
if [[ "$SETUP_PRE" != *"\"status\":\"ok\""* \
   || "$SETUP_PRE" != *"\"data_mode\":\"postgres\""* \
   || "$SETUP_PRE" != *"\"version\":\"$EXPECTED_PRE_VERSION\""* ]]; then
    echo "FAIL: live Setup pre-version/health is not $EXPECTED_PRE_VERSION"
    exit 12
fi

INITIAL_FINGERPRINT="$(setup_fingerprint)"
INITIAL_2026_COUNT="$(setup_2026_count)"
[[ -n "$INITIAL_FINGERPRINT" ]]
[[ "$INITIAL_2026_COUNT" == "1" ]]
echo "Initial Setup fingerprint:        $INITIAL_FINGERPRINT"
echo "Initial 2026 Setup Session count: $INITIAL_2026_COUNT"

echo
echo "--- Fetch and verify exact approved target ---"
sudo git -C "$REPO_ROOT" fetch origin "+refs/heads/main:refs/remotes/origin/main"
sudo git -C "$REPO_ROOT" cat-file -e "$ACCEPTED_CANDIDATE_SHA^{commit}"
sudo git -C "$REPO_ROOT" cat-file -e "$TARGET_SHA^{commit}"
sudo git -C "$REPO_ROOT" merge-base --is-ancestor "$ACCEPTED_CANDIDATE_SHA" origin/main
sudo git -C "$REPO_ROOT" merge-base --is-ancestor "$OLD_HEAD" "$TARGET_SHA"
echo "Target ancestry: PASS"

ACTUAL_MIGRATION_BLOB="$(sudo git -C "$REPO_ROOT" rev-parse "$TARGET_SHA:$MIGRATION_REL")"
ACTUAL_VALIDATION_BLOB="$(sudo git -C "$REPO_ROOT" rev-parse "$TARGET_SHA:$VALIDATION_REL")"
[[ "$ACTUAL_MIGRATION_BLOB" == "$MIGRATION_BLOB" ]]
[[ "$ACTUAL_VALIDATION_BLOB" == "$VALIDATION_BLOB" ]]
echo "Migration/validation Git blob identity: PASS"

echo
echo "--- Detached exact-candidate regression in Production runtime ---"
sudo git -C "$REPO_ROOT" worktree add --detach "$CANDIDATE_WORKTREE" "$TARGET_SHA"
M067="$CANDIDATE_WORKTREE/$MIGRATION_REL"
V067="$CANDIDATE_WORKTREE/$VALIDATION_REL"
[[ -s "$M067" && -s "$V067" ]]

grep -Fq 'PRODUCTION_VERSION = "V0.3.34-scheduling-readiness-fixes"' \
    "$CANDIDATE_WORKTREE/Setup/Application/production_backend.py"
grep -Fq "CLIENT_BUILD = 'V0.3.34-scheduling-readiness-fixes'" \
    "$CANDIDATE_WORKTREE/Setup/Application/setup_catalog_dirty_guard.js"

sudo -u fieldwiring -H env PYTHONPYCACHEPREFIX="$DETACHED_PYCACHE" bash -c \
    "cd '$CANDIDATE_WORKTREE' && '$PYTHON' -m pytest -q -p no:cacheprovider Setup/Application"
echo "DETACHED SETUP CANDIDATE REGRESSION: PASS"
echo "DETACHED SETUP CANDIDATE HEAD: $TARGET_SHA"

echo
echo "--- Freeze Setup writes for bounded Production mutation window ---"
sudo systemctl stop "$SETUP_SERVICE"
SETUP_STOPPED=1
if systemctl is-active --quiet "$SETUP_SERVICE"; then
    echo "FAIL: Setup service did not stop"
    exit 16
fi
echo "msb-setup.service stopped: PASS"

FROZEN_FINGERPRINT="$(setup_fingerprint)"
echo "Initial fingerprint: $INITIAL_FINGERPRINT"
echo "Frozen fingerprint:  $FROZEN_FINGERPRINT"
[[ "$FROZEN_FINGERPRINT" == "$INITIAL_FINGERPRINT" ]]
[[ "$(setup_2026_count)" == "$INITIAL_2026_COUNT" ]]
echo "WRITE-FREEZE STABILITY: PASS"

echo
echo "--- Create and validate rollback PostgreSQL archive ---"
sudo docker exec "$PROD_CONTAINER" \
    pg_dump -U "$DB_ACTOR" -d "$PROD_DB" -Fc > "$BACKUP_FILE"
test -s "$BACKUP_FILE"
BACKUP_CREATED=1
BACKUP_SHA="$(sha256sum "$BACKUP_FILE")"
BACKUP_SHA="${BACKUP_SHA%% *}"
sudo docker exec -i "$PROD_CONTAINER" pg_restore --list < "$BACKUP_FILE" >/dev/null
echo "Rollback archive: $BACKUP_FILE"
echo "SHA256:          $BACKUP_SHA"
echo "ROLLBACK ARCHIVE VALIDATION: PASS"

echo
echo "--- Production database preflight for migration 067 ---"
psql_prod <<'SQL'
DO $preflight$
BEGIN
    IF to_regclass('ops.setup_session_task') IS NULL
       OR to_regclass('ops.setup_task_progress') IS NULL
       OR to_regprocedure('ops.set_setup_annual_task_readiness(text,bigint,boolean)') IS NULL
       OR to_regprocedure('ops.enforce_setup_readiness_note_state()') IS NULL THEN
        RAISE EXCEPTION 'Accepted #205 readiness foundation is incomplete';
    END IF;

    IF to_regprocedure('ops.set_setup_annual_hold(text,bigint,boolean,text)') IS NOT NULL THEN
        RAISE EXCEPTION 'Migration 067 command already exists before deployment';
    END IF;

    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname='fieldwiring_app') THEN
        RAISE EXCEPTION 'Required fieldwiring_app role does not exist';
    END IF;

    IF (SELECT count(*) FROM ops.setup_session WHERE season_year=2026) <> 1 THEN
        RAISE EXCEPTION 'Expected exactly one 2026 Setup Session';
    END IF;
END
$preflight$;
SQL
echo "DATABASE PREFLIGHT: PASS"

PRE_MUTATION_FINGERPRINT="$(setup_fingerprint)"
[[ "$PRE_MUTATION_FINGERPRINT" == "$FROZEN_FINGERPRINT" ]]
echo "PRE-MUTATION FINGERPRINT STABILITY: PASS"

echo
echo "--- Apply reviewed migration 067 ---"
psql_prod < "$M067"
DB_MIGRATION_COMMITTED=1
echo "MIGRATION 067: COMMITTED"

echo
echo "--- Run exact rollback-safe validation against Production while writes are frozen ---"
VALIDATION_OUTPUT="$(psql_prod < "$V067")"
if [[ "$VALIDATION_OUTPUT" != *"SETUP_205_ANNUAL_HOLD_DISPOSABLE_VALIDATION_PASS"* ]]; then
    echo "FAIL: exact migration 067 validation marker was not returned"
    printf '%s\n' "$VALIDATION_OUTPUT"
    exit 19
fi
echo "MIGRATION 067 VALIDATION: PASS"

echo
echo "--- Validate authority and least privilege ---"
psql_prod <<'SQL'
DO $validate$
BEGIN
    IF NOT has_function_privilege(
        'fieldwiring_app',
        'ops.set_setup_annual_hold(text,bigint,boolean,text)',
        'EXECUTE'
    ) OR NOT has_function_privilege(
        'fieldwiring_app',
        'ops.set_setup_annual_task_readiness(text,bigint,boolean)',
        'EXECUTE'
    ) THEN
        RAISE EXCEPTION 'Annual readiness command EXECUTE privilege is incomplete';
    END IF;

    IF has_table_privilege('fieldwiring_app','ops.setup_session_task','INSERT')
       OR has_table_privilege('fieldwiring_app','ops.setup_session_task','UPDATE')
       OR has_table_privilege('fieldwiring_app','ops.setup_session_task','DELETE') THEN
        RAISE EXCEPTION 'Forbidden broad setup_session_task DML privilege detected';
    END IF;
END
$validate$;
SQL
echo "DATABASE CONTRACT VALIDATION: PASS"

POST_DB_FINGERPRINT="$(setup_fingerprint)"
echo "Setup fingerprint before migration: $FROZEN_FINGERPRINT"
echo "Setup fingerprint after migration:  $POST_DB_FINGERPRINT"
[[ "$POST_DB_FINGERPRINT" == "$FROZEN_FINGERPRINT" ]]
echo "PASS: migration 067 preserved governed Setup business data"

echo
echo "--- Advance dedicated Setup Production checkout to exact accepted candidate ---"
sudo git -C "$SETUP_ROOT" checkout --detach "$TARGET_SHA"
APP_ADVANCED=1
DEPLOYED_HEAD="$(sudo git -C "$SETUP_ROOT" rev-parse HEAD)"
DEPLOYED_STATUS="$(sudo git -C "$SETUP_ROOT" status --porcelain)"
[[ "$DEPLOYED_HEAD" == "$TARGET_SHA" && -z "$DEPLOYED_STATUS" ]]
echo "Setup checkout advanced exactly to $DEPLOYED_HEAD"

echo
echo "--- Restart and verify Setup V0.3.34 runtime ---"
restart_setup
SETUP_POST="$(curl -fsS http://192.168.5.9:8794/api/health)"
echo "Post-deploy Setup health: $SETUP_POST"
if [[ "$SETUP_POST" != *"\"status\":\"ok\""* \
   || "$SETUP_POST" != *"\"data_mode\":\"postgres\""* \
   || "$SETUP_POST" != *"\"version\":\"$EXPECTED_POST_VERSION\""* ]]; then
    echo "FAIL: Setup health/version does not match $EXPECTED_POST_VERSION"
    exit 22
fi

ROOT_HTML="$(curl -fsS http://192.168.5.9:8794/)"
for token in \
    'id="app-alert" class="notice production-notice" aria-live="polite" hidden' \
    'setup.css?v=2026-10-01.1' \
    'setup_scheduling_board.css?v=2026-10-01.1' \
    'setup_production.js?v=2026-10-01.2' \
    'setup_catalog_dirty_guard.js?v=2026-10-01.4'; do
    if [[ "$ROOT_HTML" != *"$token"* ]]; then
        echo "FAIL: live Setup root is missing accepted token: $token"
        exit 23
    fi
done

PRODUCTION_JS="$(curl -fsS http://192.168.5.9:8794/setup_production.js)"
if [[ "$PRODUCTION_JS" != *"document.body.classList.toggle('setup-schedule-view', name === 'schedule')"* ]]; then
    echo "FAIL: live Setup source is missing Scheduling view width scoping"
    exit 24
fi
if [[ "$PRODUCTION_JS" == *"Setup Session loaded from Production. Changes made by authorized Managers are shared immediately."* ]]; then
    echo "FAIL: live Setup source still contains persistent Production success banner"
    exit 25
fi

SCHED_JS="$(curl -fsS http://192.168.5.9:8794/setup_scheduling_board.js)"
if [[ "$SCHED_JS" != *"/readiness"* || "$SCHED_JS" != *"/annual-hold"* ]]; then
    echo "FAIL: live Scheduling Board readiness routes are incomplete"
    exit 26
fi
if [[ "$SCHED_JS" == *"Readiness condition · soft"* ]]; then
    echo "FAIL: live Scheduling Board still repeats readiness text"
    exit 27
fi

SCHED_CSS="$(curl -fsS http://192.168.5.9:8794/setup_scheduling_board.css)"
if [[ "$SCHED_CSS" != *"@media (min-width: 1600px)"* ]]; then
    echo "FAIL: live Scheduling Board CSS is missing wide-screen expansion"
    exit 28
fi
echo "V0.3.34 #205 SOURCE CONTRACT: PASS"

NEGATIVE_BODY="/tmp/msb-setup-205-v034-negative-$STAMP.json"
NEGATIVE_CODE="$(curl -sS -o "$NEGATIVE_BODY" -w '%{http_code}' \
    -X PATCH \
    -H 'Content-Type: application/json' \
    -H 'X-MSB-Setup-Command: 1' \
    --data '{"ready":true,"readiness_note":"negative-path"}' \
    'http://192.168.5.9:8794/api/setup/scheduling-board/season-tasks/1/annual-hold')"
echo "Direct unauthenticated Annual Readiness API status: $NEGATIVE_CODE"
if [[ "$NEGATIVE_CODE" != "401" ]]; then
    echo "FAIL: protected Annual Readiness API did not reject unauthenticated direct request"
    cat "$NEGATIVE_BODY" || true
    exit 29
fi
rm -f "$NEGATIVE_BODY"
echo "PROTECTED ANNUAL READINESS NEGATIVE PATH: PASS"

echo "--- Live Setup regression ---"
sudo -u fieldwiring -H env PYTHONPYCACHEPREFIX="$LIVE_PYCACHE" bash -c \
    "cd '$SETUP_ROOT' && '$PYTHON' -m pytest -q -p no:cacheprovider Setup/Application"
echo "LIVE SETUP REGRESSION: PASS"
echo "LIVE SETUP HEAD: $TARGET_SHA"

echo
echo "--- Final Production invariants ---"
FINAL_HEAD="$(sudo git -C "$SETUP_ROOT" rev-parse HEAD)"
FINAL_STATUS="$(sudo git -C "$SETUP_ROOT" status --porcelain)"
FINAL_FINGERPRINT="$(setup_fingerprint)"
FINAL_2026_COUNT="$(setup_2026_count)"
FINAL_HEALTH="$(curl -fsS http://192.168.5.9:8794/api/health)"

echo "Final Setup SHA:                $FINAL_HEAD"
echo "Final Setup fingerprint:        $FINAL_FINGERPRINT"
echo "Final 2026 Setup Session count: $FINAL_2026_COUNT"
echo "Final Setup health:             $FINAL_HEALTH"

[[ "$FINAL_HEAD" == "$TARGET_SHA" ]]
[[ -z "$FINAL_STATUS" ]]
[[ "$FINAL_FINGERPRINT" == "$FROZEN_FINGERPRINT" ]]
[[ "$FINAL_2026_COUNT" == "$INITIAL_2026_COUNT" ]]
[[ "$FINAL_HEALTH" == *"\"version\":\"$EXPECTED_POST_VERSION\""* ]]

SUCCESS=1
echo
echo "SETUP_205_V034_PRODUCTION_DEPLOYMENT_PASS"
echo "Rollback archive:  $BACKUP_FILE"
echo "Rollback SHA256:   $BACKUP_SHA"
echo "Deployment report: $REPORT"
