param(
    [Parameter(Mandatory = $true)] [long]$ReconciliationRunId,
    [string]$OutputDirectory = "\\192.168.5.4\web\my\lortodb\reports",
    [string]$BaseUrl,
    [string]$PgHost = "192.168.5.9",
    [string]$PgDatabase = "msb",
    [string]$PgUser = "msbadmin",
    [switch]$EvaluationCopy
)

# Secured production runner. The workflow passes the run ID it retained from
# Start Reconciliation; an operator does not discover or select a latest run.
$publisher = Join-Path $PSScriptRoot "publish_lor_reconciliation_report.py"
if (-not (Test-Path -LiteralPath $publisher -PathType Leaf)) {
    throw "Report publisher not found: $publisher"
}

$securePassword = Read-Host "Enter Postgres password" -AsSecureString
$passwordPointer = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($securePassword)
try {
    $env:PGPASSWORD = [Runtime.InteropServices.Marshal]::PtrToStringAuto($passwordPointer)
    $arguments = @(
        $publisher,
        "--run-id", $ReconciliationRunId,
        "--output-dir", $OutputDirectory,
        "--pg-host", $PgHost,
        "--pg-db", $PgDatabase,
        "--pg-user", $PgUser
    )
    if ($BaseUrl) { $arguments += @("--base-url", $BaseUrl) }
    # Evaluation copies allow report-layout review of a completed run without
    # replacing its registered report or changing any reconciliation state.
    if ($EvaluationCopy) { $arguments += "--evaluation-copy" }
    & python @arguments
    if ($LASTEXITCODE -ne 0) {
        $operation = if ($EvaluationCopy) { "Report evaluation rendering" } else { "Report publication" }
        throw "$operation failed with exit code $LASTEXITCODE"
    }
}
finally {
    Remove-Item Env:\PGPASSWORD -ErrorAction SilentlyContinue
    if ($passwordPointer -ne [IntPtr]::Zero) {
        [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($passwordPointer)
    }
}
