/* Durable reusable-task Extra Material review and Manager maintenance. */
(() => {
  'use strict';

  const state = {
    taskId: null,
    rows: [],
    catalog: [],
    editingRowId: null,
    requestToken: 0,
  };

  const el = (id) => document.getElementById(id);

  function numberOrNull(value) {
    const text = String(value ?? '').trim();
    if (!text) return null;
    const parsed = Number(text);
    return Number.isFinite(parsed) ? parsed : null;
  }

  function specText(row) {
    const parts = [];
    if (row.size_text) parts.push(row.size_text);
    if (row.length_value != null) parts.push(`${row.length_value} ${row.length_unit || ''}`.trim());
    if (row.color) parts.push(row.color);
    return parts.join(' · ') || '—';
  }

  function quantityText(row) {
    const qualifier = row.quantity_qualifier && row.quantity_qualifier !== 'EXACT'
      ? `${row.quantity_qualifier.toLowerCase()} `
      : '';
    if (row.quantity_required == null) return `Unverified ${row.quantity_uom || ''}`.trim();
    return `${qualifier}${row.quantity_required} ${row.quantity_uom || ''}`.trim();
  }

  function sourceText(row) {
    const sources = Array.isArray(row.sources) ? row.sources : [];
    if (!sources.length) return '<span class="extra-material-unknown">No source allocated</span>';
    return sources.map((source) => {
      const qty = source.expected_quantity == null ? '' : ` · ${escapeHtml(source.expected_quantity)}`;
      const verification = source.verification_state ? ` · ${escapeHtml(source.verification_state)}` : '';
      return `<div><strong>Container ${escapeHtml(source.container_id)}</strong>${source.container_description ? ` — ${escapeHtml(source.container_description)}` : ''}${qty}${verification}</div>`;
    }).join('');
  }

  function installSection() {
    if (el('task-extra-material-section')) return;
    const dependencies = el('detail-dependencies')?.closest('.detail-section');
    if (!dependencies) return;

    const section = document.createElement('section');
    section.id = 'task-extra-material-section';
    section.className = 'detail-section';
    section.innerHTML = `
      <div class="section-title">
        <div>
          <h3>Extra Materials Required by This Task</h3>
          <div class="hint">Task requirements are separate from Kit contents and physical stock. For example, a task may require T-Posts supplied from shared T-Post stock rather than from its Kit Box.</div>
        </div>
      </div>
      <div id="task-extra-material-status" class="muted">Select a reusable task.</div>
      <div class="extra-material-table-wrap task-extra-material-table-wrap">
        <table class="extra-material-table task-extra-material-table">
          <thead><tr><th>Item</th><th>Required</th><th>Size / Length / Color</th><th>Verification</th><th>Expected Source</th><th>Notes</th><th></th></tr></thead>
          <tbody id="task-extra-material-body"><tr><td colspan="7" class="empty-state">Select a reusable task.</td></tr></tbody>
        </table>
      </div>
      <form id="task-extra-material-form" class="extra-material-editor manager-only" hidden>
        <h3>Manager — Task Extra Material Requirement</h3>
        <div class="extra-material-form-grid">
          <label>Item<select id="task-extra-material-item" required></select></label>
          <label>Required Qty<input id="task-extra-material-qty" type="number" min="0.001" step="0.001"></label>
          <label>UOM<input id="task-extra-material-uom" type="text" value="EA"></label>
          <label>Size<input id="task-extra-material-size" type="text"></label>
          <label>Length<input id="task-extra-material-length" type="number" min="0.001" step="0.001"></label>
          <label>Length unit<select id="task-extra-material-length-unit"><option value="">—</option><option value="IN">in</option><option value="FT">ft</option><option value="MM">mm</option><option value="CM">cm</option><option value="M">m</option></select></label>
          <label>Color<input id="task-extra-material-color" type="text"></label>
          <label>Quantity qualifier<select id="task-extra-material-qualifier"><option value="EXACT">Exact</option><option value="MINIMUM">Minimum</option><option value="CONDITIONAL">Conditional</option><option value="SPARE">Spare</option></select></label>
          <label>Verification<select id="task-extra-material-verification"><option value="UNVERIFIED">Unverified</option><option value="NEEDS_REVIEW">Needs review</option><option value="VERIFIED">Verified</option></select></label>
          <label class="wide">Notes<input id="task-extra-material-notes" type="text"></label>
        </div>
        <div class="action-row">
          <button id="task-extra-material-save" type="submit">Add Requirement</button>
          <button id="task-extra-material-clear" type="button" class="secondary">Clear</button>
          <button id="task-extra-material-remove" type="button" class="warning" hidden>Remove Requirement</button>
        </div>
        <div class="hint">Expected source Containers are displayed above and remain independent of the reusable task requirement.</div>
      </form>`;
    dependencies.insertAdjacentElement('afterend', section);
  }

  async function ensureCatalog() {
    if (state.catalog.length) return;
    const payload = await api('api/setup/extra-materials');
    state.catalog = payload.extra_materials || [];
    const select = el('task-extra-material-item');
    if (select) {
      select.innerHTML = '<option value="">Select material</option>' + state.catalog.map((row) =>
        `<option value="${row.setup_extra_material_id}" data-uom="${escapeHtml(row.default_uom || 'EA')}">${escapeHtml(row.material_name)}</option>`
      ).join('');
    }
  }

  function clearEditor() {
    state.editingRowId = null;
    const values = {
      'task-extra-material-item': '',
      'task-extra-material-qty': '',
      'task-extra-material-uom': 'EA',
      'task-extra-material-size': '',
      'task-extra-material-length': '',
      'task-extra-material-length-unit': '',
      'task-extra-material-color': '',
      'task-extra-material-qualifier': 'EXACT',
      'task-extra-material-verification': 'UNVERIFIED',
      'task-extra-material-notes': '',
    };
    Object.entries(values).forEach(([id, value]) => { if (el(id)) el(id).value = value; });
    if (el('task-extra-material-save')) el('task-extra-material-save').textContent = 'Add Requirement';
    if (el('task-extra-material-remove')) el('task-extra-material-remove').hidden = true;
  }

  function editRequirement(rowId) {
    const row = state.rows.find((item) => Number(item.setup_task_extra_material_id) === Number(rowId));
    if (!row || !appState.access?.can_manage_setup) return;
    state.editingRowId = Number(rowId);
    el('task-extra-material-item').value = String(row.setup_extra_material_id);
    el('task-extra-material-qty').value = row.quantity_required ?? '';
    el('task-extra-material-uom').value = row.quantity_uom || 'EA';
    el('task-extra-material-size').value = row.size_text || '';
    el('task-extra-material-length').value = row.length_value ?? '';
    el('task-extra-material-length-unit').value = row.length_unit || '';
    el('task-extra-material-color').value = row.color || '';
    el('task-extra-material-qualifier').value = row.quantity_qualifier || 'EXACT';
    el('task-extra-material-verification').value = row.verification_state || 'UNVERIFIED';
    el('task-extra-material-notes').value = row.notes || '';
    el('task-extra-material-save').textContent = 'Save Requirement';
    el('task-extra-material-remove').hidden = false;
    el('task-extra-material-form').scrollIntoView({ behavior: 'smooth', block: 'start' });
    window.setTimeout(() => el('task-extra-material-qty')?.focus({ preventScroll: true }), 180);
  }

  function renderRows() {
    const body = el('task-extra-material-body');
    if (!body) return;
    body.innerHTML = state.rows.map((row) => `
      <tr>
        <td><strong>${escapeHtml(row.material_name)}</strong></td>
        <td>${escapeHtml(quantityText(row))}</td>
        <td>${escapeHtml(specText(row))}</td>
        <td>${escapeHtml(row.verification_state || 'UNVERIFIED')}</td>
        <td>${sourceText(row)}</td>
        <td>${escapeHtml(row.notes || '')}</td>
        <td>${appState.access?.can_manage_setup ? `<button type="button" class="small secondary task-extra-material-edit" data-row-id="${row.setup_task_extra_material_id}">Edit</button>` : ''}</td>
      </tr>`).join('') || '<tr><td colspan="7" class="empty-state">No Extra Material requirements recorded for this reusable task.</td></tr>';
    el('task-extra-material-status').textContent = `${state.rows.length} active requirement${state.rows.length === 1 ? '' : 's'}`;
    el('task-extra-material-form').hidden = !appState.access?.can_manage_setup;
    applyAccess();
  }

  async function loadTaskMaterials(taskId) {
    installSection();
    state.taskId = Number(taskId);
    state.editingRowId = null;
    clearEditor();
    const token = ++state.requestToken;
    el('task-extra-material-status').textContent = 'Loading Extra Material requirements…';
    try {
      await ensureCatalog();
      const payload = await api(`api/setup/tasks/${taskId}/extra-materials`);
      if (token !== state.requestToken || Number(taskId) !== Number(state.taskId)) return;
      state.rows = payload.extra_materials || [];
      renderRows();
    } catch (error) {
      if (token !== state.requestToken) return;
      state.rows = [];
      el('task-extra-material-body').innerHTML = `<tr><td colspan="7" class="empty-state">${escapeHtml(error.message)}</td></tr>`;
      el('task-extra-material-status').textContent = 'Extra Material requirements could not be loaded.';
    }
  }

  function payload(activeFlag = true) {
    return {
      setup_extra_material_id: Number(el('task-extra-material-item').value),
      quantity_required: numberOrNull(el('task-extra-material-qty').value),
      quantity_uom: el('task-extra-material-uom').value.trim() || 'EA',
      size_text: el('task-extra-material-size').value.trim() || null,
      length_value: numberOrNull(el('task-extra-material-length').value),
      length_unit: el('task-extra-material-length-unit').value || null,
      color: el('task-extra-material-color').value.trim() || null,
      quantity_qualifier: el('task-extra-material-qualifier').value,
      verification_state: el('task-extra-material-verification').value,
      notes: el('task-extra-material-notes').value.trim() || null,
      active_flag: activeFlag,
    };
  }

  async function saveRequirement(event) {
    event.preventDefault();
    if (!appState.access?.can_manage_setup || !state.taskId) return;
    if (!el('task-extra-material-item').value) {
      setAlert('Choose an Extra Material for this task.', 'error');
      return;
    }
    const path = state.editingRowId
      ? `api/setup/tasks/${state.taskId}/extra-materials/${state.editingRowId}`
      : `api/setup/tasks/${state.taskId}/extra-materials`;
    const method = state.editingRowId ? 'PATCH' : 'POST';
    try {
      await api(path, commandOptions(method, payload(true)));
      clearEditor();
      await loadTaskMaterials(state.taskId);
      setAlert('Task Extra Material requirement saved.');
    } catch (error) {
      setAlert(error.message, 'error');
    }
  }

  async function removeRequirement() {
    if (!appState.access?.can_manage_setup || !state.taskId || !state.editingRowId) return;
    if (!window.confirm('Remove this Extra Material requirement from the reusable task?')) return;
    try {
      await api(
        `api/setup/tasks/${state.taskId}/extra-materials/${state.editingRowId}`,
        commandOptions('PATCH', payload(false)),
      );
      clearEditor();
      await loadTaskMaterials(state.taskId);
      setAlert('Task Extra Material requirement removed.');
    } catch (error) {
      setAlert(error.message, 'error');
    }
  }

  function bind() {
    installSection();
    const originalSelectTask = selectTask;
    selectTask = function selectTaskWithExtraMaterials(taskId) {
      const result = originalSelectTask(taskId);
      loadTaskMaterials(taskId);
      return result;
    };

    el('task-extra-material-form')?.addEventListener('submit', saveRequirement);
    el('task-extra-material-clear')?.addEventListener('click', clearEditor);
    el('task-extra-material-remove')?.addEventListener('click', removeRequirement);
    el('task-extra-material-item')?.addEventListener('change', () => {
      const option = el('task-extra-material-item').selectedOptions[0];
      if (option?.dataset.uom && !state.editingRowId) el('task-extra-material-uom').value = option.dataset.uom;
    });
    el('task-extra-material-section')?.addEventListener('click', (event) => {
      const button = event.target.closest('.task-extra-material-edit');
      if (button) editRequirement(Number(button.dataset.rowId));
    });

    if (appState.selectedTaskId) loadTaskMaterials(appState.selectedTaskId);
  }

  if (document.readyState === 'loading') document.addEventListener('DOMContentLoaded', bind);
  else bind();
})();
