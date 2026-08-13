#!/usr/bin/env bash
# MSB LOR folder-alignment launcher for Linux/Ubuntu
#
# Purpose:
#   Run the same read-only Folder Alignment implementation used on Windows.
#   No alignment logic lives here.
#
# Linux paths vary by Google Drive client/mount. Configure them with either:
#   1) command-line options passed through to Python, or
#   2) these optional environment variables:
#        MSB_FOLDER_ALIGNMENT_DB
#        MSB_FOLDER_ALIGNMENT_DRIVE_ROOT
#        MSB_FOLDER_ALIGNMENT_OUTPUT_DIR
#
# Example:
#   bash ./run_folder_check.sh \
#     --db "/path/to/lor_output_v7_scene.db" \
#     --drive-root "/path/to/Display Folders" \
#     --output-dir "/path/to/google-drive-alignment"
#
# Add --include-displays only when Display/group engineering diagnostics are
# intentionally needed. The normal Setup Alignment report suppresses Displays.

set -u

REPO_ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
ALIGNMENT_SCRIPT="$REPO_ROOT/Docs/01_LOR_System/02_Data_Extraction/Folder_Alignment/generate_folder_alignment_report_v1_3_6.py"

if [[ ! -f "$ALIGNMENT_SCRIPT" ]]; then
    echo "[ERROR] Folder Alignment script not found: $ALIGNMENT_SCRIPT" >&2
    exit 2
fi

if command -v python3 >/dev/null 2>&1; then
    PYTHON_CMD="$(command -v python3)"
elif command -v python >/dev/null 2>&1; then
    PYTHON_CMD="$(command -v python)"
else
    echo "[ERROR] Python 3 was not found. Install Python 3 and try again." >&2
    exit 3
fi

PY_ARGS=()

if [[ -n "${MSB_FOLDER_ALIGNMENT_DB:-}" ]]; then
    PY_ARGS+=(--db "$MSB_FOLDER_ALIGNMENT_DB")
fi
if [[ -n "${MSB_FOLDER_ALIGNMENT_DRIVE_ROOT:-}" ]]; then
    PY_ARGS+=(--drive-root "$MSB_FOLDER_ALIGNMENT_DRIVE_ROOT")
fi
if [[ -n "${MSB_FOLDER_ALIGNMENT_OUTPUT_DIR:-}" ]]; then
    PY_ARGS+=(--output-dir "$MSB_FOLDER_ALIGNMENT_OUTPUT_DIR")
fi

has_db=false
has_drive=false
for arg in "${PY_ARGS[@]}" "$@"; do
    [[ "$arg" == "--db" ]] && has_db=true
    [[ "$arg" == "--drive-root" ]] && has_drive=true
done

if [[ "$has_db" != true || "$has_drive" != true ]]; then
    cat >&2 <<'EOF'
[ERROR] Linux Folder Alignment needs the mounted paths for the V7 SQLite file and Display Folders.

Provide them on the command line, for example:
  bash ./run_folder_check.sh \
    --db "/path/to/lor_output_v7_scene.db" \
    --drive-root "/path/to/Display Folders" \
    --output-dir "/path/to/google-drive-alignment"

Or set:
  MSB_FOLDER_ALIGNMENT_DB
  MSB_FOLDER_ALIGNMENT_DRIVE_ROOT
  MSB_FOLDER_ALIGNMENT_OUTPUT_DIR
EOF
    exit 4
fi

echo "[INFO] Folder Alignment: $ALIGNMENT_SCRIPT"
echo "[INFO] Python: $PYTHON_CMD"

"$PYTHON_CMD" "$ALIGNMENT_SCRIPT" "${PY_ARGS[@]}" "$@"
status=$?

if [[ $status -eq 0 ]]; then
    echo "[INFO] Folder Alignment completed successfully."

    output_dir="${MSB_FOLDER_ALIGNMENT_OUTPUT_DIR:-}"
    args=("$@")
    for ((i=0; i<${#args[@]}; i++)); do
        if [[ "${args[$i]}" == "--output-dir" && $((i+1)) -lt ${#args[@]} ]]; then
            output_dir="${args[$((i+1))]}"
        fi
    done

    if [[ -n "$output_dir" && -d "$output_dir" ]] && command -v xdg-open >/dev/null 2>&1; then
        xdg-open "$output_dir" >/dev/null 2>&1 || true
    fi
fi

exit $status
