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
