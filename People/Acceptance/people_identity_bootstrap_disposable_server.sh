#!/usr/bin/env bash
set -Eeuo pipefail
umask 077

ISSUE="#395"
SOURCE_REF="${2:-issue-395-silent-human-identity-bootstrap}"
CANDIDATE_SHA="${1:-}"
SERVICE_SCOPE_PROBE="${3:-false}"
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

REPO_ROOT="/opt/fieldwiring"
PRODUCTION_PYTHON="/opt/fieldwiring/.venv/bin/python"

PROD_DB_CONTAINER="msb-postgres"
PROD_DIRECTUS_CONTAINER="msb-directus"
PROD_DB="msb"
DB_ACTOR="msbadmin"
DB_IMAGE="postgis/postgis:16-3.5"
DIRECTUS_IMAGE="directus/directus:11.17.1"
NETWORK="msb-stack_default"

STAMP="$(date +%Y%m%dT%H%M%S)"
SHORT_STAMP="$(date +%H%M%S)"
WORKTREE="/tmp/msb-395-bootstrap-candidate-${STAMP}"
DUMP_FILE="/tmp/msb-395-bootstrap-production-${STAMP}.dump"
REPORT="/tmp/MSB_People_Identity_Bootstrap_Disposable_${STAMP}.txt"
TEST_DB_CONTAINER="msb-395-bootstrap-db-${SHORT_STAMP}-$$"
TEST_DIRECTUS_CONTAINER="msb-395-bootstrap-directus-${SHORT_STAMP}-$$"
TEST_DB_PASSWORD="msb395db-${SHORT_STAMP}-$$"
PEOPLE_APP_PASSWORD="msb395people-${SHORT_STAMP}-$$"
DIRECTUS_ADMIN_TOKEN=""
DIRECTUS_SECRET=""
PROD_PERSON_FP=""
PROD_DIRECTUS_FP=""

HUMAN_EMAIL="bootstrap-${SHORT_STAMP}-$$@sheboyganlights.org"
INACTIVE_EMAIL="bootstrap-inactive-${SHORT_STAMP}-$$@sheboyganlights.org"
MISSING_EMAIL="bootstrap-missing-${SHORT_STAMP}-$$@sheboyganlights.org"
TABLET_EMAIL="tablet-395-${SHORT_STAMP}-$$@sheboyganlights.org"
GHOST_EMAIL="bootstrap-ghost-${SHORT_STAMP}-$$@sheboyganlights.org"

exec > >(tee "$REPORT") 2>&1

if [[ "$SERVICE_SCOPE_PROBE" != "false" && "$SERVICE_SCOPE_PROBE" != "true" ]]; then
    echo "FAIL: unsupported disposable service scope profile"
    exit 2
fi
if [[ -z "$CANDIDATE_SHA" ]]; then
    echo "FAIL: exact candidate SHA argument is required"
    exit 2
fi

prod_person_fp() {
    sudo docker exec "$PROD_DB_CONTAINER" \
        psql -X -qAt -v ON_ERROR_STOP=1 -U "$DB_ACTOR" -d "$PROD_DB" \
        -c "SELECT md5(coalesce(string_agg(row_to_json(p)::text,'' ORDER BY p.person_id),'')) FROM ref.person p;"
}

prod_directus_fp() {
    sudo docker exec "$PROD_DB_CONTAINER" \
        psql -X -qAt -v ON_ERROR_STOP=1 -U "$DB_ACTOR" -d "$PROD_DB" \
        -c "SELECT md5(coalesce(string_agg(row_to_json(u)::text,'' ORDER BY u.id),'')) FROM public.directus_users u;"
}

