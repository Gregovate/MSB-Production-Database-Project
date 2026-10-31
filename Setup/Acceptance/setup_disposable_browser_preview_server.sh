#!/usr/bin/env bash
set -euo pipefail

PROD_CONTAINER="msb-postgres"
PROD_DB="msb"
DB_ACTOR="msbadmin"
IMAGE="postgis/postgis:16-3.5"
NETWORK="msb-stack_default"
REPO_ROOT="/opt/fieldwiring"
SETUP_LIVE_ROOT="/opt/msb-setup"
PYTHON="/opt/fieldwiring/.venv/bin/python"

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
MANIFEST="${1:?manifest path is required}"
MODE="${2:-start}"

[[ -s "$MANIFEST" ]] || { echo "FAIL: preview manifest is missing: $MANIFEST"; exit 2; }

GIS_GPX_SHA=""
GIS_FLW_SHA=""
GIS_ACTOR=""
GIS_CACHE_LOCKED=0
GIS_CACHE_LOCK_FD=""
GIS_CACHE_ACCEPTED=0
TARGET_SHA=""
TARGET_REF=""
PREVIEW_PORT=""
PREVIEW_EMAIL=""
EXPECTED_VERSION=""
ALLOW_CONCURRENT_PRODUCTION_WRITES="false"
MIGRATIONS=()
VALIDATIONS=()

while IFS=$'\t' read -r kind value extra; do
    [[ -z "$kind" ]] && continue
    [[ "$kind" == \#* ]] && continue
    [[ -z "${extra:-}" ]] || { echo "FAIL: malformed manifest line for $kind"; exit 3; }
    case "$kind" in
        candidate_sha) TARGET_SHA="$value" ;;
        target_ref) TARGET_REF="$value" ;;
        preview_port) PREVIEW_PORT="$value" ;;
        preview_email) PREVIEW_EMAIL="$value" ;;
        expected_version) EXPECTED_VERSION="$value" ;;
        allow_concurrent_production_writes) ALLOW_CONCURRENT_PRODUCTION_WRITES="$value" ;;
        gis_gpx_sha) GIS_GPX_SHA="$value" ;;
        gis_flw_sha) GIS_FLW_SHA="$value" ;;
        gis_actor) GIS_ACTOR="$value" ;;
        migration) MIGRATIONS+=("$value") ;;
        validation) VALIDATIONS+=("$value") ;;
        *) echo "FAIL: unsupported manifest key: $kind"; exit 3 ;;
    esac
done < "$MANIFEST"

: "${TARGET_SHA:?manifest candidate_sha is required}"
: "${TARGET_REF:?manifest target_ref is required}"
: "${PREVIEW_PORT:?manifest preview_port is required}"
: "${PREVIEW_EMAIL:?manifest preview_email is required}"
STATE_FILE="/tmp/msb-setup-browser-preview-state-${PREVIEW_PORT}.env"
PRESERVE_FOR_RECONNECT=0

if [[ "$MODE" != "start" && "$MODE" != "resume" ]]; then
    echo "FAIL: preview mode must be start or resume"
    exit 3
fi

if [[ "$ALLOW_CONCURRENT_PRODUCTION_WRITES" != "true" && "$ALLOW_CONCURRENT_PRODUCTION_WRITES" != "false" ]]; then
    echo "FAIL: allow_concurrent_production_writes must be true or false"
    exit 3
fi

