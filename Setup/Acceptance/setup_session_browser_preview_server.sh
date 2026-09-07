#!/usr/bin/env bash
set -euo pipefail

PROD_CONTAINER="msb-postgres"
PROD_DB="msb"
DB_ACTOR="msbadmin"
IMAGE="postgis/postgis:16-3.5"
NETWORK="msb-stack_default"
FIELDWIRING_ROOT="/opt/fieldwiring"
TARGET_REF="agent/setup-session-production-foundation"
TARGET_SHA="874a1f7d090676b97de1881df973fab08985085a"
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
PREVIEW_ENTRY="$SCRIPT_DIR/setup_session_browser_preview_entry.py"
PREVIEW_PORT="${1:-8794}"
PREVIEW_EMAIL="${2:-gliebig@sheboyganlights.org}"
STAMP="$(date +%Y%m%dT%H%M%S)"
TEST_CONTAINER="msb-setup-browser-preview-${$}"
TEST_DB="msb_setup_browser_preview"
TEST_PASSWORD="setup-preview-${$}-$(date +%s)"
APP_PASSWORD="setuppreview$(date +%s)${$}"
DUMP_FILE="$SCRIPT_DIR/production.dump"
CANDIDATE_WORKTREE="/tmp/msb-setup-browser-preview-candidate-$STAMP"
REPORT="/tmp/MSB_Setup_Session_Browser_Preview_$STAMP.txt"
PREVIEW_LOG="/tmp/MSB_Setup_Session_Browser_Preview_Flask_$STAMP.log"
GOOGLE_DOC_INDEX="/tmp/MSB_Setup_Google_Doc_Index_$STAMP.json"
RCLONE_CONFIG="/var/lib/msb-docs-fs/.config/rclone/rclone.conf"
PREVIEW_PGID=""
PROD_BEFORE=""
LIVE_HEAD=""

exec > >(tee "$REPORT") 2>&1

echo "========== SETUP SESSION BROWSER PREVIEW =========="
echo "Report:         $REPORT"
echo "Candidate SHA:  $TARGET_SHA"
echo "Preview port:   $PREVIEW_PORT"
echo "Preview user:   $PREVIEW_EMAIL"
echo "Production DB:  pg_dump + SELECT only"
echo "Preview writes: disposable PostgreSQL clone only"
echo

prod_fingerprint() {
    sudo docker exec "$PROD_CONTAINER" \
        psql -X -qAt -v ON_ERROR_STOP=1 -U "$DB_ACTOR" -d "$PROD_DB" -c "
            SELECT md5(
                coalesce((
                    SELECT string_agg(row_to_json(t)::text, '' ORDER BY t.setup_task_id)
                    FROM ref.setup_task t
                ), '') || '|' ||
                coalesce((
                    SELECT string_agg(row_to_json(r)::text, '' ORDER BY r.setup_resource_id)
                    FROM ref.setup_resource r
                ), '') || '|' ||
                coalesce((
                    SELECT string_agg(row_to_json(tr)::text, '' ORDER BY tr.setup_task_id, tr.setup_resource_id)
                    FROM ref.setup_task_resource tr
                ), '') || '|' ||
                coalesce((
                    SELECT string_agg(row_to_json(s)::text, '' ORDER BY s.setup_session_id)
                    FROM ops.setup_session s
                ), '') || '|' ||
                coalesce((
                    SELECT string_agg(row_to_json(st)::text, '' ORDER BY st.setup_session_task_id)
                    FROM ops.setup_session_task st
                ), '') || '|' ||
                coalesce((
                    SELECT string_agg(row_to_json(ds)::text, '' ORDER BY ds.setup_session_id, ds.display_id)
                    FROM ops.setup_display_state ds
                ), '') || '|' ||
                coalesce((
                    SELECT string_agg(row_to_json(cs)::text, '' ORDER BY cs.setup_session_id, cs.container_id)
                    FROM ops.setup_container_state cs
                ), '') || '|' ||
                coalesce((
                    SELECT string_agg(row_to_json(me)::text, '' ORDER BY me.setup_movement_event_id)
                    FROM ops.setup_movement_event me
                ), '')
            );
        "
}

