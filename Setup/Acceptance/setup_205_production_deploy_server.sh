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
TARGET_SHA="8161e91384cb13587fa0c92da2f80f6cf770592d"
EXPECTED_SETUP_VERSION="V0.3.14-scheduling-board"
MIGRATION_REL="Setup/Database/050_add_setup_scheduling_board_foundation.sql"
MIGRATION_BLOB="cdce6a62bb42cb7df9c32acb1dc1a5f6b6af2bb5"
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
BACKUP_DIR="/home/msbadmin/backups/setup-205"
REPORT_DIR="/home/msbadmin/setup-deployment-reports"
STAMP="$(date +%Y%m%dT%H%M%S)"
BACKUP_FILE="$BACKUP_DIR/msb-pre-setup-205-scheduling-board-$STAMP.dump"
REPORT="$REPORT_DIR/Setup_205_Production_Deploy_$STAMP.txt"
CANDIDATE_WORKTREE="/tmp/msb-setup-205-production-candidate-$STAMP"
NEGATIVE_BODY="/tmp/msb-setup-205-negative-$STAMP.txt"
M050=""
LEGACY_BEFORE=""
OLD_HEAD=""
SETUP_PRE=""
DB_MIGRATION_COMMITTED=0
APP_ADVANCED=0
SUCCESS=0
BACKUP_CREATED=0

mkdir -p "$REPORT_DIR"
exec > >(tee "$REPORT") 2>&1

echo "========== SETUP #205 PRODUCTION DEPLOYMENT =========="
echo "Authority: Gregovate/MSB-Server-Management — docs/server/Production_Database_Change_Deployment_Runbook.md"
echo "Procedure: exact-target migration-bearing Setup deployment"
echo "This step: migration 050 + exact V0.3.14 application promotion"
echo "Report:       $REPORT"
echo "Target SHA:   $TARGET_SHA"
echo "Target ref:   $TARGET_REF"
echo "Expected ver: $EXPECTED_SETUP_VERSION"
echo "Migration:    $MIGRATION_REL"
echo "Migration ID: $MIGRATION_BLOB"
echo "Setup root:   $SETUP_ROOT"
echo

psql_prod() {
    sudo docker exec -i "$PROD_CONTAINER"         psql -X -v ON_ERROR_STOP=1 -U "$DB_ACTOR" -d "$PROD_DB" "$@"
}

