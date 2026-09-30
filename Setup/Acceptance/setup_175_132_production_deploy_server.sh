#!/usr/bin/env bash
set -euo pipefail

PROD_CONTAINER="msb-postgres"
PROD_DB="msb"
DB_ACTOR="msbadmin"
REPO_ROOT="/opt/fieldwiring"
SETUP_ROOT="/opt/msb-setup"
PYTHON="/opt/fieldwiring/.venv/bin/python"
SETUP_SERVICE="msb-setup.service"

TARGET_REF="issue-175-captain-work-list-v2"
TARGET_SHA="15864bcce17d0b59c8396e99178e7113fc368b2d"
EXPECTED_VERSION="V0.3.19-pick-list"
MIGRATION_REL="Setup/Database/061_add_live_assignment_report_work.sql"
MIGRATION_BLOB="75a5daace003a229d15be1092535f020ffb010d8"
EXPECTED_JS_PIN="setup_next_pass.js?v=2026-09-26.10"
EXPECTED_CSS_PIN="setup_next_pass.css?v=2026-09-26.10"

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
BACKUP_DIR="/home/msbadmin/backups/setup-175-132"
REPORT_DIR="/home/msbadmin/setup-deployment-reports"
STAMP="$(date +%Y%m%dT%H%M%S)"
BACKUP_FILE="$BACKUP_DIR/msb-pre-setup-175-132-report-work-$STAMP.dump"
REPORT="$REPORT_DIR/Setup_175_132_Report_Work_Production_Deploy_$STAMP.txt"
CANDIDATE_WORKTREE="/tmp/msb-setup-175-132-candidate-$STAMP"
DETACHED_PYCACHE="/tmp/msb-setup-175-132-detached-pycache-$STAMP"
LIVE_PYCACHE="/tmp/msb-setup-175-132-live-pycache-$STAMP"
NEGATIVE_BODY="/tmp/msb-setup-175-132-negative-$STAMP.txt"
OLD_ACTOR_SQL="/tmp/msb-setup-175-132-old-actor-$STAMP.sql"
OLD_PROGRESS_SQL="/tmp/msb-setup-175-132-old-progress-$STAMP.sql"

OLD_HEAD=""
INITIAL_FINGERPRINT=""
FROZEN_FINGERPRINT=""
INITIAL_2026_COUNT=""
INITIAL_PROGRESS_COUNT=""
BACKUP_CREATED=0
DB_MIGRATION_COMMITTED=0
APP_ADVANCED=0
APP_ROLLED_BACK=0
MIGRATION_ROLLED_BACK=0
SETUP_STOPPED=0
SUCCESS=0

mkdir -p "$REPORT_DIR"
exec > >(tee "$REPORT") 2>&1

echo "========== SETUP #175/#132 REPORT WORK PRODUCTION DEPLOYMENT =========="
echo "Authority: Gregovate/MSB-Server-Management — docs/server/Production_Database_Change_Deployment_Runbook.md"
echo "Operator-accepted / deployment SHA: $TARGET_SHA"
echo "Target ref:                         $TARGET_REF"
echo "Expected Setup version:             $EXPECTED_VERSION"
echo "Migration:                          $MIGRATION_REL"
echo "Migration Git blob:                 $MIGRATION_BLOB"
echo "Report:                             $REPORT"
echo

psql_prod() {
    sudo docker exec -i "$PROD_CONTAINER"         psql -X -v ON_ERROR_STOP=1 -U "$DB_ACTOR" -d "$PROD_DB" "$@"
}

