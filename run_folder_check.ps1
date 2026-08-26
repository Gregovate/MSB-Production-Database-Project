# MSB LOR folder-alignment launcher for Windows
#
# Purpose:
#   Run the current read-only Google Shared Drive folder-alignment report
#   from the repository root, then open the newest generated HTML report.
#
# Optional environment variables:
#   MSB_FOLDER_ALIGNMENT_DB
#   MSB_FOLDER_ALIGNMENT_DRIVE_ROOT
#   MSB_FOLDER_ALIGNMENT_OUTPUT_DIR

$ErrorActionPreference = 'Stop'

$RepoRoot = $PSScriptRoot
$AlignmentScript = Join-Path $RepoRoot 'Docs\01_LOR_System\02_Data_Extraction\Folder_Alignment\folder_alignment.py'
#$DefaultOutputDir = 'G:\Shared drives\MSB Database\Database Previews V6.6.4\reports\google-drive-alignment'

if (-not (Test-Path -LiteralPath $AlignmentScript -PathType Leaf)) {
    Write-Error "Folder Alignment script not found: $AlignmentScript"
    exit 2
}

$PythonCommand = Get-Command python -ErrorAction SilentlyContinue

if (-not $PythonCommand) {
    $PythonCommand = Get-Command python3 -ErrorAction SilentlyContinue
}

if (-not $PythonCommand) {
    Write-Error "Python 3 was not found in the current PowerShell environment."
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

$OutputDir = if ($env:MSB_FOLDER_ALIGNMENT_OUTPUT_DIR) {
    $env:MSB_FOLDER_ALIGNMENT_OUTPUT_DIR
}
else {
    $DefaultOutputDir
}

# Explicit command-line --output-dir overrides the environment/default value.
for ($i = 0; $i -lt $args.Count; $i++) {
    if ($args[$i] -eq '--output-dir' -and ($i + 1) -lt $args.Count) {
        $OutputDir = $args[$i + 1]
        break
    }
}

Write-Host "[INFO] Folder Alignment: $AlignmentScript"
Write-Host "[INFO] Python: $($PythonCommand.Source)"

$RunStarted = Get-Date

& $PythonCommand.Source $AlignmentScript @PythonArgs @args
$AlignmentExitCode = $LASTEXITCODE

if ($null -eq $AlignmentExitCode) {
    $AlignmentExitCode = 0
}

if ($AlignmentExitCode -eq 0) {

    if (Test-Path -LiteralPath $OutputDir -PathType Container) {

        # Prefer an HTML file created/updated during this run.
        $HtmlReport = Get-ChildItem -LiteralPath $OutputDir -File -Filter '*.html' |
        Where-Object {
            $_.LastWriteTime -ge $RunStarted.AddSeconds(-2)
        } |
        Sort-Object LastWriteTime -Descending |
        Select-Object -First 1

        # Fallback to newest HTML report in the directory.
        if (-not $HtmlReport) {
            $HtmlReport = Get-ChildItem -LiteralPath $OutputDir -File -Filter '*.html' |
            Sort-Object LastWriteTime -Descending |
            Select-Object -First 1
        }

        if ($HtmlReport) {
            Write-Host "[INFO] Opening HTML report: $($HtmlReport.FullName)"
            Start-Process $HtmlReport.FullName
        }
        else {
            Write-Warning "Folder Alignment completed, but no HTML report was found in: $OutputDir"
        }
    }
    else {
        Write-Warning "Folder Alignment completed, but the output folder was not found: $OutputDir"
    }
}

exit $AlignmentExitCode