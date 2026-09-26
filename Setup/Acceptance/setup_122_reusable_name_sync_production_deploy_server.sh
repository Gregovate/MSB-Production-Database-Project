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
ACCEPTED_CANDIDATE_SHA="dd4c80fe3180df8f99cb88be451c803d60b5774f"
MERGE_SHA="0462d9318eb97e04c238c5e5b8815ec2f266bfe0"
EXPECTED_LIVE_SETUP_SHA="55e097e7bb3b807793893defc939c9a23fc4ec5d"
EXPECTED_SETUP_VERSION="V0.3.18-scheduling-board"
MIGRATION_REL="Setup/Database/059_sync_reusable_task_name_to_open_annual.sql"
MIGRATION_BLOB="1be0837c88c243fd54763817983be23fa10853bd"

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
BACKUP_DIR="/home/msbadmin/backups/setup-122-name-sync"
REPORT_DIR="/home/msbadmin/setup-deployment-reports"
STAMP="$(date +%Y%m%dT%H%M%S)"
BACKUP_FILE="$BACKUP_DIR/msb-pre-setup-122-name-sync-$STAMP.dump"
REPORT="$REPORT_DIR/Setup_122_Reusable_Name_Sync_Production_Deploy_$STAMP.txt"
CANDIDATE_WORKTREE="/tmp/msb-setup-122-name-sync-candidate-$STAMP"
PYCACHE="/tmp/msb-setup-122-name-sync-pycache-$STAMP"
ROLLBACK_SQL="/tmp/msb-setup-122-name-sync-rollback-$STAMP.sql"

OLD_HEAD=""
CURRENT_SESSION_ID=""
CURRENT_SEASON_YEAR=""
INITIAL_FULL_FINGERPRINT=""
FROZEN_ALLOWED_FINGERPRINT=""
BACKUP_CREATED=0
DB_MIGRATION_COMMITTED=0
SETUP_STOPPED=0
SUCCESS=0

mkdir -p "$REPORT_DIR"
exec > >(tee "$REPORT") 2>&1

echo "========== SETUP #122 REUSABLE NAME SYNC PRODUCTION DEPLOYMENT =========="
echo "Authority: Gregovate/MSB-Server-Management — docs/server/Production_Database_Change_Deployment_Runbook.md"
echo "Accepted candidate:      $ACCEPTED_CANDIDATE_SHA"
echo "Merged main commit:      $MERGE_SHA"
echo "Migration:               $MIGRATION_REL"
echo "Migration Git blob:      $MIGRATION_BLOB"
echo "Expected live Setup SHA: $EXPECTED_LIVE_SETUP_SHA"
echo "Expected Setup version:  $EXPECTED_SETUP_VERSION"
echo "Application source move: NONE"
echo "Report:                  $REPORT"
echo

psql_prod() {
    sudo docker exec -i "$PROD_CONTAINER" \
        psql -X -v ON_ERROR_STOP=1 -U "$DB_ACTOR" -d "$PROD_DB" "$@"
}

psql_prod_qat() {
    sudo docker exec "$PROD_CONTAINER" \
        psql -X -qAt -v ON_ERROR_STOP=1 -U "$DB_ACTOR" -d "$PROD_DB" "$@"
}

current_setup_session_id() {
    psql_prod_qat -c "
        SELECT ss.setup_session_id
        FROM ops.setup_session ss
        WHERE ss.session_status <> 'HISTORICAL_VERIFICATION'
        ORDER BY ss.season_year DESC, ss.setup_session_id DESC
        LIMIT 1;
    "
}

current_setup_season_year() {
    psql_prod_qat -c "
        SELECT ss.season_year
        FROM ops.setup_session ss
        WHERE ss.session_status <> 'HISTORICAL_VERIFICATION'
        ORDER BY ss.season_year DESC, ss.setup_session_id DESC
        LIMIT 1;
    "
}

