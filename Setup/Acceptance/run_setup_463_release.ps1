param([string]$Server = 'msbadmin@192.168.5.9', [switch]$Deploy)
$ErrorActionPreference = 'Stop'
$repo = (git rev-parse --show-toplevel).Trim()
if ($LASTEXITCODE -ne 0) { throw 'Run from the MSB repository.' }
$branch = (git -C $repo branch --show-current).Trim()
if ($LASTEXITCODE -ne 0) { throw 'Cannot identify release checkout.' }
$dirty = git -C $repo status --porcelain
if ($LASTEXITCODE -ne 0 -or $dirty) { throw 'STOP: preserve local changes first.' }
& git -C $repo fetch origin '+refs/heads/main:refs/remotes/origin/main'
if ($LASTEXITCODE -ne 0) { throw 'STOP: main refresh failed.' }
& git -C $repo merge-base --is-ancestor HEAD origin/main
if ($LASTEXITCODE -ne 0) { throw 'STOP: tooling HEAD is not merged into main.' }
& git -C $repo merge-base --is-ancestor '820b154cd664f0cac0d1d8dfd38e47b4fe19df9c' HEAD
if ($LASTEXITCODE -ne 0) { throw 'STOP: accepted release missing from main.' }
$bundleName = 'msb-release-463-' + [guid]::NewGuid().ToString('N')
$bundle = Join-Path ([System.IO.Path]::GetTempPath()) $bundleName
$remote = "/tmp/$bundleName"
try {
    New-Item -ItemType Directory -Path $bundle | Out-Null
    # Package exact committed LF bytes; local edits fail before server contact.
    & python (Join-Path $repo 'Setup/Acceptance/setup_463_transport.py') $repo $bundle
    if ($LASTEXITCODE -ne 0) { throw 'STOP: committed runner packaging failed.' }
    Write-Host 'Authority: MSB-Server-Management Production_Database_Change_Deployment_Runbook.md and Production_Database_Maintenance_Mode.md'
    Write-Host 'Procedure: four pending migrations, FieldWiring/Setup source and existing Scan validation/deployment.'
    Write-Host 'This step: accepted #171/#88 PR463 release; ONLINE preparation, then controller freeze, validated rollback snapshot, installation, validation, ONLINE proof.'
    Write-Host 'Do not operate the maintenance dashboard during this run. Failure retains state and reports; do not replay.'
    $mode = ''
    if ($Deploy) { $mode = '--deploy' }
    & scp -r $bundle "$($Server):/tmp/"
    if ($LASTEXITCODE -ne 0) { throw 'STOP: transfer failed before deployment.' }
    # One foreground SSH owns password/sudo input. No pipeline captures it.
    $command = "sudo -v && timeout --foreground --signal=TERM 2400s python3 '$remote/setup_463_release.py' '$remote/setup_463_release.json' $mode; result=`$?; rm -f '$remote/setup_463_release.py' '$remote/setup_maintenance_deploy.py' '$remote/setup_463_release.json' '$remote/validate_scan_extension_isolated.sh' '$remote/deploy_scan_extension_issue219.sh' '$remote/scan-candidate.tar' '$remote/scan-index.js'; rm -rf '$remote/__pycache__'; rmdir '$remote'; exit `$result"
    & ssh -tt -o ServerAliveInterval=15 -o ServerAliveCountMax=3 $Server $command
    if ($LASTEXITCODE -ne 0) { throw 'STOP: inspect retained server journal; do not rerun or change maintenance.' }
    if (-not $Deploy) { Write-Host '#463 PREFLIGHT PASS; Production not deployed.' }
    else { Write-Host '#463 SERVER DEPLOYMENT PASS; retain the printed report and snapshot paths for closeout.' }
} finally {
    Remove-Item -LiteralPath $bundle -Recurse -Force -ErrorAction SilentlyContinue
}
