param(
    [string]$Server = 'msbadmin@192.168.5.9',
    [Parameter(Mandatory=$true)]
    [int]$PreviewPort,
    [string]$PreviewEmail = 'gliebig@sheboyganlights.org'
)

$ErrorActionPreference = 'Stop'

# Exact application candidate approved for Planning Summary browser/print review.
# This wrapper deliberately reuses the established source-only disposable-clone
# preview harness instead of creating another server-side preview implementation.
$CandidateSha = 'c874e04790916cfc580c17b6150525eb7a23f84c'
$ExpectedBranch = 'agent/setup-122-planning-summary-print'

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$repoRoot = (Resolve-Path (Join-Path $scriptDir '..\..')).Path
$sourceLauncher = Join-Path $scriptDir 'run_setup_source_only_browser_preview.ps1'

if (-not (Test-Path -LiteralPath $sourceLauncher -PathType Leaf)) {
    throw "Required source-only Setup preview launcher is missing: $sourceLauncher"
}

# Keep the generated launcher outside the repository so the source-only harness
# can still enforce a clean worktree before opening the disposable preview.
$tempLauncher = Join-Path ([System.IO.Path]::GetTempPath()) ("msb-setup-planning-summary-preview-{0}.ps1" -f (Get-Date -Format 'yyyyMMdd-HHmmss'))
$launcherText = [System.IO.File]::ReadAllText($sourceLauncher)

$replacements = @(
    @("`$CandidateSha = '51c739bd85115c9f5d2853763e8e1450ac381407'", "`$CandidateSha = '$CandidateSha'"),
    @("`$ExpectedBranch = 'agent/setup-session-production-foundation'", "`$ExpectedBranch = '$ExpectedBranch'"),
    @('`$ScriptDir = Split-Path -Parent `$MyInvocation.MyCommand.Path', "`$ScriptDir = '$($scriptDir.Replace("'", "''"))'")
)

foreach ($pair in $replacements) {
    $needle = $pair[0]
    $replacement = $pair[1]
    if (-not $launcherText.Contains($needle)) {
        throw "Planning Summary preview launcher could not find expected source-only harness text: $needle"
    }
    $launcherText = $launcherText.Replace($needle, $replacement)
}

$utf8NoBom = New-Object System.Text.UTF8Encoding($false)
[System.IO.File]::WriteAllText($tempLauncher, $launcherText, $utf8NoBom)

try {
    Write-Host '========== SETUP #122 PLANNING SUMMARY BROWSER PREVIEW =========='
    Write-Host "Candidate SHA: $CandidateSha"
    Write-Host "Required branch: $ExpectedBranch"
    Write-Host "Preview URL: http://127.0.0.1:$PreviewPort/"
    Write-Host
    Write-Host 'This reuses the established disposable current-Production clone harness.'
    Write-Host 'Production Setup data and /opt/msb-setup remain unchanged.'
    Write-Host

    & $tempLauncher -Server $Server -PreviewPort $PreviewPort -PreviewEmail $PreviewEmail
    if ($LASTEXITCODE -ne 0) {
        throw "Planning Summary browser preview exited with code $LASTEXITCODE"
    }
}
finally {
    Remove-Item -LiteralPath $tempLauncher -Force -ErrorAction SilentlyContinue
}
