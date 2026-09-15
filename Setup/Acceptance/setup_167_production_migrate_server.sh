#!/usr/bin/env bash
set -euo pipefail

PROD_CONTAINER="msb-postgres"
PROD_DB="msb"
DB_ACTOR="msbadmin"
REPO_ROOT="/opt/fieldwiring"
SETUP_ROOT="/opt/msb-setup"
SETUP_SERVICE="msb-setup.service"
DISPLAY_SERVICE="msb-display-folders.service"
GOOGLE_SERVICE="msb-setup-google-links.service"
FIELDWIRING_SERVICE="fieldwiring.service"
PROCEDURES_SERVICE="msb-procedures.service"
TARGET_REF="agent/setup-167-kit-inventory-reconstruction"
TARGET_SHA="1e0e2d2c3ffbcafc2ffef2bb4a98c81d600e8b1b"
EXPECTED_SETUP_VERSION="V0.3.13-assignment-layer"
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
BACKUP_DIR="/home/msbadmin/backups/setup-167"
REPORT_DIR="/home/msbadmin/setup-deployment-reports"
STAMP="$(date +%Y%m%dT%H%M%S)"
BACKUP_FILE="$BACKUP_DIR/msb-pre-setup-167-reconstruction-$STAMP.dump"
TARGET_BACKUP_FILE="$BACKUP_DIR/msb-pre-setup-167-target-tables-$STAMP.dump"
REPORT="$REPORT_DIR/Setup_167_Kit_Inventory_Reconstruction_Production_Migrate_$STAMP.txt"
CANDIDATE_WORKTREE="/tmp/msb-setup-167-production-candidate-$STAMP"
M038=""
M043=""
M044=""
M045=""
M046=""
M047=""
M048=""
V_PRELOAD=""
V_COVERAGE=""
V_LOR=""
CORE_BEFORE=""
OLD_HEAD=""
PRE_EVENT_COUNT=""
DB_CHANGE_STARTED=0
APP_ADVANCED=0
SETUP_STOPPED=0
SUCCESS=0
BACKUP_CREATED=0
TARGET_BACKUP_CREATED=0

mkdir -p "$REPORT_DIR"
exec > >(tee "$REPORT") 2>&1

echo "========== SETUP #167 KIT INVENTORY RECONSTRUCTION PRODUCTION MIGRATION =========="
echo "Report:      $REPORT"
echo "Target SHA:  $TARGET_SHA"
echo "Target ref:  $TARGET_REF"
echo "Setup root:  $SETUP_ROOT"
echo

psql_prod() {
    sudo docker exec -i "$PROD_CONTAINER" \
        psql -X -v ON_ERROR_STOP=1 -U "$DB_ACTOR" -d "$PROD_DB" "$@"
}

