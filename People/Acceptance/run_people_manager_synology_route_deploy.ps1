param(
    [string]$SynologyServer = 'msbad@192.168.5.4',
    [int]$SynologyPort = 22222
)

$ErrorActionPreference = 'Stop'

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$RepoRoot = (Resolve-Path (Join-Path $ScriptDir '..\..')).Path
$ServerScript = Join-Path $ScriptDir 'people_manager_synology_route_deploy_server.sh'
$ExpectedBranch = 'agent/people-manager-milestone1-20260908'
$ProductionTargetSha = '54e1192309b96c9838676be51a0bfcdb3ac92e06'

if (-not (Test-Path -LiteralPath $ServerScript)) {
    throw "Required Synology route runner is missing: $ServerScript"
}

$currentBranch = (& git -C $RepoRoot branch --show-current).Trim()
if ($LASTEXITCODE -ne 0 -or $currentBranch -ne $ExpectedBranch) {
    throw "Run this route wrapper from branch $ExpectedBranch. Current branch: $currentBranch"
}

$dirty = (& git -C $RepoRoot status --porcelain)
if ($LASTEXITCODE -ne 0) {
    throw 'Unable to verify local Git worktree status.'
}
if ($dirty) {
    throw 'Local worktree is not clean. Pull/commit/stash/revert before packaging the route deployment.'
}

& git -C $RepoRoot cat-file -e "${ProductionTargetSha}^{commit}"
if ($LASTEXITCODE -ne 0) {
    throw "People Production target commit is not available locally: $ProductionTargetSha"
}

$stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$bundleName = "msb-people-synology-route-$stamp"
$localBundle = Join-Path ([System.IO.Path]::GetTempPath()) $bundleName
$remoteRoot = "/tmp/$bundleName"
$utf8NoBom = New-Object System.Text.UTF8Encoding($false)

Write-Host '========== PEOPLE MANAGER SYNLOGY PROTECTED ROUTE DEPLOYMENT =========='
Write-Host "Synology:          ${SynologyServer}:$SynologyPort"
Write-Host "People backend:    http://192.168.5.9:8796/"
Write-Host "Public route:      https://my.sheboyganlights.org/people/"
Write-Host "Production target: $ProductionTargetSha"
Write-Host 'Authority: MSB-Server-Management — Synology_Protected_Application_Reverse_Proxy.md'
Write-Host 'Service authority: MSB-Server-Management — Protected_Flask_Application_Service_Deployment.md'
Write-Host
Write-Host 'Run this only after the People production backend wrapper has passed.'
Write-Host

try {
    New-Item -ItemType Directory -Path $localBundle -Force | Out-Null
    $serverText = [System.IO.File]::ReadAllText($ServerScript)
    $serverText = $serverText.Replace("`r`n", "`n").Replace("`r", "`n")
    $localServer = Join-Path $localBundle 'people_manager_synology_route_deploy_server.sh'
    [System.IO.File]::WriteAllText($localServer, $serverText, $utf8NoBom)

    & scp -P $SynologyPort -r $localBundle "${SynologyServer}:/tmp/"
    if ($LASTEXITCODE -ne 0) {
        throw "SCP People Synology route bundle failed with exit code $LASTEXITCODE"
    }

    Write-Host
    Write-Host 'Starting bounded Synology /people/ route deployment...'
    & ssh -tt -p $SynologyPort $SynologyServer "bash -n '$remoteRoot/people_manager_synology_route_deploy_server.sh' && chmod 700 '$remoteRoot/people_manager_synology_route_deploy_server.sh'; timeout --signal=TERM 600s bash '$remoteRoot/people_manager_synology_route_deploy_server.sh'"
    $remoteExit = $LASTEXITCODE

    if ($remoteExit -ne 0) {
        throw "People Synology route deployment failed with exit code $remoteExit. Review the remote /tmp/MSB_People_Synology_Route_Deploy_*.txt report named in the output."
    }

    Write-Host
    Write-Host 'PEOPLE MANAGER SYNLOGY ROUTE WRAPPER: PASS'
    Write-Host 'Next: open https://my.sheboyganlights.org/people/ through normal Cloudflare-authenticated browser access.'
}
finally {
    if (Test-Path -LiteralPath $localBundle) {
        Remove-Item -LiteralPath $localBundle -Recurse -Force -ErrorAction SilentlyContinue
    }
}
