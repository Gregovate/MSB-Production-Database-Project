param(
    [string]$Server = 'msbadmin@192.168.5.9',
    [Parameter(Mandatory=$true)]
    [string]$CandidateSha,
    [Parameter(Mandatory=$true)]
    [string]$TargetRef
)

$ErrorActionPreference = 'Stop'

$repo = (git rev-parse --show-toplevel).Trim()
if (-not $repo) {
    throw 'Run this wrapper from the MSB-Production-Database-Project checkout.'
}

$currentBranch = (git -C $repo branch --show-current).Trim()
if ($LASTEXITCODE -ne 0 -or $currentBranch -ne $TargetRef) {
    throw "STOP before server contact: current branch '$currentBranch' does not equal TargetRef '$TargetRef'."
}

$head = (git -C $repo rev-parse HEAD).Trim()
if ($head -ne $CandidateSha) {
    throw "STOP before server contact: checkout HEAD $head does not equal requested candidate $CandidateSha."
}

$dirty = git -C $repo status --porcelain
if ($LASTEXITCODE -ne 0) {
    throw 'Unable to verify local Git worktree status.'
}
if ($dirty) {
    throw "STOP before server contact: local candidate worktree is not clean.`n$dirty"
}

& git -C $repo cat-file -e "${CandidateSha}^{commit}"
if ($LASTEXITCODE -ne 0) {
    throw "Candidate SHA is not available locally: $CandidateSha"
}

$requiredCandidatePaths = @(
    'LOR2DB/02_Reconciliation/reconciliation/migrations/0042_decouple_snapshot_provenance_and_add_retention.sql',
    'LOR2DB/02_Reconciliation/reconciliation/validation/37_lor_snapshot_retention_validation.sql',
    'LOR2DB/02_Reconciliation/reconciliation/acceptance/lor_snapshot_retention_disposable_server.sh',
    'LOR2DB/Application/test_snapshot_retention_migration.py'
)

foreach ($path in $requiredCandidatePaths) {
    & git -C $repo cat-file -e "${CandidateSha}:$path" 2>$null
    if ($LASTEXITCODE -ne 0) {
        throw "Exact candidate $CandidateSha is missing required #186 file: $path"
    }
}

$serverScript = Join-Path $repo 'LOR2DB\02_Reconciliation\reconciliation\acceptance\lor_snapshot_retention_disposable_server.sh'
if (-not (Test-Path -LiteralPath $serverScript -PathType Leaf)) {
    throw "Snapshot-retention disposable server runner is missing: $serverScript"
}

$stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$bundleName = "msb-lor-snapshot-retention-$stamp"
$localBundle = Join-Path $env:TEMP $bundleName
$remoteBundle = "/tmp/$bundleName"
$localRunner = Join-Path $localBundle 'lor_snapshot_retention_disposable_server.sh'
$localManifest = Join-Path $localBundle 'acceptance_manifest.tsv'
$utf8NoBom = [System.Text.UTF8Encoding]::new($false)

try {
    New-Item -ItemType Directory -Path $localBundle -Force | Out-Null

    $runnerText = [System.IO.File]::ReadAllText($serverScript)
    $runnerText = $runnerText.Replace("`r`n", "`n").Replace("`r", "`n")
    [System.IO.File]::WriteAllText($localRunner, $runnerText, $utf8NoBom)

    $manifestText = (
        "candidate_sha`t$CandidateSha`n" +
        "target_ref`t$TargetRef`n"
    )
    [System.IO.File]::WriteAllText($localManifest, $manifestText, $utf8NoBom)

    if ($runnerText.Contains("`r") -or $manifestText.Contains("`r")) {
        throw 'Generated Linux acceptance bundle contains CR characters; refusing to upload.'
    }

    Write-Host '========== LOR SNAPSHOT RETENTION DISPOSABLE ACCEPTANCE =========='
    Write-Host 'Authority: Gregovate/MSB-Server-Management — docs/server/PostgreSQL_Disposable_Acceptance_Standard.md'
    Write-Host "Server:        $Server"
    Write-Host "Candidate SHA: $CandidateSha"
    Write-Host "Target ref:    $TargetRef"
    Write-Host
    Write-Host 'Production database contract: pg_dump + SELECT only.'
    Write-Host 'All migration, FK, and prune writes: disposable current-Production clone only.'
    Write-Host

    & scp -r $localBundle "${Server}:/tmp/"
    if ($LASTEXITCODE -ne 0) {
        throw "SCP acceptance bundle upload failed with exit code $LASTEXITCODE"
    }

    $remoteRunner = "$remoteBundle/lor_snapshot_retention_disposable_server.sh"
    $remoteManifest = "$remoteBundle/acceptance_manifest.tsv"
    $remoteCommand = "chmod 700 '$remoteRunner' && bash -n '$remoteRunner' && timeout --foreground --signal=TERM 7200s bash '$remoteRunner' '$remoteManifest'"

    & ssh -tt -o ServerAliveInterval=15 -o ServerAliveCountMax=3 $Server $remoteCommand
    $remoteExit = $LASTEXITCODE
    if ($remoteExit -ne 0) {
        throw "LOR snapshot-retention disposable acceptance failed with exit code $remoteExit. Review the retained remote report for the failed gate."
    }

    Write-Host
    Write-Host 'LOR SNAPSHOT RETENTION DISPOSABLE ACCEPTANCE: CLEAN EXIT'
}
finally {
    Remove-Item -LiteralPath $localBundle -Recurse -Force -ErrorAction SilentlyContinue
}
