#!/usr/bin/env bash
set -euo pipefail

PROD_CONTAINER="msb-postgres"
PROD_DB="msb"
DB_ACTOR="msbadmin"
IMAGE="postgis/postgis:16-3.5"
NETWORK="msb-stack_default"
REPO_ROOT="/opt/fieldwiring"
SETUP_LIVE_ROOT="/opt/msb-setup"

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
PREVIEW_PORT="${1:?preview port is required}"
PREVIEW_EMAIL="${2:?preview operator email is required}"
TARGET_REF="${3:?target ref is required}"
TARGET_SHA="${4:?target SHA is required}"
STAMP="$(date +%Y%m%dT%H%M%S)"
TEST_CONTAINER="msb-setup-material-preview-${$}"
TEST_DB="msb_setup_material_browser_preview"
TEST_PASSWORD="setup-material-preview-${$}-$(date +%s)"
APP_PASSWORD="setupmaterialpreview${$}$(date +%s)"
DUMP_FILE="/tmp/msb-setup-material-preview-production-${STAMP}-${$}.dump"
GRANTS_FILE="/tmp/msb-setup-material-preview-grants-${STAMP}-${$}.sql"
CANDIDATE_WORKTREE="/tmp/msb-setup-material-preview-candidate-$STAMP"
REPORT_DIR="$HOME/setup-acceptance-reports"
REPORT="$REPORT_DIR/Setup_Display_Material_Browser_Preview_${STAMP}.txt"
PREVIEW_LOG="/tmp/Setup_Display_Material_Browser_Preview_Flask_${STAMP}.log"
PREVIEW_PGID=""
PROD_BEFORE=""
SETUP_HEAD_BEFORE=""
REPO_HEAD_BEFORE=""
PREVIEW_OWNED_PORT=0
TEMP_FILES=()

mkdir -p "$REPORT_DIR"
exec > >(tee "$REPORT") 2>&1

echo "========== SETUP DISPLAY MATERIAL BROWSER PREVIEW =========="
echo "Authority: Gregovate/MSB-Server-Management — docs/server/Pre_Production_Browser_Review_Runbook.md"
echo "Disposable standard: docs/server/PostgreSQL_Disposable_Acceptance_Standard.md"
echo "Candidate SHA: $TARGET_SHA"
echo "Target ref:    $TARGET_REF"
echo "Preview port: $PREVIEW_PORT"
echo "Preview user: $PREVIEW_EMAIL"
echo "Report:       $REPORT"
echo "Production DB: pg_dump + SELECT only"
echo "Preview writes: disposable current-Production clone only"
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

