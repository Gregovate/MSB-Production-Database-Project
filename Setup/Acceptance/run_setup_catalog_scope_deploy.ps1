param([string]$Server = 'msbadmin@192.168.5.9', [switch]$PreflightOnly)
$ErrorActionPreference = 'Stop'
$repo = (git rev-parse --show-toplevel).Trim()
if ($LASTEXITCODE -ne 0) { throw 'Run from the MSB repository.' }
$branch = (git -C $repo branch --show-current).Trim()
if ($LASTEXITCODE -ne 0 -or $branch -ne 'main') { throw 'Run from merged main.' }
$dirty = git -C $repo status --porcelain
if ($LASTEXITCODE -ne 0 -or $dirty) { throw 'STOP: preserve local changes first.' }
$acceptedTarget = 'e3c39f2781b5a97648dce1f00965110becd2edd6'
$manifestName = 'setup_catalog_scope_release.json'
$Release = 'CatalogScope'
& git -C $repo merge-base --is-ancestor $acceptedTarget HEAD
if ($LASTEXITCODE -ne 0) { throw 'STOP: main does not contain the accepted Catalog candidate.' }
$bundleName = ('msb-setup-' + $Release + '-') + (Get-Date -Format 'yyyyMMdd-HHmmss')
$bundle = Join-Path ([System.IO.Path]::GetTempPath()) $bundleName
$remote = "/tmp/$bundleName"
try {
    New-Item -ItemType Directory -Path $bundle | Out-Null
    # Git's Windows clean filter can hash a clean mixed-EOL file differently
    # from its stored blob. Existing Python reads the blob as bytes, verifies
    # its identity, compares normalized local content, and packages committed LF.
    & python (Join-Path $repo 'Setup/Acceptance/setup_catalog_scope_transport.py') $repo $bundle
    if ($LASTEXITCODE -ne 0) { throw 'STOP: committed runner packaging failed before server contact.' }
    Write-Host 'Authority: Server Management — Production_Database_Change_Deployment_Runbook.md'
    Write-Host "Accepted release: $Release. Existing controller handles the maintenance boundary; CatalogScope applies no SQL migrations."
    Write-Host 'Finish preview CLEAN EXIT. This chat owns the deployment; do not use the maintenance dashboard during this run.'
    Write-Host 'The maintenance controller blocks writes during installation. No operator pause is required before or after that window.'
    $mode = '--deploy'
    if ($PreflightOnly) { $mode = '' }
    & scp -r $bundle "$($Server):/tmp/"
    if ($LASTEXITCODE -ne 0) { throw 'STOP: transfer failed before deployment.' }
    # Foreground SSH owns password/sudo input. Retain server reports; remove only
    # these transported Python files after the bounded foreground run finishes.
    $command = "sudo -v && timeout --foreground --signal=TERM 2400s python3 '$remote/setup_catalog_scope_deploy.py' '$remote/$manifestName' $mode; result=`$?; rm -f '$remote/setup_catalog_scope_deploy.py' '$remote/setup_required_container_deploy.py' '$remote/setup_maintenance_deploy.py' '$remote/$manifestName'; rm -rf '$remote/__pycache__'; rmdir '$remote'; exit `$result"
    & ssh -tt -o ServerAliveInterval=15 -o ServerAliveCountMax=3 $Server $command
    if ($LASTEXITCODE -ne 0) { throw 'STOP: inspect retained server journal; do not rerun or change maintenance.' }
} finally {
    Remove-Item -LiteralPath $bundle -Recurse -Force -ErrorAction SilentlyContinue
}
