param (
    [string]$SQLitePath = "G:\Shared drives\MSB Database\database\lor_output_v7_scene.db",
    [Parameter(Mandatory = $true)]
    [ValidatePattern('^[0-9a-fA-F]{64}$')]
    [string]$ExpectedSQLiteSHA256,
    [string]$Notes = "V7 scene-aware LOR snapshot ingest"
)

# =============================================================================
# MSB Database - Postgres Snapshot Ingest Runner
# postgres_run_ingest_v7.ps1
#
# Initial Release : 2026-02-23  V0.1.0
# Version         : 2026-07-29  V0.3.0
# Current Version : 2026-08-13  V0.4.0
#
# Purpose:
#   Secure wrapper for the V7 scene-aware SQLite-to-Postgres snapshot ingest.
#
# Changes:
#   - Uses lor_output_v7_scene.db.
#   - Calls postgres_ingest_from_lor_sqlite_v7.py.
#   - Preserves the append-only lor_snap import_run model.
#   - Prompts securely for the Postgres password.
#
# Change Log:
#   2026-08-13  GAL / OpenAI  V0.4.0
#     Requires the SHA-256 recorded for the exact reviewed SQLite artifact.
#   2026-07-29  GAL  V0.3.0
#     Updated for V7 scene-aware snapshot ingestion.
#
#   2026-03-18  GAL  V0.2.0
#     Enforced V7 raw PropID ingestion and blocked obsolete V6 snapshots.
#
#   2026-02-23  GAL  V0.1.0
#     Initial release.
# =============================================================================

$pgHost = "192.168.5.9"
$pgDb = "msb"
$pgUser = "msbadmin"

Write-Host "MSB Postgres Snapshot Ingest"
Write-Host "SQLite: $SQLitePath"
Write-Host "Expected SHA-256: $ExpectedSQLiteSHA256"
Write-Host ""

# Safety check: only allow the approved V7 scene-aware database.
$expectedName = "lor_output_v7_scene.db"
$actualName = [System.IO.Path]::GetFileName($SQLitePath).ToLowerInvariant()

if ($actualName -ne $expectedName) {
    Write-Host ""
    Write-Host "FATAL: Wrong SQLite file selected." -ForegroundColor Red
    Write-Host "Expected: $expectedName"
    Write-Host "Actual:   $actualName"
    Write-Host "Aborting ingest."
    exit 1
}

if (-not (Test-Path -LiteralPath $SQLitePath -PathType Leaf)) {
    Write-Host ""
    Write-Host "FATAL: SQLite file not found." -ForegroundColor Red
    Write-Host "Path: $SQLitePath"
    exit 1
}

$pythonScript = Join-Path $PSScriptRoot "postgres_ingest_from_lor_sqlite_v7.py"

if (-not (Test-Path -LiteralPath $pythonScript -PathType Leaf)) {
    Write-Host ""
    Write-Host "FATAL: Python ingest script not found." -ForegroundColor Red
    Write-Host "Expected: $pythonScript"
    exit 1
}

$SecurePass = Read-Host "Enter Postgres password" -AsSecureString
$BSTR = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($SecurePass)

try {
    $PlainPassword = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($BSTR)
    $env:PGPASSWORD = $PlainPassword

    & python $pythonScript `
        --sqlite $SQLitePath `
        --expected-sqlite-sha256 ($ExpectedSQLiteSHA256.ToLowerInvariant()) `
        --pg-host $pgHost `
        --pg-db $pgDb `
        --pg-user $pgUser `
        --notes $Notes

    $exitCode = $LASTEXITCODE
}
finally {
    Remove-Item Env:\PGPASSWORD -ErrorAction SilentlyContinue

    if ($BSTR -ne [IntPtr]::Zero) {
        [System.Runtime.InteropServices.Marshal]::ZeroFreeBSTR($BSTR)
    }

    $PlainPassword = $null
    $SecurePass = $null
}

if ($exitCode -ne 0) {
    Write-Host ""
    Write-Host "Ingest failed with exit code $exitCode." -ForegroundColor Red
    exit $exitCode
}

Write-Host ""
Write-Host "Ingest runner completed successfully." -ForegroundColor Green
