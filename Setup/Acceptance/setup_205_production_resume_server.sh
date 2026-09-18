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
EXPECTED_LIVE_SHA="052d31dd4e68e13f2997f723778b88eddf9c53cf"
TARGET_SHA="8161e91384cb13587fa0c92da2f80f6cf770592d"
EXPECTED_PRE_VERSION="V0.3.13-assignment-layer"
EXPECTED_POST_VERSION="V0.3.14-scheduling-board"
REPORT_DIR="/home/msbadmin/setup-deployment-reports"
STAMP="$(date +%Y%m%dT%H%M%S)"
REPORT="$REPORT_DIR/Setup_205_Production_Resume_$STAMP.txt"
CANDIDATE_WORKTREE="/tmp/msb-setup-205-production-resume-candidate-$STAMP"
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
OLD_HEAD=""
PROD_BEFORE=""
APP_ADVANCED=0
SUCCESS=0

mkdir -p "$REPORT_DIR"
exec > >(tee "$REPORT") 2>&1

echo "========== SETUP #205 PRODUCTION RESUME =========="
echo "Authority: Gregovate/MSB-Server-Management — docs/server/Setup_Source_Only_Application_Deployment_Runbook.md"
echo "Procedure: Controlled Production Mutation — source only"
echo "This step: advance /opt/msb-setup from the verified V0.3.13 SHA to exact accepted V0.3.14 SHA"
echo "Database mutation in this resume: NONE"
echo "Report:          $REPORT"
echo "Expected live:   $EXPECTED_LIVE_SHA"
echo "Accepted target: $TARGET_SHA"
echo

