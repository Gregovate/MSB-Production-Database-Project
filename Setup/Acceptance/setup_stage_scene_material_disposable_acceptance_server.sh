#!/usr/bin/env bash
set -euo pipefail

PROD_CONTAINER="msb-postgres"
PROD_DB="msb"
DB_ACTOR="msbadmin"
IMAGE="postgis/postgis:16-3.5"
NETWORK="msb-stack_default"
REPO_ROOT="/opt/fieldwiring"
SETUP_LIVE_ROOT="/opt/msb-setup"

TARGET_REF="${1:?target ref is required}"
TARGET_SHA="${2:?target SHA is required}"
BUNDLE_DIR="${3:?bundle directory is required}"
STAMP="$(date +%Y%m%dT%H%M%S)"
TEST_CONTAINER="msb-setup-stage-scene-material-${$}"
TEST_DB="msb_setup_stage_scene_material_acceptance"
TEST_PASSWORD="setup-stage-scene-${$}-$(date +%s)"
DUMP_FILE="/tmp/msb-setup-stage-scene-material-production-${STAMP}-${$}.dump"
CANDIDATE_WORKTREE="/tmp/msb-setup-stage-scene-material-candidate-${STAMP}"
REPORT_DIR="$HOME/setup-acceptance-reports"
REPORT="$REPORT_DIR/Setup_Stage_Scene_Material_Disposable_${STAMP}.txt"
PROD_BEFORE=""
SETUP_HEAD_BEFORE=""

mkdir -p "$REPORT_DIR"
exec > >(tee "$REPORT") 2>&1

echo "========== SETUP STAGE/SCENE MATERIAL DISPOSABLE ACCEPTANCE =========="
echo "Authority: Gregovate/MSB-Server-Management — docs/server/PostgreSQL_Disposable_Acceptance_Standard.md"
echo "Candidate SHA: $TARGET_SHA"
echo "Target ref:    $TARGET_REF"
echo "Production DB: pg_dump + SELECT only"
echo "Test writes:   disposable PostgreSQL clone only"
echo "Report:        $REPORT"
echo

prod_fingerprint() {
    sudo docker exec "$PROD_CONTAINER" \
        psql -X -qAt -v ON_ERROR_STOP=1 -U "$DB_ACTOR" -d "$PROD_DB" -c "
            SELECT md5(
                coalesce((SELECT string_agg(row_to_json(t)::text, '' ORDER BY t.setup_task_id) FROM ref.setup_task t), '') || '|' ||
                coalesce((SELECT string_agg(row_to_json(d)::text, '' ORDER BY d.setup_task_id, d.prerequisite_setup_task_id) FROM ref.setup_task_dependency d), '') || '|' ||
                coalesce((SELECT string_agg(row_to_json(td)::text, '' ORDER BY td.setup_task_id, td.display_id) FROM ref.setup_task_display td), '') || '|' ||
                coalesce((SELECT string_agg(row_to_json(tc)::text, '' ORDER BY tc.setup_task_id, tc.container_id) FROM ref.setup_task_container_support tc), '') || '|' ||
                coalesce((SELECT string_agg(row_to_json(st)::text, '' ORDER BY st.setup_session_task_id) FROM ops.setup_session_task st), '')
            );
        "
}

cleanup() {
    status=$?
    trap - EXIT INT TERM
    set +e

    echo
    echo "--- Disposable cleanup ---"
    sudo docker rm -f "$TEST_CONTAINER" >/dev/null 2>&1 || true
    if sudo git -C "$REPO_ROOT" worktree list --porcelain 2>/dev/null | grep -Fq "worktree $CANDIDATE_WORKTREE"; then
        sudo git -C "$REPO_ROOT" worktree remove --force "$CANDIDATE_WORKTREE" >/dev/null 2>&1 || true
    fi
    rm -f "$DUMP_FILE" >/dev/null 2>&1 || true
    rm -rf "$BUNDLE_DIR" >/dev/null 2>&1 || true

    echo "--- Production after-check ---"
    if [[ -n "$PROD_BEFORE" ]]; then
        PROD_AFTER="$(prod_fingerprint 2>/dev/null)"
        echo "Production Setup fingerprint before: $PROD_BEFORE"
        echo "Production Setup fingerprint after:  $PROD_AFTER"
        if [[ -z "$PROD_AFTER" || "$PROD_AFTER" != "$PROD_BEFORE" ]]; then
            echo "FAIL: Production Setup fingerprint changed"
            status=97
        else
            echo "PASS: Production Setup fingerprint unchanged"
        fi
    else
        echo "SKIP: Production fingerprint was not captured before failure"
    fi

    if [[ -n "$SETUP_HEAD_BEFORE" ]]; then
        SETUP_HEAD_AFTER="$(sudo git -C "$SETUP_LIVE_ROOT" rev-parse HEAD 2>/dev/null)"
        echo "Live Setup SHA before: $SETUP_HEAD_BEFORE"
        echo "Live Setup SHA after:  $SETUP_HEAD_AFTER"
        if [[ -z "$SETUP_HEAD_AFTER" || "$SETUP_HEAD_AFTER" != "$SETUP_HEAD_BEFORE" ]]; then
            echo "FAIL: live /opt/msb-setup checkout changed"
            status=98
        else
            echo "PASS: live Setup checkout unchanged"
        fi
    else
        echo "SKIP: live Setup SHA was not captured before failure"
    fi

    echo "Report retained at: $REPORT"
    echo "Exit status: $status"
    exit "$status"
}
trap cleanup EXIT INT TERM

