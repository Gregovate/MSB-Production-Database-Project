#!/usr/bin/env bash
set -euo pipefail

PROD_CONTAINER="msb-postgres"
PROD_DB="msb"
DB_ACTOR="msbadmin"
IMAGE="postgis/postgis:16-3.5"
NETWORK="msb-stack_default"
FIELDWIRING_ROOT="/opt/fieldwiring"
TARGET_REF="agent/setup-catalog-reconstruction-20260909"
TARGET_SHA="dd1cbeafe6243089b4ee3b04ea3f67359654381f"

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
PREVIEW_ENTRY="$SCRIPT_DIR/setup_session_browser_preview_entry.py"
PREVIEW_PORT="${1:?preview port is required}"
PREVIEW_EMAIL="${2:-gliebig@sheboyganlights.org}"
STAMP="$(date +%Y%m%dT%H%M%S)"
TEST_CONTAINER="msb-setup-catalog-preview-${$}"
TEST_DB="msb_setup_catalog_browser_preview"
TEST_PASSWORD="setup-catalog-preview-${$}-$(date +%s)"
APP_PASSWORD="setupcatalogpreview${$}$(date +%s)"
DUMP_FILE="/tmp/msb-setup-catalog-preview-production-${STAMP}-${$}.dump"
GRANTS_FILE="/tmp/msb-setup-catalog-preview-grants-${STAMP}-${$}.sql"
CANDIDATE_WORKTREE="/tmp/msb-setup-catalog-preview-candidate-$STAMP"
REPORT_DIR="$HOME/setup-acceptance-reports"
REPORT="$REPORT_DIR/Setup_Catalog_Reconstruction_Browser_Preview_${STAMP}.txt"
PREVIEW_LOG="/tmp/Setup_Catalog_Reconstruction_Browser_Preview_Flask_${STAMP}.log"
CONTAINER_DB_DIR="/tmp/setup-catalog-preview-db"
CONTAINER_VALIDATION="/tmp/setup_catalog_reconstruction_disposable_validation.sql"
PREVIEW_PGID=""
PROD_BEFORE=""
LIVE_HEAD=""
PREVIEW_OWNED_PORT=0

mkdir -p "$REPORT_DIR"
exec > >(tee "$REPORT") 2>&1

echo "========== SETUP CATALOG RECONSTRUCTION BROWSER PREVIEW =========="
echo "Candidate SHA:  $TARGET_SHA"
echo "Preview port:   $PREVIEW_PORT"
echo "Preview user:   $PREVIEW_EMAIL"
echo "Report:         $REPORT"
echo "Production DB:  pg_dump + SELECT only"
echo "Preview writes: disposable PostgreSQL clone only"
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
    echo "--- Setup catalog browser preview cleanup ---"
    if [[ -n "$PREVIEW_PGID" ]]; then
        kill -- -"$PREVIEW_PGID" >/dev/null 2>&1 || true
        sleep 1
        kill -KILL -- -"$PREVIEW_PGID" >/dev/null 2>&1 || true
    fi

    sudo docker rm -f "$TEST_CONTAINER" >/dev/null 2>&1 || true

    if sudo git -C "$FIELDWIRING_ROOT" worktree list --porcelain 2>/dev/null | grep -Fq "worktree $CANDIDATE_WORKTREE"; then
        sudo git -C "$FIELDWIRING_ROOT" worktree remove --force "$CANDIDATE_WORKTREE" >/dev/null 2>&1 || true
    fi

    rm -f "$DUMP_FILE" "$GRANTS_FILE" >/dev/null 2>&1 || true
    rm -rf "$SCRIPT_DIR" >/dev/null 2>&1 || true

    echo "--- Production Setup fingerprint after-check ---"
    if [[ -n "$PROD_BEFORE" ]]; then
        PROD_AFTER="$(prod_fingerprint 2>/dev/null)"
        echo "Before: $PROD_BEFORE"
        echo "After:  $PROD_AFTER"
        if [[ -z "$PROD_AFTER" || "$PROD_AFTER" != "$PROD_BEFORE" ]]; then
            echo "FAIL: Production Setup fingerprint changed during catalog browser preview"
            status=97
        else
            echo "PASS: Production Setup fingerprint unchanged"
        fi
    else
        echo "SKIP: Production Setup fingerprint was not captured before failure"
    fi

    if [[ -n "$LIVE_HEAD" ]]; then
        HEAD_AFTER="$(sudo git -C "$FIELDWIRING_ROOT" rev-parse HEAD 2>/dev/null)"
        echo "Live checkout before: $LIVE_HEAD"
        echo "Live checkout after:  $HEAD_AFTER"
        if [[ -z "$HEAD_AFTER" || "$HEAD_AFTER" != "$LIVE_HEAD" ]]; then
            echo "FAIL: shared live checkout changed during catalog browser preview"
            status=98
        else
            echo "PASS: shared live checkout unchanged"
        fi
    else
        echo "SKIP: live checkout SHA was not captured before failure"
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
if [[ ! -s "$PREVIEW_ENTRY" ]]; then
    echo "FAIL: preview entry file is missing: $PREVIEW_ENTRY"
    exit 5
