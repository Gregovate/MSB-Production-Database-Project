#!/usr/bin/env bash
set -euo pipefail
umask 077

PROD_CONTAINER="msb-postgres"
PROD_DB="msb"
DB_ACTOR="msbadmin"

CTRL="/opt/msb-maintenance/msb_maintenance_controller.py"
CTRL_CONFIG="/etc/msb-maintenance/config.json"
CTRL_STATE="/var/lib/msb-maintenance/state.json"

TARGET_PERSON_ID=10
TARGET_EMAIL="mhayon@sheboyganlights.org"
TARGET_DIRECTUS_UUID="c4ecc239-b648-454c-a004-b80de6169e4f"
TARGET_ROLE_UUID="edd36182-2029-4bfa-b6ca-1fa9a9b771a9"
AUDIT_PERSON_ID=17

STAMP="$(date +%Y%m%dT%H%M%S)"
BACKUP="/home/msbadmin/backups/postgres/msb-pre-mark-hayon-identity-$STAMP.dump"
REPORT="/home/msbadmin/people-identity-repair-$STAMP.txt"

exec > >(tee "$REPORT") 2>&1

echo "========== MARK HAYON DIRECTUS/PERSON IDENTITY REPAIR =========="
echo "Authority: MSB-Server-Management Production Database Change Deployment Runbook"
echo "People/Identity authority: existing Adam Biebel exact-email reconciliation pattern"
echo "Target Person: $TARGET_PERSON_ID / $TARGET_EMAIL"
echo "Target Directus UUID: $TARGET_DIRECTUS_UUID"
echo "Required role: Production Crew / $TARGET_ROLE_UUID"
echo "Audit actor Person: $AUDIT_PERSON_ID"
echo "Rollback snapshot: $BACKUP"
echo "Report: $REPORT"
echo

[[ "$(id -u)" -eq 0 ]] || { echo "FAIL: run this repair with sudo/root"; exit 2; }
[[ -x "$CTRL" ]] || { echo "FAIL: maintenance controller not installed"; exit 2; }
[[ -s "$CTRL_CONFIG" ]] || { echo "FAIL: maintenance config missing"; exit 2; }

ctrl() {
    python3 "$CTRL" --config "$CTRL_CONFIG" --state-file "$CTRL_STATE" "$@"
}

psql_prod() {
    docker exec -i "$PROD_CONTAINER"         psql -X -v ON_ERROR_STOP=1 -U "$DB_ACTOR" -d "$PROD_DB" "$@"
}

psql_quiet() {
    docker exec -i "$PROD_CONTAINER"         psql -X -qAt -v ON_ERROR_STOP=1 -U "$DB_ACTOR" -d "$PROD_DB" "$@"
}

echo "--- Current maintenance state ---"
STATUS="$(ctrl status)"
echo "$STATUS"
grep -Fq '"state": "ONLINE"' <<< "$STATUS" || {
    echo "FAIL: Production is not ONLINE before repair; reconcile existing maintenance state first."
    exit 3
}

echo
echo "--- Read-only exact identity preflight ---"
psql_prod <<'SQL'
\set ON_ERROR_STOP on
DO $preflight$
DECLARE
    v_count integer;
