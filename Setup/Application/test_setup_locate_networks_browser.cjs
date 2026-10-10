// Exercise both shipped scripts against the actual source snapshot and a small DOM/Leaflet harness.
const fs = require('fs'), vm = require('vm'), assert = require('assert'), path = require('path');
const read = name => fs.readFileSync(path.join(__dirname, name), 'utf8');
function element() {
  return {children: [], style: {}, value: '', parentElement: {open: false},
    appendChild(x) { this.children.push(x); }, replaceChildren() { this.children = []; },
    addEventListener(type, fn) { this[type] = fn; }};
}
const ids = ['map-search', 'map-search-results', 'map-search-status', 'network-status', 'network-details', 'network-options', 'network-clear'];
const elements = Object.fromEntries(ids.map(id => [id, element()]));
const source = JSON.parse(read('setup_locate_networks.json'));
const page = read('locate_preview.html');
const data = JSON.parse(page.match(/const data=(.*?);data.features.push/s)[1]);
// Execute the actual inline entry defaults for both navigation paths.
const profileCode = page.match(/const mapView=.*?group\.addTo\(map\);/)[0];
for (const [query, expected] of [
  ['', ['stages','containers','displays','drops']],
  ['?view=setup', ['stages','containers','displays','drops']],
  ['?view=fieldwiring', ['stages','HV','PRI','refs']],
  ['?view=unknown', ['stages','containers','displays','drops']],
]) {
  const visible = [];
  vm.runInNewContext(profileCode, {URLSearchParams, window:{location:{search:query}}, map:{},
    layers:Object.fromEntries(['stages','containers','displays','drops','HV','PRI','refs','NET','Other']
      .map(name=>[name,{addTo(){visible.push(name);}}]))});
  assert.deepEqual(visible.sort(), expected.sort(), `Initial layers for ${query || 'Setup default'}`);
}
assert(page.includes('el.checked=initialLayers.has(el.dataset.layer)'), 'Checkboxes reflect the entry defaults');
const markers = data.features.filter(f => ['LineString','MultiLineString'].includes(f.geometry.type)).flatMap(feature => [0,1].map(i => ({
  _searchFeature: feature, options: {color: 'blue', weight: 3, opacity: .85, dashArray: null},
  getBounds() { return `${feature.properties.id}:${i}`; },
  setStyle(style) { Object.assign(this.options, style); }, openPopup() {}, bringToFront() {}
})));
const toggle = {...element(), checked: false};
let selectionBounds;
const context = {document: {getElementById: id => elements[id], createElement: element, querySelector: () => toggle},
  fetch: async () => ({ok: true, json: async () => source}),
  layers: Object.fromEntries(['NET','HV','PRI','Other'].map(name => [name, {eachLayer(fn) { markers.filter(m => m._searchFeature.properties.class === name).forEach(fn); }, addTo() {}}])),
  map: {fitBounds(bounds) { selectionBounds = bounds.items; }, closePopup() {}},
  L: {latLngBounds: () => ({items: [], extend(item) { this.items.push(item); }})}};
