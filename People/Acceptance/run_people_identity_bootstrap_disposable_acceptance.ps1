param(
    [string]$Server = 'msbadmin@192.168.5.9'
)

$ErrorActionPreference = 'Stop'

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$RepoRoot = (Resolve-Path (Join-Path $ScriptDir '..\..')).Path
$ServerScript = Join-Path $ScriptDir 'people_identity_bootstrap_disposable_server.sh'

$SourceBranch = 'issue-395-silent-human-identity-bootstrap'
$SourceRef = "origin/$SourceBranch"

if (-not (Test-Path -LiteralPath $ServerScript)) {
    throw "Required acceptance file is missing: $ServerScript"
}

$origin = (& git -C $RepoRoot remote get-url origin).Trim()
if ($LASTEXITCODE -ne 0 -or $origin -notmatch 'Gregovate/MSB-Production-Database-Project') {
    throw "STOP: wrong repository. origin=$origin"
}

$branch = (& git -C $RepoRoot branch --show-current).Trim()
if ($LASTEXITCODE -ne 0 -or $branch -ne $SourceBranch) {
    throw "STOP: switch to '$SourceBranch' before running #395 acceptance. Current branch: '$branch'"
}

$dirty = @(& git -C $RepoRoot status --porcelain)
if ($LASTEXITCODE -ne 0) {
    throw 'Unable to verify local Git worktree status.'
}
if ($dirty.Count -gt 0) {
    throw 'Local worktree is not clean. Commit/stash/revert before acceptance.'
}

& git -C $RepoRoot fetch origin $SourceBranch
if ($LASTEXITCODE -ne 0) {
    throw 'Unable to refresh the #395 candidate branch.'
}

$CandidateSha = (& git -C $RepoRoot rev-parse HEAD).Trim()
$RemoteSha = (& git -C $RepoRoot rev-parse $SourceRef).Trim()
if ($LASTEXITCODE -ne 0 -or -not $CandidateSha -or -not $RemoteSha) {
    throw 'Unable to resolve the exact #395 candidate SHA.'
}
if ($CandidateSha -ne $RemoteSha) {
    throw "STOP: local candidate does not equal remote branch. Local=$CandidateSha Remote=$RemoteSha"
}

Write-Host '========== PEOPLE #395 SILENT IDENTITY BOOTSTRAP ACCEPTANCE =========='
Write-Host "Candidate SHA: $CandidateSha"
Write-Host "Source ref:    $SourceRef"
Write-Host "Server:        $Server"
Write-Host
Write-Host 'Authority: MSB-Server-Management — docs/server/PostgreSQL_Disposable_Acceptance_Standard.md'
Write-Host 'Production database access is pg_dump + SELECT only.'
Write-Host 'The acceptance runner starts separate disposable PostgreSQL and Directus containers.'
Write-Host 'The live People service, live Directus container, and Don Martens fixture are not mutated.'
Write-Host

$stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$bundleName = "msb-395-bootstrap-acceptance-$stamp"
$localBundle = Join-Path ([System.IO.Path]::GetTempPath()) $bundleName
$remoteRoot = "/tmp/$bundleName"
$utf8NoBom = New-Object System.Text.UTF8Encoding($false)

try {
    New-Item -ItemType Directory -Path $localBundle -Force | Out-Null

    $serverText = [System.IO.File]::ReadAllText($ServerScript)
    $serverText = $serverText.Replace(([string][char]13 + [char]10), [string][char]10).Replace([string][char]13, [string][char]10)
    $localServer = Join-Path $localBundle 'people_identity_bootstrap_disposable_server.sh'
    [System.IO.File]::WriteAllText($localServer, $serverText, $utf8NoBom)

    if ($serverText.Contains([char]13)) {
        throw 'STOP: generated Linux acceptance runner contains CR characters.'
    }

    & scp -r $localBundle "${Server}:/tmp/"
    if ($LASTEXITCODE -ne 0) {
        throw "SCP acceptance bundle upload failed with exit code $LASTEXITCODE"
    }

    $remoteScript = "$remoteRoot/people_identity_bootstrap_disposable_server.sh"
    $remoteCommand = "chmod 700 '$remoteScript' && bash -n '$remoteScript' && timeout --foreground --signal=TERM 1800s bash '$remoteScript' '$CandidateSha'"

    Write-Host
    Write-Host 'Starting bounded current-Production disposable acceptance (30 minute maximum)...'
    Write-Host

    & ssh -tt -o ServerAliveInterval=15 -o ServerAliveCountMax=3 $Server $remoteCommand
    $remoteExit = $LASTEXITCODE

    if ($remoteExit -ne 0) {
        throw "People #395 disposable acceptance stopped with exit code $remoteExit. Review the retained /tmp/MSB_People_Identity_Bootstrap_Disposable_*.txt report named in the server output before further work."
    }

    Write-Host
    Write-Host 'PEOPLE #395 SILENT IDENTITY BOOTSTRAP DISPOSABLE WRAPPER: PASS'
    Write-Host 'No Production identity was changed.'
    Write-Host 'Next gate after engineering review: exact-candidate browser/application integration review; do not consume Don yet.'
}
finally {
    if (Test-Path -LiteralPath $localBundle) {
        Remove-Item -LiteralPath $localBundle -Recurse -Force -ErrorAction SilentlyContinue
    }
}
