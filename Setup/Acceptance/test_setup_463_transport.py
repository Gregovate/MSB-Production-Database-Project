"""Cross-platform archive byte identity with Windows line-ending configuration."""
import hashlib
import json
from pathlib import Path
import sys
import pytest
sys.path.insert(0, str(Path(__file__).parent))

def test_transport_committed_bytes_and_external_pins(tmp_path, monkeypatch):
    # Both repositories are disposable fixtures; only remote fetch is redirected.
    import subprocess
    import setup_463_transport as package
    real_run = subprocess.run
    def git(repo, *args):
        return real_run(['git','-C',str(repo),*args], check=True, capture_output=True).stdout
    def init(repo):
        repo.mkdir(); git(repo,'init','-q')
        git(repo,'config','user.email','test@example.invalid'); git(repo,'config','user.name','Test')
    def commit(repo):
        git(repo,'add','-f','.'); git(repo,'commit','-qm','fixture')
        return git(repo,'rev-parse','HEAD').decode().strip()
    repo = tmp_path/'app'; server = tmp_path/'server'; init(repo); init(server)
    helpers = {'deploy_scan_extension_issue219.sh': b'#!/bin/bash\necho deploy\n',
               'validate_scan_extension_isolated.sh': b'#!/bin/bash\necho validate\n'}
    (server/'scripts').mkdir()
    for name, content in helpers.items(): (server/'scripts'/name).write_bytes(content)
    server_sha = commit(server)
    scan = repo/'Scan/directus-extension-scan'
    for sub in ('src','dist'):
        (scan/sub).mkdir(parents=True); (scan/sub/'index.js').write_bytes(b'// fixture\n')
    docs = repo/'Docs/02_Production_Database/01_System_Architecture/07_Labeling_and_Scanning'
    docs.mkdir(parents=True); (docs/'README.md').write_text('fixture\n')
    app = commit(repo)
    git(repo,'config','core.autocrlf','true')
    git(repo,'config','core.eol','crlf')
    root = repo/'Setup/Acceptance'; root.mkdir(parents=True)
    manifest = dict(candidate=app, server_management_sha=server_sha,
        scan_sha256=hashlib.sha256(b'// fixture\n').hexdigest(),
        server_helpers={n:hashlib.sha256(b).hexdigest() for n,b in helpers.items()})
    (root/'setup_463_release.json').write_text(json.dumps(manifest)+'\n')
    for name in ('setup_463_release.py','setup_maintenance_deploy.py'):
        (root/name).write_bytes(b'# committed Linux bytes\n')
    commit(repo)
    # Simulate the workstation's CRLF checkout; package must still transport LF.
    (root/'setup_463_release.py').write_bytes(b'# committed Linux bytes\r\n')
    def run(argv, **kw):
        argv = list(argv)
        url = 'https://github.com/Gregovate/MSB-Server-Management.git'
        if url in argv: argv[argv.index(url)] = str(server)
        return real_run(argv, **kw)
    monkeypatch.setattr(subprocess, 'run', run)
    original_files = package.transport.FILES
    bundle = tmp_path/'bundle'; package.package(repo,bundle)
    assert package.transport.FILES == original_files
    assert (bundle/'setup_463_release.py').read_bytes() == b'# committed Linux bytes\n'
    assert (bundle/'scan-index.js').read_bytes() == b'// fixture\n'
    for name, content in helpers.items(): assert (bundle/name).read_bytes() == content
    archive_sha = real_run(['git','get-tar-commit-id'],input=(bundle/'scan-candidate.tar').read_bytes(),capture_output=True,check=True).stdout.decode().strip()
    assert archive_sha == app
    import tarfile
    with tarfile.open(bundle/'scan-candidate.tar') as archive:
        for sub in ('src','dist'):
            assert archive.extractfile('Scan/directus-extension-scan/'+sub+'/index.js').read() == b'// fixture\n'
    (root/'setup_463_release.py').write_text('# local uncommitted change\n')
    with pytest.raises(RuntimeError, match='local content differs'):
        package.package(repo,tmp_path/'rejected')
