@echo off
setlocal
title MSB Database - FormViewApp Launcher (GAL 25-10-29)

rem ---- canonical EXE on shared drive ----
set "SRC=G:\Shared drives\MSB Database\Apps\FormView\current\FormViewSA.exe"

rem ---- local per-user cache ----
set "CACHE_DIR=%LOCALAPPDATA%\MSB\FormView"
set "CACHE=%CACHE_DIR%\FormViewSA.exe"
set "LOG=%CACHE_DIR%\FormViewApp.log"
set "DB=G:\Shared drives\MSB Database\database\lor_output_v6.db"

if not exist "%CACHE_DIR%" mkdir "%CACHE_DIR%" >nul 2>nul
echo ===== %date% %time% (%USERNAME%) ===== >> "%LOG%"

rem --- single-instance guard ---
tasklist /FI "IMAGENAME eq FormViewSA.exe" | find /I "FormViewSA.exe" >NUL
if not errorlevel 1 (
  echo [INFO] Already running; exiting launcher. >> "%LOG%"
  goto :EOF
)

rem --- prerequisites ---
if not exist "G:\" (
  echo [ERR] G: missing >> "%LOG%"
  echo G: drive is not mapped. Please open Google Drive or remap.
  pause & exit /b 1
)
if not exist "%DB%" (
  echo [ERR] DB missing at %DB% >> "%LOG%"
  echo Database not found: %DB%
  pause & exit /b 1
)
if not exist "%SRC%" (
  echo [ERR] SRC exe missing at %SRC% >> "%LOG%"
  echo Application not found: %SRC%
  pause & exit /b 1
)

rem --- copy/update local cache atomically to avoid AV hiccups ---
for %%I in ("%SRC%")   do set "SRC_SZ=%%~zI"   & set "SRC_TM=%%~tI"
for %%I in ("%CACHE%") do set "CACHE_SZ=%%~zI" & set "CACHE_TM=%%~tI"

if not exist "%CACHE%" (
  echo [INFO] First copy to cache >> "%LOG%"
  copy /y "%SRC%" "%CACHE%" >nul
) else (
  if not "%SRC_SZ%"=="%CACHE_SZ%" if not "%SRC_TM%"=="%CACHE_TM%" (
    echo [INFO] New version detected; updating cache >> "%LOG%"
    copy /y "%SRC%" "%CACHE%.new" >nul
    if exist "%CACHE%.new" (
      move /y "%CACHE%.new" "%CACHE%" >nul
    )
  )
)

rem --- tiny settle delay helps some AVs ---
timeout /t 1 /nobreak >nul

rem --- launch minimized, with correct working dir, then exit launcher ---
echo [INFO] Launching cached exe >> "%LOG%"
start "" /MIN /D "%CACHE_DIR%" "%CACHE%"
exit /b 0
