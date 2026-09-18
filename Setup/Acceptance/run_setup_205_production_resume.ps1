param(
    [string]$Server = 'msbadmin@192.168.5.9'
)

$ErrorActionPreference = 'Stop'

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$RepoRoot = (Resolve-Path (Join-Path $ScriptDir '..\\..')).Path
$ServerScript = Join-Path $ScriptDir 'setup_205_production_resume_server.sh'
$ExpectedBranch = 'main'
$ExpectedLiveSha = '052d31dd4e68e13f2997f723778b88eddf9c53cf'
$AcceptedTargetSha = '8161e91384cb13587fa0c92da2f80f6cf770592d'

if (-not (Test-Path -LiteralPath $ServerScript -PathType Leaf)) {
    throw "Required #205 Production resume runner is missing: $ServerScript"
}

$currentBranch = (& git -C $RepoRoot branch --show-current).Trim()
if ($LASTEXITCODE -ne 0 -or $currentBranch -ne $ExpectedBranch) {
    throw "Run this recovery wrapper from merged branch $ExpectedBranch. Current branch: $currentBranch"
}

$dirty = (& git -C $RepoRoot status --porcelain)
if ($LASTEXITCODE -ne 0) {
    throw 'Unable to verify local Git worktree status.'
}
if ($dirty) {
    throw "Local worktree is not clean. Commit/stash/revert local changes before Production recovery."
}

& git -C $RepoRoot cat-file -e "$AcceptedTargetSha^{commit}"
if ($LASTEXITCODE -ne 0) {
    throw "Accepted Setup #205 target is not available locally: $AcceptedTargetSha"
}

& git -C $RepoRoot merge-base --is-ancestor $AcceptedTargetSha HEAD
if ($LASTEXITCODE -ne 0) {
    throw "Merged main does not contain accepted Setup #205 target $AcceptedTargetSha."
}

Write-Host '--- Local #205 Production-resume contract ---'
& python -m pytest -q -p no:cacheprovider (Join-Path $RepoRoot 'Setup\\Acceptance\\test_setup_205_production_resume_contract.py')
if ($LASTEXITCODE -ne 0) {
    throw "STOP: #205 Production-resume contract failed with exit code $LASTEXITCODE"
}
Write-Host 'PASS: #205 Production-resume contract'
Write-Host

$stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$bundleName = "msb-setup-205-production-resume-$stamp"
$localBundle = Join-Path ([System.IO.Path]::GetTempPath()) $bundleName
$remoteRoot = "/tmp/$bundleName"
$utf8NoBom = New-Object System.Text.UTF8Encoding($false)

Write-Host '========== SETUP #205 PRODUCTION RESUME =========='
Write-Host "Server:                  $Server"
Write-Host "Expected live SHA:       $ExpectedLiveSha"
Write-Host "Accepted target SHA:     $AcceptedTargetSha"
Write-Host "Expected target version: V0.3.14-scheduling-board"
Write-Host "Remote root:             $remoteRoot"
Write-Host 'Authority: Gregovate/MSB-Server-Management — docs/server/Setup_Source_Only_Application_Deployment_Runbook.md'
Write-Host 'Procedure: source-only Setup application deployment from the already-validated post-050 database state'
Write-Host 'Database mutation in this resume: NONE'
Write-Host

try {
    New-Item -ItemType Directory -Path $localBundle -Force | Out-Null

    $serverText = [System.IO.File]::ReadAllText($ServerScript)
    $serverText = $serverText.Replace([char]13 + [char]10, [char]10).Replace([char]13, [char]10)
    $localServer = Join-Path $localBundle 'setup_205_production_resume_server.sh'
    [System.IO.File]::WriteAllText($localServer, $serverText, $utf8NoBom)

    if ($serverText.Contains([char]13)) {
        throw 'Generated Linux recovery runner contains CR characters; refusing to upload.'
    }

    $remoteDestination = ("{0}:/tmp/" -f $Server)
    & scp -r $localBundle $remoteDestination
    if ($LASTEXITCODE -ne 0) {
        throw "SCP recovery bundle upload failed with exit code $LASTEXITCODE"
    }

    Write-Host
    Write-Host 'Starting bounded source-only Production recovery...'
    $remoteScript = "$remoteRoot/setup_205_production_resume_server.sh"
    $remoteCommand = "chmod 700 '$remoteScript' && bash -n '$remoteScript' && timeout --foreground --signal=TERM 3600s bash '$remoteScript'"
    & ssh -tt -o ServerAliveInterval=15 -o ServerAliveCountMax=3 $Server $remoteCommand
    $remoteExit = $LASTEXITCODE

    if ($remoteExit -ne 0) {
        throw "Setup #205 Production resume failed with exit code $remoteExit. Stop and review the retained recovery report before any further action."
    }

    Write-Host
    Write-Host 'SETUP #205 PRODUCTION RESUME WRAPPER: PASS'
}
finally {
    if (Test-Path -LiteralPath $localBundle) {
        Remove-Item -LiteralPath $localBundle -Recurse -Force -ErrorAction SilentlyContinue
    }
}
