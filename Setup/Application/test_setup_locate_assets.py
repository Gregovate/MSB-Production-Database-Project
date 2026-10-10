"""Map adapter must not infer state or recover coordinates independently."""
from setup_locate_assets import geographic_position, locate_assets


def test_location_rejects_storage_missing_and_nonfinite():
    assert geographic_position({'gps_latitude': 43, 'gps_longitude': -87}) == [43, -87]
    for event in ({}, {'gps_latitude': 43}, {'gps_latitude': 'nan', 'gps_longitude': -87},
                  {'gps_latitude': 43, 'gps_longitude': -87, 'event_type': 'RETURNED'}):
        assert geographic_position(event) is None


def test_adapter_uses_state_event_and_does_not_infer_load_or_duplicate_attached_displays():
    picture = dict(generated_at=None, through_event_id=2,
                   effect_rows=[dict(setup_movement_event_id=1, gps_latitude=43, gps_longitude=-87),
                                dict(setup_movement_event_id=2, event_type='CONTAINER_MOVE')],
                   containers=[dict(container_id=95, container_name='Test', last_movement_event_id=2)],
                   displays=[dict(display_id=1, display_name='Attached', container_id=95, position_mode='WITH_CONTAINER'),
                             dict(display_id=2, display_name='Independent', container_id=95, position_mode='DETACHED', last_movement_event_id=1)])
    result = locate_assets(picture)
    assert result['containers'][0]['position'] is None
    assert result['containers'][0]['load_state'] == 'PARTIAL'
    assert result['containers'][0]['physical_load_confirmed'] is False
    assert len(result['containers'][0]['contents']) == 2
    assert [d['name'] for d in result['displays']] == ['Independent']
    assert result['displays'][0]['position'] == [43, -87]


def test_map_endpoint_authentication_validation_and_no_store(monkeypatch):
    import setup_movement_api as api
    import setup_production_report as report
    from production_backend import app
    from setup_api import SetupCommandError
    def deny():
        raise SetupCommandError("denied")
    monkeypatch.setattr(api, 'require_reader', deny)
    monkeypatch.setattr(api, 'repo', lambda: (_ for _ in ()).throw(AssertionError('unauthorized read')))
    client = app.test_client()
    assert client.get('/api/setup/locate/assets?season_year=2026').status_code == 403
    class Base:
        def movement_summary(self, year):
            assert year == 2026
            return {'setup_session_id': 1}
    monkeypatch.setattr(api, 'require_reader', lambda: (Base(), 'reader', {}))
    assert client.get('/api/setup/locate/assets?season_year=bad').status_code == 403
    monkeypatch.setattr(api, 'repo', lambda: object())
    picture = dict(generated_at=None, through_event_id=0, effect_rows=[], containers=[], displays=[])
    monkeypatch.setattr(report, 'movement_picture', lambda repo, sid, **kwargs: picture)
    response = client.get('/api/setup/locate/assets?season_year=2026')
    assert response.status_code == 200
    assert 'no-store' in response.headers['Cache-Control']
    assert response.json['containers'] == []
    assert client.post('/api/setup/locate/assets').status_code == 405
    assert client.get('/locate/assets/container-unknown.svg').status_code == 200
    assert client.get('/locate/assets/production_backend.py').status_code == 404


def test_locate_canonical_slash_loads_actual_overlay_script():
    import re
    from urllib.parse import urljoin
    from production_backend import app
    client = app.test_client()
    response = client.get('/locate')
    assert response.status_code == 308
    assert response.headers['Location'] == '/locate/'
    page = client.get('/locate', follow_redirects=True)
    source = page.get_data(as_text=True)
    path = re.findall(r'<script src="([^"]+)"', source)[-1]
    resolved = urljoin(response.headers['Location'], path)
    script = client.get(resolved)
    assert script.status_code == 200
    assert 'javascript' in script.content_type
    assert 'Physical loads unconfirmed' in script.get_data(as_text=True)
    assert 'Loading assets…' in source


def test_locate_allows_close_inspection_without_requesting_nonexistent_tiles():
    from pathlib import Path
    source = Path(__file__).with_name('locate_preview.html').read_text()
    assert "zoomControl:true,maxZoom:24" in source
    assert 'maxZoom:24,maxNativeZoom:21' in source


