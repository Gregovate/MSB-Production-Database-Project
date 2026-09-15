param(
    [string]$Server = 'msbadmin@192.168.5.9'
)

$ErrorActionPreference = 'Stop'

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$RepoRoot = (Resolve-Path (Join-Path $ScriptDir '..\..')).Path
$ServerScript = Join-Path $ScriptDir 'setup_167_production_migrate_server.sh'
$ExpectedBranch = 'agent/setup-167-kit-inventory-reconstruction'
$AcceptedTargetSha = '1e0e2d2c3ffbcafc2ffef2bb4a98c81d600e8b1b'

if (-not (Test-Path -LiteralPath $ServerScript -PathType Leaf)) {
    throw "Required Production migration runner is missing: $ServerScript"
}

$currentBranch = (& git -C $RepoRoot branch --show-current).Trim()
if ($LASTEXITCODE -ne 0 -or $currentBranch -ne $ExpectedBranch) {
    throw "Run this migration wrapper from branch $ExpectedBranch. Current branch: $currentBranch"
}

$dirty = (& git -C $RepoRoot status --porcelain)
if ($LASTEXITCODE -ne 0) {
    throw 'Unable to verify local Git worktree status.'
}
if ($dirty) {
    throw 'Local worktree is not clean. Commit/stash/revert local changes before packaging the Production migration.'
}

& git -C $RepoRoot cat-file -e "${AcceptedTargetSha}^{commit}"
if ($LASTEXITCODE -ne 0) {
    throw "Accepted Setup #167 candidate commit is not available locally: $AcceptedTargetSha"
}

& git -C $RepoRoot merge-base --is-ancestor $AcceptedTargetSha HEAD
if ($LASTEXITCODE -ne 0) {
    throw "Current branch does not contain the accepted Setup #167 target $AcceptedTargetSha"
}

$stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$bundleName = "msb-setup-167-production-$stamp"
$localBundle = Join-Path ([System.IO.Path]::GetTempPath()) $bundleName
$remoteRoot = "/tmp/$bundleName"
$utf8NoBom = New-Object System.Text.UTF8Encoding($false)

Write-Host '========== SETUP #167 KIT INVENTORY RECONSTRUCTION PRODUCTION MIGRATION =========='
Write-Host "Server:              $Server"
Write-Host "Accepted target SHA: $AcceptedTargetSha"
Write-Host "Remote root:         $remoteRoot"
Write-Host 'Authority: Gregovate/MSB-Server-Management — docs/server/Production_Database_Change_Deployment_Runbook.md'
Write-Host 'Procedure: one SCP bundle + one foreground SSH bounded Production runner'
Write-Host 'This run applies only one-time migrations 038 and 043-048, validates the accepted reconstruction, and advances /opt/msb-setup only after DB validation passes.'
Write-Host 'The runner creates both a full rollback archive and a targeted pre-image of every table the reconstruction may change.'
Write-Host

try {
    New-Item -ItemType Directory -Path $localBundle -Force | Out-Null

    $serverText = [System.IO.File]::ReadAllText($ServerScript)
    $serverText = $serverText.Replace("`r`n", "`n").Replace("`r", "`n")
    $localServer = Join-Path $localBundle 'setup_167_production_migrate_server.sh'
    [System.IO.File]::WriteAllText($localServer, $serverText, $utf8NoBom)

    if ([System.IO.File]::ReadAllText($localServer).Contains("`r")) {
        throw 'Generated Linux Production migration runner contains CR characters; refusing to upload.'
    }

    & scp -r $localBundle "${Server}:/tmp/"
    if ($LASTEXITCODE -ne 0) {
        throw "SCP migration bundle upload failed with exit code $LASTEXITCODE"
    }

    Write-Host
    Write-Host 'Starting bounded Production migration...'
    $remoteScript = "$remoteRoot/setup_167_production_migrate_server.sh"
    $remoteCommand = "bash -n '$remoteScript' && chmod 700 '$remoteScript' && timeout --foreground --signal=TERM 3600s bash '$remoteScript'"
    & ssh -tt -o ServerAliveInterval=15 -o ServerAliveCountMax=3 $Server $remoteCommand
    $remoteExit = $LASTEXITCODE

    if ($remoteExit -ne 0) {
        throw "Setup #167 Production migration failed with exit code $remoteExit. Review the retained Setup_167_Kit_Inventory_Reconstruction_Production_Migrate_*.txt report named in the output."
    }

    Write-Host
    Write-Host 'SETUP #167 PRODUCTION MIGRATION WRAPPER: PASS'
}
finally {
    if (Test-Path -LiteralPath $localBundle) {
        Remove-Item -LiteralPath $localBundle -Recurse -Force -ErrorAction SilentlyContinue
    }
}
