#!/usr/bin/env bash
set -euo pipefail

PROD_CONTAINER="msb-postgres"
PROD_DB="msb"
DB_ACTOR="msbadmin"
REPO_ROOT="/opt/fieldwiring"
SETUP_ROOT="/opt/msb-setup"
SETUP_SERVICE="msb-setup.service"
DISPLAY_SERVICE="msb-display-folders.service"
GOOGLE_SERVICE="msb-setup-google-links.service"
FIELDWIRING_SERVICE="fieldwiring.service"
PROCEDURES_SERVICE="msb-procedures.service"
TARGET_REF="agent/setup-catalog-reconstruction-20260909"
TARGET_SHA="19239e3584a66913ecaa5f0406434be54618c303"
EXPECTED_SETUP_VERSION="V0.3.4-shared-season-guard-review"
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
BACKUP_DIR="/home/msbadmin/backups/setup-catalog"
STAMP="$(date +%Y%m%dT%H%M%S)"
BACKUP_FILE="$BACKUP_DIR/msb-pre-setup-catalog-$STAMP.dump"
REPORT="$HOME/setup-acceptance-reports/Setup_Catalog_Reconstruction_Production_Deploy_${STAMP}.txt"
CANDIDATE_WORKTREE="/tmp/msb-setup-catalog-production-candidate-$STAMP"
CONTAINER_BATCH_ROOT="/tmp/setup-catalog-production-$STAMP"
NEGATIVE_BODY="/tmp/msb-setup-catalog-negative-$STAMP.txt"
M023=""
M024=""
BATCH_DIR=""
VALIDATION=""
PROD_BEFORE=""
POST_CATALOG_FP=""
OLD_HEAD=""
M023_APPLIED=0
CATALOG_COMMITTED=0
APP_ADVANCED=0
SUCCESS=0
BACKUP_CREATED=0

mkdir -p "$(dirname "$REPORT")"
exec > >(tee "$REPORT") 2>&1

echo "========== SETUP CATALOG RECONSTRUCTION PRODUCTION DEPLOYMENT =========="
echo "Report:      $REPORT"
echo "Target SHA:  $TARGET_SHA"
echo "Target ref:  $TARGET_REF"
echo "Setup root:  $SETUP_ROOT"
echo "Migrations:  023 + 024 only"
echo

prod_fingerprint() {
    sudo docker exec "$PROD_CONTAINER" \
        psql -X -qAt -v ON_ERROR_STOP=1 -U "$DB_ACTOR" -d "$PROD_DB" -c "
            SELECT md5(
                coalesce((SELECT string_agg(row_to_json(t)::text, '' ORDER BY t.setup_task_id) FROM ref.setup_task t), '') || '|' ||
                coalesce((SELECT string_agg(row_to_json(d)::text, '' ORDER BY d.setup_task_id, d.prerequisite_setup_task_id) FROM ref.setup_task_dependency d), '') || '|' ||
                coalesce((SELECT string_agg(row_to_json(td)::text, '' ORDER BY td.setup_task_id, td.display_id) FROM ref.setup_task_display td), '') || '|' ||
                coalesce((SELECT string_agg(row_to_json(tc)::text, '' ORDER BY tc.setup_task_id, tc.container_id) FROM ref.setup_task_container_support tc), '') || '|' ||
                coalesce((SELECT string_agg(row_to_json(c)::text, '' ORDER BY c.setup_task_id, c.person_id) FROM ref.setup_task_captain c), '') || '|' ||
                coalesce((SELECT string_agg(row_to_json(tr)::text, '' ORDER BY tr.setup_task_id, tr.setup_resource_id) FROM ref.setup_task_resource tr), '') || '|' ||
                coalesce((SELECT string_agg(row_to_json(s)::text, '' ORDER BY s.setup_session_id) FROM ops.setup_session s), '') || '|' ||
                coalesce((SELECT string_agg(row_to_json(st)::text, '' ORDER BY st.setup_session_task_id) FROM ops.setup_session_task st), '') || '|' ||
                coalesce((SELECT string_agg(row_to_json(wd)::text, '' ORDER BY wd.setup_work_day_id) FROM ops.setup_work_day wd), '') || '|' ||
                coalesce((SELECT string_agg(row_to_json(wdt)::text, '' ORDER BY wdt.setup_work_day_id, wdt.setup_session_task_id) FROM ops.setup_work_day_task wdt), '') || '|' ||
                coalesce((SELECT string_agg(row_to_json(p)::text, '' ORDER BY p.setup_task_progress_id) FROM ops.setup_task_progress p), '') || '|' ||
                coalesce((SELECT string_agg(row_to_json(me)::text, '' ORDER BY me.setup_movement_event_id) FROM ops.setup_movement_event me), '')
            );
        "
}

