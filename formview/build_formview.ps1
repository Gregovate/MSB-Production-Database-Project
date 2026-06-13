# ============================================================
#  MSB Database — Build Script for FormViewSA
#  GAL 2025-10-25
# ============================================================
#  Purpose:
#    Packages FormView.py into a standalone EXE using PyInstaller.
#    Bundles Docs\images (PNG + ICO) for runtime icons and splash.
#
#  Notes:
#    - Builds to build_artifacts\dist\FormViewSA.exe
#    - Uses local version.txt for embedded version info
#    - Includes tkinter imports to prevent runtime omissions
#    - Called by build_formview.bat on successful build
#
#  Revision History:
#    2025-10-25  GAL  Initial release for EXE build
#    2025-10-29  GAL  Added --add-data Docs\images (bundle PNG+ICO)
#                     and stable build paths for smoother splash/icon handling.
# ============================================================
# 
$ErrorActionPreference = 'Stop'
Set-Location "C:\lor\ImportExport\VSCode"

# ==== Version + metadata you control ====
# --- Read version from FormView.py (APP_VERSION = "X.Y.Z") ---
$FormViewPath = Join-Path $PWD 'formview.py'     # note: lowercase if your file is lowercase
$Version = (Select-String -Path $FormViewPath -Pattern 'APP_VERSION\s*=\s*"([^"]+)"' -ErrorAction Stop |
           Select-Object -First 1).Matches[0].Groups[1].Value
Write-Host "Detected APP_VERSION from formview.py: $Version"
$Company   = 'Engineering Innovations, LLC'
$Product   = 'MSB Database - FormView'         # use ASCII hyphen, not em-dash
$FileDesc  = 'Wiring & Stage Tools (Tkinter)'  # single quotes avoid & issues
$Copyright = '(c) 2025 Engineering Innovations, LLC'


# (Optional) app icon — put an .ico next to FormView.py and set this path:
$IconPath = "$PWD\Docs\images\formview.ico"
if (-not (Test-Path $IconPath)) { throw "Icon not found: $IconPath" }


# ==== Paths ====
$BuildRoot = "build_artifacts"
$DistPath  = Join-Path $BuildRoot "dist"
$WorkPath  = Join-Path $BuildRoot "build"
$SpecPath  = $BuildRoot
$ExeName   = "FormViewSA.exe"
$SrcPy     = "FormView.py"
$OutExe    = Join-Path $DistPath $ExeName

$DestDir   = "G:\Shared drives\MSB Database\Apps\FormView\current"
$DestExe   = Join-Path $DestDir $ExeName

# ==== Clean local artifacts (optional) ====
Remove-Item -Recurse -Force .\build_artifacts\build, .\build_artifacts\dist, .\FormViewSA.spec -ErrorAction SilentlyContinue

# ==== Generate a temp version file for PyInstaller (no comments, strict syntax) ====
$VerFile = Join-Path $BuildRoot "version.txt"
New-Item -ItemType Directory -Path $BuildRoot -Force | Out-Null

# Split version into four integers
$verParts = ($Version -split '\.') + @('0','0','0','0')
$major,$minor,$patch,$build = $verParts[0..3]

# Build the exact text PyInstaller expects (NO comments)
$versionTxt = @"
VSVersionInfo(
  ffi=FixedFileInfo(
    filevers=($major, $minor, $patch, $build),
    prodvers=($major, $minor, $patch, $build),
    mask=0x3f,
    flags=0x0,
    OS=0x40004,
    fileType=0x1,
    subtype=0x0,
    date=(0, 0)
  ),
  StringFileInfo(
    [
      StringTable(
        '040904B0',
        [
          StringStruct('CompanyName', '$Company'),
          StringStruct('FileDescription', '$FileDesc'),
          StringStruct('FileVersion', '$Version'),
          StringStruct('InternalName', 'FormViewSA'),
          StringStruct('LegalCopyright', '$Copyright'),
          StringStruct('OriginalFilename', '$ExeName'),
          StringStruct('ProductName', '$Product'),
          StringStruct('ProductVersion', '$Version')
        ]
      )
    ]
  ),
  VarFileInfo([VarStruct('Translation', [1033, 1200])])
)
"@