sudo -v

if ! sudo docker inspect "$PROD_CONTAINER" >/dev/null 2>&1; then
    echo "FAIL: Production PostgreSQL container was not found"
    exit 2
fi
if [[ "$(sudo docker inspect "$PROD_CONTAINER" --format '{{.Config.Image}}')" != "$IMAGE" ]]; then
    echo "FAIL: Production PostgreSQL image is not $IMAGE"
    exit 3
fi
if ! sudo docker network inspect "$NETWORK" >/dev/null 2>&1; then
    echo "FAIL: Docker network $NETWORK was not found"
    exit 4
fi
if ! systemctl is-active --quiet msb-setup.service; then
    echo "FAIL: Production Setup service is not active"
    exit 5
fi
if ! sudo -u fieldwiring -H test -x /opt/fieldwiring/.venv/bin/python; then
    echo "FAIL: documented shared Python runtime is unavailable to fieldwiring"
    exit 6
fi

SETUP_HEAD_BEFORE="$(sudo git -C "$SETUP_LIVE_ROOT" rev-parse HEAD)"
if [[ -n "$(sudo git -C "$SETUP_LIVE_ROOT" status --porcelain)" ]]; then
    echo "FAIL: live Setup checkout has uncommitted changes"
    exit 7
fi
if [[ -n "$(sudo git -C "$REPO_ROOT" status --porcelain)" ]]; then
    echo "FAIL: shared repository checkout has uncommitted changes"
    exit 8
fi

echo "Live Setup SHA: $SETUP_HEAD_BEFORE"
PROD_BEFORE="$(prod_fingerprint)"
if [[ -z "$PROD_BEFORE" ]]; then
    echo "FAIL: Production Setup fingerprint was empty"
    exit 9
fi
echo "Production Setup fingerprint before: $PROD_BEFORE"

echo
echo "--- Fetch exact candidate and prove live-Setup ancestry ---"
sudo git -C "$REPO_ROOT" fetch origin "$TARGET_REF"
sudo git -C "$REPO_ROOT" cat-file -e "$TARGET_SHA^{commit}"
if ! sudo git -C "$REPO_ROOT" merge-base --is-ancestor "$SETUP_HEAD_BEFORE" "$TARGET_SHA"; then
    echo "FAIL: candidate is not a forward descendant of live Setup"
    exit 10
fi
sudo git -C "$REPO_ROOT" worktree add --detach "$CANDIDATE_WORKTREE" "$TARGET_SHA"

M025="$CANDIDATE_WORKTREE/Setup/Database/025_add_setup_display_material_requirement.sql"
VALIDATION="$CANDIDATE_WORKTREE/Setup/Acceptance/setup_stage_scene_material_disposable_validation.sql"
for file in "$M025" "$VALIDATION"; do
    if [[ ! -s "$file" ]]; then
        echo "FAIL: exact candidate is missing required acceptance file: $file"
        exit 11
    fi
done

if find "$CANDIDATE_WORKTREE/Setup" -type f -maxdepth 4 -print0 | xargs -0 grep -l "Choose current LOR material source" 2>/dev/null | grep -q .; then
    echo "FAIL: rejected manual LOR material-source selector is present in candidate"
    exit 12
fi

echo
echo "--- Exact candidate Python/tests in documented runtime ---"
PYCACHE="/tmp/msb-setup-stage-scene-material-pycache-$STAMP"
sudo -u fieldwiring -H env PYTHONPYCACHEPREFIX="$PYCACHE" bash -c "
    cd '$CANDIDATE_WORKTREE'
    /opt/fieldwiring/.venv/bin/python -m py_compile \
        Setup/Application/setup_material_api.py \
        Setup/Application/setup_material_resolution.py \
        Setup/Application/production_backend.py
    /opt/fieldwiring/.venv/bin/python -m pytest -q -p no:cacheprovider Setup/Application
"
rm -rf "$PYCACHE" >/dev/null 2>&1 || true
echo "PASS: exact candidate Setup/Application regression"

echo
echo "--- Capture current Production into disposable clone ---"
sudo docker exec "$PROD_CONTAINER" \
    pg_dump -U "$DB_ACTOR" -d "$PROD_DB" -Fc > "$DUMP_FILE"
test -s "$DUMP_FILE"
sudo docker exec -i "$PROD_CONTAINER" pg_restore --list < "$DUMP_FILE" >/dev/null
echo "Production dump captured: $(du -h "$DUMP_FILE" | awk '{print $1}')"

