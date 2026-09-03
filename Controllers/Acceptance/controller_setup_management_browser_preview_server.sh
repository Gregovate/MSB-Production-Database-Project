#!/usr/bin/env bash
set -euo pipefail

PROD_CONTAINER="msb-postgres"
PROD_DB="msb"
DB_ACTOR="msbadmin"
IMAGE="postgis/postgis:16-3.5"
NETWORK="msb-stack_default"
FIELDWIRING_ROOT="/opt/fieldwiring"
TARGET_REF="agent/controller-inventory-ref-sandbox"
TARGET_SHA="2fd2067958cc0a903260fe6f089f88ae63a857f1"
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
PREVIEW_ENTRY="$SCRIPT_DIR/controller_setup_management_browser_preview_entry.py"
PREVIEW_PORT="${1:-8793}"
PREVIEW_EMAIL="${2:-gliebig@sheboyganlights.org}"
STAMP="$(date +%Y%m%dT%H%M%S)"
TEST_CONTAINER="msb-controller-browser-preview-${$}"
TEST_DB="msb_controller_browser_preview"
TEST_PASSWORD="controller-preview-${$}-$(date +%s)"
APP_PASSWORD="previewapp$(date +%s)${$}"
DUMP_FILE="$SCRIPT_DIR/production.dump"
CANDIDATE_WORKTREE="/tmp/msb-controller-browser-preview-candidate-$STAMP"
REPORT="/tmp/MSB_Controller_Browser_Preview_$STAMP.txt"
PREVIEW_LOG="/tmp/MSB_Controller_Browser_Preview_Flask_$STAMP.log"
PREVIEW_PGID=""
PROD_BEFORE=""

exec > >(tee "$REPORT") 2>&1

echo "========== CONTROLLER SETUP + MANAGEMENT BROWSER PREVIEW =========="
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
                    SELECT string_agg(row_to_json(c)::text, '' ORDER BY c.controller_id)
                    FROM ref.controller c
                ), '') || '|' ||
                coalesce((
                    SELECT string_agg(row_to_json(cd)::text, '' ORDER BY cd.controller_id, cd.display_id)
                    FROM ref.controller_display cd
                ), '') || '|' ||
                coalesce((
                    SELECT string_agg(row_to_json(h)::text, '' ORDER BY h.controller_firmware_history_id)
                    FROM ref.controller_firmware_history h
                ), '')
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
        kill -- -"$PREVIEW_PGID" >/dev/null 2>&1 || true
        sleep 1
        kill -KILL -- -"$PREVIEW_PGID" >/dev/null 2>&1 || true
    fi

    sudo docker rm -f "$TEST_CONTAINER" >/dev/null 2>&1 || true

    if sudo git -C "$FIELDWIRING_ROOT" worktree list --porcelain 2>/dev/null | grep -Fq "worktree $CANDIDATE_WORKTREE"; then
        sudo git -C "$FIELDWIRING_ROOT" worktree remove --force "$CANDIDATE_WORKTREE" >/dev/null 2>&1 || true
    fi

    rm -f "$DUMP_FILE" >/dev/null 2>&1 || true
    rm -rf "$SCRIPT_DIR" >/dev/null 2>&1 || true

    echo
    echo "--- Production Controller fingerprint after-check ---"
    if [[ -n "$PROD_BEFORE" ]]; then
        PROD_AFTER="$(prod_fingerprint 2>/dev/null)"
        echo "Before: $PROD_BEFORE"
        echo "After:  $PROD_AFTER"
        if [[ "$PROD_AFTER" != "$PROD_BEFORE" ]]; then
            echo "FAIL: production Controller fingerprint changed during browser preview"
            status=97
        else
            echo "PASS: production Controller fingerprint unchanged"
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
if [[ "$PREVIEW_PORT" == "8790" || "$PREVIEW_PORT" == "8792" || "$PREVIEW_PORT" == "8055" ]]; then
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

LIVE_HEAD="$(sudo git -C "$FIELDWIRING_ROOT" rev-parse HEAD)"
if [[ -n "$(sudo git -C "$FIELDWIRING_ROOT" status --porcelain)" ]]; then
    echo "FAIL: live shared checkout has uncommitted changes"
    sudo git -C "$FIELDWIRING_ROOT" status -sb
    exit 10
fi

echo "Production checkout remains: $LIVE_HEAD"
PROD_BEFORE="$(prod_fingerprint)"
echo "Production Controller fingerprint: $PROD_BEFORE"

echo
echo "--- Fetch exact accepted candidate ---"
sudo git -C "$FIELDWIRING_ROOT" fetch origin "$TARGET_REF"
sudo git -C "$FIELDWIRING_ROOT" cat-file -e "$TARGET_SHA^{commit}"
if ! sudo git -C "$FIELDWIRING_ROOT" merge-base --is-ancestor "$LIVE_HEAD" "$TARGET_SHA"; then
    echo "FAIL: accepted candidate is not a forward descendant of the live checkout"
    exit 11
fi
sudo git -C "$FIELDWIRING_ROOT" worktree add --detach "$CANDIDATE_WORKTREE" "$TARGET_SHA"
MIGRATION_023="$CANDIDATE_WORKTREE/Controllers/Database/023_create_controller_management_commands.sql"
MIGRATION_024="$CANDIDATE_WORKTREE/Controllers/Database/024_harden_controller_assignment_capability.sql"
for f in "$MIGRATION_023" "$MIGRATION_024"; do
    [[ -s "$f" ]] || { echo "FAIL: accepted candidate migration missing: $f"; exit 12; }
done

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
    exit 13
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
    exit 14
fi

sudo docker exec -e PGPASSWORD="$TEST_PASSWORD" "$TEST_CONTAINER" \
    createdb -U "$DB_ACTOR" -T template0 "$TEST_DB"
