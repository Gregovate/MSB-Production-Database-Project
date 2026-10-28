# Engineering-only disposable review. Copies existing master exports; never writes G:.
[CmdletBinding()]
param([string]$MasterFolder='')
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
