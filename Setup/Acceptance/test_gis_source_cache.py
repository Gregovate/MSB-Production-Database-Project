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
    # The upload and cache sit on the same test filesystem; no second large
    # copy should be allocated for the cache's immutable SHA path.
    assert upload.stat().st_ino == inode
    assert cached.stat().st_nlink == 2
    upload.unlink()
    second = resolve(tmp_path, b'immutable test evidence', upload)
    assert second.returncode == 0, second.stderr
    assert Path(second.stdout.strip()).stat().st_ino == inode
    assert cached.read_bytes() == b'immutable test evidence'


def test_changed_source_has_distinct_cache_identity(tmp_path):
    paths = []
    # Each preview uses its own disposable bundle. Hash-pinned uploaded bytes
    # become read-only when hardlinked; a later export arrives under a NEW path.
    for version, data in enumerate((b'old tests', b'old plus new tests')):
        upload = tmp_path / f'source_version_{version}.flw'
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


def _run_retention(tmp_path, *, other_state=False, other_bundle=False, missing_current=False,
                   corrupted_current=False, no_lock=False):
    """Run the checked-in bash retention helper in isolated temp directories."""
    import os
    cache = tmp_path / 'cache'
    cache.mkdir()
    preview_root = tmp_path / 'previews'
    preview_root.mkdir()
    current_gpx = b'current GPX v7'
    old_gpx = b'older GPX v6'
    current_flw = b'current FLW with growing tests'
    old_flw = b'prior FLW export'
    known = {}
    for ext, current, previous in (('gpx', current_gpx, old_gpx),
                                   ('flw', current_flw, old_flw)):
        cur_sha = hashlib.sha256(current).hexdigest()
        old_sha = hashlib.sha256(previous).hexdigest()
        known[ext] = {'cur': cache / f'{cur_sha}.{ext}',
                      'old': cache / f'{old_sha}.{ext}', 'sha': cur_sha}
        known[ext]['cur'].write_bytes(current)
        known[ext]['old'].write_bytes(previous)
    unrelated = cache / 'operator-notes.flw'
    unrelated.write_text('Do not touch unowned files', encoding='utf-8')
    if missing_current:
        known['flw']['cur'].unlink()
    if corrupted_current:
        known['flw']['cur'].write_bytes(b'wrong content; must stop')
    state = preview_root / 'msb-setup-browser-preview-state-8898.env'
    if other_state:
        (preview_root / 'msb-setup-browser-preview-state-8899.env').write_text('active')
    if other_bundle:
        bundle = preview_root / 'msb-setup-disposable-browser-preview-other'
        bundle.mkdir()
        (bundle / 'preview_manifest.tsv').write_text('preview_port\t8899\n')
    source = SERVER.read_text()
    function = source.split('prune_gis_source_cache() {', 1)[1].split('\n}\n', 1)[0]
    function = function.replace('"$HOME/setup-source-cache"', shlex.quote(str(cache)))
    function = function.replace('local preview_root="/tmp"',
                                'local preview_root=' + shlex.quote(str(preview_root)))
    script = 'set -euo pipefail\n'
    script += 'GIS_CACHE_LOCKED=' + ('0' if no_lock else '1') + '\n'
    script += 'GIS_GPX_SHA=' + known['gpx']['sha'] + '\n'
    script += 'GIS_FLW_SHA=' + known['flw']['sha'] + '\n'
    script += 'STATE_FILE=' + shlex.quote(str(state)) + '\n'
    script += 'SCRIPT_DIR=' + shlex.quote(str(preview_root / 'current-bundle')) + '\n'
    script += 'prune_gis_source_cache() {' + function + '\n}\n'
    script += 'prune_gis_source_cache'
    result = subprocess.run(['bash', '-c', script], text=True, capture_output=True)
    return result, known, unrelated


def test_clean_review_keeps_only_exact_current_gpx_flw(tmp_path):
    result, files, unrelated = _run_retention(tmp_path)
    assert result.returncode == 0, result.stderr
    assert 'CACHE RETENTION PASS' in result.stdout
    assert 'removed 2' in result.stdout
    for entry in files.values():
        assert entry['cur'].exists()
        assert not entry['old'].exists()
    assert unrelated.read_text() == 'Do not touch unowned files'


def test_active_other_preview_prevents_cache_deletion(tmp_path):
    result, files, _ = _run_retention(tmp_path, other_state=True)
    assert result.returncode == 0
    assert 'CACHE RETENTION SKIP' in result.stdout
    assert all(x['cur'].exists() and x['old'].exists() for x in files.values())


def test_prepared_other_bundle_prevents_cache_deletion(tmp_path):
    result, files, _ = _run_retention(tmp_path, other_bundle=True)
    assert result.returncode == 0
    assert 'CACHE RETENTION SKIP' in result.stdout
    assert all(x['cur'].exists() and x['old'].exists() for x in files.values())


def test_missing_or_corrupt_new_source_prevents_cache_deletion(tmp_path):
    for key in ('missing_current', 'corrupted_current', 'no_lock'):
        testroot = tmp_path / key
        testroot.mkdir()
        result, files, _ = _run_retention(testroot, **{key: True})
        assert result.returncode == 0, result.stderr
        assert 'CACHE RETENTION SKIP' in result.stdout
        assert all(x['old'].exists() for x in files.values())


def test_runner_prunes_only_after_clean_browser_review_and_accepted_source():
    source = SERVER.read_text()
    gate = 'if [[ "$status" -eq 0 && "$GIS_CACHE_ACCEPTED" -eq 1 ]]'
    assert gate in source
    assert 'prune_gis_source_cache ||' in source
    assert source.index('rm -rf "$SCRIPT_DIR"') < source.index(gate)
    assert 'if ! flock -n "$GIS_CACHE_LOCK_FD"; then' in source
    assert 'GIS_CACHE_ACCEPTED=1' in source
    assert source.index('accept_site_sources.py') < source.index('GIS_CACHE_ACCEPTED=1')
    assert 'SETUP_BROWSER_PREVIEW_TRANSPORT_LOST' in source
