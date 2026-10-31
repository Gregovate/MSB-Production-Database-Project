// Exercise the real Catalog loop against viewport and nested scroll owners.
const fs=require('node:fs'),vm=require('node:vm'),assert=require('node:assert/strict');
const source=fs.readFileSync(__dirname+'/setup_next_pass.js','utf8');
const handlers={},frames=new Map();let id=0;
const root={isConnected:true,scrollTop:300},body={};
const catalog={dataset:{},contains:n=>n?.catalog===true};
const c={setupNextState:{draggedTaskId:395},el:n=>n==='library-list'?catalog:{hidden:false},
 document:{body,scrollingElement:root,querySelector:()=>({getBoundingClientRect:()=>({bottom:100})}),addEventListener:(n,f)=>{handlers[n]=f;}},
 window:{innerHeight:800,getComputedStyle:n=>({overflowY:n.overflowY||'visible'}),requestAnimationFrame:f=>{frames.set(++id,f);return id;},cancelAnimationFrame:n=>frames.delete(n),addEventListener:(n,f)=>{handlers[n]=f;}}};
vm.createContext(c);vm.runInContext(source.slice(source.indexOf('const nextCatalogDragScroll'),source.indexOf('function nextIsSitewide')),c);
function tick(){const [n,f]=frames.entries().next().value;frames.delete(n);f();}
c.nextInstallCatalogDragScroll();c.nextInstallCatalogDragScroll();
const row={catalog:true,parentElement:body};
handlers.dragover({target:row,clientY:790});tick();assert.equal(root.scrollTop,320);
tick();assert.equal(root.scrollTop,340,'stationary pointer continues scrolling');
handlers.dragover({target:row,clientY:105});tick();assert.equal(root.scrollTop,320,'scroll upward below sticky header');
handlers.dragover({target:row,clientY:400});tick();assert.equal(root.scrollTop,320,'center does not scroll');
handlers.drop();assert.equal(frames.size,0,'drop cancels loop');
const pane={isConnected:true,parentElement:body,scrollHeight:2000,clientHeight:500,overflowY:'auto',scrollTop:100,getBoundingClientRect:()=>({top:200,bottom:700})};
row.parentElement=pane;
handlers.dragover({target:row,clientY:690});tick();assert.equal(pane.scrollTop,120);assert.equal(root.scrollTop,320);
handlers.dragover({target:row,clientY:205});tick();assert.equal(pane.scrollTop,100);
handlers.dragend();assert.equal(frames.size,0);
handlers.dragover({target:row,clientY:690});handlers.blur();assert.equal(frames.size,0);
handlers.dragover({target:row,clientY:690});handlers.dragover({target:{},clientY:790});assert.equal(frames.size,0,'leaving Catalog stops scrolling');
c.setupNextState.draggedTaskId=null;handlers.dragover({target:row,clientY:690});assert.equal(frames.size,0,'unrelated drag does not scroll');
console.log('PASS Catalog edge scrolling: page/panel up/down, stationary pointer, center, cleanup, unrelated drag');
