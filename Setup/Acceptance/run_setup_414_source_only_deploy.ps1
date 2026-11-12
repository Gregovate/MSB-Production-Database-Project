param([string]$Server = 'msbadmin@192.168.5.9')
$ErrorActionPreference = 'Stop'
$repo = 'C:\Users\Greg\Github\MSB-Production-Database-Project'
$target = 'ec6d3f0e6a6a1cd69dd60256dcb7f76699e07910'
$mergedFix = 'bcebcedde6c8043d00e26d1c3f72a244a338f76f'
if (-not (Test-Path $repo)) { throw 'STOP: Office PC primary checkout missing.' }
Set-Location $repo
$branch = (git branch --show-current).Trim()
if ($LASTEXITCODE -ne 0 -or $branch -ne 'main') { throw 'STOP: Office PC primary checkout must be on main.' }
$dirty = @(git status --porcelain)
if ($LASTEXITCODE -ne 0 -or $dirty.Count -gt 0) { throw 'STOP: Preserve local primary checkout changes; runner requires clean main.' }
git fetch origin '+refs/heads/main:refs/remotes/origin/main'
if ($LASTEXITCODE -ne 0) { throw 'STOP: Cannot fetch main.' }
git pull --ff-only origin main
if ($LASTEXITCODE -ne 0) { throw 'STOP: Main cannot fast-forward.' }
git merge-base --is-ancestor $mergedFix HEAD
if ($LASTEXITCODE -ne 0) { throw 'STOP: Approved PR414 not on main.' }
git merge-base --is-ancestor $target HEAD
if ($LASTEXITCODE -ne 0) { throw 'STOP: Reviewed source release not on main.' }
$names = @('setup_414_source_only_deploy.py', 'setup_305_source_only_deploy.py')
$bundleName = 'msb-setup-414-' + (Get-Date -Format 'yyyyMMdd-HHmmss')
$bundle = Join-Path ([System.IO.Path]::GetTempPath()) $bundleName
$remote = '/tmp/' + $bundleName
$utf8 = [System.Text.UTF8Encoding]::new($false)
try {
    New-Item -ItemType Directory -Path $bundle -ErrorAction Stop | Out-Null
    foreach ($name in $names) {
        $relative = 'Setup/Acceptance/' + $name
        $committed = (git rev-parse "HEAD:$relative").Trim()
        if ($LASTEXITCODE -ne 0) { throw "STOP: Cannot resolve $name" }
        $localPath = Join-Path $repo ('Setup\Acceptance\' + $name)
        $localBlob = (git hash-object --path=$relative $localPath).Trim()
        if ($LASTEXITCODE -ne 0 -or $committed -ne $localBlob) { throw "STOP: $name differs from committed Git source" }
        $text = [System.IO.File]::ReadAllText($localPath).Replace("`r`n", "`n").Replace("`r", "`n")
        [System.IO.File]::WriteAllText((Join-Path $bundle $name),$text,$utf8)
    }
    Write-Host 'Authority: MSB-Server-Management / Setup_Source_Only_Application_Deployment_Runbook.md'
    Write-Host "Source-only PR414 release; no migration or maintenance switch. Target: $target"
    & scp -r $bundle "$($Server):/tmp/"
    if ($LASTEXITCODE -ne 0) { throw 'STOP: Transport failed.' }
    $command = "sudo -v && timeout --foreground --signal=TERM 1200s python3 '$remote/setup_414_source_only_deploy.py'; result=`$?; rm -f '$remote/setup_414_source_only_deploy.py' '$remote/setup_305_source_only_deploy.py'; rmdir '$remote'; exit `$result"
    & ssh -tt -o ServerAliveInterval=15 -o ServerAliveCountMax=3 $Server $command
    if ($LASTEXITCODE -ne 0) { throw 'STOP: Inspect retained Production deployment report. Do not rerun.' }
    Write-Host 'PASS: PR414 source-only deployment completed; check protected Setup browser.' -ForegroundColor Green
} finally {
    Remove-Item -LiteralPath $bundle -Recurse -Force -ErrorAction SilentlyContinue
}
