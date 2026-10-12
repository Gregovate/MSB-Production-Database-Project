// #171: no network, no Production and no connected browser required.
// Exercise the shipped SVG symbol registry and the bounded offline SW tile policy.
'use strict';
const assert = require('node:assert/strict');
const fs = require('node:fs');
const vm = require('node:vm');
const path = require('node:path');
const read = name => fs.readFileSync(path.join(__dirname, name), 'utf8');

(async () => {
  const page = read('locate_preview.html');
  assert(page.includes('assets/locate_leaflet_1_9_4.min.js'));
  assert(page.includes('assets/locate_leaflet_1_9_4.css'));
  assert(page.includes('assets/setup_locate_symbols.js'));
  assert(page.includes('assets/setup_locate_offline.js'));
  assert(!page.includes('unpkg.com'), 'Offline page must not require a CDN');
  assert(!page.includes('iconSize:[32,32],iconAnchor:[16,16],popupAnchor:[0,-16]'),
    'Reference icon geometry must no longer be forced square');
  const match = page.match(/const data=(.*?);data.features.push/s);
  assert(match, 'Existing GPX data is still embedded as read-only fallback');
  const feats = JSON.parse(match[1]).features;
  // Do not pin source counts: GPX data changes under the maintained importer.
  const waypoints = feats.filter(f => f.geometry.type === 'Point');
  const tracks = feats.filter(f => f.geometry.type !== 'Point');
  assert(waypoints.length > 0 && tracks.length > 0, 'Reference features retained');
  assert(feats.every(f => f.properties && typeof f.properties.name === 'string'),
    'Source names preserved for search');
  assert.equal(feats.filter(f => f.properties.name === 'Workshop').length, 1,
    'Never reinsert the temporary Workshop marker');
  assert(page.includes('window.msbReferenceSymbols.marker(xy,p.type)'));
  assert(!read('setup_locate_assets.js').includes('msb/T-Post.png'),
    'Independent Display artwork must be SVG, not old PNG');
  assert(read('setup_locate_assets.js').includes('layers.containers.clearLayers()'),
    'Never present stale movement as current during offline use');

  // #171/#88: Exercise the actual drop-picker PostGIS normalization logic.
  // No live database or production movement is needed for this regression.
  const recordLocation = read('setup_record_location.js');
  const matchNormalize = recordLocation.match(/  function normalizeSiteReference\\(snapshot\\) \\{[\\s\\S]*?\\n  \\}\\n\\n  async function loadReferenceSet/);
  assert(matchNormalize, 'Record Location must expose maintained GIS normalization');
  const normalizationBody = matchNormalize[0].replace(/\\n\\n  async function loadReferenceSet$/, '');
  const normalize = vm.runInNewContext(normalizationBody + '\\nnormalizeSiteReference', {});
  const fixture = normalize({format_version:1,data_mode:'postgres',revision:8,
    sources:{gpx:{sha256:'a'.repeat(64)}},waypoints:[
      {id:42,label:'Command Center',type:'Waypoint',
        geometry:{type:'Point',coordinates:[-87.74,43.78]}},
      {id:43,label:'Workshop',type:'Waypoint',
        geometry:{type:'Point',coordinates:[-87.75,43.77]}}
    ]});
  assert.equal(fixture.points[0].name, 'Command Center');
  assert.equal(fixture.points[0].reference_id, 'site-waypoint:42');
  assert.equal(fixture.points[1].name, 'Workshop');
  assert.equal(fixture.accepted_gpx_sha256, 'a'.repeat(64));
  assert.throws(() => normalize({format_version:1,data_mode:'postgres',waypoints:[]}),
    /No accepted maintained GPX/);

  const issued = [];
  class ImageStub {
    set src(value) {
      issued.push(value);
      this.naturalWidth = 18; this.naturalHeight = 32;
      queueMicrotask(() => this.onload && this.onload());
    }
  }
  const built = [];
  const L = {
    icon(options) {built.push(options); return {kind:'icon',options};},
    divIcon(options) {return {kind:'placeholder',options};},
    marker(xy,options) {
      return {xy,options,setIcon(icon) {this.options.icon=icon;}};
    },
    circleMarker(xy,options) {return {kind:'circle',xy,options};}
  };
  const window = {};
  const sym = vm.createContext({window,L,Image:ImageStub,setTimeout,clearTimeout});
  vm.runInContext(read('setup_locate_symbols.js'),sym);
  assert.equal(window.msbReferenceSymbols.urlFor('Camera'),
    'https://webassets.sheboyganlights.org/images/symbols/msb-svg/ip-camera.svg');
  assert.equal(window.msbReferenceSymbols.urlFor('LP-Power'),
    'https://webassets.sheboyganlights.org/images/symbols/msb-svg/lp-outlet.svg');
  assert.equal(window.msbReferenceSymbols.urlFor('Flag'),
    'https://webassets.sheboyganlights.org/images/symbols/msb-svg/pole-yellow.svg',
    'GPX Flag/Display Anchor markers use the approved yellow pole icon');
  assert(feats.some(f => f.geometry.type === 'Point' && f.properties.type === 'Flag'),
    'Flag waypoint fixtures remain in accepted source');
  assert.equal(window.msbReferenceSymbols.urlFor('Tower'),null,
    'Unreviewed artwork must not be guessed');
  const marker = window.msbReferenceSymbols.marker([43.778,-87.743],'Camera');
  assert.equal(marker.options.icon.kind,'placeholder');
  await new Promise(resolve => setImmediate(resolve));
  assert.equal(marker.options.icon.kind,'icon');
  assert.deepEqual(Array.from(marker.options.icon.options.iconSize),[18,32],
    'Native rectangular canvas is preserved');
  assert.deepEqual(Array.from(marker.options.icon.options.iconAnchor),[9,16]);
  // Independent Displays use reviewed, natural-size T-Post artwork above
  // Container coordinates; adjusting icon anchor MUST NOT change GPS data.
  const display = L.marker([43.778,-87.743], {
    icon:L.divIcon({iconSize:[12,12],iconAnchor:[6,22]}),zIndexOffset:1000
  });
  assert.equal(window.msbReferenceSymbols.setSymbol(display, 'T-Post', {yOffset:16}),true);
  await new Promise(resolve => setImmediate(resolve));
  assert.deepEqual(Array.from(display.xy),[43.778,-87.743]);
  assert.deepEqual(Array.from(display.options.icon.options.iconSize),[18,32]);
  assert.deepEqual(Array.from(display.options.icon.options.iconAnchor),[9,32]);
  assert.equal(display.options.zIndexOffset,1000);
  assert(issued.every(url => url.startsWith('https://webassets.sheboyganlights.org/images/symbols/msb-svg/')));
  const unknown = window.msbReferenceSymbols.marker([43.77,-87.74],'Unmapped-Type');
  assert.equal(unknown.kind,'circle');

  const handlers = new Map();
  const swScope = 'https://my.sheboyganlights.org/setup/locate/';
  const sw = vm.createContext({
    self: {
      registration: {scope:swScope},
      location: {origin: 'https://my.sheboyganlights.org'},
      addEventListener(type,callback) {handlers.set(type,callback);}
    },
    URL,Request,Response,Set,Math,Date,caches:{}
  });
  vm.runInContext(read('setup_locate_sw.js'),sw);
  assert.equal(vm.runInContext('tiles(19).length',sw),484);
  assert.equal(vm.runInContext('tiles(20).length',sw),1699);
  assert.equal(vm.runInContext('tiles(21).length',sw),6426);
  assert(vm.runInContext('tiles(19).every(x=>x.includes("/evergreen-2019-v1/"))',sw));
  assert(vm.runInContext('!tiles(19).some(x=>x.includes("/191000/"))',sw));
  assert(vm.runInContext('allowedExternal(new URL("https://webassets.sheboyganlights.org/maps/evergreen-2019-v1/19/1/2.jpg"))',sw));
  assert(!vm.runInContext('allowedExternal(new URL("https://other.example/file"))',sw));
  assert(!vm.runInContext('allowedExternal(new URL("https://webassets.sheboyganlights.org/images/symbols/msb/IP-camera.png"))',sw));
  const server = read('production_backend.py');
  assert(server.includes('def locate_offline_service_worker()'));
  assert(server.includes('"setup_locate_sw.js", mimetype="application/javascript"'));
  assert(!server.includes('response.headers["Service-Worker-Allowed"] = "/locate/"'));
  for (const name of ['locate_leaflet_1_9_4.min.js','locate_leaflet_1_9_4.css',
    'setup_locate_symbols.js','setup_locate_offline.js']) assert(server.includes('"'+name+'"'));
  assert(read('setup_site_reference.js').includes('readReferences()'));
  assert(read('setup_site_reference.js').includes('permissions'));
  assert(read('setup_locate_offline.js').includes('navigator.serviceWorker.register'));
  assert(read('setup_locate_offline.js').includes('aerial.options.maxNativeZoom'));
  assert(read('locate_leaflet_LICENSE.txt').includes('BSD 2-Clause License'));

  // Exercise actual SW CacheStorage promotion and failure rollback using a
  // disposable in-memory browser stand-in. No public server is contacted.
  class MemoryCache {
    constructor() { this.files = new Map(); }
    key(request) { return typeof request === 'string' ? request : request.url; }
    async put(request, response) { this.files.set(this.key(request), response.clone()); }
    async match(request) { return this.files.get(this.key(request))?.clone(); }
    async delete(request) { return this.files.delete(this.key(request)); }
  }
  const allCaches = new Map();
  const memory = {
    async open(name) {
      if (!allCaches.has(name)) allCaches.set(name,new MemoryCache());
      return allCaches.get(name);
    },
    async keys() { return [...allCaches.keys()]; },
    async has(name) {return allCaches.has(name);},
    async delete(name) {return allCaches.delete(name);}
  };
  const events = [];
  let breakSync = false;
  const fetchStub = async req => {
    if (breakSync && req.url.includes('assets/setup_locate_networks.json'))
      return new Response('simulated offline update failure',{status:503});
    const html = req.url.endsWith('/locate/');
    return new Response(html ? '<title>MSB Park Map v1</title>' : 'candidate bytes',
      {status:200,headers:{'Content-Type':html ? 'text/html' : 'application/octet-stream'}});
  };
  const worker = vm.createContext({URL,Request,Response,Set,Math,Date,
    caches:memory,fetch:fetchStub,
    self:{registration:{scope:swScope},location:{origin:'https://my.sheboyganlights.org'},
      addEventListener(){}},
    testPort:{postMessage(msg) {events.push(msg);}}});
  vm.runInContext(read('setup_locate_sw.js'),worker);
  await vm.runInContext('prepare(19, null, testPort)',worker);
  assert.equal(events.at(-1).event,'complete',
    'Fully verified package promotes a new active pointer');
  const installed = await vm.runInContext('state()',worker);
  assert.equal(installed.tiles,484);
  assert.equal(installed.referenceRevision,null);
  const firstName = installed.cacheName;
  assert((await memory.open(firstName)).files.size >= 484,
    'Aerial and shell entries are present in completed package');
  breakSync = true;
  await vm.runInContext('prepare(19, null, testPort)',worker);
  assert.equal(events.at(-1).event,'error',
    'Failed source fetch aborts rather than marking package complete');
  const unchanged = await vm.runInContext('state()',worker);
  assert.equal(unchanged.cacheName,firstName,
    'A failed replacement never destroys prior downloaded map');
  assert.equal(allCaches.size,2,'Incomplete cache is deleted, active cache retained');
  assert(!(await memory.open(firstName)).files.has(
    'https://my.sheboyganlights.org/setup/api/setup/locate/assets'),
    'No live movement API is persisted in package');

  process.stdout.write('PASS: GPX conservation, natural SVG canvas, offline tile bounds, script routes and offline permissions\n');
})().catch(error => { console.error(error); process.exitCode=1; });
