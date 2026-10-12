/* #171: offline package for the EXISTING read-only /setup/locate/ Park Map.
 * A separate SW scope preserves #88 record-location and pick-list behavior.
 * Nothing is cached until the operator explicitly chooses Download/refresh.
 * No credentials, #88 live movement API, command POST, or edit permission cached.
 */
'use strict';
const VERSION = 'msb-park-map-offline-20261011-r1';
const PREFIX = 'msb-park-map-package-';
const META = 'msb-park-map-metadata-v1';
const ROOT = self.registration.scope;
const STATE = new URL('offline-package-state', ROOT).href;
const REFERENCE = new URL('offline-reference-snapshot', ROOT).href;
const TILE_BASE = 'https://webassets.sheboyganlights.org/maps/evergreen-2019-v1/';
const SYMBOL_BASE = 'https://webassets.sheboyganlights.org/images/symbols/msb-svg/';
const SHELL = [
  './',
  'assets/locate_leaflet_1_9_4.min.js',
  'assets/locate_leaflet_1_9_4.css',
  'assets/setup_locate_symbols.js',
  'assets/setup_locate_offline.js',
  'assets/setup_locate_search.js',
  'assets/setup_site_reference.js',
  'assets/setup_locate_networks.js',
  'assets/setup_locate_networks.json',
  'assets/setup_locate_assets.js',
  'assets/container-loaded.svg',
  'assets/container-partial.svg',
  'assets/container-empty.svg',
  'assets/container-unknown.svg'
].map(relative => new URL(relative, ROOT).href);
// Bounded park + east Workshop/approach; excludes an unrelated outlier GPX
// field track at 43.6266 that would otherwise cache thousands of wrong tiles.
const BOUNDS = [
  [-87.7508, 43.7750, -87.7382, 43.7814],
  [-87.7390, 43.7765, -87.7322, 43.7792]
];
const SVG_NAMES = [
  'panel','outlet-combo','ip-camera','outlet-power','kit-box',
  'fire-hydrant','lp','lp-combo','lp-network','lp-outlet',
  'manhole','t-post','transformer','stage','lor-controller'
];
const SYMBOLS = SVG_NAMES.map(n => SYMBOL_BASE + n + '.svg');