prod_fingerprint() {
    sudo docker exec "$PROD_CONTAINER" \
        psql -X -qAt -v ON_ERROR_STOP=1 -U "$DB_ACTOR" -d "$PROD_DB" -c "
            SELECT md5(
                coalesce((SELECT string_agg(row_to_json(t)::text, '' ORDER BY t.setup_task_id) FROM ref.setup_task t), '') || '|' ||
                coalesce((SELECT string_agg(row_to_json(r)::text, '' ORDER BY r.setup_resource_id) FROM ref.setup_resource r), '') || '|' ||
                coalesce((SELECT string_agg(row_to_json(tr)::text, '' ORDER BY tr.setup_task_id, tr.setup_resource_id) FROM ref.setup_task_resource tr), '') || '|' ||
                coalesce((SELECT string_agg(row_to_json(s)::text, '' ORDER BY s.setup_session_id) FROM ops.setup_session s), '') || '|' ||
                coalesce((SELECT string_agg(row_to_json(st)::text, '' ORDER BY st.setup_session_task_id) FROM ops.setup_session_task st), '') || '|' ||
                coalesce((SELECT string_agg(row_to_json(wd)::text, '' ORDER BY wd.setup_work_day_id) FROM ops.setup_work_day wd), '')
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
    trap - EXIT INT TERM
    set +e

    if [[ "$status" -ne 0 && "$SUCCESS" -ne 1 && "$APP_ADVANCED" -eq 1 && -n "$OLD_HEAD" ]]; then
        echo
        echo "--- SOURCE-ONLY FAIL-CLOSED ROLLBACK ---"
        echo "Returning /opt/msb-setup to $OLD_HEAD"
        sudo git -C "$SETUP_ROOT" checkout --detach "$OLD_HEAD" || true
        restart_setup_service || true
        echo "Source rollback attempted; PostgreSQL was not mutated by this recovery run."
    fi

    if sudo git -C "$REPO_ROOT" worktree list --porcelain 2>/dev/null | grep -Fq "worktree $CANDIDATE_WORKTREE"; then
        sudo git -C "$REPO_ROOT" worktree remove --force "$CANDIDATE_WORKTREE" >/dev/null 2>&1 || true
    fi
    sudo git -C "$REPO_ROOT" worktree prune >/dev/null 2>&1 || true
    rm -rf "$SCRIPT_DIR" >/dev/null 2>&1 || true

    echo
    echo "--- Production after-check ---"
    if [[ -n "$PROD_BEFORE" ]]; then
        PROD_AFTER="$(prod_fingerprint 2>/dev/null)"
        echo "Production Setup fingerprint before source deployment: $PROD_BEFORE"
        echo "Production Setup fingerprint after source deployment:  $PROD_AFTER"
        if [[ -z "$PROD_AFTER" || "$PROD_AFTER" != "$PROD_BEFORE" ]]; then
            echo "FAIL: source-only recovery changed governed Setup data"
            status=97
        else
            echo "PASS: source-only recovery left governed Setup data unchanged"
        fi
    fi

    FINAL_HEAD="$(sudo git -C "$SETUP_ROOT" rev-parse HEAD 2>/dev/null || true)"
    FINAL_HEALTH="$(curl -fsS http://192.168.5.9:8794/api/health 2>/dev/null || true)"
    echo "Final Setup SHA:    $FINAL_HEAD"
    echo "Final Setup health: $FINAL_HEALTH"
    echo "Recovery report retained at: $REPORT"
    echo "Exit status: $status"
    exit "$status"
}
trap cleanup EXIT INT TERM

sudo -v

if ! sudo docker inspect "$PROD_CONTAINER" >/dev/null 2>&1; then
    echo "FAIL: Production PostgreSQL container $PROD_CONTAINER not found"
    exit 2
fi
if ! sudo git -C "$REPO_ROOT" worktree list --porcelain | grep -Fq "worktree $SETUP_ROOT"; then
    echo "FAIL: $SETUP_ROOT is not registered as a worktree of $REPO_ROOT"
    exit 3
fi

OLD_HEAD="$(sudo git -C "$SETUP_ROOT" rev-parse HEAD)"
if [[ "$OLD_HEAD" != "$EXPECTED_LIVE_SHA" ]]; then
    echo "FAIL: live Setup SHA changed since the incident was bounded"
    echo "Expected: $EXPECTED_LIVE_SHA"
    echo "Actual:   $OLD_HEAD"
    exit 4
fi
if [[ -n "$(sudo git -C "$SETUP_ROOT" status --porcelain)" ]]; then
    echo "FAIL: live Setup worktree is not clean"
    sudo git -C "$SETUP_ROOT" status -sb
    exit 5
fi

if ! systemctl is-active --quiet "$SETUP_SERVICE"; then
    echo "FAIL: msb-setup.service is not active before source-only recovery"
    exit 6
fi

SETUP_PRE="$(curl -fsS http://192.168.5.9:8794/api/health)"
echo "Pre-resume Setup health: $SETUP_PRE"
if [[ "$SETUP_PRE" != *"\"status\":\"ok\""* \
   || "$SETUP_PRE" != *"\"data_mode\":\"postgres\""* \
   || "$SETUP_PRE" != *"\"version\":\"$EXPECTED_PRE_VERSION\""* ]]; then
    echo "FAIL: current Setup runtime is not the bounded V0.3.13 incident state"
    exit 7
fi

PROD_BEFORE="$(prod_fingerprint)"
[[ -n "$PROD_BEFORE" ]] || { echo "FAIL: Production Setup fingerprint is empty"; exit 8; }
echo "Post-050 / pre-source Production fingerprint: $PROD_BEFORE"

echo
echo "--- Fetch and prove exact accepted target ancestry ---"
sudo git -C "$REPO_ROOT" fetch origin "$TARGET_REF"
sudo git -C "$REPO_ROOT" cat-file -e "$TARGET_SHA^{commit}"
if ! sudo git -C "$REPO_ROOT" merge-base --is-ancestor "$OLD_HEAD" "$TARGET_SHA"; then
    echo "FAIL: accepted #205 target is not a forward descendant of current live Setup SHA"
    exit 9
fi
echo "Forward ancestry: PASS ($OLD_HEAD -> $TARGET_SHA)"

echo
echo "--- Detached exact-target regression in Production runtime ---"
sudo git -C "$REPO_ROOT" worktree add --detach "$CANDIDATE_WORKTREE" "$TARGET_SHA"
sudo -u fieldwiring -H bash -c \
    "cd '$CANDIDATE_WORKTREE' && '$PYTHON' -m pytest -q -p no:cacheprovider Setup/Application"
echo "DETACHED EXACT-TARGET SETUP REGRESSION: PASS"

echo
echo "Authority: Gregovate/MSB-Server-Management — docs/server/Setup_Source_Only_Application_Deployment_Runbook.md"
echo "Procedure: Controlled Production Mutation"
echo "This step: advance /opt/msb-setup from $OLD_HEAD to exact approved $TARGET_SHA"
echo
sudo git -C "$SETUP_ROOT" checkout --detach "$TARGET_SHA"
APP_ADVANCED=1

DEPLOYED_HEAD="$(sudo git -C "$SETUP_ROOT" rev-parse HEAD)"
if [[ "$DEPLOYED_HEAD" != "$TARGET_SHA" ]]; then
    echo "FAIL: deployed Setup SHA is $DEPLOYED_HEAD, expected $TARGET_SHA"
    exit 10
fi
if [[ -n "$(sudo git -C "$SETUP_ROOT" status --porcelain)" ]]; then
    echo "FAIL: deployed Setup worktree is not clean"
    exit 11
fi
echo "Exact Setup target deployed: $DEPLOYED_HEAD"

echo
echo "--- Restart only msb-setup.service and verify V0.3.14 ---"
restart_setup_service
SETUP_POST="$(curl -fsS http://192.168.5.9:8794/api/health)"
echo "Post-resume Setup health: $SETUP_POST"
if [[ "$SETUP_POST" != *"\"status\":\"ok\""* \
   || "$SETUP_POST" != *"\"data_mode\":\"postgres\""* \
   || "$SETUP_POST" != *"\"version\":\"$EXPECTED_POST_VERSION\""* ]]; then
    echo "FAIL: Setup runtime did not become $EXPECTED_POST_VERSION"
    exit 12
fi

echo
echo "--- Live Setup regression ---"
sudo -u fieldwiring -H bash -c \
    "cd '$SETUP_ROOT' && '$PYTHON' -m pytest -q -p no:cacheprovider Setup/Application"
echo "LIVE SETUP REGRESSION: PASS"

POST_SOURCE_FINGERPRINT="$(prod_fingerprint)"
echo "Fingerprint before source deployment: $PROD_BEFORE"
echo "Fingerprint after source deployment:  $POST_SOURCE_FINGERPRINT"
if [[ "$POST_SOURCE_FINGERPRINT" != "$PROD_BEFORE" ]]; then
    echo "FAIL: source-only application promotion changed governed Setup data"
    exit 13
fi
echo "PASS: Production Setup fingerprint unchanged by source-only recovery"

SUCCESS=1
echo
echo "SETUP_205_PRODUCTION_RESUME_PASS"
echo "Prior / rollback SHA: $OLD_HEAD"
echo "Deployed exact SHA:   $TARGET_SHA"
echo "Recovery report:      $REPORT"
