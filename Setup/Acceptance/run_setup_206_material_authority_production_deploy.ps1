param(
    [string]$Server = 'msbadmin@192.168.5.9'
)

$ErrorActionPreference = 'Stop'

# MSB Setup #206 — V0.3.20 material-authority Production deployment wrapper.
# This wrapper packages one reviewed Linux runner and starts one foreground SSH session.
# It does NOT run unless invoked explicitly by the operator.

$ExpectedBranch = 'deploy/setup-206-material-authority-production'
$AcceptedTargetSha = '947b86a9598584717167cce094cd78d99e9a71e7'
$AcceptedServerRunnerBlob = '2aef8ae83f92f4ff92f9641568bf7e09549db932'
$Migration063Path = 'Setup/Database/063_harden_setup_extra_material_requirement_lifecycle.sql'
$Migration063Blob = '2c686ad3ae55b09a9cf3629b9ef01bb0b83dd447'
$Migration064Path = 'Setup/Database/064_add_setup_extra_material_requirement_restore.sql'
$Migration064Blob = '50de44a51b44eb008e826a7ef76b2023fafa29f7'
$ExpectedVersion = 'V0.3.20-material-authority'

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$RepoRoot = (Resolve-Path (Join-Path $ScriptDir '..\..')).Path
$ServerScript = Join-Path $ScriptDir 'setup_206_material_authority_production_deploy_server.sh'

$origin = (& git -C $RepoRoot remote get-url origin).Trim()
if ($LASTEXITCODE -ne 0 -or $origin -notmatch 'Gregovate/MSB-Production-Database-Project') {
    throw "STOP: wrong repository. origin=$origin"
}

$currentBranch = (& git -C $RepoRoot branch --show-current).Trim()
if ($LASTEXITCODE -ne 0 -or $currentBranch -ne $ExpectedBranch) {
    throw "STOP: run from '$ExpectedBranch'. Current branch: '$currentBranch'"
}

$dirty = (& git -C $RepoRoot status --porcelain)
if ($LASTEXITCODE -ne 0 -or $dirty) {
    throw "STOP: local repository is not clean. $dirty"
}

if (-not (Test-Path -LiteralPath $ServerScript -PathType Leaf)) {
    throw "STOP: Production server runner is missing: $ServerScript"
}

& git -C $RepoRoot cat-file -e ($AcceptedTargetSha + '^{commit}')
if ($LASTEXITCODE -ne 0) {
    throw "STOP: accepted target is unavailable locally: $AcceptedTargetSha"
}

& git -C $RepoRoot merge-base --is-ancestor $AcceptedTargetSha HEAD
if ($LASTEXITCODE -ne 0) {
    throw "STOP: deployment-tooling branch is not based on accepted target $AcceptedTargetSha"
}

foreach ($item in @(
    @($Migration063Path, $Migration063Blob),
    @($Migration064Path, $Migration064Blob)
)) {
    $actual = (& git -C $RepoRoot rev-parse ($AcceptedTargetSha + ':' + $item[0])).Trim()
    if ($LASTEXITCODE -ne 0 -or $actual -ne $item[1]) {
        throw "STOP: migration identity mismatch for $($item[0]). Expected $($item[1]), got '$actual'."
    }
}

$serverBlob = (& git -C $RepoRoot hash-object $ServerScript).Trim()
if ($LASTEXITCODE -ne 0 -or $serverBlob -ne $AcceptedServerRunnerBlob) {
    throw "STOP: Production server-runner identity mismatch. Expected $AcceptedServerRunnerBlob, got '$serverBlob'."
}

$backend = ((& git -C $RepoRoot show ($AcceptedTargetSha + ':Setup/Application/production_backend.py')) | Out-String)
if ($LASTEXITCODE -ne 0 -or $backend -notmatch 'PRODUCTION_VERSION = "V0\.3\.20-material-authority"') {
    throw 'STOP: accepted target does not contain server version V0.3.20-material-authority.'
}

$client = ((& git -C $RepoRoot show ($AcceptedTargetSha + ':Setup/Application/setup_catalog_dirty_guard.js')) | Out-String)
if ($LASTEXITCODE -ne 0 -or $client -notmatch "CLIENT_BUILD = 'V0\.3\.20-material-authority'") {
    throw 'STOP: accepted target does not contain client build V0.3.20-material-authority.'
}

