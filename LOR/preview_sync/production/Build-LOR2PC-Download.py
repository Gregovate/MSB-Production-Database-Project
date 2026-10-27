"""Build the immutable site ZIP from a clean exact checkout; never deploy it."""
from pathlib import Path
import subprocess
import sys
import tempfile
import zipfile

ROOT = Path(__file__).resolve().parents[3]
TARGET = ROOT/'LOR2DB/Application/landing/pc/downloads/MSB-PC-Preview-Updater-1.0.3.zip'
if TARGET.exists():
    raise SystemExit('BLOCK: versioned installer archive already exists; do not overwrite')
with tempfile.TemporaryDirectory(prefix='msb-lor2pc-package-') as temporary:
    runtime = Path(temporary)/'runtime'
    subprocess.run([sys.executable, str(Path(__file__).with_name('Prepare-LOR2PC-Candidate.py')), str(runtime)], check=True)
    TARGET.parent.mkdir(parents=True, exist_ok=True)
    # Fixed timestamps and names make a rebuild of the same committed source reproducible.
    with zipfile.ZipFile(TARGET, 'x', compression=zipfile.ZIP_DEFLATED) as archive:
        for source in sorted(runtime.iterdir()):
            entry = zipfile.ZipInfo(source.name, date_time=(1980,1,1,0,0,0))
            entry.compress_type = zipfile.ZIP_DEFLATED
            archive.writestr(entry, source.read_bytes())
print('Prepared site download only: '+str(TARGET))
