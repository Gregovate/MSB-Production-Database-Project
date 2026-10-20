"""Due-date visibility: no invented deadline and no overdue closed work."""
from repository import WorkManagementRepository


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
