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
    [ValidateSet('Setup','PeopleIdentityBootstrap')]
    [string]$PreviewProfile = 'Setup',
    [string]$ExternalAppsSha = '',
    [string]$ExternalAppsBlob = '',
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

if ($PreviewProfile -eq 'Setup') {
    $buildIdentity = Get-CandidateSetupBuildIdentity -Sha $CandidateSha
    if ($buildIdentity.Server -ne $buildIdentity.Client) {
        throw "STOP before server contact: Setup client/server version mismatch in exact candidate $CandidateSha. Client $($buildIdentity.Client); server $($buildIdentity.Server)."
    }

    if ($ExpectedVersion -ne $buildIdentity.Server) {
        throw "STOP before server contact: ExpectedVersion '$ExpectedVersion' does not match exact candidate Setup build '$($buildIdentity.Server)'."
    }
}
elseif ($PreviewProfile -eq 'PeopleIdentityBootstrap') {
    $peopleBackend = ((& git -C $repo show "${CandidateSha}:People/Application/backend.py") | Out-String)
    if ($LASTEXITCODE -ne 0) {
        throw "STOP before server contact: exact candidate $CandidateSha is missing People/Application/backend.py."
    }
    $peopleVersionMatch = [regex]::Match($peopleBackend, 'APP_VERSION\s*=\s*"([^"]+)"')
    if (-not $peopleVersionMatch.Success) {
        throw "STOP before server contact: unable to resolve People APP_VERSION from exact candidate $CandidateSha."
    }
    if ($ExpectedVersion -ne $peopleVersionMatch.Groups[1].Value) {
        throw "STOP before server contact: ExpectedVersion '$ExpectedVersion' does not match exact People candidate version '$($peopleVersionMatch.Groups[1].Value)'."
    }
    if ([string]::IsNullOrWhiteSpace($ExternalAppsSha) -or [string]::IsNullOrWhiteSpace($ExternalAppsBlob)) {
        throw 'STOP before server contact: PeopleIdentityBootstrap preview requires ExternalAppsSha and ExternalAppsBlob.'
    }
    if ($PreviewPort -ne 8898) {
        throw 'STOP before server contact: reusable disposable browser review must use registered port 8898.'
    }
    if ($PreviewEmail -eq 'gliebig@sheboyganlights.org') {
        $PreviewEmail = "bootstrap-preview-$((Get-Date).ToString('yyyyMMddHHmmss'))@sheboyganlights.org"
    }
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

# Setup profile preserves the explicitly approved shared database repair and
# explicitly approved shared database validation exceptions. Other profiles
# must use only their own feature-owned migration/validation directories.
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
        $isPeopleMigration = $Path.StartsWith('People/Database/')
        $isApprovedSharedMigration = $Path -eq 'Database/Basic_Query_Tools_Dev/Repair-SetActorOnUpdate-Attribution.sql'
        $allowed = if ($PreviewProfile -eq 'PeopleIdentityBootstrap') {
            $isPeopleMigration
        } else {
            $isSetupMigration -or $isApprovedSharedMigration -or ($referenceMigrationPaths -ccontains $Path)
        }
        if (-not $allowed) {
            throw "Migration path is outside the approved $PreviewProfile preview boundary: $Path"
        }
    }
    if ($Kind -eq 'validation') {
        $isSetupValidation = $Path.StartsWith('Setup/Acceptance/')
        $isPeopleValidation = $Path.StartsWith('People/Acceptance/')
        $isApprovedSharedValidation = $Path -eq 'Database/Acceptance/database_shared_audit_actor_disposable_validation.sql'
        $allowed = if ($PreviewProfile -eq 'PeopleIdentityBootstrap') {
            $isPeopleValidation
        } else {
            $isSetupValidation -or $isApprovedSharedValidation -or ($referenceValidationPaths -ccontains $Path)
        }
        if (-not $allowed) {
            throw "Validation path is outside the approved $PreviewProfile preview boundary: $Path"
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

$profileEntryScript = $null
if ($PreviewProfile -eq 'PeopleIdentityBootstrap') {
    $serverScript = Join-Path $repo 'Setup\Acceptance\people_identity_bootstrap_disposable_browser_preview_server.sh'
    $profileEntryScript = Join-Path $repo 'Setup\Acceptance\people_identity_bootstrap_disposable_browser_preview_entry.py'
    foreach ($tool in @($serverScript, $profileEntryScript)) {
        if (-not (Test-Path -LiteralPath $tool -PathType Leaf)) {
            throw "Reusable PeopleIdentityBootstrap browser-preview tooling is missing: $tool"
        }
    }
}
else {
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
}

$localListeners = @(Get-NetTCPConnection -LocalPort $PreviewPort -State Listen -ErrorAction SilentlyContinue)
foreach ($listener in $localListeners) {
    $owner = Get-Process -Id $listener.OwningProcess -ErrorAction SilentlyContinue
    if ($null -eq $owner) { continue }
    if ($owner.ProcessName -ne 'ssh') {
        throw "Local preview port $PreviewPort is owned by non-SSH process $($owner.ProcessName) PID $($owner.Id). Not stopping it automatically."
    }
    if ($PreviewProfile -eq 'PeopleIdentityBootstrap') {
        throw "Local preview port $PreviewPort already has SSH tunnel PID $($owner.Id). Refusing to stop it because it may belong to a preserved Setup review; inspect/resume/clean that review first."
    }
    Write-Host "Stopping stale local SSH preview tunnel PID $($owner.Id) on port $PreviewPort"
    Stop-Process -Id $owner.Id -Force
}

$gisIntake = -not [string]::IsNullOrWhiteSpace($GisGpxPath) -or -not [string]::IsNullOrWhiteSpace($GisFlwPath)
if ($gisIntake) {
    if ([string]::IsNullOrWhiteSpace($GisActor) -or $GisActor -match '[\r\n\t]') {
        throw 'Real-source GIS acceptance requires a named GisActor without control characters.'
    }
    if ([string]::IsNullOrWhiteSpace($GisGpxPath)) { throw 'GIS acceptance requires a GPX master.' }
    $gisSourcePaths = @($GisGpxPath, $GisFlwPath) | Where-Object { -not [string]::IsNullOrWhiteSpace($_) }
    foreach ($source in $gisSourcePaths) {
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
$backboneSourceDir = Join-Path $env:TEMP "${bundleName}-backbone-source"
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

    if ($null -ne $profileEntryScript) {
        $profileEntryText = [System.IO.File]::ReadAllText($profileEntryScript)
        $profileEntryText = $profileEntryText.Replace("`r`n", "`n").Replace("`r", "`n")
        [System.IO.File]::WriteAllText(
            (Join-Path $localBundle 'people_identity_bootstrap_disposable_browser_preview_entry.py'),
            $profileEntryText,
            $utf8NoBom
        )
    }

    if ($PreviewProfile -eq 'PeopleIdentityBootstrap') {
        # Obtain the separately owned Backbone Apps candidate through workstation Git.
        # Anonymous raw GitHub endpoints are not an accepted draft-source authority.
        if ($ExternalAppsSha -notmatch '^[0-9a-fA-F]{40}$' -or
            $ExternalAppsBlob -notmatch '^[0-9a-fA-F]{40}$') {
            throw 'STOP before server contact: Backbone commit and blob must each be 40 hex digits.'
        }
        if (Test-Path -LiteralPath $backboneSourceDir) {
            throw "STOP: disposable Backbone source directory already exists: $backboneSourceDir"
        }

        & git clone --quiet --no-checkout 'https://github.com/Gregovate/MSB-Internal-Web-Backbone.git' $backboneSourceDir
        if ($LASTEXITCODE -ne 0) {
            throw 'STOP before server contact: authenticated Backbone candidate Git clone failed.'
        }
        # A detached checkout with autocrlf disabled preserves committed bytes.
        & git -c core.autocrlf=false -C $backboneSourceDir checkout --quiet --detach $ExternalAppsSha
        if ($LASTEXITCODE -ne 0) {
            throw "STOP before server contact: Backbone candidate commit $ExternalAppsSha is unavailable."
        }

        $sourceBlob = (& git -C $backboneSourceDir rev-parse "${ExternalAppsSha}:my/apps/index.html").Trim()
        if ($LASTEXITCODE -ne 0 -or $sourceBlob -ne $ExternalAppsBlob) {
            throw "STOP before server contact: Backbone Apps committed blob '$sourceBlob' does not match pinned '$ExternalAppsBlob'."
        }
        $appsSource = Join-Path $backboneSourceDir 'my\apps\index.html'
        $workingBlob = (& git -C $backboneSourceDir hash-object -- $appsSource).Trim()
        if ($LASTEXITCODE -ne 0 -or $workingBlob -ne $ExternalAppsBlob) {
            throw "STOP before server contact: Backbone Apps working bytes differ from pinned '$ExternalAppsBlob'."
        }

        $bundledApps = Join-Path $localBundle 'apps-index.html'
        [System.IO.File]::Copy($appsSource, $bundledApps)
        $bundledBlob = (& git -C $repo hash-object -- $bundledApps).Trim()
        if ($LASTEXITCODE -ne 0 -or $bundledBlob -ne $ExternalAppsBlob) {
            throw "STOP before server contact: bundled Apps file differs from pinned '$ExternalAppsBlob'."
        }
        Write-Host "PASS: authenticated exact Backbone Apps source and bundle blob $ExternalAppsBlob"
    }

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
    # Setup's established server manifest parser has no preview_profile key.
    # The separate PeopleIdentityBootstrap parser REQUIRES that explicit key.
    # Keep profile-specific fields out of the default Setup manifest.
    if ($PreviewProfile -eq 'PeopleIdentityBootstrap') {
        $manifestLines += "preview_profile`t$PreviewProfile"
        $manifestLines += "external_apps_sha`t$ExternalAppsSha"
        $manifestLines += "external_apps_blob`t$ExternalAppsBlob"
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
        $flwHash = ''
        if (-not [string]::IsNullOrWhiteSpace($GisFlwPath)) {
            $flwHash = (Get-FileHash -LiteralPath $GisFlwPath -Algorithm SHA256).Hash.ToLowerInvariant()
        }
        if ($gpxHash -notmatch '^[a-f0-9]{64}$' -or ($flwHash -ne '' -and $flwHash -notmatch '^[a-f0-9]{64}$')) {
            throw 'Invalid GIS source hash.'
        }
        # One foreground probe reports missing files through an exit bitmask.
        # SSH owns the console directly; no password-sensitive output pipeline.
        $cacheProbe = 'gis_cache="$HOME/setup-source-cache"; gis_missing=0; test -f "$gis_cache/{0}.gpx" || gis_missing=$((gis_missing+1)); if [ -n "{1}" ]; then test -f "$gis_cache/{1}.flw" || gis_missing=$((gis_missing+2)); fi; exit "$gis_missing"' -f $gpxHash, $flwHash
        & ssh -o ServerAliveInterval=15 -o ServerAliveCountMax=3 $Server $cacheProbe
        $missingSources = $LASTEXITCODE
        if ($missingSources -notin @(0, 1, 2, 3)) { throw 'GIS source-cache probe failed.' }
        if (($missingSources -band 1) -ne 0) {
            Copy-Item -LiteralPath $GisGpxPath -Destination (Join-Path $localBundle 'source.gpx')
        } else { Write-Host "Reusing server GPX source $gpxHash" }
        if ($flwHash -ne '' -and ($missingSources -band 2) -ne 0) {
            Copy-Item -LiteralPath $GisFlwPath -Destination (Join-Path $localBundle 'source.flw')
        } elseif ($flwHash -ne '') { Write-Host "Reusing server FLW source $flwHash" }
        $manifestLines += "gis_gpx_sha`t$gpxHash", "gis_actor`t$GisActor"
        if ($flwHash -ne '') { $manifestLines += "gis_flw_sha`t$flwHash" }
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
    Write-Host "Preview profile: $PreviewProfile"
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
    $remoteEntry = "$remoteBundle/people_identity_bootstrap_disposable_browser_preview_entry.py"
    $remoteApps = "$remoteBundle/apps-index.html"
    $prepareCommand = "chmod 755 '$remoteBundle' && chmod 700 '$remoteRunner'"
    if ($PreviewProfile -eq 'PeopleIdentityBootstrap') {
        $prepareCommand += " && chmod 644 '$remoteEntry' '$remoteApps'"
    }
    $initialCommand = "$prepareCommand && bash -n '$remoteRunner' && timeout --foreground --signal=TERM 28800s bash '$remoteRunner' '$remoteManifest' start"
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
    Write-Host "$PreviewProfile REUSABLE DISPOSABLE BROWSER PREVIEW: CLEAN EXIT"
}
finally {
    Remove-Item -LiteralPath $localBundle -Recurse -Force -ErrorAction SilentlyContinue
    Remove-Item -LiteralPath $backboneSourceDir -Recurse -Force -ErrorAction SilentlyContinue
}
