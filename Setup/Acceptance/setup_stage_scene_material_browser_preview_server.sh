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
TEST_CONTAINER="msb-setup-stage-scene-preview-${$}"
TEST_DB="msb_setup_stage_scene_browser_preview"
TEST_PASSWORD="setup-stage-scene-preview-${$}-$(date +%s)"
APP_PASSWORD="setupstagepreview${$}$(date +%s)"
DUMP_FILE="/tmp/msb-setup-stage-scene-preview-${STAMP}-${$}.dump"
GRANTS_FILE="/tmp/msb-setup-stage-scene-preview-grants-${STAMP}-${$}.sql"
CANDIDATE_WORKTREE="/tmp/msb-setup-stage-scene-preview-candidate-${STAMP}"
REPORT_DIR="$HOME/setup-acceptance-reports"
REPORT="$REPORT_DIR/Setup_Stage_Scene_Browser_Preview_${STAMP}.txt"
PREVIEW_LOG="/tmp/Setup_Stage_Scene_Browser_Preview_Flask_${STAMP}.log"
PREVIEW_ENTRY=""
PREVIEW_PGID=""
PROD_BEFORE=""
SETUP_HEAD_BEFORE=""
PREVIEW_OWNED_PORT=0

mkdir -p "$REPORT_DIR"
exec > >(tee "$REPORT") 2>&1

echo "========== SETUP STAGE/SCENE BROWSER PREVIEW =========="
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
    echo "--- Browser preview cleanup ---"
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
    rm -rf "$SCRIPT_DIR" >/dev/null 2>&1 || true

    echo "--- Production after-check ---"
    if [[ -n "$PROD_BEFORE" ]]; then
        PROD_AFTER="$(prod_fingerprint 2>/dev/null)"
        echo "Production Setup fingerprint before: $PROD_BEFORE"
        echo "Production Setup fingerprint after:  $PROD_AFTER"
        if [[ -z "$PROD_AFTER" || "$PROD_AFTER" != "$PROD_BEFORE" ]]; then
            echo "FAIL: Production Setup fingerprint changed during browser preview"
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
            echo "FAIL: live /opt/msb-setup checkout changed during browser preview"
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
if ss -ltnH "sport = :$PREVIEW_PORT" | grep -q .; then
    echo "FAIL: preview port $PREVIEW_PORT is already listening on msb-prod-db"
    exit 4
fi
if ! sudo docker inspect "$PROD_CONTAINER" >/dev/null 2>&1; then
    echo "FAIL: Production PostgreSQL container was not found"
    exit 5
fi
if [[ "$(sudo docker inspect "$PROD_CONTAINER" --format '{{.Config.Image}}')" != "$IMAGE" ]]; then
    echo "FAIL: Production PostgreSQL image is not $IMAGE"
    exit 6
fi
if ! sudo docker network inspect "$NETWORK" >/dev/null 2>&1; then
    echo "FAIL: Docker network $NETWORK was not found"
    exit 7
fi
if ! systemctl is-active --quiet msb-setup.service; then
    echo "FAIL: Production Setup service is not active"
    exit 8
fi
if ! sudo -u fieldwiring -H test -x /opt/fieldwiring/.venv/bin/python; then
    echo "FAIL: documented shared Python runtime is unavailable to fieldwiring"
    exit 9
fi

SETUP_HEAD_BEFORE="$(sudo git -C "$SETUP_LIVE_ROOT" rev-parse HEAD)"
if [[ -n "$(sudo git -C "$SETUP_LIVE_ROOT" status --porcelain)" ]]; then
    echo "FAIL: live Setup checkout has uncommitted changes"
    exit 10
fi
if [[ -n "$(sudo git -C "$REPO_ROOT" status --porcelain)" ]]; then
    echo "FAIL: shared repository checkout has uncommitted changes"
    exit 11
fi
PROD_BEFORE="$(prod_fingerprint)"
if [[ -z "$PROD_BEFORE" ]]; then
    echo "FAIL: Production Setup fingerprint was empty"
    exit 12
fi

echo "Live Setup SHA: $SETUP_HEAD_BEFORE"
echo "Production Setup fingerprint before: $PROD_BEFORE"

