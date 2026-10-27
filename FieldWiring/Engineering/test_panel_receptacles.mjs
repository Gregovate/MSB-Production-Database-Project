// Exercise the existing atomic breaker schedule; never create duplicate outlets.
import {createFixtureDatabase} from './power_test_database.mjs';
import {readFileSync} from 'node:fs';
import assert from 'node:assert/strict';
const db=await createFixtureDatabase();
for(const name of ['171_power_snapshot_performance.sql','171_equipment_lifecycle.sql','171_equipment_catalog.sql','171_panel_receptacles.sql'])
 await db.exec(readFileSync(new URL('../../Database/EngineeringTools/sql/'+name,import.meta.url),'utf8'));
await db.exec(readFileSync(new URL('../../Database/Acceptance/171_panel_receptacles_validation.sql',import.meta.url),'utf8'));
let rev=0;
const rows=async(sql)=>(await db.query(sql)).rows;
async function cmd(kind,id,fields,request=crypto.randomUUID(),email='crew@example.test',revision=rev){
 const r=(await db.query('SELECT ref.site_power_command($1,$2::uuid,$3,$4,$5,$6::jsonb) r',[email,request,revision,kind,id,JSON.stringify(fields)])).rows[0].r;rev=r.revision;return r;
}
try {
 const p=(await cmd('panel',null,{panel_name:'PANEL 42-00',site_waypoint_id:10})).target_id;
 const fields={breaker:{site_panel_id:p,breaker_name:'1/3',breaker_role:'BRANCH',panel_positions:[1,3],pole_count:2,rated_amps:20,source_evidence:'Bottom Panel Outlets'},show_desired_state:'ON',restoration_desired_state:'OFF',legs:[{pole:1,circuit_code:'1',waypoint_ids:[]},{pole:2,circuit_code:'3',waypoint_ids:[]}]};
 const id=(await cmd('breaker_schedule',null,fields)).target_id;
 const counts=()=>rows('SELECT (SELECT count(*) FROM ref.site_power_device) devices,(SELECT count(*) FROM ref.site_power_feed) feeds,(SELECT count(*) FROM ref.site_waypoint) waypoints');
 const unchanged=JSON.stringify(await counts());
 // UI edits the existing breaker; an exact retry must not create a second one.
 const edit={...fields,breaker:{...fields.breaker,panel_outlets:true}},request=crypto.randomUUID(),initial=rev;
 await cmd('breaker_schedule',id,edit,request);
 assert.equal((await cmd('breaker_schedule',id,edit,request,undefined,initial)).replayed,true);
 await assert.rejects(cmd('breaker_schedule',id,{...edit,show_desired_state:'OFF'},request));
 await assert.rejects(cmd('breaker_schedule',id,edit,undefined,undefined,initial));
 await assert.rejects(cmd('breaker_schedule',id,edit,undefined,'volunteer@example.test'));
 let detail=(await rows('SELECT ref.site_map_power_details() s'))[0].s;
 assert.equal(detail.breakers[0].panel_outlets,true);
 assert.equal(detail.breakers[0].source_evidence,'Bottom Panel Outlets');
 assert.equal(JSON.stringify(await counts()),unchanged);
 const circuits=await rows('SELECT site_power_breaker_id,circuit_code FROM ref.site_power_circuit ORDER BY site_power_circuit_id');
 assert.deepEqual(circuits.map(c=>c.circuit_code),['1','3']);assert.ok(circuits.every(c=>c.site_power_breaker_id===id));
 assert.equal((await rows('SELECT show_desired_state FROM ref.site_power_breaker'))[0].show_desired_state,'ON');
 await assert.rejects(cmd('breaker',null,{site_panel_id:p,breaker_name:'Main',breaker_role:'MAIN',panel_outlets:true,pole_count:2}));
 // Recorded remote supply can coexist; the designation does not silently erase it.
 const remote={...edit,legs:[{...edit.legs[0],waypoint_ids:[11]},edit.legs[1]]};
 await cmd('breaker_schedule',id,remote);
 const saved=rev;await db.exec('BEGIN');await cmd('breaker',id,{panel_outlets:false});
 await assert.rejects(cmd('breaker',id,{breaker_role:'MAIN',panel_outlets:true}));await db.exec('ROLLBACK');rev=saved;
 assert.equal((await rows('SELECT panel_outlets FROM ref.site_power_breaker'))[0].panel_outlets,true);
 await cmd('breaker_schedule',id,{...remote,breaker:{...remote.breaker,panel_outlets:false}});
 assert.equal((await rows('SELECT panel_outlets FROM ref.site_power_breaker'))[0].panel_outlets,false);
 assert.equal((await rows('SELECT count(*)::int n FROM ref.site_power_feed WHERE active AND destination_waypoint_id=11'))[0].n,1);
 // FLW-only evidence survives without a reviewed physical-cable identity.
 await db.exec("UPDATE ops.linkiq_test SET physical_site_cable_id=NULL");
 detail=(await rows('SELECT ref.site_map_power_details() s'))[0].s;
 assert.equal(detail.flw_tests.length,2);assert.equal(detail.flw_tests[0].network_key,'REG');
 assert.equal(detail.flw_tests[0].physical_site_cable_id,null);
 assert.equal((await rows("SELECT has_table_privilege('fieldwiring_app','ref.site_power_breaker','UPDATE') p"))[0].p,false);
 console.log('PASS: existing breaker designation, notes/circuit/state preservation, no invented inventory, retry/auth/rollback, FLW-only test pairs.');
} finally {await db.close();}
