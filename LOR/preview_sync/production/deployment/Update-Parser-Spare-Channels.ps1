# #299: preserve SPARE masters when channel Names change during setup.
# Replaces the parser only. Does not publish, ingest or edit master previews.
[CmdletBinding()]
param([Parameter(Mandatory=$true)][ValidatePattern('^[a-f0-9]{40}$')][string]$CandidateCommit)
$ErrorActionPreference='Stop'
Set-StrictMode -Version Latest
$repo='C:\MSB_LORRunner'
$prefix='Docs/01_LOR_System/02_Data_Extraction/Parser/'
$modules=ConvertFrom-Json '[{"name": "parse_props_v7_scene_parser.py", "old": ["4beb9985fb33f476c9e20ce02fff7eb2e81b66a64a2dc6ceb45a1b4e6f998945", "18cf65990609ccf180f62db3bdc8ef781e40a96e89bc8ac45324d963eac60bc0"], "new": "1708049f0f0e18195984e821730d71b61a040b59f58e3a5c26dfdd82a102e905"}]'
function Require($value,$reason) { if (-not $value) { throw $reason } }
function Hash($path) { (Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash.ToLowerInvariant() }
Require ($env:COMPUTERNAME -ieq 'PRINT-SERVER') 'Run on PRINT-SERVER'
Require (([Security.Principal.WindowsIdentity]::GetCurrent().Name) -ieq 'PRINT-SERVER\Print Service') 'Use existing Print Service account'
$prior=@{}
foreach ($module in $modules) {
    $actual=Hash (Join-Path $repo ($prefix+$module.name))
    Require ($actual -in (@($module.old)+@($module.new))) ('Installed source differs: '+$module.name+' SHA256='+$actual)
    $prior[$module.name]=$actual
}
if (@($modules | Where-Object {$prior[$_.name] -ne $_.new}).Count -eq 0) { Write-Host 'PASS: parser SPARE correction already installed.';return }
$taskName='MSB LOR Operator Runner';$task=Get-ScheduledTask -TaskName $taskName
Require ($task.Principal.UserId -in @('Print Service','PRINT-SERVER\Print Service')) 'Task identity changed'
Require ($task.Principal.LogonType -eq 'Password' -and $task.Principal.RunLevel -eq 'Highest') 'Task configuration changed'
Require ($task.Actions[0].WorkingDirectory -ieq $repo -and $task.Actions[0].Arguments.Contains('C:\MSB_LORRunner\run_lor_runner.ps1')) 'Unexpected task launcher'
$taskBefore=Export-ScheduledTask -TaskName $taskName
$private=Join-Path $env:LOCALAPPDATA 'MSB\LORRunner'
$tokenPath=Join-Path $private 'runner-token.dpapi';$tokenHash=Hash $tokenPath
$report=Join-Path $private ('parser-spare-fix-'+[Guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $report | Out-Null
$acl=[Security.AccessControl.DirectorySecurity]::new();$acl.SetAccessRuleProtection($true,$false)
foreach ($sid in @([Security.Principal.WindowsIdentity]::GetCurrent().User.Value,'S-1-5-18','S-1-5-32-544')) {
    $acl.AddAccessRule([Security.AccessControl.FileSystemAccessRule]::new([Security.Principal.SecurityIdentifier]::new($sid),'FullControl','ContainerInherit,ObjectInherit','None','Allow'))
}
Set-Acl -LiteralPath $report -AclObject $acl
$zip=Join-Path $report 'candidate.zip'
$paths=@($modules | ForEach-Object {$prefix+$_.name})+@($prefix+'test_spare_channel_authoring.py')
& git.exe -C $repo -c core.autocrlf=false -c core.eol=lf archive --format=zip "--output=$zip" $CandidateCommit @paths
Require ($LASTEXITCODE -eq 0) 'Exact committed source unavailable'
$stage=Join-Path $report 'stage';Expand-Archive -LiteralPath $zip -DestinationPath $stage
foreach ($module in $modules) { Require ((Hash (Join-Path $stage ($prefix+$module.name))) -eq $module.new) ('Staged checksum mismatch: '+$module.name) }
& (Join-Path $repo '.venv\Scripts\python.exe') -B (Join-Path $stage ($prefix+'test_spare_channel_authoring.py'))
Require ($LASTEXITCODE -eq 0) 'Disposable rollover checks failed; nothing installed'
foreach ($module in $modules) {
    $target=Join-Path $repo ($prefix+$module.name);$backup=Join-Path $report ($module.name+'.before')
    Copy-Item -LiteralPath $target -Destination $backup
    Require ((Hash $backup) -eq $prior[$module.name]) 'Backup differs'
}
Write-Host "Backup/report: $report"
$launcher=Join-Path $repo 'run_lor_runner.ps1'
& powershell.exe -NoProfile -ExecutionPolicy Bypass -File $launcher -Action Stop -DeploymentProfile PrintServerUnattended
Require ($LASTEXITCODE -eq 0) 'Managed Stop failed; retain report'
try {
    foreach ($module in $modules) {
        $target=Join-Path $repo ($prefix+$module.name)
        Require ((Hash $target) -eq $prior[$module.name]) 'Runtime changed after staging'
        Copy-Item -LiteralPath (Join-Path $stage ($prefix+$module.name)) -Destination $target -Force
        Require ((Hash $target) -eq $module.new) 'Installed checksum mismatch'
    }
    Require ((Hash $tokenPath) -eq $tokenHash -and (Export-ScheduledTask -TaskName $taskName) -ceq $taskBefore) 'Task or pairing changed'
    Start-ScheduledTask -TaskName $taskName
    Start-Sleep -Seconds 3
    & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $launcher -Action Status -DeploymentProfile PrintServerUnattended
    Require ($LASTEXITCODE -eq 0) 'Runner status verification failed'
    Write-Host 'PASS: parser V7.0.12 installed; renamed SPARE masters and explicit child links preserved. No parser, ingest or publication performed.'
} catch {
    $failure=$_
    & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $launcher -Action Stop -DeploymentProfile PrintServerUnattended
    Require ($LASTEXITCODE -eq 0) 'Rollback HOLD: managed Stop failed'
    foreach ($module in $modules) {
        $target=Join-Path $repo ($prefix+$module.name);$backup=Join-Path $report ($module.name+'.before')
        Require ((Hash $target) -in @($prior[$module.name],$module.new)) 'Rollback HOLD: runtime changed independently'
        Require ((Hash $backup) -eq $prior[$module.name]) 'Rollback HOLD: backup changed'
        Copy-Item -LiteralPath $backup -Destination $target -Force
    }
    Start-ScheduledTask -TaskName $taskName
    throw "Rollover update failed; prior modules restored. Retain $report. $failure"
}
