param(
    [string]$Server = 'msbadmin@192.168.5.9',
    [Parameter(Mandatory=$true)]
    [int]$PreviewPort,
    [string]$PreviewEmail = 'gliebig@sheboyganlights.org'
)

$ErrorActionPreference = 'Stop'

$AcceptedCandidateSha = '48a08578158347ae70aaab916fc73a43b777c7ce'
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
        throw "Setup training preview could not find expected $Description."
    }
    return $Source.Replace($Needle, $Replacement)
}

# Reuse the already-hardened current-Production-clone browser preview machinery.
# This launcher changes only the exact candidate identity and adds migrations
# 019-022 to the disposable clone before the exact candidate application starts.
$text = [System.IO.File]::ReadAllText($BaseWrapper)
$text = $text.Replace("`r`n", "`n").Replace("`r", "`n")

$text = Replace-Required -Source $text -Needle "`$CandidateSha = '51c739bd85115c9f5d2853763e8e1450ac381407'" -Replacement "`$CandidateSha = '$AcceptedCandidateSha'" -Description 'source-only candidate SHA assignment'

# A dynamically compiled wrapper has no reliable MyInvocation path. Pin the
# real Acceptance directory so the base wrapper still resolves its server and
# entry templates from this checkout.
$scriptDirLiteral = $PSScriptRoot.Replace("'", "''")
$text = Replace-Required -Source $text -Needle '$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path' -Replacement "`$ScriptDir = '$scriptDirLiteral'" -Description 'base wrapper ScriptDir initialization'

# Insert one bounded patch into the generated disposable server. The base
# wrapper already restores a current Production dump into an isolated container,
# creates a Production-like fieldwiring_app role, and proves Production/live
# checkout fingerprints remain unchanged. Install only 019-022 into that clone.
$insertNeedle = '    # Any runtime use of /opt/fieldwiring/.venv must execute as the fieldwiring'
$insertBlock = @'
    # Current training/reconstruction candidate needs migrations 019-022 in the
    # disposable current-Production clone before the candidate Flask app starts.
    $migrationNeedle = 'TEST_IP="$(sudo docker inspect "$TEST_CONTAINER" --format ''{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}'')"'
    $migrationBlock = @(
        'echo',
        'echo "--- Apply Setup training/reconstruction migrations to disposable clone only ---"',
        'M019="$CANDIDATE_WORKTREE/Setup/Database/019_add_reconstruction_safe_task_delete.sql"',
        'M020="$CANDIDATE_WORKTREE/Setup/Database/020_add_setup_captain_management_commands.sql"',
        'M021="$CANDIDATE_WORKTREE/Setup/Database/021_add_setup_assigned_reconciliation_state.sql"',
        'M022="$CANDIDATE_WORKTREE/Setup/Database/022_require_active_setup_captain_people.sql"',
        'for migration in "$M019" "$M020" "$M021" "$M022"; do',
        '    if [[ ! -s "$migration" ]]; then',
        '        echo "FAIL: required training/reconstruction migration is missing: $migration"',
        '        exit 11',
        '    fi',
        'done',
        'psql_test < "$M019"',
        'echo "Migration 019 reconstruction-safe delete: PASS"',
        'psql_test < "$M020"',
        'echo "Migration 020 Captain management: PASS"',
        'psql_test < "$M021"',
        'echo "Migration 021 ASSIGNED reconciliation state: PASS"',
        'psql_test < "$M022"',
        'echo "Migration 022 active Captain people: PASS"',
        'echo "Disposable Setup training/reconstruction migrations 019-022: PASS"',
        ''
    ) -join "`n"
    if (-not $serverText.Contains($migrationNeedle)) {
        throw 'Training preview base server no longer contains the disposable database connection insertion point.'
    }
    $serverText = $serverText.Replace($migrationNeedle, $migrationBlock + $migrationNeedle)

'@
$insertBlock = $insertBlock.Replace("`r`n", "`n").Replace("`r", "`n")
$text = Replace-Required -Source $text -Needle $insertNeedle -Replacement ($insertBlock + $insertNeedle) -Description 'training migration patch insertion point'

$text = $text.Replace('SETUP SOURCE-ONLY BROWSER PREVIEW', 'SETUP TRAINING / RECONSTRUCTION BROWSER PREVIEW')
$text = $text.Replace('SETUP SOURCE-ONLY BROWSER REVIEW READY', 'SETUP TRAINING / RECONSTRUCTION BROWSER REVIEW READY')
$text = $text.Replace('source-only preview', 'training/reconstruction preview')
$text = $text.Replace('Source-only preview', 'Training/reconstruction preview')

$script = [scriptblock]::Create($text)
& $script -Server $Server -PreviewPort $PreviewPort -PreviewEmail $PreviewEmail
