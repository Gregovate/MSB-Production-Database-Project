@echo off
REM setup_env.bat — GAL 25-10-29
setlocal
if not exist .venv (
  py -m venv .venv
)
call .venv\Scripts\activate.bat
python -m pip install --upgrade pip
python -m pip install -r requirements.txt
echo Env ready. To run: call .venv\Scripts\activate.bat && python FormView.py
endlocal
