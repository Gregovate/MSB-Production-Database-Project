"""Exercise source reconciliation and shared map selection without a database write."""
import importlib.util
import json
import re
import shutil
import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
APP = Path(__file__).parent
spec = importlib.util.spec_from_file_location('reconcile', ROOT / 'Database/EngineeringTools/reconcile_drawio_map.py')
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)


def test_endpoint_matching_excludes_conflicts_and_description_networks(tmp_path):
    drawio = tmp_path / 'fixture.drawio'
    drawio.write_text('''<mxfile><diagram><mxGraphModel><root>
      <object id="good" Cable_ID="WV-03 to WV-05 Aux I" Network="Aux I" Waypoint_1="WV-03" Waypoint_2="WV-05"><mxCell edge="1"/></object>
      <object id="bad" Cable_ID="WV-03 to WV-05 AUX-I" Network="AUX-I" Waypoint_1="WV-03" Waypoint_2="WV-07"><mxCell edge="1"/></object>
      <mxCell id="legacy" edge="1" value="Aux I"/>
    </root></mxGraphModel></diagram></mxfile>''')
    features = [{'properties': {'class': 'NET', 'id': 't1', 'name': 'NET WV-05 to WV-03', 'desc': 'Aux-Z'}},
                {'properties': {'class': 'NET', 'id': 't2', 'name': 'NET unknown', 'desc': 'Aux I'}}]
    page = tmp_path / 'map.html'
    page.write_text('const data=' + json.dumps({'features': features}) + ';data.features.push')
    result = module.build(drawio, page)
    assert result['cables'][0]['network'] == 'AUX-I'
    assert result['cables'][0]['route_ids'] == ['t1']
    assert result['cables'][1]['status'] == 'ENDPOINT_CONFLICT'
    assert result['cables'][1]['route_ids'] == []
    assert result['unresolved_routes'][0]['route_id'] == 't2'
    assert result['legacy_edges'][0]['source_id'] == 'legacy'
    assert module.network_key('AuxB') != module.network_key('Aux-B')
    assert module.endpoint_key('GG-10') == 'GG-11'


def test_source_snapshot_routes_and_authored_map_geometry_remain_consistent():
    source = json.loads((APP / 'setup_locate_networks.json').read_text())
    data = json.loads(re.search(r'const data=(.*?);data.features.push', (APP / 'locate_preview.html').read_text()).group(1))
    routes = {f['properties']['id'] for f in data['features'] if f.get('geometry', {}).get('type') in ('LineString', 'MultiLineString')}
    matched = {r['route_id'] for r in source['mapped_routes']}
    unresolved = {r['route_id'] for r in source['unresolved_routes']}
    assert matched.isdisjoint(unresolved)
    assert matched | unresolved == routes
    assert len(source['cables']) == 445
    assert len(source['review_records']) == 25
    assert len(source['devices']) == 84
    assert source['source_kind'] == 'LinkIQ'
    assert len(source['legacy_edges']) == 73
    assert all(set(c['route_ids']) <= matched for c in source['cables'])
    from production_backend import app
    client = app.test_client()
    for name in ['setup_locate_networks.json', 'setup_locate_networks.js']:
        response = client.get('/locate/assets/' + name)
        assert response.status_code == 200
        assert 'no-store' in response.headers['Cache-Control']
    assert client.post('/locate/assets/setup_locate_networks.json').status_code == 405


