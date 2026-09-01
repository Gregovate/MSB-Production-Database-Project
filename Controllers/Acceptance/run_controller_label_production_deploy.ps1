param(
    [string]$Server = 'msbadmin@192.168.5.9'
)

$ErrorActionPreference = 'Stop'

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$RepoRoot = (Resolve-Path (Join-Path $ScriptDir '..\..')).Path
$Sql021 = Join-Path $RepoRoot 'Controllers\Database\021_create_controller_browser_authorization_contract.sql'
$Sql022 = Join-Path $RepoRoot 'Controllers\Database\022_create_controller_label_request_command.sql'
$ServerScript = Join-Path $ScriptDir 'controller_label_production_deploy_server.sh'

foreach ($path in @($Sql021, $Sql022, $ServerScript)) {
    if (-not (Test-Path -LiteralPath $path)) {
        throw "Required deployment file is missing: $path"
    }
}

$stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$bundleName = "msb-controller-label-production-$stamp"
$localBundle = Join-Path ([System.IO.Path]::GetTempPath()) $bundleName
$remoteRoot = "/tmp/$bundleName"

Write-Host '========== CONTROLLER LABEL PRODUCTION DEPLOYMENT =========='
Write-Host "Server:      $Server"
Write-Host "Remote root: $remoteRoot"
Write-Host 'Approved target: e9ab029a17067b38b34f9306069f54899925f73f'
Write-Host 'Expected live rollback checkout: 84d6f06e16c43ebb0f6aa21273b999af7f6d455b'
Write-Host 'The server gate creates and validates a rollback pg_dump before database/app mutation.'
Write-Host 'Transfer/execution uses one SCP session plus one SSH session.'
Write-Host

try {
    New-Item -ItemType Directory -Path $localBundle -Force | Out-Null

    Copy-Item -LiteralPath $Sql021 -Destination (Join-Path $localBundle '021_create_controller_browser_authorization_contract.sql')
    Copy-Item -LiteralPath $Sql022 -Destination (Join-Path $localBundle '022_create_controller_label_request_command.sql')

    $serverText = [System.IO.File]::ReadAllText($ServerScript)
    $serverText = $serverText.Replace("`r`n", "`n").Replace("`r", "`n")
    $utf8NoBom = New-Object System.Text.UTF8Encoding($false)
    [System.IO.File]::WriteAllText(
        (Join-Path $localBundle 'controller_label_production_deploy_server.sh'),
        $serverText,
        $utf8NoBom
    )

    # Native SCP/SSH own the console directly so SSH and sudo prompts remain visible.
    & scp -r $localBundle "${Server}:/tmp/"
    if ($LASTEXITCODE -ne 0) {
        throw "SCP production deployment bundle upload failed with exit code $LASTEXITCODE"
    }

    Write-Host
    Write-Host 'Starting bounded production deployment (20 minute maximum)...'
    & ssh -tt $Server "chmod 700 '$remoteRoot/controller_label_production_deploy_server.sh'; timeout --signal=TERM 1200s bash '$remoteRoot/controller_label_production_deploy_server.sh'"
    $remoteExit = $LASTEXITCODE

    if ($remoteExit -ne 0) {
        throw "Controller label production deployment failed with exit code $remoteExit. Review the remote /tmp/MSB_Controller_Label_Production_Deploy_*.txt report named in the output."
    }

    Write-Host
    Write-Host 'CONTROLLER LABEL PRODUCTION DEPLOYMENT WRAPPER: PASS'
}
finally {
    if (Test-Path -LiteralPath $localBundle) {
        Remove-Item -LiteralPath $localBundle -Recurse -Force -ErrorAction SilentlyContinue
    }
}
