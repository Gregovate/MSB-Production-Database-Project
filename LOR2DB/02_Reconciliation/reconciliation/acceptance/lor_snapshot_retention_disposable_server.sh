#!/usr/bin/env bash
set -euo pipefail

PROD_CONTAINER="msb-postgres"
PROD_DB="msb"
DB_ACTOR="msbadmin"
IMAGE="postgis/postgis:16-3.5"
NETWORK="msb-stack_default"
REPO_ROOT="/opt/fieldwiring"
PYTHON="/opt/fieldwiring/.venv/bin/python"
KEEP_COMPLETED=5
MIGRATION_REL="LOR2DB/02_Reconciliation/reconciliation/migrations/0042_decouple_snapshot_provenance_and_add_retention.sql"
VALIDATION_REL="LOR2DB/02_Reconciliation/reconciliation/validation/37_lor_snapshot_retention_validation.sql"
REPORT_PUBLISHER_REL="LOR2DB/03_Reporting/publish_lor_reconciliation_report.py"

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
TEST_CONTAINER="msb-lor-retention-${$}"
TEST_DB="msb_lor_retention_acceptance"
TEST_PASSWORD="lor-retention-${$}-$(date +%s)"
DUMP_BEFORE="/tmp/msb-lor-retention-before-${STAMP}-${$}.dump"
DUMP_AFTER="/tmp/msb-lor-retention-after-${STAMP}-${$}.dump"
CANDIDATE_WORKTREE="/tmp/msb-lor-retention-candidate-${STAMP}"
REPORT_DIR="$HOME/lor2db-acceptance-reports"
REPORT="$REPORT_DIR/LOR_Snapshot_Retention_Disposable_Acceptance_${STAMP}.txt"
PYCACHE="/tmp/msb-lor-retention-pycache-${STAMP}"
PROD_BEFORE=""
LIVE_HEAD_BEFORE=""
TEST_IP=""

mkdir -p "$REPORT_DIR"
exec > >(tee "$REPORT") 2>&1

