# ============================================================================
# Command: Save Display Folder Tree
# Purpose: Write the numbered stage-folder structure to a text file.
# Safety: READ ONLY except for creating the output text file.
# ============================================================================

$Root = "G:\Shared drives\Display Folders"
$OutputFile = "$env:USERPROFILE\Desktop\Display_Folder_Tree.txt"

Get-ChildItem -Path $Root -Directory |
    Where-Object { $_.Name -match '^\d{2}-' } |
    Sort-Object Name |
    ForEach-Object {
        $_.Name

        Get-ChildItem -Path $_.FullName -Directory -Recurse -Depth 2 |
            Sort-Object FullName |
            ForEach-Object {
                $relative = $_.FullName.Substring($_.Directory.Parent.FullName.Length + 1)
                $level = ($relative -split '[\\/]').Count
                ('    ' * $level) + $_.Name
            }
    } | Set-Content -Path $OutputFile

Write-Host "Folder tree saved to: $OutputFile"