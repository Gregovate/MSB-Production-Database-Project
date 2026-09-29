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
TARGET_SHA="3cedba88283e4766932ae7905034856a2b9baa00"
EXPECTED_LIVE_SHA="947b86a9598584717167cce094cd78d99e9a71e7"
EXPECTED_VERSION="V0.3.20-material-authority"

EXPECTED_DIRTY_GUARD_PIN="setup_catalog_dirty_guard.js?v=2026-09-29.1"
EXPECTED_EXTRA_MATERIAL_PIN="setup_extra_materials.js?v=2026-09-29.1"
EXPECTED_NEXT_PASS_PIN="setup_next_pass.js?v=2026-09-29.1"
EXPECTED_KIT_CSS_PIN="setup_kit_inventory.css?v=2026-09-29.1"
EXPECTED_KIT_JS_PIN="setup_kit_inventory.js?v=2026-09-29.1"

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
STAMP="$(date +%Y%m%dT%H%M%S)"
REPORT_DIR="/home/msbadmin/setup-deployment-reports"
REPORT="$REPORT_DIR/Setup_206_Source_Only_Followup_Production_Deploy_$STAMP.txt"
CANDIDATE_WORKTREE="/tmp/msb-setup-206-source-only-candidate-$STAMP"
DETACHED_PYCACHE="/tmp/msb-setup-206-source-only-detached-$STAMP"
LIVE_PYCACHE="/tmp/msb-setup-206-source-only-live-$STAMP"
NEGATIVE_BODY="/tmp/msb-setup-206-source-only-negative-$STAMP.json"

OLD_HEAD=""
INITIAL_CORE_FP=""
INITIAL_MATERIAL_FP=""
DEPLOY_CORE_FP=""
DEPLOY_MATERIAL_FP=""
INITIAL_2026_COUNT=""
APP_ADVANCED=0
SUCCESS=0

mkdir -p "$REPORT_DIR"
exec > >(tee "$REPORT") 2>&1

core_fingerprint() {
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
    coalesce((SELECT string_agg(row_to_json(wd)::text, '' ORDER BY wd.setup_work_day_id) FROM ops.setup_work_day wd), '')
);
"
}