for rel in "${MIGRATIONS[@]}" "${VALIDATIONS[@]}"; do
    [[ -z "$rel" ]] && continue
    if [[ "$rel" = /* || "$rel" == *".."* || "$rel" == *$'\t'* || "$rel" == *$'\n'* ]]; then
        echo "FAIL: unsafe candidate-relative path in manifest: $rel"
        exit 4
    fi
done

STAMP="$(date +%Y%m%dT%H%M%S)"
TEST_CONTAINER="msb-setup-browser-preview-${$}"
TEST_DB="msb_setup_browser_preview"
TEST_PASSWORD="setup-preview-${$}-$(date +%s)"
APP_PASSWORD="setupapp-${$}-$(date +%s)"
DUMP_FILE="/tmp/msb-setup-browser-preview-${STAMP}-${$}.dump"
GRANTS_FILE="/tmp/msb-setup-browser-preview-grants-${STAMP}-${$}.sql"
CANDIDATE_WORKTREE="/tmp/msb-setup-browser-preview-candidate-${STAMP}"
REPORT_DIR="$HOME/setup-acceptance-reports"
REPORT="$REPORT_DIR/Setup_Disposable_Browser_Preview_${STAMP}.txt"
PREVIEW_LOG="/tmp/Setup_Disposable_Browser_Preview_Flask_${STAMP}.log"
PREVIEW_ENTRY=""
PREVIEW_PGID=""
PROD_BEFORE=""
SETUP_HEAD_BEFORE=""
PREVIEW_OWNED_PORT=0
PYCACHE="/tmp/msb-setup-browser-preview-pycache-${STAMP}"

mkdir -p "$REPORT_DIR"
exec > >(tee "$REPORT") 2>&1

echo "========== SETUP REUSABLE DISPOSABLE BROWSER PREVIEW =========="
echo "Authority: Gregovate/MSB-Server-Management — docs/server/Pre_Production_Browser_Review_Runbook.md"
echo "Disposable standard: docs/server/PostgreSQL_Disposable_Acceptance_Standard.md"
echo "Candidate SHA: $TARGET_SHA"
echo "Target ref:    $TARGET_REF"
echo "Preview port:  $PREVIEW_PORT"
echo "Preview user:  $PREVIEW_EMAIL"
echo "Expected ver:  ${EXPECTED_VERSION:-not pinned}"
echo "Concurrent Production writes allowed: $ALLOW_CONCURRENT_PRODUCTION_WRITES"
echo "Migrations:    ${#MIGRATIONS[@]}"
echo "Validations:   ${#VALIDATIONS[@]}"
echo "Report:        $REPORT"
echo "Production DB: pg_dump + SELECT only"
echo "Preview writes: disposable current-Production clone only"
echo

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

cleanup_stale_preview_on_selected_port() {
    local listener_pids=()
    local fieldwiring_uid
    local pid
    local cmdline
    local owner_uid
    local pgid
    local app_dir
    local stale_worktree=""
    local dsn
    local db_host
    local stale_container=""
    local bundle
    local manifest_port

    mapfile -t listener_pids < <(
        sudo ss -ltnp "sport = :$PREVIEW_PORT" 2>/dev/null             | grep -oE 'pid=[0-9]+'             | cut -d= -f2             | sort -u             || true
    )

    if (( ${#listener_pids[@]} == 0 )); then
        rm -f "$STATE_FILE" >/dev/null 2>&1 || true
        return 0
    fi

    if (( ${#listener_pids[@]} != 1 )); then
        echo "FAIL: preview port $PREVIEW_PORT has multiple listener PIDs; refusing stale cleanup"
        sudo ss -ltnp "sport = :$PREVIEW_PORT" || true
        return 8
    fi

    pid="${listener_pids[0]}"
    cmdline="$(sudo cat "/proc/$pid/cmdline" 2>/dev/null | tr '\0' ' ' || true)"
    owner_uid="$(ps -o uid= -p "$pid" 2>/dev/null | xargs || true)"
    fieldwiring_uid="$(id -u fieldwiring)"

    if [[ "$owner_uid" != "$fieldwiring_uid"        || "$cmdline" != *"/tmp/msb-setup-browser-preview-candidate-"*"/Setup/Acceptance/setup_session_browser_preview_entry.py"* ]]; then
        echo "FAIL: preview port $PREVIEW_PORT is owned by an unknown/non-reusable-Setup-preview process; refusing to kill it"
        ps -o pid,ppid,pgid,sid,user,args -p "$pid" || true
        sudo ss -ltnp "sport = :$PREVIEW_PORT" || true
        return 8
    fi

    app_dir="$(sudo cat "/proc/$pid/environ" 2>/dev/null         | tr '\0' '\n'         | sed -n 's/^MSB_SETUP_PREVIEW_APP_DIR=//p'         | head -1)"
    if [[ "$app_dir" == /tmp/msb-setup-browser-preview-candidate-*/Setup/Application ]]; then
        stale_worktree="${app_dir%/Setup/Application}"
    else
        echo "FAIL: recognized preview PID $pid has unexpected application directory; refusing stale cleanup"
        ps -o pid,ppid,pgid,sid,user,args -p "$pid" || true
        return 8
    fi

    dsn="$(sudo cat "/proc/$pid/environ" 2>/dev/null         | tr '\0' '\n'         | sed -n 's/^SETUP_DATABASE_DSN=//p'         | head -1)"
    db_host="$(sed -n 's/.*\(^\|[[:space:]]\)host=\([^[:space:]]*\).*/\2/p' <<<"$dsn")"
    if [[ -n "$db_host" ]]; then
        while IFS= read -r name; do
            [[ -n "$name" ]] || continue
            ip="$(sudo docker inspect "$name" --format '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' 2>/dev/null || true)"
            if [[ "$ip" == "$db_host" ]]; then
                stale_container="$name"
                break
            fi
        done < <(sudo docker ps -a --format '{{.Names}}' | grep '^msb-setup-browser-preview-' || true)
    fi

    if [[ -z "$stale_container" ]]; then
        echo "FAIL: recognized preview PID $pid does not resolve to its expected disposable Setup container; refusing partial cleanup"
        return 8
    fi

    pgid="$(ps -o pgid= -p "$pid" 2>/dev/null | tr -d ' ')"
    if [[ ! "$pgid" =~ ^[0-9]+$ ]]; then
        echo "FAIL: could not determine process group for stale Setup preview PID $pid"
        return 8
    fi

    echo "Recognized stale reusable Setup preview on port $PREVIEW_PORT"
    echo "  PID/PGID: $pid/$pgid"
    echo "  worktree: $stale_worktree"
    echo "  container: $stale_container"
    echo "Stopping only this stale preview instance..."

    sudo -u fieldwiring -H kill -- -"$pgid" >/dev/null 2>&1 || true
    sleep 1
    if sudo kill -0 "$pid" >/dev/null 2>&1; then
        sudo -u fieldwiring -H kill -KILL -- -"$pgid" >/dev/null 2>&1 || true
        sleep 1
    fi

    if ss -ltnH "sport = :$PREVIEW_PORT" | grep -q .; then
        echo "FAIL: stale reusable Setup preview still owns port $PREVIEW_PORT after narrow process-group cleanup"
        sudo ss -ltnp "sport = :$PREVIEW_PORT" || true
        return 8
    fi

    echo "Removing stale reusable Setup disposable container: $stale_container"
    sudo docker rm -f "$stale_container" >/dev/null 2>&1 || true

    if sudo git -C "$REPO_ROOT" worktree list --porcelain 2>/dev/null | grep -Fq "worktree $stale_worktree"; then
        echo "Removing stale reusable Setup worktree: $stale_worktree"
        sudo git -C "$REPO_ROOT" worktree remove --force "$stale_worktree" >/dev/null 2>&1 || true
    fi

    rm -f "$STATE_FILE" >/dev/null 2>&1 || true

    # Remove only uploaded reusable-preview bundles whose manifest names this exact
    # selected port. Reports and Flask logs are retained as acceptance evidence.
    for bundle in /tmp/msb-setup-disposable-browser-preview-*; do
        [[ -d "$bundle" ]] || continue
        [[ -s "$bundle/preview_manifest.tsv" ]] || continue
        manifest_port="$(awk -F '\t' '$1 == "preview_port" { print $2; exit }' "$bundle/preview_manifest.tsv")"
        if [[ "$manifest_port" == "$PREVIEW_PORT" ]]; then
            echo "Removing stale reusable Setup preview bundle: $bundle"
            rm -rf -- "$bundle"
        fi
    done

    echo "PASS: stale reusable Setup preview on port $PREVIEW_PORT removed narrowly"
    return 0
}

cleanup() {
    status=$?
    trap - EXIT HUP INT TERM
    set +e

    if [[ "$PRESERVE_FOR_RECONNECT" -eq 1 ]]; then
        echo
        echo "SETUP_BROWSER_PREVIEW_TRANSPORT_LOST"
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
    sudo docker rm -f "$TEST_CONTAINER" >/dev/null 2>&1 || true
    if sudo git -C "$REPO_ROOT" worktree list --porcelain 2>/dev/null | grep -Fq "worktree $CANDIDATE_WORKTREE"; then
        sudo git -C "$REPO_ROOT" worktree remove --force "$CANDIDATE_WORKTREE" >/dev/null 2>&1 || true
    fi
    rm -f "$DUMP_FILE" "$GRANTS_FILE" >/dev/null 2>&1 || true
    sudo rm -rf "$PYCACHE" >/dev/null 2>&1 || true
    rm -f "$STATE_FILE" >/dev/null 2>&1 || true
    rm -rf "$SCRIPT_DIR" >/dev/null 2>&1 || true

    # The original GPX/FLW always remain on the operator's Shared Drive.
    # Content-addressed server copies are staging only, not retained evidence.
    # Retire superseded versions ONLY after a clean finished browser review,
    # after its upload bundle is gone, while holding the exclusive cache lock.
    if [[ "$status" -eq 0 && "$GIS_CACHE_ACCEPTED" -eq 1 ]]; then
        prune_gis_source_cache || echo "WARN: GIS source cache retention was not completed; no Production or source changes"
    fi

    echo "--- Production after-check ---"
    if [[ -n "$PROD_BEFORE" ]]; then
        PROD_AFTER="$(prod_fingerprint 2>/dev/null)"
        echo "Production Setup fingerprint before: $PROD_BEFORE"
        echo "Production Setup fingerprint after:  $PROD_AFTER"
        if [[ -z "$PROD_AFTER" ]]; then
            echo "FAIL: Production Setup fingerprint after-check was empty"
            status=97
        elif [[ "$PROD_AFTER" != "$PROD_BEFORE" ]]; then
            if [[ "$ALLOW_CONCURRENT_PRODUCTION_WRITES" == "true" ]]; then
                echo "INFO: Production Setup fingerprint changed during browser preview"
                echo "PASS WITH CONCURRENT ACTIVITY: fingerprint drift is allowed for this explicitly concurrent review"
                echo "NOTE: the preview clone remained the point-in-time database captured at preview start"
            else
                echo "FAIL: Production Setup fingerprint changed during browser preview"
                status=97
            fi
        else
            echo "PASS: Production Setup fingerprint unchanged"
        fi
    else
        echo "SKIP: Production fingerprint was not captured before failure"
    fi

    if [[ -n "$SETUP_HEAD_BEFORE" ]]; then
        SETUP_HEAD_AFTER="$(sudo git -C "$SETUP_LIVE_ROOT" rev-parse HEAD 2>/dev/null)"
        echo "Live Setup SHA before: $SETUP_HEAD_BEFORE"
        echo "Live Setup SHA after:  $SETUP_HEAD_AFTER"
        if [[ -z "$SETUP_HEAD_AFTER" || "$SETUP_HEAD_AFTER" != "$SETUP_HEAD_BEFORE" ]]; then
            echo "FAIL: live /opt/msb-setup checkout changed during browser preview"
            status=98
        else
            echo "PASS: live Setup checkout unchanged"
        fi
    else
        echo "SKIP: live Setup SHA was not captured before failure"
    fi

    if [[ "$PREVIEW_OWNED_PORT" -eq 1 ]] && ss -ltnH "sport = :$PREVIEW_PORT" | grep -q .; then
        echo "FAIL: preview-owned TCP port $PREVIEW_PORT is still listening after cleanup"
        status=99
    fi

    echo "Preview Flask log retained at: $PREVIEW_LOG"
    echo "Preview report retained at:    $REPORT"
    echo "Exit status: $status"
    exit "$status"
}
trap cleanup EXIT INT TERM

