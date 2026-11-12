"""Bounded read-only initial-load probe for an existing governed Setup preview.

Consumes its state; never starts/stops services, clones, migrations or Production.
Run with the documented server Python through foreground sudo/SSH.
"""
from __future__ import annotations
import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import shlex
import subprocess
import sys
import time
from datetime import datetime, timezone
from urllib.request import urlopen
from urllib.error import HTTPError


def command(args, **kwargs):
    return subprocess.run(args, check=True, capture_output=True, text=True,
                          timeout=90, **kwargs).stdout


def read_state(path):
    """Parse runner printf-%q assignments as data; never source shell code."""
    state = {}
    for line in Path(path).read_text().splitlines():
        key, sep, value = line.partition('=')
        if not sep or not re.fullmatch(r'[A-Z_]+', key):
            raise ValueError('Unexpected preview state format')
        if key not in {'TARGET_SHA','PREVIEW_PORT','TEST_CONTAINER','TEST_DB',
                       'CANDIDATE_WORKTREE','PREVIEW_ENTRY','PREVIEW_PGID',
                       'PREVIEW_EMAIL','REPORT'}:
            continue
        values = shlex.split(value)
        if len(values) != 1 or '$' in values[0] or '\n' in values[0]:
            raise ValueError('Unsupported preview state quoting')
        state[key] = values[0]
    return state


def guard(state, port, sha):
    if port != 8898 or state.get('PREVIEW_PORT') != str(port):
        raise ValueError('Only the existing port8898 preview is supported')
    if state.get('TARGET_SHA') != sha or not re.fullmatch(r'[a-f0-9]{40}', sha):
        raise ValueError('Preview candidate differs from expected SHA')
    if not re.fullmatch(r'msb-setup-browser-preview-[0-9]+', state.get('TEST_CONTAINER', '')):
        raise ValueError('Not a governed disposable container')
    if state.get('TEST_DB') != 'msb_setup_browser_preview':
        raise ValueError('Not the disposable preview database')
    root = state.get('CANDIDATE_WORKTREE', '')
    if not re.fullmatch(r'/tmp/msb-setup-browser-preview-candidate-[0-9T]+', root):
        raise ValueError('Unexpected preview worktree')
    if state.get('PREVIEW_ENTRY') != root + '/Setup/Acceptance/setup_session_browser_preview_entry.py':
        raise ValueError('Unexpected preview entry')
    if not re.fullmatch(r'[0-9]+', state.get('PREVIEW_PGID', '')):
        raise ValueError('Missing preview listener identity')
    return Path(root)


def literal_sql(sql, params):
    from psycopg2.extensions import adapt
    if not re.match(r'^\s*(SELECT|WITH)\b', sql, re.I):
        raise ValueError('Diagnostic accepts SELECT query builders only')
    parts = sql.split('%s')
    if len(parts) != len(params) + 1:
        raise ValueError('Unexpected query binding shape')
    result = parts[0]
    for value, tail in zip(params, parts[1:]):
        result += adapt(value).getquoted().decode('utf-8') + tail
    return result.strip().rstrip(';')


def capture_queries(root, controller_id):
    """Run existing query builders with a recorder, not a database connection."""
    sys.dont_write_bytecode = True
    sys.path.insert(0, str(root / 'FieldWiring/Application'))
    from controller_inventory import controller_list, controller_detail
    from repository import PostgresRepository
    captured = []

    class Recorder:
        def __enter__(self): return self
        def __exit__(self, *args): return False
        def cursor(self, **kwargs): return self
        def execute(self, sql, params=()): captured.append((sql, params))
        def fetchone(self): return {}  # non-None permits all detail SELECTs
        def fetchall(self): return []

    repo = PostgresRepository('')
    repo.connect = lambda: Recorder()
    controller_list(repo, query='Racing')
    split = len(captured)
    controller_detail(repo, controller_id)
    return [('list' if i < split else 'detail', sql, params)
            for i, (sql, params) in enumerate(captured)]


def http_get(port, path, report):
    report['current_step'] = path
    start = time.perf_counter()
    try:
        with urlopen(f'http://127.0.0.1:{port}/fieldwiring{path}', timeout=75) as response:
            raw = response.read()
            status = response.status
    except HTTPError as error:
        raw = error.read()
        status = error.code
    elapsed = round((time.perf_counter() - start) * 1000, 1)
    item = {'path': path, 'ms': elapsed, 'status': status, 'bytes': len(raw)}
    report['http'].append(item)
    print('HTTP', json.dumps(item), flush=True)
    if status != 200:
        raise RuntimeError('Preview GET failed; response content withheld')
    return json.loads(raw)


