#!/usr/bin/env bash
set -euo pipefail

MERGED_MAIN_SHA="${1:?merged main SHA is required}"

PROD_CONTAINER="msb-postgres"
PROD_DB="msb"
DB_ACTOR="msbadmin"
REPO_ROOT="/opt/fieldwiring"
SETUP_ROOT="/opt/msb-setup"
PYTHON="/opt/fieldwiring/.venv/bin/python"
SETUP_SERVICE="msb-setup.service"

APP_TARGET_SHA="7da6828d7b884ee5bb12123dab647bd6fadfba50"
EXPECTED_PRE_VERSION="V0.3.22-pick-list-delay"
EXPECTED_POST_VERSION="V0.3.29-pick-clarity"

AUDIT_REL="Database/Basic_Query_Tools_Dev/Repair-SetActorOnUpdate-Attribution.sql"
AUDIT_BLOB="2b848e91f0cc4b926e33156641cf2ceed8e6ccee"
AUDIT_VALIDATION_REL="Database/Acceptance/database_shared_audit_actor_disposable_validation.sql"
AUDIT_VALIDATION_BLOB="1e09846734deb02f49a8b94d7614758958c2cc3e"
MOVEMENT_VALIDATION_REL="Setup/Acceptance/setup_88_movement_capture_disposable_validation.sql"
MOVEMENT_VALIDATION_BLOB="fc152c305dc0bf7a056aeff60aae3615b06b96d4"
M065_REL="Setup/Database/065_add_setup_movement_capture.sql"
M065_BLOB="2738065a6fc3cb84858e401de5fae9bd6ae35dcc"

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
STAMP="$(date +%Y%m%dT%H%M%S)"
BACKUP_DIR="/home/msbadmin/backups/setup-88"
REPORT_DIR="/home/msbadmin/setup-deployment-reports"
BACKUP_FILE="$BACKUP_DIR/msb-post-065-pre-audit-recovery-$STAMP.dump"
REPORT="$REPORT_DIR/Setup_88_V0329_Audit_Recovery_$STAMP.txt"
CANDIDATE_WORKTREE="/tmp/msb-setup-88-audit-recovery-$STAMP"
DETACHED_PYCACHE="/tmp/msb-setup-88-audit-recovery-detached-pycache-$STAMP"
LIVE_PYCACHE="/tmp/msb-setup-88-audit-recovery-live-pycache-$STAMP"
NEGATIVE_BODY="/tmp/msb-setup-88-audit-recovery-negative-$STAMP.json"

OLD_SETUP_HEAD=""
SHARED_HEAD_BEFORE=""
INITIAL_FINGERPRINT=""
FROZEN_FINGERPRINT=""
INITIAL_2026_COUNT=""
INITIAL_MOVEMENT_EVENTS=""
INITIAL_CONTAINER_STATE=""
INITIAL_DISPLAY_STATE=""
AUDIT_BEFORE=""
AUDIT_AFTER=""
BACKUP_CREATED=0
AUDIT_COMMITTED=0
SETUP_ADVANCED=0
SETUP_STOPPED=0
SUCCESS=0
BACKUP_SHA=""

mkdir -p "$REPORT_DIR"
exec > >(tee "$REPORT") 2>&1

echo "========== SETUP #88 V0.3.29 AUDIT-PREREQUISITE FORWARD RECOVERY =========="
echo "Authority: Gregovate/MSB-Server-Management — docs/server/Production_Database_Change_Deployment_Runbook.md"
echo "Authority: Gregovate/MSB-Server-Management — docs/server/Setup_Production_Runtime.md"
echo "Merged main recovery source: $MERGED_MAIN_SHA"
echo "Accepted application target: $APP_TARGET_SHA"
echo "Expected Setup version: $EXPECTED_PRE_VERSION -> $EXPECTED_POST_VERSION"
echo "Precondition: migration 065 is ALREADY COMMITTED and MUST NOT be rerun"
echo "Shared audit repair: $AUDIT_REL ($AUDIT_BLOB)"
echo "Database audit validation: $AUDIT_VALIDATION_REL ($AUDIT_VALIDATION_BLOB)"
echo "#88 movement validation: $MOVEMENT_VALIDATION_REL ($MOVEMENT_VALIDATION_BLOB)"
echo "Scan/Directus: NOT MUTATED"
echo "Report: $REPORT"
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

