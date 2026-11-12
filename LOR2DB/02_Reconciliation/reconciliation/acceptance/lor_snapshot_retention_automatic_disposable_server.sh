#!/usr/bin/env bash
set -euo pipefail

PROD_CONTAINER="msb-postgres"
PROD_DB="msb"
DB_ACTOR="msbadmin"
IMAGE="postgis/postgis:16-3.5"
NETWORK="msb-stack_default"
REPO_ROOT="/opt/fieldwiring"
KEEP_COMPLETED=5
MIGRATION_REL="LOR2DB/02_Reconciliation/reconciliation/migrations/0042_decouple_snapshot_provenance_and_add_retention.sql"
VALIDATION_REL="LOR2DB/02_Reconciliation/reconciliation/validation/37_lor_snapshot_retention_validation.sql"

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
MANIFEST="${1:?manifest path is required}"
[[ -s "$MANIFEST" ]] || { echo "FAIL: acceptance manifest is missing: $MANIFEST"; exit 2; }

TARGET_SHA=""
TARGET_REF=""
while IFS=$'\t' read -r kind value extra; do
    [[ -z "$kind" ]] && continue
    [[ "$kind" == \#* ]] && continue
    [[ -z "${extra:-}" ]] || { echo "FAIL: malformed manifest line for $kind"; exit 3; }
    case "$kind" in
        candidate_sha) TARGET_SHA="$value" ;;
        target_ref) TARGET_REF="$value" ;;
        *) echo "FAIL: unsupported manifest key: $kind"; exit 3 ;;
    esac
done < "$MANIFEST"

: "${TARGET_SHA:?manifest candidate_sha is required}"
: "${TARGET_REF:?manifest target_ref is required}"

STAMP="$(date +%Y%m%dT%H%M%S)"
TEST_CONTAINER="msb-lor-auto-retention-${$}"
TEST_DB="msb_lor_auto_retention_acceptance"
TEST_PASSWORD="lor-auto-retention-${$}-$(date +%s)"
DUMP_BEFORE="/tmp/msb-lor-auto-retention-before-${STAMP}-${$}.dump"
DUMP_AFTER="/tmp/msb-lor-auto-retention-after-${STAMP}-${$}.dump"
CANDIDATE_WORKTREE="/tmp/msb-lor-auto-retention-candidate-${STAMP}"
REPORT_DIR="$HOME/lor2db-acceptance-reports"
REPORT="$REPORT_DIR/LOR_Snapshot_Automatic_Retention_Disposable_Acceptance_${STAMP}.txt"
PROD_BEFORE=""
LIVE_HEAD_BEFORE=""

mkdir -p "$REPORT_DIR"
exec > >(tee "$REPORT") 2>&1

echo "========== LOR AUTOMATIC SNAPSHOT RETENTION DISPOSABLE ACCEPTANCE =========="
echo "Authority: Gregovate/MSB-Server-Management — docs/server/PostgreSQL_Disposable_Acceptance_Standard.md"
echo "Issue:          #186"
echo "Candidate SHA:  $TARGET_SHA"
echo "Target ref:     $TARGET_REF"
echo "Production DB:  pg_dump + SELECT only"
echo "All writes:     disposable current-Production clone only"
echo "Report:         $REPORT"
echo

