# MSB Display Folders structure inventory
# READ ONLY - makes no changes to Google Drive

$Root = 'G:\Shared drives\Display Folders'
$OutFile = Join-Path $env:USERPROFILE 'Desktop\MSB_Display_Folders_Tree.txt'
$MaxDepth = 5

# Show these folders in the tree, but do not descend into them.
# Their internal contents are not needed for the current FieldWiring review.
$DoNotDescend = @(
    'Archived Photos',
    'Current Photos',
    'Photos',
    'PreviewBackground',
    'Procedures',
    'SourceDocs'
)

if (-not (Test-Path -LiteralPath $Root)) {
    throw "Display Folders root was not found: $Root"
}

$lines = [System.Collections.Generic.List[string]]::new()

$lines.Add("MSB Google Shared Drive Folder Structure")
$lines.Add("Root: $Root")
$lines.Add("Generated: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')")
$lines.Add("Maximum recursive depth below Stage root: $MaxDepth")
$lines.Add("")
$lines.Add("Display Folders")

function Add-FolderTree {
    param(
        [Parameter(Mandatory)]
        [string]$Path,

        [Parameter(Mandatory)]
        [int]$Depth,

        [Parameter(Mandatory)]
        [int]$MaxDepth,

        [Parameter(Mandatory)]
        [System.Collections.Generic.List[string]]$Lines
    )

    if ($Depth -ge $MaxDepth) {
        return
    }

    try {
        $children = @(
            Get-ChildItem -LiteralPath $Path -Directory -ErrorAction Stop |
            Sort-Object Name
        )
    }
    catch {
        $indent = '    ' * ($Depth + 1)
        $Lines.Add("${indent}[ERROR READING FOLDER: $($_.Exception.Message)]")
        return
    }

    foreach ($child in $children) {
        $indent = '    ' * ($Depth + 1)
        $Lines.Add("$indent|-- $($child.Name)")

        if ($child.Name -in $DoNotDescend) {
            continue
        }

        Add-FolderTree `
            -Path $child.FullName `
            -Depth ($Depth + 1) `
            -MaxDepth $MaxDepth `
            -Lines $Lines
    }
}

# Show EVERY root-level folder so we can see that Display Folders contains
# engineering resources in addition to Stages.
#
# Only recurse into folders matching the current Stage/Sub-stage naming family:
#   NN-...
#   NNa-...
#
# Examples:
#   01-Front Entrance-FE
#   07-Whoville-WV
#   40-CommandCenter
$rootFolders = @(
    Get-ChildItem -LiteralPath $Root -Directory |
    Sort-Object Name
)

foreach ($folder in $rootFolders) {

    $isStageCandidate = $folder.Name -match '^\d{2}[A-Za-z]?-.+'

    if ($isStageCandidate) {
        $lines.Add("|-- $($folder.Name)    [STAGE ROOT CANDIDATE]")

        Add-FolderTree `
            -Path $folder.FullName `
            -Depth 0 `
            -MaxDepth $MaxDepth `
            -Lines $lines
    }
    else {
        # Still record non-Stage root folders, but do not crawl them.
        $lines.Add("|-- $($folder.Name)    [OTHER ROOT FOLDER]")
    }
}

$lines | Set-Content -LiteralPath $OutFile -Encoding UTF8

Write-Host ""
Write-Host "Folder inventory complete."
Write-Host "Report:"
Write-Host $OutFile
Write-Host ""
Write-Host "Lines written: $($lines.Count)"