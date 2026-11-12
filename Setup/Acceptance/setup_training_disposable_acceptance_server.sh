#!/usr/bin/env bash
set -euo pipefail

PROD_CONTAINER="msb-postgres"
PROD_DB="msb"
DB_ACTOR="msbadmin"
IMAGE="postgis/postgis:16-3.5"
NETWORK="msb-stack_default"
TEST_DB="msb_setup_training_acceptance"
BUNDLE_DIR="${1:?bundle directory is required}"
CANDIDATE_SHA="${2:?candidate SHA is required}"
STAMP="$(date +%Y%m%dT%H%M%S)"
TEST_CONTAINER="msb-setup-training-acceptance-${$}"
TEST_PASSWORD="setup-training-${$}-$(date +%s)"
DUMP_FILE="/tmp/msb-setup-training-production-${STAMP}-${$}.dump"
REPORT_DIR="$HOME/setup-acceptance-reports"
REPORT="$REPORT_DIR/Setup_Training_Disposable_${STAMP}.txt"
M019="$BUNDLE_DIR/019_add_reconstruction_safe_task_delete.sql"
M020="$BUNDLE_DIR/020_add_setup_captain_management_commands.sql"
M021="$BUNDLE_DIR/021_add_setup_assigned_reconciliation_state.sql"
M022="$BUNDLE_DIR/022_require_active_setup_captain_people.sql"
VALIDATION="$BUNDLE_DIR/setup_training_disposable_validation.sql"
PROD_BEFORE=""

mkdir -p "$REPORT_DIR"
exec > >(tee "$REPORT") 2>&1

echo "========== SETUP TRAINING / RECONSTRUCTION DISPOSABLE ACCEPTANCE =========="
echo "Candidate SHA: $CANDIDATE_SHA"
echo "Report:        $REPORT"
echo "Production DB: pg_dump + SELECT only"
echo "Test writes:   disposable PostgreSQL clone only"
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
    echo "--- Disposable cleanup ---"
    sudo docker rm -f "$TEST_CONTAINER" >/dev/null 2>&1 || true
    rm -f "$DUMP_FILE" >/dev/null 2>&1 || true
    rm -rf "$BUNDLE_DIR" >/dev/null 2>&1 || true

    echo "--- Production Setup fingerprint after-check ---"
    if [[ -n "$PROD_BEFORE" ]]; then
        PROD_AFTER="$(prod_fingerprint 2>/dev/null)"
        echo "Before: $PROD_BEFORE"
        echo "After:  $PROD_AFTER"
        if [[ -z "$PROD_AFTER" || "$PROD_AFTER" != "$PROD_BEFORE" ]]; then
            echo "FAIL: Production Setup fingerprint changed during disposable acceptance"
            status=97
        else
            echo "PASS: Production Setup fingerprint unchanged"
        fi
    else
        echo "No pre-test Production fingerprint was captured."
    fi

    echo "Report retained at: $REPORT"
    echo "Exit status: $status"
    exit "$status"
}
trap cleanup EXIT INT TERM

sudo -v

for file in "$M019" "$M020" "$M021" "$M022" "$VALIDATION"; do
    if [[ ! -s "$file" ]]; then
        echo "FAIL: required acceptance file missing: $file"
        exit 2
    fi
done

if ! sudo docker inspect "$PROD_CONTAINER" >/dev/null 2>&1; then
    echo "FAIL: Production PostgreSQL container was not found"
    exit 3
fi
if [[ "$(sudo docker inspect "$PROD_CONTAINER" --format '{{.Config.Image}}')" != "$IMAGE" ]]; then
    echo "FAIL: Production PostgreSQL image is not $IMAGE"
    exit 4
fi
if ! sudo docker network inspect "$NETWORK" >/dev/null 2>&1; then
    echo "FAIL: Docker network $NETWORK was not found"
    exit 5
fi

if sudo docker inspect "$TEST_CONTAINER" >/dev/null 2>&1; then
    echo "FAIL: disposable container name already exists: $TEST_CONTAINER"
    exit 6
fi

echo "--- Candidate migration hashes ---"
sha256sum "$M019" "$M020" "$M021" "$M022" "$VALIDATION"

PROD_BEFORE="$(prod_fingerprint)"
if [[ -z "$PROD_BEFORE" ]]; then
    echo "FAIL: Production Setup fingerprint was empty"
    exit 7
fi
echo "Production Setup fingerprint before: $PROD_BEFORE"

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
    exit 8
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
    echo "FAIL: disposable PostgreSQL did not become ready"
    exit 9
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

test_fingerprint() {
    psql_test -qAt -c "
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

psql_test <<'SQL'
DO $role$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'fieldwiring_app') THEN
        CREATE ROLE fieldwiring_app LOGIN;
    END IF;
END
$role$;
SQL

echo
echo "--- Apply candidate migrations to disposable clone only ---"
psql_test < "$M019"
echo "Migration 019 reconstruction-safe delete: PASS"
psql_test < "$M020"
echo "Migration 020 Captain management: PASS"
psql_test < "$M021"
echo "Migration 021 ASSIGNED reconciliation state: PASS"
psql_test < "$M022"
echo "Migration 022 active Captain people: PASS"

IDEMPOTENCE_BEFORE="$(test_fingerprint)"
if [[ -z "$IDEMPOTENCE_BEFORE" ]]; then
    echo "FAIL: disposable Setup fingerprint was empty before migration replay"
    exit 10
fi

echo
echo "--- Reapply candidate migrations to prove idempotence ---"
psql_test < "$M019"
echo "Migration 019 idempotence replay: PASS"
psql_test < "$M020"
echo "Migration 020 idempotence replay: PASS"
psql_test < "$M021"
echo "Migration 021 idempotence replay: PASS"
psql_test < "$M022"
echo "Migration 022 idempotence replay: PASS"

IDEMPOTENCE_AFTER="$(test_fingerprint)"
echo "Disposable governed Setup fingerprint before replay: $IDEMPOTENCE_BEFORE"
echo "Disposable governed Setup fingerprint after replay:  $IDEMPOTENCE_AFTER"
if [[ -z "$IDEMPOTENCE_AFTER" || "$IDEMPOTENCE_AFTER" != "$IDEMPOTENCE_BEFORE" ]]; then
    echo "FAIL: candidate migration replay changed governed Setup data"
    exit 10
fi
echo "PASS: migrations 019-022 replay cleanly with governed Setup data unchanged"

echo
echo "--- Run feature-specific disposable assertions ---"
psql_test < "$VALIDATION"
echo "Setup training/reconstruction disposable assertions: PASS"

echo
echo "DISPOSABLE_SETUP_TRAINING_ACCEPTANCE_PASS"
