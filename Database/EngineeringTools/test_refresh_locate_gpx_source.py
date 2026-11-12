"""#171 verifies current-map rebuild candidates, preserving stable feature IDs."""
import json
from pathlib import Path
import sys

sys.path.insert(0, str(Path(__file__).resolve().parent))
from refresh_locate_gpx_source import rebuild, separate_map


def _gpx(tmp_path, duplicates=False, shift=False, single_vertex_track=False, close_existing=False):
    points = [
        ('PANEL A5-00', '-87.749133', '43.777952', 'Panel'),
        ('A5-07/09', '-87.749302', '43.778226', 'OUT-Combo'),
        ('EXTRA-01', '-87.748800', '43.778800', 'OUT-Combo'),
    ]
    if close_existing:
        points[1] = ('A5-07/09', '-87.749129', '43.777952', 'OUT-Combo')
    if duplicates:
        points[1] = ('A5-07/09', '-87.749133', '43.777952', 'OUT-Combo')
    if shift:
        points[1] = ('A5-07/09', '-87.400000', '43.778226', 'OUT-Combo')
    wp = ''.join(
        f'<wpt lat="{lat}" lon="{lon}"><name>Old Garmin</name><type>{kind}</type>'
        f'<extensions><o:label><o:label_text>{name}</o:label_text></o:label></extensions></wpt>'
        for name, lon, lat, kind in points
    )
    second_lon = '-87.749129' if close_existing else '-87.749302'
    second_lat = '43.777952' if close_existing else '43.778226'
    extra_track = (
        '<trk><name>HV single-vertex 2021</name><type>High Voltage</type>'
        '<trkseg><trkpt lat="43.777952" lon="-87.749133"/></trkseg></trk>'
        if single_vertex_track else ''
    )
    text = (
      '<gpx xmlns="http://www.topografix.com/GPX/1/1" '
      'xmlns:o="http://www.topografix.com/GPX/gpx_overlay/0/5">' + wp +
      '<trk><name>NET corrected</name><type>Network</type>'
      '<trkseg><trkpt lat="43.777952" lon="-87.749133"/>'
      f'<trkpt lat="{second_lat}" lon="{second_lon}"/></trkseg></trk>' +
      extra_track + '</gpx>'
    )
    out = tmp_path / 'input.gpx'
    out.write_text(text, encoding='utf-8')
    return out


def _map(single_vertex_track=False, close_existing=False):
    features = []
    second_coords = [-87.749129,43.777952] if close_existing else [-87.749302,43.778226]
    for idx, (name, coords, kind, icon) in enumerate([
       ('A5-00', [-87.749133, 43.777952], 'Panel', 'panel.png'),
       ('A5-Church', second_coords, 'OUT-Combo', 'outlet.png'),
    ]):
        features.append(dict(type='Feature', geometry=dict(type='Point', coordinates=coords),
                             properties=dict(id=f'w{idx}', name=name, type=kind,
                                             marker_url=icon, sym='old', cmt='', desc='', time='')))
    features.append(dict(type='Feature', geometry=dict(
        type='LineString',
        coordinates=[[-87.749133,43.777952],second_coords]),
        properties=dict(id='t0',name='NET old',type='Network',**{'class':'NET'})))
    if single_vertex_track:
        features.append(dict(type='Feature', geometry=dict(
            type='LineString', coordinates=[[-87.749133, 43.777952]]),
            properties=dict(id='t1',name='HV single-vertex 2021',
                            type='High Voltage',**{'class':'HV'})))
    return ('<html><p>GPX snapshot 743ead74d34767a9</p><div id="network-status"></div><script>const data='
            + json.dumps({'type':'FeatureCollection','features':features})
            + ';data.features.push({"type":"Feature","properties":{"id":"temporary-workshop"}});'
            + '</script></html>')


def test_refreshes_corrected_labels_adds_point_and_preserves_map_ui(tmp_path):
    source = _gpx(tmp_path)
    old = _map()
    fresh, audit = rebuild(old, source)
    assert not audit['conflicts']
    assert audit['counts']['corrected_names'] == 2
    assert audit['counts']['new_waypoints'] == 1
    assert audit['network_status'] == 'STALE_PENDING_CORRECTED_FLW'
    _, _, data = separate_map(fresh)
    by_id = {f['properties']['id']:f for f in data['features']}
    assert by_id['w0']['properties']['name'] == 'PANEL A5-00'
    assert by_id['w1']['properties']['name'] == 'A5-07/09'
    assert by_id['w2']['properties']['name'] == 'EXTRA-01'
    assert by_id['w0']['properties']['marker_url'] == 'panel.png'
    assert by_id['t0']['properties']['name'] == 'NET corrected'
    assert 'temporary-workshop' in fresh
    assert 'id="source-refresh-warning"' in fresh
    assert "GPX snapshot 743ead74d34767a9" not in fresh
    assert "GPX candidate SHA " in fresh
    assert 'LinkIQ network evidence is still the older snapshot' in fresh
    assert old != fresh


def test_rejects_ambiguous_existing_waypoint_geometry(tmp_path):
    fresh, receipt = rebuild(_map(), _gpx(tmp_path, duplicates=True))
    assert fresh is None
    assert receipt['conflicts']


def test_does_not_silently_drop_old_waypoint_without_source(tmp_path):
    fresh, receipt = rebuild(_map(), _gpx(tmp_path, shift=True))
    assert fresh is None
    assert any('Old mapped points' in c['reason'] for c in receipt['conflicts'])


def test_preserves_real_world_single_vertex_gpx_track(tmp_path):
    # The operator's actual GPX and old map both contain single-position
    # historical tracks; these records are not missing waypoint geometry.
    fresh, receipt = rebuild(
        _map(single_vertex_track=True),
        _gpx(tmp_path, single_vertex_track=True))
    assert fresh is not None
    assert not receipt['conflicts']
    _, _, data = separate_map(fresh)
    singleton = next(f for f in data['features']
                     if f['properties']['id'] == 't1')
    assert singleton['geometry']['coordinates'] == [[-87.749133, 43.777952]]


def test_coordinate_identity_precedes_names_for_nearby_points(tmp_path):
    # Two distinct equipment positions only ~1 ft apart: neither old label
    # nor GPX Garmin name can be trusted as the primary identity key.
    fresh, receipt = rebuild(
        _map(close_existing=True), _gpx(tmp_path, close_existing=True))
    assert fresh is not None
    assert not receipt['conflicts']
    assert receipt['counts']['coordinate_matches'] == 2
    ids = {m['feature_id']: m for m in receipt['coordinate_matches']}
    assert ids['w0']['gpx_label'] == 'PANEL A5-00'
    assert ids['w1']['gpx_label'] == 'A5-07/09'
    assert ids['w0']['distance_ft'] == 0
    assert ids['w1']['distance_ft'] == 0
    _, _, data = separate_map(fresh)
    assert {f['properties']['id']:f['properties']['name']
            for f in data['features'] if f['geometry']['type'] == 'Point'
           }['w1'] == 'A5-07/09'
