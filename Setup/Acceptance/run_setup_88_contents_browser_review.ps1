param(
    [Parameter(Mandatory=$true)][string]$CandidateSha,
    [string]$Server = 'msbadmin@192.168.5.9',
    [string]$PreviewEmail = 'gliebig@sheboyganlights.org'
)
$ErrorActionPreference = 'Stop'
# The shared runners verify branch, clean worktree, exact SHA and build identity
# before server contact. All migration/test writes target disposable clones only.
$targetRef = 'docs/171-symbol-type-mapping'
$migrations = @('Setup/Database/070_reconcile_setup_container_contents.sql')
$validations = @('Setup/Acceptance/setup_88_contents_reconciliation_disposable_validation.sql')
# Windows runs the full application suite. Setup/Acceptance also contains Linux
# deployment-tool tests (fcntl/systemd); those are a separate Linux engineering gate.
& python -m pytest -q -p no:cacheprovider Setup/Application
if ($LASTEXITCODE -ne 0) { throw 'STOP: Setup Application regression failed.' }
# The reusable browser runner applies and validates these same SQL files before
# readiness. Keep acceptance and browser review on one clone, with one capture.
& "$PSScriptRoot/run_setup_disposable_browser_preview.ps1" -Server $Server `
    -CandidateSha $CandidateSha -TargetRef $targetRef -PreviewPort 8898 `
    -PreviewEmail $PreviewEmail -ExpectedVersion 'V0.3.60-launch-integration' `
    -MigrationPaths $migrations -ValidationPaths $validations -AllowConcurrentProductionWrites
if ($LASTEXITCODE -ne 0) { throw 'STOP: browser preview failed; retain and inspect the report.' }
