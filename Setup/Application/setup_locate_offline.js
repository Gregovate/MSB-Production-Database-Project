/* #171: deliberately prepared, read-only Park Map cache for field Android tablets.
 * The HTML/GPX index, assets, approved SVG symbols and bounded orthophoto tiles
 * must be fully downloaded while connected before airplane-mode/restart use.
 */
(() => {
  'use strict';
  const root = new URL('./', location.href);
  const STATUS_CACHE = 'msb-park-map-metadata-v1';
  const POINTER = new URL('offline-package-state', root).href;
  const REFERENCE = new URL('offline-reference-snapshot', root).href;
  const MAP_VERSION = 'msb-park-map-offline-20261011-r1';
  const regions = [
    [-87.7508,43.7750,-87.7382,43.7814],
    [-87.7390,43.7765,-87.7322,43.7792]
  ];
  const container = document.getElementById('offline-controls');
  const select = document.createElement('select');
  const button = document.createElement('button');
  const remove = document.createElement('button');
  const status = document.createElement('div');
  status.setAttribute('role', 'status');
  status.style.cssText = 'margin:7px 0;overflow-wrap:anywhere';
  select.style.cssText = 'max-width:100%;min-height:38px;margin:7px 0';
  button.type = remove.type = 'button';
  button.textContent = 'Download / refresh offline park map';
  remove.textContent = 'Remove downloaded map';
  const note = document.createElement('p');
  note.className = 'legend';
  note.textContent = 'While online, prepare this device once. Saved imagery and references work in airplane mode. This does not save current Container positions or allow offline edits. Keep this page open until download completes.';
  container.append(note, select, button, remove, status);

  function tile(lon, lat, z) {
    const n = 2 ** z;
    return [Math.floor((lon + 180) / 360 * n),
      Math.floor((1 - Math.asinh(Math.tan(lat * Math.PI / 180)) / Math.PI) / 2 * n)];
  }
  function countTiles(maxZoom) {
    const tiles = new Set();
    for (let z = 14; z <= maxZoom; z++) for (const [w,s,e,n] of regions) {
      const [x0,y0] = tile(w,n,z), [x1,y1] = tile(e,s,z);
      for (let x = x0; x <= x1; x++) for (let y = y0; y <= y1; y++)
        tiles.add(z + '/' + x + '/' + y);
    }
    return tiles.size;
  }
  for (const [zoom, title] of [[19,'Standard'],[20,'Detailed'],[21,'Maximum detail (large download)']]) {
    const option = document.createElement('option');
    option.value = String(zoom);
    const count = countTiles(zoom);
    option.textContent = title + ' · ' + count + ' aerial tiles';
    select.appendChild(option);
  }
  const describe = data => data ?
    'Prepared: ' + new Date(data.preparedAt).toLocaleString() +
    ' · z14–' + data.maxZoom + ' · ' + data.tiles + ' tiles · ' +
    (data.referenceRevision == null ? 'static GPX only (DB not downloaded)' :
      'PostgreSQL reference revision ' + data.referenceRevision) +
    (data.version === MAP_VERSION ? '' : ' · OLD PACKAGE: refresh online') :
    'No complete offline park-map package on this device.';
  async function readState() {
    if (!('caches' in window)) return null;
    const meta = await caches.open(STATUS_CACHE);
    const response = await meta.match(POINTER);
    if (!response) return null;
    const state = await response.json();
    if (!state.cacheName || !(await caches.has(state.cacheName))) return null;
    return state;
  }
  async function readReferences() {
    try {
      const state = await readState();
      if (!state || state.referenceRevision == null) return null;
      const cache = await caches.open(state.cacheName);
      const response = await cache.match(REFERENCE);
      if (!response) return null;
      const snapshot = await response.json();
      if (snapshot.data_mode !== 'postgres' || snapshot.format_version !== 1) return null;
      // Cached copy can NEVER grant editing rights, including after reconnect.
      snapshot.permissions = {identity:false, operations:false};
      snapshot._offlinePreparedAt = state.preparedAt;
      return snapshot;
    } catch (_) { return null; }
  }
  window.MSBLocateOffline = Object.freeze({readState, readReferences});

  function message(type, payload = {}, progress = () => {}) {
    return navigator.serviceWorker.ready.then(reg => new Promise((resolve, reject) => {
      const worker = navigator.serviceWorker.controller || reg.active;
      if (!worker) return reject(Error('Park Map offline worker unavailable'));
      const channel = new MessageChannel();
      channel.port1.onmessage = event => {
        const data = event.data || {};
        if (data.event === 'progress') progress(data);
        else if (data.event === 'complete' || data.event === 'removed' || data.event === 'state') {
          channel.port1.close();
          resolve(data.data);
        } else if (data.event === 'error') {
          channel.port1.close();
          reject(Error(data.message || 'Offline download failed'));
        }
      };
      worker.postMessage({type, ...payload}, [channel.port2]);
    }));
  }
  function verifyImage(url) {
    return new Promise((resolve, reject) => {
      const image = new Image();
      let done = false;
      const finish = error => {
        if (done) return;
        done = true;
        clearTimeout(timeout);
        error ? reject(Error(url.split('/').pop() + ': ' + error)) : resolve();
      };
      const timeout = setTimeout(() => finish('timed out'),15000);
      image.onload = () => image.naturalWidth > 0 && image.naturalHeight > 0
        ? finish() : finish('invalid image dimensions');
      image.onerror = () => finish('not available on public web server');
      image.src = url;
    });
  }
  function currentMessage(data) {
    status.textContent = (navigator.onLine ? 'Connected · ' : 'OFFLINE / READ-ONLY · ')
      + describe(data) + (!navigator.onLine ?
      ' Live assets and editing unavailable. Reference routes do not certify digging clearance.' : '');
    remove.disabled = !data;
  }
  async function refresh() {
    try { currentMessage(await readState()); }
    catch (error) { status.textContent = 'Offline package status unavailable: ' + error.message; }
  }
  async function download() {
    if (!navigator.onLine) {
      status.textContent = 'Connect before downloading; the previous completed package remains intact.';
      return;
    }
    button.disabled = remove.disabled = true;
    const maxZoom = Number(select.value);
    const count = countTiles(maxZoom);
    try {
      if (!navigator.serviceWorker || !window.isSecureContext)
        throw Error('Offline installation requires HTTPS and Service Worker support');
      if (navigator.storage && navigator.storage.estimate) {
        const storage = await navigator.storage.estimate();
        // Inform, never invent an exact JPEG size or silently exhaust storage.
        if (storage.quota && storage.usage && storage.quota - storage.usage < count * 30000)
          throw Error('Device storage appears too low for ' + count + ' imagery tiles; choose a smaller zoom or free space');
      }
      status.textContent = 'Checking published Plain SVG symbols…';
      const urls = window.msbReferenceSymbols.urls();
      const results = await Promise.allSettled(urls.map(verifyImage));
      const failed = results.filter(result => result.status === 'rejected')
        .map(result => result.reason.message);
      if (failed.length) throw Error('Required published SVGs unavailable: ' + failed.join(', ') +
        '. Ask the authorized web administrator to publish them before installing.');
      let snapshot = null;
      try {
        const response = await fetch('../api/setup/locate/references',
          {cache:'no-store',credentials:'same-origin'});
        if (response.ok) {
          const candidate = await response.json();
          if (candidate.data_mode === 'postgres' && candidate.format_version === 1)
            snapshot = candidate;
        }
      } catch (_) { /* Static GPX is still useful before DB acceptance. */ }
      status.textContent = 'Saving ' + count + ' bounded aerial tiles and offline map files… 0%. Keep this page open.';
      const data = await message('PREPARE',{maxZoom,snapshot}, update => {
        status.textContent = 'Downloading map: ' + update.complete + ' / ' + update.total
          + ' assets (' + Math.floor(update.complete / update.total * 100) + '%). Keep this page open.';
      });
      currentMessage(data);
      status.textContent += ' · COMPLETE. Test airplane-mode reload before relying on this device.';
    } catch (error) {
      status.textContent = 'NOT INSTALLED: ' + error.message +
        '. Any previous complete offline package remains available.';
      await refresh().catch(() => {});
      status.textContent += ' Last attempt: ' + error.message;
    } finally {button.disabled = false; await refresh().catch(() => {});}
  }
  button.addEventListener('click',download);
  remove.addEventListener('click',async () => {
    if (!confirm('Remove the offline Park Map files and saved read-only reference data from this device?')) return;
    remove.disabled = button.disabled = true;
    try { await message('REMOVE'); currentMessage(null); }
    catch (error) { status.textContent = 'Remove failed: ' + error.message; }
    finally { button.disabled = false; }
  });
  window.addEventListener('online',refresh);
  window.addEventListener('offline',refresh);
  if ('serviceWorker' in navigator && window.isSecureContext) {
    navigator.serviceWorker.register('service-worker.js',{scope:'./'})
      .then(refresh)
      .catch(error => {status.textContent = 'Offline installation unavailable: ' + error.message;});
  } else {
    button.disabled = true;
    status.textContent = 'Offline support requires an HTTPS-capable browser with Service Workers.';
  }
})();
