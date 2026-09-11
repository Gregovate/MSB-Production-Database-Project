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

$stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$bundleName = "msb-setup-catalog-reconstruction-$stamp"
$localBundle = Join-Path $env:TEMP $bundleName
$remoteBundle = "/tmp/$bundleName"

$files = @(
    'Setup\Database\023_add_setup_task_effort.sql',
    'Setup\Database\024_reconstruct_setup_catalog_from_reviewed_one_list.sql',
    'Setup\Database\reconstruction\024_catalog_batch_01.sql',
    'Setup\Database\reconstruction\024_catalog_batch_02.sql',
    'Setup\Database\reconstruction\024_catalog_batch_03.sql',
    'Setup\Database\reconstruction\024_catalog_batch_04.sql',
    'Setup\Database\reconstruction\024_catalog_batch_05.sql',
    'Setup\Acceptance\setup_catalog_reconstruction_disposable_validation.sql',
    'Setup\Acceptance\setup_catalog_reconstruction_disposable_acceptance_server.sh'
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

    $runner = Join-Path $localBundle 'Setup\Acceptance\setup_catalog_reconstruction_disposable_acceptance_server.sh'
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
    Write-Host 'All catalog/schema writes: disposable PostgreSQL clone only'
    Write-Host ''

    & scp -r $localBundle "${Server}:/tmp/"
    if ($LASTEXITCODE -ne 0) {
        throw "SCP failed with exit code $LASTEXITCODE"
    }

    $remoteRunner = "$remoteBundle/Setup/Acceptance/setup_catalog_reconstruction_disposable_acceptance_server.sh"
    & ssh -tt $Server "bash '$remoteRunner' '$remoteBundle' '$CandidateSha'"
    if ($LASTEXITCODE -ne 0) {
        throw "Disposable catalog reconstruction acceptance failed with exit code $LASTEXITCODE"
    }
}
finally {
    Remove-Item -LiteralPath $localBundle -Recurse -Force -ErrorAction SilentlyContinue
}
