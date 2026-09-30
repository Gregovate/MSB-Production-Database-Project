#!/usr/bin/env bash
set -euo pipefail

PROD_CONTAINER="msb-postgres"
PROD_DB="msb"
DB_ACTOR="msbadmin"
IMAGE="postgis/postgis:16-3.5"
NETWORK="msb-stack_default"
REPO_ROOT="/opt/fieldwiring"
PYTHON="/opt/fieldwiring/.venv/bin/python"

TARGET_SHA="${1:?candidate SHA is required}"
TARGET_REF="${2:?target ref is required}"
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

MIGRATION_REL="Database/Basic_Query_Tools_Dev/Repair-SetActorOnUpdate-Attribution.sql"
VALIDATION_REL="Database/Acceptance/database_shared_audit_actor_disposable_validation.sql"
CONTRACT_TEST_REL="Setup/Application/test_shared_audit_actor_contract.py"

STAMP="$(date +%Y%m%dT%H%M%S)"
TEST_CONTAINER="msb-database-audit-actor-${$}"
TEST_DB="msb_database_audit_actor"
TEST_PASSWORD="audit-actor-${$}-$(date +%s)"
DUMP_FILE="/tmp/msb-database-audit-actor-${STAMP}-${$}.dump"
CANDIDATE_WORKTREE="/tmp/msb-database-audit-actor-candidate-${STAMP}"
PYCACHE="/tmp/msb-database-audit-actor-pycache-${STAMP}"
REPORT_DIR="$HOME/database-acceptance-reports"
REPORT="$REPORT_DIR/Database_Shared_Audit_Actor_Disposable_${STAMP}.txt"
PROD_BEFORE=""

mkdir -p "$REPORT_DIR"
exec > >(tee "$REPORT") 2>&1

prod_audit_fingerprint() {
    sudo docker exec "$PROD_CONTAINER" \
        psql -X -qAt -v ON_ERROR_STOP=1 -U "$DB_ACTOR" -d "$PROD_DB" -c "
            WITH function_state AS (
                SELECT string_agg(
                    p.proname || ':' || md5(pg_get_functiondef(p.oid)),
                    '|' ORDER BY p.proname
                ) AS value
                FROM pg_proc AS p
                JOIN pg_namespace AS n
                  ON n.oid = p.pronamespace
                WHERE n.nspname = 'ref'
                  AND p.proname IN (
                      'resolve_actor',
                      'set_actor_on_insert',
                      'set_actor_on_update',
                      'set_updated_fields',
                      'sync_audit_collection_policy'
                  )
            ),
            policy_state AS (
                SELECT string_agg(
                    row_to_json(a)::text,
                    '|' ORDER BY a.audit_collection_policy_id
                ) AS value
                FROM ref.audit_collection_policy AS a
            ),
            target_column_state AS (
                SELECT string_agg(
                    concat_ws(
                        ':',
                        c.table_schema,
                        c.table_name,
                        c.ordinal_position::text,
                        c.column_name,
                        c.data_type,
                        c.is_nullable,
                        coalesce(c.column_default, '')
                    ),
                    '|' ORDER BY c.table_schema, c.table_name, c.ordinal_position
                ) AS value
                FROM information_schema.columns AS c
                WHERE (c.table_schema, c.table_name) IN (
                    ('ops', 'work_order_status_history'),
                    ('ref', 'task_type'),
                    ('ref', 'work_area')
                )
            ),
            trigger_state AS (
                SELECT string_agg(
                    n.nspname || '.' || c.relname || ':' ||
                    t.tgname || ':' || pg_get_triggerdef(t.oid, true),
                    '|' ORDER BY n.nspname, c.relname, t.tgname
                ) AS value
                FROM pg_trigger AS t
                JOIN pg_proc AS p
                  ON p.oid = t.tgfoid
                JOIN pg_class AS c
                  ON c.oid = t.tgrelid
                JOIN pg_namespace AS n
                  ON n.oid = c.relnamespace
                WHERE NOT t.tgisinternal
                  AND p.proname IN (
                      'set_actor_on_insert',
                      'set_actor_on_update',
                      'set_updated_fields'
                  )
            )
            SELECT md5(
                coalesce((SELECT value FROM function_state), '') || '|' ||
                coalesce((SELECT value FROM policy_state), '') || '|' ||
                coalesce((SELECT value FROM target_column_state), '') || '|' ||
                coalesce((SELECT value FROM trigger_state), '')
            );
        "
}