echo "========== LOR SNAPSHOT RETENTION DISPOSABLE ACCEPTANCE =========="
echo "Authority: Gregovate/MSB-Server-Management — docs/server/PostgreSQL_Disposable_Acceptance_Standard.md"
echo "Issue:          #186"
echo "Candidate SHA:  $TARGET_SHA"
echo "Target ref:     $TARGET_REF"
echo "Keep completed: $KEEP_COMPLETED"
echo "Report:         $REPORT"
echo "Production DB:  pg_dump + SELECT only"
echo "Candidate writes: disposable current-Production clone only"
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
                    SELECT string_agg(row_to_json(s)::text, '' ORDER BY s.lor_scene_id)
                    FROM ref.lor_scene AS s
                ), '') || '|' ||
                coalesce((
                    SELECT string_agg(row_to_json(sd)::text, '' ORDER BY sd.lor_scene_id, sd.display_id)
                    FROM ref.lor_scene_display AS sd
                ), '') || '|' ||
                coalesce((
                    SELECT string_agg(row_to_json(r)::text, '' ORDER BY r.lor_reconciliation_run_id)
                    FROM ops.lor_reconciliation_run AS r
                ), '') || '|' ||
                coalesce((
                    SELECT string_agg(row_to_json(a)::text, '' ORDER BY a.lor_reconciliation_action_id)
                    FROM ops.lor_reconciliation_action AS a
                ), '') || '|' ||
                coalesce((
                    SELECT string_agg(row_to_json(rr)::text, '' ORDER BY rr.lor_reconciliation_result_id)
                    FROM ops.lor_reconciliation_result AS rr
                ), '') || '|' ||
                coalesce((
                    SELECT string_agg(row_to_json(sr)::text, '' ORDER BY sr.lor_reconciliation_run_id)
                    FROM ops.lor_reconciliation_source_run AS sr
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
    sudo rm -rf "$PYCACHE" >/dev/null 2>&1 || true
    rm -rf "$SCRIPT_DIR" >/dev/null 2>&1 || true

    echo "--- Production after-check ---"
    if [[ -n "$PROD_BEFORE" ]]; then
        PROD_AFTER="$(prod_fingerprint 2>/dev/null)"
        echo "Production fingerprint before: $PROD_BEFORE"
        echo "Production fingerprint after:  $PROD_AFTER"
        if [[ -z "$PROD_AFTER" || "$PROD_AFTER" != "$PROD_BEFORE" ]]; then
            echo "FAIL: Production database fingerprint changed during disposable acceptance"
            status=97
        else
            echo "PASS: Production database fingerprint unchanged"
        fi
    else
        echo "SKIP: Production fingerprint was not captured before failure"
    fi

    if [[ -n "$LIVE_HEAD_BEFORE" ]]; then
        LIVE_HEAD_AFTER="$(sudo git -C "$REPO_ROOT" rev-parse HEAD 2>/dev/null)"
        echo "Shared checkout SHA before: $LIVE_HEAD_BEFORE"
        echo "Shared checkout SHA after:  $LIVE_HEAD_AFTER"
        if [[ -z "$LIVE_HEAD_AFTER" || "$LIVE_HEAD_AFTER" != "$LIVE_HEAD_BEFORE" ]]; then
            echo "FAIL: live shared checkout changed during disposable acceptance"
            status=98
        else
            echo "PASS: live shared checkout unchanged"
        fi
    else
        echo "SKIP: live checkout SHA was not captured before failure"
    fi

    echo "Acceptance report retained at: $REPORT"
    echo "Exit status: $status"
    exit "$status"
}
trap cleanup EXIT HUP INT TERM

sudo -v

if ! sudo docker inspect "$PROD_CONTAINER" >/dev/null 2>&1; then
    echo "FAIL: Production PostgreSQL container was not found"
    exit 5
fi
if [[ "$(sudo docker inspect "$PROD_CONTAINER" --format '{{.Config.Image}}')" != "$IMAGE" ]]; then
    echo "FAIL: Production PostgreSQL image is not $IMAGE"
    exit 6
fi
if ! sudo docker network inspect "$NETWORK" >/dev/null 2>&1; then
    echo "FAIL: Docker network $NETWORK was not found"
    exit 7
fi
if ! sudo -u fieldwiring -H test -x "$PYTHON"; then
    echo "FAIL: documented shared Python runtime is unavailable to fieldwiring"
    exit 8
fi
if [[ -n "$(sudo git -C "$REPO_ROOT" status --porcelain)" ]]; then
    echo "FAIL: shared repository checkout has uncommitted changes"
    exit 9
fi

LIVE_HEAD_BEFORE="$(sudo git -C "$REPO_ROOT" rev-parse HEAD)"
PROD_BEFORE="$(prod_fingerprint)"
[[ -n "$PROD_BEFORE" ]] || { echo "FAIL: Production fingerprint was empty"; exit 10; }

echo "Shared checkout SHA: $LIVE_HEAD_BEFORE"
echo "Production fingerprint before: $PROD_BEFORE"

echo
echo "--- Fetch exact candidate and prove forward ancestry ---"
sudo git -C "$REPO_ROOT" fetch origin \
    "+refs/heads/main:refs/remotes/origin/main" \
    "+refs/heads/$TARGET_REF:refs/remotes/origin/$TARGET_REF"
sudo git -C "$REPO_ROOT" cat-file -e "$TARGET_SHA^{commit}"
if ! sudo git -C "$REPO_ROOT" merge-base --is-ancestor origin/main "$TARGET_SHA"; then
    echo "FAIL: candidate is not a forward descendant of current origin/main"
    exit 41
fi
if ! sudo git -C "$REPO_ROOT" merge-base --is-ancestor "$LIVE_HEAD_BEFORE" "$TARGET_SHA"; then
    echo "FAIL: candidate is not a forward descendant of the live shared checkout"
    exit 11
fi
sudo git -C "$REPO_ROOT" worktree add --detach "$CANDIDATE_WORKTREE" "$TARGET_SHA"

if ! sudo git -C "$REPO_ROOT" diff --quiet origin/main "$TARGET_SHA" -- \
    "LOR2DB/02_Reconciliation/reconciliation/current_procedures/P1_stage_promotion.sql" \
    "LOR2DB/Application/test_distinct_substage_repair.py" \
    "LOR2DB/Application/test_stage_folder_authority_migration.py"; then
    echo "FAIL: #186 modified files owned by the pre-existing Issue #200 regression defect"
    exit 42
fi
echo "PASS: Issue #200 P1/test files are unchanged from current main"

for rel in "$MIGRATION_REL" "$VALIDATION_REL" "$REPORT_PUBLISHER_REL" "LOR2DB/Application/test_snapshot_retention_migration.py"; do
    [[ -s "$CANDIDATE_WORKTREE/$rel" ]] || {
        echo "FAIL: exact candidate is missing required file: $rel"
        exit 12
    }
done

echo
echo "--- Exact candidate LOR2DB regression ---"
sudo -u fieldwiring -H env PYTHONPYCACHEPREFIX="$PYCACHE" \
    bash -c "cd '$CANDIDATE_WORKTREE' && '$PYTHON' -m pytest -q -p no:cacheprovider --deselect LOR2DB/Application/test_distinct_substage_repair.py::DistinctSubstageRepairTests::test_p1_moves_only_the_target_source_key --deselect LOR2DB/Application/test_stage_folder_authority_migration.py::test_add_new_stage_has_no_preview_name_fallback LOR2DB/Application"
echo "PASS: exact candidate LOR2DB/Application regression excluding the two exact current-main Issue #200 assertions"

sudo -u fieldwiring -H env PYTHONPYCACHEPREFIX="$PYCACHE" \
    bash -c "cd '$CANDIDATE_WORKTREE' && '$PYTHON' -m pytest -q -p no:cacheprovider LOR2DB/Application/test_snapshot_retention_migration.py"
echo "PASS: #186 snapshot-retention regression"

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
    exit 13
fi

sudo docker exec -e PGPASSWORD="$TEST_PASSWORD" "$TEST_CONTAINER" \
    createdb -U "$DB_ACTOR" -T template0 "$TEST_DB"
sudo docker exec -i -e PGPASSWORD="$TEST_PASSWORD" "$TEST_CONTAINER" \
    pg_restore -U "$DB_ACTOR" -d "$TEST_DB" --no-owner --no-acl --exit-on-error \
    < "$DUMP_BEFORE"
echo "Disposable current-Production clone restored"

TEST_IP="$(sudo docker inspect "$TEST_CONTAINER" --format '{{range.NetworkSettings.Networks}}{{.IPAddress}}{{end}}')"
[[ -n "$TEST_IP" ]] || { echo "FAIL: disposable container IP was empty"; exit 14; }

psql_test() {
    sudo docker exec -i -e PGPASSWORD="$TEST_PASSWORD" "$TEST_CONTAINER" \
        psql -X -v ON_ERROR_STOP=1 -U "$DB_ACTOR" -d "$TEST_DB" "$@"
}

clone_ref_fingerprint() {
    psql_test -qAt -c "
        SELECT md5(
            coalesce((
                SELECT string_agg(row_to_json(s)::text, '' ORDER BY s.lor_scene_id)
                FROM ref.lor_scene AS s
            ), '') || '|' ||
            coalesce((
                SELECT string_agg(row_to_json(sd)::text, '' ORDER BY sd.lor_scene_id, sd.display_id)
                FROM ref.lor_scene_display AS sd
            ), '')
        );
    "
}

clone_ops_history_fingerprint() {
    psql_test -qAt -c "
        SELECT md5(
            coalesce((
                SELECT string_agg(row_to_json(r)::text, '' ORDER BY r.lor_reconciliation_run_id)
                FROM ops.lor_reconciliation_run AS r
                WHERE coalesce(r.started_by_application, '') <> 'snapshot-retention-disposable-protection-test'
            ), '') || '|' ||
            coalesce((
                SELECT string_agg(row_to_json(a)::text, '' ORDER BY a.lor_reconciliation_action_id)
                FROM ops.lor_reconciliation_action AS a
            ), '') || '|' ||
            coalesce((
                SELECT string_agg(row_to_json(rr)::text, '' ORDER BY rr.lor_reconciliation_result_id)
                FROM ops.lor_reconciliation_result AS rr
            ), '') || '|' ||
            coalesce((
                SELECT string_agg(row_to_json(sr)::text, '' ORDER BY sr.lor_reconciliation_run_id)
                FROM ops.lor_reconciliation_source_run AS sr
            ), '') || '|' ||
            coalesce((
                SELECT string_agg(row_to_json(sp)::text, '' ORDER BY sp.lor_reconciliation_source_preview_id)
                FROM ops.lor_reconciliation_source_preview AS sp
            ), '') || '|' ||
            coalesce((
                SELECT string_agg(row_to_json(ss)::text, '' ORDER BY ss.lor_reconciliation_source_scene_row_id)
                FROM ops.lor_reconciliation_source_scene AS ss
            ), '')
        );
    "
}

LATEST_BEFORE="$(psql_test -qAt -c "SELECT max(import_run_id) FROM lor_snap.import_run WHERE ingest_completed_at IS NOT NULL;")"
RUN_COUNT_BEFORE="$(psql_test -qAt -c "SELECT count(*) FROM lor_snap.import_run;")"
SNAP_ROWS_BEFORE="$(psql_test -qAt -c "
    SELECT
        (SELECT count(*) FROM lor_snap.previews) +
        (SELECT count(*) FROM lor_snap.scenes) +
        (SELECT count(*) FROM lor_snap.props) +
        (SELECT count(*) FROM lor_snap.sub_props) +
        (SELECT count(*) FROM lor_snap.dmx_channels) +
        (SELECT count(*) FROM lor_snap.scene_lor_props);
")"
REF_BEFORE="$(clone_ref_fingerprint)"
OPS_BEFORE="$(clone_ops_history_fingerprint)"
LEGACY_BEFORE="$(psql_test -qAt -c "SELECT CASE WHEN to_regclass('ops.lor_reconciliation_action_legacy') IS NULL THEN -1 ELSE (SELECT count(*) FROM ops.lor_reconciliation_action_legacy) END;")"

echo "Disposable latest completed import before migration/prune: $LATEST_BEFORE"
echo "Disposable import_run rows before: $RUN_COUNT_BEFORE"
echo "Disposable raw snapshot rows before: $SNAP_ROWS_BEFORE"

echo
echo "--- Apply candidate migration to disposable clone only ---"
psql_test < "$CANDIDATE_WORKTREE/$MIGRATION_REL"

echo
echo "--- Run read-only candidate validation on disposable clone ---"
psql_test < "$CANDIDATE_WORKTREE/$VALIDATION_REL"

echo
echo "--- Retention dry run before clone-only protection case ---"
psql_test -P pager=off -c "
    SELECT import_run_id, run_ts, completed_recency_rank,
           lor_reconciliation_run_id, reconciliation_status,
           retention_disposition, retention_reason, total_snapshot_rows
    FROM ops.f_lor_snapshot_retention_plan($KEEP_COMPLETED)
    ORDER BY import_run_id DESC;
"

OPEN_COUNT="$(psql_test -qAt -c "
    SELECT count(*)
    FROM ops.lor_reconciliation_run
    WHERE status IN (
        'STARTING','PREFLIGHT','AWAITING_DECISIONS','READY_TO_FINISH',
        'PROMOTING','VALIDATING','REPORTING'
    );
")"

if [[ "$OPEN_COUNT" == "0" ]]; then
    PROTECTED_TEST_IMPORT="$(psql_test -qAt -c "
        SELECT p.import_run_id
        FROM ops.f_lor_snapshot_retention_plan($KEEP_COMPLETED) AS p
        WHERE p.retention_disposition = 'PRUNE'
          AND p.lor_reconciliation_run_id IS NULL
        ORDER BY p.import_run_id
        LIMIT 1;
    ")"
    [[ -n "$PROTECTED_TEST_IMPORT" ]] || {
        echo "FAIL: no old unreconciled PRUNE candidate exists for the clone-only open-reconciliation protection proof"
        exit 15
    }
    psql_test -c "
        INSERT INTO ops.lor_reconciliation_run (
            import_run_id, status, started_by_application
        ) VALUES (
            $PROTECTED_TEST_IMPORT,
            'AWAITING_DECISIONS',
            'snapshot-retention-disposable-protection-test'
        );
    "
    echo "Created clone-only non-terminal reconciliation protection case on import $PROTECTED_TEST_IMPORT"
else
    PROTECTED_TEST_IMPORT="$(psql_test -qAt -c "
        SELECT import_run_id
        FROM ops.lor_reconciliation_run
        WHERE status IN (
            'STARTING','PREFLIGHT','AWAITING_DECISIONS','READY_TO_FINISH',
            'PROMOTING','VALIDATING','REPORTING'
        )
        ORDER BY import_run_id
        LIMIT 1;
    ")"
    echo "Using existing non-terminal reconciliation protection case on import $PROTECTED_TEST_IMPORT"
fi

PROTECTED_REASON="$(psql_test -qAt -c "
    SELECT retention_reason
    FROM ops.f_lor_snapshot_retention_plan($KEEP_COMPLETED)
    WHERE import_run_id = $PROTECTED_TEST_IMPORT;
")"
if [[ "$PROTECTED_REASON" != "NON_TERMINAL_RECONCILIATION" ]]; then
    echo "FAIL: open reconciliation import $PROTECTED_TEST_IMPORT is not protected for the required reason"
    exit 16
fi
echo "PASS: non-terminal reconciliation protection is explicit"

REPORT_RUN_ID="$(psql_test -qAt -c "
    SELECT r.lor_reconciliation_run_id
    FROM ops.lor_reconciliation_run AS r
    JOIN ops.lor_reconciliation_source_run AS sr
      ON sr.lor_reconciliation_run_id = r.lor_reconciliation_run_id
    JOIN ops.f_lor_snapshot_retention_plan($KEEP_COMPLETED) AS p
      ON p.import_run_id = r.import_run_id
    WHERE p.retention_disposition = 'PRUNE'
      AND r.status IN ('COMPLETED','COMPLETED_WITH_EXCEPTIONS')
    ORDER BY r.import_run_id
    LIMIT 1;
")"
[[ -n "$REPORT_RUN_ID" ]] || {
    echo "FAIL: no completed reconciliation with frozen evidence is associated with a PRUNE candidate"
    exit 17
}
REPORT_IMPORT_ID="$(psql_test -qAt -c "SELECT import_run_id FROM ops.lor_reconciliation_run WHERE lor_reconciliation_run_id = $REPORT_RUN_ID;")"
echo "Historical report proof will use reconciliation run $REPORT_RUN_ID / import $REPORT_IMPORT_ID"

EXPECTED_IDS="$(psql_test -qAt -c "
    SELECT coalesce(array_agg(import_run_id ORDER BY import_run_id), ARRAY[]::bigint[])::text
    FROM ops.f_lor_snapshot_retention_plan($KEEP_COMPLETED)
    WHERE retention_disposition = 'PRUNE';
")"
if [[ -z "$EXPECTED_IDS" || "$EXPECTED_IDS" == "{}" ]]; then
    echo "FAIL: current-production clone produced no PRUNE candidates; #186 cannot prove destructive retention"
    exit 18
fi
echo "Reviewed disposable PRUNE set: $EXPECTED_IDS"

echo
echo "--- Fail-closed stale/wrong candidate-set proof ---"
if psql_test -c "CALL ops.p_prune_lor_snapshots(ARRAY[-9223372036854775808]::bigint[], $KEEP_COMPLETED);" >/dev/null 2>&1; then
    echo "FAIL: prune accepted an intentionally wrong expected candidate set"
    exit 19
else
    echo "PASS: prune rejected an intentionally wrong expected candidate set before deletion"
fi

if [[ "$(psql_test -qAt -c "SELECT count(*) FROM lor_snap.import_run;")" != "$RUN_COUNT_BEFORE" ]]; then
    echo "FAIL: wrong-set rejection changed import_run count"
    exit 20
fi

echo
echo "--- Fail-closed unexpected-future-FK proof ---"
psql_test -c "
    CREATE TABLE public.lor_snapshot_retention_blocker_test (
        import_run_id bigint REFERENCES lor_snap.import_run(import_run_id)
    );
"
if psql_test -c "CALL ops.p_prune_lor_snapshots('$EXPECTED_IDS'::bigint[], $KEEP_COMPLETED);" >/dev/null 2>&1; then
    echo "FAIL: prune ignored an unexpected future FK dependency"
    exit 21
else
    echo "PASS: prune rejected unexpected future FK dependency before deletion"
fi
psql_test -c "DROP TABLE public.lor_snapshot_retention_blocker_test;"

if [[ "$(psql_test -qAt -c "SELECT count(*) FROM lor_snap.import_run;")" != "$RUN_COUNT_BEFORE" ]]; then
    echo "FAIL: unexpected-FK rejection changed import_run count"
    exit 22
fi

echo
echo "--- Execute governed prune on disposable clone only ---"
psql_test -P pager=off -c "CALL ops.p_prune_lor_snapshots('$EXPECTED_IDS'::bigint[], $KEEP_COMPLETED);"

LATEST_AFTER="$(psql_test -qAt -c "SELECT max(import_run_id) FROM lor_snap.import_run WHERE ingest_completed_at IS NOT NULL;")"
RUN_COUNT_AFTER="$(psql_test -qAt -c "SELECT count(*) FROM lor_snap.import_run;")"
SNAP_ROWS_AFTER="$(psql_test -qAt -c "
    SELECT
        (SELECT count(*) FROM lor_snap.previews) +
        (SELECT count(*) FROM lor_snap.scenes) +
        (SELECT count(*) FROM lor_snap.props) +
        (SELECT count(*) FROM lor_snap.sub_props) +
        (SELECT count(*) FROM lor_snap.dmx_channels) +
        (SELECT count(*) FROM lor_snap.scene_lor_props);
")"
REF_AFTER="$(clone_ref_fingerprint)"
OPS_AFTER="$(clone_ops_history_fingerprint)"
LEGACY_AFTER="$(psql_test -qAt -c "SELECT CASE WHEN to_regclass('ops.lor_reconciliation_action_legacy') IS NULL THEN -1 ELSE (SELECT count(*) FROM ops.lor_reconciliation_action_legacy) END;")"

if [[ "$LATEST_AFTER" != "$LATEST_BEFORE" ]]; then
    echo "FAIL: latest completed import changed: $LATEST_BEFORE -> $LATEST_AFTER"
    exit 23
fi
if [[ "$REF_AFTER" != "$REF_BEFORE" ]]; then
    echo "FAIL: ref.lor_scene or ref.lor_scene_display changed during snapshot pruning"
    exit 24
fi
if [[ "$OPS_AFTER" != "$OPS_BEFORE" ]]; then
    echo "FAIL: durable reconciliation history changed during snapshot pruning"
    exit 25
fi
if [[ "$LEGACY_AFTER" != "$LEGACY_BEFORE" ]]; then
    echo "FAIL: legacy reconciliation action count changed: $LEGACY_BEFORE -> $LEGACY_AFTER"
    exit 26
fi
if [[ "$(psql_test -qAt -c "SELECT count(*) FROM ops.f_lor_snapshot_retention_plan($KEEP_COMPLETED) WHERE retention_disposition = 'PRUNE';")" != "0" ]]; then
    echo "FAIL: PRUNE candidates remain after governed prune"
    exit 27
fi
if [[ "$(psql_test -qAt -c "SELECT count(*) FROM lor_snap.import_run WHERE import_run_id = $PROTECTED_TEST_IMPORT;")" != "1" ]]; then
    echo "FAIL: protected non-terminal reconciliation snapshot was deleted"
    exit 28
fi
if [[ "$(psql_test -qAt -c "SELECT count(*) FROM lor_snap.import_run WHERE import_run_id = $REPORT_IMPORT_ID;")" != "0" ]]; then
    echo "FAIL: selected historical report proof import was not pruned"
    exit 29
fi

ORPHAN_SCENE_PROVENANCE="$(psql_test -qAt -c "
    SELECT count(*)
    FROM ref.lor_scene AS s
    LEFT JOIN lor_snap.import_run AS ir
      ON ir.import_run_id = s.source_import_run_id
    WHERE ir.import_run_id IS NULL;
")"
ORPHAN_MEMBERSHIP_PROVENANCE="$(psql_test -qAt -c "
    SELECT count(*)
    FROM ref.lor_scene_display AS sd
    LEFT JOIN lor_snap.import_run AS ir
      ON ir.import_run_id = sd.source_import_run_id
    WHERE ir.import_run_id IS NULL;
")"
echo "Preserved logical scene provenance values whose raw snapshot was pruned: $ORPHAN_SCENE_PROVENANCE"
echo "Preserved logical membership provenance values whose raw snapshot was pruned: $ORPHAN_MEMBERSHIP_PROVENANCE"

echo
echo "--- Prove historical report rendering survives raw snapshot deletion ---"
TEST_DSN="host=$TEST_IP port=5432 dbname=$TEST_DB user=$DB_ACTOR password=$TEST_PASSWORD"
sudo -u fieldwiring -H env \
    PYTHONPYCACHEPREFIX="$PYCACHE" \
    TEST_DSN="$TEST_DSN" \
    TEST_REPORT_RUN_ID="$REPORT_RUN_ID" \
    REPORT_PUBLISHER="$CANDIDATE_WORKTREE/$REPORT_PUBLISHER_REL" \
    "$PYTHON" - <<'PY'
import importlib.util
import os
from datetime import datetime

import psycopg2

publisher_path = os.environ["REPORT_PUBLISHER"]
spec = importlib.util.spec_from_file_location("lor_report_publisher", publisher_path)
module = importlib.util.module_from_spec(spec)
assert spec.loader is not None
spec.loader.exec_module(module)

run_id = int(os.environ["TEST_REPORT_RUN_ID"])
with psycopg2.connect(os.environ["TEST_DSN"]) as conn:
    data = module.collect_report_data(conn, run_id)
    rendered = module.render_report(data, datetime.now().astimezone())

assert data["run"]["lor_reconciliation_run_id"] == run_id
assert data["previews"]
assert "LOR Reconciliation" in rendered
print(f"PASS: historical reconciliation run {run_id} rendered from frozen evidence after raw snapshot prune")
PY

echo
echo "--- Idempotency proof ---"
EMPTY_IDS="$(psql_test -qAt -c "
    SELECT coalesce(array_agg(import_run_id ORDER BY import_run_id), ARRAY[]::bigint[])::text
    FROM ops.f_lor_snapshot_retention_plan($KEEP_COMPLETED)
    WHERE retention_disposition = 'PRUNE';
")"
if [[ "$EMPTY_IDS" != "{}" ]]; then
    echo "FAIL: expected empty second-run PRUNE set, found $EMPTY_IDS"
    exit 30
fi
psql_test -c "CALL ops.p_prune_lor_snapshots('{}'::bigint[], $KEEP_COMPLETED);"
echo "PASS: second governed prune is a no-op"

echo
echo "--- Capture pruned disposable dump for size comparison ---"
sudo docker exec -e PGPASSWORD="$TEST_PASSWORD" "$TEST_CONTAINER" \
    pg_dump -U "$DB_ACTOR" -d "$TEST_DB" -Fc > "$DUMP_AFTER"
test -s "$DUMP_AFTER"
sudo docker exec -i -e PGPASSWORD="$TEST_PASSWORD" "$TEST_CONTAINER" \
    pg_restore --list < "$DUMP_AFTER" >/dev/null
AFTER_BYTES="$(stat -c %s "$DUMP_AFTER")"
echo "Pruned disposable dump: $(du -h "$DUMP_AFTER" | awk '{print $1}') ($AFTER_BYTES bytes)"

if (( AFTER_BYTES >= BEFORE_BYTES )); then
    echo "FAIL: pruned logical dump did not shrink ($BEFORE_BYTES -> $AFTER_BYTES bytes)"
    exit 31
fi

REMOVED_BYTES=$((BEFORE_BYTES - AFTER_BYTES))
REMOVED_PERCENT="$(awk -v before="$BEFORE_BYTES" -v after="$AFTER_BYTES" 'BEGIN { if (before == 0) print "0.00"; else printf "%.2f", ((before-after)*100)/before }')"

echo
echo "--- Acceptance summary ---"
echo "Latest completed import preserved: $LATEST_BEFORE"
echo "import_run rows: $RUN_COUNT_BEFORE -> $RUN_COUNT_AFTER"
echo "raw snapshot rows: $SNAP_ROWS_BEFORE -> $SNAP_ROWS_AFTER"
echo "logical dump bytes: $BEFORE_BYTES -> $AFTER_BYTES"
echo "logical dump reduction: $REMOVED_BYTES bytes ($REMOVED_PERCENT%)"
echo "protected non-terminal import: $PROTECTED_TEST_IMPORT"
echo "historical report proof: reconciliation run $REPORT_RUN_ID / pruned import $REPORT_IMPORT_ID"
echo "LOR_SNAPSHOT_RETENTION_DISPOSABLE_ACCEPTANCE_PASS"
