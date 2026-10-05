param([string]$Server = 'msbadmin@192.168.5.9')
$ErrorActionPreference = 'Stop'
$repo = (git rev-parse --show-toplevel).Trim()
if ($LASTEXITCODE -ne 0) { throw 'Run from the MSB repository.' }
if ((git -C $repo branch --show-current).Trim() -ne 'main') { throw 'Run from merged main.' }
if (git -C $repo status --porcelain) { throw 'STOP: local worktree is not clean.' }
$target = '0783b76bfdaa5c794a3922dd5e1e0d37b788a2c9'
& git -C $repo merge-base --is-ancestor $target HEAD
if ($LASTEXITCODE -ne 0) { throw 'STOP: main does not contain approved candidate.' }
$runner = Join-Path $repo 'Setup\Acceptance\setup_301_source_only_deploy.py'
# Git hashes apply repository line-ending rules without decoding native output.
$trackedHash = (git -C $repo rev-parse 'HEAD:Setup/Acceptance/setup_301_source_only_deploy.py').Trim()
if ($LASTEXITCODE -ne 0) { throw 'STOP: committed installer is unavailable.' }
$localHash = (git -C $repo hash-object --path=Setup/Acceptance/setup_301_source_only_deploy.py $runner).Trim()
if ($LASTEXITCODE -ne 0 -or $trackedHash -ne $localHash) { throw 'STOP: installer differs from committed source.' }
$local = [System.IO.File]::ReadAllText($runner, [System.Text.Encoding]::UTF8).Replace("`r", '').TrimEnd()
$bundleName = 'msb-setup-301-' + (Get-Date -Format 'yyyyMMdd-HHmmss')
$bundle = Join-Path ([System.IO.Path]::GetTempPath()) $bundleName
$remote = "/tmp/$bundleName"
try {
    New-Item -ItemType Directory -Path $bundle | Out-Null
    [System.IO.File]::WriteAllText((Join-Path $bundle 'setup_301_source_only_deploy.py'), $local + "`n", (New-Object System.Text.UTF8Encoding($false)))
    Write-Host 'Authority: Server Management — Setup_Source_Only_Application_Deployment_Runbook.md'
    Write-Host 'Approved source-only update: no maintenance or database mutation; restart only msb-setup.service.'
    Write-Host 'Pause Setup edits during this short deployment so read-only preservation checks can compare unchanged data.'
    & scp -r $bundle "$($Server):/tmp/"
    if ($LASTEXITCODE -ne 0) { throw 'STOP: transfer failed before deployment.' }
    # SSH owns the console for password/sudo prompts; no detached SSH or pipeline.
    $command = "sudo -v && timeout --foreground --signal=TERM 1200s python3 '$remote/setup_301_source_only_deploy.py'; result=`$?; rm -f '$remote/setup_301_source_only_deploy.py'; rmdir '$remote'; exit `$result"
    & ssh -tt -o ServerAliveInterval=15 -o ServerAliveCountMax=3 $Server $command
    if ($LASTEXITCODE -ne 0) { throw 'STOP: inspect server report; do not rerun.' }
} finally {
    Remove-Item -LiteralPath $bundle -Recurse -Force -ErrorAction SilentlyContinue
}