material_fingerprint() {
    sudo docker exec "$PROD_CONTAINER"         psql -X -qAt -v ON_ERROR_STOP=1 -U "$DB_ACTOR" -d "$PROD_DB" -c "
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
    sudo docker exec "$PROD_CONTAINER"         psql -X -qAt -v ON_ERROR_STOP=1 -U "$DB_ACTOR" -d "$PROD_DB"         -c "SELECT count(*) FROM ops.setup_session WHERE season_year=2026;"
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

    if [[ "$status" -ne 0 && "$SUCCESS" -ne 1 && "$APP_ADVANCED" -eq 1 && -n "$OLD_HEAD" ]]; then
        echo
        echo "--- SOURCE-ONLY FAIL-CLOSED ROLLBACK ---"
        echo "Returning /opt/msb-setup to $OLD_HEAD"
        sudo git -C "$SETUP_ROOT" checkout --detach "$OLD_HEAD" || true
        restart_setup_service || true
        echo "Source rollback attempted. PostgreSQL was not mutated."
    fi

    if sudo git -C "$REPO_ROOT" worktree list --porcelain 2>/dev/null        | grep -Fq "worktree $CANDIDATE_WORKTREE"; then
        sudo git -C "$REPO_ROOT" worktree remove --force "$CANDIDATE_WORKTREE" >/dev/null 2>&1 || true
    fi
    sudo git -C "$REPO_ROOT" worktree prune >/dev/null 2>&1 || true
    sudo rm -rf "$DETACHED_PYCACHE" "$LIVE_PYCACHE" >/dev/null 2>&1 || true
    rm -f "$NEGATIVE_BODY" >/dev/null 2>&1 || true
    rm -rf "$SCRIPT_DIR" >/dev/null 2>&1 || true

    echo
    echo "--- Production after-check ---"
    if [[ -n "$DEPLOY_CORE_FP" ]]; then
        FINAL_CORE_FP="$(core_fingerprint 2>/dev/null || true)"
        echo "Deployment core fingerprint before: $DEPLOY_CORE_FP"
        echo "Production core fingerprint after:   $FINAL_CORE_FP"
        if [[ -z "$FINAL_CORE_FP" || "$FINAL_CORE_FP" != "$DEPLOY_CORE_FP" ]]; then
            echo "FAIL: source-only deployment changed governed core Setup data"
            status=97
        fi
    fi
    if [[ -n "$DEPLOY_MATERIAL_FP" ]]; then
        FINAL_MATERIAL_FP="$(material_fingerprint 2>/dev/null || true)"
        echo "Deployment material fingerprint before: $DEPLOY_MATERIAL_FP"
        echo "Production material fingerprint after:   $FINAL_MATERIAL_FP"
        if [[ -z "$FINAL_MATERIAL_FP" || "$FINAL_MATERIAL_FP" != "$DEPLOY_MATERIAL_FP" ]]; then
            echo "FAIL: source-only deployment changed governed material data"
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

    FINAL_HEAD="$(sudo git -C "$SETUP_ROOT" rev-parse HEAD 2>/dev/null || true)"
    FINAL_HEALTH="$(curl -fsS http://192.168.5.9:8794/api/health 2>/dev/null || true)"
    echo "Final Setup SHA:    $FINAL_HEAD"
    echo "Final Setup health: $FINAL_HEALTH"
    echo "PostgreSQL rollback archive: NOT REQUIRED / NOT CREATED"
    echo "Deployment report retained at: $REPORT"
    echo "Exit status: $status"
    exit "$status"
}
trap cleanup EXIT HUP INT TERM

sudo -v

echo "========== SETUP #206 V0.3.20 SOURCE-ONLY FOLLOW-UP PRODUCTION DEPLOYMENT =========="
echo "Authority: Gregovate/MSB-Server-Management — docs/server/Setup_Source_Only_Application_Deployment_Runbook.md"
echo "Procedure: Controlled Production Mutation — source only"
echo "Database migration: NONE"
echo "Environment/service-unit/proxy/firewall mutation: NONE"
echo "Accepted target:     $TARGET_SHA"
echo "Expected live SHA:   $EXPECTED_LIVE_SHA"
echo "Expected version:    $EXPECTED_VERSION"
echo "Report:              $REPORT"
echo

[[ "$(hostname)" == "msb-prod-db" ]] || { echo "FAIL: wrong host"; exit 2; }

sudo docker inspect "$PROD_CONTAINER" >/dev/null
if ! sudo git -C "$REPO_ROOT" worktree list --porcelain | grep -Fq "worktree $SETUP_ROOT"; then
    echo "FAIL: $SETUP_ROOT is not a registered worktree"
    exit 3
fi
[[ -z "$(sudo git -C "$REPO_ROOT" status --porcelain)" ]]     || { echo "FAIL: shared repository checkout is dirty"; exit 4; }

OLD_HEAD="$(sudo git -C "$SETUP_ROOT" rev-parse HEAD)"
echo "Verified live Setup SHA: $OLD_HEAD"
[[ "$OLD_HEAD" == "$EXPECTED_LIVE_SHA" ]]     || { echo "FAIL: live Setup SHA is not the expected accepted V0.3.20 base"; exit 5; }
[[ -z "$(sudo git -C "$SETUP_ROOT" status --porcelain)" ]]     || { echo "FAIL: live Setup worktree is not clean"; exit 6; }
systemctl is-active --quiet "$SETUP_SERVICE"     || { echo "FAIL: msb-setup.service is not active"; exit 7; }

