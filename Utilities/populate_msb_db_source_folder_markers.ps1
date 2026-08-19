<#
.SYNOPSIS
Adds the standard MSB database-source marker file to existing Google Drive source folders.

.DESCRIPTION
READ/WRITE BOUNDARY:
- Reads the existing Google Shared Drive folder tree.
- Creates ONLY the marker file:
  _MSB-DB-Source-Folder_READ-ME-FIRST-AND-DO-NOT-DELETE.txt
- Does NOT create, rename, move, or delete folders.
- Does NOT overwrite an existing marker file, preserving any LOCAL NOTES already added.
- Does NOT recurse into SourceDocs, Archive, Photos, PreviewBackground, Procedures, or Wiring.

By default the script is PREVIEW ONLY. Use -Apply to actually create marker files.

Current marked source-folder types:
- PreviewBackground
- Procedures
- Wiring

Photos is intentionally NOT marked.

Examples:
  .\populate_msb_db_source_folder_markers.ps1
  .\populate_msb_db_source_folder_markers.ps1 -StageFilter '15-*'
  .\populate_msb_db_source_folder_markers.ps1 -Apply
  .\populate_msb_db_source_folder_markers.ps1 -StageFilter '15-*' -Apply
#>

[CmdletBinding()]
param(
    [string]$DriveRoot = 'G:\Shared drives\Display Folders',

    # Wildcard filter applied to the top-level Stage folder name.
    # Examples: '15-*', '02-*', '*' (default).
    [string]$StageFilter = '*',

    # Without -Apply the script is preview-only.
    [switch]$Apply,

    # Optional report destination. Default is the current user's Desktop.
    [string]$ReportPath
)

$ErrorActionPreference = 'Stop'

$MarkerFileName = '_MSB-DB-Source-Folder_READ-ME-FIRST-AND-DO-NOT-DELETE.txt'

# Never descend into these branches while discovering source-folder roots.
$NoRecurseNames = @(
    'PreviewBackground',
    'Procedures',
    'Wiring',
    'Photos',
    'SourceDocs',
    'Archive',
    'Archived',
    'images'
)

$PreviewBackgroundText = @'
MSB DATABASE SOURCE FOLDER
READ ME — DO NOT DELETE

This file identifies this folder as a source location used by the
MSB Production Database or an MSB database-backed application

FOLDER PURPOSE — PREVIEW BACKGROUND

This folder contains current background images used by Light-O-Rama (LOR)
Previews and Scenes and used as navigation/context pointers by MSB database-
backed applications.

Important:
- Do not delete this marker file.
- Do not rename or move this folder without following the MSB folder-alignment procedure.
- Do not rename, move, or delete an image that is currently referenced by LOR unless the LOR reference is also deliberately updated.
- Keep published/current background images in this folder. Use the established archive location for superseded material when applicable.

More information:
Marker operator procedure:
https://github.com/Gregovate/MSB-Production-Database-Project/blob/main/Docs/00_Project_Overview/03-MSB_DB_Source_Folder_Marker_Operator_Procedure.md

Google Drive document organization procedure:
https://github.com/Gregovate/MSB-Production-Database-Project/blob/main/Docs/00_Project_Overview/01-Google_Drive_Document_Organization_Procedure.md

LOCAL NOTES (optional)
Use this section for short human-readable notes about this folder, known
exceptions, pending cleanup, or other information future maintainers should know.
Do not remove the standard information above.

Notes:

'@

$ProceduresText = @'
MSB DATABASE SOURCE FOLDER
READ ME — DO NOT DELETE

This file identifies this folder as a source location used by the
MSB Production Database or an MSB database-backed application

FOLDER PURPOSE — PROCEDURES

This folder is the controlled source root for field procedures associated with
this Stage, Substage, or Scene. MSB database-backed applications may use this
folder and its approved procedure branches to locate current field instructions.

Important:
- Do not delete this marker file.
- Do not rename or move this folder without following the MSB folder-alignment procedure.
- Keep current field-facing material in the approved procedure locations.
- Archive and SourceDocs material is not normal field-facing content and must remain excluded from normal application presentation.

More information:
Marker operator procedure:
https://github.com/Gregovate/MSB-Production-Database-Project/blob/main/Docs/00_Project_Overview/03-MSB_DB_Source_Folder_Marker_Operator_Procedure.md

Google Drive document organization procedure:
https://github.com/Gregovate/MSB-Production-Database-Project/blob/main/Docs/00_Project_Overview/01-Google_Drive_Document_Organization_Procedure.md

LOCAL NOTES (optional)
Use this section for short human-readable notes about this folder, known
exceptions, pending cleanup, or other information future maintainers should know.
Do not remove the standard information above.

Notes:

'@

$WiringText = @'
MSB DATABASE SOURCE FOLDER
READ ME — DO NOT DELETE

This file identifies this folder as a source location used by the
MSB Production Database or an MSB database-backed application

FOLDER PURPOSE — WIRING

