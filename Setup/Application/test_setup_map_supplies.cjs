// Execute shipped map helpers and disclosure against the real snapshot key names.
const fs=require('fs'),vm=require('vm'),assert=require('assert');
const source=fs.readFileSync(__dirname+'/setup_site_reference.js','utf8');
const helpers=source.slice(source.indexOf('  const byId ='),source.indexOf('  function field('));
const popup=source.slice(source.indexOf('  function waypointPopup('),source.indexOf('  function showWaypoint('));
// Keep the active detail renderer; legacy disabled editor code is outside this test.
const detail=source.slice(source.indexOf('  function showWaypoint('),source.indexOf('    if (false &&'))+'\n}';
const element=()=>({children:[],style:{},textContent:'',appendChild(x){this.children.push(x);},addEventListener(k,f){this[k]=f;},replaceChildren(){this.children=[];}});
const current={waypoints:[{id:1,label:'PANEL 42-00',type:'Panel'},{id:2,label:'42-03S',type:'OUT-Combo'},{id:3,label:'Unknown supply'}],
 panels:[{site_panel_id:9,site_waypoint_id:1}],circuits:[8,10,1,3,2,4].map(n=>({site_power_circuit_id:100+n,circuit_code:String(n),panel_waypoint_id:1,site_panel_id:9,site_power_breaker_id:[1,3].includes(n)?7:[2,4].includes(n)?8:9})),
 breakers:[{site_power_breaker_id:7,panel_outlets:true,source_evidence:'Bottom Panel Outlets'},{site_power_breaker_id:8,panel_outlets:false,source_evidence:'Top Panel Outlets'}],
 destinations:[8,10].map(n=>({site_power_circuit_id:100+n,site_waypoint_id:2})),
 memberships:[{site_waypoint_id:2,site_network_id:42},{site_waypoint_id:2,site_network_id:42}],networks:[{site_network_id:42,network_code:'AUX-A'}],instructions:[],cables:[],
 flw_tests:[{test_uuid:'one',endpoint_a:2,endpoint_b:3,network_key:'AUX-A',test_status_code:1,reliable_test_time:'2026-10-25 10:00',length_ft:100,physical_site_cable_id:null}]};
const body=element();let focused=false,scrolled=false;
const inspection={focus(){focused=true;},scrollIntoView(){scrolled=true;}};
const context={current,body,inspection,selection:null,selectedTrack:null,lastEditMessage:'',document:{createElement:element}};
vm.createContext(context);vm.runInContext(helpers+popup+detail,context);
const text=e=>[e.textContent,...e.children.map(text)].join(' ');
let node=vm.runInContext('waypointPopup(current.waypoints[1])',context),rendered=text(node);
assert.match(rendered,/PANEL 42-00 \/ 8; PANEL 42-00 \/ 10/);
assert.match(rendered,/Networks: AUX-A/);assert.doesNotMatch(rendered,/AUX-A, AUX-A/);
assert.match(rendered,/Cable tests: 1/);assert.match(rendered,/Cable details/);
assert.ok(node.children.some(x=>x.href==='/fieldwiring/circuits?panel=9'));
assert.equal(node.children.at(-1).href,'/fieldwiring/cable-tests?waypoint=2');
vm.runInContext('showWaypoint(2)',context);
assert.equal(inspection.open,true);assert.ok(focused&&scrolled);
assert.match(text(body),/AUX-A: 42-03S ↔ Unknown supply/);assert.match(text(body),/PASS/);
assert.ok(body.children.some(x=>x.href==='/fieldwiring/cable-tests?waypoint=2'));
assert.doesNotMatch(text(body),/provenance|revision|UUID|UNKNOWN|unreviewed|physical cable identity|raw result/);
rendered=text(vm.runInContext('waypointPopup(current.waypoints[0])',context));
assert.ok(vm.runInContext('waypointPopup(current.waypoints[0])',context).children.some(x=>x.href==='/fieldwiring/circuits?panel=9'));
assert.match(rendered,/Circuit 1: Outlets at panel — Bottom Panel Outlets/);
assert.match(rendered,/Circuit 3: Outlets at panel — Bottom Panel Outlets/);
assert.match(rendered,/Circuit 2: Top Panel Outlets/);assert.match(rendered,/Circuit 4: Top Panel Outlets/);
assert.match(rendered,/Circuit 8: 42-03S/);assert.doesNotMatch(rendered,/unknown destinations/);
assert.match(text(vm.runInContext('waypointPopup(current.waypoints[2])',context)),/Power: Not recorded/);
assert.ok(vm.runInContext('waypointPopup(current.waypoints[2])',context).children.some(x=>x.textContent==='Find panel'&&x.href==='/fieldwiring/circuits'));
console.log('PASS: saved supplies, breaker outlets/notes, FLW networks/tests without physical cable, plain details and focus/scroll.');
