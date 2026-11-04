# Temporary clone/browser review; no Production source/grant/preview promotion.
[CmdletBinding()]
param()
$ErrorActionPreference='Stop'
Set-StrictMode -Version Latest
$metadata=Get-Content -LiteralPath (Join-Path $PSScriptRoot 'SOURCE.json') -Raw | ConvertFrom-Json
$sha=[string]$metadata.source_commit
if ($sha -cnotmatch '^[a-f0-9]{40}$') { throw 'Missing exact source checkpoint' }
$script=Join-Path $PSScriptRoot 'review_clone.sh'
if ((Get-FileHash $script -Algorithm SHA256).Hash -ine $metadata.files.'review_clone.sh') { throw 'Review source digest mismatch' }
$email=Read-Host 'Enter your existing MSB/Directus login email for this isolated review'
if ($email -notmatch '^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$') { throw 'Invalid review email' }
$probe=New-Object Net.Sockets.TcpListener([Net.IPAddress]::Loopback,8898)
try { $probe.Start() } catch { throw 'HOLD: local review port 8898 is in use' } finally { $probe.Stop() }
$bytes=[IO.File]::ReadAllBytes($script)
$encoded=[Convert]::ToBase64String($bytes)
# Quote-free SSH transport; only fixed validated port/SHA/email and encoded source.
$command='printf %s '+$encoded+' | base64 -d | sudo bash -s -- 8898 '+$sha+' '+$email
Write-Host 'Wait for BROWSER REVIEW READY before opening http://127.0.0.1:8898/lor2db/'
& ssh -o ExitOnForwardFailure=yes -o ServerAliveInterval=15 -o ServerAliveCountMax=3 -L '8898:127.0.0.1:8898' -tt 'msbadmin@192.168.5.9' $command
if ($LASTEXITCODE -ne 0) { throw 'Disposable browser review HOLD. Retain output; do not switch ports or restart blindly.' }
