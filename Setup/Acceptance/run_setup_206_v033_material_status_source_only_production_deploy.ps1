param(
    [string]$Server = 'msbadmin@192.168.5.9'
)

$ErrorActionPreference = 'Stop'

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$RepoRoot = (Resolve-Path (Join-Path $ScriptDir '..\..')).Path
$ServerScript = Join-Path $ScriptDir 'setup_206_v033_material_status_source_only_production_deploy_server.sh'

$ExpectedBranch = 'tooling/206-v033-production-deploy'
$AcceptedApplicationSha = 'e9839123e7483d7ced630b3dc6ab8f377c3f3262'
$MergedMainSha = 'e81d4e2da9d84324d85f6423dca0aae831a98753'
$AcceptedServerRunnerBlob = 'e3cef2cc9064d1e1009739d8737005fd39a76f4d'
$ExpectedVersion = 'V0.3.33-material-status-review-fixes'

if (-not (Test-Path -LiteralPath $ServerScript -PathType Leaf)) {
    throw "Required #206 V0.3.33 Production runner is missing: $ServerScript"
}

$currentBranch = (& git -C $RepoRoot branch --show-current).Trim()
if ($LASTEXITCODE -ne 0 -or $currentBranch -ne $ExpectedBranch) {
    throw "Run this wrapper from branch $ExpectedBranch. Current branch: $currentBranch"
}

$dirty = (& git -C $RepoRoot status --porcelain)
if ($LASTEXITCODE -ne 0) {
    throw 'Unable to verify local Git worktree status.'
}
if ($dirty) {
    throw "Local worktree is not clean. Commit/stash/revert local changes before Production deployment. $dirty"
}

& git -C $RepoRoot cat-file -e "$AcceptedApplicationSha^{commit}"
if ($LASTEXITCODE -ne 0) {
    throw "Accepted browser-reviewed application SHA is not available locally: $AcceptedApplicationSha"
}
& git -C $RepoRoot cat-file -e "$MergedMainSha^{commit}"
if ($LASTEXITCODE -ne 0) {
    throw "Merged main SHA is not available locally: $MergedMainSha"
}
& git -C $RepoRoot merge-base --is-ancestor $AcceptedApplicationSha $MergedMainSha
if ($LASTEXITCODE -ne 0) {
    throw "Accepted application SHA is not contained in merged main $MergedMainSha"
}
& git -C $RepoRoot merge-base --is-ancestor $MergedMainSha HEAD
if ($LASTEXITCODE -ne 0) {
    throw "Current tooling branch does not contain merged main $MergedMainSha"
}

$candidateBackend = ((& git -C $RepoRoot show ($AcceptedApplicationSha + ':Setup/Application/production_backend.py')) | Out-String)
$candidateGuard = ((& git -C $RepoRoot show ($AcceptedApplicationSha + ':Setup/Application/setup_catalog_dirty_guard.js')) | Out-String)
$candidateStatusHtml = ((& git -C $RepoRoot show ($AcceptedApplicationSha + ':Setup/Application/material_status.html')) | Out-String)
$candidateStatusJs = ((& git -C $RepoRoot show ($AcceptedApplicationSha + ':Setup/Application/setup_material_status.js')) | Out-String)

if (-not $candidateBackend.Contains('PRODUCTION_VERSION = "V0.3.33-material-status-review-fixes"') -or
    -not $candidateGuard.Contains("CLIENT_BUILD = 'V0.3.33-material-status-review-fixes'") -or
    -not $candidateStatusHtml.Contains('setup_material_status.css?v=2026-10-01.3') -or
    -not $candidateStatusHtml.Contains('setup_material_status.js?v=2026-10-01.4') -or
    -not $candidateStatusHtml.Contains('id="open-material-audit"') -or
    -not $candidateStatusJs.Contains('function renderContents(item)') -or
    -not $candidateStatusJs.Contains("statusFilter.value === 'UNSCHEDULED_PICKABLE'") -or
    -not $candidateStatusJs.Contains("statusFilter.value === 'SCHEDULED_TO_PICK'")) {
    throw 'STOP before server contact: frozen V0.3.33 target does not contain the browser-accepted build/assets/behavior.'
}

