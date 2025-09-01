@echo off
setlocal
rem Run from repo root; data is on G:
pushd %~dp0\..
py preview_merger.py
if errorlevel 1 (
  echo.
  echo >> Error running dry-run. See console output above.
  pause
  exit /b 1
)
rem Open the HTML compare report if present
if exist "G:\Shared drives\MSB Database\database\merger\reports\lorprev_compare.html" (
  start "" "G:\Shared drives\MSB Database\database\merger\reports\lorprev_compare.html"
)
pause
