param(
    [string]$Server = 'msbadmin@192.168.5.9'
)

$ErrorActionPreference = 'Stop'

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$RepoRoot = (Resolve-Path (Join-Path $ScriptDir '..\..')).Path
$ServerScript = Join-Path $ScriptDir 'setup_training_production_deploy_server.sh'
$ExpectedBranch = 'agent/setup-session-production-foundation'
$AcceptedTargetSha = 'aaf7de1c1d457b3dfaafe061f084a044cdf2abb7'

if (-not (Test-Path -LiteralPath $ServerScript -PathType Leaf)) {
    throw "Required Production deployment runner is missing: $ServerScript"
}

$currentBranch = (& git -C $RepoRoot branch --show-current).Trim()
if ($LASTEXITCODE -ne 0 -or $currentBranch -ne $ExpectedBranch) {
    throw "Run this deployment wrapper from branch $ExpectedBranch. Current branch: $currentBranch"
}

$dirty = (& git -C $RepoRoot status --porcelain)
if ($LASTEXITCODE -ne 0) {
    throw 'Unable to verify local Git worktree status.'
}
if ($dirty) {
    throw 'Local worktree is not clean. Commit/stash/revert local changes before packaging the Production deployment.'
}

& git -C $RepoRoot cat-file -e "${AcceptedTargetSha}^{commit}"
if ($LASTEXITCODE -ne 0) {
    throw "Accepted Setup candidate commit is not available locally: $AcceptedTargetSha"
}

$stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$bundleName = "msb-setup-training-production-$stamp"
$localBundle = Join-Path ([System.IO.Path]::GetTempPath()) $bundleName
$remoteRoot = "/tmp/$bundleName"
$utf8NoBom = New-Object System.Text.UTF8Encoding($false)

Write-Host '========== SETUP TRAINING / RECONSTRUCTION PRODUCTION DEPLOYMENT =========='
Write-Host "Server:              $Server"
Write-Host "Accepted target SHA: $AcceptedTargetSha"
Write-Host "Remote root:         $remoteRoot"
Write-Host 'Authority: Gregovate/MSB-Server-Management — docs/server/Production_Database_Change_Deployment_Runbook.md'
Write-Host 'Procedure: bounded Production migration + exact Setup runtime promotion'
Write-Host 'This run applies only migrations 019-022 and advances /opt/msb-setup only after detached regression, rollback backup, and DB preflight pass.'
Write-Host

try {
    New-Item -ItemType Directory -Path $localBundle -Force | Out-Null

    $serverText = [System.IO.File]::ReadAllText($ServerScript)
    $serverText = $serverText.Replace("`r`n", "`n").Replace("`r", "`n")
    $localServer = Join-Path $localBundle 'setup_training_production_deploy_server.sh'
    [System.IO.File]::WriteAllText($localServer, $serverText, $utf8NoBom)

    & scp -r $localBundle "${Server}:/tmp/"
    if ($LASTEXITCODE -ne 0) {
        throw "SCP deployment bundle upload failed with exit code $LASTEXITCODE"
    }

    Write-Host
    Write-Host 'Starting bounded Production deployment...'
    & ssh -tt $Server "bash -n '$remoteRoot/setup_training_production_deploy_server.sh' && chmod 700 '$remoteRoot/setup_training_production_deploy_server.sh'; timeout --signal=TERM 1800s bash '$remoteRoot/setup_training_production_deploy_server.sh'"
    $remoteExit = $LASTEXITCODE

    if ($remoteExit -ne 0) {
        throw "Setup Production deployment failed with exit code $remoteExit. Review the remote /tmp/MSB_Setup_Training_Production_Deploy_*.txt report named in the output."
    }

    Write-Host
    Write-Host 'SETUP TRAINING / RECONSTRUCTION PRODUCTION WRAPPER: PASS'
}
finally {
    if (Test-Path -LiteralPath $localBundle) {
        Remove-Item -LiteralPath $localBundle -Recurse -Force -ErrorAction SilentlyContinue
    }
}
