param(
    [string]$Server = 'msbadmin@192.168.5.9'
)

$ErrorActionPreference = 'Stop'

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$RepoRoot = (Resolve-Path (Join-Path $ScriptDir '..\..')).Path
$Sql021 = Join-Path $RepoRoot 'Controllers\Database\021_create_controller_browser_authorization_contract.sql'
$Sql022 = Join-Path $RepoRoot 'Controllers\Database\022_create_controller_label_request_command.sql'
$ServerScript = Join-Path $ScriptDir 'controller_label_disposable_server.sh'

foreach ($path in @($Sql021, $Sql022, $ServerScript)) {
    if (-not (Test-Path -LiteralPath $path)) {
        throw "Required acceptance file is missing: $path"
    }
}

$stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$remoteRoot = "/tmp/msb-controller-label-acceptance-$stamp"

Write-Host '========== CONTROLLER LABEL DISPOSABLE ACCEPTANCE =========='
Write-Host "Server:      $Server"
Write-Host "Remote root: $remoteRoot"
Write-Host 'Production access in the remote runner is pg_dump + SELECT only.'
Write-Host 'All candidate mutations occur in a separate disposable PostgreSQL container.'
Write-Host

# Interactive native ssh/scp calls intentionally own the console directly.
# Do not pipe or redirect these calls; SSH and sudo may require password input.
& ssh -tt $Server "umask 077; mkdir -p '$remoteRoot'"
if ($LASTEXITCODE -ne 0) {
    throw "Remote acceptance workdir creation failed with exit code $LASTEXITCODE"
}

$copies = @(
    @{ Local = $ServerScript; Remote = 'controller_label_disposable_server.sh' },
    @{ Local = $Sql021; Remote = '021_create_controller_browser_authorization_contract.sql' },
    @{ Local = $Sql022; Remote = '022_create_controller_label_request_command.sql' }
)

foreach ($copy in $copies) {
    $target = "${Server}:$remoteRoot/$($copy.Remote)"
    & scp $copy.Local $target
    if ($LASTEXITCODE -ne 0) {
        throw "SCP failed for $($copy.Local) with exit code $LASTEXITCODE"
    }
}

Write-Host
Write-Host 'Starting bounded server-side disposable acceptance (20 minute maximum)...'
& ssh -tt $Server "chmod 700 '$remoteRoot/controller_label_disposable_server.sh'; timeout --signal=TERM 1200s bash '$remoteRoot/controller_label_disposable_server.sh'"
$remoteExit = $LASTEXITCODE

if ($remoteExit -ne 0) {
    throw "Controller label disposable acceptance failed with exit code $remoteExit. Review the remote /tmp/MSB_Controller_Label_Disposable_*.txt report named in the output."
}

Write-Host
Write-Host 'CONTROLLER LABEL DISPOSABLE WRAPPER: PASS'
