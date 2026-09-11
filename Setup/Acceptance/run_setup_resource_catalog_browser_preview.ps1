param(
    [string]$Server = 'msbadmin@192.168.5.9',
    [Parameter(Mandatory=$true)]
    [int]$PreviewPort,
    [string]$PreviewEmail = 'gliebig@sheboyganlights.org'
)

$ErrorActionPreference = 'Stop'

# Exact V0.3.10 application/schema candidate for Issue #152. Later commits may
# repair tests or harden acceptance tooling only; browser/deployment approval
# remains pinned to this SHA.
$AcceptedCandidateSha = 'f8518f469cc62f76aa33e666c2664a2042c23f7f'
$AcceptedBranch = 'agent/setup-152-resource-catalog'
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
        throw "Setup resource-catalog preview could not find expected $Description."
    }
    return $Source.Replace($Needle, $Replacement)
}

$text = [System.IO.File]::ReadAllText($BaseWrapper)
$text = $text.Replace("`r`n", "`n").Replace("`r", "`n")

$text = Replace-Required -Source $text -Needle "`$CandidateSha = '51c739bd85115c9f5d2853763e8e1450ac381407'" -Replacement "`$CandidateSha = '$AcceptedCandidateSha'" -Description 'source-only candidate SHA assignment'
$text = Replace-Required -Source $text -Needle "`$ExpectedBranch = 'agent/setup-session-production-foundation'" -Replacement "`$ExpectedBranch = '$AcceptedBranch'" -Description 'source-only expected branch assignment'

$scriptDirLiteral = $PSScriptRoot.Replace("'", "''")
$text = Replace-Required -Source $text -Needle '$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path' -Replacement "`$ScriptDir = '$scriptDirLiteral'" -Description 'base wrapper ScriptDir initialization'

# Recover a prior preview only after branch/clean-worktree/candidate checks pass.
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

# Add #152-focused contracts to the existing current source-only gate. The
# stage-order version-literal repair is intentionally tooling-only and does not
# alter the pinned runtime/schema candidate.
$regressionNeedle = "        '      Setup/Application/test_setup_next_pass_contract.py'"
$regressionReplacement = @(
    "        '      Setup/Application/test_setup_next_pass_contract.py \',",
    "        '      Setup/Application/test_setup_resource_management_contract.py \',",
    "        '      Setup/Application/test_setup_dirty_edit_guard_contract.py'"
) -join "`n"
$text = Replace-Required -Source $text -Needle $regressionNeedle -Replacement $regressionReplacement -Description 'focused regression tail'

# Apply Issue #152 migration 027 only to the disposable current-Production clone.
# Live Production remains pg_dump + SELECT only during this preview.
$serverInjectionNeedle = '    # Fail locally before SCP if any CR characters were reintroduced by a later'
$serverInjection = @'
    # Issue #152 resource-catalog migration belongs only in the disposable clone.
    $migrationNeedle = "SQL`n`nTEST_IP="
    $migrationReplacement = @(
        'SQL',
        '',
        'echo',
        'echo "--- Apply Issue #152 resource-catalog migration to disposable clone only ---"'.Replace('\"','"'),
        'M027="$CANDIDATE_WORKTREE/Setup/Database/027_add_setup_resource_catalog_management.sql"'.Replace('\"','"'),
        'if [[ ! -s "$M027" ]]; then echo "FAIL: Issue #152 migration missing: $M027"; exit 13; fi'.Replace('\"','"'),
        'psql_test < "$M027"'.Replace('\"','"'),
        "psql_test <<'SQL152'",
        'DO $block$',
        'DECLARE',
        '    v_min integer;',
        '    v_max integer;',
        'BEGIN',
        "    IF NOT EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'ref.setup_resource'::regclass AND attname = 'display_order' AND attnotnull) THEN",
        "        RAISE EXCEPTION 'Issue #152 display_order column is missing or nullable';",
        '    END IF;',
        "    IF to_regprocedure('ref.update_setup_resource(text,integer,text,text,text,boolean,integer)') IS NULL THEN",
        "        RAISE EXCEPTION 'Issue #152 governed update command is missing';",
        '    END IF;',
        "    IF NOT has_function_privilege('fieldwiring_app', 'ref.update_setup_resource(text,integer,text,text,text,boolean,integer)', 'EXECUTE') THEN",
        "        RAISE EXCEPTION 'fieldwiring_app cannot execute Issue #152 update command';",
        '    END IF;',
        "    IF has_table_privilege('fieldwiring_app', 'ref.setup_resource', 'UPDATE')",
        "       OR has_table_privilege('fieldwiring_app', 'ref.setup_resource', 'DELETE')",
        "       OR has_table_privilege('fieldwiring_app', 'ref.setup_task_resource', 'UPDATE') THEN",
        "        RAISE EXCEPTION 'fieldwiring_app unexpectedly has broad resource-table DML';",
        '    END IF;',
        '    SELECT min(display_order), max(display_order) INTO v_min, v_max FROM ref.setup_resource;',
        "    IF v_min IS DISTINCT FROM 100 OR v_max IS DISTINCT FROM 100 THEN",
        "        RAISE EXCEPTION 'Existing resource display_order values were unexpectedly rewritten: min %, max %', v_min, v_max;",
        '    END IF;',
        'END',
        '$block$;',
        "SELECT 'normalized_duplicate_groups=' || count(*)",
        'FROM (',
        "    SELECT lower(regexp_replace(btrim(resource_name), '[[:space:]]+', ' ', 'g'))",
        '    FROM ref.setup_resource',
        '    GROUP BY 1',
        '    HAVING count(*) > 1',
        ') d;',
        'SQL152',
        'echo "Issue #152 resource-catalog migration on disposable clone: PASS"'.Replace('\"','"'),
        '',
        'TEST_IP='
    ) -join "`n"
    if (-not $serverText.Contains($migrationNeedle)) {
        throw 'Issue #152 preview could not find the disposable clone role-grant boundary.'
    }
    $serverText = $serverText.Replace($migrationNeedle, $migrationReplacement)

    # A disconnected browser-review SSH session must trigger the same cleanup.
    $serverText = $serverText.Replace('trap - EXIT INT TERM', 'trap - EXIT HUP INT TERM')
    $serverText = $serverText.Replace('trap cleanup EXIT INT TERM', 'trap cleanup EXIT HUP INT TERM')

    # Fail locally before SCP if any CR characters were reintroduced by a later
