#!/usr/bin/env bash
set -euo pipefail

FIELDWIRING_ROOT="/opt/fieldwiring"
PREVIEW_PORT="${1:?preview port required}"

if [[ ! "$PREVIEW_PORT" =~ ^[0-9]+$ ]] || (( PREVIEW_PORT < 1024 || PREVIEW_PORT > 65535 )); then
    echo "FAIL: preview port must be 1024-65535"
    exit 2
fi
if [[ "$PREVIEW_PORT" == "8055" || "$PREVIEW_PORT" == "8790" || "$PREVIEW_PORT" == "8792" || "$PREVIEW_PORT" == "8794" ]]; then
    echo "FAIL: port $PREVIEW_PORT is a governed Production listener and must never be cleaned as preview state"
    exit 3
fi

sudo -v

echo "========== SETUP SESSION BROWSER PREVIEW STALE CLEANUP =========="
echo "Preview port: $PREVIEW_PORT"
echo

# Legacy Setup browser-preview resources. Keep this path for older launchers that
# use the msb-setup-browser-preview-* naming contract.
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
    echo "Stopping stale legacy Setup preview Python process: $pid"
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

# Source-only previews intentionally run a detached fieldwiring-owned Flask
# process from /tmp/setup_session_browser_preview_entry.py. Recover only the
# process actually listening on the requested non-Production preview port.
source_worktrees=()
source_stamps=()
source_containers=()
mapfile -t source_listener_pids < <(
    sudo ss -ltnp "sport = :$PREVIEW_PORT" 2>/dev/null \
        | grep -oE 'pid=[0-9]+' \
        | cut -d= -f2 \
        | sort -u \
        || true
)

for pid in "${source_listener_pids[@]}"; do
    [[ -n "$pid" ]] || continue

    cmdline="$(sudo tr '\0' ' ' < "/proc/$pid/cmdline" 2>/dev/null || true)"
    owner="$(ps -o user= -p "$pid" 2>/dev/null | xargs || true)"
    if [[ "$cmdline" != *"/tmp/setup_session_browser_preview_entry.py"* || "$owner" != "fieldwiring" ]]; then
        echo "FAIL: preview port $PREVIEW_PORT is owned by an unexpected process; refusing to kill it"
        ps -o pid,ppid,pgid,user,args -p "$pid" || true
        exit 4
    fi

    app_dir="$(sudo tr '\0' '\n' < "/proc/$pid/environ" 2>/dev/null \
        | sed -n 's/^MSB_SETUP_PREVIEW_APP_DIR=//p' \
        | head -1)"
    if [[ "$app_dir" == /tmp/msb-setup-source-preview-candidate-*/Setup/Application ]]; then
        worktree="${app_dir%/Setup/Application}"
        stamp="${worktree#/tmp/msb-setup-source-preview-candidate-}"
        source_worktrees+=("$worktree")
        source_stamps+=("$stamp")
    fi

    dsn="$(sudo tr '\0' '\n' < "/proc/$pid/environ" 2>/dev/null \
        | sed -n 's/^SETUP_DATABASE_DSN=//p' \
        | head -1)"
    db_host="$(sed -n 's/.*\(^\|[[:space:]]\)host=\([^[:space:]]*\).*/\2/p' <<<"$dsn")"
    if [[ -n "$db_host" ]]; then
        while IFS= read -r name; do
            [[ -n "$name" ]] || continue
            ip="$(sudo docker inspect "$name" --format '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' 2>/dev/null || true)"
            if [[ "$ip" == "$db_host" ]]; then
                source_containers+=("$name")
            fi
        done < <(sudo docker ps -a --format '{{.Names}}' | grep '^msb-setup-source-preview-' || true)
    fi

    pgid="$(ps -o pgid= -p "$pid" 2>/dev/null | tr -d ' ')"
    if [[ ! "$pgid" =~ ^[0-9]+$ ]]; then
        echo "FAIL: could not determine process group for source-only preview PID $pid"
        exit 5
    fi

    echo "Stopping stale source-only Setup preview process group: $pgid (PID $pid)"
    sudo -u fieldwiring -H kill -- -"$pgid" >/dev/null 2>&1 || true
done

