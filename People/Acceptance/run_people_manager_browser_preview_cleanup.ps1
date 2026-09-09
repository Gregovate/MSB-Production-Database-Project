param(
    [string]$Server = 'msbadmin@192.168.5.9',
    [int]$PreviewPort = 8794
)

$ErrorActionPreference = 'Stop'

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$ServerScript = Join-Path $ScriptDir 'people_manager_browser_preview_cleanup_server.sh'
$stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$bundleName = "msb-people-preview-cleanup-$stamp"
$localBundle = Join-Path ([System.IO.Path]::GetTempPath()) $bundleName
$remoteRoot = "/tmp/$bundleName"
$utf8NoBom = New-Object System.Text.UTF8Encoding($false)

if (-not (Test-Path -LiteralPath $ServerScript)) {
    throw "Required cleanup runner is missing: $ServerScript"
}

if ($PreviewPort -lt 1024 -or $PreviewPort -gt 65535) {
    throw 'PreviewPort must be between 1024 and 65535.'
}

# If Ctrl+C left the local SSH tunnel listening, stop only the owning ssh.exe
# process. Refuse to terminate any unrelated local listener.
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

Write-Host 'Authority: MSB-Server-Management — Pre_Production_Browser_Review_Runbook.md cleanup/teardown pattern'

try {
    New-Item -ItemType Directory -Path $localBundle -Force | Out-Null
    $text = [System.IO.File]::ReadAllText($ServerScript)
    $text = $text.Replace("`r`n", "`n").Replace("`r", "`n")
    $localServer = Join-Path $localBundle 'people_manager_browser_preview_cleanup_server.sh'
    [System.IO.File]::WriteAllText($localServer, $text, $utf8NoBom)

    & scp -r $localBundle "${Server}:/tmp/"
    if ($LASTEXITCODE -ne 0) {
        throw "SCP People preview cleanup upload failed with exit code $LASTEXITCODE"
    }

    $remoteScript = "$remoteRoot/people_manager_browser_preview_cleanup_server.sh"
    & ssh -tt $Server "chmod 700 '$remoteScript' && bash -n '$remoteScript' && bash '$remoteScript' '$PreviewPort'; rm -rf '$remoteRoot'"
    if ($LASTEXITCODE -ne 0) {
        throw "People Manager browser preview stale cleanup failed with exit code $LASTEXITCODE"
    }

    Write-Host
    Write-Host 'PEOPLE MANAGER BROWSER PREVIEW STALE CLEANUP: PASS'
}
finally {
    if (Test-Path -LiteralPath $localBundle) {
        Remove-Item -LiteralPath $localBundle -Recurse -Force -ErrorAction SilentlyContinue
    }
}
