param(
    [string]$Server = 'msbadmin@192.168.5.9'
)

$ErrorActionPreference = 'Stop'

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$RepoRoot = (Resolve-Path (Join-Path $ScriptDir '..\..')).Path
$Sql005 = Join-Path $RepoRoot 'People\Database\005_reconcile_directus_person_identity.sql'
$ServerScript = Join-Path $ScriptDir 'people_identity_reconciliation_disposable_server.sh'

$SourceRef = 'origin/agent/385-directus-person-self-reconcile'
$CandidateSha = 'fc831af3986e83c01501057c48f305f8c23672e0'

foreach ($path in @($Sql005, $ServerScript)) {
    if (-not (Test-Path -LiteralPath $path)) {
        throw "Required acceptance file is missing: $path"
    }
}

& git -C $RepoRoot fetch origin agent/385-directus-person-self-reconcile
if ($LASTEXITCODE -ne 0) {
    throw 'Unable to refresh the Issue #385 candidate ref.'
}

$dirty = (& git -C $RepoRoot status --porcelain)
if ($LASTEXITCODE -ne 0) { throw 'Unable to verify local Git worktree status.' }
if ($dirty) { throw 'Local worktree is not clean. Pull/commit/stash/revert before acceptance.' }

& git -C $RepoRoot cat-file -e "$CandidateSha^{commit}"
if ($LASTEXITCODE -ne 0) { throw "Accepted candidate SHA is not available locally: $CandidateSha" }

& git -C $RepoRoot merge-base --is-ancestor $CandidateSha $SourceRef
if ($LASTEXITCODE -ne 0) { throw "Remote Issue #385 ref no longer contains candidate SHA $CandidateSha" }

$runtimeChanges = @(& git -C $RepoRoot diff --name-only "$CandidateSha..$SourceRef" -- People/Database People/Application/backend.py People/Application/test_people_manager_contract.py People/Application/test_people_shared_tablet_identity_contract.py)
if ($LASTEXITCODE -ne 0) { throw 'Unable to verify exact identity-reconciliation candidate.' }
if ($runtimeChanges.Count -gt 0) {
    throw ("Identity runtime changed after candidate SHA. Acceptance refused. " + ($runtimeChanges -join ', '))
}

Write-Host '========== DIRECTUS <-> PERSON IDENTITY ACCEPTANCE =========='
Write-Host "Candidate SHA: $CandidateSha"
Write-Host "Source ref:    $SourceRef"
Write-Host
Write-Host 'Running local contract regression...'

Push-Location $RepoRoot
try {
    python -m pytest -q -p no:cacheprovider People/Application/test_people_manager_contract.py
    if ($LASTEXITCODE -ne 0) { throw "People identity contract tests failed with exit code $LASTEXITCODE" }
}
finally {
    Pop-Location
}

$stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$bundleName = "msb-identity-reconcile-acceptance-$stamp"
$localBundle = Join-Path ([System.IO.Path]::GetTempPath()) $bundleName
$remoteRoot = "/tmp/$bundleName"
$utf8NoBom = New-Object System.Text.UTF8Encoding($false)

Write-Host
Write-Host 'Preparing current-Production disposable-clone acceptance...'
Write-Host "Server:      $Server"
Write-Host "Remote root: $remoteRoot"
Write-Host 'Authority: MSB-Server-Management — PostgreSQL_Disposable_Acceptance_Standard.md'
Write-Host 'Production access in the remote runner is pg_dump + SELECT only.'
Write-Host

try {
    New-Item -ItemType Directory -Path $localBundle -Force | Out-Null
    Copy-Item -LiteralPath $Sql005 -Destination (Join-Path $localBundle '005_reconcile_directus_person_identity.sql')

    $serverText = [System.IO.File]::ReadAllText($ServerScript)
    $serverText = $serverText.Replace("`r`n", "`n").Replace("`r", "`n")
    [System.IO.File]::WriteAllText((Join-Path $localBundle 'people_identity_reconciliation_disposable_server.sh'), $serverText, $utf8NoBom)

    & scp -r $localBundle "${Server}:/tmp/"
    if ($LASTEXITCODE -ne 0) { throw "SCP acceptance bundle upload failed with exit code $LASTEXITCODE" }

    Write-Host
    Write-Host 'Starting bounded disposable acceptance (20 minute maximum)...'
    & ssh -tt $Server "chmod 700 '$remoteRoot/people_identity_reconciliation_disposable_server.sh'; timeout --signal=TERM 1200s bash '$remoteRoot/people_identity_reconciliation_disposable_server.sh'"
    $remoteExit = $LASTEXITCODE

    if ($remoteExit -ne 0) {
        throw "Identity reconciliation disposable acceptance failed with exit code $remoteExit. Review the remote /tmp/MSB_Identity_Reconcile_Disposable_*.txt report named in the output."
    }

    Write-Host
    Write-Host 'DIRECTUS <-> PERSON IDENTITY DISPOSABLE WRAPPER: PASS'
}
finally {
    if (Test-Path -LiteralPath $localBundle) {
        Remove-Item -LiteralPath $localBundle -Recurse -Force -ErrorAction SilentlyContinue
    }
}