cleanup() {
    status=$?
    trap - EXIT INT TERM
    set +e

    echo
    echo "--- Setup browser preview cleanup ---"
    if [[ -n "$PREVIEW_PGID" ]]; then
        kill -- -"$PREVIEW_PGID" >/dev/null 2>&1 || true
        sleep 1
        kill -KILL -- -"$PREVIEW_PGID" >/dev/null 2>&1 || true
    fi

    sudo docker rm -f "$TEST_CONTAINER" >/dev/null 2>&1 || true

    if sudo git -C "$FIELDWIRING_ROOT" worktree list --porcelain 2>/dev/null | grep -Fq "worktree $CANDIDATE_WORKTREE"; then
        sudo git -C "$FIELDWIRING_ROOT" worktree remove --force "$CANDIDATE_WORKTREE" >/dev/null 2>&1 || true
    fi

    rm -f "$DUMP_FILE" "$GOOGLE_DOC_INDEX" >/dev/null 2>&1 || true
    rm -rf "$SCRIPT_DIR" >/dev/null 2>&1 || true

    echo
    echo "--- Production Setup fingerprint after-check ---"
    if [[ -n "$PROD_BEFORE" ]]; then
        PROD_AFTER="$(prod_fingerprint 2>/dev/null)"
        echo "Before: $PROD_BEFORE"
        echo "After:  $PROD_AFTER"
        if [[ "$PROD_AFTER" != "$PROD_BEFORE" ]]; then
            echo "FAIL: Production Setup fingerprint changed during browser preview"
            status=97
        else
            echo "PASS: Production Setup fingerprint unchanged"
        fi
    fi

    if [[ -n "$LIVE_HEAD" ]]; then
        HEAD_AFTER="$(sudo git -C "$FIELDWIRING_ROOT" rev-parse HEAD 2>/dev/null)"
        echo "Live checkout before: $LIVE_HEAD"
        echo "Live checkout after:  $HEAD_AFTER"
        if [[ "$HEAD_AFTER" != "$LIVE_HEAD" ]]; then
            echo "FAIL: live shared checkout changed during Setup browser preview"
            status=98
        else
            echo "PASS: live shared checkout unchanged"
        fi
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
if [[ "$PREVIEW_PORT" == "8784" || "$PREVIEW_PORT" == "8790" || "$PREVIEW_PORT" == "8792" || "$PREVIEW_PORT" == "8055" ]]; then
    echo "FAIL: preview port conflicts with a governed production listener"
    exit 3
fi
if [[ ! "$PREVIEW_EMAIL" =~ ^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+$ ]]; then
    echo "FAIL: preview operator email is not valid"
    exit 4
fi
if [[ ! -s "$PREVIEW_ENTRY" ]]; then
    echo "FAIL: preview entry file is missing: $PREVIEW_ENTRY"
    exit 5
fi
if ss -ltnH "sport = :$PREVIEW_PORT" | grep -q .; then
    echo "FAIL: preview port $PREVIEW_PORT is already listening on msb-prod-db"
    exit 6
fi
if ! sudo docker inspect "$PROD_CONTAINER" >/dev/null 2>&1; then
    echo "FAIL: production PostgreSQL container was not found"
    exit 7
fi
if [[ "$(sudo docker inspect "$PROD_CONTAINER" --format '{{.Config.Image}}')" != "$IMAGE" ]]; then
    echo "FAIL: production PostgreSQL image does not match $IMAGE"
    exit 8
fi
if ! sudo docker network inspect "$NETWORK" >/dev/null 2>&1; then
    echo "FAIL: Docker network $NETWORK was not found"
    exit 9
fi
if ! systemctl is-active --quiet fieldwiring.service || ! systemctl is-active --quiet msb-procedures.service; then
    echo "FAIL: existing shared production services are not healthy before preview"
    exit 10
fi
if ! systemctl is-active --quiet msb-display-folders.service; then
    echo "FAIL: shared read-only Display Folders service is not active"
    exit 11
fi
if ! sudo -u fieldwiring -H bash -c 'cd /tmp && test -r /mnt/msb-display-folders && test -x /mnt/msb-display-folders'; then
    echo "FAIL: fieldwiring runtime account cannot read/traverse Display Folders"
    exit 12
fi

LIVE_HEAD="$(sudo git -C "$FIELDWIRING_ROOT" rev-parse HEAD)"
if [[ -n "$(sudo git -C "$FIELDWIRING_ROOT" status --porcelain)" ]]; then
    echo "FAIL: live shared checkout has uncommitted changes"
    sudo git -C "$FIELDWIRING_ROOT" status -sb
    exit 13
fi

echo "Production checkout remains: $LIVE_HEAD"
PROD_BEFORE="$(prod_fingerprint)"
echo "Production Setup fingerprint: $PROD_BEFORE"

echo
echo "--- Fetch exact accepted Setup candidate ---"
sudo git -C "$FIELDWIRING_ROOT" fetch origin "$TARGET_REF"
sudo git -C "$FIELDWIRING_ROOT" cat-file -e "$TARGET_SHA^{commit}"
if ! sudo git -C "$FIELDWIRING_ROOT" merge-base --is-ancestor "$LIVE_HEAD" "$TARGET_SHA"; then
    echo "FAIL: accepted Setup candidate is not a forward descendant of the live checkout"
    exit 14
fi
sudo git -C "$FIELDWIRING_ROOT" worktree add --detach "$CANDIDATE_WORKTREE" "$TARGET_SHA"

RESOURCE_MIGRATION="$CANDIDATE_WORKTREE/Setup/Database/008_create_setup_resource_management_commands.sql"
[[ -s "$RESOURCE_MIGRATION" ]] || {
    echo "FAIL: accepted Setup candidate is missing migration 008"
    exit 15
}

sudo -u fieldwiring -H bash -c "
    cd /tmp
    cd '$CANDIDATE_WORKTREE'
    /opt/fieldwiring/.venv/bin/python -m pytest -q -p no:cacheprovider \
        Setup/Application/test_setup_production_contract.py \
        Setup/Application/test_setup_resource_management_contract.py \
        Setup/Application/test_setup_google_doc_index_contract.py
"
echo "Exact detached Setup candidate regression: PASS"

echo
echo "--- Build sanitized Google Doc metadata index ---"
# The rclone OAuth configuration remains readable only by msb-docs-fs. The
# browser application receives a sanitized lsjson metadata file containing IDs,
# paths, and content types but no rclone credentials/tokens.
sudo -u msb-docs-fs -H /usr/bin/rclone lsjson \
    msb-display-folders: \
    --config "$RCLONE_CONFIG" \
    --recursive \
    --files-only \
    --original \
    -M \
    --include '**/Procedures/Setup/SourceDocs/**' \
    --include '**/Procedures/Setup/Archive/**' \
    > "$GOOGLE_DOC_INDEX"

test -s "$GOOGLE_DOC_INDEX"
sudo chown msb-docs-fs:msb-docs-read "$GOOGLE_DOC_INDEX"
sudo chmod 0640 "$GOOGLE_DOC_INDEX"
sudo -u fieldwiring -H test -r "$GOOGLE_DOC_INDEX"
echo "Sanitized Google Doc metadata index: PASS"

echo
echo "--- Capture current production into disposable clone ---"
sudo docker exec "$PROD_CONTAINER" \
    pg_dump -U "$DB_ACTOR" -d "$PROD_DB" -Fc > "$DUMP_FILE"
test -s "$DUMP_FILE"
sudo docker exec -i "$PROD_CONTAINER" pg_restore --list < "$DUMP_FILE" >/dev/null
echo "Production dump captured and validated: $(du -h "$DUMP_FILE" | awk '{print $1}')"

sudo docker run -d \
    --name "$TEST_CONTAINER" \
    --network "$NETWORK" \
    -e POSTGRES_USER="$DB_ACTOR" \
    -e POSTGRES_PASSWORD="$TEST_PASSWORD" \
    -e POSTGRES_DB=postgres \
    "$IMAGE" >/dev/null

init_complete=0
for _ in $(seq 1 120); do
    if sudo docker logs "$TEST_CONTAINER" 2>&1 | grep -q "PostgreSQL init process complete; ready for start up"; then
        init_complete=1
        break
    fi
    sleep 1
done
if [[ "$init_complete" -ne 1 ]]; then
    echo "FAIL: disposable PostgreSQL initialization did not complete"
    sudo docker logs "$TEST_CONTAINER" || true
    exit 16
fi

ready=0
for _ in $(seq 1 60); do
    if sudo docker exec -e PGPASSWORD="$TEST_PASSWORD" "$TEST_CONTAINER" \
        pg_isready -U "$DB_ACTOR" -d postgres >/dev/null 2>&1; then
        ready=1
        break
    fi
    sleep 1
done
if [[ "$ready" -ne 1 ]]; then
    echo "FAIL: disposable PostgreSQL final server did not become ready"
    exit 17
fi

sudo docker exec -e PGPASSWORD="$TEST_PASSWORD" "$TEST_CONTAINER" \
    createdb -U "$DB_ACTOR" -T template0 "$TEST_DB"
sudo docker exec -i -e PGPASSWORD="$TEST_PASSWORD" "$TEST_CONTAINER" \
    pg_restore -U "$DB_ACTOR" -d "$TEST_DB" --no-owner --no-acl --exit-on-error \
    < "$DUMP_FILE"
echo "Disposable current-production clone restored"

psql_test() {
    sudo docker exec -i -e PGPASSWORD="$TEST_PASSWORD" "$TEST_CONTAINER" \
        psql -X -v ON_ERROR_STOP=1 -U "$DB_ACTOR" -d "$TEST_DB" "$@"
}

psql_test <<SQL
CREATE ROLE fieldwiring_app LOGIN PASSWORD '$APP_PASSWORD';
GRANT USAGE ON SCHEMA ref, lor_snap, ops TO fieldwiring_app;
GRANT SELECT ON ALL TABLES IN SCHEMA ref, lor_snap, ops TO fieldwiring_app;

REVOKE ALL ON FUNCTION ref.setup_browser_capabilities(text) FROM PUBLIC;
REVOKE ALL ON FUNCTION ref.setup_management_actor(text,boolean) FROM PUBLIC;
REVOKE ALL ON FUNCTION ops.create_setup_session(text,integer,text) FROM PUBLIC;
REVOKE ALL ON FUNCTION ref.create_setup_task(text,text,integer,text,integer,integer,integer,integer,text,text,text,text) FROM PUBLIC;
REVOKE ALL ON FUNCTION ref.update_setup_task(text,bigint,text,integer,text,integer,boolean,integer,integer,integer,text,text,text,text) FROM PUBLIC;
REVOKE ALL ON FUNCTION ops.update_setup_session_task_review(text,bigint,text,timestamp with time zone,timestamp with time zone,integer,integer,text) FROM PUBLIC;

GRANT EXECUTE ON FUNCTION ref.setup_browser_capabilities(text) TO fieldwiring_app;
GRANT EXECUTE ON FUNCTION ops.create_setup_session(text,integer,text) TO fieldwiring_app;
GRANT EXECUTE ON FUNCTION ref.create_setup_task(text,text,integer,text,integer,integer,integer,integer,text,text,text,text) TO fieldwiring_app;
GRANT EXECUTE ON FUNCTION ref.update_setup_task(text,bigint,text,integer,text,integer,boolean,integer,integer,integer,text,text,text,text) TO fieldwiring_app;
GRANT EXECUTE ON FUNCTION ops.update_setup_session_task_review(text,bigint,text,timestamp with time zone,timestamp with time zone,integer,integer,text) TO fieldwiring_app;
SQL

# Production does not have migration 008 yet. Apply it only to the disposable
# clone so the corrected resource UI can be reviewed before production approval.
psql_test < "$RESOURCE_MIGRATION"
echo "Disposable Setup resource migration 008: PASS"

echo
echo "--- Validate disposable Setup authorization/write boundary ---"
MANAGE_OK="$(psql_test -qAt -c "SELECT can_manage_setup FROM ref.setup_browser_capabilities('$PREVIEW_EMAIL');")"
if [[ "$MANAGE_OK" != "t" ]]; then
    echo "FAIL: preview operator $PREVIEW_EMAIL does not have Setup Manager capability"
    exit 18
fi

psql_test <<'SQL'
DO $block$
BEGIN
    IF has_table_privilege('fieldwiring_app', 'ref.setup_task', 'INSERT')
       OR has_table_privilege('fieldwiring_app', 'ref.setup_task', 'UPDATE')
       OR has_table_privilege('fieldwiring_app', 'ref.setup_task', 'DELETE')
       OR has_table_privilege('fieldwiring_app', 'ref.setup_task_resource', 'INSERT')
       OR has_table_privilege('fieldwiring_app', 'ref.setup_task_resource', 'UPDATE')
       OR has_table_privilege('fieldwiring_app', 'ref.setup_task_resource', 'DELETE')
       OR has_table_privilege('fieldwiring_app', 'ops.setup_session_task', 'INSERT')
       OR has_table_privilege('fieldwiring_app', 'ops.setup_session_task', 'UPDATE')
       OR has_table_privilege('fieldwiring_app', 'ops.setup_session_task', 'DELETE')
       OR has_table_privilege('fieldwiring_app', 'ops.setup_movement_event', 'INSERT') THEN
        RAISE EXCEPTION 'Preview fieldwiring_app unexpectedly has broad Setup DML';
    END IF;

    IF has_function_privilege('fieldwiring_app', 'ref.setup_management_actor(text,boolean)', 'EXECUTE') THEN
        RAISE EXCEPTION 'Preview fieldwiring_app unexpectedly can execute internal Setup actor helper';
    END IF;

    IF NOT has_function_privilege(
        'fieldwiring_app',
        'ref.create_setup_resource(text,text,text,text)',
        'EXECUTE'
    ) OR NOT has_function_privilege(
        'fieldwiring_app',
        'ref.set_setup_task_resource(text,bigint,integer,integer,text,text,boolean)',
        'EXECUTE'
    ) THEN
        RAISE EXCEPTION 'Preview fieldwiring_app lacks narrow Setup resource commands';
    END IF;

    IF has_table_privilege('fieldwiring_app', 'directus_users', 'SELECT') THEN
        RAISE EXCEPTION 'Preview fieldwiring_app unexpectedly can directly read Directus users';
    END IF;
END
$block$;
SQL

echo "Disposable Setup authorization boundary: PASS"

TEST_IP="$(sudo docker inspect "$TEST_CONTAINER" --format '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}')"
if [[ -z "$TEST_IP" ]]; then
    echo "FAIL: could not resolve disposable PostgreSQL container IP"
    exit 19
fi

APP_DIR="$CANDIDATE_WORKTREE/Setup/Application"
DSN="host=$TEST_IP port=5432 dbname=$TEST_DB user=fieldwiring_app password=$APP_PASSWORD"

echo
echo "--- Start exact accepted Setup candidate ---"
PREVIEW_PGID="$(
    sudo -u fieldwiring -H env \
        SETUP_DATABASE_DSN="$DSN" \
        SETUP_DRIVE_ROOT="/mnt/msb-display-folders" \
        SETUP_GOOGLE_DOC_INDEX="$GOOGLE_DOC_INDEX" \
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
    echo "FAIL: Setup preview process did not return a valid process-group ID: $PREVIEW_PGID"
    exit 20
fi

preview_ready=0
for _ in $(seq 1 30); do
    if curl -fsS "http://127.0.0.1:$PREVIEW_PORT/api/health" >/dev/null 2>&1; then
        preview_ready=1
        break
    fi
    sleep 1
done
if [[ "$preview_ready" -ne 1 ]]; then
    echo "FAIL: Setup preview application did not become healthy"
    tail -n 100 "$PREVIEW_LOG" || true
    exit 21
fi

HEALTH="$(curl -fsS "http://127.0.0.1:$PREVIEW_PORT/api/health")"
ACCESS="$(curl -fsS "http://127.0.0.1:$PREVIEW_PORT/api/setup/access")"
TASKS_CODE="$(curl -sS -o /tmp/setup-preview-tasks-$STAMP.json -w '%{http_code}' "http://127.0.0.1:$PREVIEW_PORT/api/setup/tasks?season_year=2025")"
if [[ "$TASKS_CODE" != "200" ]]; then
    echo "FAIL: Setup preview task API returned HTTP $TASKS_CODE"
    cat /tmp/setup-preview-tasks-$STAMP.json || true
    rm -f /tmp/setup-preview-tasks-$STAMP.json
    exit 22
fi
rm -f /tmp/setup-preview-tasks-$STAMP.json

RESOURCES_CODE="$(curl -sS -o /tmp/setup-preview-resources-$STAMP.json -w '%{http_code}' "http://127.0.0.1:$PREVIEW_PORT/api/setup/resources")"
if [[ "$RESOURCES_CODE" != "200" ]]; then
    echo "FAIL: Setup preview resource catalog returned HTTP $RESOURCES_CODE"
    cat /tmp/setup-preview-resources-$STAMP.json || true
    rm -f /tmp/setup-preview-resources-$STAMP.json
    exit 23
fi
rm -f /tmp/setup-preview-resources-$STAMP.json

PROCEDURE_CODE="$(curl -sS -o /tmp/setup-preview-procedure-$STAMP.json -w '%{http_code}' "http://127.0.0.1:$PREVIEW_PORT/api/setup/procedure?stage_key=04")"
if [[ "$PROCEDURE_CODE" != "200" ]]; then
    echo "FAIL: Setup preview Procedure API returned HTTP $PROCEDURE_CODE"
    cat /tmp/setup-preview-procedure-$STAMP.json || true
    rm -f /tmp/setup-preview-procedure-$STAMP.json
    exit 24
fi
rm -f /tmp/setup-preview-procedure-$STAMP.json

MEGA_PROCEDURE="/tmp/setup-preview-mega-procedure-$STAMP.json"
MEGA_CODE="$(curl -sS -o "$MEGA_PROCEDURE" -w '%{http_code}' "http://127.0.0.1:$PREVIEW_PORT/api/setup/procedure?stage_key=03a")"
if [[ "$MEGA_CODE" != "200" ]]; then
    echo "FAIL: Mega Cube Setup Procedure API returned HTTP $MEGA_CODE"
    cat "$MEGA_PROCEDURE" || true
    rm -f "$MEGA_PROCEDURE"
    exit 25
fi

/opt/fieldwiring/.venv/bin/python - "$MEGA_PROCEDURE" <<'PY'
import json
import sys

with open(sys.argv[1], encoding="utf-8") as handle:
    payload = json.load(handle)
sources = payload.get("instructions", {}).get("editable_sources", [])
official = [item for item in sources if item.get("name") == "03-Mega Cube-MC Setup Procedure.gdoc"]
if len(official) != 1:
    raise SystemExit("FAIL: official Mega Cube Google Doc was not resolved exactly once")
item = official[0]
if item.get("source_backend") != "rclone-metadata-index":
    raise SystemExit("FAIL: Mega Cube Google Doc did not come from rclone metadata proof")
if not item.get("google_doc_id") or not str(item.get("edit_url", "")).startswith("https://docs.google.com/document/d/"):
    raise SystemExit("FAIL: Mega Cube editable Google Doc link is incomplete")
if any("Randy" in str(candidate.get("name", "")) for candidate in sources):
    raise SystemExit("FAIL: native Randy Word document was misclassified as editable Google Doc")
print("Mega Cube Google Doc/native Word discrimination: PASS")
PY
rm -f "$MEGA_PROCEDURE"

echo "Preview health: $HEALTH"
echo "Preview access: $ACCESS"
echo
echo "============================================================"
echo "SETUP BROWSER REVIEW READY"
echo "Open on the Windows workstation:"
echo "  http://127.0.0.1:$PREVIEW_PORT/"
echo
echo "This is candidate $TARGET_SHA against a DISPOSABLE current-production clone."
echo "Preview identity: $PREVIEW_EMAIL"
echo "Production checkout and Setup data remain unchanged."
echo
echo "Review the narrower task queue and the Equipment / Resources Needed section."
echo "Front Entrance should show SkyTrak + Boom Lift from structured DB relationships."
echo "Mega Cube should show the official Google Doc as editable, not Randy's native .docx."
echo "Manager Add/Update/Remove Resource actions change the disposable clone only."
echo "Any Save/Verify/Add Task action also changes the disposable clone only."
echo "Movement remains intentionally non-writable in this candidate."
echo
echo "When review is finished, return to this PowerShell window and press ENTER."
echo "============================================================"
echo

read -r -p "Press ENTER to stop and clean up the Setup browser preview... " _unused

echo "Setup browser review session ended by operator. Cleaning up."
