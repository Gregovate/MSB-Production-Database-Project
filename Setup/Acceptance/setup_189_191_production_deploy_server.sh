#!/usr/bin/env bash
set -euo pipefail

PROD_CONTAINER="msb-postgres"
PROD_DB="msb"
DB_ACTOR="msbadmin"
REPO_ROOT="/opt/fieldwiring"
SETUP_ROOT="/opt/msb-setup"
PYTHON="/opt/fieldwiring/.venv/bin/python"
SETUP_SERVICE="msb-setup.service"
DISPLAY_SERVICE="msb-display-folders.service"
GOOGLE_SERVICE="msb-setup-google-links.service"
FIELDWIRING_SERVICE="fieldwiring.service"
PROCEDURES_SERVICE="msb-procedures.service"
TARGET_REF="agent/setup-189-extra-material-catalog-ux"
TARGET_SHA="0322e32360d1cd5663812856c555fefe9770e029"
EXPECTED_SETUP_VERSION="V0.3.13-assignment-layer"
MIGRATION_REL="Setup/Database/049_add_setup_uom_catalog.sql"
MIGRATION_BLOB="221833519249e9367af37b5ffe2a2afa08141cb5"
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
BACKUP_DIR="/home/msbadmin/backups/setup-191"
REPORT_DIR="/home/msbadmin/setup-deployment-reports"
STAMP="$(date +%Y%m%dT%H%M%S)"
BACKUP_FILE="$BACKUP_DIR/msb-pre-setup-191-uom-$STAMP.dump"
REPORT="$REPORT_DIR/Setup_189_191_Production_Deploy_$STAMP.txt"
CANDIDATE_WORKTREE="/tmp/msb-setup-189-191-production-candidate-$STAMP"
NEGATIVE_BODY="/tmp/msb-setup-189-191-negative-$STAMP.txt"
M049=""
PROD_BEFORE=""
UOM_SOURCE_BEFORE=""
OLD_HEAD=""
DB_CHANGE_STARTED=0
APP_ADVANCED=0
SUCCESS=0
BACKUP_CREATED=0

mkdir -p "$REPORT_DIR"
exec > >(tee "$REPORT") 2>&1

echo "========== SETUP #189/#191 PRODUCTION DEPLOYMENT =========="
echo "Authority: Gregovate/MSB-Server-Management — docs/server/Production_Database_Change_Deployment_Runbook.md"
echo "Report:       $REPORT"
echo "Target SHA:   $TARGET_SHA"
echo "Target ref:   $TARGET_REF"
echo "Migration:    $MIGRATION_REL"
echo "Migration ID: $MIGRATION_BLOB"
echo "Setup root:   $SETUP_ROOT"
echo

psql_prod() {
    sudo docker exec -i "$PROD_CONTAINER" \
        psql -X -v ON_ERROR_STOP=1 -U "$DB_ACTOR" -d "$PROD_DB" "$@"
}

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

