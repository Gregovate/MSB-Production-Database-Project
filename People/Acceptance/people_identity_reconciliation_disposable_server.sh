#!/usr/bin/env bash
set -euo pipefail
umask 077

REPO_ROOT="/opt/fieldwiring"
PRODUCTION_PYTHON="/opt/fieldwiring/.venv/bin/python"
SOURCE_REF="agent/385-directus-person-self-reconcile"
ACCEPTED_RUNTIME_SHA="2c9a2937079f817dafd5119584aaffc77b51357d"
CANDIDATE_WORKTREE="/tmp/msb-identity-reconcile-static-${$}"
PROD_CONTAINER="msb-postgres"
PROD_DB="msb"
DB_ACTOR="msbadmin"
IMAGE="postgis/postgis:16-3.5"
NETWORK="msb-stack_default"
TEST_CONTAINER="msb-identity-reconcile-accept-${$}"
TEST_PASSWORD="identity-reconcile-accept-${$}-$(date +%s)"
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
SQL005="$SCRIPT_DIR/005_reconcile_directus_person_identity.sql"
DUMP_FILE="$SCRIPT_DIR/production.dump"
REPORT="/tmp/MSB_Identity_Reconcile_Disposable_$(date +%Y%m%d-%H%M%S).txt"
PROD_BEFORE=""

exec > >(tee "$REPORT") 2>&1

echo "========== DIRECTUS <-> PERSON IDENTITY DISPOSABLE ACCEPTANCE =========="
echo "Issue: #385"
echo "Authority: MSB-Server-Management — PostgreSQL_Disposable_Acceptance_Standard.md"
echo "Production access: pg_dump + SELECT only"
echo "Candidate migration: People/Database/005_reconcile_directus_person_identity.sql"
echo "Report: $REPORT"
echo

prod_fingerprint() {
    sudo docker exec "$PROD_CONTAINER" psql -X -qAt -v ON_ERROR_STOP=1 \
        -U "$DB_ACTOR" -d "$PROD_DB" \
        -c "SELECT md5(coalesce(string_agg(row_to_json(p)::text,'' ORDER BY p.person_id),'')) FROM ref.person p;"
}

cleanup() {
    status=$?
    trap - EXIT INT TERM
    set +e
    echo
    echo "--- Production after-check ---"
    if [[ -n "$PROD_BEFORE" ]]; then
        PROD_AFTER="$(prod_fingerprint 2>/dev/null || true)"
        echo "Before: $PROD_BEFORE"
        echo "After:  $PROD_AFTER"
        if [[ -z "$PROD_AFTER" || "$PROD_AFTER" != "$PROD_BEFORE" ]]; then
            echo "FAIL: Production ref.person fingerprint changed"
            status=97
        else
            echo "PASS: Production ref.person fingerprint unchanged"
        fi
    fi
    sudo docker rm -f "$TEST_CONTAINER" >/dev/null 2>&1 || true
    if sudo git -C "$REPO_ROOT" worktree list --porcelain 2>/dev/null | grep -Fq "worktree $CANDIDATE_WORKTREE"; then
        sudo git -C "$REPO_ROOT" worktree remove --force "$CANDIDATE_WORKTREE" >/dev/null 2>&1 || true
    fi
    sudo git -C "$REPO_ROOT" worktree prune >/dev/null 2>&1 || true
    rm -f "$DUMP_FILE" >/dev/null 2>&1 || true
    echo "Report retained at: $REPORT"
    echo "Exit status: $status"
    exit "$status"
}
trap cleanup EXIT INT TERM

[[ -s "$SQL005" ]] || { echo "FAIL: migration 005 missing"; exit 2; }

sudo -v
sudo docker inspect "$PROD_CONTAINER" >/dev/null
[[ "$(sudo docker inspect "$PROD_CONTAINER" --format '{{.Config.Image}}')" == "$IMAGE" ]] || {
    echo "FAIL: unexpected Production PostgreSQL image"
    exit 3
}
sudo docker network inspect "$NETWORK" >/dev/null

echo "--- Exact-candidate contract regression in governed Production Python runtime ---"
sudo git -C "$REPO_ROOT" fetch origin "$SOURCE_REF:refs/remotes/origin/$SOURCE_REF"
sudo git -C "$REPO_ROOT" cat-file -e "$ACCEPTED_RUNTIME_SHA^{commit}"
sudo git -C "$REPO_ROOT" worktree add --detach "$CANDIDATE_WORKTREE" "$ACCEPTED_RUNTIME_SHA"