audit_contract_fingerprint() {
    sudo docker exec "$PROD_CONTAINER"         psql -X -qAt -v ON_ERROR_STOP=1 -U "$DB_ACTOR" -d "$PROD_DB" -c "
            WITH function_state AS (
                SELECT string_agg(
                    p.proname || ':' || md5(pg_get_functiondef(p.oid)),
                    '|' ORDER BY p.proname
                ) AS value
                FROM pg_proc p
                JOIN pg_namespace n ON n.oid=p.pronamespace
                WHERE n.nspname='ref'
                  AND p.proname IN (
                      'resolve_actor',
                      'set_actor_on_insert',
                      'set_actor_on_update',
                      'set_updated_fields',
                      'sync_audit_collection_policy'
                  )
            ),
            policy_state AS (
                SELECT string_agg(row_to_json(a)::text, '|' ORDER BY a.audit_collection_policy_id) AS value
                FROM ref.audit_collection_policy a
            )
            SELECT md5(
                coalesce((SELECT value FROM function_state),'') || '|' ||
                coalesce((SELECT value FROM policy_state),'')
            );
        "
}

setup_2026_count() {
    sudo docker exec "$PROD_CONTAINER"         psql -X -qAt -v ON_ERROR_STOP=1 -U "$DB_ACTOR" -d "$PROD_DB"         -c "SELECT count(*) FROM ops.setup_session WHERE season_year=2026;"
}

table_count() {
    local rel="$1"
    sudo docker exec "$PROD_CONTAINER"         psql -X -qAt -v ON_ERROR_STOP=1 -U "$DB_ACTOR" -d "$PROD_DB"         -c "SELECT count(*) FROM $rel;"
}

