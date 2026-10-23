/* #205: actual delegated action handler, no browser/backend writes. */
const fs=require('node:fs');
const vm=require('node:vm');
const assert=require('node:assert/strict');
const source=fs.readFileSync(__dirname+'/setup_next_pass.js','utf8');
const start=source.indexOf('function setup205WireActionCenter(root) {');
const end=source.indexOf('\nfunction renderNextExecution()',start);
assert(start>=0 && end>start,'Action Center handler exists');
let callback;
let visited=[],opened=[],alerts=[],historyLoaded=0,focused=0,scrolled=0,redrawn=0;
const dayContent={hidden:true,closest:()=>({querySelector:()=>({
  setAttribute:(key,value)=>opened.push([key,value])
})})};
const assignment={
 dataset:{assignmentId:'101'},open:false,
 closest:(name)=>name==='.next-perform-day-content'?dayContent:null,
 scrollIntoView:()=>scrolled++,
 querySelector:(selector)=>selector==='.next-performed-on'?{focus:()=>focused++}:null
};
const all={checked:false};
const setupNextState={performCaptainFilter:'CAPTAIN:42',performCaptainFilterTouched:false};
const appState={access:{can_manage_setup:true}};
const setupBoard205State={board:{work_days:[{setup_work_day_id:9,work_date:'2026-10-14'}]}};
const ctx={
 Number, String, appState,setupNextState,setupBoard205State,
 navigateSetupView: async name=>{visited.push(name);return true;},
 document:{
  getElementById:id=>id==='next-perform-show-completed'?all:null,
  querySelectorAll:s=>s==='#next-perform-list .next-perform-assignment'?[assignment]:[]
 },
 renderNextExecution:()=>redrawn++,
 loadNextTaskExecution:async()=>historyLoaded++,
 board205OpenScheduleDialog:o=>opened.push(o),
 board205OpenPlanningInfoDialog:id=>opened.push(['planning',id]),
 board205FocusWorkDate:date=>opened.push(['day',date]),
 setAlert:msg=>alerts.push(msg)
};
vm.createContext(ctx);
vm.runInContext(source.slice(start,end),ctx);
const root={
 dataset:{},
 addEventListener:(type,fn)=>{assert.equal(type,'click'); callback=fn;},
 contains:()=>true
};
ctx.setup205WireActionCenter(root);
const original=callback;
ctx.setup205WireActionCenter(root);
assert.equal(callback,original,'handler installed only once');
async function click(action,id){
 let prevented=0,stopped=0;
 await callback({
   target:{closest:()=>({dataset:{'205Action':action,id:String(id)}})},
   preventDefault:()=>prevented++,stopPropagation:()=>stopped++
 });
 assert.equal(prevented,1);
 assert.equal(stopped,1);
}
(async()=>{
 await click('report',101);
 assert.equal(visited.at(-1),'perform');
 assert.equal(setupNextState.performCaptainFilter,'ALL');
 assert.equal(setupNextState.performCaptainFilterTouched,true);
 assert.equal(all.checked,true);
 assert.equal(dayContent.hidden,false,'collapsed historical workday revealed');
 assert.equal(assignment.open,true);
 assert.equal(historyLoaded,1,'original assignment history loaded');
 assert.equal(focused,1,'actual work form focus');
 assert.equal(scrolled,1,'exact assignment brought into view');
 assert.deepEqual(opened[0],['aria-expanded','true']);
 assert.equal(redrawn,1);
 await click('schedule',202);
 assert.equal(visited.at(-1),'schedule');
 assert.equal(opened.at(-1).kind,'task');
 assert.equal(opened.at(-1).id,202);
 await click('planning',202);
 assert.equal(opened.at(-1)[0],'planning');
 assert.equal(opened.at(-1)[1],202);
 await click('day',9);
 assert.equal(opened.at(-1)[1],'2026-10-14');
 const visits=visited.length;
 appState.access.can_manage_setup=false;
 await click('report',101);
 assert.equal(visited.length,visits,'Manager action denied for non-Manager');
 assert.equal(alerts.length,0,'no unexpected navigation errors');
 console.log('PASS #205 Manager original assignment, collapsed day, schedule, readiness, permission navigation');
})().catch(err=>{console.error(err);process.exitCode=1;});
