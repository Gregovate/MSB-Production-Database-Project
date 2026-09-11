param(
    [string]$Server = 'msbadmin@192.168.5.9',
    [Parameter(Mandatory=$true)]
    [int]$PreviewPort,
    [string]$PreviewEmail = 'gliebig@sheboyganlights.org'
)

$ErrorActionPreference = 'Stop'

# Exact V0.3.10 compact resource-picker application/schema candidate for Issue
# #152. Later commits may repair tests or harden acceptance tooling only;
# browser/deployment approval remains pinned to this SHA.
$AcceptedCandidateSha = '17590dc3a3e81dd67e38fcb42ba38e69beeea089'
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

# Add #152-focused contracts that are present inside the frozen runtime
# candidate itself. Later acceptance-tooling tests are intentionally NOT added
# to this detached-candidate regression because they do not exist at the pinned
# runtime SHA; those tests are run from the live review branch before launch.
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

Write-Host 'Issue #152 Resource Catalog V0.3.10 compact-picker browser acceptance checklist:'
Write-Host '  0. Confirm the header shows Client V0.3.10 and the terminal reports Issue #152 migration PASS on the disposable clone.'
Write-Host '  1. Open a reusable task with existing Equipment / Resources. Confirm current assignments still show quantity and REQUIRED/PREFERRED state.'
Write-Host '  2. Confirm the normal task-detail flow shows the compact Resource picker and does NOT show the full catalog editor/create forms by default.'
Write-Host '  3. In the Resource picker, search for part of a known name such as ladder or stake. Confirm the active-resource list filters immediately and is name-oriented so deliberately renamed related items group naturally.'
Write-Host '  4. Select an existing resource, change quantity/requirement if desired, and add/update it. Confirm task-specific values save without opening catalog maintenance.'
Write-Host '  5. Click Manage Resource Catalog. Confirm the full catalog maintenance area opens on demand; click Close Resource Catalog and confirm it collapses again.'
Write-Host '  6. With the catalog manager open, search active and inactive resources. Confirm Name is the practical default browse sort and inactive rows remain discoverable.'
Write-Host '  7. Rename one disposable-clone resource that already has a task assignment. Confirm its setup_resource_id stays the same and the task immediately shows the new name.'
Write-Host '  8. Confirm Optional display order is clearly secondary/advanced guidance and normal picker ordering is driven by meaningful names.'
Write-Host '  9. Mark that resource inactive. Confirm it disappears from the normal active picker but remains visible in catalog maintenance and on any existing task relationship.'
Write-Host ' 10. Reactivate it and confirm it returns to the normal picker.'
Write-Host ' 11. Try creating an existing name with different case or repeated/outer spaces. Confirm Setup blocks the duplicate and points back to the existing resource.'
Write-Host ' 12. Type a partial/near-duplicate new name. Confirm possible existing catalog matches appear before creation.'
Write-Host ' 13. Create one clearly disposable unique resource, then rename/edit it through catalog maintenance. Confirm catalog maintenance remains independent from task quantity/REQUIRED/PREFERRED fields.'
Write-Host ' 14. Confirm normal reusable task editing, prerequisites, and resource removal still operate without unexpected layout or authorization changes.'
Write-Host
Write-Host 'All writes in this checklist are against the disposable Production clone only. Production remains unchanged.'
Write-Host

$script = [scriptblock]::Create($text)
& $script -Server $Server -PreviewPort $PreviewPort -PreviewEmail $PreviewEmail
