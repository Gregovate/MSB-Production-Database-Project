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
ACCEPTED_BROWSER_SHA="59148515ab361a297cd7107184662648cd10a60d"
TARGET_SHA="a084b0130eae4547f26f3aaddf181b644eccd0b9"
EXPECTED_PRE_VERSION="V0.3.18-scheduling-board"
EXPECTED_POST_VERSION="V0.3.19-pick-list"
MIGRATION_REL="Setup/Database/060_add_setup_pick_list_manager_override.sql"
MIGRATION_BLOB="72137b49d78da26647e539769973641b24ee1c57"

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
BACKUP_DIR="/home/msbadmin/backups/setup-206"
REPORT_DIR="/home/msbadmin/setup-deployment-reports"
STAMP="$(date +%Y%m%dT%H%M%S)"
BACKUP_FILE="$BACKUP_DIR/msb-pre-setup-206-pick-list-$STAMP.dump"
REPORT="$REPORT_DIR/Setup_206_Pick_List_Production_Deploy_$STAMP.txt"
CANDIDATE_WORKTREE="/tmp/msb-setup-206-pick-list-candidate-$STAMP"
DETACHED_PYCACHE="/tmp/msb-setup-206-detached-pycache-$STAMP"
LIVE_PYCACHE="/tmp/msb-setup-206-live-pycache-$STAMP"
NEGATIVE_BODY="/tmp/msb-setup-206-negative-$STAMP.txt"

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

echo "========== SETUP #206 PICK LIST PRODUCTION DEPLOYMENT =========="
echo "Authority: Gregovate/MSB-Server-Management — docs/server/Production_Database_Change_Deployment_Runbook.md"
echo "Operator-accepted browser SHA: $ACCEPTED_BROWSER_SHA"
echo "Deployment target SHA:         $TARGET_SHA"
echo "Expected pre-version:          $EXPECTED_PRE_VERSION"
echo "Expected post-version:         $EXPECTED_POST_VERSION"
echo "Migration:                     $MIGRATION_REL"
echo "Migration Git blob:            $MIGRATION_BLOB"
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

