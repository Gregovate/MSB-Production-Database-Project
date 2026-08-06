@echo off
setlocal
pushd %~dp0\..
py preview_merger.py --apply
pause