cleanup() {
    status=$?
    trap - EXIT HUP INT TERM
    set +e

    echo
    echo "--- Cleanup ---"
    sudo docker rm -f "$TEST_DIRECTUS_CONTAINER" >/dev/null 2>&1 || true
    sudo docker rm -f "$TEST_DB_CONTAINER" >/dev/null 2>&1 || true

    if sudo git -C "$REPO_ROOT" worktree list --porcelain 2>/dev/null \
       | grep -Fq "worktree $WORKTREE"; then
        sudo git -C "$REPO_ROOT" worktree remove --force "$WORKTREE" >/dev/null 2>&1 || true
    fi
    sudo git -C "$REPO_ROOT" worktree prune >/dev/null 2>&1 || true
    rm -f "$DUMP_FILE" >/dev/null 2>&1 || true

    echo
    echo "--- Production after-check ---"
    if [[ -n "$PROD_PERSON_FP" ]]; then
        after_person="$(prod_person_fp 2>/dev/null || true)"
        echo "Person before: $PROD_PERSON_FP"
        echo "Person after:  $after_person"
        if [[ -z "$after_person" || "$after_person" != "$PROD_PERSON_FP" ]]; then
            echo "FAIL: Production ref.person fingerprint changed"
            status=97
        else
            echo "PASS: Production ref.person fingerprint unchanged"
        fi
    else
        echo "Person fingerprint: SKIP — not captured before stop"
    fi

    if [[ -n "$PROD_DIRECTUS_FP" ]]; then
        after_directus="$(prod_directus_fp 2>/dev/null || true)"
        echo "Directus before: $PROD_DIRECTUS_FP"
        echo "Directus after:  $after_directus"
        if [[ -z "$after_directus" || "$after_directus" != "$PROD_DIRECTUS_FP" ]]; then
            echo "FAIL: Production directus_users fingerprint changed"
            status=98
        else
            echo "PASS: Production directus_users fingerprint unchanged"
        fi
    else
        echo "Directus fingerprint: SKIP — not captured before stop"
    fi

    echo "Report retained at: $REPORT"
    echo "Exit status: $status"
    if [[ "$SERVICE_SCOPE_PROBE" == "true" ]]; then
        echo
        echo "========== BEGIN #395 RESULT =========="
        echo "Proof target:    #49 / #395 scoped Directus service credential"
        echo "Accepted People: dcc8f25f07a74e19ce3de3aae2d9d137b5411815"
        echo "Tooling SHA:     $CANDIDATE_SHA"
        echo "Directus image:  $DIRECTUS_IMAGE"
        if [[ "$status" == "0" ]]; then
            echo "Disposable scope: PASS"
        else
            echo "Disposable scope: STOP (read first failing line in report)"
        fi
        echo "Production FP:   See Person/Directus before-after PASS/FAIL above"
        echo "Production writes: NONE"
        echo "Real Don fixture: NOT CONSUMED"
        echo "Exit status:     $status"
        echo "Report:          $REPORT"
        echo "========== END #395 RESULT =========="
    fi
    exit "$status"
}
trap cleanup EXIT HUP INT TERM

echo "========== PEOPLE #395 SILENT IDENTITY BOOTSTRAP DISPOSABLE ACCEPTANCE =========="
echo "Issue:                 $ISSUE"
echo "Candidate SHA:         $CANDIDATE_SHA"
echo "Candidate ref:         $SOURCE_REF"
echo "Service policy proof: $SERVICE_SCOPE_PROBE"
echo "Authority:             MSB-Server-Management — PostgreSQL_Disposable_Acceptance_Standard.md"
echo "Production access:     git fetch/worktree + pg_dump + SELECT only"
echo "Production mutation:   NONE"
echo "Disposable Directus:   $DIRECTUS_IMAGE"
echo "Report:                $REPORT"
echo

sudo -v

[[ "$(hostname)" == "msb-prod-db" ]] || { echo "FAIL: wrong host"; exit 3; }
sudo docker inspect "$PROD_DB_CONTAINER" >/dev/null
sudo docker inspect "$PROD_DIRECTUS_CONTAINER" >/dev/null
[[ "$(sudo docker inspect "$PROD_DB_CONTAINER" --format '{{.Config.Image}}')" == "$DB_IMAGE" ]] \
    || { echo "FAIL: unexpected Production PostgreSQL image"; exit 4; }
[[ "$(sudo docker inspect "$PROD_DIRECTUS_CONTAINER" --format '{{.Config.Image}}')" == "$DIRECTUS_IMAGE" ]] \
    || { echo "FAIL: unexpected Production Directus image"; exit 5; }
sudo docker network inspect "$NETWORK" >/dev/null

echo "--- Refresh exact candidate without moving live checkout ---"
sudo git -C "$REPO_ROOT" fetch origin "$SOURCE_REF:refs/remotes/origin/$SOURCE_REF"
sudo git -C "$REPO_ROOT" cat-file -e "$CANDIDATE_SHA^{commit}"
[[ "$(sudo git -C "$REPO_ROOT" rev-parse "refs/remotes/origin/$SOURCE_REF")" == "$CANDIDATE_SHA" ]] \
    || { echo "FAIL: remote candidate ref has moved away from requested SHA"; exit 6; }
sudo git -C "$REPO_ROOT" worktree add --detach "$WORKTREE" "$CANDIDATE_SHA"

