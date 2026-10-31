import assert from 'node:assert/strict';
import {createFixtureDatabase} from './power_test_database.mjs';
import '../Application/static/breaker_state.js';
const model=globalThis.MSBBreakerState;
const db=await createFixtureDatabase();
let rev=0;
async function cmd(kind,id,fields,request=crypto.randomUUID(),email='crew@example.test',revision=rev) {
 const result=(await db.query('select ref.site_power_command($1,$2::uuid,$3,$4,$5,$6::jsonb) result',[email,request,revision,kind,id,JSON.stringify(fields)])).rows[0].result;
 rev=result.revision;return result;
}
try {
 const p=await cmd('panel',null,{panel_name:'Panel 14'});
 const b=await cmd('breaker_schedule',null,{breaker:{site_panel_id:p.target_id,breaker_name:'2/4',breaker_role:'BRANCH',panel_positions:[2,4],pole_count:2,rated_amps:60,source_evidence:'Panel receptacles'},legs:[{pole:1,circuit_code:'2',waypoint_ids:[]},{pole:2,circuit_code:'4',waypoint_ids:[]}],show_desired_state:'ON',restoration_desired_state:'OFF'});
 const fields={season_year:2026,phase:'SETUP',condition:'ON',observed_at:'2026-10-09T12:00:00Z'};
 const request=crypto.randomUUID(), start=rev;
 const result=await cmd('breaker_state',b.target_id,fields,request);
 const replay=await cmd('breaker_state',b.target_id,fields,request,'crew@example.test',start);
 assert.equal(replay.replayed,true);assert.equal(replay.target_id,result.target_id);
 const snap=()=>db.query("select ref.site_power_snapshot('crew@example.test') data").then(r=>r.rows[0].data);
 let s=await snap();assert.equal(s.events.length,1);assert.equal(s.actions.length,1);
 assert.equal(s.events[0].operator_email,'crew@example.test');assert.equal(s.events[0].operator_name,'Fixture User');assert.equal(s.events[0].event_kind,'REPORTED');
 const breaker=s.breakers.find(x=>x.site_power_breaker_id===b.target_id);
 let event=model.latest(s.events,b.target_id);
 assert.equal(model.status({...breaker,restoration_desired_state:'ON'},{...event,condition:'OFF'},2026,'SETUP'),'Wrong state');
 assert.equal(model.status(breaker,null,2026,'SETUP'),'No recorded state');
 assert.equal(model.classify(breaker,event,2026,'SETUP'),'completed');
 assert.equal(model.classify(breaker,event,2025,'SETUP'),'open');
 assert.equal(model.classify(breaker,event,2026,'RESTORATION'),'open');
 assert.equal(model.classify({...breaker,restoration_desired_state:'ON'},event,2026,'SETUP'),'unchanged');
 assert.equal(model.classify({...breaker,restoration_desired_state:'UNKNOWN'},event,2026,'SETUP'),'configuration');
 for(const [bad,id,email,revision] of [[{...fields,impact_reviewed:false},b.target_id,'crew@example.test',rev],[{...fields,condition:'UNKNOWN'},b.target_id,'crew@example.test',rev],[fields,999,'crew@example.test',rev],[fields,b.target_id,'volunteer@example.test',rev],[fields,b.target_id,'crew@example.test',start],[{...fields,operator_email:'forged'},b.target_id,'crew@example.test',rev]]) {
  await assert.rejects(()=>cmd('breaker_state',id,bad,crypto.randomUUID(),email,revision));
 }
 assert.equal((await snap()).events.length,1);
 await cmd('breaker_state',b.target_id,{...fields,condition:'OFF',observed_at:'2026-10-10T12:00:00Z'});
 s=await snap();assert.equal(s.actions.length,1);assert.equal(s.events.length,2);
 event=model.latest(s.events,b.target_id);assert.equal(event.condition,'OFF');assert.equal(model.classify(breaker,event,2026,'SETUP'),'open');
 await cmd('event',null,{site_power_action_id:event.site_power_action_id,season_year:2026,event_kind:'REPORTED',condition:'UNKNOWN',observed_at:event.observed_at,evidence:'Correct mistaken observation',corrects_event_id:event.event_id,impact_reviewed:true});
 s=await snap();event=model.latest(s.events,b.target_id);assert.equal(event.condition,'UNKNOWN');
 assert.equal(model.classify(breaker,event,2026,'SETUP'),'open');
 // Captured definition governs past observations even if current action metadata changes.
 await cmd('action',event.site_power_action_id,{phase:'RESTORATION'});
 assert.equal(model.latest((await snap()).events,b.target_id).definition_snapshot.phase,'SETUP');
 const before=await snap();
 await assert.rejects(()=>cmd('breaker_state',b.target_id,{...fields,phase:'SETUP',season_year:9999}));
 assert.equal((await snap()).events.length,before.events.length);assert.equal((await snap()).actions.length,before.actions.length);
 await db.exec((await import('node:fs')).readFileSync('Database/Acceptance/171_breaker_state_validation.sql','utf8'));
 await db.exec("SET ROLE fieldwiring_app");
 await assert.rejects(()=>db.exec('DELETE FROM ops.setup_power_activity_event'));
 await db.exec('RESET ROLE');
 console.log('PASS: atomic grouped breaker state, authorization, stale rejection, exact replay, correction, seasonal completion, immutable captured definition, unknown state and append-only boundaries');
} finally {await db.close();}
