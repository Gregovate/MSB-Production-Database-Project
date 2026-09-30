#!/usr/bin/env bash
set -euo pipefail

PROD_CONTAINER="msb-postgres"
PROD_DB="msb"
DB_ACTOR="msbadmin"
REPO_ROOT="/opt/fieldwiring"
SETUP_ROOT="/opt/msb-setup"
PYTHON="/opt/fieldwiring/.venv/bin/python"
SETUP_SERVICE="msb-setup.service"

TARGET_REF="agent/setup-205-work-order-gate-ux"
TARGET_SHA="9a614c1fa2eea0b425b03bdb4ac3e1790634c760"
EXPECTED_VERSION="V0.3.21-scheduling-gates"

REPORT_DIR="/home/msbadmin/setup-deployment-reports"
STAMP="$(date +%Y%m%dT%H%M%S)"
REPORT="$REPORT_DIR/Setup_205_Work_Order_Gate_UX_Source_Only_Production_Deploy_$STAMP.txt"
CANDIDATE_WORKTREE="/tmp/msb-setup-205-work-order-gate-ux-candidate-$STAMP"
DETACHED_PYCACHE="/tmp/msb-setup-205-work-order-gate-ux-detached-$STAMP"
LIVE_PYCACHE="/tmp/msb-setup-205-work-order-gate-ux-live-$STAMP"
NEGATIVE_BODY="/tmp/msb-setup-205-work-order-gate-ux-negative-$STAMP.json"
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

OLD_HEAD=""
PROD_BEFORE=""
SESSION_2026_BEFORE=""
APP_ADVANCED=0
SUCCESS=0

mkdir -p "$REPORT_DIR"
exec > >(tee "$REPORT") 2>&1

echo "========== SETUP #205 WORK ORDER GATE UX SOURCE-ONLY PRODUCTION DEPLOYMENT =========="
echo "Authority: Gregovate/MSB-Server-Management — docs/server/Setup_Source_Only_Application_Deployment_Runbook.md"
echo "Procedure: Controlled Production Mutation — source only"
echo "Database mutation: NONE"
echo "Environment/service-unit/proxy/firewall mutation: NONE"
echo "Accepted target: $TARGET_SHA"
echo "Report:            $REPORT"
echo

prod_fingerprint() {
    sudo docker exec "$PROD_CONTAINER" \
        psql -X -qAt -v ON_ERROR_STOP=1 -U "$DB_ACTOR" -d "$PROD_DB" -c "
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
                          FROM ops.setup_work_day wd), '') || '|' ||
                coalesce((SELECT string_agg(row_to_json(c)::text, '' ORDER BY c.setup_work_day_crew_id)
                          FROM ops.setup_work_day_crew c), '') || '|' ||
                coalesce((SELECT string_agg(row_to_json(wdt)::text, '' ORDER BY wdt.setup_work_day_task_id)
                          FROM ops.setup_work_day_task wdt), '') || '|' ||
                coalesce((SELECT string_agg(row_to_json(p)::text, '' ORDER BY p.setup_task_progress_id)
                          FROM ops.setup_task_progress p), '') || '|' ||
                coalesce((SELECT string_agg(row_to_json(d)::text, '' ORDER BY d.setup_session_task_id, d.prerequisite_setup_session_task_id)
                          FROM ops.setup_session_task_dependency d), '')
            );
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
    rm -f "$NEGATIVE_BODY" >/dev/null 2>&1 || true
    rm -rf "$SCRIPT_DIR" >/dev/null 2>&1 || true

    echo
    echo "--- Production after-check ---"
    if [[ -n "$PROD_BEFORE" ]]; then
        PROD_AFTER="$(prod_fingerprint 2>/dev/null || true)"
        echo "Production Setup fingerprint before: $PROD_BEFORE"
        if [[ -n "$SESSION_2026_BEFORE" ]]; then
            echo "2026 Setup Session count before: $SESSION_2026_BEFORE"
        fi
        echo "Production Setup fingerprint after:  $PROD_AFTER"
        if [[ -z "$PROD_AFTER" || "$PROD_AFTER" != "$PROD_BEFORE" ]]; then
            echo "FAIL: source-only #205 deployment changed governed Setup data"
            status=97
        else
            echo "PASS: governed Setup data unchanged by #205 source deployment"
        fi
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
echo "Verified live Setup SHA: $OLD_HEAD"
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
if [[ "$SETUP_PRE" != *"\"status\":\"ok\""* \
   || "$SETUP_PRE" != *"\"data_mode\":\"postgres\""* ]]; then
    echo "FAIL: current Setup runtime is not healthy PostgreSQL mode"
    exit 8
