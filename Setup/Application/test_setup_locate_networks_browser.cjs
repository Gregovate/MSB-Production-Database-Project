// Exercise both shipped scripts against the actual source snapshot and a small DOM/Leaflet harness.
const fs = require('fs'), vm = require('vm'), assert = require('assert'), path = require('path');
const read = name => fs.readFileSync(path.join(__dirname, name), 'utf8');
function element() {
  return {children: [], style: {}, value: '', parentElement: {open: false},
    appendChild(x) { this.children.push(x); }, replaceChildren() { this.children = []; },
    addEventListener(type, fn) { this[type] = fn; }};
}
const ids = ['map-search', 'map-search-results', 'map-search-status', 'network-status', 'network-details'];
const elements = Object.fromEntries(ids.map(id => [id, element()]));
const source = JSON.parse(read('setup_locate_networks.json'));
const page = read('locate_preview.html');
const data = JSON.parse(page.match(/const data=(.*?);data.features.push/s)[1]);
const markers = data.features.filter(f => ['LineString','MultiLineString'].includes(f.geometry.type)).flatMap(feature => [0,1].map(i => ({
  _searchFeature: feature, options: {color: 'blue', weight: 3, opacity: .85, dashArray: null},
  getBounds() { return `${feature.properties.id}:${i}`; },
  setStyle(style) { Object.assign(this.options, style); }, openPopup() {}, bringToFront() {}
})));
const toggle = {checked: false};
let selectionBounds;
const context = {document: {getElementById: id => elements[id], createElement: element, querySelector: () => toggle},
  fetch: async () => ({ok: true, json: async () => source}),
  layers: {NET: {eachLayer(fn) { markers.forEach(fn); }, addTo() {}}},
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
  context.fetch = async () => ({ok:false,status:503});
  await vm.runInContext(read('setup_locate_networks.js'), context);
  assert.match(elements['network-status'].textContent, /unavailable/);
  console.log('PASS: actual network search, grouping, alternatives, stale-details cleanup and failure behavior');
})().catch(error => { console.error(error); process.exitCode = 1; });