cleanup() {
    status=$?
    trap - EXIT INT TERM
    set +e

    echo
    echo "--- Setup Display material browser preview cleanup ---"
    if [[ -n "$PREVIEW_PGID" ]]; then
        kill -- -"$PREVIEW_PGID" >/dev/null 2>&1 || true
        sleep 1
        kill -KILL -- -"$PREVIEW_PGID" >/dev/null 2>&1 || true
    fi

    sudo docker rm -f "$TEST_CONTAINER" >/dev/null 2>&1 || true

    if sudo git -C "$REPO_ROOT" worktree list --porcelain 2>/dev/null | grep -Fq "worktree $CANDIDATE_WORKTREE"; then
        sudo git -C "$REPO_ROOT" worktree remove --force "$CANDIDATE_WORKTREE" >/dev/null 2>&1 || true
    fi

    rm -f "$DUMP_FILE" "$GRANTS_FILE" >/dev/null 2>&1 || true
    if [[ "${#TEMP_FILES[@]}" -gt 0 ]]; then
        rm -f "${TEMP_FILES[@]}" >/dev/null 2>&1 || true
    fi
    rm -rf "$SCRIPT_DIR" >/dev/null 2>&1 || true

    echo "--- Production Setup fingerprint after-check ---"
    if [[ -n "$PROD_BEFORE" ]]; then
        PROD_AFTER="$(prod_fingerprint 2>/dev/null)"
        echo "Before: $PROD_BEFORE"
        echo "After:  $PROD_AFTER"
        if [[ -z "$PROD_AFTER" || "$PROD_AFTER" != "$PROD_BEFORE" ]]; then
            echo "FAIL: Production Setup fingerprint changed during browser preview"
            status=97
        else
            echo "PASS: Production Setup fingerprint unchanged"
        fi
    else
        echo "SKIP: Production Setup fingerprint was not captured before failure"
    fi

    if [[ -n "$SETUP_HEAD_BEFORE" ]]; then
        SETUP_HEAD_AFTER="$(sudo git -C "$SETUP_LIVE_ROOT" rev-parse HEAD 2>/dev/null)"
        echo "Live Setup checkout before: $SETUP_HEAD_BEFORE"
        echo "Live Setup checkout after:  $SETUP_HEAD_AFTER"
        if [[ -z "$SETUP_HEAD_AFTER" || "$SETUP_HEAD_AFTER" != "$SETUP_HEAD_BEFORE" ]]; then
            echo "FAIL: /opt/msb-setup changed during browser preview"
            status=98
        else
            echo "PASS: live Setup checkout unchanged"
        fi
    else
        echo "SKIP: live Setup SHA was not captured before failure"
    fi

    if [[ "$PREVIEW_OWNED_PORT" -eq 1 ]] && ss -ltnH "sport = :$PREVIEW_PORT" | grep -q .; then
        echo "FAIL: preview-owned TCP port $PREVIEW_PORT is still listening after cleanup"
        status=99
    fi

    echo "Preview Flask log retained at: $PREVIEW_LOG"
    echo "Preview report retained at:    $REPORT"
    echo "Exit status: $status"
    exit "$status"
}
trap cleanup EXIT INT TERM

sudo -v

if [[ ! "$PREVIEW_PORT" =~ ^[0-9]+$ ]] || (( PREVIEW_PORT < 1024 || PREVIEW_PORT > 65535 )); then
    echo "FAIL: preview port must be an integer from 1024 through 65535"
    exit 2
fi
if [[ "$PREVIEW_PORT" == "8055" || "$PREVIEW_PORT" == "8790" || "$PREVIEW_PORT" == "8792" || "$PREVIEW_PORT" == "8794" ]]; then
    echo "FAIL: preview port conflicts with a governed Production listener"
    exit 3
fi
if [[ ! "$PREVIEW_EMAIL" =~ ^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+$ ]]; then
    echo "FAIL: preview operator email is not valid"
    exit 4
fi
if ss -ltnH "sport = :$PREVIEW_PORT" | grep -q .; then
    echo "FAIL: preview port $PREVIEW_PORT is already listening on msb-prod-db"
    exit 5
fi
if ! sudo docker inspect "$PROD_CONTAINER" >/dev/null 2>&1; then
    echo "FAIL: Production PostgreSQL container was not found"
    exit 6
fi
if [[ "$(sudo docker inspect "$PROD_CONTAINER" --format '{{.Config.Image}}')" != "$IMAGE" ]]; then
    echo "FAIL: Production PostgreSQL image is not $IMAGE"
    exit 7
fi
if ! sudo docker network inspect "$NETWORK" >/dev/null 2>&1; then
    echo "FAIL: Docker network $NETWORK was not found"
    exit 8
fi
if ! systemctl is-active --quiet fieldwiring.service \
   || ! systemctl is-active --quiet msb-procedures.service \
   || ! systemctl is-active --quiet msb-setup.service; then
    echo "FAIL: one or more Production application services are not healthy before preview"
    exit 9
fi
if ! systemctl is-active --quiet msb-display-folders.service; then
    echo "FAIL: shared read-only Display Folders service is not active"
    exit 10
fi
if ! sudo -u fieldwiring -H bash -c 'cd /tmp && test -r /mnt/msb-display-folders && test -x /mnt/msb-display-folders'; then
    echo "FAIL: fieldwiring runtime account cannot read/traverse Display Folders"
    exit 11