fi
if ss -ltnH "sport = :$PREVIEW_PORT" | grep -q .; then
    echo "FAIL: preview port $PREVIEW_PORT is already listening on msb-prod-db"
    exit 6
fi
if ! sudo docker inspect "$PROD_CONTAINER" >/dev/null 2>&1; then
    echo "FAIL: Production PostgreSQL container was not found"
    exit 7
fi
if [[ "$(sudo docker inspect "$PROD_CONTAINER" --format '{{.Config.Image}}')" != "$IMAGE" ]]; then
    echo "FAIL: Production PostgreSQL image is not $IMAGE"
    exit 8
fi
if ! sudo docker network inspect "$NETWORK" >/dev/null 2>&1; then
    echo "FAIL: Docker network $NETWORK was not found"
    exit 9
fi
if ! systemctl is-active --quiet fieldwiring.service \
   || ! systemctl is-active --quiet msb-procedures.service \
   || ! systemctl is-active --quiet msb-setup.service; then
    echo "FAIL: one or more Production application services are not healthy before preview"
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
    echo "FAIL: shared live checkout has uncommitted changes"
    sudo git -C "$FIELDWIRING_ROOT" status -sb
    exit 13
fi

echo "Production/shared checkout remains: $LIVE_HEAD"
PROD_BEFORE="$(prod_fingerprint)"
if [[ -z "$PROD_BEFORE" ]]; then
    echo "FAIL: Production Setup fingerprint was empty"
    exit 14
fi
echo "Production Setup fingerprint before: $PROD_BEFORE"

echo
echo "--- Fetch exact accepted Setup catalog candidate ---"
sudo git -C "$FIELDWIRING_ROOT" fetch origin "$TARGET_REF"
sudo git -C "$FIELDWIRING_ROOT" cat-file -e "$TARGET_SHA^{commit}"
if ! sudo git -C "$FIELDWIRING_ROOT" merge-base --is-ancestor "$LIVE_HEAD" "$TARGET_SHA"; then
    echo "FAIL: accepted Setup catalog candidate is not a forward descendant of the shared live checkout"
    exit 15
fi
sudo git -C "$FIELDWIRING_ROOT" worktree add --detach "$CANDIDATE_WORKTREE" "$TARGET_SHA"

M023="$CANDIDATE_WORKTREE/Setup/Database/023_add_setup_task_effort.sql"
M024="$CANDIDATE_WORKTREE/Setup/Database/024_reconstruct_setup_catalog_from_reviewed_one_list.sql"
BATCH_DIR="$CANDIDATE_WORKTREE/Setup/Database/reconstruction"
VALIDATION="$CANDIDATE_WORKTREE/Setup/Acceptance/setup_catalog_reconstruction_disposable_validation.sql"
for file in \
    "$M023" \
    "$M024" \
    "$BATCH_DIR/024_catalog_batch_01.sql" \
    "$BATCH_DIR/024_catalog_batch_02.sql" \
    "$BATCH_DIR/024_catalog_batch_03.sql" \
    "$BATCH_DIR/024_catalog_batch_04.sql" \
    "$BATCH_DIR/024_catalog_batch_05.sql" \
    "$VALIDATION"; do
    if [[ ! -s "$file" ]]; then
        echo "FAIL: exact accepted candidate is missing required catalog reconstruction file: $file"
        exit 16
    fi