def explain(state, sql, params, label, report):
    bound = literal_sql(sql, params)
    statement = ("BEGIN READ ONLY; SET LOCAL ROLE fieldwiring_app; "
                 "SET LOCAL statement_timeout='60s'; "
                 "EXPLAIN (ANALYZE, BUFFERS, FORMAT JSON) " + bound + '; ROLLBACK;')
    report['current_step'] = label
    started = time.perf_counter()
    raw = command(['docker', 'exec', '-i', state['TEST_CONTAINER'], 'psql',
                   '-X', '-qAt', '-v', 'ON_ERROR_STOP=1', '-U', 'msbadmin',
                   '-d', state['TEST_DB']], input=statement)
    plan = json.loads(raw)[0]
    item = {'label': label, 'query_sha256': hashlib.sha256(sql.encode()).hexdigest(),
            'sql_template': sql, 'execution_ms': plan.get('Execution Time'),
            'planning_ms': plan.get('Planning Time'),
            'docker_roundtrip_ms': round((time.perf_counter()-started)*1000, 1),
            'plan': plan}
    report['sql'].append(item)
    print('SQL', json.dumps({k: v for k, v in item.items()
                            if k not in ('plan', 'sql_template')}), flush=True)


def run(args, report):
    state = read_state(f'/tmp/msb-setup-browser-preview-state-{args.port}.env')
    root = guard(state, args.port, args.expected_sha)
    if command(['git', '-C', str(root), 'rev-parse', 'HEAD']).strip() != args.expected_sha:
        raise ValueError('Preview checkout differs')
    if command(['git', '-C', str(root), 'status', '--porcelain']).strip():
        raise ValueError('Preview checkout has local changes')
    listener = command(['ss', '-ltnp', f'sport = :{args.port}'])
    if set(re.findall(r'pid=(\d+)', listener)) != {state['PREVIEW_PGID']}:
        raise ValueError('Preview listener ownership differs')
    info = json.loads(command(['docker', 'inspect', state['TEST_CONTAINER']]))[0]
    if not info['State']['Running'] or info['Name'] != '/' + state['TEST_CONTAINER']:
        raise ValueError('Disposable clone is not running')
    report.update(candidate=args.expected_sha, database=state['TEST_DB'],
                  container=state['TEST_CONTAINER'], preview_report=state.get('REPORT'),
                  note='Existing preview; first probe is not a guaranteed cold database cache')
    print('GUARD PASS: exact running preview; clone-only READ ONLY SQL; no Production connection', flush=True)
    for path in ['/api/controller-access', '/api/stages', '/api/controllers']:
        payload = http_get(args.port, path, report)
    all_controllers = payload.get('controllers', [])
    scoped = http_get(args.port, '/api/controllers?q=Racing', report)
    rows = scoped.get('controllers') or all_controllers
    ids = [int(row['controller_id']) for row in rows[:3]]
    if not ids:
        raise ValueError('No controller IDs returned by preview')
    report['controller_ids'] = ids
    report['racing_matches'] = len(scoped.get('controllers', []))
    for controller_id in ids:
        http_get(args.port, f'/api/controllers/{controller_id}', report)
    http_get(args.port, '/api/power', report)
    http_get(args.port, f'/api/controllers/{ids[0]}', report)
    http_get(args.port, '/api/power', report)
    queries = capture_queries(root, ids[0])
    for index, (kind, sql, params) in enumerate(queries, 1):
        explain(state, sql, params, f'{kind}-{index}', report)
    explain(state, 'SELECT ref.site_power_snapshot(%s)',
            (state['PREVIEW_EMAIL'],), 'power-snapshot', report)
    report['result'] = 'PASS: diagnostic completed; not feature acceptance'


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--port', type=int, default=8898)
    parser.add_argument('--expected-sha', required=True)
    parser.add_argument('--report-tag', default=datetime.now(timezone.utc).strftime('%Y%m%dT%H%M%SZ'))
    args = parser.parse_args()
    if not re.fullmatch(r'[0-9]{8}T[0-9]{6}Z', args.report_tag):
        parser.error('Invalid report tag')
    report = {'http': [], 'sql': [], 'result': 'INCOMPLETE',
              'started_utc': datetime.now(timezone.utc).isoformat()}
    directory = Path('/home/msbadmin/setup-acceptance-reports')
    directory.mkdir(parents=True, exist_ok=True)
    path = directory / ('Controller_Initial_Load_Diagnostic_' + args.report_tag + '.json')
    failed = False
    try:
        run(args, report)
    except Exception as error:
        # Never emit exception text that might contain SQL parameters or credentials.
        report['result'] = 'HOLD: ' + type(error).__name__
        if type(error) is ValueError:
            report['guard_reason'] = str(error)
            print('Guard:', str(error), flush=True)
        failed = True
        print(report['result'], flush=True)
    finally:
        path.write_text(json.dumps(report, indent=2, default=str) + '\n')
        os.chmod(path, 0o644)
        print('REPORT:', path, flush=True)
        print('Preview left running; original runner owns cleanup.', flush=True)
    return 1 if failed else 0


if __name__ == '__main__':
    raise SystemExit(main())
