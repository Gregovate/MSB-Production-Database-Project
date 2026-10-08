// Engineering-only PostgreSQL/WASM check; not a workstation requirement.
// PGLITE_MODULE must point to an installed @electric-sql/pglite module.
import { pathToFileURL, fileURLToPath } from 'node:url';
import { resolve, dirname } from 'node:path';
import { spawnSync } from 'node:child_process';
const { PGlite } = await import(pathToFileURL(resolve(process.env.PGLITE_MODULE)).href);
const root = resolve(dirname(fileURLToPath(import.meta.url)), '../..');
import { readFileSync } from 'node:fs';
import assert from 'node:assert/strict';
const db = new PGlite();
await db.exec(`CREATE SCHEMA ops; CREATE SCHEMA ref;
CREATE TABLE ops.setup_session(setup_session_id int,season_year int,session_status text);
CREATE TABLE ref.container_type(container_type_id int,container_type_name text);
CREATE TABLE ref.container(container_id int,description text,container_type_id int);
CREATE TABLE ref.stage(stage_id int,stage_name text);
CREATE TABLE ref.display_status(display_status_id int,display_status_name text);
CREATE TABLE ref.display(display_id int,display_name text,container_id int,display_status_id int);
CREATE TABLE ops.setup_container_state(setup_session_id int,container_id int,movement_status text,last_movement_event_id int,current_stage_id int,current_location_note text);
CREATE TABLE ops.setup_display_state(setup_session_id int,display_id int,position_mode text,last_movement_event_id int,current_stage_id int,current_location_note text);
CREATE TABLE ops.setup_movement_event(setup_movement_event_id int,setup_session_id int,event_type text,container_id int,destination_stage_id int,destination_location_note text,occurred_at timestamptz,received_at timestamptz,captured_operator_email text,capture_method text,offline_captured boolean,gps_latitude numeric,gps_longitude numeric,gps_accuracy_m numeric,client_event_id text,notes text);
CREATE TABLE ops.setup_movement_event_display(setup_movement_event_id int,display_id int,movement_effect text);
INSERT INTO ops.setup_session VALUES (2,2026,'PLANNING'),(1,2025,'COMPLETE');
-- Synthetic IDs deliberately differ from governed Kit Box ID 2; no production mapping is assumed.
INSERT INTO ref.container_type VALUES (1,'Display Pallet'),(2,'Standalone Display');
INSERT INTO ref.container VALUES (216,'C216',1),(177,'C177',2),(300,'Empty test',1);
INSERT INTO ref.display_status VALUES (1,'ACTIVE'),(2,'INACTIVE');
INSERT INTO ref.display VALUES (850,'CH-PeaceOnEarth',216,1),(6,'MtPanel',216,1),(7,'Still onboard',216,1),(50,'Standalone',177,1),(999,'Unassigned',NULL,1),(1000,'Inactive',216,2);
INSERT INTO ops.setup_movement_event VALUES
(48,2,'CONTAINER_MOVE',216,NULL,'15-Church-Bells-CH','2026-10-06 13:24Z','2026-10-06 13:24Z','captain','CAMERA_SCAN',false,NULL,NULL,NULL,'48','named'),
(122,2,'CONTAINER_MOVE',216,NULL,NULL,'2026-10-06 20:03Z','2026-10-06 20:03Z','captain','HID_SCAN',false,43,-87,4,'122',''),
(200,2,'CONTAINER_MOVE',216,NULL,NULL,'2026-10-07 15:00Z','2026-10-07 15:00Z','captain','HID_SCAN',false,43,-87,3.048,'200','contents_review_required=true'),
(201,2,'CONTAINER_MOVE',177,NULL,'Earlier offline stop','2026-10-05 15:00Z','2026-10-07 16:00Z','other','HID_SCAN',true,43,-87,3,'201',''),
(202,2,'CONTAINER_MOVE',216,NULL,NULL,'2026-10-08 15:00Z','2026-10-08 15:00Z','captain','HID_SCAN',false,43,-87,3,'202','');
INSERT INTO ops.setup_movement_event_display VALUES (48,850,'UNLOADED'),(122,6,'UNLOADED'),(201,50,'UNLOADED');
INSERT INTO ops.setup_display_state VALUES (2,850,'DETACHED',48,NULL,'15-Church-Bells-CH'),(2,6,'DETACHED',122,NULL,NULL),(2,50,'DETACHED',201,NULL,'Earlier offline stop');
INSERT INTO ops.setup_container_state VALUES (2,216,'MOVED',202,NULL,NULL),(2,177,'MOVED',201,NULL,'Earlier offline stop');`);

