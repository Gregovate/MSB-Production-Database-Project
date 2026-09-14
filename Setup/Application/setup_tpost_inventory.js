/* Issue #167 — separate T-Post stock inventory outside Kit Boxes. */
(() => {
  const state = {
    access: null,
    containers: [],
    selectedContainerId: null,
    container: null,
    contents: [],
    tpostMaterialId: null,
    editingContentId: null,
    inventoryContentId: null,
  };
  const el = (id) => document.getElementById(id);

  function appBasePath() {
    const marker = '/t-post-inventory';
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
  function numberOrNull(value) {
    const text = String(value ?? '').trim();
    if (!text) return null;
    const parsed = Number(text);
    return Number.isFinite(parsed) ? parsed : null;
  }
  function formatNumber(value) {
    if (value == null || value === '') return '—';
    const n = Number(value);
    return Number.isFinite(n) ? (Number.isInteger(n) ? String(n) : String(Number(n.toFixed(3)))) : String(value);
  }
  function formatDate(value) {
    if (!value) return '';
    const date = new Date(value);
    return Number.isNaN(date.getTime()) ? String(value) : date.toLocaleString();
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
  function commandOptions(method, body) {
    return {
      method,
      headers: { 'Content-Type': 'application/json', 'X-MSB-Setup-Command': '1' },
      body: JSON.stringify(body),
    };
  }
  function setAlert(message, stateName = 'ok') {
    const target = el('inventory-alert');
    if (!target) return;
    target.textContent = message;
    target.dataset.state = stateName;
  }
  function setBusy(flag) { document.body.classList.toggle('busy', Boolean(flag)); }
  function canManage() { return Boolean(state.access?.can_manage_setup); }
  function canAdjustInventory() {
    const role = String(state.access?.role_name || '');
    const policies = new Set(state.access?.policy_names || []);
    return canManage() || role === 'Production Crew' || policies.has('Production Crew');
  }
  function applyAccess() {
    const access = state.access || {};
    el('inventory-access').textContent = `${access.display_name || access.authenticated_email || 'Signed in'} · ${access.role_name || 'No role'}`;
    document.querySelectorAll('.manager-only').forEach((node) => { node.hidden = !canManage(); });
    document.querySelectorAll('.inventory-operator-only').forEach((node) => { node.hidden = !canAdjustInventory(); });
  }
  function configureTheme() {
    try {
      const saved = localStorage.getItem('msb-theme');
      if (saved === 'light' || saved === 'dark') document.documentElement.dataset.theme = saved;
    } catch (_error) {}
    const sync = () => {
      const current = document.documentElement.dataset.theme
        || (window.matchMedia('(prefers-color-scheme: dark)').matches ? 'dark' : 'light');
      el('theme-toggle').textContent = current === 'dark' ? 'Light mode' : 'Dark mode';
    };
    sync();
    el('theme-toggle')?.addEventListener('click', () => {
      const current = document.documentElement.dataset.theme
        || (window.matchMedia('(prefers-color-scheme: dark)').matches ? 'dark' : 'light');
      const next = current === 'dark' ? 'light' : 'dark';
      document.documentElement.dataset.theme = next;
      try { localStorage.setItem('msb-theme', next); } catch (_error) {}
      sync();
    });
  }

  async function loadAccessAndCatalog() {
    const [accessPayload, catalogPayload] = await Promise.all([
      api('api/setup/access'),
      api('api/setup/extra-materials'),
    ]);
    state.access = accessPayload.access || {};
    const tpost = (catalogPayload.extra_materials || []).find((row) => row.material_name === 'T-Post');
    state.tpostMaterialId = tpost?.setup_extra_material_id || null;
    if (!state.tpostMaterialId) throw new Error('Normalized T-Post catalog family is unavailable.');
    applyAccess();
  }

  async function loadContainers() {
    const payload = await api('api/setup/t-post-inventory/containers');
    state.containers = payload.containers || [];
    renderContainerList();
    if (!state.selectedContainerId && state.containers.length) await selectContainer(Number(state.containers[0].container_id));
  }

  function renderContainerList() {
    const target = el('tpost-list');
    target.innerHTML = state.containers.map((row) => {
      const selected = Number(row.container_id) === Number(state.selectedContainerId);
      return `<button type="button" class="kit-row${selected ? ' selected' : ''}" data-container-id="${row.container_id}">
        <div class="kit-row-title">#${esc(row.container_id)} · ${esc(row.container_description || 'T-Post stock')}</div>
        <div class="kit-row-meta">${esc(row.home_location_code || 'Home location not recorded')}</div>
        <div class="kit-row-flags">
          <span class="pill">${esc(row.tpost_stock_rows || 0)} stock row${Number(row.tpost_stock_rows || 0) === 1 ? '' : 's'}</span>
          <span class="pill">${esc(row.counted_stock_rows || 0)} counted</span>
          ${Number(row.uncounted_stock_rows || 0) ? `<span class="pill">${esc(row.uncounted_stock_rows)} not counted</span>` : ''}
        </div>
      </button>`;
    }).join('') || '<div class="empty-state">No T-Post stock Containers are configured.</div>';
    target.querySelectorAll('.kit-row').forEach((button) => {
      button.addEventListener('click', () => selectContainer(Number(button.dataset.containerId)));
    });
  }

  async function selectContainer(containerId) {
    state.selectedContainerId = Number(containerId);
    state.editingContentId = null;
    state.inventoryContentId = null;
    renderContainerList();
    clearManagerForm();
    setBusy(true);
    try {
      const payload = await api(`api/setup/containers/${containerId}/extra-materials`);
      state.container = payload.container || null;
      state.contents = (payload.contents || []).filter((row) => row.material_name === 'T-Post');
      renderDetail();
      setAlert(`Loaded T-Post stock Container ${containerId}.`);
    } catch (error) {
      state.container = null;
      state.contents = [];
      renderDetail();
      setAlert(error.message, 'error');
    } finally {
      setBusy(false);
    }
  }

  function rowLabel(row) {
    const parts = [];
    if (row.length_value != null) parts.push(`${formatNumber(row.length_value)} ${row.length_unit || ''}`.trim());
    if (row.size_text) parts.push(row.size_text);
    return parts.length ? parts.join(' · ') : 'Generic / mixed T-Post stock';
  }

  function renderDetail() {
    const empty = el('tpost-empty');
    const detail = el('tpost-detail');
    if (!state.container) {
      empty.hidden = false;
      detail.hidden = true;
      return;
    }
    empty.hidden = true;
    detail.hidden = false;
    el('tpost-title').textContent = `Container ${state.container.container_id} — ${state.container.description || 'T-Post stock'}`;
    el('tpost-meta').textContent = state.container.location_code || '';

    const manager = canManage();
    const inventory = canAdjustInventory();
    el('tpost-content-body').innerHTML = state.contents.map((row) => {
      const onHand = row.on_hand_quantity == null ? '<span class="unknown">Not counted</span>' : esc(formatNumber(row.on_hand_quantity));
      const expected = row.expected_quantity == null ? '<span class="unknown">Unverified</span>' : esc(formatNumber(row.expected_quantity));
      return `<tr>
        <td><strong>${esc(rowLabel(row))}</strong></td>
        <td>${expected} ${esc(row.quantity_uom || 'EA')}</td>
        <td>${esc(row.verification_state || 'UNVERIFIED')}</td>
        <td>${onHand} ${esc(row.quantity_uom || 'EA')}</td>
        <td>${esc(row.notes || '')}</td>
        <td>
          ${manager ? `<button type="button" class="small secondary tpost-edit" data-content-id="${row.setup_container_extra_material_id}">Edit</button>` : ''}
          ${inventory ? `<button type="button" class="small tpost-count" data-content-id="${row.setup_container_extra_material_id}">Count / Adjust</button>` : ''}
        </td>
      </tr>`;
    }).join('') || '<tr><td colspan="6" class="empty-state">No active T-Post stock rows are recorded for this Container.</td></tr>';

    document.querySelectorAll('.tpost-edit').forEach((button) => {
      button.addEventListener('click', () => beginEdit(Number(button.dataset.contentId)));
    });
    document.querySelectorAll('.tpost-count').forEach((button) => {
      button.addEventListener('click', () => selectInventoryRow(Number(button.dataset.contentId)));
    });
    applyAccess();
  }

  function clearManagerForm() {
    state.editingContentId = null;
    ['tpost-expected-qty','tpost-length','tpost-size','tpost-notes'].forEach((id) => { if (el(id)) el(id).value = ''; });
    if (el('tpost-length-unit')) el('tpost-length-unit').value = '';
    if (el('tpost-verification')) el('tpost-verification').value = 'UNVERIFIED';
    if (el('tpost-save')) el('tpost-save').textContent = 'Add T-Post Row';
    ['tpost-length','tpost-length-unit','tpost-size'].forEach((id) => { if (el(id)) el(id).disabled = false; });
  }

  function beginEdit(contentId) {
    const row = state.contents.find((item) => Number(item.setup_container_extra_material_id) === Number(contentId));
    if (!row || !canManage()) return;
    state.editingContentId = contentId;
    el('tpost-expected-qty').value = row.expected_quantity ?? '';
    el('tpost-length').value = row.length_value ?? '';
    el('tpost-length-unit').value = row.length_unit || '';
    el('tpost-size').value = row.size_text || '';
    el('tpost-verification').value = row.verification_state || 'UNVERIFIED';
    el('tpost-notes').value = row.notes || '';
    el('tpost-save').textContent = 'Save T-Post Row';
    const immutable = Number(row.inventory_event_count || 0) > 0;
    ['tpost-length','tpost-length-unit','tpost-size'].forEach((id) => { el(id).disabled = immutable; });
  }

  function rowPayload() {
    return {
      setup_extra_material_id: Number(state.tpostMaterialId),
      expected_quantity: numberOrNull(el('tpost-expected-qty').value),
      quantity_uom: 'EA',
      size_text: el('tpost-size').value.trim() || null,
      length_value: numberOrNull(el('tpost-length').value),
      length_unit: el('tpost-length-unit').value || null,
      color: null,
      verification_state: el('tpost-verification').value,
      notes: el('tpost-notes').value.trim() || null,
      active_flag: true,
    };
  }

  async function saveRow(event) {
    event.preventDefault();
    if (!canManage() || !state.selectedContainerId) return;
    const path = state.editingContentId
      ? `api/setup/containers/${state.selectedContainerId}/extra-materials/${state.editingContentId}`
      : `api/setup/containers/${state.selectedContainerId}/extra-materials`;
    const method = state.editingContentId ? 'PATCH' : 'POST';
    setBusy(true);
    try {
      await api(path, commandOptions(method, rowPayload()));
      clearManagerForm();
      await selectContainer(state.selectedContainerId);
    } catch (error) {
      setAlert(error.message, 'error');
    } finally {
      setBusy(false);
    }
  }

  async function selectInventoryRow(contentId) {
    const row = state.contents.find((item) => Number(item.setup_container_extra_material_id) === Number(contentId));
    if (!row || !canAdjustInventory()) return;
    state.inventoryContentId = contentId;
    el('tpost-inventory-selected').textContent = rowLabel(row);
    el('tpost-inventory-type').value = Number(row.inventory_event_count || 0) > 0 ? 'COUNT_CORRECTION' : 'INITIAL_COUNT';
    el('tpost-inventory-delta').value = '';
    el('tpost-inventory-note').value = '';
    await loadHistory(contentId);
  }

  async function loadHistory(contentId) {
    try {
      const payload = await api(`api/setup/container-extra-materials/${contentId}/inventory-events`);
      const rows = payload.events || [];
      el('tpost-inventory-history').innerHTML = rows.map((row) => `<div class="history-row">
        <div>${esc(formatDate(row.occurred_at))}</div>
        <div><strong>${esc(row.event_type)}</strong><br>${esc(formatNumber(row.quantity_delta))}</div>
        <div>${esc(row.event_note || '')}${row.actor_display_name ? `<br><span class="muted">${esc(row.actor_display_name)}</span>` : ''}</div>
      </div>`).join('') || '<div class="muted">No physical inventory history yet.</div>';
    } catch (error) {
      el('tpost-inventory-history').textContent = error.message;
    }
  }

  async function recordInventory(event) {
    event.preventDefault();
    if (!canAdjustInventory() || !state.inventoryContentId) {
      setAlert('Select a T-Post stock row first.', 'error');
      return;
    }
    const delta = numberOrNull(el('tpost-inventory-delta').value);
    if (delta == null || delta === 0) {
      setAlert('Enter a non-zero inventory quantity change.', 'error');
      return;
    }
    setBusy(true);
    try {
      await api(
        `api/setup/container-extra-materials/${state.inventoryContentId}/inventory-events`,
        commandOptions('POST', {
          event_type: el('tpost-inventory-type').value,
          quantity_delta: delta,
          event_note: el('tpost-inventory-note').value.trim() || null,
          occurred_at: null,
        }),
      );
      await selectContainer(state.selectedContainerId);
      setAlert('T-Post inventory event recorded.');
    } catch (error) {
      setAlert(error.message, 'error');
    } finally {
      setBusy(false);
    }
  }

  async function start() {
    configureTheme();
    el('tpost-form')?.addEventListener('submit', saveRow);
    el('tpost-clear')?.addEventListener('click', clearManagerForm);
    el('tpost-inventory-form')?.addEventListener('submit', recordInventory);
    try {
      await loadAccessAndCatalog();
      await loadContainers();
      if (!state.containers.length) setAlert('No T-Post stock Containers are configured.', 'error');
    } catch (error) {
      setAlert(error.message, 'error');
    }
  }

  if (document.readyState === 'loading') document.addEventListener('DOMContentLoaded', start);
  else start();
})();
