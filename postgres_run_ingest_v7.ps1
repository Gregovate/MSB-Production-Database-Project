# MSB Database — Postgres Snapshot Ingest Runner
# postgres_run_ingest_v7.ps1
#
# Initial Release : 2026-02-23  V0.1.0
# Version         : 2026-03-18  V0.2.0
# Current Version : 2026-03-18  V0.2.0
#
# Changes:
# - Enforced ingestion of lor_output_v7.db (raw PropID model restored)
# - Added hard safety check to prevent accidental v6 ingestion
# - Updated default notes for v7 migration run
#
# Author          : Greg Liebig, Engineering Innovations, LLC.
#
# Purpose
# -------
# Secure wrapper to run the SQLite → Postgres snapshot ingest script.
#
# This runner:
#   • Prompts for Postgres password securely (not stored)
#   • Sets PGPASSWORD environment variable temporarily
#   • Executes postgres_ingest_from_lor_sqlite.py
#   • Clears credentials after execution
#
# Safety Rules
# ------------
# • Only lor_output_v7.db is permitted for ingestion.
# • Prevents accidental ingestion of obsolete v6 snapshots.
# • Requires explicit override to use any other SQLite file.
#
# Inputs
# ------
# Default SQLite file:
#   G:\Shared drives\MSB Database\database\lor_output_v7.db
#
# Target
# ------
# Host      : 192.168.5.9  (msb-prod-db)
# Database  : msb
# Schema    : lor_snap
#
# Execution
# ---------
# Run from PowerShell:
#
#   .\postgres_run_ingest.ps1
#
# Optional override (not recommended):
#
#   .\postgres_run_ingest.ps1 -SQLitePath "path\to\lor_output_v7.db"
#
# Notes
# -----
# This script performs NO data transformations.
# It is a transport layer only (append-only import_run model).
#
# Source of Truth
# ---------------
# Wiring, channel mapping, and display metadata originate in LOR.
# Postgres stores historical snapshots for operational workflows.
#
# -----------------------------------------------------------------------------
# Change Log
# 2026-03-18  GAL
#   - Enforce v7 raw PropID ingestion
#   - Added safety guard against v6 snapshot ingestion
# -----------------------------------------------------------------------------

param (
    [string]$SQLitePath = "G:\Shared drives\MSB Database\database\lor_output_v7.db",
    [string]$Notes = "LOR snapshot ingest v7 raw PropID restore"
)

$pgHost = "192.168.5.9"
$pgDb = "msb"
$pgUser = "msbadmin"

Write-Host "MSB Postgres Snapshot Ingest"
Write-Host "SQLite: $SQLitePath"
Write-Host ""

# ---- Safety check: only allow v7 database ----
$expectedName = "lor_output_v7.db"
$actualName = [System.IO.Path]::GetFileName($SQLitePath).ToLower()

if ($actualName -ne $expectedName) {
    Write-Host ""
    Write-Host "FATAL: Wrong SQLite file selected." -ForegroundColor Red
    Write-Host "Expected: $expectedName"
    Write-Host "Actual:   $actualName"
    Write-Host "Aborting ingest."
    exit 1
}

# Secure password prompt
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

# Clear password from environment after run
Remove-Item Env:\PGPASSWORD