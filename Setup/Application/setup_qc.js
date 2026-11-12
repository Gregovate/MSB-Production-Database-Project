/* #122/#205 QC record & shared repair queue. No scheduled assignments.
 * All changes saved through existing Setup command guard and DB-owned function.
 * Final annual signoff uses the claimed-auditor database gate.
 */
(() => {
  'use strict';
  let snapshot = { findings: [], auditors: [] };
  let loadedYear = null;
  let pending = null;
  let saving = false;
  // Per-page preferences survive view changes and saves, not shared identities.
  let repairScope = 'mine';
  let repairSearch = '';
  let auditScope = 'all';
  const searchWords = value => String(value || '').toLowerCase().replace(/#/g,'').split(/\s+/).filter(Boolean);
  const matchesWords = (values, words) => {
    const text=values.join(' ').toLowerCase().replace(/#/g,'');
    return words.every(word=>text.includes(word));
  };
  const mine = f => snapshot.viewer_person_id != null && f.claimed_by_person_id != null &&
    Number(f.claimed_by_person_id)===Number(snapshot.viewer_person_id);
  const myArea = id => snapshot.viewer_person_id != null && (snapshot.auditors || []).some(a=>
    Number(a.setup_session_task_id)===Number(id) && Number(a.person_id)===Number(snapshot.viewer_person_id));
  const findingSearch = f => [f.qc_finding_id,f.setup_session_task_id,f.stage_key,f.stage_name,
    f.scene_name || 'Stage-level',f.title,f.task_name,f.location_detail,f.reporter,f.repair_owner,
    ...(f.events || []).flatMap(e=>[e.note,e.person])];
  window.setupQcMatchesTaskSearch = (task, query) => matchesWords([
    task.setup_session_task_id,task.setup_task_id,task.stage_key,task.stage_name,
    task.scene_name || 'Stage-level',task.task_name,task.annual_task_name,
    ...taskFindings(task.setup_session_task_id).flatMap(findingSearch),
    ...(snapshot.auditors || []).filter(a=>Number(a.setup_session_task_id)===Number(task.setup_session_task_id)).map(a=>a.auditor)
  ],searchWords(query));
  let actionButton = null;
  let actionHost = null;
  // Keep validation beside the operator's action, including errors from SQL.
  function qcMessage(message, kind='error') {
    const anchor=actionButton?.isConnected ? actionButton : null;
    const host=anchor?.parentElement || (actionHost?.isConnected ? actionHost : null);
    if (!host) { setAlert(message,kind); return; }
    let box=host.querySelector(':scope > [data-qc-message]');
    if (!box) { box=document.createElement('div');box.dataset.qcMessage='1';host.append(box); }
    box.setAttribute('role',kind==='error' ? 'alert' : 'status');
    box.tabIndex=-1;box.dataset.kind=kind;box.textContent=message;
    box.scrollIntoView({block:'nearest'});box.focus({preventScroll:true});
  }
  const html = value => escapeHtml(String(value ?? ''));
  const localTime = value => value
    ? new Date(value).toLocaleString('en-US', {
        timeZone: 'America/Chicago',year:'numeric',month:'numeric',day:'numeric',
        hour:'numeric',minute:'2-digit'
      })
    : 'Unknown';
  const taskFindings = id => snapshot.findings.filter(
    f => Number(f.setup_session_task_id) === Number(id)
  );
  const signoffFor = id => (snapshot.signoffs || []).find(q=>Number(q.setup_session_task_id)===Number(id));
  function paintTaskStates() {
    // Exact annual identity owns the color. All findings verified still awaits
    // auditor final signoff; green requires the persisted final signoff record.
    document.querySelectorAll('[data-qc-task-id]').forEach(button => {
      const findings=taskFindings(button.dataset.qcTaskId);
      const active=findings.filter(f=>f.status!=='VERIFIED');
      const retest=active.filter(f=>f.status==='AWAITING_RETEST').length;
      const signoff=signoffFor(button.dataset.qcTaskId);
      button.dataset.qcState=signoff ? 'verified' : active.length ? 'findings' : findings.length ? 'review' : 'open';
      const label=button.querySelector('[data-qc-task-status]');
      if (label) label.textContent=signoff ? 'Ready for Production · 100%' : active.length
        ? `${active.length-retest} need repair${retest ? ' · '+retest+' repaired — awaiting area sign-off' : ''}`
        : findings.length ? 'Findings verified · Final QC pending' : 'No findings · QC pending';
    });
    // Move finalized areas into collapsed green history; keep the same delegated
    // selection handler, and never discard their recorded evidence.
    const list=document.getElementById('next-qc-list');
    if (list) {
      let archive=list.querySelector('[data-qc-completed-areas]');
      if (!archive) {
        archive=document.createElement('details');archive.dataset.qcCompletedAreas='1';
        archive.innerHTML='<summary>Ready for Production</summary>';list.append(archive);
      }
      list.querySelectorAll('[data-qc-task-id]').forEach(button=>{
        const row=button.closest('.next-qc-row');
        if (signoffFor(button.dataset.qcTaskId)) archive.append(row);
        else if (row.parentElement===archive) list.insertBefore(row,archive);
      });
      const count=archive.querySelectorAll('.next-qc-row').length;
      archive.hidden=!count;
      const counter=document.getElementById('next-qc-count');
      if (counter) counter.textContent=(list.querySelectorAll('.next-qc-row').length-count)+' active areas · '+count+' Ready for Production';
      archive.querySelector('summary').textContent='Ready for Production ('+count+')';
      // Filter existing rows rather than rebuilding forms and losing draft notes.
      const matching=new Set(nextQcFilteredTasks().map(t=>Number(t.setup_session_task_id)));
      let shown=0, completed=0;
      list.querySelectorAll('.next-qc-row').forEach(row=>{
        const id=Number(row.querySelector('[data-qc-task-id]').dataset.qcTaskId);
        row.hidden=!matching.has(id) || (auditScope==='mine' && !myArea(id));
        if (!row.hidden) { if(signoffFor(id)) completed++; else shown++; }
      });
      archive.hidden=!completed;
      archive.querySelector('summary').textContent='Ready for Production ('+completed+')';
      if(counter) counter.textContent=shown+' active areas shown · '+completed+' Ready for Production';
      const filters=document.getElementById('next-qc-area-filters');
      if(filters) {
        const tasks=nextQcAnnualTasks();
        filters.innerHTML=[['all','All Areas',tasks.length],['mine','My QC Areas',tasks.filter(t=>myArea(t.setup_session_task_id)).length]]
          .map(([key,label,total])=>`<button type="button" data-qc-area-scope="${key}" aria-pressed="${auditScope===key}">${label} (${total})</button>`).join('');
        if(!filters.dataset.bound) {
          filters.dataset.bound='1';
          filters.addEventListener('click',event=>{
            const button=event.target.closest('[data-qc-area-scope]');
            if(button) { auditScope=button.dataset.qcAreaScope;paintTaskStates(); }
          });
        }
      }
      let empty=list.querySelector('[data-qc-area-empty]');
      if(!empty) {empty=document.createElement('p');empty.dataset.qcAreaEmpty='1';list.append(empty);}
      empty.textContent='No areas match this filter and search. Choose All Areas or clear the search.';
      empty.hidden=shown+completed>0;
    }
  }
  window.setupQcApplyFilters=paintTaskStates;
  window.setupQcRefreshTaskStates=async function() {
    try { await currentData(); }
    catch (error) {
      document.querySelectorAll('[data-qc-task-status]').forEach(label=>{
        label.textContent='Status unavailable';
        delete label.closest('[data-qc-task-id]').dataset.qcState;
      });
    }
  };
  const statusLabel = status => ({
    OPEN:'Needs repair',CLAIMED:'Repair claimed',
    AWAITING_RETEST:'Repaired — awaiting area sign-off',VERIFIED:'Verified'
  }[status] || status);
  const eventMarkup = f => (f.events || []).map(e =>
    `<li><strong>${html(e.person || 'Reporter')}</strong>
      <span class="muted">${html(localTime(e.at))} · ${html(e.type)}</span>
      <div class="next-qc-note">${html(e.note)}</div></li>`).join('');
  async function refresh() {
    const year=Number(appState.seasonYear);
    // Coalesce concurrent renders; revisit the server on each view entry so
    // another worker's findings and repairs do not stay hidden all season.
    if (pending) return pending;
    pending = (async () => {
      try {
        const payload=await api(`api/setup/qc?season_year=${encodeURIComponent(year)}`);
        snapshot=payload.qc || {findings:[],auditors:[]};
        loadedYear=year;
        if (year===Number(appState.seasonYear)) paintTaskStates();
      } finally { pending=null; }
    })();
    return pending;
  }
  async function currentData() {
    await refresh();
    if (loadedYear !== Number(appState.seasonYear)) await refresh();
  }
  async function command(data) {
    if (saving) return null;
    saving = true;
    try {
      setBusy(true);
      const payload=await api('api/setup/qc/action', commandOptions('POST',data));
      await window.setupQcRenderCurrent();
      await window.setupQcRenderFixes();
      qcMessage('QC record saved.','ok');
      return payload;
    } catch (error) {
      qcMessage(error.message || String(error),'error');
      return null;
    } finally {
      saving = false;
      setBusy(false);
    }
  }
  function findingMarkup(f, withFixes) {
    const status=f.status;
    // The repair queue never verifies its own repairs. Retest belongs to QC Check.
    const controls=withFixes
      ? `<div class="next-qc-actions">
          ${status==='OPEN'
            ? `<button type="button" class="small secondary" data-qc-action="CLAIM_REPAIR" data-qc-id="${f.qc_finding_id}">I'll Fix This</button>`
            : ''}
          ${status==='CLAIMED'
            ? `<button type="button" class="small secondary" data-qc-action="REPAIRED" data-qc-id="${f.qc_finding_id}">Mark Repaired</button>`
            : ''}
          ${status==='AWAITING_RETEST' ? '<span>Repaired — awaiting area sign-off</span>' : ''}
        </div>`
      : `<div class="next-qc-actions">
          ${status==='AWAITING_RETEST'
            ? `<button type="button" class="small secondary" data-qc-action="RETEST_FAIL" data-qc-id="${f.qc_finding_id}">Still Failing</button>`
            : ''}
        </div>`;
    return `<section class="next-qc-finding" data-qc-state="${status}" data-qc-finding="${f.qc_finding_id}">
      <strong>Issue #${f.qc_finding_id}: ${html((f.events || []).find(e=>e.type==='REPORTED')?.note || f.title)}</strong>
      <span class="next-qc-state">${html(statusLabel(status))}</span>
      <div class="muted">${f.location_detail ? html(f.location_detail)+' · ' : ''}Reported by ${html(f.reporter)} ·
        ${html(localTime(f.created_at))}</div>
      ${f.repair_owner ? `<div class="muted">Repair: ${html(f.repair_owner)}</div>` : ''}
      ${(f.linked_intake_ids || []).length ? `<div class="muted">Original Intake: ${f.linked_intake_ids.map(x=>'INTAKE-'+Number(x)).join(', ')}</div>` : ''}
      ${(f.linked_intake_records || []).map(i=>`<details class="next-qc-source">
        <summary>Original INTAKE-${Number(i.intake_id)} · ${html(i.submitter_name_raw)}</summary>
        <div class="muted">${html(localTime(i.updated_at))}</div>
        <div class="next-qc-note">${html(i.problem_raw)}</div>
        ${i.notes_raw ? `<div class="next-qc-note">${html(i.notes_raw)}</div>` : ''}
        ${i.photo_url_raw ? `<div class="next-qc-note">Photo reference: ${html(i.photo_url_raw)}</div>` : ''}
      </details>`).join('')}
      <details><summary>Observations and repair history (${(f.events || []).length})</summary>
        <ul class="next-qc-events">${eventMarkup(f)}</ul>
      </details>
      ${withFixes ? `${status==='CLAIMED' ? `<label>Repair notes
         <textarea rows="3" maxlength="6000" data-qc-fix-note="${f.qc_finding_id}"
          placeholder="Describe the work actually performed"></textarea></label>` : ''}${controls}`
      : `<details class="next-qc-observation"><summary>${status==='AWAITING_RETEST' ? 'Still failing / add observation' : 'Add an observation'}</summary><label>${status==='AWAITING_RETEST' ? 'Observation (required only if still failing)' : 'Add to this existing issue'}
         <textarea rows="3" maxlength="6000" data-qc-observation="${f.qc_finding_id}"
          placeholder="Additional details or corroborating observation"></textarea></label>
         <button type="button" class="small secondary" data-qc-action="OBSERVATION"
           data-qc-id="${f.qc_finding_id}">Add Observation</button>
         ${controls}</details>
         ${status==='VERIFIED'
           ? `<button type="button" class="small secondary"
             data-qc-action="REOPEN" data-qc-id="${f.qc_finding_id}">
             Reopen — Still Broken</button>` : ''}`}
    </section>`;
  }
  function bindControls(host, id) {
    if (!host || host.dataset.qcBound) return;
    host.dataset.qcBound='1';
    host.addEventListener('click', async event => {
      const btn=event.target.closest('[data-qc-action]');
      if (!btn || !host.contains(btn)) return;
      actionButton=btn;actionHost=host;
      const action=btn.dataset.qcAction;
      const finding=Number(btn.dataset.qcId||0);
      const noteField=['OBSERVATION','REOPEN','RETEST_PASS','RETEST_FAIL'].includes(action)
        ? host.querySelector(`[data-qc-observation="${finding}"]`)
        : host.querySelector(`[data-qc-fix-note="${finding}"]`);
      let note=noteField?.value?.trim() || '';
      const targetId=Number(btn.dataset.qcTask || id ||
        snapshot.findings.find(x=>Number(x.qc_finding_id)===finding)?.setup_session_task_id);
      if (action==='READY_FOR_PRODUCTION') {
        if (!host.querySelector('[data-qc-final-tested]')?.checked) {
          qcMessage('Confirm that you observed the full two-minute test and this area works.');return;
        }
        await command({action,setup_session_task_id:targetId,observed_test:true});
        return;
      }
      if (action==='CLAIM_AUDIT') {
        await command({action,setup_session_task_id:targetId});
        return;
      }
      if (action==='REPORT_LINES') {
        const problems=host.querySelector('[data-qc-problems]')?.value?.trim() || '';
        const lines=problems.split(/\r?\n/).map(line=>line.trim()).filter(Boolean);
        if (!lines.length || lines.some(line=>line.length<3) || problems.length>6000) {
          qcMessage('Enter one problem per line (at least 3 characters each, 6000 characters total).','error');
          return;
        }
        await command({action,setup_session_task_id:targetId,note:problems});
        return;
      }
      // Claim is intent only. The database records the claim event; no work
      // evidence or invented repair note is required from the operator.
      if (action==='CLAIM_REPAIR') {
        await command({action,setup_session_task_id:targetId,qc_finding_id:finding});
        return;
      }
      if (action==='RETEST_FAIL' && !snapshot.auditors.some(a=>
          Number(a.setup_session_task_id)===targetId && Number(a.person_id)===Number(snapshot.viewer_person_id))) {
        qcMessage('Select Assign to Me for this area before recording the auditor test result.');return;
      }
      if (!note) { qcMessage('Enter a repair, retest or observation note.','error'); return; }
      await command({action,setup_session_task_id:targetId,qc_finding_id:finding,note});
    });
  }
  window.setupQcRenderCurrent=async function() {
    const id=nextQcDiscovery.selectedTaskId;
    if (!id || nextQcDiscovery.mode!=='qc') return;
    const host=document.querySelector(`[data-qc-detail="${Number(id)}"]`);
    if (!host) return;
    host.textContent='Loading QC findings and report controls…';
    try { await currentData(); }
    catch (error) { host.textContent='QC details unavailable: '+(error.message||error);return; }
    if (!host.isConnected || id!==nextQcDiscovery.selectedTaskId) return;
    const final=signoffFor(id);
    if (final) {
      host.innerHTML=`<section class="next-qc-final-record"><h4>Ready for Production · 100%</h4>
        <p>Signed by ${html((snapshot.auditors || []).find(a=>Number(a.person_id)===Number(final.auditor_person_id) && Number(a.setup_session_task_id)===Number(id))?.auditor || 'Auditor #'+final.auditor_person_id)} · ${html(localTime(final.signed_at))}</p>
        <p>${html(final.sequence_reference)}</p><p class="next-qc-note">${html(final.test_evidence)}</p>
        <p>Report subsequent problems through Work Orders.</p>
        <h4>Findings and repair history (${taskFindings(id).length})</h4>
        ${taskFindings(id).map(f=>`<section class="next-qc-finding" data-qc-state="VERIFIED">
          <strong>Issue #${html(f.qc_finding_id)}: ${html((f.events || []).find(e=>e.type==='REPORTED')?.note || f.title)}</strong>
          <p>Reported by ${html(f.reporter)} · Repair: ${html(f.repair_owner || 'Unclaimed')}</p>
          <ul>${eventMarkup(f)}</ul></section>`).join('')}
        </section>`;
      return;
    }
    const allFindings=taskFindings(id);
    const findings=allFindings.filter(f=>f.status!=='VERIFIED');
    const verified=allFindings.filter(f=>f.status==='VERIFIED');
    const auditors=snapshot.auditors.filter(x=>Number(x.setup_session_task_id)===Number(id));
    const ownsAudit=auditors.some(a=>Number(a.person_id)===Number(snapshot.viewer_person_id));
    const gate=(snapshot.final_gates || []).find(g=>Number(g.task_id)===Number(id));
    const unfinished=gate?.unfinished_work || [];
    const unrepaired=findings.filter(f=>f.status==='OPEN' || f.status==='CLAIMED');
    const canSign=ownsAudit && gate?.readiness_met && !unfinished.length && !unrepaired.length;
    host.innerHTML=`
      <div class="next-qc-record">
        <div><strong>QC auditors:</strong>
          ${auditors.length ? auditors.map(x=>html(x.auditor)).join(', ') : 'None yet'}
          ${ownsAudit ? '<span> · Assigned to you</span>' : `<button type="button" class="small secondary" data-qc-action="CLAIM_AUDIT" data-qc-task="${id}">Assign to Me</button>`}
        </div>
        ${ownsAudit ? `<section class="next-qc-signoff">
          <h4>Final QC — Ready for Production</h4>
          ${!gate ? '<p>Readiness checks unavailable.</p>' : ''}
          ${gate && !gate.readiness_met ? '<p>Blocked: annual readiness has not been confirmed.</p>' : ''}
          ${unfinished.length ? `<p>Sign-off blocked — complete this required work first:</p><ul>${unfinished.map(w=>`<li>#${html(w.id)} ${html(w.name)}</li>`).join('')}</ul>` : ''}
          ${unrepaired.length ? `<p>${unrepaired.length} problem(s) still need repair.</p>` : ''}
          <label class="next-qc-confirm"><input type="checkbox" data-qc-final-tested>
            I observed the full two-minute test and confirmed this area works.</label>
          <button type="button" data-qc-action="READY_FOR_PRODUCTION" data-qc-task="${id}" ${canSign ? '' : 'disabled'}>Ready for Production — Sign Off</button>
        </section>` : ''}
        <h4>Open findings (${findings.length})</h4>
        <div class="next-qc-active">
        ${findings.length ? findings.map(f=>findingMarkup(f,false)).join('')
          : '<p>No open findings.</p>'}
        </div>
        ${verified.length ? `<details class="next-qc-verified-history"><summary>Verified history (${verified.length})</summary>
          ${verified.map(f=>findingMarkup(f,false)).join('')}</details>` : ''}
        <form class="next-qc-new" onsubmit="return false">
          <h4>Report problems</h4>
          <label>What is wrong? One problem per line.
            <textarea data-qc-problems rows="3" maxlength="6000"
              placeholder="arch 3 - blue lights 21 to 28 inches from bottom&#10;arch 4 - all red lights"></textarea>
          </label>
          <button type="button" data-qc-action="REPORT_LINES" data-qc-task="${id}">Save Problems</button>
        </form>
      </div>`;
    bindControls(host,id);
  };
  window.setupQcRenderFixes=async function() {
    const host=document.getElementById('next-qc-fixes-list');
    if (!host || nextQcDiscovery.mode!=='fixes') return;
    try { await currentData(); }
    catch (error) { host.textContent='QC repair list unavailable: '+(error.message||error);return; }
    if (!host.isConnected || nextQcDiscovery.mode!=='fixes') return;
    const active=snapshot.findings.filter(f=>f.status!=='VERIFIED' && !signoffFor(f.setup_session_task_id));
    const totals={mine:active.filter(mine).length,unclaimed:active.filter(f=>f.claimed_by_person_id==null).length,all:active.length};
    host.innerHTML=`<h3>QC Repairs Needed · ${active.length} outstanding findings</h3>
      <div class="next-qc-tabs" role="group" aria-label="Repair assignments">
        ${[['mine','My Repairs'],['unclaimed','Unclaimed'],['all','All Repairs']].map(([key,label])=>
          `<button type="button" data-qc-repair-scope="${key}" aria-pressed="${repairScope===key}">${label} (${totals[key]})</button>`).join('')}
      </div>
      <label>Find problem <input type="search" data-qc-fix-search value="${html(repairSearch)}"
        placeholder="Search Stage, Scene, QC task, finding, person or notes"></label>
      <p data-qc-fix-count role="status"></p>
      <p class="muted">Claim a problem here, then return to record the repair. The area auditor signs off in QC Check.</p>
      ${active.map(f=>`<div class="next-qc-fix-group" data-qc-fix-group="${f.qc_finding_id}">
        <strong>${html(f.stage_name || f.stage_key)} · ${html(f.scene_name || 'Stage-level')} · QC #${f.setup_session_task_id}</strong>
        ${findingMarkup(f,true)}</div>`).join('')}
      <p data-qc-fix-empty hidden>No repairs match this filter and search. Choose Unclaimed or All Repairs, or clear the search.</p>`;
    const apply=()=>{
      let shown=0;
      const words=searchWords(repairSearch);
      host.querySelectorAll('[data-qc-fix-group]').forEach(card=>{
        const f=active.find(f=>Number(f.qc_finding_id)===Number(card.dataset.qcFixGroup));
        const inScope=repairScope==='all' || (repairScope==='mine' ? mine(f) : f.claimed_by_person_id==null);
        card.hidden=!inScope || !matchesWords(findingSearch(f),words);
        if(!card.hidden) shown++;
      });
      host.querySelector('[data-qc-fix-count]').textContent=shown+' of '+totals[repairScope]+' findings shown';
      host.querySelector('[data-qc-fix-empty]').hidden=shown>0;
      host.querySelectorAll('[data-qc-repair-scope]').forEach(b=>b.setAttribute('aria-pressed',String(b.dataset.qcRepairScope===repairScope)));
    };
    // Replace filter callbacks on render so they cannot retain a stale snapshot.
    host.oninput=event=>{
      if(event.target.matches('[data-qc-fix-search]')) {repairSearch=event.target.value;apply();}
    };
    host.onclick=event=>{
      const button=event.target.closest('[data-qc-repair-scope]');
      if(button) {repairScope=button.dataset.qcRepairScope;apply();}
    };
    bindControls(host,null);
    apply();
  };
})();