uom_source_fingerprint() {
    sudo docker exec "$PROD_CONTAINER" \
        psql -X -qAt -v ON_ERROR_STOP=1 -U "$DB_ACTOR" -d "$PROD_DB" -c "
            SELECT md5(
                coalesce((SELECT string_agg(row_to_json(m)::text, '' ORDER BY m.setup_extra_material_id) FROM ref.setup_extra_material m), '') || '|' ||
                coalesce((SELECT string_agg(row_to_json(tm)::text, '' ORDER BY tm.setup_task_extra_material_id) FROM ref.setup_task_extra_material tm), '') || '|' ||
                coalesce((SELECT string_agg(row_to_json(cm)::text, '' ORDER BY cm.setup_container_extra_material_id) FROM ref.setup_container_extra_material cm), '')
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

restart_setup_service() {
    sudo systemctl restart "$SETUP_SERVICE"
    wait_setup_ready
}

rollback_setup_191_database() {
    echo "Removing only migration-049 UOM governance objects..."
    psql_prod <<'SQL'
BEGIN;
ALTER TABLE ref.setup_extra_material
    DROP CONSTRAINT IF EXISTS fk_setup_extra_material_default_uom;
ALTER TABLE ref.setup_task_extra_material
    DROP CONSTRAINT IF EXISTS fk_setup_task_extra_material_quantity_uom;
ALTER TABLE ref.setup_container_extra_material
    DROP CONSTRAINT IF EXISTS fk_setup_container_extra_material_quantity_uom;

DROP TRIGGER IF EXISTS trg_setup_extra_material_active_uom ON ref.setup_extra_material;
DROP TRIGGER IF EXISTS trg_setup_task_extra_material_active_uom ON ref.setup_task_extra_material;
DROP TRIGGER IF EXISTS trg_setup_container_extra_material_active_uom ON ref.setup_container_extra_material;

DO $rollback$
BEGIN
    IF to_regclass('ref.setup_uom') IS NOT NULL THEN
        EXECUTE 'DROP TRIGGER IF EXISTS trg_setup_uom_identity_deactivation_guard ON ref.setup_uom';
        EXECUTE 'DROP TRIGGER IF EXISTS trg_setup_uom_actor_insert ON ref.setup_uom';
        EXECUTE 'DROP TRIGGER IF EXISTS trg_setup_uom_actor_update ON ref.setup_uom';
    END IF;
END
$rollback$;

DROP FUNCTION IF EXISTS ref.create_setup_uom(text,text,text,text);
DROP FUNCTION IF EXISTS ref.update_setup_uom(text,text,text,text,boolean,integer);
DROP FUNCTION IF EXISTS ref.enforce_active_setup_uom();
DROP FUNCTION IF EXISTS ref.guard_setup_uom_identity_and_deactivation();
DROP TABLE IF EXISTS ref.setup_uom;
COMMIT;
SQL
}

cleanup() {
    status=$?
    trap - EXIT HUP INT TERM
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
            rollback_setup_191_database || true
        fi
    fi

    if sudo git -C "$REPO_ROOT" worktree list --porcelain 2>/dev/null | grep -Fq "worktree $CANDIDATE_WORKTREE"; then
        sudo git -C "$REPO_ROOT" worktree remove --force "$CANDIDATE_WORKTREE" >/dev/null 2>&1 || true
    fi
    sudo git -C "$REPO_ROOT" worktree prune >/dev/null 2>&1 || true
    rm -f "$NEGATIVE_BODY" >/dev/null 2>&1 || true
    rm -rf "$SCRIPT_DIR" >/dev/null 2>&1 || true

    echo
    echo "--- Production after-check ---"
    if [[ -n "$PROD_BEFORE" ]]; then
        PROD_AFTER="$(prod_fingerprint 2>/dev/null)"
        echo "Production Setup fingerprint before: $PROD_BEFORE"
        echo "Production Setup fingerprint after:  $PROD_AFTER"
        if [[ -z "$PROD_AFTER" || "$PROD_AFTER" != "$PROD_BEFORE" ]]; then
            echo "FAIL: Production Setup governed data fingerprint changed"
            status=97
        else
            echo "PASS: Production Setup governed data fingerprint unchanged"
        fi
    fi

    if [[ -n "$UOM_SOURCE_BEFORE" ]]; then
        UOM_SOURCE_AFTER="$(uom_source_fingerprint 2>/dev/null)"
        echo "Extra Material source fingerprint before: $UOM_SOURCE_BEFORE"
        echo "Extra Material source fingerprint after:  $UOM_SOURCE_AFTER"
        if [[ -z "$UOM_SOURCE_AFTER" || "$UOM_SOURCE_AFTER" != "$UOM_SOURCE_BEFORE" ]]; then
            echo "FAIL: existing Extra Material/task/Container rows changed"
            status=98
        else
            echo "PASS: existing Extra Material/task/Container rows unchanged"
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
trap cleanup EXIT HUP INT TERM

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
if [[ -n "$(sudo git -C "$REPO_ROOT" status --porcelain)" ]]; then
    echo "FAIL: shared repository checkout has uncommitted changes"
    sudo git -C "$REPO_ROOT" status -sb
    exit 5
fi

OLD_HEAD="$(sudo git -C "$SETUP_ROOT" rev-parse HEAD)"
echo "Verified live Setup checkout: $OLD_HEAD"
if [[ -n "$(sudo git -C "$SETUP_ROOT" status --porcelain)" ]]; then
    echo "FAIL: live Setup checkout has uncommitted changes"
    sudo git -C "$SETUP_ROOT" status -sb
    exit 6
fi

for service in "$SETUP_SERVICE" "$DISPLAY_SERVICE" "$GOOGLE_SERVICE" "$FIELDWIRING_SERVICE" "$PROCEDURES_SERVICE"; do
    if ! systemctl is-active --quiet "$service"; then
        echo "FAIL: required Production service is not active before deployment: $service"
        exit 7
    fi
done

SETUP_PRE="$(curl -fsS http://192.168.5.9:8794/api/health)"
FW_PRE="$(curl -fsS http://192.168.5.9:8790/api/health)"
PR_PRE="$(curl -fsS http://192.168.5.9:8792/api/health)"
echo "Pre-deploy Setup health:       $SETUP_PRE"
echo "Pre-deploy FieldWiring health: $FW_PRE"
echo "Pre-deploy Procedures health:  $PR_PRE"

PROD_BEFORE="$(prod_fingerprint)"
UOM_SOURCE_BEFORE="$(uom_source_fingerprint)"
[[ -n "$PROD_BEFORE" ]] || { echo "FAIL: Production Setup fingerprint is empty"; exit 8; }
[[ -n "$UOM_SOURCE_BEFORE" ]] || { echo "FAIL: Extra Material source fingerprint is empty"; exit 9; }
echo "Pre-deploy Setup fingerprint:          $PROD_BEFORE"
echo "Pre-deploy Extra Material fingerprint: $UOM_SOURCE_BEFORE"

echo
echo "--- Fetch and verify exact operator-approved target ---"
sudo git -C "$REPO_ROOT" fetch origin "$TARGET_REF"
sudo git -C "$REPO_ROOT" cat-file -e "$TARGET_SHA^{commit}"
if ! sudo git -C "$REPO_ROOT" merge-base --is-ancestor "$OLD_HEAD" "$TARGET_SHA"; then
    echo "FAIL: accepted Setup target is not a fast-forward descendant of verified live Setup checkout"
    echo "Live:   $OLD_HEAD"
    echo "Target: $TARGET_SHA"
    exit 10
fi
echo "Verified fast-forward ancestry: $OLD_HEAD -> $TARGET_SHA"

ACTUAL_MIGRATION_BLOB="$(sudo git -C "$REPO_ROOT" rev-parse "$TARGET_SHA:$MIGRATION_REL")"
if [[ "$ACTUAL_MIGRATION_BLOB" != "$MIGRATION_BLOB" ]]; then
    echo "FAIL: accepted migration blob mismatch"
    echo "Expected: $MIGRATION_BLOB"
    echo "Actual:   $ACTUAL_MIGRATION_BLOB"
    exit 11
fi
echo "Accepted migration Git blob identity: PASS ($ACTUAL_MIGRATION_BLOB)"

echo
echo "--- Detached Production-runtime candidate regression ---"
sudo git -C "$REPO_ROOT" worktree add --detach "$CANDIDATE_WORKTREE" "$TARGET_SHA"
M049="$CANDIDATE_WORKTREE/$MIGRATION_REL"
[[ -s "$M049" ]] || { echo "FAIL: accepted target is missing migration 049"; exit 12; }
sudo -u fieldwiring -H bash -c \
    "cd '$CANDIDATE_WORKTREE' && '$PYTHON' -m pytest -q -p no:cacheprovider Setup/Application"
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
    IF to_regclass('ref.setup_extra_material') IS NULL
       OR to_regclass('ref.setup_task_extra_material') IS NULL
       OR to_regclass('ref.setup_container_extra_material') IS NULL
       OR to_regprocedure('ref.create_setup_extra_material(text,text,text,text,text)') IS NULL
       OR to_regprocedure('ref.update_setup_extra_material(text,integer,text,text,text,text,boolean,integer)') IS NULL
       OR to_regprocedure('ref.setup_management_actor(text,boolean)') IS NULL THEN
        RAISE EXCEPTION 'Current durable Extra Material foundation is incomplete';
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname='fieldwiring_app') THEN
        RAISE EXCEPTION 'Required fieldwiring_app role does not exist';
    END IF;
    IF to_regclass('ref.setup_uom') IS NOT NULL
       OR to_regprocedure('ref.create_setup_uom(text,text,text,text)') IS NOT NULL
       OR to_regprocedure('ref.update_setup_uom(text,text,text,text,boolean,integer)') IS NOT NULL THEN
        RAISE EXCEPTION 'Migration 049 UOM governance already exists; reconcile before deployment';
    END IF;
    IF EXISTS (
        SELECT 1
        FROM (
            SELECT default_uom AS uom_code FROM ref.setup_extra_material
            UNION ALL SELECT quantity_uom FROM ref.setup_task_extra_material
            UNION ALL SELECT quantity_uom FROM ref.setup_container_extra_material
        ) x
        WHERE x.uom_code IS DISTINCT FROM upper(btrim(x.uom_code))
           OR x.uom_code !~ '^[A-Z0-9][A-Z0-9._/-]{0,15}$'
    ) THEN
        RAISE EXCEPTION 'Current UOM values are not already canonical; stop before migration 049';
    END IF;
    IF EXISTS (
        SELECT 1
        FROM ref.setup_task_extra_material
        WHERE active_flag
        GROUP BY setup_task_id, setup_extra_material_id, upper(btrim(quantity_uom)),
                 coalesce(lower(btrim(size_text)), ''), coalesce(length_value, -1::numeric),
                 coalesce(length_unit, ''), coalesce(lower(btrim(color)), '')
        HAVING count(*) > 1
    ) THEN
        RAISE EXCEPTION 'UOM normalization would collide active task Extra Material rows';
    END IF;
    IF EXISTS (
        SELECT 1
        FROM ref.setup_container_extra_material
        WHERE active_flag
        GROUP BY container_id, setup_extra_material_id, upper(btrim(quantity_uom)),
                 coalesce(lower(btrim(size_text)), ''), coalesce(length_value, -1::numeric),
                 coalesce(length_unit, ''), coalesce(lower(btrim(color)), '')
        HAVING count(*) > 1
    ) THEN
        RAISE EXCEPTION 'UOM normalization would collide active Container Extra Material rows';
    END IF;
    IF EXISTS (SELECT 1 FROM ops.setup_session WHERE season_year=2026) THEN
        RAISE EXCEPTION '2026 Setup Session exists before #189/#191 deployment';
    END IF;
END
$preflight$;
SQL

echo "DATABASE PREFLIGHT: PASS"

PRE_MUTATION_FINGERPRINT="$(prod_fingerprint)"
PRE_MUTATION_UOM_SOURCE="$(uom_source_fingerprint)"
if [[ "$PRE_MUTATION_FINGERPRINT" != "$PROD_BEFORE" || "$PRE_MUTATION_UOM_SOURCE" != "$UOM_SOURCE_BEFORE" ]]; then
    echo "FAIL: Production data changed during pre-deployment validation; stop before mutation"
    exit 13
fi
echo "PRE-MUTATION FINGERPRINT STABILITY: PASS"

echo
echo "--- Apply reviewed migration 049 ---"
DB_CHANGE_STARTED=1
psql_prod < "$M049"

echo
echo "--- Validate #191 UOM database contract ---"
psql_prod <<'SQL'
DO $validate$
BEGIN
    IF to_regclass('ref.setup_uom') IS NULL THEN
        RAISE EXCEPTION 'ref.setup_uom was not installed';
    END IF;
    IF (SELECT count(*) FROM ref.setup_uom WHERE active_flag AND uom_code IN ('EA','FT','IN','SHEET','SET','ROLL','CAN')) <> 7 THEN
        RAISE EXCEPTION 'Canonical starter UOM set is incomplete';
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname='fk_setup_extra_material_default_uom' AND contype='f' AND convalidated)
       OR NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname='fk_setup_task_extra_material_quantity_uom' AND contype='f' AND convalidated)
       OR NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname='fk_setup_container_extra_material_quantity_uom' AND contype='f' AND convalidated) THEN
        RAISE EXCEPTION 'Expected validated UOM foreign keys are incomplete';
    END IF;
    IF EXISTS (
        SELECT 1 FROM ref.setup_extra_material m LEFT JOIN ref.setup_uom u ON u.uom_code=m.default_uom
        WHERE u.uom_code IS NULL OR (m.active_flag AND NOT u.active_flag)
    ) OR EXISTS (
        SELECT 1 FROM ref.setup_task_extra_material tm LEFT JOIN ref.setup_uom u ON u.uom_code=tm.quantity_uom
        WHERE u.uom_code IS NULL OR (tm.active_flag AND NOT u.active_flag)
    ) OR EXISTS (
        SELECT 1 FROM ref.setup_container_extra_material cm LEFT JOIN ref.setup_uom u ON u.uom_code=cm.quantity_uom
        WHERE u.uom_code IS NULL OR (cm.active_flag AND NOT u.active_flag)
    ) THEN
        RAISE EXCEPTION 'Extra Material UOM referential/active-state contract failed';
    END IF;
    IF NOT has_table_privilege('fieldwiring_app','ref.setup_uom','SELECT')
       OR NOT has_function_privilege('fieldwiring_app','ref.create_setup_uom(text,text,text,text)','EXECUTE')
       OR NOT has_function_privilege('fieldwiring_app','ref.update_setup_uom(text,text,text,text,boolean,integer)','EXECUTE') THEN
        RAISE EXCEPTION 'Required governed UOM read/command privileges are missing';
    END IF;
    IF has_table_privilege('fieldwiring_app','ref.setup_uom','INSERT')
       OR has_table_privilege('fieldwiring_app','ref.setup_uom','UPDATE')
       OR has_table_privilege('fieldwiring_app','ref.setup_uom','DELETE') THEN
        RAISE EXCEPTION 'Forbidden broad UOM table DML privilege detected';
    END IF;
    IF EXISTS (SELECT 1 FROM ops.setup_session WHERE season_year=2026) THEN
        RAISE EXCEPTION '#189/#191 deployment created a 2026 Setup Session';
    END IF;
