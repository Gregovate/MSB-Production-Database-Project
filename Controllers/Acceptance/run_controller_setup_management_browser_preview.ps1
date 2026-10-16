param(
    [string]$Server = 'msbadmin@192.168.5.9',
    [Parameter(Mandatory=$true)][int]$PreviewPort,
    [Parameter(Mandatory=$true)][string]$CandidateSha,
    [Parameter(Mandatory=$true)][string]$TargetRef,
    [string]$PreviewEmail = 'gliebig@sheboyganlights.org'
)
$ErrorActionPreference = 'Stop'
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$RepoRoot = (Resolve-Path (Join-Path $ScriptDir '..\..')).Path
if ($PreviewPort -ne 8898) { throw 'STOP: Controller preview must use registered port 8898.' }
if ($PreviewEmail -notmatch '^[A-Za-z0-9._%+\-]+@[A-Za-z0-9.\-]+$') { throw 'Invalid PreviewEmail.' }
$branch = (& git -C $RepoRoot branch --show-current).Trim()
if ($LASTEXITCODE -ne 0 -or ($branch -and $branch -ne $TargetRef)) { throw "STOP: worktree must be detached or on '$TargetRef'; got '$branch'." }
$dirty = & git -C $RepoRoot status --porcelain
if ($LASTEXITCODE -ne 0 -or $dirty) { throw 'STOP: preview source worktree must be clean.' }
& git -C $RepoRoot cat-file -e "${CandidateSha}^{commit}"
if ($LASTEXITCODE -ne 0) { throw 'STOP: exact candidate SHA not available locally.' }
$head = (& git -C $RepoRoot rev-parse HEAD).Trim()
if ($LASTEXITCODE -ne 0 -or $head -ne $CandidateSha) { throw "STOP: checkout HEAD $head differs from exact candidate $CandidateSha." }
$localListeners = @(Get-NetTCPConnection -LocalPort $PreviewPort -State Listen -ErrorAction SilentlyContinue)
if ($localListeners.Count -gt 0) { throw "STOP: workstation port $PreviewPort is listening. Inspect its owner; do not kill it." }
$serverScript = Join-Path $ScriptDir 'controller_setup_management_browser_preview_server.sh'
$entry = Join-Path $ScriptDir 'controller_setup_management_browser_preview_entry.py'
$stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$bundle = Join-Path ([System.IO.Path]::GetTempPath()) "msb-controller-preview-$stamp"
$remote = "/tmp/msb-controller-preview-$stamp"
$utf8 = New-Object System.Text.UTF8Encoding($false)
try {
    New-Item -ItemType Directory -Path $bundle -Force | Out-Null
    foreach ($file in @($serverScript,$entry)) {
        if (-not (Test-Path -LiteralPath $file)) { throw "Missing source: $file" }
        $value = [IO.File]::ReadAllText($file).Replace("`r`n","`n").Replace("`r","`n")
        [IO.File]::WriteAllText((Join-Path $bundle (Split-Path $file -Leaf)), $value, $utf8)
    }
    Write-Host "Candidate: $CandidateSha"
    Write-Host "Separate server worktree; current-Production disposable clone; Production untouched."
    Write-Host 'Do not open the browser until the runner prints BROWSER REVIEW READY.'
    & scp -r $bundle "${Server}:/tmp/"
    if ($LASTEXITCODE -ne 0) { throw "SCP failed: $LASTEXITCODE" }
    $remoteScript = "$remote/controller_setup_management_browser_preview_server.sh"
    $remoteCommand = "bash -n '$remoteScript' && timeout --foreground --signal=TERM 28800s bash '$remoteScript' '$PreviewPort' '$PreviewEmail' '$TargetRef' '$CandidateSha'"
    & ssh -tt -o ServerAliveInterval=30 -o ServerAliveCountMax=4 -L "${PreviewPort}:127.0.0.1:${PreviewPort}" $Server $remoteCommand
    if ($LASTEXITCODE -ne 0) { throw "STOP: remote preview failed ($LASTEXITCODE). Inspect retained Controller preview report and resources before retry." }
    Write-Host 'CONTROLLER DISPOSABLE BROWSER PREVIEW: CLEAN EXIT'
}
finally {
    if (Test-Path -LiteralPath $bundle) { Remove-Item -LiteralPath $bundle -Recurse -Force }
}
