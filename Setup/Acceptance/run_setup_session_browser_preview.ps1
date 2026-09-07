param(
    [string]$Server = 'msbadmin@192.168.5.9',
    [int]$PreviewPort = 8794,
    [string]$PreviewEmail = 'gliebig@sheboyganlights.org'
)

$ErrorActionPreference = 'Stop'

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$RepoRoot = (Resolve-Path (Join-Path $ScriptDir '..\..')).Path
$ServerScript = Join-Path $ScriptDir 'setup_session_browser_preview_server.sh'
$PreviewEntry = Join-Path $ScriptDir 'setup_session_browser_preview_entry.py'
$CleanupServerScript = Join-Path $ScriptDir 'setup_session_browser_preview_cleanup_server.sh'
$ExpectedBranch = 'agent/setup-session-production-foundation'
$CandidateSha = '92110b8ffb06572b746a7599af6a66f45a5a997f'

foreach ($path in @($ServerScript, $PreviewEntry, $CleanupServerScript)) {
    if (-not (Test-Path -LiteralPath $path)) {
        throw "Required Setup browser preview file is missing: $path"
    }
}

if ($PreviewPort -lt 1024 -or $PreviewPort -gt 65535) {
    throw 'PreviewPort must be between 1024 and 65535.'
}
if ($PreviewPort -in @(8055, 8784, 8790, 8792)) {
    throw "PreviewPort $PreviewPort conflicts with a governed production listener."
}
if ($PreviewEmail -notmatch '^[A-Za-z0-9._%+\-]+@[A-Za-z0-9.\-]+$') {
    throw 'PreviewEmail is not a valid email address.'
}

$currentBranch = (& git -C $RepoRoot branch --show-current).Trim()
if ($LASTEXITCODE -ne 0 -or $currentBranch -ne $ExpectedBranch) {
    throw "Run this Setup browser preview from branch $ExpectedBranch. Current branch: $currentBranch"
}

$dirty = (& git -C $RepoRoot status --porcelain)
if ($LASTEXITCODE -ne 0) {
    throw 'Unable to verify local Git worktree status.'
}
if ($dirty) {
    throw 'Local worktree is not clean. Pull/commit/stash/revert before packaging the Setup preview.'
}

& git -C $RepoRoot cat-file -e "${CandidateSha}^{commit}"
if ($LASTEXITCODE -ne 0) {
    throw "Accepted Setup candidate commit is not available locally: $CandidateSha"
}

$localListeners = @(Get-NetTCPConnection -LocalPort $PreviewPort -State Listen -ErrorAction SilentlyContinue)
foreach ($listener in $localListeners) {
    $owner = Get-Process -Id $listener.OwningProcess -ErrorAction SilentlyContinue
    if ($null -eq $owner) {
        continue
    }
    if ($owner.ProcessName -ne 'ssh') {
        throw "Local preview port $PreviewPort is owned by non-SSH process $($owner.ProcessName) PID $($owner.Id). Not stopping it automatically."
    }
    Write-Host "Stopping stale local SSH Setup preview tunnel PID $($owner.Id) on port $PreviewPort"
    Stop-Process -Id $owner.Id -Force
}

$stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$bundleName = "msb-setup-preview-session-$stamp"
$localBundle = Join-Path ([System.IO.Path]::GetTempPath()) $bundleName
$uploadRoot = "/tmp/$bundleName"
$remoteRoot = "/tmp/msb-setup-browser-preview-$stamp"
$utf8NoBom = New-Object System.Text.UTF8Encoding($false)
$browserUrl = "http://127.0.0.1:$PreviewPort/"

function Write-LinuxTextFile {
    param(
        [Parameter(Mandatory=$true)][string]$Source,
        [Parameter(Mandatory=$true)][string]$Destination
    )
    $text = [System.IO.File]::ReadAllText($Source)
    $text = $text.Replace("`r`n", "`n").Replace("`r", "`n")
    [System.IO.File]::WriteAllText($Destination, $text, $utf8NoBom)
}

