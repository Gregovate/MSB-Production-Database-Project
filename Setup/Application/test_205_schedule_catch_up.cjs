/* Execute the real same-day notice and its catch-up actions without a database. */
const assert = require('node:assert/strict');
const fs = require('node:fs');
const vm = require('node:vm');
const source = fs.readFileSync(__dirname+'/setup_scheduling_board.js','utf8');
const begin = source.indexOf('function board205ScheduleExistingAssignment(');
const end = source.indexOf('function board205OpenScheduleDialog(',begin);
const callbacks = {};
const existing = {setup_work_day_task_id:71, setup_session_task_id:530,
  setup_work_day_id:38,setup_work_day_crew_id:12,shift_code:'MORNING',historical_locked:false};
const controls = {
  'setup-board205-schedule-day':{value:'38'},
  'setup-board205-schedule-save':{disabled:false},
  'setup-board205-schedule-task-name':{textContent:''},
  'setup-board205-schedule-existing':{hidden:true,innerHTML:'',replaceChildren(){this.innerHTML='';},
    querySelector:selector=>({addEventListener:(_,callback)=>{callbacks[selector]=callback;}})},
  'setup-board205-schedule-dialog':{close(){}},
};
const opened=[],reported=[],revealed=[];
const context = {
  document:{getElementById:id=>controls[id]},
  setupBoard205State:{scheduleTarget:{kind:'task',id:530},board:{assignments:[existing],
    work_days:[{setup_work_day_id:38,work_date:'2026-11-10'}]}},
  board205Task:()=>({setup_task_id:185,setup_session_task_id:530,task_name:'Traffic Lanes'}),
  board205Assignment:()=>existing,
  board205CrewRow:()=>({crew_code:'A',captain_display_name:'Rick Hoffmann'}),
  board205Esc:String, board205OpenScheduleDialog:target=>opened.push(target),
  board205RevealScheduledAssignment:item=>revealed.push(item),
  setup205OpenManagerRecord:async(action,id)=>reported.push([action,id]),
  setAlert:message=>{throw Error(message);},
};
vm.createContext(context);vm.runInContext(source.slice(begin,end),context);
(async()=>{
  context.board205ScheduleExistingNotice();
  assert.equal(controls['setup-board205-schedule-save'].disabled,true);
  assert.match(controls['setup-board205-schedule-task-name'].textContent,/185.*Traffic Lanes/);
  assert.match(controls['setup-board205-schedule-existing'].innerHTML,/2026-11-10.*MORNING.*Rick Hoffmann/);
  callbacks['[data-existing-open]']();
  assert.equal(opened[0].kind,'assignment');assert.equal(opened[0].id,71);
  existing.historical_locked=true;
  callbacks['[data-existing-open]']();assert.equal(revealed.length,1);
  assert.equal(opened.length,1,'Reported history is not opened for moving');
  await callbacks['[data-existing-report]']();
  assert.deepEqual(reported,[['report',71]],'Use the actual assignment, not reusable task ID');
  controls['setup-board205-schedule-day'].value='39';
  context.board205ScheduleExistingNotice();
  assert.equal(controls['setup-board205-schedule-save'].disabled,false);
  assert.equal(controls['setup-board205-schedule-existing'].hidden,true);
  context.setupBoard205State.scheduleTarget={kind:'assignment',id:71};
  controls['setup-board205-schedule-day'].value='38';
  assert.equal(context.board205ScheduleExistingAssignment(),null,'Editing itself is not a duplicate');
  console.log('PASS task185 same-day catch-up: identity, unworked edit, protected history, reporting and another day');
})().catch(error=>{console.error(error);process.exitCode=1;});
