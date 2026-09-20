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

  function statusClass(value) {
    if (value === 'COMPLETE' || value === 'ASSIGNED_ACTIVE' || value === 'REVIEWED_SHARED_NON_TASK') return 'ok';
    if (value === 'INACTIVE_OBSOLETE_ONLY') return 'warn';
    return 'error';
  }

  function setupTaskLink(taskId, label) {
    if (!taskId) return '<span class="muted">No scoped task</span>';
    const correction = label === 'Open Display Ownership' ? '&correction=display-ownership' : '&correction=kit-boxes';
    return `<a class="button secondary" href="../?view=library&setup_task_id=${encodeURIComponent(taskId)}${correction}">${esc(label)}</a>`;
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
      <td>${setupTaskLink(row.correction_setup_task_id, 'Open Display Ownership')}</td>
    </tr>`).join('') || '<tr><td colspan="11" class="muted">No Display/LOR rows match this filter.</td></tr>';
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
      note = window.prompt('Optional Manager note/reason for shared/non-task Kit disposition:', '') ?? null;
      if (note === null) return;
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
      if (firstActive || firstInactive) actions.push(setupTaskLink(firstActive || firstInactive, 'Open Kit assignment'));
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
    renderDisplay();
    renderKit();
  }

  async function loadAudit() {
    const payload = await api('api/setup/material-audit');
    state.audit = payload.audit || {};
    render();
    const ds = state.audit.display?.summary || {};
    const ks = state.audit.kit?.summary || {};
    const openCount = Number(ds.review_required || 0)
      + Number(ks.inactive_obsolete_only || 0)
      + Number(ks.unresolved_unassigned || 0)
      + Number(ks.disposition_conflicts || 0);
    setAlert(openCount ? `${openCount} material completeness exception group(s) require Manager review.` : 'Material completeness audit has no unresolved exceptions.', openCount ? 'error' : 'ok');
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