psql_prod() {
    sudo docker exec -i "$PROD_CONTAINER" \
        psql -X -v ON_ERROR_STOP=1 -U "$DB_ACTOR" -d "$PROD_DB" "$@"
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

restart_setup_service() {
    sudo systemctl restart "$SETUP_SERVICE"
    wait_setup_ready
}

rollback_023_only() {
    echo "Rolling back schema-only migration 023 because catalog migration 024 did not commit..."
    psql_prod <<'SQL'
BEGIN;
DROP FUNCTION IF EXISTS ref.set_setup_task_effort(text,bigint,text);
ALTER TABLE ref.setup_task DROP CONSTRAINT IF EXISTS ck_setup_task_effort_level;
ALTER TABLE ref.setup_task DROP COLUMN IF EXISTS effort_level;
COMMIT;
SQL
}

cleanup() {
    status=$?
    trap - EXIT INT TERM
    set +e

    if [[ "$status" -ne 0 && "$SUCCESS" -ne 1 ]]; then
        echo
        echo "--- FAIL-CLOSED DEPLOYMENT CLEANUP ---"
        if [[ "$APP_ADVANCED" -eq 1 && -n "$OLD_HEAD" ]]; then
            echo "Restoring Setup checkout to $OLD_HEAD"
            sudo git -C "$SETUP_ROOT" reset --hard "$OLD_HEAD" || true
            restart_setup_service || true
        fi
        if [[ "$M023_APPLIED" -eq 1 && "$CATALOG_COMMITTED" -eq 0 ]]; then
            rollback_023_only || true
        elif [[ "$CATALOG_COMMITTED" -eq 1 ]]; then
            echo "NOTE: accepted catalog migration 024 committed before this later failure."
            echo "The catalog is not automatically reversed; validated rollback archive is retained for governed recovery review."
        fi
    fi

    if sudo git -C "$REPO_ROOT" worktree list --porcelain 2>/dev/null | grep -Fq "worktree $CANDIDATE_WORKTREE"; then
        sudo git -C "$REPO_ROOT" worktree remove --force "$CANDIDATE_WORKTREE" >/dev/null 2>&1 || true
    fi
    sudo docker exec "$PROD_CONTAINER" rm -rf "$CONTAINER_BATCH_ROOT" >/dev/null 2>&1 || true
    rm -f "$NEGATIVE_BODY" >/dev/null 2>&1 || true
    rm -rf "$SCRIPT_DIR" >/dev/null 2>&1 || true

    echo
    echo "--- Production Setup final-state check ---"
    if [[ -n "$PROD_BEFORE" ]]; then
        FINAL_FP="$(prod_fingerprint 2>/dev/null || true)"
        echo "Before deployment: $PROD_BEFORE"
        echo "Final observed:    $FINAL_FP"
        if [[ "$CATALOG_COMMITTED" -eq 0 ]]; then
            if [[ -z "$FINAL_FP" || "$FINAL_FP" != "$PROD_BEFORE" ]]; then
                echo "FAIL: Production Setup fingerprint changed before catalog commit"
                status=97
            else
                echo "PASS: Production Setup fingerprint unchanged before catalog commit"
            fi
        elif [[ -n "$POST_CATALOG_FP" ]]; then
            if [[ -z "$FINAL_FP" || "$FINAL_FP" != "$POST_CATALOG_FP" ]]; then
                echo "FAIL: Production Setup fingerprint changed after accepted catalog commit"
                status=98
            else
                echo "PASS: Production Setup fingerprint equals accepted post-catalog state"
            fi
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
trap cleanup EXIT INT TERM

sudo -v
mkdir -p "$BACKUP_DIR" "$(dirname "$REPORT")"

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

OLD_HEAD="$(sudo git -C "$SETUP_ROOT" rev-parse HEAD)"
echo "Verified live Setup checkout: $OLD_HEAD"
if [[ -n "$(sudo git -C "$SETUP_ROOT" status --porcelain)" ]]; then
    echo "FAIL: live Setup checkout has uncommitted changes"
    sudo git -C "$SETUP_ROOT" status -sb
    exit 5
fi

for service in "$SETUP_SERVICE" "$DISPLAY_SERVICE" "$GOOGLE_SERVICE" "$FIELDWIRING_SERVICE" "$PROCEDURES_SERVICE"; do
    if ! systemctl is-active --quiet "$service"; then
        echo "FAIL: required Production service is not active before deployment: $service"
        exit 6
    fi
done

SETUP_PRE="$(curl -fsS http://192.168.5.9:8794/api/health)"
FW_PRE="$(curl -fsS http://192.168.5.9:8790/api/health)"
PR_PRE="$(curl -fsS http://192.168.5.9:8792/api/health)"
echo "Pre-deploy Setup health:       $SETUP_PRE"
echo "Pre-deploy FieldWiring health: $FW_PRE"
echo "Pre-deploy Procedures health:  $PR_PRE"

PROD_BEFORE="$(prod_fingerprint)"
if [[ -z "$PROD_BEFORE" ]]; then
    echo "FAIL: Production Setup fingerprint is empty"
    exit 7
fi
echo "Pre-deploy Setup fingerprint: $PROD_BEFORE"

echo
echo "--- Fetch and verify exact operator-approved target ---"
sudo git -C "$REPO_ROOT" fetch origin "$TARGET_REF"
sudo git -C "$REPO_ROOT" cat-file -e "$TARGET_SHA^{commit}"
if ! sudo git -C "$REPO_ROOT" merge-base --is-ancestor "$OLD_HEAD" "$TARGET_SHA"; then
    echo "FAIL: accepted Setup target is not a fast-forward descendant of verified live Setup checkout"
    echo "Live:   $OLD_HEAD"
    echo "Target: $TARGET_SHA"
    exit 8
fi
echo "Verified fast-forward ancestry: $OLD_HEAD -> $TARGET_SHA"

echo
echo "--- Detached Production-runtime candidate regression ---"
sudo git -C "$REPO_ROOT" worktree add --detach "$CANDIDATE_WORKTREE" "$TARGET_SHA"
M023="$CANDIDATE_WORKTREE/Setup/Database/023_add_setup_task_effort.sql"
M024="$CANDIDATE_WORKTREE/Setup/Database/024_reconstruct_setup_catalog_from_reviewed_one_list.sql"
BATCH_DIR="$CANDIDATE_WORKTREE/Setup/Database/reconstruction"
VALIDATION="$CANDIDATE_WORKTREE/Setup/Acceptance/setup_catalog_reconstruction_disposable_validation.sql"
for required_file in \
    "$M023" "$M024" "$VALIDATION" \
    "$BATCH_DIR/024_catalog_batch_01.sql" \
    "$BATCH_DIR/024_catalog_batch_02.sql" \
    "$BATCH_DIR/024_catalog_batch_03.sql" \
    "$BATCH_DIR/024_catalog_batch_04.sql" \
    "$BATCH_DIR/024_catalog_batch_05.sql"; do
    if [[ ! -s "$required_file" ]]; then
        echo "FAIL: accepted target is missing reviewed catalog file $required_file"
        exit 9
    fi
done
sha256sum "$M023" "$M024" "$BATCH_DIR"/024_catalog_batch_0*.sql "$VALIDATION"

sudo -u fieldwiring -H bash -c \
    "cd '$CANDIDATE_WORKTREE' && /opt/fieldwiring/.venv/bin/python -m pytest -q -p no:cacheprovider Setup/Application"
echo "DETACHED SETUP CATALOG CANDIDATE REGRESSION: PASS"

echo
echo "--- Create and verify rollback PostgreSQL archive ---"
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
echo "--- Production database preflight ---"
psql_prod <<'SQL'
DO $block$
DECLARE
    v_active integer;
BEGIN
    IF EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_schema='ref' AND table_name='setup_task' AND column_name='effort_level'
    ) THEN
        RAISE EXCEPTION 'effort_level already exists; stop for partial-deployment review';
    END IF;
    IF to_regprocedure('ref.set_setup_task_effort(text,bigint,text)') IS NOT NULL THEN
        RAISE EXCEPTION 'set_setup_task_effort already exists; stop for partial-deployment review';
    END IF;
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_schema='ref' AND table_name='setup_task' AND column_name='baseline_plan_order'
    ) THEN
        RAISE EXCEPTION 'Setup planning order baseline is missing';
    END IF;
    IF EXISTS (SELECT 1 FROM ops.setup_session WHERE season_year >= 2026) THEN
        RAISE EXCEPTION 'A 2026-or-later Setup Session already exists';
    END IF;
    SELECT count(*) INTO v_active FROM ref.setup_task WHERE active_flag;
    IF v_active <> 68 THEN
        RAISE EXCEPTION 'Expected 68 active reusable tasks before catalog reconstruction, found %', v_active;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM ref.setup_task WHERE setup_task_id=40 AND task_name='Deliver Command Center' AND active_flag)
       OR NOT EXISTS (SELECT 1 FROM ref.setup_task WHERE setup_task_id=51 AND task_name='Deliver and Set Up Command Center Trailer' AND active_flag)
       OR NOT EXISTS (SELECT 1 FROM ref.setup_task WHERE setup_task_id=58 AND task_name='light' AND active_flag) THEN
        RAISE EXCEPTION 'Reviewed 68-task baseline identities do not match Production';
    END IF;
    IF has_table_privilege('fieldwiring_app','ref.setup_task','UPDATE') THEN
        RAISE EXCEPTION 'fieldwiring_app unexpectedly has broad ref.setup_task UPDATE';
    END IF;
