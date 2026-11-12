#!/usr/bin/env bash
set -euo pipefail

PROD_CONTAINER="msb-postgres"
PROD_DB="msb"
DB_ACTOR="msbadmin"
FIELDWIRING_ROOT="/opt/fieldwiring"
FIELDWIRING_SERVICE="fieldwiring.service"
PROCEDURES_SERVICE="msb-procedures.service"
EXPECTED_CURRENT_SHA="84d6f06e16c43ebb0f6aa21273b999af7f6d455b"
TARGET_SHA="e9ab029a17067b38b34f9306069f54899925f73f"
TARGET_REF="agent/controller-inventory-ref-sandbox"
EXPECTED_FIELDWIRING_VERSION="V0.3.3"
EXPECTED_PROCEDURES_VERSION="V0.1.0"
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
BACKUP_DIR="/home/msbadmin/backups/postgres"
STAMP="$(date +%Y%m%dT%H%M%S)"
BACKUP_FILE="$BACKUP_DIR/msb-pre-controller-browser-$STAMP.dump"
REPORT="/tmp/MSB_Controller_Label_Production_Deploy_$STAMP.txt"
CANDIDATE_WORKTREE="/tmp/msb-controller-prod-candidate-$STAMP"
PROD_BEFORE=""
OLD_HEAD=""
DB_CHANGE_STARTED=0
APP_ADVANCED=0
SUCCESS=0

exec > >(tee "$REPORT") 2>&1

echo "========== CONTROLLER LABEL PRODUCTION DEPLOYMENT =========="
echo "Report:             $REPORT"
echo "Expected live HEAD: $EXPECTED_CURRENT_SHA"
echo "Target HEAD:        $TARGET_SHA"
echo "Rollback backup:    $BACKUP_FILE"
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

rollback_database_functions() {
    echo "Rolling back Controller browser database functions..."
    psql_prod <<'SQL'
BEGIN;
DROP FUNCTION IF EXISTS ref.request_controller_label(text, bigint);
DROP FUNCTION IF EXISTS ref.controller_browser_capabilities(text);
COMMIT;
SQL
}

