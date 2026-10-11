param(
    [string]$Server = 'msbadmin@192.168.5.9',
    [Parameter(Mandatory=$true)]
    [string]$CandidateSha,
    [Parameter(Mandatory=$true)]
    [string]$TargetRef,
    [string]$LocalReviewBranch = '',
    [string[]]$MigrationPaths = @(),
    [string[]]$ValidationPaths = @(),
    [switch]$AllowConcurrentProductionWrites,
    [switch]$ProductionReadBoundary,
    [string]$GisGpxPath = '',
    [string]$GisFlwPath = '',
    [string]$GisActor = ''
)

$ErrorActionPreference = 'Stop'

$repo = (git rev-parse --show-toplevel).Trim()
if (-not $repo) {
    throw 'Run this wrapper from the MSB-Production-Database-Project checkout.'
}

# Keep the operator's local review branch separate from the remote candidate
# branch the governed server fetches. Do not alter existing callers: absent
# LocalReviewBranch, the original current-branch-equals-TargetRef rule applies.
if ([string]::IsNullOrWhiteSpace($LocalReviewBranch)) {
    $LocalReviewBranch = $TargetRef
}
if ($LocalReviewBranch -notmatch '^[A-Za-z0-9._/-]+$' -or
    $TargetRef -notmatch '^[A-Za-z0-9._/-]+$' -or
    $LocalReviewBranch.Contains('..') -or $TargetRef.Contains('..')) {
    throw 'STOP before server contact: invalid local or remote Git ref.'
}
$currentBranch = (git -C $repo branch --show-current).Trim()
if ($LASTEXITCODE -ne 0 -or $currentBranch -ne $LocalReviewBranch) {
    throw "STOP before server contact: current branch '$currentBranch' does not equal LocalReviewBranch '$LocalReviewBranch'."
}