$serverObject = "HEAD:Setup/Acceptance/setup_206_v033_material_status_source_only_production_deploy_server.sh"
$serverBlob = (& git -C $RepoRoot rev-parse $serverObject).Trim()
if ($LASTEXITCODE -ne 0 -or $serverBlob -ne $AcceptedServerRunnerBlob) {
    throw "#206 V0.3.33 Production server-runner identity mismatch. Expected blob $AcceptedServerRunnerBlob, got '$serverBlob'."
}

$stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$bundleName = "msb-setup-206-v033-source-only-$stamp"
$localBundle = Join-Path ([System.IO.Path]::GetTempPath()) $bundleName
$remoteRoot = "/tmp/$bundleName"
$utf8NoBom = New-Object System.Text.UTF8Encoding($false)

Write-Host '========== SETUP #206 V0.3.33 MATERIAL STATUS SOURCE-ONLY PRODUCTION DEPLOYMENT =========='
Write-Host "Server:                   $Server"
Write-Host "Accepted application SHA: $AcceptedApplicationSha"
Write-Host "Merged main SHA:          $MergedMainSha"
Write-Host "Expected Setup version:   $ExpectedVersion"
Write-Host "Server runner blob:       $AcceptedServerRunnerBlob"
$ToolingCommit = (& git -C $RepoRoot rev-parse HEAD).Trim()
Write-Host "Tooling commit:           $ToolingCommit"
Write-Host 'Database mutation:        NONE'
Write-Host "Remote root:              $remoteRoot"
Write-Host 'Authority: Gregovate/MSB-Server-Management — docs/server/Setup_Source_Only_Application_Deployment_Runbook.md'
Write-Host
Write-Host 'IMPORTANT: pause Setup editing while this bounded Production deployment runs.'
Write-Host

try {
    New-Item -ItemType Directory -Path $localBundle -Force | Out-Null

    $serverText = [System.IO.File]::ReadAllText($ServerScript)
    $serverText = $serverText.Replace(([char]13).ToString(), '')
    $localServer = Join-Path $localBundle 'setup_206_v033_material_status_source_only_production_deploy_server.sh'
    [System.IO.File]::WriteAllText($localServer, $serverText, $utf8NoBom)

    if ($serverText.Contains([char]13)) {
        throw 'Generated Linux deployment runner contains CR characters; refusing upload.'
    }

    & scp -r $localBundle "$($Server):/tmp/"
    if ($LASTEXITCODE -ne 0) {
        throw "SCP deployment bundle upload failed with exit code $LASTEXITCODE"
    }

    $remoteScript = "$remoteRoot/setup_206_v033_material_status_source_only_production_deploy_server.sh"
    $remoteCommand = "chmod 700 '$remoteScript' && bash -n '$remoteScript' && timeout --foreground --signal=TERM 3600s bash '$remoteScript'"

    Write-Host
    Write-Host 'Starting bounded #206 V0.3.33 source-only Production deployment...'
    & ssh -tt -o ServerAliveInterval=15 -o ServerAliveCountMax=3 $Server $remoteCommand
    $remoteExit = $LASTEXITCODE

    if ($remoteExit -ne 0) {
        throw "Setup #206 V0.3.33 source-only Production deployment failed with exit code $remoteExit. Stop and review the retained deployment report before any further Production mutation."
    }

    Write-Host
    Write-Host 'SETUP #206 V0.3.33 SOURCE-ONLY PRODUCTION DEPLOYMENT WRAPPER: PASS'
}
finally {
    if (Test-Path -LiteralPath $localBundle) {
        Remove-Item -LiteralPath $localBundle -Recurse -Force -ErrorAction SilentlyContinue
    }
}
