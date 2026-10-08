param([string]$Server = 'msbadmin@192.168.5.9', [switch]$PreflightOnly)
$ErrorActionPreference = 'Stop'
$repo = (git rev-parse --show-toplevel).Trim()
if ($LASTEXITCODE -ne 0) { throw 'Run from the MSB repository.' }
$branch = (git -C $repo branch --show-current).Trim()
if ($LASTEXITCODE -ne 0 -or $branch -ne 'main') { throw 'Run from merged main.' }
$dirty = git -C $repo status --porcelain
if ($LASTEXITCODE -ne 0 -or $dirty) { throw 'STOP: preserve local changes first.' }
$grantTarget = '1a59405ef22288c57740d822dcffa7c8d8c6d729' # Frozen pin updated before publication.
& git -C $repo merge-base --is-ancestor $grantTarget HEAD
if ($LASTEXITCODE -ne 0) { throw 'STOP: main does not contain the accepted read prerequisite.' }
$bundleName = 'msb-setup-88-read-' + (Get-Date -Format 'yyyyMMdd-HHmmss')
$bundle = Join-Path ([System.IO.Path]::GetTempPath()) $bundleName
$remote = "/tmp/$bundleName"
$files = @('setup_88_report_read_deploy.py','setup_maintenance_deploy.py','setup_88_report_source_only_deploy.py')
try {
    New-Item -ItemType Directory -Path $bundle | Out-Null
    foreach ($name in $files) {
        $relative = "Setup/Acceptance/$name"
        $path = Join-Path $repo $relative
        $tracked = (git -C $repo rev-parse "HEAD:$relative").Trim()
        if ($LASTEXITCODE -ne 0) { throw "STOP: missing committed file $name" }
        $actual = (git -C $repo hash-object --path=$relative $path).Trim()
        if ($LASTEXITCODE -ne 0 -or $actual -ne $tracked) { throw "STOP: uncommitted file $name" }
        $text = [System.IO.File]::ReadAllText($path, [System.Text.Encoding]::UTF8).Replace("`r", '')
        [System.IO.File]::WriteAllText((Join-Path $bundle $name), $text, (New-Object System.Text.UTF8Encoding($false)))
    }
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
