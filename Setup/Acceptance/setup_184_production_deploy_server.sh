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
TARGET_REF="agent/setup-184-durable-kit-inventory"
TARGET_SHA="9761cf91596a35c732acec3ed7872271f7f16d2a"
EXPECTED_SETUP_VERSION="V0.3.13-assignment-layer"
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
BACKUP_DIR="/home/msbadmin/backups/setup-184"
REPORT_DIR="/home/msbadmin/setup-deployment-reports"
STAMP="$(date +%Y%m%dT%H%M%S)"
BACKUP_FILE="$BACKUP_DIR/msb-pre-setup-184-kit-inventory-$STAMP.dump"
REPORT="$REPORT_DIR/Setup_184_Durable_Kit_Inventory_Production_Deploy_$STAMP.txt"
CANDIDATE_WORKTREE="/tmp/msb-setup-184-production-candidate-$STAMP"
NEGATIVE_BODY="/tmp/msb-setup-184-negative-$STAMP.txt"
M032=""
M033=""
M034=""
M035=""
M036=""
M037=""
PROD_BEFORE=""
OLD_HEAD=""
DB_CHANGE_STARTED=0
APP_ADVANCED=0
SUCCESS=0
BACKUP_CREATED=0

mkdir -p "$REPORT_DIR"
exec > >(tee "$REPORT") 2>&1

echo "========== SETUP #184 DURABLE KIT INVENTORY PRODUCTION DEPLOYMENT =========="
echo "Report:      $REPORT"
echo "Target SHA:  $TARGET_SHA"
echo "Target ref:  $TARGET_REF"
echo "Setup root:  $SETUP_ROOT"
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

