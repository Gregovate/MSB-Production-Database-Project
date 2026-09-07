#!/usr/bin/env bash
set -euo pipefail

FIELDWIRING_ROOT="/opt/fieldwiring"
PREVIEW_PORT="${1:-8794}"

sudo -v

echo "========== SETUP SESSION BROWSER PREVIEW STALE CLEANUP =========="
echo "Preview port: $PREVIEW_PORT"
echo

mapfile -t preview_pids < <(
    ps -eo pid=,comm=,args= \
        | awk '
            $2 ~ /^python/ &&
            $0 ~ /\/tmp\/msb-setup-browser-preview-[^ ]*\/setup_session_browser_preview_entry\.py/ {
                print $1
            }
        '
)
for pid in "${preview_pids[@]}"; do
    [[ -n "$pid" ]] || continue
    echo "Stopping stale Setup preview Python process: $pid"
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

# Remove only temporary Setup Google-Doc link-view mounts/processes.
for link_root in /tmp/msb-setup-google-links-*; do
    [[ -e "$link_root" ]] || continue
    if mountpoint -q "$link_root" 2>/dev/null; then
        echo "Unmounting stale Setup Google Doc link view: $link_root"
        sudo fusermount -u "$link_root" >/dev/null 2>&1 \
            || sudo umount "$link_root" >/dev/null 2>&1 \
            || true
    fi
done

mapfile -t link_pids < <(
    ps -eo pid=,comm=,args= \
        | awk '
            $2 == "rclone" &&
            $0 ~ /\/tmp\/msb-setup-google-links-/ {
                print $1
            }
        '
)
for pid in "${link_pids[@]}"; do
    [[ -n "$pid" ]] || continue
    echo "Stopping stale Setup Google Doc rclone process: $pid"
    sudo kill "$pid" >/dev/null 2>&1 || true
done
if (( ${#link_pids[@]} > 0 )); then
    sleep 1
    for pid in "${link_pids[@]}"; do
        [[ -n "$pid" ]] || continue
        if sudo kill -0 "$pid" >/dev/null 2>&1; then
            sudo kill -KILL "$pid" >/dev/null 2>&1 || true
        fi
    done
fi

for link_root in /tmp/msb-setup-google-links-*; do
    [[ -e "$link_root" ]] || continue
    rm -rf -- "$link_root"
done

mapfile -t preview_containers < <(
    sudo docker ps -a --format '{{.Names}}' | grep '^msb-setup-browser-preview-' || true
)
for name in "${preview_containers[@]}"; do
    [[ -n "$name" ]] || continue
    echo "Removing stale Setup preview container: $name"
    sudo docker rm -f "$name" >/dev/null
done

mapfile -t preview_worktrees < <(
    sudo git -C "$FIELDWIRING_ROOT" worktree list --porcelain \
        | awk '$1 == "worktree" { print $2 }' \
        | grep '^/tmp/msb-setup-browser-preview-candidate-' || true
)
for wt in "${preview_worktrees[@]}"; do
    [[ -n "$wt" ]] || continue
    echo "Removing stale Setup preview worktree: $wt"
    sudo git -C "$FIELDWIRING_ROOT" worktree remove --force "$wt" >/dev/null 2>&1 || true
done

for path in /tmp/msb-setup-browser-preview-*; do
    [[ -e "$path" ]] || continue
    echo "Removing stale Setup preview bundle/path: $path"
    rm -rf -- "$path"
done

if ss -ltnH "sport = :$PREVIEW_PORT" | grep -q .; then
    echo "FAIL: TCP port $PREVIEW_PORT is still listening after Setup preview cleanup"
    ss -ltnp "sport = :$PREVIEW_PORT" || true
    exit 2
fi

echo "PASS: preview port $PREVIEW_PORT is free"
echo "PASS: stale Setup browser preview resources removed"
