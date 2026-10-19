"""#88 actionable review projection, access and native command regression."""
from copy import deepcopy
from datetime import datetime, timezone
from pathlib import Path
from uuid import uuid4
import json
import os
import sys

from flask import Flask
import pytest
import psycopg2
from psycopg2.extras import Json, RealDictCursor

from test_setup_production_report import fixture_data
from setup_container_review import exception_context, captured_scope
import setup_container_review_api as api
from setup_api import SetupCommandError


def test_review_queue_does_not_turn_history_into_current_errors_or_close_new_flags():
    _, picture = fixture_data()
    c=picture['containers'][0]
    c['movement_status']='RETURNED'
    reviews=[dict(container_id=216,action='CONFIRM',resolved_flag_ids=[124],recorded_at=picture['generated_at'])]
    ctx=exception_context(picture,reviews,{216:{'pinned':True}})
    row=ctx['cases'][0]
    assert row['open_flags']==[]
    assert [r['code'] for r in row['reasons']]==['RETURNED_ATTACHED']
    assert row['status']=='OPEN'
    assert row['attached'][0]['display_name']=='Panel two'
    assert row['snapshot']=={'pinned':True}
    picture['displays'][1]['position_mode']='DETACHED'
    assert exception_context(picture,reviews,{})['cases'][0]['status']=='RESOLVED'
    fresh=deepcopy(picture['effect_rows'][0]);fresh['setup_movement_event_id']=200
    picture['effect_rows'].append(fresh)
    assert exception_context(picture,reviews,{})['cases'][0]['open_flags'][0]['setup_movement_event_id']==200


def test_capture_scope_is_not_reconstructed_from_current_assignments():
    assert captured_scope('contents_review_required=true') is None
    assert captured_scope('contents_reconciliation={"review_context":{"context_available":false,"expected_displays":[]}}') is None
    assert captured_scope('contents_reconciliation={"review_context":{"context_available":true,"expected_displays":[{"display_id":3,"display_name":"PeaceOnEarth"}]}}; contents_review_required=true')==[{'display_id':3,'display_name':'PeaceOnEarth'}]


def test_manager_guard_and_get_never_writes(monkeypatch):
    app=Flask(__name__);app.register_blueprint(api.setup_container_review_api)
    class Base:
        def movement_summary(self,year): return {'setup_session_id':2}
    class Repo:
        def exceptions(self,sid,container_id=None): assert sid==2;return {'cases':[]}
        def record_review(self,**kw): pytest.fail('GET wrote review')
    monkeypatch.setattr(api,'require_manager',lambda:(Base(),'manager@example.org',{}))
    monkeypatch.setattr(api,'repo',Repo)
    response=app.test_client().get('/api/setup/container-exceptions?season_year=2026')
    assert response.status_code==200 and response.json=={'cases':[]}
    assert 'no-store' in response.headers['Cache-Control']
    monkeypatch.setattr(api,'require_manager',lambda:(_ for _ in ()).throw(SetupCommandError('Manager required')))
    assert app.test_client().get('/api/setup/container-exceptions?season_year=2026').status_code==403
    assert app.test_client().post('/api/setup/container-exceptions/216/review',json={}).status_code==403


@pytest.fixture
def native_db(tmp_path):
    if sys.platform != 'linux' or os.geteuid() == 0:
        pytest.skip('Optional native PostgreSQL runs as non-root; PostgreSQL/WASM and host clone gates are separate')
    pgserver=pytest.importorskip('pgserver',reason='Engineering native PostgreSQL dependency; host disposable validation remains required')
    server=pgserver.get_server(tmp_path/'review-pg',cleanup_mode='delete')
    conn=psycopg2.connect(server.get_uri());conn.autocommit=True
    root=Path(__file__).parents[1]
    try:
        with conn.cursor() as cur:
            cur.execute((root/'Acceptance/setup_88_reconciliation_fixture.sql').read_text())
            cur.execute("CREATE TABLE ref.person(person_id integer PRIMARY KEY); INSERT INTO ref.person VALUES(1)")
            cur.execute("""CREATE FUNCTION ref.setup_management_actor(p_email text,p_admin boolean) RETURNS TABLE(directus_user_id uuid,person_id integer,display_name text) LANGUAGE plpgsql AS $$ BEGIN
                IF p_email<>'manager@example.org' THEN RAISE EXCEPTION 'Manager required' USING ERRCODE='42501'; END IF;
                RETURN QUERY SELECT '88000000-0000-4000-8000-000000000001'::uuid,1,'Manager'::text; END; $$""")
            cur.execute((root/'Database/070_reconcile_setup_container_contents.sql').read_text())
            cur.execute((root/'Database/077_add_setup_container_contents_review.sql').read_text())
            cur.execute("GRANT USAGE ON SCHEMA ops,ref TO fieldwiring_app; GRANT SELECT ON ALL TABLES IN SCHEMA ops,ref TO fieldwiring_app")
        yield conn
    finally:
        conn.close();server.cleanup()