await db.exec("ALTER TABLE ref.container ADD COLUMN location_code text; ALTER TABLE ref.stage ADD COLUMN stage_key text; ALTER TABLE ops.setup_movement_event ADD COLUMN gps_quality text; ALTER TABLE ops.setup_movement_event ADD COLUMN gps_fix_age_ms int;");
await db.exec(`ALTER TABLE ref.container_type ADD COLUMN private_notes text;
CREATE ROLE fieldwiring_app;
GRANT USAGE ON SCHEMA ref,ops TO fieldwiring_app;
GRANT SELECT ON ops.setup_session,ops.setup_movement_event,
 ops.setup_movement_event_display,ops.setup_container_state,
 ops.setup_display_state,ref.container,ref.display,ref.stage,ref.display_status
 TO fieldwiring_app;`);
const extracted = spawnSync(process.env.PYTHON || 'python3', ['-c', `
import ast,json,sys
from pathlib import Path
f=next(n for n in ast.parse(Path(sys.argv[1]).read_text()).body
       if isinstance(n,ast.FunctionDef) and n.name=='movement_picture')
print(json.dumps([n.args[0].value for n in ast.walk(f)
 if isinstance(n,ast.Call) and isinstance(n.func,ast.Attribute)
 and n.func.attr=='execute' and isinstance(n.args[0],ast.Constant)]))
`, resolve(root,'Setup/Application/setup_production_report.py')], {encoding:'utf8'});
assert.equal(extracted.status,0,extracted.stderr);
const queries=JSON.parse(extracted.stdout);
assert.equal(queries.length,6);
const before=(await db.query(`SELECT jsonb_agg(to_jsonb(t)) AS data FROM ref.container_type t`)).rows;
await db.exec('SET ROLE fieldwiring_app');
await assert.rejects(db.query(queries[4].replace('%s','$1'),[2]),
 /permission denied for table container_type/);
await db.exec('RESET ROLE');
await db.exec(readFileSync(resolve(root,'Setup/Database/071_grant_setup_container_type_report_read.sql'),'utf8'));
assert.deepEqual((await db.query(`SELECT jsonb_agg(to_jsonb(t)) AS data FROM ref.container_type t`)).rows,before);
await db.exec('SET ROLE fieldwiring_app');
// The added read scope is two columns, not all table columns or any DML.
await assert.rejects(db.query('SELECT private_notes FROM ref.container_type'),/permission denied/);
for (const sql of ['INSERT INTO ref.container_type VALUES (9,\'bad\',NULL)',
 'UPDATE ref.container_type SET container_type_name=\'bad\'',
 'DELETE FROM ref.container_type', 'TRUNCATE ref.container_type']) {
 await assert.rejects(db.exec(sql), /permission denied/);
}
await db.exec('BEGIN TRANSACTION ISOLATION LEVEL REPEATABLE READ READ ONLY');
const sets=[];
for (const sql of queries){
 if(sql.startsWith('SET')){await db.exec(sql);continue;}
 let bind=0; sets.push((await db.query(sql.replaceAll('%s',()=> '$'+(++bind)),[2])).rows);
}
assert.equal(sets.length,4);
assert.equal(sets[0][0].through_event_id,202);
assert.equal(sets[1].length,5);
assert.equal(sets[2].length,2);
assert.equal(sets[3].length,5);
assert.equal(sets[1].find(e=>e.setup_movement_event_id===200).display_id,null);
assert.equal(sets[3].find(d=>d.display_id===7).position_mode,'WITH_CONTAINER');
assert.equal(sets[3].find(d=>d.display_id===999).position_mode,'NO_ASSIGNED_CONTAINER');
await db.exec('ROLLBACK'); await db.close();
console.log('PASS: reproduced denied Container-type read; actual migration grants two columns only; all six exact report statements pass READ ONLY as fieldwiring_app; private column and INSERT/UPDATE/DELETE/TRUNCATE denied; type data unchanged.');
