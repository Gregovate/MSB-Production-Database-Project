# setup_env.ps1 — GAL 25-10-29
$ErrorActionPreference = 'Stop'

Write-Host "🔧 Creating/using venv at .venv"
if (!(Test-Path .venv)) { py -m venv .venv }

# Activate the venv for this session
$activate = ".\.venv\Scripts\Activate.ps1"
if (Test-Path $activate) { & $activate } else { throw "Could not find $activate" }

Write-Host "⬆️  Upgrading pip"
python -m pip install --upgrade pip

Write-Host "📦 Installing requirements"
python -m pip install -r requirements.txt

Write-Host "✅ Env ready. Use: .\.venv\Scripts\Activate.ps1 then python FormView.py"
