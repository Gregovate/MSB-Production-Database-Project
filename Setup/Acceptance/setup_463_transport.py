"""Compose existing committed-byte transport with pinned Server Management helpers."""
import hashlib
import json
from pathlib import Path
import subprocess
import sys
import tempfile
import setup_88_report_transport as transport

FILES = ('setup_463_release.py', 'setup_maintenance_deploy.py', 'setup_463_release.json')

def package(repo, bundle):
    previous = transport.FILES
    try:
        transport.FILES = FILES
        transport.package(repo, bundle)
    finally:
        transport.FILES = previous
    repo, bundle = Path(repo), Path(bundle)
    manifest = json.loads((bundle/'setup_463_release.json').read_text())
    app = manifest['candidate']
    # Read external runtime code from its owning repository at an immutable commit.
    with tempfile.TemporaryDirectory(prefix='msb463-runtime-') as checkout:
        subprocess.run(['git','init','--quiet',checkout],check=True)
        subprocess.run(['git','-C',checkout,'fetch','--quiet','--depth=1',
                        'https://github.com/Gregovate/MSB-Server-Management.git',
                        manifest['server_management_sha']],check=True)
        for name, digest in manifest['server_helpers'].items():
            content=transport.git(checkout,'show',manifest['server_management_sha']+':scripts/'+name)
            if hashlib.sha256(content).hexdigest()!=digest:
                raise RuntimeError('Server Management helper identity differs: '+name)
            (bundle/name).write_bytes(content)
    dist=transport.git(repo,'show',app+':Scan/directus-extension-scan/dist/index.js')
    src=transport.git(repo,'show',app+':Scan/directus-extension-scan/src/index.js')
    if src!=dist or hashlib.sha256(dist).hexdigest()!=manifest['scan_sha256']:
        raise RuntimeError('Accepted Scan src/dist mismatch')
    (bundle/'scan-index.js').write_bytes(dist)
    subprocess.run(['git','-C',str(repo),'archive','--format=tar',
                    '--output='+str((bundle/'scan-candidate.tar').resolve()),app,
                    'Scan/directus-extension-scan',
                    'Docs/02_Production_Database/01_System_Architecture/07_Labeling_and_Scanning'],check=True)

if __name__=='__main__':
    package(sys.argv[1],sys.argv[2])
