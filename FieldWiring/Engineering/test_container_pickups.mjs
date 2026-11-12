import {PGlite} from '@electric-sql/pglite';
import fs from 'node:fs';
import assert from 'node:assert/strict';
const db=new PGlite();
try{
 await db.exec(fs.readFileSync('Setup/Acceptance/setup_88_reconciliation_fixture.sql','utf8'));
 await db.exec(`CREATE OR REPLACE FUNCTION ref.setup_movement_actor(email text) RETURNS TABLE(directus_user_id uuid,person_id integer,display_name text) LANGUAGE plpgsql AS $$ BEGIN IF email<>'fixture@example.org' THEN RAISE EXCEPTION 'Not authorized' USING ERRCODE='42501'; END IF; RETURN QUERY SELECT '88000000-0000-4000-8000-000000000001'::uuid,1,'Fixture'::text; END $$;`);
 await db.exec(fs.readFileSync('Setup/Database/078_add_setup_container_pickup.sql','utf8'));
 let n=0;const uuid=()=> '88000000-0000-4000-8000-'+String(++n).padStart(12,'0');
 const call=(id=95,action='REQUEST',stage=15,location='Beside arches',empty=true,email='fixture@example.org',key=uuid())=>db.query('SELECT ops.record_setup_container_pickup($1,2026,$2,$3,$4,$5,$6,$7) id',[email,key,id,action,stage,location,empty]);
 const list=async()=> (await db.query('SELECT * FROM ops.setup_container_pickup_list ORDER BY stage_key,container_id')).rows;
 await assert.rejects(()=>call(95,'REQUEST',15,'Here',false),/Confirm empty/);
 await assert.rejects(()=>call(95,'REQUEST',15,'Here',true,'visitor'),/Not authorized/);
 const key=uuid();const a=await call(95,'REQUEST',16,'Behind arches',true,'fixture@example.org',key);
 assert.equal((await call(95,'REQUEST',16,'Behind arches',true,'fixture@example.org',key)).rows[0].id,a.rows[0].id);
 await assert.rejects(()=>call(95,'REQUEST',16,'Elsewhere',true,'fixture@example.org',key),/different data/);
 await call(216);assert.deepEqual((await list()).map(x=>x.container_id),[216,95]);
 assert.equal((await db.query('SELECT count(*)::int n FROM ops.setup_movement_event')).rows[0].n,0);
 await call(216,'CANCEL',null,null,false);assert.equal((await list()).length,1);
 await db.exec(`INSERT INTO ops.setup_movement_event(setup_session_id,container_id,event_type,occurred_at) SELECT setup_session_id,95,'RETURNED',clock_timestamp() FROM ops.setup_session WHERE season_year=2026`);
 assert.equal((await list()).length,0);
 await call(95);assert.equal((await list()).length,1);
 assert.equal((await db.query("SELECT has_table_privilege('fieldwiring_app','ops.setup_container_pickup_event','INSERT') a")).rows[0].a,false);
 assert.equal((await db.query('SELECT count(*)::int n FROM ops.setup_container_pickup_list WHERE season_year=2025')).rows[0].n,0);
 console.log('Container pickup actual SQL: auth, empty confirmation, replay/conflict, Stage order, cancellation, return closure, re-request and season isolation PASS');
}finally{await db.close();}
