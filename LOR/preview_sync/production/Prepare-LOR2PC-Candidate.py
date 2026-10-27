"""Prepare named runtime files from a clean, exact committed checkout. No deploy."""
import hashlib
import json
from pathlib import Path
import shutil
import subprocess
import sys

root = Path(__file__).resolve().parents[3]
if subprocess.check_output(['git', 'status', '--porcelain'], cwd=root).strip():
    raise SystemExit('BLOCK: commit the candidate before preparing runtime files')
commit = subprocess.check_output(['git', 'rev-parse', 'HEAD'], cwd=root, text=True).strip()
target = Path(sys.argv[1]).resolve()
if target.exists():
    raise SystemExit('BLOCK: output destination already exists')
target.mkdir(parents=True)
source = Path(__file__).parent
files = {}
for name in ['Update_MSB_Previews.ps1', 'Install-LOR2PC-Launcher.ps1', 'Install MSB PC Preview Updater.vbs']:
    shutil.copy2(source / name, target / name)
    files[name] = hashlib.sha256((target / name).read_bytes()).hexdigest()
shutil.copy2(source.parent / 'artifacts/MSB Preview Update Tree v2.ico', target)
(target / 'DEPLOYMENT.json').write_text(json.dumps(dict(version='1.0.2', source_commit=commit,
    apply_enabled=False, acceptance='BROWSER_COMPARISON_ONLY', current_source_url='https://my.sheboyganlights.org/lor2db/preflight/api/current-source',
    updater_sha256=files['Update_MSB_Previews.ps1'], files=files), indent=2))
print(f'Prepared candidate {commit}: {target}; not deployed')
