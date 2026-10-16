param([string]$Server = 'msbadmin@192.168.5.9', [switch]$PreflightOnly)
$ErrorActionPreference = 'Stop'
$repo = (git rev-parse --show-toplevel).Trim()
if ($LASTEXITCODE -ne 0) { throw 'Run from the MSB repository.' }
$branch = (git -C $repo branch --show-current).Trim()
if ($LASTEXITCODE -ne 0 -or $branch -ne 'main') { throw 'Run from merged main.' }
$dirty = git -C $repo status --porcelain
if ($LASTEXITCODE -ne 0 -or $dirty) { throw 'STOP: preserve local changes first.' }
& git -C $repo fetch origin '+refs/heads/main:refs/remotes/origin/main'
if ($LASTEXITCODE -ne 0) { throw 'STOP: main refresh failed.' }
& git -C $repo merge-base --is-ancestor HEAD origin/main
if ($LASTEXITCODE -ne 0) { throw 'STOP: tooling HEAD is not merged into main.' }
& git -C $repo merge-base --is-ancestor '7740498e6602f36c8cdfd384791bbafaab71ee9e' HEAD
if ($LASTEXITCODE -ne 0) { throw 'STOP: accepted release missing from main.' }
$bundleName = 'msb-setup-205-' + [guid]::NewGuid().ToString('N')
$bundle = Join-Path ([System.IO.Path]::GetTempPath()) $bundleName
$remote = "/tmp/$bundleName"
try {
    New-Item -ItemType Directory -Path $bundle | Out-Null
    # Package exact committed LF bytes; local edits fail before server contact.
    & python (Join-Path $repo 'Setup/Acceptance/setup_205_estimates_transport.py') $repo $bundle
    if ($LASTEXITCODE -ne 0) { throw 'STOP: committed runner packaging failed.' }
    Write-Host 'Authority: MSB-Server-Management Production_Database_Change_Deployment_Runbook.md and Production_Database_Maintenance_Mode.md'
    Write-Host 'Procedure: combined database prerequisites and Setup source promotion.'
    Write-Host 'This step: approved #205 075/076 release; ONLINE preparation, then controller freeze, validated rollback snapshot, installation, validation, ONLINE proof.'
    Write-Host 'Do not operate the maintenance dashboard during this run. Failure retains state and reports; do not replay.'
    $mode = '--deploy'
    if ($PreflightOnly) { $mode = '' }
    & scp -r $bundle "$($Server):/tmp/"
    if ($LASTEXITCODE -ne 0) { throw 'STOP: transfer failed before deployment.' }
    # One foreground SSH owns password/sudo input. No pipeline captures it.
    $command = "sudo -v && timeout --foreground --signal=TERM 2400s python3 '$remote/setup_205_estimates_deploy.py' '$remote/setup_205_estimates_release.json' $mode; result=`$?; rm -f '$remote/setup_205_estimates_deploy.py' '$remote/setup_maintenance_deploy.py' '$remote/setup_required_container_deploy.py' '$remote/check_setup_ui_update_date.py' '$remote/setup_205_estimates_release.json'; rm -rf '$remote/__pycache__'; rmdir '$remote'; exit `$result"
    & ssh -tt -o ServerAliveInterval=15 -o ServerAliveCountMax=3 $Server $command
    if ($LASTEXITCODE -ne 0) { throw 'STOP: inspect retained server journal; do not rerun or change maintenance.' }
    if ($PreflightOnly) { Write-Host '#205 PREFLIGHT PASS; Production not deployed.' }
    else { Write-Host '#205 SERVER DEPLOYMENT PASS; retain the printed report and snapshot paths for closeout.' }
} finally {
    Remove-Item -LiteralPath $bundle -Recurse -Force -ErrorAction SilentlyContinue
}