'@
$serverInjection = $serverInjection.Replace("`r`n", "`n").Replace("`r", "`n")
$text = Replace-Required -Source $text -Needle $serverInjectionNeedle -Replacement $serverInjection -Description 'disposable migration injection point'

# Preserve interactive sudo/PTY behavior while bounding abandoned previews.
$text = Replace-Required -Source $text -Needle "bash '`$remoteServer' '`$CandidateSha' '`$PreviewPort' '`$PreviewEmail' '`$ApprovedRef'" -Replacement "timeout --foreground --signal=TERM 28800s bash '`$remoteServer' '`$CandidateSha' '`$PreviewPort' '`$PreviewEmail' '`$ApprovedRef'" -Description 'interactive remote source-only preview invocation'
$text = Replace-Required -Source $text -Needle '& ssh -t -L "${PreviewPort}:127.0.0.1:${PreviewPort}" $Server $remoteCommand' -Replacement '& ssh -tt -o ServerAliveInterval=15 -o ServerAliveCountMax=3 -L "${PreviewPort}:127.0.0.1:${PreviewPort}" $Server $remoteCommand' -Description 'source-only SSH tunnel invocation'

$text = $text.Replace('SETUP SOURCE-ONLY BROWSER PREVIEW', 'SETUP RESOURCE CATALOG V0.3.10 BROWSER PREVIEW')
$text = $text.Replace('SETUP SOURCE-ONLY BROWSER REVIEW READY', 'SETUP RESOURCE CATALOG V0.3.10 BROWSER REVIEW READY')

Write-Host 'Issue #152 Resource Catalog V0.3.10 browser acceptance checklist:'
Write-Host '  0. Confirm the header shows Client V0.3.10 and the terminal reports Issue #152 migration PASS on the disposable clone.'
Write-Host '  1. Open a reusable task that already has Equipment / Resources. Confirm its current assignments still appear with quantity and REQUIRED/PREFERRED state.'
Write-Host '  2. In Add existing equipment/resource, search for part of a known name such as ladder, boom, sling, or stake. Confirm the active-resource list filters immediately and reports the result count.'
Write-Host '  3. Clear that search. Confirm the active catalog list returns and an already-assigned resource is still marked as already on task.'
Write-Host '  4. In Manage reusable resource catalog, search by name and by type. Confirm inactive entries are included in this Manager catalog and the result count is clear.'
Write-Host '  5. Exercise Browse sort: Catalog display order, Name, Type then name, and Active first. Confirm each produces a predictable ordering.'
Write-Host '  6. Pick one disposable-clone resource with an existing task assignment. Rename it and save. Confirm the resource ID stays the same and the task assignment immediately shows the new name.'
Write-Host '  7. Change that resource display order and save. Confirm Catalog display order sort reflects the change without altering task quantity/REQUIRED/PREFERRED values.'
Write-Host '  8. Mark that same resource inactive. Confirm it disappears from Add existing resource for new assignment, remains discoverable in Manager catalog, and its existing task relationship remains visible/removable.'
Write-Host '  9. Reactivate the resource in the disposable clone and confirm it returns to the active assignment picker.'
Write-Host ' 10. In Create New Catalog Resource, type an existing name with different case or repeated/outer spaces. Confirm Setup directs you to the existing resource instead of creating a duplicate.'
Write-Host ' 11. Type a partial/near-duplicate new name. Confirm Possible existing catalog matches are shown before creation.'
Write-Host ' 12. Create one clearly disposable unique resource, search for it, then edit its type/notes/order. Confirm catalog editing works independently from task-specific assignment fields.'
Write-Host ' 13. Confirm normal reusable task editing, prerequisites, and resource assignment/removal still operate without unexpected layout or authorization changes.'
Write-Host
Write-Host 'All writes in this checklist are against the disposable Production clone only. Production remains unchanged.'
Write-Host

$script = [scriptblock]::Create($text)
& $script -Server $Server -PreviewPort $PreviewPort -PreviewEmail $PreviewEmail