echo
echo "--- Fetch exact candidate and prove forward ancestry ---"
sudo git -C "$REPO_ROOT" fetch origin "$TARGET_REF"
sudo git -C "$REPO_ROOT" cat-file -e "$TARGET_SHA^{commit}"
if ! sudo git -C "$REPO_ROOT" merge-base --is-ancestor "$SETUP_HEAD_BEFORE" "$TARGET_SHA"; then
    echo "FAIL: candidate is not a forward descendant of live Setup"
    exit 13
fi
sudo git -C "$REPO_ROOT" worktree add --detach "$CANDIDATE_WORKTREE" "$TARGET_SHA"

M025="$CANDIDATE_WORKTREE/Setup/Database/025_add_setup_display_material_requirement.sql"
VALIDATION="$CANDIDATE_WORKTREE/Setup/Acceptance/setup_stage_scene_material_disposable_validation.sql"
PREVIEW_ENTRY="$CANDIDATE_WORKTREE/Setup/Acceptance/setup_session_browser_preview_entry.py"
for file in "$M025" "$VALIDATION" "$PREVIEW_ENTRY"; do
    if [[ ! -s "$file" ]]; then
        echo "FAIL: exact candidate is missing required browser-preview file: $file"
        exit 14
    fi
done

if find "$CANDIDATE_WORKTREE/Setup/Application" -maxdepth 2 -type f -print0 \
    | xargs -0 grep -l "Choose current LOR material source" 2>/dev/null \
    | grep -q .; then
    echo "FAIL: rejected manual material-source selector is present in application source"
    exit 15
fi

echo
echo "--- Exact candidate regression ---"
PYCACHE="/tmp/msb-setup-stage-scene-preview-pycache-$STAMP"
sudo -u fieldwiring -H env PYTHONPYCACHEPREFIX="$PYCACHE" bash -c "
    cd '$CANDIDATE_WORKTREE'
    /opt/fieldwiring/.venv/bin/python -m py_compile \
        Setup/Application/setup_material_api.py \
        Setup/Application/setup_material_resolution.py \
        Setup/Application/production_backend.py \
        Setup/Acceptance/setup_session_browser_preview_entry.py
    /opt/fieldwiring/.venv/bin/python -m pytest -q -p no:cacheprovider Setup/Application
"
rm -rf "$PYCACHE" >/dev/null 2>&1 || true
echo "PASS: exact candidate Setup/Application regression"

echo
echo "--- Capture current Production into disposable clone ---"
sudo docker exec "$PROD_CONTAINER" pg_dump -U "$DB_ACTOR" -d "$PROD_DB" -Fc > "$DUMP_FILE"
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
    sudo docker logs "$TEST_CONTAINER" || true
    exit 16
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

echo
echo "--- Recreate Production-equivalent application role boundary ---"
psql_test -c "CREATE ROLE fieldwiring_app LOGIN PASSWORD '$APP_PASSWORD';"
sudo docker exec "$PROD_CONTAINER" psql -X -qAt -v ON_ERROR_STOP=1 -U "$DB_ACTOR" -d "$PROD_DB" -c "
    SELECT format('GRANT USAGE ON SCHEMA %I TO fieldwiring_app;', n.nspname)
    FROM pg_namespace n
    WHERE n.nspname IN ('ref','lor_snap','ops','public')
      AND has_schema_privilege('fieldwiring_app', n.oid, 'USAGE')
    UNION ALL
    SELECT format('GRANT SELECT ON TABLE %I.%I TO fieldwiring_app;', n.nspname, c.relname)
    FROM pg_class c
    JOIN pg_namespace n ON n.oid = c.relnamespace
    WHERE n.nspname IN ('ref','lor_snap','ops','public')
      AND c.relkind IN ('r','v','m','f','p')
      AND has_table_privilege('fieldwiring_app', c.oid, 'SELECT')
    UNION ALL
    SELECT format('GRANT EXECUTE ON FUNCTION %I.%I(%s) TO fieldwiring_app;', n.nspname, p.proname, pg_get_function_identity_arguments(p.oid))
    FROM pg_proc p
    JOIN pg_namespace n ON n.oid = p.pronamespace
    WHERE n.nspname IN ('ref','ops')
      AND p.prokind IN ('f','w')
      AND has_function_privilege('fieldwiring_app', p.oid, 'EXECUTE');
" > "$GRANTS_FILE"
test -s "$GRANTS_FILE"
psql_test < "$GRANTS_FILE"

