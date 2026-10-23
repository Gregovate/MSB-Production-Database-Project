"""Worker orchestration checks without a database or SMTP connection."""
import pytest
import mail_worker as worker


def candidate(number=1):
    return dict(event_key=f'assignment:{number}', recipient_email='crew@example.org',
                message_kind='assignment', payload=dict(ticket=f'WO-{number}',
                title='Repair lights', assignees='Crew', due_by='2026-10-25',
                ticket_url=f'https://my.sheboyganlights.org/workorder/?ticket=WO-{number}'))


@pytest.fixture
def database(monkeypatch):
    class Connection:
        identity = {'role': 'work_management_mail', 'db': 'msb'}
        rows = [candidate()]
        closed = False
        queries = []
        def set_session(self, **kwargs):
            assert kwargs == {'readonly': True}
        def cursor(self, **kwargs):
            return self
        def __enter__(self):
            return self
        def __exit__(self, *args):
            pass
        def execute(self, query):
            self.queries.append(query)
        def fetchone(self):
            return self.identity
        def fetchall(self):
            return self.rows
        def close(self):
            self.closed = True
    connection = Connection()
    monkeypatch.setattr(worker.psycopg2, 'connect', lambda dsn: connection)
    return connection


def test_send_requires_activation_before_database(monkeypatch):
    monkeypatch.delenv('WORK_MGMT_MAIL_SEND_ENABLED', raising=False)
    monkeypatch.setattr(worker.psycopg2, 'connect', lambda _: pytest.fail('connected'))
    with pytest.raises(RuntimeError, match='activation is OFF'):
        worker.run_batch('unused', send=True)


@pytest.mark.parametrize('identity', [
    {'role': 'msbadmin', 'db': 'msb'},
    {'role': 'work_management_mail', 'db': 'msb_wo419_preview'}])
def test_wrong_identity_stops_before_candidates(database, identity):
    database.identity = identity
    with pytest.raises(RuntimeError, match='identity required'):
        worker.run_batch('unused')
    assert database.closed
    assert len(database.queries) == 1


def test_default_preview_cannot_claim_or_send(database, monkeypatch):
    monkeypatch.setattr(worker.PostgresDeliveryStore, 'claim',
                        lambda *args: pytest.fail('preview claimed delivery'))
    result = worker.run_batch('unused')
    assert [row['status'] for row in result] == ['PREVIEW_ONLY']
    assert database.closed


def test_entire_batch_rendered_before_dispatch(database, monkeypatch):
    database.rows = [candidate(1), candidate(2)]
    database.rows[1]['payload']['ticket_url'] = 'https://untrusted.example/'
    monkeypatch.setattr(worker, 'dispatch', lambda *a, **kw: pytest.fail('dispatched'))
    with pytest.raises(ValueError):
        worker.run_batch('unused')
    assert database.closed


@pytest.mark.parametrize('status', ['UNKNOWN', 'FAILED_BEFORE_DATA', 'REJECTED'])
def test_failure_stops_remaining_batch(database, monkeypatch, status):
    database.rows = [candidate(1), candidate(2)]
    monkeypatch.setenv('WORK_MGMT_MAIL_SEND_ENABLED', '1')
    attempts = []
    def dispatch(delivery, store, *, enabled):
        assert enabled and database.closed
        attempts.append(delivery.key)
        return status
    monkeypatch.setattr(worker, 'dispatch', dispatch)
    result = worker.run_batch('unused', send=True)
    assert len(attempts) == 1
    assert [row['status'] for row in result] == [status]


def test_invalid_template_is_visible_and_stops_before_any_send(database, monkeypatch):
    database.rows = [candidate(1), candidate(2)]
    database.rows[1]['payload']['ticket_url'] = 'https://untrusted.example/'
    monkeypatch.setenv('WORK_MGMT_MAIL_SEND_ENABLED', '1')
    recorded = []
    monkeypatch.setattr(worker.PostgresDeliveryStore, 'render_failure',
                        lambda self, event: recorded.append(event))
    monkeypatch.setattr(worker, 'dispatch', lambda *a, **kw: pytest.fail('sent'))
    with pytest.raises(ValueError):
        worker.run_batch('unused', send=True)
    assert recorded == ['assignment:2']
