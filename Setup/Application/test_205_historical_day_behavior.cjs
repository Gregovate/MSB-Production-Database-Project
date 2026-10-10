const fs=require('fs'),vm=require('vm'),assert=require('node:assert/strict');
const base=__dirname+'/';
const perform=fs.readFileSync(base+'setup_next_pass.js','utf8'),board=fs.readFileSync(base+'setup_scheduling_board.js','utf8');
function fn(s,n){let a=s.indexOf('function '+n+'('),b=s.indexOf('\nfunction ',a+1);return s.slice(a,b<0?undefined:b);}
const context={Intl,Date,escapeHtml:s=>String(s), setupBoard205State:{board:{assignments:[]}},board205DayAssignments:d=>context.setupBoard205State.board.assignments.filter(x=>x.setup_work_day_id===d.setup_work_day_id)};
vm.createContext(context);
for(const n of ['nextAssignmentReported','nextSetupLocalDate','nextAssignmentLate','nextAssignmentReportedLabel','nextScheduleWarning'])vm.runInContext(fn(perform,n),context);
for(const n of ['board205DayViewState','board205CanCollapseDay'])vm.runInContext(fn(board,n),context);
let checks=0;function check(f){f();checks++;}
check(()=>assert.equal(context.nextSetupLocalDate(new Date('2026-10-10T01:42:00Z')),'2026-10-09'));
check(()=>assert.equal(context.nextSetupLocalDate(new Date('2026-01-10T05:59:00Z')),'2026-01-09'));
check(()=>assert.equal(context.nextSetupLocalDate(new Date('2026-01-10T06:00:00Z')),'2026-01-10'));
check(()=>assert.equal(context.nextSetupLocalDate(new Date('2026-07-10T05:00:00Z')),'2026-07-10'));
check(()=>assert.equal(context.nextAssignmentReported({historical_locked:true,started_at:'x'}),false));
const partial={setup_work_day_id:7,work_report_count:1,reported_percent_complete:40,actual_person_minutes:0};
check(()=>assert.equal(context.nextAssignmentReported(partial),true));
check(()=>assert.equal(context.nextAssignmentReportedLabel(partial),'INCOMPLETE — Work Reported'));
check(()=>assert.equal(context.nextAssignmentReportedLabel({...partial,reported_percent_complete:100}),'COMPLETE — Work Reported'));
context.nextSetupLocalDate=()=> '2026-10-09';
const day={setup_work_day_id:7,work_date:'2026-10-05'};
context.setupBoard205State.board.assignments=[partial];
check(()=>assert.equal(context.board205DayViewState(day),'COMPLETED'));
check(()=>assert.equal(context.board205CanCollapseDay(day),true));
check(()=>assert.equal(context.board205CanCollapseDay({...day,work_date:'2026-10-09'}),false));
context.setupBoard205State.board.assignments.push({setup_work_day_id:7,work_report_count:0,effective_complete:true});
check(()=>assert.equal(context.board205DayViewState(day),'UNFINISHED'));
check(()=>assert.equal(context.board205CanCollapseDay(day),false));
check(()=>assert.equal(context.nextAssignmentLate({work_report_count:0},'2026-10-08'),true));
check(()=>assert.equal(context.nextAssignmentLate({work_report_count:0},'2026-10-09'),false));
check(()=>assert.equal(context.nextAssignmentLate(partial,'2026-10-05'),false));
check(()=>assert.match(context.nextScheduleWarning('CAPTAIN TBD — NEEDS CAPTAIN'),/background:#fff0f0.*font-weight:900/));
// Exercise the rendered Perform Work card, not just helper return values.
Object.assign(context, {
  nextPerformTask:()=>({effective_complete:true,expected_duration_minutes:60}),
  nextPerformCrew:()=>({captain_display_name:'Captain',captain_person_id:17}),
  nextPerformPlannedCrew:()=>2,nextLaborHoursText:()=>2,
  nextTaskScopeLabel:()=> 'Stage 15',formatMinutes:()=> '1 hr',
  nextCanSubmitFieldFinding:()=>true,
});
for(const n of ['nextSetupAssignmentStatus','nextPerformAssignmentStatus','nextPerformAssignmentCard']) vm.runInContext(fn(perform,n),context);
const reportedCard=context.nextPerformAssignmentCard({...partial,task_name:'Layout Displays and Nativity'});
check(()=>assert.match(reportedCard,/INCOMPLETE — Work Reported/));
check(()=>assert.doesNotMatch(reportedCard,/LATE — NO WORK REPORTED/));
const lateCard=context.nextPerformAssignmentCard({work_report_count:0,work_date:'2026-10-05',task_name:'Unreported task'});
check(()=>assert.match(lateCard,/background:#a40000;color:#fff/));
check(()=>assert.match(lateCard,/LATE — NO WORK REPORTED/));
check(()=>assert.match(lateCard,/next-report-work/));
console.log(`${checks} behavioral checks PASS`);
