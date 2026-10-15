#!/usr/bin/env bash
set -Eeuo pipefail
umask 077

MANIFEST="${1:?manifest path is required}"
MODE="${2:-start}"

[[ -s "$MANIFEST" ]] || { echo "FAIL: preview manifest is missing: $MANIFEST"; exit 2; }

RUNTIME_SHA=""
SOURCE_REF=""
PREVIEW_PORT=""
PREVIEW_EMAIL=""
EXPECTED_VERSION=""
BACKBONE_APPS_SHA=""
BACKBONE_APPS_BLOB=""
ALLOW_CONCURRENT_PRODUCTION_WRITES="false"

while IFS=$'\t' read -r kind value extra; do
    [[ -z "$kind" ]] && continue
    [[ "$kind" == \#* ]] && continue
    [[ -z "${extra:-}" ]] || { echo "FAIL: malformed manifest line for $kind"; exit 3; }
    case "$kind" in
        candidate_sha) RUNTIME_SHA="$value" ;;
        target_ref) SOURCE_REF="$value" ;;
        preview_port) PREVIEW_PORT="$value" ;;
        preview_email) PREVIEW_EMAIL="$value" ;;
        expected_version) EXPECTED_VERSION="$value" ;;
        external_apps_sha) BACKBONE_APPS_SHA="$value" ;;
        external_apps_blob) BACKBONE_APPS_BLOB="$value" ;;
        allow_concurrent_production_writes) ALLOW_CONCURRENT_PRODUCTION_WRITES="$value" ;;
        preview_profile) [[ "$value" == "PeopleIdentityBootstrap" ]] || { echo "FAIL: wrong preview profile: $value"; exit 3; } ;;
        *) echo "FAIL: unsupported manifest key for PeopleIdentityBootstrap profile: $kind"; exit 3 ;;
    esac
done < "$MANIFEST"

: "${RUNTIME_SHA:?manifest candidate_sha is required}"
: "${SOURCE_REF:?manifest target_ref is required}"
: "${PREVIEW_PORT:?manifest preview_port is required}"
: "${PREVIEW_EMAIL:?manifest preview_email is required}"
: "${EXPECTED_VERSION:?manifest expected_version is required}"
: "${BACKBONE_APPS_SHA:?manifest external_apps_sha is required}"
: "${BACKBONE_APPS_BLOB:?manifest external_apps_blob is required}"
[[ "$ALLOW_CONCURRENT_PRODUCTION_WRITES" == "false" ]] || { echo "FAIL: PeopleIdentityBootstrap preview does not permit concurrent Production writes"; exit 3; }

REPO_ROOT="/opt/fieldwiring"
PRODUCTION_PYTHON="/opt/fieldwiring/.venv/bin/python"
PROD_DB_CONTAINER="msb-postgres"
PROD_DIRECTUS_CONTAINER="msb-directus"
PROD_DB="msb"
DB_ACTOR="msbadmin"
DB_IMAGE="postgis/postgis:16-3.5"
DIRECTUS_IMAGE="directus/directus:11.17.1"
NETWORK="msb-stack_default"
PEOPLE_SERVICE="msb-people.service"

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
PREVIEW_ENTRY="$SCRIPT_DIR/people_identity_bootstrap_disposable_browser_preview_entry.py"
STATE_FILE="/tmp/msb-people-identity-bootstrap-browser-preview-state-${PREVIEW_PORT}.env"
PRESERVE_FOR_RECONNECT=0
STAMP="$(date +%Y%m%dT%H%M%S)"
SHORT_STAMP="$(date +%H%M%S)"

WORKTREE="/tmp/msb-395-browser-candidate-${STAMP}"
DUMP_FILE="$SCRIPT_DIR/production.dump"
APPS_HTML="$SCRIPT_DIR/apps-index.html"
REPORT="/tmp/MSB_People_Identity_Bootstrap_Browser_Preview_${STAMP}.txt"
PREVIEW_LOG="/tmp/MSB_People_Identity_Bootstrap_Browser_Preview_Flask_${STAMP}.log"
TEST_DB_CONTAINER="msb-395-browser-db-${SHORT_STAMP}-$$"
TEST_DIRECTUS_CONTAINER="msb-395-browser-directus-${SHORT_STAMP}-$$"
TEST_DB_PASSWORD="msb395browserdb-${SHORT_STAMP}-$$"
PEOPLE_APP_PASSWORD="msb395browserpeople-${SHORT_STAMP}-$$"
DIRECTUS_ADMIN_TOKEN=""
DIRECTUS_SECRET=""
PREVIEW_PGID=""
PROD_PERSON_FP=""
PROD_DIRECTUS_FP=""
LIVE_HEAD=""