prod_fingerprint() {
    sudo docker exec "$PROD_CONTAINER" \
        psql -X -qAt -v ON_ERROR_STOP=1 -U "$DB_ACTOR" -d "$PROD_DB" -c "
            SELECT md5(
                coalesce((
                    SELECT string_agg(row_to_json(ir)::text, '' ORDER BY ir.import_run_id)
                    FROM lor_snap.import_run AS ir
                ), '') || '|' ||
                coalesce((
                    SELECT string_agg(row_to_json(r)::text, '' ORDER BY r.lor_reconciliation_run_id)
                    FROM ops.lor_reconciliation_run AS r
                ), '')
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
    rm -f "$DUMP_BEFORE" "$DUMP_AFTER" >/dev/null 2>&1 || true
    rm -rf "$SCRIPT_DIR" >/dev/null 2>&1 || true

    echo "--- Production after-check ---"
    if [[ -n "$PROD_BEFORE" ]]; then
        PROD_AFTER="$(prod_fingerprint 2>/dev/null)"
        echo "Production fingerprint before: $PROD_BEFORE"
        echo "Production fingerprint after:  $PROD_AFTER"
        if [[ -z "$PROD_AFTER" || "$PROD_AFTER" != "$PROD_BEFORE" ]]; then
            echo "FAIL: Production database fingerprint changed during disposable automatic-retention acceptance"
            status=97
        else
            echo "PASS: Production database fingerprint unchanged"
        fi
    fi

    if [[ -n "$LIVE_HEAD_BEFORE" ]]; then
        LIVE_HEAD_AFTER="$(sudo git -C "$REPO_ROOT" rev-parse HEAD 2>/dev/null)"
        echo "Shared checkout SHA before: $LIVE_HEAD_BEFORE"
        echo "Shared checkout SHA after:  $LIVE_HEAD_AFTER"
        if [[ -z "$LIVE_HEAD_AFTER" || "$LIVE_HEAD_AFTER" != "$LIVE_HEAD_BEFORE" ]]; then
            echo "FAIL: live shared checkout changed during disposable automatic-retention acceptance"
            status=98
        else
            echo "PASS: live shared checkout unchanged"
        fi
    fi

    echo "Acceptance report retained at: $REPORT"
    echo "Exit status: $status"
    exit "$status"
}
trap cleanup EXIT HUP INT TERM

sudo -v

sudo docker inspect "$PROD_CONTAINER" >/dev/null
[[ "$(sudo docker inspect "$PROD_CONTAINER" --format '{{.Config.Image}}')" == "$IMAGE" ]] || {
    echo "FAIL: Production PostgreSQL image is not $IMAGE"; exit 5;
}
sudo docker network inspect "$NETWORK" >/dev/null
[[ -z "$(sudo git -C "$REPO_ROOT" status --porcelain)" ]] || {
    echo "FAIL: shared repository checkout has uncommitted changes"; exit 6;
}

LIVE_HEAD_BEFORE="$(sudo git -C "$REPO_ROOT" rev-parse HEAD)"
PROD_BEFORE="$(prod_fingerprint)"
[[ -n "$PROD_BEFORE" ]] || { echo "FAIL: Production fingerprint was empty"; exit 7; }

echo "Shared checkout SHA: $LIVE_HEAD_BEFORE"
echo "Production fingerprint before: $PROD_BEFORE"

echo
echo "--- Fetch exact candidate and prove ancestry ---"
sudo git -C "$REPO_ROOT" fetch origin \
    "+refs/heads/main:refs/remotes/origin/main" \
    "+refs/heads/$TARGET_REF:refs/remotes/origin/$TARGET_REF"
sudo git -C "$REPO_ROOT" cat-file -e "$TARGET_SHA^{commit}"
sudo git -C "$REPO_ROOT" merge-base --is-ancestor origin/main "$TARGET_SHA" || {
    echo "FAIL: candidate is not a forward descendant of current origin/main"; exit 8;
}
sudo git -C "$REPO_ROOT" merge-base --is-ancestor "$LIVE_HEAD_BEFORE" "$TARGET_SHA" || {
    echo "FAIL: candidate is not a forward descendant of the live shared checkout"; exit 9;
}
sudo git -C "$REPO_ROOT" worktree add --detach "$CANDIDATE_WORKTREE" "$TARGET_SHA"

for rel in "$MIGRATION_REL" "$VALIDATION_REL"; do
    [[ -s "$CANDIDATE_WORKTREE/$rel" ]] || {
        echo "FAIL: exact candidate is missing required file: $rel"; exit 10;
    }
done

echo
echo "--- Capture current Production into disposable clone ---"
sudo docker exec "$PROD_CONTAINER" pg_dump -U "$DB_ACTOR" -d "$PROD_DB" -Fc > "$DUMP_BEFORE"
test -s "$DUMP_BEFORE"
sudo docker exec -i "$PROD_CONTAINER" pg_restore --list < "$DUMP_BEFORE" >/dev/null
BEFORE_BYTES="$(stat -c %s "$DUMP_BEFORE")"
echo "Production dump captured: $(du -h "$DUMP_BEFORE" | awk '{print $1}') ($BEFORE_BYTES bytes)"

sudo docker run -d \
    --name "$TEST_CONTAINER" \
    --network "$NETWORK" \
    -e POSTGRES_USER="$DB_ACTOR" \
    -e POSTGRES_PASSWORD="$TEST_PASSWORD" \
    -e POSTGRES_DB=postgres \
    "$IMAGE" >/dev/null

ready=0
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
[[ "$ready" -eq 1 ]] || {
    echo "FAIL: disposable PostgreSQL did not reach final post-init ready state"
    sudo docker logs "$TEST_CONTAINER" || true
    exit 11
}

sudo docker exec -e PGPASSWORD="$TEST_PASSWORD" "$TEST_CONTAINER" \
    createdb -U "$DB_ACTOR" -T template0 "$TEST_DB"
sudo docker exec -i -e PGPASSWORD="$TEST_PASSWORD" "$TEST_CONTAINER" \
    pg_restore -U "$DB_ACTOR" -d "$TEST_DB" --no-owner --no-acl --exit-on-error \
    < "$DUMP_BEFORE"
echo "Disposable current-Production clone restored"

psql_test() {
    sudo docker exec -i -e PGPASSWORD="$TEST_PASSWORD" "$TEST_CONTAINER" \
        psql -X -v ON_ERROR_STOP=1 -U "$DB_ACTOR" -d "$TEST_DB" "$@"
}

LATEST_BEFORE="$(psql_test -qAt -c "SELECT max(import_run_id) FROM lor_snap.import_run WHERE ingest_completed_at IS NOT NULL;")"
RUN_COUNT_BEFORE="$(psql_test -qAt -c "SELECT count(*) FROM lor_snap.import_run;")"

echo
echo "--- Apply candidate migration and validation to disposable clone ---"
psql_test < "$CANDIDATE_WORKTREE/$MIGRATION_REL"
psql_test < "$CANDIDATE_WORKTREE/$VALIDATION_REL"

NATURAL_BLOCK_COUNT="$(psql_test -qAt -c "SELECT count(*) FROM ops.f_lor_snapshot_retention_plan(5) WHERE retention_disposition = 'BLOCK';")"
if [[ "$NATURAL_BLOCK_COUNT" != "0" ]]; then
    echo "FAIL: current Production clone contains $NATURAL_BLOCK_COUNT naturally BLOCKed snapshot(s); automatic cleanup must remain disabled until reviewed"
    psql_test -P pager=off -c "SELECT * FROM ops.f_lor_snapshot_retention_plan(5) WHERE retention_disposition = 'BLOCK' ORDER BY import_run_id;"
    exit 12
fi

OPEN_COUNT="$(psql_test -qAt -c "
    SELECT count(*)
    FROM ops.lor_reconciliation_run
    WHERE status IN ('STARTING','PREFLIGHT','AWAITING_DECISIONS','READY_TO_FINISH','PROMOTING','VALIDATING','REPORTING');
")"

if [[ "$OPEN_COUNT" == "0" ]]; then
    PROTECTED_TEST_IMPORT="$(psql_test -qAt -c "
        SELECT import_run_id
        FROM ops.f_lor_snapshot_retention_plan(5)
        WHERE retention_disposition = 'PRUNE'
        ORDER BY import_run_id
        LIMIT 1;
    ")"
    [[ -n "$PROTECTED_TEST_IMPORT" ]] || { echo "FAIL: no PRUNE candidate exists for non-terminal protection proof"; exit 13; }
    psql_test -c "
        INSERT INTO ops.lor_reconciliation_run (import_run_id, status, started_by_application)
        VALUES ($PROTECTED_TEST_IMPORT, 'AWAITING_DECISIONS', 'snapshot-retention-automatic-disposable-test');
    "
    echo "Created clone-only non-terminal protection case on import $PROTECTED_TEST_IMPORT"
else
    PROTECTED_TEST_IMPORT="$(psql_test -qAt -c "
        SELECT import_run_id
        FROM ops.lor_reconciliation_run
        WHERE status IN ('STARTING','PREFLIGHT','AWAITING_DECISIONS','READY_TO_FINISH','PROMOTING','VALIDATING','REPORTING')
        ORDER BY import_run_id LIMIT 1;
    ")"
    echo "Using existing non-terminal protection case on import $PROTECTED_TEST_IMPORT"
fi

PROTECTED_REASON="$(psql_test -qAt -c "SELECT retention_reason FROM ops.f_lor_snapshot_retention_plan(5) WHERE import_run_id = $PROTECTED_TEST_IMPORT;")"
[[ "$PROTECTED_REASON" == "NON_TERMINAL_RECONCILIATION" ]] || {
    echo "FAIL: non-terminal reconciliation import is not protected"; exit 14;
}

echo
echo "--- Prove automatic retention fails closed on BLOCK ---"
BLOCK_TEST_IMPORT="$(psql_test -qAt -c "
    SELECT import_run_id
    FROM ops.f_lor_snapshot_retention_plan(5)
    WHERE retention_disposition = 'PRUNE'
      AND retention_reason = 'LEGACY_PRE_COMPLETION_TRACKING_SNAPSHOT'
    ORDER BY import_run_id
    LIMIT 1;
")"
[[ -n "$BLOCK_TEST_IMPORT" ]] || { echo "FAIL: no legacy PRUNE candidate exists for synthetic BLOCK proof"; exit 15; }

psql_test -c "UPDATE lor_snap.import_run SET parser_version = 'snapshot-retention-block-test' WHERE import_run_id = $BLOCK_TEST_IMPORT;"
BLOCK_REASON="$(psql_test -qAt -c "SELECT retention_reason FROM ops.f_lor_snapshot_retention_plan(5) WHERE import_run_id = $BLOCK_TEST_IMPORT;")"
[[ "$BLOCK_REASON" == "INCOMPLETE_INGEST_REQUIRES_REVIEW" ]] || {
    echo "FAIL: synthetic modern incomplete row did not become BLOCK"; exit 16;
}

if psql_test -c "CALL ops.p_run_lor_snapshot_retention();" >/dev/null 2>&1; then
    echo "FAIL: automatic retention succeeded while a BLOCK row existed"
    exit 17
else
    echo "PASS: automatic retention rejected BLOCK state before deletion"
fi

[[ "$(psql_test -qAt -c "SELECT count(*) FROM lor_snap.import_run;")" == "$RUN_COUNT_BEFORE" ]] || {
    echo "FAIL: BLOCK rejection changed import_run count"; exit 18;
}

psql_test -c "UPDATE lor_snap.import_run SET parser_version = NULL WHERE import_run_id = $BLOCK_TEST_IMPORT;"
RESTORED_REASON="$(psql_test -qAt -c "SELECT retention_reason FROM ops.f_lor_snapshot_retention_plan(5) WHERE import_run_id = $BLOCK_TEST_IMPORT;")"
[[ "$RESTORED_REASON" == "LEGACY_PRE_COMPLETION_TRACKING_SNAPSHOT" ]] || {
    echo "FAIL: synthetic BLOCK row did not return to legacy PRUNE classification"; exit 19;
}

EXPECTED_PRUNE_COUNT="$(psql_test -qAt -c "SELECT count(*) FROM ops.f_lor_snapshot_retention_plan(5) WHERE retention_disposition = 'PRUNE';")"
[[ "$EXPECTED_PRUNE_COUNT" -gt 0 ]] || { echo "FAIL: no PRUNE candidates remain for destructive automatic-retention proof"; exit 20; }

echo
echo "--- Execute fixed-policy automatic retention on disposable clone ---"
psql_test -P pager=off -c "CALL ops.p_run_lor_snapshot_retention();"

LATEST_AFTER="$(psql_test -qAt -c "SELECT max(import_run_id) FROM lor_snap.import_run WHERE ingest_completed_at IS NOT NULL;")"
RUN_COUNT_AFTER="$(psql_test -qAt -c "SELECT count(*) FROM lor_snap.import_run;")"
[[ "$LATEST_AFTER" == "$LATEST_BEFORE" ]] || { echo "FAIL: latest completed import changed: $LATEST_BEFORE -> $LATEST_AFTER"; exit 21; }
[[ "$(psql_test -qAt -c "SELECT count(*) FROM lor_snap.import_run WHERE import_run_id = $PROTECTED_TEST_IMPORT;")" == "1" ]] || {
    echo "FAIL: automatic retention deleted the protected non-terminal reconciliation snapshot"; exit 22;
}
[[ "$(psql_test -qAt -c "SELECT count(*) FROM ops.f_lor_snapshot_retention_plan(5) WHERE retention_disposition = 'PRUNE';")" == "0" ]] || {
    echo "FAIL: PRUNE candidates remain after automatic retention"; exit 23;
}
[[ "$(psql_test -qAt -c "SELECT count(*) FROM ops.f_lor_snapshot_retention_plan(5) WHERE retention_disposition = 'BLOCK';")" == "0" ]] || {
    echo "FAIL: BLOCK rows remain after automatic retention"; exit 24;
}

echo
echo "--- Automatic idempotency proof ---"
COUNT_BEFORE_SECOND="$RUN_COUNT_AFTER"
psql_test -c "CALL ops.p_run_lor_snapshot_retention();"
COUNT_AFTER_SECOND="$(psql_test -qAt -c "SELECT count(*) FROM lor_snap.import_run;")"
[[ "$COUNT_AFTER_SECOND" == "$COUNT_BEFORE_SECOND" ]] || {
    echo "FAIL: second automatic retention call changed import_run count"; exit 25;
}
echo "PASS: second automatic retention call is a no-op"

echo
echo "--- Dump-size proof ---"
sudo docker exec -e PGPASSWORD="$TEST_PASSWORD" "$TEST_CONTAINER" \
    pg_dump -U "$DB_ACTOR" -d "$TEST_DB" -Fc > "$DUMP_AFTER"
test -s "$DUMP_AFTER"
sudo docker exec -i -e PGPASSWORD="$TEST_PASSWORD" "$TEST_CONTAINER" \
    pg_restore --list < "$DUMP_AFTER" >/dev/null
AFTER_BYTES="$(stat -c %s "$DUMP_AFTER")"
if (( AFTER_BYTES >= BEFORE_BYTES )); then
    echo "FAIL: automatic-retention disposable dump did not shrink ($BEFORE_BYTES -> $AFTER_BYTES bytes)"
    exit 26
fi

REMOVED_BYTES=$((BEFORE_BYTES - AFTER_BYTES))
REMOVED_PERCENT="$(awk -v before="$BEFORE_BYTES" -v after="$AFTER_BYTES" 'BEGIN { if (before == 0) print "0.00"; else printf "%.2f", ((before-after)*100)/before }')"

echo
echo "--- Automatic-retention acceptance summary ---"
echo "Latest completed import preserved: $LATEST_BEFORE"
echo "import_run rows: $RUN_COUNT_BEFORE -> $RUN_COUNT_AFTER"
echo "automatic PRUNE candidates removed: $EXPECTED_PRUNE_COUNT"
echo "protected non-terminal import: $PROTECTED_TEST_IMPORT"
echo "synthetic BLOCK proof import: $BLOCK_TEST_IMPORT"
echo "logical dump bytes: $BEFORE_BYTES -> $AFTER_BYTES"
echo "logical dump reduction: $REMOVED_BYTES bytes ($REMOVED_PERCENT%)"
echo "LOR_SNAPSHOT_AUTOMATIC_RETENTION_DISPOSABLE_ACCEPTANCE_PASS"