preserve_transport_loss() {
    PRESERVE_FOR_RECONNECT=1
    trap - HUP
    echo
    echo "SSH/PTY transport lost; preserving healthy preview for reconnect."
    exit 75
}
trap preserve_transport_loss HUP

write_resume_state() {
    umask 077
    {
        printf 'TARGET_SHA=%q\n' "$TARGET_SHA"
        printf 'TARGET_REF=%q\n' "$TARGET_REF"
        printf 'PREVIEW_PORT=%q\n' "$PREVIEW_PORT"
        printf 'PREVIEW_EMAIL=%q\n' "$PREVIEW_EMAIL"
        printf 'EXPECTED_VERSION=%q\n' "$EXPECTED_VERSION"
        printf 'ALLOW_CONCURRENT_PRODUCTION_WRITES=%q\n' "$ALLOW_CONCURRENT_PRODUCTION_WRITES"
        printf 'TEST_CONTAINER=%q\n' "$TEST_CONTAINER"
        printf 'TEST_DB=%q\n' "$TEST_DB"
        printf 'DUMP_FILE=%q\n' "$DUMP_FILE"
        printf 'GRANTS_FILE=%q\n' "$GRANTS_FILE"
        printf 'CANDIDATE_WORKTREE=%q\n' "$CANDIDATE_WORKTREE"
        printf 'REPORT=%q\n' "$REPORT"
        printf 'PREVIEW_LOG=%q\n' "$PREVIEW_LOG"
        printf 'PREVIEW_ENTRY=%q\n' "$PREVIEW_ENTRY"
        printf 'PREVIEW_PGID=%q\n' "$PREVIEW_PGID"
        printf 'PROD_BEFORE=%q\n' "$PROD_BEFORE"
        printf 'SETUP_HEAD_BEFORE=%q\n' "$SETUP_HEAD_BEFORE"
        printf 'PREVIEW_OWNED_PORT=%q\n' "$PREVIEW_OWNED_PORT"
        printf 'PYCACHE=%q\n' "$PYCACHE"
        printf 'SCRIPT_DIR=%q\n' "$SCRIPT_DIR"
    } > "$STATE_FILE"
}

resume_existing_preview() {
    local requested_sha="$TARGET_SHA"
    local requested_ref="$TARGET_REF"
    local requested_port="$PREVIEW_PORT"
    local requested_email="$PREVIEW_EMAIL"
    local requested_version="$EXPECTED_VERSION"

    sudo -v
    if [[ ! -s "$STATE_FILE" ]]; then
        echo "FAIL: no resumable Setup browser preview state exists for port $requested_port"
        exit 76
    fi

    # shellcheck disable=SC1090
    source "$STATE_FILE"

    if [[ "$TARGET_SHA" != "$requested_sha"        || "$TARGET_REF" != "$requested_ref"        || "$PREVIEW_PORT" != "$requested_port"        || "$PREVIEW_EMAIL" != "$requested_email"        || "$EXPECTED_VERSION" != "$requested_version" ]]; then
        echo "FAIL: resumable preview state does not match requested candidate/ref/port/operator/version"
        exit 77
    fi

    if [[ ! "$PREVIEW_PGID" =~ ^[0-9]+$ ]] || ! sudo kill -0 "$PREVIEW_PGID" >/dev/null 2>&1; then
        echo "FAIL: resumable preview process is no longer running"
        exit 78
    fi

    if ! sudo ss -ltnp "sport = :$PREVIEW_PORT" 2>/dev/null | grep -q "pid=$PREVIEW_PGID"; then
        echo "FAIL: preview port $PREVIEW_PORT is not owned by expected PID $PREVIEW_PGID"
        exit 79
    fi

    HEALTH="$(curl -fsS --max-time 5 "http://127.0.0.1:$PREVIEW_PORT/api/health")" || {
        echo "FAIL: resumable preview health check failed"
        exit 80
    }
    HEALTH_VERSION="$(printf '%s' "$HEALTH" | sudo -u fieldwiring -H "$PYTHON" -c 'import json,sys; print(json.load(sys.stdin).get("version", ""))')"
    if [[ "$HEALTH_VERSION" != "$EXPECTED_VERSION" ]]; then
        echo "FAIL: resumable preview version '$HEALTH_VERSION' does not match expected '$EXPECTED_VERSION'"
        exit 81
    fi

    echo
    echo "SETUP REUSABLE DISPOSABLE BROWSER REVIEW RESUMED"
    echo "Browser URL through SSH tunnel: http://127.0.0.1:$PREVIEW_PORT/"
    echo "Candidate SHA: $TARGET_SHA"
    echo "Preview identity: $PREVIEW_EMAIL"
    echo "Expected version: $EXPECTED_VERSION"
    echo "The existing disposable clone and all browser-review writes were preserved."
    echo "When review is complete, press ENTER. If the tunnel drops again, the launcher will reconnect again."

    if ! read -r _done; then
        PRESERVE_FOR_RECONNECT=1
        echo "Review terminal disconnected; preserving preview for another reconnect."
        exit 75
    fi

    echo
    echo "Browser review session ended by operator. Cleanup will now run."
    echo "SETUP_REUSABLE_DISPOSABLE_BROWSER_PREVIEW_CLEAN_EXIT"
    exit 0
}