done

sudo -u fieldwiring -H bash -c "
    cd /tmp
    cd '$CANDIDATE_WORKTREE'
    /opt/fieldwiring/.venv/bin/python -m pytest -q -p no:cacheprovider \
        Setup/Application/test_setup_production_contract.py \
        Setup/Application/test_setup_next_pass_contract.py \
        Setup/Application/test_setup_final_scope_contract.py \
        Setup/Application/test_setup_catalog_effort_contract.py
"
echo "Exact accepted Setup catalog candidate regression: PASS"

echo
echo "--- Capture current Production into disposable clone ---"
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

# postgis/postgis:16-3.5 uses a temporary PostgreSQL server during initialization.
# Require final PID 1 = postgres plus pg_isready, never pg_isready alone.
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
    exit 17
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

# Recreate the application login and mirror only the existing Production read/
# execute privileges. Candidate migration 023 separately grants its new governed
# effort command. No broad direct table DML is introduced.
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
        WHERE n.nspname IN ('ref','lor_snap','ops')
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
    echo "FAIL: could not derive existing Production fieldwiring_app privilege mirror"
    exit 18
fi
psql_test < "$GRANTS_FILE"
echo "Production-equivalent existing fieldwiring_app read/execute privileges mirrored: PASS"

sudo docker exec "$TEST_CONTAINER" mkdir -p "$CONTAINER_DB_DIR/reconstruction"
sudo docker cp "$M023" "$TEST_CONTAINER:$CONTAINER_DB_DIR/023_add_setup_task_effort.sql"
sudo docker cp "$M024" "$TEST_CONTAINER:$CONTAINER_DB_DIR/024_reconstruct_setup_catalog_from_reviewed_one_list.sql"
for batch in "$BATCH_DIR"/*.sql; do
    sudo docker cp "$batch" "$TEST_CONTAINER:$CONTAINER_DB_DIR/reconstruction/$(basename "$batch")"
done
sudo docker cp "$VALIDATION" "$TEST_CONTAINER:$CONTAINER_VALIDATION"

echo
echo "--- Apply accepted catalog candidate to disposable clone only ---"
psql_test -f "$CONTAINER_DB_DIR/023_add_setup_task_effort.sql"
echo "Migration 023 reusable effort metadata: PASS"
psql_test -f "$CONTAINER_DB_DIR/024_reconstruct_setup_catalog_from_reviewed_one_list.sql"
echo "Migration 024 reviewed reusable catalog reconstruction: PASS"
psql_test -f "$CONTAINER_VALIDATION"
echo "Disposable reconstructed catalog validation: PASS"

MANAGE_OK="$(psql_test -qAt -c "SELECT can_manage_setup FROM ref.setup_browser_capabilities('$PREVIEW_EMAIL');")"
if [[ "$MANAGE_OK" != "t" ]]; then
    echo "FAIL: preview operator $PREVIEW_EMAIL does not have Setup Manager capability"
    exit 19
fi

psql_test <<'SQL'
DO $boundary$
BEGIN
    IF has_table_privilege('fieldwiring_app', 'ref.setup_task', 'INSERT')
       OR has_table_privilege('fieldwiring_app', 'ref.setup_task', 'UPDATE')
       OR has_table_privilege('fieldwiring_app', 'ref.setup_task', 'DELETE') THEN
        RAISE EXCEPTION 'Preview fieldwiring_app unexpectedly has broad reusable-task DML';
    END IF;
    IF NOT has_function_privilege(
        'fieldwiring_app',
        'ref.set_setup_task_effort(text,bigint,text)',
        'EXECUTE'
    ) THEN
        RAISE EXCEPTION 'Preview fieldwiring_app cannot execute governed effort editor';
    END IF;
END
$boundary$;
SQL
echo "Disposable Setup effort authorization boundary: PASS"

TEST_IP="$(sudo docker inspect "$TEST_CONTAINER" --format '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}')"
if [[ -z "$TEST_IP" ]]; then
    echo "FAIL: could not resolve disposable PostgreSQL container IP"
    exit 20
fi

APP_DIR="$CANDIDATE_WORKTREE/Setup/Application"
DSN="host=$TEST_IP port=5432 dbname=$TEST_DB user=fieldwiring_app password=$APP_PASSWORD"

echo
echo "--- Start exact accepted Setup catalog candidate ---"
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
    echo "FAIL: Setup catalog preview process did not return a valid process-group ID: $PREVIEW_PGID"
    exit 21
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
    echo "FAIL: Setup catalog preview application did not become healthy"
    tail -n 100 "$PREVIEW_LOG" || true
    exit 22
fi

TASKS_FILE="/tmp/setup-catalog-preview-tasks-$STAMP.json"
EFFORT_FILE="/tmp/setup-catalog-preview-effort-$STAMP.json"
TASKS_CODE="$(curl -sS -o "$TASKS_FILE" -w '%{http_code}' "http://127.0.0.1:$PREVIEW_PORT/api/setup/tasks?season_year=2025")"
EFFORT_CODE="$(curl -sS -o "$EFFORT_FILE" -w '%{http_code}' "http://127.0.0.1:$PREVIEW_PORT/api/setup/task-efforts")"
if [[ "$TASKS_CODE" != "200" || "$EFFORT_CODE" != "200" ]]; then
    echo "FAIL: Setup catalog preview APIs did not return 200 (tasks=$TASKS_CODE efforts=$EFFORT_CODE)"
    cat "$TASKS_FILE" "$EFFORT_FILE" || true
    rm -f "$TASKS_FILE" "$EFFORT_FILE"
    exit 23
fi

sudo -u fieldwiring -H /opt/fieldwiring/.venv/bin/python - "$EFFORT_FILE" <<'PY'
import json
import sys

with open(sys.argv[1], encoding='utf-8') as handle:
    payload = json.load(handle)
rows = payload.get('task_efforts', [])
if len(rows) != 185:
    raise SystemExit(f"FAIL: effort API should expose 185 reusable tasks; found {len(rows)}")
counts = {None: 0, 'LIGHT': 0, 'MODERATE': 0, 'HEAVY': 0}
for row in rows:
    value = row.get('effort_level')
    if value not in counts:
        raise SystemExit(f"FAIL: unexpected effort value {value!r}")
    counts[value] += 1
expected = {None: 161, 'LIGHT': 8, 'MODERATE': 12, 'HEAVY': 4}
if counts != expected:
    raise SystemExit(f"FAIL: effort API counts {counts!r} != {expected!r}")
print('Setup catalog effort API 185-task distribution: PASS')
PY
rm -f "$TASKS_FILE" "$EFFORT_FILE"

echo
echo "============================================================"
echo "SETUP CATALOG BROWSER REVIEW READY"
echo "Open on the Windows workstation:"
echo "  http://127.0.0.1:$PREVIEW_PORT/"
echo
echo "This is accepted candidate $TARGET_SHA against a DISPOSABLE current-Production clone."
echo "Preview identity: $PREVIEW_EMAIL"
echo "Production Setup data and shared checkout remain unchanged."
echo
echo "Review the reconstructed reusable Catalog as the future Production task basis:"
echo "  - Stage and Scene scope/moves from the reviewed workbook"
echo "  - normalized Locate Power & Network and Layout Panels names"
echo "  - Physical Effort LIGHT / MODERATE / HEAVY / blank"
echo "  - provisional junk such as task 'light' is absent"
echo "  - reconstructed new tasks are reusable definitions, not fabricated 2025 execution"
echo "Change one Physical Effort value, save, refresh, and confirm it persists in the disposable clone."
echo "Prerequisites are intentionally empty until the next reviewed predecessor/readiness pass."
echo
echo "When review is finished, return to this PowerShell window and press ENTER."
echo "============================================================"
echo

read -r -p "Press ENTER to stop and clean up the Setup catalog browser preview... " _unused

echo "Setup catalog browser review ended by operator. Cleaning up."
