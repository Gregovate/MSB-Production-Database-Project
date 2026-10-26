import {createFixtureDatabase} from './power_test_database.mjs';
import {readFileSync} from 'node:fs';
import assert from 'node:assert/strict';
const db=await createFixtureDatabase();
const sql=n=>readFileSync(new URL('../../Database/EngineeringTools/sql/'+n,import.meta.url),'utf8');
await db.exec(sql('171_power_snapshot_performance.sql'));
await db.exec(sql('171_equipment_lifecycle.sql'));
const baseline=(await db.query("SELECT ref.site_power_snapshot('crew@example.test') s")).rows[0].s;
await db.exec(sql('171_equipment_catalog.sql'));
const projected=(await db.query("SELECT ref.site_power_snapshot('crew@example.test') s")).rows[0].s;
delete projected.equipment_models;delete projected.equipment_types;for(const d of projected.devices)delete d.equipment_model_id;assert.deepEqual(projected,baseline);
await db.exec(readFileSync(new URL('../../Database/Acceptance/171_equipment_catalog_validation.sql',import.meta.url),'utf8'));
await db.exec(readFileSync(new URL('../../Database/Acceptance/171_cable_result_evidence.sql',import.meta.url),'utf8'));
// Exercise the bounded JSON traversal too; arbitrary fixture code is NOT a mapping.
await db.exec(`ALTER TABLE ops.linkiq_test ADD COLUMN original_result jsonb;
INSERT INTO ops.linkiq_test(test_uuid,test_status_code,tester_original_name,original_result) VALUES(gen_random_uuid(),97,'Fixture only','{"status":{"result":"INFO"},"tests":[{"speed":100}]}'::jsonb);`);
await db.exec(readFileSync(new URL('../../Database/Acceptance/171_cable_result_evidence.sql',import.meta.url),'utf8'));


let rev=0;
async function cmd(kind,fields,email='crew@example.test',uuid=crypto.randomUUID(),revision=rev){const r=(await db.query('SELECT ref.site_power_command($1,$2::uuid,$3,$4,NULL,$5::jsonb) r',[email,uuid,revision,kind,JSON.stringify(fields)])).rows[0].r;rev=r.revision;return r;}
await cmd('equipment_type',{type_name:'Wireless Bridge'});
const model=(await cmd('equipment_model',{device_kind:'CAMERA',model_name:'Field camera'})).target_id;
const uuid=crypto.randomUUID(), prior=rev, fields={equipment_model_id:model,quantity:3,notes:'Setup spares'};
await cmd('equipment_inventory',fields,undefined,uuid);
assert.equal((await cmd('equipment_inventory',fields,undefined,uuid,prior)).replayed,true);
assert.equal((await db.query('SELECT count(*)::integer n FROM ref.site_power_device')).rows[0].n,3);
await assert.rejects(cmd('equipment_inventory',{...fields,quantity:4},undefined,uuid));
for(const quantity of [0,-1,1.5,101,null])await assert.rejects(cmd('equipment_inventory',{...fields,quantity}));
await assert.rejects(cmd('equipment_model',{device_kind:'CAMERA',model_name:' field CAMERA '}));
await assert.rejects(cmd('equipment_type',{type_name:'Camera'}));
for(const type_name of ['CTRL','Controller','Controllers'])await assert.rejects(cmd('equipment_type',{type_name}));
await assert.rejects(cmd('equipment_type',{type_name:'Unauthorized'},'volunteer@example.test'));
await assert.rejects(cmd('equipment_model',{device_kind:'LIGHT_POLE',model_name:'Pole'}));
const snap=(await db.query("SELECT ref.site_power_snapshot('crew@example.test') s")).rows[0].s;
assert.ok(snap.equipment_types.some(t=>t.device_kind==='CAMERA'));
assert.ok(snap.devices.every(d=>d.owner_name==='MSB'&&d.site_waypoint_id===null&&d.equipment_model_id===model));
for(const table of ['site_equipment_type','site_equipment_model'])assert.equal((await db.query(`SELECT has_table_privilege('fieldwiring_app','ref.${table}','INSERT,UPDATE,DELETE') ok`)).rows[0].ok,false);
const ids=snap.devices.map(d=>d.site_power_device_id);
const move=async(id,where,request=crypto.randomUUID(),revision=rev)=>{const r=(await db.query('SELECT ref.site_power_command($1,$2::uuid,$3,$4,$5,$6::jsonb) r',['crew@example.test',request,revision,'equipment_event',id,JSON.stringify({event_kind:'MOVE',to_waypoint_id:where})])).rows[0].r;rev=r.revision;return r;};
await assert.rejects(move(ids[0],10)); // Panel is not an installation location.
const batchRevision=rev;
await db.exec('BEGIN');await move(ids[0],11);await assert.rejects(move(ids[1],10));await db.exec('ROLLBACK');rev=batchRevision;
assert.equal((await db.query('SELECT count(*)::integer n FROM ops.site_equipment_event')).rows[0].n,0);
const moveRequest=crypto.randomUUID(),moveRevision=rev;
await move(ids[0],11,moveRequest);await move(ids[1],11);
assert.equal((await move(ids[0],11,moveRequest,moveRevision)).replayed,true);
assert.equal((await db.query('SELECT count(*)::integer n FROM ops.site_equipment_event')).rows[0].n,2);
await assert.rejects(cmd('equipment_type',{type_name:'Stale'},undefined,crypto.randomUUID(),0));
console.log('Installation eligibility, transaction rollback, distinct unit histories and exact movement retry PASS');
console.log((await db.query("SELECT proname,md5(prosrc) hash FROM pg_proc WHERE oid IN ('ref.site_power_command(text,uuid,bigint,text,bigint,jsonb)'::regprocedure,'ref.site_power_snapshot(text)'::regprocedure)")).rows);
console.log('Shared camera inventory, catalog uniqueness, permissions, quantity, exact retry and stock identities PASS');
await db.close();