This folder is the controlled source root for published field wiring information
associated with this Stage, Substage, or Scene. FieldWiring uses the resolved
Stage/Scene context to locate the applicable BackgroundStage or MusicalStage
published wiring branch.

Important:
- Do not delete this marker file.
- Do not rename or move this folder without following the MSB folder-alignment procedure.
- Published field wiring images belong in BackgroundStage or MusicalStage as applicable.
- SourceDocs contains working/source material. Database-backed field applications must not descend into or present SourceDocs content.

More information:
Marker operator procedure:
https://github.com/Gregovate/MSB-Production-Database-Project/blob/main/Docs/00_Project_Overview/03-MSB_DB_Source_Folder_Marker_Operator_Procedure.md

Google Drive document organization procedure:
https://github.com/Gregovate/MSB-Production-Database-Project/blob/main/Docs/00_Project_Overview/01-Google_Drive_Document_Organization_Procedure.md

LOCAL NOTES (optional)
Use this section for short human-readable notes about this folder, known
exceptions, pending cleanup, or other information future maintainers should know.
Do not remove the standard information above.

Notes:

'@

function Test-TopLevelStageFolder {
    param([System.IO.DirectoryInfo]$Directory)

    # Current Stage folders begin with the two-digit Stage ID.
    # The script deliberately does not require a trailing two-letter code so
    # legacy/current Stage folders are not silently missed.
    return ($Directory.Name -match '^\d{2}-')
}

function Test-StructuredScopeFolder {
    param(
        [System.IO.DirectoryInfo]$Directory,
        [System.IO.DirectoryInfo]$StageRoot
    )

    if ($Directory.FullName -eq $StageRoot.FullName) {
        return $true
    }

    # Stage/Substage/Scene roots begin with the owning NN- or NNa- prefix.
    return ($Directory.Name -match '^\d{2}[A-Za-z]?-.+')
}

function Get-MarkerText {
    param([string]$FolderType)

    switch ($FolderType) {
        'PreviewBackground' { return $PreviewBackgroundText }
        'Procedures'        { return $ProceduresText }
        'Wiring'            { return $WiringText }
        default             { throw "Unsupported marker folder type: $FolderType" }
    }
}

