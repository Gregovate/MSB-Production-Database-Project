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
    [switch]$InternalNetworkPreview
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

$stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$bundleName = "msb-setup-disposable-browser-preview-$stamp"
$localBundle = Join-Path $env:TEMP $bundleName
$remoteBundle = "/tmp/$bundleName"
$localRunner = Join-Path $localBundle 'setup_disposable_browser_preview_server.sh'
$localManifest = Join-Path $localBundle 'preview_manifest.tsv'
$utf8NoBom = [System.Text.UTF8Encoding]::new($false)
$previewBindHost = if ($InternalNetworkPreview) { '192.168.5.9' } else { '127.0.0.1' }
$browserUrl = "http://${previewBindHost}:$PreviewPort/"

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
        "preview_bind_host`t$previewBindHost",
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
    Write-Host "Preview bind:    $previewBindHost"
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
    if ($InternalNetworkPreview) {
        Write-Host 'Tablet mode: temporary preview is exposed only on the private MSB server address; no public proxy/routing is changed.'
    } else {
        Write-Host 'Desktop mode: preview is reachable only through the local SSH tunnel.'
    }
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

        if ($InternalNetworkPreview) {
            & ssh -tt -o ServerAliveInterval=15 -o ServerAliveCountMax=3 $Server $command
        } else {
            & ssh -tt -o ServerAliveInterval=15 -o ServerAliveCountMax=3 -L "${PreviewPort}:127.0.0.1:${PreviewPort}" $Server $command
        }
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
