param(
    [string]$Server = 'msbadmin@192.168.5.9',
    [string]$OperatorEmail = 'gliebig@sheboyganlights.org'
)

$ErrorActionPreference = 'Stop'

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$RepoRoot = (Resolve-Path (Join-Path $ScriptDir '..\..')).Path
$ServerScript = Join-Path $ScriptDir 'setup_122_reusable_name_sync_production_deploy_server.sh'

$ExpectedBranch = 'main'
$AcceptedCandidateSha = 'dd4c80fe3180df8f99cb88be451c803d60b5774f'
$MergedFeatureSha = '0462d9318eb97e04c238c5e5b8815ec2f266bfe0'
$MigrationPath = 'Setup/Database/059_sync_reusable_task_name_to_open_annual.sql'
$AcceptedMigrationBlob = '1be0837c88c243fd54763817983be23fa10853bd'
$AcceptedServerRunnerBlob = 'ae1df70248865de3442d55bec5edba047aefe1b7'

if (-not (Test-Path -LiteralPath $ServerScript -PathType Leaf)) {
    throw "Required #122 reusable-name Production deployment runner is missing: $ServerScript"
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
    throw "Local worktree is not clean. Commit/stash/revert before Production deployment. $dirty"
}

foreach ($sha in @($AcceptedCandidateSha, $MergedFeatureSha)) {
    & git -C $RepoRoot cat-file -e "${sha}^{commit}"
    if ($LASTEXITCODE -ne 0) {
        throw "Required accepted/merged commit is not available locally: $sha"
    }
    & git -C $RepoRoot merge-base --is-ancestor $sha HEAD
    if ($LASTEXITCODE -ne 0) {
        throw "Current main does not contain required accepted/merged commit $sha"
    }
}

$migrationBlob = (& git -C $RepoRoot rev-parse "${AcceptedCandidateSha}:$MigrationPath").Trim()
if ($LASTEXITCODE -ne 0 -or $migrationBlob -ne $AcceptedMigrationBlob) {
    throw "Accepted migration identity mismatch. Expected blob $AcceptedMigrationBlob, got '$migrationBlob'."
}

$serverBlob = (& git -C $RepoRoot hash-object $ServerScript).Trim()
if ($LASTEXITCODE -ne 0 -or $serverBlob -ne $AcceptedServerRunnerBlob) {
    throw "Production server-runner identity mismatch. Expected blob $AcceptedServerRunnerBlob, got '$serverBlob'."
}

$stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$bundleName = "msb-setup-122-name-sync-production-$stamp"
$localBundle = Join-Path ([System.IO.Path]::GetTempPath()) $bundleName
$remoteRoot = "/tmp/$bundleName"
$utf8NoBom = [System.Text.UTF8Encoding]::new($false)

Write-Host '========== SETUP #122 REUSABLE NAME SYNC PRODUCTION DEPLOYMENT =========='
Write-Host "Server:                    $Server"
Write-Host "Accepted candidate SHA:    $AcceptedCandidateSha"
Write-Host "Merged feature commit:     $MergedFeatureSha"
Write-Host "Migration:                 $MigrationPath"
Write-Host "Migration Git blob:        $AcceptedMigrationBlob"
Write-Host "Server runner blob:        $AcceptedServerRunnerBlob"
Write-Host "Deployment operator:       $OperatorEmail"
Write-Host 'Application source move:   NONE'
Write-Host 'Expected live app version: V0.3.18-scheduling-board'
Write-Host "Remote root:               $remoteRoot"
Write-Host 'Authority: Gregovate/MSB-Server-Management — docs/server/Production_Database_Change_Deployment_Runbook.md'
Write-Host 'Procedure: one SCP bundle + one foreground SSH bounded migration runner'
Write-Host 'Keep Production Setup editing paused until this runner returns.'
Write-Host

try {
    New-Item -ItemType Directory -Path $localBundle -Force | Out-Null

    $serverText = [System.IO.File]::ReadAllText($ServerScript)
    $serverText = $serverText.Replace(([char]13).ToString(), '')
    $localServer = Join-Path $localBundle 'setup_122_reusable_name_sync_production_deploy_server.sh'
    [System.IO.File]::WriteAllText($localServer, $serverText, $utf8NoBom)

    if ($serverText.Contains([char]13)) {
        throw 'Generated Linux deployment runner contains CR characters; refusing upload.'
    }

    & scp -r $localBundle "$($Server):/tmp/"
    if ($LASTEXITCODE -ne 0) {
        throw "SCP deployment bundle upload failed with exit code $LASTEXITCODE"
    }

    Write-Host
    Write-Host 'Starting bounded Production migration...'
    $remoteScript = "$remoteRoot/setup_122_reusable_name_sync_production_deploy_server.sh"
    $escapedOperatorEmail = $OperatorEmail.Replace("'", "'\''")
    $remoteCommand = "chmod 700 '$remoteScript' && bash -n '$remoteScript' && timeout --foreground --signal=TERM 3600s bash '$remoteScript' '$escapedOperatorEmail'"

    & ssh -tt -o ServerAliveInterval=15 -o ServerAliveCountMax=3 $Server $remoteCommand
    $remoteExit = $LASTEXITCODE

    if ($remoteExit -ne 0) {
        throw "Setup #122 reusable-name Production deployment failed with exit code $remoteExit. Stop and review the retained deployment report before any further Production mutation."
    }

    Write-Host
    Write-Host 'SETUP #122 REUSABLE NAME SYNC PRODUCTION DEPLOYMENT WRAPPER: PASS'
}
finally {
    if (Test-Path -LiteralPath $localBundle) {
        Remove-Item -LiteralPath $localBundle -Recurse -Force -ErrorAction SilentlyContinue
    }
}