PRE_HEALTH="$(curl -fsS http://192.168.5.9:8794/api/health)"
echo "Pre-deploy Setup health: $PRE_HEALTH"
[[ "$PRE_HEALTH" == *'"status":"ok"'*    && "$PRE_HEALTH" == *'"data_mode":"postgres"'*    && "$PRE_HEALTH" == *"\"version\":\"$EXPECTED_VERSION\""* ]]     || { echo "FAIL: current Setup runtime is not healthy V0.3.20 PostgreSQL mode"; exit 8; }

INITIAL_CORE_FP="$(core_fingerprint)"
INITIAL_MATERIAL_FP="$(material_fingerprint)"
INITIAL_2026_COUNT="$(setup_2026_count)"
[[ -n "$INITIAL_CORE_FP" && -n "$INITIAL_MATERIAL_FP" ]]     || { echo "FAIL: Production fingerprints unavailable"; exit 9; }
echo "Initial core Setup fingerprint: $INITIAL_CORE_FP"
echo "Initial material fingerprint:   $INITIAL_MATERIAL_FP"
echo "Initial 2026 Setup Session count: $INITIAL_2026_COUNT"

echo
echo "--- Fetch and prove exact accepted target ancestry ---"
sudo git -C "$REPO_ROOT" fetch origin "$TARGET_REF:refs/remotes/origin/$TARGET_REF"
sudo git -C "$REPO_ROOT" cat-file -e "$TARGET_SHA^{commit}"
sudo git -C "$REPO_ROOT" merge-base --is-ancestor "$OLD_HEAD" "$TARGET_SHA"     || { echo "FAIL: source-only target is not a forward descendant of live Setup"; exit 10; }
sudo git -C "$REPO_ROOT" merge-base --is-ancestor "$TARGET_SHA" "origin/$TARGET_REF"     || { echo "FAIL: accepted target is not contained in remote approved ref"; exit 11; }
echo "Forward ancestry: PASS ($OLD_HEAD -> $TARGET_SHA)"

echo
echo "--- Confirm source-only diff boundary ---"
DIFF_NAMES="$(sudo git -C "$REPO_ROOT" diff --name-only "$OLD_HEAD..$TARGET_SHA")"
printf '%s\n' "$DIFF_NAMES"
if printf '%s\n' "$DIFF_NAMES" | grep -Eq '^Setup/Database/|(^|/)[^/]*\.service$|setup\.env$|(^|/)(nginx|cloudflare|ufw)(/|$)'; then
    echo "FAIL: target contains a database/environment/service/proxy/firewall path"
    exit 12
fi
echo "SOURCE-ONLY DIFF BOUNDARY: PASS"

echo
echo "--- Detached exact-target regression in Production runtime ---"
sudo git -C "$REPO_ROOT" worktree add --detach "$CANDIDATE_WORKTREE" "$TARGET_SHA"

grep -Fq 'PRODUCTION_VERSION = "V0.3.20-material-authority"' "$CANDIDATE_WORKTREE/Setup/Application/production_backend.py"
grep -Fq "CLIENT_BUILD = 'V0.3.20-material-authority'" "$CANDIDATE_WORKTREE/Setup/Application/setup_catalog_dirty_guard.js"
grep -Fq "badge.textContent = ok ? 'Client V0.3.20'" "$CANDIDATE_WORKTREE/Setup/Application/setup_catalog_dirty_guard.js"
grep -Fq "$EXPECTED_DIRTY_GUARD_PIN" "$CANDIDATE_WORKTREE/Setup/Application/production.html"
grep -Fq "$EXPECTED_EXTRA_MATERIAL_PIN" "$CANDIDATE_WORKTREE/Setup/Application/production.html"
grep -Fq "$EXPECTED_NEXT_PASS_PIN" "$CANDIDATE_WORKTREE/Setup/Application/production.html"
grep -Fq "$EXPECTED_KIT_CSS_PIN" "$CANDIDATE_WORKTREE/Setup/Application/kit_inventory.html"
grep -Fq "$EXPECTED_KIT_JS_PIN" "$CANDIDATE_WORKTREE/Setup/Application/kit_inventory.html"
grep -Fq "Already linked — use Change" "$CANDIDATE_WORKTREE/Setup/Application/setup_task_extra_material_sources.js"
grep -Fq "Task / Kit spec differs. Material identity and source relationship are already linked." "$CANDIDATE_WORKTREE/Setup/Application/setup_kit_inventory.js"
grep -Fq "organizationStatus: 'idle'" "$CANDIDATE_WORKTREE/Setup/Application/setup_next_pass.js"
grep -Fq "Loading reusable Catalog organization…" "$CANDIDATE_WORKTREE/Setup/Application/setup_next_pass.js"
! grep -Fq "priorNextRenderLibrary" "$CANDIDATE_WORKTREE/Setup/Application/setup_next_pass.js"

