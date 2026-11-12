#!/usr/bin/env bash
set -euo pipefail

CANDIDATE_SHA="${1:?candidate SHA required}"
PREVIEW_PORT="${2:?preview port required}"
PREVIEW_EMAIL="${3:?preview email required}"
APPROVED_REF="${4:?approved Git ref required}"

PROD_CONTAINER="msb-postgres"
PROD_DB="msb"
DB_ACTOR="msbadmin"
IMAGE="postgis/postgis:16-3.5"
NETWORK="msb-stack_default"
REPO_ROOT="/opt/fieldwiring"
LIVE_SETUP_ROOT="/opt/msb-setup"
PYTHON="/opt/fieldwiring/.venv/bin/python"
STAMP="$(date +%Y%m%dT%H%M%S)"
TEST_CONTAINER="msb-setup-source-preview-${$}"
TEST_DB="msb_setup_source_preview"
TEST_PASSWORD="setup-preview-${$}-$(date +%s)"
APP_PASSWORD="setupapp-${$}-$(date +%s)"
CANDIDATE_WORKTREE="/tmp/msb-setup-source-preview-candidate-$STAMP"
DUMP_FILE="/tmp/msb-setup-source-preview-$STAMP.dump"
REPORT="/tmp/MSB_Setup_Source_Only_Preview_$STAMP.txt"
PREVIEW_LOG="/tmp/MSB_Setup_Source_Only_Preview_Flask_$STAMP.log"
ENTRY_SCRIPT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/setup_session_browser_preview_entry.py"
PREVIEW_PGID=""
PROD_BEFORE=""
LIVE_HEAD=""

exec > >(tee "$REPORT") 2>&1

echo "========== SETUP SOURCE-ONLY BROWSER PREVIEW =========="
echo "Candidate SHA: $CANDIDATE_SHA"
echo "Approved ref:  $APPROVED_REF"
echo "Preview port:  $PREVIEW_PORT"
echo "Preview user:  $PREVIEW_EMAIL"
echo "Production DB: pg_dump + SELECT only"
echo "Preview writes: disposable current-production clone only"
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

cleanup() {
    status=$?
    trap - EXIT INT TERM
    set +e

    echo
    echo "--- Preview cleanup ---"
    if [[ -n "$PREVIEW_PGID" ]]; then
        kill -- -"$PREVIEW_PGID" >/dev/null 2>&1 || true
        sleep 1
        kill -KILL -- -"$PREVIEW_PGID" >/dev/null 2>&1 || true
    fi
    sudo docker rm -f "$TEST_CONTAINER" >/dev/null 2>&1 || true
    if sudo git -C "$REPO_ROOT" worktree list --porcelain 2>/dev/null | grep -Fq "worktree $CANDIDATE_WORKTREE"; then
        sudo git -C "$REPO_ROOT" worktree remove --force "$CANDIDATE_WORKTREE" >/dev/null 2>&1 || true
    fi
    rm -f "$DUMP_FILE" >/dev/null 2>&1 || true

    echo
    echo "--- Production after-check ---"
    if [[ -n "$PROD_BEFORE" ]]; then
        PROD_AFTER="$(prod_fingerprint 2>/dev/null)"
        echo "Fingerprint before: $PROD_BEFORE"
        echo "Fingerprint after:  $PROD_AFTER"
        if [[ "$PROD_AFTER" != "$PROD_BEFORE" ]]; then
            echo "FAIL: Production Setup fingerprint changed during preview"
            status=97
        else
            echo "PASS: Production Setup fingerprint unchanged"
        fi
    fi
    if [[ -n "$LIVE_HEAD" ]]; then
        HEAD_AFTER="$(sudo git -C "$LIVE_SETUP_ROOT" rev-parse HEAD 2>/dev/null)"
        echo "Live Setup before: $LIVE_HEAD"
        echo "Live Setup after:  $HEAD_AFTER"
        if [[ "$HEAD_AFTER" != "$LIVE_HEAD" ]]; then
            echo "FAIL: live Setup checkout changed during preview"
            status=98
        else
            echo "PASS: live Setup checkout unchanged"
        fi
    fi
    echo "Preview log:    $PREVIEW_LOG"
    echo "Preview report: $REPORT"
    exit "$status"
}
trap cleanup EXIT INT TERM

sudo -v

