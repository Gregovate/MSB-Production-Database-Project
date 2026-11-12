param(
    [string]$Server = 'msbadmin@192.168.5.9'
)

$ErrorActionPreference = 'Stop'

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$RepoRoot = (Resolve-Path (Join-Path $ScriptDir '..\..')).Path
$Sql001 = Join-Path $RepoRoot 'People\Database\001_create_people_manager_contract.sql'
$Sql002 = Join-Path $RepoRoot 'People\Database\002_harden_people_search_phone_filter.sql'
$Sql003 = Join-Path $RepoRoot 'People\Database\003_create_people_metadata_contract.sql'
$ServerScript = Join-Path $ScriptDir 'people_manager_disposable_server.sh'

foreach ($path in @($Sql001, $Sql002, $Sql003, $ServerScript)) {
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
Write-Host 'Authority: MSB-Server-Management — PostgreSQL_Disposable_Acceptance_Standard.md'
Write-Host 'Production access in the remote runner is pg_dump + SELECT only.'
Write-Host 'All candidate mutations occur in a separate disposable PostgreSQL container.'
Write-Host 'Candidate migrations: People 001 + 002 + 003.'
Write-Host 'Transfer/execution uses one SCP session plus one foreground SSH session.'
Write-Host

try {
    New-Item -ItemType Directory -Path $localBundle -Force | Out-Null
    Copy-Item -LiteralPath $Sql001 -Destination (Join-Path $localBundle '001_create_people_manager_contract.sql')
    Copy-Item -LiteralPath $Sql002 -Destination (Join-Path $localBundle '002_harden_people_search_phone_filter.sql')
    Copy-Item -LiteralPath $Sql003 -Destination (Join-Path $localBundle '003_create_people_metadata_contract.sql')

    # Server Management requires Linux shell files to be normalized before SCP.
    # The version-controlled server runner is the reviewed source; this wrapper
    # does not rewrite server logic at runtime.
    $serverText = [System.IO.File]::ReadAllText($ServerScript)
    $serverText = $serverText.Replace("`r`n", "`n").Replace("`r", "`n")
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