sudo docker run -d \
    --name "$TEST_CONTAINER" \
    --network "$NETWORK" \
    -e POSTGRES_USER="$DB_ACTOR" \
    -e POSTGRES_PASSWORD="$TEST_PASSWORD" \
    -e POSTGRES_DB=postgres \
    "$IMAGE" >/dev/null

ready=0
pid1=""
for _ in $(seq 1 120); do
    if [[ "$(sudo docker inspect "$TEST_CONTAINER" --format '{{.State.Running}}' 2>/dev/null || true)" != "true" ]]; then
        break
    fi
    pid1="$(sudo docker exec "$TEST_CONTAINER" sh -c 'cat /proc/1/comm' 2>/dev/null | tr -d '\r\n' || true)"
    if [[ "$pid1" == "postgres" ]] && \
       sudo docker exec -e PGPASSWORD="$TEST_PASSWORD" "$TEST_CONTAINER" \
           pg_isready -U "$DB_ACTOR" -d postgres >/dev/null 2>&1; then
        ready=1
        break
    fi
    sleep 1
done
if [[ "$ready" -ne 1 ]]; then
    echo "FAIL: disposable PostgreSQL did not reach final post-init ready state"
    echo "Observed PID 1 command: ${pid1:-unknown}"
    sudo docker logs "$TEST_CONTAINER" || true
    exit 13
fi

sudo docker exec -e PGPASSWORD="$TEST_PASSWORD" "$TEST_CONTAINER" \
    createdb -U "$DB_ACTOR" -T template0 "$TEST_DB"
sudo docker exec -i -e PGPASSWORD="$TEST_PASSWORD" "$TEST_CONTAINER" \
    pg_restore -U "$DB_ACTOR" -d "$TEST_DB" --no-owner --no-acl --exit-on-error \
    < "$DUMP_FILE"
echo "Disposable current-Production clone restored"

psql_test() {
    sudo docker exec -i -e PGPASSWORD="$TEST_PASSWORD" "$TEST_CONTAINER" \
        psql -X -v ON_ERROR_STOP=1 -U "$DB_ACTOR" -d "$TEST_DB" "$@"
}

legacy_fingerprint() {
    psql_test -qAt -c "
        SELECT md5(
            coalesce((SELECT string_agg((to_jsonb(t) - 'requires_display_material')::text, '' ORDER BY t.setup_task_id) FROM ref.setup_task t), '') || '|' ||
            coalesce((SELECT string_agg(row_to_json(d)::text, '' ORDER BY d.setup_task_id, d.prerequisite_setup_task_id) FROM ref.setup_task_dependency d), '') || '|' ||
            coalesce((SELECT string_agg(row_to_json(td)::text, '' ORDER BY td.setup_task_id, td.display_id) FROM ref.setup_task_display td), '') || '|' ||
            coalesce((SELECT string_agg(row_to_json(st)::text, '' ORDER BY st.setup_session_task_id) FROM ops.setup_session_task st), '')
        );
    "
}

LEGACY_BEFORE="$(legacy_fingerprint)"
if [[ -z "$LEGACY_BEFORE" ]]; then
    echo "FAIL: disposable pre-migration fingerprint was empty"
    exit 14
fi

# pg_dump does not include cluster-global roles. Recreate only the existing
# application role needed by migration grants; no broad DML grants are added.
psql_test -c "DO \$role\$ BEGIN IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'fieldwiring_app') THEN CREATE ROLE fieldwiring_app LOGIN; END IF; END \$role\$;"

echo
echo "--- Apply migration 025 to disposable clone only ---"
psql_test < "$M025"
echo "PASS: migration 025 applied"

LEGACY_AFTER="$(legacy_fingerprint)"
echo "Disposable legacy Setup fingerprint before: $LEGACY_BEFORE"
echo "Disposable legacy Setup fingerprint after:  $LEGACY_AFTER"
if [[ -z "$LEGACY_AFTER" || "$LEGACY_AFTER" != "$LEGACY_BEFORE" ]]; then
    echo "FAIL: migration 025 changed pre-existing Setup business data"
    exit 15
fi
echo "PASS: migration 025 preserved pre-existing Setup business data"

echo
echo "--- Reapply migration 025 to prove replay safety ---"
psql_test < "$M025"
LEGACY_REPLAY="$(legacy_fingerprint)"
if [[ -z "$LEGACY_REPLAY" || "$LEGACY_REPLAY" != "$LEGACY_AFTER" ]]; then
    echo "FAIL: migration 025 replay changed pre-existing Setup business data"
    exit 16
fi
echo "PASS: migration 025 replay-safe for pre-existing Setup business data"

echo
echo "--- Five-Stage material partition validation ---"
psql_test < "$VALIDATION"

echo
echo "DISPOSABLE_SETUP_STAGE_SCENE_MATERIAL_ACCEPTANCE_PASS"
