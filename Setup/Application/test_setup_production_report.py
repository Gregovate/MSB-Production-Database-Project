"""#88 report regressions: actual evidence, permissions and GPS-only visibility."""
from datetime import datetime, timezone
from pathlib import Path
import shutil
import subprocess

from flask import Flask
import pytest

from setup_api import SetupCommandError
import setup_material_readiness_api as api
from setup_material_readiness_repository import SetupMaterialReadinessRepository
from setup_production_report import gps_text, report_context, render_report
from test_setup_175_current_location import projection


def fixture_data():
    def event(n, day, **extra):
        return dict(setup_movement_event_id=n,event_type='CONTAINER_MOVE',container_id=216,
                    container_name='Panels',occurred_at=datetime(2026,10,day,15,tzinfo=timezone.utc),
                    received_at=datetime(2026,10,7,20,tzinfo=timezone.utc),
                    destination_location_note=None,stage_key=None,stage_name=None,
                    gps_latitude=43,gps_longitude=-87,gps_accuracy_m=3.048,
                    captured_operator_email='recorder',capture_method='HID_SCAN',offline_captured=False,
                    notes=None,display_id=None,display_name=None,movement_effect=None,**extra)
    # Receipt 124 describes an earlier day; two effect rows still count as ONE event.
    old = event(48,6); old.update(destination_location_note='Church',gps_latitude=None,gps_longitude=None)
    recent=event(124,5); recent.update(notes='contents_review_required=true',offline_captured=True)
    a=dict(recent,display_id=6,display_name='Panel <one>',movement_effect='UNLOADED')
    b=dict(recent,display_id=7,display_name='Panel two',movement_effect='UNLOADED')
    latest=event(125,7)
    material=dict(session=dict(setup_session_id=2,season_year=2026,session_status='PLANNING'),
                  summary=dict(picked_moved=1,unresolved=1),items=[],
                  unresolved_requirements=[dict(task_name='<script>alert(1)</script>',
                    message='No active expected-source Container.',requirement_type='EXTRA_MATERIAL_SOURCE')])
    picture=dict(database_name='fixture_only',generated_at=datetime(2026,10,8,tzinfo=timezone.utc),
                 through_event_id=125,effect_rows=[a,b,old,latest],
                 containers=[dict(container_id=216,container_name='Panels',last_movement_event_id=125,
                                  container_type_name='Display Pallet',movement_status='CONTAINER_MOVE')],
                 displays=[dict(display_id=6,display_name='Panel <one>',container_id=216,position_mode='DETACHED',last_movement_event_id=124),
                           dict(display_id=7,display_name='Panel two',container_id=216,position_mode='WITH_CONTAINER')])
    return material,picture


def test_report_receipt_comparison_preserves_late_observation_and_effect_scope():
    material,picture=fixture_data()
    ctx=report_context(material,picture,123)
    assert [e['setup_movement_event_id'] for e in ctx['new_events']] == [124,125]
    assert len(ctx['events']) == 3
    assert ctx['new_events'][0]['observed'].startswith('10/05/2026')
    assert ctx['new_events'][0]['received'].startswith('10/07/2026')
    assert ctx['new_events'][0]['unloaded_names'] == ['Panel <one>','Panel two']
    c=ctx['containers'][0]
    assert c['prior_named_context']=='Church'
    assert c['location_group']=='GPS only / prior named context Church'
    assert len(c['review_flags']) == 1
    assert len(c['attached']) == len(c['detached']) == 1
    assert ctx['new_events'][1]['unloaded_names'] == []


def test_return_boundary_and_latest_event_cutoff_do_not_borrow_future_name():
    material,picture=fixture_data()
    returned=dict(picture['effect_rows'][-1],setup_movement_event_id=49,event_type='RETURNED',
                  occurred_at=datetime(2026,10,6,17,tzinfo=timezone.utc),destination_location_note='Home')
    future=dict(returned,setup_movement_event_id=126,event_type='CONTAINER_MOVE',
                occurred_at=datetime(2026,10,8,17,tzinfo=timezone.utc),destination_location_note='Future Stage')
    picture['effect_rows'] += [returned,future]
    c=report_context(material,picture,0)['containers'][0]
    assert c['prior_named_context'] is None
    assert c['location_group']=='GPS only / no named reference'


def test_report_html_escapes_evidence_and_explains_unresolved_and_uncertainty():
    material,picture=fixture_data()
    with Flask(__name__).app_context():
        html=render_report(material,picture,123)
    assert '<script>alert(1)</script>' not in html
    assert '&lt;script&gt;alert(1)&lt;/script&gt;' in html
    assert 'Panel &lt;one&gt;' in html
    assert '±10 ft' in html
    assert 'Recorded Display removals: 2' in html
    assert 'Physical contents unconfirmed' in html
    assert 'not a count of missing Containers' in html
    assert 'resolution status unavailable' in html
    assert 'Print / Save PDF' in html


def test_gps_quality_and_missing_fix_do_not_invent_location():
    assert gps_text(dict(gps_latitude=None,gps_longitude=-87,gps_accuracy_m=3))=='No GPS recorded'
    result=gps_text(dict(gps_latitude=43,gps_longitude=-87,gps_accuracy_m=3.048,
                         gps_quality='BAD',gps_fix_age_ms=45000))
    assert '±10 ft' in result and '[BAD]' in result and '[STALE FIX]' in result
    assert '[STALE FIX]' in gps_text(dict(gps_latitude=43,gps_longitude=-87,gps_fix_age_ms=16000))


