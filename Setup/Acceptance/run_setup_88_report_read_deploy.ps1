param([string]$Server = 'msbadmin@192.168.5.9', [switch]$PreflightOnly)
$ErrorActionPreference = 'Stop'
$repo = (git rev-parse --show-toplevel).Trim()
if ($LASTEXITCODE -ne 0) { throw 'Run from the MSB repository.' }
$branch = (git -C $repo branch --show-current).Trim()
if ($LASTEXITCODE -ne 0 -or $branch -ne 'main') { throw 'Run from merged main.' }
$dirty = git -C $repo status --porcelain
if ($LASTEXITCODE -ne 0 -or $dirty) { throw 'STOP: preserve local changes first.' }
$grantTarget = '6b04d1afff67e2b79a068316198ee7ad95a635f7' # Exact accepted migration/clone-artifact commit.
& git -C $repo merge-base --is-ancestor $grantTarget HEAD
if ($LASTEXITCODE -ne 0) { throw 'STOP: main does not contain the accepted read prerequisite.' }
$bundleName = 'msb-setup-88-read-' + (Get-Date -Format 'yyyyMMdd-HHmmss')
$bundle = Join-Path ([System.IO.Path]::GetTempPath()) $bundleName
$remote = "/tmp/$bundleName"
try {
    New-Item -ItemType Directory -Path $bundle | Out-Null
    # Git's Windows clean filter can hash a clean mixed-EOL file differently
    # from its stored blob. Existing Python reads the blob as bytes, verifies
    # its identity, compares normalized local content, and packages committed LF.
    & python (Join-Path $repo 'Setup/Acceptance/setup_88_report_transport.py') $repo $bundle
    if ($LASTEXITCODE -ne 0) { throw 'STOP: committed runner packaging failed before server contact.' }
    Write-Host 'Authority: Server Management — Production_Database_Change_Deployment_Runbook.md'
    Write-Host 'Disposable clone test first; grant SELECT on only Container type ID/name under maintenance; then install the approved report.'
    Write-Host 'Finish preview CLEAN EXIT. This chat owns the deployment; do not use the maintenance dashboard during this run.'
    Write-Host 'Pause Setup edits during the final report source change so preservation checks can compare unchanged data.'
    $mode = '--deploy'
    if ($PreflightOnly) { $mode = '' }
    & scp -r $bundle "$($Server):/tmp/"
    if ($LASTEXITCODE -ne 0) { throw 'STOP: transfer failed before deployment.' }
    # Foreground SSH owns password/sudo input. Retain server reports; remove only
    # these transported Python files after the bounded foreground run finishes.
    $command = "sudo -v && timeout --foreground --signal=TERM 2400s python3 '$remote/setup_88_report_read_deploy.py' $mode; result=`$?; rm -f '$remote/setup_88_report_read_deploy.py' '$remote/setup_maintenance_deploy.py' '$remote/setup_88_report_source_only_deploy.py'; rm -rf '$remote/__pycache__'; rmdir '$remote'; exit `$result"
    & ssh -tt -o ServerAliveInterval=15 -o ServerAliveCountMax=3 $Server $command
    if ($LASTEXITCODE -ne 0) { throw 'STOP: inspect retained server journal; do not rerun or change maintenance.' }
} finally {
    Remove-Item -LiteralPath $bundle -Recurse -Force -ErrorAction SilentlyContinue
}
