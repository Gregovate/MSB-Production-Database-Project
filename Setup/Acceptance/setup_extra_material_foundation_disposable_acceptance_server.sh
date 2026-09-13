#!/usr/bin/env bash
set -euo pipefail

# Issue #167 — current-Production disposable Extra Material acceptance.
# Authority: MSB-Server-Management PostgreSQL_Disposable_Acceptance_Standard.md.
# Production PostgreSQL is pg_dump + SELECT only; candidate writes are disposable only.

PROD_CONTAINER="msb-postgres"
PROD_DB="msb"
DB_ACTOR="msbadmin"
IMAGE="postgis/postgis:16-3.5"
NETWORK="msb-stack_default"
TEST_DB="msb_setup_167_acceptance"
BUNDLE_DIR="${1:?bundle directory is required}"
CANDIDATE_SHA="${2:?candidate SHA is required}"
STAMP="$(date +%Y%m%dT%H%M%S)"
TEST_CONTAINER="msb-setup-167-acceptance-${$}"
TEST_PASSWORD="setup-167-${$}-$(date +%s)"
DUMP_FILE="/tmp/msb-setup-167-production-${STAMP}-${$}.dump"
REPORT_DIR="$HOME/setup-acceptance-reports"
REPORT="$REPORT_DIR/Setup_167_Extra_Material_Disposable_${STAMP}.txt"

M032="$BUNDLE_DIR/Setup/Database/032_add_setup_extra_material_schema.sql"
M033="$BUNDLE_DIR/Setup/Database/033_add_setup_extra_material_manager_commands.sql"
M034="$BUNDLE_DIR/Setup/Database/034_add_setup_extra_material_container_commands.sql"
M035="$BUNDLE_DIR/Setup/Database/035_add_setup_extra_material_inventory_commands.sql"
M036="$BUNDLE_DIR/Setup/Database/036_seed_setup_extra_material_catalog.sql"
M037="$BUNDLE_DIR/Setup/Database/037_harden_setup_extra_material_duplicate_rows.sql"
VALIDATION="$BUNDLE_DIR/Setup/Acceptance/setup_extra_material_foundation_disposable_validation.sql"
PROD_BEFORE=""

mkdir -p "$REPORT_DIR"
exec > >(tee "$REPORT") 2>&1

echo "========== SETUP #167 EXTRA MATERIAL DISPOSABLE ACCEPTANCE =========="
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
                coalesce((SELECT string_agg(row_to_json(tr)::text, '' ORDER BY tr.setup_task_id, tr.setup_resource_id) FROM ref.setup_task_resource tr), '') || '|' ||
                coalesce((SELECT string_agg(row_to_json(s)::text, '' ORDER BY s.setup_session_id) FROM ops.setup_session s), '') || '|' ||
                coalesce((SELECT string_agg(row_to_json(st)::text, '' ORDER BY st.setup_session_task_id) FROM ops.setup_session_task st), '') || '|' ||
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
required_files=("$M032" "$M033" "$M034" "$M035" "$M036" "$M037" "$VALIDATION")
for file in "${required_files[@]}"; do
    [[ -s "$file" ]] || { echo "FAIL: required acceptance file missing: $file"; exit 2; }
done

sudo docker inspect "$PROD_CONTAINER" >/dev/null 2>&1 || { echo "FAIL: Production PostgreSQL container was not found"; exit 3; }
[[ "$(sudo docker inspect "$PROD_CONTAINER" --format '{{.Config.Image}}')" == "$IMAGE" ]] || { echo "FAIL: Production PostgreSQL image is not $IMAGE"; exit 4; }
sudo docker network inspect "$NETWORK" >/dev/null 2>&1 || { echo "FAIL: Docker network $NETWORK was not found"; exit 5; }
if sudo docker inspect "$TEST_CONTAINER" >/dev/null 2>&1; then
    echo "FAIL: disposable container name already exists: $TEST_CONTAINER"
    exit 6
fi

echo "--- Exact candidate file hashes ---"
sha256sum "${required_files[@]}"

PROD_BEFORE="$(prod_fingerprint)"
[[ -n "$PROD_BEFORE" ]] || { echo "FAIL: Production Setup fingerprint was empty"; exit 7; }
echo "Production Setup fingerprint before: $PROD_BEFORE"

echo
echo "--- Capture current Production into disposable clone ---"
sudo docker exec "$PROD_CONTAINER" pg_dump -U "$DB_ACTOR" -d "$PROD_DB" -Fc > "$DUMP_FILE"
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

ready=0
pid1=""
for _ in $(seq 1 120); do
    [[ "$(sudo docker inspect "$TEST_CONTAINER" --format '{{.State.Running}}' 2>/dev/null || true)" == "true" ]] || break
    pid1="$(sudo docker exec "$TEST_CONTAINER" sh -c 'cat /proc/1/comm' 2>/dev/null | tr -d '\r\n' || true)"
    if [[ "$pid1" == "postgres" ]] && sudo docker exec -e PGPASSWORD="$TEST_PASSWORD" "$TEST_CONTAINER" pg_isready -U "$DB_ACTOR" -d postgres >/dev/null 2>&1; then
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

sudo docker exec -e PGPASSWORD="$TEST_PASSWORD" "$TEST_CONTAINER" createdb -U "$DB_ACTOR" -T template0 "$TEST_DB"
sudo docker exec -i -e PGPASSWORD="$TEST_PASSWORD" "$TEST_CONTAINER" \
    pg_restore -U "$DB_ACTOR" -d "$TEST_DB" --no-owner --no-acl --exit-on-error < "$DUMP_FILE"
echo "Disposable current-Production clone restored"

psql_test() {
    sudo docker exec -e PGPASSWORD="$TEST_PASSWORD" "$TEST_CONTAINER" \
        psql -X -v ON_ERROR_STOP=1 -U "$DB_ACTOR" -d "$TEST_DB" "$@"
}

# Database dumps do not carry cluster-level roles.
psql_test -c "DO \$role\$ BEGIN IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname='fieldwiring_app') THEN CREATE ROLE fieldwiring_app LOGIN; END IF; END \$role\$;"

echo
echo "--- Apply exact #167 candidate migrations to disposable clone only ---"
for migration in "$M032" "$M033" "$M034" "$M035" "$M036" "$M037"; do
    echo "Applying $(basename "$migration")"
    # Current disposable standard: direct host-file stdin into psql in the test container.
    sudo docker exec -i -e PGPASSWORD="$TEST_PASSWORD" "$TEST_CONTAINER" \
        psql -X -v ON_ERROR_STOP=1 -U "$DB_ACTOR" -d "$TEST_DB" < "$migration"
done

echo
echo "--- Run transactional #167 assertions ---"
sudo docker exec -i -e PGPASSWORD="$TEST_PASSWORD" "$TEST_CONTAINER" \
    psql -X -v ON_ERROR_STOP=1 -U "$DB_ACTOR" -d "$TEST_DB" < "$VALIDATION"

echo
echo "--- Post-validation state ---"
psql_test -c "
    SELECT
        (SELECT count(*) FROM ref.setup_extra_material WHERE active_flag) AS active_catalog_rows,
        (SELECT count(*) FROM ops.setup_session WHERE season_year=2026) AS setup_2026_sessions,
        has_table_privilege('fieldwiring_app','ref.setup_extra_material','INSERT') AS broad_catalog_insert,
        has_table_privilege('fieldwiring_app','ops.setup_extra_material_inventory_event','UPDATE') AS broad_inventory_update;
"

echo
echo "DISPOSABLE_SETUP_167_EXTRA_MATERIAL_ACCEPTANCE_PASS"
