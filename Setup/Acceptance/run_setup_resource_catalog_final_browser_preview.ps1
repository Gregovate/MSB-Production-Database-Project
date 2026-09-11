param(
    [string]$Server = 'msbadmin@192.168.5.9',
    [Parameter(Mandatory=$true)]
    [int]$PreviewPort,
    [string]$PreviewEmail = 'gliebig@sheboyganlights.org'
)

$ErrorActionPreference = 'Stop'

# Exact #152 runtime candidate containing the compact picker plus the accepted
# Save Catalog Resource -> colored Close Resource Catalog workflow. Later branch
# commits are tests/acceptance tooling only.
$AcceptedCandidateSha = 'd74202002e6845b291dc937697f4589d3f4be6c3'
$PriorCandidateSha = '17590dc3a3e81dd67e38fcb42ba38e69beeea089'
$BaseWrapper = Join-Path $PSScriptRoot 'run_setup_resource_catalog_browser_preview.ps1'

if (-not (Test-Path -LiteralPath $BaseWrapper)) {
    throw "Required #152 browser preview wrapper is missing: $BaseWrapper"
}

$text = [System.IO.File]::ReadAllText($BaseWrapper)
$text = $text.Replace("`r`n", "`n").Replace("`r", "`n")

$candidateNeedle = "`$AcceptedCandidateSha = '$PriorCandidateSha'"
$candidateReplacement = "`$AcceptedCandidateSha = '$AcceptedCandidateSha'"
if (([regex]::Matches($text, [regex]::Escape($candidateNeedle))).Count -ne 1) {
    throw 'Final #152 preview could not find exactly one prior candidate pin.'
}
$text = $text.Replace($candidateNeedle, $candidateReplacement)

# The nested resource-catalog wrapper is executed as an in-memory scriptblock.
# PowerShell does not populate $PSScriptRoot for that scriptblock, so replace the
# two nested wrapper path initializers with this real Acceptance directory before
# execution. This keeps all file resolution deterministic from a Windows checkout.
$acceptanceDirLiteral = $PSScriptRoot.Replace("'", "''")
$nestedBaseNeedle = "`$BaseWrapper = Join-Path `$PSScriptRoot 'run_setup_source_only_browser_preview.ps1'"
$nestedBaseReplacement = "`$BaseWrapper = Join-Path '$acceptanceDirLiteral' 'run_setup_source_only_browser_preview.ps1'"
$nestedCleanupNeedle = "`$CleanupScript = Join-Path `$PSScriptRoot 'setup_session_browser_preview_cleanup_server.sh'"
$nestedCleanupReplacement = "`$CleanupScript = Join-Path '$acceptanceDirLiteral' 'setup_session_browser_preview_cleanup_server.sh'"
foreach ($replacement in @(
    @($nestedBaseNeedle, $nestedBaseReplacement, 'nested source-only wrapper path'),
    @($nestedCleanupNeedle, $nestedCleanupReplacement, 'nested cleanup-script path')
)) {
    $needle = $replacement[0]
    $replacementText = $replacement[1]
    $description = $replacement[2]
    if (([regex]::Matches($text, [regex]::Escape($needle))).Count -ne 1) {
        throw "Final #152 preview could not find exactly one $description."
    }
    $text = $text.Replace($needle, $replacementText)
}

$oldChecklist = "Write-Host '  5. Click Manage Resource Catalog. Confirm the full catalog maintenance area opens on demand; click Close Resource Catalog and confirm it collapses again.'"
$newChecklist = "Write-Host '  5. Click Manage Resource Catalog. Confirm catalog maintenance opens on demand, the top Manage button is hidden while open, and a colored Close Resource Catalog button sits directly beside Save Catalog Resource. Save an edit, then close the catalog and confirm it collapses.'"
if (-not $text.Contains($oldChecklist)) {
    throw 'Final #152 preview could not find the expected catalog open/close checklist line.'
}
$text = $text.Replace($oldChecklist, $newChecklist)
$text = $text.Replace(
    'Issue #152 Resource Catalog V0.3.10 compact-picker browser acceptance checklist:',
    'Issue #152 Resource Catalog V0.3.10 FINAL browser acceptance checklist:'
)

$script = [scriptblock]::Create($text)
& $script -Server $Server -PreviewPort $PreviewPort -PreviewEmail $PreviewEmail
