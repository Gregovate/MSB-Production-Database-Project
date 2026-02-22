# MSB Database — Postgres Snapshot Ingest Runner
# Secure password prompt (not stored)

param (
    [string]$SQLitePath = "G:\Shared drives\MSB Database\database\lor_output_v6.db",
    [string]$Notes = "LOR snapshot ingest"
)

$pgHost = "192.168.5.9"
$pgDb = "msb"
$pgUser = "msbadmin"

Write-Host "MSB Postgres Snapshot Ingest"
Write-Host "SQLite: $SQLitePath"
Write-Host ""

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