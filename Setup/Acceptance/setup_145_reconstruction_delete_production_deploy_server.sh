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
ACCEPTED_CANDIDATE_SHA="4ff33a16a4a22e77972ac832edb678ed467df2a0"
MIGRATION_REL="Setup/Database/055_fix_setup_reconstruction_delete_annual_dependencies.sql"
MIGRATION_BLOB="9126d5e9e9732fa0d3941e505d9bf7176119b3df"
EXPECTED_SETUP_VERSION="V0.3.16-stale-ownership-cleanup"

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
BACKUP_DIR="/home/msbadmin/backups/setup-145"
REPORT_DIR="/home/msbadmin/setup-deployment-reports"
STAMP="$(date +%Y%m%dT%H%M%S)"
BACKUP_FILE="$BACKUP_DIR/msb-pre-setup-145-reconstruction-delete-$STAMP.dump"
REPORT="$REPORT_DIR/Setup_145_Reconstruction_Delete_Production_Deploy_$STAMP.txt"
CANDIDATE_WORKTREE="/tmp/msb-setup-145-delete-candidate-$STAMP"
FUNCTION_ROLLBACK_SQL="/tmp/msb-setup-145-delete-function-rollback-$STAMP.sql"
DETACHED_PYCACHE="/tmp/msb-setup-145-delete-pycache-$STAMP"
LIVE_PYCACHE="/tmp/msb-setup-145-delete-live-pycache-$STAMP"

OLD_SETUP_HEAD=""
INITIAL_FINGERPRINT=""
FROZEN_FINGERPRINT=""
BACKUP_CREATED=0
DB_MIGRATION_COMMITTED=0
SETUP_STOPPED=0
SUCCESS=0

mkdir -p "$REPORT_DIR"
exec > >(tee "$REPORT") 2>&1

echo "========== SETUP #145 RECONSTRUCTION DELETE PRODUCTION DEPLOYMENT =========="
echo "Authority: Gregovate/MSB-Server-Management — docs/server/Production_Database_Change_Deployment_Runbook.md"
echo "Accepted candidate SHA: $ACCEPTED_CANDIDATE_SHA"
echo "Migration:              $MIGRATION_REL"
echo "Migration Git blob:     $MIGRATION_BLOB"
echo "Expected live version:  $EXPECTED_SETUP_VERSION"
echo "Report:                 $REPORT"
echo

psql_prod() {
    sudo docker exec -i "$PROD_CONTAINER"         psql -X -v ON_ERROR_STOP=1 -U "$DB_ACTOR" -d "$PROD_DB" "$@"
}

setup_2026_count() {
    sudo docker exec "$PROD_CONTAINER"         psql -X -qAt -v ON_ERROR_STOP=1 -U "$DB_ACTOR" -d "$PROD_DB"         -c "SELECT count(*) FROM ops.setup_session WHERE season_year=2026;"
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
                coalesce((SELECT string_agg(row_to_json(c)::text, '' ORDER BY c.setup_task_id, c.person_id)
                          FROM ref.setup_task_captain c), '') || '|' ||
                coalesce((SELECT string_agg(row_to_json(tr)::text, '' ORDER BY tr.setup_task_id, tr.setup_resource_id)
                          FROM ref.setup_task_resource tr), '') || '|' ||
                coalesce((SELECT string_agg(row_to_json(tm)::text, '' ORDER BY tm.setup_task_extra_material_id)
                          FROM ref.setup_task_extra_material tm), '') || '|' ||
                coalesce((SELECT string_agg(row_to_json(src)::text, '' ORDER BY src.setup_task_extra_material_source_id)
                          FROM ref.setup_task_extra_material_source src), '') || '|' ||
                coalesce((SELECT string_agg(row_to_json(s)::text, '' ORDER BY s.setup_session_id)
                          FROM ops.setup_session s), '') || '|' ||
                coalesce((SELECT string_agg(row_to_json(st)::text, '' ORDER BY st.setup_session_task_id)
                          FROM ops.setup_session_task st), '') || '|' ||
                coalesce((SELECT string_agg(row_to_json(dep)::text, '' ORDER BY dep.setup_session_task_id, dep.prerequisite_setup_session_task_id)
                          FROM ops.setup_session_task_dependency dep), '') || '|' ||
                coalesce((SELECT string_agg(row_to_json(wd)::text, '' ORDER BY wd.setup_work_day_id)
                          FROM ops.setup_work_day wd), '') || '|' ||
                coalesce((SELECT string_agg(row_to_json(wdt)::text, '' ORDER BY wdt.setup_work_day_task_id)
                          FROM ops.setup_work_day_task wdt), '') || '|' ||
                coalesce((SELECT string_agg(row_to_json(p)::text, '' ORDER BY p.setup_task_progress_id)
                          FROM ops.setup_task_progress p), '') || '|' ||
                coalesce((SELECT string_agg(row_to_json(me)::text, '' ORDER BY me.setup_movement_event_id)
                          FROM ops.setup_movement_event me), '')
            );
        "
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

