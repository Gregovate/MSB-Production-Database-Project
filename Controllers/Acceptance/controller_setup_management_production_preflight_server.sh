#!/usr/bin/env bash
set -euo pipefail

PROD_CONTAINER="msb-postgres"
PROD_DB="msb"
DB_ACTOR="msbadmin"
FIELDWIRING_ROOT="/opt/fieldwiring"
FIELDWIRING_SERVICE="fieldwiring.service"
PROCEDURES_SERVICE="msb-procedures.service"
TARGET_REF="agent/controller-inventory-ref-sandbox"
TARGET_SHA="2fd2067958cc0a903260fe6f089f88ae63a857f1"
BACKUP_DIR="/home/msbadmin/backups/postgres"
STAMP="$(date +%Y%m%dT%H%M%S)"
TEST_BACKUP_FILE="$BACKUP_DIR/msb-preflight-controller-setup-management-$STAMP.dump"
REPORT="/tmp/MSB_Controller_Setup_Management_Production_Preflight_$STAMP.txt"
CANDIDATE_WORKTREE="/tmp/msb-controller-setup-management-preflight-$STAMP"
PROD_BEFORE=""
BACKUP_CREATED=0

exec > >(tee "$REPORT") 2>&1

echo "========== CONTROLLER SETUP + MANAGEMENT PRODUCTION PREFLIGHT =========="
echo "Report:     $REPORT"
echo "Target SHA: $TARGET_SHA"
echo "Mode:       READ-ONLY DATABASE / NO CHECKOUT MOVEMENT / NO SERVICE RESTART"
echo

prod_fingerprint() {
    sudo docker exec "$PROD_CONTAINER" \
        psql -X -qAt -v ON_ERROR_STOP=1 -U "$DB_ACTOR" -d "$PROD_DB" -c "
            SELECT md5(
                coalesce((
                    SELECT string_agg(row_to_json(c)::text, '' ORDER BY c.controller_id)
                    FROM ref.controller c
                ), '') || '|' ||
                coalesce((
                    SELECT string_agg(row_to_json(cd)::text, '' ORDER BY cd.controller_id, cd.display_id)
                    FROM ref.controller_display cd
                ), '') || '|' ||
                coalesce((
                    SELECT string_agg(row_to_json(h)::text, '' ORDER BY h.controller_firmware_history_id)
                    FROM ref.controller_firmware_history h
                ), '')
            );
        "
}

psql_prod() {
    sudo docker exec -i "$PROD_CONTAINER" \
        psql -X -v ON_ERROR_STOP=1 -U "$DB_ACTOR" -d "$PROD_DB" "$@"
}

cleanup() {
    status=$?
    trap - EXIT INT TERM
    set +e

    if sudo git -C "$FIELDWIRING_ROOT" worktree list --porcelain 2>/dev/null | grep -Fq "worktree $CANDIDATE_WORKTREE"; then
        sudo git -C "$FIELDWIRING_ROOT" worktree remove --force "$CANDIDATE_WORKTREE" >/dev/null 2>&1 || true
    fi

    if [[ "$BACKUP_CREATED" -eq 1 && -f "$TEST_BACKUP_FILE" ]]; then
        rm -f "$TEST_BACKUP_FILE" || true
        echo "Removed temporary preflight rollback archive: $TEST_BACKUP_FILE"
    fi

    echo
    echo "--- Production Controller fingerprint after-check ---"
    if [[ -n "$PROD_BEFORE" ]]; then
        PROD_AFTER="$(prod_fingerprint 2>/dev/null)"
        echo "Before: $PROD_BEFORE"
        echo "After:  $PROD_AFTER"
        if [[ "$PROD_AFTER" != "$PROD_BEFORE" ]]; then
            echo "FAIL: production Controller fingerprint changed during preflight"
            status=97
        else
            echo "PASS: production Controller fingerprint unchanged"
        fi
    fi

    echo "Preflight report retained at: $REPORT"
    echo "Exit status: $status"
    exit "$status"
}
trap cleanup EXIT INT TERM

sudo -v
mkdir -p "$BACKUP_DIR"

if ! sudo docker inspect "$PROD_CONTAINER" >/dev/null 2>&1; then
    echo "FAIL: production PostgreSQL container $PROD_CONTAINER not found"
    exit 2
fi

OLD_HEAD="$(sudo git -C "$FIELDWIRING_ROOT" rev-parse HEAD)"
echo "Verified live checkout: $OLD_HEAD"
if [[ -n "$(sudo git -C "$FIELDWIRING_ROOT" status --porcelain)" ]]; then
    echo "FAIL: live shared checkout has uncommitted changes"
    sudo git -C "$FIELDWIRING_ROOT" status -sb
    exit 3
fi

if ! systemctl is-active --quiet "$FIELDWIRING_SERVICE" \
   || ! systemctl is-active --quiet "$PROCEDURES_SERVICE"; then
    echo "FAIL: shared production services are not active before preflight"
    exit 4
fi

FW_PRE="$(curl -fsS http://192.168.5.9:8790/api/health)"
PR_PRE="$(curl -fsS http://192.168.5.9:8792/api/health)"
echo "FieldWiring health: $FW_PRE"
echo "Procedures health:  $PR_PRE"

PROD_BEFORE="$(prod_fingerprint)"
echo "Production Controller fingerprint: $PROD_BEFORE"

