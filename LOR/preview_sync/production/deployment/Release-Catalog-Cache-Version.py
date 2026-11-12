"""Change only the catalog script cache version; no API/runner/catalog writes."""
import hashlib
import os
from pathlib import Path
import tempfile
import uuid

OLD = b'catalog.js?v=4'
NEW = b'catalog.js?v=20261101-presentation-v5'
JS_HASH = 'da6ff01673b4d41b804179a8ade367426eea9005f9601c82b7ff85a5480dd3cb'

def changed_page(before):
    if before.count(NEW) == 1 and OLD not in before:
        return before
    if before.count(OLD) != 1 or NEW in before:
        raise ValueError('Unexpected catalog script reference; nothing changed')
    return before.replace(OLD, NEW, 1)

def main():
    if os.geteuid() != 0:
        raise ValueError('Run through sudo')
    web = Path('/mnt/msb-web/my/lor2db')
    page = web/'index.html'
    if page.is_symlink() or (web/'catalog.js').is_symlink():
        raise ValueError('Redirected website path')
    if hashlib.sha256((web/'catalog.js').read_bytes()).hexdigest() != JS_HASH:
        raise ValueError('Expected concise catalog script is not installed')
    before = page.read_bytes()
    after = changed_page(before)
    parent = Path('/home/msbadmin/lor-catalog-source-releases')
    if not parent.is_dir() or parent.is_symlink():
        raise ValueError('Existing backup folder unavailable')
    backup = parent/('catalog-cache-'+uuid.uuid4().hex)
    backup.mkdir(mode=0o700)
    saved = backup/'index.html.before';saved.write_bytes(before);saved.chmod(0o600)
    if page.read_bytes() != before:
        raise ValueError('Website changed during backup')
    fd, name = tempfile.mkstemp(dir=web)
    try:
        with os.fdopen(fd,'wb') as stream:
            stream.write(after);stream.flush();os.fsync(stream.fileno())
        os.replace(name,page)
        if page.read_bytes() != after:
            raise ValueError('Page verification failed; retain backup')
    finally:
        if os.path.exists(name):os.unlink(name)
    print('PASS: catalog script cache version updated. Report: '+str(backup))

if __name__ == '__main__':
    try:main()
    except Exception as error:raise SystemExit('HOLD: '+str(error))
