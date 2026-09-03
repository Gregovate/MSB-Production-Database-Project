#!/usr/bin/env bash
set -euo pipefail

FIELDWIRING_ROOT="/opt/fieldwiring"
PREVIEW_PORT="${1:-8793}"

sudo -v

echo "========== CONTROLLER BROWSER PREVIEW STALE CLEANUP =========="
echo "Preview port: $PREVIEW_PORT"
echo

# Kill only an actual Python preview-entry process. Do not use a broad
# `pkill -f <path>` here: the SSH-side shell command can legitimately mention
# the future preview entry path before the preview starts, and a broad match can
# kill the cleanup shell itself.
mapfile -t preview_pids < <(
    ps -eo pid=,comm=,args= \
        | awk '
            $2 ~ /^python/ &&
            $0 ~ /\/tmp\/msb-controller-browser-preview-[^ ]*\/controller_setup_management_browser_preview_entry\.py/ {
                print $1
            }
        '
)
for pid in "${preview_pids[@]}"; do
    [[ -n "$pid" ]] || continue
    echo "Stopping stale preview Python process: $pid"
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

# Remove only disposable preview containers.
mapfile -t preview_containers < <(
    sudo docker ps -a --format '{{.Names}}' | grep '^msb-controller-browser-preview-' || true
)
for name in "${preview_containers[@]}"; do
    [[ -n "$name" ]] || continue
    echo "Removing stale preview container: $name"
    sudo docker rm -f "$name" >/dev/null
done

# Remove only detached preview worktrees registered beneath the documented prefix.
mapfile -t preview_worktrees < <(
    sudo git -C "$FIELDWIRING_ROOT" worktree list --porcelain \
        | awk '$1 == "worktree" { print $2 }' \
        | grep '^/tmp/msb-controller-browser-preview-candidate-' || true
)
for wt in "${preview_worktrees[@]}"; do
    [[ -n "$wt" ]] || continue
    echo "Removing stale preview worktree: $wt"
    sudo git -C "$FIELDWIRING_ROOT" worktree remove --force "$wt" >/dev/null 2>&1 || true
done

# Remove old uploaded preview bundles only; production paths are not touched.
for path in /tmp/msb-controller-browser-preview-*; do
    [[ -e "$path" ]] || continue
    echo "Removing stale preview bundle/path: $path"
    rm -rf -- "$path"
done

if ss -ltnH "sport = :$PREVIEW_PORT" | grep -q .; then
    echo "FAIL: TCP port $PREVIEW_PORT is still listening after preview cleanup"
    ss -ltnp "sport = :$PREVIEW_PORT" || true
    exit 2
fi

echo "PASS: preview port $PREVIEW_PORT is free"
echo "PASS: stale Controller browser preview resources removed"
