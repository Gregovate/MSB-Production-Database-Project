@echo off
title Build FormViewSA
echo ===========================================================
echo  MSB Database - Build FormViewSA
echo  GAL 25-10-28
echo ===========================================================
echo.

rem Run the PowerShell builder (temporary bypass)
powershell -ExecutionPolicy Bypass -NoProfile -File "%~dp0build_formview.ps1"
if errorlevel 1 (
  echo.
  echo Build failed. See the PowerShell output above.
  pause
  exit /b 1
)

rem Open the shared output folder if the build succeeded
start "" "G:\Shared drives\MSB Database\Apps\FormView\current"

echo.
echo Build complete and copied to:
echo   G:\Shared drives\MSB Database\Apps\FormView\current\FormViewSA.exe
echo.
pause
