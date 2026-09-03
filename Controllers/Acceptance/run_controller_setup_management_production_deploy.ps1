param(
    [string]$Server = 'msbadmin@192.168.5.9'
)

$ErrorActionPreference = 'Stop'

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$RepoRoot = (Resolve-Path (Join-Path $ScriptDir '..\..')).Path
$ServerScript = Join-Path $ScriptDir 'controller_setup_management_production_deploy_server.sh'
$ExpectedBranch = 'agent/controller-inventory-ref-sandbox'
$CandidateSha = '2fd2067958cc0a903260fe6f089f88ae63a857f1'

if (-not (Test-Path -LiteralPath $ServerScript)) {
    throw "Required deployment runner is missing: $ServerScript"
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
    throw 'Local worktree is not clean. Commit/stash/revert local changes before packaging a production deployment.'
}

& git -C $RepoRoot cat-file -e "${CandidateSha}^{commit}"
if ($LASTEXITCODE -ne 0) {
    throw "Accepted candidate commit is not available locally: $CandidateSha"
}

$stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$bundleName = "msb-controller-setup-management-production-$stamp"
$localBundle = Join-Path ([System.IO.Path]::GetTempPath()) $bundleName
$remoteRoot = "/tmp/$bundleName"
$utf8NoBom = New-Object System.Text.UTF8Encoding($false)

Write-Host '========== CONTROLLER SETUP + MANAGEMENT PRODUCTION DEPLOYMENT =========='
Write-Host "Server:        $Server"
Write-Host "Candidate SHA: $CandidateSha"
Write-Host "Remote root:   $remoteRoot"
Write-Host 'This is the PRODUCTION deployment gate for accepted migrations 023/024 and the exact accepted application candidate.'
Write-Host 'The remote runner creates and validates a rollback DB archive before mutation and fails closed on errors.'
Write-Host

try {
    New-Item -ItemType Directory -Path $localBundle -Force | Out-Null

    $serverText = [System.IO.File]::ReadAllText($ServerScript)
    $serverText = $serverText.Replace("`r`n", "`n").Replace("`r", "`n")
    $localServer = Join-Path $localBundle 'controller_setup_management_production_deploy_server.sh'
    [System.IO.File]::WriteAllText($localServer, $serverText, $utf8NoBom)

    & scp -r $localBundle "${Server}:/tmp/"
    if ($LASTEXITCODE -ne 0) {
        throw "SCP deployment bundle upload failed with exit code $LASTEXITCODE"
    }

    Write-Host
    Write-Host 'Starting bounded production deployment...'
    & ssh -tt $Server "bash -n '$remoteRoot/controller_setup_management_production_deploy_server.sh' && chmod 700 '$remoteRoot/controller_setup_management_production_deploy_server.sh'; timeout --signal=TERM 1800s bash '$remoteRoot/controller_setup_management_production_deploy_server.sh'"
    $remoteExit = $LASTEXITCODE

    if ($remoteExit -ne 0) {
        throw "Controller setup/management production deployment failed with exit code $remoteExit. Review the remote /tmp/MSB_Controller_Setup_Management_Production_Deploy_*.txt report named in the output."
    }

    Write-Host
    Write-Host 'CONTROLLER SETUP + MANAGEMENT PRODUCTION WRAPPER: PASS'
}
finally {
    if (Test-Path -LiteralPath $localBundle) {
        Remove-Item -LiteralPath $localBundle -Recurse -Force -ErrorAction SilentlyContinue
    }
}
