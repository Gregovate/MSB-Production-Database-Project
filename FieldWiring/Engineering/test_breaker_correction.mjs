// Execute actual incremental migration and command against disposable PostgreSQL.
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {createFixtureDatabase} from './power_test_database.mjs';
const db=await createFixtureDatabase();
let rev=0;
async function cmd(kind,id,fields,request=crypto.randomUUID(),email='crew@example.test',revision=rev) {
 const r=(await db.query('select ref.site_power_command($1,$2::uuid,$3,$4,$5,$6::jsonb) r',[email,request,revision,kind,id,JSON.stringify(fields)])).rows[0].r;
 rev=r.revision; return r;
}
const rows=async sql=>(await db.query(sql)).rows;
const schedule=(panel,positions)=>({breaker:{site_panel_id:panel,breaker_name:positions.join('/'),breaker_role:'BRANCH',panel_positions:positions,pole_count:positions.length,rated_amps:20,source_evidence:'Mistaken entry correction'},legs:positions.map((p,i)=>({pole:i+1,circuit_code:String(p),waypoint_ids:[]})),show_desired_state:'ON',restoration_desired_state:'OFF'});
const fingerprint=async()=>JSON.stringify(await rows("select (select jsonb_agg(c order by site_power_circuit_id) from ref.site_power_circuit c) c,(select jsonb_agg(b order by site_power_breaker_id) from ref.site_power_breaker b) b,(select revision from ref.site_power_revision) revision,(select count(*) from ops.site_power_edit_log) audits"));
try {
 const panel=(await cmd('panel',null,{panel_name:'FC-00',branch_position_count:8})).target_id;
 const b=(await cmd('breaker_schedule',null,schedule(panel,[2,4]))).target_id;
 let legs=await rows(`select * from ref.site_power_circuit where site_power_breaker_id=${b} order by breaker_pole`);
 await cmd('circuit',legs[0].site_power_circuit_id,{description:'Right panel outlet'});
 const req=crypto.randomUUID(),before=rev;
 await cmd('breaker_schedule',b,schedule(panel,[2]),req);
 assert.equal((await cmd('breaker_schedule',b,schedule(panel,[2]),req,'crew@example.test',before)).replayed,true);
 let now=await rows(`select * from ref.site_power_circuit where site_power_breaker_id=${b} order by breaker_pole`);
 assert.equal(now[0].site_power_circuit_id,legs[0].site_power_circuit_id);assert.equal(now[0].description,'Right panel outlet');assert.equal(now[1].active,false);
 // Retired circuit 4 no longer reserves its designation; historical ID remains distinct.
 const newB=(await cmd('breaker_schedule',null,schedule(panel,[4]))).target_id;
 assert.notEqual((await rows(`select site_power_circuit_id id from ref.site_power_circuit where site_power_breaker_id=${newB}`))[0].id,legs[1].site_power_circuit_id);
 // A later occupied-position failure must roll back earlier automatic leg retirement.
 const two=(await cmd('breaker_schedule',null,schedule(panel,[5,7]))).target_id;
 let prior=await fingerprint();await assert.rejects(()=>cmd('breaker_schedule',two,schedule(panel,[4])),/occupied/);assert.equal(await fingerprint(),prior);
 // Active dependencies on either leg block all topology reduction/removal.
 const twoLegs=await rows(`select site_power_circuit_id id from ref.site_power_circuit where site_power_breaker_id=${two} order by breaker_pole`);
 const feed=(await cmd('feed',null,{source_circuit_id:twoLegs[0].id,destination_waypoint_id:11})).target_id;
 prior=await fingerprint();
 await assert.rejects(()=>cmd('breaker_schedule',two,schedule(panel,[5])),/feed/);
 await assert.rejects(()=>cmd('breaker_remove',two,{}),/feed/);assert.equal(await fingerprint(),prior);
 const cp=(await cmd('controller_power_connection',null,{controller_id:101,site_waypoint_id:11,site_power_circuit_id:twoLegs[0].id})).target_id;
 await assert.rejects(()=>cmd('breaker_remove',two,{}),/controller 101/);
 await cmd('controller_power_connection',cp,{active:false});
 await cmd('feed',feed,{active:false});
 const conductor=(await cmd('conductor',null,{site_cable_id:1,conductor_label:'fixture hot',conductor_role:'HOT'})).target_id;
 const membership=(await cmd('conductor_circuit',null,{site_power_conductor_id:conductor,site_power_circuit_id:twoLegs[1].id})).target_id;
 await assert.rejects(()=>cmd('breaker_remove',two,{}),/conductor membership/);
 await cmd('conductor_circuit',membership,{active:false});
 const remote=(await cmd('panel',null,{panel_name:'remote',supply_panel_id:panel,supply_breaker_id:two})).target_id;
 await assert.rejects(()=>cmd('breaker_remove',two,{}),/remote panel remote/);
 await cmd('panel',remote,{supply_breaker_id:null});
 const action=(await cmd('action',null,{site_power_breaker_id:two,action_name:'Verify outlet',phase:'SETUP',action_kind:'OTHER'})).target_id;
 await assert.rejects(()=>cmd('breaker_remove',two,{}),/activity Verify outlet/);
 await cmd('action',action,{active:false});
 // State events survive removal; automatic action is retired, not deleted.
 await cmd('breaker_state',two,{season_year:2026,phase:'SETUP',condition:'OFF',observed_at:'2026-10-25T12:00:00Z'});
 const history=JSON.stringify(await rows('select * from ops.setup_power_activity_event order by event_id'));
 const auto=(await rows(`select site_power_action_id id from ref.site_power_action where site_power_breaker_id=${two} and active`))[0].id;
 const dependent=(await cmd('action',null,{site_panel_id:panel,action_name:'Dependent',phase:'SETUP',action_kind:'OTHER',prerequisite_action_ids:[auto]})).target_id;
 await assert.rejects(()=>cmd('breaker_remove',two,{}),/dependent activity/);
 await cmd('action',dependent,{active:false});
 const removeReq=crypto.randomUUID(),removeRev=rev;
 await cmd('breaker_remove',two,{},removeReq);
 assert.equal((await cmd('breaker_remove',two,{},removeReq,'crew@example.test',removeRev)).replayed,true);
 assert.equal(JSON.stringify(await rows('select * from ops.setup_power_activity_event order by event_id')),history);
 assert.equal((await rows(`select count(*)::int n from ref.site_power_circuit where site_power_breaker_id=${two} and active`))[0].n,0);
 await cmd('breaker_schedule',null,schedule(panel,[5,7]));
 await assert.rejects(()=>cmd('breaker_remove',b,{},crypto.randomUUID(),'volunteer@example.test'),/access/);
 await assert.rejects(()=>cmd('breaker_remove',b,{},crypto.randomUUID(),'crew@example.test',0),/Reload/);
 await assert.rejects(()=>cmd('breaker_remove',b,{active:false}),/replacement fields/);
 await assert.rejects(()=>cmd('breaker_remove',b,{},removeReq),/different content/);
 // Migration replay fails closed and changes no business rows.
 prior=await fingerprint();await assert.rejects(()=>db.exec(readFileSync('Database/EngineeringTools/sql/171_unassigned_breaker_correction.sql','utf8')),/baseline/);await db.exec('ROLLBACK');assert.equal(await fingerprint(),prior);
 await db.exec(readFileSync('Database/Acceptance/171_unassigned_breaker_correction_validation.sql','utf8'));
 console.log('PASS: correction/removal, freed positions/numbers, retained IDs/notes/events, dependency blockers, rollback, authorization, stale revision, exact retry and migration replay denial');
 console.log('Command MD5:',(await rows("select md5(prosrc) hash from pg_proc where oid='ref.site_power_command(text,uuid,bigint,text,bigint,jsonb)'::regprocedure"))[0].hash);
} finally {await db.close();}