if [[ "$MODE" == "resume" ]]; then
    resume_existing_preview
fi

sudo -v

if [[ ! "$PREVIEW_PORT" =~ ^[0-9]+$ ]] || (( PREVIEW_PORT < 1024 || PREVIEW_PORT > 65535 )); then
    echo "FAIL: preview port must be an integer from 1024 through 65535"
    exit 5
fi
if [[ "$PREVIEW_PORT" == "8055" || "$PREVIEW_PORT" == "8790" || "$PREVIEW_PORT" == "8792" || "$PREVIEW_PORT" == "8794" || "$PREVIEW_PORT" == "8796" ]]; then
    echo "FAIL: preview port conflicts with a governed Production listener"
    exit 6
fi
if [[ ! "$PREVIEW_EMAIL" =~ ^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+$ ]]; then
    echo "FAIL: preview email is invalid"
    exit 7
fi

echo "--- Selected-port stale preview cleanup ---"
if ! cleanup_stale_preview_on_selected_port; then
    exit 8
fi
if ss -ltnH "sport = :$PREVIEW_PORT" | grep -q .; then
    echo "FAIL: preview port $PREVIEW_PORT remains occupied after selected-port cleanup"
    sudo ss -ltnp "sport = :$PREVIEW_PORT" || true
    exit 8
fi
if ! sudo docker inspect "$PROD_CONTAINER" >/dev/null 2>&1; then
    echo "FAIL: Production PostgreSQL container was not found"
    exit 9
fi
if [[ "$(sudo docker inspect "$PROD_CONTAINER" --format '{{.Config.Image}}')" != "$IMAGE" ]]; then
    echo "FAIL: Production PostgreSQL image is not $IMAGE"
    exit 10
fi
if ! sudo docker network inspect "$NETWORK" >/dev/null 2>&1; then
    echo "FAIL: Docker network $NETWORK was not found"
    exit 11
fi
if ! systemctl is-active --quiet msb-setup.service; then
    echo "FAIL: Production Setup service is not active"
    exit 12
fi
if ! systemctl is-active --quiet msb-display-folders.service; then
    echo "FAIL: shared read-only Display Folders service is not active"
    exit 13
fi
if ! systemctl is-active --quiet msb-setup-google-links.service; then
    echo "FAIL: shared read-only Setup Google Doc link-view service is not active"
    exit 14
fi
if ! sudo -u fieldwiring -H bash -c 'cd /tmp && test -r /mnt/msb-display-folders && test -x /mnt/msb-display-folders'; then
    echo "FAIL: fieldwiring runtime account cannot read/traverse Display Folders"
    exit 15
fi
if ! sudo -u fieldwiring -H bash -c 'cd /tmp && test -r /mnt/msb-setup-google-links && test -x /mnt/msb-setup-google-links'; then
    echo "FAIL: fieldwiring runtime account cannot read/traverse Setup Google Doc link view"
    exit 16
fi
if ! sudo -u fieldwiring -H test -x "$PYTHON"; then
    echo "FAIL: documented shared Python runtime is unavailable to fieldwiring"
    exit 17
fi

SETUP_HEAD_BEFORE="$(sudo git -C "$SETUP_LIVE_ROOT" rev-parse HEAD)"
if [[ -n "$(sudo git -C "$SETUP_LIVE_ROOT" status --porcelain)" ]]; then
    echo "FAIL: live Setup checkout has uncommitted changes"
    exit 14
fi
if [[ -n "$(sudo git -C "$REPO_ROOT" status --porcelain)" ]]; then
    echo "FAIL: shared repository checkout has uncommitted changes"
    exit 15
fi
PROD_BEFORE="$(prod_fingerprint)"
if [[ -z "$PROD_BEFORE" ]]; then
    echo "FAIL: Production Setup fingerprint was empty"
    exit 16
fi

echo "Live Setup SHA: $SETUP_HEAD_BEFORE"
echo "Production Setup fingerprint before: $PROD_BEFORE"

echo
echo "--- Fetch exact candidate and prove forward ancestry ---"
sudo git -C "$REPO_ROOT" fetch origin "$TARGET_REF"
sudo git -C "$REPO_ROOT" cat-file -e "$TARGET_SHA^{commit}"
if ! sudo git -C "$REPO_ROOT" merge-base --is-ancestor "$SETUP_HEAD_BEFORE" "$TARGET_SHA"; then
    echo "FAIL: candidate is not a forward descendant of live Setup"
    exit 17
fi
sudo git -C "$REPO_ROOT" worktree add --detach "$CANDIDATE_WORKTREE" "$TARGET_SHA"

PREVIEW_ENTRY="$CANDIDATE_WORKTREE/Setup/Acceptance/setup_session_browser_preview_entry.py"
[[ -s "$PREVIEW_ENTRY" ]] || { echo "FAIL: exact candidate is missing preview entry: $PREVIEW_ENTRY"; exit 18; }

for rel in "${MIGRATIONS[@]}" "${VALIDATIONS[@]}"; do
    [[ -z "$rel" ]] && continue
    [[ -s "$CANDIDATE_WORKTREE/$rel" ]] || { echo "FAIL: exact candidate is missing required file: $rel"; exit 18; }
done

echo


