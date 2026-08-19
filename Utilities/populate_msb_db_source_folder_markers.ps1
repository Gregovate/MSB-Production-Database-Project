<#
.SYNOPSIS
Populates MSB database/source marker files in the existing Display Folders tree.

.DESCRIPTION
PREVIEW ONLY by default. Use -Apply to write files.

Creates ONLY:
  _MSB-DB-Source-Folder_READ-ME-FIRST-AND-DO-NOT-DELETE.txt

Targets:
- every detected Stage root;
- every detected Substage root;
- every detected Scene root;
- existing PreviewBackground folders;
- existing Procedures folders at Stage/Substage/Scene scope;
- existing Wiring folders at Stage/Substage/Scene scope.

It does NOT create, rename, move, or delete folders.
It does NOT overwrite an existing exact marker, preserving LOCAL NOTES.
Photos is not marked.
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

function Get-ScopeKind {
    param(
        [IO.DirectoryInfo]$Dir,
        [IO.DirectoryInfo]$StageRoot
    )

    if ($Dir.FullName -eq $StageRoot.FullName) { return 'STAGE' }

    # Governing folder rules:
    # NNa-Name-XY = Substage
    # NN-Name     = Scene
    # NNa-Name    = Scene under Substage
    if ($Dir.Name -match '^\d{2}[A-Za-z]-.+-[A-Za-z]{2,3}$') { return 'SUBSTAGE' }
    if ($Dir.Name -match '^\d{2}[A-Za-z]?-.+') { return 'SCENE' }

    return $null
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

function Get-RootMarkerText {
    param([string]$ScopeKind,[string]$FolderName)

    $label = switch ($ScopeKind) {
        'STAGE'    { 'STAGE ROOT' }
        'SUBSTAGE' { 'SUBSTAGE ROOT' }
        'SCENE'    { 'SCENE ROOT' }
        default    { 'STRUCTURED ROOT' }
    }

    return (Get-StandardHeader) + @"
FOLDER PURPOSE — $label

Folder:
$FolderName

This folder is an aligned structural scope used by the MSB Production Database,
Light-O-Rama (LOR), Folder Alignment, and database-backed applications.

IMPORTANT — DO NOT RENAME OR MOVE THIS FOLDER
- Do not rename or move this Stage, Substage, or Scene folder unless an approved
  alignment change specifically requires it.
- LOR BackgroundFile pointers, database path evidence, and application resolution
  may depend on this folder name and hierarchy.
- Keep this marker file in this folder.

LEGACY CONTENT BOUNDARY
This root may contain loose files and legacy folders accumulated over many years.
Those items may remain in place while cleanup continues.

Loose files and unmarked folders under this root are NOT automatically current
database/application source content.

Current application source content is limited to approved marked child folders,
including as applicable:
- PreviewBackground
- Procedures
- Wiring

Photos is not currently a database/application source folder.

Preserve uncertain legacy material until it is deliberately reviewed and aligned.
Do not reorganize the root merely to make it look clean.

"@ + (Get-LinksAndNotes)
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
- Do not rename or move this folder.
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
- Do not rename or move this folder.
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
- Do not rename or move this folder.
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
        [string]$ScopeKind,
        [IO.DirectoryInfo]$StageRoot
    )

    $key = $Folder.FullName.ToLowerInvariant()
    if ($Seen.ContainsKey($key)) { return }
    $Seen[$key] = $true

    $List.Add([pscustomobject]@{
        Stage        = $StageRoot.Name
        TargetType   = $TargetType
        ScopeKind    = $ScopeKind
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
        $scopeKind = Get-ScopeKind -Dir $current -StageRoot $StageRoot

        if ($scopeKind) {
            Add-Target -List $Targets -Seen $Seen -Folder $current `
                -TargetType 'ScopeRoot' -ScopeKind $scopeKind -StageRoot $StageRoot
        }

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
                    Add-Target -List $Targets -Seen $Seen -Folder $child `
                        -TargetType 'PreviewBackground' -ScopeKind $null -StageRoot $StageRoot
                    continue
                }
                'Procedures' {
                    if ($scopeKind) {
                        Add-Target -List $Targets -Seen $Seen -Folder $child `
                            -TargetType 'Procedures' -ScopeKind $null -StageRoot $StageRoot
                    }
                    continue
                }
                'Wiring' {
                    if ($scopeKind) {
                        Add-Target -List $Targets -Seen $Seen -Folder $child `
                            -TargetType 'Wiring' -ScopeKind $null -StageRoot $StageRoot
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
        if ($target.TargetType -eq 'ScopeRoot') {
            $content = Get-RootMarkerText -ScopeKind $target.ScopeKind `
                -FolderName (Split-Path -Leaf $target.FolderPath)
        }
        else {
            $content = Get-HelperMarkerText -FolderType $target.TargetType
        }

        Set-Content -LiteralPath $markerPath -Value $content -Encoding UTF8
        $action = 'CREATED'
        $message = 'Marker created.'
    }

    $results.Add([pscustomobject]@{
        Stage        = $target.Stage
        TargetType   = $target.TargetType
        ScopeKind    = $target.ScopeKind
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
    Select-Object Stage,TargetType,ScopeKind,RelativePath,Action |
    Format-Table -AutoSize

if (-not $Apply) {
    Write-Host ''
    Write-Host 'PREVIEW ONLY — no marker files were created.'
    Write-Host 'Review the output, then re-run with -Apply.'
}