sudo docker exec -i -e PGPASSWORD="$TEST_PASSWORD" "$TEST_CONTAINER" \
    pg_restore -U "$DB_ACTOR" -d "$TEST_DB" --no-owner --no-acl --exit-on-error \
    < "$DUMP_FILE"
echo "Disposable production clone restored"

psql_test() {
    sudo docker exec -i -e PGPASSWORD="$TEST_PASSWORD" "$TEST_CONTAINER" \
        psql -X -v ON_ERROR_STOP=1 -U "$DB_ACTOR" -d "$TEST_DB" "$@"
}

psql_test <<SQL
CREATE ROLE fieldwiring_app LOGIN PASSWORD '$APP_PASSWORD';
GRANT USAGE ON SCHEMA ref, lor_snap, ops TO fieldwiring_app;
GRANT SELECT ON ALL TABLES IN SCHEMA ref, lor_snap, ops TO fieldwiring_app;
GRANT EXECUTE ON FUNCTION ref.controller_browser_capabilities(text) TO fieldwiring_app;
GRANT EXECUTE ON FUNCTION ref.request_controller_label(text,bigint) TO fieldwiring_app;
SQL

psql_test < "$MIGRATION_023"
psql_test < "$MIGRATION_024"

echo
echo "--- Validate disposable browser authorization/write boundary ---"
MANAGE_OK="$(psql_test -qAt -v preview_email="$PREVIEW_EMAIL" -c "SELECT can_manage_controllers FROM ref.controller_browser_capabilities(:'preview_email');")"
if [[ "$MANAGE_OK" != "t" ]]; then
    echo "FAIL: preview operator $PREVIEW_EMAIL does not have Controller management capability"
    exit 15
fi

psql_test <<'SQL'
DO $block$
BEGIN
    IF has_table_privilege('fieldwiring_app', 'ref.controller', 'INSERT')
       OR has_table_privilege('fieldwiring_app', 'ref.controller', 'UPDATE')
       OR has_table_privilege('fieldwiring_app', 'ref.controller', 'DELETE')
       OR has_table_privilege('fieldwiring_app', 'ref.controller_display', 'INSERT')
       OR has_table_privilege('fieldwiring_app', 'ref.controller_display', 'UPDATE')
       OR has_table_privilege('fieldwiring_app', 'ref.controller_display', 'DELETE') THEN
        RAISE EXCEPTION 'Preview fieldwiring_app unexpectedly has broad Controller DML';
    END IF;
END
$block$;
SQL

echo "Disposable authorization boundary: PASS"

TEST_IP="$(sudo docker inspect "$TEST_CONTAINER" --format '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}')"
if [[ -z "$TEST_IP" ]]; then
    echo "FAIL: could not resolve disposable PostgreSQL container IP"
    exit 16
fi

APP_DIR="$CANDIDATE_WORKTREE/FieldWiring/Application"
DSN="host=$TEST_IP port=5432 dbname=$TEST_DB user=fieldwiring_app password=$APP_PASSWORD"

echo
echo "--- Start exact accepted Flask candidate ---"
setsid sudo -u fieldwiring -H env \
    FIELDWIRING_DATABASE_DSN="$DSN" \
    MSB_PREVIEW_APP_DIR="$APP_DIR" \
    MSB_PREVIEW_OPERATOR_EMAIL="$PREVIEW_EMAIL" \
    MSB_PREVIEW_HOST="127.0.0.1" \
    MSB_PREVIEW_PORT="$PREVIEW_PORT" \
    /opt/fieldwiring/.venv/bin/python "$PREVIEW_ENTRY" \
    > "$PREVIEW_LOG" 2>&1 &
PREVIEW_PGID=$!

preview_ready=0
for _ in $(seq 1 30); do
    if curl -fsS "http://127.0.0.1:$PREVIEW_PORT/api/health" >/dev/null 2>&1; then
        preview_ready=1
        break
    fi
    sleep 1
done
if [[ "$preview_ready" -ne 1 ]]; then
    echo "FAIL: preview Flask application did not become healthy"
    tail -n 100 "$PREVIEW_LOG" || true
    exit 17
fi

HEALTH="$(curl -fsS "http://127.0.0.1:$PREVIEW_PORT/api/health")"
ACCESS="$(curl -fsS "http://127.0.0.1:$PREVIEW_PORT/api/controller-access")"
OPTIONS_CODE="$(curl -sS -o /tmp/controller-preview-options-$STAMP.json -w '%{http_code}' "http://127.0.0.1:$PREVIEW_PORT/api/controller-management/options")"
if [[ "$OPTIONS_CODE" != "200" ]]; then
    echo "FAIL: preview management options returned HTTP $OPTIONS_CODE"
    cat /tmp/controller-preview-options-$STAMP.json || true
    rm -f /tmp/controller-preview-options-$STAMP.json
    exit 18
fi
rm -f /tmp/controller-preview-options-$STAMP.json

echo "Preview health: $HEALTH"
echo "Preview access: $ACCESS"
echo
echo "============================================================"
echo "BROWSER REVIEW READY"
echo "Open on the Windows workstation:"
echo "  http://127.0.0.1:$PREVIEW_PORT/controllers"
echo
echo "This is candidate $TARGET_SHA against a DISPOSABLE production clone."
echo "Preview identity: $PREVIEW_EMAIL"
echo "Production checkout and Controller data remain unchanged."
echo
echo "Use the browser normally, including clone-only Add/Edit/Assignment tests."
echo "When review is finished, return to this PowerShell window and press ENTER."
echo "============================================================"
echo

read -r -p "Press ENTER to stop and clean up the browser preview... " _unused

echo "Browser review session ended by operator. Cleaning up."
