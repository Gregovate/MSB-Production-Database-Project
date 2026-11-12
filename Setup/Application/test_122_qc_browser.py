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
window.qcFixture={findings:[],auditors:[],unreconciled_intake:[]};
window.qcWrites=[];
window.fetch=async (url,options={})=>{
 const path=String(url), action=options.body ? JSON.parse(options.body) : null;
 let body={};
 if(path.includes('api/health')) body={version:'V0.3.114-qc-history'};
 if(path.includes('qc/intake-candidates')) return {ok:false,status:503,json:async()=>({error:'Fixture Intake unavailable'})};
 if(path.includes('api/setup/qc/action')) {
  qcWrites.push(action);
  if(action.action==='REPORT') qcFixture.findings.push({qc_finding_id:71,
    setup_session_task_id:action.setup_session_task_id,title:action.title,status:'OPEN',
    stage_key:'25',stage_name:'Racing Arches',scene_name:'Test scene',events:[]});
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
  for(const id of [483,598,483]) {
   await click('[data-qc-task-id="'+id+'"]');
   assert(document.querySelector('[data-qc-action="REPORT"]').getClientRects().length,'QC form missing '+id);
  }
  // Manager source failure must not remove or block the direct report form.
  assert(!qcWrites.length,'Rendering wrote data');
  document.querySelector('[data-qc-title]').value='Arch 3 red string';
  document.querySelector('[data-qc-description]').value='Red does not illuminate';
  document.querySelector('[data-qc-evidence]').value='Check connector';
  await click('[data-qc-action="REPORT"]');
  assert(qcWrites[0].action==='REPORT' && qcWrites[0].setup_session_task_id===483,'Report required claim or wrong task');
  assert(qcWrites[0].note.includes('Check connector'),'Evidence lost');
  await click('#next-qc-fixes-tab');
  assert(document.querySelector('#next-perform-list').hidden,'Scheduled panel leaked');
  assert(!document.querySelector('#next-qc-search').getClientRects().length,'QC task search leaked into repairs');
  assert(document.querySelector('#next-qc-fixes-list [data-qc-finding="71"]').getClientRects().length,'Shared finding missing');
  await click('[data-qc-action="CLAIM_REPAIR"]');
  assert(!qcWrites.at(-1).note,'Claim incorrectly requires work evidence');
  let count=qcWrites.length;
  await click('[data-qc-action="REPAIRED"]');
  assert(qcWrites.length===count,'Repair allowed without notes');
  document.querySelector('[data-qc-fix-note="71"]').value='Reconnected wire';
  await click('[data-qc-action="REPAIRED"]');
  await click('#next-qc-check-tab');
  await click('[data-qc-action="CLAIM_AUDIT"]');
  count=qcWrites.length;
  await click('[data-qc-action="RETEST_FAIL"]');
  assert(qcWrites.length===count,'Retest allowed without evidence');
  document.querySelector('[data-qc-observation="71"]').value='Still dark in actual test';
  await click('[data-qc-action="RETEST_FAIL"]');
  await click('#next-qc-fixes-tab');
  await click('[data-qc-action="CLAIM_REPAIR"]');
  document.querySelector('[data-qc-fix-note="71"]').value='Replaced connector';
  await click('[data-qc-action="REPAIRED"]');
  await click('#next-qc-check-tab');
  document.querySelector('[data-qc-observation="71"]').value='Channel illuminated during test';
  await click('[data-qc-action="RETEST_PASS"]');
  await click('#next-qc-fixes-tab');
  assert(!document.querySelector('#next-qc-fixes-list [data-qc-finding="71"]'),'Verified finding remains outstanding');
  // Simulate a second browser's new finding, then revisit the repairs screen.
  qcFixture.findings.push({qc_finding_id:72,setup_session_task_id:598,title:'Other worker report',status:'OPEN',events:[]});
  await click('#next-qc-check-tab');await click('#next-qc-fixes-tab');
  assert(document.querySelector('[data-qc-finding="72"]'),'Other worker finding hidden by cached snapshot');
  for(const theme of ['light','dark']) {
   document.documentElement.dataset.theme=theme;
   const card=document.querySelector('[data-qc-finding="72"]');
   const style=getComputedStyle(card);
   assert(style.color!==style.backgroundColor,'Unreadable '+theme+' card');
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
                super().do_GET()

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
