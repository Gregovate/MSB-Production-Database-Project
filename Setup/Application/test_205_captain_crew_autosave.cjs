/* #205 real autosave function execution: no browser, DB, or network writes. */
const fs = require('node:fs');
const vm = require('node:vm');
const assert = require('node:assert/strict');
const source = fs.readFileSync(__dirname + '/setup_scheduling_board.js', 'utf8');
const begin = source.indexOf('function board205CrewDraft(crewNode) {');
const stop = source.indexOf('\nasync function board205RemoveCrew(crewId) {', begin);
assert(begin >= 0 && stop > begin, 'Crew autosave section missing');
assert(!source.includes('setup-board205-save-crew'), 'Manual Save button still exists');
const crew = {
  setup_work_day_crew_id:7, setup_work_day_id:11, crew_code:'B',
  captain_person_id:null, am_planned_crew_count:null, pm_planned_crew_count:null
};
const controls = {
  '.setup-board205-crew-captain-select': {value:''},
  '.setup-board205-crew-am': {value:''},
  '.setup-board205-crew-pm': {value:''},
};
const status = {textContent:'', classList:{toggle:()=>{}}};
const node = {querySelector:key=>key==='.setup-board205-crew-save-status' ? status : controls[key]};
let error = null, gate = null, releaseGate = null, requests = [], messages = [], promotionCount = 0;
const ctx = {
  Map, Promise, Number,
  board205CrewAutosaveState: new Map(),
  appState:{access:{can_manage_setup:true}},
  setupBoard205State:{board:{crews:[crew]}},
  nullableInteger:value=>value===''||value==null?null:Number(value),
  board205CrewRow:()=>crew,
  board205CrewCapacityWarnings:()=>[],
  board205CaptainCandidate:id=>Number(id)===28 ? {display_name:'Test Captain'} : null,
  board205MaybeLearnCaptainForCrewAssignments:async()=>{promotionCount++;},
  commandOptions:(method,payload)=>({method,payload}),
  setAlert:(msg,kind)=>messages.push({msg,kind}),
  window:{confirm:()=>true},
  document:{querySelector:()=>node},
  api:async(url,options)=>{
    requests.push({url,options});
    if (gate) await gate;
    if (error) throw error;
    return {crew:{...options.payload}};
  }
};
vm.createContext(ctx);
vm.runInContext(source.slice(begin,stop),ctx);
(async ()=>{
  controls['.setup-board205-crew-captain-select'].value='28';
  controls['.setup-board205-crew-am'].value='2';
  assert.equal(await ctx.board205SaveCrew(7,node),true);
  assert.equal(requests.length,1);
  assert.equal(crew.captain_person_id,28);
  assert.equal(crew.am_planned_crew_count,2);
  assert.equal(status.textContent,'Saved');
  assert.equal(promotionCount,1);
  assert.equal(await ctx.board205SaveCrew(7,node),true);
  assert.equal(requests.length,1,'same draft must not re-patch');
  controls['.setup-board205-crew-pm'].value='3';
  assert.equal(await ctx.board205SaveCrew(7,node),true);
  assert.equal(crew.pm_planned_crew_count,3);
  assert.equal(promotionCount,1,'count change does not re-prompt Captain');
  error=new Error('Connection lost');
  controls['.setup-board205-crew-am'].value='4';
  assert.equal(await ctx.board205SaveCrew(7,node),false);
  assert.equal(crew.am_planned_crew_count,2,'failed write cannot fake success');
  assert.equal(controls['.setup-board205-crew-am'].value,'4','unsaved input retained');
  assert.match(status.textContent,/Not saved/);
  assert(messages.some(x=>x.kind==='error'));
  assert.equal(await ctx.board205EnsureCrewSaved(7),false,'drop must refuse failed save');
  error=null;
  assert.equal(await ctx.board205EnsureCrewSaved(7),true);
  assert.equal(crew.am_planned_crew_count,4);
  gate=new Promise(resolve=>{releaseGate=resolve;});
  controls['.setup-board205-crew-am'].value='5';
  const first=ctx.board205SaveCrew(7,node);
  controls['.setup-board205-crew-pm'].value='6';
  const second=ctx.board205SaveCrew(7,node);
  releaseGate();
  assert.equal(await first,true);
  assert.equal(await second,true);
  assert.equal(crew.am_planned_crew_count,5);
  assert.equal(crew.pm_planned_crew_count,6);
  gate=null;
  ctx.appState.access.can_manage_setup=false;
  controls['.setup-board205-crew-pm'].value='7';
  assert.equal(await ctx.board205SaveCrew(7,node),false);
  assert.equal(crew.pm_planned_crew_count,6,'non-manager must not autosave');
  console.log('PASS #205 Captain/crew autosave, atomic drafts, failed-save drop gate, no redundant Save');
})().catch(e=>{console.error(e);process.exitCode=1;});
