param(
    [string]$Server = 'msbadmin@192.168.5.9'
)

$ErrorActionPreference = 'Stop'

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$RepoRoot = (Resolve-Path (Join-Path $ScriptDir '..\..')).Path
$ServerScript = Join-Path $ScriptDir 'setup_88_v0329_production_deploy_server.sh'

$ExpectedBranch = 'main'
$AcceptedApplicationSha = '7da6828d7b884ee5bb12123dab647bd6fadfba50'
$MigrationPath = 'Setup/Database/065_add_setup_movement_capture.sql'
$AcceptedMigrationBlob = '2738065a6fc3cb84858e401de5fae9bd6ae35dcc'
$ValidationPath = 'Setup/Acceptance/setup_88_movement_capture_disposable_validation.sql'
$AcceptedValidationBlob = 'fc152c305dc0bf7a056aeff60aae3615b06b96d4'
$AcceptedServerRunnerBlob = '4f151af8df503e019419fe8c86d491eba7d97dfa'

if (-not (Test-Path -LiteralPath $ServerScript -PathType Leaf)) {
    throw "Required #88 Production deployment runner is missing: $ServerScript"
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

& git -C $RepoRoot fetch origin main
if ($LASTEXITCODE -ne 0) {
    throw 'Unable to refresh origin/main before Production deployment.'
}

$localHead = (& git -C $RepoRoot rev-parse HEAD).Trim()
$originMain = (& git -C $RepoRoot rev-parse origin/main).Trim()
if ($LASTEXITCODE -ne 0 -or $localHead -ne $originMain) {
    throw "Local main must exactly match refreshed origin/main before Production deployment. Local=$localHead origin/main=$originMain"
}

& git -C $RepoRoot cat-file -e "${AcceptedApplicationSha}^{commit}"
if ($LASTEXITCODE -ne 0) {
    throw "Accepted V0.3.29 application SHA is not available locally: $AcceptedApplicationSha"
}
& git -C $RepoRoot merge-base --is-ancestor $AcceptedApplicationSha HEAD
if ($LASTEXITCODE -ne 0) {
    throw "Merged main does not contain accepted V0.3.29 application SHA $AcceptedApplicationSha."
}

function Assert-GitBlob {
    param(
        [Parameter(Mandatory=$true)][string]$Path,
        [Parameter(Mandatory=$true)][string]$ExpectedBlob
    )
    $actual = (& git -C $RepoRoot rev-parse "${AcceptedApplicationSha}:$Path").Trim()
    if ($LASTEXITCODE -ne 0 -or $actual -ne $ExpectedBlob) {
        throw "Accepted artifact identity mismatch for $Path. Expected $ExpectedBlob, got '$actual'."
    }
}

Assert-GitBlob -Path $MigrationPath -ExpectedBlob $AcceptedMigrationBlob
Assert-GitBlob -Path $ValidationPath -ExpectedBlob $AcceptedValidationBlob

$serverBlob = (& git -C $RepoRoot hash-object $ServerScript).Trim()
if ($LASTEXITCODE -ne 0 -or $serverBlob -ne $AcceptedServerRunnerBlob) {
    throw "Production server-runner identity mismatch. Expected blob $AcceptedServerRunnerBlob, got '$serverBlob'."
}

$backendVersion = ((& git -C $RepoRoot show "${AcceptedApplicationSha}:Setup/Application/production_backend.py") | Out-String)
if ($LASTEXITCODE -ne 0 -or $backendVersion -notmatch 'PRODUCTION_VERSION = "V0\.3\.29-pick-clarity"') {
    throw 'Accepted application SHA does not contain Setup server version V0.3.29-pick-clarity.'
}
$clientVersion = ((& git -C $RepoRoot show "${AcceptedApplicationSha}:Setup/Application/setup_catalog_dirty_guard.js") | Out-String)
if ($LASTEXITCODE -ne 0 -or $clientVersion -notmatch "CLIENT_BUILD = 'V0\.3\.29-pick-clarity'") {
    throw 'Accepted application SHA does not contain Setup client build V0.3.29-pick-clarity.'
}

$stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$bundleName = "msb-setup-88-v0329-production-$stamp"
$localBundle = Join-Path ([System.IO.Path]::GetTempPath()) $bundleName
$remoteRoot = "/tmp/$bundleName"
$utf8NoBom = [System.Text.UTF8Encoding]::new($false)
$cr = [string][char]13
$lf = [string][char]10

Write-Host '========== SETUP #88 V0.3.29 SETUP/POSTGRESQL PRODUCTION DEPLOYMENT =========='
Write-Host "Server:                    $Server"
Write-Host "Merged-main tooling SHA:   $localHead"
Write-Host "Accepted application SHA:  $AcceptedApplicationSha"
Write-Host 'Expected pre-version:      V0.3.22-pick-list-delay'
Write-Host 'Expected post-version:     V0.3.29-pick-clarity'
Write-Host "Migration:                 $MigrationPath"
Write-Host "Migration Git blob:        $AcceptedMigrationBlob"
Write-Host "Validation Git blob:       $AcceptedValidationBlob"
Write-Host "Server runner blob:        $AcceptedServerRunnerBlob"
Write-Host "Remote root:               $remoteRoot"
Write-Host 'Authority: Gregovate/MSB-Server-Management — docs/server/Production_Database_Change_Deployment_Runbook.md'
Write-Host 'Authority: Gregovate/MSB-Server-Management — docs/server/Setup_Production_Runtime.md'
Write-Host 'Procedure: one SCP bundle + one foreground SSH bounded Setup/PostgreSQL Production runner'
Write-Host 'Scan/Directus deployment is separate and remains governed by the merged Server Management Scan runbook/tooling.'
Write-Host 'Keep Setup editing paused while the bounded deployment runner is active.'
Write-Host

try {
    New-Item -ItemType Directory -Path $localBundle -Force | Out-Null

    $serverText = [System.IO.File]::ReadAllText($ServerScript)
    $serverText = $serverText.Replace($cr + $lf, $lf).Replace($cr, $lf)
    $localServer = Join-Path $localBundle 'setup_88_v0329_production_deploy_server.sh'
    [System.IO.File]::WriteAllText($localServer, $serverText, $utf8NoBom)

    if ($serverText.Contains($cr)) {
        throw 'Generated Linux deployment runner contains CR characters; refusing to upload.'
    }

    & scp -r $localBundle "${Server}:/tmp/"
    if ($LASTEXITCODE -ne 0) {
        throw "SCP deployment bundle upload failed with exit code $LASTEXITCODE"
    }

    $remoteScript = "$remoteRoot/setup_88_v0329_production_deploy_server.sh"
    $remoteCommand = "chmod 700 '$remoteScript' && bash -n '$remoteScript' && timeout --foreground --signal=TERM 3600s bash '$remoteScript'"

    Write-Host
    Write-Host 'Starting bounded Production deployment...'
    & ssh -tt -o ServerAliveInterval=15 -o ServerAliveCountMax=3 $Server $remoteCommand
    $remoteExit = $LASTEXITCODE

    if ($remoteExit -ne 0) {
        throw "Setup #88 V0.3.29 Production deployment failed with exit code $remoteExit. Stop and review the retained Production deployment report before any further mutation."
    }

    Write-Host
    Write-Host 'SETUP #88 V0.3.29 SETUP/POSTGRESQL PRODUCTION DEPLOYMENT WRAPPER: PASS'
}
finally {
    if (Test-Path -LiteralPath $localBundle) {
        Remove-Item -LiteralPath $localBundle -Recurse -Force -ErrorAction SilentlyContinue
    }
}