full_setup_fingerprint() {
    psql_prod_qat -c "
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
                      FROM ops.setup_work_day wd), '') || '|' ||
            coalesce((SELECT string_agg(row_to_json(wdt)::text, '' ORDER BY wdt.setup_work_day_task_id)
                      FROM ops.setup_work_day_task wdt), '') || '|' ||
            coalesce((SELECT string_agg(row_to_json(p)::text, '' ORDER BY p.setup_task_progress_id)
                      FROM ops.setup_task_progress p), '')
        );
    "
}

allowed_change_fingerprint() {
    psql_prod_qat -c "
        WITH current_session AS (
            SELECT ss.setup_session_id
            FROM ops.setup_session ss
            WHERE ss.session_status <> 'HISTORICAL_VERIFICATION'
            ORDER BY ss.season_year DESC, ss.setup_session_id DESC
            LIMIT 1
        )
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
            coalesce((
                SELECT string_agg(
                    CASE
                        WHEN st.setup_session_id = cs.setup_session_id
                            THEN (to_jsonb(st) - 'annual_task_name')::text
                        ELSE to_jsonb(st)::text
                    END,
                    '' ORDER BY st.setup_session_task_id
                )
                FROM ops.setup_session_task st
                CROSS JOIN current_session cs
            ), '') || '|' ||
            coalesce((SELECT string_agg(row_to_json(wd)::text, '' ORDER BY wd.setup_work_day_id)
                      FROM ops.setup_work_day wd), '') || '|' ||
            coalesce((SELECT string_agg(row_to_json(wdt)::text, '' ORDER BY wdt.setup_work_day_task_id)
                      FROM ops.setup_work_day_task wdt), '') || '|' ||
            coalesce((SELECT string_agg(row_to_json(p)::text, '' ORDER BY p.setup_task_progress_id)
                      FROM ops.setup_task_progress p), '')
        );
    "
}

