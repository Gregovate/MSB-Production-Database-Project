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

    # Keep the established child runner intact. A new PostgreSQL image can briefly
    # satisfy its original pg_isready loop while the Docker entrypoint is still
    # using the temporary initialization server. Insert a second proven gate just
    # before createdb: wait for the init-complete marker, then verify the final
    # PostgreSQL server is accepting connections. Nothing is deleted/rebalanced.
    $createDbCommand = @'
sudo docker exec -e PGPASSWORD="$TEST_PASSWORD" "$TEST_CONTAINER" \
    createdb -U "$DB_ACTOR" -T template0 "$TEST_DB"
'@
    $createDbCommand = $createDbCommand.Replace('\"', '"')

    $createDbIndex = $text.IndexOf($createDbCommand, [System.StringComparison]::Ordinal)
    if ($createDbIndex -lt 0) {
        throw 'Disposable management runner createdb command was not found.'
    }
    if ($text.IndexOf($createDbCommand, $createDbIndex + 1, [System.StringComparison]::Ordinal) -ge 0) {
        throw 'Disposable management runner createdb command is not unique.'
    }

    $finalReadyGate = @'
# The Docker entrypoint uses a temporary initialization server before the final
# PostgreSQL process. Do not restore until initialization is complete and the
# final server is accepting connections.
init_complete=0
for _ in $(seq 1 120); do
    if sudo docker logs "$TEST_CONTAINER" 2>&1 | grep -q "PostgreSQL init process complete; ready for start up"; then
        init_complete=1
        break
    fi
    sleep 1
done
if [[ "$init_complete" -ne 1 ]]; then
    echo "FAIL: disposable PostgreSQL initialization did not complete"
    sudo docker logs "$TEST_CONTAINER" || true
    exit 6
fi

final_ready=0
for _ in $(seq 1 60); do
    if sudo docker exec -e PGPASSWORD="$TEST_PASSWORD" "$TEST_CONTAINER" \
        pg_isready -U "$DB_ACTOR" -d postgres >/dev/null 2>&1; then
        final_ready=1
        break
    fi
    sleep 1
done
if [[ "$final_ready" -ne 1 ]]; then
    echo "FAIL: disposable PostgreSQL final server did not become ready"
    sudo docker logs "$TEST_CONTAINER" || true
    exit 6
fi

'@
    $finalReadyGate = $finalReadyGate.Replace('\"', '"')

    $text = $text.Substring(0, $createDbIndex) + $finalReadyGate + $text.Substring($createDbIndex)

    # Fail locally before SCP if the transformation did not produce the reviewed
    # structural evidence. Bash syntax is also checked when a local bash exists.
    foreach ($required in @(
        'PostgreSQL init process complete; ready for start up',
        'final_ready=0',
        'createdb -U "$DB_ACTOR" -T template0 "$TEST_DB"',
        'pg_restore -U "$DB_ACTOR" -d "$TEST_DB"'
    )) {
        if (-not $text.Contains($required)) {
            throw "Generated disposable management runner is missing required evidence: $required"
        }
    }

    [System.IO.File]::WriteAllText($Destination, $text, $utf8NoBom)

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

    # Native SCP/SSH intentionally own the console directly. Do not pipe,
    # redirect, Tee-Object, or background these calls; password/sudo prompts
    # must remain interactive and visible.
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
