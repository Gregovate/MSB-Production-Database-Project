import vm from 'node:vm';import {readFileSync} from 'node:fs';import assert from 'node:assert/strict';
const context={window:{}};vm.runInNewContext(readFileSync(new URL('../Application/static/cable_history.js',import.meta.url),'utf8'),context);
const data={waypoints:[{id:1,name:'A'},{id:2,name:'B'}],flw_cable_tests:[],linkiq_evidence:[
 {test_uuid:'a',endpoint_a:1,endpoint_b:2,source_pair:{designation:'Aux A'},test_time:'2026-10-25',status_code:2},
 {test_uuid:'b',endpoint_a:2,endpoint_b:1,source_pair:{designation:'Aux A'},test_time:'1970-02-10',length_ft:100},
 {test_uuid:'c',endpoint_a:1,endpoint_b:2,source_pair:{designation:'Aux B'}},
 {test_uuid:'d'},{test_uuid:'e'}]};
const r=context.window.MSBCableHistory.rows(data);assert.equal(r[0].key,r[1].key);assert.notEqual(r[0].key,r[2].key);assert.notEqual(r[3].key,r[4].key);assert.equal(r[1].reliable,null);assert.equal(r[1].length_ft,100);assert.equal(r[0].status_code,2);assert.equal(r[0].measured_link_speed_mbps,undefined);console.log('Cable identity, reverse endpoints, network separation, unresolved tests, clock defect and unknown speed PASS');
