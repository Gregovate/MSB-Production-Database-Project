param(
    [string]$Server = 'msbadmin@192.168.5.9',
    [int]$PreviewPort = 8793,
    [string]$PreviewEmail = 'gliebig@sheboyganlights.org'
)

$ErrorActionPreference = 'Stop'

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$RepoRoot = (Resolve-Path (Join-Path $ScriptDir '..\..')).Path
$ServerScript = Join-Path $ScriptDir 'controller_setup_management_browser_preview_server.sh'
$PreviewEntry = Join-Path $ScriptDir 'controller_setup_management_browser_preview_entry.py'
$CleanupServerScript = Join-Path $ScriptDir 'controller_setup_management_browser_preview_cleanup_server.sh'
$ExpectedBranch = 'agent/controller-inventory-ref-sandbox'
$TemplateCandidateSha = '2fd2067958cc0a903260fe6f089f88ae63a857f1'
$CandidateSha = '63be47f40be78f608416935ed0583287da9d90e6'

foreach ($path in @($ServerScript, $PreviewEntry, $CleanupServerScript)) {
    if (-not (Test-Path -LiteralPath $path)) {
        throw "Required browser preview file is missing: $path"
    }
}

if ($PreviewPort -lt 1024 -or $PreviewPort -gt 65535) {
    throw 'PreviewPort must be between 1024 and 65535.'
}
if ($PreviewPort -in @(8055, 8790, 8792)) {
    throw "PreviewPort $PreviewPort conflicts with a governed production listener."
}
if ($PreviewEmail -notmatch '^[A-Za-z0-9._%+\-]+@[A-Za-z0-9.\-]+$') {
    throw 'PreviewEmail is not a valid email address.'
}

$currentBranch = (& git -C $RepoRoot branch --show-current).Trim()
if ($LASTEXITCODE -ne 0 -or $currentBranch -ne $ExpectedBranch) {
    throw "Run this browser preview from branch $ExpectedBranch. Current branch: $currentBranch"
}

$dirty = (& git -C $RepoRoot status --porcelain)
if ($LASTEXITCODE -ne 0) {
    throw 'Unable to verify local Git worktree status.'
}
if ($dirty) {
    throw 'Local worktree is not clean. Pull/commit/stash/revert before packaging the preview.'
}

& git -C $RepoRoot cat-file -e "${CandidateSha}^{commit}"
if ($LASTEXITCODE -ne 0) {
    throw "Accepted candidate commit is not available locally: $CandidateSha"
}

# Ctrl+C can leave the local SSH tunnel listening even after the remote preview
# is gone. Stop only an ssh.exe listener on this dedicated preview port and
# refuse to terminate any unrelated process.
$localListeners = @(Get-NetTCPConnection -LocalPort $PreviewPort -State Listen -ErrorAction SilentlyContinue)
foreach ($listener in $localListeners) {
    $owner = Get-Process -Id $listener.OwningProcess -ErrorAction SilentlyContinue
    if ($null -eq $owner) {
        continue
    }
    if ($owner.ProcessName -ne 'ssh') {
        throw "Local preview port $PreviewPort is owned by non-SSH process $($owner.ProcessName) PID $($owner.Id). Not stopping it automatically."
    }
    Write-Host "Stopping stale local SSH preview tunnel PID $($owner.Id) on port $PreviewPort"
    Stop-Process -Id $owner.Id -Force
}

$stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
# Upload outside the stale-preview cleanup glob. After cleanup passes, the one
# uploaded bundle is moved to the normal preview prefix so later cleanup can
# still identify it if the session is interrupted.
$bundleName = "msb-controller-preview-session-$stamp"
$localBundle = Join-Path ([System.IO.Path]::GetTempPath()) $bundleName
$uploadRoot = "/tmp/$bundleName"
$remoteRoot = "/tmp/msb-controller-browser-preview-$stamp"
$utf8NoBom = New-Object System.Text.UTF8Encoding($false)
$browserUrl = "http://127.0.0.1:$PreviewPort/controllers"

function Write-LinuxTextFile {
    param(
        [Parameter(Mandatory=$true)][string]$Source,
        [Parameter(Mandatory=$true)][string]$Destination
    )
    $text = [System.IO.File]::ReadAllText($Source)
    $text = $text.Replace("`r`n", "`n").Replace("`r", "`n")
    [System.IO.File]::WriteAllText($Destination, $text, $utf8NoBom)
}

