#!/usr/bin/env bash
set -euo pipefail

PROD_CONTAINER="msb-postgres"
PROD_DB="msb"
DB_ACTOR="msbadmin"
FIELDWIRING_ROOT="/opt/fieldwiring"
FIELDWIRING_SERVICE="fieldwiring.service"
PROCEDURES_SERVICE="msb-procedures.service"
TARGET_REF="agent/controller-inventory-ref-sandbox"
TARGET_SHA="63be47f40be78f608416935ed0583287da9d90e6"
EXPECTED_FIELDWIRING_VERSION="V0.4.0"
EXPECTED_PROCEDURES_VERSION="V0.1.0"
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
BACKUP_DIR="/home/msbadmin/backups/postgres"
STAMP="$(date +%Y%m%dT%H%M%S)"
BACKUP_FILE="$BACKUP_DIR/msb-pre-controller-setup-management-$STAMP.dump"
REPORT="/tmp/MSB_Controller_Setup_Management_Production_Deploy_$STAMP.txt"
CANDIDATE_WORKTREE="/tmp/msb-controller-setup-management-candidate-$STAMP"
MIGRATION_023=""
MIGRATION_024=""
PROD_BEFORE=""
OLD_HEAD=""
DB_CHANGE_STARTED=0
APP_ADVANCED=0
SUCCESS=0
BACKUP_CREATED=0

exec > >(tee "$REPORT") 2>&1

echo "========== CONTROLLER SETUP + MANAGEMENT PRODUCTION DEPLOYMENT =========="
echo "Report:      $REPORT"
echo "Target SHA:  $TARGET_SHA"
echo "Target ref:  $TARGET_REF"
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

restart_shared_services() {
    sudo systemctl restart "$FIELDWIRING_SERVICE" "$PROCEDURES_SERVICE"
    for _ in $(seq 1 45); do
        if systemctl is-active --quiet "$FIELDWIRING_SERVICE" \
           && systemctl is-active --quiet "$PROCEDURES_SERVICE" \
           && curl -fsS http://192.168.5.9:8790/api/health >/dev/null 2>&1 \
           && curl -fsS http://192.168.5.9:8792/api/health >/dev/null 2>&1; then
            return 0
        fi
        sleep 1
    done
    return 1
}