for required in \
    "$WORKTREE/People/Database/001_create_people_manager_contract.sql" \
    "$WORKTREE/People/Database/002_harden_people_search_phone_filter.sql" \
    "$WORKTREE/People/Database/003_create_people_metadata_contract.sql" \
    "$WORKTREE/People/Database/004_stop_automatic_msb_email_generation.sql" \
    "$WORKTREE/People/Database/005_reconcile_directus_person_identity.sql" \
    "$WORKTREE/People/Database/006_create_silent_identity_bootstrap_contract.sql" \
    "$WORKTREE/People/Application/backend.py" \
    "$WORKTREE/People/Application/directus_identity_bootstrap.py" \
    "$WORKTREE/People/Application/test_people_manager_contract.py" \
    "$WORKTREE/People/Application/test_people_identity_bootstrap_runtime.py"; do
    [[ -s "$required" ]] || { echo "FAIL: candidate missing $required"; exit 7; }
done
echo "PASS: exact candidate worktree ready"

echo
echo "--- Candidate Python contract/runtime regression ---"
sudo -u fieldwiring -H bash -c \
    "cd '$WORKTREE' && '$PRODUCTION_PYTHON' -m pytest -q -p no:cacheprovider \
      People/Application/test_people_manager_contract.py \
      People/Application/test_people_identity_bootstrap_runtime.py \
      People/Application/test_people_shared_tablet_identity_contract.py \
      People/Acceptance/test_people_identity_bootstrap_acceptance_contract.py"
echo "PASS: candidate People application regression"

PROD_PERSON_FP="$(prod_person_fp)"
PROD_DIRECTUS_FP="$(prod_directus_fp)"
echo
echo "--- Production read-only fingerprints ---"
echo "ref.person:       $PROD_PERSON_FP"
echo "directus_users:  $PROD_DIRECTUS_FP"

echo
echo "--- Verify live Directus onboarding authority remains the expected create-event gate ---"
sudo docker exec "$PROD_DB_CONTAINER" \
    psql -X -v ON_ERROR_STOP=1 -U "$DB_ACTOR" -d "$PROD_DB" <<'SQL'
DO $verify$
DECLARE
    v_flow_count integer;
    v_condition_count integer;
BEGIN
    SELECT count(*)
      INTO v_flow_count
    FROM public.directus_flows f
    WHERE f.name='User Onboarding'
      AND f.status='active'
      AND f.trigger='event'
      AND coalesce(f.options::text,'') ILIKE '%items.create%'
      AND coalesce(f.options::text,'') ILIKE '%directus_users%';

    IF v_flow_count <> 1 THEN
        RAISE EXCEPTION 'Expected exactly one active User Onboarding directus_users create-event flow';
    END IF;

    SELECT count(*)
      INTO v_condition_count
    FROM public.directus_operations o
    JOIN public.directus_flows f ON f.id=o.flow
    WHERE f.name='User Onboarding'
      AND o.key='check_google_user'
      AND coalesce(o.options::text,'') ILIKE '%provider%'
      AND coalesce(o.options::text,'') ILIKE '%google%'
      AND coalesce(o.options::text,'') ILIKE '%role%'
      AND coalesce(o.options::text,'') ILIKE '%_null%';

    IF v_condition_count <> 1 THEN
        RAISE EXCEPTION 'Expected User Onboarding Google + role NULL condition was not found';
    END IF;
END
$verify$;
SQL
echo "PASS: live User Onboarding trigger/role-null gate matches #395 design premise"

echo
echo "--- Capture current Production for disposable clone ---"
sudo docker exec "$PROD_DB_CONTAINER" pg_dump -U "$DB_ACTOR" -d "$PROD_DB" -Fc > "$DUMP_FILE"
test -s "$DUMP_FILE"
sudo docker exec -i "$PROD_DB_CONTAINER" pg_restore --list < "$DUMP_FILE" >/dev/null
echo "PASS: Production dump captured and validated"

echo
echo "--- Start disposable PostgreSQL ---"
sudo docker run -d --name "$TEST_DB_CONTAINER" --network "$NETWORK" \
    -e POSTGRES_USER="$DB_ACTOR" \
    -e POSTGRES_PASSWORD="$TEST_DB_PASSWORD" \
    -e POSTGRES_DB=postgres \
    "$DB_IMAGE" >/dev/null

ready=0
pid1=""
for _ in $(seq 1 120); do
    [[ "$(sudo docker inspect "$TEST_DB_CONTAINER" --format '{{.State.Running}}' 2>/dev/null || true)" == "true" ]] || break
    pid1="$(sudo docker exec "$TEST_DB_CONTAINER" sh -c 'cat /proc/1/comm' 2>/dev/null | tr -d '\r\n' || true)"
    if [[ "$pid1" == "postgres" ]] \
       && sudo docker exec -e PGPASSWORD="$TEST_DB_PASSWORD" "$TEST_DB_CONTAINER" \
            pg_isready -U "$DB_ACTOR" -d postgres >/dev/null 2>&1; then
        ready=1
        break
    fi
    sleep 1