new_movement_evidence_count() {
    sudo docker exec "$PROD_CONTAINER"         psql -X -qAt -v ON_ERROR_STOP=1 -U "$DB_ACTOR" -d "$PROD_DB" -c "
            SELECT
                (SELECT count(*) FROM ops.setup_movement_event WHERE client_event_id IS NOT NULL)
              + (SELECT count(*) FROM ops.setup_container_state WHERE movement_status IS NOT NULL)
              + (SELECT count(*) FROM ops.setup_display_state WHERE movement_status IS NOT NULL);
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

cleanup() {
    status=$?
    trap - EXIT HUP INT TERM
    set +e

    if [[ "$status" -ne 0 && "$SUCCESS" -ne 1 ]]; then
        echo
        echo "--- FAIL-CLOSED RECOVERY ---"

        if [[ "$SETUP_ADVANCED" -eq 1 && -n "$OLD_SETUP_HEAD" ]]; then
            echo "Restoring /opt/msb-setup to prior SHA $OLD_SETUP_HEAD"
            sudo git -C "$SETUP_ROOT" checkout --detach "$OLD_SETUP_HEAD" || true
            SETUP_ADVANCED=0
        fi

        if [[ "$SETUP_STOPPED" -eq 1 || -n "$OLD_SETUP_HEAD" ]]; then
            echo "Restarting Setup after fail-closed recovery"
            restart_setup || true
        fi

        if [[ "$AUDIT_COMMITTED" -eq 1 ]]; then
            echo "Shared audit repair reached committed state and is intentionally not auto-restored."
            echo "The retained PostgreSQL archive represents the post-065 / pre-audit-repair recovery point."
        else
            echo "Shared audit repair did not reach committed-success state."
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
        AFTER_FINGERPRINT="$(setup_business_fingerprint 2>/dev/null || true)"
        echo "Frozen Setup business fingerprint: $FROZEN_FINGERPRINT"
        echo "Final Setup business fingerprint:  $AFTER_FINGERPRINT"
        if [[ -z "$AFTER_FINGERPRINT" || "$AFTER_FINGERPRINT" != "$FROZEN_FINGERPRINT" ]]; then
            echo "FAIL: governed Setup business rows changed during recovery"
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
            echo "FAIL: 2026 Setup Session count changed during recovery"
            status=96
        else
            echo "PASS: 2026 Setup Session count unchanged"
        fi
    fi

    if [[ "$BACKUP_CREATED" -eq 1 && -s "$BACKUP_FILE" ]]; then
        echo "Post-065 / pre-audit rollback archive retained at: $BACKUP_FILE"
        echo "Rollback SHA256: ${BACKUP_SHA:-unknown}"
    else
        echo "Recovery rollback PostgreSQL archive: not created before this stop"
    fi

    echo "Recovery report retained at: $REPORT"
    echo "Exit status: $status"
    exit "$status"
}
trap cleanup EXIT HUP INT TERM

sudo -v
mkdir -p "$BACKUP_DIR" "$REPORT_DIR"

echo "--- Verify current Production runtime and exact merged recovery source ---"
if ! sudo docker inspect "$PROD_CONTAINER" >/dev/null 2>&1; then
    echo "FAIL: Production PostgreSQL container not found"
    exit 2
fi
if [[ "$(sudo docker inspect "$PROD_CONTAINER" --format '{{.Config.Image}}')" != "postgis/postgis:16-3.5" ]]; then
    echo "FAIL: Production PostgreSQL image mismatch"
    exit 3
fi
if ! sudo git -C "$REPO_ROOT" worktree list --porcelain | grep -Fq "worktree $SETUP_ROOT"; then
    echo "FAIL: $SETUP_ROOT is not a registered worktree of $REPO_ROOT"
    exit 4
fi
if [[ -n "$(sudo git -C "$REPO_ROOT" status --porcelain)" ]]; then
    echo "FAIL: shared repository checkout has uncommitted changes"
    sudo git -C "$REPO_ROOT" status -sb
    exit 5
fi
if [[ -n "$(sudo git -C "$SETUP_ROOT" status --porcelain)" ]]; then
    echo "FAIL: live Setup checkout has uncommitted changes"
    sudo git -C "$SETUP_ROOT" status -sb
    exit 6
fi
if ! systemctl is-active --quiet "$SETUP_SERVICE"; then
    echo "FAIL: $SETUP_SERVICE is not active before recovery"
    exit 7
fi

OLD_SETUP_HEAD="$(sudo git -C "$SETUP_ROOT" rev-parse HEAD)"
SHARED_HEAD_BEFORE="$(sudo git -C "$REPO_ROOT" rev-parse HEAD)"
echo "Verified live Setup checkout: $OLD_SETUP_HEAD"
echo "Shared repository checkout:    $SHARED_HEAD_BEFORE"

if [[ "$OLD_SETUP_HEAD" != "6f53d7f0c4b15f7175e773a2069595eef3f0e698" ]]; then
    echo "FAIL: live Setup SHA is not the known pre-recovery V0.3.22 checkout"
    exit 8
fi

SETUP_PRE="$(curl -fsS http://192.168.5.9:8794/api/health)"
echo "Pre-recovery Setup health: $SETUP_PRE"
if [[ "$SETUP_PRE" != *"\"status\":\"ok\""*    || "$SETUP_PRE" != *"\"data_mode\":\"postgres\""*    || "$SETUP_PRE" != *"\"version\":\"$EXPECTED_PRE_VERSION\""* ]]; then
    echo "FAIL: live Setup pre-version/health is not $EXPECTED_PRE_VERSION"
    exit 9
fi

sudo git -C "$REPO_ROOT" fetch origin main
REMOTE_MAIN="$(sudo git -C "$REPO_ROOT" rev-parse origin/main)"
if [[ "$REMOTE_MAIN" != "$MERGED_MAIN_SHA" ]]; then
    echo "FAIL: origin/main moved from reviewed recovery SHA"
    echo "Expected: $MERGED_MAIN_SHA"
    echo "Actual:   $REMOTE_MAIN"
    exit 10
fi
sudo git -C "$REPO_ROOT" cat-file -e "$MERGED_MAIN_SHA^{commit}"
sudo git -C "$REPO_ROOT" cat-file -e "$APP_TARGET_SHA^{commit}"
if ! sudo git -C "$REPO_ROOT" merge-base --is-ancestor "$APP_TARGET_SHA" "$MERGED_MAIN_SHA"; then
    echo "FAIL: accepted V0.3.29 application SHA is not contained in reviewed main"
    exit 11
fi

check_blob() {
    local rel="$1"
    local expected="$2"
    local actual
    actual="$(sudo git -C "$REPO_ROOT" rev-parse "$MERGED_MAIN_SHA:$rel")"
    if [[ "$actual" != "$expected" ]]; then
        echo "FAIL: reviewed recovery blob mismatch for $rel"
        echo "Expected: $expected"
        echo "Actual:   $actual"
        exit 12
    fi
    echo "Reviewed blob PASS: $rel -> $actual"
}
check_blob "$AUDIT_REL" "$AUDIT_BLOB"
check_blob "$AUDIT_VALIDATION_REL" "$AUDIT_VALIDATION_BLOB"
check_blob "$MOVEMENT_VALIDATION_REL" "$MOVEMENT_VALIDATION_BLOB"
check_blob "$M065_REL" "$M065_BLOB"

echo
echo "--- Prove migration 065 is already installed; do not rerun it ---"
psql_prod <<'SQL'
DO $preflight$
BEGIN
    IF to_regprocedure('ref.setup_movement_actor(text)') IS NULL
       OR to_regprocedure(
           'ops.record_setup_movement_event(text,integer,uuid,text,bigint,text,timestamptz,text,text,text,boolean,numeric,numeric,numeric,integer,text,text,bigint[],timestamptz,integer,text,text)'
       ) IS NULL THEN
        RAISE EXCEPTION 'Migration 065 command surface is not installed';
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_schema='ops'
          AND table_name='setup_movement_event'
          AND column_name='client_event_id'
    ) OR NOT EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_schema='ops'
          AND table_name='setup_container_state'
          AND column_name='movement_status'
    ) OR NOT EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_schema='ops'
          AND table_name='setup_display_state'
          AND column_name='movement_status'
    ) THEN
        RAISE EXCEPTION 'Migration 065 schema is incomplete';
    END IF;

    IF has_table_privilege('fieldwiring_app','ops.setup_movement_event','INSERT')
       OR has_table_privilege('fieldwiring_app','ops.setup_movement_event','UPDATE')
       OR has_table_privilege('fieldwiring_app','ops.setup_movement_event','DELETE')
       OR has_table_privilege('fieldwiring_app','ops.setup_container_state','UPDATE')
       OR has_table_privilege('fieldwiring_app','ops.setup_display_state','UPDATE') THEN
        RAISE EXCEPTION 'fieldwiring_app unexpectedly has broad movement DML';
    END IF;
