"""Verify atomic transaction boundaries without changing the server runtime."""
from contextlib import nullcontext
import sys
from pathlib import Path
import pytest
sys.path.insert(0, str(Path(__file__).resolve().parent))
from site_db_connection import SiteConnection


class Raw:
    def __init__(self):
        self.statements = []

    def cursor(self):
        return nullcontext(self)

    def execute(self, sql):
        self.statements.append(sql)


def test_success_commits_and_leaves_connection_reusable():
    raw = Raw()
    conn = SiteConnection(raw)
    for _ in range(2):
        with conn.transaction():
            raw.execute('WRITE')
    assert raw.autocommit
    assert raw.statements == ['BEGIN', 'WRITE', 'COMMIT'] * 2


def test_failure_rolls_back_without_committing_and_can_retry():
    raw = Raw()
    conn = SiteConnection(raw)
    with pytest.raises(ValueError):
        with conn.transaction():
            raw.execute('PARTIAL WRITE')
            raise ValueError('failed import')
    assert raw.statements == ['BEGIN', 'PARTIAL WRITE', 'ROLLBACK']
    with conn.transaction():
        pass
    assert raw.statements[-2:] == ['BEGIN', 'COMMIT']


def test_nested_call_cannot_commit_outer_transaction():
    raw = Raw()
    conn = SiteConnection(raw)
    with pytest.raises(RuntimeError, match='Nested'):
        with conn.transaction():
            with conn.transaction():
                pass
    assert raw.statements == ['BEGIN', 'ROLLBACK']
