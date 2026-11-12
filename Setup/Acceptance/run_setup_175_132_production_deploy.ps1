param(
    [string]$Server = 'msbadmin@192.168.5.9'
)

$ErrorActionPreference = 'Stop'

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$RepoRoot = (Resolve-Path (Join-Path $ScriptDir '..\..')).Path
$ServerScript = Join-Path $ScriptDir 'setup_175_132_production_deploy_server.sh'

$ExpectedBranch = 'issue-175-captain-work-list-v2'
$AcceptedTargetSha = '15864bcce17d0b59c8396e99178e7113fc368b2d'
$MigrationPath = 'Setup/Database/061_add_live_assignment_report_work.sql'
$AcceptedMigrationBlob = '75a5daace003a229d15be1092535f020ffb010d8'
$AcceptedServerRunnerBlob = 'b0fb78b63cfdded2bdf84fbffb36aab0fb42f03f'
$ExpectedVersionText = 'PRODUCTION_VERSION = "V0.3.19-pick-list"'
$ExpectedJsPin = 'setup_next_pass.js?v=2026-09-26.10'
$ExpectedCssPin = 'setup_next_pass.css?v=2026-09-26.10'

if (-not (Test-Path -LiteralPath $ServerScript -PathType Leaf)) {
    throw "Required #175/#132 Production deployment runner is missing: $ServerScript"
}

$currentBranch = (& git -C $RepoRoot branch --show-current).Trim()
if ($LASTEXITCODE -ne 0 -or $currentBranch -ne $ExpectedBranch) {
    throw "Run this deployment wrapper from $ExpectedBranch. Current branch: $currentBranch"
}

$dirty = (& git -C $RepoRoot status --porcelain)
if ($LASTEXITCODE -ne 0) {
    throw 'Unable to verify local Git worktree status.'
}
if ($dirty) {
    throw "Local worktree is not clean. Commit/stash/revert local changes before Production deployment. $dirty"
}

& git -C $RepoRoot cat-file -e ($AcceptedTargetSha + '^{commit}')
if ($LASTEXITCODE -ne 0) {
    throw "Accepted #175/#132 browser candidate is not available locally: $AcceptedTargetSha"
}

& git -C $RepoRoot merge-base --is-ancestor $AcceptedTargetSha HEAD
if ($LASTEXITCODE -ne 0) {
    throw "Current feature branch does not contain accepted browser candidate $AcceptedTargetSha."
}

$targetMigrationSpec = $AcceptedTargetSha + ':' + $MigrationPath
$migrationBlob = (& git -C $RepoRoot rev-parse $targetMigrationSpec).Trim()
if ($LASTEXITCODE -ne 0 -or $migrationBlob -ne $AcceptedMigrationBlob) {
    throw "Accepted migration identity mismatch. Expected blob $AcceptedMigrationBlob, got '$migrationBlob'."
}

$serverBlob = (& git -C $RepoRoot hash-object $ServerScript).Trim()
if ($LASTEXITCODE -ne 0 -or $serverBlob -ne $AcceptedServerRunnerBlob) {
    throw "Production server-runner identity mismatch. Expected blob $AcceptedServerRunnerBlob, got '$serverBlob'."
}

$backendSpec = $AcceptedTargetSha + ':Setup/Application/production_backend.py'
$backend = ((& git -C $RepoRoot show $backendSpec) | Out-String)
if ($LASTEXITCODE -ne 0 -or -not $backend.Contains($ExpectedVersionText)) {
    throw 'Accepted target does not contain Setup version V0.3.19-pick-list.'
}

$htmlSpec = $AcceptedTargetSha + ':Setup/Application/production.html'
$html = ((& git -C $RepoRoot show $htmlSpec) | Out-String)
if ($LASTEXITCODE -ne 0 -or -not $html.Contains($ExpectedJsPin) -or -not $html.Contains($ExpectedCssPin)) {
    throw 'Accepted target does not contain the browser-reviewed #175/#132 asset pins.'
}

$stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$bundleName = "msb-setup-175-132-production-$stamp"
$localBundle = Join-Path ([System.IO.Path]::GetTempPath()) $bundleName
$remoteRoot = "/tmp/$bundleName"
$utf8NoBom = [System.Text.UTF8Encoding]::new($false)
$cr = [string][char]13
$lf = [string][char]10

Write-Host '========== SETUP #175/#132 REPORT WORK PRODUCTION DEPLOYMENT =========='
Write-Host "Server:                     $Server"
Write-Host "Browser-accepted SHA:       $AcceptedTargetSha"
Write-Host 'Expected version:           V0.3.19-pick-list'
Write-Host "Migration:                  $MigrationPath"
Write-Host "Migration Git blob:         $AcceptedMigrationBlob"
Write-Host "Server runner blob:         $AcceptedServerRunnerBlob"
Write-Host "Remote root:                $remoteRoot"
Write-Host 'Authority: Gregovate/MSB-Server-Management — docs/server/Production_Database_Change_Deployment_Runbook.md'
Write-Host 'Procedure: one SCP bundle + one foreground SSH bounded Production runner'
Write-Host 'IMPORTANT: keep Setup editing paused while the bounded deployment runner is active.'
Write-Host

try {
    New-Item -ItemType Directory -Path $localBundle -Force | Out-Null

    $serverText = [System.IO.File]::ReadAllText($ServerScript)
    $serverText = $serverText.Replace($cr + $lf, $lf).Replace($cr, $lf)
    $localServer = Join-Path $localBundle 'setup_175_132_production_deploy_server.sh'
    [System.IO.File]::WriteAllText($localServer, $serverText, $utf8NoBom)

    if ($serverText.Contains($cr)) {
        throw 'Generated Linux deployment runner contains CR characters; refusing to upload.'
    }

    & scp -r $localBundle ($Server + ':/tmp/')
    if ($LASTEXITCODE -ne 0) {
        throw "SCP deployment bundle upload failed with exit code $LASTEXITCODE"
    }

    $remoteScript = "$remoteRoot/setup_175_132_production_deploy_server.sh"
    $remoteCommand = "chmod 700 '$remoteScript' && bash -n '$remoteScript' && timeout --foreground --signal=TERM 3600s bash '$remoteScript'"

    Write-Host
    Write-Host 'Starting bounded Production deployment...'
    & ssh -tt -o ServerAliveInterval=15 -o ServerAliveCountMax=3 $Server $remoteCommand
    $remoteExit = $LASTEXITCODE

    if ($remoteExit -ne 0) {
        throw "Setup #175/#132 Production deployment failed with exit code $remoteExit. Stop and review the retained Production deployment report before any further mutation."
    }

    Write-Host
    Write-Host 'SETUP #175/#132 REPORT WORK PRODUCTION DEPLOYMENT WRAPPER: PASS'
}
finally {
    if (Test-Path -LiteralPath $localBundle) {
        Remove-Item -LiteralPath $localBundle -Recurse -Force -ErrorAction SilentlyContinue
    }
}
