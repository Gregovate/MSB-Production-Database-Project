#!/usr/bin/env bash
set -euo pipefail

PROD_CONTAINER="msb-postgres"
PROD_DB="msb"
DB_ACTOR="msbadmin"
IMAGE="postgis/postgis:16-3.5"
NETWORK="msb-stack_default"
TEST_CONTAINER="msb-people-restore-diag-${$}"
TEST_DB="msb"
TEST_PASSWORD="people-restore-diag-${$}-$(date +%s)"
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
DUMP_FILE="${SCRIPT_DIR}/production.dump"
REPORT="/tmp/MSB_People_Restore_Diagnostic_$(date +%Y%m%d-%H%M%S).txt"
PROD_BEFORE=""

exec > >(tee "$REPORT") 2>&1

echo "========== PEOPLE MANAGER RESTORE DIAGNOSTIC =========="
echo "Report: $REPORT"
echo "Production access: pg_dump + SELECT only"
echo "Disposable container: $TEST_CONTAINER"
echo

prod_fingerprint() {
    sudo docker exec "$PROD_CONTAINER" \
        psql -X -qAt -v ON_ERROR_STOP=1 -U "$DB_ACTOR" -d "$PROD_DB" -c "
            SELECT md5(coalesce(string_agg(row_to_json(p)::text, '' ORDER BY p.person_id), ''))
            FROM ref.person p;
        "
}

container_diagnostics() {
    echo
    echo "--- DISPOSABLE CONTAINER INSPECT ---"
    sudo docker inspect "$TEST_CONTAINER" --format \
        'status={{.State.Status}} running={{.State.Running}} exit={{.State.ExitCode}} oom={{.State.OOMKilled}} error={{.State.Error}} started={{.State.StartedAt}} finished={{.State.FinishedAt}} restart_count={{.RestartCount}}' \
        2>&1 || true

    echo
    echo "--- DISPOSABLE POSTGRES LOGS ---"
    sudo docker logs --timestamps "$TEST_CONTAINER" 2>&1 | tail -n 300 || true

    echo
    echo "--- HOST DISK ---"
    df -h || true

    echo
    echo "--- DOCKER DISK ---"
    sudo docker system df || true
}

cleanup() {
    status=$?
    trap - EXIT INT TERM
    set +e

    if [[ "$status" -ne 0 ]]; then
        container_diagnostics
    fi

    echo
    echo "--- Production after-check ---"
    if [[ -n "$PROD_BEFORE" ]]; then
        PROD_AFTER="$(prod_fingerprint)"
        echo "Before: $PROD_BEFORE"
        echo "After:  $PROD_AFTER"
        if [[ "$PROD_AFTER" != "$PROD_BEFORE" ]]; then
            echo "FAIL: production ref.person fingerprint changed"
            status=97
        else
            echo "PASS: production ref.person fingerprint unchanged"
        fi
    fi

    echo
    echo "--- Cleanup ---"
    sudo docker rm -f "$TEST_CONTAINER" >/dev/null 2>&1 || true
    rm -f "$DUMP_FILE" >/dev/null 2>&1 || true
    echo "Disposable container/dump cleanup attempted"
    echo "Report retained at: $REPORT"
    echo "Exit status: $status"
    exit "$status"
}
trap cleanup EXIT INT TERM

sudo -v

PROD_BEFORE="$(prod_fingerprint)"
echo "Production person fingerprint: $PROD_BEFORE"

echo
echo "--- Read-only production dump ---"
sudo docker exec "$PROD_CONTAINER" pg_dump -U "$DB_ACTOR" -d "$PROD_DB" -Fc > "$DUMP_FILE"
test -s "$DUMP_FILE"
sudo docker exec -i "$PROD_CONTAINER" pg_restore --list < "$DUMP_FILE" >/dev/null
echo "Dump validated: $(du -h "$DUMP_FILE" | awk '{print $1}')"

echo
echo "--- Start disposable PostgreSQL ---"
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
    exit 6
fi

sudo docker exec -e PGPASSWORD="$TEST_PASSWORD" "$TEST_CONTAINER" \
    createdb -U "$DB_ACTOR" -T template0 "$TEST_DB"
echo "Disposable PostgreSQL ready"

echo
echo "--- Restore Production clone ---"
set +e
sudo docker exec -i -e PGPASSWORD="$TEST_PASSWORD" "$TEST_CONTAINER" \
    pg_restore -U "$DB_ACTOR" -d "$TEST_DB" --no-owner --no-acl --exit-on-error \
    < "$DUMP_FILE"
RESTORE_STATUS=$?
set -e

if [[ "$RESTORE_STATUS" -ne 0 ]]; then
    echo "FAIL: pg_restore exited $RESTORE_STATUS"
    container_diagnostics
    exit "$RESTORE_STATUS"
fi

echo "Restore completed"

echo
echo "--- Clone verification ---"
sudo docker exec -e PGPASSWORD="$TEST_PASSWORD" "$TEST_CONTAINER" \
    psql -X -qAt -v ON_ERROR_STOP=1 -U "$DB_ACTOR" -d "$TEST_DB" -c \
    "SELECT 'people=' || count(*) || ', active=' || count(*) FILTER (WHERE active_flag) FROM ref.person;"

echo
echo "PEOPLE MANAGER RESTORE DIAGNOSTIC: PASS"