core_fingerprint() {
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

wait_setup_ready() {
    for _ in $(seq 1 60); do
        if systemctl is-active --quiet "$SETUP_SERVICE" \
           && curl -fsS http://192.168.5.9:8794/api/health >/dev/null 2>&1; then
            return 0
        fi
        sleep 1
    done
    return 1
}

start_setup_service() {
    sudo systemctl start "$SETUP_SERVICE"
    SETUP_STOPPED=0
    wait_setup_ready
}

stop_setup_service() {
    sudo systemctl stop "$SETUP_SERVICE"
    SETUP_STOPPED=1
    if systemctl is-active --quiet "$SETUP_SERVICE"; then
        echo "FAIL: Setup service remained active after stop request"
        return 1
    fi
}

rollback_target_tables() {
    if [[ "$TARGET_BACKUP_CREATED" -ne 1 || ! -s "$TARGET_BACKUP_FILE" ]]; then
        echo "FAIL: targeted pre-image archive unavailable; cannot perform bounded table rollback"
        return 1
    fi

    echo "Restoring exact pre-run state for #167-targeted Setup tables..."
    if [[ "$SETUP_STOPPED" -ne 1 ]]; then
        stop_setup_service || return 1
    fi

    psql_prod <<'SQL'
BEGIN;
DELETE FROM ops.setup_extra_material_inventory_event;
DELETE FROM ref.setup_task_extra_material_source;
DELETE FROM ref.setup_task_extra_material;
DELETE FROM ref.setup_container_extra_material_review;
DELETE FROM ref.setup_container_extra_material;
DELETE FROM ref.setup_task_container_support;
COMMIT;
SQL

    sudo docker exec -i "$PROD_CONTAINER" \
        pg_restore -U "$DB_ACTOR" -d "$PROD_DB" \
        --data-only --disable-triggers --exit-on-error \
        < "$TARGET_BACKUP_FILE"

    echo "Targeted #167 table rollback restore completed"
}

cleanup() {
    status=$?
    trap - EXIT INT TERM
    set +e

    if [[ "$status" -ne 0 && "$SUCCESS" -ne 1 ]]; then
        echo
        echo "--- FAIL-CLOSED ROLLBACK ---"

        if [[ "$APP_ADVANCED" -eq 1 && -n "$OLD_HEAD" ]]; then
            echo "Restoring Setup checkout to $OLD_HEAD"
            sudo git -C "$SETUP_ROOT" reset --hard "$OLD_HEAD" || true
            APP_ADVANCED=0
        fi

        if [[ "$DB_CHANGE_STARTED" -eq 1 ]]; then
            rollback_target_tables || true
        fi

        if [[ "$SETUP_STOPPED" -eq 1 ]]; then
            start_setup_service || true
        fi
    fi

    if sudo git -C "$REPO_ROOT" worktree list --porcelain 2>/dev/null | grep -Fq "worktree $CANDIDATE_WORKTREE"; then
        sudo git -C "$REPO_ROOT" worktree remove --force "$CANDIDATE_WORKTREE" >/dev/null 2>&1 || true
    fi
    sudo git -C "$REPO_ROOT" worktree prune >/dev/null 2>&1 || true
    rm -rf "$SCRIPT_DIR" >/dev/null 2>&1 || true

    echo
    echo "--- Final protected Setup core fingerprint ---"
    if [[ -n "$CORE_BEFORE" ]]; then
        CORE_AFTER="$(core_fingerprint 2>/dev/null)"
        echo "Before: $CORE_BEFORE"
        echo "After:  $CORE_AFTER"
        if [[ -z "$CORE_AFTER" || "$CORE_AFTER" != "$CORE_BEFORE" ]]; then
            echo "FAIL: protected Setup core fingerprint changed"
            status=97
        else
            echo "PASS: protected Setup core fingerprint unchanged"
        fi
    fi

    if [[ "$BACKUP_CREATED" -eq 1 && -s "$BACKUP_FILE" ]]; then
        echo "Rollback backup retained at: $BACKUP_FILE"
    else
        echo "Rollback backup: not created before this stop"
    fi
    if [[ "$TARGET_BACKUP_CREATED" -eq 1 && -s "$TARGET_BACKUP_FILE" ]]; then
        echo "Targeted table pre-image retained at: $TARGET_BACKUP_FILE"
    else
        echo "Targeted table pre-image: not created before this stop"
    fi
    echo "Deployment report retained at: $REPORT"
    echo "Exit status: $status"
    exit "$status"
}
trap cleanup EXIT INT TERM

sudo -v
mkdir -p "$BACKUP_DIR" "$REPORT_DIR"

if ! sudo docker inspect "$PROD_CONTAINER" >/dev/null 2>&1; then
    echo "FAIL: Production PostgreSQL container $PROD_CONTAINER not found"
    exit 2
fi
if [[ "$(sudo docker inspect "$PROD_CONTAINER" --format '{{.Config.Image}}')" != "postgis/postgis:16-3.5" ]]; then
    echo "FAIL: Production PostgreSQL image is not postgis/postgis:16-3.5"
    exit 3
fi
if ! sudo git -C "$REPO_ROOT" worktree list --porcelain | grep -Fq "worktree $SETUP_ROOT"; then
    echo "FAIL: $SETUP_ROOT is not registered as a worktree of $REPO_ROOT"
    exit 4
fi

OLD_HEAD="$(sudo git -C "$SETUP_ROOT" rev-parse HEAD)"
echo "Verified live Setup checkout: $OLD_HEAD"
if [[ -n "$(sudo git -C "$SETUP_ROOT" status --porcelain)" ]]; then
    echo "FAIL: live Setup checkout has uncommitted changes"
    sudo git -C "$SETUP_ROOT" status -sb
    exit 5
fi

for service in "$SETUP_SERVICE" "$DISPLAY_SERVICE" "$GOOGLE_SERVICE" "$FIELDWIRING_SERVICE" "$PROCEDURES_SERVICE"; do
    if ! systemctl is-active --quiet "$service"; then
        echo "FAIL: required Production service is not active before deployment: $service"
        exit 6
    fi
done

SETUP_PRE="$(curl -fsS http://192.168.5.9:8794/api/health)"
FW_PRE="$(curl -fsS http://192.168.5.9:8790/api/health)"
PR_PRE="$(curl -fsS http://192.168.5.9:8792/api/health)"
echo "Pre-deploy Setup health:       $SETUP_PRE"
echo "Pre-deploy FieldWiring health: $FW_PRE"
echo "Pre-deploy Procedures health:  $PR_PRE"

CORE_BEFORE="$(core_fingerprint)"
if [[ -z "$CORE_BEFORE" ]]; then
    echo "FAIL: protected Setup core fingerprint is empty"
    exit 7
fi
echo "Protected Setup core fingerprint before: $CORE_BEFORE"

PRE_EVENT_COUNT="$(sudo docker exec "$PROD_CONTAINER" psql -X -qAt -v ON_ERROR_STOP=1 -U "$DB_ACTOR" -d "$PROD_DB" -c "SELECT count(*) FROM ops.setup_extra_material_inventory_event;")"
echo "Physical inventory event rows before: $PRE_EVENT_COUNT"

echo
echo "--- Fetch and verify exact accepted #167 target ---"
sudo git -C "$REPO_ROOT" fetch origin "$TARGET_REF"
sudo git -C "$REPO_ROOT" cat-file -e "$TARGET_SHA^{commit}"
if ! sudo git -C "$REPO_ROOT" merge-base --is-ancestor "$OLD_HEAD" "$TARGET_SHA"; then
    echo "FAIL: accepted #167 target is not a fast-forward descendant of verified live Setup checkout"
    echo "Live:   $OLD_HEAD"
    echo "Target: $TARGET_SHA"
    exit 8
fi
echo "Verified fast-forward ancestry: $OLD_HEAD -> $TARGET_SHA"

echo
echo "--- Detached Production-runtime candidate regression ---"
sudo git -C "$REPO_ROOT" worktree add --detach "$CANDIDATE_WORKTREE" "$TARGET_SHA"

M038="$CANDIDATE_WORKTREE/Setup/Database/038_preload_setup_extra_material_known_evidence.sql"
M043="$CANDIDATE_WORKTREE/Setup/Database/043_preload_setup_kit_inventory_and_tpost_stock.sql"
M044="$CANDIDATE_WORKTREE/Setup/Database/044_preload_elf_choir_tpost_requirement.sql"
M045="$CANDIDATE_WORKTREE/Setup/Database/045_preload_reviewed_kit_assignments.sql"
M046="$CANDIDATE_WORKTREE/Setup/Database/046_preload_explicit_tpost_requirements.sql"
M047="$CANDIDATE_WORKTREE/Setup/Database/047_finalize_assigned_kit_inventory_coverage.sql"
M048="$CANDIDATE_WORKTREE/Setup/Database/048_complete_tpost_requirements_and_stock_variants.sql"
V_PRELOAD="$CANDIDATE_WORKTREE/Setup/Acceptance/setup_extra_material_preload_disposable_validation.sql"
V_COVERAGE="$CANDIDATE_WORKTREE/Setup/Acceptance/setup_167_assigned_kit_inventory_coverage.sql"
V_LOR="$CANDIDATE_WORKTREE/Setup/Acceptance/setup_lor_reconciliation_durability_readonly.sql"

for required_file in "$M038" "$M043" "$M044" "$M045" "$M046" "$M047" "$M048" "$V_PRELOAD" "$V_COVERAGE" "$V_LOR"; do
    if [[ ! -s "$required_file" ]]; then
        echo "FAIL: accepted target is missing reviewed file $required_file"
        exit 9
    fi
done

echo "Exact accepted migration/validation SHA256 identities:"
sha256sum "$M038" "$M043" "$M044" "$M045" "$M046" "$M047" "$M048" "$V_PRELOAD" "$V_COVERAGE" "$V_LOR"

sudo -u fieldwiring -H bash -c \
    "cd '$CANDIDATE_WORKTREE' && /opt/fieldwiring/.venv/bin/python -m pytest -q -p no:cacheprovider Setup/Application"
echo "DETACHED SETUP #167 CANDIDATE REGRESSION: PASS"

echo
echo "--- Create and verify full rollback PostgreSQL archive ---"
sudo docker exec "$PROD_CONTAINER" \
    pg_dump -U "$DB_ACTOR" -d "$PROD_DB" -Fc > "$BACKUP_FILE"
test -s "$BACKUP_FILE"
BACKUP_CREATED=1
BACKUP_SHA="$(sha256sum "$BACKUP_FILE" | awk '{print $1}')"
sudo docker exec -i "$PROD_CONTAINER" pg_restore --list < "$BACKUP_FILE" >/dev/null
echo "Rollback archive: $BACKUP_FILE"
echo "SHA256:          $BACKUP_SHA"
echo "FULL ROLLBACK ARCHIVE VALIDATION: PASS"

echo
echo "--- Production database preflight ---"
psql_prod <<'SQL'
DO $preflight$
BEGIN
    IF to_regclass('ref.setup_extra_material') IS NULL
       OR to_regclass('ref.setup_task_extra_material') IS NULL
       OR to_regclass('ref.setup_task_extra_material_source') IS NULL
       OR to_regclass('ref.setup_container_extra_material') IS NULL
       OR to_regclass('ref.setup_container_extra_material_review') IS NULL
       OR to_regclass('ops.setup_extra_material_inventory_event') IS NULL
       OR to_regclass('ops.setup_extra_material_inventory_balance') IS NULL THEN
        RAISE EXCEPTION '#184 durable Extra Material foundation is incomplete';
    END IF;

    IF (SELECT count(*) FROM ref.setup_extra_material WHERE active_flag) <> 43 THEN
        RAISE EXCEPTION 'Expected 43 active Extra Material catalog rows before #167 reconstruction';
    END IF;

    IF EXISTS (SELECT 1 FROM ops.setup_session WHERE season_year=2026) THEN
        RAISE EXCEPTION 'A 2026 Setup Session already exists; #167 reconstruction gate is closed';
    END IF;

    IF EXISTS (
        SELECT 1 FROM ref.setup_task_extra_material
        WHERE notes LIKE 'Preloaded from MSB_Setup_Extra_Materials_Normalization_Staging_2026-09-13_v6.xlsx.%'
           OR notes LIKE '[TPOST_RECON_2026_09_14]%'
           OR notes LIKE '[TPOST_FINAL_RECON_2026_09_14]%'
    ) OR EXISTS (
        SELECT 1 FROM ref.setup_container_extra_material
        WHERE notes LIKE 'Preloaded from MSB_Setup_Extra_Materials_Normalization_Staging_2026-09-13_v6.xlsx.%'
           OR notes LIKE 'Procedure-derived Kit preload v6.%'
           OR notes LIKE 'Preloaded from #167 physical-source reconciliation.%'
           OR notes LIKE '[#167 ASSIGNMENT-DRIVEN KIT INVENTORY]%'
           OR notes LIKE '[#167 SHARED SPACER STOCK]%'
           OR notes LIKE '[#167 TPOST STOCK SPLIT]%'
           OR notes LIKE '[#167 EXPLICIT TPOST CONTENT]%'
    ) OR EXISTS (
        SELECT 1 FROM ref.setup_container_extra_material_review
        WHERE unverified_items_text LIKE '%[#167 PROCEDURE REMAINDERS v6]%'
           OR unverified_items_text LIKE '%[#167 ASSIGNED KIT COVERAGE]%'
           OR unverified_items_text LIKE '%[#167 SHARED SPACER STOCK]%'
    ) THEN
        RAISE EXCEPTION '#167 reconstruction markers already exist; refuse to apply one-time migration twice';
    END IF;
END
$preflight$;
SQL

echo "PRODUCTION #167 DATABASE PREFLIGHT: PASS"

echo
echo "--- Recheck protected core fingerprint immediately before mutation ---"
CORE_RECHECK="$(core_fingerprint)"
echo "Captured: $CORE_BEFORE"
echo "Recheck:  $CORE_RECHECK"
if [[ "$CORE_RECHECK" != "$CORE_BEFORE" ]]; then
    echo "FAIL: protected Setup core changed during preflight; stop before mutation"
    exit 10
fi

echo
echo "--- Stop Setup service for bounded reconstruction write window ---"
stop_setup_service
echo "Setup service stopped"

echo
echo "--- Capture targeted pre-image for exact table rollback ---"
sudo docker exec "$PROD_CONTAINER" \
    pg_dump -U "$DB_ACTOR" -d "$PROD_DB" -Fc --data-only \
    -t ref.setup_task_container_support \
    -t ref.setup_task_extra_material \
    -t ref.setup_task_extra_material_source \
    -t ref.setup_container_extra_material \
    -t ref.setup_container_extra_material_review \
    -t ops.setup_extra_material_inventory_event \
    > "$TARGET_BACKUP_FILE"
test -s "$TARGET_BACKUP_FILE"
TARGET_BACKUP_CREATED=1
TARGET_BACKUP_SHA="$(sha256sum "$TARGET_BACKUP_FILE" | awk '{print $1}')"
sudo docker exec -i "$PROD_CONTAINER" pg_restore --list < "$TARGET_BACKUP_FILE" >/dev/null
echo "Targeted pre-image: $TARGET_BACKUP_FILE"
echo "SHA256:            $TARGET_BACKUP_SHA"
echo "TARGETED PRE-IMAGE VALIDATION: PASS"

echo
echo "--- Apply accepted one-time #167 migrations ---"
DB_CHANGE_STARTED=1
for migration in "$M038" "$M043" "$M044" "$M045" "$M046" "$M047" "$M048"; do
    echo "Applying $(basename "$migration")"
    sudo docker exec -i "$PROD_CONTAINER" \
        psql -X -v ON_ERROR_STOP=1 -U "$DB_ACTOR" -d "$PROD_DB" \
        < "$migration"
done

echo
echo "--- Validate exact reconstructed Production data ---"
sudo docker exec -i "$PROD_CONTAINER" \
    psql -X -v ON_ERROR_STOP=1 -U "$DB_ACTOR" -d "$PROD_DB" < "$V_PRELOAD"
sudo docker exec -i "$PROD_CONTAINER" \
    psql -X -v ON_ERROR_STOP=1 -U "$DB_ACTOR" -d "$PROD_DB" < "$V_COVERAGE"
sudo docker exec -i "$PROD_CONTAINER" \
    psql -X -v ON_ERROR_STOP=1 -U "$DB_ACTOR" -d "$PROD_DB" < "$V_LOR"

echo
echo "--- Verify least privilege and reconstruction invariants ---"
psql_prod <<'SQL'
SELECT
    (SELECT count(*) FROM ops.setup_session WHERE season_year=2026) AS setup_2026_sessions,
    (SELECT count(*) FROM ops.setup_extra_material_inventory_event) AS physical_inventory_events,
    has_table_privilege('fieldwiring_app','ref.setup_extra_material','INSERT') AS broad_catalog_insert,
    has_table_privilege('fieldwiring_app','ref.setup_task_extra_material','INSERT') AS broad_task_material_insert,
    has_table_privilege('fieldwiring_app','ref.setup_container_extra_material','INSERT') AS broad_container_material_insert,
    has_table_privilege('fieldwiring_app','ops.setup_extra_material_inventory_event','UPDATE') AS broad_inventory_update;
SQL

POST_EVENT_COUNT="$(sudo docker exec "$PROD_CONTAINER" psql -X -qAt -v ON_ERROR_STOP=1 -U "$DB_ACTOR" -d "$PROD_DB" -c "SELECT count(*) FROM ops.setup_extra_material_inventory_event;")"
if [[ "$POST_EVENT_COUNT" != "$PRE_EVENT_COUNT" ]]; then
    echo "FAIL: one-time reconstruction changed physical inventory history ($PRE_EVENT_COUNT -> $POST_EVENT_COUNT)"
    exit 11
fi

CORE_AFTER_DB="$(core_fingerprint)"
echo "Protected core before: $CORE_BEFORE"
echo "Protected core after DB reconstruction: $CORE_AFTER_DB"
if [[ "$CORE_AFTER_DB" != "$CORE_BEFORE" ]]; then
    echo "FAIL: #167 reconstruction changed protected Setup core data"
    exit 12
fi

echo "#167 DATABASE RECONSTRUCTION VALIDATION: PASS"

echo
echo "--- Fast-forward live Setup checkout to exact accepted target ---"
sudo git -C "$SETUP_ROOT" merge --ff-only "$TARGET_SHA"
DEPLOYED_HEAD="$(sudo git -C "$SETUP_ROOT" rev-parse HEAD)"
if [[ "$DEPLOYED_HEAD" != "$TARGET_SHA" ]]; then
    echo "FAIL: deployed Setup checkout does not equal accepted #167 target"
    exit 13
fi
APP_ADVANCED=1
echo "Live Setup checkout advanced to: $DEPLOYED_HEAD"

echo
echo "--- Start Setup service and verify health ---"
start_setup_service
SETUP_POST="$(curl -fsS http://192.168.5.9:8794/api/health)"
echo "Post-deploy Setup health: $SETUP_POST"
if [[ "$SETUP_POST" != *"$EXPECTED_SETUP_VERSION"* ]]; then
    echo "FAIL: Setup health version does not contain expected $EXPECTED_SETUP_VERSION"
    exit 14
fi

curl -fsS -o /dev/null http://192.168.5.9:8794/kit-inventory/
curl -fsS -o /dev/null http://192.168.5.9:8794/tpost-inventory/
echo "Kit Inventory and T-Post Inventory routes: PASS"

echo
echo "--- Live deployed Setup regression ---"
sudo -u fieldwiring -H bash -c \
    "cd '$SETUP_ROOT' && /opt/fieldwiring/.venv/bin/python -m pytest -q -p no:cacheprovider Setup/Application"
echo "LIVE SETUP REGRESSION: PASS"

echo
echo "--- Final Production invariants ---"
FINAL_HEAD="$(sudo git -C "$SETUP_ROOT" rev-parse HEAD)"
[[ "$FINAL_HEAD" == "$TARGET_SHA" ]]
[[ -z "$(sudo git -C "$SETUP_ROOT" status --porcelain)" ]]
[[ "$(sudo docker exec "$PROD_CONTAINER" psql -X -qAt -v ON_ERROR_STOP=1 -U "$DB_ACTOR" -d "$PROD_DB" -c "SELECT count(*) FROM ops.setup_session WHERE season_year=2026;")" == "0" ]]
[[ "$(core_fingerprint)" == "$CORE_BEFORE" ]]
[[ "$(sudo docker exec "$PROD_CONTAINER" psql -X -qAt -v ON_ERROR_STOP=1 -U "$DB_ACTOR" -d "$PROD_DB" -c "SELECT count(*) FROM ops.setup_extra_material_inventory_event;")" == "$PRE_EVENT_COUNT" ]]

echo "FINAL LIVE SHA: $FINAL_HEAD"
echo "2026 Setup Sessions: 0"
echo "Physical inventory history unchanged: $PRE_EVENT_COUNT row(s)"
echo "Protected Setup core fingerprint unchanged: $CORE_BEFORE"
echo

echo "SETUP_167_PRODUCTION_RECONSTRUCTION_PASS"
SUCCESS=1
