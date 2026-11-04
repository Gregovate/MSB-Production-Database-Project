"""Publish updater 1.1.2 and catalog summaries only; no service or DB changes."""
import hashlib
import json
import os
from pathlib import Path
import subprocess
import tempfile
import uuid

COMMIT = '159fc490931960607553dc171abe1e1779991449'
SOURCE = 'LOR2DB/Application/landing/'
ASSET = 'pc/downloads/MSB-PC-Preview-Updater-1.1.2-pilot.zip'
PACKAGE_HASH = '54f22811360165d025186f572585e0b37ea3a63a18c110603969d9f58f0e7e06'
PAGES = {'catalog.js': ('5c7d71949632517f26d5ff29ead6d5480d2453fcd19933f1508f92dee4ceba40', '69c9475c3aaf563574d28c6931125aea56240041acc258c2ebf2e2b885974233')}

def sha(data):
    return hashlib.sha256(data).hexdigest()

def require(ok, reason):
    if not ok:
        raise RuntimeError(reason)

def atomic(path, data):
    # NAS/CIFS owns permissions. Never chmod/chown website files.
    fd, temporary = tempfile.mkstemp(dir=path.parent)
    try:
        with os.fdopen(fd, 'wb') as stream:
            stream.write(data)
            stream.flush()
            os.fsync(stream.fileno())
        os.replace(temporary, path)
    finally:
        if os.path.exists(temporary):
            os.unlink(temporary)

def promote(web, backup, candidates):
    # Validate every input before the first website mutation.
    for name, data in candidates.items():
        target = web / name
        require(all(not p.is_symlink() for p in (target, *target.parents)), 'Redirected website path')
        require(sha(data) == (PACKAGE_HASH if name == ASSET else PAGES[name][1]), 'Candidate checksum mismatch: ' + name)
    prior = {}
    for name, (old, new) in PAGES.items():
        data = (web / name).read_bytes()
        require(sha(data) in (old, new), 'Live website differs: ' + name)
        prior[name] = data
    asset = web / ASSET
    require(not asset.exists() or sha(asset.read_bytes()) == PACKAGE_HASH, 'Immutable package differs')
    backup.mkdir(mode=0o700)
    for name, data in prior.items():
        saved = backup / (name.replace('/', '__') + '.before')
        saved.write_bytes(data)
        saved.chmod(0o600)
    print('STAGE backup: ' + str(backup), flush=True)
    # Expose the installer only after its complete bytes have been verified.
    if not asset.exists():
        atomic(asset, candidates[ASSET])
    require(sha(asset.read_bytes()) == PACKAGE_HASH, 'Installed package checksum mismatch')
    changed = []
    try:
        for name in PAGES:
            target = web / name
            require(target.read_bytes() == prior[name], 'Live website changed during release: ' + name)
            changed.append(name)
            atomic(target, candidates[name])
            require(target.read_bytes() == candidates[name], 'Website verification failed: ' + name)
    except Exception:
        # Restore only this release's bytes. Preserve independent changes.
        for name in reversed(changed):
            target = web / name
            if target.read_bytes() == candidates[name]:
                atomic(target, prior[name])
        raise
    receipt = dict(source_commit=COMMIT, package_sha256=PACKAGE_HASH, pages={n:sha((web/n).read_bytes()) for n in PAGES})
    (backup / 'receipt.json').write_text(json.dumps(receipt, indent=2))
    print('PASS: complete background problem display installed. Report: ' + str(backup), flush=True)

def main():
    require(os.geteuid() == 0, 'Run through sudo')
    web = Path('/mnt/msb-web/my/lor2db')
    mount = subprocess.run(['findmnt', '-T', str(web), '-n', '-o', 'FSTYPE'], check=True, capture_output=True).stdout
    require(b'cifs' in mount.split(), 'Website CIFS mount unavailable')
    repo = Path('/opt/fieldwiring')
    candidates = {name:subprocess.run(['git', '-C', str(repo), 'show', COMMIT+':'+SOURCE+name], check=True, capture_output=True).stdout for name in [ASSET, *PAGES]}
    parent = Path('/home/msbadmin/lor-catalog-source-releases')
    require(parent.is_dir() and not parent.is_symlink(), 'Release report directory unavailable')
    promote(web, parent / ('catalog-errors-' + uuid.uuid4().hex), candidates)

if __name__ == '__main__':
    try:
        main()
    except Exception as error:
        raise SystemExit('HOLD: ' + str(error))
