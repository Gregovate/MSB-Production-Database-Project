#!/usr/bin/env bash
set -euo pipefail

PROD_CONTAINER="msb-postgres"
PROD_DB="msb"
DB_ACTOR="msbadmin"
REPO_ROOT="/opt/fieldwiring"
SETUP_ROOT="/opt/msb-setup"
PYTHON="/opt/fieldwiring/.venv/bin/python"
SETUP_SERVICE="msb-setup.service"
FIELDWIRING_SERVICE="fieldwiring.service"
PROCEDURES_SERVICE="msb-procedures.service"

TARGET_REF="main"
TARGET_SHA="f71f578222b2ab5416fabb298e4d4767a2c8d4b5"
EXPECTED_SETUP_VERSION="V0.3.17-performance-trace"

AUDIT_REL="Database/Basic_Query_Tools_Dev/Repair-SetActorOnUpdate-Attribution.sql"
AUDIT_BLOB="5d1b6b60bf6e6bac4d8817f326dba05e3a8546b7"
READINESS_REL="Setup/Database/056_enforce_setup_readiness_note_not_ready.sql"
READINESS_BLOB="5fba08d1f8d2450476d14f7525cea4321bc17716"

DB_AUDIT_VALIDATION_REL="Database/Acceptance/database_shared_audit_actor_disposable_validation.sql"
DB_AUDIT_VALIDATION_BLOB="06c9b1311c682d5ccc24c8bfba639bcccca720a4"
SETUP_AUDIT_VALIDATION_REL="Setup/Acceptance/setup_122_shared_audit_actor_disposable_validation.sql"
SETUP_AUDIT_VALIDATION_BLOB="d91ce27cd2f3d6242c7b0cefba70689e938934a4"
READINESS_VALIDATION_REL="Setup/Acceptance/setup_122_readiness_not_ready_disposable_validation.sql"
READINESS_VALIDATION_BLOB="6ff2bba86c5301f72fc200a7b9c995e53e387f7a"

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
BACKUP_DIR="/home/msbadmin/backups/setup-122-b1a-audit"
REPORT_DIR="/home/msbadmin/setup-deployment-reports"
STAMP="$(date +%Y%m%dT%H%M%S)"
BACKUP_FILE="$BACKUP_DIR/msb-pre-setup-122-b1a-audit-$STAMP.dump"
REPORT="$REPORT_DIR/Setup_122_B1a_Audit_Baseline_Production_Deploy_$STAMP.txt"
CANDIDATE_WORKTREE="/tmp/msb-setup-122-b1a-audit-candidate-$STAMP"
PYCACHE="/tmp/msb-setup-122-b1a-audit-pycache-$STAMP"
NEGATIVE_BODY="/tmp/msb-setup-122-b1a-negative-$STAMP.json"

OLD_HEAD=""
SETUP_BEFORE=""
AUDIT_BEFORE=""
AUDIT_AFTER=""
AUDIT_COMMITTED=0
READINESS_COMMITTED=0
APP_ADVANCED=0
BACKUP_CREATED=0
SUCCESS=0

mkdir -p "$REPORT_DIR"
exec > >(tee "$REPORT") 2>&1

echo "========== SETUP #122 B1A / AUDIT BASELINE PRODUCTION DEPLOYMENT =========="
echo "Authority: Gregovate/MSB-Server-Management — docs/server/Production_Database_Change_Deployment_Runbook.md"
echo "Boundary: accepted 2025 Historical Verification / Task Finder baseline + shared audit repair + readiness invariant"
echo "Scheduling completion: NO"
echo "2026 Setup Session creation: FORBIDDEN"
echo "Target SHA:   $TARGET_SHA"
echo "Target ref:   $TARGET_REF"
echo "Expected ver: $EXPECTED_SETUP_VERSION"
echo "Migration 1:  $AUDIT_REL"
echo "Migration 2:  $READINESS_REL"
echo "Report:       $REPORT"
echo

psql_prod() {
    sudo docker exec -i "$PROD_CONTAINER"         psql -X -v ON_ERROR_STOP=1 -U "$DB_ACTOR" -d "$PROD_DB" "$@"
}

