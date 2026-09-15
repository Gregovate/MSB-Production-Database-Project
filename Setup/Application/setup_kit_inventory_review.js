/* Issue #184 — compact Kit review + safe reconciliation/edit/inventory UX. */
(() => {
  const state = {
    kitBoxes: [],
    byId: new Map(),
    filter: 'all',
    inventoryContentId: null,
    inventoryCurrentOnHand: null,
    inventoryUom: 'EA',
    expectedSubmitPending: false,
  };
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
  function formatNumber(value) {
    if (value == null || value === '') return '—';
    const n = Number(value);
    if (!Number.isFinite(n)) return String(value);
    return Number.isInteger(n) ? String(n) : String(Number(n.toFixed(3)));
  }
  function numberOrNull(value) {
    const text = String(value ?? '').trim();
    if (!text) return null;
    const parsed = Number(text);
    return Number.isFinite(parsed) ? parsed : null;
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
    updateOverview();
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

  function normalizeRemainderDisplay() {
    const textarea = el('unverified-items');
    if (!textarea || !textarea.value.includes('\\n')) return;
    textarea.value = textarea.value.replace(/\\n/g, '\n');
  }

  function selectedKit() {
    const containerId = selectedContainerId();
    return containerId ? state.byId.get(containerId) : null;
  }

  function updateOverview() {
    const kit = selectedKit();
    const set = (id, value) => { if (el(id)) el(id).textContent = String(value); };
    if (!kit) {
      ['overview-task-count','overview-display-count','overview-expected-count','overview-counted-count','overview-review-state']
        .forEach((id) => set(id, '—'));
      return;
    }
    set('overview-task-count', Number(kit.assigned_task_count || 0));
    set('overview-display-count', Number(kit.display_rows || 0));
    set('overview-expected-count', Number(kit.expected_item_rows || 0));
    set('overview-counted-count', Number(kit.counted_item_rows || 0));
    set('overview-review-state', kit.has_unverified_items ? 'Review' : 'None');
  }

  function renderAssignments() {
    normalizeRemainderDisplay();
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
    updateOverview();
  }

  function configurePermanentNavigation() {
    const back = el('inventory-back-setup');
    if (back) back.href = APP_BASE;
    const tpost = document.querySelector('a[href*="t-post-inventory"]');
    if (tpost) tpost.href = appUrl('t-post-inventory/');
  }

  function focusEditor(sectionId, focusId) {
    const section = el(sectionId);
    if (!section || section.hidden) return;
    window.requestAnimationFrame(() => {
      section.scrollIntoView({ behavior: 'smooth', block: 'start' });
      window.setTimeout(() => el(focusId)?.focus({ preventScroll: true }), 180);
    });
  }

  function closeExpectedPanel() {
    if (el('expected-editor')) el('expected-editor').hidden = true;
    clearEditDecoration();
  }

  function openExpectedPanel(focusId = 'expected-item') {
    const panel = el('expected-editor');
    if (!panel) return;
    panel.hidden = false;
    if (el('inventory-editor')) el('inventory-editor').hidden = true;
    focusEditor('expected-editor', focusId);
  }

  function closeInventoryPanel() {
    if (el('inventory-editor')) el('inventory-editor').hidden = true;
    state.inventoryContentId = null;
    state.inventoryCurrentOnHand = null;
    syncInventoryMath();
  }

  function openInventoryPanel() {
    const panel = el('inventory-editor');
    if (!panel) return;
    panel.hidden = false;
    if (el('expected-editor')) el('expected-editor').hidden = true;
    focusEditor('inventory-editor', 'inventory-delta');
  }

  function clearEditDecoration() {
    document.querySelectorAll('#kit-content-body tr.editing-source-row').forEach((row) => row.classList.remove('editing-source-row'));
    const editor = el('expected-editor');
    editor?.classList.remove('editing');
    const banner = el('expected-editor-status');
    if (banner) {
      banner.hidden = true;
      banner.textContent = '';
    }
    if (el('expected-editor-title')) el('expected-editor-title').textContent = 'Manager — Add Expected Extra Material';
    if (el('expected-clear')) el('expected-clear').textContent = 'Cancel';
  }

  function markExpectedEdit(button) {
    clearEditDecoration();
    const row = button.closest('tr');
    if (!row) return;
    row.classList.add('editing-source-row');
    const itemName = row.cells?.[0]?.textContent?.trim() || 'expected item';
    const editor = el('expected-editor');
    editor?.classList.add('editing');
    const banner = el('expected-editor-status');
    if (banner) {
      banner.hidden = false;
      banner.textContent = `EDITING EXISTING ROW — ${itemName}. Save changes or Cancel edit.`;
    }
    if (el('expected-editor-title')) el('expected-editor-title').textContent = 'Manager — Edit Expected Extra Material';
    if (el('expected-clear')) el('expected-clear').textContent = 'Cancel edit';
  }

  function compactContentRows() {
    document.querySelectorAll('#kit-content-body tr').forEach((row) => {
      const notes = row.cells?.[5];
      if (notes) {
        notes.classList.add('content-notes');
        notes.title = notes.textContent?.trim() || '';
      }
    });
  }

  function physicalFromRow(row) {
    const text = row?.cells?.[4]?.textContent?.trim() || '';
    if (!text || /not counted/i.test(text)) return { current: null, uom: 'EA' };
    const match = text.match(/(-?\d+(?:\.\d+)?)\s*([A-Za-z]+)?/);
    return match
      ? { current: Number(match[1]), uom: match[2] || 'EA' }
      : { current: null, uom: 'EA' };
  }

  function selectedPhysicalFromLabel() {
    const text = el('inventory-selected')?.textContent || '';
    const match = text.match(/On hand:\s*(not counted|-?\d+(?:\.\d+)?)/i);
    if (!match) return;
    state.inventoryCurrentOnHand = /not counted/i.test(match[1]) ? null : Number(match[1]);
  }

  function syncInventoryMath() {
    const target = el('inventory-math');
    const label = el('inventory-quantity-label');
    if (!target || !label) return;
    selectedPhysicalFromLabel();
    if (!state.inventoryContentId) {
      label.textContent = 'Quantity change (+/-)';
      target.textContent = 'Select an expected item to see the physical inventory calculation.';
      target.dataset.state = '';
      return;
    }

    const eventType = el('inventory-type')?.value || 'OTHER';
    const entered = numberOrNull(el('inventory-delta')?.value);
    const current = state.inventoryCurrentOnHand;
    const uom = state.inventoryUom || 'EA';
    label.textContent = eventType === 'INITIAL_COUNT' ? 'Observed initial count' : 'Change to on-hand (+/-)';
    target.dataset.state = '';

    if (eventType === 'INITIAL_COUNT') {
      target.textContent = entered == null
        ? 'No prior physical count. Enter the observed count; that becomes the on-hand balance.'
        : `No prior physical count → ${formatNumber(entered)} ${uom} on hand.`;
      return;
    }
    if (current == null) {
      target.textContent = 'No baseline physical count exists. Record Initial count before an adjustment.';
      target.dataset.state = 'error';
      return;
    }
    if (entered == null) {
      target.textContent = `Current on hand: ${formatNumber(current)} ${uom}. Enter a +/− change to preview the new balance.`;
      return;
    }
    const next = current + entered;
    target.textContent = `${formatNumber(current)} ${uom} + (${formatNumber(entered)} ${uom}) = ${formatNumber(next)} ${uom} on hand.`;
    if (next < 0) target.dataset.state = 'error';
  }

  function bindRowActionFocus() {
    document.addEventListener('click', (event) => {
      if (event.target.closest('#expected-add')) {
        el('expected-clear')?.click();
        queueMicrotask(() => openExpectedPanel('expected-item'));
        return;
      }
      const editButton = event.target.closest('.expected-edit');
      if (editButton) {
        markExpectedEdit(editButton);
        openExpectedPanel('expected-qty');
        return;
      }
      if (event.target.closest('#expected-clear')) {
        queueMicrotask(closeExpectedPanel);
        return;
      }
      const inventoryButton = event.target.closest('.inventory-select');
      if (inventoryButton) {
        state.inventoryContentId = Number(inventoryButton.dataset.contentId);
        const physical = physicalFromRow(inventoryButton.closest('tr'));
        state.inventoryCurrentOnHand = physical.current;
        state.inventoryUom = physical.uom;
        queueMicrotask(syncInventoryMath);
        openInventoryPanel();
        return;
      }
      if (event.target.closest('#inventory-close')) {
        closeInventoryPanel();
        return;
      }
      if (event.target.closest('#kit-list .kit-row')) {
        closeExpectedPanel();
        closeInventoryPanel();
      }
    });
  }

  function bindInventoryMath() {
    el('inventory-type')?.addEventListener('change', syncInventoryMath);
    el('inventory-delta')?.addEventListener('input', syncInventoryMath);
    const selected = el('inventory-selected');
    if (selected) new MutationObserver(syncInventoryMath).observe(selected, { childList: true, subtree: true, characterData: true });
  }

  function bind() {
    configurePermanentNavigation();
    bindRowActionFocus();
    bindInventoryMath();
    el('expected-form')?.addEventListener('submit', () => { state.expectedSubmitPending = true; });
    el('kit-filter-all')?.addEventListener('click', () => setFilter('all'));
    el('kit-filter-assigned')?.addEventListener('click', () => setFilter('assigned'));
    el('kit-filter-unassigned')?.addEventListener('click', () => setFilter('unassigned'));
    el('kit-search')?.addEventListener('input', () => queueMicrotask(applyFilter));
    el('kit-list')?.addEventListener('click', () => queueMicrotask(renderAssignments));
    window.addEventListener('popstate', () => queueMicrotask(() => { renderAssignments(); updateOverview(); }));

    const list = el('kit-list');
    if (list) new MutationObserver(applyFilter).observe(list, { childList: true, subtree: true });
    const title = el('kit-title');
    if (title) new MutationObserver(() => { renderAssignments(); updateOverview(); }).observe(title, { childList: true, subtree: true, characterData: true });
    const contentBody = el('kit-content-body');
    if (contentBody) new MutationObserver(() => {
      compactContentRows();
      if (state.expectedSubmitPending) {
        state.expectedSubmitPending = false;
        closeExpectedPanel();
      } else if (!contentBody.querySelector('.editing-source-row')) {
        clearEditDecoration();
      }
      queueMicrotask(syncInventoryMath);
    }).observe(contentBody, { childList: true, subtree: true });

    loadKitBoxes().catch((error) => {
      const summary = el('kit-filter-status');
      if (summary) summary.textContent = error.message;
    });
  }

  if (document.readyState === 'loading') document.addEventListener('DOMContentLoaded', bind);
  else bind();
})();
