import {chromium} from 'playwright';
import {createServer} from 'node:http';
import {readFile} from 'node:fs/promises';
import assert from 'node:assert/strict';
const writes=[];let rows=[];
const server=createServer(async(req,res)=>{
 const u=new URL(req.url,'http://localhost');const json=x=>{res.setHeader('Content-Type','application/json');res.end(JSON.stringify(x));};
 if(u.pathname.endsWith('/api/setup/container-pickups')){
  if(req.method==='POST'){let raw='';for await(const c of req)raw+=c;const p=JSON.parse(raw);writes.push(p);assert.equal(req.headers['x-msb-setup-command'],'1');rows=p.action==='CANCEL'?[]:[{...p,stage_key:'15',stage_name:'Church lot'}];return json({pickup_event_id:1});}
  return json({containers:rows,stages:[{stage_id:15,stage_key:'15',stage_name:'Church lot'}]});
 }
 if(u.pathname.endsWith('/api/setup/movements/state'))return json({state:{label:'Panels',current_stage_id:15,current_location_note:'Beside arches'}});
 if(u.pathname==='/setup/container-pickups/'){res.setHeader('Content-Type','text/html');res.end(await readFile('Setup/Application/container_pickups.html'));return;}
 res.statusCode=404;res.end();
});
await new Promise(r=>server.listen(0,'127.0.0.1',r));const browser=await chromium.launch({headless:true});
try{const page=await browser.newPage();const base=`http://127.0.0.1:${server.address().port}/setup/container-pickups/`;
 await page.goto(base+'?asset=CONT:95');await page.locator('#request').waitFor();assert.equal(writes.length,0);
 await page.locator('#save').click();assert.equal(writes.length,0,'empty confirmation required');
 await page.locator('#empty').check();await page.locator('#save').click();await page.locator('#rows tr').waitFor();assert.equal(writes.length,1);assert.equal(writes[0].stage_id,15);assert.equal(writes[0].location_note,'Beside arches');
 assert.match(await page.locator('#rows').innerText(),/CONT:95/);
 await page.emulateMedia({media:'print'});assert.equal(await page.locator('#request').isVisible(),false);assert.equal(await page.locator('#rows tr').isVisible(),true);await page.emulateMedia({media:'screen'});
 page.once('dialog',d=>d.accept());await page.getByRole('button',{name:'Cancel request'}).click();await page.waitForFunction(()=>document.querySelectorAll('#rows tr').length===0);assert.equal(writes[1].action,'CANCEL');
 await page.goto(base+'?asset=CONT:95&training=1');await page.locator('#request').waitFor();await page.locator('#empty').check();await page.locator('#save').click();assert.match(await page.locator('#status').innerText(),/nothing recorded/);assert.equal(writes.length,2);
 console.log('Container pickup browser: scan no-write, explicit empty confirmation, request, printable report, cancel and training PASS');
}finally{await browser.close();await new Promise(r=>server.close(r));}
