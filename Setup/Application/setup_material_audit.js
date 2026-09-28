/* Issue #145 — Manager-facing Catalog Material Completeness Audit. */
(() => {
  const state = { access: null, audit: null, filter: 'exceptions' };
  const el = (id) => document.getElementById(id);

  function appBasePath() {
    const marker = '/material-audit';
    const index = window.location.pathname.indexOf(marker);
    return index >= 0 ? window.location.pathname.slice(0, index + 1) : '/';
  }

  const APP_BASE = appBasePath();

  function appUrl(path) {
    return `${APP_BASE}${String(path || '').replace(/^\/+/, '')}`;
  }

  function esc(value) {
    return String(value ?? '')
      .replaceAll('&', '&amp;').replaceAll('<', '&lt;').replaceAll('>', '&gt;')
      .replaceAll('"', '&quot;').replaceAll("'", '&#039;');
  }

  async function api(path, options = {}) {
    const response = await fetch(appUrl(path), {
      credentials: 'same-origin',
      headers: { Accept: 'application/json', ...(options.headers || {}) },
      ...options,
    });
    const payload = await response.json().catch(() => ({}));
    if (!response.ok) throw new Error(payload.error || `Setup API returned HTTP ${response.status}`);
    return payload;
  }

  function commandOptions(body) {
    return {
      method: 'PATCH',
      headers: { 'Content-Type': 'application/json', 'X-MSB-Setup-Command': '1' },
      body: JSON.stringify(body),
    };
  }

  function setAlert(message, stateName = 'ok') {
    el('audit-alert').textContent = message;
    el('audit-alert').dataset.state = stateName;
  }

  function syncThemeButton() {
    const current = document.documentElement.dataset.theme
      || (window.matchMedia('(prefers-color-scheme: dark)').matches ? 'dark' : 'light');
    el('theme-toggle').textContent = current === 'dark' ? 'Light mode' : 'Dark mode';
  }

  function configureTheme() {
    try {
      const saved = localStorage.getItem('msb-theme');
      if (saved === 'light' || saved === 'dark') document.documentElement.dataset.theme = saved;
    } catch (_error) {}
    syncThemeButton();
    el('theme-toggle').addEventListener('click', () => {
      const current = document.documentElement.dataset.theme
        || (window.matchMedia('(prefers-color-scheme: dark)').matches ? 'dark' : 'light');
      const next = current === 'dark' ? 'light' : 'dark';
      document.documentElement.dataset.theme = next;
      try { localStorage.setItem('msb-theme', next); } catch (_error) {}
      syncThemeButton();
    });
  }

  function summaryCard(label, value) {
    return `<div class="summary-card"><span>${esc(label)}</span><strong>${esc(value)}</strong></div>`;
  }

  function taskList(rows, inactive = false) {
    if (!rows?.length) return '<span class="muted">None</span>';
    return `<div class="task-list">${rows.map((row) => {
      const scope = [row.stage_key, row.scene_name].filter(Boolean).join(' · ');
      return `<div class="${inactive ? 'inactive' : ''}">#${esc(row.setup_task_id)} · ${esc(row.task_name)}${scope ? ` · ${esc(scope)}` : ''}</div>`;
    }).join('')}</div>`;
  }

  function displayIsException(row) {
    return row.coverage_status !== 'COMPLETE';
  }

  function kitIsException(row) {
    return Boolean(row.needs_review);
  }

  function extraMaterialSourceIsException(row) {
    return Boolean(row.needs_review);
  }

  function statusClass(value) {
    if (value === 'COMPLETE' || value === 'ASSIGNED_ACTIVE' || value === 'REVIEWED_SHARED_NON_TASK' || value === 'SOURCE_ASSIGNED') return 'ok';
    if (value === 'INACTIVE_OBSOLETE_ONLY' || value === 'HISTORICAL_SOURCE_REVIEW' || value === 'RECONSTRUCTION_REVIEW') return 'warn';
    return 'error';
  }

  function setupTaskLink(taskId, label, correction = null) {
    if (!taskId) return '<span class="muted">No scoped task</span>';
    const correctionQuery = correction ? `&correction=${encodeURIComponent(correction)}` : '';
    return `<a class="button secondary" href="../?view=review&setup_task_id=${encodeURIComponent(taskId)}${correctionQuery}">${esc(label)}</a>`;
  }

  function resolveExtraMaterialSourceLink(taskId, requirementId) {
    if (!taskId || !requirementId) return '<span class="muted">Requirement identity unavailable</span>';
    return `<a class="button secondary" href="../?view=review&setup_task_id=${encodeURIComponent(taskId)}&correction=extra-material-source&setup_task_extra_material_id=${encodeURIComponent(requirementId)}">Resolve Source</a>`;
  }

  function reviewExtraMaterialRequirementLink(taskId, requirementId) {
    if (!taskId || !requirementId) return '<span class="muted">Requirement identity unavailable</span>';
    return `<a class="button secondary" href="../?view=review&setup_task_id=${encodeURIComponent(taskId)}&correction=extra-material-requirement&setup_task_extra_material_id=${encodeURIComponent(requirementId)}">Review Requirement</a>`;
  }

  function historicalSourceContext(row) {
    const context = Array.isArray(row.prior_inactive_source_context) ? row.prior_inactive_source_context : [];
    if (!context.length) return '';
    const unique = [];
    const seenSources = new Set();
    const seenRequirements = new Set();
    for (const item of context) {
      const key = String(item.setup_task_extra_material_source_id || '') || `${item.setup_task_id}:${item.container_id}`;
      if (seenSources.has(key)) continue;
      seenSources.add(key);
      const requirementId = Number(item.setup_task_extra_material_id || 0);
      const taskId = Number(item.setup_task_id || 0);
      const label = `#${item.setup_task_id} ${item.task_name || 'prior task'} → C${item.container_id} ${item.container_description || ''}`.trim();
      let restore = '';
      if (state.access?.can_manage_setup && requirementId && taskId && !seenRequirements.has(requirementId)) {
        seenRequirements.add(requirementId);
        restore = `<button type="button" class="small restore-historical-requirement"
            data-prior-task-id="${esc(taskId)}"
            data-prior-requirement-id="${esc(requirementId)}">Restore prior requirement #${esc(requirementId)}</button>`;
      }
      const reassign = state.access?.can_manage_setup && item.setup_task_extra_material_source_id
        ? `<button type="button" class="small secondary reassign-historical-source"
            data-target-requirement-id="${esc(row.setup_task_extra_material_id)}"
            data-source-id="${esc(item.setup_task_extra_material_source_id)}"
            data-container-id="${esc(item.container_id)}"
            data-expected-quantity="${esc(item.expected_quantity ?? '')}"
            data-verification-state="${esc(item.verification_state || 'UNVERIFIED')}"
            data-notes="${esc(item.notes || '')}">Move C${esc(item.container_id)} to current requirement</button>`
        : '';
      unique.push(`<div class="historical-source-item"><span>${esc(label)}</span><div class="action-row">${restore}${reassign}</div></div>`);
    }
    return `<div class="historical-source-context"><div class="muted">Source authority exists on an inactive historical requirement. Decide whether that prior requirement is the correct reusable authority to restore, or whether the source truly belongs on the current requirement.</div>${unique.join('')}</div>`;
  }

  async function restoreHistoricalRequirement(button) {
    const taskId = Number(button.dataset.priorTaskId || 0);
    const requirementId = Number(button.dataset.priorRequirementId || 0);
    if (!taskId || !requirementId) return;
    if (!window.confirm(
      `Restore historical Extra Material requirement #${requirementId} on reusable task #${taskId}? Existing source rows remain attached to that same requirement.`,
    )) return;
    try {
      setAlert(`Restoring historical requirement #${requirementId}…`);
      await api(
        `api/setup/tasks/${taskId}/extra-materials/${requirementId}/restore`,
        commandOptions({}),
      );
      await loadAudit();
      setAlert(`Historical requirement #${requirementId} restored. Review any competing current requirement separately.`);
    } catch (error) {
      setAlert(error.message || error, 'error');
    }
  }

  async function reassignHistoricalSource(button) {
    const targetRequirementId = Number(button.dataset.targetRequirementId || 0);
    const sourceId = Number(button.dataset.sourceId || 0);
    const containerId = Number(button.dataset.containerId || 0);
    if (!targetRequirementId || !sourceId || !containerId) return;
    const confirmed = window.confirm(
      `Move existing source C${containerId} to the current Extra Material requirement? Use this only when the current requirement is the correct reusable authority. This moves the existing source row; it does not create a duplicate.`,
    );
    if (!confirmed) return;

    const quantityText = String(button.dataset.expectedQuantity || '').trim();
    const expectedQuantity = quantityText ? Number(quantityText) : null;
    try {
      setAlert(`Reassigning C${containerId} to the current requirement…`);
      await api(
        `api/setup/task-extra-materials/${targetRequirementId}/sources/${sourceId}`,
        commandOptions({
          container_id: containerId,
          expected_quantity: Number.isFinite(expectedQuantity) ? expectedQuantity : null,
          verification_state: button.dataset.verificationState || 'UNVERIFIED',
          notes: button.dataset.notes || null,
          active_flag: true,
        }),
      );
      await loadAudit();
      setAlert(`C${containerId} source authority reassigned to the current requirement.`);
    } catch (error) {
      setAlert(error.message || error, 'error');
    }
  }

  function extraMaterialRequiredText(row) {
    const quantity = [row.quantity_required, row.quantity_uom].filter((value) => value != null && String(value).trim() !== '').join(' ');
    const spec = [];
    if (row.quantity_qualifier) spec.push(String(row.quantity_qualifier).replaceAll('_', ' '));
    if (row.size_text) spec.push(row.size_text);
    if (row.length_value != null) spec.push([row.length_value, row.length_unit].filter(Boolean).join(' '));
    if (row.color) spec.push(row.color);
    return [quantity || 'Quantity not recorded', spec.join(' · ')].filter(Boolean).join(' · ');
  }

  function renderFutureSession() {
    const future = state.audit?.future_session || {};
    const summary = future.summary || {};
    el('future-session-summary').innerHTML = [
      ['Active · will seed', summary.active_will_seed || 0],
      ['Inactive · omitted', summary.inactive_will_not_seed || 0],
      ['Inactive with history', summary.inactive_with_history || 0],
      ['Inactive with material', summary.inactive_with_material || 0],
      ['Active tasks depend on', summary.inactive_prerequisites || 0],
      ['Inactive with signals', summary.inactive_with_signals || 0],
    ].map(([label, value]) => summaryCard(label, value)).join('');

    const rows = future.inactive_tasks || [];
    el('future-session-audit-body').innerHTML = rows.map((row) => {
      const scope = [row.stage_key, row.scene_name].filter(Boolean).join(' · ') || 'No Stage / site-wide';
      const signals = row.impact_signals?.length
        ? row.impact_signals.map((item) => `<span class="status warn">${esc(item)}</span>`).join(' ')
        : '<span class="muted">No linked material/history/dependency signal; still omitted because inactive.</span>';
      const history = row.annual_history_count
        ? `${esc(row.annual_history_count)} annual row(s)${row.latest_season_year ? ` · latest ${esc(row.latest_season_year)}` : ''}`
        : 'None';
      return `<tr>
        <td><strong>#${esc(row.setup_task_id)} · ${esc(row.task_name)}</strong><div class="muted">Order ${esc(row.display_order ?? '—')} · ${esc(row.task_action_type || 'WORK')}</div></td>
        <td>${esc(scope)}</td>
        <td><div class="signal-stack">${signals}</div></td>
        <td>${esc(history)}</td>
        <td><span class="status error">WILL NOT SEED</span><div class="muted">Review whether this is intentionally retired or should be reactivated before creating the next Session.</div></td>
        <td>${setupTaskLink(row.setup_task_id, 'Open reusable task')}</td>
      </tr>`;
    }).join('') || '<tr><td colspan="6" class="muted">No inactive reusable tasks. Every reusable task is currently eligible for future Session seeding.</td></tr>';
  }

  function renderDisplay() {
    const display = state.audit?.display || {};
    const summary = display.summary || {};
    el('display-summary').innerHTML = [
      ['Scopes reviewed', summary.scopes_reviewed || 0],
      ['Complete', summary.complete || 0],
      ['Review required', summary.review_required || 0],
      ['Missing', summary.missing || 0],
      ['Invalid / duplicate', Number(summary.invalid || 0) + Number(summary.duplicate || 0)],
      ['Stale', summary.stale || 0],
    ].map(([label, value]) => summaryCard(label, value)).join('');

    const allRows = display.scopes || [];
    const rows = state.filter === 'exceptions' ? allRows.filter(displayIsException) : allRows;
    el('display-audit-body').innerHTML = rows.map((row) => `<tr>
      <td><strong>${esc(row.scope_label)}</strong>${row.scope_issue ? `<div class="conflict">${esc(row.scope_issue)}</div>` : ''}</td>
      <td>${taskList(row.active_tasks)}</td>
      <td>${taskList(row.material_tasks)}</td>
      <td>${esc(row.source_display_count || 0)}</td>
      <td><span class="status ${statusClass(row.coverage_status)}">${esc(row.ownership_mode || '—')} · ${esc(row.coverage_status || '—')}</span></td>
      <td>${esc(row.missing_owner_count || 0)}</td>
      <td>${esc(row.invalid_owner_count || 0)}</td>
      <td>${esc(row.duplicate_owner_count || 0)}</td>
      <td>${esc(row.stale_owner_count || 0)}</td>
      <td>${esc(row.uncontained_display_count || 0)}</td>
      <td>${setupTaskLink(row.correction_setup_task_id, 'Open Display Ownership', 'display-ownership')}</td>
    </tr>`).join('') || '<tr><td colspan="11" class="muted">No Display/LOR rows match this filter.</td></tr>';
  }

  function renderExtraMaterialSource() {
    const source = state.audit?.extra_material_source || {};
    const summary = source.summary || {};
    el('extra-material-source-summary').innerHTML = [
      ['Requirements reviewed', summary.requirements_reviewed || 0],
      ['Source assigned', summary.source_assigned || 0],
      ['Historical source review', summary.historical_source_review || 0],
      ['Reconstruction review', summary.reconstruction_review || 0],
      ['No active source', summary.unresolved_no_source || 0],
    ].map(([label, value]) => summaryCard(label, value)).join('');

    const allRows = source.requirements || [];
    const rows = state.filter === 'exceptions' ? allRows.filter(extraMaterialSourceIsException) : allRows;
    el('extra-material-source-audit-body').innerHTML = rows.map((row) => {
      const scope = [row.stage_key, row.stage_name, row.scene_name].filter(Boolean).join(' · ') || 'No Stage / site-wide';
      let sourceStatus = 'NO ACTIVE SOURCE';
      if (Number(row.active_source_count || 0) > 0) {
        sourceStatus = `${row.active_source_count} active source${Number(row.active_source_count) === 1 ? '' : 's'}`;
      } else if (row.source_status === 'HISTORICAL_SOURCE_REVIEW') {
        sourceStatus = 'HISTORICAL SOURCE REVIEW';
      } else if (row.source_status === 'RECONSTRUCTION_REVIEW') {
        sourceStatus = 'RECONSTRUCTION REVIEW';
      }
      let actions = '<span class="muted">Source authority present</span>';
      if (row.needs_review) {
        const review = reviewExtraMaterialRequirementLink(row.setup_task_id, row.setup_task_extra_material_id);
        const resolve = resolveExtraMaterialSourceLink(row.setup_task_id, row.setup_task_extra_material_id);
        actions = row.source_status === 'NO_ACTIVE_SOURCE'
          ? `<div class="action-stack">${resolve}${review}</div>`
          : `<div class="action-stack">${review}${resolve}</div>`;
      }
      return `<tr>
        <td>${esc(scope)}</td>
        <td><strong>#${esc(row.setup_task_id)} · ${esc(row.task_name)}</strong></td>
        <td><strong>${esc(row.material_name || 'Extra Material')}</strong>${row.requirement_notes ? `<div class="muted">${esc(row.requirement_notes)}</div>` : ''}</td>
        <td>${esc(extraMaterialRequiredText(row))}</td>
        <td><span class="status ${statusClass(row.verification_state === 'VERIFIED' ? 'SOURCE_ASSIGNED' : row.verification_state)}">${esc(String(row.verification_state || 'UNVERIFIED').replaceAll('_', ' '))}</span></td>
        <td><span class="status ${statusClass(row.source_status)}">${esc(sourceStatus)}</span>${historicalSourceContext(row)}</td>
        <td>${actions}</td>
      </tr>`;
    }).join('') || '<tr><td colspan="7" class="muted">No Extra Material source rows match this filter.</td></tr>';

    document.querySelectorAll('.restore-historical-requirement').forEach((button) => {
      button.addEventListener('click', () => { void restoreHistoricalRequirement(button); });
    });
    document.querySelectorAll('.reassign-historical-source').forEach((button) => {
      button.addEventListener('click', () => { void reassignHistoricalSource(button); });
    });
  }

  function dispositionText(row) {
    if (!row.disposition_active) return '<span class="muted">None</span>';
    const who = row.disposition_reviewed_by || `Person ${row.reviewed_by_person_id || ''}`;
    const when = row.disposition_reviewed_at ? new Date(row.disposition_reviewed_at).toLocaleString() : '';
    return `<strong>Reviewed shared/non-task</strong><div class="muted">${esc(who)}${when ? ` · ${esc(when)}` : ''}</div>${row.disposition_note ? `<div>${esc(row.disposition_note)}</div>` : ''}`;
  }

  async function setDisposition(containerId, reviewed) {
    let note = null;
    if (reviewed) {
      note = window.prompt('Manager reason for shared/non-task Kit disposition (required):', '') ?? null;
      if (note === null) return;
      if (!String(note).trim()) {
        setAlert('A Manager reason is required before marking a Kit reviewed shared/non-task.', 'error');
        return;
      }
    } else {
      const confirmed = window.confirm('Clear the current reviewed shared/non-task disposition for this Kit Box?');
      if (!confirmed) return;
    }
    try {
      setAlert(reviewed ? 'Recording Manager disposition…' : 'Clearing Manager disposition…');
      await api(
        `api/setup/material-audit/kits/${containerId}/shared-non-task`,
        commandOptions({ reviewed_shared_non_task: reviewed, note }),
      );
      await loadAudit();
    } catch (error) {
      setAlert(error.message || error, 'error');
    }
  }

  function renderKit() {
    const kit = state.audit?.kit || {};
    const summary = kit.summary || {};
    el('kit-summary').innerHTML = [
      ['Physical Kit Boxes', summary.physical_kit_boxes || 0],
      ['Assigned active', summary.assigned_active || 0],
      ['Inactive / obsolete only', summary.inactive_obsolete_only || 0],
      ['Reviewed shared / non-task', summary.reviewed_shared_non_task || 0],
      ['Unresolved unassigned', summary.unresolved_unassigned || 0],
      ['Disposition conflicts', summary.disposition_conflicts || 0],
    ].map(([label, value]) => summaryCard(label, value)).join('');

    const allRows = kit.kits || [];
    const rows = state.filter === 'exceptions' ? allRows.filter(kitIsException) : allRows;
    el('kit-audit-body').innerHTML = rows.map((row) => {
      const actions = [
        `<a class="button secondary" href="../kit-inventory/${encodeURIComponent(row.container_id)}">Open Kit Inventory</a>`,
      ];
      const firstActive = row.active_assignments?.[0]?.setup_task_id;
      const firstInactive = row.inactive_assignments?.[0]?.setup_task_id;
      if (firstActive || firstInactive) actions.push(setupTaskLink(firstActive || firstInactive, 'Open Kit assignment', 'kit-boxes'));
      if (row.coverage_state === 'UNASSIGNED_UNRESOLVED' && !row.disposition_active) {
        actions.push(`<button type="button" data-disposition-set="${row.container_id}">Mark reviewed shared/non-task</button>`);
      }
      if (row.disposition_active) {
        actions.push(`<button type="button" class="secondary" data-disposition-clear="${row.container_id}">Clear disposition</button>`);
      }
      return `<tr>
        <td><strong>C${String(row.container_id).padStart(3, '0')} · ${esc(row.container_description || 'Kit Box')}</strong><div class="muted">${esc(row.home_location_code || 'Home location not recorded')}</div></td>
        <td><span class="status ${statusClass(row.coverage_state)}">${esc(row.coverage_state)}</span>${row.disposition_conflict ? '<div class="conflict">Disposition conflicts with an existing KIT relationship.</div>' : ''}</td>
        <td>${taskList(row.active_assignments)}</td>
        <td>${taskList(row.inactive_assignments, true)}</td>
        <td>${dispositionText(row)}</td>
        <td><div class="action-stack">${actions.join('')}</div></td>
      </tr>`;
    }).join('') || '<tr><td colspan="6" class="muted">No Kit rows match this filter.</td></tr>';

    document.querySelectorAll('[data-disposition-set]').forEach((button) => {
      button.addEventListener('click', () => setDisposition(Number(button.dataset.dispositionSet), true));
    });
    document.querySelectorAll('[data-disposition-clear]').forEach((button) => {
      button.addEventListener('click', () => setDisposition(Number(button.dataset.dispositionClear), false));
    });
  }

  function render() {
    renderFutureSession();
    renderDisplay();
    renderExtraMaterialSource();
    renderKit();
  }

  async function loadAudit() {
    const payload = await api('api/setup/material-audit');
    state.audit = payload.audit || {};
    render();
    const fs = state.audit.future_session?.summary || {};
    const ds = state.audit.display?.summary || {};
    const es = state.audit.extra_material_source?.summary || {};
    const ks = state.audit.kit?.summary || {};
    const openCount = Number(fs.inactive_will_not_seed || 0)
      + Number(ds.review_required || 0)
      + Number(es.unresolved_no_source || 0)
      + Number(ks.inactive_obsolete_only || 0)
      + Number(ks.unresolved_unassigned || 0)
      + Number(ks.disposition_conflicts || 0);
    setAlert(openCount ? `${openCount} Setup readiness/material review item(s) require Manager attention.` : 'Material completeness audit has no unresolved exceptions.', openCount ? 'error' : 'ok');
  }

  async function initialize() {
    configureTheme();
    try {
      const accessPayload = await api('api/setup/access');
      state.access = accessPayload.access || {};
      if (!state.access.can_manage_setup) throw new Error('Setup Manager access is required for the Material Completeness Audit.');
      el('audit-access').textContent = `${state.access.display_name || state.access.authenticated_email || 'Signed in'} · Manager`;
      await loadAudit();
    } catch (error) {
      el('audit-access').textContent = 'Manager access unavailable';
      setAlert(error.message || error, 'error');
    }
  }

  el('audit-filter').addEventListener('change', () => {
    state.filter = el('audit-filter').value;
    render();
  });
  el('audit-refresh').addEventListener('click', loadAudit);

  initialize();
})();