fi
if ! sudo -u fieldwiring -H test -x /opt/fieldwiring/.venv/bin/python; then
    echo "FAIL: documented Production Python runtime is not executable as fieldwiring"
    exit 12
fi

SETUP_HEAD_BEFORE="$(sudo git -C "$SETUP_LIVE_ROOT" rev-parse HEAD)"
REPO_HEAD_BEFORE="$(sudo git -C "$REPO_ROOT" rev-parse HEAD)"
if [[ -n "$(sudo git -C "$SETUP_LIVE_ROOT" status --porcelain)" ]]; then
    echo "FAIL: live Setup detached worktree has uncommitted changes"
    sudo git -C "$SETUP_LIVE_ROOT" status -sb
    exit 13
fi
if [[ -n "$(sudo git -C "$REPO_ROOT" status --porcelain)" ]]; then
    echo "FAIL: shared repository checkout has uncommitted changes"
    sudo git -C "$REPO_ROOT" status -sb
    exit 14
fi

echo "Live Setup SHA:   $SETUP_HEAD_BEFORE"
echo "Repository HEAD:  $REPO_HEAD_BEFORE"
PROD_BEFORE="$(prod_fingerprint)"
if [[ -z "$PROD_BEFORE" ]]; then
    echo "FAIL: Production Setup fingerprint was empty"
    exit 15
fi
echo "Production Setup fingerprint before: $PROD_BEFORE"

echo
echo "--- Fetch exact candidate and prove forward ancestry from live Setup ---"
sudo git -C "$REPO_ROOT" fetch origin "$TARGET_REF"
sudo git -C "$REPO_ROOT" cat-file -e "$TARGET_SHA^{commit}"
if ! sudo git -C "$REPO_ROOT" merge-base --is-ancestor "$SETUP_HEAD_BEFORE" "$TARGET_SHA"; then
    echo "FAIL: candidate is not a forward descendant of the live /opt/msb-setup SHA"
    exit 16
fi
sudo git -C "$REPO_ROOT" worktree add --detach "$CANDIDATE_WORKTREE" "$TARGET_SHA"

M025="$CANDIDATE_WORKTREE/Setup/Database/025_add_setup_display_material_requirement.sql"
VALIDATION="$CANDIDATE_WORKTREE/Setup/Acceptance/setup_display_material_disposable_validation.sql"
PREVIEW_ENTRY="$CANDIDATE_WORKTREE/Setup/Acceptance/setup_session_browser_preview_entry.py"
for file in "$M025" "$VALIDATION" "$PREVIEW_ENTRY"; do
    if [[ ! -s "$file" ]]; then
        echo "FAIL: exact candidate is missing required acceptance file: $file"
        exit 17
    fi
done

echo
echo "--- Exact candidate regression in Production runtime ---"
sudo -u fieldwiring -H bash -c "
    cd '$CANDIDATE_WORKTREE'
    /opt/fieldwiring/.venv/bin/python -m py_compile \
        Setup/Application/setup_material_api.py \
        Setup/Application/production_backend.py
    /opt/fieldwiring/.venv/bin/python -m pytest -q -p no:cacheprovider Setup/Application
"
echo "Exact candidate full Setup/Application regression: PASS"

echo
echo "--- Capture current Production into disposable clone ---"
sudo docker exec "$PROD_CONTAINER" \
    pg_dump -U "$DB_ACTOR" -d "$PROD_DB" -Fc > "$DUMP_FILE"
test -s "$DUMP_FILE"
sha256sum "$DUMP_FILE"
sudo docker exec -i "$PROD_CONTAINER" pg_restore --list < "$DUMP_FILE" >/dev/null
echo "Production dump captured and validated: $(du -h "$DUMP_FILE" | awk '{print $1}')"

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
    exit 18
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
            coalesce((SELECT string_agg((to_jsonb(t) - 'is_display_setup_step' - 'requires_display_material')::text, '' ORDER BY t.setup_task_id) FROM ref.setup_task t), '') || '|' ||
            coalesce((SELECT string_agg(row_to_json(d)::text, '' ORDER BY d.setup_task_id, d.prerequisite_setup_task_id) FROM ref.setup_task_dependency d), '') || '|' ||
            coalesce((SELECT string_agg(row_to_json(st)::text, '' ORDER BY st.setup_session_task_id) FROM ops.setup_session_task st), '')
        );
    "
}

