param(
    [string]$Server = 'msbadmin@192.168.5.9'
)

$ErrorActionPreference = 'Stop'

# MSB Setup #206 — V0.3.20 source-only follow-up Production deployment wrapper.
# Separate from the earlier migration-bearing 063/064 deployment.

$ExpectedBranch = 'deploy/setup-206-material-authority-production'
$AcceptedTargetRef = 'agent/setup-206-tablet-material-audit'
$AcceptedTargetSha = '3cedba88283e4766932ae7905034856a2b9baa00'
$ExpectedLiveSha = '947b86a9598584717167cce094cd78d99e9a71e7'
$ExpectedVersion = 'V0.3.20-material-authority'
$AcceptedServerRunnerBlob = 'd6aa83a1536a9e795702d19b8a8b1428d36680b4'

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$RepoRoot = (Resolve-Path (Join-Path $ScriptDir '..\..')).Path
$ServerScript = Join-Path $ScriptDir 'setup_206_source_only_followup_production_deploy_server.sh'

$origin = (& git -C $RepoRoot remote get-url origin).Trim()
if ($LASTEXITCODE -ne 0 -or $origin -notmatch 'Gregovate/MSB-Production-Database-Project') {
    throw "STOP: wrong repository. origin=$origin"
}

$currentBranch = (& git -C $RepoRoot branch --show-current).Trim()
if ($LASTEXITCODE -ne 0 -or $currentBranch -ne $ExpectedBranch) {
    throw "STOP: run this source-only deployment wrapper from '$ExpectedBranch'. Current branch: '$currentBranch'"
}

$dirty = (& git -C $RepoRoot status --porcelain)
if ($LASTEXITCODE -ne 0 -or $dirty) {
    throw "STOP: local repository is not clean. $dirty"
}

if (-not (Test-Path -LiteralPath $ServerScript -PathType Leaf)) {
    throw "STOP: source-only Production server runner is missing: $ServerScript"
}

& git -C $RepoRoot fetch origin ($AcceptedTargetRef + ':refs/remotes/origin/' + $AcceptedTargetRef)
if ($LASTEXITCODE -ne 0) {
    throw "STOP: unable to fetch accepted target ref $AcceptedTargetRef"
}

& git -C $RepoRoot cat-file -e ($AcceptedTargetSha + '^{commit}')
if ($LASTEXITCODE -ne 0) {
    throw "STOP: accepted browser-reviewed target is unavailable locally: $AcceptedTargetSha"
}

& git -C $RepoRoot merge-base --is-ancestor $AcceptedTargetSha ('origin/' + $AcceptedTargetRef)
if ($LASTEXITCODE -ne 0) {
    throw "STOP: accepted target $AcceptedTargetSha is not contained in origin/$AcceptedTargetRef"
}

$serverBlobActual = (& git -C $RepoRoot hash-object $ServerScript).Trim()
if ($LASTEXITCODE -ne 0 -or $serverBlobActual -ne $AcceptedServerRunnerBlob) {
    throw "STOP: Production server-runner identity mismatch. Expected $AcceptedServerRunnerBlob, got '$serverBlobActual'."
}

$backend = ((& git -C $RepoRoot show ($AcceptedTargetSha + ':Setup/Application/production_backend.py')) | Out-String)
if ($LASTEXITCODE -ne 0 -or $backend -notmatch 'PRODUCTION_VERSION = "V0\.3\.20-material-authority"') {
    throw 'STOP: accepted target does not contain server version V0.3.20-material-authority.'
}

$guard = ((& git -C $RepoRoot show ($AcceptedTargetSha + ':Setup/Application/setup_catalog_dirty_guard.js')) | Out-String)
if ($LASTEXITCODE -ne 0 -or $guard -notmatch "CLIENT_BUILD = 'V0\.3\.20-material-authority'" -or -not $guard.Contains("badge.textContent = ok ? 'Client V0.3.20'")) {
    throw 'STOP: accepted target does not contain the healthy V0.3.20 client badge correction.'
}

$productionHtml = ((& git -C $RepoRoot show ($AcceptedTargetSha + ':Setup/Application/production.html')) | Out-String)
foreach ($pin in @(
    'setup_catalog_dirty_guard.js?v=2026-09-29.1',
    'setup_extra_materials.js?v=2026-09-29.1',
    'setup_next_pass.js?v=2026-09-29.1'
)) {
    if (-not $productionHtml.Contains($pin)) {
        throw "STOP: accepted Production shell is missing asset pin $pin"
    }
}

