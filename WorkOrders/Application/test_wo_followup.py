"""Active-WO follow-up regressions, without Production access or sending mail."""
import json
from pathlib import Path
import subprocess
import sys
from types import SimpleNamespace

import psycopg2
import pytest

sys.path.insert(0, str(Path(__file__).parent))
import v1_runtime as runtime
from repository import WorkManagementError, WorkManagementRepository

HERE = Path(__file__).parent


def test_browser_permissions_execute_real_action_selector():
    source = (HERE / 'review_actions.js').read_text()
    fn = source[source.index('  function permitted()'):source.index('  function drawActions()')]
    script = '''const assert=require('node:assert/strict'); let model;\n''' + fn + '''
    const wo={type:'WORK_ORDER',ticket:'WO-429',active:true,assignee_ids:[26],reporter_id:40};
    model={runtime:'production',actor:{person_id:26,can_manage:false},ticket:wo};
    assert(permitted().includes('clarify'));
    model.ticket={...wo,followup_state:'clarify'};
    assert(!permitted().includes('clarify'));
    model.actor={person_id:40,can_manage:false};
    assert.deepEqual(permitted(),['reply']);
    model.actor={person_id:99,can_manage:false};
    assert.deepEqual(permitted(),[]);
    model.actor={person_id:26,can_manage:true};
    model.ticket={type:'INTAKE_REQUEST',state:'PROMOTED_TO_WO'};
    assert.deepEqual(permitted(),[]);
    model.ticket={type:'TASK_FEEDBACK',state:'WAITING_ON_REPORTER',linked_work_orders:['WO-429']};
    assert.deepEqual(permitted(),[]);
    model.ticket={...wo,done_at:'2026-11-03'};
    assert.deepEqual(permitted(),[]);
    '''
    subprocess.run(['node', '-e', script], check=True)


class Conn:
    def __init__(self, failure=None):
        self.failure=failure; self.rolled_back=False; self.committed=False; self.sql=''
    def set_session(self, **kw): pass
    def cursor(self, **kw): return self
    def __enter__(self): return self
    def __exit__(self, *args): pass
    def execute(self, sql, args):
        self.sql=sql
        if self.failure: raise self.failure
    def fetchone(self): return {'outcome': {'saved': True, 'ticket':'WO-429'}}
    def commit(self): self.committed=True
    def rollback(self): self.rolled_back=True
    def close(self): pass


class Rejection(psycopg2.Error):
    @property
    def pgcode(self): return '23505'
    @property
    def diag(self): return SimpleNamespace(message_primary='Work Orders: linked Work Order owns the outcome')


@pytest.mark.parametrize('ticket,action,command',[
    ('WO-429','clarify','work_management_wo_followup'),
    ('WO-429','reply','work_management_wo_followup'),
    ('INTAKE-75','clarify','work_management_v1_command'),
    ('WO-429','complete','work_management_v1_command'),
    ('WO-422','duplicate','work_management_duplicate')])
def test_command_routing(monkeypatch,ticket,action,command):
    monkeypatch.setenv('WORK_MGMT_RUNTIME_MODE','production')
    monkeypatch.setattr(runtime,'require_v1_production_configuration',lambda **kw:'fake')
    monkeypatch.setattr(runtime,'require_native_database',lambda cur:None)
    conn=Conn(); monkeypatch.setattr(runtime.psycopg2,'connect',lambda dsn:conn)
    runtime.V1Commands().perform({'email':'test@sheboyganlights.org'},action,ticket,
      {'request_key':'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa','response':'Which channel is intended?'})
    assert 'ops.'+command+'(' in conn.sql
    assert conn.committed and not conn.rolled_back


def test_business_conflict_is_not_a_database_outage(monkeypatch):
    monkeypatch.setenv('WORK_MGMT_RUNTIME_MODE','production')
    monkeypatch.setattr(runtime,'require_v1_production_configuration',lambda **kw:'fake')
    monkeypatch.setattr(runtime,'require_native_database',lambda cur:None)
    conn=Conn(Rejection()); monkeypatch.setattr(runtime.psycopg2,'connect',lambda dsn:conn)
    with pytest.raises(WorkManagementError) as err:
        runtime.V1Commands().perform({'email':'test@sheboyganlights.org'},'clarify','INTAKE-75',
          {'request_key':'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa'})
    assert err.value.status == 409
    assert 'linked Work Order' in str(err.value)
    assert conn.rolled_back and not conn.committed


