param(
    [string]$Server = 'msbadmin@192.168.5.9',
    [Parameter(Mandatory=$true)]
    [int]$PreviewPort,
    [string]$PreviewEmail = 'gliebig@sheboyganlights.org'
)

$ErrorActionPreference = 'Stop'
$CandidateSha = '51c739bd85115c9f5d2853763e8e1450ac381407'
$ExpectedBranch = 'agent/setup-session-production-foundation'

if ($PreviewPort -lt 1024 -or $PreviewPort -gt 65535) {
    throw 'PreviewPort must be between 1024 and 65535.'
}
if ($PreviewPort -in @(8055, 8790, 8792, 8794)) {
    throw "PreviewPort $PreviewPort conflicts with a Production listener."
}
if ($PreviewEmail -notmatch '^[A-Za-z0-9._%+\-]+@[A-Za-z0-9.\-]+$') {
    throw 'PreviewEmail is not a valid email address.'
}

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$RepoRoot = (Resolve-Path (Join-Path $ScriptDir '..\..')).Path
$ServerScript = Join-Path $ScriptDir 'setup_source_only_browser_preview_server.sh'
$EntryScript = Join-Path $ScriptDir 'setup_session_browser_preview_entry.py'
foreach ($path in @($ServerScript, $EntryScript)) {
    if (-not (Test-Path -LiteralPath $path)) {
        throw "Required Setup preview file is missing: $path"
    }
}

$currentBranch = (& git -C $RepoRoot branch --show-current).Trim()
if ($LASTEXITCODE -ne 0 -or $currentBranch -ne $ExpectedBranch) {
    throw "Run this preview from branch $ExpectedBranch. Current branch: $currentBranch"
}

$dirty = (& git -C $RepoRoot status --porcelain)
if ($LASTEXITCODE -ne 0) {
    throw 'Unable to verify local Git worktree status.'
}
if ($dirty) {
    throw 'Local worktree is not clean. Pull/commit/stash/revert before preview.'
}

& git -C $RepoRoot cat-file -e "${CandidateSha}^{commit}"
if ($LASTEXITCODE -ne 0) {
    throw "Accepted Setup repair candidate is not available locally: $CandidateSha"
}
& git -C $RepoRoot merge-base --is-ancestor $CandidateSha HEAD
if ($LASTEXITCODE -ne 0) {
    throw "Current branch does not contain the accepted Setup repair candidate $CandidateSha"
}

$stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$tempRoot = Join-Path ([System.IO.Path]::GetTempPath()) "msb-setup-source-preview-$stamp"
New-Item -ItemType Directory -Path $tempRoot -Force | Out-Null
$remoteServerName = "msb-setup-source-preview-$stamp.sh"
$remoteEntryName = "msb-setup-source-preview-entry-$stamp.py"
$localServer = Join-Path $tempRoot $remoteServerName
$localEntry = Join-Path $tempRoot $remoteEntryName
$utf8NoBom = New-Object System.Text.UTF8Encoding($false)

function Write-LinuxTextFile {
    param(
        [Parameter(Mandatory=$true)][string]$Source,
        [Parameter(Mandatory=$true)][string]$Destination
    )
    $text = [System.IO.File]::ReadAllText($Source)
    $text = $text.Replace("`r`n", "`n").Replace("`r", "`n")
    [System.IO.File]::WriteAllText($Destination, $text, $utf8NoBom)
}

try {
    Write-LinuxTextFile -Source $ServerScript -Destination $localServer
    Write-LinuxTextFile -Source $EntryScript -Destination $localEntry

    # Keep the target-user child process independent of inherited shell
    # variables. The Production Python path is a current documented runtime fact.
    $serverText = [System.IO.File]::ReadAllText($localServer)
    $pythonNeedle = '            setsid "$PYTHON" "$PREVIEW_ENTRY" > "$PREVIEW_LOG" 2>&1 &'
    $pythonReplacement = '            setsid /opt/fieldwiring/.venv/bin/python "$PREVIEW_ENTRY" > "$PREVIEW_LOG" 2>&1 &'
    if (-not $serverText.Contains($pythonNeedle)) {
        throw 'Source-only preview server no longer contains the expected Python launch command.'
    }
    $serverText = $serverText.Replace($pythonNeedle, $pythonReplacement)
    [System.IO.File]::WriteAllText($localServer, $serverText, $utf8NoBom)

    Write-Host '========== SETUP SOURCE-ONLY BROWSER PREVIEW =========='
    Write-Host "Candidate SHA: $CandidateSha"
    Write-Host "Preview URL:   http://127.0.0.1:$PreviewPort/"
    Write-Host "Preview user:  $PreviewEmail"
    Write-Host
    Write-Host 'This uses a disposable current-Production database clone.'
    Write-Host 'Production Setup data and /opt/msb-setup remain unchanged.'
    Write-Host 'The clone reproduces fieldwiring_app default_transaction_read_only=on.'
    Write-Host

    & scp $localServer $localEntry "${Server}:/tmp/"
    if ($LASTEXITCODE -ne 0) {
        throw "SCP failed with exit code $LASTEXITCODE"
    }

    $remoteServer = "/tmp/$remoteServerName"
    $remoteEntry = "/tmp/$remoteEntryName"
    $remoteCommand = "chmod 700 '$remoteServer'; cd /tmp; cp '$remoteEntry' ./setup_session_browser_preview_entry.py; bash '$remoteServer' '$CandidateSha' '$PreviewPort' '$PreviewEmail'; rc=`$?; rm -f '$remoteServer' '$remoteEntry' ./setup_session_browser_preview_entry.py; exit `$rc"

    Write-Host 'Keep this PowerShell window open during browser review.'
    Write-Host 'When the server reports SETUP SOURCE-ONLY BROWSER REVIEW READY, open the Preview URL.'
    Write-Host

    & ssh -t -L "${PreviewPort}:127.0.0.1:${PreviewPort}" $Server $remoteCommand
    if ($LASTEXITCODE -ne 0) {
        throw "SSH preview session failed with exit code $LASTEXITCODE"
    }
}
finally {
    Remove-Item -LiteralPath $tempRoot -Recurse -Force -ErrorAction SilentlyContinue
}