setup_business_fingerprint() {
    sudo docker exec "$PROD_CONTAINER"         psql -X -qAt -v ON_ERROR_STOP=1 -U "$DB_ACTOR" -d "$PROD_DB" -c "
            SELECT md5(
                coalesce((SELECT string_agg(row_to_json(t)::text, '' ORDER BY t.setup_task_id) FROM ref.setup_task t), '') || '|' ||
                coalesce((SELECT string_agg(row_to_json(d)::text, '' ORDER BY d.setup_task_id, d.prerequisite_setup_task_id) FROM ref.setup_task_dependency d), '') || '|' ||
                coalesce((SELECT string_agg(row_to_json(td)::text, '' ORDER BY td.setup_task_id, td.display_id) FROM ref.setup_task_display td), '') || '|' ||
                coalesce((SELECT string_agg(row_to_json(tc)::text, '' ORDER BY tc.setup_task_id, tc.container_id) FROM ref.setup_task_container_support tc), '') || '|' ||
                coalesce((SELECT string_agg(row_to_json(r)::text, '' ORDER BY r.setup_resource_id) FROM ref.setup_resource r), '') || '|' ||
                coalesce((SELECT string_agg(row_to_json(tr)::text, '' ORDER BY tr.setup_task_id, tr.setup_resource_id) FROM ref.setup_task_resource tr), '') || '|' ||
                coalesce((SELECT string_agg(row_to_json(s)::text, '' ORDER BY s.setup_session_id) FROM ops.setup_session s), '') || '|' ||
                coalesce((SELECT string_agg(row_to_json(st)::text, '' ORDER BY st.setup_session_task_id) FROM ops.setup_session_task st), '') || '|' ||
                coalesce((SELECT string_agg(row_to_json(wd)::text, '' ORDER BY wd.setup_work_day_id) FROM ops.setup_work_day wd), '') || '|' ||
                coalesce((SELECT string_agg(row_to_json(wdt)::text, '' ORDER BY wdt.setup_work_day_task_id) FROM ops.setup_work_day_task wdt), '') || '|' ||
                coalesce((
                    SELECT string_agg(row_to_json(p)::text, '' ORDER BY p.setup_task_progress_id)
                    FROM (
                        SELECT setup_task_progress_id,
                               setup_session_task_id,
                               setup_work_day_id,
                               setup_work_day_task_id,
                               shift_code,
                               crew_count,
                               completed_quantity,
                               completed_units,
                               progress_note,
                               marks_task_complete,
                               recorded_at,
                               created_at,
                               created_by,
                               updated_at,
                               updated_by,
                               created_by_person_id,
                               updated_by_person_id
                        FROM ops.setup_task_progress
                    ) p
                ), '')
            );
        "
}

setup_2026_count() {
    sudo docker exec "$PROD_CONTAINER"         psql -X -qAt -v ON_ERROR_STOP=1 -U "$DB_ACTOR" -d "$PROD_DB"         -c "SELECT count(*) FROM ops.setup_session WHERE season_year=2026;"
}