def test_network_selection_highlights_multiple_features_and_restores_styles():
    import pytest
    if not shutil.which('node'):
        pytest.skip('Node unavailable; run JavaScript fixture on candidate workstation')
    fixture = r'''
const fs = require('fs'), vm = require('vm'), assert = require('assert');
function el() { return {children: [], value: '', style: {}, textContent: '', addEventListener(t, fn) { this[t] = fn; }, appendChild(x) { this.children.push(x); }, replaceChildren() { this.children = []; }}; }
const elements = Object.fromEntries(['map-search','map-search-results','map-search-status'].map(k => [k, el()]));
const toggle = {checked: false};
const document = {getElementById: id => elements[id], createElement: el, querySelector: () => toggle};
function marker(id) { return {_searchFeature: {properties: {id, name: id, type: 'Network'}}, options: {color: 'blue', weight: 3, opacity: .85}, getBounds: () => id, setStyle(s) { Object.assign(this.options, s); }, openPopup() {}, bringToFront() {}}; }
const a = marker('t1'), b = marker('t2'), c = marker('t2');
const layers = {NET: {eachLayer(fn) { [a,b,c].forEach(fn); }, addTo() {}}};
const context = {document, layers, map: {fitBounds() {}}, L: {latLngBounds: () => ({extend() {}})}};
vm.createContext(context);
vm.runInContext(fs.readFileSync(process.argv[1], 'utf8') + '\n globalThis.search = mapSearch;', context);
let selected = 0;
context.search.addReference({name: 'AUX-I', terms: 'Aux I AUX-I', kind: 'Network', layer: 'NET', markers: [a,b,c], onSelect() {selected++;}});
elements['map-search'].value = 'Aux I'; elements['map-search'].input();
assert.equal(selected, 0); assert.equal(a.options.color, 'blue');
elements['map-search-results'].children[0].click();
assert.equal(selected, 1); assert.equal(toggle.checked, true);
[a,b,c].forEach(m => assert.equal(m.options.color, '#ff00d4'));
context.search.select({name:'t1', layer:'NET', markers:[a]});
assert.equal(b.options.color, 'blue'); assert.equal(c.options.weight, 3);
context.search.clearAssets(); assert.equal(a.options.color, 'blue');
context.search.select({name:'Unmapped', markers:[], association:'review required', onSelect() {selected++;}});
assert.match(elements['map-search-status'].textContent, /No matched map route/);
'''
    subprocess.run(['node', '-e', fixture, str(APP / 'setup_locate_search.js')], check=True, capture_output=True, text=True)


def test_geometry_requires_complete_source_chain_and_nearby_named_waypoints():
    def feature(coords):
        return {'geometry': {'type': 'LineString', 'coordinates': coords},
                'properties': {'name': 'Historical wrong name', 'desc': 'Aux-I'}}
    coords = [[-87.0, 43.78], [-86.9998, 43.78], [-86.9996, 43.78]]
    points = {key: {'id': key, 'xy': module.local_xy(xy)} for key, xy in zip(['A','B','C'], coords)}
    records = [{'source_id': 'ab', 'network': 'INET', 'endpoints': ['A','B'], 'status': 'NO_MATCHED_ROUTE'},
               {'source_id': 'bc', 'network': 'INET', 'endpoints': ['B','C'], 'status': 'NO_MATCHED_ROUTE'}]
    matched = module.geometry_matches(feature(coords), points, records)
    assert matched['INET'][0]['waypoint_path'] == ['A','B','C']
    assert matched['INET'][0]['cable_source_ids'] == ['ab','bc']
    assert 'AUX-I' not in matched  # GPX narrative does not assign a network.
    assert not module.geometry_matches(feature(coords), points, records[:1])
    records[1]['status'] = 'ENDPOINT_CONFLICT'
    assert not module.geometry_matches(feature(coords), points, records)
    records[1]['status'] = 'NO_MATCHED_ROUTE'
    points['B']['xy'] = module.local_xy([-86.9998, 43.781])
    assert not module.geometry_matches(feature(coords), points, records)


def test_multisegment_route_cannot_highlight_unsupported_segment():
    coords = [[-87.0,43.78],[-86.9998,43.78],[-86.9996,43.78]]
    points = {key: {'id': key, 'xy': module.local_xy(xy)} for key, xy in zip(['A','B','C'], coords)}
    records = [{'source_id':'ab','network':'INET','endpoints':['A','B'],'status':'NO_MATCHED_ROUTE'}]
    feature = {'geometry': {'type':'MultiLineString','coordinates':[coords[:2],coords[1:]]}}
    assert not module.geometry_matches(feature, points, records)


def test_actual_network_scripts_search_and_highlight_source_candidates():
    import pytest
    if not shutil.which('node'):
        pytest.skip('Node unavailable; candidate CI executes this JavaScript fixture')
    subprocess.run(['node', str(APP / 'test_setup_locate_networks_browser.cjs')], check=True, capture_output=True, text=True)
