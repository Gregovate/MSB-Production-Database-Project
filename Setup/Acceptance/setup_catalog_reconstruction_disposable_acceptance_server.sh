#!/usr/bin/env bash
set -euo pipefail

PROD_CONTAINER="msb-postgres"
PROD_DB="msb"
DB_ACTOR="msbadmin"
IMAGE="postgis/postgis:16-3.5"
NETWORK="msb-stack_default"
TEST_DB="msb_setup_catalog_reconstruction_acceptance"
BUNDLE_DIR="${1:?bundle directory is required}"
CANDIDATE_SHA="${2:?candidate SHA is required}"
STAMP="$(date +%Y%m%dT%H%M%S)"
TEST_CONTAINER="msb-setup-catalog-acceptance-${$}"
TEST_PASSWORD="setup-catalog-${$}-$(date +%s)"
DUMP_FILE="/tmp/msb-setup-catalog-production-${STAMP}-${$}.dump"
REPORT_DIR="$HOME/setup-acceptance-reports"
REPORT="$REPORT_DIR/Setup_Catalog_Reconstruction_Disposable_${STAMP}.txt"

M023="$BUNDLE_DIR/Setup/Database/023_add_setup_task_effort.sql"
M024="$BUNDLE_DIR/Setup/Database/024_reconstruct_setup_catalog_from_reviewed_one_list.sql"
BATCH_DIR="$BUNDLE_DIR/Setup/Database/reconstruction"
VALIDATION="$BUNDLE_DIR/Setup/Acceptance/setup_catalog_reconstruction_disposable_validation.sql"
CONTAINER_DB_DIR="/tmp/setup-catalog-db"
CONTAINER_VALIDATION="/tmp/setup_catalog_reconstruction_disposable_validation.sql"
PROD_BEFORE=""

mkdir -p "$REPORT_DIR"
exec > >(tee "$REPORT") 2>&1

echo "========== SETUP CATALOG RECONSTRUCTION DISPOSABLE ACCEPTANCE =========="
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

required_files=(
    "$M023"
    "$M024"
    "$BATCH_DIR/024_catalog_batch_01.sql"
    "$BATCH_DIR/024_catalog_batch_02.sql"
    "$BATCH_DIR/024_catalog_batch_03.sql"
    "$BATCH_DIR/024_catalog_batch_04.sql"
    "$BATCH_DIR/024_catalog_batch_05.sql"
    "$VALIDATION"
)
for file in "${required_files[@]}"; do
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

echo "--- Candidate migration/source hashes ---"
sha256sum "${required_files[@]}"

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

# postgis/postgis:16-3.5 starts a temporary PostgreSQL server during image
# initialization. pg_isready may succeed during that temporary phase, so require
# the final container PID 1 process to be postgres as well as pg_isready success.
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
    exit 8
fi

sudo docker exec -e PGPASSWORD="$TEST_PASSWORD" "$TEST_CONTAINER" \
    createdb -U "$DB_ACTOR" -T template0 "$TEST_DB"
sudo docker exec -i -e PGPASSWORD="$TEST_PASSWORD" "$TEST_CONTAINER" \
    pg_restore -U "$DB_ACTOR" -d "$TEST_DB" --no-owner --no-acl --exit-on-error \
    < "$DUMP_FILE"
echo "Disposable current-Production clone restored"

psql_test() {
    sudo docker exec -e PGPASSWORD="$TEST_PASSWORD" "$TEST_CONTAINER" \
        psql -X -v ON_ERROR_STOP=1 -U "$DB_ACTOR" -d "$TEST_DB" "$@"
}

test_fingerprint() {
    psql_test -qAt -c "
        SELECT md5(
            coalesce((SELECT string_agg(row_to_json(t)::text, '' ORDER BY t.setup_task_id) FROM ref.setup_task t), '') || '|' ||
            coalesce((SELECT string_agg(row_to_json(d)::text, '' ORDER BY d.setup_task_id, d.prerequisite_setup_task_id) FROM ref.setup_task_dependency d), '') || '|' ||
            coalesce((SELECT string_agg(row_to_json(st)::text, '' ORDER BY st.setup_session_task_id) FROM ops.setup_session_task st), '')
        );
    "
}

psql_test -c "DO \$role\$ BEGIN IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'fieldwiring_app') THEN CREATE ROLE fieldwiring_app LOGIN; END IF; END \$role\$;"

sudo docker exec "$TEST_CONTAINER" mkdir -p "$CONTAINER_DB_DIR/reconstruction"
sudo docker cp "$BUNDLE_DIR/Setup/Database/023_add_setup_task_effort.sql" \
    "$TEST_CONTAINER:$CONTAINER_DB_DIR/023_add_setup_task_effort.sql"
sudo docker cp "$BUNDLE_DIR/Setup/Database/024_reconstruct_setup_catalog_from_reviewed_one_list.sql" \
    "$TEST_CONTAINER:$CONTAINER_DB_DIR/024_reconstruct_setup_catalog_from_reviewed_one_list.sql"
for batch in "$BATCH_DIR"/*.sql; do
    sudo docker cp "$batch" "$TEST_CONTAINER:$CONTAINER_DB_DIR/reconstruction/$(basename "$batch")"
done
sudo docker cp "$VALIDATION" "$TEST_CONTAINER:$CONTAINER_VALIDATION"

echo
echo "--- Apply candidate migrations to disposable clone only ---"
psql_test -f "$CONTAINER_DB_DIR/023_add_setup_task_effort.sql"
echo "Migration 023 reusable effort metadata: PASS"
psql_test -f "$CONTAINER_DB_DIR/024_reconstruct_setup_catalog_from_reviewed_one_list.sql"
echo "Migration 024 reviewed reusable catalog reconstruction: PASS"

CATALOG_FINGERPRINT="$(test_fingerprint)"
if [[ -z "$CATALOG_FINGERPRINT" ]]; then
    echo "FAIL: disposable catalog fingerprint was empty"
    exit 10
fi

echo
echo "--- Reapply schema-only migration 023 to prove safe replay ---"
psql_test -f "$CONTAINER_DB_DIR/023_add_setup_task_effort.sql"
REPLAY_FINGERPRINT="$(test_fingerprint)"
echo "Disposable catalog fingerprint before 023 replay: $CATALOG_FINGERPRINT"
echo "Disposable catalog fingerprint after 023 replay:  $REPLAY_FINGERPRINT"
if [[ -z "$REPLAY_FINGERPRINT" || "$REPLAY_FINGERPRINT" != "$CATALOG_FINGERPRINT" ]]; then
    echo "FAIL: migration 023 replay changed governed Setup data"
    exit 11
fi
echo "PASS: migration 023 replays without data change"

echo
echo "--- Run catalog reconstruction assertions and list resulting catalog ---"
psql_test -f "$CONTAINER_VALIDATION"
echo "Setup catalog reconstruction disposable assertions: PASS"

echo
echo "DISPOSABLE_SETUP_CATALOG_RECONSTRUCTION_ACCEPTANCE_PASS"
