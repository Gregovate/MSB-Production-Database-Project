'use strict';

const CACHE_NAME = 'msb-setup-pick-mode-v9';
const SHELL = [
  './',
  'assets/setup_pick_list.css?v=2026-09-30.5',
  'assets/setup_pick_mode.css?v=2026-09-30.8',
  'assets/qrcode.min.js?v=1',
  'assets/setup_pick_list.js?v=2026-09-30.9',
  'assets/setup_pick_mode.js?v=2026-09-30.7'
];

self.addEventListener('install', function (event) {
  event.waitUntil(
    caches.open(CACHE_NAME)
      .then(function (cache) { return cache.addAll(SHELL); })
      .then(function () { return self.skipWaiting(); })
  );
});

self.addEventListener('activate', function (event) {
  event.waitUntil(
    caches.keys()
      .then(function (keys) {
        return Promise.all(keys.filter(function (key) {
          return key.indexOf('msb-setup-pick-mode-') === 0 && key !== CACHE_NAME;
        }).map(function (key) { return caches.delete(key); }));
      })
      .then(function () { return self.clients.claim(); })
  );
});

function isSetupReadRequest(request) {
  if (request.method !== 'GET') return false;
  const url = new URL(request.url);
  return url.pathname.indexOf('/api/setup/material-readiness') >= 0
    || url.pathname.indexOf('/api/setup/access') >= 0;
}

async function networkFirst(request) {
  const cache = await caches.open(CACHE_NAME);
  try {
    const response = await fetch(request);
    if (response.ok) await cache.put(request, response.clone());
    return response;
  } catch (error) {
    const cached = await cache.match(request, {ignoreSearch: true});
    if (cached) return cached;
    throw error;
  }
}

self.addEventListener('fetch', function (event) {
  if (event.request.method !== 'GET') return;
  const url = new URL(event.request.url);
  if (url.origin !== self.location.origin) return;

  if (event.request.mode === 'navigate' && url.pathname.indexOf('/pick-list') >= 0) {
    event.respondWith(networkFirst(event.request));
    return;
  }

  if (url.pathname.indexOf('/pick-list/assets/') >= 0 || isSetupReadRequest(event.request)) {
    event.respondWith(networkFirst(event.request));
  }
});
