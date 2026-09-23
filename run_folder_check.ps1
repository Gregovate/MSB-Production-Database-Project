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
    $null
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
$RunOutput = [System.Collections.Generic.List[string]]::new()

& $PythonCommand.Source $AlignmentScript @PythonArgs @args 2>&1 |
ForEach-Object {
    $line = [string]$_
    $RunOutput.Add($line)
    Write-Host $line
}
$AlignmentExitCode = $LASTEXITCODE

if ($null -eq $AlignmentExitCode) {
    $AlignmentExitCode = 0
}

if ($AlignmentExitCode -eq 0) {
    $HtmlPaths = [System.Collections.Generic.List[string]]::new()

    foreach ($line in $RunOutput) {
        if ($line -match '^\[INFO\] (?:HTML|Procedure Inventory HTML):\s+(.+\.html)\s*
            $candidate = $Matches[1].Trim()
            if (-not $HtmlPaths.Contains($candidate)) {
                $HtmlPaths.Add($candidate)
            }
        }
    }

    # Backward-compatible fallback only when an explicit output directory was
    # supplied and the Python script did not print an HTML path.
    if ($HtmlPaths.Count -eq 0 -and
        -not [string]::IsNullOrWhiteSpace($OutputDir) -and
        (Test-Path -LiteralPath $OutputDir -PathType Container)) {

        $FallbackReports = Get-ChildItem -LiteralPath $OutputDir -File -Filter '*.html' |
            Where-Object {
                $_.LastWriteTime -ge $RunStarted.AddSeconds(-2)
            } |
            Sort-Object LastWriteTime

        foreach ($report in $FallbackReports) {
            if (-not $HtmlPaths.Contains($report.FullName)) {
                $HtmlPaths.Add($report.FullName)
            }
        }
    }

    if ($HtmlPaths.Count -eq 0) {
        Write-Warning "Folder Alignment completed, but no generated HTML report path was returned."
    }
    else {
        foreach ($HtmlPath in $HtmlPaths) {
            if (Test-Path -LiteralPath $HtmlPath -PathType Leaf) {
                Write-Host "[INFO] Opening HTML report: $HtmlPath"
                Start-Process $HtmlPath
            }
            else {
                Write-Warning "Generated HTML report was not found: $HtmlPath"
            }
        }
    }
}

exit $AlignmentExitCode) {
            $candidate = $Matches[1].Trim()
            if (-not $HtmlPaths.Contains($candidate)) {
                $HtmlPaths.Add($candidate)
            }
        }
    }

    # Backward-compatible fallback only when an explicit output directory was
    # supplied and the Python script did not print an HTML path.
    if ($HtmlPaths.Count -eq 0 -and
        -not [string]::IsNullOrWhiteSpace($OutputDir) -and
        (Test-Path -LiteralPath $OutputDir -PathType Container)) {

        $FallbackReports = Get-ChildItem -LiteralPath $OutputDir -File -Filter '*.html' |
            Where-Object {
                $_.LastWriteTime -ge $RunStarted.AddSeconds(-2)
            } |
            Sort-Object LastWriteTime

        foreach ($report in $FallbackReports) {
            if (-not $HtmlPaths.Contains($report.FullName)) {
                $HtmlPaths.Add($report.FullName)
            }
        }
    }

    if ($HtmlPaths.Count -eq 0) {
        Write-Warning "Folder Alignment completed, but no generated HTML report path was returned."
    }
    else {
        foreach ($HtmlPath in $HtmlPaths) {
            if (Test-Path -LiteralPath $HtmlPath -PathType Leaf) {
                Write-Host "[INFO] Opening HTML report: $HtmlPath"
                Start-Process $HtmlPath
            }
            else {
                Write-Warning "Generated HTML report was not found: $HtmlPath"
            }
        }
    }
}

exit $AlignmentExitCode