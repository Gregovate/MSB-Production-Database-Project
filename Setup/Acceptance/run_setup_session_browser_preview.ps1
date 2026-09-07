param(
    [string]$Server = 'msbadmin@192.168.5.9',
    [int]$PreviewPort = 8794,
    [string]$PreviewEmail = 'gliebig@sheboyganlights.org'
)

$ErrorActionPreference = 'Stop'

$impl = Join-Path $PSScriptRoot 'run_setup_session_browser_preview_impl.ps1'
if (-not (Test-Path -LiteralPath $impl)) {
    throw "Setup browser preview implementation is missing: $impl"
}

function Replace-Required {
    param(
        [Parameter(Mandatory=$true)][string]$Source,
        [Parameter(Mandatory=$true)][string]$Needle,
        [Parameter(Mandatory=$true)][string]$Replacement,
        [Parameter(Mandatory=$true)][string]$Description
    )
    if (-not $Source.Contains($Needle)) {
        throw "Setup browser preview wrapper could not find expected $Description."
    }
    return $Source.Replace($Needle, $Replacement)
}

# The implementation contains guarded multiline replacements against an LF-only
# Linux shell template. Normalize it in memory so Windows checkout line endings
# never change launcher behavior.
$text = [System.IO.File]::ReadAllText($impl)
$text = $text.Replace("`r`n", "`n").Replace("`r", "`n")

# Pin the detached application candidate without modifying the larger validated
# implementation file. Launcher-only changes remain outside the candidate.
$candidateSource = "`$CandidateSha = 'c0b6e4342129516f2f9b344acd4331f4e068e23b'"
$candidateReplacement = "`$CandidateSha = '7362c6aece365448f21cb91f4ceebf2752da3375'"
$text = Replace-Required $text $candidateSource $candidateReplacement 'candidate SHA assignment'

$text = Replace-Required \
    $text \
    "Write-Host 'Migrations 008-012 are applied only to that disposable clone.'" \
    "Write-Host 'Migrations 008-014 are applied only to that disposable clone.'" \
    'migration status banner'

# Add the contracts created from the 2026-09-07 Manager acceptance findings.
$testNeedle = '        Setup/Application/test_setup_final_scope_contract.py"'
$testReplacement = '        Setup/Application/test_setup_final_scope_contract.py \`n        Setup/Application/test_setup_browser_acceptance_findings_contract.py"'
$text = Replace-Required $text $testNeedle $testReplacement 'acceptance contract list'

# Extend the generated disposable-server migration declaration block through
# the task-creation correction and Scene field-context read grant.
$migrationNeedle = 'PARK_INFRASTRUCTURE_SEED="$CANDIDATE_WORKTREE/Setup/Database/012_seed_site_infrastructure_review_tasks.sql"'
$migrationReplacement = @'
PARK_INFRASTRUCTURE_SEED="$CANDIDATE_WORKTREE/Setup/Database/012_seed_site_infrastructure_review_tasks.sql"
CREATE_TASK_FIX="$CANDIDATE_WORKTREE/Setup/Database/013_fix_setup_task_creation_command.sql"
SCENE_CONTEXT_GRANT="$CANDIDATE_WORKTREE/Setup/Database/014_grant_setup_scene_field_context_read.sql"
'@
$text = Replace-Required $text $migrationNeedle $migrationReplacement 'migration 012 declaration'

$loopNeedle = '    "$PARK_INFRASTRUCTURE_SEED"; do'
$loopReplacement = @'
    "$PARK_INFRASTRUCTURE_SEED" \
    "$CREATE_TASK_FIX" \
    "$SCENE_CONTEXT_GRANT"; do
'@
$text = Replace-Required $text $loopNeedle $loopReplacement 'disposable migration file loop'

$applyNeedle = @'
psql_test < "$PARK_INFRASTRUCTURE_SEED"
echo "Disposable Setup Command Center/Park Infrastructure seed 012: PASS"
'@
$applyReplacement = @'
psql_test < "$PARK_INFRASTRUCTURE_SEED"
echo "Disposable Setup Command Center/Park Infrastructure seed 012: PASS"
psql_test < "$CREATE_TASK_FIX"
echo "Disposable Setup reusable-task creation correction 013: PASS"
psql_test < "$SCENE_CONTEXT_GRANT"
echo "Disposable Setup Scene/material read grant 014: PASS"
'@
$text = Replace-Required $text $applyNeedle $applyReplacement 'migration apply block'

