# Engineering-only disposable review. Copies existing master exports; never writes G:.
[CmdletBinding()]
param([string]$MasterFolder='', [string]$ProposedExport='')
$ErrorActionPreference='Stop'
Set-StrictMode -Version Latest
$meta=Get-Content -LiteralPath (Join-Path $PSScriptRoot 'SOURCE.json') -Raw | ConvertFrom-Json
$sha=[string]$meta.source_commit
if ($sha -cnotmatch '^[a-f0-9]{40}$') { throw 'Missing exact source checkpoint' }
$runner=Join-Path $PSScriptRoot 'review_clone.sh'
if ((Get-FileHash -LiteralPath $runner -Algorithm SHA256).Hash -ine $meta.files.'review_clone.sh') { throw 'Review source digest mismatch' }
$email=Read-Host 'Enter your existing MSB login email for this isolated review'
if ($email -notmatch '^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$') { throw 'Invalid review email' }
if (-not $MasterFolder) { $MasterFolder=Read-Host 'Paste the current unchanged accepted master preview folder path' }
$folder=Get-Item -LiteralPath $MasterFolder
if (-not $folder.PSIsContainer -or $folder.Name -notmatch '^Database Previews V[0-9]+\.[0-9]+\.[0-9]+$') { throw 'Expected the exact accepted versioned master folder' }
$probe=New-Object Net.Sockets.TcpListener([Net.IPAddress]::Loopback,8898)
try { $probe.Start() } catch { throw 'HOLD: local review port 8898 is in use' } finally { $probe.Stop() }
if (-not $ProposedExport) {
    # Browsers cannot force an arbitrary Windows picker path. Use the existing
    # engineering launcher's native picker so the actual source path is known.
    if (-not (Test-Path -LiteralPath 'C:\LOR\ImportExport' -PathType Container)) { throw 'Required local export folder C:\LOR\ImportExport is missing' }
    if ([Threading.Thread]::CurrentThread.GetApartmentState() -ne [Threading.ApartmentState]::STA) { throw 'Use powershell.exe -STA for the native file picker' }
    Add-Type -AssemblyName System.Windows.Forms
    $picker=New-Object System.Windows.Forms.OpenFileDialog
    $picker.InitialDirectory='C:\LOR\ImportExport'
    $picker.Title='Select your new preview for DISPOSABLE catalog review'
    $picker.Filter='Light-O-Rama preview (*.lorprev)|*.lorprev'
    $picker.CheckFileExists=$true; $picker.Multiselect=$false; $picker.RestoreDirectory=$true
    try {
        if ($picker.ShowDialog() -ne [System.Windows.Forms.DialogResult]::OK) { throw 'Review cancelled before transfer' }
        $ProposedExport=$picker.FileName
    } finally { $picker.Dispose() }
}
$proposed=Get-Item -LiteralPath $ProposedExport
if ($proposed.PSIsContainer -or $proposed.Extension -ine '.lorprev' -or $proposed.Length -gt 16777216) { throw 'Select one .lorprev export no larger than 16 MB' }
$proposedBytes=[IO.File]::ReadAllBytes($proposed.FullName)
$hasher=[Security.Cryptography.SHA256]::Create()
try { $proposedHash=([BitConverter]::ToString($hasher.ComputeHash($proposedBytes))).Replace('-','').ToLowerInvariant() } finally { $hasher.Dispose() }
if ((Get-FileHash -LiteralPath $proposed.FullName -Algorithm SHA256).Hash -ine $proposedHash) { throw 'Selected export changed while being copied' }
$sourceMetadata=@{source_path=$proposed.FullName;filename=$proposed.Name;sha256=$proposedHash} | ConvertTo-Json
Add-Type -AssemblyName System.IO.Compression
$token=[guid]::NewGuid().ToString('N')
$zip=Join-Path ([IO.Path]::GetTempPath()) ("msb299-catalog-$token.zip")
$remote="/tmp/msb299-catalog-$token.zip"
try {
    $files=@(Get-ChildItem -LiteralPath $folder.FullName -Filter '*.lorprev' -File)
    if ($files.Count -eq 0 -or $files.Count -gt 500) { throw 'Invalid copied preview count' }
    if (($files | Measure-Object -Property Length -Sum).Sum -gt 536870912) { throw 'Copied source exceeds review bound' }
    $stream=[IO.File]::Open($zip,[IO.FileMode]::CreateNew)
    $archive=New-Object IO.Compression.ZipArchive($stream,[IO.Compression.ZipArchiveMode]::Create,$false)
    try {
        foreach ($file in $files) {
            if ($file.Length -gt 16777216) { throw 'Preview export exceeds review bound' }
            $entry=$archive.CreateEntry($file.Name,[IO.Compression.CompressionLevel]::Optimal)
            $output=$entry.Open()
            try { $bytes=[IO.File]::ReadAllBytes($file.FullName); $output.Write($bytes,0,$bytes.Length) } finally { $output.Dispose() }
        }
        $selected=@{'__review_input/proposed.lorprev'=$proposedBytes;'__review_input/source.json'=[Text.Encoding]::UTF8.GetBytes($sourceMetadata)}
        foreach ($name in $selected.Keys) {
            $entry=$archive.CreateEntry($name,[IO.Compression.CompressionLevel]::Optimal)
            $output=$entry.Open()
            try { $data=[byte[]]$selected[$name]; $output.Write($data,0,$data.Length) } finally { $output.Dispose() }
        }
    } finally { $archive.Dispose(); $stream.Dispose() }
    # One transfer then one foreground SSH session. No interactive output pipeline.
    & scp $zip ('msbadmin@192.168.5.9:'+$remote)
    if ($LASTEXITCODE -ne 0) { throw 'Copied master transfer failed' }
    $text=[IO.File]::ReadAllText($runner).Replace("`r`n","`n")
    $encoded=[Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($text))
    $command='printf %s '+$encoded+' | base64 -d | sudo bash -s -- 8898 '+$sha+' '+$email+' '+$remote
    Write-Host 'Wait for BROWSER REVIEW READY before opening http://127.0.0.1:8898/lor2db/'
    & ssh -o ExitOnForwardFailure=yes -o ServerAliveInterval=15 -o ServerAliveCountMax=3 -L '8898:127.0.0.1:8898' -tt 'msbadmin@192.168.5.9' $command
    if ($LASTEXITCODE -ne 0) { throw 'Disposable catalog review HOLD. Retain output; do not switch ports or restart blindly.' }
} finally { Remove-Item -LiteralPath $zip -Force -ErrorAction SilentlyContinue }