for required in \
    "$CANDIDATE_WORKTREE/People/Application/test_people_manager_contract.py" \
    "$CANDIDATE_WORKTREE/People/Application/test_people_shared_tablet_identity_contract.py" \
    "$CANDIDATE_WORKTREE/People/Database/005_reconcile_directus_person_identity.sql"; do
    [[ -s "$required" ]] || { echo "FAIL: exact candidate is missing $required"; exit 5; }
done

sudo -u fieldwiring -H bash -c \
    "cd '$CANDIDATE_WORKTREE' && '$PRODUCTION_PYTHON' -m pytest -q -p no:cacheprovider People/Application/test_people_manager_contract.py People/Application/test_people_shared_tablet_identity_contract.py"
echo "PASS: exact-candidate contract regression"

PROD_BEFORE="$(prod_fingerprint)"
echo "Production ref.person fingerprint: $PROD_BEFORE"

echo
echo "--- Read-only current Production reconciliation snapshot ---"
sudo docker exec "$PROD_CONTAINER" psql -X -P pager=off -U "$DB_ACTOR" -d "$PROD_DB" -c "
WITH x AS (
    SELECT
        lower(u.email) AS email,
        u.id AS directus_user_id,
        u.status,
        u.provider,
        u.external_identifier,
        r.name AS role_name,
        p.person_id,
        p.active_flag,
        p.directus_user_id AS person_directus_user_id,
        owner.person_id AS uuid_owner_person_id
    FROM public.directus_users u
    LEFT JOIN public.directus_roles r ON r.id=u.role
    LEFT JOIN ref.person p ON lower(p.email)=lower(u.email)
    LEFT JOIN ref.person owner ON owner.directus_user_id=u.id
    WHERE u.email ILIKE '%@sheboyganlights.org'
)
SELECT *
FROM x
WHERE role_name IN ('Production Crew','Manager','Administrator')
   OR email IN ('pneils@sheboyganlights.org','sreiter@sheboyganlights.org')
ORDER BY role_name NULLS LAST, email;
"

echo
echo "--- Capture current Production ---"
sudo docker exec "$PROD_CONTAINER" pg_dump -U "$DB_ACTOR" -d "$PROD_DB" -Fc > "$DUMP_FILE"
test -s "$DUMP_FILE"
sudo docker exec -i "$PROD_CONTAINER" pg_restore --list < "$DUMP_FILE" >/dev/null

echo
echo "--- Start disposable PostgreSQL ---"
sudo docker run -d --name "$TEST_CONTAINER" --network "$NETWORK" \
    -e POSTGRES_USER="$DB_ACTOR" \
    -e POSTGRES_PASSWORD="$TEST_PASSWORD" \
    -e POSTGRES_DB=postgres \
    "$IMAGE" >/dev/null

ready=0
pid1=""
for _ in $(seq 1 120); do
    [[ "$(sudo docker inspect "$TEST_CONTAINER" --format '{{.State.Running}}' 2>/dev/null || true)" == "true" ]] || break
    pid1="$(sudo docker exec "$TEST_CONTAINER" sh -c 'cat /proc/1/comm' 2>/dev/null | tr -d '\r\n' || true)"
    if [[ "$pid1" == "postgres" ]] \
       && sudo docker exec -e PGPASSWORD="$TEST_PASSWORD" "$TEST_CONTAINER" \
            pg_isready -U "$DB_ACTOR" -d postgres >/dev/null 2>&1; then
        ready=1
        break
    fi
    sleep 1
done
if [[ "$ready" != "1" ]]; then
    echo "FAIL: disposable PostgreSQL did not reach final post-init ready state"
    echo "Observed PID 1 command: ${pid1:-unknown}"
    sudo docker logs "$TEST_CONTAINER" || true
    exit 4
fi

sudo docker exec -e PGPASSWORD="$TEST_PASSWORD" "$TEST_CONTAINER" \
    createdb -U "$DB_ACTOR" -T template0 "$PROD_DB"
sudo docker exec -i -e PGPASSWORD="$TEST_PASSWORD" "$TEST_CONTAINER" \
    pg_restore -U "$DB_ACTOR" -d "$PROD_DB" --no-owner --no-acl --exit-on-error < "$DUMP_FILE"
echo "Restore completed"