progress_count() {
    sudo docker exec "$PROD_CONTAINER"         psql -X -qAt -v ON_ERROR_STOP=1 -U "$DB_ACTOR" -d "$PROD_DB"         -c "SELECT count(*) FROM ops.setup_task_progress;"
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

rollback_migration_061() {
    local current_fingerprint nonnull_new

    current_fingerprint="$(setup_business_fingerprint 2>/dev/null || true)"
    if [[ -z "$current_fingerprint" || "$current_fingerprint" != "$FROZEN_FINGERPRINT" ]]; then
        echo "REFUSE automatic migration 061 rollback: Setup business fingerprint changed after migration"
        return 1
    fi

    nonnull_new="$(sudo docker exec "$PROD_CONTAINER"         psql -X -qAt -v ON_ERROR_STOP=1 -U "$DB_ACTOR" -d "$PROD_DB" -c "
            SELECT count(*)
            FROM ops.setup_task_progress
            WHERE performed_on IS NOT NULL
               OR duration_minutes IS NOT NULL
               OR percent_complete IS NOT NULL;
        " 2>/dev/null || true)"
    if [[ "$nonnull_new" != "0" ]]; then
        echo "REFUSE automatic migration 061 rollback: $nonnull_new progress row(s) use new Report Work columns"
        return 1
    fi

    [[ -s "$OLD_ACTOR_SQL" ]] || {
        echo "REFUSE automatic migration 061 rollback: old execution-actor definition was not captured"
        return 1
    }
    [[ -s "$OLD_PROGRESS_SQL" ]] || {
        echo "REFUSE automatic migration 061 rollback: old progress-command definition was not captured"
        return 1
    }

    psql_prod <<'SQL'
BEGIN;
DROP FUNCTION IF EXISTS ops.correct_setup_task_progress(
    text,bigint,date,integer,integer,integer,integer,text,text
);
DROP FUNCTION IF EXISTS ops.record_setup_task_progress(
    text,bigint,date,integer,integer,integer,integer,text,text,bigint,bigint,text
);
ALTER TABLE ops.setup_task_progress
    DROP CONSTRAINT IF EXISTS ck_setup_task_progress_duration;
ALTER TABLE ops.setup_task_progress
    DROP CONSTRAINT IF EXISTS ck_setup_task_progress_percent_complete;
ALTER TABLE ops.setup_task_progress
    DROP COLUMN IF EXISTS performed_on;
ALTER TABLE ops.setup_task_progress
    DROP COLUMN IF EXISTS duration_minutes;
ALTER TABLE ops.setup_task_progress
    DROP COLUMN IF EXISTS percent_complete;
COMMIT;
SQL

    psql_prod < "$OLD_ACTOR_SQL"
    psql_prod < "$OLD_PROGRESS_SQL"

    psql_prod <<'SQL'
REVOKE ALL ON FUNCTION ref.setup_execution_actor(text,bigint) FROM PUBLIC;
REVOKE ALL ON FUNCTION ref.setup_execution_actor(text,bigint) FROM fieldwiring_app;
REVOKE ALL ON FUNCTION ops.record_setup_task_progress(
    text,bigint,bigint,text,integer,integer,text,text,boolean
) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION ops.record_setup_task_progress(
    text,bigint,bigint,text,integer,integer,text,text,boolean
) TO fieldwiring_app;
SQL

    MIGRATION_ROLLED_BACK=1
}

cleanup() {
    status=$?
    trap - EXIT HUP INT TERM
    set +e
    rollback_failed=0

    if [[ "$status" -ne 0 && "$SUCCESS" -ne 1 ]]; then
        echo
        echo "--- FAIL-CLOSED RECOVERY ---"

        if [[ "$DB_MIGRATION_COMMITTED" -eq 1 || "$APP_ADVANCED" -eq 1 ]]; then
            if systemctl is-active --quiet "$SETUP_SERVICE"; then
                echo "Stopping Setup service before recovery"
                sudo systemctl stop "$SETUP_SERVICE" || true
                SETUP_STOPPED=1
            fi
        fi

        if [[ "$DB_MIGRATION_COMMITTED" -eq 1 ]]; then
            echo "Attempting bounded rollback of migration 061"
            if rollback_migration_061; then
                DB_MIGRATION_COMMITTED=0
                echo "Migration 061 rollback: PASS"
            else
                rollback_failed=1
                echo "WARNING: migration 061 was not automatically removed."
                echo "Setup service will remain stopped; review the retained rollback archive/report before further mutation."
            fi
        fi

        if [[ "$rollback_failed" -eq 0 && "$APP_ADVANCED" -eq 1 && -n "$OLD_HEAD" ]]; then
            echo "Restoring Setup checkout to verified prior SHA $OLD_HEAD"
            sudo git -C "$SETUP_ROOT" checkout --detach "$OLD_HEAD" || true
            APP_ADVANCED=0
            APP_ROLLED_BACK=1
        fi

        if [[ "$rollback_failed" -eq 0 && ( "$SETUP_STOPPED" -eq 1 || "$APP_ROLLED_BACK" -eq 1 ) ]]; then
            echo "Restarting Setup service after recovery"
            restart_setup || true
        fi
    fi

    if sudo git -C "$REPO_ROOT" worktree list --porcelain 2>/dev/null | grep -Fq "worktree $CANDIDATE_WORKTREE"; then
        sudo git -C "$REPO_ROOT" worktree remove --force "$CANDIDATE_WORKTREE" >/dev/null 2>&1 || true
    fi
    sudo git -C "$REPO_ROOT" worktree prune >/dev/null 2>&1 || true
    sudo rm -rf "$DETACHED_PYCACHE" "$LIVE_PYCACHE" >/dev/null 2>&1 || true
    rm -f "$NEGATIVE_BODY" "$OLD_ACTOR_SQL" "$OLD_PROGRESS_SQL" >/dev/null 2>&1 || true
    rm -rf "$SCRIPT_DIR" >/dev/null 2>&1 || true

    echo
    echo "--- Production after-check ---"
    if [[ -n "$FROZEN_FINGERPRINT" ]]; then
        AFTER_FINGERPRINT="$(setup_business_fingerprint 2>/dev/null || true)"
        echo "Frozen Setup business fingerprint: $FROZEN_FINGERPRINT"
        echo "Final Setup business fingerprint:  $AFTER_FINGERPRINT"
        if [[ -z "$AFTER_FINGERPRINT" || "$AFTER_FINGERPRINT" != "$FROZEN_FINGERPRINT" ]]; then
            echo "FAIL: governed Setup business data changed during deployment"
            status=97
        else
            echo "PASS: governed Setup business data fingerprint unchanged"
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

    if [[ -n "$INITIAL_PROGRESS_COUNT" ]]; then
        FINAL_PROGRESS_COUNT="$(progress_count 2>/dev/null || true)"
        echo "Setup progress row count before: $INITIAL_PROGRESS_COUNT"
        echo "Setup progress row count after:  $FINAL_PROGRESS_COUNT"
        if [[ -z "$FINAL_PROGRESS_COUNT" || "$FINAL_PROGRESS_COUNT" != "$INITIAL_PROGRESS_COUNT" ]]; then
            echo "FAIL: Setup progress row count changed during deployment"
            status=95
        else
            echo "PASS: Setup progress row count unchanged"
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
if [[ "$SETUP_PRE" != *"\"status\":\"ok\""*    || "$SETUP_PRE" != *"\"data_mode\":\"postgres\""*    || "$SETUP_PRE" != *"\"version\":\"$EXPECTED_VERSION\""* ]]; then
    echo "FAIL: live Setup pre-deploy health/version is not expected $EXPECTED_VERSION"
    exit 8
fi

INITIAL_FINGERPRINT="$(setup_business_fingerprint)"
[[ -n "$INITIAL_FINGERPRINT" ]] || { echo "FAIL: initial Setup business fingerprint is empty"; exit 9; }
INITIAL_2026_COUNT="$(setup_2026_count)"
INITIAL_PROGRESS_COUNT="$(progress_count)"
echo "Initial Setup business fingerprint: $INITIAL_FINGERPRINT"
echo "Initial 2026 Setup Session count:    $INITIAL_2026_COUNT"
echo "Initial Setup progress row count:    $INITIAL_PROGRESS_COUNT"
if [[ "$INITIAL_2026_COUNT" != "1" ]]; then
    echo "FAIL: expected exactly one live 2026 Setup Session before #175/#132 deployment"
    exit 10
fi

echo
echo "--- Fetch and verify exact approved target ---"
sudo git -C "$REPO_ROOT" fetch origin "$TARGET_REF:refs/remotes/origin/$TARGET_REF"
sudo git -C "$REPO_ROOT" cat-file -e "$TARGET_SHA^{commit}"
if ! sudo git -C "$REPO_ROOT" merge-base --is-ancestor "$TARGET_SHA" "origin/$TARGET_REF"; then
    echo "FAIL: accepted target is not contained in current origin/$TARGET_REF"
    exit 11
fi
if ! sudo git -C "$REPO_ROOT" merge-base --is-ancestor "$OLD_HEAD" "$TARGET_SHA"; then
    echo "FAIL: deployment target is not a forward descendant of verified live Setup checkout"
    echo "Live:   $OLD_HEAD"
    echo "Target: $TARGET_SHA"
    exit 12
fi
echo "Target ancestry: PASS"

ACTUAL_MIGRATION_BLOB="$(sudo git -C "$REPO_ROOT" rev-parse "$TARGET_SHA:$MIGRATION_REL")"
if [[ "$ACTUAL_MIGRATION_BLOB" != "$MIGRATION_BLOB" ]]; then
    echo "FAIL: migration 061 Git blob identity mismatch"
    echo "Expected: $MIGRATION_BLOB"
    echo "Actual:   $ACTUAL_MIGRATION_BLOB"
    exit 13
fi
echo "Migration 061 Git blob identity: PASS ($ACTUAL_MIGRATION_BLOB)"

echo
echo "--- Detached exact-target regression in Production runtime ---"
sudo git -C "$REPO_ROOT" worktree add --detach "$CANDIDATE_WORKTREE" "$TARGET_SHA"
M061="$CANDIDATE_WORKTREE/$MIGRATION_REL"
[[ -s "$M061" ]] || { echo "FAIL: exact target is missing migration 061"; exit 14; }

grep -Fq 'PRODUCTION_VERSION = "V0.3.19-pick-list"'     "$CANDIDATE_WORKTREE/Setup/Application/production_backend.py"
grep -Fq "$EXPECTED_JS_PIN" "$CANDIDATE_WORKTREE/Setup/Application/production.html"
grep -Fq "$EXPECTED_CSS_PIN" "$CANDIDATE_WORKTREE/Setup/Application/production.html"

sudo -u fieldwiring -H env PYTHONPYCACHEPREFIX="$DETACHED_PYCACHE" bash -c     "cd '$CANDIDATE_WORKTREE' && '$PYTHON' -m pytest -q -p no:cacheprovider Setup/Application"
echo "DETACHED SETUP TARGET REGRESSION: PASS"

echo
echo "--- Freeze Setup writes for bounded Production mutation window ---"
sudo systemctl stop "$SETUP_SERVICE"
SETUP_STOPPED=1
if systemctl is-active --quiet "$SETUP_SERVICE"; then
    echo "FAIL: Setup service did not stop"
    exit 15
fi
echo "msb-setup.service stopped: PASS"

FROZEN_FINGERPRINT="$(setup_business_fingerprint)"
echo "Initial business fingerprint: $INITIAL_FINGERPRINT"
echo "Frozen business fingerprint:  $FROZEN_FINGERPRINT"
if [[ "$FROZEN_FINGERPRINT" != "$INITIAL_FINGERPRINT" ]]; then
    echo "FAIL: Setup business data changed before write freeze; stop before mutation"
    exit 16
fi
if [[ "$(setup_2026_count)" != "$INITIAL_2026_COUNT" ]]; then
    echo "FAIL: 2026 Setup Session count changed before mutation"
    exit 17
fi
if [[ "$(progress_count)" != "$INITIAL_PROGRESS_COUNT" ]]; then
    echo "FAIL: Setup progress row count changed before mutation"
    exit 18
fi
echo "WRITE-FREEZE STABILITY: PASS"

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
echo "--- Production database preflight for migration 061 ---"
psql_prod <<'SQL'
DO $preflight$
BEGIN
    IF to_regclass('ops.setup_task_progress') IS NULL
       OR to_regclass('ops.setup_session_task') IS NULL
       OR to_regclass('ops.setup_work_day_task') IS NULL
       OR to_regprocedure('ref.setup_execution_actor(text,bigint)') IS NULL
       OR to_regprocedure(
            'ops.record_setup_task_progress(text,bigint,bigint,text,integer,integer,text,text,boolean)'
          ) IS NULL THEN
        RAISE EXCEPTION 'Accepted pre-061 Setup execution foundation is incomplete';
    END IF;

    IF EXISTS (
        SELECT 1
        FROM information_schema.columns
        WHERE table_schema='ops'
          AND table_name='setup_task_progress'
          AND column_name IN ('performed_on','duration_minutes','percent_complete')
    ) THEN
        RAISE EXCEPTION 'Migration 061 columns already/partially exist; reconcile before deployment';
    END IF;

    IF to_regprocedure(
        'ops.record_setup_task_progress(text,bigint,date,integer,integer,integer,integer,text,text,bigint,bigint,text)'
       ) IS NOT NULL
       OR to_regprocedure(
        'ops.correct_setup_task_progress(text,bigint,date,integer,integer,integer,integer,text,text)'
       ) IS NOT NULL THEN
        RAISE EXCEPTION 'Migration 061 functions already/partially exist; reconcile before deployment';
    END IF;

    IF (SELECT count(*) FROM ops.setup_session WHERE season_year=2026) <> 1 THEN
        RAISE EXCEPTION 'Expected exactly one live 2026 Setup Session';
    END IF;
END
$preflight$;
SQL
echo "DATABASE PREFLIGHT: PASS"

echo
echo "--- Capture exact pre-061 function definitions for bounded rollback ---"
sudo docker exec "$PROD_CONTAINER"     psql -X -qAt -v ON_ERROR_STOP=1 -U "$DB_ACTOR" -d "$PROD_DB"     -c "SELECT pg_get_functiondef('ref.setup_execution_actor(text,bigint)'::regprocedure);"     > "$OLD_ACTOR_SQL"
sudo docker exec "$PROD_CONTAINER"     psql -X -qAt -v ON_ERROR_STOP=1 -U "$DB_ACTOR" -d "$PROD_DB"     -c "SELECT pg_get_functiondef('ops.record_setup_task_progress(text,bigint,bigint,text,integer,integer,text,text,boolean)'::regprocedure);"     > "$OLD_PROGRESS_SQL"
test -s "$OLD_ACTOR_SQL"
test -s "$OLD_PROGRESS_SQL"
echo "PRE-061 FUNCTION ROLLBACK CAPTURE: PASS"

PRE_MUTATION_FINGERPRINT="$(setup_business_fingerprint)"
if [[ "$PRE_MUTATION_FINGERPRINT" != "$FROZEN_FINGERPRINT" ]]; then
    echo "FAIL: Setup business data changed during preflight"
    exit 19
fi
echo "PRE-MUTATION FINGERPRINT STABILITY: PASS"

echo
echo "--- Apply reviewed migration 061 only ---"
psql_prod < "$M061"
DB_MIGRATION_COMMITTED=1
echo "MIGRATION 061: COMMITTED"

echo
echo "--- Validate migration 061 authority and least privilege ---"
psql_prod <<'SQL'
DO $validate$
DECLARE
    v_new_nonnull bigint;
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_schema='ops' AND table_name='setup_task_progress' AND column_name='performed_on'
    ) OR NOT EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_schema='ops' AND table_name='setup_task_progress' AND column_name='duration_minutes'
    ) OR NOT EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_schema='ops' AND table_name='setup_task_progress' AND column_name='percent_complete'
    ) THEN
        RAISE EXCEPTION 'Migration 061 progress columns are incomplete';
    END IF;

    IF to_regprocedure(
        'ops.record_setup_task_progress(text,bigint,date,integer,integer,integer,integer,text,text,bigint,bigint,text)'
       ) IS NULL
       OR to_regprocedure(
        'ops.correct_setup_task_progress(text,bigint,date,integer,integer,integer,integer,text,text)'
       ) IS NULL THEN
        RAISE EXCEPTION 'Migration 061 Report Work functions are incomplete';
    END IF;

    IF to_regprocedure(
        'ops.record_setup_task_progress(text,bigint,bigint,text,integer,integer,text,text,boolean)'
       ) IS NOT NULL THEN
        RAISE EXCEPTION 'Legacy Report Work command still exists after migration 061';
    END IF;

    IF NOT has_function_privilege(
        'fieldwiring_app',
        'ops.record_setup_task_progress(text,bigint,date,integer,integer,integer,integer,text,text,bigint,bigint,text)',
        'EXECUTE'
    ) OR NOT has_function_privilege(
        'fieldwiring_app',
        'ops.correct_setup_task_progress(text,bigint,date,integer,integer,integer,integer,text,text)',
        'EXECUTE'
    ) THEN
        RAISE EXCEPTION 'fieldwiring_app lacks required Report Work command EXECUTE';
    END IF;

    IF has_function_privilege(
        'fieldwiring_app',
        'ref.setup_execution_actor(text,bigint)',
        'EXECUTE'
    ) THEN
        RAISE EXCEPTION 'Internal execution-actor helper is directly executable by fieldwiring_app';
    END IF;

    IF has_table_privilege('fieldwiring_app','ops.setup_task_progress','INSERT')
       OR has_table_privilege('fieldwiring_app','ops.setup_task_progress','UPDATE')
       OR has_table_privilege('fieldwiring_app','ops.setup_task_progress','DELETE') THEN
        RAISE EXCEPTION 'Forbidden broad setup_task_progress DML privilege detected';
    END IF;

    SELECT count(*)
      INTO v_new_nonnull
    FROM ops.setup_task_progress
    WHERE performed_on IS NOT NULL
       OR duration_minutes IS NOT NULL
       OR percent_complete IS NOT NULL;

    IF v_new_nonnull <> 0 THEN
        RAISE EXCEPTION 'Migration 061 unexpectedly populated new progress fields on existing rows';
    END IF;
