param(
    [Parameter(Mandatory=$true)]
    [string]$TargetSha,
    [string]$Server = 'msbadmin@192.168.5.9'
)

$ErrorActionPreference = 'Stop'

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$RepoRoot = (Resolve-Path (Join-Path $ScriptDir '..\..')).Path
$ServerScript = Join-Path $ScriptDir 'people_manager_nullable_email_production_deploy_server.sh'

$ExpectedBranch = 'main'
$RuntimeSha = '953f2b71487de80519f4fc2f8005467ca41983e9'

if (-not (Test-Path -LiteralPath $ServerScript)) {
    throw "Required People nullable-email Production runner is missing: $ServerScript"
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
    throw 'Local worktree is not clean. Pull/commit/stash/revert before Production deployment.'
}

& git -C $RepoRoot cat-file -e "${RuntimeSha}^{commit}"
if ($LASTEXITCODE -ne 0) {
    throw "Accepted runtime SHA is not available locally: $RuntimeSha"
}

& git -C $RepoRoot fetch origin main
if ($LASTEXITCODE -ne 0) { throw 'Unable to refresh origin/main.' }
$localHead = (& git -C $RepoRoot rev-parse HEAD).Trim()
$remoteMain = (& git -C $RepoRoot rev-parse origin/main).Trim()
if ($localHead -ne $TargetSha -or $remoteMain -ne $TargetSha) { throw "TargetSha must equal local main HEAD and origin/main. local=$localHead remote=$remoteMain requested=$TargetSha" }
& git -C $RepoRoot merge-base --is-ancestor $RuntimeSha $TargetSha
if ($LASTEXITCODE -ne 0) {
    throw "Merged main does not contain accepted runtime SHA $RuntimeSha"
}

$runtimeChangesAfterAcceptance = @(
    & git -C $RepoRoot diff --name-only "$RuntimeSha..$TargetSha" -- People/Application People/Database
)
if ($LASTEXITCODE -ne 0) {
    throw 'Unable to verify accepted People runtime against current branch.'
}
if ($runtimeChangesAfterAcceptance.Count -gt 0) {
    throw "People Application/Database changed after accepted runtime SHA. Deployment refused.`n$($runtimeChangesAfterAcceptance -join "`n")"
}

$stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$bundleName = "msb-people-nullable-email-production-$stamp"
$localBundle = Join-Path ([System.IO.Path]::GetTempPath()) $bundleName
$remoteRoot = "/tmp/$bundleName"
$utf8NoBom = New-Object System.Text.UTF8Encoding($false)

Write-Host '========== PEOPLE NULLABLE MSB EMAIL PRODUCTION DEPLOYMENT =========='
Write-Host "Server:          $Server"
Write-Host "Accepted runtime: $RuntimeSha"
Write-Host "Merged main SHA:  $TargetSha"
Write-Host "Remote root:     $remoteRoot"
Write-Host 'Authority: MSB-Server-Management — Production_Database_Change_Deployment_Runbook.md'
Write-Host
Write-Host 'APPROVED PRODUCTION MUTATION:'
Write-Host '  - validates existing People V0.2.0 runtime'
Write-Host '  - creates and validates a PostgreSQL rollback archive'
Write-Host '  - applies ONLY People migration 004'
Write-Host '  - requires ref.person fingerprint to remain unchanged'
Write-Host '  - fast-forwards the shared checkout to the exact accepted runtime'
Write-Host '  - restarts ONLY msb-people.service'
Write-Host '  - validates People V0.2.1 and authentication boundary'
Write-Host

try {
    New-Item -ItemType Directory -Path $localBundle -Force | Out-Null

    $serverText = [System.IO.File]::ReadAllText($ServerScript)
    $serverText = $serverText.Replace("`r`n", "`n").Replace("`r", "`n")
    $localServer = Join-Path $localBundle 'people_manager_nullable_email_production_deploy_server.sh'
    [System.IO.File]::WriteAllText($localServer, $serverText, $utf8NoBom)

    & scp -r $localBundle "${Server}:/tmp/"
    if ($LASTEXITCODE -ne 0) {
        throw "SCP deployment bundle upload failed with exit code $LASTEXITCODE"
    }

    Write-Host
    Write-Host 'Starting bounded Production deployment...'
    & ssh -tt $Server "bash -n '$remoteRoot/people_manager_nullable_email_production_deploy_server.sh' && chmod 700 '$remoteRoot/people_manager_nullable_email_production_deploy_server.sh'; timeout --signal=TERM 1800s bash '$remoteRoot/people_manager_nullable_email_production_deploy_server.sh' '$TargetSha'"
    $remoteExit = $LASTEXITCODE

    if ($remoteExit -ne 0) {
        throw "People nullable-email Production deployment failed with exit code $remoteExit. Review the remote /tmp/MSB_People_Nullable_Email_Production_Deploy_*.txt report shown in output."
    }

    Write-Host
    Write-Host 'PEOPLE NULLABLE MSB EMAIL PRODUCTION WRAPPER: PASS'
}
finally {
    if (Test-Path -LiteralPath $localBundle) {
        Remove-Item -LiteralPath $localBundle -Recurse -Force -ErrorAction SilentlyContinue
    }
}
