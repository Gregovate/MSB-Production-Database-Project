"""PDF reports include wrong-state unchanged targets and preserve observation history."""
from copy import deepcopy
from datetime import datetime
from unittest.mock import MagicMock
import sys
from pathlib import Path
import pytest
sys.path.insert(0, str(Path(__file__).resolve().parent))
from breaker_report import report_rows, build_pdf
import backend
import power_capture
from repository import PostgresRepository


def snapshot():
    return dict(revision=17,seasons=[2026,2025],panels=[dict(site_panel_id=1,panel_name='Panel FE-00',active=True)],
      breakers=[dict(site_panel_id=1,site_power_breaker_id=1,breaker_name='1/3',show_desired_state='ON',restoration_desired_state='ON',active=True,source_evidence='Gate & lights <observed>')],
      circuits=[dict(site_power_breaker_id=1,active=True,description='Local receptacle')],
      events=[dict(event_id=1,event_kind='REPORTED',condition='OFF',season_year=2026,observed_at='2026-10-25T12:00:00Z',operator_name='Greg Liebig',operator_email='private@example.test',definition_snapshot=dict(site_power_breaker_id=1,phase='SETUP'))])


def test_unchanged_target_wrong_state_and_unknown_are_exceptions():
    data=snapshot(); before=deepcopy(data)
    row=report_rows(data,2026,'SETUP')[0]
    assert row['status']=='Wrong state'
    assert row['person']=='Greg Liebig'
    assert 'Local receptacle' in row['description']
    assert data==before
    data['events']=[]
    assert report_rows(data,2026,'SETUP')[0]['status']=='No recorded state'


@pytest.mark.parametrize('condition,year,phase,status',[
 ('ON',2026,'SETUP','Completed'),('ON',2025,'SETUP','Not recorded for this season'),
 ('ON',2026,'RESTORATION','Not recorded for this season mode'),('UNKNOWN',2026,'SETUP','No recorded state')])
def test_current_season_and_mode_required(condition,year,phase,status):
    data=snapshot();data['events'][0].update(condition=condition,season_year=year)
    data['events'][0]['definition_snapshot']['phase']=phase
    assert report_rows(data,2026,'SETUP')[0]['status']==status


def test_correction_supersedes_state_and_inactive_inventory_omitted():
    data=snapshot(); e=deepcopy(data['events'][0]);e.update(event_id=2,condition='UNKNOWN',corrects_event_id=1);data['events'].append(e)
    assert report_rows(data,2026,'SETUP')[0]['status']=='No recorded state'
    data['breakers'][0]['active']=False
    assert report_rows(data,2026,'SETUP')==[]


@pytest.mark.parametrize('view',['all','exceptions','completed'])
def test_real_pdf_with_escaped_notes_and_empty_views(view):
    pdf=build_pdf(snapshot(),2026,'SETUP',view)
    assert pdf.startswith(b'%PDF-') and pdf.rstrip().endswith(b'%%EOF')


def test_pdf_endpoint_is_authenticated_read_only_and_downloadable(monkeypatch):
    conn=MagicMock();cur=conn.cursor.return_value.__enter__.return_value;cur.fetchone.return_value=(snapshot(),)
    monkeypatch.setattr(power_capture.psycopg2,'connect',lambda _:conn)
    monkeypatch.setattr(backend,'repository',lambda:PostgresRepository('fixture-only'))
    client=backend.app.test_client()
    assert client.get('/api/power/report.pdf?season=2026').status_code==401
    response=client.get('/api/power/report.pdf?season=2026&view=exceptions',headers={'Cf-Access-Authenticated-User-Email':'crew@example.test'})
    assert response.status_code==200 and response.mimetype=='application/pdf'
    assert 'attachment;' in response.headers['Content-Disposition']
    assert response.headers['Cache-Control']=='no-store'
    conn.set_session.assert_called_once_with(readonly=True)
    cur.execute.assert_called_once_with('SELECT ref.site_power_snapshot(%s)',('crew@example.test',))
    conn.commit.assert_not_called()
    assert client.get('/api/power/report.pdf?season=2026&phase=bogus',headers={'Cf-Access-Authenticated-User-Email':'crew@example.test'}).status_code==400
