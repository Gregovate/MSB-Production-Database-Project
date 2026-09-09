param(
    [string]$Server = 'msbadmin@192.168.5.9',
    [Parameter(Mandatory=$true)]
    [int]$PreviewPort,
    [string]$PreviewEmail = 'gliebig@sheboyganlights.org'
)

$ErrorActionPreference = 'Stop'

$AcceptedCandidateSha = '19239e3584a66913ecaa5f0406434be54618c303'
$repo = (git rev-parse --show-toplevel).Trim()
if (-not $repo) {
    throw 'Run this launcher from an MSB-Production-Database-Project checkout.'
}

$dirty = git -C $repo status --porcelain
if ($LASTEXITCODE -ne 0) {
    throw 'Unable to verify local Git worktree status.'
}
if ($dirty) {
    throw "Local worktree is not clean.`n$dirty"
}

& git -C $repo cat-file -e "${AcceptedCandidateSha}^{commit}"
if ($LASTEXITCODE -ne 0) {
    throw "Accepted Setup catalog candidate is not available locally: $AcceptedCandidateSha"
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

$localListeners = @(Get-NetTCPConnection -LocalPort $PreviewPort -State Listen -ErrorAction SilentlyContinue)
foreach ($listener in $localListeners) {
    $owner = Get-Process -Id $listener.OwningProcess -ErrorAction SilentlyContinue
    if ($null -eq $owner) {
        continue
    }
    if ($owner.ProcessName -ne 'ssh') {
        throw "Local preview port $PreviewPort is owned by non-SSH process $($owner.ProcessName) PID $($owner.Id). Not stopping it automatically."
    }
    Write-Host "Stopping stale local SSH Setup preview tunnel PID $($owner.Id) on port $PreviewPort"
    Stop-Process -Id $owner.Id -Force
}

$acceptanceDir = Join-Path $repo 'Setup\Acceptance'
$serverScript = Join-Path $acceptanceDir 'setup_catalog_reconstruction_browser_preview_server.sh'
$previewEntry = Join-Path $acceptanceDir 'setup_session_browser_preview_entry.py'
$cleanupScript = Join-Path $acceptanceDir 'setup_session_browser_preview_cleanup_server.sh'

foreach ($path in @($serverScript, $previewEntry, $cleanupScript)) {
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
        throw "Required Setup catalog browser-preview file is missing: $path"
    }
}

$stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$bundleName = "msb-setup-catalog-browser-preview-$stamp"
$localBundle = Join-Path $env:TEMP $bundleName
$uploadRoot = "/tmp/$bundleName"
# Keep the uploaded SCP path and executable remote path distinct. The prior
# launcher used the same value for both, causing `mv source source` to be
# interpreted as moving the directory into itself.
$remoteRoot = "/tmp/msb-setup-catalog-browser-preview-run-$stamp"
$utf8NoBom = [System.Text.UTF8Encoding]::new($false)
$browserUrl = "http://127.0.0.1:$PreviewPort/"

function Copy-NormalizedText {
    param(
        [Parameter(Mandatory=$true)][string]$Source,
        [Parameter(Mandatory=$true)][string]$Destination
    )
    $text = [System.IO.File]::ReadAllText($Source)
    $text = $text.Replace("`r`n", "`n").Replace("`r", "`n")
    [System.IO.File]::WriteAllText($Destination, $text, $utf8NoBom)
}

