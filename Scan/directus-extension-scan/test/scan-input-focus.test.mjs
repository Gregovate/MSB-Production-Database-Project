import assert from 'node:assert/strict';
import test from 'node:test';
import vm from 'node:vm';

import scanExtension from '../src/index.js';

class FakeEventTarget {
  constructor() {
    this.listeners = new Map();
    this.style = {};
    this.textContent = '';
    this.value = '';
  }

  addEventListener(type, handler) {
    const handlers = this.listeners.get(type) || [];
    handlers.push(handler);
    this.listeners.set(type, handlers);
  }

  async dispatch(type, event = {}) {
    for (const handler of this.listeners.get(type) || []) {
      await handler(event);
    }
  }
}

async function renderScanHub() {
  const routes = new Map();
  const router = {
    get(path, handler) {
      routes.set(path, handler);
    },
  };
  const response = {
    body: null,
    setHeader() {},
    send(body) {
      this.body = body;
    },
  };

  scanExtension.handler(router, { database: () => undefined });
  await routes.get('/')({}, response);
  return response.body;
}

function executeScanClient(html) {
  const match = html.match(/<script>([\s\S]*?)<\/script>/);
  assert.ok(match, 'Scan hub inline script should be present');

  const document = new FakeEventTarget();
  document.body = { tagName: 'BODY' };
  document.documentElement = { tagName: 'HTML' };
  document.activeElement = document.body;
  document.visibilityState = 'visible';

  const elements = new Map([
    ['scanForm', new FakeEventTarget()],
    ['scanInput', new FakeEventTarget()],
    ['scanBtn', new FakeEventTarget()],
    ['stopBtn', new FakeEventTarget()],
    ['reader', new FakeEventTarget()],
    ['scanStatus', new FakeEventTarget()],
  ]);
  document.getElementById = (id) => elements.get(id);

  const input = elements.get('scanInput');
  input.focusCalls = 0;
  input.focus = () => {
    input.focusCalls += 1;
    document.activeElement = input;
  };

  const window = new FakeEventTarget();
  window.location = { href: '' };
  window.setTimeout = (handler) => {
    handler();
    return 1;
  };

  vm.runInNewContext(match[1], {
    URL,
    alert() {},
    console,
    document,
    navigator: {},
    window,
  });

  return { document, elements, input, window };
}

test('Scan hub actively focuses the HID entry field at startup', async () => {
  const html = await renderScanHub();
  const { document, input } = executeScanClient(html);

  assert.match(html, /id="scanInput"[^>]*autofocus/);
  assert.ok(input.focusCalls >= 2);
  assert.equal(document.activeElement, input);
});

test('first Zebra HID character is retained when the page has no focused control', async () => {
  const html = await renderScanHub();
  const { document, input } = executeScanClient(html);
  document.activeElement = document.body;

  let prevented = false;
  await document.dispatch('keydown', {
    altKey: false,
    ctrlKey: false,
    defaultPrevented: false,
    isComposing: false,
    key: 'C',
    metaKey: false,
    preventDefault() {
      prevented = true;
    },
    target: document.body,
  });

  assert.equal(prevented, true);
  assert.equal(input.value, 'C');
  assert.equal(document.activeElement, input);
});

test('unfocused Zebra Enter submits the captured compact identifier', async () => {
  const html = await renderScanHub();
  const { document, input, window } = executeScanClient(html);
  document.activeElement = document.body;
  input.value = 'CTRL:1031';

  let prevented = false;
  await document.dispatch('keydown', {
    altKey: false,
    ctrlKey: false,
    defaultPrevented: false,
    isComposing: false,
    key: 'Enter',
    metaKey: false,
    preventDefault() {
      prevented = true;
    },
    target: document.body,
  });

  assert.equal(prevented, true);
  assert.equal(window.location.href, '/scan/CTRL/1031');
});

test('page-level HID fallback does not hijack another focused control', async () => {
  const html = await renderScanHub();
  const { document, elements, input } = executeScanClient(html);
  const cameraButton = elements.get('scanBtn');
  document.activeElement = cameraButton;

  let prevented = false;
  await document.dispatch('keydown', {
    altKey: false,
    ctrlKey: false,
    defaultPrevented: false,
    isComposing: false,
    key: 'C',
    metaKey: false,
    preventDefault() {
      prevented = true;
    },
    target: cameraButton,
  });

  assert.equal(prevented, false);
  assert.equal(input.value, '');
  assert.equal(document.activeElement, cameraButton);
});
