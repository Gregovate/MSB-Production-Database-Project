"""Exercise actual acceptance decisions without a database or role changes."""
from types import SimpleNamespace

import pytest

from validate_work_management_clone import check_privileged_reads, WorkManagementError


def denied(**kwargs):
    raise WorkManagementError('Denied', 403)


def test_crew_correct_denials_pass():
    repo = SimpleNamespace(tickets=denied, reviewer_options=lambda actor: denied())
    check_privileged_reads(repo, {'can_manage': False})


@pytest.mark.parametrize('boundary', ['tickets', 'reviewer_options'])
@pytest.mark.parametrize('status', [None, 500])
def test_crew_leak_or_wrong_error_fails(boundary, status):
    def unexpected(*args, **kwargs):
        if status:
            raise WorkManagementError('Unexpected', status)
        return []
    repo = SimpleNamespace(tickets=denied, reviewer_options=lambda actor: denied())
    setattr(repo, boundary, unexpected)
    with pytest.raises(RuntimeError):
        check_privileged_reads(repo, {'can_manage': False})


def test_manager_reads_all_required_catalogs():
    calls = []
    repo = SimpleNamespace(
        tickets=lambda **kw: calls.append(kw['scope']) or [],
        assignees=lambda: calls.append('assignees') or [{'person_id': 1}],
        reviewer_options=lambda actor: calls.append('catalogs') or {
            'task_types': [1], 'stages': [1], 'work_areas': [1]},
    )
    check_privileged_reads(repo, {'can_manage': True})
    assert calls == ['all', 'assignees', 'catalogs']


def test_manager_denial_is_not_accepted():
    with pytest.raises(WorkManagementError):
        check_privileged_reads(SimpleNamespace(tickets=denied), {'can_manage': True})


def test_release_rehearsal_pins_actual_server_envelope_and_restores_clone_baseline():
    """Any transaction drift needs a newly generated, reviewed rehearsal."""
    from pathlib import Path
    import hashlib
    here = Path(__file__).parent
    sql = (here / 'wo447_release_transaction_rehearsal.sql').read_text()
    envelope = sql.split('-- BEGIN EXACT PRODUCTION ENVELOPE\n', 1)[1].split('-- END EXACT PRODUCTION ENVELOPE', 1)[0]
    assert hashlib.sha256(envelope.encode()).hexdigest() == 'ed4e10f5f2fac4c68570a17fa21b09c0659d15fd65ed725742380cad4874b509'
    assert sql.index("current_database() <> 'msb_wo419_preview'") < sql.index('BEGIN; SET LOCAL')
    assert sql.index('WO447_UNCOMMITTED_ROLLBACK_OK') < sql.index('-- BEGIN EXACT PRODUCTION ENVELOPE')
    assert sql.index('WO447_COMMIT_OK') < sql.index('DROP FUNCTION ops.work_management_reconcile_actor(text)')
    assert sql.rindex('WO447 rollback did not restore absent entry') > sql.index('DROP FUNCTION')
    runner = (here / 'work_management_disposable_browser_preview_server.sh').read_text()
    block = runner.split('if [[ "$MODE" == "validate_v1" ]]', 1)[1]
    assert block.index('wo447_release_transaction_rehearsal.sql') < block.index('004_work_management_identity_reconciliation.sql')


def test_manager_validate_reaches_writer_with_returned_catalogs(monkeypatch):
    """Exercise the caller path that formerly lost catalogs across helper scope."""
    import validate_work_management_clone as validator
    from contextlib import nullcontext

    class Cursor:
        def execute(self, sql, *args):
            self.sql = sql
        def fetchone(self):
            if self.sql.startswith('SHOW'): return ('on',)
            if 'current_database()' in self.sql: return ('msb_wo419_preview', '172.18.0.5')
            return (0, 0)
        def fetchall(self):
            return [('WO-1', 'WORK_ORDER', 'OPEN', None, 'Reviewer')]

    catalogs = {'task_types': [{'id': 2}], 'stages': [{'id': 3}],
                'work_areas': [{'id': 4}], 'people': [{'person_id': 17}]}
    cur = Cursor()
    conn = SimpleNamespace(cursor=lambda: nullcontext(cur))
    repo = SimpleNamespace(connect=lambda: nullcontext(conn),
        access=lambda email: {'person_id': 17, 'can_manage': True},
        tickets=lambda **kwargs: [], assignees=lambda: [{'person_id': 17}],
        reviewer_options=lambda actor: catalogs, aging_report=lambda **kwargs: [])
    monkeypatch.setattr(validator, 'WorkManagementRepository', lambda: repo)
    class WriterReached(Exception): pass
    def writer():
        assert validator.CURRENT_PHASE == 'clone_write_transaction_rollback'
        raise WriterReached()
    monkeypatch.setattr(validator, 'CloneCommands', writer)
    with pytest.raises(WriterReached):
        validator.validate('gliebig@sheboyganlights.org')
