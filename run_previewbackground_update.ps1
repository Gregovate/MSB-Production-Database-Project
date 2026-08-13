# MSB PreviewBackground folder updater launcher for Windows
#
# Default behavior is DRY-RUN. Pass --apply only after reviewing proposed
# additions. The updater is additive-only: it creates PreviewBackground inside
# existing resolved scope folders and never moves, renames, deletes, or
# overwrites anything.

$ErrorActionPreference = 'Stop'

$RepoRoot = $PSScriptRoot
$UpdaterScript = Join-Path $RepoRoot 'Docs\01_LOR_System\02_Data_Extraction\Folder_Alignment\update_previewbackground_folders.py'

if (-not (Test-Path -LiteralPath $UpdaterScript -PathType Leaf)) {
    Write-Error "PreviewBackground updater not found: $UpdaterScript"
    exit 2
}

$PythonCommand = Get-Command python -ErrorAction SilentlyContinue
if (-not $PythonCommand) {
    $PythonCommand = Get-Command python3 -ErrorAction SilentlyContinue
}
if (-not $PythonCommand) {
    Write-Error "Python 3 was not found. Activate the project virtual environment or install Python 3 and try again."
    exit 3
}

$PythonArgs = @()
if ($env:MSB_FOLDER_ALIGNMENT_DB) {
    $PythonArgs += @('--db', $env:MSB_FOLDER_ALIGNMENT_DB)
}
if ($env:MSB_FOLDER_ALIGNMENT_DRIVE_ROOT) {
    $PythonArgs += @('--drive-root', $env:MSB_FOLDER_ALIGNMENT_DRIVE_ROOT)
}
if ($env:MSB_FOLDER_ALIGNMENT_OUTPUT_DIR) {
    $PythonArgs += @('--output-dir', $env:MSB_FOLDER_ALIGNMENT_OUTPUT_DIR)
}

Write-Host "[INFO] PreviewBackground updater: $UpdaterScript"
Write-Host "[INFO] Python: $($PythonCommand.Source)"
Write-Host "[INFO] Default mode is DRY-RUN. Use --apply only after review."

& $PythonCommand.Source $UpdaterScript @PythonArgs @args
$ExitCode = $LASTEXITCODE
if ($null -eq $ExitCode) {
    $ExitCode = 0
}

exit $ExitCode