BEGIN
    SELECT count(*) INTO v_count
    FROM ref.person
    WHERE person_id = 10
      AND lower(email) = 'mhayon@sheboyganlights.org'
      AND active_flag IS TRUE
      AND directus_user_id IS NULL;
    IF v_count <> 1 THEN
        RAISE EXCEPTION 'Mark Person preflight failed: expected one active exact-email Person 10 with NULL Directus link';
    END IF;

    SELECT count(*) INTO v_count
    FROM public.directus_users
    WHERE id = 'c4ecc239-b648-454c-a004-b80de6169e4f'::uuid
      AND lower(email) = 'mhayon@sheboyganlights.org'
      AND status = 'active'
      AND provider = 'google'
      AND lower(external_identifier) = 'mhayon@sheboyganlights.org'
      AND role = 'edd36182-2029-4bfa-b6ca-1fa9a9b771a9'::uuid;
    IF v_count <> 1 THEN
        RAISE EXCEPTION 'Mark Directus preflight failed: exact active Google-backed Production Crew identity not found';
    END IF;

    SELECT count(*) INTO v_count
    FROM ref.person
    WHERE directus_user_id = 'c4ecc239-b648-454c-a004-b80de6169e4f'::uuid;
    IF v_count <> 0 THEN
        RAISE EXCEPTION 'Mark Directus UUID is already linked to a Person; refusing repair';
    END IF;

    SELECT count(*) INTO v_count
    FROM ref.person
    WHERE person_id = 17
      AND active_flag IS TRUE
      AND pg_login_name = current_user;
    IF v_count <> 1 THEN
        RAISE EXCEPTION 'Audit actor preflight failed: current PostgreSQL operator must resolve to active Person 17';
    END IF;

    IF to_regprocedure('ref.setup_movement_actor(text)') IS NULL THEN
        RAISE EXCEPTION 'Setup movement actor function is missing';
    END IF;
END
$preflight$;
SQL
echo "IDENTITY PREFLIGHT: PASS"

OTHER_PEOPLE_BEFORE="$(psql_quiet -c "
    SELECT md5(coalesce(string_agg(row_to_json(p)::text, '' ORDER BY p.person_id), ''))
    FROM ref.person p
    WHERE p.person_id <> $TARGET_PERSON_ID;
")"
echo "Other-People fingerprint before: $OTHER_PEOPLE_BEFORE"

echo
echo "--- Enter Production database maintenance ---"
ctrl on
MAINT_STATUS="$(ctrl status)"
echo "$MAINT_STATUS"
grep -Fq '"state": "MAINTENANCE"' <<< "$MAINT_STATUS" || {
    echo "FAIL: controller did not reach MAINTENANCE"
    exit 4
}
grep -Fq '"freeze_proof"' <<< "$MAINT_STATUS" || {
    echo "FAIL: maintenance state did not report freeze proof"
    exit 4
}
echo "MAINTENANCE / FREEZE: PASS"

echo
echo "--- Create controller-validated rollback snapshot ---"
ctrl snapshot "$BACKUP"
[[ -s "$BACKUP" ]] || { echo "FAIL: rollback snapshot missing or empty"; exit 5; }
sha256sum "$BACKUP"
echo "ROLLBACK SNAPSHOT: PASS"

echo
echo "--- Apply one-row fail-closed identity link ---"
psql_prod <<'SQL'
\set ON_ERROR_STOP on
BEGIN;

DO $repair$
DECLARE
    v_count integer;
    v_rows integer;
