/* Issue #167 — Extra Material / expected Container contents / inventory UI. */
(() => {
  const state = {
    catalog: [],
    containerId: null,
    container: null,
    contents: [],
    editingContentId: null,
    selectedInventoryContentId: null
  };

  const xel = (id) => document.getElementById(id);

  function canAdjustInventory() {
    const access = appState.access || {};
    const role = String(access.role_name || '');
    const policies = new Set(access.policy_names || []);
    return Boolean(access.can_manage_setup) || role === 'Production Crew' || policies.has('Production Crew');
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
    if (!Number.isFinite(n)) return escapeHtml(value);
    return Number.isInteger(n) ? String(n) : String(Number(n.toFixed(3)));
  }

  function specText(row) {
    const parts = [];
    if (row.size_text) parts.push(row.size_text);
    if (row.length_value != null) parts.push(`${formatNumber(row.length_value)} ${row.length_unit || ''}`.trim());
    if (row.color) parts.push(row.color);
    return parts.length ? parts.join(' · ') : '—';
  }

  async function loadCatalog() {
    const payload = await api('api/setup/extra-materials');
    state.catalog = payload.extra_materials || [];
    const options = state.catalog.map((item) => (
      `<option value="${item.setup_extra_material_id}">${escapeHtml(item.material_name)}</option>`
    )).join('');
    xel('extra-material-item').innerHTML = `<option value="">Select material</option>${options}`;
    xel('extra-material-summary-item').innerHTML = `<option value="">All materials</option>${options}`;
  }

  async function loadContainer() {
    const raw = String(xel('extra-material-container-id').value || '').trim();
    if (!/^\d+$/.test(raw)) {
      setAlert('Enter a valid Container ID.', 'error');
      return;
    }
    state.containerId = Number(raw);
    setBusy(true);
    try {
      const payload = await api(`api/setup/containers/${state.containerId}/extra-materials`);
      state.container = payload.container || null;
      state.contents = payload.contents || [];
      state.editingContentId = null;
      state.selectedInventoryContentId = null;
      renderContainer();
      setAlert(`Loaded Container ${state.containerId}.`);
    } catch (error) {
      state.container = null;
      state.contents = [];
      renderContainer();
      setAlert(error.message, 'error');
    } finally {
      setBusy(false);
    }
  }

  function renderContainer() {
    const card = xel('extra-material-container-card');
    if (!state.container) {
      card.hidden = true;
      return;
    }
    card.hidden = false;
    xel('extra-material-container-title').textContent = `Container ${state.container.container_id} — ${state.container.description || 'No description'}`;
    xel('extra-material-container-meta').textContent = [
      state.container.container_type_name,
      state.container.location_code
    ].filter(Boolean).join(' · ');

    const access = appState.access || {};
    xel('extra-material-content-form').hidden = !access.can_manage_setup;
    xel('extra-material-unverified-manager-actions').hidden = !access.can_manage_setup;
    xel('extra-material-inventory-editor').hidden = !canAdjustInventory();
    xel('extra-material-unverified-items').value = state.container.unverified_items_text || '';
    xel('extra-material-unverified-items').readOnly = !access.can_manage_setup;

    xel('extra-material-content-body').innerHTML = state.contents.map((row) => {
      const selected = Number(row.setup_container_extra_material_id) === Number(state.selectedInventoryContentId);
      const onHand = row.on_hand_quantity == null
        ? '<span class="extra-material-unknown">Not counted</span>'
        : escapeHtml(formatNumber(row.on_hand_quantity));
      const expected = row.expected_quantity == null
        ? '<span class="extra-material-unknown">Unverified</span>'
        : escapeHtml(formatNumber(row.expected_quantity));
      return `
        <tr data-content-id="${row.setup_container_extra_material_id}" class="${selected ? 'extra-material-selected-row' : ''}">
          <td><strong>${escapeHtml(row.material_name)}</strong></td>
          <td>${expected} ${escapeHtml(row.quantity_uom || '')}</td>
          <td class="extra-material-spec">${escapeHtml(specText(row))}</td>
          <td>${escapeHtml(row.verification_state || 'UNVERIFIED')}</td>
          <td>${onHand} ${escapeHtml(row.quantity_uom || '')}</td>
          <td>${escapeHtml(row.notes || '')}</td>
          <td>
            ${access.can_manage_setup ? `<button type="button" class="small extra-material-edit" data-content-id="${row.setup_container_extra_material_id}">Edit</button>` : ''}
            ${canAdjustInventory() ? `<button type="button" class="small secondary extra-material-adjust" data-content-id="${row.setup_container_extra_material_id}">Inventory</button>` : ''}
          </td>
        </tr>`;
    }).join('') || '<tr><td colspan="7" class="empty-state">No normalized expected Extra Materials are recorded for this Container yet.</td></tr>';

    document.querySelectorAll('.extra-material-edit').forEach((button) => {
      button.addEventListener('click', () => beginContentEdit(Number(button.dataset.contentId)));
    });
    document.querySelectorAll('.extra-material-adjust').forEach((button) => {
      button.addEventListener('click', () => selectInventoryRow(Number(button.dataset.contentId)));
    });
  }

  function clearContentEditor() {
    state.editingContentId = null;
    xel('extra-material-item').value = '';
    xel('extra-material-qty').value = '';
    xel('extra-material-uom').value = 'EA';
    xel('extra-material-size').value = '';
    xel('extra-material-length').value = '';
    xel('extra-material-length-unit').value = '';
    xel('extra-material-color').value = '';
    xel('extra-material-verification').value = 'UNVERIFIED';
    xel('extra-material-notes').value = '';
    xel('extra-material-save').textContent = 'Add Expected Item';
    xel('extra-material-remove').hidden = true;
  }

  function beginContentEdit(contentId) {
    const row = state.contents.find((item) => Number(item.setup_container_extra_material_id) === Number(contentId));
    if (!row) return;
    state.editingContentId = contentId;
    xel('extra-material-item').value = String(row.setup_extra_material_id);
    xel('extra-material-qty').value = row.expected_quantity ?? '';
    xel('extra-material-uom').value = row.quantity_uom || 'EA';
    xel('extra-material-size').value = row.size_text || '';
    xel('extra-material-length').value = row.length_value ?? '';
    xel('extra-material-length-unit').value = row.length_unit || '';
    xel('extra-material-color').value = row.color || '';
    xel('extra-material-verification').value = row.verification_state || 'UNVERIFIED';
    xel('extra-material-notes').value = row.notes || '';
    xel('extra-material-save').textContent = 'Save Expected Item';
    xel('extra-material-remove').hidden = false;
  }

  function contentPayload(activeFlag = true) {
    return {
      setup_extra_material_id: Number(xel('extra-material-item').value),
      expected_quantity: numberOrNull(xel('extra-material-qty').value),
      quantity_uom: xel('extra-material-uom').value.trim() || 'EA',
      size_text: xel('extra-material-size').value.trim() || null,
      length_value: numberOrNull(xel('extra-material-length').value),
      length_unit: xel('extra-material-length-unit').value || null,
      color: xel('extra-material-color').value.trim() || null,
      verification_state: xel('extra-material-verification').value,
      notes: xel('extra-material-notes').value.trim() || null,
      active_flag: activeFlag
    };
  }

  async function saveContent(event) {
    event.preventDefault();
    if (!state.containerId || !appState.access?.can_manage_setup) return;
    if (!xel('extra-material-item').value) {
      setAlert('Choose an Extra Material.', 'error');
      return;
    }
    const payload = contentPayload(true);
    const path = state.editingContentId
      ? `api/setup/containers/${state.containerId}/extra-materials/${state.editingContentId}`
      : `api/setup/containers/${state.containerId}/extra-materials`;
    const method = state.editingContentId ? 'PATCH' : 'POST';
    setBusy(true);
    try {
      await api(path, commandOptions(method, payload));
      clearContentEditor();
      await loadContainer();
    } catch (error) {
      setAlert(error.message, 'error');
    } finally {
      setBusy(false);
    }
  }

  async function removeContent() {
    if (!state.editingContentId || !appState.access?.can_manage_setup) return;
    if (!confirm('Remove this expected item from the active Container contents? Inventory history remains durable.')) return;
    setBusy(true);
    try {
      await api(
        `api/setup/containers/${state.containerId}/extra-materials/${state.editingContentId}`,
        commandOptions('PATCH', contentPayload(false))
      );
      clearContentEditor();
      await loadContainer();
    } catch (error) {
      setAlert(error.message, 'error');
    } finally {
      setBusy(false);
    }
  }

  async function saveUnverifiedItems() {
    if (!state.containerId || !appState.access?.can_manage_setup) return;
    setBusy(true);
    try {
      await api(
        `api/setup/containers/${state.containerId}/unverified-items`,
        commandOptions('PATCH', {
          unverified_items_text: xel('extra-material-unverified-items').value.trim() || null
        })
      );
      await loadContainer();
      setAlert('Unverified Container notes saved.');
    } catch (error) {
      setAlert(error.message, 'error');
    } finally {
      setBusy(false);
    }
  }

  function selectInventoryRow(contentId) {
    state.selectedInventoryContentId = contentId;
    const row = state.contents.find((item) => Number(item.setup_container_extra_material_id) === Number(contentId));
    xel('extra-material-inventory-selected').textContent = row
      ? `${row.material_name} · ${specText(row)}`
      : '';
    renderContainer();
  }

  async function recordInventory(event) {
    event.preventDefault();
    if (!state.selectedInventoryContentId || !canAdjustInventory()) {
      setAlert('Select a recognized Container item first.', 'error');
      return;
    }
    const delta = numberOrNull(xel('extra-material-inventory-delta').value);
    if (delta == null || delta === 0) {
      setAlert('Inventory quantity change must be nonzero.', 'error');
      return;
    }
    setBusy(true);
    try {
      await api(
        `api/setup/container-extra-materials/${state.selectedInventoryContentId}/inventory-events`,
        commandOptions('POST', {
          event_type: xel('extra-material-inventory-type').value,
          quantity_delta: delta,
          event_note: xel('extra-material-inventory-note').value.trim() || null
        })
      );
      xel('extra-material-inventory-delta').value = '';
      xel('extra-material-inventory-note').value = '';
      await loadContainer();
      setAlert('Inventory adjustment recorded.');
    } catch (error) {
      setAlert(error.message, 'error');
    } finally {
      setBusy(false);
    }
  }

  async function loadSummary() {
    const selectedId = xel('extra-material-summary-item').value;
    const selected = state.catalog.find((item) => String(item.setup_extra_material_id) === String(selectedId));
    const query = selected ? `?material_name=${encodeURIComponent(selected.material_name)}` : '';
    setBusy(true);
    try {
      const payload = await api(`api/setup/extra-materials/balance-summary${query}`);
      const rows = payload.summary || [];
      xel('extra-material-summary-body').innerHTML = rows.map((row) => {
        const availableClass = row.available_after_requirement == null
          ? ''
          : Number(row.available_after_requirement) < 0 ? 'extra-material-negative' : 'extra-material-positive';
        return `
          <tr>
            <td><strong>${escapeHtml(row.material_name)}</strong></td>
            <td>${escapeHtml(specText(row))}</td>
            <td>${row.required_quantity == null ? '—' : escapeHtml(formatNumber(row.required_quantity))}</td>
            <td>${row.on_hand_quantity == null ? '<span class="extra-material-unknown">Not fully counted</span>' : escapeHtml(formatNumber(row.on_hand_quantity))}</td>
            <td class="${availableClass}">${row.available_after_requirement == null ? '—' : escapeHtml(formatNumber(row.available_after_requirement))}</td>
            <td>${escapeHtml(row.uncounted_stock_rows || 0)}</td>
          </tr>`;
      }).join('') || '<tr><td colspan="6" class="empty-state">No requirement or inventory rows match this material.</td></tr>';
    } catch (error) {
      setAlert(error.message, 'error');
    } finally {
      setBusy(false);
    }
  }

  async function ensureReady() {
    if (!state.catalog.length) await loadCatalog();
    const access = appState.access || {};
    xel('extra-material-inventory-editor').hidden = !canAdjustInventory();
    xel('extra-material-content-form').hidden = !access.can_manage_setup;
  }

  function bind() {
    const tab = document.querySelector('[data-view="extra-materials"]');
    if (tab) {
      tab.addEventListener('click', async () => {
        showView('extra-materials');
        try { await ensureReady(); } catch (error) { setAlert(error.message, 'error'); }
      });
    }
    xel('extra-material-load-container')?.addEventListener('click', loadContainer);
    xel('extra-material-container-id')?.addEventListener('keydown', (event) => {
      if (event.key === 'Enter') { event.preventDefault(); loadContainer(); }
    });
    xel('extra-material-content-form')?.addEventListener('submit', saveContent);
    xel('extra-material-clear')?.addEventListener('click', clearContentEditor);
    xel('extra-material-remove')?.addEventListener('click', removeContent);
    xel('extra-material-save-unverified')?.addEventListener('click', saveUnverifiedItems);
    xel('extra-material-inventory-form')?.addEventListener('submit', recordInventory);
    xel('extra-material-load-summary')?.addEventListener('click', loadSummary);
  }

  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', bind);
  } else {
    bind();
  }
})();
