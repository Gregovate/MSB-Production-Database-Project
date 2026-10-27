// Actual pending migration on an isolated PostgreSQL fixture, never Production.
import {PGlite} from '@electric-sql/pglite';
import fs from 'node:fs';
import assert from 'node:assert/strict';
const db=new PGlite();
try {
 await db.exec(fs.readFileSync('Setup/Acceptance/setup_88_reconciliation_fixture.sql','utf8'));
 await db.exec(`ALTER TABLE ops.setup_movement_event RENAME CONSTRAINT fixture_event_type TO ck_setup_movement_event_type;
 CREATE TABLE ref.controller(controller_id integer PRIMARY KEY,current_location_code text);
 INSERT INTO ref.controller VALUES(1001,'Workshop'),(1002,'Workshop');
 CREATE OR REPLACE FUNCTION ref.setup_movement_actor(email text) RETURNS TABLE(directus_user_id uuid,person_id integer,display_name text)
 LANGUAGE plpgsql AS $$ BEGIN IF email <> 'fixture@example.org' THEN RAISE EXCEPTION 'Not authorized' USING ERRCODE='42501'; END IF;
 RETURN QUERY SELECT '88000000-0000-4000-8000-000000000001'::uuid,1,'Fixture'::text; END $$;`);
 await db.exec(fs.readFileSync('Setup/Database/077_add_setup_controller_location.sql','utf8'));
 const base=['fixture@example.org',2026,'88000000-0000-4000-8000-000000001001','CONTROLLER',1001,'CONTROLLER_MOVE','2026-10-26T14:00:00Z',null,'fixture@example.org','HID_SCAN',false,43.7,-87.7,5,null,'Park arrival',null,[],null,null,'UNASSESSED',null];
 const sql='SELECT * FROM ops.record_setup_controller_location('+base.map((_,i)=>'$'+(i+1)).join(',')+')';
 const call=changes=>db.query(sql,Object.assign([...base],changes));
 const first=(await call({})).rows[0];assert.equal(first.asset_type,'CONTROLLER');
 assert.equal((await call({})).rows[0].duplicate_event,true);
 await assert.rejects(()=>call({16:'changed'}),/different movement evidence/);
 await assert.rejects(()=>call({0:'visitor@example.org'}),/Not authorized/);
 await assert.rejects(()=>call({4:9999}),/not found/);
 await assert.rejects(()=>call({3:'DISPLAY'}),/requires CONTROLLER/);
 await assert.rejects(()=>call({5:'PICKED'}),/requires CONTROLLER/);
 await assert.rejects(()=>call({11:null,12:null,15:null}),/Location evidence/);
 await assert.rejects(()=>call({11:100}),/Invalid GPS/);
 await assert.rejects(()=>call({17:[1]}),/without Display unloads/);
 await call({2:'88000000-0000-4000-8000-000000001002',6:'2026-10-25T14:00:00Z',10:true,15:'Older offline'});
 assert.equal((await db.query('SELECT destination_location_note FROM ops.setup_movement_event WHERE controller_id=1001 ORDER BY occurred_at DESC,setup_movement_event_id DESC LIMIT 1')).rows[0].destination_location_note,'Park arrival');
 assert.equal((await db.query('SELECT count(*)::int n FROM ops.setup_movement_event')).rows[0].n,2);
 assert.equal((await db.query('SELECT current_location_code FROM ref.controller WHERE controller_id=1001')).rows[0].current_location_code,'Workshop');
 assert.equal((await db.query('SELECT count(*)::int n FROM ops.setup_movement_event_display')).rows[0].n,0);
 assert.equal((await db.query("SELECT has_table_privilege('fieldwiring_app','ops.setup_movement_event','INSERT') AS allowed")).rows[0].allowed,false);
 console.log('Controller movement: actual migration, authorization, identity, GPS, exact/conflicting replay, offline ordering and preserved inventory/Display evidence PASS');
} finally {await db.close();}