Write-Host '========== CONTROLLER SETUP + MANAGEMENT BROWSER PREVIEW =========='
Write-Host "Server:        $Server"
Write-Host "Candidate SHA: $CandidateSha"
Write-Host "Browser URL:   $browserUrl"
Write-Host "Preview user:  $PreviewEmail"
Write-Host
Write-Host 'This preview uses a disposable current-production PostgreSQL clone.'
Write-Host 'Production Controller data and the production FieldWiring checkout are not modified.'
Write-Host 'Stale preview resources on port 8793 are cleaned narrowly before the new preview starts.'
Write-Host 'The browser will open automatically. If it opens before Flask is ready, leave it open and refresh after BROWSER REVIEW READY appears.'
Write-Host 'Keep this PowerShell window open while reviewing the browser.'
Write-Host 'When finished, return here and press ENTER so the remote trap can clean up.'
Write-Host

try {
    New-Item -ItemType Directory -Path $localBundle -Force | Out-Null
    $localServer = Join-Path $localBundle 'controller_setup_management_browser_preview_server.sh'
    $localEntry = Join-Path $localBundle 'controller_setup_management_browser_preview_entry.py'
    $localCleanup = Join-Path $localBundle 'controller_setup_management_browser_preview_cleanup_server.sh'

    Write-LinuxTextFile -Source $ServerScript -Destination $localServer
    Write-LinuxTextFile -Source $PreviewEntry -Destination $localEntry
    Write-LinuxTextFile -Source $CleanupServerScript -Destination $localCleanup

    # Keep the server template historically pinned, but transform the uploaded
    # disposable-preview runner to this exact locally tested candidate.
    $serverText = [System.IO.File]::ReadAllText($localServer)
    if (-not $serverText.Contains($TemplateCandidateSha)) {
        throw "Browser preview server template no longer contains expected candidate $TemplateCandidateSha"
    }
    $serverText = $serverText.Replace($TemplateCandidateSha, $CandidateSha)
    [System.IO.File]::WriteAllText($localServer, $serverText, $utf8NoBom)

    & scp -r $localBundle "${Server}:/tmp/"
    if ($LASTEXITCODE -ne 0) {
        throw "SCP browser preview bundle upload failed with exit code $LASTEXITCODE"
    }

    Write-Host
    Write-Host 'Cleaning stale preview state and preparing disposable browser preview...'
    Start-Process $browserUrl

    $uploadCleanup = "$uploadRoot/controller_setup_management_browser_preview_cleanup_server.sh"
    $remoteScript = "$remoteRoot/controller_setup_management_browser_preview_server.sh"
    $remoteEntry = "$remoteRoot/controller_setup_management_browser_preview_entry.py"
    $remoteCleanup = "$remoteRoot/controller_setup_management_browser_preview_cleanup_server.sh"
    $remoteCommand = "chmod 700 '$uploadCleanup' && bash -n '$uploadCleanup' && bash '$uploadCleanup' '$PreviewPort' && mv '$uploadRoot' '$remoteRoot' && chmod 755 '$remoteRoot' && chmod 700 '$remoteScript' '$remoteCleanup' && chmod 644 '$remoteEntry' && bash -n '$remoteScript'; timeout --signal=TERM 7200s bash '$remoteScript' '$PreviewPort' '$PreviewEmail'"
    & ssh -tt -L "${PreviewPort}:127.0.0.1:${PreviewPort}" $Server $remoteCommand
    $remoteExit = $LASTEXITCODE

    if ($remoteExit -ne 0) {
        throw "Controller browser preview failed with exit code $remoteExit. Review the remote /tmp/MSB_Controller_Browser_Preview_*.txt report named in the output."
    }

    Write-Host
    Write-Host 'CONTROLLER SETUP + MANAGEMENT BROWSER PREVIEW: CLEAN EXIT'
}
finally {
    if (Test-Path -LiteralPath $localBundle) {
        Remove-Item -LiteralPath $localBundle -Recurse -Force -ErrorAction SilentlyContinue
    }
}
