# Functions-only disposable shortcut validation with a COM double; no real desktop/registry.
$ErrorActionPreference='Stop'
$tokens=$null; $errors=$null
$ast=[Management.Automation.Language.Parser]::ParseFile((Join-Path $PSScriptRoot 'Install-LOR2PC-Launcher.ps1'),[ref]$tokens,[ref]$errors)
if ($errors.Count) { throw 'Installer syntax error' }
foreach ($name in @('Get-MSBLaunchArguments','Install-MSBDesktopShortcut')) {
    $fn=$ast.FindAll({param($n) $n -is [Management.Automation.Language.FunctionDefinitionAst] -and $n.Name -eq $name},$true)[0]
    . ([scriptblock]::Create($fn.Extent.Text))
}
$script:created=0
$script:link=[pscustomobject]@{TargetPath='';Arguments='';WorkingDirectory='';IconLocation='';Description=''}
$script:link | Add-Member ScriptMethod Save { [IO.File]::WriteAllText($script:savedPath,($this | ConvertTo-Json)) }
$script:shell=[pscustomobject]@{}
$script:shell | Add-Member ScriptMethod CreateShortcut {param($path) $script:created++; $script:savedPath=$path; return $script:link}
function New-Object {param($ComObject) if($ComObject -ne 'WScript.Shell'){throw 'Unexpected COM request'};return $script:shell}
$root=Join-Path ([IO.Path]::GetTempPath()) ('msb-shortcut-'+[guid]::NewGuid().ToString('N'))
try {
    $desktop=Join-Path $root 'Redirected Desktop'
    [void][IO.Directory]::CreateDirectory($desktop)
    $installed=Join-Path $root 'User Space/Update_MSB_Previews.ps1'
    $power=Join-Path $root 'Windows PowerShell/powershell.exe'
    $icon=Join-Path $root 'Tree Icon.ico'
    Install-MSBDesktopShortcut -PowerShellPath $power -InstalledScript $installed -Desktop $desktop -IconPath $icon
    $result=Get-Content -LiteralPath (Join-Path $desktop 'MSB PC Preview Updater.lnk') -Raw | ConvertFrom-Json
    if ($result.TargetPath -ne $power -or $result.Arguments -ne (Get-MSBLaunchArguments $installed)) {throw 'Wrong executable/arguments'}
    if ($result.Arguments -notmatch '-AuditOnly$' -or $result.Arguments -notlike '*-File "*"*') {throw 'Comparison-only quoting lost'}
    if ($result.IconLocation -ne ($icon+',0')) {throw 'Icon mismatch'}
    Install-MSBDesktopShortcut -PowerShellPath $power -InstalledScript $installed -Desktop $desktop -IconPath $icon -ApplyEnabled $true
    if ($script:link.Arguments -match '-AuditOnly' -or $script:link.Arguments -ne (Get-MSBLaunchArguments -InstalledScript $installed -ApplyEnabled $true)) {throw 'Explicit apply mode not reflected in fixed launch command'}
    $blocked=$false
    try {Install-MSBDesktopShortcut -PowerShellPath $power -InstalledScript $installed -Desktop (Join-Path $root 'missing') -IconPath $icon} catch {$blocked=$true}
    if (-not $blocked -or $script:created -ne 2) {throw 'Missing desktop did not block before COM'}
    Write-Host 'PASS: shortcut uses redirected Desktop, shared fixed quoted command, explicit audit/apply modes and tree icon; missing Desktop blocks (COM double only)'
} finally {if([IO.Directory]::Exists($root)){[IO.Directory]::Delete($root,$true)}}