# pg_dump/pg_restore with --no-owner --no-acl intentionally does not recreate
# cluster roles. Migration 005 contains explicit REVOKE checks against the
# existing Production application principals, so create disposable-only NOLOGIN
# placeholders before applying the candidate. This mirrors the established
# People disposable-acceptance pattern and does not touch Production roles.
sudo docker exec -i -e PGPASSWORD="$TEST_PASSWORD" "$TEST_CONTAINER" \
    psql -X -v ON_ERROR_STOP=1 -U "$DB_ACTOR" -d "$PROD_DB" <<'SQL'
DO $roles$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname='fieldwiring_app') THEN
        CREATE ROLE fieldwiring_app NOLOGIN;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname='people_app') THEN
        CREATE ROLE people_app NOLOGIN;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname='directus_app') THEN
        CREATE ROLE directus_app NOLOGIN;
    END IF;
END
$roles$;
SQL
echo "PASS: disposable application-role placeholders ready"

psql_test() {
    sudo docker exec -i -e PGPASSWORD="$TEST_PASSWORD" "$TEST_CONTAINER" \
        psql -X -v ON_ERROR_STOP=1 -U "$DB_ACTOR" -d "$PROD_DB" "$@"
}
psql_q() {
    sudo docker exec -i -e PGPASSWORD="$TEST_PASSWORD" "$TEST_CONTAINER" \
        psql -X -qAt -v ON_ERROR_STOP=1 -U "$DB_ACTOR" -d "$PROD_DB" "$@"
}

echo
echo "--- Apply candidate migration 005 to disposable clone ---"
psql_test < "$SQL005"
echo "PASS: migration 005 applied"

echo
echo "--- Verify helper privilege boundary ---"
psql_test <<'SQL'
DO $b$
BEGIN
    IF has_function_privilege('fieldwiring_app','ref.reconcile_directus_person_identity(text)','EXECUTE')
       OR has_function_privilege('people_app','ref.reconcile_directus_person_identity(text)','EXECUTE')
       OR has_function_privilege('directus_app','ref.reconcile_directus_person_identity(text)','EXECUTE')
       OR has_function_privilege('fieldwiring_app','ref.directus_person_identity_reconciliation_report()','EXECUTE')
       OR has_function_privilege('people_app','ref.directus_person_identity_reconciliation_report()','EXECUTE')
       OR has_function_privilege('directus_app','ref.directus_person_identity_reconciliation_report()','EXECUTE') THEN
        RAISE EXCEPTION 'Internal identity reconciliation helpers leaked to application roles';
    END IF;
END
$b$;
SQL
echo "PASS: reconciliation helpers remain internal"

echo
echo "--- Shared device/service accounts remain non-human ---"
expect_nonhuman_rejected() {
    local email="$1"
    local output
    local rc
    set +e
    output="$(psql_q -c "SELECT * FROM ref.reconcile_directus_person_identity('$email');" 2>&1)"
    rc=$?
    set -e
    if [[ "$rc" -eq 0 || "$output" != *"Shared device/service accounts are non-human identities"* ]]; then
        echo "FAIL: non-human account was not rejected: $email"
        echo "$output"
        exit 5
    fi
    echo "PASS: non-human account cannot reconcile to a Person: $email"
}
expect_nonhuman_rejected "tablet-99@sheboyganlights.org"
expect_nonhuman_rejected "printservice@sheboyganlights.org"
expect_nonhuman_rejected "production-1@sheboyganlights.org"

echo
echo "--- Select one existing fully-authorized mapped Google actor in clone ---"
ACTOR_ROW="$(psql_q -F '|' -c "
SELECT
    u.email,
    u.id,
    p.person_id,
    u.role,
    coalesce(p.updated_by_person_id,0)
FROM public.directus_users u
JOIN ref.person p ON p.directus_user_id=u.id
JOIN LATERAL ref.setup_browser_capabilities(u.email) s ON true
JOIN LATERAL ref.people_browser_capabilities(u.email) pm ON true
JOIN LATERAL ref.controller_browser_capabilities(u.email) cm ON true
WHERE u.status='active'
  AND lower(coalesce(u.provider,''))='google'
  AND lower(coalesce(u.external_identifier,''))=lower(u.email)
  AND p.active_flag
  AND s.can_move_setup_assets
  AND s.can_manage_setup
  AND pm.can_manage_people
  AND cm.can_manage_controllers
ORDER BY CASE WHEN p.person_id <> 17 THEN 0 ELSE 1 END, u.email
LIMIT 1;
")"
[[ -n "$ACTOR_ROW" ]] || { echo "FAIL: no fully-authorized mapped Google actor found in clone"; exit 5; }
IFS='|' read -r ACTOR_EMAIL ACTOR_UUID ACTOR_PERSON_ID ACTOR_ROLE_ID PRIOR_UPDATER <<< "$ACTOR_ROW"
echo "Acceptance actor: $ACTOR_EMAIL -> Person $ACTOR_PERSON_ID / $ACTOR_UUID"
if [[ "$ACTOR_PERSON_ID" == "17" ]]; then
    echo "WARN: clone has no non-msbadmin fully-authorized actor; audit bootstrap remains functionally tested but is not actor-distinguishing"