legacy_setup_fingerprint() {
    sudo docker exec "$PROD_CONTAINER"         psql -X -qAt -v ON_ERROR_STOP=1 -U "$DB_ACTOR" -d "$PROD_DB" -c "
            SELECT md5(
                coalesce((SELECT string_agg(to_jsonb(t)::text, '' ORDER BY t.setup_task_id)
                          FROM ref.setup_task t), '') || '|' ||
                coalesce((SELECT string_agg(to_jsonb(d)::text, '' ORDER BY d.setup_task_id, d.prerequisite_setup_task_id)
                          FROM ref.setup_task_dependency d), '') || '|' ||
                coalesce((SELECT string_agg(to_jsonb(td)::text, '' ORDER BY td.setup_task_id, td.display_id)
                          FROM ref.setup_task_display td), '') || '|' ||
                coalesce((SELECT string_agg(to_jsonb(tc)::text, '' ORDER BY tc.setup_task_id, tc.container_id)
                          FROM ref.setup_task_container_support tc), '') || '|' ||
                coalesce((SELECT string_agg(to_jsonb(r)::text, '' ORDER BY r.setup_resource_id)
                          FROM ref.setup_resource r), '') || '|' ||
                coalesce((SELECT string_agg(to_jsonb(tr)::text, '' ORDER BY tr.setup_task_id, tr.setup_resource_id)
                          FROM ref.setup_task_resource tr), '') || '|' ||
                coalesce((SELECT string_agg(to_jsonb(s)::text, '' ORDER BY s.setup_session_id)
                          FROM ops.setup_session s), '') || '|' ||
                coalesce((SELECT string_agg(
                              (to_jsonb(st) - ARRAY[
                                  'task_origin','annual_task_name','annual_stage_id','annual_lor_scene_id',
                                  'annual_task_action_type','annual_normal_crew_min','annual_normal_crew_max',
                                  'annual_expected_duration_minutes','annual_effort_level','annual_completion_point',
                                  'annual_readiness_note','annual_readiness_state','annual_weather_note',
                                  'linked_work_order_id','linked_work_order_gate'
                              ]::text[])::text,
                              '' ORDER BY st.setup_session_task_id
                          ) FROM ops.setup_session_task st), '') || '|' ||
                coalesce((SELECT string_agg(
                              (to_jsonb(wd) - 'setup_day_number')::text,
                              '' ORDER BY wd.setup_work_day_id
                          ) FROM ops.setup_work_day wd), '') || '|' ||
                coalesce((SELECT string_agg(
                              (to_jsonb(wdt) - ARRAY['setup_work_day_task_id','setup_work_day_crew_id']::text[])::text,
                              '' ORDER BY wdt.setup_work_day_id, wdt.setup_session_task_id, wdt.shift_code, wdt.crew_lane
                          ) FROM ops.setup_work_day_task wdt), '') || '|' ||
                coalesce((SELECT string_agg(
                              (to_jsonb(p) - 'setup_work_day_task_id')::text,
                              '' ORDER BY p.setup_task_progress_id
                          ) FROM ops.setup_task_progress p), '')
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

restart_setup_service() {
    sudo systemctl restart "$SETUP_SERVICE"
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
            echo "Restoring Setup application checkout to verified prior SHA $OLD_HEAD"
            sudo git -C "$SETUP_ROOT" reset --hard "$OLD_HEAD" || true
            restart_setup_service || true
            echo "Application source rollback attempted. Migration 050 is intentionally not auto-removed."
        fi
        if [[ "$DB_MIGRATION_COMMITTED" -eq 1 ]]; then
            echo "Migration 050 remains installed."
            echo "Reason: post-migration validation requires legacy command compatibility and unchanged pre-050 business data before application promotion."
            echo "Do NOT auto-restore the full PostgreSQL archive: that could erase unrelated concurrent Production writes."
            echo "Validated rollback archive is retained for governed emergency recovery if later required."
        else
            echo "Migration 050 did not reach committed-success state; its explicit transaction is expected to have rolled back on SQL failure."
        fi
    fi

    if sudo git -C "$REPO_ROOT" worktree list --porcelain 2>/dev/null | grep -Fq "worktree $CANDIDATE_WORKTREE"; then
        sudo git -C "$REPO_ROOT" worktree remove --force "$CANDIDATE_WORKTREE" >/dev/null 2>&1 || true
    fi
    sudo git -C "$REPO_ROOT" worktree prune >/dev/null 2>&1 || true
    rm -f "$NEGATIVE_BODY" >/dev/null 2>&1 || true
    rm -rf "$SCRIPT_DIR" >/dev/null 2>&1 || true

    echo
    echo "--- Production after-check ---"
    if [[ -n "$LEGACY_BEFORE" ]]; then
        LEGACY_AFTER="$(legacy_setup_fingerprint 2>/dev/null)"
        echo "Legacy Setup business fingerprint before: $LEGACY_BEFORE"
        echo "Legacy Setup business fingerprint after:  $LEGACY_AFTER"
        if [[ -z "$LEGACY_AFTER" || "$LEGACY_AFTER" != "$LEGACY_BEFORE" ]]; then
            echo "FAIL: pre-050 Setup business fields changed"
            status=97
        else
            echo "PASS: pre-050 Setup business fields unchanged"
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
trap cleanup EXIT HUP INT TERM

sudo -v
mkdir -p "$BACKUP_DIR" "$REPORT_DIR"

if ! sudo docker inspect "$PROD_CONTAINER" >/dev/null 2>&1; then
    echo "FAIL: Production PostgreSQL container $PROD_CONTAINER not found"
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

LEGACY_BEFORE="$(legacy_setup_fingerprint)"
[[ -n "$LEGACY_BEFORE" ]] || { echo "FAIL: legacy Setup business fingerprint is empty"; exit 8; }
echo "Pre-deploy legacy Setup business fingerprint: $LEGACY_BEFORE"

echo
echo "--- Fetch and verify exact operator-approved target ---"
sudo git -C "$REPO_ROOT" fetch origin "$TARGET_REF"
sudo git -C "$REPO_ROOT" cat-file -e "$TARGET_SHA^{commit}"
if ! sudo git -C "$REPO_ROOT" merge-base --is-ancestor "$OLD_HEAD" "$TARGET_SHA"; then
    echo "FAIL: accepted Setup target is not a forward descendant of verified live Setup checkout"
    echo "Live:   $OLD_HEAD"
    echo "Target: $TARGET_SHA"
    exit 9
fi
echo "Verified forward ancestry: $OLD_HEAD -> $TARGET_SHA"

ACTUAL_MIGRATION_BLOB="$(sudo git -C "$REPO_ROOT" rev-parse "$TARGET_SHA:$MIGRATION_REL")"
if [[ "$ACTUAL_MIGRATION_BLOB" != "$MIGRATION_BLOB" ]]; then
    echo "FAIL: accepted migration blob mismatch"
    echo "Expected: $MIGRATION_BLOB"
    echo "Actual:   $ACTUAL_MIGRATION_BLOB"
    exit 10
fi
echo "Accepted migration Git blob identity: PASS ($ACTUAL_MIGRATION_BLOB)"

echo
echo "--- Detached Production-runtime candidate regression ---"
sudo git -C "$REPO_ROOT" worktree add --detach "$CANDIDATE_WORKTREE" "$TARGET_SHA"
M050="$CANDIDATE_WORKTREE/$MIGRATION_REL"
[[ -s "$M050" ]] || { echo "FAIL: accepted target is missing migration 050"; exit 11; }
sudo -u fieldwiring -H bash -c     "cd '$CANDIDATE_WORKTREE' && '$PYTHON' -m pytest -q -p no:cacheprovider Setup/Application"
echo "DETACHED SETUP CANDIDATE REGRESSION: PASS"

echo
echo "--- Create and verify rollback PostgreSQL archive ---"
sudo docker exec "$PROD_CONTAINER"     pg_dump -U "$DB_ACTOR" -d "$PROD_DB" -Fc > "$BACKUP_FILE"
test -s "$BACKUP_FILE"
BACKUP_CREATED=1
BACKUP_SHA="$(sha256sum "$BACKUP_FILE" | awk '{print $1}')"
sudo docker exec -i "$PROD_CONTAINER" pg_restore --list < "$BACKUP_FILE" >/dev/null
echo "Rollback archive: $BACKUP_FILE"
echo "SHA256:          $BACKUP_SHA"
echo "ROLLBACK ARCHIVE VALIDATION: PASS"

echo
echo "--- Production database preflight for migration 050 ---"
psql_prod <<'SQL'
DO $preflight$
BEGIN
    IF to_regclass('ops.setup_session') IS NULL
       OR to_regclass('ops.setup_session_task') IS NULL
       OR to_regclass('ops.setup_work_day') IS NULL
       OR to_regclass('ops.setup_work_day_task') IS NULL
       OR to_regclass('ops.setup_task_progress') IS NULL
       OR to_regclass('ops.work_order') IS NULL
       OR to_regprocedure('ref.setup_management_actor(text,boolean)') IS NULL
       OR to_regprocedure('ops.upsert_setup_work_day(text,integer,date,text,text)') IS NULL
       OR to_regprocedure('ops.set_setup_work_day_task(text,bigint,bigint,text,text,integer,integer,boolean)') IS NULL
       OR to_regprocedure('ops.record_setup_task_progress(text,bigint,bigint,text,integer,integer,text,text,boolean)') IS NULL THEN
        RAISE EXCEPTION 'Accepted Setup scheduling/management foundation is incomplete';
    END IF;

    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname='fieldwiring_app') THEN
        RAISE EXCEPTION 'Required fieldwiring_app role does not exist';
    END IF;

    IF EXISTS (SELECT 1 FROM ops.setup_session WHERE season_year=2026) THEN
        RAISE EXCEPTION 'Real 2026 Setup Session exists before #205 deployment';
    END IF;

    IF EXISTS (
        SELECT 1
        FROM information_schema.columns
        WHERE table_schema='ops' AND table_name='setup_work_day'
          AND column_name='setup_day_number'
    ) OR to_regclass('ops.setup_work_day_crew') IS NOT NULL
      OR to_regclass('ops.setup_session_task_dependency') IS NOT NULL
      OR to_regprocedure('ops.create_setup_season_task(text,integer,text,integer,bigint,text,integer,integer,integer,integer,text,text,text,text,bigint,boolean,text)') IS NOT NULL THEN
        RAISE EXCEPTION 'Migration 050 appears already or partially installed; reconcile before deployment';
    END IF;

    IF EXISTS (
        SELECT 1 FROM ops.setup_session_task WHERE setup_task_id IS NULL
    ) THEN
        RAISE EXCEPTION 'Pre-050 Setup Session contains a season-only/null reusable task identity';
    END IF;

    IF EXISTS (
        SELECT 1
        FROM ops.setup_work_day_task
        GROUP BY setup_work_day_id, setup_session_task_id, shift_code
        HAVING count(*) > 1
    ) THEN
        RAISE EXCEPTION 'Existing schedule has duplicate task/shift rows that migration 050 cannot make unique';
    END IF;

    IF NOT has_function_privilege(
            'fieldwiring_app',
            'ops.upsert_setup_work_day(text,integer,date,text,text)',
            'EXECUTE'
       )
       OR NOT has_function_privilege(
            'fieldwiring_app',
            'ops.set_setup_work_day_task(text,bigint,bigint,text,text,integer,integer,boolean)',
            'EXECUTE'
       )
       OR NOT has_function_privilege(
            'fieldwiring_app',
            'ops.record_setup_task_progress(text,bigint,bigint,text,integer,integer,text,text,boolean)',
            'EXECUTE'
       ) THEN
        RAISE EXCEPTION 'Legacy Setup command privilege contract is incomplete';
    END IF;
END
$preflight$;
SQL
echo "DATABASE PREFLIGHT: PASS"

PRE_MUTATION_FINGERPRINT="$(legacy_setup_fingerprint)"
if [[ "$PRE_MUTATION_FINGERPRINT" != "$LEGACY_BEFORE" ]]; then
    echo "FAIL: Setup business data changed during pre-deployment validation; stop before mutation"
    exit 12
fi
echo "PRE-MUTATION FINGERPRINT STABILITY: PASS"

echo
echo "--- Apply reviewed migration 050 ---"
psql_prod < "$M050"
DB_MIGRATION_COMMITTED=1
echo "MIGRATION 050: COMMITTED"

echo
echo "--- Validate migration 050 + legacy compatibility ---"
psql_prod <<'SQL'
DO $validate$
DECLARE
    v_work_days bigint;
    v_crew_a_days bigint;
BEGIN
    IF EXISTS (SELECT 1 FROM ops.setup_session WHERE season_year=2026) THEN
        RAISE EXCEPTION '#205 deployment created a 2026 Setup Session';
    END IF;

    IF to_regclass('ops.setup_session_task_dependency') IS NULL
       OR to_regclass('ops.setup_work_day_crew') IS NULL
       OR to_regclass('ops.setup_scheduling_work_order_gate') IS NULL THEN
        RAISE EXCEPTION 'Scheduling Board foundation tables/view are incomplete';
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_schema='ops' AND table_name='setup_work_day'
          AND column_name='setup_day_number' AND is_nullable='NO'
    ) OR NOT EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_schema='ops' AND table_name='setup_work_day_task'
          AND column_name='setup_work_day_task_id' AND is_nullable='NO'
    ) OR NOT EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_schema='ops' AND table_name='setup_task_progress'
          AND column_name='setup_work_day_task_id'
    ) THEN
        RAISE EXCEPTION 'Scheduling identity columns are incomplete';
    END IF;

    IF EXISTS (
        SELECT 1 FROM ops.setup_work_day
        WHERE setup_day_number IS NULL OR setup_day_number <= 0
    ) THEN
        RAISE EXCEPTION 'Setup Day Number backfill/constraint validation failed';
    END IF;

    IF EXISTS (
        SELECT 1 FROM ops.setup_session_task
        WHERE task_origin <> 'REUSABLE'
           OR setup_task_id IS NULL
           OR annual_task_name IS NULL
           OR annual_task_action_type IS NULL
           OR annual_readiness_state NOT IN ('READY','NOT_READY')
    ) THEN
        RAISE EXCEPTION 'Existing annual Setup snapshot backfill is incomplete';
    END IF;

    SELECT count(*) INTO v_work_days FROM ops.setup_work_day;
    SELECT count(DISTINCT setup_work_day_id) INTO v_crew_a_days
    FROM ops.setup_work_day_crew
    WHERE crew_number=1 AND crew_code='A';
    IF v_crew_a_days <> v_work_days THEN
        RAISE EXCEPTION 'Every existing Setup work day must have default Crew A';
    END IF;

    IF EXISTS (
        SELECT 1 FROM ops.setup_work_day_task
        WHERE setup_work_day_task_id IS NULL
           OR setup_work_day_crew_id IS NULL
    ) THEN
        RAISE EXCEPTION 'Existing scheduled work did not receive stable assignment/crew identity';
    END IF;

    IF to_regprocedure('ops.upsert_setup_work_day(text,integer,date,text,text)') IS NULL
       OR to_regprocedure('ops.upsert_setup_work_day(text,integer,date,integer,text,text,text,text)') IS NULL
       OR to_regprocedure('ops.set_setup_work_day_task(text,bigint,bigint,text,text,integer,integer,boolean)') IS NULL
       OR to_regprocedure('ops.record_setup_task_progress(text,bigint,bigint,text,integer,integer,text,text,boolean)') IS NULL THEN
        RAISE EXCEPTION 'Legacy/new command compatibility signatures are incomplete';
    END IF;

    IF NOT has_function_privilege(
            'fieldwiring_app',
            'ops.upsert_setup_work_day(text,integer,date,text,text)',
            'EXECUTE'
       )
       OR NOT has_function_privilege(
            'fieldwiring_app',
            'ops.upsert_setup_work_day(text,integer,date,integer,text,text,text,text)',
            'EXECUTE'
       )
       OR NOT has_function_privilege(
            'fieldwiring_app',
            'ops.set_setup_work_day_task(text,bigint,bigint,text,text,integer,integer,boolean)',
            'EXECUTE'
       )
       OR NOT has_function_privilege(
            'fieldwiring_app',
            'ops.record_setup_task_progress(text,bigint,bigint,text,integer,integer,text,text,boolean)',
            'EXECUTE'
       )
       OR NOT has_function_privilege(
            'fieldwiring_app',
            'ops.create_setup_work_day_assignment(text,bigint,bigint,text,bigint,integer)',
            'EXECUTE'
       )
       OR NOT has_function_privilege(
            'fieldwiring_app',
            'ops.update_setup_work_day_assignment(text,bigint,bigint,text,bigint,integer)',
            'EXECUTE'
       )
       OR NOT has_function_privilege(
            'fieldwiring_app',
            'ops.remove_setup_work_day_assignment(text,bigint)',
            'EXECUTE'
       )
       OR NOT has_table_privilege('fieldwiring_app','ops.setup_work_day_crew','SELECT')
       OR NOT has_table_privilege('fieldwiring_app','ops.setup_session_task_dependency','SELECT')
       OR NOT has_table_privilege('fieldwiring_app','ops.setup_scheduling_work_order_gate','SELECT') THEN
        RAISE EXCEPTION 'Scheduling Board least-privilege read/command contract is incomplete';
    END IF;

    IF has_table_privilege('fieldwiring_app','ops.setup_work_day_crew','INSERT')
       OR has_table_privilege('fieldwiring_app','ops.setup_work_day_crew','UPDATE')
       OR has_table_privilege('fieldwiring_app','ops.setup_work_day_crew','DELETE')
       OR has_table_privilege('fieldwiring_app','ops.setup_session_task_dependency','INSERT')
       OR has_table_privilege('fieldwiring_app','ops.setup_session_task_dependency','UPDATE')
       OR has_table_privilege('fieldwiring_app','ops.setup_session_task_dependency','DELETE')
       OR has_table_privilege('fieldwiring_app','ops.work_order','SELECT') THEN
        RAISE EXCEPTION 'Forbidden broad Scheduling Board table privilege detected';
    END IF;
