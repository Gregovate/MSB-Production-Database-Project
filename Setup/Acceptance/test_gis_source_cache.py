"""Exercise source-cache publication/reuse without a server or database."""
import hashlib
from pathlib import Path
import shlex
import subprocess

SERVER = Path(__file__).with_name('setup_disposable_browser_preview_server.sh')


def resolve(tmp_path, data, upload):
    source = SERVER.read_text()
    function = source.split('resolve_gis_source() {', 1)[1].split('\n}\n', 1)[0]
    # Isolate only this function's cache path; do not alter the test user's HOME.
    function = function.replace('"$HOME/setup-source-cache"', shlex.quote(str(tmp_path / 'cache')))
    digest = hashlib.sha256(data).hexdigest()
    script = 'set -euo pipefail\nresolve_gis_source() {' + function + '\n}\n'
    script += 'resolve_gis_source ' + ' '.join(map(shlex.quote, [digest, 'flw', str(upload)]))
    return subprocess.run(['bash', '-c', script], text=True, capture_output=True)


def test_source_survives_bundle_removal_and_is_reused(tmp_path):
    upload = tmp_path / 'source.flw'
    upload.write_bytes(b'immutable test evidence')
    first = resolve(tmp_path, upload.read_bytes(), upload)
    assert first.returncode == 0, first.stderr
    cached = Path(first.stdout.strip())
    inode = cached.stat().st_ino
    upload.unlink()
    second = resolve(tmp_path, b'immutable test evidence', upload)
    assert second.returncode == 0, second.stderr
    assert Path(second.stdout.strip()).stat().st_ino == inode
    assert cached.read_bytes() == b'immutable test evidence'


def test_changed_source_has_distinct_cache_identity(tmp_path):
    upload = tmp_path / 'source.flw'
    paths = []
    for data in (b'old tests', b'old plus new tests'):
        upload.write_bytes(data)
        result = resolve(tmp_path, data, upload)
        assert result.returncode == 0, result.stderr
        paths.append(result.stdout.strip())
    assert paths[0] != paths[1]
    assert Path(paths[0]).read_bytes() == b'old tests'


def test_corrupt_upload_is_not_published(tmp_path):
    upload = tmp_path / 'source.flw'
    upload.write_bytes(b'wrong')
    result = resolve(tmp_path, b'expected', upload)
    assert result.returncode != 0
    assert not list((tmp_path / 'cache').glob('*.flw'))