END
$validate$;
SQL
echo "DATABASE CONTRACT VALIDATION: PASS"

POST_DB_FINGERPRINT="$(setup_business_fingerprint)"
echo "Setup business fingerprint before migration: $FROZEN_FINGERPRINT"
echo "Setup business fingerprint after migration:  $POST_DB_FINGERPRINT"
if [[ "$POST_DB_FINGERPRINT" != "$FROZEN_FINGERPRINT" ]]; then
    echo "FAIL: migration 061 changed existing governed Setup business data"
    exit 20
fi
if [[ "$(progress_count)" != "$INITIAL_PROGRESS_COUNT" ]]; then
    echo "FAIL: migration 061 changed Setup progress row count"
    exit 21
fi
echo "PASS: migration 061 preserved existing Setup business data/progress rows"

echo
echo "--- Advance dedicated Setup Production checkout to exact accepted target ---"
sudo git -C "$SETUP_ROOT" checkout --detach "$TARGET_SHA"
APP_ADVANCED=1
DEPLOYED_HEAD="$(sudo git -C "$SETUP_ROOT" rev-parse HEAD)"
DEPLOYED_STATUS="$(sudo git -C "$SETUP_ROOT" status --porcelain)"
if [[ "$DEPLOYED_HEAD" != "$TARGET_SHA" || -n "$DEPLOYED_STATUS" ]]; then
    echo "FAIL: deployed Setup checkout does not exactly match accepted target"
    echo "Expected: $TARGET_SHA"
    echo "Actual:   $DEPLOYED_HEAD"
    exit 22