END
$validate$;
SQL
echo "DATABASE CONTRACT VALIDATION: PASS"

POST_DB_FINGERPRINT="$(legacy_setup_fingerprint)"
echo "Legacy Setup business fingerprint before migration: $LEGACY_BEFORE"
echo "Legacy Setup business fingerprint after migration:  $POST_DB_FINGERPRINT"
if [[ "$POST_DB_FINGERPRINT" != "$LEGACY_BEFORE" ]]; then
    echo "FAIL: migration 050 changed pre-existing Setup business fields"
    exit 13
fi
echo "PASS: migration 050 preserved pre-existing Setup business fields"

echo
echo "--- Advance dedicated Setup Production checkout to exact accepted SHA ---"
sudo git -C "$SETUP_ROOT" merge --ff-only "$TARGET_SHA"
APP_ADVANCED=1
DEPLOYED_HEAD="$(sudo git -C "$SETUP_ROOT" rev-parse HEAD)"
if [[ "$DEPLOYED_HEAD" != "$TARGET_SHA" ]]; then
    echo "FAIL: deployed Setup checkout is $DEPLOYED_HEAD, expected $TARGET_SHA"
    exit 14
fi
echo "Setup checkout advanced exactly to $DEPLOYED_HEAD"

echo
echo "--- Restart and verify Setup V0.3.14 runtime ---"
restart_setup_service
SETUP_POST="$(curl -fsS http://192.168.5.9:8794/api/health)"
echo "Post-deploy Setup health: $SETUP_POST"
if [[ "$SETUP_POST" != *"\"status\":\"ok\""*    || "$SETUP_POST" != *"\"data_mode\":\"postgres\""*    || "$SETUP_POST" != *"\"version\":\"$EXPECTED_SETUP_VERSION\""* ]]; then
    echo "FAIL: Setup health/version does not match expected V0.3.14 runtime"
    exit 15
