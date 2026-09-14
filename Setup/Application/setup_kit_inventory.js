/* Issue #167 — standalone protected Kit Box expected-contents and inventory route. */
(() => {
  const state = {
    access: null,
    kitBoxes: [],
    catalog: [],
    selectedContainerId: null,
    container: null,
    contents: [],
    editingContentId: null,
    inventoryContentId: null,
  };

  const el = (id) => document.getElementById(id);

  function appBasePath() {
    const marker = '/kit-inventory';
    const index = window.location.pathname.indexOf(marker);
    return index >= 0 ? window.location.pathname.slice(0, index + 1) : '/';
  }

  const APP_BASE = appBasePath();
  const KIT_BASE = `${APP_BASE}kit-inventory/`;

  function appUrl(path) {
    return `${APP_BASE}${String(path || '').replace(/^\/+/, '')}`;
  }

  function escapeHtml(value) {
    return String(value ?? '')
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;')
      .replaceAll('"', '&quot;')
      .replaceAll("'", '&#039;');
  }

  async function api(path, options = {}) {
    const response = await fetch(appUrl(path), {
      credentials: 'same-origin',
      headers: { Accept: 'application/json', ...(options.headers || {}) },
      ...options,
    });
    const payload = await response.json().catch(() => ({}));
    if (!response.ok) {
      const error = new Error(payload.error || `Setup API returned HTTP ${response.status}`);
      error.status = response.status;
      error.payload = payload;
      throw error;
    }
    return payload;
  }

  function commandOptions(method, body) {
    return {
      method,
      headers: {
        'Content-Type': 'application/json',
        'X-MSB-Setup-Command': '1',
      },
      body: JSON.stringify(body),
    };
  }

  function setAlert(message, stateName = 'ok') {
    const target = el('inventory-alert');
    target.textContent = message;
    target.dataset.state = stateName;
  }

  function setBusy(flag) {
    document.body.classList.toggle('busy', Boolean(flag));
  }

  function canManage() {
    return Boolean(state.access?.can_manage_setup);
  }

  function canAdjustInventory() {
    const role = String(state.access?.role_name || '');
    const policies = new Set(state.access?.policy_names || []);
    return canManage() || role === 'Production Crew' || policies.has('Production Crew');
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
    if (!Number.isFinite(n)) return String(value);
    return Number.isInteger(n) ? String(n) : String(Number(n.toFixed(3)));
  }

  function formatDate(value) {
    if (!value) return '';
    const date = new Date(value);
    return Number.isNaN(date.getTime()) ? String(value) : date.toLocaleString();
  }

  function specText(row) {
    const parts = [];
    if (row.size_text) parts.push(row.size_text);
    if (row.length_value != null) parts.push(`${formatNumber(row.length_value)} ${row.length_unit || ''}`.trim());
    if (row.color) parts.push(row.color);
    return parts.length ? parts.join(' · ') : '—';
  }

  function routeContainerId() {
    const match = window.location.pathname.match(/\/kit-inventory\/(\d+)\/?$/);
    return match ? Number(match[1]) : null;
  }

  function syncThemeButton() {
    const button = el('theme-toggle');
    const current = document.documentElement.dataset.theme
      || (window.matchMedia('(prefers-color-scheme: dark)').matches ? 'dark' : 'light');
    if (button) button.textContent = current === 'dark' ? 'Light mode' : 'Dark mode';
  }

  function configureTheme() {
    try {
      const saved = localStorage.getItem('msb-theme');
      if (saved === 'light' || saved === 'dark') document.documentElement.dataset.theme = saved;
    } catch (_error) {}
    syncThemeButton();
    el('theme-toggle')?.addEventListener('click', () => {
      const current = document.documentElement.dataset.theme
        || (window.matchMedia('(prefers-color-scheme: dark)').matches ? 'dark' : 'light');
      const next = current === 'dark' ? 'light' : 'dark';
      document.documentElement.dataset.theme = next;
      try { localStorage.setItem('msb-theme', next); } catch (_error) {}
      syncThemeButton();
    });
  }

  function applyAccess() {
    const access = state.access || {};
    el('inventory-access').textContent = `${access.display_name || access.authenticated_email || 'Signed in'} · ${access.role_name || 'No role'}`;
    document.querySelectorAll('.manager-only').forEach((node) => { node.hidden = !canManage(); });
    document.querySelectorAll('.inventory-operator-only').forEach((node) => { node.hidden = !canAdjustInventory(); });
    el('unverified-items').readOnly = !canManage();
  }

  async function loadAccess() {
    const payload = await api('api/setup/access');
    state.access = payload.access || {};
    applyAccess();
  }

  async function loadCatalog() {
    const payload = await api('api/setup/extra-materials');
    state.catalog = payload.extra_materials || [];
    el('expected-item').innerHTML = '<option value="">Select material</option>' + state.catalog.map((item) => (
      `<option value="${item.setup_extra_material_id}">${escapeHtml(item.material_name)}</option>`
    )).join('');
  }

  async function loadKitBoxes() {
    const payload = await api('api/setup/kit-inventory/kit-boxes');
    state.kitBoxes = payload.kit_boxes || [];
    renderKitList();
  }

  function kitMatches(row, query) {
    if (!query) return true;
    const haystack = [
      row.container_id,
      row.container_description,
      row.home_location_code,
      row.assigned_task_names,
      row.has_unverified_items ? 'unverified' : '',
    ].filter((value) => value != null).join(' ').toLocaleLowerCase();
    return haystack.includes(query);
  }

  function renderKitList() {
    const query = String(el('kit-search')?.value || '').trim().toLocaleLowerCase();
    const rows = state.kitBoxes.filter((row) => kitMatches(row, query));
    el('kit-list-status').textContent = query
      ? `${rows.length} of ${state.kitBoxes.length} Kit Boxes`
      : `${state.kitBoxes.length} Kit Boxes`;

    el('kit-list').innerHTML = rows.map((row) => {
      const selected = Number(row.container_id) === Number(state.selectedContainerId);
      const expected = Number(row.expected_item_rows || 0);
      const counted = Number(row.counted_item_rows || 0);
      const uncounted = Number(row.uncounted_item_rows || 0);
      return `
        <button type="button" class="kit-row${selected ? ' selected' : ''}" data-container-id="${row.container_id}">
          <div class="kit-row-title">#${escapeHtml(row.container_id)} · ${escapeHtml(row.container_description || 'Kit Box')}</div>
          <div class="kit-row-meta">${escapeHtml(row.home_location_code || 'Home location not recorded')}</div>
          <div class="kit-row-task">${row.assigned_task_count ? `Setup: ${escapeHtml(row.assigned_task_names || `${row.assigned_task_count} task(s)`)}` : 'No reusable Setup task assignment recorded'}</div>
          <div class="kit-row-flags">
            <span class="pill">${expected} expected item${expected === 1 ? '' : 's'}</span>
            <span class="pill">${counted} counted</span>
            ${uncounted ? `<span class="pill">${uncounted} not counted</span>` : ''}
            ${row.has_unverified_items ? '<span class="pill">Unverified items</span>' : ''}
          </div>
        </button>`;
    }).join('') || '<div class="empty-state">No Kit Boxes match this search.</div>';

    document.querySelectorAll('.kit-row').forEach((button) => {
      button.addEventListener('click', () => selectKit(Number(button.dataset.containerId), { push: true }));
    });
  }

  function selectedKitRow() {
    return state.kitBoxes.find((row) => Number(row.container_id) === Number(state.selectedContainerId)) || null;
  }

  async function selectKit(containerId, { push = false } = {}) {
    const kit = state.kitBoxes.find((row) => Number(row.container_id) === Number(containerId));
    if (!kit) {
      state.selectedContainerId = null;
      state.container = null;
      state.contents = [];
      renderKitList();
      renderDetail();
      setAlert(`Container ${containerId} is not an existing Kit Box.`, 'error');
      return;
    }

    state.selectedContainerId = Number(containerId);
    state.editingContentId = null;
    state.inventoryContentId = null;
    if (push) window.history.pushState({}, '', `${KIT_BASE}${containerId}`);
    renderKitList();
    clearExpectedEditor();
    await loadSelectedKit();
  }

  async function loadSelectedKit() {
    if (!state.selectedContainerId) return;
    setBusy(true);
    try {
      const payload = await api(`api/setup/containers/${state.selectedContainerId}/extra-materials`);
      state.container = payload.container || null;
      state.contents = payload.contents || [];
      renderDetail();
      setAlert(`Loaded Kit Box ${state.selectedContainerId}.`);
    } catch (error) {
      state.container = null;
      state.contents = [];
      renderDetail();
      setAlert(error.message, 'error');
    } finally {
      setBusy(false);
    }
  }

  function renderDetail() {
    const empty = el('kit-empty');
    const detail = el('kit-detail');
    if (!state.container) {
      empty.hidden = false;
      detail.hidden = true;
      return;
    }
    empty.hidden = true;
    detail.hidden = false;

    const kit = selectedKitRow();
    el('kit-title').textContent = `Container ${state.container.container_id} — ${state.container.description || 'Kit Box'}`;
    el('kit-meta').textContent = [state.container.container_type_name, state.container.location_code].filter(Boolean).join(' · ');
    el('kit-assignments').textContent = kit?.assigned_task_count
      ? `Assigned Setup tasks: ${kit.assigned_task_names || kit.assigned_task_count}`
      : 'No reusable Setup task assignment recorded.';
    el('unverified-items').value = state.container.unverified_items_text || '';

    const accessCanManage = canManage();
    const inventoryAllowed = canAdjustInventory();
    el('kit-content-body').innerHTML = state.contents.map((row) => {
      const expected = row.expected_quantity == null ? '<span class="unknown">Unverified</span>' : escapeHtml(formatNumber(row.expected_quantity));
      const onHand = row.on_hand_quantity == null ? '<span class="unknown">Not counted</span>' : escapeHtml(formatNumber(row.on_hand_quantity));
      return `
        <tr>
          <td><strong>${escapeHtml(row.material_name)}</strong></td>
          <td>${expected} ${escapeHtml(row.quantity_uom || '')}</td>
          <td>${escapeHtml(specText(row))}</td>
          <td>${escapeHtml(row.verification_state || 'UNVERIFIED')}</td>
          <td>${onHand} ${escapeHtml(row.quantity_uom || '')}</td>
          <td>${escapeHtml(row.notes || '')}</td>
          <td>
            ${accessCanManage ? `<button type="button" class="small secondary expected-edit" data-content-id="${row.setup_container_extra_material_id}">Edit</button>` : ''}
            ${inventoryAllowed ? `<button type="button" class="small inventory-select" data-content-id="${row.setup_container_extra_material_id}">Count / Adjust</button>` : ''}
          </td>
        </tr>`;
    }).join('') || '<tr><td colspan="7" class="empty-state">No normalized expected contents recorded yet.</td></tr>';

    document.querySelectorAll('.expected-edit').forEach((button) => {
      button.addEventListener('click', () => beginExpectedEdit(Number(button.dataset.contentId)));
    });
    document.querySelectorAll('.inventory-select').forEach((button) => {
      button.addEventListener('click', () => selectInventoryItem(Number(button.dataset.contentId)));
    });
    applyAccess();
  }

  function setIdentityFieldsDisabled(disabled) {
    ['expected-item', 'expected-uom', 'expected-size', 'expected-length', 'expected-length-unit', 'expected-color']
      .forEach((id) => { el(id).disabled = Boolean(disabled); });
  }

  function clearExpectedEditor() {
    state.editingContentId = null;
    setIdentityFieldsDisabled(false);
    el('expected-item').value = '';
    el('expected-qty').value = '';
    el('expected-uom').value = 'EA';
    el('expected-size').value = '';
    el('expected-length').value = '';
    el('expected-length-unit').value = '';
    el('expected-color').value = '';
    el('expected-verification').value = 'UNVERIFIED';
    el('expected-notes').value = '';
    el('expected-save').textContent = 'Add Expected Item';
    el('expected-remove').hidden = true;
  }

  function beginExpectedEdit(contentId) {
    const row = state.contents.find((item) => Number(item.setup_container_extra_material_id) === Number(contentId));
    if (!row || !canManage()) return;
    state.editingContentId = contentId;
    el('expected-item').value = String(row.setup_extra_material_id);
    el('expected-qty').value = row.expected_quantity ?? '';
    el('expected-uom').value = row.quantity_uom || 'EA';
    el('expected-size').value = row.size_text || '';
    el('expected-length').value = row.length_value ?? '';
    el('expected-length-unit').value = row.length_unit || '';
    el('expected-color').value = row.color || '';
    el('expected-verification').value = row.verification_state || 'UNVERIFIED';
    el('expected-notes').value = row.notes || '';
    el('expected-save').textContent = 'Save Expected Item';
    el('expected-remove').hidden = false;
    setIdentityFieldsDisabled(Number(row.inventory_event_count || 0) > 0);
  }

  function expectedPayload(activeFlag = true) {
    return {
      setup_extra_material_id: Number(el('expected-item').value),
      expected_quantity: numberOrNull(el('expected-qty').value),
      quantity_uom: el('expected-uom').value.trim() || 'EA',
      size_text: el('expected-size').value.trim() || null,
      length_value: numberOrNull(el('expected-length').value),
      length_unit: el('expected-length-unit').value || null,
      color: el('expected-color').value.trim() || null,
      verification_state: el('expected-verification').value,
      notes: el('expected-notes').value.trim() || null,
      active_flag: activeFlag,
    };
  }

  async function saveExpected(event) {
    event.preventDefault();
    if (!canManage() || !state.selectedContainerId) return;
    if (!el('expected-item').value) {
      setAlert('Choose an Extra Material.', 'error');
      return;
    }
    const path = state.editingContentId
      ? `api/setup/containers/${state.selectedContainerId}/extra-materials/${state.editingContentId}`
      : `api/setup/containers/${state.selectedContainerId}/extra-materials`;
    const method = state.editingContentId ? 'PATCH' : 'POST';
    setBusy(true);
    try {
      await api(path, commandOptions(method, expectedPayload(true)));
      clearExpectedEditor();
      await loadSelectedKit();
      await loadKitBoxes();
      setAlert('Expected Kit contents saved.');
    } catch (error) {
      setAlert(error.message, 'error');
    } finally {
      setBusy(false);
    }
  }

  async function removeExpected() {
    if (!canManage() || !state.editingContentId) return;
    if (!window.confirm('Remove this item from active expected Kit contents? Durable inventory history is preserved.')) return;
    setBusy(true);
    try {
      await api(
        `api/setup/containers/${state.selectedContainerId}/extra-materials/${state.editingContentId}`,
        commandOptions('PATCH', expectedPayload(false)),
      );
      clearExpectedEditor();
      await loadSelectedKit();
      await loadKitBoxes();
      setAlert('Expected Kit item removed.');
    } catch (error) {
      setAlert(error.message, 'error');
    } finally {
      setBusy(false);
    }
  }

  async function saveUnverified() {
    if (!canManage() || !state.selectedContainerId) return;
    setBusy(true);
    try {
      await api(
        `api/setup/containers/${state.selectedContainerId}/unverified-items`,
        commandOptions('PATCH', { unverified_items_text: el('unverified-items').value.trim() || null }),
      );
      await loadSelectedKit();
      await loadKitBoxes();
      setAlert('Unverified Kit items saved.');
    } catch (error) {
      setAlert(error.message, 'error');
    } finally {
      setBusy(false);
    }
  }

  async function selectInventoryItem(contentId) {
    if (!canAdjustInventory()) return;
    const row = state.contents.find((item) => Number(item.setup_container_extra_material_id) === Number(contentId));
    if (!row) return;
    state.inventoryContentId = contentId;
    el('inventory-selected').textContent = `${row.material_name} · ${specText(row)} · On hand: ${row.on_hand_quantity == null ? 'not counted' : formatNumber(row.on_hand_quantity)}`;
    el('inventory-type').value = Number(row.inventory_event_count || 0) === 0 ? 'INITIAL_COUNT' : 'COUNT_CORRECTION';
    el('inventory-delta').value = '';
    el('inventory-note').value = '';
    await loadInventoryHistory(contentId);
  }

  async function loadInventoryHistory(contentId) {
    try {
      const payload = await api(`api/setup/container-extra-materials/${contentId}/inventory-events`);
      const events = payload.events || [];
      el('inventory-history').innerHTML = events.length
        ? `<h3>Inventory History</h3>${events.map((row) => `
            <div class="history-row">
              <div><strong>${escapeHtml(row.event_type)}</strong><br><span class="muted">${escapeHtml(formatDate(row.occurred_at))}</span></div>
              <div>${escapeHtml(formatNumber(row.quantity_delta))}</div>
              <div>${escapeHtml(row.event_note || '')}${row.actor_display_name ? `<br><span class="muted">${escapeHtml(row.actor_display_name)}</span>` : ''}</div>
            </div>`).join('')}`
        : '<div class="muted">No physical count has been recorded for this item yet.</div>';
    } catch (error) {
      el('inventory-history').innerHTML = `<div class="muted">${escapeHtml(error.message)}</div>`;
    }
  }

  async function recordInventory(event) {
    event.preventDefault();
    if (!canAdjustInventory() || !state.inventoryContentId) {
      setAlert('Select an expected Kit item first.', 'error');
      return;
    }
    const delta = numberOrNull(el('inventory-delta').value);
    if (delta == null || delta === 0) {
      setAlert('Inventory quantity change must be nonzero.', 'error');
      return;
    }
    setBusy(true);
    try {
      await api(
        `api/setup/container-extra-materials/${state.inventoryContentId}/inventory-events`,
        commandOptions('POST', {
          event_type: el('inventory-type').value,
          quantity_delta: delta,
          event_note: el('inventory-note').value.trim() || null,
        }),
      );
      const contentId = state.inventoryContentId;
      await loadSelectedKit();
      await loadKitBoxes();
      await selectInventoryItem(contentId);
      setAlert('Physical inventory change recorded.');
    } catch (error) {
      setAlert(error.message, 'error');
    } finally {
      setBusy(false);
    }
  }

  function bind() {
    configureTheme();
    el('inventory-back-setup').href = APP_BASE;
    el('kit-search')?.addEventListener('input', renderKitList);
    el('expected-form')?.addEventListener('submit', saveExpected);
    el('expected-clear')?.addEventListener('click', clearExpectedEditor);
    el('expected-remove')?.addEventListener('click', removeExpected);
    el('save-unverified')?.addEventListener('click', saveUnverified);
    el('inventory-form')?.addEventListener('submit', recordInventory);
    window.addEventListener('popstate', () => {
      const id = routeContainerId();
      if (id) selectKit(id, { push: false });
      else {
        state.selectedContainerId = null;
        state.container = null;
        renderKitList();
        renderDetail();
      }
    });
  }

  async function initialize() {
    bind();
    setBusy(true);
    try {
      await Promise.all([loadAccess(), loadCatalog(), loadKitBoxes()]);
      const directId = routeContainerId();
      if (directId) await selectKit(directId, { push: false });
      else setAlert('Select a Kit Box to review expected contents or record physical inventory.');
    } catch (error) {
      setAlert(error.message, 'error');
    } finally {
      setBusy(false);
    }
  }

  if (document.readyState === 'loading') document.addEventListener('DOMContentLoaded', initialize);
  else initialize();
})();
