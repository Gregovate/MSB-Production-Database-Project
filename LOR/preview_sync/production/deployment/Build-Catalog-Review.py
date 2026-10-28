"""Build engineering-only review handoff from exact clean committed source."""
import hashlib
import json
from pathlib import Path
import subprocess
import zipfile

SOURCE=Path(__file__).parent
ROOT=SOURCE.parents[3]
if subprocess.check_output(['git','status','--porcelain'],cwd=ROOT).strip():
    raise SystemExit('BLOCK: commit all source before preparing review handoff')
commit=subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip()
files={name:(SOURCE/name).read_bytes() for name in ('Review-LOR2PC-Catalog.ps1','review_clone.sh','READ ME - Catalog Review.txt')}
files['SOURCE.json']=(json.dumps(dict(source_commit=commit,files={name:hashlib.sha256(raw).hexdigest() for name,raw in files.items()}),indent=2)+'\n').encode()
output=ROOT/'LOR/preview_sync/artifacts/LOR2PC-Catalog-Review-1.1.0-r3.zip'
if output.exists(): raise SystemExit('BLOCK: do not overwrite immutable review archive')
with zipfile.ZipFile(output,'w',zipfile.ZIP_DEFLATED) as archive:
    for name,raw in sorted(files.items()):
        item=zipfile.ZipInfo(name,date_time=(1980,1,1,0,0,0));item.compress_type=zipfile.ZIP_DEFLATED
        archive.writestr(item,raw)
print(output)
print('Source: '+commit)
print('SHA256: '+hashlib.sha256(output.read_bytes()).hexdigest())