BEGIN
    SELECT count(*) INTO v_count
    FROM ref.person
    WHERE person_id = 10
      AND lower(email) = 'mhayon@sheboyganlights.org'
      AND active_flag IS TRUE
      AND directus_user_id IS NULL;
    IF v_count <> 1 THEN
        RAISE EXCEPTION 'Repair guard failed: target Person state changed';
    END IF;

    SELECT count(*) INTO v_count
    FROM public.directus_users
    WHERE id = 'c4ecc239-b648-454c-a004-b80de6169e4f'::uuid
      AND lower(email) = 'mhayon@sheboyganlights.org'
      AND status = 'active'
      AND provider = 'google'
      AND lower(external_identifier) = 'mhayon@sheboyganlights.org'
      AND role = 'edd36182-2029-4bfa-b6ca-1fa9a9b771a9'::uuid;
    IF v_count <> 1 THEN
        RAISE EXCEPTION 'Repair guard failed: Directus identity/role state changed';
    END IF;

    IF EXISTS (
        SELECT 1
        FROM ref.person
        WHERE directus_user_id = 'c4ecc239-b648-454c-a004-b80de6169e4f'::uuid
    ) THEN
        RAISE EXCEPTION 'Repair guard failed: Directus UUID acquired another Person link';
    END IF;

    IF NOT EXISTS (
        SELECT 1
        FROM ref.person
        WHERE person_id = 17
          AND active_flag IS TRUE
          AND pg_login_name = current_user
    ) THEN
        RAISE EXCEPTION 'Repair guard failed: PostgreSQL audit actor is not Person 17';
    END IF;

    UPDATE ref.person
       SET directus_user_id = 'c4ecc239-b648-454c-a004-b80de6169e4f'::uuid
     WHERE person_id = 10
       AND lower(email) = 'mhayon@sheboyganlights.org'
       AND active_flag IS TRUE
       AND directus_user_id IS NULL;

    GET DIAGNOSTICS v_rows = ROW_COUNT;
    IF v_rows <> 1 THEN
        RAISE EXCEPTION 'Repair changed % rows; expected exactly 1', v_rows;
    END IF;

    IF NOT EXISTS (
        SELECT 1
        FROM ref.person
        WHERE person_id = 10
          AND directus_user_id = 'c4ecc239-b648-454c-a004-b80de6169e4f'::uuid
          AND updated_by_person_id = 17
    ) THEN
        RAISE EXCEPTION 'Repair validation failed: link/audit attribution is not exact';
    END IF;

    IF NOT EXISTS (
        SELECT 1
        FROM ref.setup_movement_actor('mhayon@sheboyganlights.org') a
        WHERE a.person_id = 10
          AND a.directus_user_id = 'c4ecc239-b648-454c-a004-b80de6169e4f'::uuid
    ) THEN
        RAISE EXCEPTION 'Repair validation failed: Setup movement actor still does not resolve Mark';
    END IF;
END
$repair$;

COMMIT;
SQL
echo "MARK IDENTITY LINK: COMMITTED"

OTHER_PEOPLE_AFTER="$(psql_quiet -c "
    SELECT md5(coalesce(string_agg(row_to_json(p)::text, '' ORDER BY p.person_id), ''))
    FROM ref.person p
    WHERE p.person_id <> $TARGET_PERSON_ID;
")"
echo "Other-People fingerprint after:  $OTHER_PEOPLE_AFTER"
[[ "$OTHER_PEOPLE_AFTER" == "$OTHER_PEOPLE_BEFORE" ]] || {
    echo "FAIL: a Person other than Mark changed during the frozen repair window"
    echo "Production remains in MAINTENANCE. Use rollback snapshot: $BACKUP"
    exit 6
}
echo "OTHER PEOPLE UNCHANGED: PASS"

echo
echo "--- Final Mark / movement-actor validation ---"
psql_prod <<'SQL'
SELECT
    p.person_id,
    p.first_name,
    p.last_name,
    p.email,
    p.active_flag,
    p.directus_user_id,
    p.updated_by,
    p.updated_by_person_id,
    u.status AS directus_status,
    u.provider,
    u.external_identifier,
    u.role AS directus_role_id
FROM ref.person p
JOIN public.directus_users u ON u.id = p.directus_user_id
WHERE p.person_id = 10;

SELECT *
FROM ref.setup_movement_actor('mhayon@sheboyganlights.org');
SQL
echo "FINAL IDENTITY / MOVEMENT ACTOR VALIDATION: PASS"

echo
echo "--- Return Production to service ---"
ctrl off
FINAL_STATUS="$(ctrl status)"
echo "$FINAL_STATUS"
grep -Fq '"state": "ONLINE"' <<< "$FINAL_STATUS" || {
    echo "FAIL: repair committed but maintenance controller did not return ONLINE"
    exit 7
}

echo
echo "PEOPLE MARK HAYON IDENTITY REPAIR: PASS"
echo "Mark may now retry Pick Mode with his own account."
echo "Rollback snapshot retained: $BACKUP"
echo "Report retained: $REPORT"