psql_prod() {
    sudo docker exec -i "$PROD_CONTAINER" \
        psql -X -v ON_ERROR_STOP=1 -U "$DB_ACTOR" -d "$PROD_DB" "$@"
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

restart_setup_service() {
    sudo systemctl restart "$SETUP_SERVICE"
    wait_setup_ready
}

rollback_setup_184_database() {
    echo "Removing only #184 durable Extra Material objects introduced by migrations 032-037..."
    psql_prod <<'SQL'
BEGIN;
DROP FUNCTION IF EXISTS ops.record_setup_extra_material_inventory_event(text,bigint,text,numeric,text,timestamptz);
DROP FUNCTION IF EXISTS ref.setup_inventory_actor(text,boolean);
DROP FUNCTION IF EXISTS ref.set_setup_container_unverified_items(text,integer,text);
DROP FUNCTION IF EXISTS ref.set_setup_container_extra_material(text,bigint,integer,integer,numeric,text,text,numeric,text,text,text,text,boolean);
DROP FUNCTION IF EXISTS ref.set_setup_task_extra_material_source(text,bigint,bigint,integer,numeric,text,text,boolean);
DROP FUNCTION IF EXISTS ref.set_setup_task_extra_material(text,bigint,bigint,integer,numeric,text,text,numeric,text,text,text,text,text,boolean);
DROP FUNCTION IF EXISTS ref.update_setup_extra_material(text,integer,text,text,text,text,boolean,integer);
DROP FUNCTION IF EXISTS ref.create_setup_extra_material(text,text,text,text,text);
DROP VIEW IF EXISTS ops.setup_extra_material_inventory_balance;
DROP TABLE IF EXISTS ops.setup_extra_material_inventory_event;
DROP TABLE IF EXISTS ref.setup_container_extra_material_review;
DROP TABLE IF EXISTS ref.setup_container_extra_material;
DROP TABLE IF EXISTS ref.setup_task_extra_material_source;
DROP TABLE IF EXISTS ref.setup_task_extra_material;
DROP TABLE IF EXISTS ref.setup_extra_material;
COMMIT;
SQL
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
            restart_setup_service || true
        fi
        if [[ "$DB_CHANGE_STARTED" -eq 1 ]]; then
            rollback_setup_184_database || true
        fi
    fi

    if sudo git -C "$REPO_ROOT" worktree list --porcelain 2>/dev/null | grep -Fq "worktree $CANDIDATE_WORKTREE"; then
        sudo git -C "$REPO_ROOT" worktree remove --force "$CANDIDATE_WORKTREE" >/dev/null 2>&1 || true
    fi
    sudo git -C "$REPO_ROOT" worktree prune >/dev/null 2>&1 || true
    rm -f "$NEGATIVE_BODY" >/dev/null 2>&1 || true
    rm -rf "$SCRIPT_DIR" >/dev/null 2>&1 || true

    echo
    echo "--- Production Setup fingerprint after-check ---"
    if [[ -n "$PROD_BEFORE" ]]; then
        PROD_AFTER="$(prod_fingerprint 2>/dev/null)"
        echo "Before: $PROD_BEFORE"
        echo "After:  $PROD_AFTER"
        if [[ -z "$PROD_AFTER" || "$PROD_AFTER" != "$PROD_BEFORE" ]]; then
            echo "FAIL: Production Setup governed data fingerprint changed during deployment"
            status=97
        else
            echo "PASS: Production Setup governed data fingerprint unchanged"
        fi
    fi

    if [[ "$BACKUP_CREATED" -eq 1 && -s "$BACKUP_FILE" ]]; then
        echo "Rollback backup retained at: $BACKUP_FILE"
    else
        echo "Rollback backup: not created before this stop"
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

PROD_BEFORE="$(prod_fingerprint)"
if [[ -z "$PROD_BEFORE" ]]; then
    echo "FAIL: Production Setup fingerprint is empty"
    exit 7
fi
echo "Pre-deploy Setup fingerprint: $PROD_BEFORE"

echo
echo "--- Fetch and verify exact operator-approved target ---"
sudo git -C "$REPO_ROOT" fetch origin "$TARGET_REF"
sudo git -C "$REPO_ROOT" cat-file -e "$TARGET_SHA^{commit}"
if ! sudo git -C "$REPO_ROOT" merge-base --is-ancestor "$OLD_HEAD" "$TARGET_SHA"; then
    echo "FAIL: accepted Setup target is not a fast-forward descendant of verified live Setup checkout"
    echo "Live:   $OLD_HEAD"
    echo "Target: $TARGET_SHA"
    exit 8
fi
echo "Verified fast-forward ancestry: $OLD_HEAD -> $TARGET_SHA"

echo
echo "--- Detached Production-runtime candidate regression ---"
sudo git -C "$REPO_ROOT" worktree add --detach "$CANDIDATE_WORKTREE" "$TARGET_SHA"
M032="$CANDIDATE_WORKTREE/Setup/Database/032_add_setup_extra_material_schema.sql"
M033="$CANDIDATE_WORKTREE/Setup/Database/033_add_setup_extra_material_manager_commands.sql"
M034="$CANDIDATE_WORKTREE/Setup/Database/034_add_setup_extra_material_container_commands.sql"
M035="$CANDIDATE_WORKTREE/Setup/Database/035_add_setup_extra_material_inventory_commands.sql"
M036="$CANDIDATE_WORKTREE/Setup/Database/036_seed_setup_extra_material_catalog.sql"
M037="$CANDIDATE_WORKTREE/Setup/Database/037_harden_setup_extra_material_duplicate_rows.sql"

for required_file in "$M032" "$M033" "$M034" "$M035" "$M036" "$M037"; do
    if [[ ! -s "$required_file" ]]; then
        echo "FAIL: accepted target is missing reviewed migration $required_file"
        exit 9
    fi
done

[[ "$(sha256sum "$M032" | awk '{print $1}')" == "c056d29f2b58a1a34de816ef0aa18970b55826e8ccf7ef80ab5ab7f4f3e8230b" ]]
[[ "$(sha256sum "$M033" | awk '{print $1}')" == "1568ad96e1158e6214171c8870daac1638882ba1c6515a348a794d69cdad05be" ]]
[[ "$(sha256sum "$M034" | awk '{print $1}')" == "3280ab027323338f8e1c96f135a8da147fc403130a09d8e087c87d2cdfc9d3e3" ]]
[[ "$(sha256sum "$M035" | awk '{print $1}')" == "3a775c521d718204de81bef3b843855fee299188e99621773580f863cce8483e" ]]
[[ "$(sha256sum "$M036" | awk '{print $1}')" == "cc64d8afc49694b1dd4c637b53555a22d15e5569d6e6e1673d3ed29951646b58" ]]
[[ "$(sha256sum "$M037" | awk '{print $1}')" == "b430d7b5d17fdc8542cd4c060b3037cf6cdffe234af06ea962584326fe600be9" ]]
echo "Reviewed migration SHA256 identities: PASS"
sha256sum "$M032" "$M033" "$M034" "$M035" "$M036" "$M037"

sudo -u fieldwiring -H bash -c \
    "cd '$CANDIDATE_WORKTREE' && /opt/fieldwiring/.venv/bin/python -m pytest -q -p no:cacheprovider Setup/Application"
echo "DETACHED SETUP CANDIDATE REGRESSION: PASS"

echo
echo "--- Create and verify rollback PostgreSQL archive ---"
sudo docker exec "$PROD_CONTAINER" \
    pg_dump -U "$DB_ACTOR" -d "$PROD_DB" -Fc > "$BACKUP_FILE"
test -s "$BACKUP_FILE"
BACKUP_CREATED=1
BACKUP_SHA="$(sha256sum "$BACKUP_FILE" | awk '{print $1}')"
sudo docker exec -i "$PROD_CONTAINER" pg_restore --list < "$BACKUP_FILE" >/dev/null
echo "Rollback archive: $BACKUP_FILE"
echo "SHA256:          $BACKUP_SHA"
echo "ROLLBACK ARCHIVE VALIDATION: PASS"

echo
echo "--- Production database preflight ---"
psql_prod <<'SQL'
DO $preflight$
BEGIN
    IF to_regprocedure('ref.setup_management_actor(text,boolean)') IS NULL
       OR to_regclass('ref.container') IS NULL
       OR to_regclass('ref.setup_task') IS NULL
       OR to_regclass('ref.person') IS NULL
       OR to_regprocedure('ref.set_actor_on_insert()') IS NULL
       OR to_regprocedure('ref.set_actor_on_update()') IS NULL THEN
        RAISE EXCEPTION 'Accepted Setup/container/audit baseline is incomplete';
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname='fieldwiring_app') THEN
        RAISE EXCEPTION 'Required fieldwiring_app role does not exist';
    END IF;
    IF to_regclass('ref.setup_extra_material') IS NOT NULL
       OR to_regclass('ref.setup_task_extra_material') IS NOT NULL
       OR to_regclass('ref.setup_task_extra_material_source') IS NOT NULL
       OR to_regclass('ref.setup_container_extra_material') IS NOT NULL
       OR to_regclass('ref.setup_container_extra_material_review') IS NOT NULL
       OR to_regclass('ops.setup_extra_material_inventory_event') IS NOT NULL
       OR to_regclass('ops.setup_extra_material_inventory_balance') IS NOT NULL
       OR to_regprocedure('ref.create_setup_extra_material(text,text,text,text,text)') IS NOT NULL
       OR to_regprocedure('ops.record_setup_extra_material_inventory_event(text,bigint,text,numeric,text,timestamptz)') IS NOT NULL THEN
        RAISE EXCEPTION '#184 durable Extra Material objects already exist; reconcile before deployment';
    END IF;
    IF EXISTS (SELECT 1 FROM ops.setup_session WHERE season_year=2026) THEN
        RAISE EXCEPTION '2026 Setup Session exists before #184 deployment';
    END IF;
END
$preflight$;
SQL

echo "DATABASE PREFLIGHT: PASS"

PRE_MUTATION_FINGERPRINT="$(prod_fingerprint)"
echo "Initial fingerprint:      $PROD_BEFORE"
echo "Pre-mutation fingerprint: $PRE_MUTATION_FINGERPRINT"
if [[ "$PRE_MUTATION_FINGERPRINT" != "$PROD_BEFORE" ]]; then
    echo "FAIL: governed Setup data changed during pre-deployment validation; stop before mutation"
    exit 10
fi
echo "PRE-MUTATION FINGERPRINT STABILITY: PASS"

echo
echo "--- Apply reviewed migrations 032-037 ---"
DB_CHANGE_STARTED=1
for migration in "$M032" "$M033" "$M034" "$M035" "$M036" "$M037"; do
    echo "Applying $(basename "$migration")"
    psql_prod < "$migration"
done

echo
echo "--- Validate #184 database contract ---"
psql_prod <<'SQL'
DO $validate$
BEGIN
    IF to_regclass('ref.setup_extra_material') IS NULL
       OR to_regclass('ref.setup_task_extra_material') IS NULL
       OR to_regclass('ref.setup_task_extra_material_source') IS NULL
       OR to_regclass('ref.setup_container_extra_material') IS NULL
       OR to_regclass('ref.setup_container_extra_material_review') IS NULL
       OR to_regclass('ops.setup_extra_material_inventory_event') IS NULL
       OR to_regclass('ops.setup_extra_material_inventory_balance') IS NULL THEN
        RAISE EXCEPTION '#184 durable Extra Material objects are incomplete';
    END IF;
    IF NOT has_function_privilege('fieldwiring_app','ref.create_setup_extra_material(text,text,text,text,text)','EXECUTE')
       OR NOT has_function_privilege('fieldwiring_app','ref.update_setup_extra_material(text,integer,text,text,text,text,boolean,integer)','EXECUTE')
       OR NOT has_function_privilege('fieldwiring_app','ref.set_setup_task_extra_material(text,bigint,bigint,integer,numeric,text,text,numeric,text,text,text,text,text,boolean)','EXECUTE')
       OR NOT has_function_privilege('fieldwiring_app','ref.set_setup_task_extra_material_source(text,bigint,bigint,integer,numeric,text,text,boolean)','EXECUTE')
       OR NOT has_function_privilege('fieldwiring_app','ref.set_setup_container_extra_material(text,bigint,integer,integer,numeric,text,text,numeric,text,text,text,text,boolean)','EXECUTE')
       OR NOT has_function_privilege('fieldwiring_app','ref.set_setup_container_unverified_items(text,integer,text)','EXECUTE')
       OR NOT has_function_privilege('fieldwiring_app','ops.record_setup_extra_material_inventory_event(text,bigint,text,numeric,text,timestamptz)','EXECUTE') THEN
        RAISE EXCEPTION 'Required governed #184 EXECUTE privilege is missing';
    END IF;
    IF has_table_privilege('fieldwiring_app','ref.setup_extra_material','INSERT')
       OR has_table_privilege('fieldwiring_app','ref.setup_extra_material','UPDATE')
       OR has_table_privilege('fieldwiring_app','ref.setup_container_extra_material','INSERT')
       OR has_table_privilege('fieldwiring_app','ops.setup_extra_material_inventory_event','INSERT')
       OR has_table_privilege('fieldwiring_app','ops.setup_extra_material_inventory_event','UPDATE') THEN
        RAISE EXCEPTION 'Forbidden broad #184 table DML privilege detected';
    END IF;
    IF EXISTS (SELECT 1 FROM ops.setup_extra_material_inventory_event) THEN
        RAISE EXCEPTION '#184 foundation fabricated physical inventory events';
    END IF;
    IF EXISTS (SELECT 1 FROM ops.setup_session WHERE season_year=2026) THEN
        RAISE EXCEPTION '#184 foundation created a 2026 Setup Session';
    END IF;
END
$validate$;

SELECT
    (SELECT count(*) FROM ref.setup_extra_material WHERE active_flag) AS active_catalog_rows,
    (SELECT count(*) FROM ref.setup_task_extra_material WHERE active_flag) AS active_task_material_rows,
    (SELECT count(*) FROM ref.setup_container_extra_material WHERE active_flag) AS active_container_material_rows,
    (SELECT count(*) FROM ops.setup_extra_material_inventory_event) AS physical_inventory_events,
    (SELECT count(*) FROM ops.setup_session WHERE season_year=2026) AS setup_2026_sessions;
SQL

DB_FINGERPRINT="$(prod_fingerprint)"
echo "Pre-deploy fingerprint: $PROD_BEFORE"
echo "Post-DB fingerprint:    $DB_FINGERPRINT"
if [[ "$DB_FINGERPRINT" != "$PROD_BEFORE" ]]; then
    echo "FAIL: migrations 032-037 changed governed Setup data"
    exit 11
fi
echo "PASS: migrations 032-037 installed without changing governed Setup data"

echo
echo "--- Fast-forward dedicated Setup Production checkout ---"
sudo git -C "$SETUP_ROOT" merge --ff-only "$TARGET_SHA"
APP_ADVANCED=1
DEPLOYED_HEAD="$(sudo git -C "$SETUP_ROOT" rev-parse HEAD)"
if [[ "$DEPLOYED_HEAD" != "$TARGET_SHA" ]]; then
    echo "FAIL: deployed Setup checkout is $DEPLOYED_HEAD, expected $TARGET_SHA"
    exit 12
fi
echo "Setup checkout advanced exactly to $DEPLOYED_HEAD"

echo
echo "--- Restart and verify Setup Production runtime ---"
restart_setup_service
SETUP_POST="$(curl -fsS http://192.168.5.9:8794/api/health)"
echo "Post-deploy Setup health: $SETUP_POST"
if [[ "$SETUP_POST" != *"\"status\":\"ok\""* \
   || "$SETUP_POST" != *"\"data_mode\":\"postgres\""* \
   || "$SETUP_POST" != *"\"version\":\"$EXPECTED_SETUP_VERSION\""* ]]; then
    echo "FAIL: Setup health/version does not match expected Production runtime"
    exit 13
fi

curl -fsS http://192.168.5.9:8794/kit-inventory/ | grep -Fq 'Expected Kit Contents'
curl -fsS http://192.168.5.9:8794/t-post-inventory/ | grep -Fq 'T-Post Inventory'
echo "Standalone Kit Inventory and T-Post routes: PASS"

NEGATIVE_CODE="$(curl -sS -o "$NEGATIVE_BODY" -w '%{http_code}' http://192.168.5.9:8794/api/setup/kit-inventory/kit-boxes)"
echo "Direct unauthenticated Kit Inventory API status: $NEGATIVE_CODE"
if [[ "$NEGATIVE_CODE" != "401" ]]; then
    echo "FAIL: protected Kit Inventory API did not reject unauthenticated direct request"
    cat "$NEGATIVE_BODY" || true
    exit 14
fi
echo "PROTECTED API NEGATIVE PATH: PASS"

echo
echo "--- Live shared Setup regression ---"
sudo -u fieldwiring -H bash -c \
    "cd '$SETUP_ROOT' && /opt/fieldwiring/.venv/bin/python -m pytest -q -p no:cacheprovider Setup/Application"
echo "LIVE SETUP REGRESSION: PASS"

echo
echo "--- Final Production invariants ---"
FINAL_HEAD="$(sudo git -C "$SETUP_ROOT" rev-parse HEAD)"
FINAL_STATUS="$(sudo git -C "$SETUP_ROOT" status --porcelain)"
FINAL_FINGERPRINT="$(prod_fingerprint)"
FINAL_2026="$(sudo docker exec "$PROD_CONTAINER" psql -X -qAt -v ON_ERROR_STOP=1 -U "$DB_ACTOR" -d "$PROD_DB" -c "SELECT count(*) FROM ops.setup_session WHERE season_year=2026;")"

echo "Final Setup SHA:         $FINAL_HEAD"
echo "Final Setup fingerprint: $FINAL_FINGERPRINT"
echo "2026 Setup Sessions:     $FINAL_2026"

[[ "$FINAL_HEAD" == "$TARGET_SHA" ]]
[[ -z "$FINAL_STATUS" ]]
[[ "$FINAL_FINGERPRINT" == "$PROD_BEFORE" ]]
[[ "$FINAL_2026" == "0" ]]

SUCCESS=1
echo
echo "SETUP_184_DURABLE_KIT_INVENTORY_PRODUCTION_DEPLOYMENT_PASS"
echo "Rollback archive: $BACKUP_FILE"
echo "Rollback SHA256:  $BACKUP_SHA"
echo "Deployment report: $REPORT"
