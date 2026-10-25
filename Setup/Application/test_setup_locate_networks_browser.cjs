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
  ['?view=fieldwiring', ['stages','HV','PRI','refs','NET']],
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
const context = {window:{siteReferenceReady:null}, document: {getElementById: id => elements[id], createElement: element, querySelector: () => toggle},
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
    const expected = new Set(source.cables.filter(c => c.network === 'AUX-I').flatMap(c => c.route_ids)).size;
    assert.match(results[0].textContent, new RegExp(`AUX-I.*${expected} candidate routes`));
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
  inet[0].click();
  assert.equal(selectionBounds.length, 2 * new Set(source.cables.filter(c => c.network === 'INET').flatMap(c => c.route_ids)).size, 'Highlight source-backed INET candidates');
  search('AUX-I')[0].click();
  const expectedAuxIds = new Set(source.cables.filter(c => c.network === 'AUX-I').flatMap(c => c.route_ids));
  assert.equal(selectionBounds.length, 2 * expectedAuxIds.size, 'Highlight source-backed AUX-I candidates');
  const highlighted = markers.filter(m => m.options.color === '#ff00d4');
  assert.deepEqual([...new Set(highlighted.map(m => m._searchFeature.properties.id))].sort(), [...expectedAuxIds].sort(), 'AUX-I highlights only its reviewed-candidate source IDs');
  assert(expectedAuxIds.has('t136'), 'Corrected LinkIQ maps WV-07 to WV-09 candidate');
  assert(highlighted.every(m => !m.options.dashArray), 'Shared geometry does not prove historical alternatives');
  const detailText = elements['network-details'].children.flatMap(x => [x.textContent, ...(x.children || []).map(y=>y.textContent)]).join(' ');
  assert.match(detailText, /CAUTION: diagram devices and edges/); assert.match(detailText, /Tester length/);
  assert.equal(elements['network-details'].parentElement.open, true);
  const raw = search('NET CC to A4'); assert(raw.length >= 1);
  assert.match(raw[0].textContent, /GPX route \(source name\)/);
  raw[0].click(); assert.equal(elements['network-details'].children.length, 0, 'Raw selection must clear stale network details');
  assert.equal(elements['network-details'].parentElement.open, false);
  context.search.focusContainer(112);
  assert.match(elements['map-search-status'].textContent, /Workshop/);
  context.search.addAsset({container_id:46,name:'Section A Wraps',contents:[{display_name:'Stale attachment',position_mode:'WITH_CONTAINER'}],reported_home:true,home_location_code:'RA09-B-01'}, true, null);
  assert.match(search('46')[0].textContent, /Home — Workshop.*RA09-B-01/);
  context.search.focusContainer(46);
  assert.match(elements['map-search-status'].textContent, /Home — Workshop.*RA09-B-01/);
  assert.equal(search('Stale attachment').length, 0, 'Home container must not carry stale attached display markers Home');
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
  assert(page.includes('V0.3.63-site-reference · Source refreshed 2026-10-11'));
  assert(!page.includes('temporary-workshop'), 'Obsolete October 8 marker must not be rendered');
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

// Exercise the real panel controller without replacing any search/layer state.
{
  const page = fs.readFileSync(path.join(__dirname, 'locate_preview.html'), 'utf8');
  const controls = {};
  let focused;
  for (const id of ['map-controls', 'map-controls-open', 'map-controls-close']) {
    controls[id] = { hidden: id === 'map-controls-open', attributes: {}, handlers: {},
      setAttribute(name, value) { this.attributes[name] = value; },
      addEventListener(name, handler) { this.handlers[name] = handler; },
      focus() { focused = id; } };
  }
  const source = page.match(/<script id="map-controls-script">([\s\S]*?)<\/script>/)[1];
  vm.runInNewContext(source, { document: { getElementById: id => controls[id] } });
  controls['map-controls-close'].handlers.click();
  assert.equal(controls['map-controls'].hidden, true);
  assert.equal(controls['map-controls-open'].hidden, false);
  assert.equal(controls['map-controls-open'].attributes['aria-expanded'], 'false');
  assert.equal(focused, 'map-controls-open');
  controls['map-controls-open'].handlers.click();
  assert.equal(controls['map-controls'].hidden, false);
  assert.equal(controls['map-controls-open'].hidden, true);
  assert.equal(controls['map-controls-open'].attributes['aria-expanded'], 'true');
  assert.equal(focused, 'map-controls-close');
  let prevented = false;
  controls['map-controls'].handlers.keydown({ key: 'Escape', preventDefault() { prevented = true; } });
  assert.equal(prevented, true);
  assert.equal(controls['map-controls'].hidden, true);
  console.log('PASS: map controls collapse, reopen, keyboard escape and focus');
}

// A missing pick must not become a confirmed workshop location or an inferred park delivery.
{
  const source = fs.readFileSync(path.join(__dirname, 'setup_locate_assets.js'), 'utf8');
  const fn = source.slice(source.indexOf('  function volunteerSummary('), source.indexOf('  function popup('));
  const context = {esc: value => String(value)};
  vm.createContext(context);
  vm.runInContext(fn, context);
  const summary = context.volunteerSummary;
  assert.match(summary({expected_location:'Workshop'}), /Workshop \(expected; not confirmed\)/);
  assert.match(summary({expected_location:'Workshop'}), /No picking or movement recorded/);
  assert.match(summary({movement_status:'PICKED'}), /assumed in the park or on the way/);
  assert.match(summary({movement_status:'IN_TRANSIT'}), /In transit/);
  assert.match(summary({observation:{event_type:'PLACED',stage_name:'Candyland',stage_key:'A5'}}), /A5 Candyland/);
  assert.match(summary({movement_status:'RETURNED',current_location_note:'Workshop rack 2'}), /Returned to storage/);
  assert.match(summary({position:[43,-87]}), /Recorded map location/);
  assert.doesNotMatch(summary({position:[43,-87]}), /In the park/);
  assert.match(summary({}), /Location not recorded/);
  console.log('PASS: volunteer status preserves known, expected and unknown location distinctions');
}

// Return Home overrides historical contents associations in the volunteer summary.
{
 const source = fs.readFileSync(path.join(__dirname, 'setup_locate_assets.js'), 'utf8');
 const context = {esc: String}; vm.createContext(context);
 vm.runInContext(source.slice(source.indexOf('  function volunteerSummary('), source.indexOf('  function popup(')), context);
 const result = context.volunteerSummary({reported_home:true,home_location_code:'RC05-A-01',current_location_note:'Old park destination',movement_status:'RETURNED'});
 assert.match(result, /RC05-A-01/); assert.match(result, /Empty — reported back Home/);
 assert.doesNotMatch(result, /Old park destination/);
}

// Execute Record Location's actual renderer as nearest rank changes, then GPS stops.
{
 const source = fs.readFileSync(path.join(__dirname, 'setup_record_location.js'), 'utf8');
 const buttons = {children:[],appendChild(b){this.children.push(b)},set innerHTML(v){this.children=[]}};
 const context = {watchId:1,latestPosition:{},gpsState:{},gpsToggle:{},gpsCandidates:{},gpsCandidateButtons:buttons,
 currentGpsSnapshot:()=>({accuracy_m:3,fix_age_ms:0}),rankedReferences:()=>[{name:'A',distance_ft:10},{name:'B',distance_ft:20}],
 renderRecordReadiness:()=>{},document:{createElement:()=>({addEventListener:()=>{}})}};
 vm.createContext(context);
 vm.runInContext(source.slice(source.indexOf('  function renderGps()'),source.indexOf('  function startGps()')),context);
 context.renderGps(); assert.equal(buttons.children[0].className,'location-nearest-first');
 assert.match(buttons.children[0].textContent,/Nearest: A/);
 context.rankedReferences=()=>[{name:'B',distance_ft:5},{name:'A',distance_ft:25}];context.renderGps();
 assert.match(buttons.children[0].textContent,/Nearest: B/);
 assert.equal(buttons.children[1].className,'location-nearest-alternative');
 context.currentGpsSnapshot=()=>null;context.renderGps();assert.equal(buttons.children.length,0);
 context.watchId=null;context.renderGps();assert.equal(buttons.children.length,0);
}

// A failed live movement refresh must CLEAR potentially stale asset markers;
// offline map may only show saved reference geography, never false live positions.
(async () => {
  const controls = Object.fromEntries(['asset-year','asset-status','asset-unlocated','asset-refresh'].map(id => [id,element()]));
  let clears = 0, calls = 0;
  const ctx = {document:{getElementById:id=>controls[id]}, URLSearchParams,
    window:{location:{search:''}},
    layers:{containers:{clearLayers(){clears++;}},displays:{clearLayers(){clears++;}}},
    mapSearch:{clearAssets(){clears++;}},
    fetch:async()=>{if (++calls > 1) throw new Error('Offline'); return {ok:true,json:async()=>({containers:[],displays:[],through_event_id:188})};}};
  vm.runInNewContext(read('setup_locate_assets.js'), ctx);
  await new Promise(resolve=>setImmediate(resolve));
  assert.equal(clears,3);
  await controls['asset-refresh'].click();
  assert.equal(clears,6,'Offline refresh clears both asset marker layers and search');
  assert.match(controls['asset-status'].textContent,/CURRENT Container \/ Display locations unavailable/);
  assert.match(controls['asset-status'].textContent,/No last-known locations are being represented as live/);
  assert.equal(controls['asset-refresh'].disabled,false);
  console.log('PASS: failed movement refresh clears obsolete locations, retaining reference-only offline map');
})().catch(error => {console.error(error);process.exitCode=1;});


// Regression: shared icon-top popup rule for all map symbol classes.
(async () => {
  const symbolCode = read('setup_locate_symbols.js');
  const source = read('setup_locate_assets.js');
  const begin = source.indexOf('  function render(items, container) {');
  const end = source.indexOf('  async function load() {', begin);
  assert(begin >= 0 && end > begin, 'Run the actual current asset renderer');

  const made = [];
  function icon(options) { return {options}; }
  const L = {
    icon, divIcon: icon,
    marker(xy, options) {
      const original = [...xy], handlers = {};
      const item = {
        xy, original, options, handlers, updates: 0,
        setIcon(next) {this.options.icon = next; return this;},
        bindTooltip() {return this;},
        bindPopup(content, popupOptions) {
          const dom = {
            handlers: {}, addEventListener(type, handler) {this.handlers[type] = handler;}
          };
          this.dom = dom;
          this.popup = {
            options: {...popupOptions}, isOpen: () => Boolean(item.opened),
            getElement: () => dom, update() {item.updates++;}
          };
          return this;
        },
        on(type, handler) {handlers[type] = handler; return this;},
        getPopup() {return this.popup;},
        openPopup() {this.opened = true; handlers.popupopen?.(); return this;},
        addTo() {made.push(this); return this;}
      };
      return item;
    },
    circleMarker(xy,options) {
      return L.marker(xy,{radius:options.radius});
    }
  };
  class ImageStub {
    set src(value) {
      this.naturalWidth = 18;
      this.naturalHeight = 32;
      queueMicrotask(() => this.onload?.());
    }
  }
  const ctx = {window:{},L,Image:ImageStub,setTimeout,clearTimeout};
  vm.createContext(ctx);
  vm.runInContext(symbolCode,ctx);
  Object.assign(ctx,{
    layers:{containers:{},displays:{}},
    icons:{EMPTY:'empty.svg',UNKNOWN:'unknown.svg'},
    esc:String,popup:a=>a.name,
    unlocated:{appendChild(){}},
    mapSearch:{addAsset(){}}
  });
  vm.runInContext(source.slice(begin,end),ctx);
  const symbols=ctx.window.msbReferenceSymbols;

  ctx.render([{container_id:9,name:'Ginger Bread House',
    load_state:'EMPTY',position:[43.77,-87.74]}],true);
  const container=made[0];
  assert.deepEqual(Array.from(container.popup.options.offset),[0,-24],
    '32x32 Container popup is centered 8px above its actual top edge');
  container.openPopup();
  assert(container.dom.handlers.toggle,'Details disclosure is handled by the shared symbol helper');
  container.dom.handlers.toggle({target:{tagName:'DETAILS'}});
  assert(container.updates>=2,'Opening/expanding popup must refresh Leaflet layout');
  assert.deepEqual(container.xy,container.original,'No Container GPS movement');

  ctx.render([{display_id:909,name:'CL-GingerbreadHouse',position:[43.78,-87.75]},
              {display_id:910,name:'CL-TumbleGinger-01',position:[43.78,-87.75]}],false);
  const display=made[1];
  assert.equal(made.length,2,'Coincident Displays share one marker');
  assert.deepEqual(Array.from(display.popup.options.offset),[0,-30],
    'Placeholder 12x12 icon top is correctly calculated while SVG loads');
  display.openPopup();
  await new Promise(resolve => setImmediate(resolve));
  assert.deepEqual(Array.from(display.options.icon.options.iconAnchor),[9,32],
    'T-Post SVG natural 18x32 icon has 16px additional map offset');
  assert.deepEqual(Array.from(display.options.icon.options.popupAnchor),[0,-32]);
  assert.deepEqual(Array.from(display.popup.options.offset),[0,-8],
    'Custom SVG popupAnchor already reaches top edge; do NOT double-offset');
  display.dom.handlers.toggle({target:{tagName:'DETAILS'}});
  assert.deepEqual(display.xy,display.original,'No Display GPS movement');

  const reference=symbols.marker([43.79,-87.76],'Panel');
  symbols.bindPopupAtIconTop(reference,'Reference details');
  await new Promise(resolve => setImmediate(resolve));
  assert.deepEqual(Array.from(reference.popup.options.offset),[0,-8],
    'Permanent GPX waypoint popups use the same top-centered rule');
  assert.deepEqual(reference.xy,reference.original,'Permanent reference geometry unchanged');
  assert(read('locate_preview.html').includes(
    'window.msbReferenceSymbols.bindPopupAtIconTop(marker,detail(p))'),
    'The reference map must use the shared popup rule, not a separate legacy anchor');
  console.log('PASS: Container, independent Display and reference popups top-centered across icon replacement and disclosure');
})().catch(e=>{console.error(e);process.exitCode=1;});

// Panel checklist deep links select maintained wp IDs, never stale GPX IDs.
{
 const marker={_searchFeature:{properties:{id:'wp:42',name:'WV-00',type:'Panel'}},getLatLng(){return 'panel-point'},openPopup(){this.opened=true}};
 context.layers.refs={eachLayer(fn){fn(marker)},addTo(){}};
 context.search.reindexMapReferences();
 context.search.focusWaypoint('42');
 assert.equal(marker.opened,true);
 assert.equal(elements['map-search-status'].textContent,'WV-00');
 context.search.focusWaypoint('99999');
 assert.match(elements['map-search-status'].textContent,/not available/);
 console.log('PASS: checklist panel link focuses maintained waypoint and handles missing location');
}
