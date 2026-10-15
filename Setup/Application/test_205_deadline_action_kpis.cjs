/* #205 regression: executable shared KPI classifier, not a substitute for live-clone review. */
const fs = require('node:fs');
const vm = require('node:vm');
const assert = require('node:assert/strict');
const source = fs.readFileSync(__dirname + '/setup_next_pass.js', 'utf8');
const begin = source.indexOf('function setup205DeadlineKpiModel(');
const end = source.indexOf('\nfunction renderNextExecution()', begin);
assert(begin >= 0 && end > begin, 'shared KPI functions must exist');
const ctx = {
  Date, Set, Map, Number, String, Math, Intl,
  escapeHtml: (s) => String(s),
  nextSetupLocalDate: () => '2026-10-15',
  setupAnnualMilestoneDates: () => ({setupComplete: new Date('2026-11-19T00:00:00Z')}),
  appState: {seasonYear:2026,access:{can_manage_setup:true}},
};
vm.createContext(ctx);
vm.runInContext(source.slice(begin, end), ctx);
const get = (board) => ctx.setup205DeadlineKpiModel(board, 2026);
const base = {
  tasks: [
    {setup_session_task_id:1, task_name:'Reported done', effective_complete:true, execution_status:'COMPLETE', actual_completed_at:null, completion_work_date:'2026-10-14', completion_date_source:'REPORTED_PERFORMED_ON'},
    {setup_session_task_id:2, task_name:'Partly worked', effective_complete:false, execution_status:'IN_PROGRESS', percent_complete:90, unworked_assignment_count:1, future_assignment_count:0, prerequisites_complete:false, readiness_state:'NOT_READY'},
    {setup_session_task_id:3, task_name:'Future', effective_complete:false, execution_status:'PLANNED', unworked_assignment_count:1, future_assignment_count:1},
    {setup_session_task_id:4, task_name:'Deferred', effective_complete:false, execution_status:'DEFERRED', unworked_assignment_count:0},
    {setup_session_task_id:5, task_name:'No date', effective_complete:true, execution_status:'COMPLETE', actual_completed_at:null, completion_work_date:null, completion_date_source:'UNVERIFIED'},
  ],
  assignments: [
    {setup_session_task_id:2, setup_work_day_task_id:11, setup_work_day_id:10, work_report_count:0},
    {setup_session_task_id:2, setup_work_day_task_id:12, setup_work_day_id:11, work_report_count:1},
    {setup_session_task_id:3, setup_work_day_task_id:13, setup_work_day_id:12, work_report_count:0}
  ],
  work_days: [
    {setup_work_day_id:10,work_date:'2026-10-14'},
    {setup_work_day_id:11,work_date:'2026-10-13'},
    {setup_work_day_id:12,work_date:'2026-10-16'}
  ]
};
const k=get(base);
assert.equal(k.tasks.length,5);
assert.equal(k.complete.length,2);
assert.equal(k.incomplete.length,3);
assert.equal(k.partial.length,1);
assert.equal(k.blocked.length,1); // simultaneous prerequisite and soft readiness = one annual task
assert.equal(k.notReady.length,1);
assert.equal(k.scheduled.length,1);
assert.equal(k.needsRescheduling.length,1);
assert.equal(k.needsFirstScheduling.length,0);
assert.equal(k.overdue.length,1); // reported previous occurrence is not missing
assert.equal(k.lateNoReportTaskCount,1);
assert.equal(k.deferred.length,1);
assert.equal(k.daysLeft,35);
assert.equal(k.potentialWorkdays,30);
assert.equal(k.scheduledWorkdays,1);
assert.equal(k.requiredPerPotentialWorkday,2/30);
assert.equal(k.reliable,false); // undated completed task forces insufficient-data forecast
assert.equal(k.projectedFinish,null);
// A stale unreported assignment cannot masquerade as an active continuation.
assert.equal(k.needsRescheduling[0].setup_session_task_id, 2);
assert.equal(k.undated, 1);
const cancelled = structuredClone(base);
cancelled.work_days[0].day_status = 'CANCELLED';
assert.equal(get(cancelled).overdue.length, 0);
const html=ctx.setup205DeadlineKpiHtml(base,2026);
for (const label of ['Needs rescheduling','Partially reported','Past scheduled assignments','Required calendar pace','Required potential workday pace']) {
  assert(html.includes(label), 'missing display section: '+label);
}
console.log('PASS #205 shared KPI classifier: 21 assertions, both calendar/workday denominators');

// A forecast needs seven distinct *annual* completions with verified dates.
const wellDated = {
  tasks: Array.from({length:7},(_,i)=>({
    setup_session_task_id:100+i, task_name:'Done '+i,
    effective_complete:true,execution_status:'COMPLETE',
    actual_completed_at:null,completion_work_date:'2026-10-14',
    completion_date_source:'REPORTED_PERFORMED_ON'
  })).concat([{setup_session_task_id:199,task_name:'Unfinished',effective_complete:false,
    execution_status:'IN_PROGRESS',future_assignment_count:0,unworked_assignment_count:1}]),
  work_days:[], assignments:[]
};
const valid=get(wellDated);
assert.equal(valid.recent,7);
assert.equal(valid.reliable,true);
assert.equal(valid.needsRescheduling.length,1);
assert.equal(valid.projectedFinish,'2026-10-16');
const futureDate=structuredClone(wellDated);
futureDate.tasks[0].completion_work_date='2026-10-16';
assert.equal(get(futureDate).futureDated,1);
assert.equal(get(futureDate).reliable,false);
const six=structuredClone(wellDated);
six.tasks.shift();
assert.equal(get(six).reliable,false);
console.log('PASS #205 proven-work-date and active-continuation regression');

const managerHtml=ctx.setup205DeadlineKpiHtml(base,2026);
for(const key of ['Manager Setup Action Center','Past occurrences awaiting reports','Incomplete tasks needing continuation','Scheduled assignments without Captain']) {
  assert(managerHtml.includes(key), 'missing Manager action group: '+key);
}
assert(managerHtml.includes('data-205-action="report"'), 'original report navigation must be exact-assignment');
assert(managerHtml.includes('data-205-action="schedule"'), 'continuation must use existing scheduler');
ctx.appState.access.can_manage_setup=false;
assert(!ctx.setup205DeadlineKpiHtml(base,2026).includes('Manager Setup Action Center'), 'Manager-only action worklist must not leak');
console.log('PASS #205 Manager read-only Action Center, permission gating, route action hooks');
