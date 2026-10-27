"""Package committed #88 runner bytes without Git's Windows clean filter.

Use the workstation's existing Python, not Node. Local LF/CRLF differences are
allowed; any other content difference fails before SCP/SSH. Transport always
comes from the exact committed Git blob, with the established LF normalization.
"""
import hashlib
from pathlib import Path
import subprocess
import sys

FILES = ('setup_88_report_read_deploy.py', 'setup_maintenance_deploy.py',
         'setup_88_report_source_only_deploy.py')


def git(repo, *args):
    result = subprocess.run(['git', '-C', str(repo), *args], capture_output=True)
    if result.returncode:
        raise RuntimeError('STOP: Git transport read failed: '+result.stderr.decode('utf-8', 'replace'))
    return result.stdout


def package(repo, bundle):
    repo, bundle = Path(repo), Path(bundle)
    bundle.mkdir(parents=True, exist_ok=True)
    for name in FILES:
        relative = 'Setup/Acceptance/'+name
        oid = git(repo, 'rev-parse', 'HEAD:'+relative).decode('ascii').strip()
        committed = git(repo, 'cat-file', 'blob', oid)
        calculated = hashlib.sha1(b'blob '+str(len(committed)).encode()+b'\0'+committed).hexdigest()
        if calculated != oid:
            raise RuntimeError('STOP: committed blob verification failed: '+name)
        normalized = committed.replace(b'\r', b'')
        working = (repo/relative).read_bytes().replace(b'\r', b'')
        if working != normalized:
            raise RuntimeError('STOP: local content differs from committed source: '+name)
        # Match the server's separately pinned LF transport identities exactly.
        (bundle/name).write_bytes(normalized)


if __name__ == '__main__':
    try:
        package(sys.argv[1], sys.argv[2])
    except Exception as exc:
        print(str(exc), file=sys.stderr)
        sys.exit(1)
