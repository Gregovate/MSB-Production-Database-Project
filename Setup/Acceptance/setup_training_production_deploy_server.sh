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
TARGET_REF="agent/setup-session-production-foundation"
TARGET_SHA="aaf7de1c1d457b3dfaafe061f084a044cdf2abb7"
EXPECTED_SETUP_VERSION="V0.3.4-shared-season-guard-review"
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
BACKUP_DIR="/home/msbadmin/backups/setup-training"
STAMP="$(date +%Y%m%dT%H%M%S)"
BACKUP_FILE="$BACKUP_DIR/msb-pre-setup-training-$STAMP.dump"
REPORT="/tmp/MSB_Setup_Training_Production_Deploy_$STAMP.txt"
CANDIDATE_WORKTREE="/tmp/msb-setup-training-production-candidate-$STAMP"
NEGATIVE_BODY="/tmp/msb-setup-training-negative-$STAMP.txt"
M019=""
M020=""
M021=""
M022=""
PROD_BEFORE=""
OLD_HEAD=""
DB_CHANGE_STARTED=0
APP_ADVANCED=0
SUCCESS=0
BACKUP_CREATED=0

exec > >(tee "$REPORT") 2>&1

echo "========== SETUP TRAINING / RECONSTRUCTION PRODUCTION DEPLOYMENT =========="
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

