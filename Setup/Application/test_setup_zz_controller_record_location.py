"""Controller observations share Setup command guards without Display side effects."""
from types import SimpleNamespace
from pathlib import Path

def test_controller_command_guard_and_routing(monkeypatch):
    import setup_movement_api as api
    from production_backend import app
    calls=[]
    monkeypatch.setattr(api,'require_movement_operator',lambda:(None,'crew@example.org',{'authenticated_email':'crew@example.org'}))
    monkeypatch.setattr(api,'repo',lambda:SimpleNamespace(record_event=lambda **kw:(calls.append(kw) or {'asset_type':kw['asset_type']})))
    client=app.test_client()
    payload=dict(season_year=2026,client_event_id='88000000-0000-4000-8000-000000001001',asset_type='CONTROLLER',asset_id=1001,
                 movement_action='CONTROLLER_MOVE',occurred_at='2026-10-26T14:00:00Z',destination_location_note='Park arrival')
    assert client.post('/api/setup/movements',json=payload).status_code==403
    headers={'X-MSB-Setup-Command':'1'}
    result=client.post('/api/setup/movements',headers=headers,json=payload)
    assert result.status_code==201
    assert calls[-1]['asset_type']=='CONTROLLER'
    assert calls[-1]['movement_action']=='CONTROLLER_MOVE'
    assert not calls[-1]['reconciliation']
    for changes in [dict(asset_type='DISPLAY'),dict(movement_action='DISPLAY_MOVE'),dict(movement_action='PICKED'),dict(reconciliation={'decision':'EMPTY'})]:
        assert client.post('/api/setup/movements',headers=headers,json=payload|changes).status_code==403
    assert len(calls)==1

def test_existing_scan_destination_exposes_explicit_location_action():
    root=Path(__file__).resolve().parents[2]
    scan=(root/'Scan/directus-extension-scan/src/index.js').read_text()
    client=(root/'FieldWiring/Application/controllers.js').read_text()
    assert '/fieldwiring/controllers?controller_id=' in scan
    assert "'/setup/record-location/?asset=CTRL:'" in client
    assert "locationAction.textContent='Record Location'" in client
