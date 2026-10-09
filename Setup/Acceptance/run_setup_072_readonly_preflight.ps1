# Migration 072 — read-only Production preflight.
# Normalize Linux shell content to LF/UTF-8 without BOM before SCP.
# One transfer and one foreground SSH session; no Production mutation.
[CmdletBinding()]
param([string]$Server = "msbadmin@192.168.5.9")
$ErrorActionPreference = "Stop"
$scriptPath = Join-Path $PSScriptRoot "setup_072_production_readonly_preflight.sh"
if (-not (Test-Path -LiteralPath $scriptPath -PathType Leaf)) {
    throw "STOP: Missing preflight shell script: $scriptPath"
}
$remote = "/tmp/setup_072_production_readonly_preflight.sh"
$temp = Join-Path ([System.IO.Path]::GetTempPath()) ("msb-072-preflight-" + [guid]::NewGuid().ToString("N") + ".sh")
try {
    $source = [System.IO.File]::ReadAllText($scriptPath)
    $normalized = $source.Replace("`r`n", "`n").Replace("`r", "`n")
    [System.IO.File]::WriteAllText($temp, $normalized, (New-Object System.Text.UTF8Encoding($false)))
    if ([System.IO.File]::ReadAllText($temp).Contains([char]13)) {
        throw "STOP: CR remains in normalized script"
    }
    & scp -- $temp "${Server}:$remote"
    if ($LASTEXITCODE -ne 0) { throw "STOP: SCP transfer failed" }
    & ssh -tt -o ServerAliveInterval=15 -o ServerAliveCountMax=3 $Server "bash -n '$remote' && bash '$remote'"
    if ($LASTEXITCODE -ne 0) { throw "STOP: Read-only Production preflight failed" }
    Write-Host "SETUP 072 READ-ONLY PREFLIGHT: PASS"
}
finally {
    Remove-Item -LiteralPath $temp -Force -ErrorAction SilentlyContinue
}