LEGACY_BEFORE="$(legacy_fingerprint)"
if [[ -z "$LEGACY_BEFORE" ]]; then
    echo "FAIL: disposable legacy-data fingerprint was empty"
    exit 19
fi

echo
echo "--- Recreate Production-equivalent application role boundary ---"
psql_test -c "CREATE ROLE fieldwiring_app LOGIN PASSWORD '$APP_PASSWORD';"
sudo docker exec "$PROD_CONTAINER" \
    psql -X -qAt -v ON_ERROR_STOP=1 -U "$DB_ACTOR" -d "$PROD_DB" -c "
        SELECT format('GRANT USAGE ON SCHEMA %I TO fieldwiring_app;', n.nspname)
        FROM pg_namespace n
        WHERE n.nspname IN ('ref','lor_snap','ops')
          AND has_schema_privilege('fieldwiring_app', n.oid, 'USAGE')
        UNION ALL
        SELECT format('GRANT SELECT ON TABLE %I.%I TO fieldwiring_app;', n.nspname, c.relname)
        FROM pg_class c
        JOIN pg_namespace n ON n.oid = c.relnamespace
        WHERE n.nspname IN ('ref','lor_snap','ops','public')
          AND c.relkind IN ('r','v','m','f','p')
          AND has_table_privilege('fieldwiring_app', c.oid, 'SELECT')
        UNION ALL
        SELECT format(
            'GRANT EXECUTE ON FUNCTION %I.%I(%s) TO fieldwiring_app;',
            n.nspname,
            p.proname,
            pg_get_function_identity_arguments(p.oid)
        )
        FROM pg_proc p
        JOIN pg_namespace n ON n.oid = p.pronamespace
        WHERE n.nspname IN ('ref','ops')
          AND p.prokind IN ('f','w')
          AND has_function_privilege('fieldwiring_app', p.oid, 'EXECUTE');
    " > "$GRANTS_FILE"
if [[ ! -s "$GRANTS_FILE" ]]; then
    echo "FAIL: could not derive Production fieldwiring_app privilege mirror"
    exit 20
fi
psql_test < "$GRANTS_FILE"
echo "Production-equivalent existing application privileges mirrored: PASS"

echo
echo "--- Apply migration 025 to disposable clone only ---"
psql_test < "$M025"
psql_test < "$VALIDATION"
LEGACY_AFTER_MIGRATION="$(legacy_fingerprint)"
echo "Disposable legacy fingerprint before migration: $LEGACY_BEFORE"
echo "Disposable legacy fingerprint after migration:  $LEGACY_AFTER_MIGRATION"
if [[ "$LEGACY_AFTER_MIGRATION" != "$LEGACY_BEFORE" ]]; then
    echo "FAIL: migration 025 changed pre-existing governed Setup data"
    exit 21
fi
echo "Migration 025 preserved pre-existing Setup data: PASS"

echo
echo "--- Replay migration 025 to prove idempotent schema/function installation ---"
psql_test < "$M025"
LEGACY_AFTER_REPLAY="$(legacy_fingerprint)"
if [[ "$LEGACY_AFTER_REPLAY" != "$LEGACY_BEFORE" ]]; then
    echo "FAIL: migration 025 replay changed pre-existing governed Setup data"
    exit 22
fi
echo "Migration 025 replay: PASS"

MANAGE_OK="$(psql_test -qAt -c "SELECT can_manage_setup FROM ref.setup_browser_capabilities('$PREVIEW_EMAIL');")"
if [[ "$MANAGE_OK" != "t" ]]; then
    echo "FAIL: preview operator $PREVIEW_EMAIL does not have Setup Manager capability"
    exit 23
fi

TEST_IP="$(sudo docker inspect "$TEST_CONTAINER" --format '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}')"
if [[ -z "$TEST_IP" ]]; then
    echo "FAIL: could not resolve disposable PostgreSQL container IP"
    exit 24
