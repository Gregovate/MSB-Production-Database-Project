#!/usr/bin/env bash
set -euo pipefail

PROD_CONTAINER="msb-postgres"
PROD_DB="msb"
DB_ACTOR="msbadmin"
REPO_ROOT="/opt/fieldwiring"
SETUP_ROOT="/opt/msb-setup"
PYTHON="/opt/fieldwiring/.venv/bin/python"
SETUP_SERVICE="msb-setup.service"

DIRECTUS_CONTAINER="msb-directus"
DIRECTUS_IMAGE="directus/directus:11.17.1"
SCAN_LIVE_PATH="/opt/directus/extensions/directus-extension-scan/dist/index.js"
EXPECTED_LIVE_SCAN_SHA256="3457efa15f461b774ef20462f57807d36cb848cac67bdcffcc2a8284c2dc2f96"

TARGET_REF="agent/setup-88-pick-mode-movement"
TARGET_SHA="7da6828d7b884ee5bb12123dab647bd6fadfba50"
EXPECTED_PRE_VERSION="V0.3.22-pick-list-delay"
EXPECTED_POST_VERSION="V0.3.29-pick-clarity"

MIGRATION_REL="Setup/Database/065_add_setup_movement_capture.sql"
MIGRATION_BLOB="2738065a6fc3cb84858e401de5fae9bd6ae35dcc"
VALIDATION_REL="Setup/Acceptance/setup_88_movement_capture_disposable_validation.sql"
VALIDATION_BLOB="fc152c305dc0bf7a056aeff60aae3615b06b96d4"
SCAN_SRC_REL="Scan/directus-extension-scan/src/index.js"
SCAN_DIST_REL="Scan/directus-extension-scan/dist/index.js"
SCAN_BLOB="4c2810bf33087d33803456d4b73a4ff1dc86760b"

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
STAMP="$(date +%Y%m%dT%H%M%S)"
BACKUP_DIR="/home/msbadmin/backups/setup-88"
SCAN_BACKUP_DIR="/home/msbadmin/backups/directus-scan"
REPORT_DIR="/home/msbadmin/setup-deployment-reports"
BACKUP_FILE="$BACKUP_DIR/msb-pre-setup-88-v0329-$STAMP.dump"
SCAN_ROLLBACK="$SCAN_BACKUP_DIR/pre-setup-88-v0329-$STAMP-index.js"
REPORT="$REPORT_DIR/Setup_88_V0329_Production_Deploy_$STAMP.txt"
CANDIDATE_WORKTREE="/tmp/msb-setup-88-v0329-candidate-$STAMP"
DETACHED_PYCACHE="/tmp/msb-setup-88-v0329-detached-pycache-$STAMP"
LIVE_PYCACHE="/tmp/msb-setup-88-v0329-live-pycache-$STAMP"
STAGED_SCAN="/tmp/directus-scan-index-$TARGET_SHA-$STAMP.js"
SCAN_CONTAINER_TMP="/tmp/directus-scan-candidate-$STAMP.js"
NEGATIVE_BODY="/tmp/msb-setup-88-negative-$STAMP.json"

OLD_SETUP_HEAD=""
SHARED_HEAD_BEFORE=""
INITIAL_FINGERPRINT=""
FROZEN_FINGERPRINT=""
INITIAL_2026_COUNT=""
INITIAL_MOVEMENT_EVENTS=""
INITIAL_CONTAINER_STATE=""
INITIAL_DISPLAY_STATE=""
BACKUP_CREATED=0
DB_MIGRATION_COMMITTED=0
SETUP_ADVANCED=0
SCAN_ADVANCED=0
SETUP_STOPPED=0
SUCCESS=0
STAGED_SCAN_SHA=""
BACKUP_SHA=""
SCAN_ROLLBACK_SHA=""

mkdir -p "$REPORT_DIR"
exec > >(tee "$REPORT") 2>&1

echo "========== SETUP #88 V0.3.29 FIELD MOVEMENT PRODUCTION DEPLOYMENT =========="
echo "Authority: Gregovate/MSB-Server-Management — docs/server/Production_Database_Change_Deployment_Runbook.md"
echo "Authority: Gregovate/MSB-Server-Management — docs/server/Setup_Production_Runtime.md"
echo "Authority: Gregovate/MSB-Server-Management — docs/directus/Display_Scan_Extension_Deployment_and_Recovery.md"
echo "Authority: Gregovate/MSB-Server-Management — docs/directus/Directus_Restart_Procedure.md"
echo "Exact accepted application SHA: $TARGET_SHA"
echo "Expected Setup version: $EXPECTED_PRE_VERSION -> $EXPECTED_POST_VERSION"
echo "Migration: $MIGRATION_REL"
echo "Migration blob: $MIGRATION_BLOB"
echo "Scan artifact blob: $SCAN_BLOB"
echo "Expected current live Scan SHA256: $EXPECTED_LIVE_SCAN_SHA256"
echo "Report: $REPORT"
echo

