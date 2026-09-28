/* Durable reusable-task Extra Material review and Manager maintenance. */
(() => {
  'use strict';

  const state = {
    taskId: null,
    rows: [],
    catalog: [],
    containers: [],
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

  function displayNumber(value) {
    if (value == null || String(value).trim() === '') return '';
    const parsed = Number(value);
    return Number.isFinite(parsed) ? String(parsed) : String(value);
  }

  function specText(row) {
    const parts = [];
    if (row.size_text) parts.push(row.size_text);
    if (row.length_value != null) parts.push(`${displayNumber(row.length_value)} ${row.length_unit || ''}`.trim());
    if (row.color) parts.push(row.color);
    return parts.join(' · ') || '—';
  }

  function quantityText(row) {
    const qualifier = row.quantity_qualifier && row.quantity_qualifier !== 'EXACT'
      ? `${row.quantity_qualifier.toLowerCase()} `
      : '';
    if (row.quantity_required == null) return `Unverified ${row.quantity_uom || ''}`.trim();
    return `${qualifier}${displayNumber(row.quantity_required)} ${row.quantity_uom || ''}`.trim();
  }

  function sourceText(row) {
    const sources = Array.isArray(row.sources) ? row.sources : [];
    if (!sources.length) {
      return '<div class="task-extra-material-source-summary"><span class="extra-material-negative">NO SOURCE</span><span class="muted">Expected Source Container not assigned.</span></div>';
    }
    return `<div class="task-extra-material-source-summary">
      ${sources.map((source) => {
        const quantity = source.expected_quantity == null ? '' : ` · Qty ${displayNumber(source.expected_quantity)}`;
        const verification = String(source.verification_state || 'UNVERIFIED').replaceAll('_', ' ');
        return `<div><strong>C${escapeHtml(source.container_id)} — ${escapeHtml(source.container_description || 'Container')}</strong><span class="muted">${escapeHtml(quantity)} · ${escapeHtml(verification)}</span></div>`;
      }).join('')}
    </div>`;
  }

  function sourceAction(row) {
    if (!appState.access?.can_manage_setup) return '';
    const sources = Array.isArray(row.sources) ? row.sources : [];
    return `<button type="button" class="small secondary task-extra-material-source-inline" data-row-id="${row.setup_task_extra_material_id}">${sources.length ? 'Review Sources' : 'Add Source'}</button>`;
  }

  function openInlineSource(rowId) {
    if (!appState.access?.can_manage_setup) return;
    if (typeof window.openTaskExtraMaterialSource !== 'function') {
      setAlert('Expected Source Containers editor is still loading. Try again.', 'error');
      return;
    }
    window.openTaskExtraMaterialSource(Number(rowId));
  }

  function openPendingRequirementCorrection() {
    if (typeof consumePendingCorrection !== 'function') return;
    if (!consumePendingCorrection('extra-material-requirement')) return;

    const requirementId = Number(appState.pendingExtraMaterialRequirementId || 0);
    appState.pendingExtraMaterialRequirementId = null;
    if (!requirementId) {
      setAlert('Extra Material requirement review did not include a requirement identity.', 'error');
      return;
    }
    const row = state.rows.find(
      (item) => Number(item.setup_task_extra_material_id) === requirementId,
    );
    if (!row) {
      setAlert(`Extra Material requirement ${requirementId} is not active on this reusable task.`, 'error');
      return;
    }
    editRequirement(requirementId);
  }

  function installSection() {
    if (el('task-extra-material-section')) return;
    const dependencies = el('detail-dependencies')?.closest('.detail-section');
    if (!dependencies) return;

    const section = document.createElement('section');
    section.id = 'task-extra-material-section';
    section.className = 'detail-section';
    section.innerHTML = `
      <div class="section-title compact">
        <div>
          <h3>Extra Materials Required by This Task</h3>
          <div class="hint">Record what the task requires, then maintain its Expected Source Container from the same requirement row. Container expected contents and physical inventory remain separate facts.</div>
        </div>
        <button id="task-extra-material-add" type="button" class="small manager-only" hidden>Add Requirement</button>
      </div>
      <div id="task-extra-material-status" class="muted">Select a reusable task.</div>
      <div class="extra-material-table-wrap task-extra-material-table-wrap">
        <table class="extra-material-table task-extra-material-table">
          <thead><tr><th>Item</th><th>Required</th><th>Size / Length / Color</th><th>Verification</th><th>Sources</th><th>Notes</th><th></th></tr></thead>
          <tbody id="task-extra-material-body"><tr><td colspan="7" class="empty-state">Select a reusable task.</td></tr></tbody>
        </table>
      </div>
      <form id="task-extra-material-form" class="extra-material-editor manager-only" hidden>
        <h3 id="task-extra-material-editor-title">Manager — Add Task Requirement</h3>
        <div class="hint">New requirements require a physical source Container. One save creates the reusable requirement, its Expected Source link, and matching Container expected-content authority. Existing requirements can be edited independently.</div>
        <div class="extra-material-form-grid">
          <label>Item<select id="task-extra-material-item" required></select></label>
          <label>Required Qty<input id="task-extra-material-qty" type="number" min="0.001" step="any"></label>
          <label>UOM<input id="task-extra-material-uom" type="text" value="EA"></label>
          <label>Size<input id="task-extra-material-size" type="text"></label>
          <label>Length<input id="task-extra-material-length" type="number" min="0.001" step="any"></label>
          <label>Length unit<select id="task-extra-material-length-unit"><option value="">—</option><option value="IN">in</option><option value="FT">ft</option><option value="MM">mm</option><option value="CM">cm</option><option value="M">m</option></select></label>
          <label>Color<input id="task-extra-material-color" type="text"></label>
          <label>Quantity qualifier<select id="task-extra-material-qualifier"><option value="EXACT">Exact</option><option value="MINIMUM">Minimum</option><option value="CONDITIONAL">Conditional</option><option value="SPARE">Spare</option></select></label>
          <label>Verification<select id="task-extra-material-verification"><option value="UNVERIFIED">Unverified</option><option value="NEEDS_REVIEW">Needs review</option><option value="VERIFIED">Verified</option></select></label>
          <label class="wide">Notes<input id="task-extra-material-notes" type="text"></label>
        </div>
        <div id="task-extra-material-create-source-fields">
          <h4>Required source for this new requirement</h4>
          <div class="hint">Choose where the crew should expect to get this material. This also ensures the same material/spec is represented in that Container's expected contents.</div>
          <div class="extra-material-form-grid">
            <label class="wide">Source Container
              <select id="task-extra-material-create-source-container" required>
                <option value="">Select source Container</option>
              </select>
            </label>
            <label>Qty from this Container<input id="task-extra-material-create-source-qty" type="number" min="0.001" step="any"></label>
            <label>Source verification
              <select id="task-extra-material-create-source-verification">
                <option value="UNVERIFIED">Unverified</option>
                <option value="NEEDS_REVIEW">Needs review</option>
                <option value="VERIFIED">Verified</option>
              </select>
            </label>
            <label class="wide">Source notes<input id="task-extra-material-create-source-notes" type="text"></label>
          </div>
        </div>
        <div class="action-row">
          <button id="task-extra-material-save" type="submit">Add Requirement</button>
          <button id="task-extra-material-clear" type="button" class="secondary">Cancel</button>
          <button id="task-extra-material-remove" type="button" class="danger" hidden>Delete Mistake</button>
        </div>
      </form>`;
    dependencies.insertAdjacentElement('afterend', section);
  }

  async function ensureCatalog() {
    if (state.catalog.length && state.containers.length) return;
    const [materialPayload, containerPayload] = await Promise.all([
      api('api/setup/extra-materials'),
      api('api/setup/containers/source-options'),
    ]);
    state.catalog = materialPayload.extra_materials || [];
    state.containers = containerPayload.containers || [];

    const select = el('task-extra-material-item');
    if (select) {
      select.innerHTML = '<option value="">Select material</option>' + state.catalog.map((row) =>
        `<option value="${row.setup_extra_material_id}" data-uom="${escapeHtml(row.default_uom || 'EA')}">${escapeHtml(row.material_name)}</option>`
      ).join('');
    }

    const sourceSelect = el('task-extra-material-create-source-container');
    if (sourceSelect) {
      const rows = [...state.containers].sort((a, b) => {
        const left = String(a.container_description || '').toLowerCase();
        const right = String(b.container_description || '').toLowerCase();
        return left.localeCompare(right, undefined, { numeric: true })
          || Number(a.container_id || 0) - Number(b.container_id || 0);
      });
      sourceSelect.innerHTML = '<option value="">Select source Container</option>' + rows.map((row) => {
        const home = row.home_location_code ? ` · Home ${escapeHtml(row.home_location_code)}` : '';
        return `<option value="${row.container_id}">C${row.container_id} — ${escapeHtml(row.container_description || 'Container')}${home}</option>`;
      }).join('');
    }
  }

  function clearEditor({ hide = true } = {}) {
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
      'task-extra-material-create-source-container': '',
      'task-extra-material-create-source-qty': '',
      'task-extra-material-create-source-verification': 'UNVERIFIED',
      'task-extra-material-create-source-notes': '',
    };
    Object.entries(values).forEach(([id, value]) => { if (el(id)) el(id).value = value; });
    if (el('task-extra-material-item')) el('task-extra-material-item').disabled = false;
    if (el('task-extra-material-create-source-fields')) el('task-extra-material-create-source-fields').hidden = false;
    if (el('task-extra-material-create-source-container')) el('task-extra-material-create-source-container').required = true;
    if (el('task-extra-material-editor-title')) el('task-extra-material-editor-title').textContent = 'Manager — Add Task Requirement';
    if (el('task-extra-material-save')) el('task-extra-material-save').textContent = 'Add Requirement';
    if (el('task-extra-material-remove')) el('task-extra-material-remove').hidden = true;
    if (hide && el('task-extra-material-form')) el('task-extra-material-form').hidden = true;
  }

  function addRequirement() {
    if (!appState.access?.can_manage_setup) return;
    clearEditor({ hide: false });
    el('task-extra-material-form').hidden = false;
    el('task-extra-material-form').scrollIntoView({ behavior: 'smooth', block: 'start' });
    window.setTimeout(() => el('task-extra-material-item')?.focus({ preventScroll: true }), 180);
  }

  function editRequirement(rowId) {
    const row = state.rows.find((item) => Number(item.setup_task_extra_material_id) === Number(rowId));
    if (!row || !appState.access?.can_manage_setup) return;
    state.editingRowId = Number(rowId);
    if (el('task-extra-material-create-source-fields')) el('task-extra-material-create-source-fields').hidden = true;
    if (el('task-extra-material-create-source-container')) el('task-extra-material-create-source-container').required = false;
    el('task-extra-material-item').value = String(row.setup_extra_material_id);
    el('task-extra-material-item').disabled = true;
    el('task-extra-material-qty').value = displayNumber(row.quantity_required);
    el('task-extra-material-uom').value = row.quantity_uom || 'EA';
    el('task-extra-material-size').value = row.size_text || '';
    el('task-extra-material-length').value = displayNumber(row.length_value);
    el('task-extra-material-length-unit').value = row.length_unit || '';
    el('task-extra-material-color').value = row.color || '';
    el('task-extra-material-qualifier').value = row.quantity_qualifier || 'EXACT';
    el('task-extra-material-verification').value = row.verification_state || 'UNVERIFIED';
    el('task-extra-material-notes').value = row.notes || '';
    el('task-extra-material-editor-title').textContent = 'Manager — Edit Task Requirement';
    el('task-extra-material-save').textContent = 'Save Requirement';
    el('task-extra-material-remove').hidden = false;
    el('task-extra-material-form').hidden = false;
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
        <td>${sourceText(row)}${sourceAction(row)}</td>
        <td>${escapeHtml(row.notes || '')}</td>
        <td>${appState.access?.can_manage_setup ? `<div class="action-stack"><button type="button" class="small secondary task-extra-material-edit" data-row-id="${row.setup_task_extra_material_id}">Edit Requirement</button><button type="button" class="small danger task-extra-material-delete-mistake" data-row-id="${row.setup_task_extra_material_id}" data-material-name="${escapeHtml(row.material_name)}">Delete Mistake</button></div>` : ''}</td>
      </tr>`).join('') || '<tr><td colspan="7" class="empty-state">No Extra Material requirements recorded for this reusable task.</td></tr>';
    el('task-extra-material-status').textContent = `${state.rows.length} active requirement${state.rows.length === 1 ? '' : 's'}`;
    if (el('task-extra-material-add')) el('task-extra-material-add').hidden = !appState.access?.can_manage_setup;
    applyAccess();
  }

  async function loadTaskMaterials(taskId) {
    installSection();
    state.taskId = Number(taskId);
    clearEditor();
    const token = ++state.requestToken;
    el('task-extra-material-status').textContent = 'Loading Extra Material requirements…';
    try {
      await ensureCatalog();
      const payload = await api(`api/setup/tasks/${taskId}/extra-materials`);
      if (token !== state.requestToken || Number(taskId) !== Number(state.taskId)) return;
      state.rows = payload.extra_materials || [];
      renderRows();
      openPendingRequirementCorrection();
    } catch (error) {
      if (token !== state.requestToken) return;
      state.rows = [];
      el('task-extra-material-body').innerHTML = `<tr><td colspan="7" class="empty-state">${escapeHtml(error.message)}</td></tr>`;
      el('task-extra-material-status').textContent = 'Extra Material requirements could not be loaded.';
    }
  }

  function payload(activeFlag = true) {
    const result = {
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
    if (!state.editingRowId) {
      result.source = {
        container_id: Number(el('task-extra-material-create-source-container')?.value || 0),
        expected_quantity: numberOrNull(el('task-extra-material-create-source-qty')?.value),
        verification_state: el('task-extra-material-create-source-verification')?.value || 'UNVERIFIED',
        notes: el('task-extra-material-create-source-notes')?.value.trim() || null,
      };
    }
    return result;
  }

  async function saveRequirement(event) {
    event.preventDefault();
    if (!appState.access?.can_manage_setup || !state.taskId) return;
    if (!el('task-extra-material-item').value) {
      setAlert('Choose an Extra Material for this task.', 'error');
      return;
    }
    if (!state.editingRowId && !el('task-extra-material-create-source-container')?.value) {
      setAlert('Choose the source Container. New Extra Material requirements cannot be created without physical source authority.', 'error');
      return;
    }
    const path = state.editingRowId
      ? `api/setup/tasks/${state.taskId}/extra-materials/${state.editingRowId}`
      : `api/setup/tasks/${state.taskId}/extra-materials`;
    const method = state.editingRowId ? 'PATCH' : 'POST';
    const priorRowId = state.editingRowId;
    try {
      const result = await api(path, commandOptions(method, payload(true)));
      const taskId = state.taskId;
      clearEditor();
      await loadTaskMaterials(taskId);
      if (priorRowId) {
        setAlert('Task Extra Material requirement saved.');
      } else {
        const source = result.setup_task_extra_material_source;
        const contentCreated = Boolean(result.container_content_created);
        setAlert(
          `Extra Material requirement saved with source C${source?.container_id || '?'}.${contentCreated ? ' Matching Container expected contents were created.' : ' Existing matching Container expected contents were reused.'}`
        );
      }
    } catch (error) {
      setAlert(error.message, 'error');
    }
  }

  async function deleteRequirement(rowId, materialName = 'this Extra Material') {
    if (!appState.access?.can_manage_setup || !state.taskId || !rowId) return;
    const confirmed = window.confirm(
      `DELETE MISTAKE: permanently remove ${materialName} from this reusable task? Any task-source links attached to this mistaken requirement are deleted with it. This does not delete the Extra Material catalog item, Container expected contents, Displays, or inventory history.`,
    );
    if (!confirmed) return;
    try {
      const result = await api(
        `api/setup/tasks/${state.taskId}/extra-materials/${rowId}`,
        commandOptions('DELETE', {}),
      );
      const deletedSources = Number(result.deleted?.deleted_source_count || 0);
      const taskId = state.taskId;
      clearEditor();
      await loadTaskMaterials(taskId);
      setAlert(
        `Mistaken Extra Material requirement deleted${deletedSources ? ` with ${deletedSources} task-source link${deletedSources === 1 ? '' : 's'}` : ''}.`,
      );
    } catch (error) {
      setAlert(error.message, 'error');
    }
  }

  async function removeRequirement() {
    if (!state.editingRowId) return;
    const row = state.rows.find(
      (item) => Number(item.setup_task_extra_material_id) === Number(state.editingRowId),
    );
    await deleteRequirement(state.editingRowId, row?.material_name || 'this Extra Material');
  }

  function bind() {
    installSection();
    const originalSelectTask = selectTask;
    selectTask = function selectTaskWithExtraMaterials(taskId) {
      const result = originalSelectTask(taskId);
      loadTaskMaterials(taskId);
      return result;
    };

    el('task-extra-material-add')?.addEventListener('click', addRequirement);
    el('task-extra-material-form')?.addEventListener('submit', saveRequirement);
    el('task-extra-material-clear')?.addEventListener('click', () => clearEditor());
    el('task-extra-material-remove')?.addEventListener('click', removeRequirement);
    el('task-extra-material-item')?.addEventListener('change', () => {
      const option = el('task-extra-material-item').selectedOptions[0];
      if (option?.dataset.uom && !state.editingRowId) el('task-extra-material-uom').value = option.dataset.uom;
    });
    el('task-extra-material-qty')?.addEventListener('input', () => {
      if (state.editingRowId) return;
      const sourceQty = el('task-extra-material-create-source-qty');
      if (sourceQty && !sourceQty.value) sourceQty.value = el('task-extra-material-qty').value;
    });
    el('task-extra-material-section')?.addEventListener('click', (event) => {
      const sourceButton = event.target.closest('.task-extra-material-source-inline');
      if (sourceButton) {
        openInlineSource(Number(sourceButton.dataset.rowId));
        return;
      }
      const deleteButton = event.target.closest('.task-extra-material-delete-mistake');
      if (deleteButton) {
        void deleteRequirement(
          Number(deleteButton.dataset.rowId),
          deleteButton.dataset.materialName || 'this Extra Material',
        );
        return;
      }
      const button = event.target.closest('.task-extra-material-edit');
      if (button) editRequirement(Number(button.dataset.rowId));
    });

    window.refreshTaskExtraMaterials = loadTaskMaterials;
    window.editTaskExtraMaterialRequirement = editRequirement;
    if (appState.selectedTaskId) loadTaskMaterials(appState.selectedTaskId);
  }

  if (document.readyState === 'loading') document.addEventListener('DOMContentLoaded', bind);
  else bind();
})();
