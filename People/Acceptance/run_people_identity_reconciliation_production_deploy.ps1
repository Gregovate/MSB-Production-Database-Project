param(
    [Parameter(Mandatory=$true)]
    [string]$TargetSha,
    [string]$Server = 'msbadmin@192.168.5.9'
)

$ErrorActionPreference = 'Stop'

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$RepoRoot = (Resolve-Path (Join-Path $ScriptDir '..\..')).Path
$ServerScript = Join-Path $ScriptDir 'people_identity_reconciliation_production_deploy_server.sh'

$ExpectedBranch = 'main'
$RuntimeSha = 'f6f581dce0e65b6b9be0cff62478719550e3fefe'

if (-not (Test-Path -LiteralPath $ServerScript)) {
    throw "Required #385 Production runner is missing: $ServerScript"
}

$currentBranch = (& git -C $RepoRoot branch --show-current).Trim()
if ($LASTEXITCODE -ne 0 -or $currentBranch -ne $ExpectedBranch) {
    throw "Run this deployment wrapper from branch $ExpectedBranch. Current branch: $currentBranch"
}

$dirty = (& git -C $RepoRoot status --porcelain)
if ($LASTEXITCODE -ne 0) { throw 'Unable to verify local Git worktree status.' }
if ($dirty) { throw 'Local worktree is not clean. Production deployment refused.' }

& git -C $RepoRoot fetch origin main
if ($LASTEXITCODE -ne 0) { throw 'Unable to refresh origin/main.' }

$localHead = (& git -C $RepoRoot rev-parse HEAD).Trim()
$remoteMain = (& git -C $RepoRoot rev-parse origin/main).Trim()
if ($localHead -ne $TargetSha -or $remoteMain -ne $TargetSha) {
    throw "TargetSha must equal local main and origin/main. local=$localHead remote=$remoteMain requested=$TargetSha"
}

& git -C $RepoRoot cat-file -e "$RuntimeSha^{commit}"
if ($LASTEXITCODE -ne 0) { throw "Accepted runtime SHA is unavailable locally: $RuntimeSha" }

& git -C $RepoRoot merge-base --is-ancestor $RuntimeSha $TargetSha
if ($LASTEXITCODE -ne 0) { throw "Merged main does not contain accepted runtime SHA $RuntimeSha" }

$runtimeChanges = @(
    & git -C $RepoRoot diff --name-only "$RuntimeSha..$TargetSha" -- People/Application People/Database
)
if ($LASTEXITCODE -ne 0) { throw 'Unable to verify exact accepted People runtime.' }
if ($runtimeChanges.Count -gt 0) {
    throw ("People runtime changed after accepted SHA. Deployment refused. " + ($runtimeChanges -join ', '))
}

$stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$bundleName = "msb-people-identity-reconcile-production-$stamp"
$localBundle = Join-Path ([System.IO.Path]::GetTempPath()) $bundleName
$remoteRoot = "/tmp/$bundleName"
$utf8NoBom = New-Object System.Text.UTF8Encoding($false)

Write-Host '========== PEOPLE IDENTITY RECONCILIATION PRODUCTION DEPLOYMENT =========='
Write-Host "Server:           $Server"
Write-Host "Accepted runtime: $RuntimeSha"
Write-Host "Merged main SHA:  $TargetSha"
Write-Host "Remote root:      $remoteRoot"
Write-Host 'Authority: Gregovate/MSB-Server-Management — docs/server/Production_Database_Change_Deployment_Runbook.md'
Write-Host 'Procedure: database-changing deployment under Issue #37 maintenance controller'
Write-Host 'This step: apply only People migration 005 and promote exact merged People V0.2.2 runtime'
Write-Host

try {
    New-Item -ItemType Directory -Path $localBundle -Force | Out-Null

    $serverText = [System.IO.File]::ReadAllText($ServerScript)
    $serverText = $serverText.Replace("`r`n", "`n").Replace("`r", "`n")
    $localServer = Join-Path $localBundle 'people_identity_reconciliation_production_deploy_server.sh'
    [System.IO.File]::WriteAllText($localServer, $serverText, $utf8NoBom)

    & scp -r $localBundle "${Server}:/tmp/"
    if ($LASTEXITCODE -ne 0) {
        throw "SCP Production bundle upload failed with exit code $LASTEXITCODE"
    }

    Write-Host
    Write-Host 'Starting bounded #385 Production deployment...'
    & ssh -tt $Server "chmod 700 '$remoteRoot/people_identity_reconciliation_production_deploy_server.sh'; timeout --signal=TERM 1800s bash '$remoteRoot/people_identity_reconciliation_production_deploy_server.sh' '$TargetSha'"
    $remoteExit = $LASTEXITCODE

    if ($remoteExit -ne 0) {
        throw "People identity reconciliation Production deployment failed with exit code $remoteExit. Review the retained remote report named in the output."
    }

    Write-Host
    Write-Host 'PEOPLE IDENTITY RECONCILIATION PRODUCTION WRAPPER: PASS'
}
finally {
    if (Test-Path -LiteralPath $localBundle) {
        Remove-Item -LiteralPath $localBundle -Recurse -Force -ErrorAction SilentlyContinue
    }
}
