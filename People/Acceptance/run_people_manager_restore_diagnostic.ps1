param(
    [string]$Server = 'msbadmin@192.168.5.9'
)

$ErrorActionPreference = 'Stop'

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$ServerScript = Join-Path $ScriptDir 'people_manager_restore_diagnostic_server.sh'

if (-not (Test-Path -LiteralPath $ServerScript)) {
    throw "Required diagnostic file is missing: $ServerScript"
}

$stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$bundleName = "msb-people-restore-diagnostic-$stamp"
$localBundle = Join-Path ([System.IO.Path]::GetTempPath()) $bundleName
$remoteRoot = "/tmp/$bundleName"

Write-Host '========== PEOPLE MANAGER RESTORE DIAGNOSTIC =========='
Write-Host "Server:      $Server"
Write-Host "Remote root: $remoteRoot"
Write-Host 'Production access is pg_dump + SELECT only.'
Write-Host 'The diagnostic captures disposable PostgreSQL logs/inspect state before cleanup.'
Write-Host

try {
    New-Item -ItemType Directory -Path $localBundle -Force | Out-Null

    $serverText = [System.IO.File]::ReadAllText($ServerScript)
    $serverText = $serverText.Replace("`r`n", "`n").Replace("`r", "`n")
    $utf8NoBom = New-Object System.Text.UTF8Encoding($false)
    [System.IO.File]::WriteAllText(
        (Join-Path $localBundle 'people_manager_restore_diagnostic_server.sh'),
        $serverText,
        $utf8NoBom
    )

    & scp -r $localBundle "${Server}:/tmp/"
    if ($LASTEXITCODE -ne 0) {
        throw "SCP diagnostic bundle upload failed with exit code $LASTEXITCODE"
    }

    & ssh -tt $Server "chmod 700 '$remoteRoot/people_manager_restore_diagnostic_server.sh'; timeout --signal=TERM 1200s bash '$remoteRoot/people_manager_restore_diagnostic_server.sh'"
    $remoteExit = $LASTEXITCODE

    if ($remoteExit -ne 0) {
        throw "People Manager restore diagnostic failed with exit code $remoteExit. Paste the complete diagnostic output here."
    }

    Write-Host
    Write-Host 'PEOPLE MANAGER RESTORE DIAGNOSTIC WRAPPER: PASS'
}
finally {
    if (Test-Path -LiteralPath $localBundle) {
        Remove-Item -LiteralPath $localBundle -Recurse -Force -ErrorAction SilentlyContinue
    }
}