fi
APP_DIR="$CANDIDATE_WORKTREE/Setup/Application"
DSN="host=$TEST_IP port=5432 dbname=$TEST_DB user=fieldwiring_app password=$APP_PASSWORD"

echo
echo "--- Start exact candidate on temporary preview port ---"
PREVIEW_PGID="$(
    sudo -u fieldwiring -H env \
        SETUP_DATABASE_DSN="$DSN" \
        SETUP_DRIVE_ROOT="/mnt/msb-display-folders" \
        MSB_SETUP_PREVIEW_APP_DIR="$APP_DIR" \
        MSB_SETUP_PREVIEW_OPERATOR_EMAIL="$PREVIEW_EMAIL" \
        MSB_SETUP_PREVIEW_HOST="127.0.0.1" \
        MSB_SETUP_PREVIEW_PORT="$PREVIEW_PORT" \
        MSB_SETUP_PREVIEW_ENTRY="$PREVIEW_ENTRY" \
        MSB_SETUP_PREVIEW_LOG="$PREVIEW_LOG" \
        bash -c '
            cd /tmp
            setsid /opt/fieldwiring/.venv/bin/python "$MSB_SETUP_PREVIEW_ENTRY" \
                > "$MSB_SETUP_PREVIEW_LOG" 2>&1 &
            echo $!
        '
)"
if [[ ! "$PREVIEW_PGID" =~ ^[0-9]+$ ]]; then
    echo "FAIL: preview process did not return a valid process-group ID: $PREVIEW_PGID"
    exit 25
fi
PREVIEW_OWNED_PORT=1

preview_ready=0
for _ in $(seq 1 30); do
    if curl -fsS "http://127.0.0.1:$PREVIEW_PORT/api/health" >/dev/null 2>&1; then
        preview_ready=1
        break
    fi
    sleep 1
done
if [[ "$preview_ready" -ne 1 ]]; then
    echo "FAIL: Setup Display material preview did not become healthy"
    tail -n 120 "$PREVIEW_LOG" || true
    exit 26
fi
curl -fsS "http://127.0.0.1:$PREVIEW_PORT/api/health"
echo

METADATA_FILE="/tmp/setup-material-metadata-$STAMP.json"
TEMP_FILES+=("$METADATA_FILE")
METADATA_CODE="$(curl -sS -o "$METADATA_FILE" -w '%{http_code}' "http://127.0.0.1:$PREVIEW_PORT/api/setup/task-display-material")"
if [[ "$METADATA_CODE" != "200" ]]; then
    echo "FAIL: Display material metadata API returned HTTP $METADATA_CODE"
    cat "$METADATA_FILE" || true
    exit 27
fi
sudo -u fieldwiring -H /opt/fieldwiring/.venv/bin/python - "$METADATA_FILE" <<'PY'
import json
import sys
with open(sys.argv[1], encoding='utf-8') as handle:
    rows = json.load(handle).get('task_display_material', [])
if not rows:
    raise SystemExit('FAIL: task-display-material API returned no tasks')
if any(row.get('is_display_setup_step') or row.get('requires_display_material') for row in rows):
    raise SystemExit('FAIL: migration 025/API inferred material flags before review')
print(f'Display material metadata defaults: PASS ({len(rows)} tasks, all false)')
PY

query_task_id() {
    local sql="$1"
    psql_test -qAt -c "$sql" | head -n 1
}

