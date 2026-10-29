// Disposable browser-logic checks; no actual browser, login or local listener.
const vm = require('node:vm');
const fs = require('node:fs');
const assert = require('node:assert/strict');
const source = fs.readFileSync(__dirname + '/handoff.js', 'utf8');
async function run(hash, authorized, failAt = 0) {
  const status = {}, details = {}, calls = [], handlers = {};
  await vm.runInNewContext(source, {
    document: {querySelector: selector => selector === '#status' ? status : selector === '#handoff-details' ? details : {addEventListener: (event, handler) => { handlers[event] = handler; }}},
    URLSearchParams, location: {hash, pathname:'/lor2db/pc/'},
    navigator: {permissions: {query: async () => ({state:'granted'})}},
    history: {replaceState() {}}, AbortSignal,
    fetch: async (url, options) => {
      calls.push({url, options});
      if (calls.length === failAt) throw new TypeError('Failed to fetch');
      return {status: authorized ? 200 : 403, ok: calls.length === 1 ? authorized : true,
        headers: {get: () => 'application/json'}, json: async () => ({name:'MSB 🎄'})};
    }
  });
  return {status, details, calls, handlers};
}
(async () => {
  let idle = await run('', true);
  assert.equal(idle.calls.length, 0);
  idle.handlers.click();
  assert.match(idle.status.textContent, /If no updater window opens/);
  assert.match(idle.status.textContent, /No previews change/);
  let result = await run('#port=5555&nonce=' + 'a'.repeat(64), true);
  assert.equal(result.calls.length, 2);
  assert.equal(result.calls[0].options.credentials, 'same-origin');
  assert.equal(result.calls[1].options.credentials, 'omit');
  assert.match(result.calls[1].url, /^http:\/\/127\.0\.0\.1:5555\/a{64}$/);
  assert.equal(result.calls[1].options.body, '{"name":"MSB \\ud83c\\udf84"}');
  result = await run('#port=5555&nonce=' + 'a'.repeat(64), false);
  assert.equal(result.calls.length, 1);
  assert.match(result.status.textContent, /No preview update was authorized/);
  result = await run('#port=5555&nonce=' + 'a'.repeat(64), true, 2);
  let diagnostic = JSON.parse(result.details.textContent);
  assert.equal(diagnostic.phase, 'loopback-request');
  assert.equal(diagnostic.sourceHttpStatus, 200);
  assert.equal(diagnostic['loopback-network'], 'granted');
  assert.match(result.status.textContent, /connection to the PC updater/);
  assert.ok(!result.details.textContent.includes('a'.repeat(64)));
  result = await run('#port=5555&nonce=' + 'a'.repeat(64), true, 1);
  assert.equal(JSON.parse(result.details.textContent).phase, 'accepted-source-request');
  assert.match(result.status.textContent, /could not obtain accepted MSB source evidence/);
  result = await run('#port=80&nonce=bad', true);
  assert.equal(result.calls.length, 0);
  console.log('PASS: browser relay success, credentials isolation, ASCII encoding, denied authorization and invalid request');
})();
