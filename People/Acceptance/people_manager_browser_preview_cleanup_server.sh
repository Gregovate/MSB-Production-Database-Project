#!/usr/bin/env bash
set -euo pipefail

FIELDWIRING_ROOT="/opt/fieldwiring"
PREVIEW_PORT="${1:?preview port argument is required}"

if [[ ! "$PREVIEW_PORT" =~ ^[0-9]+$ ]] || (( PREVIEW_PORT < 1024 || PREVIEW_PORT > 65535 )); then
    echo "FAIL: preview port must be an integer from 1024 through 65535"
    exit 2
fi
if [[ "$PREVIEW_PORT" == "8794" ]]; then
    echo "FAIL: port 8794 is the live Production Setup listener and must never be cleaned as People preview state"
    exit 3
fi
if [[ "$PREVIEW_PORT" == "8055" || "$PREVIEW_PORT" == "8790" || "$PREVIEW_PORT" == "8792" ]]; then
    echo "FAIL: port $PREVIEW_PORT is a governed Production listener and must never be cleaned as People preview state"
    exit 3
fi

sudo -v

echo "========== PEOPLE MANAGER BROWSER PREVIEW STALE CLEANUP =========="
echo "Preview port: $PREVIEW_PORT"
echo

# Stop only actual Python preview-entry processes. Avoid broad pkill patterns
# because the SSH-side command can legitimately mention the future preview path.
mapfile -t preview_pids < <(
    ps -eo pid=,comm=,args= \
        | awk '
            $2 ~ /^python/ &&
            $0 ~ /\/tmp\/msb-people-browser-preview-[^ ]*\/people_manager_browser_preview_entry\.py/ {
                print $1
            }
        '
)
for pid in "${preview_pids[@]}"; do
    [[ -n "$pid" ]] || continue
    echo "Stopping stale People preview Python process: $pid"
    sudo kill "$pid" >/dev/null 2>&1 || true
done
if (( ${#preview_pids[@]} > 0 )); then
    sleep 1
    for pid in "${preview_pids[@]}"; do
        [[ -n "$pid" ]] || continue
        if sudo kill -0 "$pid" >/dev/null 2>&1; then
            sudo kill -KILL "$pid" >/dev/null 2>&1 || true
        fi
    done
fi

# Remove only People Manager disposable preview containers.
mapfile -t preview_containers < <(
    sudo docker ps -a --format '{{.Names}}' | grep '^msb-people-browser-preview-' || true
)
for name in "${preview_containers[@]}"; do
    [[ -n "$name" ]] || continue
    echo "Removing stale People preview container: $name"
    sudo docker rm -f "$name" >/dev/null
done

# Remove only detached People preview worktrees registered under this prefix.
mapfile -t preview_worktrees < <(
    sudo git -C "$FIELDWIRING_ROOT" worktree list --porcelain \
        | awk '$1 == "worktree" { print $2 }' \
        | grep '^/tmp/msb-people-browser-preview-candidate-' || true
)
for wt in "${preview_worktrees[@]}"; do
    [[ -n "$wt" ]] || continue
    echo "Removing stale People preview worktree: $wt"
    sudo git -C "$FIELDWIRING_ROOT" worktree remove --force "$wt" >/dev/null 2>&1 || true
done

# Remove old uploaded People preview bundles only. Reports/logs have different
# names and remain available as acceptance evidence.
for path in /tmp/msb-people-browser-preview-*; do
    [[ -e "$path" ]] || continue
    echo "Removing stale People preview bundle/path: $path"
    rm -rf -- "$path"
done

if ss -ltnH "sport = :$PREVIEW_PORT" | grep -q .; then
    echo "FAIL: TCP port $PREVIEW_PORT is occupied after People preview cleanup; refusing to touch the listener"
    ss -ltnp "sport = :$PREVIEW_PORT" || true
    exit 4
fi

echo "PASS: preview port $PREVIEW_PORT is free"
echo "PASS: stale People Manager browser preview resources removed"