fi


PROD_BEFORE="$(prod_fingerprint)"
[[ -n "$PROD_BEFORE" ]] || { echo "FAIL: Production Setup fingerprint is empty"; exit 10; }
echo "Production Setup fingerprint before: $PROD_BEFORE"

SESSION_2026_BEFORE="$(sudo docker exec "$PROD_CONTAINER" psql -X -qAt -v ON_ERROR_STOP=1 -U "$DB_ACTOR" -d "$PROD_DB" -c "SELECT count(*) FROM ops.setup_session WHERE season_year=2026;")"
echo "2026 Setup Session count before: $SESSION_2026_BEFORE"
[[ "$SESSION_2026_BEFORE" == "1" ]] || { echo "FAIL: expected exactly one live 2026 Setup Session before #205 source deployment"; exit 11; }

echo
echo "--- Fetch and prove exact accepted target ancestry ---"
sudo git -C "$REPO_ROOT" fetch origin "$TARGET_REF:refs/remotes/origin/$TARGET_REF"
sudo git -C "$REPO_ROOT" cat-file -e "$TARGET_SHA^{commit}"
if ! sudo git -C "$REPO_ROOT" merge-base --is-ancestor "$TARGET_SHA" "origin/$TARGET_REF"; then
    echo "FAIL: exact browser-accepted #205 target is not contained in merged origin/main"
    exit 11
fi
if ! sudo git -C "$REPO_ROOT" merge-base --is-ancestor "$OLD_HEAD" "$TARGET_SHA"; then
    echo "FAIL: accepted #205 target is not a forward descendant of live Setup"
    exit 12
fi
echo "Forward ancestry: PASS ($OLD_HEAD -> $TARGET_SHA)"

echo
echo "--- Detached exact-target regression in Production runtime ---"
sudo git -C "$REPO_ROOT" worktree add --detach "$CANDIDATE_WORKTREE" "$TARGET_SHA"
sudo -u fieldwiring -H env PYTHONPYCACHEPREFIX="$DETACHED_PYCACHE" bash -c \
    "cd '$CANDIDATE_WORKTREE' && '$PYTHON' -m pytest -q -p no:cacheprovider Setup/Application"
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
echo "--- Restart only msb-setup.service and verify runtime ---"
restart_setup_service
SETUP_POST="$(curl -fsS http://192.168.5.9:8794/api/health)"
echo "Post-deploy Setup health: $SETUP_POST"
if [[ "$SETUP_POST" != *"\"status\":\"ok\""* \
   || "$SETUP_POST" != *"\"data_mode\":\"postgres\""* \
   || "$SETUP_POST" != *"\"version\":\"$EXPECTED_VERSION\""* ]]; then
    echo "FAIL: Setup runtime did not become healthy at $EXPECTED_VERSION"
    exit 15
fi

echo
echo "--- Verify accepted browser assets are live ---"
ROOT_HTML="$(curl -fsS http://192.168.5.9:8794/)"
for asset in \
    'setup_production.css?v=2026-09-25.2' \
    'setup_scheduling_board.css?v=2026-09-29.2' \
    'setup_next_pass.css?v=2026-09-29.1' \
    'setup_production.js?v=2026-09-29.2' \
    'setup_review_usability.js?v=2026-09-29.2' \
    'setup_next_pass.js?v=2026-09-29.5' \
    'setup_catalog_dirty_guard.js?v=2026-09-29.3' \
    'setup_scheduling_board.js?v=2026-09-29.5'; do
    if [[ "$ROOT_HTML" != *"$asset"* ]]; then
        echo "FAIL: deployed Setup HTML is missing accepted asset pin: $asset"
        exit 16
    fi