END
$preflight$;
SQL
echo "MIGRATION 065 INSTALLED PRECONDITION: PASS"

INITIAL_FINGERPRINT="$(setup_business_fingerprint)"
INITIAL_2026_COUNT="$(setup_2026_count)"
INITIAL_MOVEMENT_EVENTS="$(table_count ops.setup_movement_event)"
INITIAL_CONTAINER_STATE="$(table_count ops.setup_container_state)"
INITIAL_DISPLAY_STATE="$(table_count ops.setup_display_state)"
INITIAL_NEW_EVIDENCE="$(new_movement_evidence_count)"
AUDIT_BEFORE="$(audit_contract_fingerprint)"

echo "Initial Setup business fingerprint: $INITIAL_FINGERPRINT"
echo "Initial 2026 Setup Session count:    $INITIAL_2026_COUNT"
echo "Initial explicit movement evidence:  $INITIAL_NEW_EVIDENCE"
echo "Initial audit contract fingerprint:  $AUDIT_BEFORE"

if [[ "$INITIAL_2026_COUNT" != "1" ]]; then
    echo "FAIL: expected exactly one live 2026 Setup Session"
    exit 13
fi
if [[ "$INITIAL_NEW_EVIDENCE" != "0" ]]; then
    echo "FAIL: explicit movement evidence exists before recovery; stop for review"
    exit 14
fi

echo
echo "--- Create detached reviewed-main worktree and run regression ---"
sudo git -C "$REPO_ROOT" worktree add --detach "$CANDIDATE_WORKTREE" "$MERGED_MAIN_SHA"
for rel in "$AUDIT_REL" "$AUDIT_VALIDATION_REL" "$MOVEMENT_VALIDATION_REL"; do
    [[ -s "$CANDIDATE_WORKTREE/$rel" ]] || { echo "FAIL: reviewed main is missing $rel"; exit 15; }
done
sudo -u fieldwiring -H env PYTHONPYCACHEPREFIX="$DETACHED_PYCACHE" bash -c     "cd '$CANDIDATE_WORKTREE' && '$PYTHON' -m pytest -q -p no:cacheprovider Setup/Application"
echo "DETACHED MERGED-MAIN SETUP REGRESSION: PASS"

