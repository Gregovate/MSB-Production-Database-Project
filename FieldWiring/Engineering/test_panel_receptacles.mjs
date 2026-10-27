// Execute the incremental migration and real command in an isolated database.
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
 const other=(await cmd('panel',null,{panel_name:'Other panel'})).target_id;
 const circuit=async(parent,n)=>(await cmd('circuit',null,{site_panel_id:parent,circuit_code:String(n)})).target_id;
 const a=await circuit(p,1),b=await circuit(p,3),wrong=await circuit(other,1);
 for(const [id,position] of [[a,1],[b,3]]) {
  const breaker=(await cmd('breaker',null,{site_panel_id:p,breaker_name:String(position),breaker_role:'BRANCH',panel_positions:[position],pole_count:1,rated_amps:20})).target_id;
  await cmd('circuit',id,{site_power_breaker_id:breaker,breaker_pole:1});
 }
 const fields={site_panel_id:p,device_name:'Outlet 1',site_power_circuit_id:a,active:true};
 const request=crypto.randomUUID(),before=rev;
 const first=(await cmd('panel_outlet',null,fields,request)).target_id;
 assert.equal((await cmd('panel_outlet',null,fields,request,undefined,before)).replayed,true);
 await assert.rejects(cmd('panel_outlet',null,{...fields,device_name:'Changed'},request));
 await assert.rejects(cmd('panel_outlet',null,{...fields,device_name:'Stale'},undefined,undefined,before));
 await assert.rejects(cmd('panel_outlet',null,{...fields,device_name:'Forbidden'},undefined,'volunteer@example.test'));
 for(let n=2;n<=6;n++)await cmd('panel_outlet',null,{...fields,device_name:'Outlet '+n,site_power_circuit_id:n%2?a:b});
 let outlets=(await rows('SELECT ref.site_panel_outlet_snapshot() s'))[0].s;
 assert.equal(outlets.length,6);assert.ok(outlets.every(o=>o.site_panel_id===p));
 assert.equal((await rows('SELECT count(*)::int n FROM ref.site_power_device WHERE site_panel_id IS NOT NULL AND site_waypoint_id IS NOT NULL'))[0].n,0);
 await assert.rejects(cmd('panel_outlet',null,{...fields,device_name:'Wrong',site_power_circuit_id:wrong}));
 await assert.rejects(cmd('panel_outlet',null,fields)); // duplicate within same panel
 await assert.rejects(cmd('feed',null,{source_circuit_id:b,destination_device_id:first}));
 await assert.rejects(cmd('device',first,{site_waypoint_id:11}));
 await assert.rejects(cmd('feed',null,{source_device_id:first,destination_waypoint_id:11}));
 await assert.rejects(cmd('panel',p,{active:false}));
 await cmd('panel_outlet',first,{...fields,device_name:'Left receptacle',site_power_circuit_id:b});
 assert.equal((await rows(`SELECT count(*)::int n FROM ref.site_power_feed WHERE destination_device_id=${first} AND NOT active`))[0].n,1);
 const snap=JSON.stringify((await rows('SELECT ref.site_panel_outlet_snapshot() s'))[0].s),saved=rev;
 await db.exec('BEGIN');await cmd('panel_outlet',first,{...fields,active:false});
 await assert.rejects(cmd('panel_outlet',null,{...fields,site_power_circuit_id:wrong}));await db.exec('ROLLBACK');rev=saved;
 assert.equal(JSON.stringify((await rows('SELECT ref.site_panel_outlet_snapshot() s'))[0].s),snap);
 await cmd('panel_outlet',first,{...fields,active:false});
 assert.equal((await rows('SELECT ref.site_panel_outlet_snapshot() s'))[0].s.length,5);
 assert.equal((await rows(`SELECT active FROM ref.site_power_device WHERE site_power_device_id=${first}`))[0].active,false);
 assert.equal((await rows("SELECT has_table_privilege('fieldwiring_app','ref.site_power_device','INSERT,UPDATE,DELETE') p"))[0].p,false);
 console.log('PASS: six panel receptacles, distinct supplies, no fake waypoints, atomic rollback, retry/auth/drift/retirement and bypass guards.');
} finally {await db.close();}