Write-Host '========== SETUP SESSION BROWSER PREVIEW =========='
Write-Host "Server:        $Server"
Write-Host "Candidate SHA: $CandidateSha"
Write-Host "Browser URL:   $browserUrl"
Write-Host "Preview user:  $PreviewEmail"
Write-Host
Write-Host 'This preview uses a disposable current-production PostgreSQL clone.'
Write-Host 'Production Setup data and the live shared application checkout are not modified.'
Write-Host 'The browser is not auto-opened; wait for SETUP BROWSER REVIEW READY before opening it.'
Write-Host 'Keep this PowerShell window open while reviewing the browser.'
Write-Host 'When finished, return here and press ENTER so the remote trap can clean up.'
Write-Host

try {
    New-Item -ItemType Directory -Path $localBundle -Force | Out-Null
    $localServer = Join-Path $localBundle 'setup_session_browser_preview_server.sh'
    $localEntry = Join-Path $localBundle 'setup_session_browser_preview_entry.py'
    $localCleanup = Join-Path $localBundle 'setup_session_browser_preview_cleanup_server.sh'

    Write-LinuxTextFile -Source $ServerScript -Destination $localServer
    Write-LinuxTextFile -Source $PreviewEntry -Destination $localEntry
    Write-LinuxTextFile -Source $CleanupServerScript -Destination $localCleanup

    $serverText = [System.IO.File]::ReadAllText($localServer)

    # Keep the checked-in server harness reusable while packaging the exact accepted
    # candidate selected above for this browser-review run.
    $targetOld = 'TARGET_SHA="c72644f02b825acb830603fe6b4f7bd48713b681"'
    $targetNew = "TARGET_SHA=`"$CandidateSha`""
    if (-not $serverText.Contains($targetOld)) {
        throw 'Setup browser preview server template no longer contains the expected candidate SHA placeholder.'
    }
    $serverText = $serverText.Replace($targetOld, $targetNew)

    # Include all accepted browser-review contracts in the exact detached-candidate gate.
    $testOld = '        Setup/Application/test_setup_google_doc_index_contract.py'
    $testNew = "        Setup/Application/test_setup_google_doc_index_contract.py \`n        Setup/Application/test_setup_review_usability_contract.py \`n        Setup/Application/test_setup_next_pass_contract.py"
    if (-not $serverText.Contains($testOld)) {
        throw 'Setup browser preview server template no longer contains the expected detached regression list.'
    }
    $serverText = $serverText.Replace($testOld, $testNew)

    # Extend the disposable-clone migration set. Production remains pg_dump + SELECT only.
    $migrationOld = @'
RESOURCE_MIGRATION="$CANDIDATE_WORKTREE/Setup/Database/008_create_setup_resource_management_commands.sql"
[[ -s "$RESOURCE_MIGRATION" ]] || {
    echo "FAIL: accepted Setup candidate is missing migration 008"
    exit 15
}
'@
    $migrationNew = @'
RESOURCE_MIGRATION="$CANDIDATE_WORKTREE/Setup/Database/008_create_setup_resource_management_commands.sql"
NEXT_PASS_MIGRATION="$CANDIDATE_WORKTREE/Setup/Database/009_create_setup_scope_schedule_execution_commands.sql"
REVIEW_CORRECTION_SEED="$CANDIDATE_WORKTREE/Setup/Database/010_seed_2025_stage02_elf_scope_corrections.sql"
for migration_file in "$RESOURCE_MIGRATION" "$NEXT_PASS_MIGRATION" "$REVIEW_CORRECTION_SEED"; do
    [[ -s "$migration_file" ]] || {
        echo "FAIL: accepted Setup candidate is missing required disposable migration/seed: $migration_file"
        exit 15
    }
done
'@
    if (-not $serverText.Contains($migrationOld)) {
        throw 'Setup browser preview server template no longer contains the expected migration declaration block.'
    }
    $serverText = $serverText.Replace($migrationOld, $migrationNew)

    $applyOld = @'
psql_test < "$RESOURCE_MIGRATION"
echo "Disposable Setup resource migration 008: PASS"
'@
    $applyNew = @'
psql_test < "$RESOURCE_MIGRATION"
echo "Disposable Setup resource migration 008: PASS"
psql_test < "$NEXT_PASS_MIGRATION"
echo "Disposable Setup scope/schedule/execution migration 009: PASS"
psql_test < "$REVIEW_CORRECTION_SEED"
echo "Disposable Setup 2025 review corrections 010: PASS"

# Give the Captain/Perform Work screen one intentionally incomplete task in the
# disposable clone. This changes no Production history and makes completion UI
# testable without inventing a permanent 2026 session during browser review.
psql_test <<'SQL'
UPDATE ops.setup_session_task st
SET execution_status = 'READY',
    actual_started_at = NULL,
    actual_completed_at = NULL,
    actual_crew_count = NULL,
    actual_duration_minutes = NULL,
    completion_note = NULL,
    completed_by_person_id = NULL,
    annual_notes = concat_ws(E'\n', nullif(st.annual_notes, ''),
        '[PREVIEW ONLY] Execution reset to READY so Captain completion can be exercised in the disposable browser review.')
FROM ops.setup_session ss, ref.setup_task t
WHERE st.setup_session_id = ss.setup_session_id
  AND st.setup_task_id = t.setup_task_id
  AND ss.season_year = 2025
  AND t.task_name = 'Install Fred''s Stars';

DO $block$
DECLARE
    v_stage02 integer;
    v_mega_scene bigint;
    v_fred_scene bigint;
    v_count integer;
BEGIN
    SELECT stage_id INTO v_stage02 FROM ref.stage WHERE stage_key = '02';
    SELECT lor_scene_id INTO v_mega_scene FROM ref.lor_scene
      WHERE stage_id = v_stage02 AND scene_name = '02-Mega Tree';
    SELECT lor_scene_id INTO v_fred_scene FROM ref.lor_scene
      WHERE stage_id = v_stage02 AND scene_name = '02-Fred''s Stars';

    SELECT count(*) INTO v_count FROM ref.setup_task
      WHERE lor_scene_id = v_mega_scene
        AND task_name IN ('Prepare / Load Light Strings','Erect / Position Mega Tree Structure','Hang and Secure Light Strings','Complete Electrical / Network Connections');
    IF v_count <> 4 THEN
        RAISE EXCEPTION 'Stage 02 Mega Tree Scene should contain four reconstructed tasks; found %', v_count;
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM ref.setup_task t
        JOIN ref.setup_task_resource tr ON tr.setup_task_id = t.setup_task_id
        JOIN ref.setup_resource r ON r.setup_resource_id = tr.setup_resource_id
        WHERE t.lor_scene_id = v_fred_scene
          AND t.task_name = 'Install Fred''s Stars'
          AND t.normal_crew_min = 2 AND t.normal_crew_max = 3
          AND r.resource_name = 'Boom Lift' AND tr.quantity_required = 1
    ) THEN
        RAISE EXCEPTION 'Fred''s Stars browser-review correction is incomplete';
    END IF;

    IF NOT EXISTS (
        SELECT 1
        FROM ref.setup_task scaffold
        JOIN ref.stage s ON s.stage_id = scaffold.stage_id AND s.stage_key = '08'
        JOIN ref.setup_task_dependency d ON d.setup_task_id = scaffold.setup_task_id
        JOIN ref.setup_task locates ON locates.setup_task_id = d.prerequisite_setup_task_id
        WHERE scaffold.task_name = 'Set Scaffold and Elves'
          AND locates.task_name = 'Locates'
    ) THEN
        RAISE EXCEPTION 'Elf Choir Locates prerequisite is missing';
    END IF;
END
$block$;
SQL
echo "Stage/Scene review correction validation: PASS"
'@
    if (-not $serverText.Contains($applyOld)) {
        throw 'Setup browser preview server template no longer contains the expected migration-008 apply block.'
    }
    $serverText = $serverText.Replace($applyOld, $applyNew)

    # Strengthen the least-privilege gate for the new command layer.
    $boundaryNeedle = "    IF has_table_privilege('fieldwiring_app', 'directus_users', 'SELECT') THEN"
    $boundaryInsert = @'
    IF has_table_privilege('fieldwiring_app', 'ops.setup_task_progress', 'INSERT')
       OR has_table_privilege('fieldwiring_app', 'ops.setup_task_progress', 'UPDATE')
       OR has_table_privilege('fieldwiring_app', 'ops.setup_work_day_task', 'INSERT')
       OR has_table_privilege('fieldwiring_app', 'ops.setup_work_day_task', 'UPDATE')
       OR has_table_privilege('fieldwiring_app', 'ref.setup_task_dependency', 'INSERT')
       OR has_table_privilege('fieldwiring_app', 'ref.setup_task_dependency', 'UPDATE') THEN
        RAISE EXCEPTION 'Preview fieldwiring_app unexpectedly has broad V0.2 Setup DML';
    END IF;

    IF NOT has_function_privilege('fieldwiring_app', 'ref.set_setup_task_scope(text,bigint,integer,bigint)', 'EXECUTE')
       OR NOT has_function_privilege('fieldwiring_app', 'ref.set_setup_task_dependency(text,bigint,bigint,text,boolean)', 'EXECUTE')
       OR NOT has_function_privilege('fieldwiring_app', 'ops.upsert_setup_work_day(text,integer,date,text,text)', 'EXECUTE')
       OR NOT has_function_privilege('fieldwiring_app', 'ops.set_setup_work_day_task(text,bigint,bigint,text,integer,integer,boolean)', 'EXECUTE')
       OR NOT has_function_privilege('fieldwiring_app', 'ops.record_setup_task_progress(text,bigint,bigint,text,integer,integer,text,text,boolean)', 'EXECUTE') THEN
        RAISE EXCEPTION 'Preview fieldwiring_app lacks one or more narrow V0.2 Setup commands';
    END IF;

'@
    if (-not $serverText.Contains($boundaryNeedle)) {
        throw 'Setup browser preview server template no longer contains the expected authorization boundary insertion point.'
    }
    $serverText = $serverText.Replace($boundaryNeedle, $boundaryInsert + $boundaryNeedle)

    # Validate the new read surfaces after Flask starts, before telling the operator
    # the browser review is ready.
    $apiNeedle = 'PROCEDURE_CODE="$(curl -sS -o /tmp/setup-preview-procedure-$STAMP.json -w ''%{http_code}'' "http://127.0.0.1:$PREVIEW_PORT/api/setup/procedure?stage_key=04")"'
    $apiInsert = @'
for endpoint in \
    "/api/setup/organization" \
    "/api/setup/schedule?season_year=2025" \
    "/api/setup/execution?season_year=2025"; do
    NEXT_CODE="$(curl -sS -o /tmp/setup-preview-next-$STAMP.json -w '%{http_code}' "http://127.0.0.1:$PREVIEW_PORT$endpoint")"
    if [[ "$NEXT_CODE" != "200" ]]; then
        echo "FAIL: Setup V0.2 API $endpoint returned HTTP $NEXT_CODE"
        cat /tmp/setup-preview-next-$STAMP.json || true
        rm -f /tmp/setup-preview-next-$STAMP.json
        exit 28
    fi
done
rm -f /tmp/setup-preview-next-$STAMP.json
echo "Stage/Scene + Schedule + Captain read APIs: PASS"

'@
    if (-not $serverText.Contains($apiNeedle)) {
        throw 'Setup browser preview server template no longer contains the expected Procedure API insertion point.'
    }
    $serverText = $serverText.Replace($apiNeedle, $apiInsert + $apiNeedle)

    # The preview server performs one post-start JSON validation with the production
    # Python runtime. /opt/fieldwiring is intentionally not traversable by msbadmin,
    # so package that one validator under the fieldwiring runtime account as well.
    $validatorOld = "/opt/fieldwiring/.venv/bin/python - `"`$MEGA_PROCEDURE`" <<'PY'"
    $validatorNew = "sudo -u fieldwiring -H /opt/fieldwiring/.venv/bin/python - `"`$MEGA_PROCEDURE`" <<'PY'"
    if (-not $serverText.Contains($validatorOld)) {
        throw 'Setup browser preview server template no longer contains the expected Mega Cube validator command.'
    }
    $serverText = $serverText.Replace($validatorOld, $validatorNew)

    $readyOld = 'echo "Review the narrower task queue and the Equipment / Resources Needed section."'
    $readyNew = @'
echo "Review Stage/Scene grouping, inline/collapsible gaps, cross-area drag/drop, and Copy destination focus."
echo "Verify prerequisite Add/Remove using Elf Choir Locates -> Set Scaffold and Elves."
echo "Review the lightweight Schedule tab (Morning / Afternoon / All Day; parallel tasks allowed)."
echo "Review Perform Work: Fred''s Stars is PREVIEW-ONLY READY so crew/progress/completion can be exercised."
echo "Perform Work should include the current published Setup Procedure PDF when one resolves."
echo "Material/location context is read-only in this pass; movement/scanning writes remain intentionally absent."
'@
    if (-not $serverText.Contains($readyOld)) {
        throw 'Setup browser preview server template no longer contains the expected review guidance line.'
    }
    $serverText = $serverText.Replace($readyOld, $readyNew)

    [System.IO.File]::WriteAllText($localServer, $serverText, $utf8NoBom)

    & scp -r $localBundle "${Server}:/tmp/"
    if ($LASTEXITCODE -ne 0) {
        throw "SCP Setup browser preview bundle upload failed with exit code $LASTEXITCODE"
    }

    Write-Host
    Write-Host 'Cleaning stale Setup preview state and preparing disposable browser preview...'

    $uploadCleanup = "$uploadRoot/setup_session_browser_preview_cleanup_server.sh"
    $remoteScript = "$remoteRoot/setup_session_browser_preview_server.sh"
    $remoteEntry = "$remoteRoot/setup_session_browser_preview_entry.py"
    $remoteCleanup = "$remoteRoot/setup_session_browser_preview_cleanup_server.sh"
    # Keep a safety ceiling for abandoned previews without cutting off a normal
    # multi-hour operator browser review. Eight hours matches a full review session.
    $remoteCommand = "chmod 700 '$uploadCleanup' && bash -n '$uploadCleanup' && bash '$uploadCleanup' '$PreviewPort' && mv '$uploadRoot' '$remoteRoot' && chmod 755 '$remoteRoot' && chmod 700 '$remoteScript' '$remoteCleanup' && chmod 644 '$remoteEntry' && bash -n '$remoteScript' && timeout --signal=TERM 28800s bash '$remoteScript' '$PreviewPort' '$PreviewEmail'"

    & ssh -tt -L "${PreviewPort}:127.0.0.1:${PreviewPort}" $Server $remoteCommand
    $remoteExit = $LASTEXITCODE

    if ($remoteExit -ne 0) {
        throw "Setup browser preview failed with exit code $remoteExit. Review the remote /tmp/MSB_Setup_Session_Browser_Preview_*.txt report named in the output."
    }

    Write-Host
    Write-Host 'SETUP SESSION BROWSER PREVIEW: CLEAN EXIT'
}
finally {
    if (Test-Path -LiteralPath $localBundle) {
        Remove-Item -LiteralPath $localBundle -Recurse -Force -ErrorAction SilentlyContinue
    }
}