restart_shared_services() {
    sudo systemctl restart "$FIELDWIRING_SERVICE" "$PROCEDURES_SERVICE"
    for _ in $(seq 1 30); do
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

cleanup() {
    status=$?
    trap - EXIT INT TERM
    set +e

    if [[ "$status" -ne 0 && "$SUCCESS" -ne 1 ]]; then
        echo
        echo "--- FAIL-CLOSED ROLLBACK ---"
        if [[ "$APP_ADVANCED" -eq 1 && -n "$OLD_HEAD" ]]; then
            echo "Resetting shared checkout to $OLD_HEAD"
            sudo git -C "$FIELDWIRING_ROOT" reset --hard "$OLD_HEAD"
            restart_shared_services || true
        fi
        if [[ "$DB_CHANGE_STARTED" -eq 1 ]]; then
            rollback_database_functions || true
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
            echo "FAIL: production Controller table fingerprint changed during deployment"
            status=97
        else
            echo "PASS: production Controller table fingerprint unchanged"
        fi
    fi

    echo "Rollback backup retained at: $BACKUP_FILE"
    echo "Deployment report retained at: $REPORT"
    echo "Exit status: $status"
    exit "$status"
}
trap cleanup EXIT INT TERM

sudo -v
mkdir -p "$BACKUP_DIR"

for required_file in \
    "$SCRIPT_DIR/021_create_controller_browser_authorization_contract.sql" \
    "$SCRIPT_DIR/022_create_controller_label_request_command.sql"; do
    if [[ ! -s "$required_file" ]]; then
        echo "FAIL: deployment bundle missing $required_file"
        exit 2
    fi
done

if ! sudo docker inspect "$PROD_CONTAINER" >/dev/null 2>&1; then
    echo "FAIL: production PostgreSQL container $PROD_CONTAINER not found"
    exit 3
fi

OLD_HEAD="$(sudo git -C "$FIELDWIRING_ROOT" rev-parse HEAD)"
if [[ "$OLD_HEAD" != "$EXPECTED_CURRENT_SHA" ]]; then
    echo "FAIL: live checkout is $OLD_HEAD, expected $EXPECTED_CURRENT_SHA"
    exit 4
fi

if [[ -n "$(sudo git -C "$FIELDWIRING_ROOT" status --porcelain)" ]]; then
    echo "FAIL: live shared checkout has uncommitted changes"
    sudo git -C "$FIELDWIRING_ROOT" status -sb
    exit 5
fi

if ! systemctl is-active --quiet "$FIELDWIRING_SERVICE" \
   || ! systemctl is-active --quiet "$PROCEDURES_SERVICE"; then
    echo "FAIL: shared production services are not active before deployment"
    exit 6
fi

FW_PRE="$(curl -fsS http://192.168.5.9:8790/api/health)"
PR_PRE="$(curl -fsS http://192.168.5.9:8792/api/health)"
echo "Pre-deploy FieldWiring health: $FW_PRE"
echo "Pre-deploy Procedures health:  $PR_PRE"

PROD_BEFORE="$(prod_fingerprint)"
echo "Pre-deploy Controller fingerprint: $PROD_BEFORE"

echo
echo "--- Fetch and verify exact application target ---"
sudo git -C "$FIELDWIRING_ROOT" fetch origin "$TARGET_REF"
sudo git -C "$FIELDWIRING_ROOT" cat-file -e "$TARGET_SHA^{commit}"
if ! sudo git -C "$FIELDWIRING_ROOT" merge-base --is-ancestor "$OLD_HEAD" "$TARGET_SHA"; then
    echo "FAIL: target is not a fast-forward descendant of live checkout"
    exit 7
fi

echo "Verified fast-forward ancestry: $OLD_HEAD -> $TARGET_SHA"

echo
echo "--- Detached production-environment candidate regression ---"
sudo git -C "$FIELDWIRING_ROOT" worktree add --detach "$CANDIDATE_WORKTREE" "$TARGET_SHA"
sudo -u fieldwiring -H bash -c \
    "cd '$CANDIDATE_WORKTREE' && /opt/fieldwiring/.venv/bin/python -m pytest -q -p no:cacheprovider FieldWiring/Application Procedures/Application"
echo "DETACHED CANDIDATE REGRESSION: PASS"

echo
echo "--- Create and verify rollback database backup ---"
sudo docker exec "$PROD_CONTAINER" \
    pg_dump -U "$DB_ACTOR" -d "$PROD_DB" -Fc > "$BACKUP_FILE"
test -s "$BACKUP_FILE"
BACKUP_SHA="$(sha256sum "$BACKUP_FILE" | awk '{print $1}')"
cat "$BACKUP_FILE" | sudo docker exec -i "$PROD_CONTAINER" pg_restore --list >/dev/null
echo "Rollback archive: $BACKUP_FILE"
echo "SHA256:           $BACKUP_SHA"
echo "ROLLBACK ARCHIVE VALIDATION: PASS"

echo
echo "--- Production database preflight ---"
psql_prod <<'SQL'
DO $block$
BEGIN
    IF to_regprocedure('ref.controller_browser_capabilities(text)') IS NOT NULL THEN
        RAISE EXCEPTION 'ref.controller_browser_capabilities(text) already exists';
    END IF;
    IF to_regprocedure('ref.request_controller_label(text,bigint)') IS NOT NULL THEN
        RAISE EXCEPTION 'ref.request_controller_label(text,bigint) already exists';
    END IF;
    IF has_table_privilege('fieldwiring_app', 'ref.controller', 'UPDATE') THEN
        RAISE EXCEPTION 'fieldwiring_app unexpectedly has direct ref.controller UPDATE';
    END IF;
END
$block$;
SQL

echo "DATABASE PREFLIGHT: PASS"

echo
echo "--- Apply migrations 021 / 022 to production ---"
DB_CHANGE_STARTED=1
cat "$SCRIPT_DIR/021_create_controller_browser_authorization_contract.sql" | psql_prod
cat "$SCRIPT_DIR/022_create_controller_label_request_command.sql" | psql_prod

echo
echo "--- Validate production authorization/write boundary ---"
psql_prod <<'SQL'
DO $block$
DECLARE
    v_email text;
    v_print boolean;
    v_manage boolean;
BEGIN
    IF NOT has_function_privilege(
        'fieldwiring_app',
        'ref.controller_browser_capabilities(text)',
        'EXECUTE'
    ) THEN
        RAISE EXCEPTION 'fieldwiring_app lacks capability-function EXECUTE';
    END IF;
    IF NOT has_function_privilege(
        'fieldwiring_app',
        'ref.request_controller_label(text,bigint)',
        'EXECUTE'
    ) THEN
        RAISE EXCEPTION 'fieldwiring_app lacks label-command EXECUTE';
    END IF;
    IF has_table_privilege('fieldwiring_app', 'ref.controller', 'UPDATE') THEN
        RAISE EXCEPTION 'fieldwiring_app unexpectedly gained direct Controller UPDATE';
    END IF;

    SELECT u.email INTO v_email
    FROM public.directus_users u
    JOIN public.directus_roles r ON r.id = u.role
    JOIN ref.person p ON p.directus_user_id = u.id
    WHERE u.status = 'active'
      AND r.name = 'Administrator'
    ORDER BY u.email
    LIMIT 1;

    IF v_email IS NULL THEN
        RAISE EXCEPTION 'No active Administrator mapped to ref.person for production validation';
    END IF;

    SELECT c.can_print_label, c.can_manage_controllers
      INTO v_print, v_manage
    FROM ref.controller_browser_capabilities(v_email) c;

    IF v_print IS DISTINCT FROM true OR v_manage IS DISTINCT FROM true THEN
        RAISE EXCEPTION 'Administrator capability validation failed for %', v_email;
    END IF;
END
$block$;
SQL

echo "PRODUCTION DATABASE AUTHORIZATION VALIDATION: PASS"

DB_AFTER_MIGRATIONS="$(prod_fingerprint)"
if [[ "$DB_AFTER_MIGRATIONS" != "$PROD_BEFORE" ]]; then
    echo "FAIL: Controller table data changed while installing functions"
    exit 8
fi

echo "PASS: migrations added controlled functions without changing Controller table data"

echo
echo "--- Fast-forward shared production checkout ---"
sudo git -C "$FIELDWIRING_ROOT" merge --ff-only "$TARGET_SHA"
APP_ADVANCED=1
DEPLOYED_HEAD="$(sudo git -C "$FIELDWIRING_ROOT" rev-parse HEAD)"
if [[ "$DEPLOYED_HEAD" != "$TARGET_SHA" ]]; then
    echo "FAIL: deployed checkout is $DEPLOYED_HEAD, expected $TARGET_SHA"
    exit 9
fi

echo "Shared checkout advanced to $DEPLOYED_HEAD"

echo
echo "--- Restart shared services and verify health ---"
if ! restart_shared_services; then
    echo "FAIL: shared services did not become healthy after restart"
    sudo systemctl status "$FIELDWIRING_SERVICE" "$PROCEDURES_SERVICE" --no-pager -l || true
    exit 10
fi

FW_HEALTH="$(curl -fsS http://192.168.5.9:8790/api/health)"
PR_HEALTH="$(curl -fsS http://192.168.5.9:8792/api/health)"
echo "FieldWiring health: $FW_HEALTH"
echo "Procedures health:  $PR_HEALTH"

if [[ "$FW_HEALTH" != *"\"version\":\"$EXPECTED_FIELDWIRING_VERSION\""* \
   || "$FW_HEALTH" != *"\"data_mode\":\"postgres\""* \
   || "$FW_HEALTH" != *"\"status\":\"ok\""* ]]; then
    echo "FAIL: unexpected FieldWiring health payload"
    exit 11
fi
if [[ "$PR_HEALTH" != *"\"version\":\"$EXPECTED_PROCEDURES_VERSION\""* \
   || "$PR_HEALTH" != *"\"data_mode\":\"postgres\""* \
   || "$PR_HEALTH" != *"\"status\":\"ok\""* ]]; then
    echo "FAIL: unexpected Procedures health payload"
    exit 12
fi

echo
echo "--- Live shared-checkout regression ---"
sudo -u fieldwiring -H bash -c \
    "cd '$FIELDWIRING_ROOT' && /opt/fieldwiring/.venv/bin/python -m pytest -q -p no:cacheprovider FieldWiring/Application Procedures/Application"
echo "LIVE SHARED REGRESSION: PASS"

echo
echo "--- Live Controller access endpoint boundary ---"
ACCESS_CODE="$(curl -sS -o /tmp/controller-access-noidentity-$STAMP.json -w '%{http_code}' http://192.168.5.9:8790/api/controller-access)"
cat /tmp/controller-access-noidentity-$STAMP.json
rm -f /tmp/controller-access-noidentity-$STAMP.json
if [[ "$ACCESS_CODE" != "401" ]]; then
    echo "FAIL: Controller access endpoint without Cloudflare identity returned HTTP $ACCESS_CODE, expected 401"
    exit 13
fi
echo "PASS: Controller access endpoint rejects missing Cloudflare identity"

FINAL_HEAD="$(sudo git -C "$FIELDWIRING_ROOT" rev-parse HEAD)"
FINAL_FP="$(prod_fingerprint)"
if [[ "$FINAL_HEAD" != "$TARGET_SHA" || "$FINAL_FP" != "$PROD_BEFORE" ]]; then
    echo "FAIL: final checkout/fingerprint validation failed"
    exit 14
fi

SUCCESS=1
echo
echo "CONTROLLER LABEL PRODUCTION DEPLOYMENT: PASS"
echo "Deployed checkout: $FINAL_HEAD"
echo "Rollback checkout: $OLD_HEAD"
echo "Rollback DB dump:  $BACKUP_FILE"
echo "Rollback SHA256:   $BACKUP_SHA"
echo "FieldWiring:       $FW_HEALTH"
echo "Procedures:        $PR_HEALTH"
echo "Production Controller fingerprint: $FINAL_FP"
