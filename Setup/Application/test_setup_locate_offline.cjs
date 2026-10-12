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
  assert.equal(window.msbReferenceSymbols.urlFor('Tower'),null,
    'Unreviewed artwork must not be guessed');
  const marker = window.msbReferenceSymbols.marker([43.778,-87.743],'Camera');
  assert.equal(marker.options.icon.kind,'placeholder');
  await new Promise(resolve => setImmediate(resolve));
  assert.equal(marker.options.icon.kind,'icon');
  assert.deepEqual(Array.from(marker.options.icon.options.iconSize),[18,32],
    'Native rectangular canvas is preserved');
  assert.deepEqual(Array.from(marker.options.icon.options.iconAnchor),[9,16]);
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

  process.stdout.write('PASS: GPX conservation, natural SVG canvas, offline tile bounds, script routes and offline permissions\n');
})().catch(error => { console.error(error); process.exitCode=1; });