END
$block$;
SQL
echo "DATABASE PREFLIGHT: PASS"

echo
echo "--- Apply accepted Setup migrations 023 and 024 ---"
psql_prod < "$M023"
M023_APPLIED=1

echo "Migration 023 reusable effort metadata: PASS"

sudo docker exec "$PROD_CONTAINER" mkdir -p "$CONTAINER_BATCH_ROOT/reconstruction"
for batch in "$BATCH_DIR"/024_catalog_batch_0*.sql; do
    sudo docker cp "$batch" "$PROD_CONTAINER:$CONTAINER_BATCH_ROOT/reconstruction/$(basename "$batch")"
done
sudo docker exec -w "$CONTAINER_BATCH_ROOT" -i "$PROD_CONTAINER" \
    psql -X -v ON_ERROR_STOP=1 -U "$DB_ACTOR" -d "$PROD_DB" < "$M024"
CATALOG_COMMITTED=1

echo "Migration 024 reviewed reusable catalog reconstruction: PASS"
psql_prod < "$VALIDATION"
echo "PRODUCTION SETUP CATALOG VALIDATION: PASS"

POST_CATALOG_FP="$(prod_fingerprint)"
if [[ -z "$POST_CATALOG_FP" || "$POST_CATALOG_FP" == "$PROD_BEFORE" ]]; then
    echo "FAIL: accepted catalog migration did not produce the expected governed-data change"
    exit 10