done
[[ "$ready" == "1" ]] || {
    echo "FAIL: disposable PostgreSQL did not reach final post-init ready state; PID1=${pid1:-unknown}"
    sudo docker logs "$TEST_DB_CONTAINER" || true
    exit 8
}

sudo docker exec -e PGPASSWORD="$TEST_DB_PASSWORD" "$TEST_DB_CONTAINER" \
    createdb -U "$DB_ACTOR" -T template0 "$PROD_DB"
sudo docker exec -i -e PGPASSWORD="$TEST_DB_PASSWORD" "$TEST_DB_CONTAINER" \
    pg_restore -U "$DB_ACTOR" -d "$PROD_DB" --no-owner --no-acl --exit-on-error < "$DUMP_FILE"
echo "PASS: current Production restored to disposable PostgreSQL"

psql_test() {
    sudo docker exec -i -e PGPASSWORD="$TEST_DB_PASSWORD" "$TEST_DB_CONTAINER" \
        psql -X -v ON_ERROR_STOP=1 -U "$DB_ACTOR" -d "$PROD_DB" "$@"
}
psql_q() {
    sudo docker exec -i -e PGPASSWORD="$TEST_DB_PASSWORD" "$TEST_DB_CONTAINER" \
        psql -X -qAt -v ON_ERROR_STOP=1 -U "$DB_ACTOR" -d "$PROD_DB" "$@"
}

echo
echo "--- Create disposable application-role principals ---"
psql_test <<SQL
DO \$roles\$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname='fieldwiring_app') THEN
        CREATE ROLE fieldwiring_app NOLOGIN;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname='directus_app') THEN
        CREATE ROLE directus_app NOLOGIN;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname='people_app') THEN
        CREATE ROLE people_app LOGIN;
    END IF;
END
\$roles\$;
ALTER ROLE people_app LOGIN PASSWORD '$PEOPLE_APP_PASSWORD';
SQL
echo "PASS: disposable roles ready"

echo
echo "--- Reapply accepted People contracts and candidate migration 006 to clone ---"
for migration in \
    001_create_people_manager_contract.sql \
    002_harden_people_search_phone_filter.sql \
    003_create_people_metadata_contract.sql \
    004_stop_automatic_msb_email_generation.sql \
    005_reconcile_directus_person_identity.sql \
    006_create_silent_identity_bootstrap_contract.sql; do
    psql_test < "$WORKTREE/People/Database/$migration"
done
echo "PASS: People migrations 001-006 applied to disposable clone"

echo
echo "--- Bootstrap database contract / least privilege ---"
psql_test <<'SQL'
DO $contract$
BEGIN
    IF to_regprocedure('ref.people_identity_bootstrap_status(text)') IS NULL
       OR to_regprocedure('ref.people_identity_bootstrap_reconcile(text)') IS NULL THEN
        RAISE EXCEPTION 'Identity bootstrap functions are missing';
    END IF;

    IF NOT has_function_privilege(
        'people_app',
        'ref.people_identity_bootstrap_status(text)',
        'EXECUTE'
    ) OR NOT has_function_privilege(
        'people_app',
        'ref.people_identity_bootstrap_reconcile(text)',
        'EXECUTE'
    ) THEN
        RAISE EXCEPTION 'people_app is missing bootstrap EXECUTE';
    END IF;

    IF has_table_privilege('people_app','ref.person','SELECT')
       OR has_table_privilege('people_app','ref.person','INSERT')
       OR has_table_privilege('people_app','public.directus_users','SELECT')
       OR has_table_privilege('people_app','public.directus_users','INSERT')
       OR has_table_privilege('people_app','public.directus_users','UPDATE')
       OR has_table_privilege('people_app','public.directus_roles','SELECT') THEN
        RAISE EXCEPTION 'people_app leaked direct identity-table privilege';
    END IF;
END
$contract$;
SQL
echo "PASS: bootstrap DB functions present and people_app remains least privilege"

echo
echo "--- Build clone-only human/nonhuman fixtures ---"
psql_test <<SQL
INSERT INTO ref.person(first_name,last_name,email,active_flag,directus_user_id)
VALUES
    ('Bootstrap','Human','$HUMAN_EMAIL',true,NULL),
    ('Bootstrap','Inactive','$INACTIVE_EMAIL',false,NULL);