function tilexy(lon, lat, zoom) {
  const n = 2 ** zoom;
  const y = Math.asinh(Math.tan(lat * Math.PI / 180));
  return [Math.floor((lon + 180) / 360 * n),
    Math.floor((1 - y / Math.PI) / 2 * n)];
}
function tiles(maxZoom) {
  if (![19, 20, 21].includes(maxZoom)) throw Error('Unsupported offline imagery zoom');
  const result = new Set();
  for (let z = 14; z <= maxZoom; z++) for (const [west,south,east,north] of BOUNDS) {
    const [left,top] = tilexy(west,north,z);
    const [right,bottom] = tilexy(east,south,z);
    for (let x = left; x <= right; x++)
      for (let y = top; y <= bottom; y++)
        result.add(TILE_BASE + z + '/' + x + '/' + y + '.jpg');
  }
  if (result.size > 7000) throw Error('Offline tile set exceeds controlled 7,000 tile limit');
  return [...result];
}
function allowedExternal(url) {
  return url.origin === 'https://webassets.sheboyganlights.org' &&
    (url.href.startsWith(TILE_BASE) || SYMBOLS.includes(url.href));
}
async function state() {
  const store = await caches.open(META);
  const response = await store.match(STATE);
  if (!response) return null;
  const data = await response.json();
  if (typeof data.cacheName !== 'string' || !data.cacheName.startsWith(PREFIX)) return null;
  if (!(await caches.has(data.cacheName))) return null;
  return data;
}
async function cacheOrNetwork(request, fallback) {
  try {
    const response = await fetch(request);
    if (response.ok || response.type === 'opaque') return response;
    if (!fallback) return response;
  } catch (_) { /* The offline package is the only fallback. */ }
  if (fallback) {
    const match = await fallback.match(request, {ignoreSearch: true});
    if (match) return match;
  }
  return Response.error();
}
async function prepare(maxZoom, snapshot, port) {
  const tileUrls = tiles(maxZoom);
  const allUrls = [...SHELL, ...SYMBOLS, ...tileUrls];
  const cacheName = PREFIX + VERSION + '-' + Date.now() + '-' + Math.random().toString(36).slice(2,8);
  const stage = await caches.open(cacheName);
  let count = 0, next = 0, failed = null, promoted = false;
  const tell = message => { try { port.postMessage(message); } catch (_) {} };
  try {
    const workers = Array.from({length: 6}, async () => {
      while (!failed && next < allUrls.length) {
        const url = allUrls[next++];
        try {
          const external = new URL(url).origin !== self.location.origin;
          const request = new Request(url, {
            mode: external ? 'no-cors' : 'same-origin',
            credentials: external ? 'omit' : 'same-origin',
            cache: 'reload'
          });
          const response = await fetch(request);
          // Opaque responses can be stored for cross-origin tile/image loading,
          // but HTTP status cannot be inspected. The operator still must perform
          // an airplane-mode visual check before accepting image coverage.
          if (!response.ok && response.type !== 'opaque')
            throw Error('HTTP ' + response.status + ' from ' + url);
          if (!external && url === SHELL[0]) {
            const html = await response.clone().text();
            if (!html.includes('<title>MSB Park Map v1</title>'))
              throw Error('Expected Park Map HTML unavailable (Access/login response?)');
          }
          if (!external && url !== SHELL[0] &&
              (response.headers.get('Content-Type') || '').includes('text/html'))
            throw Error('Unexpected HTML/login response instead of map asset: ' + url);
          await stage.put(new Request(url), response.clone());
          count++;
          if (count % 10 === 0 || count === allUrls.length)
            tell({event:'progress',complete:count,total:allUrls.length});
        } catch (error) {
          failed = error;
        }
      }
    });
    await Promise.all(workers);
    if (failed) throw failed;
    if (snapshot !== null) {
      if (!snapshot || snapshot.data_mode !== 'postgres' || snapshot.format_version !== 1)
        throw Error('Unexpected PostgreSQL reference snapshot');
      // Store only bounded reference facts. Never store live permission grants.
      const picked = {data_mode:'postgres',format_version:1,
        revision:snapshot.revision,unresolved_linkiq_tests:snapshot.unresolved_linkiq_tests,
        sources:snapshot.sources,permissions:{identity:false,operations:false}};
      for (const key of ['waypoints','tracks','routes','panels','circuits','destinations',
        'networks','memberships','instructions','cables']) {
        if (!Array.isArray(snapshot[key])) throw Error('Missing reference collection: ' + key);
        picked[key] = snapshot[key];
      }
      await stage.put(REFERENCE,new Response(JSON.stringify(picked),
        {headers:{'Content-Type':'application/json'}}));
    }
    const data = {cacheName,version:VERSION,maxZoom,tiles:tileUrls.length,
      symbols:SYMBOLS.length,preparedAt:new Date().toISOString(),
      referenceRevision:snapshot ? snapshot.revision : null};
    // Single last step switches active package atomically. Prior package remains
    // authoritative if any asset fetch, cache write or quota check fails.
    const meta = await caches.open(META);
    await meta.put(STATE,new Response(JSON.stringify(data),
      {headers:{'Content-Type':'application/json'}}));
    promoted = true;
    tell({event:'complete',data});
    // Cleanup is best-effort; never delete a newly promoted active package.
    try {
      for (const key of await caches.keys())
        if (key.startsWith(PREFIX) && key !== cacheName) await caches.delete(key);
    } catch (_) { /* Active package remains valid and recorded. */ }
  } catch (error) {
    if (!promoted) await caches.delete(cacheName);
    tell({event:'error',message:String(error.message || error)});
  }
}
self.addEventListener('install', event => event.waitUntil(self.skipWaiting()));
self.addEventListener('activate', event => event.waitUntil(self.clients.claim()));
self.addEventListener('message', event => {
  const p = event.ports && event.ports[0];
  if (!p || !event.data) return;
  if (event.data.type === 'PREPARE') {
    event.waitUntil(prepare(Number(event.data.maxZoom), event.data.snapshot ?? null, p));
  } else if (event.data.type === 'STATE') {
    event.waitUntil(state().then(data => p.postMessage({event:'state',data}))
      .catch(e => p.postMessage({event:'error',message:String(e)})));
  } else if (event.data.type === 'REMOVE') {
    event.waitUntil((async () => {
      const current = await state();
      const store = await caches.open(META);
      await store.delete(STATE);
      if (current) await caches.delete(current.cacheName);
      p.postMessage({event:'removed'});
    })().catch(e => p.postMessage({event:'error',message:String(e)})));
  }
});
self.addEventListener('fetch', event => {
  const req = event.request;
  if (req.method !== 'GET') return;  // Never queue or replay a GIS edit.
  const url = new URL(req.url);
  const sameApp = url.origin === self.location.origin && url.href.startsWith(ROOT);
  if (!sameApp && !allowedExternal(url)) return;
  event.respondWith((async () => {
    const current = await state();
    const pkg = current ? await caches.open(current.cacheName) : null;
    if (sameApp && req.mode === 'navigate')
      return cacheOrNetwork(req, pkg ? {
        match: () => pkg.match(new URL('./',ROOT).href)
      } : null);
    return cacheOrNetwork(req,pkg);
  })());
});
