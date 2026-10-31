# #81/#299: replace only preview_catalog.py, retaining protected catalog history.
# No parser/ingest, master write, catalog publish, Linux change or PC installation.
[CmdletBinding()]
param([Parameter(Mandatory=$true)][ValidatePattern('^[a-f0-9]{40}$')][string]$CandidateCommit)
$ErrorActionPreference='Stop'
Set-StrictMode -Version Latest
$repo='C:\MSB_LORRunner'
$relative='Docs/01_LOR_System/02_Data_Extraction/Parser/preview_catalog.py'
$target=Join-Path $repo $relative
$expectedOld='c6ced490b1c84582fa52553c8126b4c2e30c1df77517e21b7f8e8e3c4e056716'
$expectedNew='06b600aa45db8dc848ae01513159029e1363229196aeeeaf466a46136fcefe01'
$taskName='MSB LOR Operator Runner'
function Require($value,$reason) { if (-not $value) { throw $reason } }
function Hash($path) { (Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash.ToLowerInvariant() }
Require ($env:COMPUTERNAME -ieq 'PRINT-SERVER') 'Run on PRINT-SERVER'
Require (([Security.Principal.WindowsIdentity]::GetCurrent().Name) -ieq 'PRINT-SERVER\Print Service') 'Use existing Print Service account'
Require ((Hash $target) -in @($expectedOld,$expectedNew)) 'Installed catalog source differs; no replacement'
if ((Hash $target) -eq $expectedNew) { Write-Host 'Image-aware catalog source is already installed.'; return }
$task=Get-ScheduledTask -TaskName $taskName
Require ($task.Principal.UserId -in @('Print Service','PRINT-SERVER\Print Service')) 'Task identity changed'
Require ($task.Principal.LogonType -eq 'Password' -and $task.Principal.RunLevel -eq 'Highest') 'Task configuration changed'
Require ($task.Actions[0].WorkingDirectory -ieq $repo -and $task.Actions[0].Arguments.Contains('C:\MSB_LORRunner\run_lor_runner.ps1')) 'Unexpected task launcher'
$taskBefore=Export-ScheduledTask -TaskName $taskName
$private=Join-Path $env:LOCALAPPDATA 'MSB\LORRunner'
$tokenPath=Join-Path $private 'runner-token.dpapi';$tokenHash=Hash $tokenPath
$report=Join-Path $private ('catalog-policy-'+[Guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $report | Out-Null
$acl=[Security.AccessControl.DirectorySecurity]::new();$acl.SetAccessRuleProtection($true,$false)
foreach ($sid in @([Security.Principal.WindowsIdentity]::GetCurrent().User.Value,'S-1-5-18','S-1-5-32-544')) {
    $acl.AddAccessRule([Security.AccessControl.FileSystemAccessRule]::new([Security.Principal.SecurityIdentifier]::new($sid),'FullControl','ContainerInherit,ObjectInherit','None','Allow'))
}
Set-Acl -LiteralPath $report -AclObject $acl
$zip=Join-Path $report 'candidate.zip'
& git.exe -C $repo -c core.autocrlf=false -c core.eol=lf archive --format=zip "--output=$zip" $CandidateCommit $relative
Require ($LASTEXITCODE -eq 0) 'Exact committed source unavailable'
$stage=Join-Path $report 'stage';Expand-Archive -LiteralPath $zip -DestinationPath $stage
$candidate=Join-Path $stage $relative
Require ((Hash $candidate) -eq $expectedNew) 'Staged catalog checksum mismatch'
& (Join-Path $repo '.venv\Scripts\python.exe') -B -c 'import ast,pathlib,sys;ast.parse(pathlib.Path(sys.argv[1]).read_bytes())' $candidate
Require ($LASTEXITCODE -eq 0) 'Candidate syntax failed'
$backup=Join-Path $report 'preview_catalog.py.before'
Copy-Item -LiteralPath $target -Destination $backup
Require ((Hash $backup) -eq $expectedOld) 'Backup checksum mismatch'
Write-Host "Backup/report: $report"
$launcher=Join-Path $repo 'run_lor_runner.ps1'
# The existing managed Stop refuses while parser/ingest is running and verifies
# the owned listener is gone. Do not kill arbitrary processes or re-register task.
& powershell.exe -NoProfile -ExecutionPolicy Bypass -File $launcher -Action Stop -DeploymentProfile PrintServerUnattended
Require ($LASTEXITCODE -eq 0) 'Managed Stop failed; retain report'
try {
    Require ((Hash $target) -eq $expectedOld) 'Runtime changed after staging'
    Copy-Item -LiteralPath $candidate -Destination $target -Force
    Require ((Hash $target) -eq $expectedNew) 'Installed checksum mismatch'
    Require ((Hash $tokenPath) -eq $tokenHash -and (Export-ScheduledTask -TaskName $taskName) -ceq $taskBefore) 'Task or pairing changed'
    Start-ScheduledTask -TaskName $taskName
    Start-Sleep -Seconds 3
    & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $launcher -Action Status -DeploymentProfile PrintServerUnattended
    Require ($LASTEXITCODE -eq 0) 'Runner status verification failed'
    Write-Host 'PASS: image-aware catalog policy installed. No catalog has been published. Install updater 1.1.2 before publishing a new catalog.'
} catch {
    $failure=$_
    Require ((Hash $target) -in @($expectedOld,$expectedNew)) 'Rollback HOLD: catalog source changed independently'
    Require ((Hash $backup) -eq $expectedOld) 'Rollback HOLD: backup changed'
    & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $launcher -Action Stop -DeploymentProfile PrintServerUnattended
    Require ($LASTEXITCODE -eq 0) 'Rollback HOLD: managed Stop failed'
    Copy-Item -LiteralPath $backup -Destination $target -Force
    Start-ScheduledTask -TaskName $taskName
    throw "Policy update failed; prior module restored and task restarted. Retain $report. $failure"
}