if [[ ! "$PREVIEW_PORT" =~ ^[0-9]+$ ]] || (( PREVIEW_PORT < 1024 || PREVIEW_PORT > 65535 )); then
    echo "FAIL: preview port must be 1024-65535"
    exit 2
fi
if [[ "$PREVIEW_PORT" == "8790" || "$PREVIEW_PORT" == "8792" || "$PREVIEW_PORT" == "8794" || "$PREVIEW_PORT" == "8055" ]]; then
    echo "FAIL: preview port conflicts with a Production listener"
    exit 3
fi
if [[ ! "$PREVIEW_EMAIL" =~ ^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+$ ]]; then
    echo "FAIL: preview email is invalid"
    exit 4
fi
if [[ -z "$APPROVED_REF" ]]; then
    echo "FAIL: approved Git ref is required"
    exit 5
fi
if [[ ! -s "$ENTRY_SCRIPT" ]]; then
    echo "FAIL: preview entry script is missing: $ENTRY_SCRIPT"
    exit 5
fi
if ss -ltnH "sport = :$PREVIEW_PORT" | grep -q .; then
    echo "FAIL: preview port $PREVIEW_PORT is already listening"
    exit 6
fi

for service in msb-setup.service fieldwiring.service msb-procedures.service msb-display-folders.service msb-setup-google-links.service; do
    if ! systemctl is-active --quiet "$service"; then
        echo "FAIL: required Production service is not active: $service"
        exit 7
    fi
done

LIVE_HEAD="$(sudo git -C "$LIVE_SETUP_ROOT" rev-parse HEAD)"
if [[ -n "$(sudo git -C "$LIVE_SETUP_ROOT" status --porcelain)" ]]; then
    echo "FAIL: live Setup worktree has uncommitted changes"
    sudo git -C "$LIVE_SETUP_ROOT" status -sb
    exit 8
fi
printf 'Live Setup SHA: %s\n' "$LIVE_HEAD"

PROD_BEFORE="$(prod_fingerprint)"
echo "Production Setup fingerprint: $PROD_BEFORE"

echo
echo "--- Fetch exact candidate and run detached regression ---"
sudo git -C "$REPO_ROOT" fetch origin "$APPROVED_REF"
sudo git -C "$REPO_ROOT" cat-file -e "$CANDIDATE_SHA^{commit}"
if ! sudo git -C "$REPO_ROOT" merge-base --is-ancestor "$LIVE_HEAD" "$CANDIDATE_SHA"; then
    echo "FAIL: candidate is not a forward descendant of live Setup"
    exit 9
fi
sudo git -C "$REPO_ROOT" worktree add --detach "$CANDIDATE_WORKTREE" "$CANDIDATE_SHA"

sudo -u fieldwiring -H bash -c "
    cd /tmp
    cd '$CANDIDATE_WORKTREE'
    '$PYTHON' -m pytest -q -p no:cacheprovider Setup/Application/test_setup_*contract.py
"
echo "Exact detached Setup candidate regression: PASS"

echo
echo "--- Capture current Production into disposable clone ---"
sudo docker exec "$PROD_CONTAINER" pg_dump -U "$DB_ACTOR" -d "$PROD_DB" -Fc > "$DUMP_FILE"
test -s "$DUMP_FILE"
sudo docker exec -i "$PROD_CONTAINER" pg_restore --list < "$DUMP_FILE" >/dev/null
echo "Production dump captured and validated"

sudo docker run -d \
    --name "$TEST_CONTAINER" \
    --network "$NETWORK" \
    -e POSTGRES_USER="$DB_ACTOR" \
    -e POSTGRES_PASSWORD="$TEST_PASSWORD" \
    -e POSTGRES_DB=postgres \
    "$IMAGE" >/dev/null

ready=0
for _ in $(seq 1 120); do
    if sudo docker exec -e PGPASSWORD="$TEST_PASSWORD" "$TEST_CONTAINER" \
        pg_isready -U "$DB_ACTOR" -d postgres >/dev/null 2>&1; then
        ready=1
        break
    fi
    sleep 1
done
if [[ "$ready" -ne 1 ]]; then
    echo "FAIL: disposable PostgreSQL did not become ready"
    exit 10
fi