vm.createContext(context);
vm.runInContext(read('setup_locate_search.js') + '\nglobalThis.search = mapSearch;', context);
function search(query) { elements['map-search'].value = query; elements['map-search'].input(); return elements['map-search-results'].children; }
(async () => {
  await vm.runInContext(read('setup_locate_networks.js'), context);
  context.search.addAsset({container_id:112,name:'Flammables Cabinets',contents:[],expected_location:'Workshop'}, true, null);
  for (const query of ['AUX-I','Aux I','aux-i']) {
    const results = search(query);
    assert.equal(results.length, 1, 'Exact network must not compete with raw GPX labels');
    assert.match(results[0].textContent, /AUX-I.*13 candidate routes/);
  }
  search('AUX-I')[0].click();
  elements['map-search'].value = ''; elements['map-search'].input();
  assert.equal(elements['network-details'].children.length, 0, 'Clearing search removes stale evidence');
  assert.equal(elements['network-details'].parentElement.open, false);
  assert.equal(elements['map-search-results'].children.length, 0);
  assert.equal(elements['map-search-status'].textContent, '');
  assert(markers.every(m => m.options.color === 'blue'), 'Clearing search restores track styles');
  assert(elements['network-options'].children.every(label => !label.children[0].checked));
  const before = markers.map(m => m.options.color);
  search('INET'); assert.deepEqual(markers.map(m => m.options.color), before, 'Typing does not change the map');
  const inet = search('INET'); assert.equal(inet.length, 1, 'INET must not match Cabinets');
  inet[0].click(); assert.equal(selectionBounds.length, 60, 'Highlight all segments of all 30 INET candidates');
  search('AUX-I')[0].click(); assert.equal(selectionBounds.length, 26, 'Highlight all 13 AUX-I candidates');
  const highlighted = markers.filter(m => m.options.color === '#ff00d4');
  assert(highlighted.some(m => m._searchFeature.properties.id === 't77'));
  assert(highlighted.some(m => m._searchFeature.properties.id === 't79'));
  assert(highlighted.some(m => m._searchFeature.properties.id === 't80'));
  assert(highlighted.some(m => m._searchFeature.properties.id === 't131'), 'LinkIQ resolves WV-00/WV-03 despite schematic error');
  assert(highlighted.every(m => !m.options.dashArray), 'Shared geometry does not prove historical alternatives');
  const detailText = elements['network-details'].children.flatMap(x => [x.textContent, ...(x.children || []).map(y=>y.textContent)]).join(' ');
  assert.match(detailText, /ENDPOINT_CONFLICT/); assert.match(detailText, /Tester length/);
  assert.equal(elements['network-details'].parentElement.open, true);
  const raw = search('NET CC to A4'); assert(raw.length >= 1);
  assert.match(raw[0].textContent, /GPX route \(source name\)/);
  raw[0].click(); assert.equal(elements['network-details'].children.length, 0, 'Raw selection must clear stale network details');
  assert.equal(elements['network-details'].parentElement.open, false);
  context.search.focusContainer(112);
  assert.match(elements['map-search-status'].textContent, /Workshop/);
  context.search.focusContainer(9999);
  assert.match(elements['map-search-status'].textContent, /not in this season/);
  context.search.clearAssets();
  markers.forEach(m => {assert.equal(m.options.color, 'blue'); assert.equal(m.options.dashArray, null);});
  // The expandable checklist selects multiple networks without any search text.
  const controls = new Map(elements['network-options'].children.map(label => [label.children[0].value, label.children[0]]));
  assert.equal(controls.size, new Set(source.cables.map(c => c.network)).size);
  function check(name, checked) { const control = controls.get(name); control.checked = checked; control.change(); }
  const routeIds = name => new Set(source.cables.filter(c => c.network === name).flatMap(c => c.route_ids));
  const activeIds = () => new Set(markers.filter(m => m.options.color === '#ff00d4').map(m => m._searchFeature.properties.id));
  elements['map-search'].value = '';
  check('AUX-I', true); check('INET', true);
  assert.deepEqual(activeIds(), new Set([...routeIds('AUX-I'), ...routeIds('INET')]));
  assert(controls.get('AUX-I').checked && controls.get('INET').checked);
  check('AUX-I', false);
  assert.deepEqual(activeIds(), routeIds('INET'), 'Removing one network preserves shared tracks used by another');
  elements['network-clear'].click();
  assert.equal(activeIds().size, 0);
  assert([...controls.values()].every(c => !c.checked));
  const unresolved = [...controls.keys()].find(name => !routeIds(name).size);
  assert(unresolved, 'Snapshot includes networks without geographic matches');
  check(unresolved, true);
  assert.equal(activeIds().size, 0);
  assert(elements['network-details'].children.length > 0, 'Unmatched networks still expose test evidence');
  search('INET')[0].click();
  assert(controls.get('INET').checked && !controls.get(unresolved).checked, 'Search synchronizes checklist');
  toggle.checked = false; toggle.change();
  assert.equal(activeIds().size, 0, 'Parent off restores all highlighted source tracks');
  assert([...controls.values()].every(c => !c.checked));
  assert(page.includes('<details id="network-picker"><summary>'), 'Network list has native keyboard-accessible disclosure');
  assert(page.includes('V0.3.58-gis-v1 · Updated 2026-10-10'));
  const styles = vm.runInNewContext('(' + page.match(/const trackStyles=(.*?);/)[1] + ')');
  assert.equal(styles.PRI.color, '#ff8b25');
  assert.equal(styles.HV.color, '#dd2424');
  assert.equal(styles.PRI.weight, 0.037 * 96);
  assert.equal(styles.HV.weight, 0.025 * 96);
  assert(page.includes('{...trackStyles[cls],opacity:.85}'), 'Rendered polylines use QGIS widths');
  // The real selection code must restore the distinct QGIS base styles.
  for (const marker of markers) Object.assign(marker.options, styles[marker._searchFeature.properties.class]);
  search('INET')[0].click();
  elements['map-search'].value = ''; elements['map-search'].input();
  for (const marker of markers) {
    const expected = styles[marker._searchFeature.properties.class];
    assert.equal(marker.options.color, expected.color);
    assert.equal(marker.options.weight, expected.weight);
  }
  context.fetch = async () => ({ok:false,status:503});
  await vm.runInContext(read('setup_locate_networks.js'), context);
  assert.match(elements['network-status'].textContent, /unavailable/);
  console.log('PASS: actual network search, multi-network checklist, shared tracks, clear/parent-off, unresolved evidence and failure behavior');
})().catch(error => { console.error(error); process.exitCode = 1; });
