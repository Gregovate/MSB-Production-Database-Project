"""Real Chromium DOM regression with fixture API responses, no Node or database.

Opt in with MSB_QC_BROWSER=/path/to/chrome. This proves rendering/event routing,
not PostgreSQL authorization or protected operator acceptance on the clone.
The entire candidate production.html and its actual scripts/styles are served.
"""
import os
import re
import html
from pathlib import Path
import subprocess
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer
from threading import Thread
import pytest

APP = Path(__file__).resolve().parent
BROWSER = os.environ.get('MSB_QC_BROWSER')

BOOT = r'''<script>
window.qcTestErrors=[];
addEventListener('error',e=>qcTestErrors.push(e.message));
window.qcFixture={findings:[],auditors:[],unreconciled_intake:[{intake_id:85,stage_id:null,problem:"WRONG AREA LEGACY REPORT"}]};
window.qcWrites=[];
window.fetch=async (url,options={})=>{
 const path=String(url), action=options.body ? JSON.parse(options.body) : null;
 let body={};
 if(path.includes('api/health')) body={version:'V0.3.117-qc-status'};
 if(path.includes('qc/intake-candidates')) throw Error('Normal QC requested legacy Intake');
 if(path.includes('api/setup/qc/action')) {
  qcWrites.push(action);
  if(action.action==='REPORT_LINES') action.note.split(/\r?\n/).filter(line=>line.trim()).forEach((line,index)=>qcFixture.findings.push({qc_finding_id:71+index,
    setup_session_task_id:action.setup_session_task_id,title:line,status:'OPEN',
    stage_key:'25',stage_name:'Racing Arches',scene_name:'Test scene',events:[{type:'REPORTED',note:line}]}));
  else if(action.action==='CLAIM_AUDIT') qcFixture.auditors.push({setup_session_task_id:483,auditor:'Tester'});
  else {
   const f=qcFixture.findings.find(f=>f.qc_finding_id===action.qc_finding_id);
   f.status={CLAIM_REPAIR:'CLAIMED',REPAIRED:'AWAITING_RETEST',RETEST_FAIL:'OPEN',RETEST_PASS:'VERIFIED'}[action.action]||f.status;
  }
  body={result:{finding_id:71}};
 } else if(path.includes('api/setup/qc?')) body={qc:structuredClone(qcFixture)};
 return {ok:true,status:200,json:async()=>body};
};
</script>'''

