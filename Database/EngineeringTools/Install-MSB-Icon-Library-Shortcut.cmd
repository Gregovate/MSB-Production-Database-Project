@echo off
setlocal
REM One-time install: double-click this from the repository EngineeringTools folder.
set "MSB_ICON_LAUNCHER=%~dp0Launch-MSB-Icon-Library.cmd"
set "MSB_ICON_ARTWORK=%~dp0assets\MSB-Icon-Library-Manager.ico"
if not exist "%MSB_ICON_LAUNCHER%" (
  echo Could not find Icon Library Manager launcher: "%MSB_ICON_LAUNCHER%"
  pause
  exit /b 1
)
if not exist "%MSB_ICON_ARTWORK%" (
  echo Cannot install the branded shortcut because its app icon is missing:
  echo "%MSB_ICON_ARTWORK%"
  echo Update your authorized Git checkout, then retry. No shortcut changed.
  pause
  exit /b 1
)
powershell.exe -NoProfile -Command "$desk=[Environment]::GetFolderPath('Desktop'); if (-not (Test-Path -LiteralPath $desk)) { throw 'Desktop folder is unavailable' }; $p=Join-Path $desk 'MSB Icon Library Manager.lnk'; $sh=New-Object -ComObject WScript.Shell; $lnk=$sh.CreateShortcut($p); $lnk.TargetPath=$env:MSB_ICON_LAUNCHER; $lnk.WorkingDirectory=Split-Path -Parent $env:MSB_ICON_LAUNCHER; $lnk.Description='Manage MSB GIS Icons from controlled Shared Drive source'; $lnk.IconLocation=$env:MSB_ICON_ARTWORK+',0'; $lnk.Save(); Write-Host ('Desktop shortcut created: '+$p)"
if errorlevel 1 (
  echo Shortcut installation failed. No source assets were changed.
  pause
  exit /b 1
)
echo Custom MSB Icon Library Manager shortcut icon configured.
echo Double-click the 'MSB Icon Library Manager' icon on your Desktop next time.
pause