def test_recorded_contents_classification():
    for modes, expected in [([], 'UNKNOWN'), (['WITH_CONTAINER'], 'LOADED'),
                            (['DETACHED'] * 16, 'EMPTY'),
                            (['WITH_CONTAINER', 'DETACHED'], 'PARTIAL'),
                            (['WITH_CONTAINER', 'NO_ASSIGNED_CONTAINER'], 'UNKNOWN')]:
        result = locate_assets(dict(generated_at=None, through_event_id=113,
            effect_rows=[], containers=[dict(container_id=1)],
            displays=[dict(display_id=i, display_name=str(i), container_id=1,
                           position_mode=mode) for i, mode in enumerate(modes)]))
        assert result['containers'][0]['load_state'] == expected
        assert result['containers'][0]['physical_load_confirmed'] is False


def test_display_artwork_above_container_preserves_gps():
    from pathlib import Path
    source = Path(__file__).with_name('setup_locate_assets.js').read_text()
    assert 'L.marker(a.position' in source
    assert 'iconAnchor: container ? [16,16] : [16,48]' in source
    assert 'zIndexOffset: container ? 0 : 1000' in source


def test_search_is_served_before_asset_overlay():
    from production_backend import app
    client = app.test_client()
    page = client.get('/locate/').get_data(as_text=True)
    assert 'id="map-search"' in page
    assert page.index('src="assets/setup_locate_search.js"') < page.index('src="assets/setup_locate_assets.js"')
    assert client.get('/locate/assets/setup_locate_search.js').status_code == 200


def test_unobserved_container_has_expected_workshop_without_fabricated_gps():
    result = locate_assets(dict(generated_at=None, through_event_id=0,
        effect_rows=[], containers=[dict(container_id=1)], displays=[]))
    assert result['containers'][0]['expected_location'] == 'Workshop'
    assert result['containers'][0]['position'] is None


def test_reported_return_home_overrides_loaded_associations():
    result = locate_assets(dict(generated_at=None, through_event_id=2,
        effect_rows=[dict(setup_movement_event_id=2, event_type='RETURNED', gps_latitude=43, gps_longitude=-87)],
        containers=[dict(container_id=1, last_movement_event_id=2, movement_status='RETURNED', home_location_code='RC05-A-01')],
        displays=[dict(display_id=1, display_name='Arch', container_id=1, position_mode='WITH_CONTAINER')]))
    container = result['containers'][0]
    assert container['reported_home'] is True
    assert container['load_state'] == 'EMPTY'
    assert container['home_location_code'] == 'RC05-A-01'
    from setup_locate_assets import WORKSHOP_POSITION
    assert container['position'] == WORKSHOP_POSITION


def test_confirmed_round_trip_preserves_detached_park_locations():
    """C046/C050 Production evidence: empty Home returns must not move displays."""
    from setup_locate_assets import WORKSHOP_POSITION
    import json
    from pathlib import Path
    root = Path(__file__).resolve().parents[2]
    canonical = json.loads((root / 'Docs/02_Production_Database/01_System_Architecture/11_Site_Infrastructure_GIS/workshop_reference.json').read_text())
    bundled = json.loads(Path(__file__).with_name('setup_workshop_reference.json').read_text())
    assert canonical == bundled
    assert 43.778 < WORKSHOP_POSITION[0] < 43.779
    assert -87.734 < WORKSHOP_POSITION[1] < -87.733
    picture = dict(generated_at=None, through_event_id=188, containers=[], displays=[], effect_rows=[])
    for cid, drop, returned, lat, lon, rack in [(46,116,186,43.776757,-87.745766,'RA09-B-01'), (50,114,188,43.776652,-87.745525,'RA10-C-01')]:
        picture['effect_rows'].extend([
            dict(setup_movement_event_id=drop,event_type='CONTAINER_MOVE',gps_latitude=lat,gps_longitude=lon),
            dict(setup_movement_event_id=returned,event_type='RETURNED')])
        picture['containers'].append(dict(container_id=cid,last_movement_event_id=returned,movement_status='RETURNED',home_location_code=rack))
        for i in range(16):
            picture['displays'].append(dict(display_id=cid*100+i,display_name=f'Wrap {cid}-{i}',container_id=cid,position_mode='DETACHED',last_movement_event_id=drop))
    result = locate_assets(picture)
    for c in result['containers']:
        assert c['position'] == WORKSHOP_POSITION
        assert c['position_source'] == 'storage-workshop-reference'
        assert c['observation']['gps_latitude'] is None
        assert c['load_state'] == 'EMPTY'
    assert len(result['displays']) == 32
    assert all(d['position'] == [43.776757,-87.745766] for d in result['displays'][:16])
    assert all(d['position'] == [43.776652,-87.745525] for d in result['displays'][16:])
