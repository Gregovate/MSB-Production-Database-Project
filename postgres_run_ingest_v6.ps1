# MSB Database — Postgres Snapshot Ingest Runner (V6 Recovery)
# postgres_run_ingest_v6_recovery.ps1
#
# Initial Release : 2026-03-18  V0.1.0
# Version         : 2026-03-18  V0.1.0
# Current Version : 2026-03-18  V0.1.0
#
# Changes:
# - Recovery runner for known-good v6 parser output
# - Hard-wired to lor_output_v6.db for emergency production recovery
# - Prevents accidental use of v7 during recovery work
#
# Author          : Greg Liebig, Engineering Innovations, LLC.
#
# Purpose
# -------
# Secure wrapper to ingest the known-good v6 SQLite snapshot into Postgres
# for emergency production recovery.
#
# Safety Rules
# ------------
# • Only lor_output_v6.db is permitted in this recovery runner.
# • Use only for production recovery / comparison work.
# • Do not use this runner for forward v7 migration testing.
#
param (
    [string]$SQLitePath = "G:\Shared drives\MSB Database\database\lor_output_v6.db",
    [string]$Notes = "LOR snapshot ingest v6 recovery"
)

$pgHost = "192.168.5.9"
$pgDb = "msb"
$pgUser = "msbadmin"

Write-Host "MSB Postgres Snapshot Ingest - V6 Recovery"
Write-Host "SQLite: $SQLitePath"
Write-Host ""

# ---- Safety check: only allow v6 recovery database ----
$expectedName = "lor_output_v6.db"
$actualName = [System.IO.Path]::GetFileName($SQLitePath).ToLower()

if ($actualName -ne $expectedName) {
    Write-Host ""
    Write-Host "FATAL: Wrong SQLite file selected." -ForegroundColor Red
    Write-Host "Expected: $expectedName"
    Write-Host "Actual:   $actualName"
    Write-Host "Aborting ingest."
    exit 1
}

$SecurePass = Read-Host "Enter Postgres password" -AsSecureString
$BSTR = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($SecurePass)
$PlainPassword = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($BSTR)

$env:PGPASSWORD = $PlainPassword

python postgres_ingest_from_lor_sqlite.py `
    --sqlite "$SQLitePath" `
    --pg-host "$pgHost" `
    --pg-db "$pgDb" `
    --pg-user "$pgUser" `
    --notes "$Notes"

Remove-Item Env:\PGPASSWORD