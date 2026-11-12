// Run with: node --test FieldWiring/Application/test_controller_uid_explorer.mjs
// Tests the shipped browser source without changing it or contacting Production.
import { readFileSync } from 'node:fs';
import { join, dirname } from 'node:path';
import { fileURLToPath } from 'node:url';
import { runInNewContext } from 'node:vm';
import test from 'node:test';
import assert from 'node:assert/strict';

const here = dirname(fileURLToPath(import.meta.url));
const source = readFileSync(join(here, 'static/controllers_planner_v2.js'), 'utf8');
const instrumented = source.replace(
  '  install();\n})();',
  '  return {uniqueNetworks,lorUsage,candidates,setOptions(x){options=x;}};\n})();'
);
assert.notEqual(instrumented, source, 'source harness anchor must remain current');
const helpers = runInNewContext(instrumented, { document: {querySelector:()=>({})} });
helpers.setOptions({
  planning_lor_uid_usage: [
    {network:'regular',uid_hex:'20',display_name:'Display A'},
    {network:'Regular',uid_hex:'21',display_name:'Display B'},
    {network:'Aux K',uid_hex:'20',display_name:'Display C'}
  ],
  planning_controller_programming: [
    {lor_network:'REGULAR',lor_uid_start:34,lor_uid_end:34,controller_status_name:'DEPLOYED'},
    {lor_network:'regular',lor_uid_start:40,lor_uid_end:43,controller_status_name:'AVAILABLE',controller_id:1200}
  ]
});

test('Regular is one network across spelling variations',()=>{
  assert.equal(helpers.uniqueNetworks(['Regular','regular','Aux K']).join('|'),'Aux K|Regular');
  assert.equal(helpers.lorUsage('Regular').size,2);
  assert.equal(helpers.lorUsage('Aux K').size,1);
});

for(const width of [2,4,8,16]) {
  test(`contiguous width ${width}: no used LOR or deployed overlap`,()=>{
    const blocks=helpers.candidates('Regular',width);
    assert.ok(blocks.length>0);
    assert.ok(blocks.every(b=>b.end-b.start+1===width && b.end<=240));
    assert.ok(blocks.every(b=>b.end<32 || b.start>33)); // LOR 20-21 hex
    assert.ok(blocks.every(b=>b.end<34 || b.start>34)); // deployed physical
  });
}

test('AVAILABLE shelf programming remains candidate evidence, not blocking conflict',()=>{
  assert.ok(helpers.candidates('Regular',4).some(b=>b.start===40 && b.stock.length===1));
});

test('no candidate UID outside the governed hex 01-F0 range',()=>{
  assert.ok(helpers.candidates('Regular',2).every(b=>b.start>=1 && b.end<=240));
});