$productionHtml = ((& git -C $RepoRoot show ($AcceptedTargetSha + ':Setup/Application/production.html')) | Out-String)
if ($LASTEXITCODE -ne 0 -or -not $productionHtml.Contains('setup_catalog_dirty_guard.js?v=2026-09-28.1') -or -not $productionHtml.Contains('setup_extra_materials.js?v=2026-09-28.3')) {
    throw 'STOP: accepted V0.3.20 Production shell asset pins are missing.'
}

$kitHtml = ((& git -C $RepoRoot show ($AcceptedTargetSha + ':Setup/Application/kit_inventory.html')) | Out-String)
if ($LASTEXITCODE -ne 0 -or -not $kitHtml.Contains('setup_kit_inventory.css?v=2026-09-28.2') -or -not $kitHtml.Contains('setup_kit_inventory.js?v=2026-09-28.3')) {
    throw 'STOP: accepted Kit Inventory asset pins are missing.'
}

$stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$bundleName = "msb-setup-206-material-authority-production-$stamp"
$localBundle = Join-Path ([System.IO.Path]::GetTempPath()) $bundleName
$remoteRoot = "/tmp/$bundleName"
$utf8NoBom = [System.Text.UTF8Encoding]::new($false)

Write-Host '========== SETUP #206 V0.3.20 MATERIAL AUTHORITY PRODUCTION DEPLOYMENT =========='
Write-Host "Server:                    $Server"
Write-Host "Deployment tooling branch: $ExpectedBranch"
Write-Host "Frozen accepted SHA:       $AcceptedTargetSha"
Write-Host "Expected version:          $ExpectedVersion"
Write-Host "Migration 063:             $Migration063Path"
Write-Host "Migration 064:             $Migration064Path"
Write-Host "Server runner blob:        $AcceptedServerRunnerBlob"
Write-Host "Remote bundle:             $remoteRoot"
Write-Host 'Authority: Gregovate/MSB-Server-Management — docs/server/Production_Database_Change_Deployment_Runbook.md'
Write-Host
Write-Host 'IMPORTANT: this command MUTATES Production. Keep Setup editing paused while it runs.'
Write-Host

try {
    New-Item -ItemType Directory -Path $localBundle -Force | Out-Null

    $serverText = [System.IO.File]::ReadAllText($ServerScript)
    $serverText = $serverText.Replace([string][char]13 + [string][char]10, [string][char]10).Replace([string][char]13, [string][char]10)
    $localServer = Join-Path $localBundle 'setup_206_material_authority_production_deploy_server.sh'
    [System.IO.File]::WriteAllText($localServer, $serverText, $utf8NoBom)

    if ($serverText.Contains([string][char]13)) {
        throw 'STOP: generated Linux deployment runner contains CR characters.'
    }

    & scp -r $localBundle ($Server + ':/tmp/')
    if ($LASTEXITCODE -ne 0) {
        throw "SCP deployment bundle upload failed with exit code $LASTEXITCODE"
    }

    $remoteScript = "$remoteRoot/setup_206_material_authority_production_deploy_server.sh"
    $remoteCommand = "chmod 700 '$remoteScript' && bash -n '$remoteScript' && timeout --foreground --signal=TERM 3600s bash '$remoteScript'"

    Write-Host
    Write-Host 'Starting bounded V0.3.20 Production deployment...'
    Write-Host

    & ssh -tt -o ServerAliveInterval=15 -o ServerAliveCountMax=3 $Server $remoteCommand
    $remoteExit = $LASTEXITCODE

    if ($remoteExit -ne 0) {
        throw "Setup #206 V0.3.20 Production deployment stopped with exit code $remoteExit. Review the retained server deployment report before further mutation."
    }

    Write-Host
    Write-Host 'SETUP #206 V0.3.20 MATERIAL AUTHORITY PRODUCTION DEPLOYMENT WRAPPER: PASS'
}
finally {
    if (Test-Path -LiteralPath $localBundle) {
        Remove-Item -LiteralPath $localBundle -Recurse -Force -ErrorAction SilentlyContinue
    }
}
