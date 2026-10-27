// Execute shipped popup rendering with the actual snapshot's primary-key names.
const fs=require('fs'),vm=require('vm'),assert=require('assert');
const source=fs.readFileSync(__dirname+'/setup_site_reference.js','utf8');
const helpers=source.slice(source.indexOf('  const byId ='),source.indexOf('  function field('));
const popup=source.slice(source.indexOf('  function waypointPopup('),source.indexOf('  function showWaypoint('));
const element=()=>({children:[],style:{},textContent:'',appendChild(x){this.children.push(x);},addEventListener(){}});
const current={waypoints:[{id:1,label:'PANEL 42-00',type:'Panel'},{id:2,label:'42-03S',type:'OUT-Combo'},{id:3,label:'Unknown supply'}],
 panels:[{site_panel_id:9,site_waypoint_id:1}],circuits:[8,10,1].map(n=>({site_power_circuit_id:100+n,circuit_code:String(n),panel_waypoint_id:1})),
 destinations:[8,10].map(n=>({site_power_circuit_id:100+n,site_waypoint_id:2})),
 panel_outlets:[{site_power_device_id:7,site_panel_id:9,site_power_circuit_id:101,device_name:'Lower left'}],memberships:[],networks:[],instructions:[],cables:[]};
const context={current,document:{createElement:element}};
vm.createContext(context);vm.runInContext(helpers+popup,context);
const text=e=>[e.textContent,...e.children.map(text)].join(' ');
let rendered=text(vm.runInContext('waypointPopup(current.waypoints[1])',context));
assert.match(rendered,/PANEL 42-00 \/ 8; PANEL 42-00 \/ 10/);
assert.doesNotMatch(rendered,/Supplying circuit\(s\): Not recorded/);
rendered=text(vm.runInContext('waypointPopup(current.waypoints[0])',context));
assert.match(rendered,/1 supplies At panel: Lower left/);
assert.match(rendered,/8 supplies 42-03S/);assert.match(rendered,/10 supplies 42-03S/);
assert.match(rendered,/Supplying circuit\(s\): Not recorded/,'local receptacle must not imply incoming panel supply');
assert.match(text(vm.runInContext('waypointPopup(current.waypoints[2])',context)),/Supplying circuit\(s\): Not recorded/);
current.panel_outlets=[];
assert.match(text(vm.runInContext('waypointPopup(current.waypoints[0])',context)),/1 supplies unknown destinations/);
console.log('PASS: map displays both circuit legs, explicit local outlets and genuinely unknown destinations.');