if (( ${#source_listener_pids[@]} > 0 )); then
    sleep 1
    for pid in "${source_listener_pids[@]}"; do
        [[ -n "$pid" ]] || continue
        if sudo kill -0 "$pid" >/dev/null 2>&1; then
            pgid="$(ps -o pgid= -p "$pid" 2>/dev/null | tr -d ' ')"
            if [[ "$pgid" =~ ^[0-9]+$ ]]; then
                sudo -u fieldwiring -H kill -KILL -- -"$pgid" >/dev/null 2>&1 || true
            fi
        fi
    done
fi

# The source-only server wrapper waits on the review TTY after launching Flask.
# If the SSH/tunnel side disappears, that wrapper can survive even after Flask is
# stopped. Kill only wrappers whose command line contains this exact preview port.
mapfile -t source_wrapper_pids < <(
    ps -eo pid=,comm=,args= \
        | awk -v port="$PREVIEW_PORT" '
            $2 == "bash" &&
            $0 ~ /bash \/tmp\/msb-setup-source-preview-[0-9-]+\.sh/ &&
            index($0, " " port " ") {
                print $1
            }
        '
)
for pid in "${source_wrapper_pids[@]}"; do
    [[ -n "$pid" ]] || continue
    source_containers+=("msb-setup-source-preview-$pid")
    echo "Stopping stale source-only Setup preview wrapper: $pid"
    sudo kill -KILL "$pid" >/dev/null 2>&1 || true
done

# Remove only disposable containers discovered from the exact wrapper PID or the
# exact database host used by the source-only Flask listener.
if (( ${#source_containers[@]} > 0 )); then
    mapfile -t unique_source_containers < <(printf '%s\n' "${source_containers[@]}" | awk 'NF && !seen[$0]++')
    for name in "${unique_source_containers[@]}"; do
        [[ -n "$name" ]] || continue
        if sudo docker ps -a --format '{{.Names}}' | grep -Fxq "$name"; then
            echo "Removing stale source-only Setup preview container: $name"
            sudo docker rm -f "$name" >/dev/null
        fi
    done
fi

# Remove only worktrees identified from the exact listener environment. Reports
# and Flask logs are retained as acceptance evidence.
if (( ${#source_worktrees[@]} > 0 )); then
    mapfile -t unique_source_worktrees < <(printf '%s\n' "${source_worktrees[@]}" | awk 'NF && !seen[$0]++')
    for wt in "${unique_source_worktrees[@]}"; do
        [[ -n "$wt" ]] || continue
        if sudo git -C "$FIELDWIRING_ROOT" worktree list --porcelain 2>/dev/null | grep -Fq "worktree $wt"; then
            echo "Removing stale source-only Setup preview worktree: $wt"
            sudo git -C "$FIELDWIRING_ROOT" worktree remove --force "$wt" >/dev/null
        fi
    done
fi

if (( ${#source_stamps[@]} > 0 )); then
    mapfile -t unique_source_stamps < <(printf '%s\n' "${source_stamps[@]}" | awk 'NF && !seen[$0]++')
    for stamp in "${unique_source_stamps[@]}"; do
        [[ "$stamp" =~ ^[0-9]{8}T[0-9]{6}$ ]] || continue
        dump="/tmp/msb-setup-source-preview-$stamp.dump"
        if [[ -f "$dump" ]]; then
            echo "Removing stale source-only Setup preview dump: $dump"
            rm -f -- "$dump"
        fi
    done
fi

# Stop stale Setup Google-Doc rclone processes before unmounting their roots.
# The mount roots are owned by msb-docs-fs, so removal from sticky /tmp must be
# performed with sudo rather than as msbadmin.
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
    if mountpoint -q "$link_root" 2>/dev/null; then
        echo "Unmounting stale Setup Google Doc link view: $link_root"
        sudo fusermount -u "$link_root" >/dev/null 2>&1 \
            || sudo umount "$link_root" >/dev/null 2>&1 \
            || true
    fi
    if mountpoint -q "$link_root" 2>/dev/null; then
        echo "FAIL: stale Setup Google Doc link view is still mounted: $link_root"
        exit 6
    fi
    sudo rm -rf -- "$link_root"
done

mapfile -t preview_containers < <(
    sudo docker ps -a --format '{{.Names}}' | grep '^msb-setup-browser-preview-' || true
)
for name in "${preview_containers[@]}"; do
    [[ -n "$name" ]] || continue
    echo "Removing stale legacy Setup preview container: $name"
    sudo docker rm -f "$name" >/dev/null
done

mapfile -t preview_worktrees < <(
    sudo git -C "$FIELDWIRING_ROOT" worktree list --porcelain \
        | awk '$1 == "worktree" { print $2 }' \
        | grep '^/tmp/msb-setup-browser-preview-candidate-' || true
)
for wt in "${preview_worktrees[@]}"; do
    [[ -n "$wt" ]] || continue
    echo "Removing stale legacy Setup preview worktree: $wt"
    sudo git -C "$FIELDWIRING_ROOT" worktree remove --force "$wt" >/dev/null 2>&1 || true
done

for path in /tmp/msb-setup-browser-preview-*; do
    [[ -e "$path" ]] || continue
    echo "Removing stale legacy Setup preview bundle/path: $path"
    rm -rf -- "$path"
done

# The common source-only entry path is safe to remove only after the requested
# preview port is no longer owned by a source-only preview process.
if ! ss -ltnH "sport = :$PREVIEW_PORT" | grep -q .; then
    rm -f /tmp/setup_session_browser_preview_entry.py >/dev/null 2>&1 || true
fi

if ss -ltnH "sport = :$PREVIEW_PORT" | grep -q .; then
    echo "FAIL: TCP port $PREVIEW_PORT is still listening after Setup preview cleanup"
    sudo ss -ltnp "sport = :$PREVIEW_PORT" || true
    exit 7
fi

echo "PASS: preview port $PREVIEW_PORT is free"
echo "PASS: stale Setup browser preview resources removed"
