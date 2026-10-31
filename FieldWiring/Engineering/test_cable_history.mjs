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
assert.deepEqual(Array.from(api.pointOptions(parsed),p=>p[1]),['Unresolved label: FE-02','Unresolved label: FE-02B']);
assert.ok(!api.pointOptions(r).some(p=>p[1]==='07-Whoville-WV'));
assert.equal(parsed[0].points[0].value,'label:FE-02B');
const ambiguous=api.rows({...source,network_options:[{network_code:'AUX-A'},{network_code:'Aux A'}]});assert.equal(ambiguous[2].network,'Unresolved');
console.log('Catalog-only networks, source-only test points, unrelated waypoint exclusion, ambiguous network and snapshot cache PASS');

for(const [standard,expected] of [['10BASE-T','10 Mbps'],['100BASE-TX','100 Mbps'],['1000BASE-T','1000 Mbps'],['2.5GBASE-T','2500 Mbps'],['Cat6','Not recorded'],['','Not recorded']])assert.equal(api.speedLabel({test_standard:standard}),expected);
assert.equal(api.speedLabel({measured_link_speed_mbps:1000}),'Not recorded','never substitute unrelated measurement for saved test standard');
console.log('Saved FLW test standard rates, original text and missing/unsupported standards PASS');

assert.equal(api.resultLabel({status_code:1}),'PASS');
assert.equal(api.resultLabel({status_code:6}),'FAIL');
assert.equal(api.resultLabel({status_code:8}),'INFO');
assert.equal(api.resultLabel({status_code:97}),'Not decoded');
assert.equal(api.resultLabel({}),'Not decoded');
assert.equal(api.resultLabel({result:'PASS'}),'PASS');
assert.equal(api.dateLabel('2026-10-13T09:58:00'),'Oct 13, 2026, 9:58 AM');
const aliases=api.rows({...data,waypoints:[{id:1,name:'CC-00',aliases:['Old CC']}],linkiq_evidence:[{test_uuid:'x',source_pair:{endpoint_labels:['Old CC','BELLS']}},{test_uuid:'y',endpoint_a:1,endpoint_b:2}]});
assert.equal(aliases[0].points[0].value,'1');
assert.equal(aliases[0].labels[0],'CC-00');
assert.equal(aliases[0].points[1].label,'Unresolved label: BELLS');
assert.equal(api.pointOptions(aliases).filter(p=>p[0]==='1').length,1);
console.log('Accepted alias deduplication, explicit unresolved labels, local dates and verified FLW result mapping PASS');

// Source-derived anchors match the operator's LinkWare screenshot, not synthetic codes.
const evidence=JSON.parse(readFileSync(new URL('./flw_result_evidence.json',import.meta.url),'utf8'));
for(const t of evidence.anchors)assert.equal(api.resultLabel(t),t.expected_result);
const reverse=api.rows({...data,linkiq_evidence:[
 {test_uuid:'old',cable_id:10,endpoint_a:1,endpoint_b:2,source_pair:{designation:'Aux A'},length_ft:137},
 {test_uuid:'new',cable_id:20,endpoint_a:2,endpoint_b:1,source_pair:{designation:'AUX-A'},length_ft:250},
 {test_uuid:'other',cable_id:10,endpoint_a:1,endpoint_b:2,source_pair:{designation:'AUX-B'}},
 {test_uuid:'missing',cable_id:10,endpoint_a:1,endpoint_b:2}
]});
assert.equal(reverse[0].key,reverse[1].key,'reverse direction/different cable IDs/length do not split a segment');
assert.notEqual(reverse[0].key,reverse[2].key,'same cable ID must not combine networks');
assert.notEqual(reverse[0].key,reverse[3].key,'missing network cannot establish the same segment');
console.log('Original FLW anchors and direction-independent network segment history PASS');

// Preserve source identifiers even when nothing can be matched to a waypoint.
const raw={test_uuid:'opaque-database-uuid',original_name:'BENCH-007',source_pair:{display_label:'Cable 5 ft <shop>'}};
assert.deepEqual(JSON.parse(JSON.stringify(api.sourceIds(raw))),{cableId:'Cable 5 ft <shop>',testId:'BENCH-007'});
assert.match(api.sourceLabel(raw),/Cable 5 ft <shop>.*BENCH-007/);
assert.doesNotMatch(api.sourceLabel(raw),/opaque-database-uuid/);
assert.equal(api.sourceIds({original_name:'Tester only'}).cableId,'');
console.log('FLW Cable ID and Test ID preserved for unresolved records; no invented cable identity PASS');
assert.equal(api.sourceLabel({original_name:'FE-02 SPARE-01',source_pair:{display_label:'FE-02 SPARE-01'}}),'Cable / Test ID: FE-02 SPARE-01');
assert.equal(api.networkLabel({network:'Unresolved',designation:'SPARE-01'}),'Not matched: SPARE-01');
assert.equal(api.networkLabel({network:'AUX-E',designation:'AUX-E'}),'AUX-E');
