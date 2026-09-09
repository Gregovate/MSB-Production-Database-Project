param(
    [string]$Server = 'msbadmin@192.168.5.9',
    [Parameter(Mandatory=$true)]
    [int]$PreviewPort,
    [string]$PreviewEmail = 'gliebig@sheboyganlights.org'
)

$ErrorActionPreference = 'Stop'

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$RepoRoot = (Resolve-Path (Join-Path $ScriptDir '..\..')).Path
$ServerScript = Join-Path $ScriptDir 'people_manager_browser_preview_server.sh'
$PreviewEntry = Join-Path $ScriptDir 'people_manager_browser_preview_entry.py'
$CleanupServerScript = Join-Path $ScriptDir 'people_manager_browser_preview_cleanup_server.sh'
$ExpectedBranch = 'agent/people-manager-milestone1-20260908'
$CandidateSha = '7cd4c02420f564c1fe563d0c12052480c6ce6f6b'

foreach ($path in @($ServerScript, $PreviewEntry, $CleanupServerScript)) {
    if (-not (Test-Path -LiteralPath $path)) {
        throw "Required browser preview file is missing: $path"
    }
}

if ($PreviewPort -lt 1024 -or $PreviewPort -gt 65535) {
    throw 'PreviewPort must be between 1024 and 65535.'
}
if ($PreviewPort -eq 8794) {
    throw 'PreviewPort 8794 is the live Production Setup listener and must never be used for browser preview.'
}
if ($PreviewPort -in @(8055, 8790, 8792)) {
    throw "PreviewPort $PreviewPort conflicts with a governed Production listener."
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
    throw "Accepted People candidate commit is not available locally: $CandidateSha"
}

& git -C $RepoRoot merge-base --is-ancestor $CandidateSha HEAD
if ($LASTEXITCODE -ne 0) {
    throw "Accepted People candidate $CandidateSha is not an ancestor of the current branch head."
}

# Acceptance/harness documentation may advance after the accepted candidate,
# but application/database behavior must remain exactly what passed the
# disposable gate. Refuse preview if either governed candidate area changed.
$changedCandidateFiles = @(& git -C $RepoRoot diff --name-only "$CandidateSha..HEAD" -- People/Application People/Database)
if ($LASTEXITCODE -ne 0) {
    throw 'Unable to compare current branch with the accepted People candidate.'
}
if ($changedCandidateFiles.Count -gt 0) {
    throw "People Application/Database files changed after accepted candidate $CandidateSha. Re-run engineering/disposable acceptance before browser review.`n$($changedCandidateFiles -join "`n")"
}

# Ctrl+C can leave the local SSH tunnel listening after the remote preview
# stops. Stop only ssh.exe on this explicitly selected preview port. Refuse to
# terminate any unrelated local process.
$localListeners = @(Get-NetTCPConnection -LocalPort $PreviewPort -State Listen -ErrorAction SilentlyContinue)
foreach ($listener in $localListeners) {
    $owner = Get-Process -Id $listener.OwningProcess -ErrorAction SilentlyContinue
    if ($null -eq $owner) {
        continue
    }
    if ($owner.ProcessName -ne 'ssh') {
        throw "Local preview port $PreviewPort is owned by non-SSH process $($owner.ProcessName) PID $($owner.Id). Not stopping it automatically."
    }
    Write-Host "Stopping stale local SSH People preview tunnel PID $($owner.Id) on port $PreviewPort"
    Stop-Process -Id $owner.Id -Force
}

$stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
# Upload outside the stale-preview cleanup glob. After cleanup passes, the
# uploaded bundle is moved to the normal preview prefix for bounded teardown.
$bundleName = "msb-people-preview-session-$stamp"
$localBundle = Join-Path ([System.IO.Path]::GetTempPath()) $bundleName
$uploadRoot = "/tmp/$bundleName"
$remoteRoot = "/tmp/msb-people-browser-preview-$stamp"
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

Write-Host '========== PEOPLE MANAGER PRE-PRODUCTION BROWSER REVIEW =========='
Write-Host "Server:        $Server"
Write-Host "Candidate SHA: $CandidateSha"
Write-Host "Browser URL:   $browserUrl"
Write-Host "Preview user:  $PreviewEmail"
Write-Host 'Authority: MSB-Server-Management — Pre_Production_Browser_Review_Runbook.md'
Write-Host 'Clone authority: MSB-Server-Management — PostgreSQL_Disposable_Acceptance_Standard.md'
Write-Host
Write-Host 'This runs the exact disposable-accepted People candidate against a new current-Production clone.'
Write-Host 'Production ref.person, the Production checkout, and fieldwiring.service are not changed.'
Write-Host 'The browser is not auto-opened; wait for BROWSER REVIEW READY before opening the URL shown above.'
Write-Host 'Keep this PowerShell window open during review.'
Write-Host 'When finished, return here and press ENTER so the governed teardown can complete.'
Write-Host

try {
    New-Item -ItemType Directory -Path $localBundle -Force | Out-Null
    $localServer = Join-Path $localBundle 'people_manager_browser_preview_server.sh'
    $localEntry = Join-Path $localBundle 'people_manager_browser_preview_entry.py'
    $localCleanup = Join-Path $localBundle 'people_manager_browser_preview_cleanup_server.sh'

    Write-LinuxTextFile -Source $ServerScript -Destination $localServer
    Write-LinuxTextFile -Source $PreviewEntry -Destination $localEntry
    Write-LinuxTextFile -Source $CleanupServerScript -Destination $localCleanup

    & scp -r $localBundle "${Server}:/tmp/"
    if ($LASTEXITCODE -ne 0) {
        throw "SCP People browser preview bundle upload failed with exit code $LASTEXITCODE"
    }

    Write-Host
    Write-Host 'Cleaning stale People preview state and preparing disposable browser review...'

    $uploadCleanup = "$uploadRoot/people_manager_browser_preview_cleanup_server.sh"
    $remoteScript = "$remoteRoot/people_manager_browser_preview_server.sh"
    $remoteEntry = "$remoteRoot/people_manager_browser_preview_entry.py"
    $remoteCleanup = "$remoteRoot/people_manager_browser_preview_cleanup_server.sh"
    $remoteCommand = "chmod 700 '$uploadCleanup' && bash -n '$uploadCleanup' && bash '$uploadCleanup' '$PreviewPort' && mv '$uploadRoot' '$remoteRoot' && chmod 755 '$remoteRoot' && chmod 700 '$remoteScript' '$remoteCleanup' && chmod 644 '$remoteEntry' && bash -n '$remoteScript' && timeout --signal=TERM 7200s bash '$remoteScript' '$PreviewPort' '$PreviewEmail'"

    # Foreground SSH owns the console directly so SSH/sudo prompts and the final
    # operator ENTER remain usable. The tunnel exposes only the temporary
    # localhost preview listener to this workstation.
    & ssh -tt -L "${PreviewPort}:127.0.0.1:${PreviewPort}" $Server $remoteCommand
    $remoteExit = $LASTEXITCODE

    if ($remoteExit -ne 0) {
        throw "People Manager browser preview failed with exit code $remoteExit. Review the remote /tmp/MSB_People_Manager_Browser_Preview_*.txt report named in the output."
    }

    Write-Host
    Write-Host 'PEOPLE MANAGER BROWSER PREVIEW: CLEAN EXIT'
}
finally {
    if (Test-Path -LiteralPath $localBundle) {
        Remove-Item -LiteralPath $localBundle -Recurse -Force -ErrorAction SilentlyContinue
    }
}
