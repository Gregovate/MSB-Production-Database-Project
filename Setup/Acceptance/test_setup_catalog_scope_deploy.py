"""Exercise the reused source-only window and containment for accepted Catalog source."""
import json
from pathlib import Path
import pytest
from setup_catalog_scope_deploy import CatalogScopeDeploy
from setup_maintenance_deploy import Stop
from test_setup_scheduled_search_deploy import FakeSource

MANIFEST = json.loads(Path(__file__).with_name('setup_catalog_scope_release.json').read_text())

class FakeCatalog(CatalogScopeDeploy, FakeSource):
    def __init__(self, root, fail=None):
        FakeSource.__init__(self, root, fail)
        self.m = {**MANIFEST, 'shared': 'unchanged-shared'}


def test_catalog_reuses_freeze_source_promotion_and_reopen_without_migration(tmp_path):
    d = FakeCatalog(tmp_path/'report')
    try:
        d.deploy()
        assert d.head == MANIFEST['target']
        assert d.calls.index('on') < d.calls.index('git:checkout') < d.calls.index('off')
        assert 'snapshot' not in d.calls and 'git:merge' not in d.calls
        assert not d.migration_started and not d.committed
        assert all(q.startswith('BEGIN READ ONLY;') for q in d.queries)
        assert 'protected Catalog' in d.stage
    finally:
        d.log.close()


@pytest.mark.parametrize('failure', ['on', 'validate', 'invariants'])
def test_catalog_failure_never_reopens_or_applies_sql(tmp_path, failure):
    d = FakeCatalog(tmp_path/'report', failure)
    try:
        with pytest.raises(Stop):
            d.deploy()
        assert 'off' not in d.calls
        assert not d.migration_started
    finally:
        d.log.close()


def test_unexpected_source_still_stops_before_maintenance(tmp_path):
    d = FakeCatalog(tmp_path/'report')
    try:
        d.head = 'unreviewed-source'
        with pytest.raises(Stop, match='Setup baseline drift'):
            d.baseline()
        assert 'on' not in d.calls
    finally:
        d.log.close()
