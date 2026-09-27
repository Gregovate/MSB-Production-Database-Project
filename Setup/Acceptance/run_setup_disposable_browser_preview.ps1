param(
    [string]$Server = 'msbadmin@192.168.5.9',
    [Parameter(Mandatory=$true)]
    [int]$PreviewPort,
    [Parameter(Mandatory=$true)]
    [string]$CandidateSha,
    [Parameter(Mandatory=$true)]
    [string]$TargetRef,
    [string]$PreviewEmail = 'gliebig@sheboyganlights.org',
    [string]$ExpectedVersion = '',
    [string[]]$MigrationPaths = @(),
    [string[]]$ValidationPaths = @(),
    [switch]$AllowConcurrentProductionWrites
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
    $remoteCommand = "chmod 700 '$remoteRunner' && bash -n '$remoteRunner' && timeout --foreground --signal=TERM 28800s bash '$remoteRunner' '$remoteManifest'"

    & ssh -tt -o ServerAliveInterval=15 -o ServerAliveCountMax=3 -L "${PreviewPort}:127.0.0.1:${PreviewPort}" $Server $remoteCommand
    $remoteExit = $LASTEXITCODE
    if ($remoteExit -ne 0) {
        throw "Reusable Setup browser preview failed with exit code $remoteExit. Review the retained remote report for the failed gate."
    }

    Write-Host
    Write-Host 'SETUP REUSABLE DISPOSABLE BROWSER PREVIEW: CLEAN EXIT'
}
finally {
    Remove-Item -LiteralPath $localBundle -Recurse -Force -ErrorAction SilentlyContinue
}