sudo docker exec -e PGPASSWORD="$TEST_PASSWORD" "$TEST_CONTAINER" \
    createdb -U "$DB_ACTOR" -T template0 "$TEST_DB"
sudo docker exec -i -e PGPASSWORD="$TEST_PASSWORD" "$TEST_CONTAINER" \
    pg_restore -U "$DB_ACTOR" -d "$TEST_DB" --no-owner --no-acl --exit-on-error < "$DUMP_FILE"
echo "Disposable current-Production clone restored"

psql_test() {
    sudo docker exec -i -e PGPASSWORD="$TEST_PASSWORD" "$TEST_CONTAINER" \
        psql -X -v ON_ERROR_STOP=1 -U "$DB_ACTOR" -d "$TEST_DB" "$@"
}

psql_test <<SQL
CREATE ROLE fieldwiring_app LOGIN PASSWORD '$APP_PASSWORD';
ALTER ROLE fieldwiring_app SET default_transaction_read_only = on;
GRANT USAGE ON SCHEMA ref, ops, lor_snap TO fieldwiring_app;
GRANT SELECT ON ALL TABLES IN SCHEMA ref, ops, lor_snap TO fieldwiring_app;

REVOKE ALL ON FUNCTION ref.setup_browser_capabilities(text) FROM PUBLIC;
REVOKE ALL ON FUNCTION ref.setup_management_actor(text,boolean) FROM PUBLIC;
REVOKE ALL ON FUNCTION ops.create_setup_session(text,integer,text) FROM PUBLIC;
REVOKE ALL ON FUNCTION ref.create_setup_task(text,text,integer,text,integer,integer,integer,integer,text,text,text,text) FROM PUBLIC;
REVOKE ALL ON FUNCTION ref.update_setup_task(text,bigint,text,integer,text,integer,boolean,integer,integer,integer,text,text,text,text) FROM PUBLIC;
REVOKE ALL ON FUNCTION ops.update_setup_session_task_review(text,bigint,text,timestamp with time zone,timestamp with time zone,integer,integer,text) FROM PUBLIC;
REVOKE ALL ON FUNCTION ref.create_setup_resource(text,text,text,text) FROM PUBLIC;
REVOKE ALL ON FUNCTION ref.set_setup_task_resource(text,bigint,integer,integer,text,text,boolean) FROM PUBLIC;
REVOKE ALL ON FUNCTION ref.set_setup_task_scope(text,bigint,integer,bigint) FROM PUBLIC;
REVOKE ALL ON FUNCTION ref.set_setup_task_dependency(text,bigint,bigint,text,boolean) FROM PUBLIC;
REVOKE ALL ON FUNCTION ops.upsert_setup_work_day(text,integer,date,text,text) FROM PUBLIC;
REVOKE ALL ON FUNCTION ops.set_setup_work_day_task(text,bigint,bigint,text,text,integer,integer,boolean) FROM PUBLIC;
REVOKE ALL ON FUNCTION ops.record_setup_task_progress(text,bigint,bigint,text,integer,integer,text,text,boolean) FROM PUBLIC;
REVOKE ALL ON FUNCTION ops.set_setup_session_task_planned_order(text,bigint,integer,text) FROM PUBLIC;
REVOKE ALL ON FUNCTION ops.promote_setup_session_order_to_baseline(text,integer) FROM PUBLIC;
REVOKE ALL ON FUNCTION ref.delete_setup_reconstruction_task(text,bigint) FROM PUBLIC;
REVOKE ALL ON FUNCTION ref.setup_task_captain_list(bigint) FROM PUBLIC;
REVOKE ALL ON FUNCTION ref.setup_captain_person_list() FROM PUBLIC;
REVOKE ALL ON FUNCTION ref.set_setup_task_captain(text,bigint,integer,text,integer,text,boolean) FROM PUBLIC;
REVOKE ALL ON FUNCTION ref.set_setup_task_effort(text,bigint,text) FROM PUBLIC;
REVOKE ALL ON FUNCTION ref.set_setup_task_display_material_requirement(text,bigint,boolean) FROM PUBLIC;

