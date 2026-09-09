param(
    [string]$Server = 'msbadmin@192.168.5.9'
)

$ErrorActionPreference = 'Stop'

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$RepoRoot = (Resolve-Path (Join-Path $ScriptDir '..\..')).Path
$Sql001 = Join-Path $RepoRoot 'People\Database\001_create_people_manager_contract.sql'
$Sql002 = Join-Path $RepoRoot 'People\Database\002_harden_people_search_phone_filter.sql'
$ServerScript = Join-Path $ScriptDir 'people_manager_disposable_server.sh'

foreach ($path in @($Sql001, $Sql002, $ServerScript)) {
    if (-not (Test-Path -LiteralPath $path)) {
        throw "Required acceptance file is missing: $path"
    }
}

$stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$bundleName = "msb-people-manager-acceptance-$stamp"
$localBundle = Join-Path ([System.IO.Path]::GetTempPath()) $bundleName
$remoteRoot = "/tmp/$bundleName"

Write-Host '========== PEOPLE MANAGER DISPOSABLE ACCEPTANCE =========='
Write-Host "Server:      $Server"
Write-Host "Remote root: $remoteRoot"
Write-Host 'Production access in the remote runner is pg_dump + SELECT only.'
Write-Host 'All candidate mutations occur in a separate disposable PostgreSQL container.'
Write-Host 'Transfer/execution uses one SCP session plus one foreground SSH session.'
Write-Host

try {
    New-Item -ItemType Directory -Path $localBundle -Force | Out-Null
    Copy-Item -LiteralPath $Sql001 -Destination (Join-Path $localBundle '001_create_people_manager_contract.sql')
    Copy-Item -LiteralPath $Sql002 -Destination (Join-Path $localBundle '002_harden_people_search_phone_filter.sql')

    # Normalize CRLF to LF and write UTF-8 without BOM before Linux bash sees it.
    $serverText = [System.IO.File]::ReadAllText($ServerScript)
    $serverText = $serverText.Replace("`r`n", "`n").Replace("`r", "`n")

    # The postgis image starts a temporary PostgreSQL server while its init scripts
    # load PostGIS, then fast-shuts that server down and execs the final PostgreSQL
    # server as PID 1. pg_isready can succeed during the temporary phase. Replace
    # the historical readiness block in the uploaded disposable runner so restore
    # starts only after the final server is PID 1 and ready.
    $oldReadiness = @'
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

sudo docker exec -e PGPASSWORD="$TEST_PASSWORD" "$TEST_CONTAINER" \
    createdb -U "$DB_ACTOR" -T template0 "$TEST_DB"
echo "Disposable PostgreSQL is ready"
'@
    $oldReadiness = $oldReadiness.Replace("`r`n", "`n").Replace("`r", "`n")

    $newReadiness = @'
ready=0
pid1=""
for _ in $(seq 1 120); do
    if [[ "$(sudo docker inspect "$TEST_CONTAINER" --format '{{.State.Running}}' 2>/dev/null || true)" != "true" ]]; then
        break
    fi
    pid1="$(sudo docker exec "$TEST_CONTAINER" sh -c 'cat /proc/1/comm' 2>/dev/null | tr -d '\r\n' || true)"
    if [[ "$pid1" == "postgres" ]] && \
       sudo docker exec -e PGPASSWORD="$TEST_PASSWORD" "$TEST_CONTAINER" \
           pg_isready -U "$DB_ACTOR" -d postgres >/dev/null 2>&1; then
        ready=1
        break
    fi
    sleep 1
done
if [[ "$ready" -ne 1 ]]; then
    echo "FAIL: disposable PostgreSQL did not reach final post-init ready state"
    echo "Observed PID 1 command: ${pid1:-unknown}"
    sudo docker logs "$TEST_CONTAINER" || true
    exit 6
fi

sudo docker exec -e PGPASSWORD="$TEST_PASSWORD" "$TEST_CONTAINER" \
    createdb -U "$DB_ACTOR" -T template0 "$TEST_DB"
echo "Disposable PostgreSQL final server ready"
'@
    $newReadiness = $newReadiness.Replace("`r`n", "`n").Replace("`r", "`n")

    if (-not $serverText.Contains($oldReadiness)) {
        throw 'Disposable server readiness block did not match the expected reviewed source; refusing to upload an unpatched runner.'
    }
    $serverText = $serverText.Replace($oldReadiness, $newReadiness)

    $utf8NoBom = New-Object System.Text.UTF8Encoding($false)
    [System.IO.File]::WriteAllText(
        (Join-Path $localBundle 'people_manager_disposable_server.sh'),
        $serverText,
        $utf8NoBom
    )

    & scp -r $localBundle "${Server}:/tmp/"
    if ($LASTEXITCODE -ne 0) {
        throw "SCP acceptance bundle upload failed with exit code $LASTEXITCODE"
    }

    Write-Host
    Write-Host 'Starting bounded server-side disposable acceptance (20 minute maximum)...'
    & ssh -tt $Server "chmod 700 '$remoteRoot/people_manager_disposable_server.sh'; timeout --signal=TERM 1200s bash '$remoteRoot/people_manager_disposable_server.sh'"
    $remoteExit = $LASTEXITCODE

    if ($remoteExit -ne 0) {
        throw "People Manager disposable acceptance failed with exit code $remoteExit. Review the remote /tmp/MSB_People_Manager_Disposable_*.txt report named in the output."
    }

    Write-Host
    Write-Host 'PEOPLE MANAGER DISPOSABLE WRAPPER: PASS'
}
finally {
    if (Test-Path -LiteralPath $localBundle) {
        Remove-Item -LiteralPath $localBundle -Recurse -Force -ErrorAction SilentlyContinue
    }
}
