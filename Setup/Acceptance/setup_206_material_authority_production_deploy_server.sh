#!/usr/bin/env bash
set -euo pipefail

PROD_CONTAINER="msb-postgres"
PROD_DB="msb"
DB_ACTOR="msbadmin"
REPO_ROOT="/opt/fieldwiring"
SETUP_ROOT="/opt/msb-setup"
PYTHON="/opt/fieldwiring/.venv/bin/python"
SETUP_SERVICE="msb-setup.service"

TARGET_REF="agent/setup-206-tablet-material-audit"
TARGET_SHA="947b86a9598584717167cce094cd78d99e9a71e7"
EXPECTED_LIVE_SHA="fc0b76d57826eebf04b81c99cbb904109162cd87"
EXPECTED_PRE_VERSION="V0.3.19-pick-list"
EXPECTED_POST_VERSION="V0.3.20-material-authority"
M063_REL="Setup/Database/063_harden_setup_extra_material_requirement_lifecycle.sql"
M063_BLOB="2c686ad3ae55b09a9cf3629b9ef01bb0b83dd447"
M064_REL="Setup/Database/064_add_setup_extra_material_requirement_restore.sql"
M064_BLOB="50de44a51b44eb008e826a7ef76b2023fafa29f7"
EXPECTED_DIRTY_GUARD_PIN="setup_catalog_dirty_guard.js?v=2026-09-28.1"
EXPECTED_EXTRA_MATERIAL_PIN="setup_extra_materials.js?v=2026-09-28.3"
EXPECTED_KIT_CSS_PIN="setup_kit_inventory.css?v=2026-09-28.2"
EXPECTED_KIT_JS_PIN="setup_kit_inventory.js?v=2026-09-28.3"

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
STAMP="$(date +%Y%m%dT%H%M%S)"
BACKUP_DIR="/home/msbadmin/backups/setup-206-material-authority"
REPORT_DIR="/home/msbadmin/setup-deployment-reports"
BACKUP_FILE="$BACKUP_DIR/msb-pre-setup-206-material-authority-$STAMP.dump"
REPORT="$REPORT_DIR/Setup_206_Material_Authority_Production_Deploy_$STAMP.txt"
CANDIDATE_WORKTREE="/tmp/msb-setup-206-material-authority-candidate-$STAMP"
DETACHED_PYCACHE="/tmp/msb-setup-206-material-authority-detached-$STAMP"
LIVE_PYCACHE="/tmp/msb-setup-206-material-authority-live-$STAMP"
NEGATIVE_BODY="/tmp/msb-setup-206-material-authority-negative-$STAMP.txt"

OLD_HEAD=""
INITIAL_CORE_FP=""
FROZEN_CORE_FP=""
INITIAL_MATERIAL_FP=""
FROZEN_MATERIAL_FP=""
INITIAL_2026_COUNT=""
BACKUP_CREATED=0
M063_COMMITTED=0
M064_COMMITTED=0
APP_ADVANCED=0
SETUP_STOPPED=0
SUCCESS=0

mkdir -p "$BACKUP_DIR" "$REPORT_DIR"
exec > >(tee "$REPORT") 2>&1

psql_prod() {
    sudo docker exec -i "$PROD_CONTAINER" \
        psql -X -v ON_ERROR_STOP=1 -U "$DB_ACTOR" -d "$PROD_DB" "$@"
}

