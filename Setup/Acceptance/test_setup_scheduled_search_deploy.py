"""Search release uses the existing maintenance boundary without any SQL writes."""
import json
from pathlib import Path
import pytest
from setup_required_container_deploy import ScheduledSearchDeploy, deployment_profile
from setup_maintenance_deploy import Stop, SETUP
from test_setup_required_container_deploy import FakeRequired

MANIFEST=json.loads(Path(__file__).with_name('setup_scheduled_search_release.json').read_text())


class FakeSource(ScheduledSearchDeploy, FakeRequired):
    def __init__(self,root,fail=None):
        FakeRequired.__init__(self,root,fail)
        self.m={**MANIFEST,'shared':'unchanged-shared'}
        self.head=self.old_setup;self.queries=[]
    def git(self,*args,root=None):
        self.calls.append('git:'+args[0])
        if args[0]=='rev-parse':return self.head if root==SETUP else self.m['shared']
        if args[0]=='checkout':self.head=args[-1]
        if args[0]=='show':
            return Path(__file__).parents[1].joinpath('Database/073_add_setup_required_container_command.sql').read_text()
        return ''
    def run(self,args,**kwargs):
        if 'curl' in args:
            return json.dumps(dict(status='ok',data_mode='postgres',version=self.version))
        return FakeRequired.run(self,args,**kwargs)
    def sql(self,query):self.queries.append(query);return ''
    def capture(self):
        self.captures+=1
        return 'drift' if self.fail=='invariants' and self.captures==2 else 'stable'
    def validate(self):
        if self.fail=='validate':raise Stop('validation failed')
        ScheduledSearchDeploy.validate(self)


def test_source_only_release_never_migrates_or_creates_rollback_archive(tmp_path):
    d=FakeSource(tmp_path/'report')
    try:
        d.deploy()
        assert d.head==d.target
        assert d.calls.index('on')<d.calls.index('git:checkout')<d.calls.index('off')
        assert 'snapshot' not in d.calls and 'git:merge' not in d.calls
        assert not d.migration_started and not d.committed
        assert d.queries and all(q.startswith('BEGIN READ ONLY;') for q in d.queries)
        assert d.m['shared']=='unchanged-shared'
        assert json.loads((d.root/'state.json').read_text())['migration_started'] is False
    finally:d.log.close()


@pytest.mark.parametrize('fail',['on','validate','invariants'])
def test_failed_source_gate_keeps_maintenance_containment(tmp_path,fail):
    d=FakeSource(tmp_path/'report',fail)
    try:
        with pytest.raises(Stop):d.deploy()
        assert 'off' not in d.calls
        assert not d.migration_started
    finally:d.log.close()


def test_unknown_profile_rejected(tmp_path):
    with pytest.raises(Stop):deployment_profile({'profile':'unknown'},tmp_path/'report')


def test_search_profile_requires_accepted_c106_baseline_and_no_migration():
    assert MANIFEST['old_setup']=='efb7f26fd0d4e1275daa509e2ade62bc291b1d8f'
    assert MANIFEST['migration'] is None
    assert MANIFEST['target']==ScheduledSearchDeploy.target
    assert MANIFEST['old_version']=='V0.3.64-required-containers'
    wrapper=Path(__file__).with_name('run_setup_required_container_deploy.ps1').read_text()
    assert "ValidateSet('RequiredContainers','ScheduledSearch')" in wrapper
    assert 'setup_scheduled_search_release.json' in wrapper
    assert 'timeout --foreground' in wrapper
