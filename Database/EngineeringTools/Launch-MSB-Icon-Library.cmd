@echo off
setlocal
REM MSB #171 Stable GUI launcher. Create a Desktop shortcut to this file once.
set "HERE=%~dp0"
set "PYTHONW="
if exist "%HERE%..\..\.venv\Scripts\pythonw.exe" set "PYTHONW=%HERE%..\..\.venv\Scripts\pythonw.exe"
if not defined PYTHONW if exist "%LOCALAPPDATA%\Programs\Python\Python313\pythonw.exe" set "PYTHONW=%LOCALAPPDATA%\Programs\Python\Python313\pythonw.exe"
if not defined PYTHONW if exist "%LOCALAPPDATA%\Programs\Python\Python312\pythonw.exe" set "PYTHONW=%LOCALAPPDATA%\Programs\Python\Python312\pythonw.exe"
if not defined PYTHONW if exist "%LOCALAPPDATA%\Programs\Python\Python311\pythonw.exe" set "PYTHONW=%LOCALAPPDATA%\Programs\Python\Python311\pythonw.exe"
if not defined PYTHONW (
  echo Python is not configured for the Icon Library Manager.
  echo Use a Python installation with Tkinter, then configure this launch shortcut.
  pause
  exit /b 1
)
start "MSB Icon Library Manager" "%PYTHONW%" "%HERE%icon_library_manager.pyw"