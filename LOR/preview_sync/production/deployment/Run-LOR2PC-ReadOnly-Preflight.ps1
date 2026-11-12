# Read-only remote reconnaissance. No upload or production file is created.
[CmdletBinding()]
param()
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$scriptPath = Join-Path $PSScriptRoot 'Inspect-LOR2PC-Production.sh'
if (-not (Test-Path -LiteralPath $scriptPath -PathType Leaf)) { throw 'Missing Inspect-LOR2PC-Production.sh' }
$bytes = [IO.File]::ReadAllBytes($scriptPath)
$encoded = [Convert]::ToBase64String($bytes)
# Only Base64 from the adjacent committed script enters the shell command.
# No nested quotes: Windows PowerShell 5.1 may strip quotes around bash -c,
# causing a shebang-only command to return 0 without executing the preflight.
$command = 'printf %s ' + $encoded + ' | base64 -d | bash'
& ssh -tt 'msbadmin@192.168.5.9' $command
if ($LASTEXITCODE -ne 0) { throw 'Read-only preflight HOLD. Retain output; do not mutate Production.' }