GRANT EXECUTE ON FUNCTION ref.setup_browser_capabilities(text) TO fieldwiring_app;
GRANT EXECUTE ON FUNCTION ops.create_setup_session(text,integer,text) TO fieldwiring_app;
GRANT EXECUTE ON FUNCTION ref.create_setup_task(text,text,integer,text,integer,integer,integer,integer,text,text,text,text) TO fieldwiring_app;
GRANT EXECUTE ON FUNCTION ref.update_setup_task(text,bigint,text,integer,text,integer,boolean,integer,integer,integer,text,text,text,text) TO fieldwiring_app;
GRANT EXECUTE ON FUNCTION ops.update_setup_session_task_review(text,bigint,text,timestamp with time zone,timestamp with time zone,integer,integer,text) TO fieldwiring_app;
GRANT EXECUTE ON FUNCTION ref.create_setup_resource(text,text,text,text) TO fieldwiring_app;
GRANT EXECUTE ON FUNCTION ref.set_setup_task_resource(text,bigint,integer,integer,text,text,boolean) TO fieldwiring_app;
GRANT EXECUTE ON FUNCTION ref.set_setup_task_scope(text,bigint,integer,bigint) TO fieldwiring_app;
GRANT EXECUTE ON FUNCTION ref.set_setup_task_dependency(text,bigint,bigint,text,boolean) TO fieldwiring_app;
GRANT EXECUTE ON FUNCTION ops.upsert_setup_work_day(text,integer,date,text,text) TO fieldwiring_app;
GRANT EXECUTE ON FUNCTION ops.set_setup_work_day_task(text,bigint,bigint,text,text,integer,integer,boolean) TO fieldwiring_app;
GRANT EXECUTE ON FUNCTION ops.record_setup_task_progress(text,bigint,bigint,text,integer,integer,text,text,boolean) TO fieldwiring_app;
GRANT EXECUTE ON FUNCTION ops.set_setup_session_task_planned_order(text,bigint,integer,text) TO fieldwiring_app;
GRANT EXECUTE ON FUNCTION ops.promote_setup_session_order_to_baseline(text,integer) TO fieldwiring_app;
GRANT EXECUTE ON FUNCTION ref.delete_setup_reconstruction_task(text,bigint) TO fieldwiring_app;
GRANT EXECUTE ON FUNCTION ref.setup_task_captain_list(bigint) TO fieldwiring_app;
GRANT EXECUTE ON FUNCTION ref.setup_captain_person_list() TO fieldwiring_app;
GRANT EXECUTE ON FUNCTION ref.set_setup_task_captain(text,bigint,integer,text,integer,text,boolean) TO fieldwiring_app;
GRANT EXECUTE ON FUNCTION ref.set_setup_task_effort(text,bigint,text) TO fieldwiring_app;
GRANT EXECUTE ON FUNCTION ref.set_setup_task_display_material_requirement(text,bigint,boolean) TO fieldwiring_app;
SQL

TEST_IP="$(sudo docker inspect "$TEST_CONTAINER" --format '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}')"
if [[ -z "$TEST_IP" ]]; then
    echo "FAIL: disposable PostgreSQL IP could not be resolved"
    exit 11
fi
DSN="host=$TEST_IP port=5432 dbname=$TEST_DB user=fieldwiring_app password=$APP_PASSWORD"

READONLY_DEFAULT="$(sudo docker exec -e PGPASSWORD="$APP_PASSWORD" "$TEST_CONTAINER" \
    psql -X -qAt -U fieldwiring_app -d "$TEST_DB" -c 'SHOW default_transaction_read_only;')"
if [[ "$READONLY_DEFAULT" != "on" ]]; then
    echo "FAIL: preview fieldwiring_app does not reproduce Production default_transaction_read_only=on"
    exit 12
fi
echo "Preview role default_transaction_read_only=on: PASS"

psql_test <<'SQL'
DO $block$
BEGIN
    IF has_table_privilege('fieldwiring_app', 'ref.setup_task', 'INSERT')
       OR has_table_privilege('fieldwiring_app', 'ref.setup_task', 'UPDATE')
       OR has_table_privilege('fieldwiring_app', 'ops.setup_session_task', 'UPDATE') THEN
        RAISE EXCEPTION 'Preview fieldwiring_app unexpectedly has broad Setup DML';
    END IF;
END
$block$;
SQL
echo "Preview least-privilege table boundary: PASS"