# After the existing final seed validation, prove the exact Add Task command
# works inside a transaction that is rolled back, then create a preview-only
# parallel Crew A/B work-day example so the scheduling board is testable without
# inventing durable Production history.
$validationNeedle = 'echo "Final Stage/Scene/Command Center/Park Infrastructure validation: PASS"'
$validationReplacement = @'
echo "Final Stage/Scene/Command Center/Park Infrastructure validation: PASS"

echo "--- Disposable Create Reusable Task rollback probe ---"
PROBE_TASK_ID="$(psql_test -qAt <<SQL
BEGIN;
SELECT setup_task_id
FROM ref.create_setup_task(
    '$PREVIEW_EMAIL',
    '[PREVIEW PROBE] Create Reusable Task',
    NULL,
    'WORK',
    99990,
    NULL,
    NULL,
    NULL,
    NULL,
    NULL,
    NULL,
    '[PREVIEW ONLY] rollback probe'
);
ROLLBACK;
SQL
)"
if [[ ! "$PROBE_TASK_ID" =~ ^[0-9]+$ ]]; then
    echo "FAIL: Create Reusable Task rollback probe did not return a task ID: $PROBE_TASK_ID"
    exit 18
fi
PROBE_REMAINS="$(psql_test -qAt -c "SELECT count(*) FROM ref.setup_task WHERE task_name = '[PREVIEW PROBE] Create Reusable Task';")"
if [[ "$PROBE_REMAINS" != "0" ]]; then
    echo "FAIL: Create Reusable Task rollback probe left $PROBE_REMAINS row(s) behind"
    exit 18
fi
echo "Disposable Create Reusable Task rollback probe: PASS"

psql_test <<'SQL'
DO $block$
DECLARE
    v_session_id bigint;
    v_day_id bigint;
    v_fred_session_task_id bigint;
    v_command_center_session_task_id bigint;
BEGIN
    SELECT ss.setup_session_id
      INTO v_session_id
    FROM ops.setup_session ss
    WHERE ss.season_year = 2025;

    IF v_session_id IS NULL THEN
        RAISE EXCEPTION '2025 Setup Session is required for preview scheduling seed';
    END IF;

    INSERT INTO ops.setup_work_day(
        setup_session_id,
        work_date,
        day_status,
        notes
    ) VALUES (
        v_session_id,
        DATE '2025-09-13',
        'PLANNED',
        '[PREVIEW ONLY] Parallel crew scheduling example for browser acceptance.'
    )
    ON CONFLICT (setup_session_id, work_date)
    DO UPDATE SET day_status = EXCLUDED.day_status,
                  notes = EXCLUDED.notes
    RETURNING setup_work_day_id INTO v_day_id;

    SELECT st.setup_session_task_id
      INTO v_fred_session_task_id
    FROM ops.setup_session_task st
    JOIN ref.setup_task t ON t.setup_task_id = st.setup_task_id
    WHERE st.setup_session_id = v_session_id
      AND t.task_name = 'Install Fred''s Stars'
    LIMIT 1;

    SELECT st.setup_session_task_id
      INTO v_command_center_session_task_id
    FROM ops.setup_session_task st
    JOIN ref.setup_task t ON t.setup_task_id = st.setup_task_id
    JOIN ref.stage s ON s.stage_id = t.stage_id
    WHERE st.setup_session_id = v_session_id
      AND s.stage_key = '40'
      AND t.task_name = 'Deliver and Set Up Command Center Trailer'
    LIMIT 1;

    IF v_fred_session_task_id IS NULL OR v_command_center_session_task_id IS NULL THEN
        RAISE EXCEPTION 'Preview scheduling seed could not resolve Fred''s Stars and Command Center tasks';
    END IF;

    INSERT INTO ops.setup_work_day_task(
        setup_work_day_id,
        setup_session_task_id,
        shift_code,
        crew_lane,
        sort_order,
        planned_crew_count
    ) VALUES (
        v_day_id,
        v_fred_session_task_id,
        'MORNING',
        'A',
        10,
        3
    )
    ON CONFLICT (setup_work_day_id, setup_session_task_id)
    DO UPDATE SET shift_code = EXCLUDED.shift_code,
                  crew_lane = EXCLUDED.crew_lane,
                  sort_order = EXCLUDED.sort_order,
                  planned_crew_count = EXCLUDED.planned_crew_count;

    INSERT INTO ops.setup_work_day_task(
        setup_work_day_id,
        setup_session_task_id,
        shift_code,
        crew_lane,
        sort_order,
        planned_crew_count
    ) VALUES (
        v_day_id,
        v_command_center_session_task_id,
        'MORNING',
        'B',
        20,
        NULL
    )
    ON CONFLICT (setup_work_day_id, setup_session_task_id)
    DO UPDATE SET shift_code = EXCLUDED.shift_code,
                  crew_lane = EXCLUDED.crew_lane,
                  sort_order = EXCLUDED.sort_order,
                  planned_crew_count = EXCLUDED.planned_crew_count;

    UPDATE ops.setup_session_task st
       SET execution_status = 'PLANNED',
           planned_date = DATE '2025-09-13'
     WHERE st.setup_session_task_id IN (
         v_fred_session_task_id,
         v_command_center_session_task_id
     );
