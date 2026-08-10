# MSB LOR folder-alignment launcher
#
# Purpose:
#   Run the current read-only Google Shared Drive folder-alignment report
#   from the repository root.
#
# The alignment implementation belongs to the LOR data-extraction system.
# This launcher intentionally contains no alignment logic.

$ErrorActionPreference = 'Stop'

$RepoRoot = $PSScriptRoot
$AlignmentScript = Join-Path $RepoRoot 'Docs\01_LOR_System\02_Data_Extraction\Folder_Alignment\generate_folder_alignment_report.py'

if (-not (Test-Path -LiteralPath $AlignmentScript -PathType Leaf)) {
    Write-Error "Folder alignment script not found: $AlignmentScript"
    exit 2
}

$PythonCommand = Get-Command python -ErrorAction SilentlyContinue
if (-not $PythonCommand) {
    Write-Error "Python was not found in the current PowerShell environment. Activate the project virtual environment and try again."
    exit 3
}

Write-Host "[INFO] Folder alignment: $AlignmentScript"
Write-Host "[INFO] Python: $($PythonCommand.Source)"

& $PythonCommand.Source $AlignmentScript @args
$AlignmentExitCode = $LASTEXITCODE

if ($null -eq $AlignmentExitCode) {
    $AlignmentExitCode = 0
}

exit $AlignmentExitCode
