param(
    [string]$Server = 'msbadmin@192.168.5.9',
    [Parameter(Mandatory=$true)]
    [int]$PreviewPort,
    [string]$PreviewEmail = 'gliebig@sheboyganlights.org'
)

$ErrorActionPreference = 'Stop'

# Exact V0.3.7 application candidate for the Issue #154 follow-up. Later
# acceptance-only commits may follow, but browser approval remains pinned here.
$AcceptedCandidateSha = '7480fdae852ca7de70a8cdb65f1f26c7c6aaa40b'
$AcceptedBranch = 'agent/setup-dirty-edit-followup-154'
$BaseWrapper = Join-Path $PSScriptRoot 'run_setup_source_only_browser_preview.ps1'

if (-not (Test-Path -LiteralPath $BaseWrapper)) {
    throw "Setup source-only preview base wrapper is missing: $BaseWrapper"
}

function Replace-Required {
    param(
        [Parameter(Mandatory=$true)][string]$Source,
        [Parameter(Mandatory=$true)][string]$Needle,
        [Parameter(Mandatory=$true)][string]$Replacement,
        [Parameter(Mandatory=$true)][string]$Description
    )

    if (-not $Source.Contains($Needle)) {
        throw "Setup dirty-edit preview could not find expected $Description."
    }
    return $Source.Replace($Needle, $Replacement)
}

# Reuse the hardened source-only current-Production-clone preview. Override only
# the exact application candidate/ref and focused regression list for #154.
$text = [System.IO.File]::ReadAllText($BaseWrapper)
$text = $text.Replace("`r`n", "`n").Replace("`r", "`n")

$text = Replace-Required -Source $text -Needle "`$CandidateSha = '51c739bd85115c9f5d2853763e8e1450ac381407'" -Replacement "`$CandidateSha = '$AcceptedCandidateSha'" -Description 'source-only candidate SHA assignment'
$text = Replace-Required -Source $text -Needle "`$ExpectedBranch = 'agent/setup-session-production-foundation'" -Replacement "`$ExpectedBranch = '$AcceptedBranch'" -Description 'source-only expected branch assignment'

# A dynamically compiled wrapper has no reliable MyInvocation path. Pin the
# real Acceptance directory so the base wrapper resolves its server/entry files.
$scriptDirLiteral = $PSScriptRoot.Replace("'", "''")
$text = Replace-Required -Source $text -Needle '$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path' -Replacement "`$ScriptDir = '$scriptDirLiteral'" -Description 'base wrapper ScriptDir initialization'

# Add the #154 contracts to the focused detached regression. The Stage-order
# contract carries the current V0.3.7 health-version assertion.
$regressionNeedle = "        '      Setup/Application/test_setup_next_pass_contract.py'"
$regressionReplacement = @(
    "        '      Setup/Application/test_setup_next_pass_contract.py \',",
    "        '      Setup/Application/test_setup_stage_order_contract.py \',",
    "        '      Setup/Application/test_setup_dirty_edit_guard_contract.py'"
) -join "`n"
$text = Replace-Required -Source $text -Needle $regressionNeedle -Replacement $regressionReplacement -Description 'focused regression tail'

$text = $text.Replace('SETUP SOURCE-ONLY BROWSER PREVIEW', 'SETUP CATALOG DIRTY-EDIT V0.3.7 BROWSER PREVIEW')
$text = $text.Replace('SETUP SOURCE-ONLY BROWSER REVIEW READY', 'SETUP CATALOG DIRTY-EDIT V0.3.7 BROWSER REVIEW READY')

Write-Host 'Issue #154 V0.3.7 browser acceptance checklist:'
Write-Host '  0. Before any edit, confirm the header visibly shows Client V0.3.7. If not, stop and refresh; do not write.'
Write-Host '  1. Open an annual 2025 task and change reusable fields without saving.'
Write-Host '  2. Click Mark Verified; prove every reusable edit persists and annual state becomes VERIFIED.'
Write-Host '  3. Force a reusable save failure (for example a duplicate/invalid task name) and click Mark Verified; prove verification does NOT change.'
Write-Host '  4. With dirty edits, switch tasks and exercise Save + continue, Discard + continue, and Stay.'
Write-Host '  5. Make an annual-note draft, click Save Reusable Task, and prove the annual draft remains present.'
Write-Host '  6. Exercise one independent Effort or Material save and confirm it remains separately governed.'
Write-Host '  7. Return to the Catalog / change tabs with dirty edits and confirm no silent loss.'
Write-Host

$script = [scriptblock]::Create($text)
& $script -Server $Server -PreviewPort $PreviewPort -PreviewEmail $PreviewEmail
