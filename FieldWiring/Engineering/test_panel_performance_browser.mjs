// Same Production-scale fixture, actual page, original global-render behavior vs focused path.
import {createFixtureDatabase} from './power_test_database.mjs';
import {populatePowerScale} from './power_scale_fixture.mjs';
import {createServer} from 'node:http';
import {readFile} from 'node:fs/promises';
import {chromium} from 'playwright';
import assert from 'node:assert/strict';
const app=new URL('../Application/',import.meta.url);
const db=await createFixtureDatabase();
await populatePowerScale(db);
await db.exec(await readFile(new URL('../../Database/EngineeringTools/sql/171_power_snapshot_performance.sql',import.meta.url),'utf8'));
const snapshot=(await db.query("SELECT ref.site_power_snapshot('crew@example.test') data")).rows[0].data;
await db.close();
let baseline=false,requests=0;
const script=await readFile(new URL('static/power_capture.js',app),'utf8');
const focused='panelId = id;\n    renderPanels();';
assert.ok(script.includes(focused));
const server=createServer(async(req,res)=>{
 try {
  const pathname=new URL(req.url,'http://localhost').pathname;
  if(pathname==='/api/power'){requests++;res.setHeader('Content-Type','application/json');res.end(JSON.stringify(snapshot));return;}
  if(req.method!=='GET'){res.writeHead(405);res.end();return;}
  const name=pathname==='/circuits'?'circuits.html':pathname.slice(1);
  if(name.includes('..'))throw Error('Invalid path');
  res.setHeader('Content-Type',name.endsWith('.js')?'text/javascript':name.endsWith('.css')?'text/css':'text/html');
  res.end(name==='static/power_capture.js'?baseline?script.replace(focused,'panelId = id;\n    render();'):script:await readFile(new URL(name,app)));
 } catch(e){res.writeHead(404);res.end(e.message);}
});
await new Promise(resolve=>server.listen(0,'127.0.0.1',resolve));
let browser;
try {
 browser=await chromium.launch({headless:true,args:['--no-sandbox'],...(process.env.POWER_TEST_CHROMIUM?{executablePath:process.env.POWER_TEST_CHROMIUM}:{})});
 const measurements={};
 for(const old of [true,false]) {
  baseline=old;
  const page=await browser.newPage({viewport:{width:1100,height:850}});
  const errors=[];page.on('pageerror',e=>errors.push(e.message));
  await page.goto(`http://127.0.0.1:${server.address().port}/circuits`);
  await page.locator('#status').filter({hasText:'Revision 400'}).waitFor();
  const count=requests;
  const result=await page.evaluate(()=>{
   const unaffected=['detail-waypoint','equipment','installations','test-pair','test-history','breaker-checklist-rows','breaker-report-rows','actions','history'];
   const saved=Object.fromEntries(unaffected.map(id=>[id,[...document.getElementById(id).childNodes]]));
   const times=[];
   for(let i=0;i<12;i++) {
    const target=document.querySelectorAll('#panels button')[i%17];
    const start=performance.now();target.click();times.push(performance.now()-start);
   }
   return {times,retained:unaffected.every(id=>saved[id].length===document.getElementById(id).childNodes.length&&saved[id].every((n,i)=>n===document.getElementById(id).childNodes[i])),selected:document.querySelector('#panels [aria-pressed="true"]').textContent,detail:document.getElementById('panel-detail').textContent};
  });
  assert.equal(requests,count,'panel clicks issue no API request');
  assert.equal(result.retained,!old,'candidate retains unrelated DOM; baseline rebuilds it');
  assert.match(result.detail,/Panel 12/);assert.match(result.selected,/Panel 12/);
  if(!old) {
   // Report/checklist navigation uses focused rendering too, retaining report rows.
   await page.locator('#show-breaker-report').click();
   const first=page.locator('#breaker-report-rows button').first();
   const handle=await first.elementHandle();await first.click();
   assert.equal(await handle.evaluate(n=>n.isConnected),true);
   await page.reload();await page.locator('#status').filter({hasText:'Revision 400'}).waitFor();
   assert.match(await page.locator('#panel-detail').innerText(),/Panel 1/);
  }
  assert.deepEqual(errors,[]);
  measurements[old?'global_render_baseline':'focused_panel_render']=result.times.map(t=>Math.round(t*100)/100);
  await page.close();
 }
 console.log(JSON.stringify({fixture:'synthetic Production-scale DOM, local Chromium; not protected Production',milliseconds:measurements}));
 console.log('PASS: focused click/report navigation, unrelated DOM retained, selection and reload retained, no API calls');
} finally {if(browser)await browser.close();server.closeAllConnections();await new Promise(resolve=>server.close(resolve));}
