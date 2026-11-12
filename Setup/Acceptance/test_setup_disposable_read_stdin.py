"""Execute the real ACL export shell path with Docker's stdin semantics.

The CLI double drops stdin unless exec has -i, matching the failure on host.
SQL semantics are covered separately by the PostgreSQL privilege proof.
"""
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys

import pytest


@pytest.mark.skipif(shutil.which('bash') is None, reason='Shell transport proof requires bash')
@pytest.mark.parametrize('failure', [None, 'missing_i', 'sql_error', 'empty'])
def test_read_acl_export_delivers_host_file_to_psql_and_replays(tmp_path, failure):
    acceptance = Path(__file__).parent
    shell = (acceptance/'setup_disposable_acceptance_server.sh').read_text()
    block = shell.split('if [[ "$PRODUCTION_READ_BOUNDARY" == "true" ]]', 1)[1]
    block = 'if [[ "$PRODUCTION_READ_BOUNDARY" == "true" ]]'+block.split('# Preserve the real Production function boundary:', 1)[0]
    if failure == 'missing_i':
        block = block.replace('docker exec -i "$PROD_CONTAINER"', 'docker exec "$PROD_CONTAINER"')
    psql_test = next(line for line in shell.splitlines() if line.startswith('psql_test()'))
    runner = tmp_path/'export.sh'
    runner.write_text('set -eu\n'+psql_test+'\n'+block)
    # Execute through a subprocess, so shell redirection and EOF are real. No
    # database/container credentials or privileged commands enter this proof.
    shim = tmp_path/'sudo'
    shim.write_text('#!'+sys.executable+'\n'+'''
import json, os, pathlib, sys
args = sys.argv[1:]
assert args[:2] == ['docker', 'exec'], args
data = sys.stdin.buffer.read() if '-i' in args else b''
with open(os.environ['CALLS'], 'a') as stream:
    stream.write(json.dumps({'args': args, 'stdin': data.decode()})+'\\n')
if 'production' in args:
    if os.environ['FAILURE'] == 'sql_error':
        print('ERROR: injected PostgreSQL failure', file=sys.stderr)
        sys.exit(3)
    if not data or os.environ['FAILURE'] == 'empty':
        sys.exit(0)
    expected = pathlib.Path(os.environ['CANDIDATE_WORKTREE'])/'Setup/Acceptance/setup_production_read_boundary.sql'
    assert data == expected.read_bytes()
    print('GRANT SELECT (container_type_id,container_type_name) ON TABLE ref.container_type TO fieldwiring_app;')
else:
    assert 'disposable' in args
    assert data == pathlib.Path(os.environ['GRANTS_FILE']).read_bytes()
    assert b'GRANT SELECT (' in data and b'ALL TABLES' not in data
''')
    shim.chmod(0o755)
    calls = tmp_path/'calls.jsonl'
    grants = tmp_path/'grants.sql'
    environment = dict(os.environ, PATH=str(tmp_path)+os.pathsep+os.environ['PATH'],
                       CANDIDATE_WORKTREE=str(acceptance.parents[1]),
                       GRANTS_FILE=str(grants), CALLS=str(calls), FAILURE=failure or '',
                       PRODUCTION_READ_BOUNDARY='true', PROD_CONTAINER='production',
                       PROD_DB='msb', TEST_CONTAINER='disposable', TEST_DB='clone',
                       TEST_PASSWORD='test-only', DB_ACTOR='msbadmin')
    result = subprocess.run(['bash', str(runner)], env=environment, capture_output=True,
                            text=True, timeout=10)
    events = [json.loads(line) for line in calls.read_text().splitlines()]
    if failure is None:
        assert result.returncode == 0, result.stderr
        assert len(events) == 2
        assert events[0]['stdin'] == (acceptance/'setup_production_read_boundary.sql').read_text()
        assert events[1]['stdin'] == grants.read_text()
    else:
        assert result.returncode == (3 if failure == 'sql_error' else 23)
        assert len(events) == 1  # Failed export must never reach clone replay.
        if failure != 'sql_error':
            assert 'Production read ACL extraction was empty' in result.stdout
