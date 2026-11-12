param(
    [string]$Server = 'msbadmin@192.168.5.9'
)

$ErrorActionPreference = 'Stop'

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$RepoRoot = (Resolve-Path (Join-Path $ScriptDir '..\..')).Path
$ServerScript = Join-Path $ScriptDir 'people_manager_production_deploy_server.sh'
$ExpectedBranch = 'agent/people-manager-milestone1-20260908'
$TargetSha = '54e1192309b96c9838676be51a0bfcdb3ac92e06'
$DatabaseAcceptedSha = 'deaa9157282e59e8acd6a7da2a82fc9296e44f20'
$BrowserAcceptedSha = '4724185fe8cd8831a59c61ea40df61073abbb0c6'

if (-not (Test-Path -LiteralPath $ServerScript)) {
    throw "Required People production deployment runner is missing: $ServerScript"
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
    throw 'Local worktree is not clean. Pull/commit/stash/revert before packaging the production deployment.'
}

foreach ($sha in @($TargetSha, $DatabaseAcceptedSha, $BrowserAcceptedSha)) {
    & git -C $RepoRoot cat-file -e "${sha}^{commit}"
    if ($LASTEXITCODE -ne 0) {
        throw "Required People acceptance commit is not available locally: $sha"
    }
}

& git -C $RepoRoot merge-base --is-ancestor $BrowserAcceptedSha $TargetSha
if ($LASTEXITCODE -ne 0) {
    throw "Production target $TargetSha is not a descendant of browser-accepted SHA $BrowserAcceptedSha"
}

$behaviorChanges = @(& git -C $RepoRoot diff --name-only "$DatabaseAcceptedSha..$TargetSha" -- People/Database People/Application/backend.py People/Application/people.js)
if ($LASTEXITCODE -ne 0) {
    throw 'Unable to verify disposable-accepted People database/API behavior against the production target.'
}
if ($behaviorChanges.Count -gt 0) {
    throw "People database/API behavior changed after disposable acceptance. Production deployment refused.`n$($behaviorChanges -join "`n")"
}

$browserChanges = @(& git -C $RepoRoot diff --name-only "$BrowserAcceptedSha..$TargetSha" -- People/Application People/Database)
if ($LASTEXITCODE -ne 0) {
    throw 'Unable to verify browser-accepted People runtime against the production target.'
}
if ($browserChanges.Count -gt 0) {
    throw "People application/database files changed after browser acceptance. Production deployment refused.`n$($browserChanges -join "`n")"
}

$stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$bundleName = "msb-people-production-$stamp"
$localBundle = Join-Path ([System.IO.Path]::GetTempPath()) $bundleName
$remoteRoot = "/tmp/$bundleName"
$utf8NoBom = New-Object System.Text.UTF8Encoding($false)

Write-Host '========== PEOPLE MANAGER PRODUCTION DEPLOYMENT =========='
Write-Host "Server:              $Server"
Write-Host "Production target:   $TargetSha"
Write-Host "DB accepted SHA:     $DatabaseAcceptedSha"
Write-Host "Browser accepted:    $BrowserAcceptedSha"
Write-Host "Remote root:         $remoteRoot"
Write-Host 'Authority: MSB-Server-Management — Production_Database_Change_Deployment_Runbook.md'
Write-Host 'Service authority: MSB-Server-Management — Protected_Flask_Application_Service_Deployment.md'
Write-Host
Write-Host 'This is the explicitly approved PRODUCTION gate for People Manager.'
Write-Host 'It will create a validated PostgreSQL rollback archive before migration, install migrations 001-003, advance the shared checkout only by fast-forward, install msb-people.service on verified-unused port 8796, and add only the Synology-source UFW rule.'
Write-Host 'The Synology /people/ reverse-proxy route is a separate governed step after this backend deployment passes.'
Write-Host

try {
    New-Item -ItemType Directory -Path $localBundle -Force | Out-Null

    $serverText = [System.IO.File]::ReadAllText($ServerScript)
    $serverText = $serverText.Replace("`r`n", "`n").Replace("`r", "`n")
    $localServer = Join-Path $localBundle 'people_manager_production_deploy_server.sh'
    [System.IO.File]::WriteAllText($localServer, $serverText, $utf8NoBom)

    & scp -r $localBundle "${Server}:/tmp/"
    if ($LASTEXITCODE -ne 0) {
        throw "SCP People deployment bundle upload failed with exit code $LASTEXITCODE"
    }

    Write-Host
    Write-Host 'Starting bounded People production deployment...'
    & ssh -tt $Server "bash -n '$remoteRoot/people_manager_production_deploy_server.sh' && chmod 700 '$remoteRoot/people_manager_production_deploy_server.sh'; timeout --signal=TERM 1800s bash '$remoteRoot/people_manager_production_deploy_server.sh'"
    $remoteExit = $LASTEXITCODE

    if ($remoteExit -ne 0) {
        throw "People Manager production deployment failed with exit code $remoteExit. Review the remote /tmp/MSB_People_Manager_Production_Deploy_*.txt report named in the output."
    }

    Write-Host
    Write-Host 'PEOPLE MANAGER PRODUCTION BACKEND WRAPPER: PASS'
    Write-Host 'Next governed step: deploy the Synology /people/ route using run_people_manager_synology_route_deploy.ps1.'
}
finally {
    if (Test-Path -LiteralPath $localBundle) {
        Remove-Item -LiteralPath $localBundle -Recurse -Force -ErrorAction SilentlyContinue
    }
}
