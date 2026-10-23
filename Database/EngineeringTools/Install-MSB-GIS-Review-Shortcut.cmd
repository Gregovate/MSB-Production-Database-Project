@echo off
setlocal
REM #171 test ONLY. Create a separate Desktop shortcut for the isolated
REM Office Desktop review worktree. Never replace the daily Icon Manager link.
set "REVIEW_LAUNCHER=%~dp0Launch-MSB-Icon-Library.cmd"
set "REVIEW_ICON=%~dp0assets\MSB-Icon-Library-Manager.ico"
if not exist "%REVIEW_LAUNCHER%" (
  echo Cannot find the #171 review launcher. Nothing changed.
  pause
  exit /b 1
)
if not exist "%REVIEW_ICON%" (
  echo Cannot find the review shortcut icon. Nothing changed.
  pause
  exit /b 1
)
powershell.exe -NoProfile -Command "$ErrorActionPreference='Stop'; $desktop=[Environment]::GetFolderPath('Desktop'); if (-not (Test-Path -LiteralPath $desktop)) { throw 'Windows Desktop is unavailable' }; $link=Join-Path $desktop 'MSB GIS Review #171.lnk'; if (Test-Path -LiteralPath $link) { throw 'Review shortcut already exists. Refusing to overwrite it.' }; $w=New-Object -ComObject WScript.Shell; $s=$w.CreateShortcut($link); $s.TargetPath=$env:REVIEW_LAUNCHER; $s.WorkingDirectory=Split-Path -Parent $env:REVIEW_LAUNCHER; $s.IconLocation=$env:REVIEW_ICON+',0'; $s.Description='TEST ONLY - PR #378 MSB GIS Office ExpertGPS reconnaissance'; $s.Save(); Write-Host ('Review shortcut created: '+$link)"
if errorlevel 1 (
  echo #171 review shortcut installation stopped. Existing shortcuts preserved.
  pause
  exit /b 1
)
echo.
echo Created MSB GIS Review #171 on this Windows Desktop.
echo This review shortcut points to the isolated candidate checkout.
echo The normal MSB Icon Library Manager shortcut remains unchanged.
pause
