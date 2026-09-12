param(
    [string]$Server = 'msbadmin@192.168.5.9',
    [Parameter(Mandatory=$true)]
    [int]$PreviewPort,
    [string]$PreviewEmail = 'gliebig@sheboyganlights.org'
)

$ErrorActionPreference = 'Stop'

# Exact V0.3.11 application candidate for Issue #169. Later commits may add
# browser-review tooling or documentation only; browser/deployment approval
# remains pinned to this SHA unless an application/runtime file changes.
$AcceptedCandidateSha = '28ad2d28addd47f8f086ed3b2e53468b453dbe13'
$AcceptedBranch = 'agent/setup-active-task-context-169'
$BaseWrapper = Join-Path $PSScriptRoot 'run_setup_source_only_browser_preview.ps1'
$CleanupScript = Join-Path $PSScriptRoot 'setup_session_browser_preview_cleanup_server.sh'

foreach ($requiredPath in @($BaseWrapper, $CleanupScript)) {
    if (-not (Test-Path -LiteralPath $requiredPath)) {
        throw "Required Setup preview file is missing: $requiredPath"
    }
}

function Replace-Required {
    param(
        [Parameter(Mandatory=$true)][string]$Source,
        [Parameter(Mandatory=$true)][string]$Needle,
        [Parameter(Mandatory=$true)][string]$Replacement,
        [Parameter(Mandatory=$true)][string]$Description
    )
    if (-not $Source.Contains($Needle)) {
        throw "Setup active-task preview could not find expected $Description."
    }
    return $Source.Replace($Needle, $Replacement)
}

$text = [System.IO.File]::ReadAllText($BaseWrapper)
$text = $text.Replace("`r`n", "`n").Replace("`r", "`n")

$text = Replace-Required -Source $text -Needle "`$CandidateSha = '51c739bd85115c9f5d2853763e8e1450ac381407'" -Replacement "`$CandidateSha = '$AcceptedCandidateSha'" -Description 'source-only candidate SHA assignment'
$text = Replace-Required -Source $text -Needle "`$ExpectedBranch = 'agent/setup-session-production-foundation'" -Replacement "`$ExpectedBranch = '$AcceptedBranch'" -Description 'source-only expected branch assignment'

$scriptDirLiteral = $PSScriptRoot.Replace("'", "''")
$text = Replace-Required -Source $text -Needle '$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path' -Replacement "`$ScriptDir = '$scriptDirLiteral'" -Description 'base wrapper ScriptDir initialization'

# Recover only a provably stale Setup preview on the explicitly selected
# non-Production port. Unknown listeners remain fail-closed per the runbook.
$cleanupInjectionNeedle = '$stamp = Get-Date -Format ''yyyyMMdd-HHmmss'''
$cleanupInjection = @'
$cleanupScript = Join-Path $ScriptDir 'setup_session_browser_preview_cleanup_server.sh'
if (-not (Test-Path -LiteralPath $cleanupScript)) {
    throw "Setup preview stale-cleanup script is missing: $cleanupScript"
}
$cleanupStamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$cleanupTemp = Join-Path ([System.IO.Path]::GetTempPath()) "msb-setup-source-preview-cleanup-$cleanupStamp.sh"
$cleanupRemote = "/tmp/msb-setup-source-preview-cleanup-$cleanupStamp.sh"
$cleanupUtf8 = New-Object System.Text.UTF8Encoding($false)
try {
    $cleanupText = [System.IO.File]::ReadAllText($cleanupScript)
    $cleanupText = $cleanupText.Replace("`r`n", "`n").Replace("`r", "`n")
    [System.IO.File]::WriteAllText($cleanupTemp, $cleanupText, $cleanupUtf8)

    & scp $cleanupTemp "${Server}:$cleanupRemote"
    if ($LASTEXITCODE -ne 0) {
        throw "Setup preview stale-cleanup upload failed with exit code $LASTEXITCODE"
    }

    $cleanupCommand = "chmod 700 '$cleanupRemote'; bash -n '$cleanupRemote'; rc=`$?; if [ `$rc -eq 0 ]; then bash '$cleanupRemote' '$PreviewPort'; rc=`$?; fi; rm -f '$cleanupRemote'; exit `$rc"
    & ssh -tt $Server $cleanupCommand
    if ($LASTEXITCODE -ne 0) {
        throw "Setup preview stale-cleanup failed with exit code $LASTEXITCODE"
    }
}
finally {
    Remove-Item -LiteralPath $cleanupTemp -Force -ErrorAction SilentlyContinue
}

$stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
'@
$cleanupInjection = $cleanupInjection.Replace("`r`n", "`n").Replace("`r", "`n")
$text = Replace-Required -Source $text -Needle $cleanupInjectionNeedle -Replacement $cleanupInjection -Description 'source-only stale-cleanup injection point'

