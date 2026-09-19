import assert from 'node:assert/strict';
import fs from 'node:fs';
import test from 'node:test';

import scanExtension from '../src/index.js';

async function renderRoute(path) {
  const routes = new Map();
  const router = {
    get(routePath, handler) {
      routes.set(routePath, handler);
    },
  };

  let databaseCalled = false;
  const response = {
    body: null,
    headers: new Map(),
    setHeader(name, value) {
      this.headers.set(String(name).toLowerCase(), value);
    },
    send(body) {
      this.body = body;
    },
  };

  scanExtension.handler(router, {
    database() {
      databaseCalled = true;
      throw new Error('field-test route must not query the database');
    },
  });

  const handler = routes.get(path);
  assert.ok(handler, 'expected route ' + path + ' to be registered');
  await handler({}, response);

  return { response, databaseCalled };
}

test('field acceptance route is read-only and contains no database dependency', async () => {
  const { response, databaseCalled } = await renderRoute('/field-test');

  assert.equal(databaseCalled, false);
  assert.match(response.body, /READ-ONLY ENGINEERING TEST/);
  assert.match(response.body, /does not change Setup movement state or write test observations to PostgreSQL/i);
  assert.equal(response.headers.get('cache-control'), 'no-store');
});

test('field acceptance route exercises real browser GPS and HID capture primitives', async () => {
  const { response } = await renderRoute('/field-test');

  assert.match(response.body, /navigator\.geolocation\.watchPosition/);
  assert.match(response.body, /enableHighAccuracy:\s*true/);
  assert.match(response.body, /localStorage\.setItem/);
  assert.match(response.body, /document\.addEventListener\('keydown'/);
  assert.match(response.body, /Verify normal Scan route/);
});

test('field acceptance route preserves current GPX reference provenance and named candidates', async () => {
  const { response } = await renderRoute('/field-test');

  assert.match(response.body, /2026_msb\.gpx/);
  assert.match(response.body, /ExpertGPS 9\.34 using Garmin GPSMAP 66sr/);
  assert.match(response.body, /03a-Mega Cube-MC/);
  assert.match(response.body, /23-Peanuts-PN/);
  assert.match(response.body, /24-Traditional Christmas-TC/);
  assert.match(response.body, /30-Santa's Station Entrance/);

  const referenceCount = (response.body.match(/"name":/g) || []).length;
  assert.equal(referenceCount, 31);
});

test('scan source and deployed dist candidate remain byte-identical', () => {
  const src = fs.readFileSync(new URL('../src/index.js', import.meta.url), 'utf8');
  const dist = fs.readFileSync(new URL('../dist/index.js', import.meta.url), 'utf8');
  assert.equal(src, dist);
});