END
$block$;
SQL
echo "Preview-only 2025-09-13 Morning Crew A/B scheduling example: PASS"
'@
$text = Replace-Required $text $validationNeedle $validationReplacement 'final seed validation marker'

# Add a post-start API assertion proving the Captain material resolver follows
# current Scene -> Display -> Container truth for Fred's Stars.
$procedureGateNeedle = 'echo "Stage 40 + Park Infrastructure task-specific Procedure APIs: PASS"'
$procedureGateReplacement = @'
echo "Stage 40 + Park Infrastructure task-specific Procedure APIs: PASS"

FRED_TASK_ID="$(psql_test -qAt -c "SELECT t.setup_task_id FROM ref.setup_task t JOIN ref.lor_scene ls ON ls.lor_scene_id=t.lor_scene_id WHERE t.task_name='Install Fred''s Stars' AND ls.scene_name='02-Fred''s Stars' LIMIT 1;")"
FRED_CONTEXT="/tmp/setup-preview-fred-context-$STAMP.json"
FRED_CONTEXT_CODE="$(curl -sS -o "$FRED_CONTEXT" -w '%{http_code}' "http://127.0.0.1:$PREVIEW_PORT/api/setup/tasks/$FRED_TASK_ID/field-context?season_year=2025")"
if [[ "$FRED_CONTEXT_CODE" != "200" ]]; then
    echo "FAIL: Fred's Stars field-context API returned HTTP $FRED_CONTEXT_CODE"
    cat "$FRED_CONTEXT" || true
    rm -f "$FRED_CONTEXT"
    exit 28
fi
sudo -u fieldwiring -H /opt/fieldwiring/.venv/bin/python - "$FRED_CONTEXT" <<'PY'
import json
import sys

with open(sys.argv[1], encoding="utf-8") as handle:
    payload = json.load(handle)
displays = payload.get("context", {}).get("displays", [])
if len(displays) != 16:
    raise SystemExit(f"FAIL: Fred's Stars field context should derive 16 Scene Displays; found {len(displays)}")
container_ids = {item.get("container_id") for item in displays}
if container_ids != {63}:
    raise SystemExit(f"FAIL: Fred's Stars Scene Displays should resolve to Container 63; found {sorted(container_ids)}")
if not all(item.get("relationship_source") == "SCENE" for item in displays):
    raise SystemExit("FAIL: Fred's Stars material context was not derived from current Scene membership")
print("Fred's Stars Scene -> 16 Displays -> Container 63 field context: PASS")
PY
rm -f "$FRED_CONTEXT"
'@
$text = Replace-Required $text $procedureGateNeedle $procedureGateReplacement 'task-specific Procedure API gate'

# Make the review guidance tell the operator that the scheduling board has a
# disposable parallel-crew example ready for immediate inspection.
$readyNeedle = 'echo "Review the rolling Schedule board with Morning / Afternoon / All Day and Crew A / B / C lanes."'
$readyReplacement = @'
echo "Review the rolling Schedule board with Morning / Afternoon / All Day and Crew A / B / C lanes."
echo "Preview-only 2025-09-13 Morning includes Crew A (Fred's Stars) and Crew B (Command Center) so parallel scheduling can be tested immediately."
'@
$text = Replace-Required $text $readyNeedle $readyReplacement 'schedule review guidance'

# The implementation normally derives Setup/Acceptance from its own file path.
# Because it is executed from memory here, supply the same directory explicitly.
$literalScriptDir = $PSScriptRoot.Replace("'", "''")
$sourceLine = '$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path'
$replacementLine = "`$ScriptDir = '$literalScriptDir'"
$text = Replace-Required $text $sourceLine $replacementLine 'ScriptDir initialization'

# Normalize again after wrapper-inserted here-strings so generated Linux shell
# content cannot inherit Windows CRLF from this wrapper source.
$text = $text.Replace("`r`n", "`n").Replace("`r", "`n")

$script = [scriptblock]::Create($text)
& $script -Server $Server -PreviewPort $PreviewPort -PreviewEmail $PreviewEmail
