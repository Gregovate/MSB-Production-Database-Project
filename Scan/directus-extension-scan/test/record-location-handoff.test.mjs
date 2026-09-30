import fs from 'node:fs';
import test from 'node:test';
import assert from 'node:assert/strict';

const src = fs.readFileSync(new URL('../src/index.js', import.meta.url), 'utf8');
const dist = fs.readFileSync(new URL('../dist/index.js', import.meta.url), 'utf8');

test('resolved Display and Container pages offer explicit Record Location handoff', () => {
  for (const text of [src, dist]) {
    assert.match(text, /setup\/record-location\/\?asset=DISP:/);
    assert.match(text, /setup\/record-location\/\?asset=CONT:/);
    assert.match(text, />Record Location</);
  }
});

test('normal Scan routes remain the identity hub', () => {
  assert.match(src, /router\.get\('\/DISP\/:key'/);
  assert.match(src, /router\.get\('\/CONT\/:key'/);
  assert.match(src, /Field Wiring/);
  assert.match(src, /Procedures/);
  assert.match(src, /Open Work Orders/);
});
