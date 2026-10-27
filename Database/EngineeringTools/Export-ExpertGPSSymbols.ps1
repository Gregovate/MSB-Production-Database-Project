#Requires -Version 5.1
<#
.SYNOPSIS
  Stage ExpertGPS PNGs directly from the current approved MSB GIS Plain SVG directory.
.DESCRIPTION
  Read-only for the Plain SVG source and all installed/published symbol libraries.
  Uses the original ExpertGPS readme.txt parent URL contract and preserves the
  individual SVG canvas dimensions. Stages PNGs, a SHA-256 inventory, and a ZIP.
  This intentionally does NOT install PNGs on the PC or modify Synology.
.EXAMPLE
  .\Export-ExpertGPSSymbols.ps1
.EXAMPLE
  .\Export-ExpertGPSSymbols.ps1 -PlainSvgDirectory 'G:\Shared drives\Display Folders\Park Drawings\MSB GIS\Symbols\Plain'
#>
[CmdletBinding()]
param(
    [string]$PlainSvgDirectory = 'G:\Shared drives\Display Folders\Park Drawings\MSB GIS\Symbols\Plain',
    [string]$ReadmePath = (Join-Path $env:LOCALAPPDATA 'TopoGrafix\Symbols\msb\readme.txt'),
    [string]$OutputDirectory = (Join-Path $env:USERPROFILE ('Downloads\MSB-ExpertGPS-PNGs-' + (Get-Date -Format 'yyyyMMdd-HHmmss'))),
    [string]$InkscapeExecutable = 'C:\Program Files\Inkscape\bin\inkscape.com'
)
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

if (-not (Test-Path -LiteralPath $PlainSvgDirectory -PathType Container)) {
    throw "Approved Plain SVG directory missing: $PlainSvgDirectory"
}
if (-not (Test-Path -LiteralPath $ReadmePath -PathType Leaf)) {
    throw "ExpertGPS readme.txt missing: $ReadmePath (provide -ReadmePath if needed)"
}
if (-not (Test-Path -LiteralPath $InkscapeExecutable -PathType Leaf)) {
    throw "Inkscape CLI not found: $InkscapeExecutable (Windows Inkscape installs normally provide bin\inkscape.com; override -InkscapeExecutable if installed elsewhere)"
}
if (Test-Path -LiteralPath $OutputDirectory) {
    throw "Staging output already exists; specify a new, empty -OutputDirectory: $OutputDirectory"
}

$expectedUrl = 'https://webassets.sheboyganlights.org/images/symbols/'
$firstLine = [System.IO.File]::ReadLines($ReadmePath) | Select-Object -First 1
if ($firstLine -cne $expectedUrl) {
    throw "ExpertGPS readme.txt first line must be the parent URL $expectedUrl ; found: $firstLine"
}

$plain = (Resolve-Path -LiteralPath $PlainSvgDirectory).Path
$sourceFiles = @(Get-ChildItem -LiteralPath $plain -Filter '*.svg' -File | Sort-Object Name)
if ($sourceFiles.Count -eq 0) {
    throw "No Plain SVG files found in $plain"
}
$sourceNames = @{}
foreach ($sourceFile in $sourceFiles) {
    if ($sourceFile.Name -cnotmatch '^[a-z0-9]+(-[a-z0-9]+)*\.svg$') {
        throw "Noncanonical SVG filename: $($sourceFile.Name). Review name/GPX compatibility first."
    }
    $pngName = [System.IO.Path]::ChangeExtension($sourceFile.Name, '.png')
    if ($sourceNames.ContainsKey($pngName)) {
        throw "Two SVGs would generate the same PNG name: $pngName"
    }
    $sourceNames[$pngName] = $true
}

$null = New-Item -ItemType Directory -Path $OutputDirectory -Force
$staging = (Resolve-Path -LiteralPath $OutputDirectory).Path
$msb = Join-Path $staging 'msb'
$null = New-Item -ItemType Directory -Path $msb -Force
Copy-Item -LiteralPath $ReadmePath -Destination (Join-Path $msb 'readme.txt') -ErrorAction Stop
if ((Get-FileHash -LiteralPath $ReadmePath -Algorithm SHA256).Hash -cne
    (Get-FileHash -LiteralPath (Join-Path $msb 'readme.txt') -Algorithm SHA256).Hash) {
    throw 'Staged readme.txt does not match the input bytes.'
}

$diagnosticLog = Join-Path $staging 'MSB_Inkscape_Export_Diagnostics.txt'
$null = Set-Content -LiteralPath $diagnosticLog -Value @(
    'MSB #171 staged Inkscape PNG export diagnostics',
    ('Inkscape command-line executable: ' + $InkscapeExecutable),
    ('Plain SVG source: ' + $plain),
    ('Staging output: ' + $staging),
    'NOTE: does not install to ExpertGPS or publish to any web library.',
    ''
) -Encoding UTF8

