@echo off
setlocal
REM #171 stable launcher. Prefer checkout .venv; preflight dependencies and
REM keep diagnostics visible when the app cannot start.
set "HERE=%~dp0"
pushd "%HERE%" || (echo Cannot enter the GIS Manager folder. & pause & exit /b 1)
set "PYTHON="
if exist "%HERE%..\..\.venv\Scripts\python.exe" set "PYTHON=%HERE%..\..\.venv\Scripts\python.exe"
if not defined PYTHON if exist "%LOCALAPPDATA%\Programs\Python\Python313\python.exe" set "PYTHON=%LOCALAPPDATA%\Programs\Python\Python313\python.exe"
if not defined PYTHON if exist "%LOCALAPPDATA%\Programs\Python\Python312\python.exe" set "PYTHON=%LOCALAPPDATA%\Programs\Python\Python312\python.exe"
if not defined PYTHON if exist "%LOCALAPPDATA%\Programs\Python\Python311\python.exe" set "PYTHON=%LOCALAPPDATA%\Programs\Python\Python311\python.exe"
if not defined PYTHON (
  echo MSB GIS Manager could not find a supported Python installation.
  echo Update or install the approved workstation environment and retry.
  pause
  exit /b 1
)
"%PYTHON%" -c "import tkinter; import PIL; import garmin_bmp_derivatives; import garmin_gpx_export; import garmin_bmp_promotion" >nul 2>&1
if errorlevel 1 (
  echo MSB GIS Manager dependencies are missing from:
  echo   %PYTHON%
  echo Required: Python Tkinter and Pillow, plus checked-in GIS tool modules.
  echo No GIS data or workstation configuration was changed.
  echo Run the installer diagnostics or ask the GIS administrator.
  pause
  exit /b 1
)
set "PYTHONW=%PYTHON:python.exe=pythonw.exe%"
if not exist "%PYTHONW%" (
  echo Python GUI executable is missing: %PYTHONW%
  pause
  exit /b 1
)
start "MSB GIS Manager" "%PYTHONW%" "%HERE%icon_library_manager.pyw"
if errorlevel 1 (
  echo Failed to launch MSB GIS Manager. No data changed.
  pause
  exit /b 1
)
