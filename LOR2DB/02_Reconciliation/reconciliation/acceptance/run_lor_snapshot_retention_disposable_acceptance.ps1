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

$legacyWrapper = Join-Path $repo 'LOR2DB\02_Reconciliation\reconciliation\acceptance\run_lor_snapshot_retention_disposable_acceptance_legacy.ps1'
$automaticServerScript = Join-Path $repo 'LOR2DB\02_Reconciliation\reconciliation\acceptance\lor_snapshot_retention_automatic_disposable_server.sh'

foreach ($required in @($legacyWrapper, $automaticServerScript)) {
    if (-not (Test-Path -LiteralPath $required -PathType Leaf)) {
        throw "Required #186 acceptance artifact is missing: $required"
    }
}

Write-Host '========== #186 DISPOSABLE ACCEPTANCE — PHASE 1 =========='
Write-Host 'Running the previously accepted comprehensive retention harness.'
Write-Host

& $legacyWrapper `
    -Server $Server `
    -CandidateSha $CandidateSha `
    -TargetRef $TargetRef
if ($LASTEXITCODE -ne 0) {
    throw "Legacy/comprehensive #186 disposable acceptance failed with exit code $LASTEXITCODE"
}

Write-Host
Write-Host '========== #186 DISPOSABLE ACCEPTANCE — PHASE 2 =========='
Write-Host 'Running automatic post-report retention acceptance on a fresh disposable current-Production clone.'
Write-Host

$stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$bundleName = "msb-lor-auto-retention-$stamp"
$localBundle = Join-Path $env:TEMP $bundleName
$remoteBundle = "/tmp/$bundleName"
$localRunner = Join-Path $localBundle 'lor_snapshot_retention_automatic_disposable_server.sh'
$localManifest = Join-Path $localBundle 'acceptance_manifest.tsv'
$utf8NoBom = [System.Text.UTF8Encoding]::new($false)

try {
    New-Item -ItemType Directory -Path $localBundle -Force | Out-Null

    $runnerText = [System.IO.File]::ReadAllText($automaticServerScript)
    $runnerText = $runnerText.Replace("`r`n", "`n").Replace("`r", "`n")
    [System.IO.File]::WriteAllText($localRunner, $runnerText, $utf8NoBom)

    $manifestText = (
        "candidate_sha`t$CandidateSha`n" +
        "target_ref`t$TargetRef`n"
    )
    [System.IO.File]::WriteAllText($localManifest, $manifestText, $utf8NoBom)

    if ($runnerText.Contains("`r") -or $manifestText.Contains("`r")) {
        throw 'Generated Linux automatic-retention acceptance bundle contains CR characters; refusing to upload.'
    }

    & scp -r $localBundle "${Server}:/tmp/"
    if ($LASTEXITCODE -ne 0) {
        throw "SCP automatic-retention acceptance bundle upload failed with exit code $LASTEXITCODE"
    }

    $remoteRunner = "$remoteBundle/lor_snapshot_retention_automatic_disposable_server.sh"
    $remoteManifest = "$remoteBundle/acceptance_manifest.tsv"
    $remoteCommand = "chmod 700 '$remoteRunner' && bash -n '$remoteRunner' && timeout --foreground --signal=TERM 7200s bash '$remoteRunner' '$remoteManifest'"

    & ssh -tt -o ServerAliveInterval=15 -o ServerAliveCountMax=3 $Server $remoteCommand
    $remoteExit = $LASTEXITCODE
    if ($remoteExit -ne 0) {
        throw "Automatic LOR snapshot-retention disposable acceptance failed with exit code $remoteExit. Review the retained remote report for the failed gate."
    }

    Write-Host
    Write-Host '#186 LOR SNAPSHOT RETENTION DISPOSABLE ACCEPTANCE: BOTH PHASES PASSED'
}
finally {
    Remove-Item -LiteralPath $localBundle -Recurse -Force -ErrorAction SilentlyContinue
}
