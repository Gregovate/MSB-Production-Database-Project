param(
    [Parameter(Mandatory=$true)][string]$CandidateSha,
    [string]$Server = 'msbadmin@192.168.5.9',
    [string]$PreviewEmail = 'gliebig@sheboyganlights.org'
)
$ErrorActionPreference = 'Stop'
# The shared runners verify branch, clean worktree, exact SHA and build identity
# before server contact. All migration/test writes target disposable clones only.
$targetRef = 'fix/88-container-contents-reconciliation'
$migrations = @('Setup/Database/070_reconcile_setup_container_contents.sql')
$validations = @('Setup/Acceptance/setup_88_contents_reconciliation_disposable_validation.sql')
# Windows runs the full application suite. Setup/Acceptance also contains Linux
# deployment-tool tests (fcntl/systemd); those are a separate Linux engineering gate.
& python -m pytest -q -p no:cacheprovider Setup/Application
if ($LASTEXITCODE -ne 0) { throw 'STOP: Setup Application regression failed.' }
& "$PSScriptRoot/run_setup_disposable_acceptance.ps1" -Server $Server `
    -CandidateSha $CandidateSha -TargetRef $targetRef -MigrationPaths $migrations `
    -ValidationPaths $validations -AllowConcurrentProductionWrites
if ($LASTEXITCODE -ne 0) { throw 'STOP: disposable acceptance failed; retain and inspect the report.' }
& "$PSScriptRoot/run_setup_disposable_browser_preview.ps1" -Server $Server `
    -CandidateSha $CandidateSha -TargetRef $targetRef -PreviewPort 8898 `
    -PreviewEmail $PreviewEmail -ExpectedVersion 'V0.3.46-container-drop-intent' `
    -MigrationPaths $migrations -ValidationPaths $validations -AllowConcurrentProductionWrites
if ($LASTEXITCODE -ne 0) { throw 'STOP: browser preview failed; retain and inspect the report.' }
