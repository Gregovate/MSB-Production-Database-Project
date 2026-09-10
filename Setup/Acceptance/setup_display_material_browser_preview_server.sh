#!/usr/bin/env bash
set -euo pipefail

PROD_CONTAINER="msb-postgres"
PROD_DB="msb"
DB_ACTOR="msbadmin"
IMAGE="postgis/postgis:16-3.5"
NETWORK="msb-stack_default"
REPO_ROOT="/opt/fieldwiring"
SETUP_LIVE_ROOT="/opt/msb-setup"
MASTER_MUSICAL_PREVIEW_UUID="fcf5c29c-8d51-46c5-9ad0-cc47a97c75bd"

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
PREVIEW_OWNED_PORT=0
TEMP_FILES=()

mkdir -p "$REPORT_DIR"
exec > >(tee "$REPORT") 2>&1

echo "========== SETUP EXPLICIT LOR MATERIAL BROWSER PREVIEW =========="
echo "Authority: Gregovate/MSB-Server-Management — docs/server/Pre_Production_Browser_Review_Runbook.md"
echo "Disposable standard: docs/server/PostgreSQL_Disposable_Acceptance_Standard.md"
echo "Candidate SHA: $TARGET_SHA"
echo "Target ref:    $TARGET_REF"
echo "Preview port:  $PREVIEW_PORT"
echo "Preview user:  $PREVIEW_EMAIL"
echo "Report:        $REPORT"
echo "Production DB: pg_dump + SELECT only"
echo "Preview writes: disposable current-Production clone only"
echo