else
    echo "PASS: acceptance actor differs from msbadmin Person 17, so reconciliation audit attribution is actor-distinguishing"
fi

unlink_actor() {
    psql_q -c "UPDATE ref.person SET directus_user_id=NULL WHERE person_id=$ACTOR_PERSON_ID;" >/dev/null
    [[ "$(psql_q -c "SELECT directus_user_id IS NULL FROM ref.person WHERE person_id=$ACTOR_PERSON_ID;")" == "t" ]] || {
        echo "FAIL: unable to create clone-only unlinked fixture"
        exit 6
    }
}

assert_relinked() {
    local label="$1"
    local row
    row="$(psql_q -F '|' -c "
      SELECT directus_user_id::text, updated_by_person_id
      FROM ref.person WHERE person_id=$ACTOR_PERSON_ID;
    ")"
    [[ "$row" == "$ACTOR_UUID|$ACTOR_PERSON_ID" ]] || {
        echo "FAIL: $label did not relink/audit to same Person: $row"
        exit 7
    }
    echo "PASS: $label self-reconciled exact identity and audit actor"
}

echo
echo "--- Runtime self-reconciliation through protected actor boundaries ---"
unlink_actor
psql_q -c "SELECT * FROM ref.setup_movement_actor('$ACTOR_EMAIL');" >/dev/null
assert_relinked "Setup movement actor"

unlink_actor
psql_q -c "SELECT * FROM ref.setup_management_actor('$ACTOR_EMAIL',false);" >/dev/null
assert_relinked "Setup management actor"

TASK_ID="$(psql_q -c "SELECT setup_task_id FROM ref.setup_task ORDER BY setup_task_id LIMIT 1;")"
[[ "$TASK_ID" =~ ^[0-9]+$ ]] || { echo "FAIL: no Setup task available for execution actor test"; exit 8; }
unlink_actor
psql_q -c "SELECT * FROM ref.setup_execution_actor('$ACTOR_EMAIL',$TASK_ID);" >/dev/null
assert_relinked "Setup execution actor"

unlink_actor
psql_q -c "SELECT * FROM ref.setup_inventory_actor('$ACTOR_EMAIL',false);" >/dev/null
assert_relinked "Setup inventory actor"

unlink_actor
psql_q -c "SELECT * FROM ref.people_management_actor('$ACTOR_EMAIL');" >/dev/null
assert_relinked "People management actor"

unlink_actor
psql_q -c "SELECT * FROM ref.controller_management_actor('$ACTOR_EMAIL');" >/dev/null
assert_relinked "Controller management actor"

echo
echo "--- Idempotent already-linked path ---"
IDEMP="$(psql_q -F '|' -c "
SELECT person_id,link_reconciled
FROM ref.reconcile_directus_person_identity('$ACTOR_EMAIL');
")"
[[ "$IDEMP" == "$ACTOR_PERSON_ID|f" ]] || { echo "FAIL: already-linked reconcile was not idempotent: $IDEMP"; exit 9; }
echo "PASS: already-linked reconciliation is a no-op"

echo
echo "--- Role preservation ---"
[[ "$(psql_q -c "SELECT role::text FROM public.directus_users WHERE id='$ACTOR_UUID'::uuid;")" == "$ACTOR_ROLE_ID" ]] || {
    echo "FAIL: Directus role changed during reconciliation"
    exit 10
}
echo "PASS: Directus role unchanged"

expect_reconcile_failure() {
    local label="$1"
    local needle="$2"
    local output
    set +e
    output="$(psql_q -c "SELECT * FROM ref.reconcile_directus_person_identity('$ACTOR_EMAIL');" 2>&1)"
    rc=$?
    set -e
    if [[ "$rc" -eq 0 || "$output" != *"$needle"* ]]; then
        echo "FAIL: $label did not fail closed as expected"
        echo "$output"
        exit 11
    fi
    echo "PASS: $label fails closed"
}

echo
echo "--- Conflict / missing-state failure cases ---"

