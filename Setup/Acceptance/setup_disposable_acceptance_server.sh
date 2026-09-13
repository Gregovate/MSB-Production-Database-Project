#!/usr/bin/env bash
set -euo pipefail

PROD_CONTAINER="msb-postgres"
PROD_DB="msb"
DB_ACTOR="msbadmin"
IMAGE="postgis/postgis:16-3.5"
NETWORK="msb-stack_default"
REPO_ROOT="/opt/fieldwiring"
SETUP_LIVE_ROOT="/opt/msb-setup"
PYTHON="/opt/fieldwiring/.venv/bin/python"

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
MANIFEST="${1:?manifest path is required}"
[[ -s "$MANIFEST" ]] || { echo "FAIL: acceptance manifest is missing: $MANIFEST"; exit 2; }

TARGET_SHA=""
TARGET_REF=""
MIGRATIONS=()
VALIDATIONS=()

while IFS=$'\t' read -r kind value extra; do
    [[ -z "$kind" ]] && continue
    [[ "$kind" == \#* ]] && continue
    [[ -z "${extra:-}" ]] || { echo "FAIL: malformed manifest line for $kind"; exit 3; }
    case "$kind" in
        candidate_sha) TARGET_SHA="$value" ;;
        target_ref) TARGET_REF="$value" ;;
        migration) MIGRATIONS+=("$value") ;;
        validation) VALIDATIONS+=("$value") ;;
        *) echo "FAIL: unsupported manifest key: $kind"; exit 3 ;;
    esac
done < "$MANIFEST"

: "${TARGET_SHA:?manifest candidate_sha is required}"
: "${TARGET_REF:?manifest target_ref is required}"