psql_prod() {
    sudo docker exec -i "$PROD_CONTAINER" \
        psql -X -v ON_ERROR_STOP=1 -U "$DB_ACTOR" -d "$PROD_DB" "$@"
}

setup_business_fingerprint() {
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
                coalesce((SELECT string_agg(row_to_json(wc)::text, '' ORDER BY wc.setup_work_day_crew_id) FROM ops.setup_work_day_crew wc), '') || '|' ||
                coalesce((SELECT string_agg(row_to_json(wdt)::text, '' ORDER BY wdt.setup_work_day_task_id) FROM ops.setup_work_day_task wdt), '') || '|' ||
                coalesce((SELECT string_agg(row_to_json(p)::text, '' ORDER BY p.setup_task_progress_id) FROM ops.setup_task_progress p), '') || '|' ||
                coalesce((
                    SELECT string_agg(row_to_json(x)::text, '' ORDER BY x.setup_movement_event_id)
                    FROM (
                        SELECT setup_movement_event_id, setup_session_id, event_type, setup_session_task_id,
                               container_id, destination_stage_id, destination_location_note, occurred_at,
                               notes, created_at, created_by, updated_at, updated_by,
                               created_by_person_id, updated_by_person_id
                        FROM ops.setup_movement_event
                    ) x
                ), '') || '|' ||
                coalesce((
                    SELECT string_agg(row_to_json(x)::text, '' ORDER BY x.setup_session_id, x.container_id)
                    FROM (
                        SELECT setup_session_id, container_id, current_stage_id, current_location_note,
                               last_movement_event_id, created_at, created_by, updated_at, updated_by,
                               created_by_person_id, updated_by_person_id
                        FROM ops.setup_container_state
                    ) x
                ), '') || '|' ||
                coalesce((
                    SELECT string_agg(row_to_json(x)::text, '' ORDER BY x.setup_session_id, x.display_id)
                    FROM (
                        SELECT setup_session_id, display_id, position_mode, current_stage_id,
                               current_location_note, verified_present_at, verified_present_by_person_id,
                               last_movement_event_id, created_at, created_by, updated_at, updated_by,
                               created_by_person_id, updated_by_person_id
                        FROM ops.setup_display_state
                    ) x
                ), '') || '|' ||
                coalesce((SELECT string_agg(row_to_json(o)::text, '' ORDER BY o.setup_pick_list_override_id) FROM ops.setup_pick_list_override o), '') || '|' ||
                coalesce((SELECT string_agg(row_to_json(d)::text, '' ORDER BY d.setup_pick_list_delay_id) FROM ops.setup_pick_list_delay d), '')
            );
        "
}

setup_2026_count() {
    sudo docker exec "$PROD_CONTAINER" \
        psql -X -qAt -v ON_ERROR_STOP=1 -U "$DB_ACTOR" -d "$PROD_DB" \
        -c "SELECT count(*) FROM ops.setup_session WHERE season_year=2026;"
}

table_count() {
    local rel="$1"
    sudo docker exec "$PROD_CONTAINER" \
        psql -X -qAt -v ON_ERROR_STOP=1 -U "$DB_ACTOR" -d "$PROD_DB" \
        -c "SELECT count(*) FROM $rel;"
}