# Add only tests present in the exact #169 candidate. No migration is applied:
# this is a source-only UI safety change.
$regressionNeedle = "        '      Setup/Application/test_setup_next_pass_contract.py'"
$regressionReplacement = @(
    "        '      Setup/Application/test_setup_next_pass_contract.py \',",
    "        '      Setup/Application/test_setup_production_contract.py \',",
    "        '      Setup/Application/test_setup_dirty_edit_guard_contract.py \',",
    "        '      Setup/Application/test_setup_task_detail_compact_contract.py \',",
    "        '      Setup/Application/test_setup_predecessor_drag_contract.py \',",
    "        '      Setup/Application/test_setup_prerequisite_editor_contract.py \',",
    "        '      Setup/Application/test_setup_resource_management_contract.py \',",
    "        '      Setup/Application/test_setup_active_task_context_contract.py'"
) -join "`n"
$text = Replace-Required -Source $text -Needle $regressionNeedle -Replacement $regressionReplacement -Description 'focused regression tail'

# Long browser reviews must preserve terminal foreground ownership and clean up
# on tunnel/session loss, per the current browser-review runbook.
$serverInjectionNeedle = '    # Fail locally before SCP if any CR characters were reintroduced by a later'
$serverInjection = @'
    # A disconnected browser-review SSH session must trigger the same cleanup.
    $serverText = $serverText.Replace('trap - EXIT INT TERM', 'trap - EXIT HUP INT TERM')
    $serverText = $serverText.Replace('trap cleanup EXIT INT TERM', 'trap cleanup EXIT HUP INT TERM')

    # Fail locally before SCP if any CR characters were reintroduced by a later
'@
$serverInjection = $serverInjection.Replace("`r`n", "`n").Replace("`r", "`n")
$text = Replace-Required -Source $text -Needle $serverInjectionNeedle -Replacement $serverInjection -Description 'session-loss cleanup injection point'

$text = Replace-Required -Source $text -Needle "bash '`$remoteServer' '`$CandidateSha' '`$PreviewPort' '`$PreviewEmail' '`$ApprovedRef'" -Replacement "timeout --foreground --signal=TERM 28800s bash '`$remoteServer' '`$CandidateSha' '`$PreviewPort' '`$PreviewEmail' '`$ApprovedRef'" -Description 'interactive remote source-only preview invocation'
$text = Replace-Required -Source $text -Needle '& ssh -t -L "${PreviewPort}:127.0.0.1:${PreviewPort}" $Server $remoteCommand' -Replacement '& ssh -tt -o ServerAliveInterval=15 -o ServerAliveCountMax=3 -L "${PreviewPort}:127.0.0.1:${PreviewPort}" $Server $remoteCommand' -Description 'source-only SSH tunnel invocation'

$text = $text.Replace('SETUP SOURCE-ONLY BROWSER PREVIEW', 'SETUP ACTIVE TASK CONTEXT V0.3.11 BROWSER PREVIEW')
$text = $text.Replace('SETUP SOURCE-ONLY BROWSER REVIEW READY', 'SETUP ACTIVE TASK CONTEXT V0.3.11 BROWSER REVIEW READY')

Write-Host 'Issue #169 V0.3.11 browser acceptance checklist:'
Write-Host '  0. Confirm the header shows Client V0.3.11 and the preview reports the exact candidate SHA above.'
Write-Host '  1. Open a long reusable task such as Stage 01 Front Arch and confirm its normal detail heading still shows Stage, task name, IDs, and verification state.'
Write-Host '  2. Confirm the sticky global Setup header also shows Active task with the selected Stage and task name.'
Write-Host '  3. Scroll down through Material / Logistics, Prerequisites, Equipment / Resources, and Setup Procedure. The Active task identity must remain visible in the sticky header for the entire scroll.'
Write-Host '  4. Switch to a different task with no unsaved edits. Confirm Active task updates immediately to the newly selected Stage/task.'
Write-Host '  5. Make an unsaved reusable edit, then attempt to open another task. Exercise Save and continue, Discard and continue, and Stay on this task. No path may silently lose edits.'
Write-Host '  6. Confirm the persistent identity still names the actual selected task after each Save / Discard / Stay outcome.'
Write-Host '  7. Check light mode and dark mode. The persistent identity must remain readable using the existing Setup theme tokens.'
Write-Host '  8. Narrow the browser to laptop/mobile-style widths. Confirm the header wraps without hiding season, operator, client version, theme control, or active task identity.'
Write-Host '  9. Confirm prerequisites, Resource Catalog/Equipment controls, Material / Logistics detail, Captains/Knowledge Owners, procedure links, and ordinary task selection still work.'
Write-Host ' 10. Confirm Reusable Task Catalog and Movement / Scanning views do not show a stale Active task identity when the review view is not active.'
Write-Host
Write-Host 'All writes in this checklist are against the disposable Production clone only. Production remains unchanged.'
Write-Host

$script = [scriptblock]::Create($text)
& $script -Server $Server -PreviewPort $PreviewPort -PreviewEmail $PreviewEmail