$versionTxt | Set-Content -Path $VerFile -Encoding UTF8

# ==== Generate a temp version file for PyInstaller (STRICT format) ====
$VerFile = Join-Path $BuildRoot "version.txt"
New-Item -ItemType Directory -Path $BuildRoot -Force | Out-Null

# Split version into four integers
$verParts = ($Version -split '\.') + @('0','0','0','0')
$major,$minor,$patch,$build = $verParts[0..3]

# EXACT format PyInstaller expects (no comments)
$versionTxt = @"
VSVersionInfo(
  ffi=FixedFileInfo(
    filevers=($major, $minor, $patch, $build),
    prodvers=($major, $minor, $patch, $build),
    mask=0x3f,
    flags=0x0,
    OS=0x40004,
    fileType=0x1,
    subtype=0x0,
    date=(0, 0)
  ),
  kids=[
    StringFileInfo([
      StringTable(
        '040904B0',
        [
          StringStruct('CompanyName', '$Company'),
          StringStruct('FileDescription', '$FileDesc'),
          StringStruct('FileVersion', '$Version'),
          StringStruct('InternalName', 'FormViewSA'),
          StringStruct('LegalCopyright', '$Copyright'),
          StringStruct('OriginalFilename', '$ExeName'),
          StringStruct('ProductName', '$Product'),
          StringStruct('ProductVersion', '$Version')
        ]
      )
    ]),
    VarFileInfo([VarStruct('Translation', [1033, 1200])])
  ]
)
"@
$versionTxt | Set-Content -Path $VerFile -Encoding UTF8

# ==== Build with PyInstaller (absolute path; remove stale .spec) ====
$VerFileAbs = (Resolve-Path $VerFile).Path
$SpecFile   = Join-Path $SpecPath "FormViewSA.spec"
Remove-Item -Force $SpecFile -ErrorAction SilentlyContinue

# Paths
$ScriptRoot = Split-Path -Parent $PSCommandPath
$ImagesPath = Join-Path $ScriptRoot 'Docs\images'
$IconPath   = Join-Path $ImagesPath  'formview.ico'   # used by --icon

$piArgs = @(
  'formview.py',
  '--onefile','--noconsole','--clean',
  '--name','FormViewSA',
  '--distpath', (Join-Path $PWD 'build_artifacts\dist'),
  '--workpath', (Join-Path $PWD 'build_artifacts\build'),
  '--specpath', (Join-Path $PWD 'build_artifacts'),
  '--version-file', (Resolve-Path '.\build_artifacts\version.txt'),
  '--hidden-import=tkinter',
  '--hidden-import=tkinter.filedialog',
  '--hidden-import=tkinter.messagebox',
  '--icon', $IconPath
)
# Bundle the entire images folder so both PNG and ICO are present at runtime
# NOTE: On Windows, PyInstaller uses ';' between SRC and DEST.
$piArgs += @('--add-data', "$ImagesPath;Docs/images")

Write-Host "PyInstaller args: $($piArgs -join ' ')"
pyinstaller @piArgs

# ==== Deploy to shared folder ====
New-Item -ItemType Directory -Path $DestDir -Force | Out-Null
Copy-Item $OutExe $DestExe -Force
Unblock-File -Path $DestExe -ErrorAction SilentlyContinue

# ==== Report ====
$hash = (Get-FileHash $DestExe -Algorithm SHA256).Hash
$sz   = (Get-Item $DestExe).Length
Write-Host "Built and copied to: $DestExe"
Write-Host ("Size : {0:N0} bytes" -f $sz)
Write-Host "SHA256: $hash"
Write-Host "Version: $Version"