# A cache file is a disposable verified transport copy, NOT a second source
# master. Keep only the active accepted SHA for each source type after a clean
# review. Do not delete a cache another preview could be using.
prune_gis_source_cache() {
    local source_cache="$HOME/setup-source-cache"
    local preview_root="/tmp"
    local source_ext expected current current_actual candidate candidate_sha links size
    local total_bytes=0 removed=0 state bundle
    if [[ "$GIS_CACHE_LOCKED" != "1" ]]; then
        echo "CACHE RETENTION SKIP: no exclusive GIS source-cache lock"
        return 0
    fi
    # Validate each selected source before pruning; leave unselected FLW untouched.
    for source_ext in gpx flw; do
        if [[ "$source_ext" == gpx ]]; then expected="$GIS_GPX_SHA"
        else expected="$GIS_FLW_SHA"; fi
        [[ "$source_ext" == flw && -z "$expected" ]] && continue
        [[ "$expected" =~ ^[a-f0-9]{64}$ ]] || {
            echo "CACHE RETENTION SKIP: unverified $source_ext source identity"
            return 0
        }
        current="$source_cache/$expected.$source_ext"
        [[ -f "$current" && ! -L "$current" ]] || {
            echo "CACHE RETENTION SKIP: current $source_ext source absent"
            return 0
        }
        current_actual="$(sha256sum "$current" | cut -d' ' -f1)"
        [[ "$current_actual" == "$expected" ]] || {
            echo "CACHE RETENTION SKIP: current $source_ext SHA mismatch"
            return 0
        }
    done

    # Existing/future preview versions might not know this cache lock.
    # Conservatively retain everything if ANOTHER review is prepared or live.
    for state in "$preview_root"/msb-setup-browser-preview-state-*.env; do
        [[ -f "$state" ]] || continue
        if [[ "$state" != "$STATE_FILE" ]]; then
            echo "CACHE RETENTION SKIP: another browser preview state exists"
            return 0
        fi
    done
    for bundle in "$preview_root"/msb-setup-disposable-browser-preview-*; do
        [[ -d "$bundle" && -s "$bundle/preview_manifest.tsv" ]] || continue
        if [[ "$bundle" != "$SCRIPT_DIR" ]]; then
            echo "CACHE RETENTION SKIP: another source review bundle exists"
            return 0
        fi
    done

    for source_ext in gpx flw; do
        if [[ "$source_ext" == gpx ]]; then expected="$GIS_GPX_SHA"
        else expected="$GIS_FLW_SHA"; fi
        [[ "$source_ext" == flw && -z "$expected" ]] && continue
        for candidate in "$source_cache"/*."$source_ext"; do
            [[ -e "$candidate" ]] || continue
            [[ -f "$candidate" && ! -L "$candidate" ]] || continue
            candidate_sha="$(basename -- "$candidate" ".$source_ext")"
            [[ "$candidate_sha" =~ ^[a-f0-9]{64}$ ]] || continue
            [[ "$candidate_sha" == "$expected" ]] && continue
            # Never delete a file still hardlinked to an in-flight bundle.
            links="$(stat -c '%h' -- "$candidate")" || return 1
            [[ "$links" == "1" ]] || continue
            size="$(stat -c '%s' -- "$candidate")" || return 1
            if rm -f -- "$candidate"; then
                removed=$((removed+1))
                total_bytes=$((total_bytes+size))
            else
                echo "WARN: could not remove superseded $source_ext cache file" >&2
                return 1
            fi
        done
    done
    echo "CACHE RETENTION PASS: kept selected current sources; removed $removed superseded verified-name cached files ($total_bytes bytes)"
}

# Content-addressed transport copies are retained only while useful.
# The exclusive lock is held through the current browser review; a newer
# preview cannot replace/prune a file used by this accepted run.
resolve_gis_source() {
    local source_sha="$1" source_ext="$2" uploaded="$3"
    local source_cache="$HOME/setup-source-cache"
    local cached="$source_cache/$source_sha.$source_ext"
    mkdir -p "$source_cache"
    chmod 700 "$source_cache"
    if [[ ! -f "$cached" ]]; then
        [[ -f "$uploaded" ]] || { echo "FAIL: missing GIS source $source_sha.$source_ext" >&2; return 16; }
        [[ "$(sha256sum "$uploaded" | cut -d' ' -f1)" == "$source_sha" ]] || { echo "FAIL: GIS upload hash differs" >&2; return 16; }
        local staged_dir staged
        staged_dir="$(mktemp -d "$source_cache/.incoming-XXXXXXXX")" || return 16
        staged="$staged_dir/payload"
        # Uploaded bundle and server cache normally use the same filesystem.
        # Hardlink the already-verified bytes rather than copying another
        # growing FLW onto disk; fall back to cp only across mount boundaries.
        if ! ln -- "$uploaded" "$staged" 2>/dev/null; then
            if ! cp -- "$uploaded" "$staged"; then
                rm -rf -- "$staged_dir"
                return 16
            fi
        fi
        chmod 400 "$staged"
        # Never overwrite a canonical hash path; keep immutable identity.
        ln "$staged" "$cached" 2>/dev/null || true
        rm -f -- "$staged"
        rmdir -- "$staged_dir"
    fi
    [[ -f "$cached" && "$(sha256sum "$cached" | cut -d' ' -f1)" == "$source_sha" ]] || { echo "FAIL: cached GIS source hash differs" >&2; return 16; }
    printf '%s\n' "$cached"
}

if [[ -n "$GIS_GPX_SHA$GIS_FLW_SHA$GIS_ACTOR" ]]; then
    [[ "$GIS_GPX_SHA" =~ ^[a-f0-9]{64}$ && ( -z "$GIS_FLW_SHA" || "$GIS_FLW_SHA" =~ ^[a-f0-9]{64}$ ) && -n "$GIS_ACTOR" ]] || { echo "FAIL: incomplete GIS source manifest"; exit 16; }
    [[ " ${MIGRATIONS[*]} " == *" Database/EngineeringTools/sql/171_site_infrastructure_schema_candidate.sql "* && " ${VALIDATIONS[*]} " == *" Database/Acceptance/171_site_infrastructure_disposable_validation.sql "* ]] || { echo "FAIL: GIS schema and validation required"; exit 16; }
    mkdir -p "$HOME/setup-source-cache"
    chmod 700 "$HOME/setup-source-cache"
    exec {GIS_CACHE_LOCK_FD}>"$HOME/setup-source-cache/.preview-source.lock"
    if ! flock -n "$GIS_CACHE_LOCK_FD"; then
        echo "FAIL: another GIS browser review holds the source cache; reuse/finish that review before retrying"
        exit 16
    fi
    GIS_CACHE_LOCKED=1
    echo "Exclusive GIS source cache lock: acquired"
    GIS_GPX_SOURCE="$(resolve_gis_source "$GIS_GPX_SHA" gpx "$SCRIPT_DIR/source.gpx")"
    GIS_FLW_ARGS=()
    if [[ -n "$GIS_FLW_SHA" ]]; then
        GIS_FLW_SOURCE="$(resolve_gis_source "$GIS_FLW_SHA" flw "$SCRIPT_DIR/source.flw")"
        GIS_FLW_ARGS=(--flw "$GIS_FLW_SOURCE" --flw-sha "$GIS_FLW_SHA")
    fi
    echo "Verified persistent GIS sources: $GIS_GPX_SHA / $GIS_FLW_SHA"
    sudo "$PYTHON" -c 'import psycopg2'
fi

# SHA-verify and cache sources BEFORE regression. An early test failure then
# cleans the upload bundle but retains verified source bytes for the next test;
# the single read-only Production dump is still strictly AFTER regression.
echo
echo "--- Exact candidate regression ---"
sudo -u fieldwiring -H env PYTHONPYCACHEPREFIX="$PYCACHE" bash -c "
    set -e
    cd '$CANDIDATE_WORKTREE'
    '$PYTHON' -m py_compile Setup/Application/production_backend.py Setup/Acceptance/setup_session_browser_preview_entry.py
    '$PYTHON' -m pytest -q -p no:cacheprovider Setup/Application Setup/Acceptance/test_setup_gis_preview.py
    '$PYTHON' -m pytest -q -p no:cacheprovider FieldWiring/Application
"
echo "PASS: exact candidate Setup/Application regression"

echo
echo "--- Capture current Production into disposable clone ---"
sudo docker exec "$PROD_CONTAINER" pg_dump -U "$DB_ACTOR" -d "$PROD_DB" -Fc > "$DUMP_FILE"
test -s "$DUMP_FILE"
sudo docker exec -i "$PROD_CONTAINER" pg_restore --list < "$DUMP_FILE" >/dev/null
echo "Production dump captured: $(du -h "$DUMP_FILE" | awk '{print $1}')"

sudo docker run -d \
    --name "$TEST_CONTAINER" \
    --network "$NETWORK" \
    -e POSTGRES_USER="$DB_ACTOR" \
    -e POSTGRES_PASSWORD="$TEST_PASSWORD" \
    -e POSTGRES_DB=postgres \
    "$IMAGE" >/dev/null

ready=0
pid1=""
for _ in $(seq 1 120); do
    if [[ "$(sudo docker inspect "$TEST_CONTAINER" --format '{{.State.Running}}' 2>/dev/null || true)" != "true" ]]; then
        break
    fi
    pid1="$(sudo docker exec "$TEST_CONTAINER" sh -c 'cat /proc/1/comm' 2>/dev/null | tr -d '\r\n' || true)"
    if [[ "$pid1" == "postgres" ]] && \
       sudo docker exec -e PGPASSWORD="$TEST_PASSWORD" "$TEST_CONTAINER" \
           pg_isready -U "$DB_ACTOR" -d postgres >/dev/null 2>&1; then
        ready=1
        break
    fi
    sleep 1
done
if [[ "$ready" -ne 1 ]]; then
    echo "FAIL: disposable PostgreSQL did not reach final post-init ready state"
    echo "Observed PID 1 command: ${pid1:-unknown}"
    sudo docker logs "$TEST_CONTAINER" || true
    exit 19
fi

sudo docker exec -e PGPASSWORD="$TEST_PASSWORD" "$TEST_CONTAINER" \
    createdb -U "$DB_ACTOR" -T template0 "$TEST_DB"
sudo docker exec -i -e PGPASSWORD="$TEST_PASSWORD" "$TEST_CONTAINER" \
    pg_restore -U "$DB_ACTOR" -d "$TEST_DB" --no-owner --no-acl --exit-on-error < "$DUMP_FILE"
echo "Disposable current-Production clone restored"

psql_test() {
    sudo docker exec -i -e PGPASSWORD="$TEST_PASSWORD" "$TEST_CONTAINER" \
        psql -X -v ON_ERROR_STOP=1 -U "$DB_ACTOR" -d "$TEST_DB" "$@"
}

echo
echo "--- Recreate current Production application-role boundary ---"
psql_test -c "CREATE ROLE fieldwiring_app LOGIN PASSWORD '$APP_PASSWORD';"

# Reproduce the established Setup disposable read boundary. The accepted Setup
# browser-preview tooling intentionally grants read-only access across the
# application schemas in the disposable clone while keeping all writes behind
# narrow SECURITY DEFINER command functions.
psql_test <<'SQL'
GRANT USAGE ON SCHEMA ref, ops, lor_snap TO fieldwiring_app;
GRANT SELECT ON ALL TABLES IN SCHEMA ref, ops, lor_snap TO fieldwiring_app;
SQL

# Preserve the real Production function boundary: replay PUBLIC revokes and
# fieldwiring_app EXECUTE grants from catalog ACLs. This keeps internal helpers
# inaccessible and avoids inventing command privileges in the clone.
sudo docker exec "$PROD_CONTAINER" psql -X -qAt -v ON_ERROR_STOP=1 -U "$DB_ACTOR" -d "$PROD_DB" -c "
    SELECT grant_stmt
    FROM (
        SELECT
            10 AS ord,
            format(
                'REVOKE ALL ON FUNCTION %I.%I(%s) FROM PUBLIC;',
                n.nspname,
                p.proname,
                pg_get_function_identity_arguments(p.oid)
            ) AS grant_stmt
        FROM pg_proc AS p
        JOIN pg_namespace AS n
          ON n.oid = p.pronamespace
        WHERE n.nspname IN ('ref','ops')
          AND p.prokind IN ('f','w')
          AND p.proacl IS NOT NULL
          AND NOT EXISTS (
              SELECT 1
              FROM aclexplode(p.proacl) AS public_acl
              WHERE public_acl.grantee = 0
                AND public_acl.privilege_type = 'EXECUTE'
          )

        UNION ALL

        SELECT
            20 AS ord,
            format(
                'GRANT EXECUTE ON FUNCTION %I.%I(%s) TO fieldwiring_app;',
                n.nspname,
                p.proname,
                pg_get_function_identity_arguments(p.oid)
            )
        FROM pg_proc AS p
        JOIN pg_namespace AS n
          ON n.oid = p.pronamespace
        CROSS JOIN LATERAL aclexplode(p.proacl) AS acl
        JOIN pg_roles AS grantee
          ON grantee.oid = acl.grantee
        WHERE n.nspname IN ('ref','ops')
          AND p.prokind IN ('f','w')
          AND grantee.rolname = 'fieldwiring_app'
          AND acl.privilege_type = 'EXECUTE'
    ) AS grants
    ORDER BY ord, grant_stmt;
" > "$GRANTS_FILE"

if [[ ! -s "$GRANTS_FILE" ]]; then
    echo "FAIL: Production function ACL extraction returned no Setup command boundary"
    exit 23
fi

grant_count="$(wc -l < "$GRANTS_FILE" | tr -d '[:space:]')"
echo "Production function ACL statements extracted: $grant_count"
if ! psql_test -q < "$GRANTS_FILE"; then
    echo "FAIL: application-role function ACL batch replay failed"
    exit 23
fi
echo "Production function ACL batch replay: PASS"

psql_test -c "ALTER ROLE fieldwiring_app SET default_transaction_read_only = on;"

echo "--- Production Setup function-boundary proof (read-only) ---"
PROD_CAPABILITY_EXEC="$(sudo docker exec "$PROD_CONTAINER" psql -X -qAt -v ON_ERROR_STOP=1 -U "$DB_ACTOR" -d "$PROD_DB" -c "SELECT has_function_privilege('fieldwiring_app','ref.setup_browser_capabilities(text)','EXECUTE');")"
PROD_UPDATE_EXEC="$(sudo docker exec "$PROD_CONTAINER" psql -X -qAt -v ON_ERROR_STOP=1 -U "$DB_ACTOR" -d "$PROD_DB" -c "SELECT has_function_privilege('fieldwiring_app','ref.update_setup_task(text,bigint,text,integer,text,integer,boolean,integer,integer,integer,text,text,text,text)','EXECUTE');")"
PROD_INTERNAL_EXEC="$(sudo docker exec "$PROD_CONTAINER" psql -X -qAt -v ON_ERROR_STOP=1 -U "$DB_ACTOR" -d "$PROD_DB" -c "SELECT has_function_privilege('fieldwiring_app','ref.setup_management_actor(text,boolean)','EXECUTE');")"

echo "Production capability EXECUTE: $PROD_CAPABILITY_EXEC"
echo "Production update-task EXECUTE:  $PROD_UPDATE_EXEC"
echo "Production internal-helper EXECUTE: $PROD_INTERNAL_EXEC"

if [[ "$PROD_CAPABILITY_EXEC" != "t" || "$PROD_UPDATE_EXEC" != "t" || "$PROD_INTERNAL_EXEC" != "f" ]]; then
    echo "FAIL: Production Setup function authorization boundary is not the documented contract"
    exit 23
fi
echo "Production Setup function authorization boundary: PASS"

echo "--- Production role/ACL diagnostic (read-only) ---"
sudo docker exec "$PROD_CONTAINER" psql -X -P pager=off -U "$DB_ACTOR" -d "$PROD_DB" -c "
    SELECT
        member_role.rolname AS member_role,
        granted_role.rolname AS inherited_role,
        member_role.rolinherit
    FROM pg_auth_members AS m
    JOIN pg_roles AS member_role
      ON member_role.oid = m.member
    JOIN pg_roles AS granted_role
      ON granted_role.oid = m.roleid
    WHERE member_role.rolname = 'fieldwiring_app'
       OR granted_role.rolname = 'fieldwiring_app'
    ORDER BY member_role.rolname, granted_role.rolname;
" || true

psql_test <<'SQL'
DO $boundary$
BEGIN
    IF NOT has_schema_privilege('fieldwiring_app', 'ref', 'USAGE')
       OR NOT has_schema_privilege('fieldwiring_app', 'ops', 'USAGE')
       OR NOT has_schema_privilege('fieldwiring_app', 'lor_snap', 'USAGE') THEN
        RAISE EXCEPTION 'Preview fieldwiring_app lacks required schema USAGE';
    END IF;

    IF NOT has_table_privilege('fieldwiring_app', 'ref.setup_task', 'SELECT')
       OR NOT has_table_privilege('fieldwiring_app', 'ops.setup_session_task', 'SELECT') THEN
        RAISE EXCEPTION 'Preview fieldwiring_app lacks required Setup SELECT boundary';
    END IF;

    IF NOT has_function_privilege(
        'fieldwiring_app',
        'ref.setup_browser_capabilities(text)',
        'EXECUTE'
    ) THEN
        RAISE EXCEPTION 'Preview fieldwiring_app cannot execute Setup capability function';
    END IF;

    /*
      Function ACLs are stripped by pg_restore --no-acl, so PostgreSQL's
      default PUBLIC EXECUTE makes the disposable clone unsuitable as the
      authority for the internal-helper EXECUTE assertion. The exact Production
      boundary is proved read-only immediately above instead.
    */

    IF has_table_privilege('fieldwiring_app', 'ref.setup_task', 'INSERT')
       OR has_table_privilege('fieldwiring_app', 'ref.setup_task', 'UPDATE')
       OR has_table_privilege('fieldwiring_app', 'ref.setup_task', 'DELETE')
       OR has_table_privilege('fieldwiring_app', 'ops.setup_session_task', 'INSERT')
       OR has_table_privilege('fieldwiring_app', 'ops.setup_session_task', 'UPDATE')
       OR has_table_privilege('fieldwiring_app', 'ops.setup_session_task', 'DELETE') THEN
        RAISE EXCEPTION 'Preview fieldwiring_app unexpectedly has broad Setup DML';
    END IF;
END
$boundary$;
SQL
echo "Established Setup disposable read boundary + Production command ACL replay: PASS"

echo
echo "--- Apply candidate migrations to disposable clone only ---"
for rel in "${MIGRATIONS[@]}"; do
    [[ -z "$rel" ]] && continue
    echo "Applying: $rel"
    psql_test < "$CANDIDATE_WORKTREE/$rel"
done

echo
echo "--- Run candidate validation SQL on disposable clone ---"
for rel in "${VALIDATIONS[@]}"; do
    [[ -z "$rel" ]] && continue
    echo "Validating: $rel"
    psql_test < "$CANDIDATE_WORKTREE/$rel"
done

MANAGE_OK="$(psql_test -qAt -c "SELECT can_manage_setup FROM ref.setup_browser_capabilities('$PREVIEW_EMAIL');")"
if [[ "$MANAGE_OK" != "t" ]]; then
    echo "FAIL: preview operator $PREVIEW_EMAIL lacks Setup Manager capability"
    exit 20
fi

# Combined GIS/power review uses existing Directus roles; never provision a second grant store.
GIS_EDITOR_PREVIEW=0
for rel in "${MIGRATIONS[@]}"; do
    if [[ "$rel" == "Database/EngineeringTools/sql/171_site_reference_operations_candidate.sql" ]]; then
        GIS_EDITOR_PREVIEW=1
    fi
done
if [[ "$GIS_EDITOR_PREVIEW" == "1" ]]; then
    [[ -n "$GIS_GPX_SHA" ]] || {
        echo "FAIL: GIS editor browser review requires exact approved GPX intake on this clone"
        exit 20
    }
    GIS_GRANT_VERIFIED="$(psql_test -qAt -F '|' -v preview_email="$PREVIEW_EMAIL" <<'SQL'
SELECT (ref.site_reference_permissions(:'preview_email')->>'identity')::boolean,
       (ref.site_power_access(:'preview_email')->>'can_edit')::boolean;
SQL
)"
    if [[ "$GIS_GRANT_VERIFIED" != 't|t' ]]; then
        echo "FAIL: Directus GIS/power permissions did not verify"
        exit 20
    fi
    echo "PASS: clone-only GIS editor rights for selected preview Manager; Production grants unchanged"