DO \$fixtures\$
BEGIN
    IF EXISTS (SELECT 1 FROM public.directus_users WHERE lower(email) IN (
        lower('$HUMAN_EMAIL'), lower('$INACTIVE_EMAIL'), lower('$MISSING_EMAIL'),
        lower('$TABLET_EMAIL'), lower('$GHOST_EMAIL')
    )) THEN
        RAISE EXCEPTION 'Generated disposable fixture email collided with Directus data';
    END IF;
END
\$fixtures\$;
SQL

[[ "$(psql_q -c "SELECT disposition FROM ref.people_identity_bootstrap_status('$HUMAN_EMAIL');")" == "READY_CREATE" ]] \
    || { echo "FAIL: active human fixture is not READY_CREATE"; exit 9; }
[[ "$(psql_q -c "SELECT disposition FROM ref.people_identity_bootstrap_status('$INACTIVE_EMAIL');")" == "PERSON_INACTIVE" ]] \
    || { echo "FAIL: inactive human fixture did not fail closed"; exit 10; }
[[ "$(psql_q -c "SELECT disposition FROM ref.people_identity_bootstrap_status('$MISSING_EMAIL');")" == "NO_PERSON" ]] \
    || { echo "FAIL: missing human fixture did not return NO_PERSON"; exit 11; }
[[ "$(psql_q -c "SELECT disposition FROM ref.people_identity_bootstrap_status('$TABLET_EMAIL');")" == "NONHUMAN_ACCOUNT" ]] \
    || { echo "FAIL: tablet fixture did not remain NONHUMAN_ACCOUNT"; exit 12; }
echo "PASS: bootstrap status classifications"

BASELINE_ROLE_ID="$(psql_q -c "SELECT id FROM public.directus_roles WHERE name='MSB Browser';")"
[[ -n "$BASELINE_ROLE_ID" ]] || { echo "FAIL: MSB Browser role ID missing in clone"; exit 13; }

ADMIN_USER_ID="$(psql_q -c "
SELECT u.id
FROM public.directus_users u
WHERE u.status='active'
  AND EXISTS (
      SELECT 1
      FROM public.directus_access a
      JOIN public.directus_policies p ON p.id=a.policy
      WHERE (a."user"=u.id OR (u.role IS NOT NULL AND a.role=u.role))
        AND p.admin_access
  )
ORDER BY u.email
LIMIT 1;
")"
[[ -n "$ADMIN_USER_ID" ]] || { echo "FAIL: no active Directus admin user found in disposable clone"; exit 14; }

DIRECTUS_ADMIN_TOKEN="$(openssl rand -hex 32)"
DIRECTUS_SECRET="$(openssl rand -hex 32)"
psql_q -c "UPDATE public.directus_users SET token='$DIRECTUS_ADMIN_TOKEN' WHERE id='$ADMIN_USER_ID'::uuid;" >/dev/null
echo "PASS: clone-only Directus admin static token prepared (not printed)"

echo
echo "--- Start disposable Directus 11.17.1 against disposable PostgreSQL ---"
sudo docker run -d --name "$TEST_DIRECTUS_CONTAINER" --network "$NETWORK" \
    -e SECRET="$DIRECTUS_SECRET" \
    -e DB_CLIENT=pg \
    -e DB_HOST="$TEST_DB_CONTAINER" \
    -e DB_PORT=5432 \
    -e DB_DATABASE="$PROD_DB" \
    -e DB_USER="$DB_ACTOR" \
    -e DB_PASSWORD="$TEST_DB_PASSWORD" \
    -e PUBLIC_URL="http://127.0.0.1:8055" \
    -e TELEMETRY=false \
    "$DIRECTUS_IMAGE" >/dev/null

directus_ready=0
for _ in $(seq 1 120); do
    if [[ "$(sudo docker inspect "$TEST_DIRECTUS_CONTAINER" --format '{{.State.Running}}' 2>/dev/null || true)" != "true" ]]; then
        break
    fi
    if sudo docker exec "$TEST_DIRECTUS_CONTAINER" node -e \
        "fetch('http://127.0.0.1:8055/server/health').then(r=>{if(!r.ok)process.exit(1)}).catch(()=>process.exit(1))" \
        >/dev/null 2>&1; then
        directus_ready=1
        break
    fi
    sleep 1
done
if [[ "$directus_ready" != "1" ]]; then
    echo "FAIL: disposable Directus did not become healthy"
    sudo docker logs --tail 200 "$TEST_DIRECTUS_CONTAINER" || true
    exit 15
fi
echo "PASS: disposable Directus healthy"