rollback_management_functions() {
    echo "Removing Controller setup/management functions installed by 023/024..."
    psql_prod <<'SQL'
BEGIN;
DROP FUNCTION IF EXISTS ref.unassign_controller_display(text, bigint, bigint, boolean);
DROP FUNCTION IF EXISTS ref.reassign_controller_display(text, bigint, bigint, bigint, bigint, text, text);
DROP FUNCTION IF EXISTS ref.update_controller_display_assignment(text, bigint, bigint, bigint, text, text);
DROP FUNCTION IF EXISTS ref.assign_controller_display(text, bigint, bigint, bigint, text, text, boolean);
DROP FUNCTION IF EXISTS ref.update_controller(text, bigint, integer, integer, text, integer, text, text, text, integer, text, boolean, text, text, boolean, text, integer, integer, text, text, text);
DROP FUNCTION IF EXISTS ref.create_controller(text, integer, integer, text, integer, text, text, text, integer, text, boolean, text, text, boolean, text, integer, integer, text, text, text);
DROP FUNCTION IF EXISTS ref.controller_management_options(text);
DROP FUNCTION IF EXISTS ref.controller_management_actor(text);
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
            echo "Restoring shared checkout to $OLD_HEAD"
            sudo git -C "$FIELDWIRING_ROOT" reset --hard "$OLD_HEAD"
            restart_shared_services || true
        fi
        if [[ "$DB_CHANGE_STARTED" -eq 1 ]]; then
            rollback_management_functions || true
        fi
    fi

    if sudo git -C "$FIELDWIRING_ROOT" worktree list --porcelain 2>/dev/null | grep -Fq "worktree $CANDIDATE_WORKTREE"; then
        sudo git -C "$FIELDWIRING_ROOT" worktree remove --force "$CANDIDATE_WORKTREE" >/dev/null 2>&1 || true
    fi
    rm -rf "$SCRIPT_DIR" >/dev/null 2>&1 || true

    echo
    echo "--- Production Controller fingerprint after-check ---"
    if [[ -n "$PROD_BEFORE" ]]; then
        PROD_AFTER="$(prod_fingerprint 2>/dev/null)"
        echo "Before: $PROD_BEFORE"
        echo "After:  $PROD_AFTER"
        if [[ "$PROD_AFTER" != "$PROD_BEFORE" ]]; then
            echo "FAIL: production Controller fingerprint changed during deployment"
            status=97
        else
            echo "PASS: production Controller fingerprint unchanged"
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
    echo "FAIL: shared production services are not active before deployment"
    exit 4
fi

FW_PRE="$(curl -fsS http://192.168.5.9:8790/api/health)"
PR_PRE="$(curl -fsS http://192.168.5.9:8792/api/health)"
echo "Pre-deploy FieldWiring health: $FW_PRE"
echo "Pre-deploy Procedures health:  $PR_PRE"

PROD_BEFORE="$(prod_fingerprint)"
echo "Pre-deploy Controller fingerprint: $PROD_BEFORE"

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
echo "--- Apply accepted migrations 023 / 024 ---"
DB_CHANGE_STARTED=1
sudo docker exec -i "$PROD_CONTAINER" \
    psql -X -v ON_ERROR_STOP=1 -U "$DB_ACTOR" -d "$PROD_DB" \
    < "$MIGRATION_023"
sudo docker exec -i "$PROD_CONTAINER" \
    psql -X -v ON_ERROR_STOP=1 -U "$DB_ACTOR" -d "$PROD_DB" \
    < "$MIGRATION_024"

echo
echo "--- Validate production management boundary ---"
psql_prod <<'SQL'
DO $block$
DECLARE
    v_email text;
    v_options jsonb;
BEGIN
    IF has_function_privilege('fieldwiring_app', 'ref.controller_management_actor(text)', 'EXECUTE') THEN
        RAISE EXCEPTION 'fieldwiring_app must not execute internal controller_management_actor';
    END IF;
    IF NOT has_function_privilege('fieldwiring_app', 'ref.controller_management_options(text)', 'EXECUTE')
       OR NOT has_function_privilege('fieldwiring_app', 'ref.create_controller(text,integer,integer,text,integer,text,text,text,integer,text,boolean,text,text,boolean,text,integer,integer,text,text,text)', 'EXECUTE')
       OR NOT has_function_privilege('fieldwiring_app', 'ref.update_controller(text,bigint,integer,integer,text,integer,text,text,text,integer,text,boolean,text,text,boolean,text,integer,integer,text,text,text)', 'EXECUTE')
       OR NOT has_function_privilege('fieldwiring_app', 'ref.assign_controller_display(text,bigint,bigint,bigint,text,text,boolean)', 'EXECUTE')
       OR NOT has_function_privilege('fieldwiring_app', 'ref.update_controller_display_assignment(text,bigint,bigint,bigint,text,text)', 'EXECUTE')
       OR NOT has_function_privilege('fieldwiring_app', 'ref.reassign_controller_display(text,bigint,bigint,bigint,bigint,text,text)', 'EXECUTE')
       OR NOT has_function_privilege('fieldwiring_app', 'ref.unassign_controller_display(text,bigint,bigint,boolean)', 'EXECUTE') THEN
        RAISE EXCEPTION 'fieldwiring_app lacks one or more required Controller management command privileges';
    END IF;

    IF has_table_privilege('fieldwiring_app', 'ref.controller', 'INSERT')
       OR has_table_privilege('fieldwiring_app', 'ref.controller', 'UPDATE')
       OR has_table_privilege('fieldwiring_app', 'ref.controller', 'DELETE')
       OR has_table_privilege('fieldwiring_app', 'ref.controller_display', 'INSERT')
       OR has_table_privilege('fieldwiring_app', 'ref.controller_display', 'UPDATE')
       OR has_table_privilege('fieldwiring_app', 'ref.controller_display', 'DELETE') THEN
        RAISE EXCEPTION 'fieldwiring_app unexpectedly gained broad Controller table DML';
    END IF;

    SELECT u.email INTO v_email
    FROM public.directus_users u
    JOIN ref.person p ON p.directus_user_id = u.id
    JOIN LATERAL ref.controller_browser_capabilities(u.email) c ON true
    WHERE u.status = 'active'
      AND c.can_manage_controllers
    ORDER BY u.email
    LIMIT 1;
    IF v_email IS NULL THEN
        RAISE EXCEPTION 'No active mapped Manager/Admin is available for production validation';
    END IF;

    SELECT ref.controller_management_options(v_email) INTO v_options;
    IF jsonb_array_length(v_options->'models') = 0
       OR jsonb_array_length(v_options->'statuses') = 0
       OR jsonb_array_length(v_options->'planning_stages') = 0
       OR jsonb_array_length(v_options->'planning_lor_uid_usage') = 0 THEN
        RAISE EXCEPTION 'Controller management/planning options are incomplete in production';
    END IF;
END
$block$;
SQL

echo "PRODUCTION MANAGEMENT BOUNDARY: PASS"

DB_AFTER_MIGRATIONS="$(prod_fingerprint)"
if [[ "$DB_AFTER_MIGRATIONS" != "$PROD_BEFORE" ]]; then
    echo "FAIL: Controller governed table data changed while installing management functions"
    exit 7
fi
echo "PASS: migrations installed functions without changing Controller governed data"

echo
echo "--- Fast-forward shared production checkout ---"
sudo git -C "$FIELDWIRING_ROOT" merge --ff-only "$TARGET_SHA"
APP_ADVANCED=1
DEPLOYED_HEAD="$(sudo git -C "$FIELDWIRING_ROOT" rev-parse HEAD)"
if [[ "$DEPLOYED_HEAD" != "$TARGET_SHA" ]]; then
    echo "FAIL: deployed checkout is $DEPLOYED_HEAD, expected $TARGET_SHA"
    exit 8
fi
echo "Shared checkout advanced to $DEPLOYED_HEAD"

echo
echo "--- Restart and verify shared services ---"
if ! restart_shared_services; then
    echo "FAIL: shared services did not return healthy after deployment"
    exit 9
fi

FW_POST="$(curl -fsS http://192.168.5.9:8790/api/health)"
PR_POST="$(curl -fsS http://192.168.5.9:8792/api/health)"
echo "Post-deploy FieldWiring health: $FW_POST"
echo "Post-deploy Procedures health:  $PR_POST"

if [[ "$FW_POST" != *"\"version\":\"$EXPECTED_FIELDWIRING_VERSION\""* ]]; then
    echo "FAIL: FieldWiring version does not match $EXPECTED_FIELDWIRING_VERSION"
    exit 10
fi
if [[ "$PR_POST" != *"\"version\":\"$EXPECTED_PROCEDURES_VERSION\""* ]]; then
    echo "FAIL: Procedures version does not match $EXPECTED_PROCEDURES_VERSION"
    exit 11
fi

echo
echo "--- Live combined regression ---"
sudo -u fieldwiring -H bash -c \
    "cd '$FIELDWIRING_ROOT' && /opt/fieldwiring/.venv/bin/python -m pytest -q -p no:cacheprovider FieldWiring/Application Procedures/Application"
echo "LIVE COMBINED REGRESSION: PASS"

echo
echo "--- Live security/API negative proof ---"
ACCESS_CODE="$(curl -sS -o /tmp/controller-v040-access-$STAMP.json -w '%{http_code}' http://192.168.5.9:8790/api/controller-access)"
MANAGE_CODE="$(curl -sS -o /tmp/controller-v040-manage-$STAMP.json -w '%{http_code}' http://192.168.5.9:8790/api/controller-management/options)"
if [[ "$ACCESS_CODE" != "401" ]]; then
    echo "FAIL: /api/controller-access without Cloudflare identity returned HTTP $ACCESS_CODE"
    cat /tmp/controller-v040-access-$STAMP.json || true
    exit 12
fi
if [[ "$MANAGE_CODE" != "401" ]]; then
    echo "FAIL: /api/controller-management/options without Cloudflare identity returned HTTP $MANAGE_CODE"
    cat /tmp/controller-v040-manage-$STAMP.json || true
    exit 13
fi
rm -f /tmp/controller-v040-access-$STAMP.json /tmp/controller-v040-manage-$STAMP.json

echo "PASS: management APIs reject requests without protected Cloudflare identity"

FINAL_HEAD="$(sudo git -C "$FIELDWIRING_ROOT" rev-parse HEAD)"
FINAL_FP="$(prod_fingerprint)"
if [[ "$FINAL_HEAD" != "$TARGET_SHA" ]]; then
    echo "FAIL: final production checkout $FINAL_HEAD does not match target $TARGET_SHA"
    exit 14
fi
if [[ "$FINAL_FP" != "$PROD_BEFORE" ]]; then
    echo "FAIL: final Controller fingerprint differs from pre-deploy fingerprint"
    exit 15
fi

echo "PASS: final Controller fingerprint unchanged"
SUCCESS=1

echo
echo "========== CONTROLLER SETUP + MANAGEMENT PRODUCTION DEPLOYMENT: PASS =========="
echo "Old checkout: $OLD_HEAD"
echo "New checkout: $FINAL_HEAD"
echo "FieldWiring:  $FW_POST"
echo "Procedures:   $PR_POST"
echo "Backup:       $BACKUP_FILE"
echo "Backup SHA:   $BACKUP_SHA"
echo "Report:       $REPORT"
