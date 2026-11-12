#!/usr/bin/env bash
# MSB PreviewBackground folder updater launcher for Linux/Ubuntu
#
# Default behavior is DRY-RUN. Pass --apply only after reviewing proposed
# additions. The updater is additive-only and never moves, renames, deletes,
# or overwrites anything.

set -u

REPO_ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
UPDATER_SCRIPT="$REPO_ROOT/Docs/01_LOR_System/02_Data_Extraction/Folder_Alignment/update_previewbackground_folders.py"

if [[ ! -f "$UPDATER_SCRIPT" ]]; then
    echo "[ERROR] PreviewBackground updater not found: $UPDATER_SCRIPT" >&2
    exit 2
fi

if command -v python3 >/dev/null 2>&1; then
    PYTHON_CMD="$(command -v python3)"
elif command -v python >/dev/null 2>&1; then
    PYTHON_CMD="$(command -v python)"
else
    echo "[ERROR] Python 3 was not found." >&2
    exit 3
fi

PY_ARGS=()
[[ -n "${MSB_FOLDER_ALIGNMENT_DB:-}" ]] && PY_ARGS+=(--db "$MSB_FOLDER_ALIGNMENT_DB")
[[ -n "${MSB_FOLDER_ALIGNMENT_DRIVE_ROOT:-}" ]] && PY_ARGS+=(--drive-root "$MSB_FOLDER_ALIGNMENT_DRIVE_ROOT")
[[ -n "${MSB_FOLDER_ALIGNMENT_OUTPUT_DIR:-}" ]] && PY_ARGS+=(--output-dir "$MSB_FOLDER_ALIGNMENT_OUTPUT_DIR")

has_db=false
has_drive=false
for arg in "${PY_ARGS[@]}" "$@"; do
    [[ "$arg" == "--db" ]] && has_db=true
    [[ "$arg" == "--drive-root" ]] && has_drive=true
done

if [[ "$has_db" != true || "$has_drive" != true ]]; then
    cat >&2 <<'EOF'
[ERROR] Linux PreviewBackground update requires mounted paths for the V7 SQLite file and Display Folders.

Example dry-run:
  bash ./run_previewbackground_update.sh \
    --db "/path/to/lor_output_v7_scene.db" \
    --drive-root "/path/to/Display Folders" \
    --output-dir "/path/to/google-drive-alignment"

Add --apply only after reviewing the dry-run.
EOF
    exit 4
fi

echo "[INFO] PreviewBackground updater: $UPDATER_SCRIPT"
echo "[INFO] Python: $PYTHON_CMD"
echo "[INFO] Default mode is DRY-RUN. Use --apply only after review."

"$PYTHON_CMD" "$UPDATER_SCRIPT" "${PY_ARGS[@]}" "$@"
exit $?
