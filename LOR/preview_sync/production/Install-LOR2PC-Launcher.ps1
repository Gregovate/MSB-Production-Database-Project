# Administrator-prepared, per-user launcher installation; no preview writes.
[CmdletBinding()]
param()
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
# MSB standard: every programmer installs LOR with C:\LOR as its data folder.
# This read-only prerequisite runs before copying files or registering a handler.
function Assert-MSBLocalLibrary {
    if (-not (Test-Path -LiteralPath 'C:\LOR\CommonData\LORPreviews.xml' -PathType Leaf)) {
        throw 'MSB requires Light-O-Rama to use C:\LOR as its data folder. Open Light-O-Rama once with that data folder, then close it and run Install MSB PC Preview Updater.vbs again. Required file: C:\LOR\CommonData\LORPreviews.xml. No updater was installed.'
    }
}
try {
    Assert-MSBLocalLibrary
    $source = Join-Path $PSScriptRoot 'Update_MSB_Previews.ps1'
    $metadata = Join-Path $PSScriptRoot 'DEPLOYMENT.json'
    if (-not (Test-Path $metadata)) { throw 'Missing committed-release deployment identity. Administrator preparation is required.' }
    $release = Get-Content $metadata -Raw | ConvertFrom-Json
    if ($release.version -ne '1.0.3' -or $release.source_commit -notmatch '^[a-f0-9]{40}$' -or
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
    Set-Item -Path ($protocol + '\shell\open\command') -Value ('"' + $powershell + '" -NoLogo -NoProfile -ExecutionPolicy Bypass -STA -WindowStyle Hidden -File "' + $installed + '" -AuditOnly')
    Add-Type -AssemblyName System.Windows.Forms
    [void][Windows.Forms.MessageBox]::Show('MSB PC Preview Updater launcher installed. No previews were changed.', 'MSB LOR2PC')
} catch {
    Add-Type -AssemblyName System.Windows.Forms
    [void][Windows.Forms.MessageBox]::Show($_.Exception.Message, 'MSB LOR2PC setup blocked')
    exit 2
}
