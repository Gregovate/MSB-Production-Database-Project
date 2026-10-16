/* #205: existing-crew day-to-day multi-task movement keeps original AM/PM. */
const fs=require('node:fs');
const vm=require('node:vm');
const assert=require('node:assert/strict');
const source=fs.readFileSync(__dirname+'/setup_scheduling_board.js','utf8');
const start=source.indexOf('async function board205DropToCell(');
const end=source.indexOf('\nasync function board205NudgeAssignment(',start);
assert(start>=0&&end>start);
const selected=[
 {setup_work_day_task_id:81,setup_work_day_id:7,shift_code:'MORNING',setup_session_task_id:101},
 {setup_work_day_task_id:82,setup_work_day_id:7,shift_code:'AFTERNOON',setup_session_task_id:102},
];
let sent=[],alerts=[],preserve=false,confirmations=0;
const ctx={
 Number,Set,Map,Promise,
 appState:{access:{can_manage_setup:true}},
 setupBoard205State:{dragged:null},
 board205EnsureCrewSaved:async()=>true,
 board205DraggedAssignmentItems:()=>selected,
 board205ConfirmAssignmentGroupPlacement:(_items,_crewId,_shift,keep)=>{
   preserve=keep;confirmations++;return true;
 },
 board205EndSort:()=>10,
 board205Task:id=>({setup_session_task_id:id,task_name:'Test '+id}),
 board205MaybeLearnCaptainForTasks:async()=>{},
 board205ClearAssignmentSelection:()=>{},
 board205Load:async()=>{},
 board205CrewRow:()=>({crew_code:'B'}),
 api:async(_url,{payload})=>{sent.push({...payload});},
 commandOptions:(method,payload)=>({method,payload}),
 setBusy:()=>{},
 setAlert:(message,kind)=>alerts.push({message,kind}),
 window:{alert:msg=>{throw Error('Unexpected operator alert: '+msg)}},
};
vm.createContext(ctx);
vm.runInContext(source.slice(start,end),ctx);
(async()=>{
 const drag={kind:'assignments',ids:[81,82]};
 await ctx.board205DropToCell(drag,12,'AFTERNOON',9,null);
 assert.equal(preserve,true);
 assert.equal(confirmations,1);
 assert.deepEqual(sent.map(x=>x.shift_code),['MORNING','AFTERNOON']);
 assert(sent.every(x=>x.setup_work_day_id===12 && x.setup_work_day_crew_id===9));
 assert(alerts.at(-1).message.includes('Original AM/PM shifts preserved'));
 sent=[];alerts=[];confirmations=0;
 selected[0].setup_work_day_id=12;
 selected[1].setup_work_day_id=12;
 await ctx.board205DropToCell(drag,12,'AFTERNOON',9,null);
 assert.equal(preserve,false,'same-day intentional shift move allowed');
 assert.deepEqual(sent.map(x=>x.shift_code),['AFTERNOON','AFTERNOON']);
 console.log('PASS #205 preserve mixed AM/PM across days; explicit same-day shift placement');
})().catch(err=>{console.error(err);process.exitCode=1;});