fi

curl -fsS http://192.168.5.9:8794/ | grep -Fq 'setup_scheduling_board.css?v=2026-09-18.4'
curl -fsS http://192.168.5.9:8794/ | grep -Fq 'setup_scheduling_board.js?v=2026-09-18.4'
echo "Scheduling Board production assets: PASS"

NEGATIVE_CODE="$(curl -sS -o "$NEGATIVE_BODY" -w '%{http_code}'     'http://192.168.5.9:8794/api/setup/scheduling-board?season_year=2026')"
echo "Direct unauthenticated Scheduling Board API status: $NEGATIVE_CODE"
if [[ "$NEGATIVE_CODE" != "401" ]]; then
    echo "FAIL: protected Scheduling Board API did not reject unauthenticated direct request"
    cat "$NEGATIVE_BODY" || true
    exit 16
fi
echo "PROTECTED SCHEDULING BOARD NEGATIVE PATH: PASS"

MANAGER_EMAIL="$(sudo docker exec "$PROD_CONTAINER"     psql -X -qAt -v ON_ERROR_STOP=1 -U "$DB_ACTOR" -d "$PROD_DB" -c "
        SELECT lower(u.email)
        FROM public.directus_users u
        JOIN ref.person p ON p.directus_user_id=u.id
        JOIN LATERAL ref.setup_browser_capabilities(u.email) c ON true
        WHERE u.status='active' AND c.can_admin_setup
        ORDER BY u.email
        LIMIT 1;
    ")"
