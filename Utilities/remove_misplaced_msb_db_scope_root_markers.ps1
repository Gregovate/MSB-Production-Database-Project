<#
.SYNOPSIS
Safely previews/removes DB-source marker files that were mistakenly placed at Stage/Substage/Scene roots.

.DESCRIPTION
This is a remediation utility for reports produced by an earlier marker-population
script version that incorrectly targeted ScopeRoot folders.

The utility reads an existing CSV report and considers ONLY rows where:
  TargetType = ScopeRoot

PREVIEW ONLY by default. Use -Apply to remove files.

When -Apply is used, every marker is copied to a timestamped Desktop backup folder
before the original is deleted. Helper-folder markers under PreviewBackground,
Procedures, and Wiring are never targeted by this script.
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)]
    [string]$InputReport,

    [string]$DriveRoot = 'G:\Shared drives\Display Folders',

    [switch]$Apply,

    [string]$OutputReport,

    [string]$BackupRoot
)

$ErrorActionPreference = 'Stop'
$MarkerName = '_MSB-DB-Source-Folder_READ-ME-FIRST-AND-DO-NOT-DELETE.txt'

if (-not (Test-Path -LiteralPath $InputReport -PathType Leaf)) {
    throw "Input report not found: $InputReport"
}

if (-not (Test-Path -LiteralPath $DriveRoot -PathType Container)) {
    throw "Display Folders root not found: $DriveRoot"
}

$DriveRoot = (Resolve-Path -LiteralPath $DriveRoot).Path
$InputReport = (Resolve-Path -LiteralPath $InputReport).Path

$stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$desktop = [Environment]::GetFolderPath('Desktop')

if (-not $OutputReport) {
    $OutputReport = Join-Path $desktop "MSB_DB_Misplaced_Scope_Root_Marker_Cleanup_$stamp.csv"
}

if (-not $BackupRoot) {
    $BackupRoot = Join-Path $desktop "MSB_DB_Misplaced_Scope_Root_Marker_Backup_$stamp"
}

function Test-PathUnderRoot {
    param([string]$Path,[string]$Root)

    $fullPath = [IO.Path]::GetFullPath($Path).TrimEnd('\')
    $fullRoot = [IO.Path]::GetFullPath($Root).TrimEnd('\')
    return $fullPath.StartsWith($fullRoot + '\',[StringComparison]::OrdinalIgnoreCase)
}

function Get-RelativePathSafe {
    param([string]$Base,[string]$Child)
    try { return [IO.Path]::GetRelativePath($Base,$Child) }
    catch {
        if ($Child.StartsWith($Base,[StringComparison]::OrdinalIgnoreCase)) {
            return $Child.Substring($Base.Length).TrimStart('\')
        }
        return $Child
    }
}

$inputRows = @(Import-Csv -LiteralPath $InputReport)
$scopeRows = @($inputRows | Where-Object { $_.TargetType -eq 'ScopeRoot' })

if ($scopeRows.Count -eq 0) {
    throw 'The input report contains no TargetType=ScopeRoot rows. Nothing to remediate.'
}

$results = New-Object 'Collections.Generic.List[object]'

foreach ($row in $scopeRows) {
    $markerPath = $row.MarkerPath
    $action = $null
    $message = $null
    $backupPath = $null

    if ([string]::IsNullOrWhiteSpace($markerPath)) {
        $action = 'REVIEW'
        $message = 'ScopeRoot row has no MarkerPath.'
    }
    elseif ((Split-Path -Leaf $markerPath) -ne $MarkerName) {
        $action = 'REVIEW'
        $message = 'MarkerPath filename does not match the approved marker filename.'
    }
    elseif (-not (Test-PathUnderRoot -Path $markerPath -Root $DriveRoot)) {
        $action = 'REVIEW'
        $message = 'MarkerPath is not beneath the configured Display Folders root.'
    }
    elseif ($markerPath -match '\\(PreviewBackground|Procedures|Wiring)\\') {
        $action = 'REVIEW'
        $message = 'Safety stop: path appears to be inside an approved helper folder.'
    }
    elseif (-not (Test-Path -LiteralPath $markerPath -PathType Leaf)) {
        $action = 'SKIPPED_MISSING'
        $message = 'Marker is already absent.'
    }
    elseif (-not $Apply) {
        $action = 'WOULD_REMOVE'
        $message = 'Preview only. This ScopeRoot marker is outside the approved marker placement contract.'
    }
    else {
        $relativeMarker = Get-RelativePathSafe -Base $DriveRoot -Child $markerPath
        $backupPath = Join-Path $BackupRoot $relativeMarker
        $backupDir = Split-Path -Parent $backupPath

        if (-not (Test-Path -LiteralPath $backupDir -PathType Container)) {
            New-Item -ItemType Directory -Path $backupDir -Force | Out-Null
        }

        Copy-Item -LiteralPath $markerPath -Destination $backupPath -Force
        Remove-Item -LiteralPath $markerPath -Force

        $action = 'REMOVED'
        $message = 'Misplaced ScopeRoot marker backed up and removed.'
    }

    $results.Add([pscustomobject]@{
        Stage        = $row.Stage
        ScopeKind    = $row.ScopeKind
        RelativePath = $row.RelativePath
        MarkerPath   = $markerPath
        Action       = $action
        BackupPath   = $backupPath
        Message      = $message
    })
}

$outputDir = Split-Path -Parent $OutputReport
if ($outputDir -and -not (Test-Path -LiteralPath $outputDir -PathType Container)) {
    New-Item -ItemType Directory -Path $outputDir -Force | Out-Null
}

$results | Export-Csv -LiteralPath $OutputReport -NoTypeInformation -Encoding UTF8

Write-Host ''
Write-Host 'MSB Misplaced Scope-Root Marker Cleanup'
Write-Host "Input report: $InputReport"
Write-Host "Mode: $(if ($Apply) { 'APPLY' } else { 'PREVIEW ONLY' })"
Write-Host "ScopeRoot rows: $($scopeRows.Count)"
Write-Host "Would remove: $(@($results | Where-Object Action -eq 'WOULD_REMOVE').Count)"
Write-Host "Removed: $(@($results | Where-Object Action -eq 'REMOVED').Count)"
Write-Host "Missing: $(@($results | Where-Object Action -eq 'SKIPPED_MISSING').Count)"
Write-Host "Review: $(@($results | Where-Object Action -eq 'REVIEW').Count)"
Write-Host "Output report: $OutputReport"
if ($Apply) {
    Write-Host "Backup root: $BackupRoot"
}
Write-Host ''

$results |
    Select-Object Stage,ScopeKind,RelativePath,Action |
    Format-Table -AutoSize

if (-not $Apply) {
    Write-Host ''
    Write-Host 'PREVIEW ONLY — no files were removed.'
    Write-Host 'Review the output before running with -Apply.'
}
