import vm from 'node:vm';import {readFileSync} from 'node:fs';import assert from 'node:assert/strict';
const context={window:{}};vm.runInNewContext(readFileSync(new URL('../Application/static/cable_history.js',import.meta.url),'utf8'),context);
const data={network_options:[{network_code:'AUX-A'},{network_code:'AUX-B'}],waypoints:[{id:1,name:'A'},{id:2,name:'B'},{id:99,name:'07-Whoville-WV'}],flw_cable_tests:[],linkiq_evidence:[
 {test_uuid:'a',endpoint_a:1,endpoint_b:2,source_pair:{designation:'Aux A'},test_time:'2026-10-25',status_code:2},
 {test_uuid:'b',endpoint_a:2,endpoint_b:1,source_pair:{designation:'Aux A'},test_time:'1970-02-10',length_ft:100},
 {test_uuid:'c',endpoint_a:1,endpoint_b:2,source_pair:{designation:'Aux B'}},
 {test_uuid:'d'},{test_uuid:'e'}]};
const r=context.window.MSBCableHistory.rows(data);assert.equal(r[0].key,r[1].key);assert.notEqual(r[0].key,r[2].key);assert.notEqual(r[3].key,r[4].key);assert.equal(r[1].reliable,null);assert.equal(r[1].length_ft,100);assert.equal(r[0].status_code,2);assert.equal(r[0].measured_link_speed_mbps,undefined);console.log('Cable identity, reverse endpoints, network separation, unresolved tests, clock defect and unknown speed PASS');

const api=context.window.MSBCableHistory;
const source={...data,linkiq_evidence:[
 {test_uuid:'x',source_pair:{designation:'AUX-1',endpoint_labels:['FE-02B','FE-02']}},
 {test_uuid:'y',source_pair:{designation:'AUX-2',endpoint_labels:['FE-02B','FE-02']}},
 {test_uuid:'z',source_pair:{designation:'Aux A',endpoint_labels:['FE-02B','FE-02']}}
]};
const parsed=api.rows(source);assert.equal(parsed[0].network,'Unresolved');assert.equal(parsed[1].network,'Unresolved');assert.equal(parsed[2].network,'AUX-A');assert.notEqual(parsed[0].key,parsed[1].key);
assert.equal(parsed[0].designation,'AUX-1');assert.equal(api.rows(source),parsed);
assert.deepEqual(Array.from(api.pointOptions(parsed),p=>p[1]),['FE-02','FE-02B']);
assert.ok(!api.pointOptions(r).some(p=>p[1]==='07-Whoville-WV'));
assert.equal(parsed[0].points[0].value,'label:FE-02B');
const ambiguous=api.rows({...source,network_options:[{network_code:'AUX-A'},{network_code:'Aux A'}]});assert.equal(ambiguous[2].network,'Unresolved');
console.log('Catalog-only networks, source-only test points, unrelated waypoint exclusion, ambiguous network and snapshot cache PASS');

for(const [standard,expected] of [['10BASE-T','10 Mbps · 10BASE-T'],['100BASE-TX','100 Mbps · 100BASE-TX'],['1000BASE-T','1000 Mbps · 1000BASE-T'],['2.5GBASE-T','2500 Mbps · 2.5GBASE-T'],['Cat6','Cat6'],['','Not recorded']])assert.equal(api.speedLabel({test_standard:standard}),expected);
assert.equal(api.speedLabel({measured_link_speed_mbps:1000}),'Not recorded','never substitute unrelated measurement for saved test standard');
console.log('Saved FLW test standard rates, original text and missing/unsupported standards PASS');
