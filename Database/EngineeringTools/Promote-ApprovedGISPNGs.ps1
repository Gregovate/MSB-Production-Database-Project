#Requires -Version 5.1
<#
.SYNOPSIS
  Dry-run or add the approved #171 32 PNGs to the canonical Shared Drive library.
.DESCRIPTION
  Default is READ-ONLY. -Apply creates ONLY missing files after source/ZIP/hash
  verification. Never overwrites, renames or deletes; existing collisions abort.
  Never modifies Masters, Plain, ExpertGPS, webassets, GPX, or draw.io.
#>
[CmdletBinding()]
param(
    [string]$ZipPath = '',
    [string]$PlainSvgDirectory = 'G:\Shared drives\Display Folders\Park Drawings\MSB GIS\Symbols\Plain',
    [string]$DestinationDirectory = 'G:\Shared drives\Display Folders\Park Drawings\MSB GIS\Symbols\png',
    [switch]$Apply
)
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$expectedZipHash = '85569dc7cafa1da169bd68244bb9757daadfb53c1d02e911256790d0c6a63e53'
$expectedReadmeHash = '69115edd6b8dcf97db836179e014c9221e0f8eba62033703e35b1411a18e9b59'

function Hash-Bytes([byte[]]$bytes) {
    $algo = [Security.Cryptography.SHA256]::Create()
    try { [BitConverter]::ToString($algo.ComputeHash($bytes)).Replace('-', '').ToLowerInvariant() }
    finally { $algo.Dispose() }
}
function Read-ZipBytes($entry) {
    if ($null -eq $entry) { throw 'Required archive entry missing.' }
    $stream = $entry.Open()
    $memory = New-Object IO.MemoryStream
    try {
        $stream.CopyTo($memory)
        return ,($memory.ToArray())
    }
    finally {
        $stream.Dispose()
        $memory.Dispose()
    }
}

if ([string]::IsNullOrWhiteSpace($ZipPath)) {
    # Do not guess the operator's precise timestamped staging-folder name.
    # Find the single reviewed byte-exact ZIP among the standard Downloads stages.
    $downloads = Join-Path $env:USERPROFILE 'Downloads'
    $matches = @()
    $stageDirs = @(Get-ChildItem -LiteralPath $downloads -Directory -Filter 'MSB-ExpertGPS-PNGs-*' -ErrorAction Stop)
    foreach ($dir in $stageDirs) {
        $candidate = Join-Path $dir.FullName 'MSB_ExpertGPS_Current_Plain_Staged.zip'
        if (Test-Path -LiteralPath $candidate -PathType Leaf) {
            $candidateHash = (Get-FileHash -LiteralPath $candidate -Algorithm SHA256).Hash.ToLowerInvariant()
            if ($candidateHash -ceq $expectedZipHash) { $matches += $candidate }
        }
    }
    if ($matches.Count -ne 1) {
        throw "Found $($matches.Count) byte-exact approved ZIP candidates in Downloads. Pass -ZipPath explicitly if it was moved or duplicated."
    }
    $ZipPath = $matches[0]
}
if (-not (Test-Path -LiteralPath $ZipPath -PathType Leaf)) {
    throw "Candidate ZIP not found: $ZipPath. Pass -ZipPath with the actual corrected 07:24 ZIP."
}
if (-not (Test-Path -LiteralPath $PlainSvgDirectory -PathType Container)) {
    throw "Canonical Plain source unavailable: $PlainSvgDirectory"
}
$zipHash = (Get-FileHash -LiteralPath $ZipPath -Algorithm SHA256).Hash.ToLowerInvariant()
if ($zipHash -cne $expectedZipHash) {
    throw "Wrong candidate ZIP SHA256 $zipHash. Expected approved corrected 07:24 ZIP $expectedZipHash. No changes made."
}