for rel in "${MIGRATIONS[@]}" "${VALIDATIONS[@]}"; do
    [[ -z "$rel" ]] && continue
    if [[ "$rel" = /* || "$rel" == *".."* || "$rel" == *$'\t'* || "$rel" == *$'\n'* ]]; then
        echo "FAIL: unsafe candidate-relative path in manifest: $rel"
        exit 4
    fi
done

STAMP="$(date +%Y%m%dT%H%M%S)"
TEST_CONTAINER="msb-setup-disposable-${$}"
TEST_DB="msb_setup_disposable_acceptance"
TEST_PASSWORD="setup-disposable-${$}-$(date +%s)"
APP_PASSWORD="setupapp-${$}-$(date +%s)"
DUMP_FILE="/tmp/msb-setup-disposable-${STAMP}-${$}.dump"
GRANTS_FILE="/tmp/msb-setup-disposable-grants-${STAMP}-${$}.sql"
CANDIDATE_WORKTREE="/tmp/msb-setup-disposable-candidate-${STAMP}"
REPORT_DIR="$HOME/setup-acceptance-reports"
REPORT="$REPORT_DIR/Setup_Disposable_Acceptance_${STAMP}.txt"
PROD_BEFORE=""
SETUP_HEAD_BEFORE=""
PYCACHE="/tmp/msb-setup-disposable-pycache-${STAMP}"

mkdir -p "$REPORT_DIR"
exec > >(tee "$REPORT") 2>&1

echo "========== SETUP REUSABLE DISPOSABLE ACCEPTANCE =========="
echo "Authority: Gregovate/MSB-Server-Management — docs/server/PostgreSQL_Disposable_Acceptance_Standard.md"
echo "Candidate SHA: $TARGET_SHA"
echo "Target ref:    $TARGET_REF"
echo "Migrations:    ${#MIGRATIONS[@]}"
echo "Validations:   ${#VALIDATIONS[@]}"
echo "Report:        $REPORT"
echo "Production DB: pg_dump + SELECT only"
echo "Candidate writes: disposable current-Production clone only"
echo

prod_fingerprint() {
    sudo docker exec "$PROD_CONTAINER" \
        psql -X -qAt -v ON_ERROR_STOP=1 -U "$DB_ACTOR" -d "$PROD_DB" -c "
            SELECT md5(
                coalesce((SELECT string_agg(row_to_json(t)::text, '' ORDER BY t.setup_task_id) FROM ref.setup_task t), '') || '|' ||
                coalesce((SELECT string_agg(row_to_json(d)::text, '' ORDER BY d.setup_task_id, d.prerequisite_setup_task_id) FROM ref.setup_task_dependency d), '') || '|' ||
                coalesce((SELECT string_agg(row_to_json(td)::text, '' ORDER BY td.setup_task_id, td.display_id) FROM ref.setup_task_display td), '') || '|' ||
                coalesce((SELECT string_agg(row_to_json(tc)::text, '' ORDER BY tc.setup_task_id, tc.container_id) FROM ref.setup_task_container_support tc), '') || '|' ||
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
    trap - EXIT HUP INT TERM
    set +e

    echo
    echo "--- Disposable cleanup ---"
    sudo docker rm -f "$TEST_CONTAINER" >/dev/null 2>&1 || true
    if sudo git -C "$REPO_ROOT" worktree list --porcelain 2>/dev/null | grep -Fq "worktree $CANDIDATE_WORKTREE"; then
        sudo git -C "$REPO_ROOT" worktree remove --force "$CANDIDATE_WORKTREE" >/dev/null 2>&1 || true
    fi
    rm -f "$DUMP_FILE" "$GRANTS_FILE" >/dev/null 2>&1 || true
    sudo rm -rf "$PYCACHE" >/dev/null 2>&1 || true
    rm -rf "$SCRIPT_DIR" >/dev/null 2>&1 || true

    echo "--- Production after-check ---"
    if [[ -n "$PROD_BEFORE" ]]; then
        PROD_AFTER="$(prod_fingerprint 2>/dev/null)"
        echo "Production Setup fingerprint before: $PROD_BEFORE"
        echo "Production Setup fingerprint after:  $PROD_AFTER"
        if [[ -z "$PROD_AFTER" || "$PROD_AFTER" != "$PROD_BEFORE" ]]; then
            echo "FAIL: Production Setup fingerprint changed during disposable acceptance"
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
            echo "FAIL: live /opt/msb-setup checkout changed during disposable acceptance"
            status=98
        else
            echo "PASS: live Setup checkout unchanged"
        fi
    else
        echo "SKIP: live Setup SHA was not captured before failure"
    fi

    echo "Acceptance report retained at: $REPORT"
    echo "Exit status: $status"
    exit "$status"
}
trap cleanup EXIT HUP INT TERM

sudo -v

if ! sudo docker inspect "$PROD_CONTAINER" >/dev/null 2>&1; then echo "FAIL: Production PostgreSQL container was not found"; exit 5; fi
if [[ "$(sudo docker inspect "$PROD_CONTAINER" --format '{{.Config.Image}}')" != "$IMAGE" ]]; then echo "FAIL: Production PostgreSQL image is not $IMAGE"; exit 6; fi
if ! sudo docker network inspect "$NETWORK" >/dev/null 2>&1; then echo "FAIL: Docker network $NETWORK was not found"; exit 7; fi
if ! systemctl is-active --quiet msb-setup.service; then echo "FAIL: Production Setup service is not active"; exit 8; fi
if ! sudo -u fieldwiring -H test -x "$PYTHON"; then echo "FAIL: documented shared Python runtime is unavailable to fieldwiring"; exit 9; fi

SETUP_HEAD_BEFORE="$(sudo git -C "$SETUP_LIVE_ROOT" rev-parse HEAD)"
if [[ -n "$(sudo git -C "$SETUP_LIVE_ROOT" status --porcelain)" ]]; then echo "FAIL: live Setup checkout has uncommitted changes"; exit 10; fi
if [[ -n "$(sudo git -C "$REPO_ROOT" status --porcelain)" ]]; then echo "FAIL: shared repository checkout has uncommitted changes"; exit 11; fi
PROD_BEFORE="$(prod_fingerprint)"
[[ -n "$PROD_BEFORE" ]] || { echo "FAIL: Production Setup fingerprint was empty"; exit 12; }
echo "Live Setup SHA: $SETUP_HEAD_BEFORE"
echo "Production Setup fingerprint before: $PROD_BEFORE"

echo
echo "--- Fetch exact candidate and prove forward ancestry ---"
sudo git -C "$REPO_ROOT" fetch origin "$TARGET_REF"
sudo git -C "$REPO_ROOT" cat-file -e "$TARGET_SHA^{commit}"
if ! sudo git -C "$REPO_ROOT" merge-base --is-ancestor "$SETUP_HEAD_BEFORE" "$TARGET_SHA"; then echo "FAIL: candidate is not a forward descendant of live Setup"; exit 13; fi
sudo git -C "$REPO_ROOT" worktree add --detach "$CANDIDATE_WORKTREE" "$TARGET_SHA"
for rel in "${MIGRATIONS[@]}" "${VALIDATIONS[@]}"; do
    [[ -z "$rel" ]] && continue
    [[ -s "$CANDIDATE_WORKTREE/$rel" ]] || { echo "FAIL: exact candidate is missing required file: $rel"; exit 14; }
done

echo
echo "--- Exact candidate regression ---"
sudo -u fieldwiring -H env PYTHONPYCACHEPREFIX="$PYCACHE" bash -c "cd '$CANDIDATE_WORKTREE' && '$PYTHON' -m pytest -q -p no:cacheprovider Setup/Application"
echo "PASS: exact candidate Setup/Application regression"

echo
echo "--- Capture current Production into disposable clone ---"
sudo docker exec "$PROD_CONTAINER" pg_dump -U "$DB_ACTOR" -d "$PROD_DB" -Fc > "$DUMP_FILE"
test -s "$DUMP_FILE"
sudo docker exec -i "$PROD_CONTAINER" pg_restore --list < "$DUMP_FILE" >/dev/null
echo "Production dump captured: $(du -h "$DUMP_FILE" | awk '{print $1}')"

sudo docker run -d --name "$TEST_CONTAINER" --network "$NETWORK" -e POSTGRES_USER="$DB_ACTOR" -e POSTGRES_PASSWORD="$TEST_PASSWORD" -e POSTGRES_DB=postgres "$IMAGE" >/dev/null
ready=0
pid1=""
for _ in $(seq 1 120); do
    if [[ "$(sudo docker inspect "$TEST_CONTAINER" --format '{{.State.Running}}' 2>/dev/null || true)" != "true" ]]; then break; fi
    pid1="$(sudo docker exec "$TEST_CONTAINER" sh -c 'cat /proc/1/comm' 2>/dev/null | tr -d '\r\n' || true)"
    if [[ "$pid1" == "postgres" ]] && sudo docker exec -e PGPASSWORD="$TEST_PASSWORD" "$TEST_CONTAINER" pg_isready -U "$DB_ACTOR" -d postgres >/dev/null 2>&1; then ready=1; break; fi
    sleep 1
done
if [[ "$ready" -ne 1 ]]; then echo "FAIL: disposable PostgreSQL did not reach final post-init ready state"; echo "Observed PID 1 command: ${pid1:-unknown}"; sudo docker logs "$TEST_CONTAINER" || true; exit 15; fi

sudo docker exec -e PGPASSWORD="$TEST_PASSWORD" "$TEST_CONTAINER" createdb -U "$DB_ACTOR" -T template0 "$TEST_DB"
sudo docker exec -i -e PGPASSWORD="$TEST_PASSWORD" "$TEST_CONTAINER" pg_restore -U "$DB_ACTOR" -d "$TEST_DB" --no-owner --no-acl --exit-on-error < "$DUMP_FILE"
echo "Disposable current-Production clone restored"

psql_test() { sudo docker exec -i -e PGPASSWORD="$TEST_PASSWORD" "$TEST_CONTAINER" psql -X -v ON_ERROR_STOP=1 -U "$DB_ACTOR" -d "$TEST_DB" "$@"; }

echo
echo "--- Recreate current Production application-role boundary ---"
psql_test -c "CREATE ROLE fieldwiring_app LOGIN PASSWORD '$APP_PASSWORD';"
sudo docker exec "$PROD_CONTAINER" psql -X -qAt -v ON_ERROR_STOP=1 -U "$DB_ACTOR" -d "$PROD_DB" -c "
    SELECT format('GRANT USAGE ON SCHEMA %I TO fieldwiring_app;', n.nspname)
    FROM pg_namespace n
    WHERE n.nspname IN ('ref','lor_snap','ops','public') AND has_schema_privilege('fieldwiring_app', n.oid, 'USAGE')
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
psql_test -c "ALTER ROLE fieldwiring_app SET default_transaction_read_only = on;"

echo
echo "--- Apply candidate migrations to disposable clone only ---"
for rel in "${MIGRATIONS[@]}"; do
    [[ -z "$rel" ]] && continue
    echo "Applying: $rel"
    psql_test < "$CANDIDATE_WORKTREE/$rel"
done

echo
echo "--- Run candidate validation SQL on disposable clone ---"
for rel in "${VALIDATIONS[@]}"; do
    [[ -z "$rel" ]] && continue
    echo "Validating: $rel"
    psql_test < "$CANDIDATE_WORKTREE/$rel"
done

echo
echo "SETUP_REUSABLE_DISPOSABLE_ACCEPTANCE_PASS"
