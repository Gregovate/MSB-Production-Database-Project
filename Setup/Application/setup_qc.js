/* #122/#205 QC record & shared repair queue. No scheduled assignments.
 * All changes saved through existing Setup command guard and DB-owned function.
 * Final annual QC approval is intentionally NOT supplied by this module.
 */
(() => {
  'use strict';
  let snapshot = { findings: [], auditors: [] };
  let loadedYear = null;
  let pending = null;
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
  const statusLabel = status => ({
    OPEN:'Needs repair',CLAIMED:'Repair claimed',
    AWAITING_RETEST:'Repair complete — needs retest',VERIFIED:'Verified'
  }[status] || status);
  const eventMarkup = f => (f.events || []).map(e =>
    `<li><strong>${html(e.person || 'Reporter')}</strong>
      <span class="muted">${html(localTime(e.at))} · ${html(e.type)}</span>
      <div class="next-qc-note">${html(e.note)}</div></li>`).join('');
  async function refresh() {
    const year=Number(appState.seasonYear);
    if (pending) await pending;
    pending = api(`api/setup/qc?season_year=${encodeURIComponent(year)}`);
    try {
      const payload=await pending;
      snapshot=payload.qc || {findings:[],auditors:[]};
      loadedYear=year;
    } finally {
      pending=null;
    }
  }
  async function currentData() {
    if (loadedYear !== Number(appState.seasonYear)) await refresh();
  }
  async function command(data) {
    try {
      setBusy(true);
      const payload=await api('api/setup/qc/action', commandOptions('POST',data));
      await refresh();
      window.setupQcRenderCurrent();
      window.setupQcRenderFixes();
      setAlert('QC record saved.','ok');
      return payload;
    } catch (error) {
      setAlert(error.message || String(error),'error');
      return null;
    } finally {
      setBusy(false);
    }
  }
  function findingMarkup(f, withFixes) {
    const status=f.status;
    const controls=withFixes
      ? `<div class="next-qc-actions">
          ${status==='OPEN' || status==='CLAIMED'
            ? `<button type="button" class="small secondary" data-qc-action="CLAIM_REPAIR" data-qc-id="${f.qc_finding_id}">I'll Fix This</button>
               <button type="button" class="small secondary" data-qc-action="REPAIRED" data-qc-id="${f.qc_finding_id}">Repair Complete</button>`
            : ''}
          ${status==='AWAITING_RETEST'
            ? `<button type="button" class="small secondary" data-qc-action="RETEST_PASS" data-qc-id="${f.qc_finding_id}">Retest Passed</button>
               <button type="button" class="small secondary" data-qc-action="RETEST_FAIL" data-qc-id="${f.qc_finding_id}">Still Failing</button>`
            : ''}
        </div>`
      : '';
    return `<section class="next-qc-finding" data-qc-finding="${f.qc_finding_id}">
      <strong>Issue #${f.qc_finding_id}: ${html(f.title)}</strong>
      <span class="next-qc-state">${html(statusLabel(status))}</span>
      <div class="muted">${html(f.location_detail || 'Location unspecified')} ·
        ${html(f.discovery_phase)} · Reported by ${html(f.reporter)} ·
        ${html(localTime(f.created_at))}</div>
      ${f.repair_owner ? `<div class="muted">Repair: ${html(f.repair_owner)}</div>` : ''}
      ${(f.linked_intake_ids || []).length ? `<div class="muted">Original Intake: ${f.linked_intake_ids.map(x=>'INTAKE-'+Number(x)).join(', ')}</div>` : ''}
      <details><summary>Observations and repair history (${(f.events || []).length})</summary>
        <ul class="next-qc-events">${eventMarkup(f)}</ul>
      </details>
      ${withFixes ? `<label>Repair or retest notes
         <textarea rows="3" maxlength="6000" data-qc-fix-note="${f.qc_finding_id}"
          placeholder="What was repaired? What did the retest show?"></textarea></label>${controls}`
      : `<label>Add to this existing issue
         <textarea rows="3" maxlength="6000" data-qc-observation="${f.qc_finding_id}"
          placeholder="Additional details or corroborating observation"></textarea></label>
         <button type="button" class="small secondary" data-qc-action="OBSERVATION"
           data-qc-id="${f.qc_finding_id}">Add Observation</button>
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
      const noteField=['OBSERVATION','REOPEN'].includes(action)
        ? host.querySelector(`[data-qc-observation="${finding}"]`)
        : host.querySelector(`[data-qc-fix-note="${finding}"]`);
      let note=noteField?.value?.trim() || '';
      const targetId=Number(btn.dataset.qcTask || id ||
        snapshot.findings.find(x=>Number(x.qc_finding_id)===finding)?.setup_session_task_id);
      if (action==='CLAIM_AUDIT') {
        await command({action,setup_session_task_id:targetId});
        return;
      }
      if (action==='REPORT') {
        const problem=host.querySelector('[data-qc-problem]')?.value?.trim() || '';
        const evidence=host.querySelector('[data-qc-evidence]')?.value?.trim() || '';
        const phase=host.querySelector('[data-qc-phase]')?.value;
        const location=host.querySelector('[data-qc-location]')?.value?.trim() || '';
        if (!problem) { setAlert('Enter what you found before saving.','error');return; }
        // Familiar Task Feedback form, but QC task-scoped storage only.
        // No Work Order Intake submission, Manager triage or calendar mutation.
        const title=problem.slice(0,200);
        const detail=evidence ? problem+'\n\nSuggested correction / evidence:\n'+evidence : problem;
        await command({action,setup_session_task_id:targetId,title,
          note:detail,discovery_phase:phase,location_detail:location});
        return;
      }
      if (action==='CLAIM_REPAIR' && !note) note='Claimed repair';
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
    const findings=taskFindings(id);
    const selectedQcTask=nextQcAnnualTasks().find(
      t=>Number(t.setup_session_task_id)===Number(id));
    const auditors=(snapshot.auditors || []).filter(
      x=>Number(x.setup_session_task_id)===Number(id));
    host.innerHTML=`
      <div class="next-qc-record">
        <div><strong>QC auditors:</strong>
          ${auditors.length ? auditors.map(x=>html(x.auditor)).join(', ') : 'None yet'}
          <button type="button" class="small secondary" data-qc-action="CLAIM_AUDIT" data-qc-task="${id}">Assign to Me</button>
        </div>
        <h4>Previously reported problems (${findings.length})</h4>
        ${findings.length ? findings.map(f=>findingMarkup(f,false)).join('')
          : '<p>No QC findings saved yet for this task.</p>'}
        <form class="next-qc-new next-problem-form" onsubmit="return false">
          <h4>Report a problem on QC #${id}</h4>
          <p class="muted">This uses the familiar Task Feedback form. The report is saved
            directly to QC #${id}, not Work Order Intake. No schedule is required.</p>
          <label>What did you find?
            <textarea class="next-problem-text" data-qc-problem rows="4"
              maxlength="200" required placeholder="Describe the failure or observation"></textarea>
          </label>
          <label>Suggested correction / evidence <span class="muted">(optional)</span>
            <textarea class="next-suggestion-text" data-qc-evidence rows="5"
              maxlength="2000" placeholder="Details, affected section, symptoms or suggested fix"></textarea>
          </label>
          <label>Exact location / channel <span class="muted">(optional)</span>
            <input data-qc-location maxlength="500" placeholder="Display, arch, channel or section">
          </label>
          <label>When found
            <select data-qc-phase>
              <option value="INITIAL_POWER">Initial Power-Up</option>
              <option value="INSTALLATION">Installation</option>
              <option value="FINAL_TEST">Final Test</option>
              <option value="OTHER">Other</option>
            </select>
          </label>
          <button type="button" data-qc-action="REPORT" data-qc-task="${id}">Save QC Problem</button>
                </form>
      </div>`;
    bindControls(host,id);
  };
  window.setupQcRenderFixes=async function() {
    const host=document.getElementById('next-qc-fixes-list');
    if (!host || nextQcDiscovery.mode!=='fixes') return;
    try { await currentData(); }
    catch (error) { host.textContent='QC repair list unavailable: '+(error.message||error);return; }
    const active=snapshot.findings.filter(f=>f.status!=='VERIFIED');
    host.innerHTML=`<h3>Report Fixes · ${active.length} outstanding issues</h3>
      <label>Find problem <input type="search" data-qc-fix-search
        placeholder="Search Stage, Scene, issue, Display or channel"></label>
      <p class="muted">Same records reported under QC Check. Repair Complete requires a functional retest.</p>
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