echo
echo "--- Start exact candidate against disposable clone ---"
PREVIEW_PGID="$(
    sudo -u fieldwiring -H env \
        SETUP_DATABASE_DSN="$DSN" \
        SETUP_DRIVE_ROOT="/mnt/msb-display-folders" \
        SETUP_GOOGLE_DOC_LINK_ROOT="/mnt/msb-setup-google-links" \
        MSB_SETUP_PREVIEW_APP_DIR="$CANDIDATE_WORKTREE/Setup/Application" \
        MSB_SETUP_PREVIEW_OPERATOR_EMAIL="$PREVIEW_EMAIL" \
        MSB_SETUP_PREVIEW_HOST="127.0.0.1" \
        MSB_SETUP_PREVIEW_PORT="$PREVIEW_PORT" \
        PREVIEW_ENTRY="$ENTRY_SCRIPT" \
        PREVIEW_LOG="$PREVIEW_LOG" \
        bash -c '
            cd /tmp
            setsid "$PYTHON" "$PREVIEW_ENTRY" > "$PREVIEW_LOG" 2>&1 &
            echo $!
        '
)"
if [[ ! "$PREVIEW_PGID" =~ ^[0-9]+$ ]]; then
    echo "FAIL: preview process did not return a valid process-group ID"
    exit 13
fi

app_ready=0
for _ in $(seq 1 60); do
    if curl -fsS "http://127.0.0.1:$PREVIEW_PORT/api/health" >/dev/null 2>&1; then
        app_ready=1
        break
    fi
    sleep 0.5
done
if [[ "$app_ready" -ne 1 ]]; then
    echo "FAIL: Setup preview did not become healthy"
    tail -n 100 "$PREVIEW_LOG" || true
    exit 14
fi

echo
echo "--- Exact API write probe under Production-like read-only role ---"
CREATE_RESPONSE="$(curl -fsS -X POST \
    -H 'Content-Type: application/json' \
    -H 'X-MSB-Setup-Command: 1' \
    --data '{"task_name":"[PREVIEW ONLY] Setup write transaction probe","stage_id":null,"task_action_type":"WORK","display_order":99999}' \
    "http://127.0.0.1:$PREVIEW_PORT/api/setup/tasks")"
PROBE_TASK_ID="$(printf '%s' "$CREATE_RESPONSE" | "$PYTHON" -c 'import json,sys; print(json.load(sys.stdin)["setup_task"]["setup_task_id"])')"
if [[ ! "$PROBE_TASK_ID" =~ ^[0-9]+$ ]]; then
    echo "FAIL: Setup create-task API write probe returned no task ID"
    exit 15
fi

TASKS_JSON="$(curl -fsS "http://127.0.0.1:$PREVIEW_PORT/api/setup/tasks?season_year=2025")"
PROBE_SESSION_TASK_ID="$(printf '%s' "$TASKS_JSON" | "$PYTHON" -c 'import json,sys; d=json.load(sys.stdin); rows=[r for r in d["tasks"] if r.get("task_name")=="[PREVIEW ONLY] Setup write transaction probe"]; print(rows[0].get("setup_session_task_id") or "")')"
if [[ ! "$PROBE_SESSION_TASK_ID" =~ ^[0-9]+$ ]]; then
    echo "FAIL: preview task was not seeded into the open 2025 Setup Session"
    exit 16
fi

curl -fsS -X PATCH \
    -H 'Content-Type: application/json' \
    -H 'X-MSB-Setup-Command: 1' \
    --data '{"verification_state":"NEEDS_CORRECTION","annual_notes":"[PREVIEW ONLY] Production-like write transaction probe."}' \
    "http://127.0.0.1:$PREVIEW_PORT/api/setup/session-tasks/$PROBE_SESSION_TASK_ID/review" >/dev/null

echo "Create reusable task + update 2025 annual review through exact API: PASS"

echo
echo "SETUP SOURCE-ONLY BROWSER REVIEW READY"
echo "Open in your browser through the SSH tunnel: http://127.0.0.1:$PREVIEW_PORT/"
echo "Candidate SHA: $CANDIDATE_SHA"
echo "Approved ref: $APPROVED_REF"
echo "Preview identity: $PREVIEW_EMAIL"
echo "The row named '[PREVIEW ONLY] Setup write transaction probe' exists only in the disposable clone."
echo "Exercise real Manager workflows here. Production remains unchanged."
echo
read -r -p "When browser review is finished, press ENTER here to clean up the preview. " _
