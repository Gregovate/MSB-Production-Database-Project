/* #205: executable null-versus-Captain-only staffing and task-hour regression. */
const fs = require('node:fs');
const vm = require('node:vm');
const assert = require('node:assert/strict');
const board = fs.readFileSync(__dirname + '/setup_scheduling_board.js', 'utf8');
const perform = fs.readFileSync(__dirname + '/setup_next_pass.js', 'utf8');
function between(text, from, to) {
  const start = text.indexOf(from);
  const end = text.indexOf(to, start + from.length);
  assert(start >= 0 && end > start, 'Function boundary not found: ' + from);
  return text.slice(start, end);
}
const tasks = [
  {setup_session_task_id: 11, expected_duration_minutes:120, normal_crew_min:null, effort_level:null},
  {setup_session_task_id: 12, expected_duration_minutes:60, normal_crew_min:2, effort_level:'LIGHT'}
];
const crew = {setup_work_day_crew_id:7, setup_work_day_id:10, captain_person_id:28,
  am_planned_crew_count:null, pm_planned_crew_count:null};
const assignments = [
  {setup_work_day_task_id:1, setup_work_day_crew_id:7, setup_session_task_id:11,
   shift_code:'MORNING', historical_locked:false, planned_crew_count:4},
  {setup_work_day_task_id:2, setup_work_day_crew_id:7, setup_session_task_id:12,
   shift_code:'MORNING', historical_locked:false, planned_crew_count:4}
];
const target = {innerHTML:''};
const ctx = {
  Number, Boolean, String, Set, Map, Math,
  appState:{seasonYear:2026,access:{can_manage_setup:true}},
  setupBoard205State:{board:{tasks,crews:[crew],assignments}},
  setupNextState:{performBoard:{crews:[crew]},perform:{tasks}},
  document:{getElementById:()=>target},
  board205CrewRow:id=>Number(id)===7?crew:null,
  board205Task:id=>tasks.find(t=>t.setup_session_task_id===Number(id)),
  nextPerformCrew:()=>crew,
  nextPerformTask:id=>tasks.find(t=>t.setup_session_task_id===Number(id)),
  nextPerformAssignmentStatus:()=> 'PLANNED',
  board205Esc:value=>String(value),
  setup205WireManagementNavigation:()=>{},
  setup205DeadlineKpiHtml:()=>'<section>Progress summary</section>'
};
vm.createContext(ctx);
vm.runInContext(between(board,'function board205MissingEstimates(', '\nfunction board205ReschedulingLabel('),ctx);
vm.runInContext(between(board,'function board205LaborHours(', '\nfunction board205ProgressPercent('),ctx);
vm.runInContext(between(board,'function board205RenderKpis(', '\nfunction board205Render('),ctx);
vm.runInContext(between(perform,'function nextLaborHours(', '\nfunction nextPerformDay('),ctx);
vm.runInContext(between(perform,'function nextPerformLaborKpis(', '\n// #205: Linear elapsed-time capacity'),ctx);
vm.runInContext(between(perform,'function nextDayStaffingSummary(', '\n// Use the existing Captain scope'),ctx);
assert.equal(ctx.board205RequireEstimates(tasks[0]),true,'Missing estimates must not block scheduling');
assert.deepEqual(Array.from(ctx.board205MissingEstimates(tasks[0])),['crew size','effort'],
  'Known duration does not become unknown when crew/effort estimates missing');
assert.equal(ctx.board205AssignmentPlannedCrew(assignments[0]),null,
  'Existing crew NULL overrides obsolete assignment count');
assert.equal(ctx.board205LaborHours(null,120),null,'No fabricated zero labor');
assert.equal(ctx.nextPerformPlannedCrew(assignments[0]),null,
  'Perform Work must not infer staffing from old assignment count');
assert.equal(ctx.nextLaborHours(null,120),null);
ctx.board205RenderKpis();
assert.match(target.innerHTML,/3 known task-hours/,'Duration survives blank crew count');
assert.match(target.innerHTML,/Planned person-hours TBD/,'Unknown is not zero');
assert(!target.innerHTML.includes('0 planned labor hr'));
const summary = ctx.nextDayStaffingSummary(assignments,[crew],tasks);
assert.match(summary,/3\.0 known task-hours/);
assert.match(summary,/unconfirmed crew/);
assert(!summary.includes('0 people planned'));
assert(!summary.includes('/ 1 minimum needed'),'Unknown task crew minimum cannot be forced to one');
const kpis = ctx.nextPerformLaborKpis(assignments);
assert.equal(kpis.plannedHours,'TBD');
assert.equal(kpis.plannedUnknown,2);
crew.am_planned_crew_count=1;
assert.equal(ctx.board205AssignmentPlannedCrew(assignments[0]),1,'Crew=1 means Captain alone');
assert.equal(ctx.nextPerformPlannedCrew(assignments[0]),1);
assert.equal(ctx.board205LaborHours(1,120),2);
ctx.board205RenderKpis();
assert.match(target.innerHTML,/3 known task-hours/);
assert.match(target.innerHTML,/3 planned person-hours/);
assert(!target.innerHTML.includes('Planned person-hours TBD'));
console.log('PASS #205 nullable crew, Captain-only one, independent task durations, partial labor and advisory estimates');
