param(
    [string]$Server = 'msbadmin@192.168.5.9'
)

$ErrorActionPreference = 'Stop'

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$RepoRoot = (Resolve-Path (Join-Path $ScriptDir '..\..')).Path
$ServerScript = Join-Path $ScriptDir 'setup_205_source_only_production_deploy_server.sh'

$ExpectedBranch = 'agent/setup-205-work-order-gate-ux'
$AcceptedTargetSha = '9a614c1fa2eea0b425b03bdb4ac3e1790634c760'
$AcceptedServerRunnerBlob = 'ff2d49a980379fec03ff163f29da780f6c09ea65'

if (-not (Test-Path -LiteralPath $ServerScript -PathType Leaf)) {
    throw "Required #205 source-only Production deployment runner is missing: $ServerScript"
}

$currentBranch = (& git -C $RepoRoot branch --show-current).Trim()
if ($LASTEXITCODE -ne 0 -or $currentBranch -ne $ExpectedBranch) {
    throw "Run this #205 source-only Production deployment wrapper from branch $ExpectedBranch. Current branch: $currentBranch"
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
    throw "Current #205 tooling branch does not contain accepted browser-reviewed target $AcceptedTargetSha"
}

$candidateBackend = ((& git -C $RepoRoot show ($AcceptedTargetSha + ':Setup/Application/production_backend.py')) | Out-String)
$candidateGuard = ((& git -C $RepoRoot show ($AcceptedTargetSha + ':Setup/Application/setup_catalog_dirty_guard.js')) | Out-String)
$candidateHtml = ((& git -C $RepoRoot show ($AcceptedTargetSha + ':Setup/Application/production.html')) | Out-String)
if (-not $candidateBackend.Contains('PRODUCTION_VERSION = "V0.3.21-scheduling-gates"') -or
    -not $candidateGuard.Contains("CLIENT_BUILD = 'V0.3.21-scheduling-gates'") -or
    -not $candidateHtml.Contains('setup_next_pass.js?v=2026-09-29.5') -or
    -not $candidateHtml.Contains('setup_next_pass.css?v=2026-09-29.1') -or
    -not $candidateHtml.Contains('setup_scheduling_board.js?v=2026-09-29.5')) {
    throw 'STOP before server contact: frozen #205 target does not contain the browser-accepted version/build/assets.'
}

$serverObject = "HEAD:Setup/Acceptance/setup_205_source_only_production_deploy_server.sh"
$serverBlob = (& git -C $RepoRoot rev-parse $serverObject).Trim()
if ($LASTEXITCODE -ne 0 -or $serverBlob -ne $AcceptedServerRunnerBlob) {
    throw "#205 Production server-runner identity mismatch. Expected blob $AcceptedServerRunnerBlob, got '$serverBlob'."
}

$stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$bundleName = "msb-setup-205-source-only-$stamp"
$localBundle = Join-Path ([System.IO.Path]::GetTempPath()) $bundleName
$remoteRoot = "/tmp/$bundleName"
$utf8NoBom = New-Object System.Text.UTF8Encoding($false)

Write-Host '========== SETUP #205 WORK ORDER GATE UX SOURCE-ONLY PRODUCTION DEPLOYMENT =========='
Write-Host "Server:              $Server"
Write-Host "Accepted target SHA: $AcceptedTargetSha"
$ToolingCommit = (& git -C $RepoRoot rev-parse HEAD).Trim()
Write-Host "Server runner blob:  $AcceptedServerRunnerBlob"
Write-Host "Tooling commit:      $ToolingCommit"
Write-Host 'Expected Setup ver:  V0.3.21-scheduling-gates'
Write-Host 'Database mutation:   NONE'
Write-Host "Remote root:         $remoteRoot"
Write-Host 'Authority: Gregovate/MSB-Server-Management — docs/server/Setup_Source_Only_Application_Deployment_Runbook.md'
Write-Host 'Procedure: Controlled Production Mutation — source only'
Write-Host 'This deployment changes /opt/msb-setup source only; PostgreSQL is not mutated.'
Write-Host
Write-Host 'IMPORTANT: keep Setup editing paused while this bounded deployment runs.'
Write-Host

try {
    New-Item -ItemType Directory -Path $localBundle -Force | Out-Null

    $serverText = [System.IO.File]::ReadAllText($ServerScript)
    $serverText = $serverText.Replace(([char]13).ToString(), '')
    $localServer = Join-Path $localBundle 'setup_205_source_only_production_deploy_server.sh'
    [System.IO.File]::WriteAllText($localServer, $serverText, $utf8NoBom)

    if ($serverText.Contains([char]13)) {
        throw 'Generated Linux deployment runner contains CR characters; refusing upload.'
    }

    & scp -r $localBundle "$($Server):/tmp/"
    if ($LASTEXITCODE -ne 0) {
        throw "SCP deployment bundle upload failed with exit code $LASTEXITCODE"
    }

    $remoteScript = "$remoteRoot/setup_205_source_only_production_deploy_server.sh"
    $remoteCommand = "chmod 700 '$remoteScript' && bash -n '$remoteScript' && timeout --foreground --signal=TERM 3600s bash '$remoteScript'"

    Write-Host
    Write-Host 'Starting bounded #205 source-only Production deployment...'
    & ssh -tt -o ServerAliveInterval=15 -o ServerAliveCountMax=3 $Server $remoteCommand
    $remoteExit = $LASTEXITCODE

    if ($remoteExit -ne 0) {
        throw "Setup #205 source-only Production deployment failed with exit code $remoteExit. Stop and review the retained deployment report before any further Production mutation."
    }

    Write-Host
    Write-Host 'SETUP #205 WORK ORDER GATE UX SOURCE-ONLY PRODUCTION DEPLOYMENT WRAPPER: PASS'
}
finally {
    if (Test-Path -LiteralPath $localBundle) {
        Remove-Item -LiteralPath $localBundle -Recurse -Force -ErrorAction SilentlyContinue
    }
}
