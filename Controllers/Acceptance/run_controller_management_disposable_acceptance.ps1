param(
    [string]$Server = 'msbadmin@192.168.5.9'
)

$ErrorActionPreference = 'Stop'

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$RepoRoot = (Resolve-Path (Join-Path $ScriptDir '..\..')).Path
$Sql023 = Join-Path $RepoRoot 'Controllers\Database\023_create_controller_management_commands.sql'
$ServerScript = Join-Path $ScriptDir 'controller_management_disposable_server.sh'

foreach ($path in @($Sql023, $ServerScript)) {
    if (-not (Test-Path -LiteralPath $path)) {
        throw "Required acceptance file is missing: $path"
    }
}

$stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$bundleName = "msb-controller-management-acceptance-$stamp"
$localBundle = Join-Path ([System.IO.Path]::GetTempPath()) $bundleName
$remoteRoot = "/tmp/$bundleName"

Write-Host '========== CONTROLLER MANAGEMENT DISPOSABLE ACCEPTANCE =========='
Write-Host "Server:      $Server"
Write-Host "Remote root: $remoteRoot"
Write-Host 'Production access in the remote runner is pg_dump + SELECT only.'
Write-Host 'All candidate mutations occur in a separate disposable PostgreSQL container.'
Write-Host 'Transfer/execution uses one SCP session plus one foreground SSH session.'
Write-Host

try {
    New-Item -ItemType Directory -Path $localBundle -Force | Out-Null
    Copy-Item -LiteralPath $Sql023 -Destination (Join-Path $localBundle '023_create_controller_management_commands.sql')

    # Normalize CRLF to LF and write UTF-8 without BOM before Linux bash sees it.
    $serverText = [System.IO.File]::ReadAllText($ServerScript)
    $serverText = $serverText.Replace("`r`n", "`n").Replace("`r", "`n")
    $utf8NoBom = New-Object System.Text.UTF8Encoding($false)
    [System.IO.File]::WriteAllText(
        (Join-Path $localBundle 'controller_management_disposable_server.sh'),
        $serverText,
        $utf8NoBom
    )

    # Native SCP/SSH own the console directly so SSH/sudo prompts stay usable.
    & scp -r $localBundle "${Server}:/tmp/"
    if ($LASTEXITCODE -ne 0) {
        throw "SCP acceptance bundle upload failed with exit code $LASTEXITCODE"
    }

    Write-Host
    Write-Host 'Starting bounded server-side disposable acceptance (20 minute maximum)...'
    & ssh -tt $Server "chmod 700 '$remoteRoot/controller_management_disposable_server.sh'; timeout --signal=TERM 1200s bash '$remoteRoot/controller_management_disposable_server.sh'"
    $remoteExit = $LASTEXITCODE

    if ($remoteExit -ne 0) {
        throw "Controller management disposable acceptance failed with exit code $remoteExit. Review the remote /tmp/MSB_Controller_Management_Disposable_*.txt report named in the output."
    }

    Write-Host
    Write-Host 'CONTROLLER MANAGEMENT DISPOSABLE WRAPPER: PASS'
}
finally {
    if (Test-Path -LiteralPath $localBundle) {
        Remove-Item -LiteralPath $localBundle -Recurse -Force -ErrorAction SilentlyContinue
    }
}