exec > >(tee "$REPORT") 2>&1

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

psql_q() {
    sudo docker exec -i -e PGPASSWORD="$TEST_DB_PASSWORD" "$TEST_DB_CONTAINER" \
        psql -X -qAt -v ON_ERROR_STOP=1 -U "$DB_ACTOR" -d "$PROD_DB" "$@"
}

cleanup() {
    status=$?
    trap - EXIT HUP INT TERM
    set +e

    if [[ "$PRESERVE_FOR_RECONNECT" -eq 1 ]]; then
        echo
        echo "PEOPLE_IDENTITY_BOOTSTRAP_BROWSER_PREVIEW_TRANSPORT_LOST"
        echo "Preview resources preserved for reconnect on port $PREVIEW_PORT."
        echo "State file: $STATE_FILE"
        exit "$status"
    fi

    echo
    echo "--- Browser preview cleanup ---"

    if [[ -n "$PREVIEW_PGID" ]]; then
        sudo -u fieldwiring -H kill -- -"$PREVIEW_PGID" >/dev/null 2>&1 || true
        sleep 1
        sudo -u fieldwiring -H kill -KILL -- -"$PREVIEW_PGID" >/dev/null 2>&1 || true
    fi

    sudo docker rm -f "$TEST_DIRECTUS_CONTAINER" >/dev/null 2>&1 || true
    sudo docker rm -f "$TEST_DB_CONTAINER" >/dev/null 2>&1 || true

    if sudo git -C "$REPO_ROOT" worktree list --porcelain 2>/dev/null \
       | grep -Fq "worktree $WORKTREE"; then
        sudo git -C "$REPO_ROOT" worktree remove --force "$WORKTREE" >/dev/null 2>&1 || true
    fi
    sudo git -C "$REPO_ROOT" worktree prune >/dev/null 2>&1 || true

    rm -f "$DUMP_FILE" "$APPS_HTML" "$STATE_FILE" >/dev/null 2>&1 || true
    rm -rf "$SCRIPT_DIR" >/dev/null 2>&1 || true

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

    if [[ -n "$LIVE_HEAD" ]]; then
        current_head="$(sudo git -C "$REPO_ROOT" rev-parse HEAD 2>/dev/null || true)"
        echo "Checkout before: $LIVE_HEAD"
        echo "Checkout after:  $current_head"
        if [[ -z "$current_head" || "$current_head" != "$LIVE_HEAD" ]]; then
            echo "FAIL: Production shared checkout moved"
            status=96
        else
            echo "PASS: Production shared checkout unchanged"
        fi
    fi

    if systemctl is-active --quiet "$PEOPLE_SERVICE" \
       && curl -fsS http://192.168.5.9:8796/api/health >/dev/null 2>&1; then
        echo "PASS: Production People service remains healthy"
    else
        echo "FAIL: Production People service is not healthy after preview"
        status=95
    fi

    if ss -ltnH "sport = :$PREVIEW_PORT" | grep -q .; then
        echo "FAIL: preview port $PREVIEW_PORT is still listening"
        ss -ltnp "sport = :$PREVIEW_PORT" || true
        status=94
    else
        echo "PASS: preview port $PREVIEW_PORT is no longer listening"
    fi

    echo "Preview log retained at:    $PREVIEW_LOG"
    echo "Preview report retained at: $REPORT"
    echo "Exit status: $status"
    exit "$status"
}
trap cleanup EXIT INT TERM

preserve_transport_loss() {
    PRESERVE_FOR_RECONNECT=1
    trap - HUP
    echo
    echo "SSH/PTY transport lost; preserving healthy People identity preview for reconnect."
    exit 75
}
trap preserve_transport_loss HUP