def test_stale_intake_refresh_preserves_draft_and_blocks_failed_status_read():
    source = (HERE / 'review_actions.js').read_text()
    code = source[source.index('  function intakeHandled('):source.index('  window.setInterval(')]
    script = '''const assert=require('node:assert/strict');
    const nodes = new Map();
    function node() {return {disabled:false,value:'unsaved question',children:[],
      replaceChildren(){this.children=[];},append(...v){this.children.push(...v);},
      querySelectorAll(){return [fieldset];}};}
    const fieldset=node(), button=node();
    const byId=id=>{if(!nodes.has(id))nodes.set(id,node());return nodes.get(id);};
    const document={createElement:node,createTextNode:s=>s,querySelectorAll:()=>[button]};
    const appBase=''; const model={ticket:{ticket:'INTAKE-75',type:'INTAKE_REQUEST',state:'SUBMITTED'}};
    let answer={...model.ticket,state:'PROMOTED_TO_WO',linked_work_orders:['WO-429'],
      linked_work_order_details:[{ticket:'WO-429',assignees:'Greg Liebig'}],
      handled:{handled_by:'Another manager',note:'Promoted to WO-429'}};
    let fail=false;
    const fetch=async()=>({ok:!fail,json:async()=>({ticket:answer})});
    ''' + code + '''
    (async()=>{
      const input=byId('review-response');
      assert.equal(await refreshIntakeStatus(),false);
      assert.equal(input.value,'unsaved question');
      assert.equal(fieldset.disabled,true);
      assert.equal(button.disabled,true);
      assert.equal(byId('review-submit').disabled,true);
      model.ticket={ticket:'INTAKE-76',type:'INTAKE_REQUEST',state:'SUBMITTED'};
      fail=true;
      assert.equal(await refreshIntakeStatus(),false);
      assert.equal(model.intakeStatusVerified,false);
      assert.equal(input.value,'unsaved question');
      fail=false;answer={...model.ticket};
      assert.equal(await refreshIntakeStatus(),true);
      assert.equal(byId('review-submit').disabled,false);
    })().catch(e=>{console.error(e);process.exit(1)});
    '''
    subprocess.run(['node','-e',script],check=True)


def test_handled_intake_metadata_uses_native_wo_and_actor_history():
    class Cursor:
        def __init__(self): self.index=-1
        def execute(self,sql,args): self.index+=1
        def fetchall(self):
            return [
              [{'ticket_key':'INTAKE-75','event_kind':'promoted_source','details':{},
                'handled_by':'Manager A','created_at':'2026-11-03','note':'Promoted to WO-429'}],
              [],
              [{'source_intake_id':75,'work_order_id':429,'assignees':'Greg Liebig'}]
            ][self.index]
    row={'type':'INTAKE_REQUEST','ticket':'INTAKE-75','state':'SUBMITTED'}
    repo=object.__new__(WorkManagementRepository)
    repo.enrich_feedback(Cursor(),[row])
    assert row['state']=='PROMOTED_TO_WO'
    assert row['handled']['handled_by']=='Manager A'
    assert row['linked_work_order_details']==[{'ticket':'WO-429','assignees':'Greg Liebig'}]


def test_existing_photo_references_preserve_both_sources_and_reject_active_urls():
    from repository import photo_references
    original = "https://drive.google.com/open?id=original"
    added = "https://drive.google.com/file/d/added/view"
    assert photo_references(added, original + ", " + added) == [added, original]
    assert photo_references(None, original) == [original]
    assert photo_references("javascript:alert(1) data:text/html,evil https://user:pass@example.org/x https://[") == []


def test_activity_presentation_uses_names_plain_labels_and_central_time():
    source = (HERE / 'app.js').read_text()
    functions = source[source.index('  function activityHeading'):source.index('  async function loadActivity')]
    script = "const assert=require('node:assert/strict');\n" + functions + """
    assert.equal(activityHeading({event_kind:'progress',actor_name:'Greg Liebig'}),
      'Work note added · Greg Liebig');
    assert.equal(activityHeading({event_kind:'promote',actor_name:'Rick Hoffmann'}),
      'Request promoted to Work Order · Rick Hoffmann');
    assert.equal(activityHeading({event_kind:'new_internal_code',actor_person_id:17}),
      'Activity recorded · Name unavailable');
    const date=activityDate('2026-11-03T12:00:14Z');
    assert(date.includes('Nov 3, 2026'));
    assert(date.includes('6:00 AM CST'));
    assert.equal(activityDate('invalid'), 'Date unavailable');
    """
    subprocess.run(['node', '-e', script], check=True)


def test_progress_copies_hidden_only_when_exact_activity_is_loaded():
    source = (HERE / 'app.js').read_text()
    fn = source[source.index('  function originalNotesWithoutRecordedProgress'):source.index('  function activityHeading')]
    script = "const assert=require('node:assert/strict');\n" + fn + r"""
    const entry='[2026-11-03 12:00 UTC | Person #17] First line\nSecond line';
    const event={event_kind:'progress',actor_person_id:17,created_at:'2026-11-03T12:00:14Z',note:'First line\nSecond line'};
    assert.equal(originalNotesWithoutRecordedProgress('Original notes\n'+entry,[event]),'Original notes');
    assert.equal(originalNotesWithoutRecordedProgress(entry,[]),entry);
    assert.equal(originalNotesWithoutRecordedProgress(entry,[{...event,actor_person_id:15}]),entry);
    assert.equal(originalNotesWithoutRecordedProgress(entry+'\nUnmatched history',[event]),entry+'\nUnmatched history');
    assert.equal(originalNotesWithoutRecordedProgress(entry,[{...event,created_at:'2026-11-03T12:01:14Z'}]),entry);
    """
    subprocess.run(['node','-e',script],check=True)