Add-Type -AssemblyName System.IO.Compression
Add-Type -AssemblyName System.IO.Compression.FileSystem
$archive = [IO.Compression.ZipFile]::OpenRead((Resolve-Path -LiteralPath $ZipPath).Path)
try {
    $entries = @($archive.Entries)
    $pngEntries = @($entries | Where-Object { $_.FullName -cmatch '^msb/[a-z0-9]+(-[a-z0-9]+)*\.png$' })
    if ($entries.Count -ne 34 -or $pngEntries.Count -ne 32) {
        throw "Invalid ZIP member count: $($entries.Count) total / $($pngEntries.Count) PNGs; expected 34 / 32."
    }
    $seen = @{}
    foreach ($entry in $entries) {
        $validPng = $entry.FullName -cmatch '^msb/[a-z0-9]+(-[a-z0-9]+)*\.png$'
        $validOther = @('msb/readme.txt','MSB_ExpertGPS_PNG_Inventory.csv') -ccontains $entry.FullName
        if (-not $validPng -and -not $validOther) {
            throw "Unexpected ZIP member: $($entry.FullName)"
        }
        $key = $entry.FullName.ToLowerInvariant()
        if ($seen.ContainsKey($key)) { throw "Duplicate/case-colliding member: $key" }
        $seen[$key] = $true
    }

    $readme = Read-ZipBytes ($archive.GetEntry('msb/readme.txt'))
    if ((Hash-Bytes $readme) -cne $expectedReadmeHash) {
        throw 'ZIP contains an unapproved ExpertGPS readme.txt.'
    }
    $firstLine = ([Text.Encoding]::UTF8.GetString($readme) -split '\r?\n')[0].TrimStart([char]0xFEFF)
    if ($firstLine -cne 'https://webassets.sheboyganlights.org/images/symbols/') {
        throw 'ZIP readme.txt parent URL is wrong.'
    }

    $csvBytes = Read-ZipBytes ($archive.GetEntry('MSB_ExpertGPS_PNG_Inventory.csv'))
    $csvText = [Text.Encoding]::UTF8.GetString($csvBytes).TrimStart([char]0xFEFF)
    $lines = @($csvText -split '\r?\n' | Where-Object { $_.Trim() -ne '' })
    $rows = @($lines | ConvertFrom-Csv)
    if ($rows.Count -ne 32) { throw "Manifest contains $($rows.Count) rows, not 32." }
    foreach ($column in @('SVG','SVG_SHA256','PNG','Width_PX','Height_PX','PNG_SHA256')) {
        if ($rows[0].PSObject.Properties.Name -cnotcontains $column) {
            throw "Manifest column missing: $column"
        }
    }

    $payloads = @{}
    $seenNames = @{}
    foreach ($row in $rows) {
        if ($row.SVG -cnotmatch '^[a-z0-9]+(-[a-z0-9]+)*\.svg$' -or
            $row.PNG -cnotmatch '^[a-z0-9]+(-[a-z0-9]+)*\.png$' -or
            [IO.Path]::ChangeExtension($row.SVG, '.png') -cne $row.PNG) {
            throw "Invalid source/output filename in manifest: $($row.SVG) / $($row.PNG)"
        }
        $nameKey = $row.PNG.ToLowerInvariant()
        if ($seenNames.ContainsKey($nameKey)) { throw "Duplicate manifest PNG name: $nameKey" }
        $seenNames[$nameKey] = $true
        if ($row.PNG_SHA256 -cnotmatch '^[0-9a-f]{64}$' -or
            $row.SVG_SHA256 -cnotmatch '^[0-9a-f]{64}$') {
            throw "Invalid SHA256 in manifest for $($row.PNG)"
        }
        $pngEntry = $archive.GetEntry('msb/' + $row.PNG)
        $bytes = Read-ZipBytes $pngEntry
        if ((Hash-Bytes $bytes) -cne $row.PNG_SHA256) {
            throw "Manifest PNG hash does not match ZIP member $($row.PNG)"
        }
        if ($bytes.Length -lt 26 -or
            ([BitConverter]::ToString($bytes,0,8) -cne '89-50-4E-47-0D-0A-1A-0A') -or
            $bytes[25] -ne 6) {
            throw "Invalid RGBA PNG header $($row.PNG)"
        }
        $w = ([int64]$bytes[16] * 16777216) + ([int64]$bytes[17] * 65536) +
             ([int64]$bytes[18] * 256) + [int64]$bytes[19]
        $h = ([int64]$bytes[20] * 16777216) + ([int64]$bytes[21] * 65536) +
             ([int64]$bytes[22] * 256) + [int64]$bytes[23]
        if ($w -ne [int]$row.Width_PX -or $h -ne [int]$row.Height_PX) {
            throw "PNG canvas not as approved: $($row.PNG)"
        }
        $svg = Join-Path $PlainSvgDirectory $row.SVG
        if (-not (Test-Path -LiteralPath $svg -PathType Leaf)) {
            throw "Approved current Plain SVG missing: $svg"
        }
        $sourceHash = (Get-FileHash -LiteralPath $svg -Algorithm SHA256).Hash.ToLowerInvariant()
        if ($sourceHash -cne $row.SVG_SHA256) {
            throw "Current Plain SVG changed after approval: $($row.SVG). Stop and review."
        }
        $payloads[$row.PNG] = $bytes
    }
    foreach ($entry in $pngEntries) {
        if (-not $seenNames.ContainsKey($entry.Name.ToLowerInvariant())) {
            throw "Unlisted ZIP PNG: $($entry.Name)"
        }
    }

    $existing = @()
    if (Test-Path -LiteralPath $DestinationDirectory) {
        if (-not (Test-Path -LiteralPath $DestinationDirectory -PathType Container)) {
            throw "Destination is not a folder: $DestinationDirectory"
        }
        $existing = @(Get-ChildItem -LiteralPath $DestinationDirectory -File -ErrorAction Stop)
    }
    $missing = @()
    $matched = @()
    $conflicts = @()
    foreach ($row in $rows) {
        $found = @($existing | Where-Object { $_.Name -ieq $row.PNG })
        if ($found.Count -eq 0) {
            $missing += $row
        }
        elseif ($found.Count -ne 1 -or $found[0].Name -cne $row.PNG) {
            $conflicts += "Case/filename collision: $($row.PNG)"
        }
        elseif ((Get-FileHash -LiteralPath $found[0].FullName -Algorithm SHA256).Hash.ToLowerInvariant() -cne $row.PNG_SHA256) {
            $conflicts += "Different existing artwork: $($row.PNG)"
        }
        else {
            $matched += $row
        }
    }
    if ($conflicts.Count -gt 0) {
        throw ("Existing destination conflicts; no copies made. Review these files:" +
               [Environment]::NewLine + ($conflicts -join [Environment]::NewLine))
    }
    Write-Host "Approved corrected candidate verified: $zipHash"
    Write-Host 'ZIP PNG, readme, manifest and current Plain SVG hashes: 32/32 PASS'
    Write-Host "Canonical destination: $DestinationDirectory"
    Write-Host "Missing: $($missing.Count); already identical: $($matched.Count); conflicts: 0"
    if (-not $Apply) {
        Write-Host 'DRY RUN PASS. No files written. Use -Apply only after reviewing this result.'
    }
    else {
        if (-not (Test-Path -LiteralPath $DestinationDirectory)) {
            $null = New-Item -ItemType Directory -Path $DestinationDirectory -ErrorAction Stop
        }
        $receipt = @()
        foreach ($row in $rows) {
            $target = Join-Path $DestinationDirectory $row.PNG
            if (Test-Path -LiteralPath $target) {
                $oldHash = (Get-FileHash -LiteralPath $target -Algorithm SHA256).Hash.ToLowerInvariant()
                if ($oldHash -cne $row.PNG_SHA256) {
                    throw "Destination changed during promotion: $target; refusing overwrite."
                }
                $action = 'already-identical'
            }
            else {
                # FileMode.CreateNew fails if a concurrent writer added the name.
                $output = [IO.File]::Open($target,[IO.FileMode]::CreateNew,[IO.FileAccess]::Write)
                try {
                    $bytes = $payloads[$row.PNG]
                    $output.Write($bytes,0,$bytes.Length)
                    $output.Flush()
                }
                finally { $output.Dispose() }
                $action = 'created'
            }
            $verifiedHash = (Get-FileHash -LiteralPath $target -Algorithm SHA256).Hash.ToLowerInvariant()
            if ($verifiedHash -cne $row.PNG_SHA256) {
                throw "Post-copy SHA256 mismatch: $target. Stop; preserve file for investigation."
            }
            $receipt += [pscustomobject]@{
                Name = $row.PNG
                Result = $action
                SHA256 = $verifiedHash
                Approved_ZIP_SHA256 = $zipHash
                Destination = $target
            }
        }
        $receiptName = 'MSB_GIS_Approved_PNG_Promotion_' + (Get-Date -Format 'yyyyMMdd-HHmmss') + '.csv'
        $receiptPath = Join-Path (Split-Path -Parent $ZipPath) $receiptName
        $receipt | Export-Csv -LiteralPath $receiptPath -NoTypeInformation -Encoding UTF8
        Write-Host "PROMOTION PASS: 32/32 verified. Added: $($missing.Count); already identical: $($matched.Count)."
        Write-Host "Receipt: $receiptPath"
        Write-Host 'No legacy icons overwritten or deleted. NOT installed in ExpertGPS; NOT published to Synology.'
    }
}
finally {
    $archive.Dispose()
}
