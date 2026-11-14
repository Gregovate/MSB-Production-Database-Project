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
window.qcFixture={viewer_person_id:1,signoffs:[],final_gates:[483,598].map(id=>({task_id:id,readiness_met:true,unfinished_work:[],unresolved_findings:0})),findings:[],auditors:[],unreconciled_intake:[{intake_id:85,stage_id:null,problem:"WRONG AREA LEGACY REPORT"}]};
window.qcWrites=[];
window.fetch=async (url,options={})=>{
 const path=String(url), action=options.body ? JSON.parse(options.body) : null;
 let body={};
 if(path.includes('api/health')) body={version:'V0.3.123-qc-recheck'};
 if(path.includes('qc/intake-candidates')) throw Error('Normal QC requested legacy Intake');
 if(path.includes('api/setup/qc/action')) {
  qcWrites.push(action);
  if(action.action==='REPORT_LINES') action.note.split(/\r?\n/).filter(line=>line.trim()).forEach((line,index)=>qcFixture.findings.push({qc_finding_id:71+index,
    setup_session_task_id:action.setup_session_task_id,title:line,status:'OPEN',
    stage_key:'25',stage_name:'Racing Arches',scene_name:'Test scene',events:[{type:'REPORTED',note:line}]}));
  else if(action.action==='EDIT_ISSUE') {
   const f=qcFixture.findings.find(f=>f.qc_finding_id===action.qc_finding_id);
   f.setup_session_task_id=action.target_task_id;f.current_description=action.note;
   qcFixture.signoffs=qcFixture.signoffs.filter(s=>s.setup_session_task_id!==action.target_task_id);
  }
  else if(action.action==='CLAIM_AUDIT') qcFixture.auditors.push({setup_session_task_id:action.setup_session_task_id,person_id:1,auditor:'Tester'});
  else if(action.action==='READY_FOR_PRODUCTION') qcFixture.signoffs.push({setup_session_task_id:action.setup_session_task_id,auditor_person_id:1,signed_at:new Date().toISOString(),test_evidence:action.note,sequence_reference:action.sequence_reference});
  else {
   const f=qcFixture.findings.find(f=>f.qc_finding_id===action.qc_finding_id);
   if(action.action==='RETEST_FAIL') f.claimed_by_person_id=null;
   if(action.action==='CLAIM_REPAIR') f.claimed_by_person_id=1;
   if(action.note) f.events.push({type:action.action,note:action.note,person:'Tester'});
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
   task_name:'QC Check - Verify Stage/Scene sequence lights during the 2 minute test sequence', completion_point:'No Conn must be reported',
   stage_id:25,stage_key:'25',stage_name:'Racing Arches',scene_name:'Test scene',
   execution_status:'NOT_READY',prerequisite_count:1,prerequisites_complete:false})),assignments:[]};
  // Execute discovery cases in the existing browser harness, never Node on the server.
  for (const [stage, name, expected] of [
    ['Show Animation EL 90 Elf On Shelf-1','Plug in Network & Test',true],
    ['Ordinary Stage','Plug in Network & Test',false],
    ['Show Animation EL 90 Elf On Shelf-1','Locate Power & Network',false],
    ['Show Animation EL 90 Elf On Shelf-1','PLUG IN & VERIFY: Wire Displays to Controller',false]
  ]) assert(nextIsFinalShowQc({stage_name:stage,task_name:name})===expected,'Show Animation discovery: '+stage+' / '+name);
  renderNextExecution();
  await click('#next-qc-check-tab');
  assert(setupTaskDisplayName(setupNextState.performBoard.tasks[0].task_name)==='QC Check - Verify Stage/Scene sequence lights during the 2 minute test sequence','QC task wording');
  assert(setupTaskDisplayName('Plug in Network Cables and test')==='Plug in Network Cables and test','Unrelated task renamed');
  assert(setupTaskCompletion(setupNextState.performBoard.tasks[0]).includes('No Conn'),'QC completion guidance');
  assert(setupNextState.performBoard.tasks[0].task_name.startsWith('QC Check'),'Saved task wording not rendered');
  assert(document.querySelector('.next-qc-toolbar #next-qc-report'),'Report outside toolbar');
  assert(document.querySelector('.next-qc-filterbar #next-qc-search'),'Search outside filterbar');
  for(const id of [483,598]) {
   await click('[data-qc-task-id="'+id+'"]');
   assert(document.querySelector('[data-qc-action="REPORT_LINES"]').getClientRects().length,'QC form missing '+id);
  }
  // Unclassified historical sources never appear under either selected area.
  assert(!document.querySelector('[data-qc-link-intake]'),'Legacy reconciliation still visible');
  // Collapse/reopen must retain draft text and expose explicit expanded state.
  document.querySelector('[data-qc-detail="598"] [data-qc-problems]').value='Draft preserved';
  await click('[data-qc-task-id="598"]');
  assert(document.querySelector('[data-qc-task-id="598"]').getAttribute('aria-expanded')==='false','QC cannot collapse');
  await click('[data-qc-task-id="598"]');
  assert(document.querySelector('[data-qc-detail="598"] [data-qc-problems]').value==='Draft preserved','Collapse erased draft');
  assert(!document.querySelector('#next-qc-content').textContent.includes('WRONG AREA LEGACY REPORT'),'Unclassified source shown as area finding');
  assert(!qcWrites.length,'Rendering wrote data');
  assert(!document.querySelector('[data-qc-action="READY_FOR_PRODUCTION"]'),'Unclaimed auditor has signoff control');
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
  assert(document.querySelector('[data-qc-repair-scope="unclaimed"]').getAttribute('aria-pressed')==='true','Unclaimed repairs must be first');
  await click('[data-qc-repair-scope="unclaimed"]');
  assert(document.querySelectorAll('[data-qc-repair-area]').length===1,'Repairs repeats area header');
  await click('[data-qc-repair-toggle="598"]');
  assert(document.querySelector('#qc-repair-area-598').hidden,'Repairs cannot collapse');
  await click('[data-qc-repair-toggle="598"]');
  const search=document.querySelector('[data-qc-fix-search]');
  search.value='598 arch 3';search.dispatchEvent(new Event('input',{bubbles:true}));
  assert(document.querySelector('[data-qc-fix-count]').textContent==='2 of 6 findings shown','Multiword task/problem search failed');
  search.value='';search.dispatchEvent(new Event('input',{bubbles:true}));
  assert(document.querySelector('#next-qc-fixes-list [data-qc-finding="71"]').getClientRects().length,'Shared finding missing');
  for (const theme of ['light','dark']) {
    document.documentElement.dataset.theme=theme;
    assert(getComputedStyle(document.querySelector('#next-qc-fixes-tab')).backgroundColor==='rgb(7, 89, 133)','Selected QC mode lacks blue fill in '+theme);
    assert(getComputedStyle(document.querySelector('#next-qc-fixes-list [data-qc-action="CLAIM_REPAIR"]')).backgroundColor==='rgb(146, 64, 14)','Repair claim lacks amber fill in '+theme);
  }
  assert(document.querySelector('#next-qc-report').href.includes('season_year=2026'),'Full-history report link missing season');
  await click('#next-qc-fixes-list [data-qc-id="71"][data-qc-action="CLAIM_REPAIR"]');
  assert(!qcWrites.at(-1).note,'Claim incorrectly requires work evidence');
  assert(!document.querySelector('#next-qc-fixes-list [data-qc-finding="71"]').getClientRects().length,'Claim stayed in Unclaimed');
  await click('[data-qc-repair-scope="mine"]');
  // Filters/search must not destroy a draft repair note.
  document.querySelector('[data-qc-fix-note="71"]').value='Draft to preserve';
  await click('[data-qc-repair-scope="all"]');
  await click('[data-qc-repair-scope="mine"]');
  assert(document.querySelector('[data-qc-fix-note="71"]').value==='Draft to preserve','Filter erased draft');
  document.querySelector('[data-qc-fix-note="71"]').value='';
  let count=qcWrites.length;
  await click('[data-qc-action="REPAIRED"]');
  assert(qcWrites.length===count,'Repair allowed without notes');
  assert(document.querySelector('#next-qc-fixes-list [data-qc-message]').textContent.includes('note'),'Repair error is not local');
  assert(parseFloat(getComputedStyle(document.querySelector('[data-qc-fix-note="71"]')).fontSize)>=18,'Repair text too small');
  document.querySelector('[data-qc-fix-note="71"]').value='Reconnected wire';
  await click('[data-qc-action="REPAIRED"]');
  await click('#next-qc-check-tab');
  assert(document.querySelector('[data-qc-task-id="598"]').dataset.qcState==='findings','Repair prematurely turned area green');
  assert(document.querySelector('[data-qc-task-id="598"]').textContent.includes('awaiting area sign-off'),'Verification status missing');
  await click('[data-qc-action="CLAIM_AUDIT"]');
  await click('[data-qc-area-scope="mine"]');
  assert(!document.querySelector('[data-qc-task-id="483"]').getClientRects().length,'Other area leaked into My QC Areas');
  const areaSearch=document.querySelector('#next-qc-search');
  areaSearch.value='#71 Reconnected';areaSearch.dispatchEvent(new Event('input',{bubbles:true}));
  assert(document.querySelector('[data-qc-task-id="598"]').getClientRects().length,'QC search omitted finding/history');
  areaSearch.value='no-match';areaSearch.dispatchEvent(new Event('input',{bubbles:true}));
  assert(document.querySelector('[data-qc-area-empty]').getClientRects().length,'Missing QC no-match feedback');
  areaSearch.value='';areaSearch.dispatchEvent(new Event('input',{bubbles:true}));
  await click('[data-qc-area-scope="all"]');
  document.querySelector('[data-qc-finding="71"] .next-qc-observation').open=true;
  count=qcWrites.length;
  await click('[data-qc-action="RETEST_FAIL"]');
  assert(qcWrites.length===count,'Retest allowed without evidence');
  document.querySelector('[data-qc-finding="71"] .next-qc-observation').open=true;
  document.querySelector('[data-qc-observation="71"]').value='Still dark in actual test';
  await click('[data-qc-action="RETEST_FAIL"]');
  await click('#next-qc-fixes-tab');
  await click('[data-qc-repair-scope="unclaimed"]');
  await click('#next-qc-fixes-list [data-qc-id="71"][data-qc-action="CLAIM_REPAIR"]');
  await click('[data-qc-repair-scope="mine"]');
  document.querySelector('[data-qc-fix-note="71"]').value='Replaced connector';
  await click('[data-qc-action="REPAIRED"]');
  await click('#next-qc-check-tab');
  assert(!document.querySelector('[data-qc-action="RETEST_PASS"]'),'Redundant per-finding Verified button remains');
  assert(document.querySelector('.next-qc-active [data-qc-finding="71"]'),'Repaired finding vanished before area observation');
  // Model all remaining findings verified, then a new failure in the same area.
  qcFixture.findings.forEach(f=>f.status='VERIFIED');
  await setupQcRenderCurrent();
  const area=document.querySelector('[data-qc-task-id="598"]');
  assert(area.dataset.qcState==='review','Finding verification bypassed final auditor signoff');
  assert(area.textContent.includes('Final QC pending'),'Finding verification implied annual PASS');
  assert(document.querySelector('[data-qc-detail="598"]').textContent.includes('Tester'),'Final signer identity hidden');
  assert(document.querySelector('[data-qc-detail="598"]').textContent.includes('Issue #71'),'Completed finding history hidden');
  for(const theme of ['light','dark']) {
    document.documentElement.dataset.theme=theme;
    assert(getComputedStyle(area).backgroundColor==='rgb(255, 255, 255)','Pending final signoff incorrectly shows green');
    assert(getComputedStyle(document.querySelector('[data-qc-task-id="483"]')).backgroundColor==='rgb(255, 255, 255)','Open area is not white');
  }
  // Simulate a second browser's new finding, then revisit the repairs screen.
  qcFixture.findings.push({qc_finding_id:80,setup_session_task_id:598,title:'Other worker report',status:'OPEN',events:[]});
  await setupQcRenderCurrent();
  assert(document.querySelector('[data-qc-task-id="598"]').dataset.qcState==='findings','New finding did not turn pending area yellow');
  // A new finding alongside a repaired/unverified finding also stays yellow.
  qcFixture.findings[0].status='AWAITING_RETEST';
  await setupQcRenderCurrent();
  assert(document.querySelector('[data-qc-task-id="598"]').textContent.includes('awaiting area sign-off'),'Mixed unverified/new findings lost retest warning');
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
  // Claimed auditor signs off only after work gates and every finding pass.
  qcFixture.findings.forEach(f=>f.status='AWAITING_RETEST');
  qcFixture.final_gates.find(g=>g.task_id===598).unfinished_work=[{id:77,name:'Install wiring'}];
  await setupQcRenderCurrent();
  assert(document.querySelector('[data-qc-action="READY_FOR_PRODUCTION"]').disabled,'Unfinished task did not block signoff');
  qcFixture.final_gates.find(g=>g.task_id===598).unfinished_work=[];
  await setupQcRenderCurrent();
  assert(!document.querySelector('[data-qc-action="READY_FOR_PRODUCTION"]').disabled,'Claimed ready auditor cannot sign off');
  const beforeFinal=qcWrites.length;
  await click('[data-qc-action="READY_FOR_PRODUCTION"]');
  assert(qcWrites.length===beforeFinal,'Missing test evidence allowed signoff');
  assert(!document.querySelector('[data-qc-final-sequence]'),'Unapproved sequence field remains');
  assert(!document.querySelector('[data-qc-final-evidence]'),'Redundant final-result field remains');
  assert(document.querySelector('.next-qc-signoff [data-qc-message]').textContent.includes('observed'),'Signoff validation is not local');
  document.querySelector('[data-qc-final-tested]').checked=true;
  await click('[data-qc-action="READY_FOR_PRODUCTION"]');
  const complete=document.querySelector('[data-qc-task-id="598"]');
  assert(complete.dataset.qcState==='verified','Final signed area did not turn green');
  assert(!complete.closest('[data-qc-completed-areas]'),'Signed area was removed from the main list');
  assert(complete.getClientRects().length,'Green area is hidden');
  assert(document.querySelector('[data-qc-detail="598"] [data-qc-action="REPORT_LINES"]'),'Green area cannot report a new problem');
  assert(!document.querySelector('[data-qc-detail="598"]').textContent.includes('through Work Orders'),'Premature Work Order handoff');
  for(const theme of ['light','dark']) {
    document.documentElement.dataset.theme=theme;
    assert(getComputedStyle(complete).backgroundColor==='rgb(220, 252, 231)','Final area not green in '+theme);
  }
  // Same display names must never cause another person's repair to become mine.
  qcFixture.findings.push({qc_finding_id:91,setup_session_task_id:483,title:'Other owner',status:'CLAIMED',claimed_by_person_id:2,repair_owner:'Tester',events:[]});
  qcFixture.findings.push({qc_finding_id:92,setup_session_task_id:483,title:'My repair',status:'AWAITING_RETEST',claimed_by_person_id:1,repair_owner:'Tester',events:[]});
  await click('#next-qc-fixes-tab');
  await click('[data-qc-repair-scope="mine"]');
  assert(!document.querySelector('#next-qc-fixes-list [data-qc-finding="91"]').getClientRects().length,'Same name confused repair ownership');
  assert(document.querySelector('#next-qc-fixes-list [data-qc-finding="92"]').getClientRects().length,'Awaiting signoff lost My Repairs ownership');
  const writesBeforeFilters=qcWrites.length;
  for(const theme of ['light','dark']) {
    document.documentElement.dataset.theme=theme;
    assert(getComputedStyle(document.querySelector('[data-qc-repair-scope="mine"]')).backgroundColor==='rgb(7, 89, 133)','Selected assignment filter unreadable');
  }
  await click('[data-qc-repair-scope="all"]');
  assert(qcWrites.length===writesBeforeFilters,'Filtering wrote data');
  qcFixture.findings.push({qc_finding_id:99,setup_session_task_id:483,title:'Wrong area text',current_description:'Correctable description',status:'OPEN',can_edit:true,updated_at:'2026-11-14T12:00:00Z',stage_name:'Racing Arches',events:[]});
  await setupQcRenderFixes();
  const edit=document.querySelector('#next-qc-fixes-list [data-qc-finding="99"] .next-qc-edit');
  assert(edit,'Repairs missing Edit Issue');edit.open=true;
  edit.querySelector('textarea').value='Clarified description';
  edit.querySelector('select').value='598';
  await click('#next-qc-fixes-list [data-qc-id="99"][data-qc-action="EDIT_ISSUE"]');
  assert(qcWrites.at(-1).target_task_id===598 && qcWrites.at(-1).note==='Clarified description','Edit payload incorrect');
  await click('#next-qc-check-tab');
  if(nextQcDiscovery.selectedTaskId!==598) await click('[data-qc-task-id="598"]');
  assert(document.querySelector('[data-qc-detail="598"] [data-qc-finding="99"] .next-qc-edit'),'QC Check missing same Edit Issue');
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