$rows = @()
foreach ($sourceFile in $sourceFiles) {
    $svgSha = (Get-FileHash -LiteralPath $sourceFile.FullName -Algorithm SHA256).Hash.ToLowerInvariant()
    $pngName = [System.IO.Path]::ChangeExtension($sourceFile.Name, '.png')
    $pngPath = Join-Path $msb $pngName

    # Capture the real renderer error. inkscape.com is the Windows console wrapper;
    # inkscape.exe is a GUI launcher and may not propagate diagnostics/exit status.
    # Temporarily allow native stderr to be captured without turning it into an
    # unhelpful PowerShell terminating error under ErrorActionPreference = Stop.
    $renderOutput = @()
    $renderExitCode = $null
    $renderException = ''
    $originalErrorActionPreference = $ErrorActionPreference
    try {
        $ErrorActionPreference = 'Continue'
        $renderOutput = @(& $InkscapeExecutable $sourceFile.FullName '--export-type=png' ('--export-filename=' + $pngPath) 2>&1)
        $renderExitCode = $LASTEXITCODE
    }
    catch {
        $renderException = $_.Exception.Message
    }
    finally {
        $ErrorActionPreference = $originalErrorActionPreference
    }

    $pngExists = Test-Path -LiteralPath $pngPath -PathType Leaf
    $rendererMessage = if ($renderOutput.Count -gt 0) {
        ($renderOutput | Out-String).Trim()
    } else {
        '(none captured)'
    }
    $renderDetails = @(
        ('SVG: ' + $sourceFile.FullName),
        ('PNG: ' + $pngPath),
        ('Exit code: ' + $renderExitCode),
        ('PNG created: ' + $pngExists),
        ('Invocation exception: ' + $renderException),
        ('Renderer output: ' + $rendererMessage),
        ''
    )
    Add-Content -LiteralPath $diagnosticLog -Value $renderDetails -Encoding UTF8
    if ($renderException -or $renderExitCode -ne 0 -or -not $pngExists) {
        throw "Inkscape PNG export failed: $($sourceFile.Name); exit code=$renderExitCode; PNG created=$pngExists; exception=$renderException; renderer output=$rendererMessage; diagnostics: $diagnosticLog"
    }

    # Parse PNG IHDR directly so the check works on Windows PowerShell 5.1
    # without installing image-processing modules.
    $bytes = [System.IO.File]::ReadAllBytes($pngPath)
    $signature = [System.BitConverter]::ToString($bytes, 0, [Math]::Min(8, $bytes.Length))
    if ($bytes.Length -lt 26 -or $signature -cne '89-50-4E-47-0D-0A-1A-0A') {
        throw "Invalid PNG signature: $pngName"
    }
    if ($bytes[25] -ne 6) {
        throw "PNG is not truecolor+alpha (RGBA): $pngName; color type=$($bytes[25])"
    }
    $width = [int]((([uint32]$bytes[16] -shl 24) -bor ([uint32]$bytes[17] -shl 16) -bor ([uint32]$bytes[18] -shl 8) -bor [uint32]$bytes[19]))
    $height = [int]((([uint32]$bytes[20] -shl 24) -bor ([uint32]$bytes[21] -shl 16) -bor ([uint32]$bytes[22] -shl 8) -bor [uint32]$bytes[23]))
    if ($width -le 0 -or $height -le 0) {
        throw "Invalid PNG canvas dimensions: $pngName"
    }
    if ((Get-FileHash -LiteralPath $sourceFile.FullName -Algorithm SHA256).Hash.ToLowerInvariant() -cne $svgSha) {
        throw "Plain SVG source changed during export; discard this staging: $($sourceFile.Name)"
    }
    $rows += [pscustomobject]@{
        SVG = $sourceFile.Name
        SVG_SHA256 = $svgSha
        PNG = $pngName
        Width_PX = $width
        Height_PX = $height
        PNG_SHA256 = (Get-FileHash -LiteralPath $pngPath -Algorithm SHA256).Hash.ToLowerInvariant()
    }
}
$manifest = Join-Path $staging 'MSB_ExpertGPS_PNG_Inventory.csv'
$rows | Export-Csv -LiteralPath $manifest -NoTypeInformation -Encoding UTF8
$zipFile = Join-Path $staging 'MSB_ExpertGPS_Current_Plain_Staged.zip'
Compress-Archive -LiteralPath $msb, $manifest -DestinationPath $zipFile -CompressionLevel Optimal

Write-Host "Exported $($rows.Count) current Plain SVGs to RGBA PNGs."
Write-Host "Source: $plain"
Write-Host "Staging: $staging"
Write-Host "ZIP: $zipFile"
Write-Host 'NOT installed to local ExpertGPS. NOT published to Synology.'
Write-Host 'Review the manifest and artwork before merge-only installation and governed web publication.'
