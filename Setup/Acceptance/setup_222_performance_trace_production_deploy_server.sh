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
EXPECTED_LIVE_SHA="1b08bdd26156b67ba89ea484fdc035b0b09ffc28"
TARGET_SHA="64835504962247d7a09c1146e5e77d8e19948559"
EXPECTED_PRE_VERSION="V0.3.16-stale-ownership-cleanup"
EXPECTED_POST_VERSION="V0.3.17-performance-trace"

REPORT_DIR="/home/msbadmin/setup-deployment-reports"
STAMP="$(date +%Y%m%dT%H%M%S)"
REPORT="$REPORT_DIR/Setup_222_Performance_Trace_Production_Deploy_$STAMP.txt"
CANDIDATE_WORKTREE="/tmp/msb-setup-222-perf-candidate-$STAMP"
DETACHED_PYCACHE="/tmp/msb-setup-222-perf-detached-$STAMP"
LIVE_PYCACHE="/tmp/msb-setup-222-perf-live-$STAMP"
PROBE_HEADERS="/tmp/msb-setup-222-perf-headers-$STAMP.txt"
PROBE_BODY="/tmp/msb-setup-222-perf-body-$STAMP.txt"
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

OLD_HEAD=""
PROD_BEFORE=""
APP_ADVANCED=0
SUCCESS=0

mkdir -p "$REPORT_DIR"
exec > >(tee "$REPORT") 2>&1

echo "========== SETUP #222 PERFORMANCE TRACE PRODUCTION DEPLOYMENT =========="
echo "Authority: Gregovate/MSB-Server-Management — docs/server/Setup_Source_Only_Application_Deployment_Runbook.md"
echo "Procedure: Controlled Production Mutation — source only"
echo "Database mutation: NONE"
echo "Environment/service-unit/proxy/firewall mutation: NONE"
echo "Expected live SHA: $EXPECTED_LIVE_SHA"
echo "Accepted target:   $TARGET_SHA"
echo "Report:            $REPORT"
echo