TASK00="$(query_task_id "SELECT t.setup_task_id FROM ref.setup_task t JOIN ref.stage s ON s.stage_id=t.stage_id WHERE s.stage_key='00' AND t.lor_scene_id IS NULL AND t.active_flag ORDER BY CASE WHEN t.task_name='Setup HWY42 Traffic Signs' THEN 0 ELSE 1 END, t.display_order, t.setup_task_id;")"
TASK01="$(query_task_id "SELECT t.setup_task_id FROM ref.setup_task t JOIN ref.stage s ON s.stage_id=t.stage_id WHERE s.stage_key='01' AND t.lor_scene_id IS NULL AND t.active_flag ORDER BY t.display_order, t.setup_task_id;")"
TASK16="$(query_task_id "SELECT t.setup_task_id FROM ref.setup_task t JOIN ref.stage s ON s.stage_id=t.stage_id WHERE s.stage_key='16' AND t.lor_scene_id IS NULL AND t.active_flag ORDER BY CASE WHEN t.task_name='Setup Northern Lights' THEN 0 ELSE 1 END, t.display_order, t.setup_task_id;")"
TASK13SCENE="$(query_task_id "SELECT t.setup_task_id FROM ref.setup_task t JOIN ref.lor_scene ls ON ls.lor_scene_id=t.lor_scene_id WHERE ls.scene_name='13-Christmas Story' AND t.active_flag ORDER BY t.display_order, t.setup_task_id;")"
for pair in "00:$TASK00" "01:$TASK01" "16:$TASK16" "13-Christmas Story:$TASK13SCENE"; do
    label="${pair%%:*}"
    value="${pair#*:}"
    if [[ ! "$value" =~ ^[0-9]+$ ]]; then
        echo "FAIL: could not select representative material task for $label"
        exit 28
    fi
done

echo "Representative probe tasks: Stage00=$TASK00 Stage01=$TASK01 Stage16=$TASK16 ChristmasStory=$TASK13SCENE"

patch_flag() {
    local task_id="$1"
    local endpoint="$2"
    local json="$3"
    local response_file="/tmp/setup-material-patch-${task_id}-${endpoint//\//_}-$STAMP.json"
    TEMP_FILES+=("$response_file")
    local code
    code="$(curl -sS -o "$response_file" -w '%{http_code}' \
        -X PATCH \
        -H 'Content-Type: application/json' \
        -H 'X-MSB-Setup-Command: 1' \
        --data "$json" \
        "http://127.0.0.1:$PREVIEW_PORT/api/setup/tasks/$task_id/$endpoint")"
    if [[ "$code" != "200" ]]; then
        echo "FAIL: PATCH task $task_id/$endpoint returned HTTP $code"
        cat "$response_file" || true
        exit 29
    fi
}

for task_id in "$TASK00" "$TASK01" "$TASK16" "$TASK13SCENE"; do
    patch_flag "$task_id" "display-setup-step" '{"is_display_setup_step":true}'
    patch_flag "$task_id" "display-material" '{"requires_display_material":true}'
done

echo "Governed Display Setup + whole-scope material PATCH probes: PASS"

# Magic Igloo proves Display Setup color/classification is not the same as
# releasing the entire Stage material set for every physical step.
MAGIC_IDS="$(psql_test -qAt -c "
    SELECT string_agg(t.setup_task_id::text, ',' ORDER BY t.setup_task_id)
    FROM ref.setup_task t
    JOIN ref.stage s ON s.stage_id=t.stage_id
    WHERE s.stage_key='26'
      AND t.active_flag
      AND t.task_name IN (
        'Layout / Erect Frame / Strap Down',
        'Install Skins and Bungees',
        'Install Lighting, Cameras, Mats, Signs, and Finish Setup'
      );
")"
IFS=',' read -r -a MAGIC_ARRAY <<< "$MAGIC_IDS"
if [[ "${#MAGIC_ARRAY[@]}" -ne 3 ]]; then
    echo "FAIL: expected three current Magic Igloo Display Setup tasks; found '$MAGIC_IDS'"
    exit 30
fi
for task_id in "${MAGIC_ARRAY[@]}"; do
    patch_flag "$task_id" "display-setup-step" '{"is_display_setup_step":true}'
done
echo "Magic Igloo three-step Display Setup classification probe: PASS"

fetch_context() {
    local task_id="$1"
    local label="$2"
    local file="/tmp/setup-material-context-${label}-$STAMP.json"
    TEMP_FILES+=("$file")
    local code
    code="$(curl -sS -o "$file" -w '%{http_code}' \
        "http://127.0.0.1:$PREVIEW_PORT/api/setup/tasks/$task_id/material-context?season_year=2025")"
    if [[ "$code" != "200" ]]; then
        echo "FAIL: material context $label returned HTTP $code"
        cat "$file" || true
        exit 31
    fi
    printf '%s' "$file"
}