override_count() {
    sudo docker exec "$PROD_CONTAINER" \
        psql -X -qAt -v ON_ERROR_STOP=1 -U "$DB_ACTOR" -d "$PROD_DB" -c "
            SELECT CASE
                WHEN to_regclass('ops.setup_pick_list_override') IS NULL THEN -1
                ELSE (SELECT count(*) FROM ops.setup_pick_list_override)
            END;
        "
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

rollback_migration_060() {
    local rows
    rows="$(override_count 2>/dev/null || true)"
    if [[ "$rows" != "0" ]]; then
        echo "REFUSE automatic migration 060 rollback: override row count is '${rows:-unknown}', expected 0"
        return 1
    fi
    psql_prod <<'SQL'
BEGIN;
DROP FUNCTION IF EXISTS ops.set_setup_pick_list_override(
    text,integer,integer,date,date,integer,text,boolean
);
DROP TABLE IF EXISTS ops.setup_pick_list_override;
COMMIT;
SQL
    MIGRATION_ROLLED_BACK=1
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
            echo "Attempting bounded rollback of migration 060"
            if rollback_migration_060; then
                DB_MIGRATION_COMMITTED=0
                echo "Migration 060 rollback: PASS"
            else
                echo "WARNING: migration 060 was not automatically removed; review retained backup/report before further mutation"
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
sudo git -C "$REPO_ROOT" cat-file -e "$ACCEPTED_BROWSER_SHA^{commit}"
sudo git -C "$REPO_ROOT" cat-file -e "$TARGET_SHA^{commit}"

if ! sudo git -C "$REPO_ROOT" merge-base --is-ancestor "$ACCEPTED_BROWSER_SHA" "$TARGET_SHA"; then
    echo "FAIL: V0.3.19 target does not contain the operator-accepted #206 browser candidate"
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
    echo "FAIL: migration 060 Git blob identity mismatch"
    echo "Expected: $MIGRATION_BLOB"
    echo "Actual:   $ACTUAL_MIGRATION_BLOB"
    exit 14
fi
echo "Migration 060 Git blob identity: PASS ($ACTUAL_MIGRATION_BLOB)"

echo
echo "--- Detached exact-target regression in Production runtime ---"
sudo git -C "$REPO_ROOT" worktree add --detach "$CANDIDATE_WORKTREE" "$TARGET_SHA"
M060="$CANDIDATE_WORKTREE/$MIGRATION_REL"
[[ -s "$M060" ]] || { echo "FAIL: exact target is missing migration 060"; exit 15; }

grep -Fq 'PRODUCTION_VERSION = "V0.3.19-pick-list"' \
    "$CANDIDATE_WORKTREE/Setup/Application/production_backend.py"
grep -Fq "CLIENT_BUILD = 'V0.3.19-pick-list'" \
    "$CANDIDATE_WORKTREE/Setup/Application/setup_catalog_dirty_guard.js"
grep -Fq 'setup_catalog_dirty_guard.js?v=2026-09-26.1' \
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
echo "--- Production database preflight for migration 060 ---"
psql_prod <<'SQL'
DO $preflight$
BEGIN
    IF to_regclass('ops.setup_session') IS NULL
       OR to_regclass('ops.setup_container_state') IS NULL
       OR to_regclass('ref.container') IS NULL
       OR to_regclass('ref.stage') IS NULL
       OR to_regprocedure('ref.setup_management_actor(text,boolean)') IS NULL THEN
        RAISE EXCEPTION 'Accepted Setup #206 authority foundation is incomplete';
    END IF;

    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname='fieldwiring_app') THEN
        RAISE EXCEPTION 'Required fieldwiring_app role does not exist';
    END IF;

    IF to_regclass('ops.setup_pick_list_override') IS NOT NULL
       OR to_regprocedure(
            'ops.set_setup_pick_list_override(text,integer,integer,date,date,integer,text,boolean)'
          ) IS NOT NULL THEN
        RAISE EXCEPTION 'Migration 060 appears already or partially installed; reconcile before deployment';
    END IF;

    IF (SELECT count(*) FROM ops.setup_session WHERE season_year=2026) <> 1 THEN
        RAISE EXCEPTION 'Expected exactly one live 2026 Setup Session';
    END IF;
END
$preflight$;
SQL
echo "DATABASE PREFLIGHT: PASS"

PRE_MUTATION_FINGERPRINT="$(setup_fingerprint)"
if [[ "$PRE_MUTATION_FINGERPRINT" != "$FROZEN_FINGERPRINT" ]]; then
    echo "FAIL: Setup business data changed during preflight"
    exit 19
fi
echo "PRE-MUTATION FINGERPRINT STABILITY: PASS"

echo
echo "--- Apply reviewed migration 060 ---"
psql_prod < "$M060"
DB_MIGRATION_COMMITTED=1
echo "MIGRATION 060: COMMITTED"

echo
echo "--- Validate migration 060 authority and least privilege ---"
psql_prod <<'SQL'
DO $validate$
BEGIN
    IF to_regclass('ops.setup_pick_list_override') IS NULL THEN
        RAISE EXCEPTION 'Pick List override table is missing';
    END IF;
    IF to_regprocedure(
        'ops.set_setup_pick_list_override(text,integer,integer,date,date,integer,text,boolean)'
    ) IS NULL THEN
        RAISE EXCEPTION 'Pick List override command is missing';
    END IF;

    IF NOT EXISTS (
        SELECT 1
        FROM information_schema.columns
        WHERE table_schema='ops'
          AND table_name='setup_pick_list_override'
          AND column_name='destination_stage_id'
          AND is_nullable='NO'
    ) THEN
        RAISE EXCEPTION 'Governed destination_stage_id column is missing/not required';
    END IF;

    IF NOT has_table_privilege(
            'fieldwiring_app',
            'ops.setup_pick_list_override',
            'SELECT'
       ) OR NOT has_function_privilege(
            'fieldwiring_app',
            'ops.set_setup_pick_list_override(text,integer,integer,date,date,integer,text,boolean)',
            'EXECUTE'
       ) THEN
        RAISE EXCEPTION 'Pick List override read/command privilege is incomplete';
    END IF;

    IF has_table_privilege('fieldwiring_app','ops.setup_pick_list_override','INSERT')
       OR has_table_privilege('fieldwiring_app','ops.setup_pick_list_override','UPDATE')
       OR has_table_privilege('fieldwiring_app','ops.setup_pick_list_override','DELETE') THEN
        RAISE EXCEPTION 'Forbidden broad Pick List override DML privilege detected';
    END IF;

    IF EXISTS (SELECT 1 FROM ops.setup_pick_list_override) THEN
        RAISE EXCEPTION 'Migration 060 unexpectedly created Pick List override rows';
    END IF;

    IF (SELECT count(*) FROM ops.setup_session WHERE season_year=2026) <> 1 THEN
        RAISE EXCEPTION 'Migration 060 changed the live 2026 Setup Session count';
    END IF;
END
$validate$;
SQL
echo "DATABASE CONTRACT VALIDATION: PASS"

POST_DB_FINGERPRINT="$(setup_fingerprint)"
echo "Setup fingerprint before migration: $FROZEN_FINGERPRINT"
echo "Setup fingerprint after migration:  $POST_DB_FINGERPRINT"
if [[ "$POST_DB_FINGERPRINT" != "$FROZEN_FINGERPRINT" ]]; then
    echo "FAIL: migration 060 changed existing governed Setup data"
    exit 20
fi
echo "PASS: migration 060 preserved existing governed Setup data"

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
echo "--- Restart and verify Setup V0.3.19 runtime ---"
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
if [[ "$ROOT_HTML" != *'setup_catalog_dirty_guard.js?v=2026-09-26.1'* ]]; then
    echo "FAIL: Production root does not expose the V0.3.19 dirty-guard cache pin"
    exit 23
fi

PICK_HTML="$(curl -fsS http://192.168.5.9:8794/pick-list/)"
if [[ "$PICK_HTML" != *'Rolling Pick List'* \
   || "$PICK_HTML" != *'setup_pick_list.js?v=2026-09-26.5'* ]]; then
    echo "FAIL: Production Pick List page/assets are not the accepted target"
    exit 24
fi
curl -fsS http://192.168.5.9:8794/pick-list/assets/qrcode.min.js >/dev/null
echo "Production Pick List page/assets: PASS"

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
'
echo "AUTHENTICATED 2026 PICK LIST READ: PASS"

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
FINAL_OVERRIDE_COUNT="$(override_count)"
FINAL_HEALTH="$(curl -fsS http://192.168.5.9:8794/api/health)"

echo "Final Setup SHA:                $FINAL_HEAD"
echo "Final Setup fingerprint:        $FINAL_FINGERPRINT"
echo "Final 2026 Setup Session count: $FINAL_2026_COUNT"
echo "Final Pick List override rows:  $FINAL_OVERRIDE_COUNT"
echo "Final Setup health:             $FINAL_HEALTH"

[[ "$FINAL_HEAD" == "$TARGET_SHA" ]]
[[ -z "$FINAL_STATUS" ]]
[[ "$FINAL_FINGERPRINT" == "$FROZEN_FINGERPRINT" ]]
[[ "$FINAL_2026_COUNT" == "$INITIAL_2026_COUNT" ]]
[[ "$FINAL_OVERRIDE_COUNT" == "0" ]]
[[ "$FINAL_HEALTH" == *"\"version\":\"$EXPECTED_POST_VERSION\""* ]]

SUCCESS=1
echo
echo "SETUP_206_PICK_LIST_PRODUCTION_DEPLOYMENT_PASS"
echo "Rollback archive:  $BACKUP_FILE"
echo "Rollback SHA256:   $BACKUP_SHA"
echo "Deployment report: $REPORT"
