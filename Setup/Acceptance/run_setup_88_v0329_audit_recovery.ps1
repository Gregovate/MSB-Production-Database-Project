param(
    [string]$Server = 'msbadmin@192.168.5.9'
)

$ErrorActionPreference = 'Stop'

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$RepoRoot = (Resolve-Path (Join-Path $ScriptDir '..\..')).Path
$ServerScript = Join-Path $ScriptDir 'setup_88_v0329_audit_recovery_server.sh'

$ExpectedBranch = 'main'
$AcceptedApplicationSha = '7da6828d7b884ee5bb12123dab647bd6fadfba50'

$AuditPath = 'Database/Basic_Query_Tools_Dev/Repair-SetActorOnUpdate-Attribution.sql'
$AuditBlob = '2b848e91f0cc4b926e33156641cf2ceed8e6ccee'
$AuditValidationPath = 'Database/Acceptance/database_shared_audit_actor_disposable_validation.sql'
$AuditValidationBlob = '1e09846734deb02f49a8b94d7614758958c2cc3e'
$MovementValidationPath = 'Setup/Acceptance/setup_88_movement_capture_disposable_validation.sql'
$MovementValidationBlob = 'fc152c305dc0bf7a056aeff60aae3615b06b96d4'
$MigrationPath = 'Setup/Database/065_add_setup_movement_capture.sql'
$MigrationBlob = '2738065a6fc3cb84858e401de5fae9bd6ae35dcc'
$ServerRunnerBlob = 'bea8cc2ed74ebbe57170963c5e09cd59c884326e'

if (-not (Test-Path -LiteralPath $ServerScript -PathType Leaf)) {
    throw "Required #88 audit recovery runner is missing: $ServerScript"
}

$currentBranch = (& git -C $RepoRoot branch --show-current).Trim()
if ($LASTEXITCODE -ne 0 -or $currentBranch -ne $ExpectedBranch) {
    throw "Run this recovery wrapper from merged branch $ExpectedBranch. Current branch: $currentBranch"
}

$dirty = (& git -C $RepoRoot status --porcelain)
if ($LASTEXITCODE -ne 0) {
    throw 'Unable to verify local Git worktree status.'
}
if ($dirty) {
    throw "Local worktree is not clean. Commit/stash/revert local changes before Production recovery. $dirty"
}

& git -C $RepoRoot fetch origin main
if ($LASTEXITCODE -ne 0) {
    throw 'Unable to refresh origin/main before Production recovery.'
}

$localHead = (& git -C $RepoRoot rev-parse HEAD).Trim()
$originMain = (& git -C $RepoRoot rev-parse origin/main).Trim()
if ($LASTEXITCODE -ne 0 -or $localHead -ne $originMain) {
    throw "Local main must exactly match refreshed origin/main before Production recovery. Local=$localHead origin/main=$originMain"
}

& git -C $RepoRoot cat-file -e "${AcceptedApplicationSha}^{commit}"
if ($LASTEXITCODE -ne 0) {
    throw "Accepted V0.3.29 application SHA is not available locally: $AcceptedApplicationSha"
}
& git -C $RepoRoot merge-base --is-ancestor $AcceptedApplicationSha HEAD
if ($LASTEXITCODE -ne 0) {
    throw "Merged main does not contain accepted V0.3.29 application SHA $AcceptedApplicationSha."
}

function Assert-HeadBlob {
    param(
        [Parameter(Mandatory=$true)][string]$Path,
        [Parameter(Mandatory=$true)][string]$ExpectedBlob
    )
    $actual = (& git -C $RepoRoot rev-parse "${localHead}:$Path").Trim()
    if ($LASTEXITCODE -ne 0 -or $actual -ne $ExpectedBlob) {
        throw "Merged-main artifact identity mismatch for $Path. Expected $ExpectedBlob, got '$actual'."
    }
}

Assert-HeadBlob -Path $AuditPath -ExpectedBlob $AuditBlob
Assert-HeadBlob -Path $AuditValidationPath -ExpectedBlob $AuditValidationBlob
Assert-HeadBlob -Path $MovementValidationPath -ExpectedBlob $MovementValidationBlob
Assert-HeadBlob -Path $MigrationPath -ExpectedBlob $MigrationBlob