cleanup() {
    status=$?
    trap - EXIT HUP INT TERM
    set +e

    echo
    echo "--- Database-wide audit acceptance cleanup ---"
    sudo docker rm -f "$TEST_CONTAINER" >/dev/null 2>&1 || true
    if sudo git -C "$REPO_ROOT" worktree list --porcelain 2>/dev/null | grep -Fq "worktree $CANDIDATE_WORKTREE"; then
        sudo git -C "$REPO_ROOT" worktree remove --force "$CANDIDATE_WORKTREE" >/dev/null 2>&1 || true
    fi
    sudo git -C "$REPO_ROOT" worktree prune >/dev/null 2>&1 || true
    rm -f "$DUMP_FILE" >/dev/null 2>&1 || true
    sudo rm -rf "$PYCACHE" >/dev/null 2>&1 || true
    rm -rf "$SCRIPT_DIR" >/dev/null 2>&1 || true

    echo "--- Production audit-contract after-check ---"
    if [[ -n "$PROD_BEFORE" ]]; then
        PROD_AFTER="$(prod_audit_fingerprint 2>/dev/null)"
        echo "Production audit-contract fingerprint before: $PROD_BEFORE"
        echo "Production audit-contract fingerprint after:  $PROD_AFTER"
        if [[ -z "$PROD_AFTER" || "$PROD_AFTER" != "$PROD_BEFORE" ]]; then
            echo "FAIL: Production shared audit contract changed"
            status=97
        else
            echo "PASS: Production shared audit contract unchanged"
        fi
    else
        echo "SKIP: Production audit-contract fingerprint was not captured before failure"
    fi

    echo "Report retained at: $REPORT"
    echo "Exit status: $status"
    exit "$status"
}
trap cleanup EXIT HUP INT TERM

echo "========== DATABASE-WIDE SHARED AUDIT ACTOR DISPOSABLE ACCEPTANCE =========="
echo "Authority: Gregovate/MSB-Server-Management — docs/server/PostgreSQL_Disposable_Acceptance_Standard.md"
echo "Candidate SHA: $TARGET_SHA"
echo "Target ref:    $TARGET_REF"
echo "Migration:     $MIGRATION_REL"
echo "Validation:    $VALIDATION_REL"
echo "Production DB: pg_dump + SELECT only"
echo "Candidate writes: disposable current-Production clone only"
echo "Report:        $REPORT"
echo

sudo -v

if ! sudo docker inspect "$PROD_CONTAINER" >/dev/null 2>&1; then
    echo "FAIL: Production PostgreSQL container was not found"
    exit 10
fi
if [[ "$(sudo docker inspect "$PROD_CONTAINER" --format '{{.Config.Image}}')" != "$IMAGE" ]]; then
    echo "FAIL: Production PostgreSQL image is not $IMAGE"
    exit 11
fi
if ! sudo docker network inspect "$NETWORK" >/dev/null 2>&1; then
    echo "FAIL: Docker network $NETWORK was not found"
    exit 12
fi
if ! sudo -u fieldwiring -H test -x "$PYTHON"; then
    echo "FAIL: documented shared Python runtime is unavailable"
    exit 13
fi
if [[ -n "$(sudo git -C "$REPO_ROOT" status --porcelain)" ]]; then
    echo "FAIL: shared repository checkout has uncommitted changes"
    exit 14
fi

PROD_BEFORE="$(prod_audit_fingerprint)"
if [[ -z "$PROD_BEFORE" ]]; then
    echo "FAIL: Production audit-contract fingerprint was empty"
    exit 15
fi
echo "Production audit-contract fingerprint before: $PROD_BEFORE"

