param(
    [string]$Server = 'msbadmin@192.168.5.9',
    [Parameter(Mandatory=$true)]
    [int]$PreviewPort,
    [string]$PreviewEmail = 'gliebig@sheboyganlights.org'
)

$ErrorActionPreference = 'Stop'

# Exact V0.3.9 application/schema/test candidate for Issue #151. Later commits
# may harden acceptance tooling only; browser/deployment approval remains pinned.
$AcceptedCandidateSha = '280ec6bee5ec9847459f28de41140520e71b0910'
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
    "        '      Setup/Application/test_setup_prerequisite_editor_contract.py \',",
    "        '      Setup/Application/test_setup_dirty_edit_guard_contract.py \',",
    "        '      Setup/Application/test_setup_task_detail_compact_contract.py'"
) -join "`n"
$text = Replace-Required -Source $text -Needle $regressionNeedle -Replacement $regressionReplacement -Description 'focused regression tail'

# Issue #151 now includes a narrow schema migration for persistent prerequisite
# review order. Apply it only after the current Production dump has been restored
# into the disposable clone and after fieldwiring_app has been recreated there.
# The live Production database remains pg_dump + SELECT only during this preview.
$serverInjectionNeedle = '    # Fail locally before SCP if any CR characters were reintroduced by a later'
$serverInjection = @'
    # Issue #151 prerequisite-order migration belongs only in the disposable clone.
    $migrationNeedle = "SQL`n`nTEST_IP="
    $migrationReplacement = @(
        'SQL',
        '',
        'echo',
        'echo "--- Apply Issue #151 prerequisite-order migration to disposable clone only ---"'.Replace('\"','"'),
        'M026="$CANDIDATE_WORKTREE/Setup/Database/026_add_setup_dependency_order.sql"'.Replace('\"','"'),
        'if [[ ! -s "$M026" ]]; then echo "FAIL: Issue #151 migration missing: $M026"; exit 13; fi'.Replace('\"','"'),
        'psql_test < "$M026"'.Replace('\"','"'),
        "psql_test <<'SQL151'",
        'DO $block$',
        'BEGIN',
        "    IF NOT EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'ref.setup_task_dependency'::regclass AND attname = 'sort_order' AND attnotnull) THEN",
        "        RAISE EXCEPTION 'Issue #151 sort_order column is missing or nullable';",
        '    END IF;',
        "    IF to_regprocedure('ref.reorder_setup_task_dependencies(text,bigint,bigint[])') IS NULL THEN",
        "        RAISE EXCEPTION 'Issue #151 reorder command is missing';",
        '    END IF;',
        "    IF NOT has_function_privilege('fieldwiring_app', 'ref.reorder_setup_task_dependencies(text,bigint,bigint[])', 'EXECUTE') THEN",
        "        RAISE EXCEPTION 'fieldwiring_app cannot execute Issue #151 reorder command';",
        '    END IF;',
        "    IF has_table_privilege('fieldwiring_app', 'ref.setup_task_dependency', 'UPDATE')",
        "       OR has_table_privilege('fieldwiring_app', 'ref.setup_task_dependency', 'INSERT')",
        "       OR has_table_privilege('fieldwiring_app', 'ref.setup_task_dependency', 'DELETE') THEN",
        "        RAISE EXCEPTION 'fieldwiring_app unexpectedly has broad prerequisite table DML';",
        '    END IF;',
        'END',
        '$block$;',
        'SQL151',
        'echo "Issue #151 prerequisite-order migration on disposable clone: PASS"'.Replace('\"','"'),
        '',
        'TEST_IP='
    ) -join "`n"
    if (-not $serverText.Contains($migrationNeedle)) {
        throw 'Issue #151 preview could not find the disposable clone role-grant boundary.'
    }
    $serverText = $serverText.Replace($migrationNeedle, $migrationReplacement)

    # Fail locally before SCP if any CR characters were reintroduced by a later
'@
$serverInjection = $serverInjection.Replace("`r`n", "`n").Replace("`r", "`n")
$text = Replace-Required -Source $text -Needle $serverInjectionNeedle -Replacement $serverInjection -Description 'disposable migration injection point'

$text = $text.Replace('SETUP SOURCE-ONLY BROWSER PREVIEW', 'SETUP SHIFT-DRAG PREDECESSOR V0.3.9 BROWSER PREVIEW')
$text = $text.Replace('SETUP SOURCE-ONLY BROWSER REVIEW READY', 'SETUP SHIFT-DRAG PREDECESSOR V0.3.9 BROWSER REVIEW READY')

Write-Host 'Issue #151 Shift-drag predecessor V0.3.9 browser acceptance checklist:'
Write-Host '  0. Confirm the header visibly shows Client V0.3.9 and the preview reports the Issue #151 migration PASS on the disposable clone.'
Write-Host '  1. In the Catalog, hold Shift BEFORE pressing the left mouse button on dependent task A; drag onto prerequisite B. Confirm A depends on B and neither task moves.'
Write-Host '  2. Add a second prerequisite C to A by Shift-drag. Confirm the Catalog Requires line lists both B and C.'
Write-Host '  3. Repeat A -> B and confirm no duplicate relationship appears.'
Write-Host '  4. Try a reverse relationship that would make a cycle. Confirm the governed circular-dependency error and no task movement.'
Write-Host '  5. Open A. Confirm there is ONE prerequisite list only: each row appears once with position, Up, Down, and Remove controls; the separate Add prerequisite form is below it.'
Write-Host '  6. Move C above B with Up/Down. Confirm the detail list AND Catalog Requires line immediately show the same new order. Close/reopen A and confirm order persists.'
Write-Host '  7. Remove one prerequisite. Confirm it disappears immediately from the one detail list and the Catalog Requires line; close/reopen A and confirm it stays removed.'
Write-Host '  8. Add one prerequisite using the manual Add form. Confirm the newly added task appends once, the dropdown no longer offers it as an available choice, and all views agree.'
Write-Host '  9. Perform one ordinary drag WITHOUT Shift. Confirm normal Catalog move/reorder/scope behavior remains unchanged.'
Write-Host ' 10. Shift-drag over empty Stage/Scene space and release. Confirm the gesture cancels without moving the task.'
Write-Host ' 11. Remember: prerequisite Up/Down is review/display order only. It does not imply one prerequisite depends on another.'
Write-Host

$script = [scriptblock]::Create($text)
& $script -Server $Server -PreviewPort $PreviewPort -PreviewEmail $PreviewEmail