fi
echo "Accepted post-catalog fingerprint: $POST_CATALOG_FP"

echo
echo "--- Fast-forward dedicated Setup Production checkout ---"
sudo git -C "$SETUP_ROOT" merge --ff-only "$TARGET_SHA"
APP_ADVANCED=1
DEPLOYED_HEAD="$(sudo git -C "$SETUP_ROOT" rev-parse HEAD)"
if [[ "$DEPLOYED_HEAD" != "$TARGET_SHA" ]]; then
    echo "FAIL: deployed Setup checkout is $DEPLOYED_HEAD, expected $TARGET_SHA"
    exit 11
fi
if [[ -n "$(sudo git -C "$SETUP_ROOT" status --porcelain)" ]]; then
    echo "FAIL: deployed Setup checkout is not clean"
    exit 12
fi
echo "Setup checkout advanced exactly to $DEPLOYED_HEAD"

echo
echo "--- Restart and verify Setup Production runtime ---"
restart_setup_service
SETUP_POST="$(curl -fsS http://192.168.5.9:8794/api/health)"
echo "Post-deploy Setup health: $SETUP_POST"
if [[ "$SETUP_POST" != *"\"status\":\"ok\""* \
   || "$SETUP_POST" != *"\"data_mode\":\"postgres\""* \
   || "$SETUP_POST" != *"\"version\":\"$EXPECTED_SETUP_VERSION\""* ]]; then
    echo "FAIL: Setup health payload does not match accepted Production runtime contract"
    exit 13
