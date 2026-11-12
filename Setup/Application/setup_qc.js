/* #122/#205 QC record & shared repair queue. No scheduled assignments.
 * All changes saved through existing Setup command guard and DB-owned function.
 * Final annual QC approval is intentionally NOT supplied by this module.
 */
(() => {
  'use strict';
  let snapshot = { findings: [], auditors: [] };
  let loadedYear = null;
  let pending = null;
  let intakeCandidates = [];
  let intakeLoadedYear = null;
  async function reviewIntake() {
    if (!appState.access?.can_manage_setup) return [];
    if (intakeLoadedYear !== Number(appState.seasonYear)) {
      const payload=await api(
        `api/setup/qc/intake-candidates?season_year=${encodeURIComponent(appState.seasonYear)}`);
      intakeCandidates=payload.intake_candidates || [];
      intakeLoadedYear=Number(appState.seasonYear);
    }
    return intakeCandidates;
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
    // Coalesce concurrent renders; revisit the server on each view entry so
    // another worker's findings and repairs do not stay hidden all season.
    if (pending) return pending;
    pending = (async () => {
      try {
        const payload=await api(`api/setup/qc?season_year=${encodeURIComponent(year)}`);
        snapshot=payload.qc || {findings:[],auditors:[]};
        loadedYear=year;
      } finally { pending=null; }
    })();
    return pending;
  }
  async function currentData() {
    await refresh();
    if (loadedYear !== Number(appState.seasonYear)) await refresh();
  }
  async function command(data) {
    try {
      setBusy(true);
      const payload=await api('api/setup/qc/action', commandOptions('POST',data));
      // A successful link invalidates the Manager's source-link inventory.
      if (data.action==='LINK_INTAKE') intakeLoadedYear=null;
      await window.setupQcRenderCurrent();
      await window.setupQcRenderFixes();
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
    return `<section class="next-qc-finding" data-qc-finding="${f.qc_finding_id}">
      <strong>Issue #${f.qc_finding_id}: ${html(f.title)}</strong>
      <span class="next-qc-state">${html(statusLabel(status))}</span>
      <div class="muted">${html(f.location_detail || 'Location unspecified')} ·
        ${html(f.discovery_phase)} · Reported by ${html(f.reporter)} ·
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
      ${withFixes ? `<label>Repair notes
         <textarea rows="3" maxlength="6000" data-qc-fix-note="${f.qc_finding_id}"
          placeholder="Describe the work actually performed"></textarea></label>${controls}`
      : `<label>${status==='AWAITING_RETEST' ? 'Retest evidence / observation' : 'Add to this existing issue'}
         <textarea rows="3" maxlength="6000" data-qc-observation="${f.qc_finding_id}"
          placeholder="Additional details or corroborating observation"></textarea></label>
         <button type="button" class="small secondary" data-qc-action="OBSERVATION"
           data-qc-id="${f.qc_finding_id}">Add Observation</button>
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
      if (action==='LINK_INTAKE') {
        const intakeId=Number(host.querySelector('[data-qc-link-intake]')?.value||0);
        const findingId=Number(host.querySelector('[data-qc-link-finding]')?.value||0);
        const rationale=host.querySelector('[data-qc-link-rationale]')?.value?.trim();
        if (!intakeId || !findingId || !rationale) {
          setAlert('Choose the original Intake, existing finding, and link rationale.','error');
          return;
        }
        await command({action, setup_session_task_id:targetId,
          qc_finding_id:findingId,intake_id:intakeId,note:rationale});
        return;
      }
      if (action==='CLAIM_AUDIT') {
        await command({action,setup_session_task_id:targetId});
        return;
      }
      if (action==='REPORT') {
        const title=host.querySelector('[data-qc-title]')?.value?.trim();
        note=host.querySelector('[data-qc-description]')?.value?.trim();
        const evidence=host.querySelector('[data-qc-evidence]')?.value?.trim();
        if (evidence) note += '\n\nSuggested correction / evidence:\n'+evidence;
        const phase=host.querySelector('[data-qc-phase]')?.value;
        const location=host.querySelector('[data-qc-location]')?.value?.trim();
        if (!title || !host.querySelector('[data-qc-description]')?.value?.trim()) { setAlert('Describe the problem before saving.','error');return; }
        if (note.length>6000) { setAlert('Findings and evidence together must be 6000 characters or fewer.','error');return; }
        await command({action,setup_session_task_id:targetId,title,
          note,discovery_phase:phase,location_detail:location});
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
    const findings=taskFindings(id);
    const selectedQcTask=nextQcAnnualTasks().find(
      t=>Number(t.setup_session_task_id)===Number(id));
    const unlinkedIntake=(snapshot.unreconciled_intake || []).filter(
      i=>i.stage_id != null && Number(i.stage_id)===Number(selectedQcTask?.stage_id));
    // Manager Intake reconciliation must not hold up the QC problem entry form.
    // Historical Intake remains read-only source evidence until a Manager links it.
    let relevantIntake=[];
    const selected=nextQcAnnualTasks().find(
      t=>Number(t.setup_session_task_id)===Number(id));
    const auditors=snapshot.auditors.filter(x=>Number(x.setup_session_task_id)===Number(id));
    host.innerHTML=`
      <div class="next-qc-record">
        <div><strong>QC auditors:</strong>
          ${auditors.length ? auditors.map(x=>html(x.auditor)).join(', ') : 'None yet'}
          <button type="button" class="small secondary" data-qc-action="CLAIM_AUDIT" data-qc-task="${id}">Assign to Me</button>
        </div>
        <h4>Previously reported problems (${findings.length})</h4>
        ${findings.length ? findings.map(f=>findingMarkup(f,false)).join('')
          : '<p>No QC findings saved yet for this task.</p>'}
        ${unlinkedIntake.length ? `<section class="next-qc-finding">
          <h4>Earlier Intake reports needing review (${unlinkedIntake.length})</h4>
          <p class="muted">These original reports are visible to avoid duplicate problems.
            A Manager must reconcile them to exact QC findings before they appear in Report Fixes.</p>
          ${unlinkedIntake.map(i=>`<details><summary>INTAKE-${Number(i.intake_id)}
              · ${html((i.problem||'').slice(0,140))}</summary>
              <div class="muted">${html(i.submitter_name)} ·
                ${html(localTime(i.updated_at))}</div>
              <div class="next-qc-note">${html(i.problem)}</div>
              <div class="next-qc-note">${html(i.notes||'')}</div></details>`).join('')}
        </section>` : ''}
        ${appState.access?.can_manage_setup ? `<section class="next-qc-finding">
          <h4>Manager: attach historical reports to existing QC findings</h4>
          <p class="muted">Original Intake remains unchanged. Confirm the exact defect and link
            it to one or more QC findings; do not link the separate promoted GFCI Work Order.
            Create distinct QC findings first for separate physical defects.</p>
          <label>Unpromoted Intake from this Stage
            <select data-qc-link-intake>
              <option value="">Choose original Intake</option>
              ${relevantIntake.map(i=>`<option value="${Number(i.intake_id)}">
                INTAKE-${Number(i.intake_id)} · ${html((i.problem_raw||'').slice(0,150))}
              </option>`).join('')}
            </select>
          </label>
          <details data-qc-intake-review><summary>Review original Intake descriptions (loading…)</summary><div data-qc-intake-rows>
            ${relevantIntake.map(i=>`<div class="next-qc-finding">
               <strong>INTAKE-${Number(i.intake_id)}</strong> · ${html(i.submitter_name_raw)}
               <div class="muted">${html(localTime(i.updated_at))} ·
                 linked findings ${html((i.linked_findings||[]).join(', ')||'none')}</div>
               <div class="next-qc-note">${html(i.problem_raw)}</div>
               ${i.notes_raw ? `<div class="next-qc-note"><strong>Original notes:</strong> ${html(i.notes_raw)}</div>` : ""}
               ${i.photo_url_raw ? `<div class="muted">Photo reference: ${html(i.photo_url_raw)}</div>` : ""}
              </div>`).join('')}</div>
          </details>
          <label>Existing QC problem
            <select data-qc-link-finding>
              <option value="">Choose finding to corroborate</option>
              ${findings.map(f=>`<option value="${Number(f.qc_finding_id)}">
                 #${Number(f.qc_finding_id)} · ${html(f.title)}
              </option>`).join('')}
            </select>
          </label>
          <label>Why these are the same issue?
            <textarea rows="3" maxlength="2000" data-qc-link-rationale
              placeholder="Confirm arch / channel / failure and overlapping evidence"></textarea>
          </label>
          <button type="button" class="small secondary" data-qc-action="LINK_INTAKE"
            data-qc-task="${id}">Link original Intake to QC finding</button>
        </section>` : ''}
        <form class="next-qc-new" onsubmit="return false">
          <h4>Report a problem on QC #${id}</h4>
          <p class="muted">Available throughout Setup, even when unscheduled or NOT_READY.
            Reports are saved directly on this QC task, not to Work Order Intake.</p>
          <label>Problem / affected Display <input data-qc-title required maxlength="200" placeholder="e.g., Arch 3 — red string out"></label>
          <label>Exact location / channel <input data-qc-location maxlength="500" placeholder="Arch, section, controller/channel if known"></label>
          <label>When found <select data-qc-phase>
            <option value="INITIAL_POWER">Initial Power-Up</option>
            <option value="INSTALLATION">Installation</option>
            <option value="FINAL_TEST">Final Test</option>
            <option value="OTHER">Other</option>
          </select></label>
          <label>What did you find? <textarea data-qc-description rows="7" maxlength="6000"
            placeholder="What worked, what did not, and how to reproduce it"></textarea></label>
          <label>Suggested correction / evidence <span class="muted">(optional)</span>
            <textarea data-qc-evidence rows="3" maxlength="2000"></textarea></label>
          <button type="button" data-qc-action="REPORT" data-qc-task="${id}">Save QC Problem</button>
        </form>
      </div>`;
    bindControls(host,id);
    if (appState.access?.can_manage_setup) {
      // Update only the Intake review section after asynchronous loading.
      // Never replace the entire QC form and erase an operator's unsaved notes.
      void reviewIntake().then(all => {
        if (!host.isConnected || id!==nextQcDiscovery.selectedTaskId ||
            nextQcDiscovery.mode!=='qc') return;
        relevantIntake=all.filter(i=>Number(i.stage_id)===Number(selected?.stage_id));
        const selector=host.querySelector('[data-qc-link-intake]');
        if (selector) {
          const previous=selector.value;
          selector.innerHTML='<option value="">Choose original Intake</option>'+
            relevantIntake.map(i=>`<option value="${Number(i.intake_id)}">
              INTAKE-${Number(i.intake_id)} · ${html((i.problem_raw||'').slice(0,150))}
            </option>`).join('');
          if (Array.from(selector.options).some(opt=>opt.value===previous)) selector.value=previous;
        }
        const panel=host.querySelector('[data-qc-intake-review]');
        if (panel) {
          const summary=panel.querySelector('summary');
          if (summary) summary.textContent='Review original Intake descriptions ('+relevantIntake.length+')';
          const rows=panel.querySelector('[data-qc-intake-rows]');
          if (rows) rows.innerHTML=relevantIntake.map(i=>`<div class="next-qc-finding">
            <strong>INTAKE-${Number(i.intake_id)}</strong> · ${html(i.submitter_name_raw)}
            <div class="muted">${html(localTime(i.updated_at))} ·
              linked findings ${html((i.linked_findings||[]).join(', ')||'none')}</div>
            <div class="next-qc-note">${html(i.problem_raw)}</div>
            ${i.notes_raw ? `<div class="next-qc-note"><strong>Original notes:</strong> ${html(i.notes_raw)}</div>` : ''}
            ${i.photo_url_raw ? `<div class="muted">Photo reference: ${html(i.photo_url_raw)}</div>` : ''}
          </div>`).join('');
        }
      }).catch(error=>{
        const panel=host.querySelector('[data-qc-intake-review]');
        if (panel) panel.querySelector('summary').textContent=
          'Historical Intake review unavailable — QC reporting remains available';
        setAlert('Original Intake review unavailable: '+(error.message||error),'error');
      });
    }
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
