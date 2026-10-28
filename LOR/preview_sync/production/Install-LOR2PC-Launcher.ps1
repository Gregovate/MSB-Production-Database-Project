# Administrator-prepared, per-user launcher installation; no preview writes.
[CmdletBinding()]
param()
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
# MSB standard: every programmer installs LOR with C:\LOR as its data folder.
# This read-only prerequisite runs before copying files or registering a handler.
function Assert-MSBLocalLibrary {
    if (-not (Test-Path -LiteralPath 'C:\LOR\CommonData\LORPreviews.xml' -PathType Leaf)) {
        throw 'MSB requires Light-O-Rama to use C:\LOR as its data folder. Open Light-O-Rama once with that data folder, then close it and run Setup MSB PC Preview Updater.vbs again. Required file: C:\LOR\CommonData\LORPreviews.xml. No updater was installed.'
    }
}
function Get-MSBLaunchArguments {
    param([string]$InstalledScript, [bool]$ApplyEnabled = $false)
    $arguments = '-NoLogo -NoProfile -ExecutionPolicy Bypass -STA -WindowStyle Hidden -File "' + $InstalledScript + '"'
    if (-not $ApplyEnabled) { $arguments += ' -AuditOnly' }
    return $arguments
}

function Install-MSBDesktopShortcut {
    param([string]$PowerShellPath, [string]$InstalledScript, [string]$Desktop, [string]$IconPath, [bool]$ApplyEnabled = $false)
    # Resolve the real per-user Desktop (including Windows folder redirection).
    if ([string]::IsNullOrWhiteSpace($Desktop) -or -not (Test-Path -LiteralPath $Desktop -PathType Container)) {
        throw 'Your Windows Desktop folder is unavailable. Contact the MSB administrator.'
    }
    $shell = New-Object -ComObject WScript.Shell
    $shortcut = $shell.CreateShortcut((Join-Path $Desktop 'MSB PC Preview Updater.lnk'))
    $shortcut.TargetPath = $PowerShellPath
    # Same fixed release-mode command as the browser protocol; never accept URI arguments.
    $shortcut.Arguments = Get-MSBLaunchArguments -InstalledScript $InstalledScript -ApplyEnabled $ApplyEnabled
    $shortcut.WorkingDirectory = [IO.Path]::GetDirectoryName($InstalledScript)
    $shortcut.IconLocation = $IconPath + ',0'
    $shortcut.Description = $(if ($ApplyEnabled) { 'Review and update this PC from accepted MSB previews.' } else { 'Check this PC against accepted MSB previews (comparison only).' })
    $shortcut.Save()
}

try {
    Assert-MSBLocalLibrary
    $source = Join-Path $PSScriptRoot 'Update_MSB_Previews.ps1'
    $metadata = Join-Path $PSScriptRoot 'DEPLOYMENT.json'
    if (-not (Test-Path $metadata)) { throw 'Missing committed-release deployment identity. Administrator preparation is required.' }
    $release = Get-Content $metadata -Raw | ConvertFrom-Json
    if ($release.apply_enabled -isnot [bool]) { throw 'Installer apply permission must be an explicit boolean.' }
    if ($release.version -ne '1.0.9' -or $release.source_commit -notmatch '^[a-f0-9]{40}$' -or
        $release.files.'Update_MSB_Previews.ps1' -ine (Get-FileHash $source -Algorithm SHA256).Hash) { throw 'Updater release identity/hash mismatch.' }
    $destination = Join-Path $env:LOCALAPPDATA ('MSB\LOR2PC\' + $release.source_commit)
    New-Item -ItemType Directory -Path $destination -Force | Out-Null
    foreach ($file in @('Update_MSB_Previews.ps1', 'DEPLOYMENT.json', 'MSB Preview Update Tree v2.ico')) {
        Copy-Item -LiteralPath (Join-Path $PSScriptRoot $file) -Destination $destination -Force
    }
    $installed = Join-Path $destination 'Update_MSB_Previews.ps1'
    if ((Get-FileHash $installed -Algorithm SHA256).Hash -ine $release.files.'Update_MSB_Previews.ps1') { throw 'Installed updater hash mismatch.' }
    $protocol = 'HKCU:\Software\Classes\msb-lor2pc'
    New-Item -Path ($protocol + '\shell\open\command') -Force | Out-Null
    Set-Item -Path $protocol -Value 'URL:MSB PC Preview Update'
    New-ItemProperty -Path $protocol -Name 'URL Protocol' -Value '' -Force | Out-Null
    $powershell = Join-Path $env:SystemRoot 'System32\WindowsPowerShell\v1.0\powershell.exe'
    # Fixed executable/script only: protocol URI input is deliberately ignored.
    Set-Item -Path ($protocol + '\shell\open\command') -Value ('"' + $powershell + '" ' + (Get-MSBLaunchArguments -InstalledScript $installed -ApplyEnabled $release.apply_enabled))
    $icon = Join-Path $destination 'MSB Preview Update Tree v2.ico'
    New-Item -Path ($protocol + '\DefaultIcon') -Force | Out-Null
    Set-Item -Path ($protocol + '\DefaultIcon') -Value ('"' + $icon + '",0')
    Install-MSBDesktopShortcut -PowerShellPath $powershell -InstalledScript $installed -Desktop ([Environment]::GetFolderPath('DesktopDirectory')) -IconPath $icon -ApplyEnabled $release.apply_enabled
    Add-Type -AssemblyName System.Windows.Forms
    [void][Windows.Forms.MessageBox]::Show('MSB PC Preview Updater installed. A shortcut is on your Desktop. No previews were changed.', 'MSB LOR2PC')
} catch {
    Add-Type -AssemblyName System.Windows.Forms
    [void][Windows.Forms.MessageBox]::Show($_.Exception.Message, 'MSB LOR2PC setup blocked')
    exit 2
}
