"""Build a two-file programmer ZIP with self-contained setup; never deploy."""
import argparse
import base64
import hashlib
import io
from pathlib import Path
import subprocess
import sys
import tempfile
import zipfile

ROOT = Path(__file__).resolve().parents[3]
SOURCE = Path(__file__).parent
DOWNLOADS = ROOT/'LOR2DB/Application/landing/pc/downloads'
SETUP = 'Setup MSB PC Preview Updater.vbs'
README = 'READ ME Instructions.txt'


def write_files(destination, files):
    with zipfile.ZipFile(destination, 'w', compression=zipfile.ZIP_DEFLATED) as archive:
        for name, data in sorted(files.items()):
            entry = zipfile.ZipInfo(name, date_time=(1980,1,1,0,0,0))
            entry.compress_type = zipfile.ZIP_DEFLATED
            archive.writestr(entry, data)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--enable-apply', action='store_true')
    args = parser.parse_args()
    suffix = 'pilot' if args.enable_apply else 'review'
    target = DOWNLOADS/('MSB-PC-Preview-Updater-1.0.8-'+suffix+'.zip')
    if target.exists():
        raise SystemExit('BLOCK: versioned installer archive already exists; do not overwrite')
    with tempfile.TemporaryDirectory(prefix='msb-lor2pc-package-') as temporary:
        runtime = Path(temporary)/'runtime'
        subprocess.run([sys.executable, str(SOURCE/'Prepare-LOR2PC-Candidate.py'), str(runtime)] + (['--enable-apply'] if args.enable_apply else []), check=True)
        payload = io.BytesIO()
        # Retain the complete hash-recorded runtime inside setup, never at the
        # programmer-visible package root.
        hidden = {p.name:p.read_bytes() for p in runtime.iterdir()}
        write_files(payload, hidden)
        encoded = base64.b64encode(payload.getvalue()).decode('ascii')
        lines = '\r\n'.join('payload = payload & "'+encoded[i:i+120]+'"' for i in range(0,len(encoded),120))
        setup = (SOURCE/'Setup-MSB-PC-Preview-Updater.vbs.in').read_text()
        setup = setup.replace('@@PAYLOAD@@', lines).replace('@@SHA256@@', hashlib.sha256(payload.getvalue()).hexdigest())
        target.parent.mkdir(parents=True, exist_ok=True)
        write_files(target, {SETUP:setup.encode('ascii'), README:(SOURCE/('READ ME - Show PC Apply Pilot.txt' if args.enable_apply else 'READ ME - Programmer PC Setup.txt')).read_bytes()})
    print('Prepared two-file site download only: '+str(target))


if __name__ == '__main__': main()
