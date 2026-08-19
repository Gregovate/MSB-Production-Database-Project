# FieldWiring Drive Context Resolver Test
# READ ONLY - does not modify SQLite, PostgreSQL, LOR, or Google Drive.

param(
    [string]$SnapshotPath,
    [switch]$AllMasterScenes,
    [string[]]$Scene,
    [string]$DriveRoot = 'G:\Shared drives\Display Folders',
    [string]$OutputDir
)

$ErrorActionPreference = 'Stop'

$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$ScriptPath = Join-Path $PSScriptRoot 'test_drive_context_resolver.py'

if (-not (Test-Path -LiteralPath $ScriptPath)) {
    throw "Resolver test script was not found: $ScriptPath"
}

$VenvPython = Join-Path $RepoRoot '.venv\Scripts\python.exe'
if (Test-Path -LiteralPath $VenvPython) {
    $Python = $VenvPython
}
else {
    $PythonCommand = Get-Command python -ErrorAction SilentlyContinue
    if (-not $PythonCommand) {
        throw 'Python was not found. Activate the repository virtual environment or install Python.'
    }
    $Python = $PythonCommand.Source
}

$Arguments = @(
    $ScriptPath,
    '--drive-root', $DriveRoot
)

if ($SnapshotPath) {
    $Arguments += @('--snapshot', $SnapshotPath)
}

if ($AllMasterScenes) {
    $Arguments += '--all-master-scenes'
}

foreach ($SceneName in $Scene) {
    if ($SceneName) {
        $Arguments += @('--scene', $SceneName)
    }
}

if ($OutputDir) {
    $Arguments += @('--output-dir', $OutputDir)
}

Write-Host ''
Write-Host 'Running read-only FieldWiring Drive resolver test...'
Write-Host "Python: $Python"
Write-Host "Drive root: $DriveRoot"
if ($SnapshotPath) {
    Write-Host "Snapshot: $SnapshotPath"
}
else {
    Write-Host 'Snapshot: auto-discovery'
}
Write-Host ''

& $Python @Arguments
$ExitCode = $LASTEXITCODE

if ($ExitCode -eq 0) {
    Write-Host ''
    Write-Host 'Resolver test completed with all tested cases RESOLVED.'
}
elif ($ExitCode -eq 2) {
    Write-Host ''
    Write-Warning 'Resolver test completed, but one or more cases are UNRESOLVED. Review the generated report; do not treat this as a script failure.'
}
else {
    Write-Host ''
    Write-Error "Resolver test failed to run correctly (exit code $ExitCode)."
}

exit $ExitCode
