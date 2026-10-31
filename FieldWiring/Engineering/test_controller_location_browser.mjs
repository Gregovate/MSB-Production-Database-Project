// Exercise the real Record Location page and offline queue; network API is isolated.
import {chromium} from 'playwright';
import {createServer} from 'node:http';
import {readFile} from 'node:fs/promises';
import assert from 'node:assert/strict';
const writes=[];
const server=createServer(async(req,res)=>{
 const u=new URL(req.url,'http://localhost');
 res.setHeader('Cache-Control','no-store');
 const json=x=>{res.setHeader('Content-Type','application/json');res.end(JSON.stringify(x));};
 if(u.pathname.endsWith('/api/setup/access'))return json({access:{can_move_setup_assets:true,authenticated_email:'fixture@example.org'}});
 if(u.pathname.endsWith('/api/setup/locate/references'))return json({format_version:1,data_mode:'postgres',waypoints:[]});
 if(u.pathname.endsWith('/api/setup/movements/state'))return json({state:{asset_type:'CONTROLLER',asset_id:1001,label:'Controller 1001',movement_status:null}});
 if(u.pathname.endsWith('/api/setup/movements')&&req.method==='POST'){
  let raw='';for await(const chunk of req)raw+=chunk;const p=JSON.parse(raw);writes.push(p);return json({movement:{asset_type:p.asset_type,asset_id:p.asset_id,unloaded_display_count:0}});
 }
 const files={'/setup/record-location/':'record_location.html','/setup/record-location/assets/setup_record_location.js':'setup_record_location.js','/setup/record-location/assets/setup_record_location.css':'setup_record_location.css'};
 if(files[u.pathname]){res.setHeader('Content-Type',u.pathname.endsWith('.js')?'text/javascript':u.pathname.endsWith('.css')?'text/css':'text/html');res.end(await readFile('Setup/Application/'+files[u.pathname]));return;}
 res.statusCode=404;res.end();
});
await new Promise(r=>server.listen(0,'127.0.0.1',r));
const browser=await chromium.launch({headless:true});
try{
 const ctx=await browser.newContext({serviceWorkers:'block'}),page=await ctx.newPage();
 const base=`http://127.0.0.1:${server.address().port}/setup/record-location/`;
 await page.goto(base+'?asset=CTRL:1001&season_year=2026');
 await page.locator('#movement-pending-title').filter({hasText:'CTRL:1001'}).waitFor();
 assert.equal(writes.length,0,'scanning/deep link alone must not record');
 await page.locator('.location-note-details > summary').click();
 await page.locator('#movement-location-note').fill('Park arrival');
 await page.locator('#movement-record-here').click();
 await page.waitForFunction(()=>document.querySelector('#movement-feedback').textContent.includes('RECORDED'));
 assert.equal(writes.length,1);assert.equal(writes[0].asset_type,'CONTROLLER');assert.equal(writes[0].movement_action,'CONTROLLER_MOVE');
 assert.equal(writes[0].reconciliation,undefined);
 await page.locator('#movement-manual-input').fill('https://my.sheboyganlights.org/scan/CTRL/1001');
 await page.locator('#movement-manual-go').click();
 await page.locator('#movement-pending-title').filter({hasText:'CTRL:1001'}).waitFor();
 await ctx.setOffline(true);
 await page.locator('#movement-location-note').fill('Offline park drop');
 await page.locator('#movement-record-here').click();
 await page.waitForFunction(()=>document.querySelector('#movement-queue').textContent.includes('1'));
 assert.equal(writes.length,1);
 await ctx.setOffline(false);
 await page.waitForFunction(()=>document.querySelector('#movement-queue').textContent.includes('0'));
 assert.equal(writes.length,2);assert.equal(writes[1].offline_captured,true);assert.equal(writes[1].asset_type,'CONTROLLER');
 await page.goto(base+'?asset=CTRL:1001&season_year=2026&training=1');
 await page.locator('#movement-pending-title').filter({hasText:'CTRL:1001'}).waitFor();
 await page.locator('.location-note-details > summary').click();
 await page.locator('#movement-location-note').fill('Training only');await page.locator('#movement-record-here').click();
 await page.waitForFunction(()=>document.querySelector('#movement-feedback').textContent.includes('NOTHING RECORDED'));
 assert.equal(writes.length,2);
 console.log('Controller Record Location: deep link, full QR, explicit save, offline queue/replay and training no-write PASS');
}finally{await browser.close();await new Promise(r=>server.close(r));}
