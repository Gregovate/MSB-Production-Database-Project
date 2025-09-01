@echo off
setlocal
pushd %~dp0\..
rem Generate CSVs + index.html using the schema-compatible reporter
py tools\report_preview_history.py
if errorlevel 1 (
  echo.
  echo >> Reporter failed. See console output above.
  pause
  exit /b 1
)

rem Open the newest report folder’s index.html
set "R=G:\Shared drives\MSB Database\database\merger\reports"
for /f "delims=" %%D in ('dir /b /ad /o-d "%R%"') do (
  if exist "%R%\%%D\index.html" (
    start "" "%R%\%%D\index.html"
    goto :done
  )
)
:done
pause