fi
echo "Setup checkout advanced exactly to $DEPLOYED_HEAD"

echo
echo "--- Restart and verify Setup runtime ---"
restart_setup
SETUP_POST="$(curl -fsS http://192.168.5.9:8794/api/health)"
echo "Post-deploy Setup health: $SETUP_POST"
if [[ "$SETUP_POST" != *"\"status\":\"ok\""*    || "$SETUP_POST" != *"\"data_mode\":\"postgres\""*    || "$SETUP_POST" != *"\"version\":\"$EXPECTED_VERSION\""* ]]; then
    echo "FAIL: Setup health/version does not match expected $EXPECTED_VERSION"
    exit 23
fi

ROOT_HTML="$(curl -fsS http://192.168.5.9:8794/)"
if [[ "$ROOT_HTML" != *"$EXPECTED_JS_PIN"* || "$ROOT_HTML" != *"$EXPECTED_CSS_PIN"* ]]; then
    echo "FAIL: Production root does not expose accepted #175/#132 asset pins"
    exit 24
fi

NEXT_JS="$(curl -fsS http://192.168.5.9:8794/setup_next_pass.js)"
if [[ "$NEXT_JS" != *"Report Correction"*    || "$NEXT_JS" != *"Correct report"*    || "$NEXT_JS" != *"msb.setup.performCaptainFilter.v1."*    || "$NEXT_JS" != *"Work completed on"* ]]; then
    echo "FAIL: Production setup_next_pass.js is not the accepted #175/#132 field workflow"
    exit 25
