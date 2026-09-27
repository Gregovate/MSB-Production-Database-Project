param(
    [string]$Server = 'msbadmin@192.168.5.9'
)

$ErrorActionPreference = 'Stop'

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$RepoRoot = (Resolve-Path (Join-Path $ScriptDir '..\..')).Path
$ServerScript = Join-Path $ScriptDir 'setup_122_b1a_audit_baseline_production_deploy_server.sh'

$ExpectedBranch = 'main'
$AcceptedTargetSha = 'f71f578222b2ab5416fabb298e4d4767a2c8d4b5'

$PinnedFiles = @(
    @{
        Path = 'Database/Basic_Query_Tools_Dev/Repair-SetActorOnUpdate-Attribution.sql'
        Blob = '5d1b6b60bf6e6bac4d8817f326dba05e3a8546b7'
    },
    @{
        Path = 'Setup/Database/056_enforce_setup_readiness_note_not_ready.sql'
        Blob = '5fba08d1f8d2450476d14f7525cea4321bc17716'
    },
    @{
        Path = 'Database/Acceptance/database_shared_audit_actor_disposable_validation.sql'
        Blob = '06c9b1311c682d5ccc24c8bfba639bcccca720a4'
    },
    @{
        Path = 'Setup/Acceptance/setup_122_shared_audit_actor_disposable_validation.sql'
        Blob = 'd91ce27cd2f3d6242c7b0cefba70689e938934a4'
    },
    @{
        Path = 'Setup/Acceptance/setup_122_readiness_not_ready_disposable_validation.sql'
        Blob = '6ff2bba86c5301f72fc200a7b9c995e53e387f7a'
    }
)

if (-not (Test-Path -LiteralPath $ServerScript -PathType Leaf)) {
    throw "Required #122 B1a/audit Production deployment runner is missing: $ServerScript"
}

$currentBranch = (& git -C $RepoRoot branch --show-current).Trim()
if ($LASTEXITCODE -ne 0 -or $currentBranch -ne $ExpectedBranch) {
    throw "Run this Production deployment wrapper from merged branch $ExpectedBranch. Current branch: $currentBranch"
}

$dirty = (& git -C $RepoRoot status --porcelain)
if ($LASTEXITCODE -ne 0) {
    throw 'Unable to verify local Git worktree status.'
}
if ($dirty) {
    throw "Local worktree is not clean. Commit/stash/revert before Production deployment. $dirty"
}

& git -C $RepoRoot cat-file -e "$AcceptedTargetSha^{commit}"
if ($LASTEXITCODE -ne 0) {
    throw "Accepted browser-reviewed target is not available locally: $AcceptedTargetSha"
}

& git -C $RepoRoot merge-base --is-ancestor $AcceptedTargetSha HEAD
if ($LASTEXITCODE -ne 0) {
    throw "Merged main does not contain accepted browser-reviewed target $AcceptedTargetSha"
}

foreach ($item in $PinnedFiles) {
    $objectSpec = "$($AcceptedTargetSha):$($item.Path)"
    $actual = (& git -C $RepoRoot rev-parse $objectSpec).Trim()
    if ($LASTEXITCODE -ne 0 -or $actual -ne $item.Blob) {
        throw "Accepted blob mismatch for $($item.Path). Expected $($item.Blob), got '$actual'."
    }
}

$stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$bundleName = "msb-setup-122-b1a-audit-production-$stamp"
$localBundle = Join-Path ([System.IO.Path]::GetTempPath()) $bundleName
$remoteRoot = "/tmp/$bundleName"
$utf8NoBom = New-Object System.Text.UTF8Encoding($false)

Write-Host '========== SETUP #122 B1A / AUDIT BASELINE PRODUCTION DEPLOYMENT =========='
Write-Host "Server:               $Server"
Write-Host "Accepted source SHA:  $AcceptedTargetSha"
Write-Host 'Expected Setup ver:   V0.3.17-performance-trace'
Write-Host 'Database migrations:  shared audit repair + Setup readiness invariant'
Write-Host 'Scheduling completion: NOT DECLARED'
Write-Host '2026 Setup Session:    MUST REMAIN ABSENT'
Write-Host "Remote root:          $remoteRoot"
Write-Host 'Authority: Gregovate/MSB-Server-Management — docs/server/Production_Database_Change_Deployment_Runbook.md'
Write-Host 'Production mutation is limited to the two accepted migrations and advancing /opt/msb-setup to the exact browser-reviewed SHA.'
Write-Host

try {
    New-Item -ItemType Directory -Path $localBundle -Force | Out-Null

    $serverText = [System.IO.File]::ReadAllText($ServerScript)
    $serverText = $serverText.Replace(([char]13).ToString(), '')
    $localServer = Join-Path $localBundle 'setup_122_b1a_audit_baseline_production_deploy_server.sh'
    [System.IO.File]::WriteAllText($localServer, $serverText, $utf8NoBom)

    if ($serverText.Contains([char]13)) {
        throw 'Generated Linux deployment runner contains CR characters; refusing upload.'
    }

    & scp -r $localBundle "$($Server):/tmp/"
    if ($LASTEXITCODE -ne 0) {
        throw "SCP deployment bundle upload failed with exit code $LASTEXITCODE"
    }

    Write-Host
    Write-Host 'Starting bounded Production deployment...'
    $remoteScript = "$remoteRoot/setup_122_b1a_audit_baseline_production_deploy_server.sh"
    $remoteCommand = "chmod 700 '$remoteScript' && bash -n '$remoteScript' && timeout --foreground --signal=TERM 3600s bash '$remoteScript'"

    & ssh -tt -o ServerAliveInterval=15 -o ServerAliveCountMax=3 $Server $remoteCommand
    $remoteExit = $LASTEXITCODE

    if ($remoteExit -ne 0) {
        throw "Setup #122 B1a/audit Production deployment failed with exit code $remoteExit. Stop and review the retained deployment report before any further Production mutation."
    }

    Write-Host
    Write-Host 'SETUP #122 B1A / AUDIT BASELINE PRODUCTION DEPLOYMENT WRAPPER: PASS'
}
finally {
    if (Test-Path -LiteralPath $localBundle) {
        Remove-Item -LiteralPath $localBundle -Recurse -Force -ErrorAction SilentlyContinue
    }
}
