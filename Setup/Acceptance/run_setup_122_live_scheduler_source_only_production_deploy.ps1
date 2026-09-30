param(
    [string]$Server = 'msbadmin@192.168.5.9'
)

$ErrorActionPreference = 'Stop'

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$RepoRoot = (Resolve-Path (Join-Path $ScriptDir '..\..')).Path
$ServerScript = Join-Path $ScriptDir 'setup_122_live_scheduler_source_only_production_deploy_server.sh'

$ExpectedBranch = 'main'
$AcceptedTargetSha = '55e097e7bb3b807793893defc939c9a23fc4ec5d'
$AcceptedServerRunnerBlob = 'ed18b5f6bf88ce976334edc84de9cb126072fea1'

if (-not (Test-Path -LiteralPath $ServerScript -PathType Leaf)) {
    throw "Required #122 source-only Production deployment runner is missing: $ServerScript"
}

$currentBranch = (& git -C $RepoRoot branch --show-current).Trim()
if ($LASTEXITCODE -ne 0 -or $currentBranch -ne $ExpectedBranch) {
    throw "Run this source-only Production deployment wrapper from merged branch $ExpectedBranch. Current branch: $currentBranch"
}

$dirty = (& git -C $RepoRoot status --porcelain)
if ($LASTEXITCODE -ne 0) {
    throw 'Unable to verify local Git worktree status.'
}
if ($dirty) {
    throw "Local worktree is not clean. Commit/stash/revert local changes before Production deployment. $dirty"
}

& git -C $RepoRoot cat-file -e "$AcceptedTargetSha^{commit}"
if ($LASTEXITCODE -ne 0) {
    throw "Accepted browser-reviewed target is not available locally: $AcceptedTargetSha"
}

& git -C $RepoRoot merge-base --is-ancestor $AcceptedTargetSha HEAD
if ($LASTEXITCODE -ne 0) {
    throw "Merged main does not contain accepted browser-reviewed target $AcceptedTargetSha"
}

$serverObject = "HEAD:Setup/Acceptance/setup_122_live_scheduler_source_only_production_deploy_server.sh"
$serverBlob = (& git -C $RepoRoot rev-parse $serverObject).Trim()
if ($LASTEXITCODE -ne 0 -or $serverBlob -ne $AcceptedServerRunnerBlob) {
    throw "Production server-runner identity mismatch. Expected blob $AcceptedServerRunnerBlob, got '$serverBlob'."
}

$stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$bundleName = "msb-setup-122-live-scheduler-source-only-$stamp"
$localBundle = Join-Path ([System.IO.Path]::GetTempPath()) $bundleName
$remoteRoot = "/tmp/$bundleName"
$utf8NoBom = New-Object System.Text.UTF8Encoding($false)

Write-Host '========== SETUP #122 LIVE SCHEDULER SOURCE-ONLY PRODUCTION DEPLOYMENT =========='
Write-Host "Server:              $Server"
Write-Host "Accepted target SHA: $AcceptedTargetSha"
Write-Host "Server runner blob:  $AcceptedServerRunnerBlob"
Write-Host 'Expected Setup ver:  V0.3.18-scheduling-board'
Write-Host 'Database mutation:   NONE'
Write-Host "Remote root:         $remoteRoot"
Write-Host 'Authority: Gregovate/MSB-Server-Management — docs/server/Setup_Source_Only_Application_Deployment_Runbook.md'
Write-Host

try {
    New-Item -ItemType Directory -Path $localBundle -Force | Out-Null

    $serverText = [System.IO.File]::ReadAllText($ServerScript)
    $serverText = $serverText.Replace(([char]13).ToString(), '')
    $localServer = Join-Path $localBundle 'setup_122_live_scheduler_source_only_production_deploy_server.sh'
    [System.IO.File]::WriteAllText($localServer, $serverText, $utf8NoBom)

    if ($serverText.Contains([char]13)) {
        throw 'Generated Linux deployment runner contains CR characters; refusing upload.'
    }

    & scp -r $localBundle "$($Server):/tmp/"
    if ($LASTEXITCODE -ne 0) {
        throw "SCP deployment bundle upload failed with exit code $LASTEXITCODE"
    }

    $remoteScript = "$remoteRoot/setup_122_live_scheduler_source_only_production_deploy_server.sh"
    $remoteCommand = "chmod 700 '$remoteScript' && bash -n '$remoteScript' && timeout --foreground --signal=TERM 3600s bash '$remoteScript'"

    Write-Host
    Write-Host 'Starting bounded source-only Production deployment...'
    & ssh -tt -o ServerAliveInterval=15 -o ServerAliveCountMax=3 $Server $remoteCommand
    $remoteExit = $LASTEXITCODE

    if ($remoteExit -ne 0) {
        throw "Setup #122 live-scheduler source-only Production deployment failed with exit code $remoteExit. Stop and review the retained deployment report before any further Production mutation."
    }

    Write-Host
    Write-Host 'SETUP #122 LIVE SCHEDULER SOURCE-ONLY PRODUCTION DEPLOYMENT WRAPPER: PASS'
}
finally {
    if (Test-Path -LiteralPath $localBundle) {
        Remove-Item -LiteralPath $localBundle -Recurse -Force -ErrorAction SilentlyContinue
    }
}