CHECK = r'''<script>
addEventListener('load',()=>setTimeout(async()=>{
 const result=document.createElement('pre');result.id='qc-browser-result';
 const assert=(ok,message)=>{if(!ok)throw Error(message);};
 const wait=()=>new Promise(r=>setTimeout(r,30));
 const click=async selector=>{
  const node=document.querySelector(selector);
  assert(node && node.getClientRects().length,'Invisible/missing control '+selector);
  node.click();await wait();
 };
 try {
  appState.access={can_read_setup:true,can_manage_setup:ROLE,role_name:ROLE?'Manager':'Production Crew'};
  appState.seasonYear=2026;
  window.msbSetupEnsureServerBuild=async()=>true;
  document.querySelectorAll('.view').forEach(v=>v.classList.remove('active-view'));
  document.querySelector('#perform-view').classList.add('active-view');
  setupNextState.performBoard={tasks:[483,598].map(id=>({setup_session_task_id:id,
   task_name:'Plug in Network to controller and watch display against 2 minute Test show',
   stage_id:25,stage_key:'25',stage_name:'Racing Arches',scene_name:'Test scene',
   execution_status:'NOT_READY',prerequisite_count:1,prerequisites_complete:false})),assignments:[]};
  renderNextExecution();
  await click('#next-qc-check-tab');
  for(const id of [483,598]) {
   await click('[data-qc-task-id="'+id+'"]');
   assert(document.querySelector('[data-qc-action="REPORT_LINES"]').getClientRects().length,'QC form missing '+id);
  }
  // Unclassified historical sources never appear under either selected area.
  assert(!document.querySelector('[data-qc-link-intake]'),'Legacy reconciliation still visible');
  assert(!document.querySelector('#next-qc-content').textContent.includes('WRONG AREA LEGACY REPORT'),'Unclassified source shown as area finding');
  assert(!qcWrites.length,'Rendering wrote data');
  const problems='arch 3 - blue lights 21" to 28" and 76" to 80" from bottom\narch 3 - all red lights\narch 4 - all red lights\narch 8 - yellow lights 12" to 20" from top\narch 9 - blue lights from top to @1 foot down\narch 11 - all blue lights';
  document.querySelector('[data-qc-problems]').value=problems;
  await click('[data-qc-action="REPORT_LINES"]');
  assert(qcWrites[0].action==='REPORT_LINES' && qcWrites[0].setup_session_task_id===598,'Report required claim or wrong task');
  assert(qcWrites[0].note===problems,'Free-form measurements changed');
  assert(qcFixture.findings.length===6,'Six lines did not become six findings');
  await click('[data-qc-task-id="483"]');
  assert(!document.querySelector('[data-qc-detail="483"] [data-qc-finding]'),'Racing Arches findings leaked into Front Entrance');
  await click('[data-qc-task-id="598"]');
  await click('#next-qc-fixes-tab');
  assert(document.querySelector('#next-perform-list').hidden,'Scheduled panel leaked');
  assert(!document.querySelector('#next-qc-search').getClientRects().length,'QC task search leaked into repairs');
  assert(document.querySelector('#next-qc-fixes-list [data-qc-finding="71"]').getClientRects().length,'Shared finding missing');
  await click('#next-qc-fixes-list [data-qc-id="71"][data-qc-action="CLAIM_REPAIR"]');
  assert(!qcWrites.at(-1).note,'Claim incorrectly requires work evidence');
  let count=qcWrites.length;
  await click('[data-qc-action="REPAIRED"]');
  assert(qcWrites.length===count,'Repair allowed without notes');
  document.querySelector('[data-qc-fix-note="71"]').value='Reconnected wire';
  await click('[data-qc-action="REPAIRED"]');
  await click('#next-qc-check-tab');
  assert(document.querySelector('[data-qc-task-id="598"]').dataset.qcState==='findings','Repair prematurely turned area green');
  assert(document.querySelector('[data-qc-task-id="598"]').textContent.includes('verification needed'),'Verification status missing');
  await click('[data-qc-action="CLAIM_AUDIT"]');
  count=qcWrites.length;
  await click('[data-qc-action="RETEST_FAIL"]');
  assert(qcWrites.length===count,'Retest allowed without evidence');
  document.querySelector('[data-qc-observation="71"]').value='Still dark in actual test';
  await click('[data-qc-action="RETEST_FAIL"]');
  await click('#next-qc-fixes-tab');
  await click('#next-qc-fixes-list [data-qc-id="71"][data-qc-action="CLAIM_REPAIR"]');
  document.querySelector('[data-qc-fix-note="71"]').value='Replaced connector';
  await click('[data-qc-action="REPAIRED"]');
  await click('#next-qc-check-tab');
  document.querySelector('[data-qc-observation="71"]').value='Channel illuminated during test';
  await click('[data-qc-action="RETEST_PASS"]');
  await click('#next-qc-fixes-tab');
  assert(!document.querySelector('#next-qc-fixes-list [data-qc-finding="71"]'),'Verified finding remains outstanding');
  await click('#next-qc-check-tab');
  assert(!document.querySelector('.next-qc-active [data-qc-finding="71"]'),'Verified finding remains in active QC list');
  assert(!document.querySelector('.next-qc-verified-history').open,'Verified history did not collapse');
  assert(document.querySelector('[data-qc-task-id="598"]').dataset.qcState==='findings','One verified finding hid the remaining failures');
  // Model all remaining findings verified, then a new failure in the same area.
  qcFixture.findings.forEach(f=>f.status='VERIFIED');
  await setupQcRenderCurrent();
  const area=document.querySelector('[data-qc-task-id="598"]');
  assert(area.dataset.qcState==='verified','All-verified area is not green');
  assert(area.textContent.includes('Final QC pending'),'Finding verification implied annual PASS');
  for(const theme of ['light','dark']) {
    document.documentElement.dataset.theme=theme;
    assert(getComputedStyle(area).backgroundColor==='rgb(220, 252, 231)','Green area lost its state color');
    assert(getComputedStyle(document.querySelector('[data-qc-task-id="483"]')).backgroundColor==='rgb(255, 255, 255)','Open area is not white');
  }
  // Simulate a second browser's new finding, then revisit the repairs screen.
  qcFixture.findings.push({qc_finding_id:80,setup_session_task_id:598,title:'Other worker report',status:'OPEN',events:[]});
  await setupQcRenderCurrent();
  assert(document.querySelector('[data-qc-task-id="598"]').dataset.qcState==='findings','New finding did not turn green area yellow');
  // A new finding alongside a repaired/unverified finding also stays yellow.
  qcFixture.findings[0].status='AWAITING_RETEST';
  await setupQcRenderCurrent();
  assert(document.querySelector('[data-qc-task-id="598"]').textContent.includes('verification needed'),'Mixed unverified/new findings lost retest warning');
  assert(document.querySelector('[data-qc-finding="80"]'),'Other worker finding hidden by cached snapshot');
  for(const theme of ['light','dark']) {
   document.documentElement.dataset.theme=theme;
   const card=document.querySelector('.next-qc-active [data-qc-finding="80"]');
   const style=getComputedStyle(card);
   assert(getComputedStyle(document.querySelector('[data-qc-task-id="598"]')).backgroundColor==='rgb(254, 243, 199)','Area is not yellow');
   assert(style.color!==style.backgroundColor,'Unreadable '+theme+' card');
   card.querySelectorAll('details').forEach(d=>d.open=true);
   const note=card.querySelector('textarea');
   assert(getComputedStyle(note).color!==getComputedStyle(note).backgroundColor,'Unreadable '+theme+' notes');
  }
  await click('#next-qc-work-tab');
  assert(!document.querySelector('#next-perform-list').hidden,'Scheduled Work not restored');
  assert(document.querySelector('#next-qc-content').hidden,'QC remains visible in Scheduled Work');
  assert(!qcTestErrors.length,'Browser errors: '+qcTestErrors.join('; '));
  result.textContent='PASS';
 } catch(e) {result.textContent='FAIL: '+e.stack;}
 document.body.append(result);
},150));
</script>'''


