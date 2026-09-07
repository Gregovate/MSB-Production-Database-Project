param(
    [string]$Server = 'msbadmin@192.168.5.9',
    [int]$PreviewPort = 8794,
    [string]$PreviewEmail = 'gliebig@sheboyganlights.org'
)

$ErrorActionPreference = 'Stop'

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$RepoRoot = (Resolve-Path (Join-Path $ScriptDir '..\..')).Path
$ServerScript = Join-Path $ScriptDir 'setup_session_browser_preview_server.sh'
$PreviewEntry = Join-Path $ScriptDir 'setup_session_browser_preview_entry.py'
$CleanupServerScript = Join-Path $ScriptDir 'setup_session_browser_preview_cleanup_server.sh'
$ExpectedBranch = 'agent/setup-session-production-foundation'
$CandidateSha = 'c72644f02b825acb830603fe6b4f7bd48713b681'

foreach ($path in @($ServerScript, $PreviewEntry, $CleanupServerScript)) {
    if (-not (Test-Path -LiteralPath $path)) {
        throw "Required Setup browser preview file is missing: $path"
    }
}

if ($PreviewPort -lt 1024 -or $PreviewPort -gt 65535) {
    throw 'PreviewPort must be between 1024 and 65535.'
}
if ($PreviewPort -in @(8055, 8784, 8790, 8792)) {
    throw "PreviewPort $PreviewPort conflicts with a governed production listener."
}
if ($PreviewEmail -notmatch '^[A-Za-z0-9._%+\-]+@[A-Za-z0-9.\-]+$') {
    throw 'PreviewEmail is not a valid email address.'
}

$currentBranch = (& git -C $RepoRoot branch --show-current).Trim()
if ($LASTEXITCODE -ne 0 -or $currentBranch -ne $ExpectedBranch) {
    throw "Run this Setup browser preview from branch $ExpectedBranch. Current branch: $currentBranch"
}

$dirty = (& git -C $RepoRoot status --porcelain)
if ($LASTEXITCODE -ne 0) {
    throw 'Unable to verify local Git worktree status.'
}
if ($dirty) {
    throw 'Local worktree is not clean. Pull/commit/stash/revert before packaging the Setup preview.'
}

& git -C $RepoRoot cat-file -e "${CandidateSha}^{commit}"
if ($LASTEXITCODE -ne 0) {
    throw "Accepted Setup candidate commit is not available locally: $CandidateSha"
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

$stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$bundleName = "msb-setup-preview-session-$stamp"
$localBundle = Join-Path ([System.IO.Path]::GetTempPath()) $bundleName
$uploadRoot = "/tmp/$bundleName"
$remoteRoot = "/tmp/msb-setup-browser-preview-$stamp"
$utf8NoBom = New-Object System.Text.UTF8Encoding($false)
$browserUrl = "http://127.0.0.1:$PreviewPort/"

function Write-LinuxTextFile {
    param(
        [Parameter(Mandatory=$true)][string]$Source,
        [Parameter(Mandatory=$true)][string]$Destination
    )
    $text = [System.IO.File]::ReadAllText($Source)
    $text = $text.Replace("`r`n", "`n").Replace("`r", "`n")
    [System.IO.File]::WriteAllText($Destination, $text, $utf8NoBom)
}

Write-Host '========== SETUP SESSION BROWSER PREVIEW =========='
Write-Host "Server:        $Server"
Write-Host "Candidate SHA: $CandidateSha"
Write-Host "Browser URL:   $browserUrl"
Write-Host "Preview user:  $PreviewEmail"
Write-Host
Write-Host 'This preview uses a disposable current-production PostgreSQL clone.'
Write-Host 'Production Setup data and the live shared application checkout are not modified.'
Write-Host 'The browser is not auto-opened; wait for SETUP BROWSER REVIEW READY before opening it.'
Write-Host 'Keep this PowerShell window open while reviewing the browser.'
Write-Host 'When finished, return here and press ENTER so the remote trap can clean up.'
Write-Host

try {
    New-Item -ItemType Directory -Path $localBundle -Force | Out-Null
    $localServer = Join-Path $localBundle 'setup_session_browser_preview_server.sh'
    $localEntry = Join-Path $localBundle 'setup_session_browser_preview_entry.py'
    $localCleanup = Join-Path $localBundle 'setup_session_browser_preview_cleanup_server.sh'

    Write-LinuxTextFile -Source $ServerScript -Destination $localServer
    Write-LinuxTextFile -Source $PreviewEntry -Destination $localEntry
    Write-LinuxTextFile -Source $CleanupServerScript -Destination $localCleanup

    # The preview server performs one post-start JSON validation with the production
    # Python runtime. /opt/fieldwiring is intentionally not traversable by msbadmin,
    # so package that one validator under the fieldwiring runtime account as well.
    $serverText = [System.IO.File]::ReadAllText($localServer)
    $validatorOld = "/opt/fieldwiring/.venv/bin/python - `"`$MEGA_PROCEDURE`" <<'PY'"
    $validatorNew = "sudo -u fieldwiring -H /opt/fieldwiring/.venv/bin/python - `"`$MEGA_PROCEDURE`" <<'PY'"
    if (-not $serverText.Contains($validatorOld)) {
        throw 'Setup browser preview server template no longer contains the expected Mega Cube validator command.'
    }
    $serverText = $serverText.Replace($validatorOld, $validatorNew)
    [System.IO.File]::WriteAllText($localServer, $serverText, $utf8NoBom)

    & scp -r $localBundle "${Server}:/tmp/"
    if ($LASTEXITCODE -ne 0) {
        throw "SCP Setup browser preview bundle upload failed with exit code $LASTEXITCODE"
    }

    Write-Host
    Write-Host 'Cleaning stale Setup preview state and preparing disposable browser preview...'

    $uploadCleanup = "$uploadRoot/setup_session_browser_preview_cleanup_server.sh"
    $remoteScript = "$remoteRoot/setup_session_browser_preview_server.sh"
    $remoteEntry = "$remoteRoot/setup_session_browser_preview_entry.py"
    $remoteCleanup = "$remoteRoot/setup_session_browser_preview_cleanup_server.sh"
    $remoteCommand = "chmod 700 '$uploadCleanup' && bash -n '$uploadCleanup' && bash '$uploadCleanup' '$PreviewPort' && mv '$uploadRoot' '$remoteRoot' && chmod 755 '$remoteRoot' && chmod 700 '$remoteScript' '$remoteCleanup' && chmod 644 '$remoteEntry' && bash -n '$remoteScript' && timeout --signal=TERM 7200s bash '$remoteScript' '$PreviewPort' '$PreviewEmail'"

    & ssh -tt -L "${PreviewPort}:127.0.0.1:${PreviewPort}" $Server $remoteCommand
    $remoteExit = $LASTEXITCODE

    if ($remoteExit -ne 0) {
        throw "Setup browser preview failed with exit code $remoteExit. Review the remote /tmp/MSB_Setup_Session_Browser_Preview_*.txt report named in the output."
    }

    Write-Host
    Write-Host 'SETUP SESSION BROWSER PREVIEW: CLEAN EXIT'
}
finally {
    if (Test-Path -LiteralPath $localBundle) {
        Remove-Item -LiteralPath $localBundle -Recurse -Force -ErrorAction SilentlyContinue
    }
}
