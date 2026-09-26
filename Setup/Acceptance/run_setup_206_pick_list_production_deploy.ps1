param(
    [string]$Server = 'msbadmin@192.168.5.9'
)

$ErrorActionPreference = 'Stop'

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$RepoRoot = (Resolve-Path (Join-Path $ScriptDir '..\..')).Path
$ServerScript = Join-Path $ScriptDir 'setup_206_pick_list_production_deploy_server.sh'

$ExpectedBranch = 'main'
$AcceptedBrowserSha = '59148515ab361a297cd7107184662648cd10a60d'
$AcceptedTargetSha = 'a084b0130eae4547f26f3aaddf181b644eccd0b9'
$MigrationPath = 'Setup/Database/060_add_setup_pick_list_manager_override.sql'
$AcceptedMigrationBlob = '72137b49d78da26647e539769973641b24ee1c57'
$AcceptedServerRunnerBlob = '4160c4f12d264d83e23f82bce6fa0b969f751ef9'

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

& git -C $RepoRoot cat-file -e "${AcceptedBrowserSha}^{commit}"
if ($LASTEXITCODE -ne 0) {
    throw "Accepted #206 browser candidate is not available locally: $AcceptedBrowserSha"
}
& git -C $RepoRoot cat-file -e "${AcceptedTargetSha}^{commit}"
if ($LASTEXITCODE -ne 0) {
    throw "Accepted #206 V0.3.19 deployment target is not available locally: $AcceptedTargetSha"
}

& git -C $RepoRoot merge-base --is-ancestor $AcceptedBrowserSha $AcceptedTargetSha
if ($LASTEXITCODE -ne 0) {
    throw "V0.3.19 deployment target does not contain accepted browser candidate $AcceptedBrowserSha."
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

$backendVersion = (& git -C $RepoRoot show "${AcceptedTargetSha}:Setup/Application/production_backend.py")
if ($LASTEXITCODE -ne 0 -or $backendVersion -notmatch 'PRODUCTION_VERSION = "V0\.3\.19-pick-list"') {
    throw 'Accepted target does not contain Setup server version V0.3.19-pick-list.'
}
$clientVersion = (& git -C $RepoRoot show "${AcceptedTargetSha}:Setup/Application/setup_catalog_dirty_guard.js")
if ($LASTEXITCODE -ne 0 -or $clientVersion -notmatch "CLIENT_BUILD = 'V0\.3\.19-pick-list'") {
    throw 'Accepted target does not contain Setup client build V0.3.19-pick-list.'
}

$stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$bundleName = "msb-setup-206-pick-list-production-$stamp"
$localBundle = Join-Path ([System.IO.Path]::GetTempPath()) $bundleName
$remoteRoot = "/tmp/$bundleName"
$utf8NoBom = [System.Text.UTF8Encoding]::new($false)
$cr = [string][char]13
$lf = [string][char]10

Write-Host '========== SETUP #206 PICK LIST PRODUCTION DEPLOYMENT =========='
Write-Host "Server:                    $Server"
Write-Host "Browser-accepted SHA:      $AcceptedBrowserSha"
Write-Host "Deployment target SHA:     $AcceptedTargetSha"
Write-Host 'Expected pre-version:      V0.3.18-scheduling-board'
Write-Host 'Expected post-version:     V0.3.19-pick-list'
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
    $localServer = Join-Path $localBundle 'setup_206_pick_list_production_deploy_server.sh'
    [System.IO.File]::WriteAllText($localServer, $serverText, $utf8NoBom)

    if ($serverText.Contains($cr)) {
        throw 'Generated Linux deployment runner contains CR characters; refusing to upload.'
    }

    & scp -r $localBundle "${Server}:/tmp/"
    if ($LASTEXITCODE -ne 0) {
        throw "SCP deployment bundle upload failed with exit code $LASTEXITCODE"
    }

    $remoteScript = "$remoteRoot/setup_206_pick_list_production_deploy_server.sh"
    $remoteCommand = "chmod 700 '$remoteScript' && bash -n '$remoteScript' && timeout --foreground --signal=TERM 3600s bash '$remoteScript'"

    Write-Host
    Write-Host 'Starting bounded Production deployment...'
    & ssh -tt -o ServerAliveInterval=15 -o ServerAliveCountMax=3 $Server $remoteCommand
    $remoteExit = $LASTEXITCODE

    if ($remoteExit -ne 0) {
        throw "Setup #206 Production deployment failed with exit code $remoteExit. Stop and review the retained Production deployment report before any further mutation."
    }

    Write-Host
    Write-Host 'SETUP #206 PICK LIST PRODUCTION DEPLOYMENT WRAPPER: PASS'
}
finally {
    if (Test-Path -LiteralPath $localBundle) {
        Remove-Item -LiteralPath $localBundle -Recurse -Force -ErrorAction SilentlyContinue
    }
}
