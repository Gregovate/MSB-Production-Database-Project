/* Issue #167 — assignment visibility + assigned/unassigned Kit reconciliation filters. */
(() => {
  const state = { kitBoxes: [], byId: new Map(), filter: 'all' };
  const el = (id) => document.getElementById(id);

  function appBasePath() {
    const marker = '/kit-inventory';
    const index = window.location.pathname.indexOf(marker);
    return index >= 0 ? window.location.pathname.slice(0, index + 1) : '/';
  }
  const APP_BASE = appBasePath();
  function appUrl(path) { return `${APP_BASE}${String(path || '').replace(/^\/+/, '')}`; }
  function esc(value) {
    return String(value ?? '')
      .replaceAll('&', '&amp;').replaceAll('<', '&lt;').replaceAll('>', '&gt;')
      .replaceAll('"', '&quot;').replaceAll("'", '&#039;');
  }
  function selectedContainerId() {
    const match = window.location.pathname.match(/\/kit-inventory\/(\d+)\/?$/);
    return match ? Number(match[1]) : null;
  }

  async function loadKitBoxes() {
    const response = await fetch(appUrl('api/setup/kit-inventory/kit-boxes'), {
      credentials: 'same-origin', headers: { Accept: 'application/json' },
    });
    const payload = await response.json().catch(() => ({}));
    if (!response.ok) throw new Error(payload.error || `Setup API returned HTTP ${response.status}`);
    state.kitBoxes = payload.kit_boxes || [];
    state.byId = new Map(state.kitBoxes.map((row) => [Number(row.container_id), row]));
    applyFilter();
    renderAssignments();
  }

  function setFilter(next) {
    state.filter = next;
    ['all', 'assigned', 'unassigned'].forEach((name) => {
      const button = el(`kit-filter-${name}`);
      button?.classList.toggle('active-filter', name === next);
      button?.setAttribute('aria-pressed', name === next ? 'true' : 'false');
    });
    applyFilter();
  }

  function filterMatches(row) {
    const assigned = Number(row?.assigned_task_count || 0) > 0;
    if (state.filter === 'assigned') return assigned;
    if (state.filter === 'unassigned') return !assigned;
    return true;
  }

  function applyFilter() {
    const assigned = state.kitBoxes.filter((row) => Number(row.assigned_task_count || 0) > 0).length;
    const unassigned = state.kitBoxes.length - assigned;
    const summary = el('kit-filter-status');
    if (summary) summary.textContent = `${state.kitBoxes.length} total · ${assigned} assigned · ${unassigned} unassigned`;

    document.querySelectorAll('.kit-row[data-container-id]').forEach((button) => {
      const row = state.byId.get(Number(button.dataset.containerId));
      button.hidden = row ? !filterMatches(row) : false;
    });
  }

  function renderAssignments() {
    const body = el('kit-task-assignment-body');
    if (!body) return;
    const containerId = selectedContainerId();
    if (!containerId) {
      body.innerHTML = '<tr><td colspan="4" class="empty-state">Select a Kit Box.</td></tr>';
      return;
    }
    const kit = state.byId.get(containerId);
    const tasks = Array.isArray(kit?.assigned_tasks) ? kit.assigned_tasks : [];
    body.innerHTML = tasks.map((task) => {
      const stage = [task.stage_key, task.stage_name].filter(Boolean).join(' · ') || 'Site-wide / unresolved Stage';
      return `<tr>
        <td>${esc(stage)}</td>
        <td>${esc(task.setup_task_id)}</td>
        <td><strong>${esc(task.task_name || '')}</strong></td>
        <td>${esc(task.relationship_notes || '')}</td>
      </tr>`;
    }).join('') || '<tr><td colspan="4" class="empty-state"><strong>Unassigned Kit.</strong> No reusable Setup task → KIT relationship exists yet.</td></tr>';
  }

  function bind() {
    el('kit-filter-all')?.addEventListener('click', () => setFilter('all'));
    el('kit-filter-assigned')?.addEventListener('click', () => setFilter('assigned'));
    el('kit-filter-unassigned')?.addEventListener('click', () => setFilter('unassigned'));
    el('kit-search')?.addEventListener('input', () => queueMicrotask(applyFilter));
    el('kit-list')?.addEventListener('click', () => queueMicrotask(renderAssignments));
    window.addEventListener('popstate', () => queueMicrotask(renderAssignments));

    const list = el('kit-list');
    if (list) new MutationObserver(applyFilter).observe(list, { childList: true, subtree: true });
    const title = el('kit-title');
    if (title) new MutationObserver(renderAssignments).observe(title, { childList: true, subtree: true, characterData: true });

    loadKitBoxes().catch((error) => {
      const summary = el('kit-filter-status');
      if (summary) summary.textContent = error.message;
    });
  }

  if (document.readyState === 'loading') document.addEventListener('DOMContentLoaded', bind);
  else bind();
})();
