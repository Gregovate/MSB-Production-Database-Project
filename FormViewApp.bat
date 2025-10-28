@echo off
setlocal
title MSB Database - FormViewApp Launcher

rem ============================================================
rem  MSB Database — FormViewApp Launcher
rem  GAL 25-10-25
rem  This ensures a visible console, logs any errors, and checks
rem  that the G: drive and database file exist before launching.
rem ============================================================

rem ---- Canonical EXE on shared drive ----
set "SRC=G:\Shared drives\MSB Database\Apps\FormView\current\FormViewSA.exe"

rem ---- Local per-user cache (avoids network execution issues) ----
set "CACHE=%LOCALAPPDATA%\MSB\FormView\FormViewSA.exe"
set "LOG=%LOCALAPPDATA%\MSB\FormView\FormViewApp.log"
set "DB=G:\Shared drives\MSB Database\database\lor_output_v6.db"

mkdir "%LOCALAPPDATA%\MSB\FormView" >nul 2>nul

echo ===== %date% %time% (%USERNAME%) ===== >> "%LOG%"

rem --- Basic checks ---
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

rem --- Auto-update local cache if shared EXE is newer ---
for %%I in ("%SRC%")   do set "SRC_SZ=%%~zI"   & set "SRC_TM=%%~tI"
for %%I in ("%CACHE%") do set "CACHE_SZ=%%~zI" & set "CACHE_TM=%%~tI"

if not exist "%CACHE%" (
  echo [INFO] First copy to cache >> "%LOG%"
  copy /y "%SRC%" "%CACHE%" >nul
) else (
  if not "%SRC_SZ%"=="%CACHE_SZ%" if not "%SRC_TM%"=="%CACHE_TM%" (
    echo [INFO] New version detected; updating cache >> "%LOG%"
    copy /y "%SRC%" "%CACHE%" >nul
  )
)

rem --- Launch from local cache ---
echo [INFO] Launching cached exe >> "%LOG%"
start "" "%CACHE%"
exit /b 0