END
$validate$;

SELECT uom_code, display_name, active_flag, display_order
FROM ref.setup_uom
ORDER BY display_order, uom_code;
SQL

POST_DB_FINGERPRINT="$(prod_fingerprint)"
POST_DB_UOM_SOURCE="$(uom_source_fingerprint)"
if [[ "$POST_DB_FINGERPRINT" != "$PROD_BEFORE" ]]; then
    echo "FAIL: migration 049 changed governed Setup data outside its catalog"
    exit 14
fi
if [[ "$POST_DB_UOM_SOURCE" != "$UOM_SOURCE_BEFORE" ]]; then
    echo "FAIL: migration 049 rewrote existing Extra Material/task/Container rows"
    exit 15
fi
echo "PASS: migration 049 installed without changing existing Setup/Extra Material rows"

echo
echo "--- Fast-forward dedicated Setup Production checkout ---"
sudo git -C "$SETUP_ROOT" merge --ff-only "$TARGET_SHA"
APP_ADVANCED=1
DEPLOYED_HEAD="$(sudo git -C "$SETUP_ROOT" rev-parse HEAD)"
if [[ "$DEPLOYED_HEAD" != "$TARGET_SHA" ]]; then
    echo "FAIL: deployed Setup checkout is $DEPLOYED_HEAD, expected $TARGET_SHA"
    exit 16
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
    exit 17
