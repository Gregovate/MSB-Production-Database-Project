// Exercise production scope mutation flows with stale organization data and a mock API.
const fs = require('node:fs');
const vm = require('node:vm');
const assert = require('node:assert/strict');
const read = name => fs.readFileSync(__dirname + '/' + name, 'utf8');
const main = read('setup_next_pass.js');
function declaration(source, name) {
  const start = source.search(new RegExp('(?:async )?function ' + name + '\\('));
  assert.ok(start >= 0, name);
  const rest = source.slice(start);
  const end = rest.slice(1).search(/\n(?:async )?function |\nconst |\nwindow\./);
  return end < 0 ? rest : rest.slice(0, end + 1);
}
async function exercise(mode, sceneId, sourceSceneId = null, sourceStageId = 21) {
  let saved = [{setup_task_id:29, stage_id:sourceStageId, lor_scene_id:sourceSceneId, task_name:'Bears', display_order:10}];
  let reads = 0, creates = 0;
  const elements = {};
  const element = id => elements[id] ||= {value:'', hidden:false, reset(){},close(){},scrollIntoView(){},focus(){}};
  const c = {console, Map, Number, String, Boolean, Promise,
    appState:{tasks: structuredClone(saved), stages:[{stage_id:20,stage_key:'20'},{stage_id:21,stage_key:'21'}],access:{can_manage_setup:true}},
    setupNextState:{scenes:[],taskScopes:new Map([[29,{...saved[0]}]]),organizationStatus:'ready',closedStages:new Set(),closedScopes:new Set(),copySourceId:29},
    el:element, nullableInteger:v=>v===''?null:Number(v),
    setBusy(){}, setAlert(){}, renderLibrary(){}, requestAnimationFrame(){},
    document:{querySelector(){return null;}}, window:{alert(message){throw Error(message);}},
    commandOptions:(method,body)=>({method,body}),
    api:async(path,options)=>{
      if(path==='api/setup/organization') {reads++;return {organization:{scenes:[{lor_scene_id:2101,stage_id:21,scene_name:'21-SnowballBears'}],task_scopes:structuredClone(saved).map(t=>({...t,scene_name:t.lor_scene_id===2101?'21-SnowballBears':t.lor_scene_id===2102?'21-Sliding Penguins':null}))}};}
      if(path.endsWith('/resources'))return {resources:[]};
      if(path==='api/setup/tasks') {creates++;saved.push({...options.body, setup_task_id:396,lor_scene_id:null});return {setup_task:{setup_task_id:396}};}
      if(path.endsWith('/scope')) {Object.assign(saved.find(x=>x.setup_task_id===Number(path.split('/')[3])),options.body);return {};}
      throw Error('Unexpected API '+path);
    },
    reloadTasks:async()=>{c.appState.tasks=structuredClone(saved);c.applyNextTaskScopes();},
    nextPersistOrder:async tasks=>{assert.ok(tasks.some(t=>t.setup_task_id===(mode==='move'?29:396)), 'destination order includes moved/created task');},
    normalizeCurrentSetupOrganization(){c.applyNextTaskScopes();}
  };
  vm.createContext(c);
  for(const name of ['applyNextTaskScopes','loadNextOrganization','nextIsSitewide','nextTasksForScope','nextScopeKey','nextTaskScopeLabel','nextMoveTask','submitNextCopy'])vm.runInContext(declaration(main,name),c);
  c.taskById=id=>c.appState.tasks.find(x=>x.setup_task_id===id);
  // Install the real decorator: the options argument must survive it.
  const live=read('setup_live_review_fixes.js');
  vm.runInContext(live.slice(live.indexOf('  const setupScenePrefix'),live.indexOf('  function ensureTaskSectionPurpose')),c);
  await c.loadNextOrganization(false);assert.equal(reads,0,'ordinary read retains cache');
  if(mode==='move')await c.nextMoveTask(29,21,sceneId);
  if(mode==='copy') {
    element('next-copy-stage').value='21';element('next-copy-scene').value=sceneId??'';element('next-copy-name').value='Setup Snowballs';
    await c.submitNextCopy({preventDefault(){}});
  }
  if(mode==='add') {
    element('add-stage-id').value='21';element('add-scene-id').value=sceneId??'';element('add-task-name').value='Setup Snowballs';element('add-display-order').value='20';
    vm.runInContext(declaration(read('setup_acceptance_fixes.js'),'acceptanceCreateReusableTask'),c);
    await c.acceptanceCreateReusableTask({preventDefault(){}});
  }
  assert.equal(reads,1,'one authoritative refresh after scope mutation');
  const id=mode==='move'?29:396;
  assert.equal(c.taskById(id).lor_scene_id,sceneId,'immediate visible placement');
  assert.equal(saved.find(x=>x.setup_task_id===id).lor_scene_id,sceneId,'saved placement');
  await c.loadNextOrganization(false,{force:true});await c.reloadTasks();
  assert.equal(c.taskById(id).lor_scene_id,sceneId,'placement after fresh load');
  assert.equal(creates,mode==='move'?0:1,'refresh never creates another task');
}
(async()=>{
 // Real normalizer must preserve organization when its request wins the bootstrap race.
 const boot = {appState:{stages:[],tasks:[]}, setupNextState:{scenes:[{lor_scene_id:2101,stage_id:21,scene_name:'21-SnowballBears'}],taskScopes:new Map([[29,{setup_task_id:29,stage_id:21,lor_scene_id:2101,scene_name:'21-SnowballBears'}]])},applyNextTaskScopes(){}};
 vm.createContext(boot);
 const live=read('setup_live_review_fixes.js');
 vm.runInContext(live.slice(live.indexOf('  const setupScenePrefix'),live.indexOf('  if (typeof loadNextOrganization ===')),boot);
 boot.normalizeCurrentSetupOrganization();
 assert.equal(boot.setupNextState.scenes.length,1,'early organization must retain Scenes');
 assert.equal(boot.setupNextState.taskScopes.get(29).lor_scene_id,2101,'early scope must survive');
 boot.appState.stages=[{stage_id:21,stage_key:'21'}];
 boot.normalizeCurrentSetupOrganization();
 assert.equal(boot.setupNextState.scenes.length,1,'Scene survives Stage bootstrap');
 assert.equal(boot.setupNextState.taskScopes.get(29).lor_scene_id,2101);
 for(const mode of ['move','copy','add'])for(const scene of [2101,null])await exercise(mode,scene);
 for(const scene of [2101,null])await exercise('move',scene,2102);
 await exercise('move',null,null,20);
 await exercise('copy',null,null,20);
 console.log('PASS: Stage-to-Scene, Scene-to-Stage, Scene-to-Scene; Copy/Add into Scene and Stage; immediate/fresh-load placement, cache and create counts');
})().catch(e=>{console.error(e);process.exitCode=1;});
