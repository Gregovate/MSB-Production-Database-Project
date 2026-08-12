# MSB LOR folder-alignment launcher for Windows
#
# Purpose:
#   Run the current read-only Google Shared Drive folder-alignment report
#   from the repository root, then open the report folder for inspection.
#
# The alignment implementation belongs to the LOR data-extraction system.
# This launcher intentionally contains no alignment logic.
#
# Optional cross-platform path configuration uses the same environment variable
# names as run_folder_check.sh:
#   MSB_FOLDER_ALIGNMENT_DB
#   MSB_FOLDER_ALIGNMENT_DRIVE_ROOT
#   MSB_FOLDER_ALIGNMENT_OUTPUT_DIR
# Explicit command-line arguments are appended last and therefore override the
# environment-provided values.

$ErrorActionPreference = 'Stop'

$RepoRoot = $PSScriptRoot
$AlignmentScript = Join-Path $RepoRoot 'Docs\01_LOR_System\02_Data_Extraction\Folder_Alignment\generate_folder_alignment_report_v1_3_4.py'
$DefaultOutputDir = 'G:\Shared drives\MSB Database\Database Previews V6.6.4\reports\google-drive-alignment'

if (-not (Test-Path -LiteralPath $AlignmentScript -PathType Leaf)) {
    Write-Error "Folder Alignment script not found: $AlignmentScript"
    exit 2
}

$PythonCommand = Get-Command python -ErrorAction SilentlyContinue
if (-not $PythonCommand) {
    $PythonCommand = Get-Command python3 -ErrorAction SilentlyContinue
}
if (-not $PythonCommand) {
    Write-Error "Python 3 was not found in the current PowerShell environment. Activate the project virtual environment or install Python 3 and try again."
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

# Track the output folder so Explorer opens the location actually used.
$OutputDir = if ($env:MSB_FOLDER_ALIGNMENT_OUTPUT_DIR) {
    $env:MSB_FOLDER_ALIGNMENT_OUTPUT_DIR
}
else {
    $DefaultOutputDir
}

for ($i = 0; $i -lt $args.Count; $i++) {
    if ($args[$i] -eq '--output-dir' -and ($i + 1) -lt $args.Count) {
        $OutputDir = $args[$i + 1]
        break
    }
}

Write-Host "[INFO] Folder Alignment: $AlignmentScript"
Write-Host "[INFO] Python: $($PythonCommand.Source)"

# Environment-derived defaults first; explicit arguments last so argparse uses
# the explicit value when the same option is supplied more than once.
& $PythonCommand.Source $AlignmentScript @PythonArgs @args
$AlignmentExitCode = $LASTEXITCODE

if ($null -eq $AlignmentExitCode) {
    $AlignmentExitCode = 0
}

if ($AlignmentExitCode -eq 0) {
    if (Test-Path -LiteralPath $OutputDir -PathType Container) {
        Write-Host "[INFO] Opening report folder: $OutputDir"
        Start-Process explorer.exe -ArgumentList $OutputDir
    }
    else {
        Write-Warning "Report completed, but the output folder was not found: $OutputDir"
    }
}

exit $AlignmentExitCode
