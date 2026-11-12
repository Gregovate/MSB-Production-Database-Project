/* November 3 regression: real selectors/renderers, synthetic operator evidence. */
const fs = require('node:fs'), vm = require('node:vm'), assert = require('node:assert/strict');
const source = fs.readFileSync(__dirname+'/setup_next_pass.js','utf8');
const schedule = fs.readFileSync(__dirname+'/setup_scheduling_board.js','utf8');
function load(text, name) {
  const start=text.indexOf('function '+name+'(');
  assert(start>=0, name);
  const ends=['\nfunction ', '\nasync function '].map(x=>text.indexOf(x,start+1)).filter(x=>x>=0);
  vm.runInContext(text.slice(start,Math.min(...ends)),ctx);
}
const tasks=[
  {setup_session_task_id:436,task_name:'Sledders',execution_status:'COMPLETE',effective_complete:true,progress_entries:2,percent_complete:100},
  {setup_session_task_id:424,task_name:'Glistening Grove',execution_status:'COMPLETE',effective_complete:true,progress_entries:2,percent_complete:100,latest_work_report:{percent_complete:95}},
  {setup_session_task_id:422,task_name:"John's Tree",execution_status:'COMPLETE',effective_complete:true,progress_entries:4,percent_complete:100},
  ...[[392,85],[451,75],[341,50],[365,10]].map(([id,percent])=>({setup_session_task_id:id,task_name:'Partial '+id,execution_status:'IN_PROGRESS',effective_complete:false,progress_entries:1,percent_complete:percent})),
  ...[353,462,338].map(id=>({setup_session_task_id:id,task_name:'Unreported '+id,execution_status:'PLANNED',effective_complete:false,progress_entries:0}))
];
const assignments=[[436,332],[436,286],[424,317],[422,243],[392,304],[451,348],[341,347],[365,308],[353,341],[462,350],[338,309]].map(([task,id])=>({setup_session_task_id:task,setup_work_day_task_id:id,setup_work_day_id:1,setup_work_day_crew_id:1,shift_code:'MORNING',work_date:'2026-10-23',work_report_count:0,actual_person_minutes:0,task_name:tasks.find(t=>t.setup_session_task_id===task).task_name}));
const board={tasks,assignments,work_days:[{setup_work_day_id:1,work_date:'2026-10-23'}],crews:[]};
const before=JSON.stringify(board);
const toggle={checked:false};
const taskFor=id=>tasks.find(t=>t.setup_session_task_id===Number(id));
const ctx={console,Intl,Date,Number,String,Math,Set,Map,
  escapeHtml:s=>String(s).replaceAll('&','&amp;').replaceAll('<','&lt;'),
  el:()=>toggle, document:{getElementById:()=>toggle},
  nextPerformCaptainScopedAssignments:rows=>rows, nextPerformTask:taskFor,
  board205Task:taskFor,board205DayAssignments:()=>assignments,
  board205AssignmentsFor:()=>assignments,board205CrewSequence:()=>assignments,
  SETUP_BOARD205_TYPICAL_AM_MINUTES:180,
  appState:{access:{can_manage_setup:true}},
  setupAnnualMilestoneDates:()=>({setupComplete:new Date('2026-11-17T00:00:00Z')}),
  nextPerformCrew:()=>null,nextPerformPlannedCrew:()=>2,nextLaborHoursText:()=>2,
  nextTaskScopeLabel:()=>'',formatMinutes:()=>'',nextCanSubmitFieldFinding:()=>true,
  nextCanRescheduleNoWork:()=>false,
};
vm.createContext(ctx);
for(const name of ['nextAssignmentReported','nextAnnualTaskComplete','nextAssignmentInactive','nextAssignmentReviewLabel','nextSetupLocalDate','nextAssignmentLate','nextAssignmentReportedLabel','nextScheduleWarning','nextSetupAssignmentStatus','nextPerformAssignmentStatus','nextPerformTaskNumberLabel','nextPerformTaskScopeLabel','nextPerformAssignmentCard','nextFilterPerformAssignments','nextPerformShiftWorkload','nextLateWorkSummary','setup205DeadlineKpiModel'])load(source,name);
ctx.nextSetupLocalDate=()=> '2026-11-03';
for(const name of ['board205DayViewState','board205ShowReportedTaskCards','board205ActiveAssignmentsFor','board205AmCapacity','board205ShiftWorkload'])load(schedule,name);
assert.equal(ctx.setup205DeadlineKpiModel(board,2026).overdue.length,7);
assert.equal(ctx.nextFilterPerformAssignments(assignments).length,7);
assert.equal(ctx.board205ActiveAssignmentsFor().length,7);
assert.equal(ctx.board205ShiftWorkload(1,'MORNING').count,7);
assert.equal(ctx.nextPerformShiftWorkload(assignments,'MORNING').count,7);
assert.equal(ctx.board205DayViewState(board.work_days[0]),'UNFINISHED');
for(const a of assignments.slice(0,4)){
 assert.equal(ctx.nextAssignmentLate(a,a.work_date,taskFor(a.setup_session_task_id)),false);
 assert.equal(ctx.nextAssignmentReported(a),false,'never fabricate a report');
 const card=ctx.nextPerformAssignmentCard(a);
 assert(card.includes('data-work-status="COMPLETE"'));
 assert(!card.includes('LATE') && !card.includes('this dated assignment needs review'));
}
for(const a of assignments.slice(4,8)){
 const card=ctx.nextPerformAssignmentCard(a);
 assert(card.includes('Overall task progress:') && card.includes('this dated assignment needs review'));
 assert(!card.includes('NO WORK REPORTED'));
}
assert(ctx.nextPerformAssignmentCard(assignments[8]).includes('NO WORK REPORTED'));
const summary=ctx.nextLateWorkSummary(assignments,board);
assert(summary.includes('7 PAST ASSIGNMENTS TO REVIEW'));
assert(!summary.includes("John's Tree") && !summary.includes('Glistening Grove'));
toggle.checked=true;
assert.equal(ctx.nextFilterPerformAssignments(assignments).length,11);
assert.equal(ctx.board205ActiveAssignmentsFor().length,11);
ctx.board205DayAssignments=()=>assignments.slice(0,4);
assert.equal(ctx.board205DayViewState({}),'COMPLETED');
assert.equal(ctx.nextAssignmentLate({...assignments[4],day_status:'CANCELLED'},'2026-10-23',tasks[3]),false);
assert.equal(ctx.nextAssignmentLate(assignments[4],'2026-11-04',tasks[3]),false);
assert.equal(ctx.nextAssignmentLate({...assignments[4],work_report_count:1},'2026-10-23',tasks[3]),false);
assert.equal(ctx.nextAssignmentLate(assignments[0],'2026-10-23',{execution_status:'IN_PROGRESS',effective_complete:false,percent_complete:100}),true,'old max 100 does not hide reopened work');
assert.equal(ctx.nextAssignmentLate(assignments[0],'2026-10-23',{execution_status:'PLANNED',effective_complete:true,linked_work_order_gate:true}),false);
assert.equal(JSON.stringify(board),before,'all input history and labor stay unchanged');
console.log('PASS completed follow-up: 11 assignments -> 7 active; history, partial progress, completion, reopening, dates and workload');