fi
echo "Production #175/#132 client assets: PASS"

NEGATIVE_CODE="$(curl -sS -o "$NEGATIVE_BODY" -w '%{http_code}'     'http://192.168.5.9:8794/api/setup/scheduling-board?season_year=2026')"
echo "Direct unauthenticated scheduling-board API status: $NEGATIVE_CODE"
if [[ "$NEGATIVE_CODE" != "401" ]]; then
    echo "FAIL: protected Scheduling Board API did not reject unauthenticated direct request"
    cat "$NEGATIVE_BODY" || true
    exit 26
fi
echo "PROTECTED SETUP NEGATIVE PATH: PASS"

MANAGER_EMAIL="$(sudo docker exec "$PROD_CONTAINER"     psql -X -qAt -v ON_ERROR_STOP=1 -U "$DB_ACTOR" -d "$PROD_DB" -c "
        SELECT lower(u.email)
        FROM public.directus_users u
        JOIN ref.person p ON p.directus_user_id=u.id
        JOIN LATERAL ref.setup_browser_capabilities(u.email) c ON true
        WHERE u.status='active' AND c.can_manage_setup
        ORDER BY u.email
        LIMIT 1;
    ")"
[[ -n "$MANAGER_EMAIL" ]] || { echo "FAIL: no active Setup Manager identity found"; exit 27; }