fi

TEST_IP="$(sudo docker inspect "$TEST_CONTAINER" --format '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}')"
if [[ -z "$TEST_IP" ]]; then
    echo "FAIL: could not resolve disposable PostgreSQL container IP"
    exit 21
fi
if [[ -n "$GIS_GPX_SHA" ]]; then
    echo "--- Actual GPX and optional read-only FLW import, replay, and exports ---"
    TEST_IP="$(sudo docker inspect "$TEST_CONTAINER" --format '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}')"
    [[ -n "$TEST_IP" ]] || { echo "FAIL: no disposable container address"; exit 17; }
    sudo env PGHOST="$TEST_IP" PGPORT=5432 PGDATABASE="$TEST_DB" PGUSER="$DB_ACTOR" PGPASSWORD="$TEST_PASSWORD" \
        PYTHONPYCACHEPREFIX="$PYCACHE" "$PYTHON" \
        "$CANDIDATE_WORKTREE/Database/EngineeringTools/accept_site_sources.py" \
        --gpx "$GIS_GPX_SOURCE" "${GIS_FLW_ARGS[@]}" \
        --gpx-sha "$GIS_GPX_SHA" --actor "$GIS_ACTOR" --operator-email "$PREVIEW_EMAIL" \
        --output "$REPORT_DIR/GIS_Source_Acceptance_${STAMP}"
    GIS_CACHE_ACCEPTED=1
