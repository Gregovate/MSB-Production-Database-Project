param(
    [string]$Server = 'msbadmin@192.168.5.9',
    [Parameter(Mandatory=$true)]
    [string]$CandidateSha
)

$ErrorActionPreference = 'Stop'

$repo = (git rev-parse --show-toplevel).Trim()
if (-not $repo) {
    throw 'Run this wrapper from the MSB-Production-Database-Project checkout.'
}

$head = (git -C $repo rev-parse HEAD).Trim()
if ($head -ne $CandidateSha) {
    throw "STOP: checkout HEAD $head does not equal requested candidate $CandidateSha"
}

$status = git -C $repo status --porcelain
if ($status) {
    throw "STOP: checkout is not clean.`n$status"
}

Write-Host '--- Exact-candidate full Setup/Application regression ---'
& python -m pytest -q -p no:cacheprovider (Join-Path $repo 'Setup\Application')
if ($LASTEXITCODE -ne 0) {
    throw "Full Setup/Application regression failed with exit code $LASTEXITCODE"
}

$statusAfterRegression = git -C $repo status --porcelain
if ($statusAfterRegression) {
    throw "STOP: regression left the exact-candidate checkout dirty.`n$statusAfterRegression"
}

Write-Host 'PASS: full Setup/Application regression'
Write-Host 'PASS: exact-candidate checkout remains clean'
Write-Host

$stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$bundleName = "msb-setup-184-durable-kit-inventory-$stamp"
$localBundle = Join-Path $env:TEMP $bundleName
$remoteBundle = "/tmp/$bundleName"

$files = @(
    'Setup\Database\032_add_setup_extra_material_schema.sql',
    'Setup\Database\033_add_setup_extra_material_manager_commands.sql',
    'Setup\Database\034_add_setup_extra_material_container_commands.sql',
    'Setup\Database\035_add_setup_extra_material_inventory_commands.sql',
    'Setup\Database\036_seed_setup_extra_material_catalog.sql',
    'Setup\Database\037_harden_setup_extra_material_duplicate_rows.sql',
    'Setup\Acceptance\setup_extra_material_foundation_disposable_validation.sql',
    'Setup\Acceptance\setup_extra_material_foundation_disposable_acceptance_server.sh'
)

try {
    foreach ($relative in $files) {
        $source = Join-Path $repo $relative
        if (-not (Test-Path -LiteralPath $source -PathType Leaf)) {
            throw "Required acceptance file is missing: $source"
        }

        $destination = Join-Path $localBundle $relative
        $destinationDirectory = Split-Path -Parent $destination
        New-Item -ItemType Directory -Path $destinationDirectory -Force | Out-Null
        Copy-Item -LiteralPath $source -Destination $destination
    }

    $runner = Join-Path $localBundle 'Setup\Acceptance\setup_extra_material_foundation_disposable_acceptance_server.sh'
    $runnerText = [System.IO.File]::ReadAllText($runner).Replace("`r`n", "`n")
    [System.IO.File]::WriteAllText(
        $runner,
        $runnerText,
        [System.Text.UTF8Encoding]::new($false)
    )

    Write-Host "Candidate SHA: $CandidateSha"
    Write-Host "Local bundle:  $localBundle"
    Write-Host "Remote bundle: $remoteBundle"
    Write-Host 'Production database contract: pg_dump + SELECT only'
    Write-Host 'All #184 schema/catalog/inventory writes: disposable PostgreSQL clone only'
    Write-Host ''

    & scp -r $localBundle "${Server}:/tmp/"
    if ($LASTEXITCODE -ne 0) {
        throw "SCP failed with exit code $LASTEXITCODE"
    }

    $remoteRunner = "$remoteBundle/Setup/Acceptance/setup_extra_material_foundation_disposable_acceptance_server.sh"
    & ssh -tt $Server "bash '$remoteRunner' '$remoteBundle' '$CandidateSha'"
    if ($LASTEXITCODE -ne 0) {
        throw "Disposable #184 durable Kit Inventory acceptance failed with exit code $LASTEXITCODE"
    }
}
finally {
    Remove-Item -LiteralPath $localBundle -Recurse -Force -ErrorAction SilentlyContinue
}
