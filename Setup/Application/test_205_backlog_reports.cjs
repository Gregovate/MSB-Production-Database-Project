/* Execute production queue functions: unreported work must not masquerade as ready. */
const assert=require('node:assert/strict'),fs=require('node:fs'),vm=require('node:vm');
const source=fs.readFileSync(__dirname+'/setup_scheduling_board.js','utf8');
const start=source.indexOf('function board205NeedsContinuation(');
const end=source.indexOf('function board205SchedulableReportScope(',start);
const tasks=[
 {id:185,board_status:'SCHEDULED',execution_status:'PLANNED',unworked_assignment_count:1},
 {id:1,board_status:'READY_TO_SCHEDULE',execution_status:'READY'},
 {id:2,board_status:'NEEDS_SCHEDULING_AGAIN',execution_status:'IN_PROGRESS',progress_entries:1},
 {id:3,board_status:'SCHEDULED',execution_status:'PLANNED',future_assignment_count:1},
 {id:4,board_status:'COMPLETE',execution_status:'COMPLETE',effective_complete:true},
 {id:5,board_status:'NEEDS_SCHEDULING_AGAIN',execution_status:'IN_PROGRESS',unworked_assignment_count:1},
 {id:6,board_status:'BLOCKED',execution_status:'PLANNED',unworked_assignment_count:1,hardBlocked:true},
];
let statuses=new Set(['READY']);
const context={document:{getElementById:()=>null},setupBoard205State:{board:{tasks}},
 board205ReadyOnlyEnabled:()=>false,board205FinderSelectedStatuses:()=>statuses,
 board205FinderStatusFamily:t=>['READY_TO_SCHEDULE','NEEDS_SCHEDULING_AGAIN'].includes(t.board_status)?'READY':t.board_status,
 board205HasHardBlock:t=>!!t.hardBlocked,board205BlockingEnabled:()=>false,
 board205FinderCompare:(a,b)=>a.id-b.id};
vm.createContext(context);vm.runInContext(source.slice(start,end),context);
assert.deepEqual(Array.from(context.board205QueueTasks(),t=>t.id).sort((a,b)=>a-b),[1,2,5]);
assert.deepEqual(Array.from(context.board205SchedulableTasksForReport(),t=>t.id),[1,2,5]);
assert.equal(context.board205NeedsContinuation(tasks[5]),true);
assert.equal(context.board205NeedsContinuation(tasks[2]),true);
statuses=new Set(['SCHEDULED']);
assert.ok(Array.from(context.board205QueueTasks(),t=>t.id).includes(185),'Explicit Scheduled inspection remains available');
assert.equal(context.setupBoard205State.board.tasks.length,7,'Work/report populations stay intact');
const repo=fs.readFileSync(__dirname+'/setup_scheduling_board_repository.py','utf8');
assert.ok(repo.indexOf("THEN 'NEEDS_SCHEDULING_AGAIN'") < repo.indexOf("WHEN coalesce(sched.unworked_assignment_count, 0) > 0"),'Partial reported work takes precedence over old missing reports');
console.log('PASS backlog: task185 awaiting report excluded; first work and reported continuation retained; print and blocker paths consistent');