try {
    New-Item -ItemType Directory -Path $localBundle -Force | Out-Null
    $localServer = Join-Path $localBundle 'setup_catalog_reconstruction_browser_preview_server.sh'
    Copy-NormalizedText -Source $serverScript -Destination $localServer
    Copy-NormalizedText -Source $previewEntry -Destination (Join-Path $localBundle 'setup_session_browser_preview_entry.py')
    Copy-NormalizedText -Source $cleanupScript -Destination (Join-Path $localBundle 'setup_session_browser_preview_cleanup_server.sh')

    # Pin the runtime server script to the exact application/database candidate
    # that must be re-accepted after the active-catalog effort API correction.
    $serverText = [System.IO.File]::ReadAllText($localServer)
    $oldTarget = 'TARGET_SHA="dd1cbeafe6243089b4ee3b04ea3f67359654381f"'
    $newTarget = "TARGET_SHA=`"$AcceptedCandidateSha`""
    if (-not $serverText.Contains($oldTarget)) {
        throw 'Catalog preview server no longer contains the expected accepted-candidate placeholder.'
    }
    $serverText = $serverText.Replace($oldTarget, $newTarget)

    # The Flask process runs as fieldwiring. Cleanup therefore must signal its
    # process group through sudo; a plain msbadmin kill cannot terminate it.
    $oldTerm = '        kill -- -"$PREVIEW_PGID" >/dev/null 2>&1 || true'
    $newTerm = '        sudo kill -- -"$PREVIEW_PGID" >/dev/null 2>&1 || true'
    $oldKill = '        kill -KILL -- -"$PREVIEW_PGID" >/dev/null 2>&1 || true'
    $newKill = '        sudo kill -KILL -- -"$PREVIEW_PGID" >/dev/null 2>&1 || true'
    if (-not $serverText.Contains($oldTerm) -or -not $serverText.Contains($oldKill)) {
        throw 'Catalog preview server no longer contains the expected preview-process cleanup commands.'
    }
    $serverText = $serverText.Replace($oldTerm, $newTerm).Replace($oldKill, $newKill)
    [System.IO.File]::WriteAllText($localServer, $serverText, $utf8NoBom)

    Write-Host '========== SETUP CATALOG RECONSTRUCTION BROWSER PREVIEW =========='
    Write-Host "Server:             $Server"
    Write-Host "Accepted candidate: $AcceptedCandidateSha"
    Write-Host "Preview port:       $PreviewPort"
    Write-Host "Browser URL:        $browserUrl"
    Write-Host "Preview identity:   $PreviewEmail"
    Write-Host
    Write-Host 'Production database contract: pg_dump + SELECT only'
    Write-Host 'All catalog/schema/browser writes: disposable PostgreSQL clone only'
    Write-Host 'The browser is not auto-opened; wait for SETUP CATALOG BROWSER REVIEW READY.'
    Write-Host 'Keep this PowerShell window open during review.'
    Write-Host

    & scp -r $localBundle "${Server}:/tmp/"
    if ($LASTEXITCODE -ne 0) {
        throw "SCP Setup catalog browser-preview bundle upload failed with exit code $LASTEXITCODE"
    }

    $uploadCleanup = "$uploadRoot/setup_session_browser_preview_cleanup_server.sh"
    $remoteServer = "$remoteRoot/setup_catalog_reconstruction_browser_preview_server.sh"
    $remoteEntry = "$remoteRoot/setup_session_browser_preview_entry.py"
    $remoteCleanup = "$remoteRoot/setup_session_browser_preview_cleanup_server.sh"

    $remoteCommand = "chmod 700 '$uploadCleanup' && bash -n '$uploadCleanup' && bash '$uploadCleanup' '$PreviewPort' && rm -rf '$remoteRoot' && mv '$uploadRoot' '$remoteRoot' && chmod 755 '$remoteRoot' && chmod 700 '$remoteServer' '$remoteCleanup' && chmod 644 '$remoteEntry' && bash -n '$remoteServer' && timeout --signal=TERM 28800s bash '$remoteServer' '$PreviewPort' '$PreviewEmail'"

    & ssh -tt -L "${PreviewPort}:127.0.0.1:${PreviewPort}" $Server $remoteCommand
    $remoteExit = $LASTEXITCODE
    if ($remoteExit -ne 0) {
        throw "Setup catalog browser preview failed with exit code $remoteExit. Use the retained remote Setup_Catalog_Reconstruction_Browser_Preview report for the exact failed gate."
    }

    Write-Host
    Write-Host 'SETUP CATALOG RECONSTRUCTION BROWSER PREVIEW: CLEAN EXIT'
}
finally {
    Remove-Item -LiteralPath $localBundle -Recurse -Force -ErrorAction SilentlyContinue
}