fi

DSN="host=$TEST_IP port=5432 dbname=$TEST_DB user=fieldwiring_app password=$APP_PASSWORD"
APP_DIR="$CANDIDATE_WORKTREE/Setup/Application"

echo
echo "--- Start exact candidate on temporary preview port ---"
PREVIEW_PGID="$(sudo -u fieldwiring -H env \
    MSB_GIS_REQUIRED_SOURCE_SHA="$GIS_GPX_SHA" \
    SETUP_DATABASE_DSN="$DSN" \
    FIELDWIRING_DATABASE_DSN="$DSN" \
    PROCEDURE_DATABASE_DSN="$DSN" \
    SETUP_DRIVE_ROOT="/mnt/msb-display-folders" \
    SETUP_GOOGLE_DOC_LINK_ROOT="/mnt/msb-setup-google-links" \
    MSB_SETUP_PREVIEW_APP_DIR="$APP_DIR" \
    MSB_SETUP_PREVIEW_OPERATOR_EMAIL="$PREVIEW_EMAIL" \
    MSB_SETUP_PREVIEW_HOST="127.0.0.1" \
    MSB_SETUP_PREVIEW_PORT="$PREVIEW_PORT" \
    MSB_SETUP_PREVIEW_ENTRY="$PREVIEW_ENTRY" \
    MSB_SETUP_PREVIEW_LOG="$PREVIEW_LOG" \
    bash -c '
        cd /tmp
        setsid /opt/fieldwiring/.venv/bin/python "$MSB_SETUP_PREVIEW_ENTRY" > "$MSB_SETUP_PREVIEW_LOG" 2>&1 &
        echo $!
    ')"
