param(
    [string]$Server = 'msbadmin@192.168.5.9'
)

$ErrorActionPreference = 'Stop'

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$RepoRoot = (Resolve-Path (Join-Path $ScriptDir '..\..')).Path
$ServerScript = Join-Path $ScriptDir 'setup_145_display_ownership_production_deploy_server.sh'

$ExpectedBranch = 'main'
$AcceptedTargetSha = '1b08bdd26156b67ba89ea484fdc035b0b09ffc28'
$MergedMainSha = '80f6ebbcbf2946eddb1b3fe04383a2d43f61b845'
$MigrationPath = 'Setup/Database/052_add_stale_display_ownership_cleanup.sql'
$AcceptedMigrationBlob = '5fbe22f7af8218a0d9ca29ca25d7d53e389e7042'
$AcceptedServerRunnerBlob = 'e12e8f89a3f698e243ca061f02c185fa5c1d78ee'

if (-not (Test-Path -LiteralPath $ServerScript -PathType Leaf)) {
    throw "Required #145 Production deployment runner is missing: $ServerScript"
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
    throw "Local worktree is not clean. Commit/stash/revert local changes before Production deployment.`n$dirty"
}

& git -C $RepoRoot cat-file -e "${AcceptedTargetSha}^{commit}"
if ($LASTEXITCODE -ne 0) {
    throw "Accepted #145 candidate is not available locally: $AcceptedTargetSha"
}

& git -C $RepoRoot merge-base --is-ancestor $AcceptedTargetSha HEAD
if ($LASTEXITCODE -ne 0) {
    throw "Current main does not contain accepted #145 target $AcceptedTargetSha."
}

& git -C $RepoRoot merge-base --is-ancestor $MergedMainSha HEAD
if ($LASTEXITCODE -ne 0) {
    throw "Current main does not contain merged PR #232 commit $MergedMainSha."
}

$migrationBlob = (& git -C $RepoRoot rev-parse "${AcceptedTargetSha}:$MigrationPath").Trim()
if ($LASTEXITCODE -ne 0 -or $migrationBlob -ne $AcceptedMigrationBlob) {
    throw "Accepted migration identity mismatch. Expected blob $AcceptedMigrationBlob, got '$migrationBlob'."
}

$serverBlob = (& git -C $RepoRoot hash-object $ServerScript).Trim()
if ($LASTEXITCODE -ne 0 -or $serverBlob -ne $AcceptedServerRunnerBlob) {
    throw "Production server-runner identity mismatch. Expected blob $AcceptedServerRunnerBlob, got '$serverBlob'."
}

$stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$bundleName = "msb-setup-145-display-ownership-production-$stamp"
$localBundle = Join-Path ([System.IO.Path]::GetTempPath()) $bundleName
$remoteRoot = "/tmp/$bundleName"
$utf8NoBom = [System.Text.UTF8Encoding]::new($false)

Write-Host '========== SETUP #145 DISPLAY OWNERSHIP PRODUCTION DEPLOYMENT =========='
Write-Host "Server:                 $Server"
Write-Host "Accepted runtime SHA:   $AcceptedTargetSha"
Write-Host "Merged PR #232 commit:  $MergedMainSha"
Write-Host "Expected version:       V0.3.16-stale-ownership-cleanup"
Write-Host "Migration:              $MigrationPath"
Write-Host "Migration Git blob:     $AcceptedMigrationBlob"
Write-Host "Server runner blob:     $AcceptedServerRunnerBlob"
Write-Host "Remote root:            $remoteRoot"
Write-Host 'Authority: Gregovate/MSB-Server-Management — docs/server/Production_Database_Change_Deployment_Runbook.md'
Write-Host 'Procedure: one SCP bundle + one foreground SSH bounded Production runner'
Write-Host 'Keep all Production Setup editing paused until the runner returns.'
Write-Host

try {
    New-Item -ItemType Directory -Path $localBundle -Force | Out-Null

    $serverText = [System.IO.File]::ReadAllText($ServerScript)
    $serverText = $serverText.Replace("`r`n", "`n").Replace("`r", "`n")
    $localServer = Join-Path $localBundle 'setup_145_display_ownership_production_deploy_server.sh'
    [System.IO.File]::WriteAllText($localServer, $serverText, $utf8NoBom)

    if ($serverText.Contains("`r")) {
        throw 'Generated Linux deployment runner contains CR characters; refusing to upload.'
    }

    & scp -r $localBundle "${Server}:/tmp/"
    if ($LASTEXITCODE -ne 0) {
        throw "SCP deployment bundle upload failed with exit code $LASTEXITCODE"
    }

    $remoteScript = "$remoteRoot/setup_145_display_ownership_production_deploy_server.sh"
    $remoteCommand = "chmod 700 '$remoteScript' && bash -n '$remoteScript' && timeout --foreground --signal=TERM 3600s bash '$remoteScript'"

    Write-Host
    Write-Host 'Starting bounded Production deployment...'
    & ssh -tt -o ServerAliveInterval=15 -o ServerAliveCountMax=3 $Server $remoteCommand
    $remoteExit = $LASTEXITCODE

    if ($remoteExit -ne 0) {
        throw "Setup #145 Production deployment failed with exit code $remoteExit. Stop and review the retained Production deployment report before any further mutation."
    }

    Write-Host
    Write-Host 'SETUP #145 DISPLAY OWNERSHIP PRODUCTION DEPLOYMENT WRAPPER: PASS'
}
finally {
    if (Test-Path -LiteralPath $localBundle) {
        Remove-Item -LiteralPath $localBundle -Recurse -Force -ErrorAction SilentlyContinue
    }
}