current_name_drift_count() {
    psql_prod_qat -c "
        WITH current_session AS (
            SELECT ss.setup_session_id
            FROM ops.setup_session ss
            WHERE ss.session_status <> 'HISTORICAL_VERIFICATION'
            ORDER BY ss.season_year DESC, ss.setup_session_id DESC
            LIMIT 1
        )
        SELECT count(*)
        FROM ops.setup_session_task st
        JOIN current_session cs
          ON cs.setup_session_id = st.setup_session_id
        JOIN ref.setup_task t
          ON t.setup_task_id = st.setup_task_id
        WHERE st.task_origin = 'REUSABLE'
          AND st.annual_task_name IS DISTINCT FROM t.task_name;
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

capture_narrow_rollback() {
    {
        echo '\set ON_ERROR_STOP on'
        echo 'BEGIN;'
        echo 'DROP TRIGGER IF EXISTS trg_setup_task_sync_open_annual_name ON ref.setup_task;'
        echo 'DROP FUNCTION IF EXISTS ref.sync_setup_task_name_to_open_annual_sessions();'
        psql_prod_qat -c "
            WITH current_session AS (
                SELECT ss.setup_session_id
                FROM ops.setup_session ss
                WHERE ss.session_status <> 'HISTORICAL_VERIFICATION'
                ORDER BY ss.season_year DESC, ss.setup_session_id DESC
                LIMIT 1
            )
            SELECT format(
                'UPDATE ops.setup_session_task SET annual_task_name = %L WHERE setup_session_task_id = %s;',
                st.annual_task_name,
                st.setup_session_task_id
            )
            FROM ops.setup_session_task st
            JOIN current_session cs
              ON cs.setup_session_id = st.setup_session_id
            JOIN ref.setup_task t
              ON t.setup_task_id = st.setup_task_id
            WHERE st.task_origin = 'REUSABLE'
              AND st.annual_task_name IS DISTINCT FROM t.task_name
            ORDER BY st.setup_session_task_id;
        "
        echo 'COMMIT;'
    } > "$ROLLBACK_SQL"
    test -s "$ROLLBACK_SQL"
}

rollback_migration_059() {
    if [[ ! -s "$ROLLBACK_SQL" ]]; then
        echo "Narrow rollback SQL is unavailable"
        return 1
    fi
    echo "Restoring pre-migration annual names and removing migration 059 trigger/function"
    psql_prod < "$ROLLBACK_SQL"
}

cleanup() {
    status=$?
    trap - EXIT HUP INT TERM
    set +e

    if [[ "$status" -ne 0 && "$SUCCESS" -ne 1 ]]; then
        echo
        echo "--- FAIL-CLOSED RECOVERY ---"
        if [[ "$DB_MIGRATION_COMMITTED" -eq 1 ]]; then
            if rollback_migration_059; then
                echo "Migration 059 narrow rollback: PASS"
                DB_MIGRATION_COMMITTED=0
            else
                echo "WARNING: automatic migration 059 rollback failed"
                status=98
            fi
        else
            echo "Migration 059 did not reach committed-success state."
        fi

        if [[ "$SETUP_STOPPED" -eq 1 ]]; then
            echo "Restarting Setup service after recovery"
            restart_setup || { echo "WARNING: Setup service restart failed during recovery"; status=99; }
        fi
    fi

    if sudo git -C "$REPO_ROOT" worktree list --porcelain 2>/dev/null | grep -Fq "worktree $CANDIDATE_WORKTREE"; then
        sudo git -C "$REPO_ROOT" worktree remove --force "$CANDIDATE_WORKTREE" >/dev/null 2>&1 || true
    fi
    sudo git -C "$REPO_ROOT" worktree prune >/dev/null 2>&1 || true
    sudo rm -rf "$PYCACHE" >/dev/null 2>&1 || true
    rm -f "$ROLLBACK_SQL" >/dev/null 2>&1 || true
    rm -rf "$SCRIPT_DIR" >/dev/null 2>&1 || true

    echo
    echo "--- Production after-check ---"
    FINAL_HEAD="$(sudo git -C "$SETUP_ROOT" rev-parse HEAD 2>/dev/null || true)"
    echo "Live Setup SHA before: $OLD_HEAD"
    echo "Live Setup SHA after:  $FINAL_HEAD"
    if [[ -n "$OLD_HEAD" && "$FINAL_HEAD" != "$OLD_HEAD" ]]; then
        echo "FAIL: migration-only deployment changed the live Setup checkout"
        status=97
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
if [[ -n "$(sudo git -C "$REPO_ROOT" status --porcelain)" ]]; then
    echo "FAIL: shared repository checkout has uncommitted changes"
    exit 4
fi
if [[ -n "$(sudo git -C "$SETUP_ROOT" status --porcelain)" ]]; then
    echo "FAIL: live Setup checkout has uncommitted changes"
    exit 5
fi
if ! systemctl is-active --quiet "$SETUP_SERVICE"; then
    echo "FAIL: msb-setup.service is not active before deployment"
    exit 6
fi

OLD_HEAD="$(sudo git -C "$SETUP_ROOT" rev-parse HEAD)"
echo "Verified live Setup checkout: $OLD_HEAD"
if [[ "$OLD_HEAD" != "$EXPECTED_LIVE_SETUP_SHA" ]]; then
    echo "FAIL: live Setup SHA differs from current accepted runtime authority"
    echo "Expected: $EXPECTED_LIVE_SETUP_SHA"
    echo "Actual:   $OLD_HEAD"
    exit 7
fi

SETUP_PRE="$(curl -fsS http://192.168.5.9:8794/api/health)"
echo "Pre-deploy Setup health: $SETUP_PRE"
if [[ "$SETUP_PRE" != *"\"status\":\"ok\""* \
   || "$SETUP_PRE" != *"\"data_mode\":\"postgres\""* \
   || "$SETUP_PRE" != *"\"version\":\"$EXPECTED_SETUP_VERSION\""* ]]; then
    echo "FAIL: current Setup runtime health/version is not the accepted baseline"
    exit 8
fi

CURRENT_SESSION_ID="$(current_setup_session_id)"
CURRENT_SEASON_YEAR="$(current_setup_season_year)"
echo "Current non-historical Setup Session ID: $CURRENT_SESSION_ID"
echo "Current non-historical season year:      $CURRENT_SEASON_YEAR"
if [[ ! "$CURRENT_SESSION_ID" =~ ^[0-9]+$ || "$CURRENT_SEASON_YEAR" != "2026" ]]; then
    echo "FAIL: expected 2026 to be the current Setup Session before this repair"
    exit 9
fi

if [[ -n "$(psql_prod_qat -c "SELECT 1 FROM ops.setup_session WHERE season_year > 2026 AND session_status <> 'HISTORICAL_VERIFICATION' LIMIT 1;")" ]]; then
    echo "FAIL: a later non-historical Setup Session already exists; do not apply the 2026 repair runner"
    exit 10
fi

INITIAL_FULL_FINGERPRINT="$(full_setup_fingerprint)"
[[ -n "$INITIAL_FULL_FINGERPRINT" ]] || { echo "FAIL: initial Setup fingerprint is empty"; exit 11; }
echo "Initial full Setup fingerprint: $INITIAL_FULL_FINGERPRINT"

echo
echo "--- Fetch and verify accepted migration identity ---"
sudo git -C "$REPO_ROOT" fetch origin "$TARGET_REF:refs/remotes/origin/$TARGET_REF"
sudo git -C "$REPO_ROOT" cat-file -e "$ACCEPTED_CANDIDATE_SHA^{commit}"
sudo git -C "$REPO_ROOT" cat-file -e "$MERGE_SHA^{commit}"

if ! sudo git -C "$REPO_ROOT" merge-base --is-ancestor "$ACCEPTED_CANDIDATE_SHA" "origin/$TARGET_REF"; then
    echo "FAIL: accepted candidate is not contained in origin/main"
    exit 12
fi
if ! sudo git -C "$REPO_ROOT" merge-base --is-ancestor "$MERGE_SHA" "origin/$TARGET_REF"; then
    echo "FAIL: PR #247 merge commit is not contained in origin/main"
    exit 13
fi

ACTUAL_MIGRATION_BLOB="$(sudo git -C "$REPO_ROOT" rev-parse "$ACCEPTED_CANDIDATE_SHA:$MIGRATION_REL")"
if [[ "$ACTUAL_MIGRATION_BLOB" != "$MIGRATION_BLOB" ]]; then
    echo "FAIL: migration 059 Git blob identity mismatch"
    echo "Expected: $MIGRATION_BLOB"
    echo "Actual:   $ACTUAL_MIGRATION_BLOB"
    exit 14
fi
echo "Migration 059 Git blob identity: PASS ($ACTUAL_MIGRATION_BLOB)"

echo
echo "--- Detached exact-candidate regression in Production runtime ---"
sudo git -C "$REPO_ROOT" worktree add --detach "$CANDIDATE_WORKTREE" "$ACCEPTED_CANDIDATE_SHA"
M059="$CANDIDATE_WORKTREE/$MIGRATION_REL"
[[ -s "$M059" ]] || { echo "FAIL: accepted candidate is missing migration 059"; exit 15; }

sudo -u fieldwiring -H env PYTHONPYCACHEPREFIX="$PYCACHE" bash -c \
    "cd '$CANDIDATE_WORKTREE' && '$PYTHON' -m pytest -q -p no:cacheprovider Setup/Application"
echo "DETACHED ACCEPTED-CANDIDATE SETUP REGRESSION: PASS"

echo
echo "--- Freeze Setup writes for bounded migration ---"
sudo systemctl stop "$SETUP_SERVICE"
SETUP_STOPPED=1
if systemctl is-active --quiet "$SETUP_SERVICE"; then
    echo "FAIL: Setup service did not stop"
    exit 16
fi
echo "msb-setup.service stopped: PASS"

FROZEN_ALLOWED_FINGERPRINT="$(allowed_change_fingerprint)"
[[ -n "$FROZEN_ALLOWED_FINGERPRINT" ]] || { echo "FAIL: frozen allowed-change fingerprint is empty"; exit 17; }
echo "Frozen allowed-change fingerprint: $FROZEN_ALLOWED_FINGERPRINT"

PRE_DRIFT="$(current_name_drift_count)"
echo "Current annual reusable name mismatches before migration: $PRE_DRIFT"

echo "--- Current Task 74 / 376 names before migration ---"
psql_prod -P pager=off -c "
    SELECT
        t.setup_task_id,
        t.task_name AS reusable_name,
        st.annual_task_name AS current_annual_name
    FROM ref.setup_task t
    LEFT JOIN ops.setup_session_task st
      ON st.setup_task_id = t.setup_task_id
     AND st.setup_session_id = $CURRENT_SESSION_ID
    WHERE t.setup_task_id IN (74,376)
    ORDER BY t.setup_task_id;
"

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
echo "--- Production database preflight for migration 059 ---"
psql_prod <<'SQL'
DO $preflight$
BEGIN
    IF to_regclass('ref.setup_task') IS NULL
       OR to_regclass('ops.setup_session') IS NULL
       OR to_regclass('ops.setup_session_task') IS NULL
       OR to_regprocedure('ref.update_setup_task(text,bigint,text,integer,text,integer,boolean,integer,integer,integer,text,text,text,text)') IS NULL THEN
        RAISE EXCEPTION 'Setup #122 reusable-name synchronization prerequisites are incomplete';
    END IF;

    IF to_regprocedure('ref.sync_setup_task_name_to_open_annual_sessions()') IS NOT NULL THEN
        RAISE EXCEPTION 'Migration 059 trigger function already exists; reconcile prior/partial deployment first';
    END IF;

    IF EXISTS (
        SELECT 1
        FROM pg_trigger
        WHERE tgrelid = 'ref.setup_task'::regclass
          AND tgname = 'trg_setup_task_sync_open_annual_name'
          AND NOT tgisinternal
    ) THEN
        RAISE EXCEPTION 'Migration 059 trigger already exists; reconcile prior/partial deployment first';
    END IF;
END
$preflight$;
SQL
echo "DATABASE PREFLIGHT: PASS"

capture_narrow_rollback
echo "NARROW ROLLBACK CAPTURE: PASS"

PRE_MIGRATION_ALLOWED="$(allowed_change_fingerprint)"
if [[ "$PRE_MIGRATION_ALLOWED" != "$FROZEN_ALLOWED_FINGERPRINT" ]]; then
    echo "FAIL: governed Setup data changed after freeze and before migration"
    exit 18
fi

echo
echo "--- Apply reviewed migration 059 ---"
psql_prod < "$M059"
DB_MIGRATION_COMMITTED=1
echo "MIGRATION 059: COMMITTED"

echo
echo "--- Validate migration 059 contract ---"
psql_prod <<'SQL'
DO $validate$
BEGIN
    IF to_regprocedure('ref.sync_setup_task_name_to_open_annual_sessions()') IS NULL THEN
        RAISE EXCEPTION 'Migration 059 trigger function is missing';
    END IF;

    IF NOT EXISTS (
        SELECT 1
        FROM pg_trigger
        WHERE tgrelid = 'ref.setup_task'::regclass
          AND tgname = 'trg_setup_task_sync_open_annual_name'
          AND NOT tgisinternal
    ) THEN
        RAISE EXCEPTION 'Migration 059 trigger is missing';
    END IF;

    IF has_function_privilege(
        'fieldwiring_app',
        'ref.sync_setup_task_name_to_open_annual_sessions()',
        'EXECUTE'
    ) THEN
        RAISE EXCEPTION 'fieldwiring_app unexpectedly has direct EXECUTE on internal name-sync trigger function';
    END IF;
END
$validate$;
SQL

POST_DRIFT="$(current_name_drift_count)"
echo "Current annual reusable name mismatches after migration: $POST_DRIFT"
if [[ "$POST_DRIFT" != "0" ]]; then
    echo "FAIL: current annual reusable names are still out of sync"
    exit 19
fi

POST_ALLOWED="$(allowed_change_fingerprint)"
echo "Frozen allowed-change fingerprint: $FROZEN_ALLOWED_FINGERPRINT"
echo "Post-migration allowed fingerprint: $POST_ALLOWED"
if [[ "$POST_ALLOWED" != "$FROZEN_ALLOWED_FINGERPRINT" ]]; then
    echo "FAIL: migration 059 changed governed Setup data outside current-session annual_task_name"
    exit 20
fi
echo "PASS: only current-session annual_task_name changes were permitted"

TASK74="$(psql_prod_qat -c "
    SELECT t.task_name || '|' || st.annual_task_name
    FROM ref.setup_task t
    JOIN ops.setup_session_task st
      ON st.setup_task_id = t.setup_task_id
     AND st.setup_session_id = $CURRENT_SESSION_ID
    WHERE t.setup_task_id = 74;
")"
TASK376="$(psql_prod_qat -c "
    SELECT t.task_name || '|' || st.annual_task_name
    FROM ref.setup_task t
    JOIN ops.setup_session_task st
      ON st.setup_task_id = t.setup_task_id
     AND st.setup_session_id = $CURRENT_SESSION_ID
    WHERE t.setup_task_id = 376;
")"
echo "Task 74 reusable|annual:  $TASK74"
echo "Task 376 reusable|annual: $TASK376"
if [[ "$TASK74" != "Move Volunteer Trailer|Move Volunteer Trailer" ]]; then
    echo "FAIL: Task 74 current annual name is not synchronized"
    exit 21
fi
if [[ "$TASK376" != "Move Volunteer Steps|Move Volunteer Steps" ]]; then
    echo "FAIL: Task 376 current annual name is not synchronized"
    exit 22
fi
echo "TASK 74 / 376 NAME SYNCHRONIZATION: PASS"

echo
echo "--- Restart unchanged Setup application and verify runtime ---"
restart_setup

SETUP_POST="$(curl -fsS http://192.168.5.9:8794/api/health)"
echo "Post-migration Setup health: $SETUP_POST"
if [[ "$SETUP_POST" != *"\"status\":\"ok\""* \
   || "$SETUP_POST" != *"\"data_mode\":\"postgres\""* \
   || "$SETUP_POST" != *"\"version\":\"$EXPECTED_SETUP_VERSION\""* ]]; then
    echo "FAIL: Setup runtime did not return healthy at the unchanged accepted version"
    exit 23
fi

FINAL_HEAD="$(sudo git -C "$SETUP_ROOT" rev-parse HEAD)"
FINAL_STATUS="$(sudo git -C "$SETUP_ROOT" status --porcelain)"
FINAL_ALLOWED="$(allowed_change_fingerprint)"
FINAL_DRIFT="$(current_name_drift_count)"

echo
echo "--- Final Production invariants ---"
echo "Final live Setup SHA:       $FINAL_HEAD"
echo "Final name mismatch count:  $FINAL_DRIFT"
echo "Final allowed fingerprint:  $FINAL_ALLOWED"

[[ "$FINAL_HEAD" == "$OLD_HEAD" ]]
[[ -z "$FINAL_STATUS" ]]
[[ "$FINAL_ALLOWED" == "$FROZEN_ALLOWED_FINGERPRINT" ]]
[[ "$FINAL_DRIFT" == "0" ]]
systemctl is-active --quiet "$SETUP_SERVICE"

SUCCESS=1
echo
echo "SETUP_122_REUSABLE_NAME_SYNC_PRODUCTION_DEPLOYMENT_PASS"
echo "Accepted candidate SHA: $ACCEPTED_CANDIDATE_SHA"
echo "Merged main commit:      $MERGE_SHA"
echo "Migration blob:          $MIGRATION_BLOB"
echo "Rollback archive:        $BACKUP_FILE"
echo "Rollback SHA256:         $BACKUP_SHA"
echo "Deployment report:       $REPORT"