# Candidate must be the exact fetched remote branch head; a local review
# branch may not silently substitute a different SHA.
& git -C $repo show-ref --verify --quiet "refs/remotes/origin/$TargetRef"
if ($LASTEXITCODE -ne 0) {
    throw "STOP before server contact: no fetched origin/$TargetRef remote-tracking ref."
}
$remoteHead = (& git -C $repo rev-parse "refs/remotes/origin/$TargetRef").Trim()
if ($LASTEXITCODE -ne 0 -or $remoteHead -ne $CandidateSha) {
    throw "STOP before server contact: origin/$TargetRef is '$remoteHead', not exact CandidateSha '$CandidateSha'."
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

# #230 reference-data SQL requires an exact candidate allowlist. Ordinary
# historical Setup-only previews must continue to work without this new file.
$referenceMigrationPaths = @()
$referenceValidationPaths = @()
$referenceSqlPaths = @($MigrationPaths) + @($ValidationPaths) | Where-Object {
    $_ -is [string] -and $_.StartsWith('Database/') -and
    $_ -ne 'Database/Basic_Query_Tools_Dev/Repair-SetActorOnUpdate-Attribution.sql' -and
    $_ -ne 'Database/Acceptance/database_shared_audit_actor_disposable_validation.sql'
}
if (@($referenceSqlPaths).Count -gt 0) {
    $referenceAllowlistPath = 'Database/Acceptance/reference_data_disposable_allowlist.json'
    $referenceAllowlistJson = (& git -C $repo show "${CandidateSha}:$referenceAllowlistPath" | Out-String)
    if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($referenceAllowlistJson)) {
        throw "STOP: reference-data disposable allowlist missing in exact candidate."
    }
    try { $referenceAllowlist = $referenceAllowlistJson | ConvertFrom-Json -ErrorAction Stop }
    catch { throw "STOP: invalid candidate reference-data disposable allowlist." }
    if ($referenceAllowlist.schema_version -ne 1 -or
        $null -eq $referenceAllowlist.approved_migration_paths -or
        $null -eq $referenceAllowlist.approved_validation_paths) {
        throw "STOP: unsupported reference-data disposable allowlist."
    }
    foreach ($entry in @($referenceAllowlist.approved_migration_paths) +
                       @($referenceAllowlist.approved_validation_paths)) {
        if ($entry -isnot [string] -or
            $entry -notmatch '^Database/[A-Za-z0-9_./-]+[.]sql$' -or
            $entry.Contains('..') -or $entry.Contains('*')) {
            throw "STOP: unsafe candidate reference-data SQL path: $entry"
        }
    }
    $referenceMigrationPaths = @($referenceAllowlist.approved_migration_paths)
    $referenceValidationPaths = @($referenceAllowlist.approved_validation_paths)
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
        $isApprovedReferenceMigration = $referenceMigrationPaths -ccontains $Path
        if (-not ($isSetupMigration -or $isApprovedSharedMigration -or $isApprovedReferenceMigration)) {
            throw "Migration path must be under Setup/Database/, an explicitly approved shared database repair, or the exact reference-data SQL allowlist: $Path"
        }
    }
    if ($Kind -eq 'validation') {
        $isSetupValidation = $Path.StartsWith('Setup/Acceptance/')
        $isApprovedSharedValidation = $Path -eq 'Database/Acceptance/database_shared_audit_actor_disposable_validation.sql'
        $isApprovedReferenceValidation = $referenceValidationPaths -ccontains $Path
        if (-not ($isSetupValidation -or $isApprovedSharedValidation -or $isApprovedReferenceValidation)) {
            throw "Validation path must be under Setup/Acceptance/, an explicitly approved shared database validation, or the exact reference-data SQL allowlist: $Path"
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

$gisIntake = -not [string]::IsNullOrWhiteSpace($GisGpxPath) -or -not [string]::IsNullOrWhiteSpace($GisFlwPath)
if ($gisIntake) {
    if ([string]::IsNullOrWhiteSpace($GisActor) -or $GisActor -match '[\r\n\t]') {
        throw 'Real-source GIS acceptance requires a named GisActor without control characters.'
    }
    foreach ($source in @($GisGpxPath, $GisFlwPath)) {
        if (-not (Test-Path -LiteralPath $source -PathType Leaf)) { throw "Missing GIS source: $source" }
    }
    if ($MigrationPaths -cnotcontains 'Database/EngineeringTools/sql/171_site_infrastructure_schema_candidate.sql' -or
        $ValidationPaths -cnotcontains 'Database/Acceptance/171_site_infrastructure_disposable_validation.sql') {
        throw 'GIS intake requires the #171 schema and validation in this same run.'
    }
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
        "target_ref`t$TargetRef",
        "allow_concurrent_production_writes`t$($AllowConcurrentProductionWrites.IsPresent.ToString().ToLowerInvariant())"
        "production_read_boundary`t$($ProductionReadBoundary.IsPresent.ToString().ToLowerInvariant())"
    )
    foreach ($path in $MigrationPaths) {
        $manifestLines += "migration`t$path"
    }
    foreach ($path in $ValidationPaths) {
        $manifestLines += "validation`t$path"
    }
    if ($gisIntake) {
        Copy-Item -LiteralPath $GisGpxPath -Destination (Join-Path $localBundle 'source.gpx')
        Copy-Item -LiteralPath $GisFlwPath -Destination (Join-Path $localBundle 'source.flw')
        $gpxHash = (Get-FileHash -LiteralPath (Join-Path $localBundle 'source.gpx') -Algorithm SHA256).Hash.ToLowerInvariant()
        $flwHash = (Get-FileHash -LiteralPath (Join-Path $localBundle 'source.flw') -Algorithm SHA256).Hash.ToLowerInvariant()
        $manifestLines += "gis_gpx_sha`t$gpxHash", "gis_flw_sha`t$flwHash", "gis_actor`t$GisActor"
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
    Write-Host "Concurrent Production writes allowed: $($AllowConcurrentProductionWrites.IsPresent.ToString().ToLowerInvariant())"
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
