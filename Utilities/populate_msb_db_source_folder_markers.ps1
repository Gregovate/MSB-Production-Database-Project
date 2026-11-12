<#
.SYNOPSIS
Adds the standard MSB database-source marker file to existing Google Drive source folders.

.DESCRIPTION
PREVIEW ONLY by default. Use -Apply to create marker files.

Creates ONLY:
  _MSB-DB-Source-Folder_READ-ME-FIRST-AND-DO-NOT-DELETE.txt

Approved current targets:
- PreviewBackground folders at any legitimate Stage/Substage/Scene/Display/shared-folder scope;
- Procedures folders at structured Stage/Substage/Scene scope;
- Wiring folders at structured Stage/Substage/Scene scope.

IMPORTANT:
- Stage/Substage/Scene ROOT folders are NOT marker targets.
- Photos is NOT a marker target.
- The script does not create, rename, move, or delete folders.
- The script does not overwrite an existing exact marker, preserving LOCAL NOTES.
- The script does not recurse into SourceDocs, Archive, Photos, PreviewBackground,
  Procedures, or Wiring after those helper folders are encountered.
#>

[CmdletBinding()]
param(
    [string]$DriveRoot = 'G:\Shared drives\Display Folders',
    [string]$StageFilter = '*',
    [switch]$Apply,
    [string]$ReportPath
)

$ErrorActionPreference = 'Stop'
$MarkerName = '_MSB-DB-Source-Folder_READ-ME-FIRST-AND-DO-NOT-DELETE.txt'

$SkipRecursion = @(
    'PreviewBackground','Procedures','Wiring','Photos',
    'SourceDocs','Archive','Archived','images'
)

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

function Test-TopLevelStage {
    param([IO.DirectoryInfo]$Dir)
    return ($Dir.Name -match '^\d{2}-.+')
}

function Test-StructuredScope {
    param(
        [IO.DirectoryInfo]$Dir,
        [IO.DirectoryInfo]$StageRoot
    )

    if ($Dir.FullName -eq $StageRoot.FullName) { return $true }

    # Governing folder rules:
    # NNa-Name-XY = Substage
    # NN-Name     = Scene
    # NNa-Name    = Scene under Substage
    return ($Dir.Name -match '^\d{2}[A-Za-z]?-.+')
}

function Get-StandardHeader {
    return @'
MSB DATABASE SOURCE FOLDER
READ ME — DO NOT DELETE

This file identifies this folder as a source location used by the
MSB Production Database or an MSB database-backed application

'@
}

function Get-LinksAndNotes {
    return @'
More information:
Marker operator procedure:
https://github.com/Gregovate/MSB-Production-Database-Project/blob/main/Docs/00_Project_Overview/03-MSB_DB_Source_Folder_Marker_Operator_Procedure.md

Google Drive document organization procedure:
https://github.com/Gregovate/MSB-Production-Database-Project/blob/main/Docs/00_Project_Overview/01-Google_Drive_Document_Organization_Procedure.md

LOCAL NOTES (optional)
Use this section for short factual notes about known legacy exceptions,
pending cleanup, stale pointers, or other information future maintainers
should know. Do not remove the standard information above.

Notes:

'@
}

function Get-HelperMarkerText {
    param([string]$FolderType)

    $body = switch ($FolderType) {
        'PreviewBackground' {
@'
FOLDER PURPOSE — PREVIEW BACKGROUND

This folder contains current background images used by Light-O-Rama Previews
and Scenes and as navigation/context evidence by MSB database-backed applications.

Important:
- Do not rename or move this folder without following the folder-alignment procedure.
- Do not casually rename, move, or delete an image referenced by LOR.
- Referenced BackgroundFile paths must be deliberately realigned when changed.

'@
        }
        'Procedures' {
@'
FOLDER PURPOSE — PROCEDURES

This folder is the controlled source root for field procedures associated with
this Stage, Substage, or Scene.

Important:
- Do not rename or move this folder without following the folder-alignment procedure.
- Keep current field-facing material in approved procedure locations.
- Archive and SourceDocs material is not normal field-facing content.

'@
        }
        'Wiring' {
@'
FOLDER PURPOSE — WIRING

This folder is the controlled source root for published field wiring information
associated with this Stage, Substage, or Scene.

Important:
- Do not rename or move this folder without following the folder-alignment procedure.
- Published field wiring belongs in BackgroundStage or MusicalStage as applicable.
- SourceDocs is working/source material and must not be traversed or presented by
  database-backed field applications.

'@
        }
        default { throw "Unsupported helper type: $FolderType" }
    }

    return (Get-StandardHeader) + $body + (Get-LinksAndNotes)
}

function Add-Target {
    param(
        [Collections.Generic.List[object]]$List,
        [hashtable]$Seen,
        [IO.DirectoryInfo]$Folder,
        [string]$TargetType,
        [IO.DirectoryInfo]$StageRoot
    )

    $key = $Folder.FullName.ToLowerInvariant()
    if ($Seen.ContainsKey($key)) { return }
    $Seen[$key] = $true

    $List.Add([pscustomobject]@{
        Stage        = $StageRoot.Name
        TargetType   = $TargetType
        FolderPath   = $Folder.FullName
        RelativePath = Get-RelativePathSafe -Base $DriveRoot -Child $Folder.FullName
    })
}

