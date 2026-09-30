param(
    [string]$Server = 'msbadmin@192.168.5.9',
    [Parameter(Mandatory=$true)]
    [string]$CandidateSha,
    [Parameter(Mandatory=$true)]
    [string]$TargetRef,
    [string[]]$MigrationPaths = @(),
    [string[]]$ValidationPaths = @()
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

$toolingHead = (git -C $repo rev-parse HEAD).Trim()
& git -C $repo merge-base --is-ancestor $CandidateSha $toolingHead
if ($LASTEXITCODE -ne 0) {
    throw "STOP before server contact: requested candidate $CandidateSha is not an ancestor of current acceptance-tooling HEAD $toolingHead."
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

function Get-CandidateSetupBuildIdentity {
    param(
        [Parameter(Mandatory=$true)]
        [string]$Sha
    )

    $backend = ((& git -C $repo show "${Sha}:Setup/Application/production_backend.py") | Out-String)
    if ($LASTEXITCODE -ne 0) {
        throw "STOP before server contact: exact candidate $Sha is missing Setup/Application/production_backend.py."
    }

    $client = ((& git -C $repo show "${Sha}:Setup/Application/setup_catalog_dirty_guard.js") | Out-String)
    if ($LASTEXITCODE -ne 0) {
        throw "STOP before server contact: exact candidate $Sha is missing Setup/Application/setup_catalog_dirty_guard.js."
    }

    $serverMatch = [regex]::Match($backend, 'PRODUCTION_VERSION\s*=\s*"([^"]+)"')
    $clientMatch = [regex]::Match($client, "CLIENT_BUILD\s*=\s*'([^']+)'")
    if (-not $serverMatch.Success -or -not $clientMatch.Success) {
        throw "STOP before server contact: unable to resolve exact Setup server/client build identities from candidate $Sha."
    }

    [pscustomobject]@{
        Server = $serverMatch.Groups[1].Value
        Client = $clientMatch.Groups[1].Value
    }
}

$buildIdentity = Get-CandidateSetupBuildIdentity -Sha $CandidateSha
if ($buildIdentity.Server -ne $buildIdentity.Client) {
    throw "STOP before server contact: Setup client/server version mismatch in exact candidate $CandidateSha. Client $($buildIdentity.Client); server $($buildIdentity.Server)."
}

function Assert-SafeCandidatePath {
    param(
        [Parameter(Mandatory=$true)][string]$Path,
        [Parameter(Mandatory=$true)][string]$Kind
    )

    if ([string]::IsNullOrWhiteSpace($Path)) {
        throw "$Kind path cannot be blank."
    }
    if ([System.IO.Path]::IsPathRooted($Path) -or $Path.Contains('..') -or $Path.Contains("`t") -or $Path.Contains("`r") -or $Path.Contains("`n")) {
        throw "Unsafe $Kind candidate-relative path: $Path"
    }
    if ($Kind -eq 'migration') {
        $isSetupMigration = $Path.StartsWith('Setup/Database/')
        $isApprovedSharedMigration = $Path -eq 'Database/Basic_Query_Tools_Dev/Repair-SetActorOnUpdate-Attribution.sql'
        if (-not ($isSetupMigration -or $isApprovedSharedMigration)) {
            throw "Migration path must be under Setup/Database/ or explicitly approved shared database repair: $Path"
        }
    }
    if ($Kind -eq 'validation') {
        $isSetupValidation = $Path.StartsWith('Setup/Acceptance/')
        $isApprovedSharedValidation = $Path -eq 'Database/Acceptance/database_shared_audit_actor_disposable_validation.sql'
        if (-not ($isSetupValidation -or $isApprovedSharedValidation)) {
            throw "Validation path must be under Setup/Acceptance/ or explicitly approved shared database validation: $Path"
        }
    }

    & git -C $repo cat-file -e "${CandidateSha}:$Path" 2>$null
    if ($LASTEXITCODE -ne 0) {
        throw "Exact candidate $CandidateSha is missing $Kind file: $Path"
    }
}

foreach ($path in $MigrationPaths) {
    Assert-SafeCandidatePath -Path $path -Kind 'migration'
}
foreach ($path in $ValidationPaths) {
    Assert-SafeCandidatePath -Path $path -Kind 'validation'
}

$serverScript = Join-Path $repo 'Setup\Acceptance\setup_disposable_acceptance_server.sh'
if (-not (Test-Path -LiteralPath $serverScript -PathType Leaf)) {
    throw "Reusable Setup disposable-acceptance server runner is missing: $serverScript"
}
& git -C $repo cat-file -e "${CandidateSha}:Setup/Acceptance/setup_disposable_acceptance_server.sh" 2>$null
if ($LASTEXITCODE -ne 0) {
    throw 'Exact candidate does not contain the reusable Setup disposable-acceptance server runner.'
}

$stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$bundleName = "msb-setup-disposable-acceptance-$stamp"
$localBundle = Join-Path $env:TEMP $bundleName
$remoteBundle = "/tmp/$bundleName"
$localRunner = Join-Path $localBundle 'setup_disposable_acceptance_server.sh'
$localManifest = Join-Path $localBundle 'acceptance_manifest.tsv'
$utf8NoBom = [System.Text.UTF8Encoding]::new($false)

try {
    New-Item -ItemType Directory -Path $localBundle -Force | Out-Null

    $runnerText = [System.IO.File]::ReadAllText($serverScript)
    $runnerText = $runnerText.Replace("`r`n", "`n").Replace("`r", "`n")
    [System.IO.File]::WriteAllText($localRunner, $runnerText, $utf8NoBom)

    $manifestLines = @(
        "candidate_sha`t$CandidateSha",
        "target_ref`t$TargetRef"
    )
    foreach ($path in $MigrationPaths) {
        $manifestLines += "migration`t$path"
    }
    foreach ($path in $ValidationPaths) {
        $manifestLines += "validation`t$path"
    }
    $manifestText = ($manifestLines -join "`n") + "`n"
    [System.IO.File]::WriteAllText($localManifest, $manifestText, $utf8NoBom)

    if ($runnerText.Contains("`r") -or $manifestText.Contains("`r")) {
        throw 'Generated Linux acceptance bundle contains CR characters; refusing to upload.'
    }

    Write-Host '========== SETUP REUSABLE DISPOSABLE ACCEPTANCE =========='
    Write-Host 'Authority: Gregovate/MSB-Server-Management — docs/server/PostgreSQL_Disposable_Acceptance_Standard.md'
    Write-Host "Server:        $Server"
    Write-Host "Candidate SHA: $CandidateSha"
    Write-Host "Target ref:    $TargetRef"
    Write-Host "Migrations:    $($MigrationPaths.Count)"
    Write-Host "Validations:   $($ValidationPaths.Count)"
    Write-Host
    Write-Host 'Production database contract: pg_dump + SELECT only.'
    Write-Host 'All candidate writes: disposable current-Production clone only.'
    Write-Host

    & scp -r $localBundle "${Server}:/tmp/"
    if ($LASTEXITCODE -ne 0) {
        throw "SCP acceptance bundle upload failed with exit code $LASTEXITCODE"
    }

    $remoteRunner = "$remoteBundle/setup_disposable_acceptance_server.sh"
    $remoteManifest = "$remoteBundle/acceptance_manifest.tsv"
    $remoteCommand = "chmod 700 '$remoteRunner' && bash -n '$remoteRunner' && timeout --foreground --signal=TERM 7200s bash '$remoteRunner' '$remoteManifest'"

    & ssh -tt -o ServerAliveInterval=15 -o ServerAliveCountMax=3 $Server $remoteCommand
    $remoteExit = $LASTEXITCODE
    if ($remoteExit -ne 0) {
        throw "Reusable Setup disposable acceptance failed with exit code $remoteExit. Review the retained remote report for the failed gate."
    }

    Write-Host
    Write-Host 'SETUP REUSABLE DISPOSABLE ACCEPTANCE: CLEAN EXIT'
}
finally {
    Remove-Item -LiteralPath $localBundle -Recurse -Force -ErrorAction SilentlyContinue
}