function Get-RelativePathSafe {
    param(
        [string]$BasePath,
        [string]$ChildPath
    )

    try {
        return [System.IO.Path]::GetRelativePath($BasePath, $ChildPath)
    }
    catch {
        if ($ChildPath.StartsWith($BasePath, [System.StringComparison]::OrdinalIgnoreCase)) {
            return $ChildPath.Substring($BasePath.Length).TrimStart('\')
        }
        return $ChildPath
    }
}

function Add-Target {
    param(
        [System.Collections.Generic.List[object]]$Targets,
        [System.IO.DirectoryInfo]$Folder,
        [string]$FolderType,
        [System.IO.DirectoryInfo]$StageRoot
    )

    $key = $Folder.FullName.ToLowerInvariant()
    if ($script:SeenTargets.ContainsKey($key)) {
        return
    }

    $script:SeenTargets[$key] = $true

    $Targets.Add([pscustomobject]@{
        Stage        = $StageRoot.Name
        FolderType   = $FolderType
        FolderPath   = $Folder.FullName
        RelativePath = Get-RelativePathSafe -BasePath $DriveRoot -ChildPath $Folder.FullName
    })
}

function Find-StageTargets {
    param([System.IO.DirectoryInfo]$StageRoot)

    $targets = New-Object 'System.Collections.Generic.List[object]'
    $queue = New-Object 'System.Collections.Generic.Queue[System.IO.DirectoryInfo]'
    $queue.Enqueue($StageRoot)

    while ($queue.Count -gt 0) {
        $current = $queue.Dequeue()

        try {
            $children = @(Get-ChildItem -LiteralPath $current.FullName -Directory -Force -ErrorAction Stop)
        }
        catch {
            Write-Warning "Unable to enumerate folder: $($current.FullName) -- $($_.Exception.Message)"
            continue
        }

        foreach ($child in $children) {
            switch ($child.Name) {
                'PreviewBackground' {
                    # PreviewBackground is a DB/application source at Stage,
                    # Substage, Scene, and Display/shared-folder scope.
                    Add-Target -Targets $targets -Folder $child -FolderType 'PreviewBackground' -StageRoot $StageRoot
                    continue
                }

                'Procedures' {
                    # Procedures is marked only when it is the helper folder
                    # of a structured Stage/Substage/Scene scope.
                    if (Test-StructuredScopeFolder -Directory $current -StageRoot $StageRoot) {
                        Add-Target -Targets $targets -Folder $child -FolderType 'Procedures' -StageRoot $StageRoot
                    }
                    continue
                }

                'Wiring' {
                    # Wiring is marked only when it is the helper folder
                    # of a structured Stage/Substage/Scene scope.
                    if (Test-StructuredScopeFolder -Directory $current -StageRoot $StageRoot) {
                        Add-Target -Targets $targets -Folder $child -FolderType 'Wiring' -StageRoot $StageRoot
                    }
                    continue
                }

                default {
                    if ($NoRecurseNames -contains $child.Name) {
                        continue
                    }

                    # Skip hidden/system-like helper roots. Normal Stage, Scene,
                    # Substage, Display, and shared-document folders continue.
                    if ($child.Name.StartsWith('_')) {
                        continue
                    }

                    $queue.Enqueue($child)
                }
            }
        }
    }

    return $targets
}

if (-not (Test-Path -LiteralPath $DriveRoot -PathType Container)) {
    throw "Display Folders root was not found: $DriveRoot"
}

$resolvedDriveRoot = (Resolve-Path -LiteralPath $DriveRoot).Path
$DriveRoot = $resolvedDriveRoot

if (-not $ReportPath) {
    $desktop = [Environment]::GetFolderPath('Desktop')
    $stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
    $ReportPath = Join-Path $desktop "MSB_DB_Source_Folder_Marker_$stamp.csv"
}

$stageRoots = @(
    Get-ChildItem -LiteralPath $DriveRoot -Directory -Force |
        Where-Object {
            (Test-TopLevelStageFolder -Directory $_) -and
            ($_.Name -like $StageFilter)
        } |
        Sort-Object Name
)

if ($stageRoots.Count -eq 0) {
    throw "No top-level Stage folders matched '$StageFilter' under $DriveRoot"
}

$script:SeenTargets = @{}
$allTargets = New-Object 'System.Collections.Generic.List[object]'

foreach ($stageRoot in $stageRoots) {
    foreach ($target in (Find-StageTargets -StageRoot $stageRoot)) {
        $allTargets.Add($target)
    }
}

$results = New-Object 'System.Collections.Generic.List[object]'

foreach ($target in ($allTargets | Sort-Object Stage, RelativePath)) {
    $markerPath = Join-Path $target.FolderPath $MarkerFileName
    $otherMarkers = @(
        Get-ChildItem -LiteralPath $target.FolderPath -File -Filter '_MSB-DB-Source-Folder*.txt' -ErrorAction SilentlyContinue |
            Where-Object { $_.Name -ne $MarkerFileName }
    )

    $action = $null
    $message = $null

    if (Test-Path -LiteralPath $markerPath -PathType Leaf) {
        $action = 'SKIPPED_EXISTING'
        $message = 'Exact marker already exists; local notes preserved.'
    }
    elseif ($otherMarkers.Count -gt 0) {
        $action = 'REVIEW_EXISTING_MARKER'
        $message = "Different MSB DB source marker already exists: $($otherMarkers.Name -join ', '). No new marker created."
    }
    elseif (-not $Apply) {
        $action = 'WOULD_CREATE'
        $message = 'Preview only. Re-run with -Apply to create this marker.'
    }
    else {
        $content = Get-MarkerText -FolderType $target.FolderType
        Set-Content -LiteralPath $markerPath -Value $content -Encoding UTF8
        $action = 'CREATED'
        $message = 'Marker created.'
    }

    $results.Add([pscustomobject]@{
        Stage        = $target.Stage
        FolderType   = $target.FolderType
        RelativePath = $target.RelativePath
        MarkerPath   = $markerPath
        Action       = $action
        Message      = $message
    })
}

$reportFolder = Split-Path -Parent $ReportPath
if ($reportFolder -and -not (Test-Path -LiteralPath $reportFolder)) {
    New-Item -ItemType Directory -Path $reportFolder -Force | Out-Null
}

$results | Export-Csv -LiteralPath $ReportPath -NoTypeInformation -Encoding UTF8

$created = @($results | Where-Object Action -eq 'CREATED').Count
$wouldCreate = @($results | Where-Object Action -eq 'WOULD_CREATE').Count
$existing = @($results | Where-Object Action -eq 'SKIPPED_EXISTING').Count
$review = @($results | Where-Object Action -eq 'REVIEW_EXISTING_MARKER').Count

Write-Host ''
Write-Host 'MSB DB Source Folder Marker'
Write-Host "Drive root: $DriveRoot"
Write-Host "Stage filter: $StageFilter"
Write-Host "Mode: $(if ($Apply) { 'APPLY' } else { 'PREVIEW ONLY' })"
Write-Host ''
Write-Host "Targets found: $($results.Count)"
if ($Apply) {
    Write-Host "Created: $created"
}
else {
    Write-Host "Would create: $wouldCreate"
}
Write-Host "Already present: $existing"
Write-Host "Existing different marker names requiring review: $review"
Write-Host "Report: $ReportPath"
Write-Host ''

$results |
    Select-Object Stage, FolderType, RelativePath, Action |
    Format-Table -AutoSize

if (-not $Apply) {
    Write-Host ''
    Write-Host 'PREVIEW ONLY — no marker files were created.'
    Write-Host 'Review the report, then re-run with -Apply when ready.'
}