new_movement_evidence_count() {
    sudo docker exec "$PROD_CONTAINER" \
        psql -X -qAt -v ON_ERROR_STOP=1 -U "$DB_ACTOR" -d "$PROD_DB" -c "
            SELECT
                (SELECT count(*) FROM ops.setup_movement_event WHERE client_event_id IS NOT NULL)
              + (SELECT count(*) FROM ops.setup_container_state WHERE movement_status IS NOT NULL)
              + (SELECT count(*) FROM ops.setup_display_state WHERE movement_status IS NOT NULL);
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

restart_directus() {
    sudo docker restart "$DIRECTUS_CONTAINER" >/dev/null
    for _ in $(seq 1 90); do
        if [[ "$(sudo docker inspect "$DIRECTUS_CONTAINER" --format '{{.State.Running}}' 2>/dev/null || true)" == "true" ]] \
           && curl -fsS http://127.0.0.1:8055/scan/ >/dev/null 2>&1; then
            return 0
        fi
        sleep 1
    done
    return 1
}

cleanup() {
    status=$?
    trap - EXIT HUP INT TERM
    set +e

    if [[ "$status" -ne 0 && "$SUCCESS" -ne 1 ]]; then
        echo
        echo "--- FAIL-CLOSED RECOVERY ---"

        if [[ "$SCAN_ADVANCED" -eq 1 && -s "$SCAN_ROLLBACK" ]]; then
            echo "Restoring immediately preceding Scan artifact"
            sudo cp -p "$SCAN_ROLLBACK" "$SCAN_LIVE_PATH" || true
            restart_directus || true
            SCAN_ADVANCED=0
            echo "Scan artifact rollback attempted."
        fi

        if [[ "$SETUP_ADVANCED" -eq 1 && -n "$OLD_SETUP_HEAD" ]]; then
            echo "Restoring /opt/msb-setup to prior SHA $OLD_SETUP_HEAD"
            sudo git -C "$SETUP_ROOT" checkout --detach "$OLD_SETUP_HEAD" || true
            SETUP_ADVANCED=0
        fi

        if [[ "$SETUP_STOPPED" -eq 1 || -n "$OLD_SETUP_HEAD" ]]; then
            echo "Restarting Setup after fail-closed recovery"
            restart_setup || true
        fi

        if [[ "$DB_MIGRATION_COMMITTED" -eq 1 ]]; then
            echo "Migration 065 reached committed state and is intentionally not auto-restored."
            echo "Reason: it alters the existing movement schema; full archive restore could erase unrelated Production writes."
            echo "Use the retained validated PostgreSQL archive only through a separately governed recovery decision."
        else
            echo "Migration 065 did not reach committed-success state."
        fi
    fi

    sudo docker exec "$DIRECTUS_CONTAINER" rm -f "$SCAN_CONTAINER_TMP" >/dev/null 2>&1 || true

    if sudo git -C "$REPO_ROOT" worktree list --porcelain 2>/dev/null | grep -Fq "worktree $CANDIDATE_WORKTREE"; then
        sudo git -C "$REPO_ROOT" worktree remove --force "$CANDIDATE_WORKTREE" >/dev/null 2>&1 || true
    fi
    sudo git -C "$REPO_ROOT" worktree prune >/dev/null 2>&1 || true
    sudo rm -rf "$DETACHED_PYCACHE" "$LIVE_PYCACHE" >/dev/null 2>&1 || true
    rm -f "$STAGED_SCAN" "$NEGATIVE_BODY" >/dev/null 2>&1 || true
    rm -rf "$SCRIPT_DIR" >/dev/null 2>&1 || true

    echo
    echo "--- Production after-check ---"
    if [[ -n "$FROZEN_FINGERPRINT" ]]; then
        AFTER_FINGERPRINT="$(setup_business_fingerprint 2>/dev/null || true)"
        echo "Frozen Setup business fingerprint: $FROZEN_FINGERPRINT"
        echo "Final Setup business fingerprint:  $AFTER_FINGERPRINT"
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

    if [[ -s "$SCAN_ROLLBACK" ]]; then
        echo "Immediately preceding Scan artifact retained at: $SCAN_ROLLBACK"
        echo "Scan rollback SHA256: ${SCAN_ROLLBACK_SHA:-unknown}"
    else
        echo "Scan rollback artifact: not created before this stop"
    fi

    echo "Deployment report retained at: $REPORT"
    echo "Exit status: $status"
    exit "$status"
}
trap cleanup EXIT HUP INT TERM

sudo -v
mkdir -p "$BACKUP_DIR" "$SCAN_BACKUP_DIR" "$REPORT_DIR"

echo "--- Verify current Production runtime ---"
if ! sudo docker inspect "$PROD_CONTAINER" >/dev/null 2>&1; then
    echo "FAIL: Production PostgreSQL container not found"
    exit 2
fi
if [[ "$(sudo docker inspect "$PROD_CONTAINER" --format '{{.Config.Image}}')" != "postgis/postgis:16-3.5" ]]; then
    echo "FAIL: Production PostgreSQL image mismatch"
    exit 3
fi
if ! sudo docker inspect "$DIRECTUS_CONTAINER" >/dev/null 2>&1; then
    echo "FAIL: Directus container not found"
    exit 4
fi
if [[ "$(sudo docker inspect "$DIRECTUS_CONTAINER" --format '{{.Config.Image}}')" != "$DIRECTUS_IMAGE" ]]; then
    echo "FAIL: Directus image differs from documented $DIRECTUS_IMAGE"
    exit 5
fi
if ! sudo git -C "$REPO_ROOT" worktree list --porcelain | grep -Fq "worktree $SETUP_ROOT"; then
    echo "FAIL: $SETUP_ROOT is not a registered worktree of $REPO_ROOT"
    exit 6
fi
if [[ -n "$(sudo git -C "$REPO_ROOT" status --porcelain)" ]]; then
    echo "FAIL: shared repository checkout has uncommitted changes"
    sudo git -C "$REPO_ROOT" status -sb
    exit 7
fi
if [[ -n "$(sudo git -C "$SETUP_ROOT" status --porcelain)" ]]; then
    echo "FAIL: live Setup checkout has uncommitted changes"
    sudo git -C "$SETUP_ROOT" status -sb
    exit 8
fi
if ! systemctl is-active --quiet "$SETUP_SERVICE"; then
    echo "FAIL: $SETUP_SERVICE is not active before deployment"
    exit 9
fi
if [[ "$(sudo docker inspect "$DIRECTUS_CONTAINER" --format '{{.State.Running}}')" != "true" ]]; then
    echo "FAIL: $DIRECTUS_CONTAINER is not running before deployment"
    exit 10
fi
if [[ ! -s "$SCAN_LIVE_PATH" ]]; then
    echo "FAIL: live Scan artifact is missing: $SCAN_LIVE_PATH"
    exit 11
fi

OLD_SETUP_HEAD="$(sudo git -C "$SETUP_ROOT" rev-parse HEAD)"
SHARED_HEAD_BEFORE="$(sudo git -C "$REPO_ROOT" rev-parse HEAD)"
echo "Verified live Setup checkout: $OLD_SETUP_HEAD"
echo "Shared repository checkout:    $SHARED_HEAD_BEFORE"

SETUP_PRE="$(curl -fsS http://192.168.5.9:8794/api/health)"
echo "Pre-deploy Setup health: $SETUP_PRE"
if [[ "$SETUP_PRE" != *"\"status\":\"ok\""* \
   || "$SETUP_PRE" != *"\"data_mode\":\"postgres\""* \
   || "$SETUP_PRE" != *"\"version\":\"$EXPECTED_PRE_VERSION\""* ]]; then
    echo "FAIL: live Setup pre-version/health is not $EXPECTED_PRE_VERSION"
    exit 12
fi

LIVE_SCAN_SHA="$(sha256sum "$SCAN_LIVE_PATH" | awk '{print $1}')"
echo "Current live Scan SHA256: $LIVE_SCAN_SHA"
if [[ "$LIVE_SCAN_SHA" != "$EXPECTED_LIVE_SCAN_SHA256" ]]; then
    echo "FAIL: live Scan hash differs from documented accepted baseline"
    echo "Expected: $EXPECTED_LIVE_SCAN_SHA256"
    echo "Actual:   $LIVE_SCAN_SHA"
    exit 13
fi
echo "LIVE SCAN HASH BASELINE: PASS"

INITIAL_FINGERPRINT="$(setup_business_fingerprint)"
INITIAL_2026_COUNT="$(setup_2026_count)"
INITIAL_MOVEMENT_EVENTS="$(table_count ops.setup_movement_event)"
INITIAL_CONTAINER_STATE="$(table_count ops.setup_container_state)"
INITIAL_DISPLAY_STATE="$(table_count ops.setup_display_state)"
echo "Initial Setup business fingerprint: $INITIAL_FINGERPRINT"
echo "Initial 2026 Setup Session count:    $INITIAL_2026_COUNT"
echo "Initial movement events:             $INITIAL_MOVEMENT_EVENTS"
echo "Initial Container state rows:        $INITIAL_CONTAINER_STATE"
echo "Initial Display state rows:          $INITIAL_DISPLAY_STATE"
if [[ "$INITIAL_2026_COUNT" != "1" ]]; then
    echo "FAIL: expected exactly one live 2026 Setup Session"
    exit 14
fi

echo
echo "--- Fetch and verify exact accepted target ---"
sudo git -C "$REPO_ROOT" fetch origin "$TARGET_REF:refs/remotes/origin/$TARGET_REF"
sudo git -C "$REPO_ROOT" cat-file -e "$TARGET_SHA^{commit}"
if ! sudo git -C "$REPO_ROOT" merge-base --is-ancestor "$TARGET_SHA" "origin/$TARGET_REF"; then
    echo "FAIL: exact accepted target is not contained in origin/$TARGET_REF"
    exit 15
fi
if ! sudo git -C "$REPO_ROOT" merge-base --is-ancestor "$OLD_SETUP_HEAD" "$TARGET_SHA"; then
    echo "FAIL: accepted target is not a forward descendant of verified live Setup checkout"
    echo "Live:   $OLD_SETUP_HEAD"
    echo "Target: $TARGET_SHA"
    exit 16
fi
echo "TARGET ANCESTRY: PASS"

check_blob() {
    local rel="$1"
    local expected="$2"
    local actual
    actual="$(sudo git -C "$REPO_ROOT" rev-parse "$TARGET_SHA:$rel")"
    if [[ "$actual" != "$expected" ]]; then
        echo "FAIL: Git blob mismatch for $rel"
        echo "Expected: $expected"
        echo "Actual:   $actual"
        exit 17
    fi
    echo "Git blob identity PASS: $rel -> $actual"
}
check_blob "$MIGRATION_REL" "$MIGRATION_BLOB"
check_blob "$VALIDATION_REL" "$VALIDATION_BLOB"
check_blob "$SCAN_SRC_REL" "$SCAN_BLOB"
check_blob "$SCAN_DIST_REL" "$SCAN_BLOB"

echo
echo "--- Detached exact-target regression and Scan staging ---"
sudo git -C "$REPO_ROOT" worktree add --detach "$CANDIDATE_WORKTREE" "$TARGET_SHA"
M065="$CANDIDATE_WORKTREE/$MIGRATION_REL"
V065="$CANDIDATE_WORKTREE/$VALIDATION_REL"
SCAN_SRC="$CANDIDATE_WORKTREE/$SCAN_SRC_REL"
SCAN_DIST="$CANDIDATE_WORKTREE/$SCAN_DIST_REL"
for required in "$M065" "$V065" "$SCAN_SRC" "$SCAN_DIST"; do
    [[ -s "$required" ]] || { echo "FAIL: exact target is missing required file $required"; exit 18; }
done

grep -Fq 'PRODUCTION_VERSION = "V0.3.29-pick-clarity"' \
    "$CANDIDATE_WORKTREE/Setup/Application/production_backend.py"
grep -Fq "CLIENT_BUILD = 'V0.3.29-pick-clarity'" \
    "$CANDIDATE_WORKTREE/Setup/Application/setup_catalog_dirty_guard.js"
cmp -s "$SCAN_SRC" "$SCAN_DIST" || { echo "FAIL: Scan src/index.js and dist/index.js differ"; exit 19; }

sudo -u fieldwiring -H env PYTHONPYCACHEPREFIX="$DETACHED_PYCACHE" bash -c \
    "cd '$CANDIDATE_WORKTREE' && '$PYTHON' -m pytest -q -p no:cacheprovider Setup/Application"
echo "DETACHED EXACT-TARGET SETUP REGRESSION: PASS"

cp "$SCAN_DIST" "$STAGED_SCAN"
STAGED_SCAN_SHA="$(sha256sum "$STAGED_SCAN" | awk '{print $1}')"
echo "Staged Scan SHA256: $STAGED_SCAN_SHA"
sudo docker cp "$STAGED_SCAN" "$DIRECTUS_CONTAINER:$SCAN_CONTAINER_TMP"
sudo docker exec "$DIRECTUS_CONTAINER" node --check "$SCAN_CONTAINER_TMP"
sudo docker exec "$DIRECTUS_CONTAINER" rm -f "$SCAN_CONTAINER_TMP"
echo "STAGED SCAN JAVASCRIPT SYNTAX: PASS"

echo
echo "--- Freeze Setup writes for bounded Production mutation window ---"
sudo systemctl stop "$SETUP_SERVICE"
SETUP_STOPPED=1
if systemctl is-active --quiet "$SETUP_SERVICE"; then
    echo "FAIL: Setup service did not stop"
    exit 20
fi
FROZEN_FINGERPRINT="$(setup_business_fingerprint)"
echo "Initial fingerprint: $INITIAL_FINGERPRINT"
echo "Frozen fingerprint:  $FROZEN_FINGERPRINT"
if [[ "$FROZEN_FINGERPRINT" != "$INITIAL_FINGERPRINT" ]]; then
    echo "FAIL: Setup data changed before write freeze"
    exit 21
fi
if [[ "$(setup_2026_count)" != "$INITIAL_2026_COUNT" ]]; then
    echo "FAIL: 2026 Setup Session count changed before mutation"
    exit 22
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
echo "--- Capture immediately preceding Scan rollback artifact ---"
sudo cp -p "$SCAN_LIVE_PATH" "$SCAN_ROLLBACK"
test -s "$SCAN_ROLLBACK"
SCAN_ROLLBACK_SHA="$(sha256sum "$SCAN_ROLLBACK" | awk '{print $1}')"
if [[ "$SCAN_ROLLBACK_SHA" != "$EXPECTED_LIVE_SCAN_SHA256" ]]; then
    echo "FAIL: Scan rollback copy hash differs from verified live baseline"
    exit 23
fi
echo "Scan rollback: $SCAN_ROLLBACK"
echo "Scan rollback SHA256: $SCAN_ROLLBACK_SHA"
echo "SCAN ROLLBACK CAPTURE: PASS"

echo
echo "--- Production database preflight for migration 065 ---"
psql_prod <<'SQL'
DO $preflight$
BEGIN
    IF to_regclass('ops.setup_movement_event') IS NULL
       OR to_regclass('ops.setup_movement_event_display') IS NULL
       OR to_regclass('ops.setup_container_state') IS NULL
       OR to_regclass('ops.setup_display_state') IS NULL
       OR to_regprocedure('ref.setup_browser_capabilities(text)') IS NULL
       OR to_regprocedure('ref.set_actor_on_update()') IS NULL THEN
        RAISE EXCEPTION 'Accepted Setup movement/audit foundation is incomplete';
    END IF;

    IF to_regprocedure('ref.setup_movement_actor(text)') IS NOT NULL
       OR to_regprocedure(
           'ops.record_setup_movement_event(text,integer,uuid,text,bigint,text,timestamptz,text,text,text,boolean,numeric,numeric,numeric,integer,text,text,bigint[],timestamptz,integer,text,text)'
       ) IS NOT NULL THEN
        RAISE EXCEPTION 'Migration 065 command surface already exists; stop for review';
    END IF;

    IF EXISTS (
        SELECT 1
        FROM information_schema.columns
        WHERE table_schema='ops'
          AND table_name='setup_movement_event'
          AND column_name='client_event_id'
    ) OR EXISTS (
        SELECT 1
        FROM information_schema.columns
        WHERE table_schema='ops'
          AND table_name='setup_container_state'
          AND column_name='movement_status'
    ) OR EXISTS (
        SELECT 1
        FROM information_schema.columns
        WHERE table_schema='ops'
          AND table_name='setup_display_state'
          AND column_name='movement_status'
    ) THEN
        RAISE EXCEPTION 'Migration 065 schema is partially/already present; stop for review';
    END IF;

    IF has_table_privilege('fieldwiring_app','ops.setup_movement_event','INSERT')
       OR has_table_privilege('fieldwiring_app','ops.setup_movement_event','UPDATE')
       OR has_table_privilege('fieldwiring_app','ops.setup_movement_event','DELETE')
       OR has_table_privilege('fieldwiring_app','ops.setup_container_state','UPDATE')
       OR has_table_privilege('fieldwiring_app','ops.setup_display_state','UPDATE') THEN
        RAISE EXCEPTION 'fieldwiring_app unexpectedly has broad movement DML before deployment';
    END IF;
END
$preflight$;
SQL
echo "DATABASE PREFLIGHT: PASS"

PRE_MUTATION_FINGERPRINT="$(setup_business_fingerprint)"
if [[ "$PRE_MUTATION_FINGERPRINT" != "$FROZEN_FINGERPRINT" ]]; then
    echo "FAIL: Setup business data changed during preflight"
    exit 24
fi
echo "PRE-MUTATION FINGERPRINT STABILITY: PASS"

echo
echo "--- Apply reviewed migration 065 ---"
psql_prod < "$M065"
DB_MIGRATION_COMMITTED=1
echo "MIGRATION 065: COMMITTED"

echo
echo "--- Transactional production validation of movement contract ---"
psql_prod < "$V065"
echo "MOVEMENT CONTRACT VALIDATION: PASS"

POST_DB_FINGERPRINT="$(setup_business_fingerprint)"
if [[ "$POST_DB_FINGERPRINT" != "$FROZEN_FINGERPRINT" ]]; then
    echo "FAIL: migration 065 changed pre-existing governed Setup business data"
    exit 25
fi
NEW_EVIDENCE="$(new_movement_evidence_count)"
if [[ "$NEW_EVIDENCE" != "0" ]]; then
    echo "FAIL: transactional validation left real movement evidence behind: $NEW_EVIDENCE"
    exit 26
fi
echo "POST-MIGRATION DATA BOUNDARY: PASS"

echo
echo "--- Advance dedicated Setup Production checkout to exact accepted target ---"
sudo git -C "$SETUP_ROOT" checkout --detach "$TARGET_SHA"
SETUP_ADVANCED=1
DEPLOYED_SETUP_HEAD="$(sudo git -C "$SETUP_ROOT" rev-parse HEAD)"
DEPLOYED_SETUP_STATUS="$(sudo git -C "$SETUP_ROOT" status --porcelain)"
if [[ "$DEPLOYED_SETUP_HEAD" != "$TARGET_SHA" || -n "$DEPLOYED_SETUP_STATUS" ]]; then
    echo "FAIL: deployed Setup checkout does not exactly match accepted target"
    exit 27
fi
echo "Setup checkout advanced exactly to $DEPLOYED_SETUP_HEAD"

echo
echo "--- Install exact approved Scan artifact ---"
sudo cp "$STAGED_SCAN" "$SCAN_LIVE_PATH"
sudo chown --reference="$SCAN_ROLLBACK" "$SCAN_LIVE_PATH"
sudo chmod --reference="$SCAN_ROLLBACK" "$SCAN_LIVE_PATH"
SCAN_ADVANCED=1
LIVE_SCAN_NEW_SHA="$(sha256sum "$SCAN_LIVE_PATH" | awk '{print $1}')"
if [[ "$LIVE_SCAN_NEW_SHA" != "$STAGED_SCAN_SHA" ]]; then
    echo "FAIL: live Scan hash does not match staged candidate"
    exit 28
fi
sudo docker exec "$DIRECTUS_CONTAINER" node --check /directus/extensions/directus-extension-scan/dist/index.js
echo "LIVE SCAN ARTIFACT HASH/SYNTAX: PASS ($LIVE_SCAN_NEW_SHA)"

echo
echo "--- Restart Directus and verify Scan extension ---"
if ! restart_directus; then
    echo "FAIL: Directus did not return with /scan/ healthy"
    sudo docker ps --filter name="$DIRECTUS_CONTAINER" || true
    sudo docker logs --tail 200 "$DIRECTUS_CONTAINER" || true
    exit 29
fi
sudo docker ps --filter name="$DIRECTUS_CONTAINER"
sudo docker logs --tail 200 "$DIRECTUS_CONTAINER"

SCAN_DISPLAY_ID="$(sudo docker exec "$PROD_CONTAINER" psql -X -qAt -v ON_ERROR_STOP=1 -U "$DB_ACTOR" -d "$PROD_DB" -c "SELECT display_id FROM ref.display ORDER BY display_id LIMIT 1;")"
SCAN_CONTAINER_ID="$(sudo docker exec "$PROD_CONTAINER" psql -X -qAt -v ON_ERROR_STOP=1 -U "$DB_ACTOR" -d "$PROD_DB" -c "SELECT container_id FROM ref.container ORDER BY container_id LIMIT 1;")"
[[ -n "$SCAN_DISPLAY_ID" && -n "$SCAN_CONTAINER_ID" ]] || { echo "FAIL: Scan regression fixture identities unavailable"; exit 30; }

SCAN_ROOT_HTML="$(curl -fsS http://127.0.0.1:8055/scan/)"
DISP_HTML="$(curl -fsS "http://127.0.0.1:8055/scan/DISP/$SCAN_DISPLAY_ID")"
CONT_HTML="$(curl -fsS "http://127.0.0.1:8055/scan/CONT/$SCAN_CONTAINER_ID")"

grep -Fq 'focusScanInput' <<<"$SCAN_ROOT_HTML"
grep -Fq 'Record Location' <<<"$DISP_HTML"
grep -Fq "https://my.sheboyganlights.org/setup/record-location/?asset=DISP:$SCAN_DISPLAY_ID" <<<"$DISP_HTML"
grep -Fq 'Field Wiring' <<<"$DISP_HTML"
grep -Fq 'Procedures' <<<"$DISP_HTML"
grep -Fq 'Record Location' <<<"$CONT_HTML"
grep -Fq "https://my.sheboyganlights.org/setup/record-location/?asset=CONT:$SCAN_CONTAINER_ID" <<<"$CONT_HTML"

CTRL_HEADERS="$(curl -sS -D - -o /dev/null http://127.0.0.1:8055/scan/CTRL/1014)"
grep -Fqi 'location: https://my.sheboyganlights.org/fieldwiring/controllers?controller_id=1014' <<<"$CTRL_HEADERS"
CTRL_BAD_CODE="$(curl -sS -o /dev/null -w '%{http_code}' http://127.0.0.1:8055/scan/CTRL/not-a-controller)"
if [[ "$CTRL_BAD_CODE" != "400" ]]; then
    echo "FAIL: invalid CTRL route returned HTTP $CTRL_BAD_CODE, expected 400"
    exit 31
fi
echo "SCAN ROUTE/HANDOFF REGRESSION: PASS"

echo
echo "--- Restart and verify Setup V0.3.29 runtime ---"
restart_setup
SETUP_POST="$(curl -fsS http://192.168.5.9:8794/api/health)"
echo "Post-deploy Setup health: $SETUP_POST"
if [[ "$SETUP_POST" != *"\"status\":\"ok\""* \
   || "$SETUP_POST" != *"\"data_mode\":\"postgres\""* \
   || "$SETUP_POST" != *"\"version\":\"$EXPECTED_POST_VERSION\""* ]]; then
    echo "FAIL: Setup health/version does not match $EXPECTED_POST_VERSION"
    exit 32
fi

ROOT_HTML="$(curl -fsS http://192.168.5.9:8794/)"
grep -Fq 'V0.3.29-pick-clarity' <<<"$ROOT_HTML" || true

MOVEMENT_NOIDENTITY_CODE="$(curl -sS -o "$NEGATIVE_BODY" -w '%{http_code}' \
    'http://192.168.5.9:8794/api/setup/movements/search?q=CONT%3A36')"
if [[ "$MOVEMENT_NOIDENTITY_CODE" != "401" ]]; then
    echo "FAIL: movement search without protected identity returned HTTP $MOVEMENT_NOIDENTITY_CODE, expected 401"
    cat "$NEGATIVE_BODY" || true
    exit 33
fi
echo "PROTECTED MOVEMENT API NEGATIVE PATH: PASS"

echo
echo "--- Live Setup regression ---"
sudo -u fieldwiring -H env PYTHONPYCACHEPREFIX="$LIVE_PYCACHE" bash -c \
    "cd '$SETUP_ROOT' && '$PYTHON' -m pytest -q -p no:cacheprovider Setup/Application"
echo "LIVE SETUP REGRESSION: PASS"

echo
echo "--- Final Production invariants ---"
FINAL_SETUP_HEAD="$(sudo git -C "$SETUP_ROOT" rev-parse HEAD)"
FINAL_SETUP_STATUS="$(sudo git -C "$SETUP_ROOT" status --porcelain)"
FINAL_SHARED_HEAD="$(sudo git -C "$REPO_ROOT" rev-parse HEAD)"
FINAL_FINGERPRINT="$(setup_business_fingerprint)"
FINAL_2026_COUNT="$(setup_2026_count)"
FINAL_MOVEMENT_EVENTS="$(table_count ops.setup_movement_event)"
FINAL_CONTAINER_STATE="$(table_count ops.setup_container_state)"
FINAL_DISPLAY_STATE="$(table_count ops.setup_display_state)"
FINAL_NEW_EVIDENCE="$(new_movement_evidence_count)"
FINAL_SCAN_SHA="$(sha256sum "$SCAN_LIVE_PATH" | awk '{print $1}')"
FINAL_HEALTH="$(curl -fsS http://192.168.5.9:8794/api/health)"

echo "Final Setup SHA:                    $FINAL_SETUP_HEAD"
echo "Final shared repository SHA:        $FINAL_SHARED_HEAD"
echo "Final Setup business fingerprint:   $FINAL_FINGERPRINT"
echo "Final 2026 Setup Session count:     $FINAL_2026_COUNT"
echo "Movement events before/after:       $INITIAL_MOVEMENT_EVENTS / $FINAL_MOVEMENT_EVENTS"
echo "Container state rows before/after:  $INITIAL_CONTAINER_STATE / $FINAL_CONTAINER_STATE"
echo "Display state rows before/after:    $INITIAL_DISPLAY_STATE / $FINAL_DISPLAY_STATE"
echo "New explicit movement evidence:     $FINAL_NEW_EVIDENCE"
echo "Final Scan SHA256:                  $FINAL_SCAN_SHA"
echo "Final Setup health:                 $FINAL_HEALTH"

[[ "$FINAL_SETUP_HEAD" == "$TARGET_SHA" ]]
[[ -z "$FINAL_SETUP_STATUS" ]]
[[ "$FINAL_SHARED_HEAD" == "$SHARED_HEAD_BEFORE" ]]
[[ "$FINAL_FINGERPRINT" == "$FROZEN_FINGERPRINT" ]]
[[ "$FINAL_2026_COUNT" == "$INITIAL_2026_COUNT" ]]
[[ "$FINAL_MOVEMENT_EVENTS" == "$INITIAL_MOVEMENT_EVENTS" ]]
[[ "$FINAL_CONTAINER_STATE" == "$INITIAL_CONTAINER_STATE" ]]
[[ "$FINAL_DISPLAY_STATE" == "$INITIAL_DISPLAY_STATE" ]]
[[ "$FINAL_NEW_EVIDENCE" == "0" ]]
[[ "$FINAL_SCAN_SHA" == "$STAGED_SCAN_SHA" ]]
[[ "$FINAL_HEALTH" == *"\"version\":\"$EXPECTED_POST_VERSION\""* ]]

SUCCESS=1
echo
echo "SETUP_88_V0329_PRODUCTION_DEPLOYMENT_PASS"
echo "Deployed Setup SHA:       $FINAL_SETUP_HEAD"
echo "Deployed Scan SHA256:     $FINAL_SCAN_SHA"
echo "Rollback Setup SHA:       $OLD_SETUP_HEAD"
echo "Rollback PostgreSQL dump: $BACKUP_FILE"
echo "Rollback PostgreSQL SHA:  $BACKUP_SHA"
echo "Rollback Scan artifact:   $SCAN_ROLLBACK"
echo "Rollback Scan SHA256:     $SCAN_ROLLBACK_SHA"
echo "Deployment report:        $REPORT"