write_resume_state() {
    umask 077
    {
        printf 'RUNTIME_SHA=%q\n' "$RUNTIME_SHA"
        printf 'SOURCE_REF=%q\n' "$SOURCE_REF"
        printf 'PREVIEW_PORT=%q\n' "$PREVIEW_PORT"
        printf 'PREVIEW_EMAIL=%q\n' "$PREVIEW_EMAIL"
        printf 'EXPECTED_VERSION=%q\n' "$EXPECTED_VERSION"
        printf 'BACKBONE_APPS_SHA=%q\n' "$BACKBONE_APPS_SHA"
        printf 'BACKBONE_APPS_BLOB=%q\n' "$BACKBONE_APPS_BLOB"
        printf 'WORKTREE=%q\n' "$WORKTREE"
        printf 'DUMP_FILE=%q\n' "$DUMP_FILE"
        printf 'APPS_HTML=%q\n' "$APPS_HTML"
        printf 'REPORT=%q\n' "$REPORT"
        printf 'PREVIEW_LOG=%q\n' "$PREVIEW_LOG"
        printf 'TEST_DB_CONTAINER=%q\n' "$TEST_DB_CONTAINER"
        printf 'TEST_DB_PASSWORD=%q\n' "$TEST_DB_PASSWORD"
        printf 'TEST_DIRECTUS_CONTAINER=%q\n' "$TEST_DIRECTUS_CONTAINER"
        printf 'PREVIEW_PGID=%q\n' "$PREVIEW_PGID"
        printf 'PROD_PERSON_FP=%q\n' "$PROD_PERSON_FP"
        printf 'PROD_DIRECTUS_FP=%q\n' "$PROD_DIRECTUS_FP"
        printf 'LIVE_HEAD=%q\n' "$LIVE_HEAD"
        printf 'SCRIPT_DIR=%q\n' "$SCRIPT_DIR"
    } > "$STATE_FILE"
}

verify_browser_result() {
    echo
    echo "--- Verify browser-triggered disposable identity state ---"
    FINAL_ROW="$(psql_q -F '|' -c "
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
WHERE lower(u.email)=lower('$PREVIEW_EMAIL');
")"
    IFS='|' read -r FINAL_STATUS FINAL_PROVIDER FINAL_EXTERNAL FINAL_ROLE FINAL_PERSON FINAL_LINKED <<< "$FINAL_ROW"
    if [[ "$FINAL_STATUS" != "active" \
          || "$FINAL_PROVIDER" != "google" \
          || "$FINAL_EXTERNAL" != "$PREVIEW_EMAIL" \
          || "$FINAL_ROLE" != "MSB Browser" \
          || ! "$FINAL_PERSON" =~ ^[0-9]+$ \
          || "$FINAL_LINKED" != "t" ]]; then
        echo "FAIL: browser did not establish expected identity: $FINAL_ROW"
        return 25
    fi
    echo "PASS: browser created exact Google Directus identity at MSB Browser and linked existing Person"

    REPEAT_CODE="$(curl -sS -o /tmp/msb395-repeat-$STAMP.json -w '%{http_code}' \
        -X POST \
        -H 'Content-Type: application/json' \
        -H 'X-MSB-Identity-Bootstrap: 1' \
        -d '{}' \
        "http://127.0.0.1:$PREVIEW_PORT/people/api/identity/bootstrap")"
    if [[ "$REPEAT_CODE" != "200" ]]; then
        echo "FAIL: repeat bootstrap was not idempotent; HTTP $REPEAT_CODE"
        cat /tmp/msb395-repeat-$STAMP.json || true
        return 26
    fi
    if ! grep -Fq '"created":false' /tmp/msb395-repeat-$STAMP.json; then
        echo "FAIL: repeat bootstrap did not report created=false"
        cat /tmp/msb395-repeat-$STAMP.json || true
        return 27
    fi
    rm -f /tmp/msb395-repeat-$STAMP.json

    if grep -Eqi 'traceback|uncaught|fatal|syntax error' "$PREVIEW_LOG"; then
        echo "FAIL: preview log contains application error evidence"
        tail -n 100 "$PREVIEW_LOG"
        return 28
    fi
    echo "PASS: repeat bootstrap is idempotent"
}

