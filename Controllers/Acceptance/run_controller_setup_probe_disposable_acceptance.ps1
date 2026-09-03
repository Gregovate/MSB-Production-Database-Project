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
$CandidateSha = '2fd2067958cc0a903260fe6f089f88ae63a857f1'

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

function Write-StabilizedManagementServer {
    param(
        [Parameter(Mandatory=$true)][string]$Source,
        [Parameter(Mandatory=$true)][string]$Destination
    )

    $text = [System.IO.File]::ReadAllText($Source)
    $text = $text.Replace("`r`n", "`n").Replace("`r", "`n")
    $lines = $text -split "`n", -1

    # Do not rewrite any existing Bash block. Find the unique createdb line and
    # insert one additional readiness gate immediately before its docker exec.
    $needle = 'createdb -U "$DB_ACTOR" -T template0 "$TEST_DB"'
    $matches = @()
    for ($i = 0; $i -lt $lines.Length; $i++) {
        if ($lines[$i].Contains($needle)) {
            $matches += $i
        }
    }
    if ($matches.Count -ne 1) {
        throw "Expected exactly one disposable createdb line; found $($matches.Count)."
    }

    $createdbLine = [int]$matches[0]
    if ($createdbLine -lt 1) {
        throw 'Disposable createdb line has no preceding docker-exec line.'
    }
    $insertAt = $createdbLine - 1
    if (-not $lines[$insertAt].Contains('sudo docker exec')) {
        throw 'Disposable createdb command is not preceded by the expected docker-exec line.'
    }

    $gate = @(
        '# Final PostgreSQL startup gate: the image briefly accepts connections on a temporary init server.',
        'init_complete=0',
        'for _ in $(seq 1 120); do',
        '    if sudo docker logs "$TEST_CONTAINER" 2>&1 | grep -q "PostgreSQL init process complete; ready for start up"; then',
        '        init_complete=1',
        '        break',
        '    fi',
        '    sleep 1',
        'done',
        'if [[ "$init_complete" -ne 1 ]]; then',
        '    echo "FAIL: disposable PostgreSQL initialization did not complete"',
        '    sudo docker logs "$TEST_CONTAINER" || true',
        '    exit 6',
        'fi',
        '',
        'final_ready=0',
        'for _ in $(seq 1 60); do',
        '    if sudo docker exec -e PGPASSWORD="$TEST_PASSWORD" "$TEST_CONTAINER" \',
        '        pg_isready -U "$DB_ACTOR" -d postgres >/dev/null 2>&1; then',
        '        final_ready=1',
        '        break',
        '    fi',
        '    sleep 1',
        'done',
        'if [[ "$final_ready" -ne 1 ]]; then',
        '    echo "FAIL: disposable PostgreSQL final server did not become ready"',
        '    sudo docker logs "$TEST_CONTAINER" || true',
        '    exit 6',
        'fi',
        ''
    )

    $before = @()
    if ($insertAt -gt 0) {
        $before = @($lines[0..($insertAt - 1)])
    }
    $after = @($lines[$insertAt..($lines.Length - 1)])
    $outputLines = @($before) + @($gate) + @($after)
    $output = [string]::Join("`n", $outputLines)

    foreach ($required in @(
        'PostgreSQL init process complete; ready for start up',
        'final_ready=0',
        'createdb -U "$DB_ACTOR" -T template0 "$TEST_DB"',
        'pg_restore -U "$DB_ACTOR" -d "$TEST_DB"'
    )) {
        if (-not $output.Contains($required)) {
            throw "Generated disposable management runner is missing required evidence: $required"
        }
    }

    [System.IO.File]::WriteAllText($Destination, $output, $utf8NoBom)

    $bash = Get-Command bash -ErrorAction SilentlyContinue
    if ($null -ne $bash) {
        & $bash.Source -n $Destination
        if ($LASTEXITCODE -ne 0) {
            throw "Generated disposable management runner failed local bash -n with exit code $LASTEXITCODE"
        }
        Write-Host 'Generated disposable management runner: bash -n PASS'
    } else {
        Write-Host 'Generated disposable management runner: local bash unavailable; server will syntax-check before execution.'
    }
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
    $generatedChild = Join-Path $localCore 'controller_management_disposable_server.sh'
    Write-StabilizedManagementServer -Source $ChildServer -Destination $generatedChild

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

    # Native SCP/SSH intentionally own the console directly so password and sudo
    # prompts remain interactive and visible.
    & scp -r $localBundle "${Server}:/tmp/"
    if ($LASTEXITCODE -ne 0) {
        throw "SCP acceptance bundle upload failed with exit code $LASTEXITCODE"
    }

    Write-Host
    Write-Host 'Starting bounded Controller setup probe / disposable acceptance...'
    & ssh -tt $Server "bash -n '$remoteRoot/controller_setup_probe_disposable_server.sh' && bash -n '$remoteRoot/management-core/controller_management_disposable_server.sh' && chmod 700 '$remoteRoot/controller_setup_probe_disposable_server.sh'; timeout --signal=TERM 1800s bash '$remoteRoot/controller_setup_probe_disposable_server.sh'"
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
