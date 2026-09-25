param(
    [string]$Server = 'msbadmin@192.168.5.9'
)

$ErrorActionPreference = 'Stop'

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$RepoRoot = (Resolve-Path (Join-Path $ScriptDir '..\..')).Path
$ServerScript = Join-Path $ScriptDir 'setup_122_2026_launch_unblock_production_deploy_server.sh'

$ExpectedBranch = 'main'
$AcceptedTargetSha = '06a6536d92db5c7352beeed496563ed9bfdb7146'
$AcceptedServerRunnerBlob = '8209a237a386c754309c8177321443e974e65e48'
$Migration057Path = 'Setup/Database/057_enable_2026_unworked_task_deletion.sql'
$Migration057Blob = '053570d192345caa5708ccc61f69674c17c25989'
$Migration058Path = 'Setup/Database/058_preserve_catalog_review_on_annual_launch.sql'
$Migration058Blob = '221498abaea8ab923c06d287ba2d94d80007d5e7'

if (-not (Test-Path -LiteralPath $ServerScript -PathType Leaf)) {
    throw "Required #122 2026 launch Production deployment runner is missing: $ServerScript"
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

$serverBlob = (& git -C $RepoRoot hash-object $ServerScript).Trim()
if ($LASTEXITCODE -ne 0 -or $serverBlob -ne $AcceptedServerRunnerBlob) {
    throw "Production server-runner identity mismatch. Expected blob $AcceptedServerRunnerBlob, got '$serverBlob'."
}

foreach ($migration in @(
    @{ Path = $Migration057Path; Blob = $Migration057Blob },
    @{ Path = $Migration058Path; Blob = $Migration058Blob }
)) {
    $objectSpec = "$($AcceptedTargetSha):$($migration.Path)"
    $actual = (& git -C $RepoRoot rev-parse $objectSpec).Trim()
    if ($LASTEXITCODE -ne 0 -or $actual -ne $migration.Blob) {
        throw "Accepted migration blob mismatch for $($migration.Path). Expected $($migration.Blob), got '$actual'."
    }
}

$stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$bundleName = "msb-setup-122-2026-launch-production-$stamp"
$localBundle = Join-Path ([System.IO.Path]::GetTempPath()) $bundleName
$remoteRoot = "/tmp/$bundleName"
$utf8NoBom = New-Object System.Text.UTF8Encoding($false)

Write-Host '========== SETUP #122 2026 LAUNCH-UNBLOCK PRODUCTION DEPLOYMENT =========='
Write-Host "Server:               $Server"
Write-Host "Accepted target SHA:  $AcceptedTargetSha"
Write-Host "Server runner blob:   $AcceptedServerRunnerBlob"
Write-Host 'Expected Setup ver:   V0.3.17-performance-trace'
Write-Host 'Database migrations:  057 + 058'
Write-Host '2026 Session creation: NOT PART OF THIS DEPLOYMENT'
Write-Host "Remote root:          $remoteRoot"
Write-Host 'Authority: Gregovate/MSB-Server-Management — docs/server/Production_Database_Change_Deployment_Runbook.md'
Write-Host 'Production mutation is limited to migrations 057/058 and advancing /opt/msb-setup to the exact browser-accepted SHA.'
Write-Host

try {
    New-Item -ItemType Directory -Path $localBundle -Force | Out-Null

    $serverText = [System.IO.File]::ReadAllText($ServerScript)
    $serverText = $serverText.Replace(([char]13).ToString(), '')
    $localServer = Join-Path $localBundle 'setup_122_2026_launch_unblock_production_deploy_server.sh'
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
    $remoteScript = "$remoteRoot/setup_122_2026_launch_unblock_production_deploy_server.sh"
    $remoteCommand = "chmod 700 '$remoteScript' && bash -n '$remoteScript' && timeout --foreground --signal=TERM 3600s bash '$remoteScript'"

    & ssh -tt -o ServerAliveInterval=15 -o ServerAliveCountMax=3 $Server $remoteCommand
    $remoteExit = $LASTEXITCODE

    if ($remoteExit -ne 0) {
        throw "Setup #122 2026 launch Production deployment failed with exit code $remoteExit. Stop and review the retained deployment report before any further Production mutation."
    }

    Write-Host
    Write-Host 'SETUP #122 2026 LAUNCH-UNBLOCK PRODUCTION DEPLOYMENT WRAPPER: PASS'
}
finally {
    if (Test-Path -LiteralPath $localBundle) {
        Remove-Item -LiteralPath $localBundle -Recurse -Force -ErrorAction SilentlyContinue
    }
}
