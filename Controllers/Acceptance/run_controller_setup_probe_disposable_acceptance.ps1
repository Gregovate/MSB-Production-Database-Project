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

function Write-PatchedManagementServer {
    param(
        [Parameter(Mandatory=$true)][string]$Source,
        [Parameter(Mandatory=$true)][string]$Destination
    )

    $text = [System.IO.File]::ReadAllText($Source)
    $text = $text.Replace("`r`n", "`n").Replace("`r", "`n")

    # A brand-new postgres image briefly accepts pg_isready connections on its
    # temporary initialization server, then intentionally stops that server
    # before starting the final PostgreSQL process. Waiting only on pg_isready
    # can therefore terminate pg_restore mid-stream with "administrator command".
    # Reuse the proven Controller label harness sequence: wait for the Docker
    # entrypoint init-complete marker first, then wait for the final server.
    $oldReady = @'
ready=0
for _ in $(seq 1 120); do
    if sudo docker exec -e PGPASSWORD="$TEST_PASSWORD" "$TEST_CONTAINER" \
        pg_isready -U "$DB_ACTOR" -d postgres >/dev/null 2>&1; then
        ready=1
        break
    fi
    sleep 1
done
if [[ "$ready" -ne 1 ]]; then
    echo "FAIL: disposable PostgreSQL initialization did not become ready"
    sudo docker logs "$TEST_CONTAINER" || true
    exit 6
fi
'@

    $newReady = @'
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

ready=0
for _ in $(seq 1 60); do
    if sudo docker exec -e PGPASSWORD="$TEST_PASSWORD" "$TEST_CONTAINER" \
        pg_isready -U "$DB_ACTOR" -d postgres >/dev/null 2>&1; then
        ready=1
        break
    fi
    sleep 1
done
if [[ "$ready" -ne 1 ]]; then
    echo "FAIL: disposable PostgreSQL final server did not become ready"
    sudo docker logs "$TEST_CONTAINER" || true
    exit 6
fi
'@

    if (-not $text.Contains($oldReady)) {
        throw 'Disposable management runner startup block no longer matches the reviewed patch boundary.'
    }
    $text = $text.Replace($oldReady, $newReady)

    $oldCleanup = @'
    echo
    echo "--- Cleanup ---"
    sudo docker rm -f "$TEST_CONTAINER" >/dev/null 2>&1 || true
'@
    $newCleanup = @'
    if [[ "$status" -ne 0 ]] && sudo docker inspect "$TEST_CONTAINER" >/dev/null 2>&1; then
        echo
        echo "--- Disposable PostgreSQL logs (failure evidence) ---"
        sudo docker logs "$TEST_CONTAINER" || true
    fi

    echo
    echo "--- Cleanup ---"
    sudo docker rm -f "$TEST_CONTAINER" >/dev/null 2>&1 || true
'@
    if (-not $text.Contains($oldCleanup)) {
        throw 'Disposable management runner cleanup block no longer matches the reviewed patch boundary.'
    }
    $text = $text.Replace($oldCleanup, $newCleanup)

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
    Write-PatchedManagementServer -Source $ChildServer -Destination (Join-Path $localCore 'controller_management_disposable_server.sh')

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
