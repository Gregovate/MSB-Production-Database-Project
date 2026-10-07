'use strict';

const CACHE_NAME = 'msb-setup-record-location-v16';
const SHELL = [
  './',
  'assets/setup_record_location.css?v=2026-10-07.2',
  'assets/setup_record_location.js?v=2026-10-07.3',
  'location-references.json'
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
          return key.indexOf('msb-setup-record-location-') === 0 && key !== CACHE_NAME;
        }).map(function (key) { return caches.delete(key); }));
      })
      .then(function () { return self.clients.claim(); })
  );
});

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

  if (event.request.mode === 'navigate' && url.pathname.indexOf('/record-location') >= 0) {
    event.respondWith(networkFirst(event.request));
    return;
  }

  if (url.pathname.indexOf('/record-location/location-references.json') >= 0) {
    event.respondWith(networkFirst(event.request));
    return;
  }

  if (url.pathname.indexOf('/record-location/assets/') >= 0) {
    event.respondWith(networkFirst(event.request));
  }
});