@pytest.mark.skipif(not BROWSER, reason='Set MSB_QC_BROWSER for real Chromium regression; no Node')
@pytest.mark.parametrize('manager', [False, True])
def test_qc_real_page_controls_and_shared_finding_lifecycle(tmp_path, manager):
    """Exercise actual DOM controls, including both failure modes from review."""
    page = (APP/'production.html').read_text().replace('<head>', '<head>'+BOOT)
    page = page.replace('</body>', CHECK.replace('ROLE', str(manager).lower())+'</body>')

    class Handler(SimpleHTTPRequestHandler):
        def __init__(self, *args, **kwargs):
            super().__init__(*args, directory=str(APP), **kwargs)

        def log_message(self, *_):
            pass

        def do_GET(self):
            if self.path == '/production.html':
                data = page.encode()
                self.send_response(200)
                self.send_header('Content-Type', 'text/html')
                self.send_header('Content-Length', str(len(data)))
                self.end_headers()
                self.wfile.write(data)
            else:
                # Use the real Flask asset boundary. A permissive file server
                # hid the missing QC registration during the failed review.
                from production_backend import app
                with app.test_client() as client:
                    response = client.get(self.path)
                    self.send_response(response.status_code)
                    self.send_header('Content-Type', response.content_type)
                    self.send_header('Content-Length', str(len(response.data)))
                    self.end_headers()
                    self.wfile.write(response.data)

    server = ThreadingHTTPServer(('127.0.0.1', 0), Handler)
    thread = Thread(target=server.serve_forever, daemon=True)
    thread.start()
    try:
        run = subprocess.run([BROWSER, '--headless', '--no-sandbox', '--disable-gpu',
            '--disable-background-networking', '--disable-dev-shm-usage',
            '--user-data-dir='+str(tmp_path/'profile'), '--dump-dom',
            '--virtual-time-budget=10000',
            f'http://127.0.0.1:{server.server_port}/production.html'],
            capture_output=True, text=True, timeout=40)
        assert run.returncode == 0, run.stderr[-3000:]
        result = re.search(r'<pre id="qc-browser-result">(.*?)</pre>', run.stdout, re.S)
        assert result, 'Browser regression did not finish: '+run.stderr[-1500:]
        assert html.unescape(result.group(1)) == 'PASS', html.unescape(result.group(1))
    finally:
        server.shutdown()
        server.server_close()
        thread.join(timeout=3)


def test_production_page_scripts_are_served_by_real_backend():
    """Catch missing asset registration without Chromium, Node or a database."""
    # Backend startup installs repository extensions. Isolate that startup so
    # this HTTP test does not alter unrelated repository-unit-test fixtures.
    import sys
    code = r'''import re
from production_backend import app
with app.test_client() as client:
    page = client.get('/')
    assert page.status_code == 200
    scripts = re.findall(r'<script[^>]+src="([^"]+)"', page.get_data(as_text=True))
    assert any(url.startswith('setup_qc.js?') for url in scripts)
    for url in scripts:
        response = client.get('/' + url)
        assert response.status_code == 200, f'{url}: HTTP {response.status_code}'
        assert response.mimetype == 'application/javascript', url
    assert client.get('/setup_qc_api.py').status_code == 404
'''
    result = subprocess.run([sys.executable, '-c', code], cwd=APP,
                            capture_output=True, text=True, timeout=30)
    assert result.returncode == 0, result.stdout + result.stderr
