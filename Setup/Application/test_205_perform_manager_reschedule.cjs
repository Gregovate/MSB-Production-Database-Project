/* #205 Manager No-Work rescheduling from Perform Work; never real DB writes. */
const fs=require('node:fs');
const vm=require('node:vm');
const assert=require('node:assert/strict');
const source=fs.readFileSync(__dirname+'/setup_next_pass.js','utf8');
function section(start,end){
  const i=source.indexOf(start), j=source.indexOf(end,i);
  assert(i>=0 && j>i,'required function not found: '+start);
  return source.slice(i,j);
}
const assignment = {
  setup_work_day_task_id:44,setup_session_task_id:33,
  setup_work_day_id:10,setup_work_day_crew_id:8,
  work_date:'2026-10-14',shift_code:'MORNING',sort_order:10,
  work_report_count:0,historical_locked:false,
};
const task={setup_session_task_id:33,task_name:'Replace Outlet Box',effective_complete:false};
const days=[
  {setup_work_day_id:10,work_date:'2026-10-14',setup_day_number:10,day_status:'PLANNED'},
  {setup_work_day_id:20,work_date:'2026-10-26',setup_day_number:11,day_status:'PLANNED'}
];
const crews=[
  {setup_work_day_crew_id:8,setup_work_day_id:10,crew_code:'B'},
  {setup_work_day_crew_id:9,setup_work_day_id:20,crew_code:'C'}
];
const controls={
 '#next-reschedule-day':{value:'20'},
 '#next-reschedule-crew':{value:'9'},
 '#next-reschedule-shift':{value:'AFTERNOON'},
};
let closeCount=0,loads=0,alerts=[],calls=[],busy=[],allowConfirm=true;
const dialog={
 dataset:{assignmentId:'44',originalShift:'MORNING'},
 querySelector:name=>controls[name],close:()=>closeCount++
};
const ctx={
 Number,String,
 appState:{access:{can_manage_setup:true}},
 setupNextState:{performBoard:{
   assignments:[assignment],tasks:[task],crews,work_days:days,
 }},
 nextPerformTask:id=>Number(id)===33?task:null,
 nextPerformDay:id=>days.find(d=>Number(d.setup_work_day_id)===Number(id)),
 nextSetupLocalDate:()=> '2026-10-15',
 document:{getElementById:()=>dialog},
 window:{confirm:()=>allowConfirm},
 setBusy:b=>busy.push(b), setAlert:(message,kind)=>alerts.push({message,kind}),
 commandOptions:(method,payload)=>({method,payload}),
 loadNextExecution:async()=>{loads++;},
 board205Load:async()=>{},
 api:async (url,options)=>{
    calls.push({url,method:options.method,payload:options.payload});
    assignment.setup_work_day_id=options.payload.setup_work_day_id;
    assignment.setup_work_day_crew_id=options.payload.setup_work_day_crew_id;
    assignment.shift_code=options.payload.shift_code;
    assignment.work_date='2026-10-26';
    return {assignment:{setup_work_day_task_id:44}};
 }
};
vm.createContext(ctx);
vm.runInContext(
 section('function nextCanRescheduleNoWork(', 'function nextPerformAssignmentCard(')+
 section('async function nextSubmitRescheduleNoWork(', 'function nextPerformLaborKpis(')+
 section('function nextAssignmentReported(', 'function nextAssignmentReportedLabel('),
 ctx
);
assert.equal(ctx.nextAssignmentLate(assignment),true);
assert.equal(ctx.nextCanRescheduleNoWork(assignment,task),true);
async function submit(){
  return ctx.nextSubmitRescheduleNoWork({preventDefault:()=>{}});
}
(async()=>{
  // Unprivileged staff cannot reschedule.
  ctx.appState.access.can_manage_setup=false;
  await submit();
  assert.equal(calls.length,0);
  ctx.appState.access.can_manage_setup=true;

  // A Captain report or historical actual work must block the Manager move.
  assignment.work_report_count=1;
  assert.equal(ctx.nextCanRescheduleNoWork(assignment,task),false);
  await submit();
  assert.equal(calls.length,0);
  assignment.work_report_count=0;
  assignment.historical_locked=true;
  assert.equal(ctx.nextCanRescheduleNoWork(assignment,task),false);
  await submit();
  assert.equal(calls.length,0);
  assignment.historical_locked=false;

  // The Manager may cancel; no write occurs.
  allowConfirm=false;
  await submit();
  assert.equal(calls.length,0);
  allowConfirm=true;

  // Exact original assignment moves to the selected future day, crew, shift.
  await submit();
  assert.equal(calls.length,1,'Reschedule blocked: '+JSON.stringify(alerts));
  assert.equal(calls[0].method,'PATCH');
  assert(calls[0].url.endsWith('/assignments/44'));
  assert.equal(calls[0].payload.setup_work_day_id,20);
  assert.equal(calls[0].payload.setup_work_day_crew_id,9);
  assert.equal(calls[0].payload.shift_code,'AFTERNOON');
  assert.equal(assignment.work_report_count,0,'No fabricated progress report');
  assert.equal(ctx.nextAssignmentLate(assignment),false,'Original missed warning must no longer appear');
  assert.equal(closeCount,1);
  assert.equal(loads,1);
  assert(alerts.at(-1).message.includes('Old late warning cleared'));

  // No duplicate move if new destination matches current assignment.
  await submit();
  assert.equal(calls.length,1);
  console.log('PASS #205 Manager no-work reschedule in Perform Work: audit-route PATCH, no fake report, no lingering late flag, locks');
})().catch(e=>{console.error(e);process.exitCode=1;});
