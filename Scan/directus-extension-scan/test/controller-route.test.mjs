import assert from 'node:assert/strict';
import test from 'node:test';

import scanExtension from '../src/index.js';

function registeredRoutes() {
  const routes = new Map();
  const router = {
    get(path, handler) {
      routes.set(path, handler);
    },
  };

  scanExtension.handler(router, { database: () => undefined });
  return routes;
}

function responseRecorder() {
  return {
    statusCode: 200,
    body: null,
    redirectTarget: null,
    status(code) {
      this.statusCode = code;
      return this;
    },
    send(body) {
      this.body = body;
      return this;
    },
    redirect(target) {
      this.redirectTarget = target;
      return this;
    },
  };
}

test('CTRL route hands permanent identity to Controller Inventory', async () => {
  const handler = registeredRoutes().get('/CTRL/:key');
  const response = responseRecorder();

  assert.equal(typeof handler, 'function');
  await handler({ params: { key: '1014' } }, response);

  assert.equal(response.statusCode, 200);
  assert.equal(
    response.redirectTarget,
    'https://my.sheboyganlights.org/fieldwiring/controllers?controller_id=1014',
  );
});

test('CTRL route rejects a nonnumeric Controller identity', async () => {
  const handler = registeredRoutes().get('/CTRL/:key');
  const response = responseRecorder();

  await handler({ params: { key: 'not-a-controller' } }, response);

  assert.equal(response.statusCode, 400);
  assert.match(response.body, /Expected CTRL:/);
  assert.equal(response.redirectTarget, null);
});