fi

sudo -u fieldwiring -H bash -c \
    "cd '$SETUP_ROOT' && /opt/fieldwiring/.venv/bin/python -m pytest -q -p no:cacheprovider Setup/Application"
echo "LIVE SETUP APPLICATION REGRESSION: PASS"

NEGATIVE_STATUS="$(curl -sS -o "$NEGATIVE_BODY" -w '%{http_code}' http://192.168.5.9:8794/api/setup/access || true)"
if [[ "$NEGATIVE_STATUS" != "401" ]]; then
    echo "FAIL: direct protected Setup access without Cloudflare identity returned HTTP $NEGATIVE_STATUS, expected 401"
    cat "$NEGATIVE_BODY" || true
    exit 14
fi
echo "Protected Setup negative-path HTTP 401: PASS"

PUBLIC_HEALTH="$(curl -sk --fail --resolve my.sheboyganlights.org:443:192.168.5.4 https://my.sheboyganlights.org/setup/api/health)"
echo "Synology /setup/ health: $PUBLIC_HEALTH"

for service in "$DISPLAY_SERVICE" "$GOOGLE_SERVICE" "$FIELDWIRING_SERVICE" "$PROCEDURES_SERVICE"; do
    if ! systemctl is-active --quiet "$service"; then
        echo "FAIL: adjacent required Production service is not active after Setup deployment: $service"
        exit 15
    fi
done

echo
echo "--- Final Production invariants ---"
FINAL_HEAD="$(sudo git -C "$SETUP_ROOT" rev-parse HEAD)"
FINAL_FP="$(prod_fingerprint)"
echo "Final Setup checkout:    $FINAL_HEAD"
echo "Final Setup fingerprint: $FINAL_FP"
if [[ "$FINAL_HEAD" != "$TARGET_SHA" ]]; then
    echo "FAIL: final Setup checkout no longer equals accepted target"
    exit 16
fi
if [[ "$FINAL_FP" != "$POST_CATALOG_FP" ]]; then
    echo "FAIL: final governed Setup fingerprint differs from accepted post-catalog fingerprint"
    exit 17
fi

psql_prod -qAt -c "
SELECT 'active_reusable_tasks=' || count(*) FROM ref.setup_task WHERE active_flag;
SELECT 'total_reusable_task_rows=' || count(*) FROM ref.setup_task;
SELECT 'dependencies=' || count(*) FROM ref.setup_task_dependency;
SELECT '2026_sessions=' || count(*) FROM ops.setup_session WHERE season_year >= 2026;
SELECT 'effort_light=' || count(*) FROM ref.setup_task WHERE active_flag AND effort_level='LIGHT';
SELECT 'effort_moderate=' || count(*) FROM ref.setup_task WHERE active_flag AND effort_level='MODERATE';
SELECT 'effort_heavy=' || count(*) FROM ref.setup_task WHERE active_flag AND effort_level='HEAVY';
SELECT 'effort_unreviewed=' || count(*) FROM ref.setup_task WHERE active_flag AND effort_level IS NULL;
"

SUCCESS=1
echo
echo "SETUP_CATALOG_RECONSTRUCTION_PRODUCTION_DEPLOYMENT_PASS"
