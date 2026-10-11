param(
    [string]$Server = 'msbadmin@192.168.5.9',
    [Parameter(Mandatory=$true)]
    [int]$PreviewPort,
    [Parameter(Mandatory=$true)]
    [string]$CandidateSha,
    [Parameter(Mandatory=$true)]
    [string]$TargetRef,
    [string]$PreviewEmail = 'gliebig@sheboyganlights.org',
    [Parameter(Mandatory=$true)]
    [string]$ExpectedVersion,
    [string[]]$MigrationPaths = @(),
    [string[]]$ValidationPaths = @(),
    [switch]$AllowConcurrentProductionWrites,
    [string]$LocalReviewBranch = '',
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

if ($ExpectedVersion -ne $buildIdentity.Server) {
    throw "STOP before server contact: ExpectedVersion '$ExpectedVersion' does not match exact candidate Setup build '$($buildIdentity.Server)'."
}

if ($PreviewPort -lt 1024 -or $PreviewPort -gt 65535) {
    throw 'PreviewPort must be between 1024 and 65535.'
}
if ($PreviewPort -in @(8055, 8790, 8792, 8794)) {
    throw "PreviewPort $PreviewPort conflicts with a governed Production listener."
}
if ($PreviewEmail -notmatch '^[A-Za-z0-9._%+\-]+@[A-Za-z0-9.\-]+$') {
    throw 'PreviewEmail is not a valid email address.'
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

$serverScript = Join-Path $repo 'Setup\Acceptance\setup_disposable_browser_preview_server.sh'
if (-not (Test-Path -LiteralPath $serverScript -PathType Leaf)) {
    throw "Reusable Setup browser-preview server runner is missing: $serverScript"
}

& git -C $repo cat-file -e "${CandidateSha}:Setup/Acceptance/setup_disposable_browser_preview_server.sh" 2>$null
if ($LASTEXITCODE -ne 0) {
    throw 'Exact candidate does not contain the reusable Setup browser-preview server runner.'
}
& git -C $repo cat-file -e "${CandidateSha}:Setup/Acceptance/setup_session_browser_preview_entry.py" 2>$null
if ($LASTEXITCODE -ne 0) {
    throw 'Exact candidate does not contain the Setup browser-preview entry point.'
}

$localListeners = @(Get-NetTCPConnection -LocalPort $PreviewPort -State Listen -ErrorAction SilentlyContinue)
foreach ($listener in $localListeners) {
    $owner = Get-Process -Id $listener.OwningProcess -ErrorAction SilentlyContinue
    if ($null -eq $owner) { continue }
    if ($owner.ProcessName -ne 'ssh') {
        throw "Local preview port $PreviewPort is owned by non-SSH process $($owner.ProcessName) PID $($owner.Id). Not stopping it automatically."
    }
    Write-Host "Stopping stale local SSH preview tunnel PID $($owner.Id) on port $PreviewPort"
    Stop-Process -Id $owner.Id -Force
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
$bundleName = "msb-setup-disposable-browser-preview-$stamp"
$localBundle = Join-Path $env:TEMP $bundleName
$remoteBundle = "/tmp/$bundleName"
$localRunner = Join-Path $localBundle 'setup_disposable_browser_preview_server.sh'
$localManifest = Join-Path $localBundle 'preview_manifest.tsv'
$utf8NoBom = [System.Text.UTF8Encoding]::new($false)
$browserUrl = "http://127.0.0.1:$PreviewPort/"

try {
    New-Item -ItemType Directory -Path $localBundle -Force | Out-Null

    $runnerText = [System.IO.File]::ReadAllText($serverScript)
    $runnerText = $runnerText.Replace("`r`n", "`n").Replace("`r", "`n")
    [System.IO.File]::WriteAllText($localRunner, $runnerText, $utf8NoBom)

    $manifestLines = @(
        "candidate_sha`t$CandidateSha",
        "target_ref`t$TargetRef",
        "preview_port`t$PreviewPort",
        "preview_email`t$PreviewEmail",
        "allow_concurrent_production_writes`t$($AllowConcurrentProductionWrites.IsPresent.ToString().ToLowerInvariant())"
    )
    if (-not [string]::IsNullOrWhiteSpace($ExpectedVersion)) {
        $manifestLines += "expected_version`t$ExpectedVersion"
    }
    foreach ($path in $MigrationPaths) {
        $manifestLines += "migration`t$path"
    }
    foreach ($path in $ValidationPaths) {
        $manifestLines += "validation`t$path"
    }
    if ($gisIntake) {
        # Hash the originals; only stage a local copy when the server lacks it.
        $gpxHash = (Get-FileHash -LiteralPath $GisGpxPath -Algorithm SHA256).Hash.ToLowerInvariant()
        $flwHash = (Get-FileHash -LiteralPath $GisFlwPath -Algorithm SHA256).Hash.ToLowerInvariant()
        if ($gpxHash -notmatch '^[a-f0-9]{64}$' -or $flwHash -notmatch '^[a-f0-9]{64}$') {
            throw 'Invalid GIS source hash.'
        }
        # One foreground probe reports missing files through an exit bitmask.
        # SSH owns the console directly; no password-sensitive output pipeline.
        $cacheProbe = 'gis_cache="$HOME/setup-source-cache"; gis_missing=0; test -f "$gis_cache/{0}.gpx" || gis_missing=$((gis_missing+1)); test -f "$gis_cache/{1}.flw" || gis_missing=$((gis_missing+2)); exit "$gis_missing"' -f $gpxHash, $flwHash
        & ssh -o ServerAliveInterval=15 -o ServerAliveCountMax=3 $Server $cacheProbe
        $missingSources = $LASTEXITCODE
        if ($missingSources -notin @(0, 1, 2, 3)) { throw 'GIS source-cache probe failed.' }
        if (($missingSources -band 1) -ne 0) {
            Copy-Item -LiteralPath $GisGpxPath -Destination (Join-Path $localBundle 'source.gpx')
        } else { Write-Host "Reusing server GPX source $gpxHash" }
        if (($missingSources -band 2) -ne 0) {
            Copy-Item -LiteralPath $GisFlwPath -Destination (Join-Path $localBundle 'source.flw')
        } else { Write-Host "Reusing server FLW source $flwHash" }
        $manifestLines += "gis_gpx_sha`t$gpxHash", "gis_flw_sha`t$flwHash", "gis_actor`t$GisActor"
    }
    $manifestText = ($manifestLines -join "`n") + "`n"
    [System.IO.File]::WriteAllText($localManifest, $manifestText, $utf8NoBom)

    if ($runnerText.Contains("`r") -or $manifestText.Contains("`r")) {
        throw 'Generated Linux preview bundle contains CR characters; refusing to upload.'
    }

    Write-Host '========== SETUP REUSABLE DISPOSABLE BROWSER PREVIEW =========='
    Write-Host 'Authority: Gregovate/MSB-Server-Management — docs/server/Pre_Production_Browser_Review_Runbook.md'
    Write-Host 'Disposable standard: docs/server/PostgreSQL_Disposable_Acceptance_Standard.md'
    Write-Host "Server:          $Server"
    Write-Host "Candidate SHA:   $CandidateSha"
    Write-Host "Tooling SHA:     $toolingHead"
    Write-Host "Target ref:      $TargetRef"
    Write-Host "Preview port:    $PreviewPort"
    Write-Host "Browser URL:     $browserUrl"
    Write-Host "Preview user:    $PreviewEmail"
    Write-Host "Expected version:$ExpectedVersion"
    Write-Host "Concurrent Prod: $($AllowConcurrentProductionWrites.IsPresent)"
    Write-Host "Migrations:      $($MigrationPaths.Count)"
    Write-Host "Validations:     $($ValidationPaths.Count)"
    Write-Host
    Write-Host 'Production database contract: pg_dump + SELECT only from this preview harness.'
    if ($AllowConcurrentProductionWrites) {
        Write-Host 'Concurrent Production application edits are allowed; fingerprint drift will be reported, not failed.'
        Write-Host 'NOTE: the disposable clone is a point-in-time snapshot. Production edits made after preview start are NOT visible in this preview.'
    }
    Write-Host 'All migration/API/browser writes from the preview: disposable current-Production clone only.'
    Write-Host 'Keep this PowerShell window open for the complete review and cleanup.'
    Write-Host

    & scp -r $localBundle "${Server}:/tmp/"
    if ($LASTEXITCODE -ne 0) {
        throw "SCP preview bundle upload failed with exit code $LASTEXITCODE"
    }

    $remoteRunner = "$remoteBundle/setup_disposable_browser_preview_server.sh"
    $remoteManifest = "$remoteBundle/preview_manifest.tsv"
    $initialCommand = "chmod 700 '$remoteRunner' && bash -n '$remoteRunner' && timeout --foreground --signal=TERM 28800s bash '$remoteRunner' '$remoteManifest' start"
    $resumeCommand = "timeout --foreground --signal=TERM 28800s bash '$remoteRunner' '$remoteManifest' resume"

    $mode = 'start'
    $reconnectAttempts = 0
    $maxReconnectAttempts = 12
    $initialExit = 0

    while ($true) {
        $command = if ($mode -eq 'start') { $initialCommand } else { $resumeCommand }

        & ssh -tt -o ServerAliveInterval=15 -o ServerAliveCountMax=3 -L "${PreviewPort}:127.0.0.1:${PreviewPort}" $Server $command
        $remoteExit = $LASTEXITCODE

        if ($remoteExit -eq 0) {
            break
        }

        if ($mode -eq 'start') {
            $initialExit = $remoteExit
            if ($remoteExit -notin @(75, 255)) {
                throw "Reusable Setup browser preview start failed with exit code $remoteExit. The start failure is not resumable; review the retained remote report."
            }
            Write-Warning "Browser-review SSH transport ended with exit code $remoteExit. Checking whether the exact healthy preview can be resumed without rebuilding it..."
            $mode = 'resume'
        }
        elseif ($remoteExit -notin @(75, 255)) {
            throw "Reusable Setup browser preview could not be resumed (initial exit $initialExit; resume exit $remoteExit). Review the retained remote report."
        }

        $reconnectAttempts += 1
        if ($reconnectAttempts -gt $maxReconnectAttempts) {
            throw "Reusable Setup browser preview tunnel could not be re-established after $maxReconnectAttempts attempts. The remote preview may still be preserved; do not start another preview until its state is inspected."
        }

        $localListeners = @(Get-NetTCPConnection -LocalPort $PreviewPort -State Listen -ErrorAction SilentlyContinue)
        foreach ($listener in $localListeners) {
            $owner = Get-Process -Id $listener.OwningProcess -ErrorAction SilentlyContinue
            if ($null -eq $owner) { continue }
            if ($owner.ProcessName -ne 'ssh') {
                throw "Local preview port $PreviewPort became owned by non-SSH process $($owner.ProcessName) PID $($owner.Id) during reconnect."
            }
            Stop-Process -Id $owner.Id -Force
        }

        Start-Sleep -Seconds 2
        Write-Host "Reconnecting to preserved Setup browser preview on port $PreviewPort (attempt $reconnectAttempts/$maxReconnectAttempts)..."
    }

    Write-Host
    Write-Host 'SETUP REUSABLE DISPOSABLE BROWSER PREVIEW: CLEAN EXIT'
}
finally {
    Remove-Item -LiteralPath $localBundle -Recurse -Force -ErrorAction SilentlyContinue
}