$serverBlob = (& git -C $RepoRoot hash-object $ServerScript).Trim()
if ($LASTEXITCODE -ne 0 -or $serverBlob -ne $ServerRunnerBlob) {
    throw "Audit recovery server-runner identity mismatch. Expected blob $ServerRunnerBlob, got '$serverBlob'."
}

$backendVersion = ((& git -C $RepoRoot show "${AcceptedApplicationSha}:Setup/Application/production_backend.py") | Out-String)
if ($LASTEXITCODE -ne 0 -or $backendVersion -notmatch 'PRODUCTION_VERSION = "V0\.3\.29-pick-clarity"') {
    throw 'Accepted application SHA does not contain Setup server version V0.3.29-pick-clarity.'
}

$stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$bundleName = "msb-setup-88-audit-recovery-$stamp"
$localBundle = Join-Path ([System.IO.Path]::GetTempPath()) $bundleName
$remoteRoot = "/tmp/$bundleName"
$utf8NoBom = [System.Text.UTF8Encoding]::new($false)
$cr = [string][char]13
$lf = [string][char]10

Write-Host '========== SETUP #88 V0.3.29 AUDIT-PREREQUISITE FORWARD RECOVERY =========='
Write-Host "Server:                   $Server"
Write-Host "Merged-main recovery SHA: $localHead"
Write-Host "Accepted application SHA: $AcceptedApplicationSha"
Write-Host "Audit repair blob:        $AuditBlob"
Write-Host "Audit validation blob:    $AuditValidationBlob"
Write-Host "Movement validation blob: $MovementValidationBlob"
Write-Host "Migration 065 blob:       $MigrationBlob"
Write-Host "Server runner blob:       $ServerRunnerBlob"
Write-Host 'Migration 065 must already be installed and will NOT be reapplied.'
Write-Host 'Scan/Directus is not mutated by this recovery.'
Write-Host 'Authority: Gregovate/MSB-Server-Management — docs/server/Production_Database_Change_Deployment_Runbook.md'
Write-Host 'Authority: Gregovate/MSB-Server-Management — docs/server/Setup_Production_Runtime.md'
Write-Host 'Keep Setup editing paused while the bounded recovery runner is active.'
Write-Host

try {
    New-Item -ItemType Directory -Path $localBundle -Force | Out-Null

    $serverText = [System.IO.File]::ReadAllText($ServerScript)
    $serverText = $serverText.Replace($cr + $lf, $lf).Replace($cr, $lf)
    $localServer = Join-Path $localBundle 'setup_88_v0329_audit_recovery_server.sh'
    [System.IO.File]::WriteAllText($localServer, $serverText, $utf8NoBom)

    if ($serverText.Contains($cr)) {
        throw 'Generated Linux recovery runner contains CR characters; refusing to upload.'
    }

    & scp -r $localBundle "${Server}:/tmp/"
    if ($LASTEXITCODE -ne 0) {
        throw "SCP recovery bundle upload failed with exit code $LASTEXITCODE"
    }

    $remoteScript = "$remoteRoot/setup_88_v0329_audit_recovery_server.sh"
    $remoteCommand = "chmod 700 '$remoteScript' && bash -n '$remoteScript' && timeout --foreground --signal=TERM 3600s bash '$remoteScript' '$localHead'"

    Write-Host
    Write-Host 'Starting bounded Production forward recovery...'
    & ssh -tt -o ServerAliveInterval=15 -o ServerAliveCountMax=3 $Server $remoteCommand
    $remoteExit = $LASTEXITCODE

    if ($remoteExit -ne 0) {
        throw "Setup #88 V0.3.29 audit recovery failed with exit code $remoteExit. Stop and review the retained recovery report before any further mutation."
    }

    Write-Host
    Write-Host 'SETUP #88 V0.3.29 AUDIT-PREREQUISITE FORWARD RECOVERY WRAPPER: PASS'
}
finally {
    if (Test-Path -LiteralPath $localBundle) {
        Remove-Item -LiteralPath $localBundle -Recurse -Force -ErrorAction SilentlyContinue
    }
}