sudo -u fieldwiring -H env PYTHONPYCACHEPREFIX="$DETACHED_PYCACHE"     bash -c "cd '$CANDIDATE_WORKTREE' && '$PYTHON' -m pytest -q -p no:cacheprovider Setup/Application"
echo "DETACHED EXACT-TARGET SETUP REGRESSION: PASS"

DEPLOY_CORE_FP="$(core_fingerprint)"
DEPLOY_MATERIAL_FP="$(material_fingerprint)"
[[ "$DEPLOY_CORE_FP" == "$INITIAL_CORE_FP" ]]     || { echo "FAIL: core Setup data changed during source-only preflight"; exit 13; }
[[ "$DEPLOY_MATERIAL_FP" == "$INITIAL_MATERIAL_FP" ]]     || { echo "FAIL: material data changed during source-only preflight"; exit 14; }
[[ "$(setup_2026_count)" == "$INITIAL_2026_COUNT" ]]     || { echo "FAIL: 2026 Setup Session count changed during preflight"; exit 15; }
echo "PRE-MUTATION DATA STABILITY: PASS"

echo
echo "Authority: Gregovate/MSB-Server-Management — docs/server/Setup_Source_Only_Application_Deployment_Runbook.md"
echo "Procedure: Controlled Production Mutation"
echo "This step: advance /opt/msb-setup from $OLD_HEAD to exact approved $TARGET_SHA"
echo "Database/environment/service-unit/proxy/firewall mutation: NONE"
sudo git -C "$SETUP_ROOT" checkout --detach "$TARGET_SHA"
APP_ADVANCED=1

DEPLOYED_HEAD="$(sudo git -C "$SETUP_ROOT" rev-parse HEAD)"
[[ "$DEPLOYED_HEAD" == "$TARGET_SHA" ]]     || { echo "FAIL: deployed Setup SHA is $DEPLOYED_HEAD, expected $TARGET_SHA"; exit 16; }
[[ -z "$(sudo git -C "$SETUP_ROOT" status --porcelain)" ]]     || { echo "FAIL: deployed Setup worktree is not clean"; exit 17; }

echo
echo "--- Restart only msb-setup.service and verify runtime ---"
restart_setup_service
POST_HEALTH="$(curl -fsS http://192.168.5.9:8794/api/health)"
echo "Post-deploy Setup health: $POST_HEALTH"
[[ "$POST_HEALTH" == *'"status":"ok"'*    && "$POST_HEALTH" == *'"data_mode":"postgres"'*    && "$POST_HEALTH" == *"\"version\":\"$EXPECTED_VERSION\""* ]]     || { echo "FAIL: Setup runtime did not return healthy V0.3.20"; exit 18; }

echo
echo "--- Verify accepted source-only assets are live ---"
ROOT_HTML="$(curl -fsS http://192.168.5.9:8794/)"
for asset in     "$EXPECTED_DIRTY_GUARD_PIN"     "$EXPECTED_EXTRA_MATERIAL_PIN"     "$EXPECTED_NEXT_PASS_PIN"; do
    [[ "$ROOT_HTML" == *"$asset"* ]]         || { echo "FAIL: deployed Setup HTML is missing accepted asset pin: $asset"; exit 19; }
