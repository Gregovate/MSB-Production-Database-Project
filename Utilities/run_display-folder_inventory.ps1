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

# Keep the report accumulator at script scope. Passing a List[string] that
# already contains the intentional blank header line through a Mandatory
# parameter causes PowerShell's parameter binder to reject the collection as
# containing an empty string. Mutating one script-scoped list avoids that
# binder behavior and keeps recursion simple.
$script:lines = [System.Collections.Generic.List[string]]::new()
$script:DoNotDescend = $DoNotDescend

[void]$script:lines.Add("MSB Google Shared Drive Folder Structure")
[void]$script:lines.Add("Root: $Root")
[void]$script:lines.Add("Generated: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')")
[void]$script:lines.Add("Maximum recursive depth below Stage root: $MaxDepth")
[void]$script:lines.Add("")
[void]$script:lines.Add("Display Folders")

function Add-FolderTree {
    param(
        [Parameter(Mandatory)]
        [string]$Path,

        [Parameter(Mandatory)]
        [int]$Depth,

        [Parameter(Mandatory)]
        [int]$MaxDepth
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
        [void]$script:lines.Add("${indent}[ERROR READING FOLDER: $($_.Exception.Message)]")
        return
    }

    foreach ($child in $children) {
        $indent = '    ' * ($Depth + 1)
        [void]$script:lines.Add("$indent|-- $($child.Name)")

        if ($child.Name -in $script:DoNotDescend) {
            continue
        }

        Add-FolderTree `
            -Path $child.FullName `
            -Depth ($Depth + 1) `
            -MaxDepth $MaxDepth
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
try {
    $rootFolders = @(
        Get-ChildItem -LiteralPath $Root -Directory -ErrorAction Stop |
        Sort-Object Name
    )
}
catch {
    throw "Unable to enumerate Display Folders root '$Root': $($_.Exception.Message)"
}

foreach ($folder in $rootFolders) {
    $isStageCandidate = $folder.Name -match '^\d{2}[A-Za-z]?-.+'

    if ($isStageCandidate) {
        [void]$script:lines.Add("|-- $($folder.Name)    [STAGE ROOT CANDIDATE]")

        Add-FolderTree `
            -Path $folder.FullName `
            -Depth 0 `
            -MaxDepth $MaxDepth
    }
    else {
        # Still record non-Stage root folders, but do not crawl them.
        [void]$script:lines.Add("|-- $($folder.Name)    [OTHER ROOT FOLDER]")
    }
}

$script:lines | Set-Content -LiteralPath $OutFile -Encoding UTF8

Write-Host ""
Write-Host "Folder inventory complete."
Write-Host "Report:"
Write-Host $OutFile
Write-Host ""
Write-Host "Lines written: $($script:lines.Count)"