echo
echo "--- Verify disposable admin token through supported Directus API ---"
sudo docker exec -i -e TOKEN="$DIRECTUS_ADMIN_TOKEN" "$TEST_DIRECTUS_CONTAINER" node - <<'NODE'
const token = process.env.TOKEN;
const r = await fetch('http://127.0.0.1:8055/users/me?fields=id', {
  headers: { Authorization: `Bearer ${token}` }
});
if (r.status !== 200) {
  console.error(`Directus /users/me returned HTTP ${r.status}`);
  process.exit(1);
}
console.log('PASS: disposable Directus admin API authentication');
NODE

if [[ "$SERVICE_SCOPE_PROBE" == "true" ]]; then
    [[ "$SOURCE_REF" == "issue-395-production-deployment-readiness" ]] || {
        echo "FAIL: #49 service scope probe only supported on its owning readiness branch"
        exit 31
    }
    [[ -s "$SCRIPT_DIR/people_395_service_scope_disposable_probe.sh" ]] || {
        echo "FAIL: versioned #49 disposable scope probe missing"
        exit 32
    }
    # Never accept runtime changes: the proven People V0.2.3 backend/SQL remains frozen.
    if ! sudo git -C "$REPO_ROOT" diff --quiet          dcc8f25f07a74e19ce3de3aae2d9d137b5411815          "$CANDIDATE_SHA" -- People/Application People/Database; then
        echo "FAIL: scoped-permission disposable tool changed accepted People runtime"
        exit 33
    fi
    # shellcheck disable=SC1091
    source "$SCRIPT_DIR/people_395_service_scope_disposable_probe.sh"
    run_people_395_service_scope_probe
    echo "PASS: scoped service policy proof completed without touching Production"
fi

DB_IP="$(sudo docker inspect "$TEST_DB_CONTAINER" --format '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}')"
DIRECTUS_IP="$(sudo docker inspect "$TEST_DIRECTUS_CONTAINER" --format '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}')"
[[ -n "$DB_IP" && -n "$DIRECTUS_IP" ]] || { echo "FAIL: disposable container IP unavailable"; exit 16; }

echo
echo "--- Exact candidate end-to-end bootstrap through Flask + Directus Users API + clone DB ---"

EXISTING_MANAGER_EMAIL="$(psql_q -c "
SELECT lower(u.email)
FROM public.directus_users u
JOIN ref.person p ON p.directus_user_id=u.id
LEFT JOIN public.directus_roles r ON r.id=u.role
WHERE u.status='active'
  AND lower(coalesce(u.provider,''))='google'
  AND lower(coalesce(u.external_identifier,''))=lower(u.email)
  AND p.active_flag
  AND r.name IN ('Manager','Administrator')
ORDER BY CASE WHEN r.name='Manager' THEN 0 ELSE 1 END, u.email
LIMIT 1;
")"
[[ -n "$EXISTING_MANAGER_EMAIL" ]] || { echo "FAIL: no existing exact Google Manager/Admin fixture in clone"; exit 17; }
EXISTING_MANAGER_ROLE="$(psql_q -c "
SELECT r.name
FROM public.directus_users u
LEFT JOIN public.directus_roles r ON r.id=u.role
WHERE lower(u.email)=lower('$EXISTING_MANAGER_EMAIL')
LIMIT 1;
")"

SAFE_LINK_EMAIL="$(psql_q -c "
SELECT lower(u.email)
FROM public.directus_users u
JOIN ref.person p ON p.directus_user_id=u.id
LEFT JOIN public.directus_roles r ON r.id=u.role
WHERE u.status='active'
  AND lower(coalesce(u.provider,''))='google'
  AND lower(coalesce(u.external_identifier,''))=lower(u.email)
  AND p.active_flag
  AND r.name='Production Crew'
ORDER BY u.email
LIMIT 1;
")"
[[ -n "$SAFE_LINK_EMAIL" ]] || { echo "FAIL: no existing exact Google Production Crew fixture in clone"; exit 18; }
SAFE_LINK_UUID="$(psql_q -c "SELECT id FROM public.directus_users WHERE lower(email)=lower('$SAFE_LINK_EMAIL') LIMIT 1;")"
SAFE_LINK_PERSON_ID="$(psql_q -c "SELECT person_id FROM ref.person WHERE directus_user_id='$SAFE_LINK_UUID'::uuid LIMIT 1;")"
psql_q -c "UPDATE ref.person SET directus_user_id=NULL WHERE person_id=$SAFE_LINK_PERSON_ID;" >/dev/null
[[ "$(psql_q -c "SELECT disposition FROM ref.people_identity_bootstrap_status('$SAFE_LINK_EMAIL');")" == "SAFE_EXISTING_LINK" ]] \
    || { echo "FAIL: clone safe-link fixture not established"; exit 19; }

