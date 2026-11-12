/* #122/#205 QC record & shared repair queue. No scheduled assignments.
 * All changes saved through existing Setup command guard and DB-owned function.
 * Final annual QC approval is intentionally NOT supplied by this module.
 */
(() => {
  'use strict';
  let snapshot = { findings: [], auditors: [] };
  let loadedYear = null;
  let pending = null;
  let saving = false;
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
  function paintTaskStates() {
    // Exact annual identity owns the color; ordinary completion is not QC PASS.
    document.querySelectorAll('[data-qc-task-id]').forEach(button => {
      const findings=taskFindings(button.dataset.qcTaskId);
      const active=findings.filter(f=>f.status!=='VERIFIED');
      const retest=active.filter(f=>f.status==='AWAITING_RETEST').length;
      button.dataset.qcState=active.length ? 'findings' : findings.length ? 'verified' : 'open';
      const label=button.querySelector('[data-qc-task-status]');
      if (label) label.textContent=active.length
        ? `${active.length} open${retest ? ' · '+retest+' verification needed' : ' · Needs repair'}`
        : findings.length ? 'Findings verified · Final QC pending' : 'No findings · QC pending';
    });
  }
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
    AWAITING_RETEST:'Verification needed',VERIFIED:'Verified'
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
      setAlert('QC record saved.','ok');
      return payload;
    } catch (error) {
      setAlert(error.message || String(error),'error');
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
          ${status==='AWAITING_RETEST' ? '<span>Awaiting auditor retest in QC Check</span>' : ''}
        </div>`
      : `<div class="next-qc-actions">
          ${status==='AWAITING_RETEST'
            ? `<button type="button" class="small secondary" data-qc-action="RETEST_PASS" data-qc-id="${f.qc_finding_id}">Verified</button>
               <button type="button" class="small secondary" data-qc-action="RETEST_FAIL" data-qc-id="${f.qc_finding_id}">Still Failing</button>`
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
      : `${status==='AWAITING_RETEST' ? '' : '<details><summary>Add an observation</summary>'}<label>${status==='AWAITING_RETEST' ? 'Retest evidence / observation' : 'Add to this existing issue'}
         <textarea rows="3" maxlength="6000" data-qc-observation="${f.qc_finding_id}"
          placeholder="Additional details or corroborating observation"></textarea></label>
         <button type="button" class="small secondary" data-qc-action="OBSERVATION"
           data-qc-id="${f.qc_finding_id}">Add Observation</button>
         ${status==='AWAITING_RETEST' ? '' : '</details>'}
         ${controls}
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
      const action=btn.dataset.qcAction;
      const finding=Number(btn.dataset.qcId||0);
      const noteField=['OBSERVATION','REOPEN','RETEST_PASS','RETEST_FAIL'].includes(action)
        ? host.querySelector(`[data-qc-observation="${finding}"]`)
        : host.querySelector(`[data-qc-fix-note="${finding}"]`);
      let note=noteField?.value?.trim() || '';
      const targetId=Number(btn.dataset.qcTask || id ||
        snapshot.findings.find(x=>Number(x.qc_finding_id)===finding)?.setup_session_task_id);
      if (action==='CLAIM_AUDIT') {
        await command({action,setup_session_task_id:targetId});
        return;
      }
      if (action==='REPORT_LINES') {
        const problems=host.querySelector('[data-qc-problems]')?.value?.trim() || '';
        const lines=problems.split(/\r?\n/).map(line=>line.trim()).filter(Boolean);
        if (!lines.length || lines.some(line=>line.length<3) || problems.length>6000) {
          setAlert('Enter one problem per line (at least 3 characters each, 6000 characters total).','error');
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
      if (!note) { setAlert('Enter a repair, retest or observation note.','error'); return; }
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
    const allFindings=taskFindings(id);
    const findings=allFindings.filter(f=>f.status!=='VERIFIED');
    const verified=allFindings.filter(f=>f.status==='VERIFIED');
    const auditors=snapshot.auditors.filter(x=>Number(x.setup_session_task_id)===Number(id));
    host.innerHTML=`
      <div class="next-qc-record">
        <div><strong>QC auditors:</strong>
          ${auditors.length ? auditors.map(x=>html(x.auditor)).join(', ') : 'None yet'}
          <button type="button" class="small secondary" data-qc-action="CLAIM_AUDIT" data-qc-task="${id}">Assign to Me</button>
        </div>
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
            <textarea data-qc-problems rows="7" maxlength="6000"
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
    const active=snapshot.findings.filter(f=>f.status!=='VERIFIED');
    host.innerHTML=`<h3>QC Repairs Needed · ${active.length} outstanding findings</h3>
      <label>Find problem <input type="search" data-qc-fix-search
        placeholder="Search Stage, Scene, issue, Display or channel"></label>
      <p class="muted">Same findings reported under QC Check. Workers claim and repair here;
        auditors verify those same records in QC Check.</p>
      ${active.length ? active.map(f=>`<div class="next-qc-fix-group" data-qc-fix-group>
        <strong>${html(f.stage_key)} ${html(f.stage_name)}
          · ${html(f.scene_name || 'Stage-level')} · QC #${f.setup_session_task_id}</strong>
        ${findingMarkup(f,true)}</div>`).join('') :
        '<p>No outstanding QC findings in the new ledger.</p>'}`;
    bindControls(host,null);
    if (!host.dataset.qcFixSearchBound) {
      host.dataset.qcFixSearchBound='1';
      host.addEventListener('input', event=>{
        if (!event.target.matches('[data-qc-fix-search]')) return;
        const query=event.target.value.trim().toLowerCase();
        host.querySelectorAll('[data-qc-fix-group]').forEach(card=>{
          card.hidden=!card.textContent.toLowerCase().includes(query);
        });
      });
    }
  };
})();