echo
echo "--- Freeze Setup writes for bounded forward recovery ---"
sudo systemctl stop "$SETUP_SERVICE"
SETUP_STOPPED=1
if systemctl is-active --quiet "$SETUP_SERVICE"; then
    echo "FAIL: Setup service did not stop"
    exit 16
fi

FROZEN_FINGERPRINT="$(setup_business_fingerprint)"
if [[ "$FROZEN_FINGERPRINT" != "$INITIAL_FINGERPRINT" ]]; then
    echo "FAIL: Setup business data changed before recovery freeze"
    exit 17
fi
if [[ "$(setup_2026_count)" != "$INITIAL_2026_COUNT" ]]; then
    echo "FAIL: 2026 Setup Session count changed before recovery"
    exit 18
fi
echo "WRITE-FREEZE STABILITY: PASS"

echo
echo "--- Create and validate post-065 / pre-audit rollback PostgreSQL archive ---"
sudo docker exec "$PROD_CONTAINER"     pg_dump -U "$DB_ACTOR" -d "$PROD_DB" -Fc > "$BACKUP_FILE"
test -s "$BACKUP_FILE"
BACKUP_CREATED=1
BACKUP_SHA="$(sha256sum "$BACKUP_FILE" | awk '{print $1}')"
sudo docker exec -i "$PROD_CONTAINER" pg_restore --list < "$BACKUP_FILE" >/dev/null
echo "Rollback archive: $BACKUP_FILE"
echo "SHA256:          $BACKUP_SHA"
echo "ROLLBACK ARCHIVE VALIDATION: PASS"

echo
echo "--- Apply yesterday's accepted database-wide audit repair ---"
psql_prod < "$CANDIDATE_WORKTREE/$AUDIT_REL"
AUDIT_COMMITTED=1
echo "SHARED AUDIT REPAIR: COMMITTED"

echo
echo "--- Validate shared audit actor contract in rollback transaction ---"
psql_prod < "$CANDIDATE_WORKTREE/$AUDIT_VALIDATION_REL"
echo "DATABASE-WIDE AUDIT VALIDATION: PASS"

AUDIT_AFTER="$(audit_contract_fingerprint)"
echo "Audit contract fingerprint before: $AUDIT_BEFORE"
echo "Audit contract fingerprint after:  $AUDIT_AFTER"
if [[ -z "$AUDIT_AFTER" || "$AUDIT_AFTER" == "$AUDIT_BEFORE" ]]; then
    echo "FAIL: audit repair did not change the known pre-recovery audit contract"
    exit 19
fi

echo
echo "--- Re-run #88 movement contract validation only; migration 065 is NOT reapplied ---"
psql_prod < "$CANDIDATE_WORKTREE/$MOVEMENT_VALIDATION_REL"
echo "MOVEMENT CONTRACT VALIDATION: PASS"

POST_VALIDATION_FINGERPRINT="$(setup_business_fingerprint)"
POST_VALIDATION_EVIDENCE="$(new_movement_evidence_count)"
if [[ "$POST_VALIDATION_FINGERPRINT" != "$FROZEN_FINGERPRINT" ]]; then
    echo "FAIL: recovery validations changed governed Setup business rows"
    exit 20
fi
if [[ "$POST_VALIDATION_EVIDENCE" != "0" ]]; then
    echo "FAIL: rollback-only validations left movement evidence behind: $POST_VALIDATION_EVIDENCE"
    exit 21
fi
echo "POST-VALIDATION DATA BOUNDARY: PASS"

echo
echo "--- Advance dedicated Setup Production checkout to exact accepted V0.3.29 application ---"
sudo git -C "$SETUP_ROOT" checkout --detach "$APP_TARGET_SHA"
SETUP_ADVANCED=1
DEPLOYED_SETUP_HEAD="$(sudo git -C "$SETUP_ROOT" rev-parse HEAD)"
DEPLOYED_SETUP_STATUS="$(sudo git -C "$SETUP_ROOT" status --porcelain)"
if [[ "$DEPLOYED_SETUP_HEAD" != "$APP_TARGET_SHA" || -n "$DEPLOYED_SETUP_STATUS" ]]; then
    echo "FAIL: deployed Setup checkout does not exactly match accepted target"
    exit 22
fi
echo "Setup checkout advanced exactly to $DEPLOYED_SETUP_HEAD"

