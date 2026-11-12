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
$bundleName = "msb-setup-training-disposable-$stamp"
$localBundle = Join-Path $env:TEMP $bundleName
$remoteBundle = "/tmp/$bundleName"

$files = @(
    'Setup\Database\019_add_reconstruction_safe_task_delete.sql',
    'Setup\Database\020_add_setup_captain_management_commands.sql',
    'Setup\Database\021_add_setup_assigned_reconciliation_state.sql',
    'Setup\Database\022_require_active_setup_captain_people.sql',
    'Setup\Acceptance\setup_training_disposable_validation.sql',
    'Setup\Acceptance\setup_training_disposable_acceptance_server.sh'
)

try {
    New-Item -ItemType Directory -Path $localBundle -Force | Out-Null

    foreach ($relative in $files) {
        $source = Join-Path $repo $relative
        if (-not (Test-Path -LiteralPath $source -PathType Leaf)) {
            throw "Required acceptance file is missing: $source"
        }
        Copy-Item -LiteralPath $source -Destination $localBundle
    }

    $runner = Join-Path $localBundle 'setup_training_disposable_acceptance_server.sh'
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
    Write-Host 'Disposable database: all test writes occur only in the temporary PostgreSQL container'
    Write-Host ''

    & scp -r $localBundle "${Server}:/tmp/"
    if ($LASTEXITCODE -ne 0) {
        throw "SCP failed with exit code $LASTEXITCODE"
    }

    & ssh -tt $Server "bash '$remoteBundle/setup_training_disposable_acceptance_server.sh' '$remoteBundle' '$CandidateSha'"
    if ($LASTEXITCODE -ne 0) {
        throw "Disposable acceptance failed with exit code $LASTEXITCODE"
    }
}
finally {
    Remove-Item -LiteralPath $localBundle -Recurse -Force -ErrorAction SilentlyContinue
}
