// Keep Additional Equipment placement separate from controller LOR eligibility.
import vm from 'node:vm';import {readFileSync} from 'node:fs';import assert from 'node:assert/strict';
const context={window:{}};vm.runInNewContext(readFileSync(new URL('../Application/static/equipment_capture.js',import.meta.url),'utf8'),context);
const api=context.window.MSBEquipmentCapture;
const data={waypoints:[{id:1,name:'Stage',type:'Stage'},{id:2,name:'Box',type:'OUT-Combo'},{id:3,name:'Pole',type:'Pole-Power'},{id:4,name:'Network',type:'Network',network_capable:false},{id:5,name:'Combo in name only',type:'Landmark'}]};
assert.deepEqual(Array.from(api.waypointChoices(data),r=>r[0]),[2,3,4]);
assert.deepEqual(Array.from(api.waypointChoices(data,[1]),r=>r[0]),[1,2,3,4]);
assert.match(api.waypointChoices(data,[1])[0][1],/recorded; reconcile/);
for(const kind of ['FUSE','DISCONNECT','OUTLET','LIGHT_POLE'])assert.equal(api.isAdditionalDevice({device_kind:kind}),false);
for(const kind of ['POWER_SUPPLY','POE_SWITCH','ETHERNET_SWITCH','RS485_REPEATER','OTHER'])assert.equal(api.isAdditionalDevice({device_kind:kind}),true);
console.log('Equipment type/location boundaries and recorded legacy locations PASS');
