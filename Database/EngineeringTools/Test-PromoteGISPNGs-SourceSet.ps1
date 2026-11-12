#Requires -Version 5.1
<#
.SYNOPSIS
  Disposable regression checks for the read-only source-set preflight in #171.
.DESCRIPTION
  Extracts the guard function via PowerShell AST without running the promoter.
  Creates only disposable SVG stub names beneath %TEMP%; never accesses G:.
#>
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$scriptPath = Join-Path $PSScriptRoot 'Promote-ApprovedGISPNGs.ps1'
$tokens = $null
$errors = $null
$ast = [Management.Automation.Language.Parser]::ParseFile($scriptPath, [ref]$tokens, [ref]$errors)
if ($errors.Count -gt 0) {
    throw "PowerShell parser errors in promoter: $($errors | Out-String)"
}
$def = $ast.Find({
    param($node)
    ($node -is [Management.Automation.Language.FunctionDefinitionAst]) -and
    ($node.Name -ceq 'Assert-LivePlainSetEqualsManifest')
}, $true)
if ($null -eq $def) { throw 'Source-set verification helper missing from promoter.' }
. ([scriptblock]::Create($def.Extent.Text))

function Assert-Rejects([scriptblock]$action, [string]$reason) {
    $rejected = $false
    try { & $action }
    catch { $rejected = $true }
    if (-not $rejected) { throw "Expected fail-closed rejection for $reason" }
}

$testRoot = Join-Path ([IO.Path]::GetTempPath()) ('msb-171-source-set-' + [Guid]::NewGuid().ToString('N'))
$null = New-Item -ItemType Directory -Path $testRoot
$PlainSvgDirectory = $testRoot
try {
    $oldManifest = @([pscustomobject]@{SVG='car-l.svg'})
    $expandedManifest = @(
        [pscustomobject]@{SVG='car-l.svg'}
        [pscustomobject]@{SVG='antenna-l.svg'}
        [pscustomobject]@{SVG='antenna-r.svg'}
    )
    Set-Content -LiteralPath (Join-Path $testRoot 'car-l.svg') -Value '<svg/>' -Encoding UTF8
    Assert-LivePlainSetEqualsManifest $oldManifest

    Set-Content -LiteralPath (Join-Path $testRoot 'antenna-l.svg') -Value '<svg/>' -Encoding UTF8
    Assert-Rejects { Assert-LivePlainSetEqualsManifest $oldManifest } 'new antenna-l absent from old manifest'

    Set-Content -LiteralPath (Join-Path $testRoot 'antenna-r.svg') -Value '<svg/>' -Encoding UTF8
    Assert-Rejects { Assert-LivePlainSetEqualsManifest $oldManifest } 'two new antennas absent from old manifest'
    Assert-LivePlainSetEqualsManifest $expandedManifest

    Rename-Item -LiteralPath (Join-Path $testRoot 'antenna-l.svg') -NewName 'antenna-left.svg'
    Assert-Rejects { Assert-LivePlainSetEqualsManifest $expandedManifest } 'source filename change'

    Remove-Item -LiteralPath (Join-Path $testRoot 'antenna-left.svg')
    Assert-Rejects { Assert-LivePlainSetEqualsManifest $expandedManifest } 'manifest SVG no longer present'

    Write-Host 'PASS: source-set guard rejects additions, renames and missing sources; accepts exact set.'
}
finally {
    Remove-Item -LiteralPath $testRoot -Recurse -Force -ErrorAction SilentlyContinue
}