if [[ ! "$PREVIEW_PGID" =~ ^[0-9]+$ ]]; then
    echo "FAIL: preview process did not return a PID"
    exit 22
fi
PREVIEW_OWNED_PORT=1

preview_ready=0
for _ in $(seq 1 60); do
    if curl -fsS "http://127.0.0.1:$PREVIEW_PORT/api/health" >/dev/null 2>&1; then
        preview_ready=1
        break
    fi
    sleep 0.5
done
if [[ "$preview_ready" -ne 1 ]]; then
    echo "FAIL: preview did not become healthy"
    tail -n 120 "$PREVIEW_LOG" || true
    exit 23
fi

HEALTH="$(curl -fsS "http://127.0.0.1:$PREVIEW_PORT/api/health")"
echo "Preview health: $HEALTH"
if [[ -n "$EXPECTED_VERSION" ]]; then
    HEALTH_VERSION="$(printf '%s' "$HEALTH" | sudo -u fieldwiring -H "$PYTHON" -c 'import json,sys; print(json.load(sys.stdin).get("version", ""))')"
    if [[ "$HEALTH_VERSION" != "$EXPECTED_VERSION" ]]; then
        echo "FAIL: preview health version '$HEALTH_VERSION' does not match expected '$EXPECTED_VERSION'"
        exit 24
    fi
    echo "Preview version pin: PASS ($HEALTH_VERSION)"
fi
curl -fsS "http://127.0.0.1:$PREVIEW_PORT/api/setup/access" >/dev/null
echo "Preview authorization: PASS"
if [[ "$GIS_EDITOR_PREVIEW" == "1" ]]; then
    echo "--- Verify real-source PostGIS reference map and editor HTTP boundary ---"
    GIS_HTTP_CHECK="$(curl -fsS "http://127.0.0.1:$PREVIEW_PORT/api/setup/locate/references" |
        sudo -u fieldwiring -H "$PYTHON" -c '
import json,sys
snapshot=json.load(sys.stdin)
assert snapshot.get("data_mode") == "postgres", "GIS read did not use PostgreSQL"
assert snapshot.get("format_version") == 1, "Unsupported GIS snapshot version"
assert len(snapshot.get("waypoints") or []) > 0, "No imported GPX waypoints"
assert len(snapshot.get("tracks") or []) > 0, "No imported GPX tracks"
assert snapshot.get("sources", {}).get("gpx", {}).get("sha256"), "No accepted GPX binding"
assert snapshot.get("permissions", {}).get("identity") is True, "Manager cannot edit GIS reference"
assert snapshot.get("power_editor_url") == "/fieldwiring/circuits", "Combined circuit reader unavailable"
print("PASS: live PostGIS references: {} waypoints, {} tracks, revision {}; Directus GIS authorization and shared circuit model".format(
    len(snapshot["waypoints"]), len(snapshot["tracks"]), snapshot["revision"]))
    ')"
    echo "$GIS_HTTP_CHECK"
fi
# Review both real application entry points on the same isolated listener.
curl -fsS "http://127.0.0.1:$PREVIEW_PORT/fieldwiring/" >/dev/null
curl -fsS "http://127.0.0.1:$PREVIEW_PORT/fieldwiring/api/health"
curl -fsS "http://127.0.0.1:$PREVIEW_PORT/setup/locate/" >/dev/null
echo "Field Wiring / GIS navigation routes: PASS"

# Prevent a browser review from declaring READY when its central Scheduling
# Board endpoint fails against the actual disposable current-Production clone.
# Source-only GET through the same isolated loopback listener, no write.
echo "--- Scheduling Board disposable endpoint preflight ---"
if ! curl -fsS --max-time 60 "http://127.0.0.1:$PREVIEW_PORT/api/setup/scheduling-board?season_year=2026" |
    sudo -u fieldwiring -H "$PYTHON" -c '
import json, sys
payload = json.load(sys.stdin)
board = payload.get("board")
if not isinstance(board, dict) or not isinstance(board.get("session"), dict):
    raise SystemExit("FAIL: Scheduling Board 2026 session missing from disposable clone")
tasks = board.get("tasks")
days = board.get("work_days")
if not isinstance(tasks, list) or not isinstance(days, list):
    raise SystemExit("FAIL: Scheduling Board is missing annual tasks/workdays")
print("PASS: Scheduling Board 2026 disposable response, "
      + str(len(tasks)) + " tasks and " + str(len(days)) + " workdays")
' ; then
    echo "FAIL: Scheduling Board disposable API failed before operator browser review"
    tail -n 75 "$PREVIEW_LOG" || true
    exit 25
fi

write_resume_state
echo "Reconnect state: $STATE_FILE"

cat <<CHECKLIST

SETUP REUSABLE DISPOSABLE BROWSER REVIEW READY
Browser URL through SSH tunnel: http://127.0.0.1:$PREVIEW_PORT/
Field Wiring / GIS entry: http://127.0.0.1:$PREVIEW_PORT/fieldwiring/
Candidate SHA: $TARGET_SHA
Candidate ref: $TARGET_REF
Preview identity: $PREVIEW_EMAIL
Expected version: ${EXPECTED_VERSION:-not pinned}

The exact candidate is running against a disposable current-Production database clone.
All browser writes from this preview are disposable.
Concurrent Production application writes allowed: $ALLOW_CONCURRENT_PRODUCTION_WRITES
The preview clone is a point-in-time snapshot; later Production edits are not visible until a new preview is started.

Perform the feature-specific operator checklist now.
When review is complete, return to this terminal and press ENTER.
CHECKLIST

if ! read -r _done; then
    PRESERVE_FOR_RECONNECT=1
    echo "Review terminal disconnected; preserving preview for reconnect."
    exit 75
fi

echo
echo "Browser review session ended by operator. Cleanup will now run."
echo "SETUP_REUSABLE_DISPOSABLE_BROWSER_PREVIEW_CLEAN_EXIT"
