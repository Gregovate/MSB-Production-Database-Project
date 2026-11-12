@echo off
setlocal
pushd %~dp0\..
if exist .git (
  git pull --ff-only
) else (
  echo This folder is not a Git clone. Re-download the ZIP from:
  echo https://github.com/Gregovate/MSB-Production-Database-Project
)
pause
