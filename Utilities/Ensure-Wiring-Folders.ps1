# ===============================================================
# Ensure-Wiring-Folders.ps1
# GAL 2025-10-30
# Purpose:
#   Verify that every stage folder under "Display Folders"
#   has the full Wiring subfolder structure:
#       Wiring\
#           BackgroundStage\
#               SourceDocs\
#           MusicalStage\
#               SourceDocs\
#
#   Existing folders are left untouched.
# ===============================================================

# --- Root of all display folders ---
$root = "G:\Shared drives\Display Folders"

# --- Get all stage folders starting with two digits and a dash ---
$stageFolders = Get-ChildItem -Path $root -Directory | Where-Object {
    $_.Name -match '^\d{2}-'
}

foreach ($stage in $stageFolders) {
    Write-Host "Checking: $($stage.Name)" -ForegroundColor Cyan

    $wiringRoot      = Join-Path $stage.FullName "Wiring"
    $backgroundStage = Join-Path $wiringRoot "BackgroundStage"
    $backgroundSrc   = Join-Path $backgroundStage "SourceDocs"
    $musicalStage    = Join-Path $wiringRoot "MusicalStage"
    $musicalSrc      = Join-Path $musicalStage "SourceDocs"

    # List of required paths
    $required = @($wiringRoot, $backgroundStage, $backgroundSrc, $musicalStage, $musicalSrc)

    foreach ($path in $required) {
        if (-not (Test-Path $path)) {
            New-Item -ItemType Directory -Path $path | Out-Null
            Write-Host "  Created: $path" -ForegroundColor Green
        } else {
            Write-Host "  Exists:  $path" -ForegroundColor DarkGray
        }
    }
}

Write-Host "`nAll stage folders verified." -ForegroundColor Yellow
