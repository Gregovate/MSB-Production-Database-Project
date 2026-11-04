/* Disposable browser-transport tests: no network or signed-in session. */
'use strict';
const assert = require('node:assert/strict');
const fs = require('node:fs');
const vm = require('node:vm');
const path = require('node:path');
const source = fs.readFileSync(path.join(__dirname, '../../../LOR2DB/Application/landing/pc/handoff.js'), 'utf8');
async function run(installed, releaseOK) {
  const nodes = new Map();
  for (const id of ['#status','#open-updater','#handoff-details']) nodes.set(id, {textContent:'', addEventListener(){}});
  let posted;
  const response = (data, ok=true) => ({ok, status:ok?200:503, headers:{get:()=> 'application/json'}, json:async()=>data});
  const context = {
    document:{querySelector:id=>nodes.get(id)},
    location:{hash:'#port=23456&nonce='+'a'.repeat(64)+(installed?'&updater='+installed:''), pathname:'/lor2db/pc/'},
    history:{replaceState(){}}, URLSearchParams, AbortSignal, Date,
    navigator:{permissions:{query:async()=>({state:'granted'})}},
    fetch:async(url, options)=>{
      if(url.includes('current-source')) return response({schema_version:3, evidence_id:'b'.repeat(64)});
      if(url.includes('updater-release.json')) { assert.equal(options.cache,'no-store'); assert.equal(options.credentials,'same-origin');return response({schema_version:1,latest_version:'1.1.3'},releaseOK); }
      posted=JSON.parse(options.body);return response({});
    }
  };
  context.globalThis=context;
  await vm.runInNewContext(source,context);
  return {posted,status:nodes.get('#status').textContent};
}
(async()=>{
  let r=await run('1.1.3',true);assert.equal(r.posted.updater_release.latest_version,'1.1.3');assert.match(r.status,/version checked/);
  r=await run(null,true);assert.match(r.status,/needs updating/);
  r=await run('1.1.2',true);assert.match(r.status,/Installed updater: 1.1.2/);
  r=await run('1.1.3',false);assert.equal(r.posted.updater_release,null);
  console.log('PASS: browser relays fresh version evidence, identifies legacy updater, and retains version-check failure');
})().catch(error=>{console.error(error);process.exitCode=1;});
