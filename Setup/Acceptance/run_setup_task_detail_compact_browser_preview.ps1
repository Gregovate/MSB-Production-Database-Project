param(
    [string]$Server = 'msbadmin@192.168.5.9',
    [Parameter(Mandatory=$true)]
    [int]$PreviewPort,
    [string]$PreviewEmail = 'gliebig@sheboyganlights.org'
)

$ErrorActionPreference = 'Stop'

# Exact V0.3.8 application/test candidate for Issue #153. Later commits may
# harden only acceptance tooling; browser/deployment approval remains pinned.
$AcceptedCandidateSha = '08758645b8c2226e732254ddc88faed4eda3f4b3'
$AcceptedBranch = 'agent/setup-task-detail-layout-153'
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
        throw "Setup compact-layout preview could not find expected $Description."
    }
    return $Source.Replace($Needle, $Replacement)
}

$text = [System.IO.File]::ReadAllText($BaseWrapper)
$text = $text.Replace("`r`n", "`n").Replace("`r", "`n")

$text = Replace-Required -Source $text -Needle "`$CandidateSha = '51c739bd85115c9f5d2853763e8e1450ac381407'" -Replacement "`$CandidateSha = '$AcceptedCandidateSha'" -Description 'source-only candidate SHA assignment'
$text = Replace-Required -Source $text -Needle "`$ExpectedBranch = 'agent/setup-session-production-foundation'" -Replacement "`$ExpectedBranch = '$AcceptedBranch'" -Description 'source-only expected branch assignment'

$scriptDirLiteral = $PSScriptRoot.Replace("'", "''")
$text = Replace-Required -Source $text -Needle '$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path' -Replacement "`$ScriptDir = '$scriptDirLiteral'" -Description 'base wrapper ScriptDir initialization'

$regressionNeedle = "        '      Setup/Application/test_setup_next_pass_contract.py'"
$regressionReplacement = @(
    "        '      Setup/Application/test_setup_next_pass_contract.py \',",
    "        '      Setup/Application/test_setup_stage_order_contract.py \',",
    "        '      Setup/Application/test_setup_dirty_edit_guard_contract.py \',",
    "        '      Setup/Application/test_setup_task_detail_compact_contract.py'"
) -join "`n"
$text = Replace-Required -Source $text -Needle $regressionNeedle -Replacement $regressionReplacement -Description 'focused regression tail'

$text = $text.Replace('SETUP SOURCE-ONLY BROWSER PREVIEW', 'SETUP TASK-DETAIL V0.3.8 BROWSER PREVIEW')
$text = $text.Replace('SETUP SOURCE-ONLY BROWSER REVIEW READY', 'SETUP TASK-DETAIL V0.3.8 BROWSER REVIEW READY')

Write-Host 'Issue #153 V0.3.8 browser acceptance checklist:'
Write-Host '  0. Confirm the header visibly shows Client V0.3.8 before any write.'
Write-Host '  1. Open a typical task at desktop width. Reusable Task Definition should be materially shorter and use two columns.'
Write-Host '  2. Annual Historical Actual stays in the right rail; Captains / Knowledge Owners appear beneath it instead of inside the reusable column.'
Write-Host '  3. Prerequisites and Equipment / Resources are reachable with substantially less scrolling than Production V0.3.7.'
Write-Host '  4. Material / Logistics shows the four essential counts as a compact inline summary, not four large cards.'
Write-Host '  5. View Material Details still opens the full Container / Display dialog and warnings remain visible.'
Write-Host '  6. Verify one reusable edit + Save, one annual edit, Captain controls, and resource controls remain functional.'
Write-Host '  7. Narrow the browser/mobile width and confirm the editor stacks cleanly with no clipped controls.'
Write-Host '  8. Check both light and dark modes for readable contrast. Cross-app palette/logo standardization is tracked separately in #159.'
Write-Host

$script = [scriptblock]::Create($text)
& $script -Server $Server -PreviewPort $PreviewPort -PreviewEmail $PreviewEmail