prod_fingerprint() {
    sudo docker exec "$PROD_CONTAINER"         psql -X -qAt -v ON_ERROR_STOP=1 -U "$DB_ACTOR" -d "$PROD_DB" -c "
            SELECT md5(
                coalesce((SELECT string_agg(row_to_json(t)::text, '' ORDER BY t.setup_task_id)
                          FROM ref.setup_task t), '') || '|' ||
                coalesce((SELECT string_agg(row_to_json(r)::text, '' ORDER BY r.setup_resource_id)
                          FROM ref.setup_resource r), '') || '|' ||
                coalesce((SELECT string_agg(row_to_json(tr)::text, '' ORDER BY tr.setup_task_id, tr.setup_resource_id)
                          FROM ref.setup_task_resource tr), '') || '|' ||
                coalesce((SELECT string_agg(row_to_json(s)::text, '' ORDER BY s.setup_session_id)
                          FROM ops.setup_session s), '') || '|' ||
                coalesce((SELECT string_agg(row_to_json(st)::text, '' ORDER BY st.setup_session_task_id)
                          FROM ops.setup_session_task st), '') || '|' ||
                coalesce((SELECT string_agg(row_to_json(wd)::text, '' ORDER BY wd.setup_work_day_id)
                          FROM ops.setup_work_day wd), '')
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
        echo "Source rollback attempted; PostgreSQL was not mutated."
    fi

    if sudo git -C "$REPO_ROOT" worktree list --porcelain 2>/dev/null | grep -Fq "worktree $CANDIDATE_WORKTREE"; then
        sudo git -C "$REPO_ROOT" worktree remove --force "$CANDIDATE_WORKTREE" >/dev/null 2>&1 || true
    fi
    sudo git -C "$REPO_ROOT" worktree prune >/dev/null 2>&1 || true
    sudo rm -rf "$DETACHED_PYCACHE" "$LIVE_PYCACHE" >/dev/null 2>&1 || true
    rm -f "$PROBE_HEADERS" "$PROBE_BODY" >/dev/null 2>&1 || true
    rm -rf "$SCRIPT_DIR" >/dev/null 2>&1 || true

    echo
    echo "--- Production after-check ---"
    if [[ -n "$PROD_BEFORE" ]]; then
        PROD_AFTER="$(prod_fingerprint 2>/dev/null || true)"
        echo "Production Setup fingerprint before: $PROD_BEFORE"
        echo "Production Setup fingerprint after:  $PROD_AFTER"
        if [[ -z "$PROD_AFTER" || "$PROD_AFTER" != "$PROD_BEFORE" ]]; then
            echo "FAIL: source-only #222 deployment changed governed Setup data"
            status=97
        else
            echo "PASS: governed Setup data unchanged"
        fi
    fi

    FINAL_2026="$(setup_2026_count 2>/dev/null || true)"
    echo "Final 2026 Setup Session count: ${FINAL_2026:-unknown}"
    if [[ -n "$FINAL_2026" && "$FINAL_2026" != "0" ]]; then
        echo "FAIL: #222 deployment created or observed a real 2026 Setup Session"
        status=96
    fi

    FINAL_HEAD="$(sudo git -C "$SETUP_ROOT" rev-parse HEAD 2>/dev/null || true)"
    FINAL_HEALTH="$(curl -fsS http://192.168.5.9:8794/api/health 2>/dev/null || true)"
    echo "Final Setup SHA:    $FINAL_HEAD"
    echo "Final Setup health: $FINAL_HEALTH"
    echo "Deployment report retained at: $REPORT"
    echo "Exit status: $status"
    exit "$status"
}
trap cleanup EXIT HUP INT TERM

sudo -v

echo "--- Verify current Production state ---"
if ! sudo docker inspect "$PROD_CONTAINER" >/dev/null 2>&1; then
    echo "FAIL: Production PostgreSQL container not found"
    exit 2
fi
if ! sudo git -C "$REPO_ROOT" worktree list --porcelain | grep -Fq "worktree $SETUP_ROOT"; then
    echo "FAIL: $SETUP_ROOT is not registered as a worktree of $REPO_ROOT"
    exit 3
fi
if [[ -n "$(sudo git -C "$REPO_ROOT" status --porcelain)" ]]; then
    echo "FAIL: shared repository checkout has uncommitted changes"
    exit 4
fi

OLD_HEAD="$(sudo git -C "$SETUP_ROOT" rev-parse HEAD)"
if [[ "$OLD_HEAD" != "$EXPECTED_LIVE_SHA" ]]; then
    echo "FAIL: live Setup SHA changed from the verified pre-#222 state"
    echo "Expected: $EXPECTED_LIVE_SHA"
    echo "Actual:   $OLD_HEAD"
    exit 5
fi
if [[ -n "$(sudo git -C "$SETUP_ROOT" status --porcelain)" ]]; then
    echo "FAIL: live Setup worktree is not clean"
    exit 6
fi
if ! systemctl is-active --quiet "$SETUP_SERVICE"; then
    echo "FAIL: msb-setup.service is not active"
    exit 7
fi

SETUP_PRE="$(curl -fsS http://192.168.5.9:8794/api/health)"
echo "Pre-deploy Setup health: $SETUP_PRE"
if [[ "$SETUP_PRE" != *"\"status\":\"ok\""*    || "$SETUP_PRE" != *"\"data_mode\":\"postgres\""*    || "$SETUP_PRE" != *"\"version\":\"$EXPECTED_PRE_VERSION\""* ]]; then
    echo "FAIL: current Setup runtime is not the verified V0.3.16 state"
    exit 8
fi

if [[ "$(setup_2026_count)" != "0" ]]; then
    echo "FAIL: real 2026 Setup Session exists before #222 source-only deployment"
    exit 9
fi

PROD_BEFORE="$(prod_fingerprint)"
[[ -n "$PROD_BEFORE" ]] || { echo "FAIL: Production Setup fingerprint is empty"; exit 10; }
echo "Production Setup fingerprint before: $PROD_BEFORE"

echo
echo "--- Fetch and prove exact accepted target ancestry ---"
sudo git -C "$REPO_ROOT" fetch origin "$TARGET_REF:refs/remotes/origin/$TARGET_REF"
sudo git -C "$REPO_ROOT" cat-file -e "$TARGET_SHA^{commit}"
if ! sudo git -C "$REPO_ROOT" merge-base --is-ancestor "$TARGET_SHA" "origin/$TARGET_REF"; then
    echo "FAIL: exact accepted #222 target is not contained in merged origin/main"
    exit 11
fi
if ! sudo git -C "$REPO_ROOT" merge-base --is-ancestor "$OLD_HEAD" "$TARGET_SHA"; then
    echo "FAIL: accepted #222 target is not a forward descendant of live Setup"
    exit 12
fi
echo "Forward ancestry: PASS ($OLD_HEAD -> $TARGET_SHA)"

echo
echo "--- Detached exact-target regression in Production runtime ---"
sudo git -C "$REPO_ROOT" worktree add --detach "$CANDIDATE_WORKTREE" "$TARGET_SHA"
sudo -u fieldwiring -H env PYTHONPYCACHEPREFIX="$DETACHED_PYCACHE" bash -c     "cd '$CANDIDATE_WORKTREE' && '$PYTHON' -m pytest -q -p no:cacheprovider Setup/Application"
echo "DETACHED EXACT-TARGET SETUP REGRESSION: PASS"

echo
echo "Authority: Gregovate/MSB-Server-Management — docs/server/Setup_Source_Only_Application_Deployment_Runbook.md"
echo "Procedure: Controlled Production Mutation"
echo "This step: advance /opt/msb-setup from $OLD_HEAD to exact approved $TARGET_SHA"
echo "Database/environment/service-unit/proxy/firewall mutation: NONE"
sudo git -C "$SETUP_ROOT" checkout --detach "$TARGET_SHA"
APP_ADVANCED=1

DEPLOYED_HEAD="$(sudo git -C "$SETUP_ROOT" rev-parse HEAD)"
if [[ "$DEPLOYED_HEAD" != "$TARGET_SHA" ]]; then
    echo "FAIL: deployed Setup SHA is $DEPLOYED_HEAD, expected $TARGET_SHA"
    exit 13
fi
if [[ -n "$(sudo git -C "$SETUP_ROOT" status --porcelain)" ]]; then
    echo "FAIL: deployed Setup worktree is not clean"
    exit 14
fi

echo
echo "--- Restart only msb-setup.service and verify V0.3.17 ---"
restart_setup_service
SETUP_POST="$(curl -fsS http://192.168.5.9:8794/api/health)"
echo "Post-deploy Setup health: $SETUP_POST"
if [[ "$SETUP_POST" != *"\"status\":\"ok\""*    || "$SETUP_POST" != *"\"data_mode\":\"postgres\""*    || "$SETUP_POST" != *"\"version\":\"$EXPECTED_POST_VERSION\""* ]]; then
    echo "FAIL: Setup runtime did not become $EXPECTED_POST_VERSION"
    exit 15
fi

echo
echo "--- Validate trace headers and journal emission ---"
PROBE_START="$(date --iso-8601=seconds)"
curl -sS -D "$PROBE_HEADERS" -o "$PROBE_BODY"     -H 'Cf-Access-Authenticated-User-Email: performance-probe@invalid.local'     http://192.168.5.9:8794/api/setup/access
if ! grep -qi '^Server-Timing: app;dur=' "$PROBE_HEADERS"; then
    echo "FAIL: Setup API response did not include Server-Timing"
    cat "$PROBE_HEADERS"
    exit 16
fi
PROBE_REQUEST_ID="$(awk -F': ' 'tolower($1)=="x-msb-request-id"{gsub("\r","",$2); print $2}' "$PROBE_HEADERS" | tail -1)"
if [[ -z "$PROBE_REQUEST_ID" ]]; then
    echo "FAIL: Setup API response did not include X-MSB-Request-ID"
    exit 17
fi
sleep 1
if ! journalctl -u "$SETUP_SERVICE" --since "$PROBE_START" --no-pager     | grep -F "SETUP_PERF request_id=$PROBE_REQUEST_ID operator=performance-probe@invalid.local" >/dev/null; then
    echo "FAIL: performance probe did not reach msb-setup.service journal"
    journalctl -u "$SETUP_SERVICE" --since "$PROBE_START" --no-pager || true
    exit 18
fi
echo "PERFORMANCE TRACE HEADERS / JOURNAL: PASS ($PROBE_REQUEST_ID)"

echo
echo "--- Live Setup regression ---"
sudo -u fieldwiring -H env PYTHONPYCACHEPREFIX="$LIVE_PYCACHE" bash -c     "cd '$SETUP_ROOT' && '$PYTHON' -m pytest -q -p no:cacheprovider Setup/Application"
echo "LIVE SETUP REGRESSION: PASS"

POST_SOURCE_FINGERPRINT="$(prod_fingerprint)"
echo "Fingerprint before source deployment: $PROD_BEFORE"
echo "Fingerprint after source deployment:  $POST_SOURCE_FINGERPRINT"
if [[ "$POST_SOURCE_FINGERPRINT" != "$PROD_BEFORE" ]]; then
    echo "FAIL: source-only #222 deployment changed governed Setup data"
    exit 19
fi

FINAL_2026="$(setup_2026_count)"
if [[ "$FINAL_2026" != "0" ]]; then
    echo "FAIL: a real 2026 Setup Session exists after #222 deployment"
    exit 20
fi

SUCCESS=1
echo
echo "SETUP_222_PERFORMANCE_TRACE_PRODUCTION_DEPLOYMENT_PASS"
echo "Prior / rollback SHA: $OLD_HEAD"
echo "Deployed exact SHA:   $TARGET_SHA"
echo "Trace journal marker: SETUP_PERF"
echo "Deployment report:    $REPORT"
