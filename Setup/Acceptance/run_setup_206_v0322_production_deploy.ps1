param(
    [string]$Server = 'msbadmin@192.168.5.9'
)

$ErrorActionPreference = 'Stop'

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$RepoRoot = (Resolve-Path (Join-Path $ScriptDir '..\..')).Path
$ServerScript = Join-Path $ScriptDir 'setup_206_v0322_production_deploy_server.sh'

$ExpectedBranch = 'main'
$AcceptedTargetSha = '6f53d7f0c4b15f7175e773a2069595eef3f0e698'
$MigrationPath = 'Setup/Database/063_add_setup_pick_list_delay.sql'
$AcceptedMigrationBlob = '45d1f71e226ab9e358e40f331945135cbe19cfb8'
$AcceptedServerRunnerBlob = 'c104f9b51ea258720bd13ae0f2d125167f30be6e'

if (-not (Test-Path -LiteralPath $ServerScript -PathType Leaf)) {
    throw "Required #206 Production deployment runner is missing: $ServerScript"
}

$currentBranch = (& git -C $RepoRoot branch --show-current).Trim()
if ($LASTEXITCODE -ne 0 -or $currentBranch -ne $ExpectedBranch) {
    throw "Run this deployment wrapper from merged branch $ExpectedBranch. Current branch: $currentBranch"
}

$dirty = (& git -C $RepoRoot status --porcelain)
if ($LASTEXITCODE -ne 0) {
    throw 'Unable to verify local Git worktree status.'
}
if ($dirty) {
    throw "Local worktree is not clean. Commit/stash/revert local changes before Production deployment. $dirty"
}

& git -C $RepoRoot cat-file -e "${AcceptedTargetSha}^{commit}"
if ($LASTEXITCODE -ne 0) {
    throw "Accepted #206 V0.3.22 deployment target is not available locally: $AcceptedTargetSha"
}

& git -C $RepoRoot merge-base --is-ancestor $AcceptedTargetSha HEAD
if ($LASTEXITCODE -ne 0) {
    throw "Current main does not contain accepted #206 deployment target $AcceptedTargetSha."
}

$migrationBlob = (& git -C $RepoRoot rev-parse "${AcceptedTargetSha}:$MigrationPath").Trim()
if ($LASTEXITCODE -ne 0 -or $migrationBlob -ne $AcceptedMigrationBlob) {
    throw "Accepted migration identity mismatch. Expected blob $AcceptedMigrationBlob, got '$migrationBlob'."
}

$serverBlob = (& git -C $RepoRoot hash-object $ServerScript).Trim()
if ($LASTEXITCODE -ne 0 -or $serverBlob -ne $AcceptedServerRunnerBlob) {
    throw "Production server-runner identity mismatch. Expected blob $AcceptedServerRunnerBlob, got '$serverBlob'."
}

$backendVersion = ((& git -C $RepoRoot show "${AcceptedTargetSha}:Setup/Application/production_backend.py") | Out-String)
if ($LASTEXITCODE -ne 0 -or $backendVersion -notmatch 'PRODUCTION_VERSION = "V0\.3\.22-pick-list-delay"') {
    throw 'Accepted target does not contain Setup server version V0.3.22-pick-list-delay.'
}
$clientVersion = ((& git -C $RepoRoot show "${AcceptedTargetSha}:Setup/Application/setup_catalog_dirty_guard.js") | Out-String)
if ($LASTEXITCODE -ne 0 -or $clientVersion -notmatch "CLIENT_BUILD = 'V0\.3\.22-pick-list-delay'") {
    throw 'Accepted target does not contain Setup client build V0.3.22-pick-list-delay.'
}

$candidateHtml = ((& git -C $RepoRoot show "${AcceptedTargetSha}:Setup/Application/production.html") | Out-String)
if ($LASTEXITCODE -ne 0 -or -not $candidateHtml.Contains('setup_catalog_dirty_guard.js?v=2026-09-30.1')) {
    throw 'Accepted target does not contain the V0.3.22 dirty-guard asset pin.'
}

$stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$bundleName = "msb-setup-206-v0322-production-$stamp"
$localBundle = Join-Path ([System.IO.Path]::GetTempPath()) $bundleName
$remoteRoot = "/tmp/$bundleName"
$utf8NoBom = [System.Text.UTF8Encoding]::new($false)
$cr = [string][char]13
$lf = [string][char]10

Write-Host '========== SETUP #206 V0.3.22 PICK LIST DELAY PRODUCTION DEPLOYMENT =========='
Write-Host "Server:                    $Server"
Write-Host "Deployment target SHA:     $AcceptedTargetSha"
Write-Host 'Expected pre-version:      V0.3.21-scheduling-gates'
Write-Host 'Expected post-version:     V0.3.22-pick-list-delay'
Write-Host "Migration:                 $MigrationPath"
Write-Host "Migration Git blob:        $AcceptedMigrationBlob"
Write-Host "Server runner blob:        $AcceptedServerRunnerBlob"
Write-Host "Remote root:               $remoteRoot"
Write-Host 'Authority: Gregovate/MSB-Server-Management — docs/server/Production_Database_Change_Deployment_Runbook.md'
Write-Host 'Procedure: one SCP bundle + one foreground SSH bounded Production runner'
Write-Host 'Keep Setup editing paused while the bounded deployment runner is active.'
Write-Host

try {
    New-Item -ItemType Directory -Path $localBundle -Force | Out-Null

    $serverText = [System.IO.File]::ReadAllText($ServerScript)
    $serverText = $serverText.Replace($cr + $lf, $lf).Replace($cr, $lf)
    $localServer = Join-Path $localBundle 'setup_206_v0322_production_deploy_server.sh'
    [System.IO.File]::WriteAllText($localServer, $serverText, $utf8NoBom)

    if ($serverText.Contains($cr)) {
        throw 'Generated Linux deployment runner contains CR characters; refusing to upload.'
    }

    & scp -r $localBundle "${Server}:/tmp/"
    if ($LASTEXITCODE -ne 0) {
        throw "SCP deployment bundle upload failed with exit code $LASTEXITCODE"
    }

    $remoteScript = "$remoteRoot/setup_206_v0322_production_deploy_server.sh"
    $remoteCommand = "chmod 700 '$remoteScript' && bash -n '$remoteScript' && timeout --foreground --signal=TERM 3600s bash '$remoteScript'"

    Write-Host
    Write-Host 'Starting bounded Production deployment...'
    & ssh -tt -o ServerAliveInterval=15 -o ServerAliveCountMax=3 $Server $remoteCommand
    $remoteExit = $LASTEXITCODE

    if ($remoteExit -ne 0) {
        throw "Setup #206 V0.3.22 Production deployment failed with exit code $remoteExit. Stop and review the retained Production deployment report before any further mutation."
    }

    Write-Host
    Write-Host 'SETUP #206 V0.3.22 PICK LIST DELAY PRODUCTION DEPLOYMENT WRAPPER: PASS'
}
finally {
    if (Test-Path -LiteralPath $localBundle) {
        Remove-Item -LiteralPath $localBundle -Recurse -Force -ErrorAction SilentlyContinue
    }
}