core_fingerprint() {
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

material_fingerprint() {
    sudo docker exec "$PROD_CONTAINER" \
        psql -X -qAt -v ON_ERROR_STOP=1 -U "$DB_ACTOR" -d "$PROD_DB" -c "
SELECT md5(
    coalesce((SELECT string_agg(row_to_json(m)::text, '' ORDER BY m.setup_extra_material_id) FROM ref.setup_extra_material m), '') || '|' ||
    coalesce((SELECT string_agg(row_to_json(tm)::text, '' ORDER BY tm.setup_task_extra_material_id) FROM ref.setup_task_extra_material tm), '') || '|' ||
    coalesce((SELECT string_agg(row_to_json(src)::text, '' ORDER BY src.setup_task_extra_material_source_id) FROM ref.setup_task_extra_material_source src), '') || '|' ||
    coalesce((SELECT string_agg(row_to_json(cem)::text, '' ORDER BY cem.setup_container_extra_material_id) FROM ref.setup_container_extra_material cem), '') || '|' ||
    coalesce((SELECT string_agg(row_to_json(rem)::text, '' ORDER BY rem.container_id) FROM ref.setup_container_extra_material_review rem), '') || '|' ||
    coalesce((SELECT string_agg(row_to_json(ev)::text, '' ORDER BY ev.setup_extra_material_inventory_event_id) FROM ops.setup_extra_material_inventory_event ev), '')
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

rollback_new_functions() {
    psql_prod <<'SQL'
BEGIN;
REVOKE ALL ON FUNCTION ref.restore_setup_task_extra_material(text,bigint,bigint) FROM PUBLIC;
REVOKE ALL ON FUNCTION ref.restore_setup_task_extra_material(text,bigint,bigint) FROM fieldwiring_app;
DROP FUNCTION IF EXISTS ref.restore_setup_task_extra_material(text,bigint,bigint);
REVOKE ALL ON FUNCTION ref.delete_setup_task_extra_material(text,bigint,bigint) FROM PUBLIC;
REVOKE ALL ON FUNCTION ref.delete_setup_task_extra_material(text,bigint,bigint) FROM fieldwiring_app;
DROP FUNCTION IF EXISTS ref.delete_setup_task_extra_material(text,bigint,bigint);
COMMIT;
SQL
}

cleanup() {
    status=$?
    trap - EXIT HUP INT TERM
    set +e
    rollback_failed=0

    if [[ "$status" -ne 0 && "$SUCCESS" -ne 1 ]]; then
        echo
        echo "--- FAIL-CLOSED V0.3.20 RECOVERY ---"

        if [[ "$M063_COMMITTED" -eq 1 || "$M064_COMMITTED" -eq 1 || "$APP_ADVANCED" -eq 1 ]]; then
            if systemctl is-active --quiet "$SETUP_SERVICE"; then
                sudo systemctl stop "$SETUP_SERVICE" >/dev/null 2>&1 || true
                SETUP_STOPPED=1
            fi
        fi

        if [[ "$APP_ADVANCED" -eq 1 && -n "$OLD_HEAD" ]]; then
            echo "Restoring Setup checkout to $OLD_HEAD"
            if sudo git -C "$SETUP_ROOT" checkout --detach "$OLD_HEAD"; then
                APP_ADVANCED=0
                echo "Application rollback: PASS"
            else
                rollback_failed=1
                echo "Application rollback: FAILED"
            fi
        fi

        if [[ "$M063_COMMITTED" -eq 1 || "$M064_COMMITTED" -eq 1 ]]; then
            echo "Removing only new 063/064 command functions"
            if rollback_new_functions; then
                M063_COMMITTED=0
                M064_COMMITTED=0
                echo "Migration function rollback: PASS"
            else
                rollback_failed=1
                echo "Migration function rollback: FAILED"
            fi
        fi

        if [[ "$rollback_failed" -eq 0 && "$SETUP_STOPPED" -eq 1 ]]; then
            echo "Restarting Setup after recovery"
            restart_setup || true
        elif [[ "$rollback_failed" -ne 0 ]]; then
            echo "WARNING: rollback requires review; Setup remains stopped."
        fi
    fi

    if sudo git -C "$REPO_ROOT" worktree list --porcelain 2>/dev/null \
       | grep -Fq "worktree $CANDIDATE_WORKTREE"; then
        sudo git -C "$REPO_ROOT" worktree remove --force "$CANDIDATE_WORKTREE" >/dev/null 2>&1 || true
    fi
    sudo git -C "$REPO_ROOT" worktree prune >/dev/null 2>&1 || true
    sudo rm -rf "$DETACHED_PYCACHE" "$LIVE_PYCACHE" >/dev/null 2>&1 || true
    rm -f "$NEGATIVE_BODY" >/dev/null 2>&1 || true
    rm -rf "$SCRIPT_DIR" >/dev/null 2>&1 || true

    echo
    echo "--- Production after-check ---"
    if [[ -n "$FROZEN_CORE_FP" ]]; then
        FINAL_CORE_FP="$(core_fingerprint 2>/dev/null || true)"
        echo "Frozen core Setup fingerprint: $FROZEN_CORE_FP"
        echo "Final core Setup fingerprint:  $FINAL_CORE_FP"
        if [[ -z "$FINAL_CORE_FP" || "$FINAL_CORE_FP" != "$FROZEN_CORE_FP" ]]; then
            echo "FAIL: core Setup fingerprint changed"
            status=97
        fi
    fi
    if [[ -n "$FROZEN_MATERIAL_FP" ]]; then
        FINAL_MATERIAL_FP="$(material_fingerprint 2>/dev/null || true)"
        echo "Frozen material fingerprint: $FROZEN_MATERIAL_FP"
        echo "Final material fingerprint:  $FINAL_MATERIAL_FP"
        if [[ -z "$FINAL_MATERIAL_FP" || "$FINAL_MATERIAL_FP" != "$FROZEN_MATERIAL_FP" ]]; then
            echo "FAIL: material authority data changed"
            status=96
        fi
    fi
    if [[ -n "$INITIAL_2026_COUNT" ]]; then
        FINAL_2026_COUNT="$(setup_2026_count 2>/dev/null || true)"
        echo "2026 Setup Session count before: $INITIAL_2026_COUNT"
        echo "2026 Setup Session count after:  $FINAL_2026_COUNT"
        if [[ -z "$FINAL_2026_COUNT" || "$FINAL_2026_COUNT" != "$INITIAL_2026_COUNT" ]]; then
            echo "FAIL: 2026 Setup Session count changed"
            status=95
        fi
    fi

    if [[ "$BACKUP_CREATED" -eq 1 && -s "$BACKUP_FILE" ]]; then
        echo "Rollback archive retained at: $BACKUP_FILE"
        echo "Rollback SHA256: $BACKUP_SHA"
    else
        echo "Rollback archive: not created before this stop"
    fi
    echo "Deployment report retained at: $REPORT"
    echo "Exit status: $status"
    exit "$status"
}
trap cleanup EXIT HUP INT TERM

sudo -v

echo "========== SETUP #206 V0.3.20 MATERIAL AUTHORITY PRODUCTION DEPLOYMENT =========="
echo "Authority: Gregovate/MSB-Server-Management — docs/server/Production_Database_Change_Deployment_Runbook.md"
echo "Frozen accepted SHA:       $TARGET_SHA"
echo "Expected live SHA:         $EXPECTED_LIVE_SHA"
echo "Expected pre-version:      $EXPECTED_PRE_VERSION"
echo "Expected post-version:     $EXPECTED_POST_VERSION"
echo "Migration 063:             $M063_REL"
echo "Migration 064:             $M064_REL"
echo "Report:                    $REPORT"
echo

[[ "$(hostname)" == "msb-prod-db" ]] || { echo "FAIL: wrong host"; exit 2; }

sudo docker inspect "$PROD_CONTAINER" >/dev/null
[[ "$(sudo docker inspect "$PROD_CONTAINER" --format '{{.Config.Image}}')" == "postgis/postgis:16-3.5" ]] \
    || { echo "FAIL: unexpected PostgreSQL image"; exit 3; }

if ! sudo git -C "$REPO_ROOT" worktree list --porcelain | grep -Fq "worktree $SETUP_ROOT"; then
    echo "FAIL: $SETUP_ROOT is not a registered worktree"
    exit 4
fi
[[ -z "$(sudo git -C "$REPO_ROOT" status --porcelain)" ]] \
    || { echo "FAIL: shared repository checkout is dirty"; exit 5; }

OLD_HEAD="$(sudo git -C "$SETUP_ROOT" rev-parse HEAD)"
echo "Live Setup SHA: $OLD_HEAD"
[[ "$OLD_HEAD" == "$EXPECTED_LIVE_SHA" ]] \
    || { echo "FAIL: live Setup SHA is not the expected pre-deploy SHA"; exit 6; }
[[ -z "$(sudo git -C "$SETUP_ROOT" status --porcelain)" ]] \
    || { echo "FAIL: live Setup checkout is dirty"; exit 7; }
systemctl is-active --quiet "$SETUP_SERVICE" \
    || { echo "FAIL: Setup service is not active"; exit 8; }

PRE_HEALTH="$(curl -fsS http://192.168.5.9:8794/api/health)"
echo "Pre-deploy health: $PRE_HEALTH"
[[ "$PRE_HEALTH" == *'"status":"ok"'* \
   && "$PRE_HEALTH" == *'"data_mode":"postgres"'* \
   && "$PRE_HEALTH" == *"\"version\":\"$EXPECTED_PRE_VERSION\""* ]] \
    || { echo "FAIL: live Setup health/version is not expected V0.3.19"; exit 9; }

INITIAL_CORE_FP="$(core_fingerprint)"
INITIAL_MATERIAL_FP="$(material_fingerprint)"
INITIAL_2026_COUNT="$(setup_2026_count)"
[[ -n "$INITIAL_CORE_FP" && -n "$INITIAL_MATERIAL_FP" ]] \
    || { echo "FAIL: Production fingerprints unavailable"; exit 10; }
[[ "$INITIAL_2026_COUNT" == "1" ]] \
    || { echo "FAIL: expected exactly one 2026 Setup Session"; exit 11; }
echo "Initial core Setup fingerprint: $INITIAL_CORE_FP"
echo "Initial material fingerprint:   $INITIAL_MATERIAL_FP"

echo
echo "--- Fetch and verify frozen accepted target ---"
sudo git -C "$REPO_ROOT" fetch origin "$TARGET_REF:refs/remotes/origin/$TARGET_REF"
sudo git -C "$REPO_ROOT" cat-file -e "$TARGET_SHA^{commit}"
sudo git -C "$REPO_ROOT" merge-base --is-ancestor "$OLD_HEAD" "$TARGET_SHA" \
    || { echo "FAIL: target is not a forward descendant of live Setup"; exit 12; }
sudo git -C "$REPO_ROOT" merge-base --is-ancestor "$TARGET_SHA" "origin/$TARGET_REF" \
    || { echo "FAIL: target is not contained in remote accepted branch"; exit 13; }

ACTUAL_063="$(sudo git -C "$REPO_ROOT" rev-parse "$TARGET_SHA:$M063_REL")"
ACTUAL_064="$(sudo git -C "$REPO_ROOT" rev-parse "$TARGET_SHA:$M064_REL")"
[[ "$ACTUAL_063" == "$M063_BLOB" ]] || { echo "FAIL: migration 063 blob mismatch"; exit 14; }
[[ "$ACTUAL_064" == "$M064_BLOB" ]] || { echo "FAIL: migration 064 blob mismatch"; exit 15; }
echo "Target ancestry/migration blobs: PASS"

echo
echo "--- Detached exact-target Production-runtime regression ---"
sudo git -C "$REPO_ROOT" worktree add --detach "$CANDIDATE_WORKTREE" "$TARGET_SHA"
M063="$CANDIDATE_WORKTREE/$M063_REL"
M064="$CANDIDATE_WORKTREE/$M064_REL"
test -s "$M063"
test -s "$M064"

grep -Fq 'PRODUCTION_VERSION = "V0.3.20-material-authority"' "$CANDIDATE_WORKTREE/Setup/Application/production_backend.py"
grep -Fq "CLIENT_BUILD = 'V0.3.20-material-authority'" "$CANDIDATE_WORKTREE/Setup/Application/setup_catalog_dirty_guard.js"
grep -Fq "$EXPECTED_DIRTY_GUARD_PIN" "$CANDIDATE_WORKTREE/Setup/Application/production.html"
grep -Fq "$EXPECTED_EXTRA_MATERIAL_PIN" "$CANDIDATE_WORKTREE/Setup/Application/production.html"
grep -Fq "$EXPECTED_KIT_CSS_PIN" "$CANDIDATE_WORKTREE/Setup/Application/kit_inventory.html"
grep -Fq "$EXPECTED_KIT_JS_PIN" "$CANDIDATE_WORKTREE/Setup/Application/kit_inventory.html"

sudo -u fieldwiring -H env PYTHONPYCACHEPREFIX="$DETACHED_PYCACHE" \
    bash -c "cd '$CANDIDATE_WORKTREE' && '$PYTHON' -m pytest -q -p no:cacheprovider Setup/Application"
echo "DETACHED V0.3.20 SETUP REGRESSION: PASS"

echo
echo "--- Freeze Setup writes for bounded Production mutation window ---"
sudo systemctl stop "$SETUP_SERVICE"
SETUP_STOPPED=1
! systemctl is-active --quiet "$SETUP_SERVICE" \
    || { echo "FAIL: Setup service did not stop"; exit 16; }

FROZEN_CORE_FP="$(core_fingerprint)"
FROZEN_MATERIAL_FP="$(material_fingerprint)"
[[ "$FROZEN_CORE_FP" == "$INITIAL_CORE_FP" ]] \
    || { echo "FAIL: core Setup data changed before mutation"; exit 17; }
[[ "$FROZEN_MATERIAL_FP" == "$INITIAL_MATERIAL_FP" ]] \
    || { echo "FAIL: material authority data changed before mutation"; exit 18; }
[[ "$(setup_2026_count)" == "$INITIAL_2026_COUNT" ]] \
    || { echo "FAIL: 2026 Setup Session count changed before mutation"; exit 19; }
echo "WRITE-FREEZE STABILITY: PASS"

echo
echo "--- Create and validate rollback PostgreSQL archive ---"
sudo docker exec "$PROD_CONTAINER" pg_dump -U "$DB_ACTOR" -d "$PROD_DB" -Fc > "$BACKUP_FILE"
test -s "$BACKUP_FILE"
BACKUP_CREATED=1
BACKUP_SHA="$(sha256sum "$BACKUP_FILE" | awk '{print $1}')"
sudo docker exec -i "$PROD_CONTAINER" pg_restore --list < "$BACKUP_FILE" >/dev/null
echo "Rollback archive: $BACKUP_FILE"
echo "Rollback SHA256:  $BACKUP_SHA"
echo "ROLLBACK ARCHIVE VALIDATION: PASS"

echo
echo "--- Production database preflight for migrations 063 + 064 ---"
psql_prod <<'SQL'
DO $preflight$
BEGIN
    IF to_regclass('ref.setup_task_extra_material') IS NULL
       OR to_regclass('ref.setup_task_extra_material_source') IS NULL
       OR to_regclass('ref.setup_container_extra_material') IS NULL
       OR to_regclass('ops.setup_extra_material_inventory_event') IS NULL
       OR to_regprocedure('ref.setup_management_actor(text,boolean)') IS NULL
       OR to_regprocedure(
            'ref.set_setup_task_extra_material(text,bigint,bigint,integer,numeric,text,text,numeric,text,text,text,text,text,boolean)'
          ) IS NULL
       OR to_regprocedure(
            'ref.set_setup_task_extra_material_source(text,bigint,bigint,integer,numeric,text,text,boolean)'
          ) IS NULL THEN
        RAISE EXCEPTION 'Accepted Extra Material authority foundation is incomplete';
    END IF;

    IF to_regprocedure('ref.delete_setup_task_extra_material(text,bigint,bigint)') IS NOT NULL
       OR to_regprocedure('ref.restore_setup_task_extra_material(text,bigint,bigint)') IS NOT NULL THEN
        RAISE EXCEPTION 'Migration 063/064 command functions already or partially installed';
    END IF;

    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname='fieldwiring_app') THEN
        RAISE EXCEPTION 'fieldwiring_app role missing';
    END IF;
END
$preflight$;
SQL
echo "MIGRATION PREFLIGHT: PASS"

[[ "$(core_fingerprint)" == "$FROZEN_CORE_FP" ]]
[[ "$(material_fingerprint)" == "$FROZEN_MATERIAL_FP" ]]

echo
echo "--- Apply migration 063 only ---"
psql_prod < "$M063"
M063_COMMITTED=1
echo "MIGRATION 063: COMMITTED"

echo
echo "--- Apply migration 064 only ---"
psql_prod < "$M064"
M064_COMMITTED=1
echo "MIGRATION 064: COMMITTED"

echo
echo "--- Validate 063/064 least privilege and data preservation ---"
psql_prod <<'SQL'
DO $validate$
BEGIN
    IF to_regprocedure('ref.delete_setup_task_extra_material(text,bigint,bigint)') IS NULL THEN
        RAISE EXCEPTION 'Governed requirement delete command missing';
    END IF;
    IF to_regprocedure('ref.restore_setup_task_extra_material(text,bigint,bigint)') IS NULL THEN
        RAISE EXCEPTION 'Governed historical restore command missing';
    END IF;

    IF NOT has_function_privilege(
        'fieldwiring_app',
        'ref.delete_setup_task_extra_material(text,bigint,bigint)',
        'EXECUTE'
    ) THEN
        RAISE EXCEPTION 'fieldwiring_app lacks governed delete EXECUTE';
    END IF;
    IF NOT has_function_privilege(
        'fieldwiring_app',
        'ref.restore_setup_task_extra_material(text,bigint,bigint)',
        'EXECUTE'
    ) THEN
        RAISE EXCEPTION 'fieldwiring_app lacks governed restore EXECUTE';
    END IF;

    IF has_table_privilege('fieldwiring_app','ref.setup_task_extra_material','UPDATE')
       OR has_table_privilege('fieldwiring_app','ref.setup_task_extra_material','DELETE')
       OR has_table_privilege('fieldwiring_app','ref.setup_task_extra_material_source','DELETE') THEN
        RAISE EXCEPTION 'Forbidden broad Extra Material DML privilege detected';
    END IF;
END
$validate$;
SQL

[[ "$(core_fingerprint)" == "$FROZEN_CORE_FP" ]] \
    || { echo "FAIL: 063/064 changed core Setup data"; exit 20; }
[[ "$(material_fingerprint)" == "$FROZEN_MATERIAL_FP" ]] \
    || { echo "FAIL: 063/064 changed material authority rows/history"; exit 21; }
echo "MIGRATION 063/064 CONTRACT/DATA PRESERVATION: PASS"

echo
echo "--- Advance /opt/msb-setup to frozen V0.3.20 target ---"
sudo git -C "$SETUP_ROOT" checkout --detach "$TARGET_SHA"
APP_ADVANCED=1
[[ "$(sudo git -C "$SETUP_ROOT" rev-parse HEAD)" == "$TARGET_SHA" ]]
[[ -z "$(sudo git -C "$SETUP_ROOT" status --porcelain)" ]]
echo "EXACT V0.3.20 TARGET INSTALLED: PASS"

echo
echo "--- Restart and verify Setup V0.3.20 runtime ---"
restart_setup
SETUP_POST="$(curl -fsS http://192.168.5.9:8794/api/health)"
echo "Post-deploy health: $SETUP_POST"
[[ "$SETUP_POST" == *'"status":"ok"'* \
   && "$SETUP_POST" == *'"data_mode":"postgres"'* \
   && "$SETUP_POST" == *"\"version\":\"$EXPECTED_POST_VERSION\""* ]] \
    || { echo "FAIL: Setup health/version is not V0.3.20 material authority"; exit 22; }

ROOT_HTML="$(curl -fsS http://192.168.5.9:8794/)"
[[ "$ROOT_HTML" == *"$EXPECTED_DIRTY_GUARD_PIN"* \
   && "$ROOT_HTML" == *"$EXPECTED_EXTRA_MATERIAL_PIN"* ]] \
    || { echo "FAIL: V0.3.20 root asset pins are not live"; exit 23; }

GUARD_JS="$(curl -fsS http://192.168.5.9:8794/setup_catalog_dirty_guard.js)"
[[ "$GUARD_JS" == *"CLIENT_BUILD = 'V0.3.20-material-authority'"* \
   && "$GUARD_JS" == *"Client V0.3.20"* ]] \
    || { echo "FAIL: V0.3.20 client build badge/guard is not live"; exit 24; }

KIT_HTML="$(curl -fsS http://192.168.5.9:8794/kit-inventory/)"
[[ "$KIT_HTML" == *"$EXPECTED_KIT_CSS_PIN"* \
   && "$KIT_HTML" == *"$EXPECTED_KIT_JS_PIN"* \
   && "$KIT_HTML" == *"Edit / Remove"* \
   && "$KIT_HTML" == *"Count / Adjust"* ]] \
    || { echo "FAIL: accepted Kit Inventory shell is not live"; exit 25; }

EXTRA_JS="$(curl -fsS http://192.168.5.9:8794/setup_task_extra_material_sources.js)"
[[ "$EXTRA_JS" == *"humanContainerId"* \
   && "$EXTRA_JS" == *"ID or C###"* ]] \
    || { echo "FAIL: accepted C### source search behavior is not live"; exit 26; }
echo "LIVE V0.3.20 MATERIAL AUTHORITY ASSETS: PASS"

NEGATIVE_CODE="$(
    curl -sS -o "$NEGATIVE_BODY" -w '%{http_code}' \
      'http://192.168.5.9:8794/api/setup/material-readiness?season_year=2026'
)"
echo "Unauthenticated material-readiness status: $NEGATIVE_CODE"
[[ "$NEGATIVE_CODE" == "401" ]] \
    || { echo "FAIL: protected Setup API did not fail closed"; exit 27; }
echo "PROTECTED NEGATIVE PATH: PASS"

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
[[ -n "$MANAGER_EMAIL" ]] || { echo "FAIL: no active Setup Manager identity found"; exit 28; }

ACCESS_JSON="$(curl -fsS -H "Cf-Access-Authenticated-User-Email: $MANAGER_EMAIL" \
    http://192.168.5.9:8794/api/setup/access)"
printf '%s' "$ACCESS_JSON" | sudo -u fieldwiring -H "$PYTHON" -c '
import json, sys
payload=json.load(sys.stdin)
assert payload.get("can_manage_setup") is True or (payload.get("access") or {}).get("can_manage_setup") is True
'
echo "AUTHENTICATED MANAGER ACCESS: PASS"

echo
echo "--- Full live Setup regression ---"
sudo -u fieldwiring -H env PYTHONPYCACHEPREFIX="$LIVE_PYCACHE" \
    bash -c "cd '$SETUP_ROOT' && '$PYTHON' -m pytest -q -p no:cacheprovider Setup/Application"
echo "LIVE V0.3.20 SETUP REGRESSION: PASS"

echo
echo "--- Final Production invariants ---"
FINAL_HEAD="$(sudo git -C "$SETUP_ROOT" rev-parse HEAD)"
FINAL_CORE_FP="$(core_fingerprint)"
FINAL_MATERIAL_FP="$(material_fingerprint)"
FINAL_2026_COUNT="$(setup_2026_count)"
FINAL_HEALTH="$(curl -fsS http://192.168.5.9:8794/api/health)"

echo "Final Setup SHA:                $FINAL_HEAD"
echo "Final core Setup fingerprint:   $FINAL_CORE_FP"
echo "Final material fingerprint:     $FINAL_MATERIAL_FP"
echo "Final 2026 Setup Session count: $FINAL_2026_COUNT"
echo "Final Setup health:             $FINAL_HEALTH"

[[ "$FINAL_HEAD" == "$TARGET_SHA" ]]
[[ -z "$(sudo git -C "$SETUP_ROOT" status --porcelain)" ]]
[[ "$FINAL_CORE_FP" == "$FROZEN_CORE_FP" ]]
[[ "$FINAL_MATERIAL_FP" == "$FROZEN_MATERIAL_FP" ]]
[[ "$FINAL_2026_COUNT" == "$INITIAL_2026_COUNT" ]]
[[ "$FINAL_HEALTH" == *"\"version\":\"$EXPECTED_POST_VERSION\""* ]]

SUCCESS=1
echo
echo "SETUP_206_MATERIAL_AUTHORITY_PRODUCTION_DEPLOYMENT_PASS"
echo "Final SHA:          $FINAL_HEAD"
echo "Rollback archive:   $BACKUP_FILE"
echo "Rollback SHA256:    $BACKUP_SHA"
echo "Deployment report:  $REPORT"