def test_report_endpoint_requires_manager_and_rejects_bad_comparison_before_db(monkeypatch):
    app=Flask(__name__); app.register_blueprint(api.setup_material_readiness_api)
    def deny(): raise SetupCommandError('Manager access is required')
    monkeypatch.setattr(api,'require_manager',deny)
    monkeypatch.setattr(api,'repo',lambda: pytest.fail('DB must not be read before authorization'))
    client=app.test_client()
    assert client.get('/api/setup/material-status/report?season_year=2026').status_code==403
    monkeypatch.setattr(api,'require_manager',lambda: None)
    for value in ('-1','1.5','abc','999999999999999999999'):
        assert client.get('/api/setup/material-status/report?season_year=2026&since_event_id='+value).status_code==400


def test_report_endpoint_fresh_html_and_no_store(monkeypatch):
    app=Flask(__name__); app.register_blueprint(api.setup_material_readiness_api)
    material,picture=fixture_data()
    class Repo:
        def manager_material_status(self,year): assert year==2026; return material
    monkeypatch.setattr(api,'require_manager',lambda: None)
    monkeypatch.setattr(api,'repo',Repo)
    monkeypatch.setattr(api,'movement_picture',lambda repo,sid: picture if sid==2 else pytest.fail('wrong Session'))
    response=app.test_client().get('/api/setup/material-status/report?season_year=2026&since_event_id=123')
    assert response.status_code==200
    assert response.mimetype=='text/html'
    assert response.headers['Cache-Control']=='no-store, max-age=0'
    assert b'event 125' in response.data
    material['session']=None
    assert app.test_client().get('/api/setup/material-status/report?season_year=2026').status_code==404


def test_material_status_actual_projection_keeps_gps_only_container_and_detached_display(projection,monkeypatch):
    next_repo,conn=projection
    conn.executescript("""
      ALTER TABLE ops.setup_container_state ADD COLUMN last_movement_at TEXT;
      ALTER TABLE ops.setup_display_state ADD COLUMN last_movement_at TEXT;
      INSERT INTO ops.setup_display_state(setup_session_id,display_id,position_mode,last_movement_event_id)
        VALUES(1,834,'DETACHED',41);
      UPDATE ops.setup_movement_event SET event_type='CONTAINER_MOVE',container_id=178;
    """)
    repo=SetupMaterialReadinessRepository('fixture-only')
    monkeypatch.setattr(repo,'connect',next_repo.connect)
    state=repo._observation_state(setup_session_id=1,container_ids=[178],display_ids=[834])
    assert state[('CONTAINER',178)]['gps_latitude']==43.778556
    assert state[('CONTAINER',178)]['gps_accuracy_m']==3
    assert state[('DISPLAY',834)]['gps_latitude']==43.778657
    assert state[('DISPLAY',834)]['position_mode']=='DETACHED'


def test_material_status_executable_ui_gps_and_report_scope():
    node=shutil.which('node')
    if not node: pytest.skip('Node engineering check; not required on the browser-review workstation')
    source=Path(__file__).with_name('setup_material_status.js').read_text()
    source=source.replace('  load().catch(showError);\n})();',
      "  globalThis.ui={currentLocation,renderSummary,setData:value=>data=value};\n})();")
    harness=r'''
    const assert=require('node:assert/strict');
    const elements={};
    class Element{constructor(){this.value='';this.listeners={};this.options=[];}addEventListener(k,fn){this.listeners[k]=fn;}appendChild(c){this.options.push(c);}querySelectorAll(){return [];}scrollIntoView(){this.scrolled=true;}}
    globalThis.document={getElementById:id=>elements[id]??=new Element(),createElement:()=>new Element()};
    globalThis.location={search:'?season_year=2026'};
    globalThis.window={open:(...args)=>globalThis.opened=args};
    '''
    checks=r'''
    assert.match(ui.currentLocation({current_observation:{gps_latitude:43.77,gps_longitude:-87.74,gps_accuracy_m:3.048,last_movement_event_id:44}}),/GPS .*±10 ft/);
    assert.doesNotMatch(ui.currentLocation({current_observation:{gps_latitude:43,gps_longitude:-87}}),/No Setup observation/);
    assert.match(ui.currentLocation({current_observation:{current_location_note:'Church',gps_latitude:43,gps_longitude:-87}}),/prior named context/);
    assert.match(ui.currentLocation({current_observation:{last_movement_event_id:1,last_event_type:'PICKED'}}),/PICKED recorded; no location/);
    assert.equal(ui.currentLocation({}),'No Setup observation');
    elements['season-select'].value='2026';elements['status-filter'].value='PICKED_MOVED';
    elements['production-report-button'].listeners.click();
    assert.equal(opened[0],'../api/setup/material-status/report?season_year=2026');assert.equal(opened[2],'noopener');
    ui.setData({summary:{unresolved:15},items:[],unresolved_requirements:[{message:'missing source'}]});
    elements['search-filter'].value='old';elements['stage-filter'].value='15';ui.renderSummary();
    elements['show-unresolved'].listeners.click();
    assert.equal(elements['status-filter'].value,'UNRESOLVED');assert.equal(elements['search-filter'].value,'');
    assert.equal(elements['stage-filter'].value,'');assert.ok(elements['unresolved-panel'].scrolled);
    '''
    subprocess.run([node,'-e',harness+source+checks],check=True,capture_output=True,text=True)