done

GUARD_JS="$(curl -fsS http://192.168.5.9:8794/setup_catalog_dirty_guard.js)"
[[ "$GUARD_JS" == *"CLIENT_BUILD = 'V0.3.20-material-authority'"*    && "$GUARD_JS" == *"badge.textContent = ok ? 'Client V0.3.20'"* ]]     || { echo "FAIL: healthy V0.3.20 badge correction is not live"; exit 20; }

NEXT_JS="$(curl -fsS http://192.168.5.9:8794/setup_next_pass.js)"
[[ "$NEXT_JS" == *"organizationStatus: 'idle'"*    && "$NEXT_JS" == *"Loading reusable Catalog organization…"*    && "$NEXT_JS" != *"priorNextRenderLibrary"* ]]     || { echo "FAIL: deterministic Catalog organization gate is not live"; exit 21; }

SOURCE_JS="$(curl -fsS http://192.168.5.9:8794/setup_task_extra_material_sources.js)"
[[ "$SOURCE_JS" == *"Already linked — use Change"* ]]     || { echo "FAIL: already-linked source guidance is not live"; exit 22; }

KIT_HTML="$(curl -fsS http://192.168.5.9:8794/kit-inventory/)"
[[ "$KIT_HTML" == *"$EXPECTED_KIT_CSS_PIN"*    && "$KIT_HTML" == *"$EXPECTED_KIT_JS_PIN"* ]]     || { echo "FAIL: accepted Kit Inventory asset pins are not live"; exit 23; }
echo "ACCEPTED SOURCE-ONLY ASSETS: PASS"

NEGATIVE_CODE="$(curl -sS -o "$NEGATIVE_BODY" -w '%{http_code}'     'http://192.168.5.9:8794/api/setup/organization')"
echo "Direct unauthenticated organization API status: $NEGATIVE_CODE"
[[ "$NEGATIVE_CODE" == "401" ]]     || { echo "FAIL: protected Setup organization API did not reject unauthenticated direct request"; exit 24; }
echo "PROTECTED ORGANIZATION NEGATIVE PATH: PASS"

echo
echo "--- Full live Setup regression ---"
sudo -u fieldwiring -H env PYTHONPYCACHEPREFIX="$LIVE_PYCACHE"     bash -c "cd '$SETUP_ROOT' && '$PYTHON' -m pytest -q -p no:cacheprovider Setup/Application"
echo "LIVE SETUP REGRESSION: PASS"

POST_CORE_FP="$(core_fingerprint)"
POST_MATERIAL_FP="$(material_fingerprint)"
echo "Core fingerprint before source deployment:     $DEPLOY_CORE_FP"
echo "Core fingerprint after source deployment:      $POST_CORE_FP"
echo "Material fingerprint before source deployment: $DEPLOY_MATERIAL_FP"
echo "Material fingerprint after source deployment:  $POST_MATERIAL_FP"
[[ "$POST_CORE_FP" == "$DEPLOY_CORE_FP" ]]     || { echo "FAIL: source-only deployment changed core Setup data"; exit 25; }
[[ "$POST_MATERIAL_FP" == "$DEPLOY_MATERIAL_FP" ]]     || { echo "FAIL: source-only deployment changed material authority data"; exit 26; }
[[ "$(setup_2026_count)" == "$INITIAL_2026_COUNT" ]]     || { echo "FAIL: 2026 Setup Session count changed"; exit 27; }

SUCCESS=1
echo
echo "SETUP_206_SOURCE_ONLY_FOLLOWUP_PRODUCTION_DEPLOYMENT_PASS"
echo "Prior / rollback SHA: $OLD_HEAD"
echo "Deployed exact SHA:   $TARGET_SHA"
echo "Expected version:     $EXPECTED_VERSION"
echo "Database migration:   NONE"
echo "Deployment report:    $REPORT"
echo "Protected /setup/ operator validation: REQUIRED NEXT"