# provider mismatch
unlink_actor
psql_q -c "UPDATE public.directus_users SET provider='local' WHERE id='$ACTOR_UUID'::uuid;" >/dev/null
expect_reconcile_failure "provider mismatch" "requires a Google-backed user"
psql_q -c "UPDATE public.directus_users SET provider='google' WHERE id='$ACTOR_UUID'::uuid;" >/dev/null

# external identifier mismatch
psql_q -c "UPDATE public.directus_users SET external_identifier='mismatch@example.invalid' WHERE id='$ACTOR_UUID'::uuid;" >/dev/null
expect_reconcile_failure "external identifier mismatch" "external identifier does not match"
psql_q -c "UPDATE public.directus_users SET external_identifier=lower(email) WHERE id='$ACTOR_UUID'::uuid;" >/dev/null

# inactive Person
psql_q -c "UPDATE ref.person SET active_flag=false WHERE person_id=$ACTOR_PERSON_ID;" >/dev/null
expect_reconcile_failure "inactive Person" "matching the authenticated email is inactive"
psql_q -c "UPDATE ref.person SET active_flag=true WHERE person_id=$ACTOR_PERSON_ID;" >/dev/null

# missing Person exact email
ORIGINAL_EMAIL="$(psql_q -c "SELECT email FROM ref.person WHERE person_id=$ACTOR_PERSON_ID;")"
TEMP_EMAIL="identity-missing-$ACTOR_PERSON_ID@example.invalid"
psql_q -c "UPDATE ref.person SET email='$TEMP_EMAIL' WHERE person_id=$ACTOR_PERSON_ID;" >/dev/null
expect_reconcile_failure "missing exact-email Person" "No MSB Person exists"
psql_q -c "UPDATE ref.person SET email='$ORIGINAL_EMAIL' WHERE person_id=$ACTOR_PERSON_ID;" >/dev/null

# Person linked to a different Directus identity using a clone-only Directus user.
CONFLICT_UUID="$(cat /proc/sys/kernel/random/uuid)"
CONFLICT_EMAIL="identity-conflict-$ACTOR_PERSON_ID@sheboyganlights.org"
psql_q -c "
INSERT INTO public.directus_users(id,first_name,last_name,email,status,provider,external_identifier,role)
VALUES ('$CONFLICT_UUID'::uuid,'Identity','Conflict','$CONFLICT_EMAIL','active','google','$CONFLICT_EMAIL','$ACTOR_ROLE_ID'::uuid);
" >/dev/null
psql_q -c "UPDATE ref.person SET directus_user_id='$CONFLICT_UUID'::uuid WHERE person_id=$ACTOR_PERSON_ID;" >/dev/null
expect_reconcile_failure "Person link conflict" "already linked to a different Directus identity"
psql_q -c "UPDATE ref.person SET directus_user_id=NULL WHERE person_id=$ACTOR_PERSON_ID;" >/dev/null

# Directus UUID already owned by another Person.
OTHER_PERSON_ID="$(psql_q -c "
INSERT INTO ref.person(first_name,last_name,email,active_flag,directus_user_id)
VALUES ('Identity','Owner','identity-owner-$ACTOR_PERSON_ID@example.invalid',true,'$ACTOR_UUID'::uuid)
RETURNING person_id;
")"
[[ "$OTHER_PERSON_ID" =~ ^[0-9]+$ ]] || { echo "FAIL: unable to create UUID-owner fixture"; exit 12; }
expect_reconcile_failure "Directus UUID ownership conflict" "already linked to a different MSB Person"
psql_q -c "UPDATE ref.person SET directus_user_id=NULL WHERE person_id=$OTHER_PERSON_ID;" >/dev/null

# Restore accepted actor and prove again.
psql_q -c "SELECT * FROM ref.reconcile_directus_person_identity('$ACTOR_EMAIL');" >/dev/null
assert_relinked "final restore"

echo
echo "--- Reconciliation report classifications ---"
psql_test -P pager=off -c "
SELECT disposition,count(*)
FROM ref.directus_person_identity_reconciliation_report()
GROUP BY disposition
ORDER BY disposition;
"
[[ "$(psql_q -c "
SELECT disposition
FROM ref.directus_person_identity_reconciliation_report()
WHERE email=lower('$ACTOR_EMAIL')
  AND directus_user_id='$ACTOR_UUID'::uuid
LIMIT 1;
")" == "LINKED_OK" ]] || { echo "FAIL: report did not classify restored actor LINKED_OK"; exit 13; }
echo "PASS: reconciliation report available and classifies linked identity"

echo
echo "DIRECTUS <-> PERSON IDENTITY DISPOSABLE ACCEPTANCE: PASS"