def query(conn,sql,args=()):
    with conn.cursor(cursor_factory=RealDictCursor) as cur:
        cur.execute(sql,args)
        return [dict(r) for r in cur.fetchall()] if cur.description else []


def snapshot(conn,cid=216):
    return query(conn,'SELECT ops.setup_container_review_snapshot(2,%s) s',(cid,))[0]['s']


def command(**kw):
    return dict(action='CONFIRM',display_ids=[2],flag_ids=[],resolve_flag_ids=[],evidence='Crew confirmed recorded state',observed_at='2026-10-10T15:00:00Z',whole_case_confirmed=False,**kw)


def save(conn,request,cid=216,expected=None,event=None,email='manager@example.org'):
    return query(conn,'SELECT * FROM ops.review_setup_container_contents(%s,2026,%s,%s,%s,%s)',
                 (email,cid,str(event or uuid4()),Json(expected if expected is not None else snapshot(conn,cid)),Json(request)))[0]


def test_native_review_partial_closure_retry_and_privilege(native_db):
    conn=native_db
    notes='contents_reconciliation='+json.dumps({'review_context':{'context_available':True,'expected_displays':[{'display_id':2},{'display_id':3}]}})+'; contents_review_required=true'
    flag=query(conn,"INSERT INTO ops.setup_movement_event(setup_session_id,event_type,container_id,occurred_at,received_at,destination_location_note,notes) VALUES(2,'CONTAINER_MOVE',216,'2026-10-10','2026-10-10','Park',%s) RETURNING setup_movement_event_id",(notes,))[0]['setup_movement_event_id']
    req=command();req.update(flag_ids=[flag]);expected=snapshot(conn);event=uuid4()
    query(conn,'SET ROLE fieldwiring_app')
    first=save(conn,req,expected=expected,event=event)
    assert save(conn,req,expected=expected,event=event)['setup_container_review_event_id']==first['setup_container_review_event_id']
    with pytest.raises(psycopg2.Error,match='identity already used'):
        save(conn,{**req,'evidence':'Different claim'},expected=expected,event=event)
    with pytest.raises(psycopg2.Error,match='changed'):
        save(conn,req,expected=expected)
    with pytest.raises(psycopg2.Error,match='still unresolved'):
        save(conn,{**req,'resolve_flag_ids':[flag]})
    complete={**req,'display_ids':[3],'resolve_flag_ids':[flag]}
    assert save(conn,complete)['resolved_flag_ids']==[flag]
    with pytest.raises(psycopg2.Error,match='Manager required'):
        save(conn,req,email='captain@example.org')
    with pytest.raises(psycopg2.Error,match='permission denied'):
        query(conn,"UPDATE ops.setup_container_review_event SET evidence='hide evidence'")
    with pytest.raises(psycopg2.Error,match='permission denied'):
        query(conn,'DELETE FROM ops.setup_container_review_event')


def test_native_return_recovery_preserves_home_and_later_placements(native_db):
    conn=native_db
    park=query(conn,"INSERT INTO ops.setup_movement_event(setup_session_id,event_type,container_id,occurred_at,received_at,destination_location_note,gps_latitude,gps_longitude,gps_accuracy_m) VALUES(2,'CONTAINER_MOVE',216,'2026-10-09 10:00Z','2026-10-09','Festive Trees',43.778407,-87.743780,3) RETURNING setup_movement_event_id")[0]['setup_movement_event_id']
    returned=query(conn,"INSERT INTO ops.setup_movement_event(setup_session_id,event_type,container_id,occurred_at,received_at) VALUES(2,'RETURNED',216,'2026-10-09 12:00Z','2026-10-09 12:00Z') RETURNING setup_movement_event_id")[0]['setup_movement_event_id']
    query(conn,"INSERT INTO ops.setup_container_state VALUES(2,216,NULL,'RC02-A-01',%s,'RETURNED','2026-10-09 12:00Z')",(returned,))
    before=snapshot(conn)
    with pytest.raises(psycopg2.Error,match='contradiction'):
        save(conn,command())
    req={**command(),'action':'PRIOR_PARK','display_ids':[2]}
    result=save(conn,req)
    ds=query(conn,'SELECT * FROM ops.setup_display_state WHERE display_id=2')[0]
    event=query(conn,'SELECT * FROM ops.setup_movement_event WHERE setup_movement_event_id=%s',(ds['last_movement_event_id'],))[0]
    assert ds['position_mode']=='DETACHED' and event['destination_location_note']=='Festive Trees'
    assert f'prior_event_id={park}' in event['notes'] and 'inferred_unload=true' in event['notes']
    assert event['occurred_at'].year>=2026 and event['occurred_at']!=datetime(2026,10,9,tzinfo=timezone.utc)
    assert snapshot(conn)['state']==before['state']
    # New direct placement must invalidate a screen opened before it arrived.
    stale=snapshot(conn)
    query(conn,"SELECT * FROM ops.record_setup_movement_event('manager@example.org',2026,%s,'DISPLAY',3,'DISPLAY_MOVE',clock_timestamp(),NULL,NULL,'MANUAL_ENTRY',false,NULL,NULL,NULL,16,'Later valid placement')",(str(uuid4()),))
    with pytest.raises(psycopg2.Error,match='changed'):
        save(conn,{**req,'display_ids':[3]},expected=stale)
    with pytest.raises(psycopg2.Error,match='independent placement'):
        save(conn,{**req,'display_ids':[3]})
    assert query(conn,'SELECT current_stage_id FROM ops.setup_display_state WHERE display_id=3')[0]['current_stage_id']==16
    assert result['movement_event_ids']==[ds['last_movement_event_id']]


