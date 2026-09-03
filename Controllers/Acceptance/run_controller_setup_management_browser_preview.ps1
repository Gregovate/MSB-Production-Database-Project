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
$ExpectedBranch = 'agent/controller-inventory-ref-sandbox'
$CandidateSha = '2fd2067958cc0a903260fe6f089f88ae63a857f1'

foreach ($path in @($ServerScript, $PreviewEntry)) {
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

$stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$bundleName = "msb-controller-browser-preview-$stamp"
$localBundle = Join-Path ([System.IO.Path]::GetTempPath()) $bundleName
$remoteRoot = "/tmp/$bundleName"
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
Write-Host 'The browser will open automatically. If it opens before Flask is ready, leave it open and refresh after BROWSER REVIEW READY appears.'
Write-Host 'Keep this PowerShell window open while reviewing the browser.'
Write-Host 'When finished, return here and press ENTER so the remote trap can clean up.'
Write-Host

try {
    New-Item -ItemType Directory -Path $localBundle -Force | Out-Null
    Write-LinuxTextFile -Source $ServerScript -Destination (Join-Path $localBundle 'controller_setup_management_browser_preview_server.sh')
    Write-LinuxTextFile -Source $PreviewEntry -Destination (Join-Path $localBundle 'controller_setup_management_browser_preview_entry.py')

    & scp -r $localBundle "${Server}:/tmp/"
    if ($LASTEXITCODE -ne 0) {
        throw "SCP browser preview bundle upload failed with exit code $LASTEXITCODE"
    }

    Write-Host
    Write-Host 'Preparing disposable browser preview...'
    Start-Process $browserUrl

    $remoteScript = "$remoteRoot/controller_setup_management_browser_preview_server.sh"
    $remoteEntry = "$remoteRoot/controller_setup_management_browser_preview_entry.py"
    $remoteCommand = "chmod 755 '$remoteRoot' && chmod 700 '$remoteScript' && chmod 644 '$remoteEntry' && bash -n '$remoteScript'; timeout --signal=TERM 7200s bash '$remoteScript' '$PreviewPort' '$PreviewEmail'"
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