setup_business_fingerprint() {
    sudo docker exec "$PROD_CONTAINER"         psql -X -qAt -v ON_ERROR_STOP=1 -U "$DB_ACTOR" -d "$PROD_DB" -c "
            SELECT md5(
                coalesce((SELECT string_agg(row_to_json(t)::text, '' ORDER BY t.setup_task_id)
                          FROM ref.setup_task t), '') || '|' ||
                coalesce((SELECT string_agg(row_to_json(d)::text, '' ORDER BY d.setup_task_id, d.prerequisite_setup_task_id)
                          FROM ref.setup_task_dependency d), '') || '|' ||
                coalesce((SELECT string_agg(row_to_json(r)::text, '' ORDER BY r.setup_resource_id)
                          FROM ref.setup_resource r), '') || '|' ||
                coalesce((SELECT string_agg(row_to_json(s)::text, '' ORDER BY s.setup_session_id)
                          FROM ops.setup_session s), '') || '|' ||
                coalesce((SELECT string_agg(row_to_json(st)::text, '' ORDER BY st.setup_session_task_id)
                          FROM ops.setup_session_task st), '') || '|' ||
                coalesce((SELECT string_agg(row_to_json(wd)::text, '' ORDER BY wd.setup_work_day_id)
                          FROM ops.setup_work_day wd), '')
            );
        "
}

audit_contract_fingerprint() {
    sudo docker exec "$PROD_CONTAINER"         psql -X -qAt -v ON_ERROR_STOP=1 -U "$DB_ACTOR" -d "$PROD_DB" -c "
            WITH function_state AS (
                SELECT string_agg(
                    p.proname || ':' || md5(pg_get_functiondef(p.oid)),
                    '|' ORDER BY p.proname
                ) AS value
                FROM pg_proc p
                JOIN pg_namespace n ON n.oid=p.pronamespace
                WHERE n.nspname='ref'
                  AND p.proname IN (
                      'resolve_actor',
                      'set_actor_on_insert',
                      'set_actor_on_update',
                      'set_updated_fields',
                      'sync_audit_collection_policy'
                  )
            ),
            policy_state AS (
                SELECT string_agg(row_to_json(a)::text, '|' ORDER BY a.audit_collection_policy_id) AS value
                FROM ref.audit_collection_policy a
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
                        coalesce(c.column_default,'')
                    ),
                    '|' ORDER BY c.table_schema,c.table_name,c.ordinal_position
                ) AS value
                FROM information_schema.columns c
                WHERE (c.table_schema,c.table_name) IN (
                    ('ops','work_order_status_history'),
                    ('ref','task_type'),
                    ('ref','work_area')
                )
            ),
            trigger_state AS (
                SELECT string_agg(
                    n.nspname || '.' || c.relname || ':' || t.tgname || ':' || pg_get_triggerdef(t.oid,true),
                    '|' ORDER BY n.nspname,c.relname,t.tgname
                ) AS value
                FROM pg_trigger t
                JOIN pg_proc p ON p.oid=t.tgfoid
                JOIN pg_class c ON c.oid=t.tgrelid
                JOIN pg_namespace n ON n.oid=c.relnamespace
                WHERE NOT t.tgisinternal
                  AND p.proname IN ('set_actor_on_insert','set_actor_on_update','set_updated_fields')
            )
            SELECT md5(
                coalesce((SELECT value FROM function_state),'') || '|' ||
                coalesce((SELECT value FROM policy_state),'') || '|' ||
                coalesce((SELECT value FROM target_column_state),'') || '|' ||
                coalesce((SELECT value FROM trigger_state),'')
            );
        "
}

setup_2026_count() {
    sudo docker exec "$PROD_CONTAINER"         psql -X -qAt -v ON_ERROR_STOP=1 -U "$DB_ACTOR" -d "$PROD_DB"         -c "SELECT count(*) FROM ops.setup_session WHERE season_year=2026;"
}

