// Execute the actual migration using PostgreSQL/WASM, independent of local OS
// users. This synthetic fixture is supplemental; it does not replace the current
// Production-clone/audit/privilege gate. Install @electric-sql/pglite externally.
import fs from 'node:fs';
import assert from 'node:assert/strict';
const {PGlite} = await import(process.env.MSB_PGLITE_MODULE || '@electric-sql/pglite');
const db = new PGlite();
let id = 100;
const uuid = () => '88000000-0000-4000-8000-' + String(++id).padStart(12,'0');
async function record(container, action, time, note, decision, expected, prior, remaining, gps=[], priorClient=null) {
 const key=uuid();
 const sql=decision ? 'ops.record_setup_container_reconciliation' : 'ops.record_setup_movement_event';
 const params=['fixture@example.org',2026,key,'CONTAINER',container,action,time,null,'fixture@example.org','HID_SCAN',false,
 ...[gps[0]??null,gps[1]??null,gps[2]??null],null,note,null,[],null,null,'UNASSESSED',null];
 if(decision) params.push(JSON.stringify({decision,identify_remaining:remaining!==undefined,expected_display_ids:expected,prior_event_id:prior,remaining_display_ids:remaining,prior_client_event_id:priorClient}));
 const query=`SELECT * FROM ${sql}(${params.map((_,i)=>'$'+(i+1)).join(',')})`;
 const result=await db.query(query,params);
 return {...result.rows[0],query,params};
}
const state=async display=>(await db.query('SELECT * FROM ops.setup_display_state WHERE display_id=$1',[display])).rows[0];
async function rejected(callback,pattern) {await assert.rejects(callback,pattern);}
try {
 await db.exec(fs.readFileSync(new URL('setup_88_reconciliation_fixture.sql',import.meta.url),'utf8'));
 await db.exec(fs.readFileSync(new URL('../Database/070_reconcile_setup_container_contents.sql',import.meta.url),'utf8'));
 let prior=await record(95,'CONTAINER_MOVE','2026-10-07T10:00:00Z','15-Church-ParkingLot',null,null,null,null,[43.7,-87.7,3]);
 await record(95,'CONTAINER_MOVE','2026-10-07T10:01:00Z',null,null,null,null,null,[43.701,-87.701,5.12]);
 assert.equal((await db.query('SELECT current_location_note FROM ops.setup_container_state WHERE container_id=95')).rows[0].current_location_note,'15-Church-ParkingLot');
 prior=await record(216,'CONTAINER_MOVE','2026-10-07T11:00:00Z','Prior park drop',null,null,null,null,[43.7,-87.7,3]);
 let partial=await record(216,'CONTAINER_MOVE','2026-10-07T12:00:00Z','New Container drop','NOT_EMPTY',[2,3],prior.setup_movement_event_id,[2],[43.8,-87.8,5.12]);
 assert.equal(partial.unloaded_display_count,1);
 assert.equal((await state(3)).position_mode,'DETACHED');
 assert.equal((await state(2)),undefined);
 let evidence=(await db.query('SELECT e.* FROM ops.setup_movement_event e JOIN ops.setup_display_state ds ON ds.last_movement_event_id=e.setup_movement_event_id WHERE ds.display_id=3')).rows[0];
 assert.equal(evidence.destination_location_note,'Prior park drop');
 assert.equal(evidence.event_type,'TASK_UNLOAD');
 assert.equal(Number(evidence.gps_latitude),43.7);
 assert.match(evidence.notes,/inferred_unload=true/);
 const count=(await db.query('SELECT count(*)::integer n FROM ops.setup_movement_event')).rows[0].n;
 assert.equal((await db.query(partial.query,partial.params)).rows[0].duplicate_event,true);
 assert.equal((await db.query('SELECT count(*)::integer n FROM ops.setup_movement_event')).rows[0].n,count);
 await rejected(()=>record(216,'RETURNED','2026-10-07T13:00:00Z',null,'EMPTY',[2,3],partial.setup_movement_event_id),/changed/);
 await rejected(()=>record(216,'CONTAINER_MOVE','2026-10-07T13:00:00Z','Here','NOT_EMPTY',[2],partial.setup_movement_event_id,[]),/at least one/);
 const returned=await record(216,'RETURNED','2026-10-07T13:00:00Z',null,'EMPTY',[2],partial.setup_movement_event_id);
 evidence=(await db.query('SELECT e.* FROM ops.setup_movement_event e JOIN ops.setup_display_state ds ON ds.last_movement_event_id=e.setup_movement_event_id WHERE ds.display_id=2')).rows[0];
 assert.equal(evidence.destination_location_note,'New Container drop');
 assert.equal(Number(evidence.gps_latitude),43.8);
 assert.equal((await state(3)).last_movement_event_id,partial.unloaded_display_count ? (await db.query('SELECT setup_movement_event_id FROM ops.setup_movement_event WHERE client_event_id=md5($1)::uuid',[partial.params[2]+':3'])).rows[0].setup_movement_event_id:0);
 assert.equal((await db.query('SELECT current_location_note FROM ops.setup_container_state WHERE container_id=216')).rows[0].current_location_note,'RC02-A-01');
 assert.equal((await db.query('SELECT gps_latitude FROM ops.setup_movement_event WHERE setup_movement_event_id=$1',[returned.setup_movement_event_id])).rows[0].gps_latitude,null);
 const bellsDrop=await record(30,'CONTAINER_MOVE','2026-10-07T14:00:00Z','Bells park','NOT_SURE');
 assert.equal(await state(4),undefined);
 await rejected(()=>record(30,'RETURNED','2026-10-07T15:00:00Z',null,null),/reconciliation first/);
 // A later offline return resolves its queued predecessor by client UUID.
 const bellsReturn=await record(30,'RETURNED','2026-10-07T15:10:00Z',null,'EMPTY',[4],null,undefined,[],bellsDrop.params[2]);
 assert.equal(bellsReturn.unloaded_display_count,1);
 for(const [container,display] of [[199,5],[177,6]]) {
  await rejected(()=>record(container,'CONTAINER_MOVE','2026-10-07T15:00:00Z','Here','EMPTY',[display],null),/cannot be emptied/);
  const legacyParams=['fixture@example.org',2026,uuid(),'CONTAINER',container,'CONTAINER_MOVE','2026-10-07T15:00:00Z',null,null,'HID_SCAN',false,null,null,null,null,'Here',null,[display],null,null,'UNASSESSED',null];
  const legacySql=`SELECT * FROM ops.record_setup_movement_event(${legacyParams.map((_,i)=>'$'+(i+1)).join(',')})`;
  await rejected(()=>db.query(legacySql,legacyParams),/stays with its/);
  legacyParams[2]=uuid();legacyParams[3]='DISPLAY';legacyParams[4]=display;legacyParams[5]='DISPLAY_MOVE';legacyParams[17]=[];
  await rejected(()=>db.query(legacySql,legacyParams),/stays with its/);
  await record(container,'CONTAINER_MOVE','2026-10-07T15:00:00Z','Here','NOT_SURE');
 }
 // Multi-Display Pallet remains a valid removable load.
 const multi=await record(149,'CONTAINER_MOVE','2026-10-07T15:30:00Z','Multi park',null);
 const multiEmpty=await record(149,'RETURNED','2026-10-07T15:31:00Z',null,'EMPTY',[7,8],multi.setup_movement_event_id);
 assert.equal(multiEmpty.unloaded_display_count,2);
 // Failure of the final Container command rolls back all child detachments.
 const beforeFailure=(await db.query('SELECT count(*)::integer n FROM ops.setup_movement_event')).rows[0].n;
 await rejected(()=>record(222,'CONTAINER_MOVE','2026-10-07T15:45:00Z',null,'EMPTY',[9],null),/Location evidence is required/);
 assert.equal(await state(9),undefined);
 assert.equal((await db.query('SELECT count(*)::integer n FROM ops.setup_movement_event')).rows[0].n,beforeFailure);
 // Not Empty without identification records review evidence only.
 await record(222,'CONTAINER_MOVE','2026-10-07T15:50:00Z','Unknown contents','NOT_EMPTY');
 assert.equal(await state(9),undefined);
 await db.exec('DELETE FROM ops.setup_container_state WHERE container_id=222');
 // Use another unobserved fixture identity to exercise unresolved location.
 await db.exec("INSERT INTO ref.container VALUES(223,1,'RC07-A-02','No prior'); INSERT INTO ref.display VALUES(11,223,1,'Never observed')");
 const unresolved=await record(223,'RETURNED','2026-10-07T16:00:00Z',null,'EMPTY',[11],null);
 assert.equal(unresolved.unloaded_display_count,1);
 assert.match((await state(11)).current_location_note,/unresolved/);
 // Direct placement detaches exactly the scanned Display; later Container movement cannot move it.
 await db.exec("INSERT INTO ref.container VALUES(224,1,'RC07-A-03','Individual placement'); INSERT INTO ref.display VALUES(12,224,1,'Peace on Earth direct scan'),(13,224,1,'Still on Container')");
 await db.exec('INSERT INTO ref.lor_scene VALUES(1,15); INSERT INTO ref.lor_scene_display VALUES(1,12)');
 const repository=fs.readFileSync(new URL('../Application/setup_movement_repository.py',import.meta.url),'utf8');
 const stageQuery=repository.match(/SELECT s.stage_id, s.stage_key, s.stage_name,[\s\S]*?ORDER BY s.stage_key, s.stage_id/)[0].replace('%s','$1');
 const candidates=(await db.query(stageQuery,[12])).rows;
 assert.deepEqual(candidates.map(stage=>[stage.stage_id,stage.assigned]),[[15,true],[16,false]]);
 const directParams=['fixture@example.org',2026,uuid(),'DISPLAY',12,'DISPLAY_MOVE','2026-10-07T16:10:00Z',null,
   'fixture@example.org','HID_SCAN',false,43.778,-87.749,2,16,'16 · Actual placement elsewhere',
   'display_setup_location_confirmed=true; direct_display_observation=true',[],null,null,'UNASSESSED',null];
 const directQuery=`SELECT * FROM ops.record_setup_movement_event(${directParams.map((_,i)=>'$'+(i+1)).join(',')})`;
 const direct=(await db.query(directQuery,directParams)).rows[0];
 assert.equal((await state(12)).position_mode,'DETACHED');
 assert.equal((await state(12)).current_stage_id,16);
 assert.equal(await state(13),undefined);
 assert.equal((await db.query('SELECT container_id FROM ref.display WHERE display_id=12')).rows[0].container_id,224);
 await record(224,'CONTAINER_MOVE','2026-10-07T16:20:00Z','Later Container location','NOT_SURE');
 assert.equal((await state(12)).last_movement_event_id,direct.setup_movement_event_id);
 assert.equal((await state(12)).current_location_note,'16 · Actual placement elsewhere');
 assert.equal((await db.query(directQuery,directParams)).rows[0].duplicate_event,true);
 // Existing Stage-group unload uses the NEW observed location, not reconciliation's prior anchor.
 await db.exec("INSERT INTO ref.container VALUES(34,1,'RC03-A-04','Stage group fixture'); INSERT INTO ref.display VALUES(14,34,1,'Group member A'),(15,34,1,'Group member B'),(16,34,1,'Next Stage stays attached')");
 await record(34,'CONTAINER_MOVE','2026-10-07T17:00:00Z','Earlier Container drop',null,null,null,null,[43.70,-87.70,3]);
 const groupParams=['fixture@example.org',2026,uuid(),'CONTAINER',34,'CONTAINER_MOVE','2026-10-07T17:10:00Z',null,
  'fixture@example.org','HID_SCAN',false,43.80,-87.80,5.12,null,'Observed group unload here','direct_container_unload=true',[14,15],null,null,'UNASSESSED',null];
 const groupQuery=`SELECT * FROM ops.record_setup_movement_event(${groupParams.map((_,i)=>'$'+(i+1)).join(',')})`;
 const group=(await db.query(groupQuery,groupParams)).rows[0];
 assert.equal(group.unloaded_display_count,2);
 for(const display of [14,15]) {
  assert.equal((await state(display)).position_mode,'DETACHED');
  assert.equal((await state(display)).current_location_note,'Observed group unload here');
  assert.equal((await state(display)).last_movement_event_id,group.setup_movement_event_id);
 }
 assert.equal(await state(16),undefined);
 const groupEvent=(await db.query('SELECT * FROM ops.setup_movement_event WHERE setup_movement_event_id=$1',[group.setup_movement_event_id])).rows[0];
 assert.equal(Number(groupEvent.gps_latitude),43.80);assert.match(groupEvent.notes,/direct_container_unload=true/);
 assert.ok(!groupEvent.notes.includes('inferred_unload=true'));
 await record(34,'CONTAINER_MOVE','2026-10-07T17:20:00Z','Next Stage Container drop','NOT_SURE');
 assert.equal((await state(14)).last_movement_event_id,group.setup_movement_event_id);
 assert.equal((await db.query(groupQuery,groupParams)).rows[0].duplicate_event,true);
 console.log('SETUP_88_LOCAL_POSTGRES_RECONCILIATION_PASS');
} finally {await db.close();}