restore_prior_delete_function() {
    if [[ ! -s "$FUNCTION_ROLLBACK_SQL" ]]; then
        echo "FAIL: prior delete function definition was not captured"
        return 1
    fi
    echo "Restoring pre-055 delete function definition"
    psql_prod < "$FUNCTION_ROLLBACK_SQL"
}

cleanup() {
    status=$?
    trap - EXIT HUP INT TERM
    set +e

    if [[ "$status" -ne 0 && "$SUCCESS" -ne 1 ]]; then
        echo
        echo "--- FAIL-CLOSED RECOVERY ---"
        if [[ "$DB_MIGRATION_COMMITTED" -eq 1 ]]; then
            restore_prior_delete_function || true
            DB_MIGRATION_COMMITTED=0
        fi
        if [[ "$SETUP_STOPPED" -eq 1 ]]; then
            echo "Restarting Setup after recovery"
            restart_setup || true
        fi
    fi

    if sudo git -C "$REPO_ROOT" worktree list --porcelain 2>/dev/null | grep -Fq "worktree $CANDIDATE_WORKTREE"; then
        sudo git -C "$REPO_ROOT" worktree remove --force "$CANDIDATE_WORKTREE" >/dev/null 2>&1 || true
    fi
    sudo git -C "$REPO_ROOT" worktree prune >/dev/null 2>&1 || true
    sudo rm -rf "$DETACHED_PYCACHE" "$LIVE_PYCACHE" >/dev/null 2>&1 || true
    rm -f "$FUNCTION_ROLLBACK_SQL" >/dev/null 2>&1 || true
    rm -rf "$SCRIPT_DIR" >/dev/null 2>&1 || true

    echo
    echo "--- Production after-check ---"
    FINAL_SETUP_HEAD="$(sudo git -C "$SETUP_ROOT" rev-parse HEAD 2>/dev/null || true)"
    echo "Initial live Setup SHA: $OLD_SETUP_HEAD"
    echo "Final live Setup SHA:   $FINAL_SETUP_HEAD"
    if [[ -n "$OLD_SETUP_HEAD" && "$FINAL_SETUP_HEAD" != "$OLD_SETUP_HEAD" ]]; then
        echo "FAIL: DB-only deployment moved the live Setup checkout"
        status=95
    fi

    if [[ -n "$FROZEN_FINGERPRINT" ]]; then
        AFTER_FINGERPRINT="$(setup_fingerprint 2>/dev/null || true)"
        echo "Frozen Setup fingerprint: $FROZEN_FINGERPRINT"
        echo "Final Setup fingerprint:  $AFTER_FINGERPRINT"
        if [[ -z "$AFTER_FINGERPRINT" || "$AFTER_FINGERPRINT" != "$FROZEN_FINGERPRINT" ]]; then
            echo "FAIL: governed Setup data changed during DB-only deployment"
            status=97
        else
            echo "PASS: governed Setup data unchanged"
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
    exit 5
fi

OLD_SETUP_HEAD="$(sudo git -C "$SETUP_ROOT" rev-parse HEAD)"
echo "Verified live Setup checkout: $OLD_SETUP_HEAD"
if [[ -n "$(sudo git -C "$SETUP_ROOT" status --porcelain)" ]]; then
    echo "FAIL: live Setup checkout has uncommitted changes"
    exit 6
fi

for service in "$SETUP_SERVICE" "$DISPLAY_SERVICE" "$GOOGLE_SERVICE" "$FIELDWIRING_SERVICE" "$PROCEDURES_SERVICE"; do
    if ! systemctl is-active --quiet "$service"; then
        echo "FAIL: required Production service is not active before deployment: $service"
        exit 7
    fi
done

SETUP_PRE="$(curl -fsS http://192.168.5.9:8794/api/health)"
echo "Pre-deploy Setup health: $SETUP_PRE"
if [[ "$SETUP_PRE" != *"\"status\":\"ok\""* || "$SETUP_PRE" != *"\"version\":\"$EXPECTED_SETUP_VERSION\""* ]]; then
    echo "FAIL: current Setup health/version is not the accepted live runtime"
    exit 8
fi

INITIAL_FINGERPRINT="$(setup_fingerprint)"
[[ -n "$INITIAL_FINGERPRINT" ]] || { echo "FAIL: initial Setup fingerprint is empty"; exit 9; }
echo "Initial Setup fingerprint: $INITIAL_FINGERPRINT"

if [[ "$(setup_2026_count)" != "0" ]]; then
    echo "FAIL: real 2026 Setup Session exists before #145 delete repair deployment"
    exit 10
fi
echo "2026 Setup Session preflight: PASS (0 rows)"

echo
echo "--- Fetch merged main and prove accepted candidate identity ---"
sudo git -C "$REPO_ROOT" fetch origin "$TARGET_REF:refs/remotes/origin/$TARGET_REF"
sudo git -C "$REPO_ROOT" cat-file -e "$ACCEPTED_CANDIDATE_SHA^{commit}"
if ! sudo git -C "$REPO_ROOT" merge-base --is-ancestor "$ACCEPTED_CANDIDATE_SHA" "origin/$TARGET_REF"; then
    echo "FAIL: accepted disposable candidate is not contained in merged origin/main"
    exit 11
fi

ACTUAL_MIGRATION_BLOB="$(sudo git -C "$REPO_ROOT" rev-parse "$ACCEPTED_CANDIDATE_SHA:$MIGRATION_REL")"
if [[ "$ACTUAL_MIGRATION_BLOB" != "$MIGRATION_BLOB" ]]; then
    echo "FAIL: migration 055 Git blob identity mismatch"
    echo "Expected: $MIGRATION_BLOB"
    echo "Actual:   $ACTUAL_MIGRATION_BLOB"
    exit 12
fi
echo "Accepted migration identity: PASS ($ACTUAL_MIGRATION_BLOB)"

echo
echo "--- Detached exact-candidate regression in Production runtime ---"
sudo git -C "$REPO_ROOT" worktree add --detach "$CANDIDATE_WORKTREE" "$ACCEPTED_CANDIDATE_SHA"
M055="$CANDIDATE_WORKTREE/$MIGRATION_REL"
[[ -s "$M055" ]] || { echo "FAIL: exact accepted candidate is missing migration 055"; exit 13; }
sudo -u fieldwiring -H env PYTHONPYCACHEPREFIX="$DETACHED_PYCACHE" bash -c     "cd '$CANDIDATE_WORKTREE' && '$PYTHON' -m pytest -q -p no:cacheprovider Setup/Application"
echo "DETACHED SETUP CANDIDATE REGRESSION: PASS"

echo
echo "--- Freeze Setup writes for bounded DB-only mutation window ---"
sudo systemctl stop "$SETUP_SERVICE"
SETUP_STOPPED=1
if systemctl is-active --quiet "$SETUP_SERVICE"; then
    echo "FAIL: Setup service did not stop"
    exit 14
fi
echo "msb-setup.service stopped: PASS"

FROZEN_FINGERPRINT="$(setup_fingerprint)"
echo "Initial fingerprint: $INITIAL_FINGERPRINT"
echo "Frozen fingerprint:  $FROZEN_FINGERPRINT"
if [[ "$FROZEN_FINGERPRINT" != "$INITIAL_FINGERPRINT" ]]; then
    echo "FAIL: Setup data changed before write freeze"
    exit 15
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
echo "--- Capture pre-055 function definition for narrow rollback ---"
sudo docker exec "$PROD_CONTAINER"     psql -X -qAt -v ON_ERROR_STOP=1 -U "$DB_ACTOR" -d "$PROD_DB"     -c "SELECT pg_get_functiondef('ref.delete_setup_reconstruction_task(text,bigint)'::regprocedure);"     > "$FUNCTION_ROLLBACK_SQL"
test -s "$FUNCTION_ROLLBACK_SQL"
echo "Prior delete function definition captured: PASS"

echo
echo "--- Production database preflight for migration 055 ---"
psql_prod <<'SQL'
DO $preflight$
BEGIN
    IF to_regprocedure('ref.delete_setup_reconstruction_task(text,bigint)') IS NULL
       OR to_regclass('ops.setup_session_task_dependency') IS NULL
       OR to_regclass('ref.setup_task_extra_material') IS NULL
       OR to_regclass('ref.setup_task_extra_material_source') IS NULL THEN
        RAISE EXCEPTION 'Required reconstruction-delete schema is incomplete';
    END IF;

    IF EXISTS (SELECT 1 FROM ops.setup_session WHERE season_year=2026) THEN
        RAISE EXCEPTION 'Real 2026 Setup Session exists before migration 055';
    END IF;

    IF has_table_privilege('fieldwiring_app','ops.setup_session_task_dependency','DELETE')
       OR has_table_privilege('fieldwiring_app','ops.setup_session_task','DELETE')
       OR has_table_privilege('fieldwiring_app','ref.setup_task','DELETE')
       OR has_table_privilege('fieldwiring_app','ref.setup_task_extra_material','DELETE')
       OR has_table_privilege('fieldwiring_app','ref.setup_task_extra_material_source','DELETE') THEN
        RAISE EXCEPTION 'fieldwiring_app unexpectedly has broad task-delete DML';
    END IF;
END
$preflight$;
SQL
echo "DATABASE PREFLIGHT: PASS"

PRE_MIGRATION_FINGERPRINT="$(setup_fingerprint)"
[[ "$PRE_MIGRATION_FINGERPRINT" == "$FROZEN_FINGERPRINT" ]] || {
    echo "FAIL: Setup data changed after freeze and before migration"; exit 16;
}

echo
echo "--- Apply exact accepted migration 055 ---"
psql_prod < "$M055"
DB_MIGRATION_COMMITTED=1
echo "MIGRATION 055: COMMITTED"

echo
echo "--- Validate migration 055 least-privilege contract ---"
psql_prod <<'SQL'
DO $validate$
BEGIN
    IF to_regprocedure('ref.delete_setup_reconstruction_task(text,bigint)') IS NULL THEN
        RAISE EXCEPTION 'Reconstruction delete function is missing after migration 055';
    END IF;

    IF NOT has_function_privilege(
        'fieldwiring_app',
        'ref.delete_setup_reconstruction_task(text,bigint)',
        'EXECUTE'
    ) THEN
        RAISE EXCEPTION 'fieldwiring_app lacks required EXECUTE on reconstruction delete';
    END IF;

    IF has_table_privilege('fieldwiring_app','ops.setup_session_task_dependency','DELETE')
       OR has_table_privilege('fieldwiring_app','ops.setup_session_task','DELETE')
       OR has_table_privilege('fieldwiring_app','ref.setup_task','DELETE')
       OR has_table_privilege('fieldwiring_app','ref.setup_task_extra_material','DELETE')
       OR has_table_privilege('fieldwiring_app','ref.setup_task_extra_material_source','DELETE') THEN
        RAISE EXCEPTION 'Migration 055 introduced forbidden broad DELETE authority';
    END IF;

    IF EXISTS (SELECT 1 FROM ops.setup_session WHERE season_year=2026) THEN
        RAISE EXCEPTION 'Migration 055 created a real 2026 Setup Session';
    END IF;
END
$validate$;
SQL
echo "MIGRATION 055 SECURITY CONTRACT: PASS"

POST_DB_FINGERPRINT="$(setup_fingerprint)"
echo "Frozen fingerprint:  $FROZEN_FINGERPRINT"
echo "Post-DB fingerprint: $POST_DB_FINGERPRINT"
if [[ "$POST_DB_FINGERPRINT" != "$FROZEN_FINGERPRINT" ]]; then
    echo "FAIL: migration 055 changed governed Setup data"
    exit 17
fi
echo "PASS: migration 055 changed no governed Setup data"

echo
echo "--- Restart and verify unchanged Setup Production runtime ---"
restart_setup

SETUP_POST="$(curl -fsS http://192.168.5.9:8794/api/health)"
echo "Post-deploy Setup health: $SETUP_POST"
if [[ "$SETUP_POST" != *"\"status\":\"ok\""*    || "$SETUP_POST" != *"\"data_mode\":\"postgres\""*    || "$SETUP_POST" != *"\"version\":\"$EXPECTED_SETUP_VERSION\""* ]]; then
    echo "FAIL: Setup health/version changed unexpectedly"
    exit 18
fi
echo "SETUP HEALTH / VERSION: PASS"

echo
echo "--- Live Setup regression after DB-only migration ---"
sudo -u fieldwiring -H env PYTHONPYCACHEPREFIX="$LIVE_PYCACHE" bash -c \
    "cd '$SETUP_ROOT' && '$PYTHON' -m pytest -q -p no:cacheprovider Setup/Application"
echo "LIVE SETUP REGRESSION: PASS"

FINAL_SETUP_HEAD="$(sudo git -C "$SETUP_ROOT" rev-parse HEAD)"
FINAL_FINGERPRINT="$(setup_fingerprint)"
FINAL_2026="$(setup_2026_count)"

echo
echo "--- Final Production invariants ---"
echo "Final live Setup SHA:     $FINAL_SETUP_HEAD"
echo "Final Setup fingerprint:  $FINAL_FINGERPRINT"
echo "2026 Setup Session count: $FINAL_2026"

[[ "$FINAL_SETUP_HEAD" == "$OLD_SETUP_HEAD" ]]
[[ "$FINAL_FINGERPRINT" == "$FROZEN_FINGERPRINT" ]]
[[ "$FINAL_2026" == "0" ]]
systemctl is-active --quiet "$SETUP_SERVICE"

SUCCESS=1
echo
echo "SETUP_145_RECONSTRUCTION_DELETE_PRODUCTION_DEPLOYMENT_PASS"
echo "Accepted candidate SHA: $ACCEPTED_CANDIDATE_SHA"
echo "Migration blob:         $MIGRATION_BLOB"
echo "Live Setup SHA retained:$FINAL_SETUP_HEAD"
echo "Rollback archive:       $BACKUP_FILE"
echo "Rollback SHA256:        $BACKUP_SHA"
echo "Deployment report:      $REPORT"
