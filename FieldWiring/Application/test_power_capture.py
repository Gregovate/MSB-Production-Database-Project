"""Exercise transport guards, transaction atomicity, attribution and failed saves."""
import sys
from pathlib import Path
from unittest.mock import MagicMock
import pytest
sys.path.insert(0, str(Path(__file__).resolve().parent))
import backend
import power_capture
from repository import PostgresRepository

HEADERS={'Cf-Access-Authenticated-User-Email':'Crew@Example.test','X-MSB-Power-Command':'1'}

def command():
    return {'request_id':'00000000-0000-0000-0000-000000000001','kind':'panel','id':None,'fields':{'panel_name':'A'}}

@pytest.fixture
def db(monkeypatch):
    conn=MagicMock();cursor=conn.cursor.return_value.__enter__.return_value
    cursor.fetchone.return_value=({'revision':2,'target_id':1},)
    monkeypatch.setattr(power_capture.psycopg2,'connect',lambda _:conn)
    monkeypatch.setattr(backend,'repository',lambda:PostgresRepository('fixture-only'))
    return conn,cursor

def test_missing_identity_denied_before_db():
    assert backend.app.test_client().post('/api/power/commands',json={}).status_code==401

@pytest.mark.parametrize('body', [None,[],{}, {'revision':True,'commands':[command()]}, {'revision':0,'commands':[]}, {'revision':0,'commands':[dict(command(),actor='spoof')]}])
def test_malformed_batch_denied(body,db):
    r=backend.app.test_client().post('/api/power/commands',json=body,headers=HEADERS)
    assert r.status_code in (400,403)
    db[1].execute.assert_not_called()

def test_simple_cross_origin_shape_denied(db):
    r=backend.app.test_client().post('/api/power/commands',json={'revision':0,'commands':[command()]},headers={'Cf-Access-Authenticated-User-Email':'crew@example.test'})
    assert r.status_code==403
    db[1].execute.assert_not_called()

def test_batch_commits_once_and_uses_header_actor(db):
    conn,cur=db;cur.fetchone.side_effect=[({'revision':2,'target_id':1},),({'revision':3,'target_id':2},)]
    r=backend.app.test_client().post('/api/power/commands',json={'revision':1,'commands':[command(),command()]},headers=HEADERS)
    assert r.status_code==200
    assert [c.args[1][2] for c in cur.execute.call_args_list]==[1,2]
    assert all(c.args[1][0]=='crew@example.test' for c in cur.execute.call_args_list)
    conn.commit.assert_called_once();conn.close.assert_called_once()
    assert r.headers['Cache-Control']=='no-store'

def test_second_command_failure_rolls_back_whole_batch(db):
    conn,cur=db;cur.execute.side_effect=[None,RuntimeError('fixture failure')]
    r=backend.app.test_client().post('/api/power/commands',json={'revision':1,'commands':[command(),command()]},headers=HEADERS)
    assert r.status_code==500
    conn.rollback.assert_called_once();conn.commit.assert_not_called();conn.close.assert_called_once()

def test_snapshot_uses_read_only_transaction(db):
    conn,cur=db;cur.fetchone.return_value=({'revision':0},)
    r=backend.app.test_client().get('/api/power',headers=HEADERS)
    assert r.status_code==200
    conn.set_session.assert_called_once_with(readonly=True)
    assert cur.execute.call_args.args[1]==('crew@example.test',)