rollback_setup_training_database() {
    echo "Restoring pre-019-022 Setup database command/constraint boundary..."
    psql_prod <<'SQL'
BEGIN;

DROP FUNCTION IF EXISTS ref.delete_setup_reconstruction_task(text,bigint);
DROP FUNCTION IF EXISTS ref.setup_task_captain_list(bigint);
DROP FUNCTION IF EXISTS ref.setup_captain_person_list();
DROP FUNCTION IF EXISTS ref.set_setup_task_captain(text,bigint,integer,text,integer,text,boolean);

ALTER TABLE ops.setup_session_task
    DROP CONSTRAINT IF EXISTS ck_setup_session_task_verification;
ALTER TABLE ops.setup_session_task
    ADD CONSTRAINT ck_setup_session_task_verification CHECK (
        verification_state IN ('UNVERIFIED', 'VERIFIED', 'NEEDS_CORRECTION')
    );

CREATE OR REPLACE FUNCTION ops.update_setup_session_task_review(
    p_email text,
    p_setup_session_task_id bigint,
    p_verification_state text,
    p_actual_started_at timestamptz,
    p_actual_completed_at timestamptz,
    p_actual_crew_count integer,
    p_actual_duration_minutes integer,
    p_annual_notes text
)
RETURNS TABLE (
    setup_session_task_id bigint,
    operator_display_name text
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, ops, ref
AS $function$
DECLARE
    v_directus_user_id uuid;
    v_person_id integer;
    v_display_name text;
    v_verification text := upper(btrim(coalesce(p_verification_state, 'UNVERIFIED')));
BEGIN
    SELECT a.directus_user_id, a.person_id, a.display_name
      INTO v_directus_user_id, v_person_id, v_display_name
    FROM ref.setup_management_actor(p_email, false) AS a;

    IF v_verification NOT IN ('UNVERIFIED', 'VERIFIED', 'NEEDS_CORRECTION') THEN
        RAISE EXCEPTION USING ERRCODE = '22023', MESSAGE = 'Invalid Setup verification state';
    END IF;

    PERFORM pg_catalog.set_config(
        'app.directus_user_uuid',
        v_directus_user_id::text,
        true
    );

    UPDATE ops.setup_session_task st
       SET verification_state = v_verification,
           actual_started_at = p_actual_started_at,
           actual_completed_at = p_actual_completed_at,
           actual_crew_count = p_actual_crew_count,
           actual_duration_minutes = p_actual_duration_minutes,
           annual_notes = nullif(btrim(p_annual_notes), '')
     WHERE st.setup_session_task_id = p_setup_session_task_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION USING ERRCODE = 'P0002', MESSAGE = 'Setup annual task was not found';
    END IF;

    RETURN QUERY SELECT p_setup_session_task_id, v_display_name;
END;
$function$;

REVOKE ALL ON FUNCTION ops.update_setup_session_task_review(
    text, bigint, text, timestamptz, timestamptz, integer, integer, text
) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION ops.update_setup_session_task_review(
    text, bigint, text, timestamptz, timestamptz, integer, integer, text
) TO fieldwiring_app;

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
            rollback_setup_training_database || true
        fi
    fi

    if sudo git -C "$REPO_ROOT" worktree list --porcelain 2>/dev/null | grep -Fq "worktree $CANDIDATE_WORKTREE"; then
        sudo git -C "$REPO_ROOT" worktree remove --force "$CANDIDATE_WORKTREE" >/dev/null 2>&1 || true
    fi
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
mkdir -p "$BACKUP_DIR"

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
M019="$CANDIDATE_WORKTREE/Setup/Database/019_add_reconstruction_safe_task_delete.sql"
M020="$CANDIDATE_WORKTREE/Setup/Database/020_add_setup_captain_management_commands.sql"
M021="$CANDIDATE_WORKTREE/Setup/Database/021_add_setup_assigned_reconciliation_state.sql"
M022="$CANDIDATE_WORKTREE/Setup/Database/022_require_active_setup_captain_people.sql"
for required_file in "$M019" "$M020" "$M021" "$M022"; do
    if [[ ! -s "$required_file" ]]; then
        echo "FAIL: accepted target is missing reviewed migration $required_file"
        exit 9
    fi
done

[[ "$(sudo git -C "$REPO_ROOT" rev-parse "$TARGET_SHA:Setup/Database/019_add_reconstruction_safe_task_delete.sql")" == "886b910833f895179ad218c0cd1ba217de0f7bf9" ]]
[[ "$(sudo git -C "$REPO_ROOT" rev-parse "$TARGET_SHA:Setup/Database/020_add_setup_captain_management_commands.sql")" == "deb83713295d23bb9b153cf905c9f9b16f1f48bd" ]]
[[ "$(sudo git -C "$REPO_ROOT" rev-parse "$TARGET_SHA:Setup/Database/021_add_setup_assigned_reconciliation_state.sql")" == "44680394f71074446918cae4aa7ee1aeddd1599b" ]]
[[ "$(sudo git -C "$REPO_ROOT" rev-parse "$TARGET_SHA:Setup/Database/022_require_active_setup_captain_people.sql")" == "130fc1ebc289e7e26a152c88bbfb24e47e80eebc" ]]
echo "Reviewed migration blob identities: PASS"
sha256sum "$M019" "$M020" "$M021" "$M022"

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
DO $block$
DECLARE
    v_constraint text;
    v_role_config text;
BEGIN
    IF to_regprocedure('ref.setup_management_actor(text,boolean)') IS NULL
       OR to_regprocedure('ops.update_setup_session_task_review(text,bigint,text,timestamptz,timestamptz,integer,integer,text)') IS NULL
       OR to_regclass('ref.setup_task_captain') IS NULL
       OR to_regclass('ref.person') IS NULL THEN
        RAISE EXCEPTION 'Required accepted Setup V0.3.4 baseline is incomplete';
    END IF;

    IF to_regprocedure('ref.delete_setup_reconstruction_task(text,bigint)') IS NOT NULL
       OR to_regprocedure('ref.setup_task_captain_list(bigint)') IS NOT NULL
       OR to_regprocedure('ref.setup_captain_person_list()') IS NOT NULL
       OR to_regprocedure('ref.set_setup_task_captain(text,bigint,integer,text,integer,text,boolean)') IS NOT NULL THEN
        RAISE EXCEPTION 'One or more 019/020/022 functions already exist; stop for partial-deployment review';
    END IF;

    SELECT pg_get_constraintdef(c.oid)
      INTO v_constraint
    FROM pg_constraint c
    WHERE c.conrelid = 'ops.setup_session_task'::regclass
      AND c.conname = 'ck_setup_session_task_verification';
    IF v_constraint IS NULL THEN
        RAISE EXCEPTION 'Setup verification constraint is missing before deployment';
    END IF;
    IF position('ASSIGNED' IN v_constraint) > 0 THEN
        RAISE EXCEPTION 'ASSIGNED is already present in the Setup verification constraint; stop for partial-deployment review';
    END IF;

    IF has_table_privilege('fieldwiring_app', 'ref.setup_task', 'DELETE')
       OR has_table_privilege('fieldwiring_app', 'ref.setup_task_captain', 'INSERT')
       OR has_table_privilege('fieldwiring_app', 'ref.setup_task_captain', 'UPDATE')
       OR has_table_privilege('fieldwiring_app', 'ref.setup_task_captain', 'DELETE')
       OR has_table_privilege('fieldwiring_app', 'ops.setup_session_task', 'UPDATE') THEN
        RAISE EXCEPTION 'fieldwiring_app unexpectedly has broad Setup DML before deployment';
    END IF;

    SELECT coalesce(array_to_string(r.rolconfig, ','), '')
      INTO v_role_config
    FROM pg_roles r
    WHERE r.rolname = 'fieldwiring_app';
    IF position('default_transaction_read_only=on' IN v_role_config) = 0 THEN
        RAISE EXCEPTION 'fieldwiring_app default_transaction_read_only=on runtime guard is missing';
    END IF;
END
$block$;
SQL
echo "DATABASE PREFLIGHT: PASS"

echo
echo "--- Apply accepted Setup migrations 019 / 020 / 021 / 022 ---"
DB_CHANGE_STARTED=1
sudo docker exec -i "$PROD_CONTAINER" \
    psql -X -v ON_ERROR_STOP=1 -U "$DB_ACTOR" -d "$PROD_DB" < "$M019"
sudo docker exec -i "$PROD_CONTAINER" \
    psql -X -v ON_ERROR_STOP=1 -U "$DB_ACTOR" -d "$PROD_DB" < "$M020"
sudo docker exec -i "$PROD_CONTAINER" \
    psql -X -v ON_ERROR_STOP=1 -U "$DB_ACTOR" -d "$PROD_DB" < "$M021"
sudo docker exec -i "$PROD_CONTAINER" \
    psql -X -v ON_ERROR_STOP=1 -U "$DB_ACTOR" -d "$PROD_DB" < "$M022"

echo
echo "--- Validate Production Setup command/security boundary ---"
psql_prod <<'SQL'
DO $block$
DECLARE
    v_constraint text;
    v_inactive_count integer;
BEGIN
    IF NOT has_function_privilege('fieldwiring_app', 'ref.delete_setup_reconstruction_task(text,bigint)', 'EXECUTE')
       OR NOT has_function_privilege('fieldwiring_app', 'ref.setup_task_captain_list(bigint)', 'EXECUTE')
       OR NOT has_function_privilege('fieldwiring_app', 'ref.setup_captain_person_list()', 'EXECUTE')
       OR NOT has_function_privilege('fieldwiring_app', 'ref.set_setup_task_captain(text,bigint,integer,text,integer,text,boolean)', 'EXECUTE')
       OR NOT has_function_privilege('fieldwiring_app', 'ops.update_setup_session_task_review(text,bigint,text,timestamptz,timestamptz,integer,integer,text)', 'EXECUTE') THEN
        RAISE EXCEPTION 'fieldwiring_app lacks one or more required Setup command/projection privileges';
    END IF;

    IF has_function_privilege('fieldwiring_app', 'ref.setup_management_actor(text,boolean)', 'EXECUTE') THEN
        RAISE EXCEPTION 'fieldwiring_app must not directly execute setup_management_actor';
    END IF;

    IF has_table_privilege('fieldwiring_app', 'ref.setup_task', 'DELETE')
       OR has_table_privilege('fieldwiring_app', 'ref.setup_task_captain', 'INSERT')
       OR has_table_privilege('fieldwiring_app', 'ref.setup_task_captain', 'UPDATE')
       OR has_table_privilege('fieldwiring_app', 'ref.setup_task_captain', 'DELETE')
       OR has_table_privilege('fieldwiring_app', 'ops.setup_session_task', 'UPDATE') THEN
        RAISE EXCEPTION 'fieldwiring_app unexpectedly gained broad Setup DML';
    END IF;

    SELECT pg_get_constraintdef(c.oid)
      INTO v_constraint
    FROM pg_constraint c
    WHERE c.conrelid = 'ops.setup_session_task'::regclass
      AND c.conname = 'ck_setup_session_task_verification';
    IF v_constraint IS NULL OR position('ASSIGNED' IN v_constraint) = 0 THEN
        RAISE EXCEPTION 'ASSIGNED reconciliation state is not present in Production constraint';
    END IF;

    SELECT count(*)
      INTO v_inactive_count
    FROM ref.setup_captain_person_list() cp
    JOIN ref.person p ON p.person_id = cp.person_id
    WHERE NOT p.active_flag;
    IF v_inactive_count <> 0 THEN
        RAISE EXCEPTION 'Inactive people are exposed by the Production Captain candidate projection';
    END IF;
END
$block$;
SQL
echo "PRODUCTION SETUP COMMAND/SECURITY BOUNDARY: PASS"

DB_AFTER_MIGRATIONS="$(prod_fingerprint)"
if [[ -z "$DB_AFTER_MIGRATIONS" || "$DB_AFTER_MIGRATIONS" != "$PROD_BEFORE" ]]; then
    echo "FAIL: governed Setup data changed while installing migrations 019-022"
    exit 10
fi
echo "PASS: migrations 019-022 installed without changing governed Setup data"

echo
echo "--- Fast-forward dedicated Setup Production checkout ---"
sudo git -C "$SETUP_ROOT" merge --ff-only "$TARGET_SHA"
APP_ADVANCED=1
DEPLOYED_HEAD="$(sudo git -C "$SETUP_ROOT" rev-parse HEAD)"
if [[ "$DEPLOYED_HEAD" != "$TARGET_SHA" ]]; then
    echo "FAIL: deployed Setup checkout is $DEPLOYED_HEAD, expected $TARGET_SHA"
    exit 11
fi
if [[ -n "$(sudo git -C "$SETUP_ROOT" status --porcelain)" ]]; then
    echo "FAIL: deployed Setup checkout is not clean"
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
    echo "FAIL: Setup health payload does not match accepted Production runtime contract"
    exit 13
fi

sudo -u fieldwiring -H bash -c \
    "cd '$SETUP_ROOT' && /opt/fieldwiring/.venv/bin/python -m pytest -q -p no:cacheprovider Setup/Application"
echo "LIVE SETUP APPLICATION REGRESSION: PASS"

NEGATIVE_STATUS="$(curl -sS -o "$NEGATIVE_BODY" -w '%{http_code}' http://192.168.5.9:8794/api/setup/access || true)"
if [[ "$NEGATIVE_STATUS" != "401" ]]; then
    echo "FAIL: direct protected Setup access without Cloudflare identity returned HTTP $NEGATIVE_STATUS, expected 401"
    cat "$NEGATIVE_BODY" || true
    exit 14
fi
echo "Protected Setup negative-path HTTP 401: PASS"

PUBLIC_HEALTH="$(curl -sk --fail --resolve my.sheboyganlights.org:443:192.168.5.4 https://my.sheboyganlights.org/setup/api/health)"
echo "Synology /setup/ health: $PUBLIC_HEALTH"

for service in "$DISPLAY_SERVICE" "$GOOGLE_SERVICE" "$FIELDWIRING_SERVICE" "$PROCEDURES_SERVICE"; do
    if ! systemctl is-active --quiet "$service"; then
        echo "FAIL: adjacent required Production service is not active after Setup deployment: $service"
        exit 15
    fi
done

echo
echo "--- Final Production invariants ---"
FINAL_HEAD="$(sudo git -C "$SETUP_ROOT" rev-parse HEAD)"
FINAL_FP="$(prod_fingerprint)"
echo "Final Setup checkout:    $FINAL_HEAD"
echo "Final Setup fingerprint: $FINAL_FP"
if [[ "$FINAL_HEAD" != "$TARGET_SHA" ]]; then
    echo "FAIL: final Setup checkout no longer equals accepted target"
    exit 16
fi
if [[ "$FINAL_FP" != "$PROD_BEFORE" ]]; then
    echo "FAIL: final governed Setup fingerprint differs from pre-deploy fingerprint"
    exit 17
fi

psql_prod -qAt -c "
SELECT '2025_historical_sessions=' || count(*)
FROM ops.setup_session
WHERE season_year = 2025 AND session_status = 'HISTORICAL_VERIFICATION';
SELECT '2026_sessions=' || count(*)
FROM ops.setup_session
WHERE season_year = 2026;
SELECT 'setup_tasks=' || count(*) FROM ref.setup_task;
SELECT 'annual_tasks=' || count(*) FROM ops.setup_session_task;
SELECT 'work_days=' || count(*) FROM ops.setup_work_day;
SELECT 'movement_events=' || count(*) FROM ops.setup_movement_event;
"

SUCCESS=1
echo
echo "SETUP_TRAINING_PRODUCTION_DEPLOYMENT_PASS"
