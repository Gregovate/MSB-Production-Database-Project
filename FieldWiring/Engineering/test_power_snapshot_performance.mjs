// Compare actual deployed and candidate functions against the same isolated database.
import {createFixtureDatabase} from './power_test_database.mjs';
import {populatePowerScale} from './power_scale_fixture.mjs';
import {readFileSync} from 'node:fs';
import assert from 'node:assert/strict';
import {execFileSync} from 'node:child_process';
import {fileURLToPath} from 'node:url';
const db=await createFixtureDatabase();
const migration=readFileSync(new URL('../../Database/EngineeringTools/sql/171_power_snapshot_performance.sql',import.meta.url),'utf8');
const canonical=value=>Array.isArray(value)?value.map(canonical).sort((a,b)=>JSON.stringify(a).localeCompare(JSON.stringify(b))):value&&typeof value==='object'?Object.fromEntries(Object.keys(value).sort().map(k=>[k,canonical(value[k])])):value;
const snapshot=async name=>(await db.query(`SELECT ref.${name}('crew@example.test') data`)).rows[0].data;
try {
 const definition=(await db.query("SELECT pg_get_functiondef('ref.site_power_snapshot(text)'::regprocedure) definition")).rows[0].definition;
 await db.exec(definition.replace('ref.site_power_snapshot(', 'ref.fixture_snapshot_baseline('));
 const attributes=()=>db.query("SELECT proowner,proacl,prosecdef,provolatile,proconfig FROM pg_proc WHERE oid='ref.site_power_snapshot(text)'::regprocedure");
 const beforeAttributes=await attributes();
 await populatePowerScale(db);
 const baseline=await snapshot('fixture_snapshot_baseline');
 for(const [key,count] of Object.entries({panels:17,breakers:83,circuits:139,waypoints:240,load_lineage:1091,network_requirements:182,placement_eligibility:890,linkiq_evidence:517,flw_cable_tests:475,history:400})) assert.equal(baseline[key].length,count,key);
 await db.exec(migration);
 assert.deepEqual(await attributes(),beforeAttributes,'owner, grants, security, stability and search path unchanged');
 const candidate=await snapshot('site_power_snapshot');
 assert.deepEqual(canonical(candidate),canonical(baseline),'all snapshot content/multiplicity, not just counts');
 assert.deepEqual(candidate.waypoints,baseline.waypoints,'waypoint ordering and aliases');
 const scoped=JSON.parse(execFileSync('python',['-c',"import sys,json;from power_capture import controller_snapshot;json.dump(controller_snapshot(json.load(sys.stdin)),sys.stdout)"],{input:JSON.stringify(candidate),env:{...process.env,PYTHONPATH:fileURLToPath(new URL('../Application',import.meta.url))}}));
 assert.equal(scoped.revision,candidate.revision);
 assert.deepEqual(scoped.access,candidate.access);
 for(const [key,rows] of Object.entries(scoped).filter(([,v])=>Array.isArray(v))) {
  assert.equal(rows.length,candidate[key].length,`${key}: no filtering or deduplication`);
  rows.forEach((row,i)=>{for(const [field,value] of Object.entries(row))assert.deepEqual(value,candidate[key][i][field],`${key}.${field}`);});
 }
 for(const [key,count] of Object.entries({waypoints:240,network_requirements:182,placement_eligibility:890}))assert.equal(scoped[key].length,count);
 for(const key of ['flw_cable_tests','linkiq_evidence','history','breaker_impacts','equipment_events'])assert.equal(key in scoped,false);
 const fullBytes=Buffer.byteLength(JSON.stringify(candidate)), scopedBytes=Buffer.byteLength(JSON.stringify(scoped));
 assert.ok(scopedBytes < fullBytes * 0.3,'controller payload must omit at least 70% of the scale-fixture bytes');
 console.log(JSON.stringify({fixture:'synthetic Production-scale counts; not measured field latency',fullBytes,scopedBytes,reductionPercent:Math.round(100*(1-scopedBytes/fullBytes))}));

 await db.exec(readFileSync(new URL('../../Database/Acceptance/171_power_snapshot_performance_validation.sql',import.meta.url),'utf8'));
 for(const email of ['crew@example.test','manager@example.test','volunteer@example.test']) {
  const rows=(await db.query('SELECT ref.fixture_snapshot_baseline($1) old,ref.site_power_snapshot($1) new',[email])).rows[0];
  assert.deepEqual(canonical(rows.new),canonical(rows.old));
 }
 for(const email of ['inactive@example.test','norole@example.test','missing@example.test']) {
  for(const name of ['fixture_snapshot_baseline','site_power_snapshot']) await assert.rejects(db.query(`SELECT ref.${name}($1)`,[email]),e=>e.code==='42501');
 }
 // Duplicate dictionary keys, unresolved LOR evidence, source ambiguity, and aliases
 // must preserve the original eligibility/access semantics even after evidence changes.
 await db.exec(`INSERT INTO ref.site_network VALUES(3,'reg','LOR');
 INSERT INTO ref.site_waypoint_alias VALUES(12,'accepted alias','fixture',now()),(12,'unaccepted',NULL,NULL);
 INSERT INTO ops.linkiq_intake_review(source_sha256,test_uuid,proposal) VALUES('conflict',md5('test-1')::uuid,'{"endpoint_candidates":[[11],[99]],"designation":"AUX-A","reasons":[]}');`);
 assert.deepEqual(canonical(await snapshot('site_power_snapshot')),canonical(await snapshot('fixture_snapshot_baseline')));
 await db.exec('DELETE FROM ref.site_network WHERE site_network_id=3');
 const timings={};
 for(const name of ['fixture_snapshot_baseline','site_power_snapshot']) {
  const samples=[];
  for(let i=0;i<3;i++){const start=performance.now();await snapshot(name);samples.push(Math.round(performance.now()-start));}
  timings[name]=samples;
 }
 console.log(JSON.stringify({fixture:'synthetic PGlite; not Production latency',counts:Object.fromEntries(Object.entries(baseline).filter(([,v])=>Array.isArray(v)).map(([k,v])=>[k,v.length])),milliseconds:timings}));
 await assert.rejects(db.exec(migration),/Unexpected site_power_snapshot baseline/);
 await db.exec('ROLLBACK');
 console.log('PASS: complete content equivalence, exact scale counts, authorization, function attributes, changed evidence and replay refusal');
} finally {await db.close();}
