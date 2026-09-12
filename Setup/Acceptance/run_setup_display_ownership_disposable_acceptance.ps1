param(
    [string]$Server = 'msbadmin@192.168.5.9',
    [Parameter(Mandatory=$true)]
    [string]$CandidateSha,
    [string]$TargetRef = 'agent/setup-141-display-ownership'
)

$ErrorActionPreference = 'Stop'

$repo = (git rev-parse --show-toplevel).Trim()
if (-not $repo) {
    throw 'Run this wrapper from the MSB-Production-Database-Project checkout.'
}

$head = (git -C $repo rev-parse HEAD).Trim()
if ($head -ne $CandidateSha) {
    throw "STOP: checkout HEAD $head does not equal requested candidate $CandidateSha"
}

$status = git -C $repo status --porcelain
if ($LASTEXITCODE -ne 0) {
    throw 'Unable to verify local Git worktree status.'
}
if ($status) {
    throw "STOP: checkout is not clean.`n$status"
}

$source = Join-Path $repo 'Setup\Acceptance\setup_display_ownership_disposable_acceptance_server.sh'
if (-not (Test-Path -LiteralPath $source -PathType Leaf)) {
    throw "Required acceptance runner is missing: $source"
}

$stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$localBundle = Join-Path $env:TEMP "msb-setup-display-ownership-$stamp"
$remoteBundle = "/tmp/msb-setup-display-ownership-$stamp"
$runner = Join-Path $localBundle 'setup_display_ownership_disposable_acceptance_server.sh'

try {
    New-Item -ItemType Directory -Path $localBundle -Force | Out-Null
    $text = [System.IO.File]::ReadAllText($source).Replace("`r`n", "`n").Replace("`r", "`n")
    [System.IO.File]::WriteAllText($runner, $text, [System.Text.UTF8Encoding]::new($false))

    Write-Host '========== SETUP DISPLAY OWNERSHIP DISPOSABLE ACCEPTANCE =========='
    Write-Host 'Authority: Gregovate/MSB-Server-Management — docs/server/PostgreSQL_Disposable_Acceptance_Standard.md'
    Write-Host "Server:        $Server"
    Write-Host "Candidate SHA: $CandidateSha"
    Write-Host "Target ref:    $TargetRef"
    Write-Host 'Production database contract: pg_dump + SELECT only'
    Write-Host 'All schema/data writes: disposable current-Production clone only'
    Write-Host

    & scp -r $localBundle "${Server}:/tmp/"
    if ($LASTEXITCODE -ne 0) {
        throw "SCP failed with exit code $LASTEXITCODE"
    }

    $remoteRunner = "$remoteBundle/setup_display_ownership_disposable_acceptance_server.sh"
    & ssh -tt $Server "chmod 700 '$remoteRunner' && bash -n '$remoteRunner' && bash '$remoteRunner' '$TargetRef' '$CandidateSha' '$remoteBundle'"
    if ($LASTEXITCODE -ne 0) {
        throw "Setup Display ownership disposable acceptance failed with exit code $LASTEXITCODE"
    }
}
finally {
    Remove-Item -LiteralPath $localBundle -Recurse -Force -ErrorAction SilentlyContinue
}
