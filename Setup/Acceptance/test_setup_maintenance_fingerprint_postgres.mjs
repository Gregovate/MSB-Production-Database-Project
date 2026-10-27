// Execute the runner's actual SQL generator and every generated statement.
import {execFileSync} from 'node:child_process';
import {fileURLToPath} from 'node:url';
import assert from 'node:assert/strict';
const {PGlite} = await import(process.env.MSB_PGLITE_MODULE || '@electric-sql/pglite');
const directory=fileURLToPath(new URL('.',import.meta.url));
const sql=execFileSync(process.env.PYTHON || 'python3',['-c',`
from setup_maintenance_deploy import Deploy
class Probe:
    m={'profile':'field-070'}
    def sql(self, query): print(query)
Deploy.capture(Probe())
`],{cwd:directory,encoding:'utf8'});
const generator=sql.split('BEGIN ISOLATION LEVEL REPEATABLE READ READ ONLY;')[1].split('\\gexec')[0];
const db=new PGlite();
try {
 await db.exec(`CREATE SCHEMA ref; CREATE SCHEMA ops;
 CREATE TABLE ref.empty_table(id integer);
 CREATE TABLE ops.events(id integer, note text);
 INSERT INTO ops.events VALUES(2,'second'),(1,'quote''s');`);
 async function capture(){
  const statements=(await db.query(generator)).rows.map(row=>row.format);
  assert.equal(statements.length,2);
  const result=[];
  for(const statement of statements)result.push((await db.query(statement)).rows[0].json_build_object);
  return result;
 }
 const before=await capture();
 assert.equal(before.find(r=>r.table==='ref.empty_table').digest,'d41d8cd98f00b204e9800998ecf8427e');
 await db.exec("BEGIN; UPDATE ops.events SET note='changed' WHERE id=1;");
 assert.notDeepEqual(await capture(),before,'Changed business row must change fingerprint');
 await db.exec('ROLLBACK;');
 assert.deepEqual(await capture(),before,'Rollback restores fingerprint');
 await db.exec("DELETE FROM ops.events; INSERT INTO ops.events VALUES(1,'quote''s'),(2,'second');");
 assert.deepEqual(await capture(),before,'Row insertion order must not change fingerprint');
 console.log('PASS: actual fingerprint generator, empty tables, quoted text, row changes and ordering');
} finally {await db.close();}