fi

curl -fsS http://192.168.5.9:8794/kit-inventory/ | grep -Fq 'Find or edit an existing catalog material'
curl -fsS http://192.168.5.9:8794/kit-inventory/assets/setup_uom_catalog.js | grep -Fq 'Issue #191'
echo "Kit Inventory accepted UX and governed UOM asset: PASS"

NEGATIVE_CODE="$(curl -sS -o "$NEGATIVE_BODY" -w '%{http_code}' http://192.168.5.9:8794/api/setup/uoms)"
echo "Direct unauthenticated UOM API status: $NEGATIVE_CODE"
if [[ "$NEGATIVE_CODE" != "401" ]]; then
    echo "FAIL: protected UOM API did not reject unauthenticated direct request"
    cat "$NEGATIVE_BODY" || true
    exit 18
fi
echo "PROTECTED UOM API NEGATIVE PATH: PASS"

echo
echo "--- Live shared Setup regression ---"
sudo -u fieldwiring -H bash -c \
    "cd '$SETUP_ROOT' && '$PYTHON' -m pytest -q -p no:cacheprovider Setup/Application"
echo "LIVE SETUP REGRESSION: PASS"

echo
echo "--- Final Production invariants ---"
FINAL_HEAD="$(sudo git -C "$SETUP_ROOT" rev-parse HEAD)"
FINAL_STATUS="$(sudo git -C "$SETUP_ROOT" status --porcelain)"
FINAL_FINGERPRINT="$(prod_fingerprint)"
FINAL_UOM_SOURCE="$(uom_source_fingerprint)"
FINAL_2026="$(sudo docker exec "$PROD_CONTAINER" psql -X -qAt -v ON_ERROR_STOP=1 -U "$DB_ACTOR" -d "$PROD_DB" -c "SELECT count(*) FROM ops.setup_session WHERE season_year=2026;")"
FINAL_UOM_ROWS="$(sudo docker exec "$PROD_CONTAINER" psql -X -qAt -v ON_ERROR_STOP=1 -U "$DB_ACTOR" -d "$PROD_DB" -c "SELECT count(*) FROM ref.setup_uom;")"

echo "Final Setup SHA:                  $FINAL_HEAD"
echo "Final Setup fingerprint:          $FINAL_FINGERPRINT"
echo "Final Extra Material fingerprint: $FINAL_UOM_SOURCE"
echo "Final UOM catalog rows:           $FINAL_UOM_ROWS"
echo "2026 Setup Sessions:              $FINAL_2026"

[[ "$FINAL_HEAD" == "$TARGET_SHA" ]]
[[ -z "$FINAL_STATUS" ]]
[[ "$FINAL_FINGERPRINT" == "$PROD_BEFORE" ]]
[[ "$FINAL_UOM_SOURCE" == "$UOM_SOURCE_BEFORE" ]]
[[ "$FINAL_2026" == "0" ]]
[[ "$FINAL_UOM_ROWS" -ge 7 ]]

SUCCESS=1
echo
echo "SETUP_189_191_PRODUCTION_DEPLOYMENT_PASS"
echo "Rollback archive:  $BACKUP_FILE"
echo "Rollback SHA256:   $BACKUP_SHA"
echo "Deployment report: $REPORT"
