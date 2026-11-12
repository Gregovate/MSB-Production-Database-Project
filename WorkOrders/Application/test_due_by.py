"""Due-date visibility: no invented deadline and no overdue closed work."""
from repository import WorkManagementRepository
from repository import WorkManagementError
import pytest


class Cursor:
    def execute(self, sql, params):
        self.deadlines = 'AS today' in sql

    def fetchall(self):
        if not self.deadlines:
            return []
        return [dict(ticket='WO-1', due_by=None, today='2026-10-20'),
                dict(ticket='WO-2', due_by='2026-10-19', today='2026-10-20'),
                dict(ticket='WO-3', due_by='2026-10-20', today='2026-10-20'),
                dict(ticket='WO-4', due_by='2026-10-19', today='2026-10-20'),
                dict(ticket='WO-5', due_by='2026-10-19', today='2026-10-20')]


def test_legacy_today_overdue_completed_and_canceled():
    rows = [dict(ticket=f'WO-{i}', type='WORK_ORDER', active=i != 5,
                 done_at='2026-10-19' if i == 4 else None)
            for i in range(1, 6)]
    reader = WorkManagementRepository.__new__(WorkManagementRepository)
    reader.enrich_work_order(Cursor(), rows)
    assert rows[0]['due_date_required'] and rows[0]['due_by'] is None
    assert rows[1]['overdue']
    assert not rows[2]['overdue']  # Due today remains on time.
    assert not rows[3]['overdue']  # Completed is not outstanding work.
    assert not rows[4]['overdue']  # Canceled is not outstanding work.


@pytest.mark.parametrize('direction', ['asc', 'desc'])
@pytest.mark.parametrize('due_filter,operator', [('overdue', ' < '), ('today', ' = '), ('missing', ' IS NULL')])
def test_deadline_selection_is_applied_before_limit(direction, due_filter, operator):
    class Connection:
        queries = []
        def __enter__(self): return self
        def __exit__(self, *args): pass
        def cursor(self, **kwargs): return self
        def execute(self, sql, params=None): self.queries.append(sql)
        def fetchall(self): return []
    connection = Connection()
    repo = WorkManagementRepository.__new__(WorkManagementRepository)
    repo.connect = lambda: connection
    repo.tickets(actor={'can_manage': False, 'person_id': 17}, scope='mine',
                 person_id=None, show_completed=True, search='',
                 sort='due_' + direction, due_filter=due_filter)
    sql = connection.queries[0]
    assert 't.active AND t.done_at IS NULL' in sql
    assert "->>'due_by')::date" + ' FROM' in sql
    assert operator in sql.split('ORDER BY')[-2]
    assert direction.upper() + ' NULLS LAST' in sql
    assert sql.rindex('ORDER BY') < sql.index('LIMIT %s')
    if due_filter != 'missing':
        assert "AT TIME ZONE 'America/Chicago'" in sql


def test_untrusted_deadline_filter_is_rejected():
    from repository import deadline_condition
    with pytest.raises(WorkManagementError):
        deadline_condition('today; DROP TABLE ops.work_order')
