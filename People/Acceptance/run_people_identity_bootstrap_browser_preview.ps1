param(
    [string]$Server = 'msbadmin@192.168.5.9',
    [Parameter(Mandatory=$true)]
    [int]$PreviewPort
)

$ErrorActionPreference = 'Stop'

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$RepoRoot = (Resolve-Path (Join-Path $ScriptDir '..\..')).Path
$ServerScript = Join-Path $ScriptDir 'people_identity_bootstrap_browser_preview_server.sh'
$PreviewEntry = Join-Path $ScriptDir 'people_identity_bootstrap_browser_preview_entry.py'
$ExpectedBranch = 'issue-395-silent-human-identity-bootstrap'
$AcceptedRuntimeSha = 'dcc8f25f07a74e19ce3de3aae2d9d137b5411815'

foreach ($path in @($ServerScript, $PreviewEntry)) {
    if (-not (Test-Path -LiteralPath $path)) {
        throw "Required #395 browser-review file is missing: $path"
    }
}

if ($PreviewPort -ne 8795) {
    throw 'People browser review uses the registered preview port 8795.'
}

$origin = (& git -C $RepoRoot remote get-url origin).Trim()
if ($LASTEXITCODE -ne 0 -or $origin -notmatch 'Gregovate/MSB-Production-Database-Project') {
    throw "STOP: wrong repository. origin=$origin"
}

$currentBranch = (& git -C $RepoRoot branch --show-current).Trim()
if ($LASTEXITCODE -ne 0 -or $currentBranch -ne $ExpectedBranch) {
    throw "STOP: run from '$ExpectedBranch'. Current branch: '$currentBranch'"
}

$dirty = @(& git -C $RepoRoot status --porcelain)
if ($LASTEXITCODE -ne 0) { throw 'Unable to verify local Git worktree status.' }
if ($dirty.Count -gt 0) { throw 'Local worktree is not clean. Commit/stash/revert before browser review.' }

& git -C $RepoRoot fetch origin $ExpectedBranch
if ($LASTEXITCODE -ne 0) { throw 'Unable to refresh #395 candidate branch.' }

$RemoteSha = (& git -C $RepoRoot rev-parse "origin/$ExpectedBranch").Trim()
$HeadSha = (& git -C $RepoRoot rev-parse HEAD).Trim()
if ($HeadSha -ne $RemoteSha) {
    throw "STOP: local branch is not current. Local=$HeadSha Remote=$RemoteSha"
}

& git -C $RepoRoot cat-file -e "${AcceptedRuntimeSha}^{commit}"
if ($LASTEXITCODE -ne 0) { throw "Accepted runtime SHA unavailable locally: $AcceptedRuntimeSha" }

$runtimeChanges = @(& git -C $RepoRoot diff --name-only "$AcceptedRuntimeSha..HEAD" -- People/Application People/Database)
if ($LASTEXITCODE -ne 0) { throw 'Unable to verify accepted runtime freeze.' }
if ($runtimeChanges.Count -gt 0) {
    throw ("STOP: People runtime changed after disposable acceptance. Re-run disposable acceptance first.`n" + ($runtimeChanges -join "`n"))
}

$listeners = @(Get-NetTCPConnection -LocalPort $PreviewPort -State Listen -ErrorAction SilentlyContinue)
foreach ($listener in $listeners) {
    $owner = Get-Process -Id $listener.OwningProcess -ErrorAction SilentlyContinue
    if ($null -eq $owner) { continue }
    if ($owner.ProcessName -ne 'ssh') {
        throw "Local preview port $PreviewPort is owned by $($owner.ProcessName) PID $($owner.Id). Stop/review it manually; no automatic kill."
    }
    throw "Local preview port $PreviewPort already has an SSH listener PID $($owner.Id). Close the prior preview/tunnel before starting this review."
}

$stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$bundleName = "msb-395-browser-preview-$stamp"
$localBundle = Join-Path ([System.IO.Path]::GetTempPath()) $bundleName
$remoteRoot = "/tmp/$bundleName"
$utf8NoBom = New-Object System.Text.UTF8Encoding($false)

function Write-LinuxTextFile {
    param(
        [Parameter(Mandatory=$true)][string]$Source,
        [Parameter(Mandatory=$true)][string]$Destination
    )
    $text = [System.IO.File]::ReadAllText($Source)
    $text = $text.Replace(([string][char]13 + [char]10), [string][char]10).Replace([string][char]13, [string][char]10)
    [System.IO.File]::WriteAllText($Destination, $text, $utf8NoBom)
}

Write-Host '========== PEOPLE #395 + APPS #24 INTEGRATED BROWSER REVIEW =========='
Write-Host "Server:              $Server"
Write-Host "People runtime SHA:  $AcceptedRuntimeSha"
Write-Host "Preview port:        $PreviewPort"
Write-Host 'Authority: MSB-Server-Management — docs/server/Pre_Production_Browser_Review_Runbook.md'
Write-Host 'Clone authority: MSB-Server-Management — docs/server/PostgreSQL_Disposable_Acceptance_Standard.md'
Write-Host 'Production mutation: NONE'
Write-Host
Write-Host 'Wait for BROWSER REVIEW READY before opening the localhost URL.'
Write-Host 'Keep this PowerShell window open during review; press ENTER here when finished.'
Write-Host

try {
    New-Item -ItemType Directory -Path $localBundle -Force | Out-Null
    $localServer = Join-Path $localBundle 'people_identity_bootstrap_browser_preview_server.sh'
    $localEntry = Join-Path $localBundle 'people_identity_bootstrap_browser_preview_entry.py'

    Write-LinuxTextFile -Source $ServerScript -Destination $localServer
    Write-LinuxTextFile -Source $PreviewEntry -Destination $localEntry

    & scp -r $localBundle "${Server}:/tmp/"
    if ($LASTEXITCODE -ne 0) { throw "SCP browser-review bundle failed with exit code $LASTEXITCODE" }

    $remoteScript = "$remoteRoot/people_identity_bootstrap_browser_preview_server.sh"
    $remoteCommand = "chmod 700 '$remoteScript' && chmod 644 '$remoteRoot/people_identity_bootstrap_browser_preview_entry.py' && bash -n '$remoteScript' && timeout --foreground --signal=TERM 7200s bash '$remoteScript' '$PreviewPort'"

    & ssh -tt -o ServerAliveInterval=15 -o ServerAliveCountMax=3 -L "${PreviewPort}:127.0.0.1:${PreviewPort}" $Server $remoteCommand
    $remoteExit = $LASTEXITCODE

    if ($remoteExit -ne 0) {
        throw "#395 integrated browser preview stopped with exit code $remoteExit. Review the retained MSB_People_Identity_Bootstrap_Browser_Preview report named in the server output."
    }

    Write-Host
    Write-Host 'PEOPLE #395 + APPS #24 INTEGRATED BROWSER REVIEW WRAPPER: PASS'
    Write-Host 'Production and Don were not mutated.'
}
finally {
    if (Test-Path -LiteralPath $localBundle) {
        Remove-Item -LiteralPath $localBundle -Recurse -Force -ErrorAction SilentlyContinue
    }
}
