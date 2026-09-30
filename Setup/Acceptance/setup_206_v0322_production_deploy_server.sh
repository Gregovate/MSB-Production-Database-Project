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
ACCEPTED_CANDIDATE_SHA="6f53d7f0c4b15f7175e773a2069595eef3f0e698"
TARGET_SHA="6f53d7f0c4b15f7175e773a2069595eef3f0e698"
EXPECTED_PRE_VERSION="V0.3.21-scheduling-gates"
EXPECTED_POST_VERSION="V0.3.22-pick-list-delay"
MIGRATION_REL="Setup/Database/063_add_setup_pick_list_delay.sql"
MIGRATION_BLOB="45d1f71e226ab9e358e40f331945135cbe19cfb8"

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
BACKUP_DIR="/home/msbadmin/backups/setup-206"
REPORT_DIR="/home/msbadmin/setup-deployment-reports"
STAMP="$(date +%Y%m%dT%H%M%S)"
BACKUP_FILE="$BACKUP_DIR/msb-pre-setup-206-v0322-pick-list-delay-$STAMP.dump"
REPORT="$REPORT_DIR/Setup_206_V0322_Pick_List_Delay_Production_Deploy_$STAMP.txt"
CANDIDATE_WORKTREE="/tmp/msb-setup-206-v0322-candidate-$STAMP"
DETACHED_PYCACHE="/tmp/msb-setup-206-v0322-detached-pycache-$STAMP"
LIVE_PYCACHE="/tmp/msb-setup-206-v0322-live-pycache-$STAMP"
NEGATIVE_BODY="/tmp/msb-setup-206-v0322-negative-$STAMP.txt"

OLD_HEAD=""
INITIAL_FINGERPRINT=""
FROZEN_FINGERPRINT=""
INITIAL_2026_COUNT=""
BACKUP_CREATED=0
DB_MIGRATION_COMMITTED=0
APP_ADVANCED=0
APP_ROLLED_BACK=0
SETUP_STOPPED=0
MIGRATION_ROLLED_BACK=0
SUCCESS=0

mkdir -p "$REPORT_DIR"
exec > >(tee "$REPORT") 2>&1

echo "========== SETUP #206 V0.3.22 PICK LIST DELAY PRODUCTION DEPLOYMENT =========="
echo "Authority: Gregovate/MSB-Server-Management — docs/server/Production_Database_Change_Deployment_Runbook.md"
echo "Exact accepted candidate SHA: $ACCEPTED_CANDIDATE_SHA"
echo "Deployment target SHA:         $TARGET_SHA"
echo "Expected pre-version:          $EXPECTED_PRE_VERSION"
echo "Expected post-version:         $EXPECTED_POST_VERSION"
echo "Migration:                     $MIGRATION_REL"
echo "Approved migration path:        $MIGRATION_REL"
echo "Approved migration Git blob:    $MIGRATION_BLOB"
echo "Report:                        $REPORT"
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
                coalesce((SELECT string_agg(row_to_json(r)::text, '' ORDER BY r.setup_resource_id) FROM ref.setup_resource r), '') || '|' ||
                coalesce((SELECT string_agg(row_to_json(tr)::text, '' ORDER BY tr.setup_task_id, tr.setup_resource_id) FROM ref.setup_task_resource tr), '') || '|' ||
                coalesce((SELECT string_agg(row_to_json(s)::text, '' ORDER BY s.setup_session_id) FROM ops.setup_session s), '') || '|' ||
                coalesce((SELECT string_agg(row_to_json(st)::text, '' ORDER BY st.setup_session_task_id) FROM ops.setup_session_task st), '') || '|' ||
                coalesce((SELECT string_agg(row_to_json(wd)::text, '' ORDER BY wd.setup_work_day_id) FROM ops.setup_work_day wd), '')
            );
        "
}

setup_2026_count() {
    sudo docker exec "$PROD_CONTAINER" \
        psql -X -qAt -v ON_ERROR_STOP=1 -U "$DB_ACTOR" -d "$PROD_DB" \
        -c "SELECT count(*) FROM ops.setup_session WHERE season_year=2026;"
}