prod_fingerprint() {
    sudo docker exec "$PROD_CONTAINER" psql -X -qAt -v ON_ERROR_STOP=1 -U "$DB_ACTOR" -d "$PROD_DB" -c "
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
    echo "--- Setup explicit material browser preview cleanup ---"
    if [[ -n "$PREVIEW_PGID" ]]; then
        sudo kill -- -"$PREVIEW_PGID" >/dev/null 2>&1 || true
        sleep 1
        sudo kill -KILL -- -"$PREVIEW_PGID" >/dev/null 2>&1 || true
    fi
    sudo docker rm -f "$TEST_CONTAINER" >/dev/null 2>&1 || true
    if sudo git -C "$REPO_ROOT" worktree list --porcelain 2>/dev/null | grep -Fq "worktree $CANDIDATE_WORKTREE"; then
        sudo git -C "$REPO_ROOT" worktree remove --force "$CANDIDATE_WORKTREE" >/dev/null 2>&1 || true
    fi
    rm -f "$DUMP_FILE" "$GRANTS_FILE" >/dev/null 2>&1 || true
    if (( ${#TEMP_FILES[@]} > 0 )); then rm -f "${TEMP_FILES[@]}" >/dev/null 2>&1 || true; fi
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
    fi
    if [[ "$PREVIEW_OWNED_PORT" -eq 1 ]] && ss -ltnH "sport = :$PREVIEW_PORT" | grep -q .; then
        echo "FAIL: preview-owned TCP port $PREVIEW_PORT is still listening after cleanup"
        status=99
    fi
    if [[ -s "$PREVIEW_LOG" ]]; then echo "Preview Flask log retained at: $PREVIEW_LOG"; else echo "Preview Flask log: not created"; fi
    echo "Preview report retained at:    $REPORT"
    echo "Exit status: $status"
    exit "$status"
}
trap cleanup EXIT INT TERM

sudo -v
if [[ ! "$PREVIEW_PORT" =~ ^[0-9]+$ ]] || (( PREVIEW_PORT < 1024 || PREVIEW_PORT > 65535 )); then echo "FAIL: preview port must be an integer from 1024 through 65535"; exit 2; fi
if [[ "$PREVIEW_PORT" == "8055" || "$PREVIEW_PORT" == "8790" || "$PREVIEW_PORT" == "8792" || "$PREVIEW_PORT" == "8794" ]]; then echo "FAIL: preview port conflicts with a governed Production listener"; exit 3; fi
if ss -ltnH "sport = :$PREVIEW_PORT" | grep -q .; then echo "FAIL: preview port $PREVIEW_PORT is already listening on msb-prod-db"; exit 4; fi
if ! sudo docker inspect "$PROD_CONTAINER" >/dev/null 2>&1; then echo "FAIL: Production PostgreSQL container was not found"; exit 5; fi
if [[ "$(sudo docker inspect "$PROD_CONTAINER" --format '{{.Config.Image}}')" != "$IMAGE" ]]; then echo "FAIL: Production PostgreSQL image is not $IMAGE"; exit 6; fi
if ! sudo docker network inspect "$NETWORK" >/dev/null 2>&1; then echo "FAIL: Docker network $NETWORK was not found"; exit 7; fi
if ! systemctl is-active --quiet msb-setup.service; then echo "FAIL: Production Setup service is not active"; exit 8; fi
if ! sudo -u fieldwiring -H test -x /opt/fieldwiring/.venv/bin/python; then echo "FAIL: Production Python runtime is not executable as fieldwiring"; exit 9; fi

SETUP_HEAD_BEFORE="$(sudo git -C "$SETUP_LIVE_ROOT" rev-parse HEAD)"
if [[ -n "$(sudo git -C "$SETUP_LIVE_ROOT" status --porcelain)" ]]; then echo "FAIL: live Setup detached worktree has uncommitted changes"; exit 10; fi
if [[ -n "$(sudo git -C "$REPO_ROOT" status --porcelain)" ]]; then echo "FAIL: shared repository checkout has uncommitted changes"; exit 11; fi

echo "Live Setup SHA: $SETUP_HEAD_BEFORE"
PROD_BEFORE="$(prod_fingerprint)"
test -n "$PROD_BEFORE"
echo "Production Setup fingerprint before: $PROD_BEFORE"

echo
echo "--- Fetch exact candidate and prove forward ancestry from live Setup ---"
sudo git -C "$REPO_ROOT" fetch origin "$TARGET_REF"
sudo git -C "$REPO_ROOT" cat-file -e "$TARGET_SHA^{commit}"
if ! sudo git -C "$REPO_ROOT" merge-base --is-ancestor "$SETUP_HEAD_BEFORE" "$TARGET_SHA"; then echo "FAIL: candidate is not a forward descendant of live Setup"; exit 12; fi
sudo git -C "$REPO_ROOT" worktree add --detach "$CANDIDATE_WORKTREE" "$TARGET_SHA"

M026="$CANDIDATE_WORKTREE/Setup/Database/026_add_setup_explicit_lor_material_sources.sql"
VALIDATION="$CANDIDATE_WORKTREE/Setup/Acceptance/setup_display_material_disposable_validation.sql"
PREVIEW_ENTRY="$CANDIDATE_WORKTREE/Setup/Acceptance/setup_session_browser_preview_entry.py"
for file in "$M026" "$VALIDATION" "$PREVIEW_ENTRY"; do if [[ ! -s "$file" ]]; then echo "FAIL: exact candidate is missing required acceptance file: $file"; exit 13; fi; done
if [[ -e "$CANDIDATE_WORKTREE/Setup/Database/025_add_setup_display_material_requirement.sql" ]]; then echo "FAIL: rejected migration 025 is still present in candidate"; exit 14; fi

echo
echo "--- Exact candidate regression in Production runtime ---"
sudo -u fieldwiring -H env PYTHONPYCACHEPREFIX="/tmp/msb-setup-material-pycache-$STAMP" bash -c "
    cd '$CANDIDATE_WORKTREE'
    /opt/fieldwiring/.venv/bin/python -m py_compile Setup/Application/setup_material_api.py Setup/Application/production_backend.py
    /opt/fieldwiring/.venv/bin/python -m pytest -q -p no:cacheprovider Setup/Application
"
rm -rf "/tmp/msb-setup-material-pycache-$STAMP" >/dev/null 2>&1 || true
echo "Exact candidate full Setup/Application regression: PASS"

echo
echo "--- Capture current Production into disposable clone ---"
sudo docker exec "$PROD_CONTAINER" pg_dump -U "$DB_ACTOR" -d "$PROD_DB" -Fc > "$DUMP_FILE"
test -s "$DUMP_FILE"
sudo docker exec -i "$PROD_CONTAINER" pg_restore --list < "$DUMP_FILE" >/dev/null
sha256sum "$DUMP_FILE"

sudo docker run -d --name "$TEST_CONTAINER" --network "$NETWORK" -e POSTGRES_USER="$DB_ACTOR" -e POSTGRES_PASSWORD="$TEST_PASSWORD" -e POSTGRES_DB=postgres "$IMAGE" >/dev/null
ready=0
for _ in $(seq 1 120); do
    pid1="$(sudo docker exec "$TEST_CONTAINER" sh -c 'cat /proc/1/comm' 2>/dev/null | tr -d '\r\n' || true)"
    if [[ "$pid1" == "postgres" ]] && sudo docker exec -e PGPASSWORD="$TEST_PASSWORD" "$TEST_CONTAINER" pg_isready -U "$DB_ACTOR" -d postgres >/dev/null 2>&1; then ready=1; break; fi
    sleep 1
done
if [[ "$ready" -ne 1 ]]; then echo "FAIL: disposable PostgreSQL did not reach final ready state"; exit 15; fi

sudo docker exec -e PGPASSWORD="$TEST_PASSWORD" "$TEST_CONTAINER" createdb -U "$DB_ACTOR" -T template0 "$TEST_DB"
sudo docker exec -i -e PGPASSWORD="$TEST_PASSWORD" "$TEST_CONTAINER" pg_restore -U "$DB_ACTOR" -d "$TEST_DB" --no-owner --no-acl --exit-on-error < "$DUMP_FILE"

psql_test() { sudo docker exec -i -e PGPASSWORD="$TEST_PASSWORD" "$TEST_CONTAINER" psql -X -v ON_ERROR_STOP=1 -U "$DB_ACTOR" -d "$TEST_DB" "$@"; }

legacy_exact_fingerprint() {
    psql_test -qAt -c "
        SELECT md5(
            coalesce((SELECT string_agg((to_jsonb(t) - 'is_display_setup_step')::text, '' ORDER BY t.setup_task_id) FROM ref.setup_task t), '') || '|' ||
            coalesce((SELECT string_agg(row_to_json(d)::text, '' ORDER BY d.setup_task_id, d.prerequisite_setup_task_id) FROM ref.setup_task_dependency d), '') || '|' ||
            coalesce((SELECT string_agg(row_to_json(td)::text, '' ORDER BY td.setup_task_id, td.display_id) FROM ref.setup_task_display td), '') || '|' ||
            coalesce((SELECT string_agg(row_to_json(st)::text, '' ORDER BY st.setup_session_task_id) FROM ops.setup_session_task st), '')
        );
    "
}

legacy_business_fingerprint() {
    psql_test -qAt -c "
        SELECT md5(
            coalesce((SELECT string_agg((to_jsonb(t) - 'is_display_setup_step' - 'updated_at' - 'updated_by' - 'updated_by_person_id')::text, '' ORDER BY t.setup_task_id) FROM ref.setup_task t), '') || '|' ||
            coalesce((SELECT string_agg(row_to_json(d)::text, '' ORDER BY d.setup_task_id, d.prerequisite_setup_task_id) FROM ref.setup_task_dependency d), '') || '|' ||
            coalesce((SELECT string_agg(row_to_json(td)::text, '' ORDER BY td.setup_task_id, td.display_id) FROM ref.setup_task_display td), '') || '|' ||
            coalesce((SELECT string_agg(row_to_json(st)::text, '' ORDER BY st.setup_session_task_id) FROM ops.setup_session_task st), '')
        );
    "
}

LEGACY_EXACT_BEFORE="$(legacy_exact_fingerprint)"
LEGACY_BUSINESS_BEFORE="$(legacy_business_fingerprint)"
if [[ -z "$LEGACY_EXACT_BEFORE" || -z "$LEGACY_BUSINESS_BEFORE" ]]; then echo "FAIL: disposable pre-migration fingerprints were empty"; exit 16; fi

echo
echo "--- Recreate Production-equivalent application role boundary ---"
psql_test -c "CREATE ROLE fieldwiring_app LOGIN PASSWORD '$APP_PASSWORD';"
sudo docker exec "$PROD_CONTAINER" psql -X -qAt -v ON_ERROR_STOP=1 -U "$DB_ACTOR" -d "$PROD_DB" -c "
    SELECT format('GRANT USAGE ON SCHEMA %I TO fieldwiring_app;', n.nspname)
    FROM pg_namespace n WHERE n.nspname IN ('ref','lor_snap','ops') AND has_schema_privilege('fieldwiring_app', n.oid, 'USAGE')
    UNION ALL
    SELECT format('GRANT SELECT ON TABLE %I.%I TO fieldwiring_app;', n.nspname, c.relname)
    FROM pg_class c JOIN pg_namespace n ON n.oid = c.relnamespace
    WHERE n.nspname IN ('ref','lor_snap','ops','public') AND c.relkind IN ('r','v','m','f','p') AND has_table_privilege('fieldwiring_app', c.oid, 'SELECT')
    UNION ALL
    SELECT format('GRANT EXECUTE ON FUNCTION %I.%I(%s) TO fieldwiring_app;', n.nspname, p.proname, pg_get_function_identity_arguments(p.oid))
    FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
    WHERE n.nspname IN ('ref','ops') AND p.prokind IN ('f','w') AND has_function_privilege('fieldwiring_app', p.oid, 'EXECUTE');
" > "$GRANTS_FILE"
test -s "$GRANTS_FILE"
psql_test < "$GRANTS_FILE"

echo
echo "--- Apply migration 026 to disposable clone only ---"
psql_test < "$M026"
psql_test < "$VALIDATION"
LEGACY_EXACT_AFTER="$(legacy_exact_fingerprint)"
echo "Disposable legacy exact fingerprint before migration: $LEGACY_EXACT_BEFORE"
echo "Disposable legacy exact fingerprint after migration:  $LEGACY_EXACT_AFTER"
if [[ "$LEGACY_EXACT_AFTER" != "$LEGACY_EXACT_BEFORE" ]]; then echo "FAIL: migration 026 changed pre-existing Setup data or audit provenance"; exit 17; fi
echo "Migration 026 preserved pre-existing Setup data exactly: PASS"

echo
echo "--- Replay migration 026 ---"
psql_test < "$M026"
if [[ "$(legacy_exact_fingerprint)" != "$LEGACY_EXACT_BEFORE" ]]; then echo "FAIL: migration 026 replay changed pre-existing Setup data or audit provenance"; exit 18; fi
echo "Migration 026 replay: PASS"

MANAGE_OK="$(psql_test -qAt -c "SELECT can_manage_setup FROM ref.setup_browser_capabilities('$PREVIEW_EMAIL');")"
if [[ "$MANAGE_OK" != "t" ]]; then echo "FAIL: preview operator lacks Setup Manager capability"; exit 19; fi
TEST_IP="$(sudo docker inspect "$TEST_CONTAINER" --format '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}')"
if [[ -z "$TEST_IP" ]]; then echo "FAIL: could not resolve disposable PostgreSQL container IP"; exit 20; fi
DSN="host=$TEST_IP port=5432 dbname=$TEST_DB user=fieldwiring_app password=$APP_PASSWORD"
APP_DIR="$CANDIDATE_WORKTREE/Setup/Application"

echo
echo "--- Start exact candidate on temporary preview port ---"
PREVIEW_PGID="$(sudo -u fieldwiring -H env SETUP_DATABASE_DSN="$DSN" MSB_SETUP_PREVIEW_APP_DIR="$APP_DIR" MSB_SETUP_PREVIEW_OPERATOR_EMAIL="$PREVIEW_EMAIL" MSB_SETUP_PREVIEW_HOST="127.0.0.1" MSB_SETUP_PREVIEW_PORT="$PREVIEW_PORT" MSB_SETUP_PREVIEW_ENTRY="$PREVIEW_ENTRY" MSB_SETUP_PREVIEW_LOG="$PREVIEW_LOG" bash -c '
    cd /tmp
    setsid /opt/fieldwiring/.venv/bin/python "$MSB_SETUP_PREVIEW_ENTRY" > "$MSB_SETUP_PREVIEW_LOG" 2>&1 &
    echo $!
')"
if [[ ! "$PREVIEW_PGID" =~ ^[0-9]+$ ]]; then echo "FAIL: preview process did not return PID"; exit 21; fi
PREVIEW_OWNED_PORT=1
preview_ready=0
for _ in $(seq 1 30); do
    if curl -fsS "http://127.0.0.1:$PREVIEW_PORT/api/health" >/dev/null 2>&1; then preview_ready=1; break; fi
    sleep 1
done
if [[ "$preview_ready" -ne 1 ]]; then echo "FAIL: preview did not become healthy"; tail -n 120 "$PREVIEW_LOG" || true; exit 22; fi
curl -fsS "http://127.0.0.1:$PREVIEW_PORT/api/health"
echo

METADATA="/tmp/setup-material-metadata-$STAMP.json"; TEMP_FILES+=("$METADATA")
code="$(curl -sS -o "$METADATA" -w '%{http_code}' "http://127.0.0.1:$PREVIEW_PORT/api/setup/task-display-material")"
if [[ "$code" != "200" ]]; then cat "$METADATA" || true; exit 23; fi
sudo -u fieldwiring -H /opt/fieldwiring/.venv/bin/python - "$METADATA" <<'PY'
import json, sys
with open(sys.argv[1], encoding='utf-8') as f: payload = json.load(f)
rows = payload.get('task_display_material', [])
if not rows: raise SystemExit('FAIL: metadata API returned no tasks')
if any(r.get('is_display_setup_step') for r in rows): raise SystemExit('FAIL: migration inferred Display Setup classification')
if any(r.get('material_sources') for r in rows): raise SystemExit('FAIL: migration inferred material sources from work scope')
types = {x.get('source_type') for x in payload.get('material_source_catalog', [])}
if types != {'LOR_STAGE','LOR_PREVIEW','LOR_SCENE'}: raise SystemExit(f'FAIL: source catalog types are {sorted(types)}')
print(f'Material metadata defaults: PASS tasks={len(rows)} sources=0')
PY

query_task_id() { psql_test -qAt -c "$1"; }
TASK00="$(query_task_id "SELECT t.setup_task_id FROM ref.setup_task t JOIN ref.stage s ON s.stage_id=t.stage_id WHERE s.stage_key='00' AND t.active_flag ORDER BY CASE WHEN t.task_name='Setup HWY42 Traffic Signs' THEN 0 ELSE 1 END, t.display_order, t.setup_task_id LIMIT 1;")"
TASK01="$(query_task_id "SELECT t.setup_task_id FROM ref.setup_task t JOIN ref.stage s ON s.stage_id=t.stage_id WHERE s.stage_key='01' AND t.active_flag ORDER BY t.display_order, t.setup_task_id LIMIT 1;")"
TASK16="$(query_task_id "SELECT t.setup_task_id FROM ref.setup_task t JOIN ref.stage s ON s.stage_id=t.stage_id WHERE s.stage_key='16' AND t.active_flag ORDER BY CASE WHEN t.task_name='Setup Northern Lights' THEN 0 ELSE 1 END, t.display_order, t.setup_task_id LIMIT 1;")"
TASK13="$(query_task_id "SELECT t.setup_task_id FROM ref.setup_task t WHERE t.lor_scene_id=258 AND t.active_flag ORDER BY t.display_order, t.setup_task_id LIMIT 1;")"
STAGE00_ID="$(query_task_id "SELECT stage_id FROM ref.stage WHERE stage_key='00' ORDER BY stage_id LIMIT 1;")"
SCENE16_ID="$(query_task_id "SELECT ls.lor_scene_id FROM ref.lor_scene ls JOIN ref.stage s ON s.stage_id=ls.stage_id WHERE ls.lor_scene_id=298 AND s.stage_key='16' LIMIT 1;")"
MASTER_PREVIEW_NAME="$(query_task_id "SELECT name FROM lor_snap.v_current_previews WHERE id='$MASTER_MUSICAL_PREVIEW_UUID' LIMIT 1;")"
for value in "$TASK00" "$TASK01" "$TASK16" "$TASK13" "$STAGE00_ID" "$SCENE16_ID"; do if [[ ! "$value" =~ ^[0-9]+$ ]]; then echo "FAIL: representative task/source lookup failed"; exit 24; fi; done
if [[ "$MASTER_PREVIEW_NAME" != *"Master Musical Preview"* ]]; then echo "FAIL: expected shared Master Musical Preview for $MASTER_MUSICAL_PREVIEW_UUID; found '$MASTER_PREVIEW_NAME'"; exit 24; fi
echo "Stage 16 current material evidence: Scene $SCENE16_ID inside shared Preview '$MASTER_PREVIEW_NAME'"

NONE_CTX="/tmp/setup-material-none-$STAMP.json"; TEMP_FILES+=("$NONE_CTX")
code="$(curl -sS -o "$NONE_CTX" -w '%{http_code}' "http://127.0.0.1:$PREVIEW_PORT/api/setup/tasks/$TASK13/material-context?season_year=2025")"
if [[ "$code" != "200" ]]; then cat "$NONE_CTX" || true; exit 25; fi
sudo -u fieldwiring -H /opt/fieldwiring/.venv/bin/python - "$NONE_CTX" <<'PY'
import json, sys
ctx=json.load(open(sys.argv[1], encoding='utf-8'))['context']
if ctx.get('displays') or ctx.get('material_containers'): raise SystemExit('FAIL: work Scene implied material with zero selected sources')
if ctx.get('material_resolution',{}).get('mode') != 'NONE': raise SystemExit('FAIL: zero-source task did not resolve mode NONE')
print('Work-scope/material independence: PASS (Scene-scoped task resolves 0 Displays before source selection)')
PY

patch_source() {
    local task="$1" type="$2" key="$3" active="${4:-true}" file code
    file="/tmp/setup-material-source-${task}-${type}-${RANDOM}-$STAMP.json"; TEMP_FILES+=("$file")
    code="$(curl -sS -o "$file" -w '%{http_code}' -X PATCH -H 'Content-Type: application/json' -H 'X-MSB-Setup-Command: 1' --data "{\"source_type\":\"$type\",\"source_key\":\"$key\",\"active\":$active}" "http://127.0.0.1:$PREVIEW_PORT/api/setup/tasks/$task/material-source")"
    if [[ "$code" != "200" ]]; then echo "FAIL: material-source PATCH $task $type $key active=$active -> $code"; cat "$file" || true; exit 26; fi
}
patch_source "$TASK00" LOR_STAGE "$STAGE00_ID"
for scene_id in 253 254 293 467 468; do patch_source "$TASK01" LOR_SCENE "$scene_id"; done
patch_source "$TASK16" LOR_PREVIEW "$MASTER_MUSICAL_PREVIEW_UUID"
patch_source "$TASK13" LOR_SCENE "258"

MAGIC_IDS="$(psql_test -qAt -c "SELECT string_agg(t.setup_task_id::text, ',' ORDER BY t.setup_task_id) FROM ref.setup_task t JOIN ref.stage s ON s.stage_id=t.stage_id WHERE s.stage_key='26' AND t.active_flag AND t.task_name IN ('Layout / Erect Frame / Strap Down','Install Skins and Bungees','Install Lighting, Cameras, Mats, Signs, and Finish Setup');")"
IFS=',' read -r -a MAGIC_ARRAY <<< "$MAGIC_IDS"
if [[ "${#MAGIC_ARRAY[@]}" -ne 3 ]]; then echo "FAIL: expected three Magic Igloo tasks"; exit 27; fi
for task in "${MAGIC_ARRAY[@]}"; do
    file="/tmp/setup-display-step-$task-$STAMP.json"; TEMP_FILES+=("$file")
    code="$(curl -sS -o "$file" -w '%{http_code}' -X PATCH -H 'Content-Type: application/json' -H 'X-MSB-Setup-Command: 1' --data '{"is_display_setup_step":true}' "http://127.0.0.1:$PREVIEW_PORT/api/setup/tasks/$task/display-setup-step")"
    if [[ "$code" != "200" ]]; then cat "$file" || true; exit 28; fi
done
echo "Display Setup classification independent of material: PASS"

CTX00="/tmp/setup-material-context-stage00-$STAMP.json"; CTX01="/tmp/setup-material-context-stage01-$STAMP.json"; CTX16_PREVIEW="/tmp/setup-material-context-master-preview-$STAMP.json"; CTX13="/tmp/setup-material-context-christmas-story-$STAMP.json"; CTX16_SCENE="/tmp/setup-material-context-stage16-scene-$STAMP.json"
TEMP_FILES+=("$CTX00" "$CTX01" "$CTX16_PREVIEW" "$CTX13" "$CTX16_SCENE")
fetch_context() { local task="$1" file="$2" code; code="$(curl -sS -o "$file" -w '%{http_code}' "http://127.0.0.1:$PREVIEW_PORT/api/setup/tasks/$task/material-context?season_year=2025")"; if [[ "$code" != "200" ]]; then cat "$file" || true; exit 29; fi; }
fetch_context "$TASK00" "$CTX00"; fetch_context "$TASK01" "$CTX01"; fetch_context "$TASK16" "$CTX16_PREVIEW"; fetch_context "$TASK13" "$CTX13"

sudo -u fieldwiring -H /opt/fieldwiring/.venv/bin/python - "$CTX00" "$CTX01" "$CTX16_PREVIEW" "$CTX13" <<'PY'
import json, sys
def load(path):
    with open(path, encoding='utf-8') as f: return json.load(f)['context']
def material_container_ids(ctx): return sorted(int(c['container_id']) for c in ctx.get('material_containers', []))
def display_container_ids(ctx): return sorted({int(d['container_id']) for d in ctx.get('displays', []) if d.get('container_id') is not None})
def check(label, ctx, count, containers, sources, uncontained=None):
    displays=ctx.get('displays', []); ids=[d['display_id'] for d in displays]
    if len(ids) != len(set(ids)): raise SystemExit(f'FAIL: {label} returned duplicate Displays')
    actual=set(display_container_ids(ctx)); material=material_container_ids(ctx)
    if len(displays) != count: raise SystemExit(f'FAIL: {label} expected {count} Displays; found {len(displays)}')
    if actual != set(containers): raise SystemExit(f'FAIL: {label} Display containers {sorted(actual)} != {sorted(containers)}')
    if material != sorted(set(containers)): raise SystemExit(f'FAIL: {label} derived material containers {material} != {sorted(set(containers))}')
    if ctx.get('material_resolution',{}).get('source_count') != sources: raise SystemExit(f'FAIL: {label} source_count mismatch')
    if uncontained is not None and sum(1 for d in displays if d.get('container_id') is None) != uncontained: raise SystemExit(f'FAIL: {label} uncontained count mismatch')
    print(f'{label}: PASS displays={count} containers={sorted(actual)} sources={sources}')
def check_shared_preview(ctx):
    label='Shared Master Musical Preview source'; displays=ctx.get('displays', []); ids=[d['display_id'] for d in displays]
    if len(ids) != len(set(ids)): raise SystemExit(f'FAIL: {label} returned duplicate Displays')
    if len(displays) <= 66: raise SystemExit(f'FAIL: {label} was incorrectly clamped to one work Stage/Scene; found only {len(displays)} Displays')
    if material_container_ids(ctx) != display_container_ids(ctx): raise SystemExit(f'FAIL: {label} material Containers do not match derived Display Containers')
    resolution=ctx.get('material_resolution', {}); sources=resolution.get('sources', [])
    if resolution.get('source_count') != 1 or len(sources) != 1 or sources[0].get('source_type') != 'LOR_PREVIEW': raise SystemExit(f'FAIL: {label} did not retain exact Preview source identity')
    if 'Master Musical Preview' not in str(sources[0].get('label') or ''): raise SystemExit(f'FAIL: {label} source label is not the shared Master Musical Preview')
    print(f'{label}: PASS displays={len(displays)} containers={len(display_container_ids(ctx))} sources=1 (whole Preview, not Stage-clamped)')
check('Stage 00 explicit Stage source', load(sys.argv[1]), 11, {1,146}, 1)
check('Stage 01 explicit five-group union', load(sys.argv[2]), 7, {1}, 5)
check_shared_preview(load(sys.argv[3]))
check('13-Christmas Story explicit Scene source', load(sys.argv[4]), 8, {6,131,150,171}, 1, 1)
PY

patch_source "$TASK16" LOR_PREVIEW "$MASTER_MUSICAL_PREVIEW_UUID" false
patch_source "$TASK16" LOR_SCENE "$SCENE16_ID" true
fetch_context "$TASK16" "$CTX16_SCENE"
sudo -u fieldwiring -H /opt/fieldwiring/.venv/bin/python - "$CTX16_SCENE" <<'PY'
import json, sys
ctx=json.load(open(sys.argv[1], encoding='utf-8'))['context']; displays=ctx.get('displays', []); ids=[d['display_id'] for d in displays]
if len(ids) != len(set(ids)): raise SystemExit('FAIL: Stage 16 Northern Lights Scene returned duplicate Displays')
containers={int(d['container_id']) for d in displays if d.get('container_id') is not None}; material=sorted(int(c['container_id']) for c in ctx.get('material_containers', []))
if len(displays) != 66: raise SystemExit(f'FAIL: Stage 16 Northern Lights explicit Scene source expected 66 Displays; found {len(displays)}')
if containers != {16,17,18,19}: raise SystemExit(f'FAIL: Stage 16 Northern Lights containers {sorted(containers)} != [16, 17, 18, 19]')
if material != [16,17,18,19]: raise SystemExit(f'FAIL: Stage 16 Northern Lights derived material containers {material} != [16, 17, 18, 19]')
resolution=ctx.get('material_resolution', {}); sources=resolution.get('sources', [])
if resolution.get('source_count') != 1: raise SystemExit('FAIL: Stage 16 Northern Lights Scene source_count mismatch')
if len(sources) != 1 or sources[0].get('source_type') != 'LOR_SCENE' or str(sources[0].get('source_key')) != '298': raise SystemExit('FAIL: Stage 16 Northern Lights did not resolve from exact LOR Scene 298')
print('Stage 16 Northern Lights explicit Scene source: PASS displays=66 containers=[16, 17, 18, 19] sources=1')
PY

psql_test <<SQL
DO \$candidate_metadata\$
BEGIN
    IF (SELECT count(*) FROM ref.setup_task WHERE is_display_setup_step) <> 3 THEN RAISE EXCEPTION 'Expected exactly three Display Setup classifications after probes'; END IF;
    IF EXISTS (SELECT 1 FROM ref.setup_task WHERE is_display_setup_step AND setup_task_id NOT IN ($MAGIC_IDS)) THEN RAISE EXCEPTION 'Display Setup classification leaked outside the three Magic Igloo probe tasks'; END IF;
    IF (SELECT count(*) FROM ref.setup_task_material_source) <> 8 THEN RAISE EXCEPTION 'Expected exactly eight material-source rows after probes'; END IF;
    IF EXISTS (
        SELECT 1 FROM ref.setup_task_material_source ms
        WHERE NOT (
            (ms.setup_task_id = $TASK00 AND ms.source_type = 'LOR_STAGE' AND ms.stage_id = $STAGE00_ID)
            OR (ms.setup_task_id = $TASK01 AND ms.source_type = 'LOR_SCENE' AND ms.lor_scene_id IN (253,254,293,467,468))
            OR (ms.setup_task_id = $TASK16 AND ms.source_type = 'LOR_SCENE' AND ms.lor_scene_id = 298)
            OR (ms.setup_task_id = $TASK13 AND ms.source_type = 'LOR_SCENE' AND ms.lor_scene_id = 258)
        )
    ) THEN RAISE EXCEPTION 'Unexpected material-source row exists after probes'; END IF;
    IF EXISTS (SELECT 1 FROM ref.setup_task_material_source WHERE setup_task_id = $TASK16 AND source_type = 'LOR_PREVIEW') THEN RAISE EXCEPTION 'Temporary shared Preview probe source was not removed from Stage 16 task'; END IF;
    RAISE NOTICE 'SETUP_EXPLICIT_MATERIAL_PROBE_METADATA_PASS';
END
\$candidate_metadata\$;
SQL

LEGACY_BUSINESS_AFTER="$(legacy_business_fingerprint)"
echo "Disposable pre-existing business fingerprint before probes: $LEGACY_BUSINESS_BEFORE"
echo "Disposable pre-existing business fingerprint after probes:  $LEGACY_BUSINESS_AFTER"
if [[ "$LEGACY_BUSINESS_AFTER" != "$LEGACY_BUSINESS_BEFORE" ]]; then echo "FAIL: clone-only probes changed pre-existing Setup business data"; exit 30; fi
echo "Clone-only probes changed only candidate metadata + required audit provenance: PASS"

echo
echo "============================================================"
echo "SETUP EXPLICIT LOR MATERIAL BROWSER REVIEW READY"
echo "Open on the Windows workstation:"
echo "  http://127.0.0.1:$PREVIEW_PORT/"
echo
echo "Exact candidate: $TARGET_SHA"
echo "Production remains unchanged. All preview writes go to the disposable clone."
echo
echo "Review:"
echo "  1. Display Setup is a separate classification and color."
echo "  2. Material editor shows explicit Stage / Preview / Scene-group sources."
echo "  3. A task with no selected source shows no Display material."
echo "  4. Stage 01 task shows five selected LOR groups and resolves 7 Displays."
echo "  5. Stage 16 task uses exact Northern Lights Scene 298 and resolves 66 Displays; the shared Master Musical Preview remains a whole-Preview source."
echo "  6. Christmas Story resolves 8 Displays and Containers 6,131,150,171."
echo "  7. Add one preview-only task and confirm creation opens the full editor."
echo
read -r -p "Press ENTER to stop and clean up the Setup material preview... " _unused

echo "Operator ended browser review. Cleaning up."