BOARD_JSON="$(curl -fsS     -H "Cf-Access-Authenticated-User-Email: $MANAGER_EMAIL"     'http://192.168.5.9:8794/api/setup/scheduling-board?season_year=2026')"
printf '%s' "$BOARD_JSON" | sudo -u fieldwiring -H "$PYTHON" -c '
import json, sys
payload=json.load(sys.stdin)
board=payload.get("board") or {}
assert (board.get("session") or {}).get("season_year") == 2026
assert isinstance(board.get("assignments"), list)
assert isinstance(board.get("crews"), list)
'
echo "AUTHENTICATED 2026 SCHEDULING BOARD READ: PASS"

echo
echo "--- Live Setup regression ---"
sudo -u fieldwiring -H env PYTHONPYCACHEPREFIX="$LIVE_PYCACHE" bash -c     "cd '$SETUP_ROOT' && '$PYTHON' -m pytest -q -p no:cacheprovider Setup/Application"
echo "LIVE SETUP REGRESSION: PASS"

echo
echo "--- Final Production invariants ---"
FINAL_HEAD="$(sudo git -C "$SETUP_ROOT" rev-parse HEAD)"
FINAL_STATUS="$(sudo git -C "$SETUP_ROOT" status --porcelain)"
FINAL_FINGERPRINT="$(setup_business_fingerprint)"
FINAL_2026_COUNT="$(setup_2026_count)"
FINAL_PROGRESS_COUNT="$(progress_count)"
FINAL_HEALTH="$(curl -fsS http://192.168.5.9:8794/api/health)"

echo "Final Setup SHA:                   $FINAL_HEAD"
echo "Final Setup business fingerprint:  $FINAL_FINGERPRINT"
echo "Final 2026 Setup Session count:    $FINAL_2026_COUNT"
echo "Final Setup progress row count:    $FINAL_PROGRESS_COUNT"
echo "Final Setup health:                $FINAL_HEALTH"

[[ "$FINAL_HEAD" == "$TARGET_SHA" ]]
[[ -z "$FINAL_STATUS" ]]
[[ "$FINAL_FINGERPRINT" == "$FROZEN_FINGERPRINT" ]]
[[ "$FINAL_2026_COUNT" == "$INITIAL_2026_COUNT" ]]
[[ "$FINAL_PROGRESS_COUNT" == "$INITIAL_PROGRESS_COUNT" ]]
[[ "$FINAL_HEALTH" == *"\"version\":\"$EXPECTED_VERSION\""* ]]

SUCCESS=1
echo
echo "SETUP_175_132_REPORT_WORK_PRODUCTION_DEPLOYMENT_PASS"
echo "Rollback archive:  $BACKUP_FILE"
echo "Rollback SHA256:   $BACKUP_SHA"
echo "Deployment report: $REPORT"