cleanup_stale_profile_preview() {
    local listener_pids=()
    local fieldwiring_uid
    local pid
    local cmdline
    local owner_uid
    local pgid
    local PREVIEW_PGID=""
    local TEST_DB_CONTAINER=""
    local TEST_DIRECTUS_CONTAINER=""
    local WORKTREE=""
    local SCRIPT_DIR=""

    mapfile -t listener_pids < <(
        sudo ss -ltnp "sport = :$PREVIEW_PORT" 2>/dev/null \
            | grep -oE 'pid=[0-9]+' | cut -d= -f2 | sort -u || true
    )

    if (( ${#listener_pids[@]} == 0 )); then
        rm -f "$STATE_FILE" >/dev/null 2>&1 || true
        return 0
    fi

    if [[ ! -s "$STATE_FILE" ]]; then
        echo "FAIL: preview port $PREVIEW_PORT is occupied without recognized People identity preview state; refusing cleanup"
        sudo ss -ltnp "sport = :$PREVIEW_PORT" || true
        return 8
    fi

    if (( ${#listener_pids[@]} != 1 )); then
        echo "FAIL: preview port $PREVIEW_PORT has multiple listener PIDs; refusing cleanup"
        return 8
    fi

    # shellcheck disable=SC1090
    source "$STATE_FILE"
    pid="${listener_pids[0]}"
    owner_uid="$(ps -o uid= -p "$pid" 2>/dev/null | xargs || true)"
    fieldwiring_uid="$(id -u fieldwiring)"
    cmdline="$(sudo cat "/proc/$pid/cmdline" 2>/dev/null | tr '\0' ' ' || true)"

    if [[ "$PREVIEW_PGID" != "$pid" \
          || "$owner_uid" != "$fieldwiring_uid" \
          || "$cmdline" != *"people_identity_bootstrap_disposable_browser_preview_entry.py"* ]]; then
        echo "FAIL: port $PREVIEW_PORT is not owned by the recognized People identity preview; refusing to kill it"
        ps -o pid,ppid,pgid,sid,user,args -p "$pid" || true
        return 8
    fi

    pgid="$(ps -o pgid= -p "$pid" 2>/dev/null | tr -d ' ')"
    [[ "$pgid" =~ ^[0-9]+$ ]] || { echo "FAIL: could not resolve stale preview PGID"; return 8; }

    echo "Recognized stale People identity preview on port $PREVIEW_PORT; removing only that preview."
    sudo -u fieldwiring -H kill -- -"$pgid" >/dev/null 2>&1 || true
    sleep 1
    sudo -u fieldwiring -H kill -KILL -- -"$pgid" >/dev/null 2>&1 || true

    [[ "$TEST_DIRECTUS_CONTAINER" == msb-395-browser-directus-* ]] \
        && sudo docker rm -f "$TEST_DIRECTUS_CONTAINER" >/dev/null 2>&1 || true
    [[ "$TEST_DB_CONTAINER" == msb-395-browser-db-* ]] \
        && sudo docker rm -f "$TEST_DB_CONTAINER" >/dev/null 2>&1 || true
    if [[ "$WORKTREE" == /tmp/msb-395-browser-candidate-* ]] \
       && sudo git -C "$REPO_ROOT" worktree list --porcelain | grep -Fq "worktree $WORKTREE"; then
        sudo git -C "$REPO_ROOT" worktree remove --force "$WORKTREE" >/dev/null 2>&1 || true
    fi
    [[ "$SCRIPT_DIR" == /tmp/msb-setup-disposable-browser-preview-* ]] && rm -rf "$SCRIPT_DIR" >/dev/null 2>&1 || true
    rm -f "$STATE_FILE" >/dev/null 2>&1 || true

    if ss -ltnH "sport = :$PREVIEW_PORT" | grep -q .; then
        echo "FAIL: selected port remains occupied after narrow stale cleanup"
        return 8
    fi
    echo "PASS: stale People identity preview removed narrowly"
}

resume_existing_preview() {
    local requested_sha="$RUNTIME_SHA"
    local requested_ref="$SOURCE_REF"
    local requested_port="$PREVIEW_PORT"
    local requested_email="$PREVIEW_EMAIL"
    local requested_version="$EXPECTED_VERSION"
    local requested_apps_sha="$BACKBONE_APPS_SHA"
    local requested_apps_blob="$BACKBONE_APPS_BLOB"

    sudo -v
    if [[ ! -s "$STATE_FILE" ]]; then
        echo "FAIL: no resumable People identity preview state exists for port $requested_port"
        exit 76
    fi

    # shellcheck disable=SC1090
    source "$STATE_FILE"
    if [[ "$RUNTIME_SHA" != "$requested_sha" \
          || "$SOURCE_REF" != "$requested_ref" \
          || "$PREVIEW_PORT" != "$requested_port" \
          || "$PREVIEW_EMAIL" != "$requested_email" \
          || "$EXPECTED_VERSION" != "$requested_version" \
          || "$BACKBONE_APPS_SHA" != "$requested_apps_sha" \
          || "$BACKBONE_APPS_BLOB" != "$requested_apps_blob" ]]; then
        echo "FAIL: resumable People identity preview does not match requested candidate/ref/port/operator/version/Apps identity"
        exit 77
    fi

    [[ "$PREVIEW_PGID" =~ ^[0-9]+$ ]] && sudo kill -0 "$PREVIEW_PGID" >/dev/null 2>&1 \
        || { echo "FAIL: resumable preview process is not running"; exit 78; }
    sudo ss -ltnp "sport = :$PREVIEW_PORT" 2>/dev/null | grep -q "pid=$PREVIEW_PGID" \
        || { echo "FAIL: resumable preview port is not owned by expected PID"; exit 79; }
    curl -fsS --max-time 5 "http://127.0.0.1:$PREVIEW_PORT/preview/health" >/dev/null \
        || { echo "FAIL: resumable preview health check failed"; exit 80; }

    echo
    echo "REUSABLE PEOPLE IDENTITY DISPOSABLE BROWSER REVIEW RESUMED"
    echo "Browser URL through SSH tunnel: http://127.0.0.1:$PREVIEW_PORT/"
    echo "Candidate SHA: $RUNTIME_SHA"
    echo "Preview identity: $PREVIEW_EMAIL"
    echo "Expected version: $EXPECTED_VERSION"
    echo "The existing disposable PostgreSQL + Directus preview was preserved."

    if ! read -r _done; then
        PRESERVE_FOR_RECONNECT=1
        echo "Review terminal disconnected; preserving preview for another reconnect."
        exit 75
    fi

    verify_browser_result
    echo
    echo "REUSABLE PEOPLE IDENTITY DISPOSABLE BROWSER REVIEW: PASS"
    exit 0
}

if [[ "$MODE" == "resume" ]]; then
    resume_existing_preview
fi

echo "========== REUSABLE PEOPLE IDENTITY DISPOSABLE BROWSER REVIEW =========="
echo "People runtime SHA:   $RUNTIME_SHA"
echo "Backbone Apps SHA:    $BACKBONE_APPS_SHA"
echo "Backbone Apps blob:   $BACKBONE_APPS_BLOB"
echo "Preview port:         $PREVIEW_PORT"
echo "Preview identity:     $PREVIEW_EMAIL"
echo "Authority:            MSB-Server-Management — Pre_Production_Browser_Review_Runbook.md"
echo "Clone authority:      MSB-Server-Management — PostgreSQL_Disposable_Acceptance_Standard.md"
echo "Production mutation:  NONE"
echo "Report:               $REPORT"
echo

sudo -v

[[ "$(hostname)" == "msb-prod-db" ]] || { echo "FAIL: wrong host"; exit 2; }
if [[ ! "$PREVIEW_PORT" =~ ^[0-9]+$ ]] || (( PREVIEW_PORT < 1024 || PREVIEW_PORT > 65535 )); then
    echo "FAIL: preview port must be 1024-65535"
    exit 3
fi
if [[ "$PREVIEW_PORT" != "8898" ]]; then
    echo "FAIL: reusable disposable browser review uses registered stable port 8898"
    exit 4
fi
if [[ ! "$PREVIEW_EMAIL" =~ ^[A-Za-z0-9._%+-]+@sheboyganlights[.]org$ ]]; then
    echo "FAIL: People identity preview email must be a sheboyganlights.org address"
    exit 4
fi
sudo -u fieldwiring -H "$PRODUCTION_PYTHON" -m py_compile "$PREVIEW_ENTRY"
echo "PASS: reusable profile entry compiles in documented Production Python"

echo "--- Selected-port stale preview cleanup ---"
if ! cleanup_stale_profile_preview; then
    exit 5
fi
if ss -ltnH "sport = :$PREVIEW_PORT" | grep -q .; then
    echo "FAIL: preview port $PREVIEW_PORT remains occupied after selected-port cleanup"
    sudo ss -ltnp "sport = :$PREVIEW_PORT" || true
    exit 5
fi
[[ -s "$PREVIEW_ENTRY" ]] || { echo "FAIL: preview entry missing"; exit 6; }

sudo docker inspect "$PROD_DB_CONTAINER" >/dev/null
sudo docker inspect "$PROD_DIRECTUS_CONTAINER" >/dev/null
[[ "$(sudo docker inspect "$PROD_DB_CONTAINER" --format '{{.Config.Image}}')" == "$DB_IMAGE" ]] \
    || { echo "FAIL: unexpected Production PostgreSQL image"; exit 7; }
[[ "$(sudo docker inspect "$PROD_DIRECTUS_CONTAINER" --format '{{.Config.Image}}')" == "$DIRECTUS_IMAGE" ]] \
    || { echo "FAIL: unexpected Production Directus image"; exit 8; }
sudo docker network inspect "$NETWORK" >/dev/null

systemctl is-active --quiet "$PEOPLE_SERVICE" \
    || { echo "FAIL: Production People service is not active"; exit 9; }
curl -fsS http://192.168.5.9:8796/api/health >/dev/null \
    || { echo "FAIL: Production People health check failed"; exit 10; }

LIVE_HEAD="$(sudo git -C "$REPO_ROOT" rev-parse HEAD)"
[[ -z "$(sudo git -C "$REPO_ROOT" status --porcelain)" ]] \
    || { echo "FAIL: shared Production checkout is dirty"; exit 11; }

PROD_PERSON_FP="$(prod_person_fp)"
PROD_DIRECTUS_FP="$(prod_directus_fp)"
echo "Production checkout:       $LIVE_HEAD"
echo "Production Person FP:      $PROD_PERSON_FP"
echo "Production Directus FP:    $PROD_DIRECTUS_FP"

echo
echo "--- Verify exact accepted People runtime ---"
sudo git -C "$REPO_ROOT" fetch origin "$SOURCE_REF:refs/remotes/origin/$SOURCE_REF"
sudo git -C "$REPO_ROOT" cat-file -e "$RUNTIME_SHA^{commit}"

runtime_changes="$(sudo git -C "$REPO_ROOT" diff --name-only "$RUNTIME_SHA..refs/remotes/origin/$SOURCE_REF" -- People/Application People/Database || true)"
if [[ -n "$runtime_changes" ]]; then
    echo "FAIL: People runtime files changed after disposable-accepted SHA"
    echo "$runtime_changes"
    exit 12
fi

sudo git -C "$REPO_ROOT" worktree add --detach "$WORKTREE" "$RUNTIME_SHA"

CANDIDATE_VERSION="$(grep -E '^APP_VERSION = "' "$WORKTREE/People/Application/backend.py" | sed -E 's/^APP_VERSION = "([^"]+)".*/\1/' | head -1)"
if [[ "$CANDIDATE_VERSION" != "$EXPECTED_VERSION" ]]; then
    echo "FAIL: exact People candidate version '$CANDIDATE_VERSION' does not match expected '$EXPECTED_VERSION'"
    exit 13
fi
echo "PASS: exact People version pin ($CANDIDATE_VERSION)"

for required in \
    "$WORKTREE/People/Application/backend.py" \
    "$WORKTREE/People/Application/directus_identity_bootstrap.py" \
    "$WORKTREE/People/Application/test_people_manager_contract.py" \
    "$WORKTREE/People/Application/test_people_identity_bootstrap_runtime.py" \
    "$WORKTREE/People/Database/006_create_silent_identity_bootstrap_contract.sql"; do
    [[ -s "$required" ]] || { echo "FAIL: accepted runtime missing $required"; exit 13; }
done

sudo -u fieldwiring -H bash -c \
    "cd '$WORKTREE' && '$PRODUCTION_PYTHON' -m pytest -q -p no:cacheprovider \
      People/Application/test_people_manager_contract.py \
      People/Application/test_people_identity_bootstrap_runtime.py \
      People/Application/test_people_shared_tablet_identity_contract.py"
echo "PASS: exact accepted People runtime regression"

echo
echo "--- Fetch exact Backbone Apps candidate ---"
curl -fsSL \
    "https://raw.githubusercontent.com/Gregovate/MSB-Internal-Web-Backbone/$BACKBONE_APPS_SHA/my/apps/index.html" \
    -o "$APPS_HTML"
[[ -s "$APPS_HTML" ]] || { echo "FAIL: Apps candidate download empty"; exit 14; }
actual_apps_blob="$(git hash-object "$APPS_HTML")"
[[ "$actual_apps_blob" == "$BACKBONE_APPS_BLOB" ]] \
    || { echo "FAIL: Apps candidate blob mismatch: $actual_apps_blob"; exit 15; }
grep -Fq "MSB Apps v0.2 — Updated 2026-10-15" "$APPS_HTML" \
    || { echo "FAIL: Apps v0.2 visible version missing"; exit 16; }
grep -Fq "/people/api/identity/bootstrap" "$APPS_HTML" \
    || { echo "FAIL: Apps identity bootstrap call missing"; exit 17; }
echo "PASS: exact Backbone Apps candidate verified"

echo
echo "--- Capture current Production clone ---"
sudo docker exec "$PROD_DB_CONTAINER" pg_dump -U "$DB_ACTOR" -d "$PROD_DB" -Fc > "$DUMP_FILE"
test -s "$DUMP_FILE"
sudo docker exec -i "$PROD_DB_CONTAINER" pg_restore --list < "$DUMP_FILE" >/dev/null

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
[[ "$ready" == "1" ]] || { echo "FAIL: disposable PostgreSQL not ready"; exit 18; }

sudo docker exec -e PGPASSWORD="$TEST_DB_PASSWORD" "$TEST_DB_CONTAINER" \
    createdb -U "$DB_ACTOR" -T template0 "$PROD_DB"
sudo docker exec -i -e PGPASSWORD="$TEST_DB_PASSWORD" "$TEST_DB_CONTAINER" \
    pg_restore -U "$DB_ACTOR" -d "$PROD_DB" --no-owner --no-acl --exit-on-error < "$DUMP_FILE"

psql_test() {
    sudo docker exec -i -e PGPASSWORD="$TEST_DB_PASSWORD" "$TEST_DB_CONTAINER" \
        psql -X -v ON_ERROR_STOP=1 -U "$DB_ACTOR" -d "$PROD_DB" "$@"
}
psql_q() {
    sudo docker exec -i -e PGPASSWORD="$TEST_DB_PASSWORD" "$TEST_DB_CONTAINER" \
        psql -X -qAt -v ON_ERROR_STOP=1 -U "$DB_ACTOR" -d "$PROD_DB" "$@"
}

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

for migration in \
    001_create_people_manager_contract.sql \
    002_harden_people_search_phone_filter.sql \
    003_create_people_metadata_contract.sql \
    004_stop_automatic_msb_email_generation.sql \
    005_reconcile_directus_person_identity.sql \
    006_create_silent_identity_bootstrap_contract.sql; do
    psql_test < "$WORKTREE/People/Database/$migration"
done

echo
echo "--- Create clone-only preview human ---"
psql_test <<SQL
INSERT INTO ref.person(first_name,last_name,email,active_flag,directus_user_id)
VALUES ('Bootstrap','Preview','$PREVIEW_EMAIL',true,NULL);
SQL

[[ "$(psql_q -c "SELECT disposition FROM ref.people_identity_bootstrap_status('$PREVIEW_EMAIL');")" == "READY_CREATE" ]] \
    || { echo "FAIL: preview identity is not READY_CREATE"; exit 19; }

ADMIN_USER_ID="$(psql_q -c "
SELECT u.id
FROM public.directus_users u
WHERE u.status='active'
  AND EXISTS (
      SELECT 1
      FROM public.directus_access a
      JOIN public.directus_policies p ON p.id=a.policy
      WHERE (a.\"user\"=u.id OR (u.role IS NOT NULL AND a.role=u.role))
        AND p.admin_access
  )
ORDER BY u.email
LIMIT 1;
")"
[[ -n "$ADMIN_USER_ID" ]] || { echo "FAIL: clone has no Directus admin user"; exit 20; }

DIRECTUS_ADMIN_TOKEN="$(openssl rand -hex 32)"
DIRECTUS_SECRET="$(openssl rand -hex 32)"
psql_q -c "UPDATE public.directus_users SET token='$DIRECTUS_ADMIN_TOKEN' WHERE id='$ADMIN_USER_ID'::uuid;" >/dev/null

echo
echo "--- Start disposable Directus ---"
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
[[ "$directus_ready" == "1" ]] || { echo "FAIL: disposable Directus not healthy"; exit 21; }

DB_IP="$(sudo docker inspect "$TEST_DB_CONTAINER" --format '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}')"
DIRECTUS_IP="$(sudo docker inspect "$TEST_DIRECTUS_CONTAINER" --format '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}')"
[[ -n "$DB_IP" && -n "$DIRECTUS_IP" ]] || { echo "FAIL: disposable IP lookup failed"; exit 22; }

DSN="host=$DB_IP port=5432 dbname=$PROD_DB user=people_app password=$PEOPLE_APP_PASSWORD"
APP_DIR="$WORKTREE/People/Application"

echo
echo "--- Start exact integrated preview ---"
PREVIEW_PGID="$(
    sudo -u fieldwiring -H env \
        PEOPLE_DATABASE_DSN="$DSN" \
        PEOPLE_DIRECTUS_URL="http://$DIRECTUS_IP:8055" \
        PEOPLE_DIRECTUS_IDENTITY_TOKEN="$DIRECTUS_ADMIN_TOKEN" \
        MSB_PREVIEW_APP_DIR="$APP_DIR" \
        MSB_PREVIEW_APPS_HTML="$APPS_HTML" \
        MSB_PREVIEW_OPERATOR_EMAIL="$PREVIEW_EMAIL" \
        MSB_PREVIEW_HOST="127.0.0.1" \
        MSB_PREVIEW_PORT="$PREVIEW_PORT" \
        MSB_PREVIEW_LOG="$PREVIEW_LOG" \
        bash -c '
            setsid /opt/fieldwiring/.venv/bin/python "'"$PREVIEW_ENTRY"'" \
                > "$MSB_PREVIEW_LOG" 2>&1 &
            echo $!
        '
)"
[[ "$PREVIEW_PGID" =~ ^[0-9]+$ ]] || { echo "FAIL: preview process group invalid: $PREVIEW_PGID"; exit 23; }

preview_ready=0
for _ in $(seq 1 30); do
    if curl -fsS "http://127.0.0.1:$PREVIEW_PORT/preview/health" >/dev/null 2>&1; then
        preview_ready=1
        break
    fi
    sleep 1
done
if [[ "$preview_ready" != "1" ]]; then
    echo "FAIL: integrated preview did not become healthy"
    tail -n 100 "$PREVIEW_LOG" || true
    exit 24
fi

write_resume_state
echo "Reconnect state: $STATE_FILE"

echo
echo "============================================================"
echo "REUSABLE DISPOSABLE BROWSER REVIEW READY"
echo "Open:"
echo "  http://127.0.0.1:$PREVIEW_PORT/"
echo
echo "Review identity: $PREVIEW_EMAIL"
echo "People SHA:      $RUNTIME_SHA"
echo "Apps SHA:        $BACKBONE_APPS_SHA"
echo
echo "Review:"
echo "  1. Confirm the normal MSB Apps page appears and shows 'MSB Apps v0.2 — Updated 2026-10-15'."
echo "  2. Confirm NO Directus page or Google account chooser appears."
echo "  3. Wait a few seconds. Confirm NO yellow identity-initialization error banner appears."
echo "  4. Refresh the Apps page once. Confirm it remains normal with no error banner."
echo "  5. Do not click the Production application links; this review is only the bootstrap/app-launcher integration."
echo
echo "When finished, return here and press ENTER."
echo "============================================================"

read -r -p "Press ENTER to finish reusable disposable browser review... " _unused

verify_browser_result
echo
echo "REUSABLE PEOPLE IDENTITY DISPOSABLE BROWSER REVIEW: PASS"