assert.equal(ctx.nextPerformTaskNumberLabel({setup_task_id:184,setup_session_task_id:900}),'Task 184');
assert.equal(ctx.nextPerformTaskNumberLabel({setup_task_id:null,setup_session_task_id:900}),'Annual Task 900');
const duplicateDays={...board,tasks:[{...tasks[3],setup_task_id:184}],work_days:[
 {setup_work_day_id:1,work_date:'2026-10-23'}, {setup_work_day_id:2,work_date:'2026-10-24'}]};
const twoDates=[{...assignments[4]}, {...assignments[4],setup_work_day_task_id:999,setup_work_day_id:2}];
const datedSummary=ctx.nextLateWorkSummary(twoDates,duplicateDays);
assert.equal((datedSummary.match(/Task 184/g)||[]).length,2);
assert(datedSummary.includes('2026-10-23') && datedSummary.includes('2026-10-24'));
assert(datedSummary.includes('data-assignment-id="304"') && datedSummary.includes('data-assignment-id="999"'));
assert(datedSummary.includes('Overall task progress:'));
console.log('PASS visible reusable/annual task identity and distinct dated reports with overall progress');

assert(schedule.includes('<span>${board205Esc(nextPerformTaskNumberLabel(task))} · ${board205Esc(item.task_name)}</span>'));

// Reused names must retain scope without expanding a task or opening Report Work.
const scopedTask={...tasks[3],stage_id:4,stage_key:'04',stage_name:'Food Collection',scene_name:'Logo Tree'};
const scopedBoard={...board,tasks:[scopedTask]};
assert(ctx.nextLateWorkSummary([assignments[4]],scopedBoard).includes('Stage 04 — Food Collection / Logo Tree'));
const oldTask=ctx.nextPerformTask;
ctx.nextPerformTask=()=>scopedTask;
assert(ctx.nextPerformAssignmentCard(assignments[4]).includes('Stage 04 — Food Collection / Logo Tree'));
ctx.nextPerformTask=oldTask;
assert.equal(ctx.nextPerformTaskScopeLabel({...scopedTask,scene_name:null}),'Stage 04 — Food Collection / Stage-level');
assert.equal(ctx.nextPerformTaskScopeLabel({}),'Site-wide / Infrastructure');
assert(ctx.nextLateWorkSummary([assignments[4]],{...scopedBoard,tasks:[{...scopedTask,scene_name:'<unsafe>'}]}).includes('&lt;unsafe>'));
console.log('PASS stage/scene context before Report Work, stage-level/site-wide fallbacks and escaped scope');

// Past follow-up hides stale staffing forecasts; today's operational view retains them.
const historicalCard=ctx.nextPerformAssignmentCard(assignments[4]);
assert(!historicalCard.includes('Planned crew'));
assert(!historicalCard.includes('Est. labor'));
assert(!historicalCard.includes('EFFORT TBD'));
assert(historicalCard.includes('Captain:'));
assert(historicalCard.includes('next-report-work'));
const currentCard=ctx.nextPerformAssignmentCard({...assignments[4],work_date:'2026-11-03'});
assert(currentCard.includes('Planned crew'));
assert(currentCard.includes('Est. labor'));
const pastSummary=ctx.nextLateWorkSummary(assignments,board);
assert(!pastSummary.includes(' · Crew '));
assert(pastSummary.includes('2026-10-23'));
console.log('PASS past-work cards omit staffing forecasts; today keeps staffing and past report identity remains');

// Reporting action remains in the visible summary for collapsed past/current/future cards.
for (const work_date of ['2026-10-23','2026-11-03','2026-11-04']) {
 const card=ctx.nextPerformAssignmentCard({...assignments[4],work_date});
 const summary=card.split('<summary>')[1].split('</summary>')[0];
 assert(summary.includes('next-report-work'));
 assert(summary.includes('Report Work'));
 assert.equal((card.match(/class="small next-report-work"/g)||[]).length,1);
}
const completedSummary=ctx.nextPerformAssignmentCard(assignments[0]).split('<summary>')[1].split('</summary>')[0];
assert(completedSummary.includes('Review Work History'));
console.log('PASS visible report action in collapsed past/current/future summary and completed history');
