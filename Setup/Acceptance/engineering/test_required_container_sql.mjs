// Isolated SQL engineering check; not current-Production clone acceptance.
const { PGlite } = await import(process.env.PGLITE_MODULE || '@electric-sql/pglite');
import fs from 'node:fs';
import assert from 'node:assert/strict';
const db = new PGlite();
await db.exec(`CREATE SCHEMA ref; CREATE ROLE fieldwiring_app;
CREATE TABLE ref.setup_task(setup_task_id bigint PRIMARY KEY,active_flag boolean,stage_id int);
CREATE TABLE ref.container(container_id int PRIMARY KEY,container_type_id int);
CREATE TABLE ref.setup_task_container_support(setup_task_id bigint REFERENCES ref.setup_task,
container_id int REFERENCES ref.container,relationship_type text,notes text,
CONSTRAINT pk_setup_task_container_support PRIMARY KEY(setup_task_id,container_id));
CREATE FUNCTION ref.setup_management_actor(text,boolean) RETURNS TABLE(directus_user_id uuid,person_id int,display_name text)
LANGUAGE plpgsql AS $$ BEGIN
IF $1 <> 'manager@example.test' THEN RAISE EXCEPTION USING ERRCODE='42501',MESSAGE='Manager required'; END IF;
RETURN QUERY SELECT '00000000-0000-0000-0000-000000000001'::uuid,1,'Manager'::text; END $$;
INSERT INTO ref.setup_task VALUES(10,true,NULL),(11,true,1),(12,false,1);
INSERT INTO ref.container VALUES(106,7),(107,2);
INSERT INTO ref.setup_task_container_support VALUES(10,107,'KIT','Preserve');`);
await db.exec(fs.readFileSync(new URL('../../Database/073_add_setup_required_container_command.sql', import.meta.url),'utf8'));
const command = (task,id,assigned,email='manager@example.test')=>db.query('SELECT * FROM ref.set_setup_task_required_container($1,$2,$3,$4,NULL)',[email,task,id,assigned]);
await command(10,106,true); await command(10,106,true); await command(11,106,true);
let links=(await db.query('SELECT * FROM ref.setup_task_container_support ORDER BY setup_task_id,container_id')).rows;
assert.equal(links.length,3); assert.equal(links[0].relationship_type,'REQUIRED_CONTAINER');
await assert.rejects(command(10,106,true,'picker@example.test'), /Manager required/);
await assert.rejects(command(12,106,true),/active reusable/);
await assert.rejects(command(10,999,true),/not found/);
await assert.rejects(command(10,107,true),/will not be overwritten/);
await assert.rejects(command(10,107,false),/will not be overwritten/);
await command(10,106,false); await command(10,106,false);
links=(await db.query('SELECT * FROM ref.setup_task_container_support ORDER BY setup_task_id,container_id')).rows;
assert.equal(links.length,2); assert.equal(links[0].relationship_type,'KIT');
assert.equal(links[0].notes,'Preserve'); assert.equal(links[1].setup_task_id,11);
assert.equal((await db.query('SELECT container_type_id FROM ref.container WHERE container_id=106')).rows[0].container_type_id,7);
await db.exec('BEGIN');await command(10,106,true);await db.exec('ROLLBACK');
assert.equal((await db.query('SELECT * FROM ref.setup_task_container_support')).rows.length,2);
console.log('PASS: actual migration, C106 non-Kit/scope-independent links, idempotency, sharing, Manager gate, missing/inactive rejection, KIT preservation, unlink and rollback.');
await db.close();
