# build_formview.ps1 — GAL 2025-10-25
$ErrorActionPreference = 'Stop'
Set-Location "C:\lor\ImportExport\VSCode"

# ==== Version + metadata you control ====
$Version   = '0.2.4'
$Company   = 'Engineering Innovations, LLC'
$Product   = 'MSB Database - FormView'         # use ASCII hyphen, not em-dash
$FileDesc  = 'Wiring & Stage Tools (Tkinter)'  # single quotes avoid & issues
$Copyright = '(c) 2025 Engineering Innovations, LLC'


# (Optional) app icon — put an .ico next to FormView.py and set this path:
$IconPath  = ''  # e.g., "$PWD\formview.ico" or leave blank to skip

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
Remove-Item -Recurse -Force $BuildRoot -ErrorAction SilentlyContinue

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

$piArgs = @(
  $SrcPy,
  '--onefile','--noconsole',
  '--name','FormViewSA',
  '--distpath',$DistPath,
  '--workpath',$WorkPath,
  '--specpath',$SpecPath,
  '--version-file',$VerFileAbs,
  '--hidden-import=tkinter',
  '--hidden-import=tkinter.filedialog',
  '--hidden-import=tkinter.messagebox'
)
if ($IconPath) { $piArgs += @('--icon', $IconPath) }

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

