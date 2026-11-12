# MSB PostgreSQL ingest launcher
#
# Purpose:
#   Run the current V7 PostgreSQL ingest runner from the repository root.
#
# This launcher intentionally contains no parser or ingest logic.

$ErrorActionPreference = 'Stop'

$RepoRoot = $PSScriptRoot
$IngestRunner = Join-Path $RepoRoot 'LOR2DB\01_Ingest\postgres_run_ingest_v7.ps1'

if (-not (Test-Path -LiteralPath $IngestRunner -PathType Leaf)) {
    Write-Error "Ingest runner not found: $IngestRunner"
    exit 2
}

Write-Host "[INFO] Ingest runner: $IngestRunner"

& $IngestRunner @args
$IngestExitCode = $LASTEXITCODE

if ($null -eq $IngestExitCode) {
    $IngestExitCode = 0
}

exit $IngestExitCode
