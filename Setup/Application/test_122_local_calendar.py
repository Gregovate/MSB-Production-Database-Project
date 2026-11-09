"""Local-calendar regression at UTC/local midnight and DST; no Production writes."""
from datetime import datetime, timedelta
from pathlib import Path
import json
import os
import subprocess

import pytest
from flask import Flask
import setup_next_api as api

APP = Path(__file__).parent
CASES = [
    ('2026-11-09T01:30:00+00:00', '2026-11-08'),
    ('2026-07-09T01:30:00+00:00', '2026-07-08'),
    ('2026-11-09T05:59:59+00:00', '2026-11-08'),
    ('2026-11-09T06:00:00+00:00', '2026-11-09'),
    ('2026-03-08T07:59:59+00:00', '2026-03-08'),
    ('2026-03-08T08:00:00+00:00', '2026-03-08'),
    ('2026-11-01T06:59:59+00:00', '2026-11-01'),
    ('2026-11-01T07:00:00+00:00', '2026-11-01'),
    ('2027-01-01T01:00:00+00:00', '2026-12-31'),
]

@pytest.mark.parametrize('instant,local_date', CASES)
@pytest.mark.parametrize('correction', [False, True])
def test_report_and_correction_use_park_date(monkeypatch, instant, local_date, correction):
    class Clock:
        @staticmethod
        def now(zone):
            return datetime.fromisoformat(instant).astimezone(zone)

    class Repository:
        calls = []
        def record_progress(self, **kwargs):
            self.calls.append(kwargs)
            return kwargs
        correct_progress = record_progress

    repository = Repository()
    monkeypatch.setattr(api, 'datetime', Clock)
    monkeypatch.setattr(api, 'require_setup_command', lambda: None)
    monkeypatch.setattr(api, 'require_reader', lambda: (None, 'fixture@example.invalid', {}))
    monkeypatch.setattr(api, 'require_manager', lambda: (None, 'fixture@example.invalid', {}))
    monkeypatch.setattr(api, 'repo', lambda: repository)
    app = Flask(__name__)
    app.register_blueprint(api.setup_next_api)
    client = app.test_client()
    path = '/api/setup/progress/42' if correction else '/api/setup/session-tasks/42/progress'
    send = client.patch if correction else client.post
    payload = dict(crew_count=1, duration_minutes=60, percent_complete=50,
                   performed_on=local_date, progress_note='Actual work fixture')
    response = send(path, json=payload)
    assert response.status_code == (200 if correction else 201), response.json
    assert repository.calls[-1]['performed_on'] == local_date
    count = len(repository.calls)
    payload['performed_on'] = (datetime.fromisoformat(local_date) + timedelta(days=1)).date().isoformat()
    response = send(path, json=payload)
    assert response.status_code == 403
    assert response.json["error"] == "Work completed on date cannot be in the future"
    assert len(repository.calls) == count  # rejected before any persistence

@pytest.mark.parametrize('browser_zone', ['UTC', 'America/Chicago', 'Asia/Tokyo'])
def test_browser_dates_do_not_depend_on_workstation(browser_zone):
    # Execute the actual functions, not a Python rewrite of their behavior.
    next_source = (APP / 'setup_next_pass.js').read_text()
    date_fn = next_source.split('function nextSetupLocalDate(', 1)[1].split('\nfunction ', 1)[0]
    sources = ['function nextSetupLocalDate(' + date_fn]
    board = (APP / 'setup_scheduling_board.js').read_text()
    for name in ['board205TodayKey', 'board205TodayDateKey']:
        sources.append('function ' + name + '(' + board.split('function '+name+'(', 1)[1].split('\nfunction ', 1)[0])
    checks = ['nextSetupLocalDate()', 'board205TodayKey()', 'board205TodayDateKey()']
    for index, filename in enumerate(['setup_pick_list.js', 'setup_material_status.js']):
        source = (APP / filename).read_text()
        fn = 'function todayIso() {' + source.split('function todayIso() {', 1)[1].split('\n  }', 1)[0] + '\n  }'
        sources.append(fn.replace('todayIso', 'today'+str(index)))
        checks.append('today'+str(index)+'()')
    script = '''const assert = require('node:assert/strict');
const RealDate = Date;
let instant;
global.Date = class extends RealDate {
  constructor(...args) { super(...(args.length ? args : [instant])); }
};
''' + '\n'.join(sources) + '\n'
    script += 'for (const [stamp, expected] of '+json.dumps(CASES)+') { instant=stamp;'
    for call in checks:
        script += 'assert.equal('+call+', expected);'
    script += '}'
    subprocess.run(['node', '-e', script], env={**os.environ, 'TZ': browser_zone}, check=True)


def test_migration_is_function_scoped_and_preserves_command_bodies():
    sql = (APP.parent / 'Database/079_fix_setup_local_calendar_boundaries.sql').read_text()
    assert sql.count("SET TimeZone TO 'America/Chicago'") == 4
    for name in ['reject_past_setup_work_day_insert', 'add_historical_setup_work_day',
                 'record_setup_task_progress', 'correct_setup_task_progress']:
        assert 'ALTER FUNCTION ops.'+name+'(' in sql
    for forbidden in ['ALTER ROLE', 'ALTER DATABASE', 'ALTER SYSTEM', 'UPDATE ',
                      'DELETE ', 'INSERT ', 'GRANT ', 'CREATE OR REPLACE']:
        assert forbidden not in sql
