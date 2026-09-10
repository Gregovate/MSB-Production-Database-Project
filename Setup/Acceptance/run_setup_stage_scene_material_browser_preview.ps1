param(
    [string]$Server = 'msbadmin@192.168.5.9',
    [Parameter(Mandatory=$true)]
    [int]$PreviewPort,
    [Parameter(Mandatory=$true)]
    [string]$CandidateSha,
    [string]$TargetRef = 'agent/setup-stage-scene-material-fix-20260910',
    [string]$PreviewEmail = 'gliebig@sheboyganlights.org'
)

$ErrorActionPreference = 'Stop'

$repo = (git rev-parse --show-toplevel).Trim()
if (-not $repo) {
    throw 'Run this wrapper from an MSB-Production-Database-Project checkout.'
}

& git -C $repo cat-file -e "${CandidateSha}^{commit}"
if ($LASTEXITCODE -ne 0) {
    & git -C $repo fetch origin $TargetRef
    if ($LASTEXITCODE -ne 0) {
        throw "Unable to fetch candidate ref $TargetRef"
    }
    & git -C $repo cat-file -e "${CandidateSha}^{commit}"
    if ($LASTEXITCODE -ne 0) {
        throw "Candidate SHA is not available locally after fetch: $CandidateSha"
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

$serverScript = Join-Path $repo 'Setup\Acceptance\setup_stage_scene_material_browser_preview_server.sh'
if (-not (Test-Path -LiteralPath $serverScript -PathType Leaf)) {
    throw "Required Setup Stage/Scene preview runner is missing: $serverScript"
}

$stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$bundleName = "msb-setup-stage-scene-browser-preview-$stamp"
$localBundle = Join-Path $env:TEMP $bundleName
$remoteBundle = "/tmp/$bundleName"
$utf8NoBom = [System.Text.UTF8Encoding]::new($false)
$browserUrl = "http://127.0.0.1:$PreviewPort/"

try {
    New-Item -ItemType Directory -Path $localBundle -Force | Out-Null
    $runner = Join-Path $localBundle 'setup_stage_scene_material_browser_preview_server.sh'
    $text = [System.IO.File]::ReadAllText($serverScript)
    $text = $text.Replace("`r`n", "`n").Replace("`r", "`n")
    [System.IO.File]::WriteAllText($runner, $text, $utf8NoBom)

    Write-Host '========== SETUP STAGE/SCENE BROWSER PREVIEW =========='
    Write-Host 'Authority: Gregovate/MSB-Server-Management — docs/server/Pre_Production_Browser_Review_Runbook.md'
    Write-Host 'Disposable standard: docs/server/PostgreSQL_Disposable_Acceptance_Standard.md'
    Write-Host "Server:        $Server"
    Write-Host "Candidate SHA: $CandidateSha"
    Write-Host "Target ref:    $TargetRef"
    Write-Host "Preview port:  $PreviewPort"
    Write-Host "Browser URL:   $browserUrl"
    Write-Host "Preview user:  $PreviewEmail"
    Write-Host
    Write-Host 'Production database contract: pg_dump + SELECT only'
    Write-Host 'All migration/API/browser writes: disposable current-Production clone only'
    Write-Host 'The browser is not opened automatically. Wait for SETUP STAGE/SCENE BROWSER REVIEW READY.'
    Write-Host 'Keep this PowerShell window open during browser review.'
    Write-Host

    & scp -r $localBundle "${Server}:/tmp/"
    if ($LASTEXITCODE -ne 0) {
        throw "SCP preview bundle upload failed with exit code $LASTEXITCODE"
    }

    $remoteRunner = "$remoteBundle/setup_stage_scene_material_browser_preview_server.sh"
    $remoteCommand = "chmod 700 '$remoteRunner' && bash -n '$remoteRunner' && bash '$remoteRunner' '$PreviewPort' '$PreviewEmail' '$TargetRef' '$CandidateSha'"

    & ssh -tt -L "${PreviewPort}:127.0.0.1:${PreviewPort}" $Server $remoteCommand
    $remoteExit = $LASTEXITCODE
    if ($remoteExit -ne 0) {
        throw "Setup Stage/Scene browser preview failed with exit code $remoteExit. Use the retained remote report for the exact failed gate."
    }

    Write-Host
    Write-Host 'SETUP STAGE/SCENE BROWSER PREVIEW: CLEAN EXIT'
}
finally {
    Remove-Item -LiteralPath $localBundle -Recurse -Force -ErrorAction SilentlyContinue
}