delay_count() {
    sudo docker exec "$PROD_CONTAINER" \
        psql -X -qAt -v ON_ERROR_STOP=1 -U "$DB_ACTOR" -d "$PROD_DB" -c "
            SELECT CASE
                WHEN to_regclass('ops.setup_pick_list_delay') IS NULL THEN -1
                ELSE (SELECT count(*) FROM ops.setup_pick_list_delay)
            END;
        "
}

wait_setup_ready() {wait_setup_ready() {
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

rollback_migration_063_pick_delay() {
    local rows
    rows="$(delay_count 2>/dev/null || true)"
    if [[ "$rows" != "0" ]]; then
        echo "REFUSE automatic Pick Delay rollback: row count is '${rows:-unknown}', expected 0"
        return 1
    fi
    psql_prod <<'SQL'
BEGIN;
DROP TRIGGER IF EXISTS trg_setup_pick_list_delay_schedule_release ON ops.setup_work_day_task;
DROP FUNCTION IF EXISTS ops.clear_setup_pick_list_delay_on_schedule();
DROP FUNCTION IF EXISTS ops.set_setup_pick_list_delay(
    text,integer,integer,bigint[],text,boolean
);
DROP TABLE IF EXISTS ops.setup_pick_list_delay;
COMMIT;
SQL
    MIGRATION_ROLLED_BACK=1
}

cleanup() {cleanup() {
    status=$?
    trap - EXIT HUP INT TERM
    set +e

    if [[ "$status" -ne 0 && "$SUCCESS" -ne 1 ]]; then
        echo
        echo "--- FAIL-CLOSED RECOVERY ---"

        if [[ "$APP_ADVANCED" -eq 1 && -n "$OLD_HEAD" ]]; then
            echo "Restoring Setup checkout to verified prior SHA $OLD_HEAD"
            sudo git -C "$SETUP_ROOT" checkout --detach "$OLD_HEAD" || true
            APP_ADVANCED=0
            APP_ROLLED_BACK=1
        fi

        if [[ "$DB_MIGRATION_COMMITTED" -eq 1 ]]; then
            if systemctl is-active --quiet "$SETUP_SERVICE"; then
                echo "Stopping Setup service before migration rollback"
                sudo systemctl stop "$SETUP_SERVICE" || true
                SETUP_STOPPED=1
            fi
            echo "Attempting bounded rollback of Pick Delay migration"
            if rollback_migration_063_pick_delay; then
                DB_MIGRATION_COMMITTED=0
                echo "Pick Delay migration rollback: PASS"
            else
                echo "WARNING: Pick Delay migration was not automatically removed; review retained backup/report before further mutation"
            fi
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

echo "--- Verify Production runtime and live Setup checkout ---"
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
    echo "FAIL: $SETUP_SERVICE is not active before deployment"
    exit 7
fi

SETUP_PRE="$(curl -fsS http://192.168.5.9:8794/api/health)"
echo "Pre-deploy Setup health: $SETUP_PRE"
if [[ "$SETUP_PRE" != *"\"status\":\"ok\""* \
   || "$SETUP_PRE" != *"\"data_mode\":\"postgres\""* \
   || "$SETUP_PRE" != *"\"version\":\"$EXPECTED_PRE_VERSION\""* ]]; then
    echo "FAIL: live Setup pre-version/health is not the expected $EXPECTED_PRE_VERSION"
    exit 8
fi

INITIAL_FINGERPRINT="$(setup_fingerprint)"
[[ -n "$INITIAL_FINGERPRINT" ]] || { echo "FAIL: initial Setup fingerprint is empty"; exit 9; }
INITIAL_2026_COUNT="$(setup_2026_count)"
echo "Initial Setup fingerprint: $INITIAL_FINGERPRINT"
echo "Initial 2026 Setup Session count: $INITIAL_2026_COUNT"
if [[ "$INITIAL_2026_COUNT" != "1" ]]; then
    echo "FAIL: expected exactly one live 2026 Setup Session before #206 deployment"
    exit 10
fi

echo
echo "--- Fetch and verify exact approved target ---"
sudo git -C "$REPO_ROOT" fetch origin "$TARGET_REF:refs/remotes/origin/$TARGET_REF"
sudo git -C "$REPO_ROOT" cat-file -e "$ACCEPTED_CANDIDATE_SHA^{commit}"
sudo git -C "$REPO_ROOT" cat-file -e "$TARGET_SHA^{commit}"

if ! sudo git -C "$REPO_ROOT" merge-base --is-ancestor "$ACCEPTED_CANDIDATE_SHA" "$TARGET_SHA"; then
    echo "FAIL: V0.3.22 target does not contain the exact accepted #206 candidate"
    exit 11
fi
if ! sudo git -C "$REPO_ROOT" merge-base --is-ancestor "$TARGET_SHA" "origin/$TARGET_REF"; then
    echo "FAIL: exact deployment target is not contained in current origin/main"
    exit 12
fi
if ! sudo git -C "$REPO_ROOT" merge-base --is-ancestor "$OLD_HEAD" "$TARGET_SHA"; then
    echo "FAIL: deployment target is not a forward descendant of verified live Setup checkout"
    echo "Live:   $OLD_HEAD"
    echo "Target: $TARGET_SHA"
    exit 13
fi
echo "Target ancestry: PASS"

ACTUAL_MIGRATION_BLOB="$(sudo git -C "$REPO_ROOT" rev-parse "$TARGET_SHA:$MIGRATION_REL")"
if [[ "$ACTUAL_MIGRATION_BLOB" != "$MIGRATION_BLOB" ]]; then
    echo "FAIL: Pick Delay migration Git blob identity mismatch"
    echo "Expected: $MIGRATION_BLOB"
    echo "Actual:   $ACTUAL_MIGRATION_BLOB"
    exit 14
fi
echo "Pick Delay migration Git blob identity: PASS ($ACTUAL_MIGRATION_BLOB)"

echo
echo "--- Detached exact-target regression in Production runtime ---"
sudo git -C "$REPO_ROOT" worktree add --detach "$CANDIDATE_WORKTREE" "$TARGET_SHA"
M063="$CANDIDATE_WORKTREE/$MIGRATION_REL"
[[ -s "$M063" ]] || { echo "FAIL: exact target is missing approved Pick Delay migration"; exit 15; }

grep -Fq 'PRODUCTION_VERSION = "V0.3.22-pick-list-delay"' \
    "$CANDIDATE_WORKTREE/Setup/Application/production_backend.py"
grep -Fq "CLIENT_BUILD = 'V0.3.22-pick-list-delay'" \
    "$CANDIDATE_WORKTREE/Setup/Application/setup_catalog_dirty_guard.js"
grep -Fq 'setup_catalog_dirty_guard.js?v=2026-09-30.1' \
    "$CANDIDATE_WORKTREE/Setup/Application/production.html"

sudo -u fieldwiring -H env PYTHONPYCACHEPREFIX="$DETACHED_PYCACHE" bash -c \
    "cd '$CANDIDATE_WORKTREE' && '$PYTHON' -m pytest -q -p no:cacheprovider Setup/Application"
echo "DETACHED SETUP TARGET REGRESSION: PASS"

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
if [[ "$FROZEN_FINGERPRINT" != "$INITIAL_FINGERPRINT" ]]; then
    echo "FAIL: Setup data changed before write freeze; stop before mutation"
    exit 17
fi
if [[ "$(setup_2026_count)" != "$INITIAL_2026_COUNT" ]]; then
    echo "FAIL: 2026 Setup Session count changed before mutation"
    exit 18
fi
echo "WRITE-FREEZE STABILITY: PASS"

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
echo "--- Production database preflight for exact Pick Delay migration ---"
psql_prod <<'SQL'
DO $preflight$
BEGIN
    IF to_regclass('ops.setup_session') IS NULL
       OR to_regclass('ops.setup_work_day') IS NULL
       OR to_regclass('ops.setup_work_day_task') IS NULL
       OR to_regclass('ops.setup_container_state') IS NULL
       OR to_regclass('ref.container') IS NULL
       OR to_regprocedure('ref.setup_management_actor(text,boolean)') IS NULL THEN
        RAISE EXCEPTION 'Accepted Setup #206 authority foundation is incomplete';
    END IF;

    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname='fieldwiring_app') THEN
        RAISE EXCEPTION 'Required fieldwiring_app role does not exist';
    END IF;

    IF to_regclass('ops.setup_pick_list_delay') IS NOT NULL
       OR to_regprocedure(
            'ops.set_setup_pick_list_delay(text,integer,integer,bigint[],text,boolean)'
          ) IS NOT NULL
       OR to_regprocedure(
            'ops.clear_setup_pick_list_delay_on_schedule()'
          ) IS NOT NULL
       OR EXISTS (
            SELECT 1
            FROM pg_trigger t
            JOIN pg_class c ON c.oid=t.tgrelid
            JOIN pg_namespace n ON n.oid=c.relnamespace
            WHERE n.nspname='ops'
              AND c.relname='setup_work_day_task'
              AND t.tgname='trg_setup_pick_list_delay_schedule_release'
              AND NOT t.tgisinternal
       ) THEN
        RAISE EXCEPTION 'Pick Delay migration appears already or partially installed; reconcile before deployment';
    END IF;

    IF (SELECT count(*) FROM ops.setup_session WHERE season_year=2026) <> 1 THEN
        RAISE EXCEPTION 'Expected exactly one 2026 Setup Session';
    END IF;
END
$preflight$;
SQL
echo "DATABASE PREFLIGHT: PASS"echo "DATABASE PREFLIGHT: PASS"

PRE_MUTATION_FINGERPRINT="$(setup_fingerprint)"
if [[ "$PRE_MUTATION_FINGERPRINT" != "$FROZEN_FINGERPRINT" ]]; then
    echo "FAIL: Setup business data changed during preflight"
    exit 19
fi
echo "PRE-MUTATION FINGERPRINT STABILITY: PASS"

echo
echo "--- Apply reviewed Pick Delay migration ---"
psql_prod < "$M063"
DB_MIGRATION_COMMITTED=1
echo "PICK DELAY MIGRATION: COMMITTED"

echo
echo "--- Validate Pick Delay authority and least privilege ---"
psql_prod <<'SQL'
DO $validate$
BEGIN
    IF to_regclass('ops.setup_pick_list_delay') IS NULL THEN
        RAISE EXCEPTION 'Pick Delay table is missing';
    END IF;
    IF to_regprocedure(
        'ops.set_setup_pick_list_delay(text,integer,integer,bigint[],text,boolean)'
    ) IS NULL THEN
        RAISE EXCEPTION 'Pick Delay command is missing';
    END IF;
    IF to_regprocedure('ops.clear_setup_pick_list_delay_on_schedule()') IS NULL THEN
        RAISE EXCEPTION 'Pick Delay schedule-release function is missing';
    END IF;
    IF NOT EXISTS (
        SELECT 1
        FROM pg_trigger t
        JOIN pg_class c ON c.oid=t.tgrelid
        JOIN pg_namespace n ON n.oid=c.relnamespace
        WHERE n.nspname='ops'
          AND c.relname='setup_work_day_task'
          AND t.tgname='trg_setup_pick_list_delay_schedule_release'
          AND NOT t.tgisinternal
    ) THEN
        RAISE EXCEPTION 'Pick Delay schedule-release trigger is missing';
    END IF;

    IF NOT has_table_privilege(
            'fieldwiring_app',
            'ops.setup_pick_list_delay',
            'SELECT'
       ) OR NOT has_function_privilege(
            'fieldwiring_app',
            'ops.set_setup_pick_list_delay(text,integer,integer,bigint[],text,boolean)',
            'EXECUTE'
       ) THEN
        RAISE EXCEPTION 'Pick Delay read/command privilege is incomplete';
    END IF;

    IF has_table_privilege('fieldwiring_app','ops.setup_pick_list_delay','INSERT')
       OR has_table_privilege('fieldwiring_app','ops.setup_pick_list_delay','UPDATE')
       OR has_table_privilege('fieldwiring_app','ops.setup_pick_list_delay','DELETE') THEN
        RAISE EXCEPTION 'Forbidden broad Pick Delay DML privilege detected';
    END IF;

    IF has_function_privilege(
        'fieldwiring_app',
        'ops.clear_setup_pick_list_delay_on_schedule()',
        'EXECUTE'
    ) THEN
        RAISE EXCEPTION 'Application role must not directly execute the internal schedule-release trigger function';
    END IF;

    IF EXISTS (SELECT 1 FROM ops.setup_pick_list_delay) THEN
        RAISE EXCEPTION 'Pick Delay migration unexpectedly created rows';
    END IF;

    IF (SELECT count(*) FROM ops.setup_session WHERE season_year=2026) <> 1 THEN
        RAISE EXCEPTION 'Pick Delay migration changed the 2026 Setup Session count';
    END IF;
END
$validate$;
SQL
echo "DATABASE CONTRACT VALIDATION: PASS"

POST_DB_FINGERPRINT="$(setup_fingerprint)"
echo "Setup fingerprint before migration: $FROZEN_FINGERPRINT"
echo "Setup fingerprint after migration:  $POST_DB_FINGERPRINT"
if [[ "$POST_DB_FINGERPRINT" != "$FROZEN_FINGERPRINT" ]]; then
    echo "FAIL: Pick Delay migration changed existing governed Setup data"
    exit 20
fi
echo "PASS: Pick Delay migration preserved existing governed Setup data"echo "PASS: migration 060 preserved existing governed Setup data"

echo
echo "--- Advance dedicated Setup Production checkout to exact target ---"
sudo git -C "$SETUP_ROOT" checkout --detach "$TARGET_SHA"
APP_ADVANCED=1
DEPLOYED_HEAD="$(sudo git -C "$SETUP_ROOT" rev-parse HEAD)"
DEPLOYED_STATUS="$(sudo git -C "$SETUP_ROOT" status --porcelain)"
if [[ "$DEPLOYED_HEAD" != "$TARGET_SHA" || -n "$DEPLOYED_STATUS" ]]; then
    echo "FAIL: deployed Setup checkout does not exactly match clean target"
    echo "Expected: $TARGET_SHA"
    echo "Actual:   $DEPLOYED_HEAD"
    exit 21
fi
echo "Setup checkout advanced exactly to $DEPLOYED_HEAD"

echo
echo "--- Restart and verify Setup V0.3.22 runtime ---"
restart_setup
SETUP_POST="$(curl -fsS http://192.168.5.9:8794/api/health)"
echo "Post-deploy Setup health: $SETUP_POST"
if [[ "$SETUP_POST" != *"\"status\":\"ok\""* \
   || "$SETUP_POST" != *"\"data_mode\":\"postgres\""* \
   || "$SETUP_POST" != *"\"version\":\"$EXPECTED_POST_VERSION\""* ]]; then
    echo "FAIL: Setup health/version does not match expected $EXPECTED_POST_VERSION"
    exit 22
fi

ROOT_HTML="$(curl -fsS http://192.168.5.9:8794/)"
if [[ "$ROOT_HTML" != *'setup_catalog_dirty_guard.js?v=2026-09-30.1'* ]]; then
    echo "FAIL: Production root does not expose the V0.3.22 dirty-guard cache pin"
    exit 23
fi

PICK_HTML="$(curl -fsS http://192.168.5.9:8794/pick-list/)"
if [[ "$PICK_HTML" != *'Rolling Pick List'* \
   || "$PICK_HTML" != *'setup_pick_list.js?v=2026-09-29.3'* \
   || "$PICK_HTML" != *'Show delayed picks'* ]]; then
    echo "FAIL: Production Pick List page/assets are not the accepted target"
    exit 24
fi
curl -fsS http://192.168.5.9:8794/pick-list/assets/qrcode.min.js >/dev/null
echo "Production Pick List page/assets: PASS"

DIRTY_GUARD_JS="$(curl -fsS http://192.168.5.9:8794/setup_catalog_dirty_guard.js)"
PICK_JS="$(curl -fsS http://192.168.5.9:8794/pick-list/assets/setup_pick_list.js)"
if [[ "$DIRTY_GUARD_JS" != *"V0.3.22-pick-list-delay"* ]]; then
    echo "FAIL: live client build guard is not V0.3.22-pick-list-delay"
    exit 25
fi
for token in \
    'DELAYED — DO NOT PICK YET' \
    'Show delayed picks' \
    '../api/setup/material-readiness/delays'; do
    if [[ "$PICK_JS" != *"$token"* ]]; then
        echo "FAIL: live Pick List source is missing accepted V0.3.22 token: $token"
        exit 25
    fi
done
echo "V0.3.22 CLIENT/PICK DELAY SOURCE CONTRACT: PASS"

NEGATIVE_CODE="$(curl -sS -o "$NEGATIVE_BODY" -w '%{http_code}' \
    'http://192.168.5.9:8794/api/setup/material-readiness?season_year=2026')"
echo "Direct unauthenticated material-readiness API status: $NEGATIVE_CODE"
if [[ "$NEGATIVE_CODE" != "401" ]]; then
    echo "FAIL: protected material-readiness API did not reject unauthenticated direct request"
    cat "$NEGATIVE_BODY" || true
    exit 25
fi
echo "PROTECTED PICK LIST NEGATIVE PATH: PASS"

MANAGER_EMAIL="$(sudo docker exec "$PROD_CONTAINER" \
    psql -X -qAt -v ON_ERROR_STOP=1 -U "$DB_ACTOR" -d "$PROD_DB" -c "
        SELECT lower(u.email)
        FROM public.directus_users u
        JOIN ref.person p ON p.directus_user_id=u.id
        JOIN LATERAL ref.setup_browser_capabilities(u.email) c ON true
        WHERE u.status='active' AND c.can_manage_setup
        ORDER BY u.email
        LIMIT 1;
    ")"
[[ -n "$MANAGER_EMAIL" ]] || { echo "FAIL: no active Setup Manager identity found"; exit 26; }

READINESS_JSON="$(curl -fsS \
    -H "Cf-Access-Authenticated-User-Email: $MANAGER_EMAIL" \
    'http://192.168.5.9:8794/api/setup/material-readiness?season_year=2026')"
printf '%s' "$READINESS_JSON" | sudo -u fieldwiring -H "$PYTHON" -c '
import json, sys
payload=json.load(sys.stdin)
r=payload.get("readiness") or {}
assert (r.get("session") or {}).get("season_year") == 2026
assert isinstance(r.get("physical_items"), list)
assert "pick_list_overrides" in r
assert isinstance(r.get("pick_list_delays"), list)
assert "pick_delay_count" in (r.get("summary") or {})
'
echo "AUTHENTICATED 2026 PICK LIST/PICK DELAY READ: PASS"

echo
echo "--- Live Setup regression ---"
sudo -u fieldwiring -H env PYTHONPYCACHEPREFIX="$LIVE_PYCACHE" bash -c \
    "cd '$SETUP_ROOT' && '$PYTHON' -m pytest -q -p no:cacheprovider Setup/Application"
echo "LIVE SETUP REGRESSION: PASS"

echo
echo "--- Final Production invariants ---"
FINAL_HEAD="$(sudo git -C "$SETUP_ROOT" rev-parse HEAD)"
FINAL_STATUS="$(sudo git -C "$SETUP_ROOT" status --porcelain)"
FINAL_FINGERPRINT="$(setup_fingerprint)"
FINAL_2026_COUNT="$(setup_2026_count)"
FINAL_DELAY_COUNT="$(delay_count)"
FINAL_HEALTH="$(curl -fsS http://192.168.5.9:8794/api/health)"

echo "Final Setup SHA:                $FINAL_HEAD"
echo "Final Setup fingerprint:        $FINAL_FINGERPRINT"
echo "Final 2026 Setup Session count: $FINAL_2026_COUNT"
echo "Final Pick Delay rows:          $FINAL_DELAY_COUNT"
echo "Final Setup health:             $FINAL_HEALTH"

[[ "$FINAL_HEAD" == "$TARGET_SHA" ]]
[[ -z "$FINAL_STATUS" ]]
[[ "$FINAL_FINGERPRINT" == "$FROZEN_FINGERPRINT" ]]
[[ "$FINAL_2026_COUNT" == "$INITIAL_2026_COUNT" ]]
[[ "$FINAL_DELAY_COUNT" == "0" ]]
[[ "$FINAL_HEALTH" == *"\"version\":\"$EXPECTED_POST_VERSION\""* ]]

SUCCESS=1
echo
echo "SETUP_206_V0322_PICK_LIST_DELAY_PRODUCTION_DEPLOYMENT_PASS"
echo "Rollback archive:  $BACKUP_FILE"
echo "Rollback SHA256:   $BACKUP_SHA"
echo "Deployment report: $REPORT"