CTX00="$(fetch_context "$TASK00" stage00)"
CTX01="$(fetch_context "$TASK01" stage01)"
CTX16="$(fetch_context "$TASK16" stage16)"
CTX13="$(fetch_context "$TASK13SCENE" christmas_story)"

sudo -u fieldwiring -H /opt/fieldwiring/.venv/bin/python - \
    "$CTX00" "$CTX01" "$CTX16" "$CTX13" <<'PY'
import json
import sys


def load(path):
    with open(path, encoding='utf-8') as handle:
        return json.load(handle)['context']


def check(label, context, expected_count, expected_containers, expected_uncontained=None):
    displays = context.get('displays', [])
    containers = {int(d['container_id']) for d in displays if d.get('container_id') is not None}
    uncontained = sum(1 for d in displays if d.get('container_id') is None)
    if len(displays) != expected_count:
        raise SystemExit(f'FAIL: {label} expected {expected_count} Displays; found {len(displays)}')
    if containers != set(expected_containers):
        raise SystemExit(f'FAIL: {label} containers {sorted(containers)} != {sorted(expected_containers)}')
    if expected_uncontained is not None and uncontained != expected_uncontained:
        raise SystemExit(f'FAIL: {label} expected {expected_uncontained} uncontained Displays; found {uncontained}')
    mode = context.get('material_resolution', {}).get('mode')
    print(f'{label}: PASS displays={len(displays)} containers={sorted(containers)} uncontained={uncontained} mode={mode}')

check('Stage 00 remainder', load(sys.argv[1]), 11, {1, 146})
check('Stage 01 remainder', load(sys.argv[2]), 7, {1})
check('Stage 16 Northern Lights', load(sys.argv[3]), 66, {16, 17, 18, 19})
check('13-Christmas Story Scene', load(sys.argv[4]), 8, {6, 131, 150, 171}, 1)
PY

echo "Current-Production-derived Stage/Scene material resolver assertions: PASS"

LEGACY_AFTER_PROBES="$(legacy_fingerprint)"
if [[ "$LEGACY_AFTER_PROBES" != "$LEGACY_BEFORE" ]]; then
    echo "FAIL: clone-only flag/API probes changed pre-existing Setup data outside new metadata"
    exit 32
fi
echo "Clone-only probes changed only new Display Setup/material metadata: PASS"

echo
echo "============================================================"
echo "SETUP DISPLAY MATERIAL BROWSER REVIEW READY"
echo "Open on the Windows workstation:"
echo "  http://127.0.0.1:$PREVIEW_PORT/"
echo
echo "Exact candidate: $TARGET_SHA"
echo "Preview identity: $PREVIEW_EMAIL"
echo "Production remains unchanged. All preview writes go to the disposable clone."
echo
echo "Review these visible behaviors:"
echo "  1. Reusable Task Catalog: representative Stage 00, Stage 01, Stage 16 and Christmas Story rows show DISPLAY SETUP + SCOPE MATERIAL treatment."
echo "  2. Stage 26 Magic Igloo: Frame, Skins/Bungees, and Lighting/Cameras/Finish rows all show DISPLAY SETUP; they are not falsely given whole-scope staged material timing."
echo "  3. Open a representative material task and confirm the two separate checkboxes are understandable."
echo "  4. Inspect Material / Logistics for Stage 00, Stage 01, Stage 16 and Christmas Story. Automated counts already passed above."
echo "  5. Add one PREVIEW-ONLY reusable task and confirm creation immediately opens the full task editor. You may delete the preview task afterward, but it cannot affect Production."
echo
echo "When review is finished, return here and press ENTER."
echo "============================================================"
echo

read -r -p "Press ENTER to stop and clean up the Setup Display material preview... " _unused

echo "Operator ended browser review. Cleaning up."