echo
echo "--- Apply candidate migration and five-Stage validation to disposable clone ---"
psql_test < "$M025"
psql_test < "$VALIDATION"

MANAGE_OK="$(psql_test -qAt -c "SELECT can_manage_setup FROM ref.setup_browser_capabilities('$PREVIEW_EMAIL');")"
if [[ "$MANAGE_OK" != "t" ]]; then
    echo "FAIL: preview operator $PREVIEW_EMAIL lacks Setup Manager capability"
    exit 17
fi

TEST_IP="$(sudo docker inspect "$TEST_CONTAINER" --format '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}')"
if [[ -z "$TEST_IP" ]]; then
    echo "FAIL: could not resolve disposable PostgreSQL container IP"
    exit 18
fi
DSN="host=$TEST_IP port=5432 dbname=$TEST_DB user=fieldwiring_app password=$APP_PASSWORD"
APP_DIR="$CANDIDATE_WORKTREE/Setup/Application"

echo
echo "--- Start exact candidate on temporary preview port ---"
PREVIEW_PGID="$(sudo -u fieldwiring -H env \
    SETUP_DATABASE_DSN="$DSN" \
    FIELDWIRING_DATABASE_DSN="$DSN" \
    PROCEDURE_DATABASE_DSN="$DSN" \
    MSB_SETUP_PREVIEW_APP_DIR="$APP_DIR" \
    MSB_SETUP_PREVIEW_OPERATOR_EMAIL="$PREVIEW_EMAIL" \
    MSB_SETUP_PREVIEW_HOST="127.0.0.1" \
    MSB_SETUP_PREVIEW_PORT="$PREVIEW_PORT" \
    MSB_SETUP_PREVIEW_ENTRY="$PREVIEW_ENTRY" \
    MSB_SETUP_PREVIEW_LOG="$PREVIEW_LOG" \
    bash -c '
        cd /tmp
        setsid /opt/fieldwiring/.venv/bin/python "$MSB_SETUP_PREVIEW_ENTRY" > "$MSB_SETUP_PREVIEW_LOG" 2>&1 &
        echo $!
    ')"
if [[ ! "$PREVIEW_PGID" =~ ^[0-9]+$ ]]; then
    echo "FAIL: preview process did not return a PID"
    exit 19
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
    echo "FAIL: preview did not become healthy"
    tail -n 120 "$PREVIEW_LOG" || true
    exit 20
fi

HEALTH="$(curl -fsS "http://127.0.0.1:$PREVIEW_PORT/api/health")"
echo "Preview health: $HEALTH"
ACCESS="$(curl -fsS "http://127.0.0.1:$PREVIEW_PORT/api/setup/access")"
echo "Preview authorization: PASS"

cat <<CHECKLIST

SETUP STAGE/SCENE BROWSER REVIEW READY
Browser URL through SSH tunnel: http://127.0.0.1:$PREVIEW_PORT/

Review these exact behaviors in the temporary preview:
  1. Reusable Task editor shows one "Uses Display / Container Material" checkbox.
  2. No LOR Stage/Preview/Scene material-source chooser is present.
  3. Check a Stage-level Display setup task: material resolves automatically from LOR and shows Display/Container counts.
  4. Check a real Scene task: material resolves to that exact Scene, not sibling/Stage material.
  5. Material-bearing tasks receive the visual material highlight.
  6. Plan / Schedule defaults to View order = Stage and groups tasks under Stage headings.
  7. Stage view says planned order is unchanged and does not expose reorder controls.
  8. Switch Plan / Schedule to Planned order: existing planning order and reorder controls return.
  9. The scheduling task selector follows the selected Stage/Planned view order.
 10. Perform Work defaults to View order = Stage and groups tasks under Stage headings.
 11. Switch Perform Work to Planned order and confirm the original planning sequence remains available.
 12. Existing 2025 review/catalog/resource/procedure behavior still works.

All checkbox/save actions in this preview write only to the disposable clone.
Production Setup remains untouched.

Press ENTER in this SSH window when browser review is complete.
CHECKLIST

read -r _done

echo
echo "Browser review session ended by operator. Cleanup will now run."
echo "SETUP_STAGE_SCENE_BROWSER_PREVIEW_CLEAN_EXIT"