echo
echo "--- Fetch and verify exact accepted target ---"
sudo git -C "$FIELDWIRING_ROOT" fetch origin "$TARGET_REF"
sudo git -C "$FIELDWIRING_ROOT" cat-file -e "$TARGET_SHA^{commit}"
if ! sudo git -C "$FIELDWIRING_ROOT" merge-base --is-ancestor "$OLD_HEAD" "$TARGET_SHA"; then
    echo "FAIL: accepted target is not a fast-forward descendant of the verified live checkout"
    exit 5
fi
echo "Verified fast-forward ancestry: $OLD_HEAD -> $TARGET_SHA"

echo
echo "--- Detached production-runtime candidate regression ---"
sudo git -C "$FIELDWIRING_ROOT" worktree add --detach "$CANDIDATE_WORKTREE" "$TARGET_SHA"
MIGRATION_023="$CANDIDATE_WORKTREE/Controllers/Database/023_create_controller_management_commands.sql"
MIGRATION_024="$CANDIDATE_WORKTREE/Controllers/Database/024_harden_controller_assignment_capability.sql"
for required_file in "$MIGRATION_023" "$MIGRATION_024"; do
    if [[ ! -s "$required_file" ]]; then
        echo "FAIL: accepted target is missing reviewed migration $required_file"
        exit 6
    fi
done
sudo -u fieldwiring -H bash -c \
    "cd '$CANDIDATE_WORKTREE' && /opt/fieldwiring/.venv/bin/python -m pytest -q -p no:cacheprovider FieldWiring/Application Procedures/Application"
echo "DETACHED CANDIDATE REGRESSION: PASS"

echo
echo "--- Test rollback archive creation/validation ---"
sudo docker exec "$PROD_CONTAINER" \
    pg_dump -U "$DB_ACTOR" -d "$PROD_DB" -Fc > "$TEST_BACKUP_FILE"
test -s "$TEST_BACKUP_FILE"
BACKUP_CREATED=1
BACKUP_SHA="$(sha256sum "$TEST_BACKUP_FILE" | awk '{print $1}')"
sudo docker exec -i "$PROD_CONTAINER" pg_restore --list < "$TEST_BACKUP_FILE" >/dev/null
echo "Temporary rollback archive: $TEST_BACKUP_FILE"
echo "SHA256:                   $BACKUP_SHA"
echo "ROLLBACK ARCHIVE TEST: PASS"

echo
echo "--- Production database preflight (read-only) ---"
psql_prod <<'SQL'
DO $block$
BEGIN
    IF to_regprocedure('ref.controller_browser_capabilities(text)') IS NULL
       OR to_regprocedure('ref.request_controller_label(text,bigint)') IS NULL THEN
        RAISE EXCEPTION 'Production Controller browser migrations 021/022 are required before 023/024';
    END IF;

    IF to_regprocedure('ref.controller_management_actor(text)') IS NOT NULL
       OR to_regprocedure('ref.controller_management_options(text)') IS NOT NULL
       OR to_regprocedure('ref.create_controller(text,integer,integer,text,integer,text,text,text,integer,text,boolean,text,text,boolean,text,integer,integer,text,text,text)') IS NOT NULL
       OR to_regprocedure('ref.update_controller(text,bigint,integer,integer,text,integer,text,text,text,integer,text,boolean,text,text,boolean,text,integer,integer,text,text,text)') IS NOT NULL
       OR to_regprocedure('ref.assign_controller_display(text,bigint,bigint,bigint,text,text,boolean)') IS NOT NULL
       OR to_regprocedure('ref.update_controller_display_assignment(text,bigint,bigint,bigint,text,text)') IS NOT NULL
       OR to_regprocedure('ref.reassign_controller_display(text,bigint,bigint,bigint,bigint,text,text)') IS NOT NULL
       OR to_regprocedure('ref.unassign_controller_display(text,bigint,bigint,boolean)') IS NOT NULL THEN
        RAISE EXCEPTION 'One or more Controller management functions already exist; stop for review';
    END IF;

    IF has_table_privilege('fieldwiring_app', 'ref.controller', 'INSERT')
       OR has_table_privilege('fieldwiring_app', 'ref.controller', 'UPDATE')
       OR has_table_privilege('fieldwiring_app', 'ref.controller', 'DELETE')
       OR has_table_privilege('fieldwiring_app', 'ref.controller_display', 'INSERT')
       OR has_table_privilege('fieldwiring_app', 'ref.controller_display', 'UPDATE')
       OR has_table_privilege('fieldwiring_app', 'ref.controller_display', 'DELETE') THEN
        RAISE EXCEPTION 'fieldwiring_app unexpectedly has broad Controller table DML before deployment';
    END IF;
END
$block$;
SQL
echo "DATABASE PREFLIGHT: PASS"

echo
echo "--- Live negative security checks (no identity) ---"
ACCESS_CODE="$(curl -sS -o /tmp/controller-preflight-access-$STAMP.json -w '%{http_code}' http://192.168.5.9:8790/api/controller-access)"
cat /tmp/controller-preflight-access-$STAMP.json
rm -f /tmp/controller-preflight-access-$STAMP.json
if [[ "$ACCESS_CODE" != "401" ]]; then
    echo "FAIL: /api/controller-access without Cloudflare identity returned HTTP $ACCESS_CODE, expected 401"
    exit 7
fi

echo
echo "PRODUCTION PREFLIGHT STOP POINT REACHED"
echo "No migrations applied. No checkout movement. No service restart."
echo "CONTROLLER SETUP + MANAGEMENT PRODUCTION PREFLIGHT: PASS"
