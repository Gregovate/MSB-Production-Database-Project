"""Failure containment tests for the #171 profile of the established runner."""
import hashlib
import json
from pathlib import Path
import sys
import pytest
sys.path.insert(0,str(Path(__file__).parent))
import setup_171_release as site
from setup_maintenance_deploy import Stop

ROOT=Path(__file__).parent
MANIFEST=json.loads((ROOT/'setup_171_release.json').read_text())


class Fake(site.SiteDeploy):
    def __init__(self,root,fail=None):
        super().__init__(dict(MANIFEST),root)
        self.events=[];self.fail=fail;self.new_tables=MANIFEST['new_tables']
    def event(self,name):
        self.events.append(name)
        if self.fail==name:raise Stop(name)
    def mark(self,name):
        self.stage=name; self.journal()
    def controller(self,action,*args):
        self.event(action)
        if action=='snapshot':
            return {'snapshot':dict(validated=True,ok=True,bytes=42,path=args[0],sha256='digest')}
        if action=='off':
            return dict(state='ONLINE',last_error=None,live={'database_fenced':False},gates={'online_proof':{'ok':True}})
        return dict(state='MAINTENANCE',last_error=None,maintenance_started_at='now',
                    gates={'freeze_proof':{'ok':True}},
                    live={'database_fenced':True,'sessions':[]})
    def run(self,argv,**kw):
        assert argv[:2]==['sudo','sha256sum']
        return 'digest archive'
    def capture(self):
        self.event('capture')
        return 'unchanged existing business rows'
    def apply_migrations(self):
        self.event('migrations')
    def validate(self):
        self.event('validate')
    def promote_source(self,baseline):
        self.event('promote')
    def before_reopen(self,baseline):
        self.event('before_reopen')
    def live_validation(self):
        self.event('live_validation')


def test_full_sequence_uses_existing_orchestrator(tmp_path):
    d=Fake(tmp_path/'report')
    d.deploy()
    assert d.events.index('on') < d.events.index('snapshot') < d.events.index('migrations')
    assert d.events.index('migrations') < d.events.index('validate') < d.events.index('promote')
    assert d.events.index('promote') < d.events.index('before_reopen') < d.events.index('off')
    assert d.events.index('off') < d.events.index('live_validation')
    assert d.committed


@pytest.mark.parametrize('failure',['on','snapshot','migrations','validate','promote','before_reopen'])
def test_failure_never_reopens_or_restores(tmp_path,failure):
    d=Fake(tmp_path/'report',failure)
    with pytest.raises(Stop): d.deploy()
    assert 'off' not in d.events
    assert d.maintenance_started
    assert d.events.count('migrations')<=1


def test_hashes_and_approved_source():
    assert MANIFEST['target']==MANIFEST['candidate']==site.APP
    assert list(MANIFEST['migration_blobs'])==list(site.MIGRATIONS)
    assert 'ref.site_network' not in MANIFEST['new_tables']
    for name,digest in MANIFEST['helpers'].items():
        assert hashlib.sha256((ROOT/name).read_bytes()).hexdigest()==digest


def test_mismatched_manifest_stops_before_maintenance(tmp_path):
    d=site.SiteDeploy({**MANIFEST,'target':'wrong'},tmp_path/'report')
    with pytest.raises(Stop,match='manifest'):d.preflight()
    assert not d.maintenance_started


def test_sources_reject_changed_bytes(tmp_path,monkeypatch):
    monkeypatch.setattr(site,'CACHE',tmp_path)
    (tmp_path/(site.GPX+'.gpx')).write_bytes(b'not approved')
    d=site.SiteDeploy(MANIFEST,tmp_path/'report')
    with pytest.raises(Stop,match='source'):d.sources()


def test_source_profile_does_not_relax_disposable_gate():
    source=(ROOT.parents[1]/'Database/EngineeringTools/accept_site_sources.py').read_text()
    assert "conn.info.dbname == 'msb_setup_browser_preview'" in source
    assert 'def deploy(' not in (ROOT/'setup_171_release.py').read_text()
