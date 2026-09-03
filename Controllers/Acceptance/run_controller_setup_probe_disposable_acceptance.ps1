param(
    [string]$Server = 'msbadmin@192.168.5.9'
)

$ErrorActionPreference = 'Stop'

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$RepoRoot = (Resolve-Path (Join-Path $ScriptDir '..\..')).Path
$Sql023 = Join-Path $RepoRoot 'Controllers\Database\023_create_controller_management_commands.sql'
$Sql024 = Join-Path $RepoRoot 'Controllers\Database\024_harden_controller_assignment_capability.sql'
$ChildServer = Join-Path $ScriptDir 'controller_management_disposable_server.sh'
$ParentServer = Join-Path $ScriptDir 'controller_setup_probe_disposable_server.sh'
$CandidateSha = '49ae25d8a1acb8116f3d0a100d22af9a9d57ad18'

foreach ($path in @($Sql023, $Sql024, $ChildServer, $ParentServer)) {
    if (-not (Test-Path -LiteralPath $path)) {
        throw "Required acceptance file is missing: $path"
    }
}

$stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$bundleName = "msb-controller-setup-probe-acceptance-$stamp"
$localBundle = Join-Path ([System.IO.Path]::GetTempPath()) $bundleName
$localCore = Join-Path $localBundle 'management-core'
$remoteRoot = "/tmp/$bundleName"
$utf8NoBom = New-Object System.Text.UTF8Encoding($false)

function Write-LinuxTextFile {
    param(
        [Parameter(Mandatory=$true)][string]$Source,
        [Parameter(Mandatory=$true)][string]$Destination
    )
    $text = [System.IO.File]::ReadAllText($Source)
    $text = $text.Replace("`r`n", "`n").Replace("`r", "`n")
    [System.IO.File]::WriteAllText($Destination, $text, $utf8NoBom)
}

Write-Host '========== CONTROLLER SETUP PROBE + MANAGEMENT ACCEPTANCE =========='
Write-Host "Server:        $Server"
Write-Host "Candidate SHA: $CandidateSha"
Write-Host "Remote root:   $remoteRoot"
Write-Host 'Production access for the probe is SELECT/pg_dump only.'
Write-Host 'All Controller create/edit/assignment mutations occur in the disposable PostgreSQL clone.'
Write-Host 'Transfer/execution uses one SCP session plus one foreground SSH session.'
Write-Host

try {
    New-Item -ItemType Directory -Path $localCore -Force | Out-Null

    Write-LinuxTextFile -Source $ParentServer -Destination (Join-Path $localBundle 'controller_setup_probe_disposable_server.sh')
    Write-LinuxTextFile -Source $ChildServer -Destination (Join-Path $localCore 'controller_management_disposable_server.sh')

    # The established child acceptance runner expects one migration filename.
    # Build that disposable-only input by applying reviewed 023 followed by 024.
    $sql023Text = [System.IO.File]::ReadAllText($Sql023).Replace("`r`n", "`n").Replace("`r", "`n")
    $sql024Text = [System.IO.File]::ReadAllText($Sql024).Replace("`r`n", "`n").Replace("`r", "`n")
    $combinedSql = $sql023Text.TrimEnd() + "`n`n-- ============================================================`n-- Follow-on assignment-capability hardening (024)`n-- ============================================================`n`n" + $sql024Text.TrimStart()
    [System.IO.File]::WriteAllText(
        (Join-Path $localCore '023_create_controller_management_commands.sql'),
        $combinedSql,
        $utf8NoBom
    )

    # Native SCP/SSH intentionally own the console directly. Do not pipe,
    # redirect, Tee-Object, or background these calls; password/sudo prompts
    # must remain interactive and visible.
    & scp -r $localBundle "${Server}:/tmp/"
    if ($LASTEXITCODE -ne 0) {
        throw "SCP acceptance bundle upload failed with exit code $LASTEXITCODE"
    }

    Write-Host
    Write-Host 'Starting bounded Controller setup probe / disposable acceptance...'
    & ssh -tt $Server "chmod 700 '$remoteRoot/controller_setup_probe_disposable_server.sh'; timeout --signal=TERM 1800s bash '$remoteRoot/controller_setup_probe_disposable_server.sh'"
    $remoteExit = $LASTEXITCODE

    if ($remoteExit -ne 0) {
        throw "Controller setup probe / disposable acceptance failed with exit code $remoteExit. Review the remote /tmp/MSB_Controller_Setup_Probe_Disposable_*.txt report named in the output."
    }

    Write-Host
    Write-Host 'CONTROLLER SETUP PROBE + MANAGEMENT WRAPPER: PASS'
}
finally {
    if (Test-Path -LiteralPath $localBundle) {
        Remove-Item -LiteralPath $localBundle -Recurse -Force -ErrorAction SilentlyContinue
    }
}
