param(
    [string]$Server = 'msbadmin@192.168.5.9',
    [Parameter(Mandatory=$true)]
    [int]$PreviewPort,
    [string]$PreviewEmail = 'gliebig@sheboyganlights.org'
)

$ErrorActionPreference = 'Stop'

# Exact V0.3.9 application/test candidate for Issue #151. Later commits may
# harden acceptance tooling only; browser/deployment approval remains pinned here.
$AcceptedCandidateSha = 'bd7457205b7f6596b9221348b6118ba9861abecc'
$AcceptedBranch = 'agent/setup-shift-drag-predecessor-151'
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
        throw "Setup predecessor-drag preview could not find expected $Description."
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
    "        '      Setup/Application/test_setup_predecessor_drag_contract.py \',",
    "        '      Setup/Application/test_setup_dirty_edit_guard_contract.py \',",
    "        '      Setup/Application/test_setup_task_detail_compact_contract.py'"
) -join "`n"
$text = Replace-Required -Source $text -Needle $regressionNeedle -Replacement $regressionReplacement -Description 'focused regression tail'

$text = $text.Replace('SETUP SOURCE-ONLY BROWSER PREVIEW', 'SETUP SHIFT-DRAG PREDECESSOR V0.3.9 BROWSER PREVIEW')
$text = $text.Replace('SETUP SOURCE-ONLY BROWSER REVIEW READY', 'SETUP SHIFT-DRAG PREDECESSOR V0.3.9 BROWSER REVIEW READY')

Write-Host 'Issue #151 Shift-drag predecessor V0.3.9 browser acceptance checklist:'
Write-Host '  0. Confirm the header visibly shows Client V0.3.9 and the Catalog shows the Fast prerequisite entry hint.'
Write-Host '  1. Choose two disposable-clone reusable tasks A and B and note both tasks'' current scope/order before testing.'
Write-Host '  2. Hold Shift BEFORE starting the drag on dependent task A. A must visibly show Dependent.'
Write-Host '  3. Drag A over prerequisite task B. B must visibly show Prerequisite target; release on B.'
Write-Host '  4. Confirm explicit success feedback says A depends on B and neither task moved. A''s Requires line must show B.'
Write-Host '  5. Repeat the same Shift-drag A -> B. Confirm it remains one dependency, not a duplicate.'
Write-Host '  6. Try Shift-drag B -> A. Confirm the governed circular-dependency error is shown and neither task moves.'
Write-Host '  7. Confirm A and B still have their original scope/order after all Shift-drag operations.'
Write-Host '  8. Now perform one ordinary drag WITHOUT Shift. Confirm normal Catalog move/reorder behavior still works.'
Write-Host '  9. Open task A and confirm the existing manual prerequisite editor still shows/removes B as a normal fallback.'
Write-Host ' 10. Verify Shift-drag over empty Stage/Scene space does not move the task and reports that a task target is required.'
Write-Host

$script = [scriptblock]::Create($text)
& $script -Server $Server -PreviewPort $PreviewPort -PreviewEmail $PreviewEmail