echo
echo "--- Observe current Production Directus/shared-audit gaps ---"
DIRECTUS_GAPS="$(sudo docker exec "$PROD_CONTAINER" \
    psql -X -qAt -v ON_ERROR_STOP=1 -U "$DB_ACTOR" -d "$PROD_DB" -c "
        WITH shared_update_tables AS (
            SELECT DISTINCT
                n.nspname AS schema_name,
                c.relname AS table_name,
                c.oid AS table_oid
            FROM pg_trigger AS t
            JOIN pg_proc AS p
              ON p.oid = t.tgfoid
            JOIN pg_class AS c
              ON c.oid = t.tgrelid
            JOIN pg_namespace AS n
              ON n.oid = c.relnamespace
            WHERE NOT t.tgisinternal
              AND p.proname IN ('set_actor_on_update','set_updated_fields')
        )
        SELECT s.schema_name || '.' || s.table_name
        FROM shared_update_tables AS s
        WHERE has_table_privilege('directus_app', s.table_oid, 'UPDATE')
          AND (
              NOT EXISTS (
                  SELECT 1
                  FROM ref.audit_collection_policy AS a
                  WHERE a.schema_name = s.schema_name
                    AND a.collection_name = s.table_name
                    AND a.active_flag = true
                    AND a.update_actor_enabled = true
              )
              OR EXISTS (
                  SELECT 1
                  FROM (
                      VALUES
                          ('created_at'),
                          ('created_by'),
                          ('created_by_person_id'),
                          ('updated_at'),
                          ('updated_by'),
                          ('updated_by_person_id')
                  ) AS required(column_name)
                  WHERE NOT EXISTS (
                      SELECT 1
                      FROM information_schema.columns AS col
                      WHERE col.table_schema = s.schema_name
                        AND col.table_name = s.table_name
                        AND col.column_name = required.column_name
                  )
              )
          )
        ORDER BY 1;
    ")"

if [[ -n "$DIRECTUS_GAPS" ]]; then
    echo "INFO: current Production contains known Directus/shared-audit gaps that this candidate must close in the disposable clone:"
    printf '%s\n' "$DIRECTUS_GAPS"
else
    echo "INFO: current Production has no Directus/shared-audit gaps under this check"
fi

echo
echo "--- Fetch exact database candidate ---"
sudo git -C "$REPO_ROOT" fetch origin main
MAIN_SHA="$(sudo git -C "$REPO_ROOT" rev-parse FETCH_HEAD)"
sudo git -C "$REPO_ROOT" fetch origin "$TARGET_REF"
FETCHED_TARGET="$(sudo git -C "$REPO_ROOT" rev-parse FETCH_HEAD)"
sudo git -C "$REPO_ROOT" cat-file -e "$TARGET_SHA^{commit}"
if [[ "$FETCHED_TARGET" != "$TARGET_SHA" ]]; then
    echo "FAIL: fetched target ref is $FETCHED_TARGET, expected exact candidate $TARGET_SHA"
    exit 16
fi
if ! sudo git -C "$REPO_ROOT" merge-base --is-ancestor "$MAIN_SHA" "$TARGET_SHA"; then
    echo "FAIL: exact candidate is not a forward descendant of fetched current main $MAIN_SHA"
    exit 17
fi
sudo git -C "$REPO_ROOT" worktree add --detach "$CANDIDATE_WORKTREE" "$TARGET_SHA"

for rel in "$MIGRATION_REL" "$VALIDATION_REL" "$CONTRACT_TEST_REL"; do
    [[ -s "$CANDIDATE_WORKTREE/$rel" ]] || {
        echo "FAIL: exact candidate is missing required file: $rel"
        exit 18
    }
done

echo
echo "--- Exact candidate audit contract regression ---"
sudo -u fieldwiring -H env PYTHONPYCACHEPREFIX="$PYCACHE" bash -c "
    cd '$CANDIDATE_WORKTREE'
    '$PYTHON' -m pytest -q -p no:cacheprovider '$CONTRACT_TEST_REL'
"
echo "PASS: exact candidate shared audit contract regression"

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
    echo "Observed PID 1 command: ${pid1:-unknown}"
    sudo docker logs "$TEST_CONTAINER" || true
    exit 19
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

echo
echo "--- Apply database-wide shared audit repair to disposable clone only ---"
psql_test < "$CANDIDATE_WORKTREE/$MIGRATION_REL"

echo
echo "--- Run database-wide shared audit validation ---"
psql_test < "$CANDIDATE_WORKTREE/$VALIDATION_REL"

echo
echo "--- Disposable installed-function proof ---"
psql_test -c "
    SELECT
        p.oid::regprocedure AS function_signature,
        md5(pg_get_functiondef(p.oid)) AS definition_md5
    FROM pg_proc AS p
    JOIN pg_namespace AS n
      ON n.oid = p.pronamespace
    WHERE n.nspname = 'ref'
      AND p.proname IN ('resolve_actor','set_actor_on_update','set_updated_fields')
    ORDER BY p.proname;
"

echo
echo "DATABASE_SHARED_AUDIT_ACTOR_DISPOSABLE_ACCEPTANCE_PASS"
