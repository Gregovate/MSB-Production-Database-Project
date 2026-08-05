param(
    [long]$ReconciliationRunId,
    [string]$OutputDirectory = "\\192.168.5.4\web\my\lor2db\reports",
    [string]$BaseUrl = "https://my.sheboyganlights.org/lor2db/reports",
    [string]$PgHost = "192.168.5.9",
    [string]$PgDatabase = "msb",
    [string]$PgUser = "msbadmin",
    [switch]$EvaluationCopy,
    [switch]$RefreshIndex
)
# =============================================================================
# MSB Database - LOR Reconciliation Report Publisher
# publish_lor_reconciliation_report.ps1
#
# Initial Release : 2026-08-03  V0.1.0
# Current Version : 2026-08-04  V0.1.1
#
# Purpose:
#   Secure PowerShell wrapper for publishing finalized LOR reconciliation
#   reports and rebuilding the automatically generated report index.
#
# Operation:
#   - Publishes a specified completed reconciliation run.
#   - Supports evaluation copies without replacing the registered final report.
#   - Rebuilds index.html from reports already present in the output folder.
#   - Prompts securely for the PostgreSQL password when database access is needed.
#   - Publishes beneath the protected my.sheboyganlights.org/lor2db route.
#
# Change Log:
#   2026-08-04  GAL  V0.1.1
#     Changed the NAS output folder from lortodb to lor2db.
#     Added the protected default report URL:
#       https://my.sheboyganlights.org/lor2db/reports
#
#   2026-08-03  GAL  V0.1.0
#     Initial report-publication wrapper.
# =============================================================================


# Secured production runner. The workflow passes the run ID it retained from
# Start Reconciliation; an operator does not discover or select a latest run.
$publisher = Join-Path $PSScriptRoot "publish_lor_reconciliation_report.py"
if (-not (Test-Path -LiteralPath $publisher -PathType Leaf)) {
    throw "Report publisher not found: $publisher"
}

$arguments = @($publisher, "--output-dir", $OutputDirectory)
if ($RefreshIndex) {
    # Rebuild browsing from files already present; no database credentials or
    # reconciliation state are needed or changed.
    $arguments += "--refresh-index"
    & python @arguments
    if ($LASTEXITCODE -ne 0) { throw "Report index refresh failed with exit code $LASTEXITCODE" }
    return
}
if (-not $PSBoundParameters.ContainsKey("ReconciliationRunId")) {
    throw "ReconciliationRunId is required unless -RefreshIndex is used"
}

$securePassword = Read-Host "Enter Postgres password" -AsSecureString
$passwordPointer = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($securePassword)
try {
    $env:PGPASSWORD = [Runtime.InteropServices.Marshal]::PtrToStringAuto($passwordPointer)
    $arguments += @(
        "--run-id", $ReconciliationRunId,
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