done
echo "ACCEPTED #205 ASSET PINS: PASS"

NEXT_JS="$(curl -fsS http://192.168.5.9:8794/setup_next_pass.js)"
SCHED_JS="$(curl -fsS http://192.168.5.9:8794/setup_scheduling_board.js)"
DIRTY_GUARD_JS="$(curl -fsS http://192.168.5.9:8794/setup_catalog_dirty_guard.js)"

for token in \
    'performCaptainFilterTouched' \
    'mineByIdentity' \
    '<span>Planned labor</span>' \
    '<span>Actual labor</span>' \
    '<span>Variance</span>'; do
    if [[ "$NEXT_JS" != *"$token"* ]]; then
        echo "FAIL: live Perform Work source is missing accepted #205 token: $token"
        exit 17
    fi
done

if [[ "$SCHED_JS" != *"Linked Work Order completion completes/satisfies this Setup item"* \
   || "$SCHED_JS" != *"['WORK', 'GATE'].includes(actionType)"* ]]; then
    echo "FAIL: live Scheduling Board source is missing accepted #205 Work Order semantics"
    exit 18
fi

if [[ "$DIRTY_GUARD_JS" != *"V0.3.21-scheduling-gates"* ]]; then
    echo "FAIL: live client build guard is not V0.3.21-scheduling-gates"
    exit 19
fi
echo "LIVE #205 SOURCE CONTRACT: PASS"

NEGATIVE_CODE="$(curl -sS -o "$NEGATIVE_BODY" -w '%{http_code}' \
    'http://192.168.5.9:8794/api/setup/scheduling-board?season_year=2026')"
echo "Direct unauthenticated Scheduling Board API status: $NEGATIVE_CODE"
if [[ "$NEGATIVE_CODE" != "401" ]]; then
    echo "FAIL: protected Scheduling Board API did not reject unauthenticated direct request"
    cat "$NEGATIVE_BODY" || true
    exit 20
fi
echo "PROTECTED SCHEDULING BOARD NEGATIVE PATH: PASS"

echo
echo "--- Live Setup regression ---"
sudo -u fieldwiring -H env PYTHONPYCACHEPREFIX="$LIVE_PYCACHE" bash -c \
    "cd '$SETUP_ROOT' && '$PYTHON' -m pytest -q -p no:cacheprovider Setup/Application"
echo "LIVE SETUP REGRESSION: PASS"

POST_SOURCE_FINGERPRINT="$(prod_fingerprint)"
echo "Fingerprint before source deployment: $PROD_BEFORE"
echo "Fingerprint after source deployment:  $POST_SOURCE_FINGERPRINT"
if [[ "$POST_SOURCE_FINGERPRINT" != "$PROD_BEFORE" ]]; then
    echo "FAIL: source-only #205 deployment changed governed Setup data"
    exit 21
fi

SESSION_2026_AFTER="$(sudo docker exec "$PROD_CONTAINER" psql -X -qAt -v ON_ERROR_STOP=1 -U "$DB_ACTOR" -d "$PROD_DB" -c "SELECT count(*) FROM ops.setup_session WHERE season_year=2026;")"
echo "2026 Setup Session count after:  $SESSION_2026_AFTER"
[[ "$SESSION_2026_AFTER" == "$SESSION_2026_BEFORE" ]] || { echo "FAIL: 2026 Setup Session count changed during source-only deployment"; exit 22; }

SUCCESS=1
echo
echo "SETUP_205_WORK_ORDER_GATE_UX_SOURCE_ONLY_PRODUCTION_DEPLOYMENT_PASS"
echo "Prior / rollback SHA:  $OLD_HEAD"
echo "Deployed exact SHA:    $TARGET_SHA"
echo "Deployment report:     $REPORT"
