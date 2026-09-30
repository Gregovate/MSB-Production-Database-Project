'use strict';

const CACHE_NAME = 'msb-setup-pick-mode-v1';
const SHELL = [
  './',
  'assets/setup_pick_list.css?v=2026-09-29.3',
  'assets/setup_pick_mode.css?v=2026-09-29.1',
  'assets/qrcode.min.js?v=1',
  'assets/setup_pick_list.js?v=2026-09-29.3',
  'assets/setup_pick_mode.js?v=2026-09-29.1'
];

self.addEventListener('install', (event) => {
  event.waitUntil(
    caches.open(CACHE_NAME)
      .then((cache) => cache.addAll(SHELL))
      .then(() => self.skipWaiting())
  );
});

self.addEventListener('activate', (event) => {
  event.waitUntil(
    caches.keys()
      .then((keys) => Promise.all(
        keys.filter((key) => key !== CACHE_NAME).map((key) => caches.delete(key))
      ))
      .then(() => self.clients.claim())
  );
});

function isSetupReadRequest(request) {
  if (request.method !== 'GET') return false;
  const url = new URL(request.url);
  return (
    url.pathname.includes('/api/setup/material-readiness')
    || url.pathname.includes('/api/setup/access')
    || url.pathname.includes('/api/setup/containers/source-options')
    || url.pathname.includes('/api/setup/stages')
  );
}

async function networkFirst(request) {
  const cache = await caches.open(CACHE_NAME);
  try {
    const response = await fetch(request);
    if (response.ok) await cache.put(request, response.clone());
    return response;
  } catch (error) {
    const cached = await cache.match(request);
    if (cached) return cached;
    throw error;
  }
}

self.addEventListener('fetch', (event) => {
  if (isSetupReadRequest(event.request)) {
    event.respondWith(networkFirst(event.request));
    return;
  }

  if (event.request.method !== 'GET') return;

  const url = new URL(event.request.url);
  if (url.origin !== self.location.origin) return;

  if (url.pathname.includes('/pick-list')) {
    event.respondWith(
      caches.match(event.request).then((cached) => cached || fetch(event.request))
    );
  }
});
