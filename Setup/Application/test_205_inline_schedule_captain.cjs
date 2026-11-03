/* Exercise the actual scheduling submit handler with continuation and move payloads. */
const assert = require('node:assert/strict');
const fs = require('node:fs');
const vm = require('node:vm');
const source = fs.readFileSync(__dirname + '/setup_scheduling_board.js', 'utf8');
assert.match(source, /addEventListener\('change', board205ScheduleCaptainVisibility\)/);
const begin = source.indexOf('async function board205SubmitScheduleDialog(');
const end = source.indexOf('\nasync function board205AddWorkDay(', begin);
async function run({kind='task', choice='NEW_CREW', captain='8', existing=false, fail=false, allow=true, size='4'}={}) {
  const calls=[]; let closed=false; let loaded=false; const errors=[];
  const controls={
    'setup-board205-schedule-day':{value:'17'},
    'setup-board205-schedule-shift':{value:'AFTERNOON'},
    'setup-board205-schedule-crew':{value:choice},
    'setup-board205-schedule-captain':{value:captain},
    'setup-board205-schedule-size':{value:size},
    'setup-board205-schedule-dialog':{close(){closed=true;}},
  };
  const task={setup_session_task_id:23, percent_complete:40};
  const context={
    document:{getElementById:id=>controls[id]},
    appState:{access:{can_manage_setup:allow}},
    setupBoard205State:{scheduleTarget:{kind,id:kind==='task'?23:41}},
    board205CaptainCandidate:id=>id===8?{person_id:8}:null,
    board205CrewsForDay:()=>existing?[{setup_work_day_crew_id:101,captain_person_id:8}]:[],
    board205Assignment:()=>({setup_work_day_id:10,setup_session_task_id:23,shift_code:'MORNING',setup_work_day_crew_id:50}),
    board205Task:()=>task, board205ConfirmPlacement:()=>true,
    board205EndSort:()=>20, setBusy:()=>{},
    commandOptions:(method,body)=>({method,body}),
    api:async(url,options)=>{calls.push({url,...options});if(fail)throw Error('Locked');return {crew:{setup_work_day_crew_id:99}};},
    board205MaybeLearnCaptainForTask:async()=>{},
    board205Load:async()=>{loaded=true;},
    setAlert:message=>errors.push(message), window:{alert:()=>{}},
  };
  vm.createContext(context);vm.runInContext(source.slice(begin,end),context);
  await context.board205SubmitScheduleDialog({preventDefault(){}});
  return {calls,closed,loaded,errors,task};
}
(async()=>{
  const continuation=await run();
  assert.equal(continuation.calls.length,1);
  assert.match(continuation.calls[0].url,/work-days\/17\/crews\/with-tasks$/);
  assert.equal(continuation.calls[0].body.captain_person_id,8);
  assert.equal(continuation.calls[0].body.items[0].id,23);
  assert.equal(continuation.calls[0].body.items[0].shift,'AFTERNOON');
  assert.equal(continuation.calls[0].body.pm_planned_crew_count,4);
  assert.equal(continuation.calls[0].body.am_planned_crew_count,null);
  assert.equal((await run({size:''})).calls[0].body.pm_planned_crew_count,null);
  assert.equal((await run({size:'-2'})).calls.length,0);
  assert.equal(continuation.task.percent_complete,40);
  assert.ok(continuation.closed && continuation.loaded);
  const move=await run({kind:'assignment'});
  assert.equal(move.calls[0].body.assignment_shift,'AFTERNOON');
  assert.equal(move.calls[0].body.items[0].id,41);
  const reuse=await run({existing:true});
  assert.equal(reuse.calls[0].url,'api/setup/scheduling-board/assignments');
  assert.equal(reuse.calls[0].body.setup_work_day_crew_id,101);
  const ordinary=await run({choice:'102'});
  assert.equal(ordinary.calls[0].body.setup_work_day_crew_id,102);
  const failed=await run({fail:true});
  assert.equal(failed.closed,false);assert.equal(failed.loaded,false);
  assert.deepEqual(failed.errors,['Locked']);
  assert.equal((await run({captain:''})).calls.length,0);
  assert.equal((await run({allow:false})).calls.length,0);
  console.log('PASS inline Captain: continuation, explicit shift move, existing crew reuse, validation and failure retention');
})().catch(error=>{console.error(error);process.exitCode=1;});