[[ -n "$MANAGER_EMAIL" ]] || { echo "FAIL: no active Setup Administrator identity found"; exit 17; }

BOARD_2026="$(curl -fsS     -H "Cf-Access-Authenticated-User-Email: $MANAGER_EMAIL"     'http://192.168.5.9:8794/api/setup/scheduling-board?season_year=2026')"
echo "Authenticated 2026 Scheduling Board read: $BOARD_2026"
if [[ "$BOARD_2026" != *"\"session\":null"* ]]; then
    echo "FAIL: 2026 Scheduling Board should have no real annual Session before #145/#122 launch"
    exit 18
fi
echo "AUTHENTICATED SCHEDULING BOARD READ: PASS"

echo
echo "--- Live Setup regression ---"
sudo -u fieldwiring -H bash -c     "cd '$SETUP_ROOT' && '$PYTHON' -m pytest -q -p no:cacheprovider Setup/Application"
echo "LIVE SETUP REGRESSION: PASS"

echo
echo "--- Final Production invariants ---"
FINAL_HEAD="$(sudo git -C "$SETUP_ROOT" rev-parse HEAD)"
FINAL_STATUS="$(sudo git -C "$SETUP_ROOT" status --porcelain)"
FINAL_FINGERPRINT="$(legacy_setup_fingerprint)"
FINAL_2026="$(sudo docker exec "$PROD_CONTAINER"     psql -X -qAt -v ON_ERROR_STOP=1 -U "$DB_ACTOR" -d "$PROD_DB"     -c "SELECT count(*) FROM ops.setup_session WHERE season_year=2026;")"
FINAL_CREW_TABLE="$(sudo docker exec "$PROD_CONTAINER"     psql -X -qAt -v ON_ERROR_STOP=1 -U "$DB_ACTOR" -d "$PROD_DB"     -c "SELECT to_regclass('ops.setup_work_day_crew') IS NOT NULL;")"

echo "Final Setup SHA:                     $FINAL_HEAD"
echo "Final Setup legacy fingerprint:      $FINAL_FINGERPRINT"
echo "2026 Setup Sessions:                 $FINAL_2026"
echo "Scheduling crew foundation present:  $FINAL_CREW_TABLE"

[[ "$FINAL_HEAD" == "$TARGET_SHA" ]]
[[ -z "$FINAL_STATUS" ]]
[[ "$FINAL_FINGERPRINT" == "$LEGACY_BEFORE" ]]
[[ "$FINAL_2026" == "0" ]]
[[ "$FINAL_CREW_TABLE" == "t" ]]

SUCCESS=1
echo
echo "SETUP_205_PRODUCTION_DEPLOYMENT_PASS"
echo "Rollback archive:  $BACKUP_FILE"
echo "Rollback SHA256:   $BACKUP_SHA"
echo "Deployment report: $REPORT"
