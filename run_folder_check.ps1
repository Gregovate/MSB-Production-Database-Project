# MSB LOR folder-alignment launcher
#
# Purpose:
#   Run the current read-only Google Shared Drive folder-alignment report
#   from the repository root, then open the report folder for inspection.
#
# The alignment implementation belongs to the LOR data-extraction system.
# This launcher intentionally contains no alignment logic.

$ErrorActionPreference = 'Stop'

$RepoRoot = $PSScriptRoot
$AlignmentScript = Join-Path $RepoRoot 'Docs\01_LOR_System\02_Data_Extraction\Folder_Alignment\generate_folder_alignment_report_v1_3_4.py'
$DefaultOutputDir = 'G:\Shared drives\MSB Database\Database Previews V6.6.4\reports\google-drive-alignment'

if (-not (Test-Path -LiteralPath $AlignmentScript -PathType Leaf)) {
    Write-Error "Folder alignment script not found: $AlignmentScript"
    exit 2
}

$PythonCommand = Get-Command python -ErrorAction SilentlyContinue
if (-not $PythonCommand) {
    Write-Error "Python was not found in the current PowerShell environment. Activate the project virtual environment and try again."
    exit 3
}

# Track an explicitly supplied --output-dir so Explorer opens the folder that
# was actually used by the Python report generator.
$OutputDir = $DefaultOutputDir
for ($i = 0; $i -lt $args.Count; $i++) {
    if ($args[$i] -eq '--output-dir' -and ($i + 1) -lt $args.Count) {
        $OutputDir = $args[$i + 1]
        break
    }
}

Write-Host "[INFO] Folder alignment: $AlignmentScript"
Write-Host "[INFO] Python: $($PythonCommand.Source)"

& $PythonCommand.Source $AlignmentScript @args
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