sudo -u fieldwiring -H env \
    PYTHONPATH="$WORKTREE/People/Application" \
    PEOPLE_DATABASE_DSN="host=$DB_IP port=5432 dbname=$PROD_DB user=people_app password=$PEOPLE_APP_PASSWORD" \
    PEOPLE_DIRECTUS_URL="http://$DIRECTUS_IP:8055" \
    PEOPLE_DIRECTUS_IDENTITY_TOKEN="$DIRECTUS_ADMIN_TOKEN" \
    HUMAN_EMAIL="$HUMAN_EMAIL" \
    INACTIVE_EMAIL="$INACTIVE_EMAIL" \
    MISSING_EMAIL="$MISSING_EMAIL" \
    TABLET_EMAIL="$TABLET_EMAIL" \
    GHOST_EMAIL="$GHOST_EMAIL" \
    BASELINE_ROLE_ID="$BASELINE_ROLE_ID" \
    EXISTING_MANAGER_EMAIL="$EXISTING_MANAGER_EMAIL" \
    EXISTING_MANAGER_ROLE="$EXISTING_MANAGER_ROLE" \
    SAFE_LINK_EMAIL="$SAFE_LINK_EMAIL" \
    "$PRODUCTION_PYTHON" - <<'PY'
import os
import sys

from backend import app
from directus_identity_bootstrap import DirectusIdentityBootstrapClient

def post(email):
    with app.test_client() as client:
        return client.post(
            "/api/identity/bootstrap",
            json={},
            headers={
                "Cf-Access-Authenticated-User-Email": email,
                "X-MSB-Identity-Bootstrap": "1",
            },
        )

human = os.environ["HUMAN_EMAIL"]
response = post(human)
assert response.status_code == 201, (response.status_code, response.get_json())
payload = response.get_json()["identity"]
assert payload == {
    "state": "ready",
    "created": True,
    "linked": True,
    "role_name": "MSB Browser",
}, payload
print("PASS: READY_CREATE -> Directus user -> exact Person link -> MSB Browser")

repeat = post(human)
assert repeat.status_code == 200, (repeat.status_code, repeat.get_json())
assert repeat.get_json()["identity"]["created"] is False
assert repeat.get_json()["identity"]["role_name"] == "MSB Browser"
print("PASS: repeat bootstrap is idempotent")

manager = post(os.environ["EXISTING_MANAGER_EMAIL"])
assert manager.status_code == 200, (manager.status_code, manager.get_json())
assert manager.get_json()["identity"]["role_name"] == os.environ["EXISTING_MANAGER_ROLE"]
assert manager.get_json()["identity"]["created"] is False
print("PASS: existing Manager/Administrator role preserved")

crew = post(os.environ["SAFE_LINK_EMAIL"])
assert crew.status_code == 200, (crew.status_code, crew.get_json())
assert crew.get_json()["identity"]["role_name"] == "Production Crew"
assert crew.get_json()["identity"]["created"] is False
print("PASS: existing Production Crew safe link reconciled without role change")

missing = post(os.environ["MISSING_EMAIL"])
assert missing.status_code == 403, (missing.status_code, missing.get_json())
print("PASS: missing Person fails before Directus creation")

inactive = post(os.environ["INACTIVE_EMAIL"])
assert inactive.status_code == 403, (inactive.status_code, inactive.get_json())
print("PASS: inactive Person fails before Directus creation")

tablet = post(os.environ["TABLET_EMAIL"])
assert tablet.status_code == 200, (tablet.status_code, tablet.get_json())
assert tablet.get_json()["identity"]["state"] == "nonhuman"
assert tablet.get_json()["identity"]["created"] is False
assert tablet.get_json()["identity"]["linked"] is False
print("PASS: tablet identity remains non-human/no-op")

# Directly exercise the supported Directus Users API with a non-null Browser
# role and no Person. The legacy User Onboarding flow must stop at role IS NULL
# and therefore must not auto-create a Person.
client = DirectusIdentityBootstrapClient()
ghost = os.environ["GHOST_EMAIL"]
created = client.create_google_browser_user(
    email=ghost,
    first_name="Bootstrap",
    last_name="Ghost",
    baseline_role_id=os.environ["BASELINE_ROLE_ID"],
)
assert created.get("id")
print("PASS: supported Directus Users API accepts provider/external_identifier + Browser role")
PY