wait_setup_ready() {
    for _ in $(seq 1 60); do
        if systemctl is-active --quiet "$SETUP_SERVICE"            && curl -fsS http://192.168.5.9:8794/api/health >/dev/null 2>&1; then
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

cleanup() {
    status=$?
    trap - EXIT HUP INT TERM
    set +e

    if [[ "$status" -ne 0 && "$SUCCESS" -ne 1 ]]; then
        echo
        echo "--- FAIL-CLOSED RECOVERY ---"
        if [[ "$APP_ADVANCED" -eq 1 && -n "$OLD_HEAD" ]]; then
            echo "Restoring /opt/msb-setup to prior SHA $OLD_HEAD"
            sudo git -C "$SETUP_ROOT" reset --hard "$OLD_HEAD" || true
            restart_setup_service || true
            echo "Application source rollback attempted."
        fi

        if [[ "$AUDIT_COMMITTED" -eq 1 || "$READINESS_COMMITTED" -eq 1 ]]; then
            echo "Accepted database migration(s) reached committed state and are intentionally not auto-restored."
            echo "Reason: a full PostgreSQL archive restore could erase unrelated concurrent Production writes."
            echo "Use the retained rollback archive only through a separately governed recovery decision."
        else
            echo "No accepted database migration reached committed-success state."
        fi
    fi

    if sudo git -C "$REPO_ROOT" worktree list --porcelain 2>/dev/null | grep -Fq "worktree $CANDIDATE_WORKTREE"; then
        sudo git -C "$REPO_ROOT" worktree remove --force "$CANDIDATE_WORKTREE" >/dev/null 2>&1 || true
    fi
    sudo git -C "$REPO_ROOT" worktree prune >/dev/null 2>&1 || true
    sudo rm -rf "$PYCACHE" >/dev/null 2>&1 || true
    rm -f "$NEGATIVE_BODY" >/dev/null 2>&1 || true
    rm -rf "$SCRIPT_DIR" >/dev/null 2>&1 || true

    echo
    echo "--- Production after-check ---"
    if [[ -n "$SETUP_BEFORE" ]]; then
        SETUP_AFTER="$(setup_business_fingerprint 2>/dev/null || true)"
        echo "Setup business fingerprint before: $SETUP_BEFORE"
        echo "Setup business fingerprint after:  $SETUP_AFTER"
        if [[ -z "$SETUP_AFTER" || "$SETUP_AFTER" != "$SETUP_BEFORE" ]]; then
            echo "FAIL: governed Setup business rows changed during baseline deployment"
            status=97
        else
            echo "PASS: governed Setup business rows unchanged"
        fi
    fi

    FINAL_2026="$(setup_2026_count 2>/dev/null || true)"
    echo "Final 2026 Setup Session count: ${FINAL_2026:-unknown}"
    if [[ -n "$FINAL_2026" && "$FINAL_2026" != "0" ]]; then
        echo "FAIL: this baseline deployment must not create a 2026 Setup Session"
        status=96
    fi

    if [[ "$BACKUP_CREATED" -eq 1 && -s "$BACKUP_FILE" ]]; then
        echo "Rollback archive retained at: $BACKUP_FILE"
    else
        echo "Rollback archive: not created before this stop"
    fi

    echo "Deployment report retained at: $REPORT"
    echo "Exit status: $status"
    exit "$status"
}
trap cleanup EXIT HUP INT TERM

sudo -v
mkdir -p "$BACKUP_DIR" "$REPORT_DIR"

echo "--- Verify current Production state ---"
if ! sudo docker inspect "$PROD_CONTAINER" >/dev/null 2>&1; then
    echo "FAIL: Production PostgreSQL container not found"
    exit 2
fi
if [[ "$(sudo docker inspect "$PROD_CONTAINER" --format '{{.Config.Image}}')" != "postgis/postgis:16-3.5" ]]; then
    echo "FAIL: Production PostgreSQL image mismatch"
    exit 3
fi
if ! sudo git -C "$REPO_ROOT" worktree list --porcelain | grep -Fq "worktree $SETUP_ROOT"; then
    echo "FAIL: $SETUP_ROOT is not a registered worktree of $REPO_ROOT"
    exit 4
fi
if [[ -n "$(sudo git -C "$REPO_ROOT" status --porcelain)" ]]; then
    echo "FAIL: shared repository checkout has uncommitted changes"
    sudo git -C "$REPO_ROOT" status -sb
    exit 5
fi

OLD_HEAD="$(sudo git -C "$SETUP_ROOT" rev-parse HEAD)"
echo "Verified live Setup SHA: $OLD_HEAD"
if [[ -n "$(sudo git -C "$SETUP_ROOT" status --porcelain)" ]]; then
    echo "FAIL: live Setup worktree has uncommitted changes"
    sudo git -C "$SETUP_ROOT" status -sb
    exit 6
fi

for service in "$SETUP_SERVICE" "$FIELDWIRING_SERVICE" "$PROCEDURES_SERVICE"; do
    if ! systemctl is-active --quiet "$service"; then
        echo "FAIL: required Production service is not active: $service"
        exit 7
    fi
done

SETUP_PRE="$(curl -fsS http://192.168.5.9:8794/api/health)"
FW_PRE="$(curl -fsS http://192.168.5.9:8790/api/health)"
PR_PRE="$(curl -fsS http://192.168.5.9:8792/api/health)"
echo "Pre-deploy Setup health:       $SETUP_PRE"
echo "Pre-deploy FieldWiring health: $FW_PRE"
echo "Pre-deploy Procedures health:  $PR_PRE"
if [[ "$SETUP_PRE" != *"\"status\":\"ok\""*    || "$SETUP_PRE" != *"\"data_mode\":\"postgres\""*    || "$SETUP_PRE" != *"\"version\":\"$EXPECTED_SETUP_VERSION\""* ]]; then
    echo "FAIL: current Setup runtime is not the expected $EXPECTED_SETUP_VERSION state"
    exit 8
fi

if [[ "$(setup_2026_count)" != "0" ]]; then
    echo "FAIL: a real 2026 Setup Session already exists; stop and reconcile under #122"
    exit 9
fi

SETUP_BEFORE="$(setup_business_fingerprint)"
AUDIT_BEFORE="$(audit_contract_fingerprint)"
[[ -n "$SETUP_BEFORE" && -n "$AUDIT_BEFORE" ]] || { echo "FAIL: Production pre-deploy fingerprints are incomplete"; exit 10; }
echo "Setup business fingerprint before: $SETUP_BEFORE"
echo "Audit contract fingerprint before: $AUDIT_BEFORE"

echo
echo "--- Fetch exact browser-accepted target and prove merged ancestry ---"
sudo git -C "$REPO_ROOT" fetch origin "$TARGET_REF:refs/remotes/origin/$TARGET_REF"
sudo git -C "$REPO_ROOT" cat-file -e "$TARGET_SHA^{commit}"
if ! sudo git -C "$REPO_ROOT" merge-base --is-ancestor "$TARGET_SHA" "origin/$TARGET_REF"; then
    echo "FAIL: exact browser-accepted target is not contained in merged origin/$TARGET_REF"
    exit 11
fi
if ! sudo git -C "$REPO_ROOT" merge-base --is-ancestor "$OLD_HEAD" "$TARGET_SHA"; then
    echo "FAIL: browser-accepted target is not a forward descendant of live Setup"
    echo "Live:   $OLD_HEAD"
    echo "Target: $TARGET_SHA"
    exit 12
fi
echo "Forward ancestry: PASS ($OLD_HEAD -> $TARGET_SHA)"

check_blob() {
    rel="$1"
    expected="$2"
    actual="$(sudo git -C "$REPO_ROOT" rev-parse "$TARGET_SHA:$rel")"
    if [[ "$actual" != "$expected" ]]; then
        echo "FAIL: accepted blob mismatch for $rel"
        echo "Expected: $expected"
        echo "Actual:   $actual"
        exit 13
    fi
    echo "Accepted blob: $rel = $actual"
}

check_blob "$AUDIT_REL" "$AUDIT_BLOB"
check_blob "$READINESS_REL" "$READINESS_BLOB"
check_blob "$DB_AUDIT_VALIDATION_REL" "$DB_AUDIT_VALIDATION_BLOB"
check_blob "$SETUP_AUDIT_VALIDATION_REL" "$SETUP_AUDIT_VALIDATION_BLOB"
check_blob "$READINESS_VALIDATION_REL" "$READINESS_VALIDATION_BLOB"

echo
echo "--- Detached exact-target regression in Production runtime ---"
sudo git -C "$REPO_ROOT" worktree add --detach "$CANDIDATE_WORKTREE" "$TARGET_SHA"
for rel in     "$AUDIT_REL"     "$READINESS_REL"     "$DB_AUDIT_VALIDATION_REL"     "$SETUP_AUDIT_VALIDATION_REL"     "$READINESS_VALIDATION_REL"; do
    [[ -s "$CANDIDATE_WORKTREE/$rel" ]] || { echo "FAIL: candidate is missing $rel"; exit 14; }
done
sudo -u fieldwiring -H env PYTHONPYCACHEPREFIX="$PYCACHE" bash -c     "cd '$CANDIDATE_WORKTREE' && '$PYTHON' -m pytest -q -p no:cacheprovider Setup/Application"
echo "DETACHED EXACT-TARGET SETUP REGRESSION: PASS"

echo
echo "--- Create and verify rollback PostgreSQL archive ---"
sudo docker exec "$PROD_CONTAINER" pg_dump -U "$DB_ACTOR" -d "$PROD_DB" -Fc > "$BACKUP_FILE"
test -s "$BACKUP_FILE"
BACKUP_CREATED=1
BACKUP_SHA="$(sha256sum "$BACKUP_FILE" | awk '{print $1}')"
sudo docker exec -i "$PROD_CONTAINER" pg_restore --list < "$BACKUP_FILE" >/dev/null
echo "Rollback archive: $BACKUP_FILE"
echo "Rollback SHA256:  $BACKUP_SHA"
echo "ROLLBACK ARCHIVE VALIDATION: PASS"

echo
echo "--- Production database preflight ---"
psql_prod <<'SQL'
DO $preflight$
BEGIN
    IF to_regclass('ref.person') IS NULL
       OR to_regclass('ref.audit_collection_policy') IS NULL
       OR to_regclass('ref.setup_task') IS NULL
       OR to_regclass('ops.setup_session') IS NULL
       OR to_regclass('ops.setup_session_task') IS NULL
       OR to_regclass('ops.setup_task_progress') IS NULL THEN
        RAISE EXCEPTION 'Required shared audit / Setup foundation is incomplete';
    END IF;

    IF to_regprocedure('ref.resolve_actor()') IS NULL
       OR to_regprocedure('ref.set_actor_on_update()') IS NULL
       OR to_regprocedure('ref.set_updated_fields()') IS NULL
       OR to_regprocedure('ref.sync_audit_collection_policy()') IS NULL
       OR to_regprocedure('ref.setup_management_actor(text,boolean)') IS NULL THEN
        RAISE EXCEPTION 'Required shared audit / Setup command functions are incomplete';
    END IF;

    IF EXISTS (SELECT 1 FROM ops.setup_session WHERE season_year=2026) THEN
        RAISE EXCEPTION '2026 Setup Session exists before B1a/audit baseline deployment';
    END IF;

    IF NOT EXISTS (
        SELECT 1
        FROM information_schema.columns
        WHERE table_schema='ops'
          AND table_name='setup_session_task'
          AND column_name='annual_readiness_note'
    ) OR NOT EXISTS (
        SELECT 1
        FROM information_schema.columns
        WHERE table_schema='ops'
          AND table_name='setup_session_task'
          AND column_name='annual_readiness_state'
    ) THEN
        RAISE EXCEPTION 'Scheduling readiness snapshot columns are missing';
    END IF;

    IF NOT has_function_privilege(
        'fieldwiring_app',
        'ref.setup_browser_capabilities(text)',
        'EXECUTE'
    ) OR has_function_privilege(
        'fieldwiring_app',
        'ref.setup_management_actor(text,boolean)',
        'EXECUTE'
    ) THEN
        RAISE EXCEPTION 'Production Setup function authorization boundary is not the accepted contract';
    END IF;
END
$preflight$;
SQL
echo "DATABASE PREFLIGHT: PASS"

PRE_MUTATION_SETUP="$(setup_business_fingerprint)"
if [[ "$PRE_MUTATION_SETUP" != "$SETUP_BEFORE" ]]; then
    echo "FAIL: Setup business rows changed during pre-deployment gates"
    exit 15
fi
echo "PRE-MUTATION SETUP FINGERPRINT STABILITY: PASS"

echo
echo "--- Apply accepted shared audit repair ---"
psql_prod < "$CANDIDATE_WORKTREE/$AUDIT_REL"
AUDIT_COMMITTED=1
echo "SHARED AUDIT REPAIR: COMMITTED"

echo
echo "--- Validate database-wide audit contract in Production transaction ---"
psql_prod < "$CANDIDATE_WORKTREE/$DB_AUDIT_VALIDATION_REL"
echo "DATABASE-WIDE AUDIT VALIDATION: PASS"

echo
echo "--- Apply accepted Setup readiness invariant ---"
psql_prod < "$CANDIDATE_WORKTREE/$READINESS_REL"
READINESS_COMMITTED=1
echo "SETUP READINESS INVARIANT: COMMITTED"

echo
echo "--- Validate Setup audit consumer + readiness invariant in rollback transactions ---"
psql_prod < "$CANDIDATE_WORKTREE/$SETUP_AUDIT_VALIDATION_REL"
psql_prod < "$CANDIDATE_WORKTREE/$READINESS_VALIDATION_REL"
echo "SETUP AUDIT / READINESS VALIDATION: PASS"

POST_DB_SETUP="$(setup_business_fingerprint)"
AUDIT_AFTER="$(audit_contract_fingerprint)"
echo "Setup business fingerprint before DB migrations: $SETUP_BEFORE"
echo "Setup business fingerprint after DB migrations:  $POST_DB_SETUP"
echo "Audit contract fingerprint before:              $AUDIT_BEFORE"
echo "Audit contract fingerprint after:               $AUDIT_AFTER"
if [[ "$POST_DB_SETUP" != "$SETUP_BEFORE" ]]; then
    echo "FAIL: accepted database migrations changed governed Setup business rows"
    exit 16
fi
if [[ -z "$AUDIT_AFTER" ]]; then
    echo "FAIL: post-migration audit contract fingerprint is empty"
    exit 17
fi
if [[ "$(setup_2026_count)" != "0" ]]; then
    echo "FAIL: database baseline deployment created a 2026 Setup Session"
    exit 18
fi
echo "POST-MIGRATION DATA BOUNDARY: PASS"

echo
echo "--- Advance dedicated Setup checkout to exact browser-accepted SHA ---"
sudo git -C "$SETUP_ROOT" merge --ff-only "$TARGET_SHA"
APP_ADVANCED=1
DEPLOYED_HEAD="$(sudo git -C "$SETUP_ROOT" rev-parse HEAD)"
if [[ "$DEPLOYED_HEAD" != "$TARGET_SHA" ]]; then
    echo "FAIL: deployed Setup SHA is $DEPLOYED_HEAD; expected $TARGET_SHA"
    exit 19
fi
if [[ -n "$(sudo git -C "$SETUP_ROOT" status --porcelain)" ]]; then
    echo "FAIL: deployed Setup worktree is not clean"
    exit 20
fi
echo "Setup checkout advanced exactly to $DEPLOYED_HEAD"

echo
echo "--- Restart only Setup and verify runtime ---"
restart_setup_service
SETUP_POST="$(curl -fsS http://192.168.5.9:8794/api/health)"
echo "Post-deploy Setup health: $SETUP_POST"
if [[ "$SETUP_POST" != *"\"status\":\"ok\""*    || "$SETUP_POST" != *"\"data_mode\":\"postgres\""*    || "$SETUP_POST" != *"\"version\":\"$EXPECTED_SETUP_VERSION\""* ]]; then
    echo "FAIL: Setup runtime did not become healthy at $EXPECTED_SETUP_VERSION"
    exit 21
fi

curl -fsS http://192.168.5.9:8794/ | grep -Fq 'setup_scheduling_board.css?v=2026-09-23.4'
curl -fsS http://192.168.5.9:8794/ | grep -Fq 'setup_scheduling_board.js?v=2026-09-23.4'
echo "B1a Scheduling/Task Finder production assets: PASS"

NEGATIVE_CODE="$(curl -sS -o "$NEGATIVE_BODY" -w '%{http_code}'     'http://192.168.5.9:8794/api/setup/scheduling-board?season_year=2026')"
echo "Direct unauthenticated Scheduling Board API status: $NEGATIVE_CODE"
if [[ "$NEGATIVE_CODE" != "401" ]]; then
    echo "FAIL: protected Scheduling Board API did not reject unauthenticated direct request"
    cat "$NEGATIVE_BODY" || true
    exit 22
fi
echo "PROTECTED SCHEDULING BOARD NEGATIVE PATH: PASS"

MANAGER_EMAIL="$(sudo docker exec "$PROD_CONTAINER"     psql -X -qAt -v ON_ERROR_STOP=1 -U "$DB_ACTOR" -d "$PROD_DB" -c "
        SELECT lower(u.email)
        FROM public.directus_users u
        JOIN ref.person p ON p.directus_user_id=u.id
        JOIN LATERAL ref.setup_browser_capabilities(u.email) c ON true
        WHERE u.status='active'
          AND c.can_manage_setup
        ORDER BY u.email
        LIMIT 1;
    ")"
[[ -n "$MANAGER_EMAIL" ]] || { echo "FAIL: no active Setup Manager identity found"; exit 23; }

BOARD_2026="$(curl -fsS     -H "Cf-Access-Authenticated-User-Email: $MANAGER_EMAIL"     'http://192.168.5.9:8794/api/setup/scheduling-board?season_year=2026')"
if [[ "$BOARD_2026" != *"\"session\":null"* ]]; then
    echo "FAIL: 2026 Scheduling Board must remain session-null after this baseline deployment"
    echo "$BOARD_2026"
    exit 24
fi
echo "AUTHENTICATED 2026 BOARD REMAINS UNCREATED: PASS"

echo
echo "--- Live Setup regression ---"
sudo -u fieldwiring -H env PYTHONPYCACHEPREFIX="$PYCACHE" bash -c     "cd '$SETUP_ROOT' && '$PYTHON' -m pytest -q -p no:cacheprovider Setup/Application"
echo "LIVE SETUP REGRESSION: PASS"

echo
echo "--- Final Production invariants ---"
FINAL_HEAD="$(sudo git -C "$SETUP_ROOT" rev-parse HEAD)"
FINAL_STATUS="$(sudo git -C "$SETUP_ROOT" status --porcelain)"
FINAL_SETUP="$(setup_business_fingerprint)"
FINAL_2026="$(setup_2026_count)"
FINAL_AUDIT="$(audit_contract_fingerprint)"

echo "Final Setup SHA:                $FINAL_HEAD"
echo "Final Setup business fingerprint: $FINAL_SETUP"
echo "Final audit contract fingerprint:  $FINAL_AUDIT"
echo "Final 2026 Setup Session count:    $FINAL_2026"

[[ "$FINAL_HEAD" == "$TARGET_SHA" ]]
[[ -z "$FINAL_STATUS" ]]
[[ "$FINAL_SETUP" == "$SETUP_BEFORE" ]]
[[ "$FINAL_2026" == "0" ]]
[[ -n "$FINAL_AUDIT" ]]

SUCCESS=1
echo
echo "SETUP_122_B1A_AUDIT_BASELINE_PRODUCTION_DEPLOYMENT_PASS"
echo "Scheduling completion: NOT DECLARED"
echo "2026 Setup Session:     NOT CREATED"
echo "Rollback archive:      $BACKUP_FILE"
echo "Rollback SHA256:       $BACKUP_SHA"
echo "Deployment report:     $REPORT"