function Find-TargetsForStage {
    param(
        [IO.DirectoryInfo]$StageRoot,
        [Collections.Generic.List[object]]$Targets,
        [hashtable]$Seen
    )

    $queue = New-Object 'Collections.Generic.Queue[System.IO.DirectoryInfo]'
    $queue.Enqueue($StageRoot)

    while ($queue.Count -gt 0) {
        $current = $queue.Dequeue()
        $isStructuredScope = Test-StructuredScope -Dir $current -StageRoot $StageRoot

        try {
            $children = @(Get-ChildItem -LiteralPath $current.FullName -Directory -Force)
        }
        catch {
            Write-Warning "Unable to enumerate $($current.FullName): $($_.Exception.Message)"
            continue
        }

        foreach ($child in $children) {
            switch ($child.Name) {
                'PreviewBackground' {
                    # PreviewBackground may be a legitimate LOR/database source
                    # beneath Stage, Substage, Scene, Display, or shared folders.
                    Add-Target -List $Targets -Seen $Seen -Folder $child `
                        -TargetType 'PreviewBackground' -StageRoot $StageRoot
                    continue
                }
                'Procedures' {
                    if ($isStructuredScope) {
                        Add-Target -List $Targets -Seen $Seen -Folder $child `
                            -TargetType 'Procedures' -StageRoot $StageRoot
                    }
                    continue
                }
                'Wiring' {
                    if ($isStructuredScope) {
                        Add-Target -List $Targets -Seen $Seen -Folder $child `
                            -TargetType 'Wiring' -StageRoot $StageRoot
                    }
                    continue
                }
                default {
                    if ($SkipRecursion -contains $child.Name) { continue }
                    if ($child.Name.StartsWith('_')) { continue }
                    $queue.Enqueue($child)
                }
            }
        }
    }
}

if (-not (Test-Path -LiteralPath $DriveRoot -PathType Container)) {
    throw "Display Folders root was not found: $DriveRoot"
}
$DriveRoot = (Resolve-Path -LiteralPath $DriveRoot).Path

if (-not $ReportPath) {
    $desktop = [Environment]::GetFolderPath('Desktop')
    $stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
    $ReportPath = Join-Path $desktop "MSB_DB_Source_Folder_Marker_$stamp.csv"
}

$stageRoots = @(
    Get-ChildItem -LiteralPath $DriveRoot -Directory -Force |
    Where-Object { (Test-TopLevelStage $_) -and ($_.Name -like $StageFilter) } |
    Sort-Object Name
)

if ($stageRoots.Count -eq 0) {
    throw "No Stage folders matched '$StageFilter' under $DriveRoot"
}

$targets = New-Object 'Collections.Generic.List[object]'
$seen = @{}
foreach ($stageRoot in $stageRoots) {
    Find-TargetsForStage -StageRoot $stageRoot -Targets $targets -Seen $seen
}

$results = New-Object 'Collections.Generic.List[object]'

foreach ($target in ($targets | Sort-Object Stage,RelativePath)) {
    $markerPath = Join-Path $target.FolderPath $MarkerName
    $otherMarkers = @(
        Get-ChildItem -LiteralPath $target.FolderPath -File `
            -Filter '_MSB-DB-Source-Folder*.txt' -ErrorAction SilentlyContinue |
        Where-Object { $_.Name -ne $MarkerName }
    )

    if (Test-Path -LiteralPath $markerPath -PathType Leaf) {
        $action = 'SKIPPED_EXISTING'
        $message = 'Exact marker already exists; local notes preserved.'
    }
    elseif ($otherMarkers.Count -gt 0) {
        $action = 'REVIEW_EXISTING_MARKER'
        $message = "Different marker already exists: $($otherMarkers.Name -join ', ')"
    }
    elseif (-not $Apply) {
        $action = 'WOULD_CREATE'
        $message = 'Preview only.'
    }
    else {
        $content = Get-HelperMarkerText -FolderType $target.TargetType
        Set-Content -LiteralPath $markerPath -Value $content -Encoding UTF8
        $action = 'CREATED'
        $message = 'Marker created.'
    }

    $results.Add([pscustomobject]@{
        Stage        = $target.Stage
        TargetType   = $target.TargetType
        RelativePath = $target.RelativePath
        MarkerPath   = $markerPath
        Action       = $action
        Message      = $message
    })
}

$reportDir = Split-Path -Parent $ReportPath
if ($reportDir -and -not (Test-Path -LiteralPath $reportDir)) {
    New-Item -ItemType Directory -Path $reportDir -Force | Out-Null
}
$results | Export-Csv -LiteralPath $ReportPath -NoTypeInformation -Encoding UTF8

Write-Host ''
Write-Host 'MSB DB Source Folder Marker Population'
Write-Host "Drive root: $DriveRoot"
Write-Host "Stage filter: $StageFilter"
Write-Host "Mode: $(if ($Apply) { 'APPLY' } else { 'PREVIEW ONLY' })"
Write-Host "Targets: $($results.Count)"
Write-Host "Created: $(@($results | Where-Object Action -eq 'CREATED').Count)"
Write-Host "Would create: $(@($results | Where-Object Action -eq 'WOULD_CREATE').Count)"
Write-Host "Already present: $(@($results | Where-Object Action -eq 'SKIPPED_EXISTING').Count)"
Write-Host "Review: $(@($results | Where-Object Action -eq 'REVIEW_EXISTING_MARKER').Count)"
Write-Host "Report: $ReportPath"
Write-Host ''

$results |
    Select-Object Stage,TargetType,RelativePath,Action |
    Format-Table -AutoSize

if (-not $Apply) {
    Write-Host ''
    Write-Host 'PREVIEW ONLY — no marker files were created.'
    Write-Host 'Review the output, then re-run with -Apply.'
}