def test_native_protected_recovery_and_legacy_scope(native_db):
    conn=native_db
    bad=query(conn,"INSERT INTO ops.setup_movement_event(setup_session_id,event_type,container_id,occurred_at,received_at,destination_location_note,notes) VALUES(2,'CONTAINER_MOVE',199,'2026-10-09','2026-10-09','Park','contents_review_required=true') RETURNING setup_movement_event_id")[0]['setup_movement_event_id']
    query(conn,"INSERT INTO ops.setup_container_state VALUES(2,199,NULL,'Park',%s,'CONTAINER_MOVE','2026-10-09')",(bad,))
    query(conn,"INSERT INTO ops.setup_display_state VALUES(2,5,'DETACHED',NULL,'Park',%s,'TASK_UNLOAD','2026-10-09')",(bad,))
    req={**command(),'display_ids':[5],'flag_ids':[bad]}
    with pytest.raises(psycopg2.Error,match='stays attached'):
        save(conn,{**req,'action':'LOCATION','location_note':'Other'},cid=199)
    restored=save(conn,{**req,'action':'ATTACH'},cid=199)
    assert query(conn,'SELECT position_mode,current_location_note FROM ops.setup_display_state WHERE display_id=5')[0]=={'position_mode':'WITH_CONTAINER','current_location_note':None}
    with pytest.raises(psycopg2.Error,match='whole case'):
        save(conn,{**req,'resolve_flag_ids':[bad]},cid=199)
    assert save(conn,{**req,'resolve_flag_ids':[bad],'whole_case_confirmed':True},cid=199)['resolved_flag_ids']==[bad]
    assert query(conn,'SELECT movement_effect FROM ops.setup_movement_event_display WHERE setup_movement_event_id=%s',(restored['movement_event_ids'][0],))[0]['movement_effect']=='REATTACHED'


def test_field_check_remains_actionable_until_explicit_scoped_review():
    _,picture=fixture_data()
    picture['effect_rows']=[r for r in picture['effect_rows'] if r['setup_movement_event_id']!=124]
    check=dict(container_id=216,action='NEEDS_FIELD_CHECK',resolved_flag_ids=[],display_ids=[6,7],
               recorded_at=picture['generated_at'],snapshot={})
    partial=dict(container_id=216,action='CONFIRM',resolved_flag_ids=[],display_ids=[6],recorded_at=picture['generated_at'])
    ctx=exception_context(picture,[check,partial],{})
    assert ctx['cases'][0]['status']=='NEEDS_FIELD_CHECK'
    complete={**partial,'display_ids':[7]}
    assert exception_context(picture,[check,partial,complete],{})['cases'][0]['status']=='RESOLVED'


def test_known_concern_can_be_opened_from_desk_without_flagging_healthy_inventory():
    _,picture=fixture_data()
    for row in picture['effect_rows']: row['notes']=None
    assert exception_context(picture,[],{})['cases']==[]
    manual=exception_context(picture,[],{},container_id=216)
    assert manual['cases'][0]['status']=='NOT_FLAGGED'
    assert manual['counts']['open']==manual['counts']['resolved']==0


def test_review_api_uses_signed_in_manager_and_requires_command_guard(monkeypatch):
    app=Flask(__name__);app.register_blueprint(api.setup_container_review_api)
    calls=[]
    class Repo:
        def record_review(self,**kw): calls.append(kw);return {'setup_container_review_event_id':1}
    monkeypatch.setattr(api,'require_manager',lambda:(None,'signed-in@example.org',{}))
    monkeypatch.setattr(api,'repo',Repo)
    body=dict(season_year=2026,client_event_id=str(uuid4()),snapshot={'pinned':True},
              email='spoofed@example.org',command=command())
    client=app.test_client()
    assert client.post('/api/setup/container-exceptions/216/review',json=body).status_code==403
    response=client.post('/api/setup/container-exceptions/216/review',json=body,
                         headers={'X-MSB-Setup-Command':'1'})
    assert response.status_code==200
    assert calls[0]['email']=='signed-in@example.org' and calls[0]['snapshot']=={'pinned':True}


def test_live_host_serves_only_review_assets():
    from production_backend import app
    client=app.test_client()
    assert client.get('/container-exceptions/').status_code==200
    assert client.get('/container-exceptions/assets/setup_container_review.js').status_code==200
    assert client.get('/container-exceptions/assets/setup_container_review.py').status_code==404
