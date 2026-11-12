"""QC HTTP boundary tests. SQL role/state acceptance remains clone-owned.

Use the real header, identity and Manager guards with a recording repository;
never connect to Production or assert that a mocked command proves SQL access.
"""
import pytest
from flask import Flask
import setup_api as auth
import setup_qc_api as qc


@pytest.fixture
def client(monkeypatch):
    calls = []
    access = {'can_read_setup': True, 'can_manage_setup': False}

    class Repository:
        def capabilities(self, email):
            return access

        def command(self, email, data):
            calls.append((email, data))
            return {'finding_id': 17}

        def snapshot(self, email, year):
            return {'findings': []}

        def intake_candidates(self, email, year):
            calls.append(('intake', year))
            return []

    repo = Repository()
    monkeypatch.setattr(auth, 'setup_repository', lambda: repo)
    monkeypatch.setattr(qc, 'qc_repo', lambda: repo)
    app = Flask(__name__)
    app.register_blueprint(qc.setup_qc_api)
    app.testing = True
    return app.test_client(), calls, access


HEADERS = {'Cf-Access-Authenticated-User-Email': 'crew@example.test',
           'X-MSB-Setup-Command': '1'}


def test_report_and_claim_do_not_require_auditor_or_note_for_claim(client):
    http, calls, _ = client
    for action, fields in [('REPORT', {'title': 'Arch 3', 'note': 'Red is out'}),
                           ('CLAIM_REPAIR', {'qc_finding_id': 17})]:
        response = http.post('/api/setup/qc/action', headers=HEADERS,
                             json={'action': action, 'setup_session_task_id': 483, **fields})
        assert response.status_code == 200
        assert calls[-1][0] == 'crew@example.test'
        assert calls[-1][1]['setup_session_task_id'] == 483
    assert calls[-1][1]['note'] is None


@pytest.mark.parametrize('headers,status', [({}, 403),
    ({'X-MSB-Setup-Command': '1'}, 401),
    ({'Cf-Access-Authenticated-User-Email': 'crew@example.test'}, 403)])
def test_missing_identity_or_command_guard_denies_before_repository(client, headers, status):
    http, calls, _ = client
    response = http.post('/api/setup/qc/action', headers=headers,
                         json={'action': 'CLAIM_AUDIT', 'setup_session_task_id': 483})
    assert response.status_code == status
    assert not calls


def test_no_setup_access_and_final_pass_are_denied(client):
    http, calls, access = client
    access['can_read_setup'] = False
    assert http.get('/api/setup/qc?season_year=2026', headers=HEADERS).status_code == 403
    access['can_read_setup'] = True
    assert http.post('/api/setup/qc/action', headers=HEADERS,
                     json={'action': 'FINAL_QC_PASS', 'setup_session_task_id': 483}).status_code == 403
    assert not calls


def test_historical_intake_review_is_manager_only(client):
    http, calls, access = client
    url = '/api/setup/qc/intake-candidates?season_year=2026'
    assert http.get(url, headers=HEADERS).status_code == 403
    assert not calls
    access['can_manage_setup'] = True
    assert http.get(url, headers=HEADERS).status_code == 200
    assert calls == [('intake', 2026)]