$kitHtml = ((& git -C $RepoRoot show ($AcceptedTargetSha + ':Setup/Application/kit_inventory.html')) | Out-String)
foreach ($pin in @(
    'setup_kit_inventory.css?v=2026-09-29.1',
    'setup_kit_inventory.js?v=2026-09-29.1'
)) {
    if (-not $kitHtml.Contains($pin)) {
        throw "STOP: accepted Kit Inventory shell is missing asset pin $pin"
    }
}

$nextPass = ((& git -C $RepoRoot show ($AcceptedTargetSha + ':Setup/Application/setup_next_pass.js')) | Out-String)
if (-not $nextPass.Contains("organizationStatus: 'idle'") -or -not $nextPass.Contains('function renderNextLibraryReadiness()') -or -not $nextPass.Contains('Retry Catalog Organization') -or $nextPass.Contains('priorNextRenderLibrary')) {
    throw 'STOP: accepted target does not contain the deterministic Catalog organization gate.'
}

$stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$bundleName = "msb-setup-206-source-only-followup-$stamp"
$localBundle = Join-Path ([System.IO.Path]::GetTempPath()) $bundleName
$remoteRoot = "/tmp/$bundleName"
$utf8NoBom = [System.Text.UTF8Encoding]::new($false)

Write-Host '========== SETUP #206 V0.3.20 SOURCE-ONLY FOLLOW-UP PRODUCTION DEPLOYMENT =========='
Write-Host "Server:                    $Server"
Write-Host "Deployment tooling branch: $ExpectedBranch"
Write-Host "Accepted target ref:       $AcceptedTargetRef"
Write-Host "Accepted target SHA:       $AcceptedTargetSha"
Write-Host "Expected live SHA:         $ExpectedLiveSha"
Write-Host "Expected version:          $ExpectedVersion"
Write-Host "Server runner blob:        $AcceptedServerRunnerBlob"
Write-Host "Remote bundle:             $remoteRoot"
Write-Host 'Authority: Gregovate/MSB-Server-Management — docs/server/Setup_Source_Only_Application_Deployment_Runbook.md'
Write-Host 'Database migration: NONE'
Write-Host
Write-Host 'IMPORTANT: this command advances the live Setup application checkout and restarts only msb-setup.service.'
Write-Host 'Keep Setup editing paused while the bounded deployment runs.'
Write-Host

try {
    New-Item -ItemType Directory -Path $localBundle -Force | Out-Null

    $serverText = [System.IO.File]::ReadAllText($ServerScript)
    $serverText = $serverText.Replace([string][char]13 + [string][char]10, [string][char]10).Replace([string][char]13, [string][char]10)
    $localServer = Join-Path $localBundle 'setup_206_source_only_followup_production_deploy_server.sh'
    [System.IO.File]::WriteAllText($localServer, $serverText, $utf8NoBom)

    if ($serverText.Contains([string][char]13)) {
        throw 'STOP: generated Linux deployment runner contains CR characters.'
    }

    & scp -r $localBundle ($Server + ':/tmp/')
    if ($LASTEXITCODE -ne 0) {
        throw "SCP deployment bundle upload failed with exit code $LASTEXITCODE"
    }

    $remoteScript = "$remoteRoot/setup_206_source_only_followup_production_deploy_server.sh"
    $remoteCommand = "chmod 700 '$remoteScript' && bash -n '$remoteScript' && timeout --foreground --signal=TERM 3600s bash '$remoteScript'"

    Write-Host
    Write-Host 'Starting bounded #206 source-only Production deployment...'
    Write-Host

    & ssh -tt -o ServerAliveInterval=15 -o ServerAliveCountMax=3 $Server $remoteCommand
    $remoteExit = $LASTEXITCODE

    if ($remoteExit -ne 0) {
        throw "Setup #206 source-only Production deployment stopped with exit code $remoteExit. Review the retained deployment report before any further Production mutation."
    }

    Write-Host
    Write-Host 'SETUP #206 V0.3.20 SOURCE-ONLY FOLLOW-UP PRODUCTION DEPLOYMENT WRAPPER: PASS'
}
finally {
    if (Test-Path -LiteralPath $localBundle) {
        Remove-Item -LiteralPath $localBundle -Recurse -Force -ErrorAction SilentlyContinue
    }
}