echo
echo "--- Restart and verify Setup V0.3.29 runtime ---"
restart_setup
SETUP_POST="$(curl -fsS http://192.168.5.9:8794/api/health)"
echo "Post-recovery Setup health: $SETUP_POST"
if [[ "$SETUP_POST" != *"\"status\":\"ok\""*    || "$SETUP_POST" != *"\"data_mode\":\"postgres\""*    || "$SETUP_POST" != *"\"version\":\"$EXPECTED_POST_VERSION\""* ]]; then
    echo "FAIL: Setup health/version does not match $EXPECTED_POST_VERSION"
    exit 23
fi

MOVEMENT_NOIDENTITY_CODE="$(curl -sS -o "$NEGATIVE_BODY" -w '%{http_code}'     'http://192.168.5.9:8794/api/setup/movements/search?q=CONT%3A36')"
if [[ "$MOVEMENT_NOIDENTITY_CODE" != "401" ]]; then
    echo "FAIL: movement search without protected identity returned HTTP $MOVEMENT_NOIDENTITY_CODE, expected 401"
    cat "$NEGATIVE_BODY" || true
    exit 24
fi
echo "PROTECTED MOVEMENT API NEGATIVE PATH: PASS"

echo
echo "--- Live Setup regression ---"
sudo -u fieldwiring -H env PYTHONPYCACHEPREFIX="$LIVE_PYCACHE" bash -c     "cd '$SETUP_ROOT' && '$PYTHON' -m pytest -q -p no:cacheprovider Setup/Application"
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
FINAL_AUDIT="$(audit_contract_fingerprint)"
FINAL_HEALTH="$(curl -fsS http://192.168.5.9:8794/api/health)"

echo "Final Setup SHA:                    $FINAL_SETUP_HEAD"
echo "Final shared repository SHA:        $FINAL_SHARED_HEAD"
echo "Final Setup business fingerprint:   $FINAL_FINGERPRINT"
echo "Final 2026 Setup Session count:     $FINAL_2026_COUNT"
echo "Movement events before/after:       $INITIAL_MOVEMENT_EVENTS / $FINAL_MOVEMENT_EVENTS"
echo "Container state rows before/after:  $INITIAL_CONTAINER_STATE / $FINAL_CONTAINER_STATE"
echo "Display state rows before/after:    $INITIAL_DISPLAY_STATE / $FINAL_DISPLAY_STATE"
echo "New explicit movement evidence:     $FINAL_NEW_EVIDENCE"
echo "Final audit contract fingerprint:   $FINAL_AUDIT"
echo "Final Setup health:                 $FINAL_HEALTH"

[[ "$FINAL_SETUP_HEAD" == "$APP_TARGET_SHA" ]]
[[ -z "$FINAL_SETUP_STATUS" ]]
[[ "$FINAL_SHARED_HEAD" == "$SHARED_HEAD_BEFORE" ]]
[[ "$FINAL_FINGERPRINT" == "$FROZEN_FINGERPRINT" ]]
[[ "$FINAL_2026_COUNT" == "$INITIAL_2026_COUNT" ]]
[[ "$FINAL_MOVEMENT_EVENTS" == "$INITIAL_MOVEMENT_EVENTS" ]]
[[ "$FINAL_CONTAINER_STATE" == "$INITIAL_CONTAINER_STATE" ]]
[[ "$FINAL_DISPLAY_STATE" == "$INITIAL_DISPLAY_STATE" ]]
[[ "$FINAL_NEW_EVIDENCE" == "0" ]]
[[ "$FINAL_AUDIT" == "$AUDIT_AFTER" ]]
[[ "$FINAL_HEALTH" == *"\"version\":\"$EXPECTED_POST_VERSION\""* ]]

SUCCESS=1
echo
echo "SETUP_88_V0329_AUDIT_RECOVERY_PASS"
echo "Shared audit repair:       COMMITTED"
echo "Migration 065:             PRE-EXISTING / NOT REAPPLIED"
echo "Deployed Setup SHA:        $FINAL_SETUP_HEAD"
echo "Rollback Setup SHA:        $OLD_SETUP_HEAD"
echo "Post-065 rollback dump:    $BACKUP_FILE"
echo "Post-065 rollback SHA256:  $BACKUP_SHA"
echo "Recovery report:           $REPORT"