echo
echo "--- Verify resulting clone state ---"
HUMAN_ROW="$(psql_q -F '|' -c "
SELECT
    u.status,
    lower(u.provider),
    lower(u.external_identifier),
    r.name,
    p.person_id,
    (p.directus_user_id=u.id)
FROM public.directus_users u
JOIN ref.person p ON lower(p.email)=lower(u.email)
LEFT JOIN public.directus_roles r ON r.id=u.role
WHERE lower(u.email)=lower('$HUMAN_EMAIL');
")"
IFS='|' read -r HUMAN_STATUS HUMAN_PROVIDER HUMAN_EXTERNAL HUMAN_ROLE HUMAN_PERSON_ID HUMAN_LINKED <<< "$HUMAN_ROW"
if [[ "$HUMAN_STATUS" != "active" \
      || "$HUMAN_PROVIDER" != "google" \
      || "$HUMAN_EXTERNAL" != "$HUMAN_EMAIL" \
      || "$HUMAN_ROLE" != "MSB Browser" \
      || ! "$HUMAN_PERSON_ID" =~ ^[0-9]+$ \
      || "$HUMAN_LINKED" != "t" ]]; then
    echo "FAIL: created human identity final state unexpected: $HUMAN_ROW"
    exit 20
fi
echo "PASS: new human identity exact Google/Browser/Person link"

MANAGER_ROLE_AFTER="$(psql_q -c "
SELECT r.name
FROM public.directus_users u
LEFT JOIN public.directus_roles r ON r.id=u.role
WHERE lower(u.email)=lower('$EXISTING_MANAGER_EMAIL')
LIMIT 1;
")"
[[ "$MANAGER_ROLE_AFTER" == "$EXISTING_MANAGER_ROLE" ]] \
    || { echo "FAIL: existing Manager/Admin role changed"; exit 21; }
echo "PASS: existing Manager/Admin role unchanged"

CREW_ROLE_AFTER="$(psql_q -c "
SELECT r.name
FROM public.directus_users u
LEFT JOIN public.directus_roles r ON r.id=u.role
WHERE lower(u.email)=lower('$SAFE_LINK_EMAIL')
LIMIT 1;
")"
[[ "$CREW_ROLE_AFTER" == "Production Crew" ]] \
    || { echo "FAIL: existing Production Crew role changed"; exit 22; }
[[ "$(psql_q -c "SELECT directus_user_id::text FROM ref.person WHERE person_id=$SAFE_LINK_PERSON_ID;")" == "$SAFE_LINK_UUID" ]] \
    || { echo "FAIL: Production Crew safe link was not restored"; exit 23; }
echo "PASS: Production Crew role preserved and Person link restored"

for blocked in "$MISSING_EMAIL" "$INACTIVE_EMAIL" "$TABLET_EMAIL"; do
    [[ "$(psql_q -c "SELECT count(*) FROM public.directus_users WHERE lower(email)=lower('$blocked');")" == "0" ]] \
        || { echo "FAIL: blocked/no-op identity unexpectedly created Directus user: $blocked"; exit 24; }
done
echo "PASS: missing/inactive/nonhuman states created no Directus users"

[[ "$(psql_q -c "SELECT count(*) FROM ref.person WHERE lower(email)=lower('$GHOST_EMAIL');")" == "0" ]] \
    || { echo "FAIL: legacy User Onboarding auto-created Person for non-null-role Directus user"; exit 25; }
GHOST_ROLE="$(psql_q -c "
SELECT r.name
FROM public.directus_users u
LEFT JOIN public.directus_roles r ON r.id=u.role
WHERE lower(u.email)=lower('$GHOST_EMAIL')
LIMIT 1;
")"
[[ "$GHOST_ROLE" == "MSB Browser" ]] \
    || { echo "FAIL: ghost API-created Directus user did not retain Browser role"; exit 26; }
echo "PASS: non-null Browser role prevents legacy missing-Person auto-create branch"

echo
echo "--- Directus disposable logs (error scan) ---"
if sudo docker logs "$TEST_DIRECTUS_CONTAINER" 2>&1 \
    | grep -Eqi 'uncaught|fatal|syntax error|failed to load'; then
    sudo docker logs --tail 200 "$TEST_DIRECTUS_CONTAINER" 2>&1
    echo "FAIL: disposable Directus logs contain fatal/load error evidence"
    exit 27
fi
echo "PASS: no fatal/load errors detected in disposable Directus logs"

echo
echo "PEOPLE #395 SILENT IDENTITY BOOTSTRAP DISPOSABLE ACCEPTANCE: PASS"
echo "Candidate SHA: $CANDIDATE_SHA"
echo "Report:        $REPORT"
