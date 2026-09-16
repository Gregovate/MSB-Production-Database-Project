/* Issue #198 — Manager maintenance for task Extra Material expected source Containers. */
(() => {
  'use strict';

  const state = {
    taskId: null,
    requirements: [],
    containers: [],
    resolvedContainerIds: new Set(),
    selectedRequirementId: null,
    editingSourceId: null,
    originalSourceContainerId: null,
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

  function sameQuantity(left, right) {
    if (left == null && right == null) return true;
    if (left == null || right == null) return false;
    return Number(left) === Number(right);
  }

  function requirementById(requirementId) {
    return state.requirements.find(
      (row) => Number(row.setup_task_extra_material_id) === Number(requirementId),
    ) || null;
  }

  function sourceById(requirementId, sourceId) {
    const requirement = requirementById(requirementId);
    return (requirement?.sources || []).find(
      (row) => Number(row.setup_task_extra_material_source_id) === Number(sourceId),
    ) || null;
  }

  function containerById(containerId) {
    return state.containers.find((row) => Number(row.container_id) === Number(containerId)) || null;
  }

  function requirementLabel(row) {
    const parts = [row.material_name || 'Extra Material'];
    if (row.quantity_required != null) parts.push(`${displayNumber(row.quantity_required)} ${row.quantity_uom || ''}`.trim());
    const spec = [];
    if (row.size_text) spec.push(row.size_text);
    if (row.length_value != null) spec.push(`${displayNumber(row.length_value)} ${row.length_unit || ''}`.trim());
    if (row.color) spec.push(row.color);
    if (spec.length) parts.push(spec.join(' · '));
    return parts.join(' — ');
  }

  function containerTypeLabel(row) {
    if (!row) return 'Container';
    if (row.display_pallet) return 'Display Pallet';
    if (Number(row.container_type_id) === 2) return 'Kit Box';
    return 'Container';
  }

  function containerLabel(row) {
    const type = containerTypeLabel(row);
    const home = row.home_location_code ? ` · ${row.home_location_code}` : '';
    const resolved = state.resolvedContainerIds.has(Number(row.container_id)) ? ' · TASK' : '';
    return `C${row.container_id} — ${row.container_description || 'No description'} · ${type}${home}${resolved}`;
  }

  function allocationAudit(requirement) {
    const sources = Array.isArray(requirement.sources) ? requirement.sources : [];
    const required = requirement.quantity_required == null ? null : Number(requirement.quantity_required);
    const known = sources.filter((source) => source.expected_quantity != null);
    const missingCount = sources.length - known.length;
    const knownTotal = known.reduce((sum, source) => sum + Number(source.expected_quantity), 0);
    const allVerified = sources.length > 0 && sources.every(
      (source) => String(source.verification_state || '').toUpperCase() === 'VERIFIED' && source.expected_quantity != null,
    );
    const uom = requirement.quantity_uom || '';

    if (required == null) {
      return {
        className: 'review',
        text: sources.length ? `Source total ${displayNumber(knownTotal)} ${uom} · task requirement quantity missing` : 'Task requirement quantity missing',
      };
    }
    if (!sources.length) {
      return { className: 'review', text: `Required ${displayNumber(required)} ${uom} · no source allocation` };
    }
    if (missingCount > 0) {
      return {
        className: 'review',
        text: `Allocated ${displayNumber(knownTotal)} of ${displayNumber(required)} ${uom} · ${missingCount} source ${missingCount === 1 ? 'quantity' : 'quantities'} missing`,
      };
    }

    const delta = knownTotal - required;
    if (Math.abs(delta) < 1e-9) {
      return { className: 'ok', text: `Allocated ${displayNumber(knownTotal)} of ${displayNumber(required)} ${uom} · BALANCED` };
    }

    const direction = delta > 0 ? '+' : '-';
    const magnitude = displayNumber(Math.abs(delta));
    return {
      className: 'mismatch',
      text: allVerified
        ? `Verified sources total ${displayNumber(knownTotal)}; task requires ${displayNumber(required)} ${uom} · REVIEW TASK REQUIREMENT (${direction}${magnitude})`
        : `Allocated ${displayNumber(knownTotal)} of ${displayNumber(required)} ${uom} · MISMATCH ${direction}${magnitude}`,
    };
  }

  function installSection() {
    if (el('task-extra-material-source-section')) return;
    const requirements = el('task-extra-material-section');
    if (!requirements) return;

    const section = document.createElement('section');
    section.id = 'task-extra-material-source-section';
    section.className = 'detail-section';
    section.innerHTML = `
      <div class="section-title compact">
        <div>
          <h3>Expected Source Containers</h3>
          <div class="hint">Assign and reconcile where this requirement comes from.</div>
        </div>
      </div>
      <div id="task-extra-material-source-status" class="muted">Select a reusable task.</div>
      <div id="task-extra-material-source-body"></div>
      <form id="task-extra-material-source-form" class="extra-material-editor manager-only" hidden>
        <h3 id="task-extra-material-source-editor-title">Manager — Add Source</h3>
        <div id="task-extra-material-source-selected" class="selected-item"></div>
        <div id="task-extra-material-source-editor-help" class="hint">Select a Container and enter the quantity from that Container.</div>
        <div class="extra-material-form-grid">
          <label class="wide">Find Container<input id="task-extra-material-source-search" type="search" placeholder="ID, description, type, or location" autocomplete="off"></label>
          <label class="wide">Source Container<select id="task-extra-material-source-container" size="6" required></select></label>
          <label>Qty from this Container<input id="task-extra-material-source-qty" type="number" min="0.001" step="any"></label>
          <label>Verification<select id="task-extra-material-source-verification"><option value="UNVERIFIED">Unverified</option><option value="NEEDS_REVIEW">Needs review</option><option value="VERIFIED">Verified</option></select></label>
          <label class="wide">Source notes<input id="task-extra-material-source-notes" type="text"></label>
        </div>
        <div class="action-row">
          <button id="task-extra-material-source-save" type="submit">Add Source</button>
          <button id="task-extra-material-source-clear" type="button" class="secondary">Cancel</button>
        </div>
      </form>`;
    requirements.insertAdjacentElement('afterend', section);

    el('task-extra-material-source-search')?.addEventListener('input', renderContainerOptions);
    el('task-extra-material-source-container')?.addEventListener('change', handleSourceContainerChange);
    el('task-extra-material-source-form')?.addEventListener('submit', saveSource);
    el('task-extra-material-source-clear')?.addEventListener('click', clearEditor);
    section.addEventListener('click', handleSectionClick);
  }

  function renderContainerOptions() {
    const select = el('task-extra-material-source-container');
    if (!select) return;
    const query = String(el('task-extra-material-source-search')?.value || '').trim().toLocaleLowerCase();
    const current = select.value;
    const rows = state.containers
      .filter((row) => {
        if (!query) return true;
        return [row.container_id, row.container_description, containerTypeLabel(row), row.home_location_code]
          .filter((value) => value != null)
          .join(' ')
          .toLocaleLowerCase()
          .includes(query);
      })
      .sort((a, b) => {
        const aResolved = state.resolvedContainerIds.has(Number(a.container_id)) ? 0 : 1;
        const bResolved = state.resolvedContainerIds.has(Number(b.container_id)) ? 0 : 1;
        if (aResolved !== bResolved) return aResolved - bResolved;
        return Number(a.container_id) - Number(b.container_id);
      });
    select.innerHTML = rows.map((row) => (
      `<option value="${row.container_id}">${escapeHtml(containerLabel(row))}</option>`
    )).join('');
    if (current && rows.some((row) => String(row.container_id) === String(current))) select.value = current;
  }

  function clearEditor() {
    state.selectedRequirementId = null;
    state.editingSourceId = null;
    state.originalSourceContainerId = null;
    if (el('task-extra-material-source-search')) el('task-extra-material-source-search').value = '';
    if (el('task-extra-material-source-container')) el('task-extra-material-source-container').selectedIndex = -1;
    if (el('task-extra-material-source-qty')) el('task-extra-material-source-qty').value = '';
    if (el('task-extra-material-source-verification')) el('task-extra-material-source-verification').value = 'UNVERIFIED';
    if (el('task-extra-material-source-notes')) el('task-extra-material-source-notes').value = '';
    if (el('task-extra-material-source-form')) el('task-extra-material-source-form').hidden = true;
  }

  function loadSourceFacts(source) {
    el('task-extra-material-source-qty').value = displayNumber(source?.expected_quantity);
    el('task-extra-material-source-verification').value = source?.verification_state || 'UNVERIFIED';
    el('task-extra-material-source-notes').value = source?.notes || '';
  }

  function handleSourceContainerChange() {
    if (!state.editingSourceId) return;
    const source = sourceById(state.selectedRequirementId, state.editingSourceId);
    if (!source) return;
    const selectedId = Number(el('task-extra-material-source-container').value || 0);
    if (selectedId === Number(state.originalSourceContainerId)) {
      loadSourceFacts(source);
      el('task-extra-material-source-editor-help').textContent = 'Current Container selected. You may edit its quantity, verification, or notes.';
      return;
    }

    el('task-extra-material-source-qty').value = '';
    el('task-extra-material-source-verification').value = 'UNVERIFIED';
    el('task-extra-material-source-notes').value = '';
    el('task-extra-material-source-editor-help').textContent = 'Replacement selected. Enter the quantity and verification known for the new Container.';
  }

  function beginSource(requirementId, sourceId = null) {
    if (!appState.access?.can_manage_setup) return;
    const requirement = requirementById(requirementId);
    if (!requirement) return;

    state.selectedRequirementId = Number(requirementId);
    state.editingSourceId = sourceId == null ? null : Number(sourceId);
    if (el('task-extra-material-source-search')) el('task-extra-material-source-search').value = '';
    renderContainerOptions();

    const source = sourceId == null ? null : sourceById(requirementId, sourceId);
    if (source) {
      state.originalSourceContainerId = Number(source.container_id);
      el('task-extra-material-source-editor-title').textContent = 'Manager — Change Source';
      el('task-extra-material-source-selected').textContent = `${requirementLabel(requirement)} · Current C${source.container_id}`;
      el('task-extra-material-source-editor-help').textContent = 'Choose a replacement Container, or keep this Container to edit its source facts.';
      el('task-extra-material-source-container').value = String(source.container_id);
      loadSourceFacts(source);
      el('task-extra-material-source-save').textContent = 'Save Source';
    } else {
      state.originalSourceContainerId = null;
      el('task-extra-material-source-editor-title').textContent = 'Manager — Add Source';
      el('task-extra-material-source-selected').textContent = requirementLabel(requirement);
      el('task-extra-material-source-editor-help').textContent = 'Select a Container and enter the quantity from that Container.';
      el('task-extra-material-source-container').selectedIndex = -1;
      el('task-extra-material-source-qty').value = '';
      el('task-extra-material-source-verification').value = 'UNVERIFIED';
      el('task-extra-material-source-notes').value = '';
      el('task-extra-material-source-save').textContent = 'Add Source';
    }

    el('task-extra-material-source-form').hidden = false;
    el('task-extra-material-source-form').scrollIntoView({ behavior: 'smooth', block: 'start' });
  }

  function renderRequirements() {
    installSection();
    const body = el('task-extra-material-source-body');
    if (!body) return;
    if (!state.requirements.length) {
      body.innerHTML = '<div class="empty-state">No active Extra Material requirements.</div>';
      el('task-extra-material-source-status').textContent = '';
      return;
    }

    body.innerHTML = state.requirements.map((requirement) => {
      const sources = Array.isArray(requirement.sources) ? requirement.sources : [];
      const audit = allocationAudit(requirement);
      return `
        <div class="setup-extra-material-source-group" data-source-requirement-id="${requirement.setup_task_extra_material_id}">
          <div class="section-title compact">
            <div>
              <strong>${escapeHtml(requirementLabel(requirement))}</strong>
              <div class="setup-extra-material-source-audit ${audit.className}">${escapeHtml(audit.text)}</div>
            </div>
            ${appState.access?.can_manage_setup ? `<button type="button" class="small task-extra-material-source-add" data-requirement-id="${requirement.setup_task_extra_material_id}">Add Source</button>` : ''}
          </div>
          <div class="setup-extra-material-source-list">
            ${sources.length ? sources.map((source) => {
              const physical = containerById(source.container_id);
              const type = containerTypeLabel(physical);
              const quantity = source.expected_quantity == null ? 'Qty —' : `Qty ${displayNumber(source.expected_quantity)}`;
              const verification = String(source.verification_state || 'UNVERIFIED').replaceAll('_', ' ');
              const title = source.notes ? ` title="${escapeHtml(source.notes)}"` : '';
              return `
                <div class="setup-extra-material-source-row"${title}>
                  <div class="setup-extra-material-source-copy">
                    <strong>C${escapeHtml(source.container_id)} — ${escapeHtml(source.container_description || 'No description')}</strong>
                    <span class="muted">${escapeHtml(type)} · ${escapeHtml(quantity)} · ${escapeHtml(verification)}</span>
                  </div>
                  ${appState.access?.can_manage_setup ? `<div class="action-row"><button type="button" class="small secondary task-extra-material-source-edit" data-requirement-id="${requirement.setup_task_extra_material_id}" data-source-id="${source.setup_task_extra_material_source_id}">Change</button><button type="button" class="small danger task-extra-material-source-remove" data-requirement-id="${requirement.setup_task_extra_material_id}" data-source-id="${source.setup_task_extra_material_source_id}">Remove</button></div>` : ''}
                </div>`;
            }).join('') : '<div class="muted">No source assigned.</div>'}
          </div>
        </div>`;
    }).join('');
    el('task-extra-material-source-status').textContent = '';
    applyAccess();
  }

  async function loadTaskSources(taskId) {
    installSection();
    state.taskId = Number(taskId);
    clearEditor();
    const token = ++state.requestToken;
    if (el('task-extra-material-source-status')) el('task-extra-material-source-status').textContent = 'Loading sources…';
    try {
      const requests = [
        api(`api/setup/tasks/${taskId}/extra-materials`),
        api('api/setup/containers/source-options'),
      ];
      if (appState.seasonYear != null) {
        requests.push(api(`api/setup/tasks/${taskId}/field-context?season_year=${encodeURIComponent(appState.seasonYear)}`));
      }
      const [requirementsPayload, containersPayload, contextPayload] = await Promise.all(requests);
      if (token !== state.requestToken || Number(taskId) !== Number(state.taskId)) return;
      state.requirements = requirementsPayload.extra_materials || [];
      state.containers = containersPayload.containers || [];
      const ids = contextPayload?.context?.material_resolution?.container_ids || [];
      state.resolvedContainerIds = new Set(ids.map((value) => Number(value)));
      renderContainerOptions();
      renderRequirements();
    } catch (error) {
      if (token !== state.requestToken) return;
      state.requirements = [];
      state.containers = [];
      state.resolvedContainerIds = new Set();
      if (el('task-extra-material-source-body')) el('task-extra-material-source-body').innerHTML = `<div class="empty-state">${escapeHtml(error.message || error)}</div>`;
      if (el('task-extra-material-source-status')) el('task-extra-material-source-status').textContent = 'Sources could not be loaded.';
    }
  }

  function sourcePayload(activeFlag = true) {
    return {
      container_id: Number(el('task-extra-material-source-container').value),
      expected_quantity: numberOrNull(el('task-extra-material-source-qty').value),
      verification_state: el('task-extra-material-source-verification').value,
      notes: el('task-extra-material-source-notes').value.trim() || null,
      active_flag: activeFlag,
    };
  }

  async function verifySourceRoundTrip(requirementId, sourceId, requested) {
    const payload = await api(`api/setup/tasks/${state.taskId}/extra-materials`);
    const requirement = (payload.extra_materials || []).find(
      (row) => Number(row.setup_task_extra_material_id) === Number(requirementId),
    );
    const source = (requirement?.sources || []).find(
      (row) => Number(row.setup_task_extra_material_source_id) === Number(sourceId),
    );
    if (!source) throw new Error('Saved source could not be reloaded.');
    if (Number(source.container_id) !== Number(requested.container_id)) {
      throw new Error(`Saved source Container mismatch: expected C${requested.container_id}, reloaded C${source.container_id}.`);
    }
    if (!sameQuantity(source.expected_quantity, requested.expected_quantity)) {
      throw new Error(`Saved source quantity mismatch: entered ${displayNumber(requested.expected_quantity) || 'blank'}, reloaded ${displayNumber(source.expected_quantity) || 'blank'}.`);
    }
    return payload;
  }

  async function saveSource(event) {
    event.preventDefault();
    if (!appState.access?.can_manage_setup || !state.selectedRequirementId) return;
    const containerId = Number(el('task-extra-material-source-container').value || 0);
    if (!containerId) {
      setAlert('Choose a source Container first.', 'error');
      return;
    }

    const requested = sourcePayload(true);
    if (requested.verification_state === 'VERIFIED' && requested.expected_quantity == null) {
      setAlert('A VERIFIED source requires Qty from this Container.', 'error');
      return;
    }

    const requirement = requirementById(state.selectedRequirementId);
    const duplicate = (requirement?.sources || []).some((source) => (
      Number(source.container_id) === containerId
      && Number(source.setup_task_extra_material_source_id) !== Number(state.editingSourceId)
    ));
    if (duplicate) {
      setAlert(`Container ${containerId} is already an active source for this requirement.`, 'error');
      return;
    }

    const requirementId = state.selectedRequirementId;
    const existingSourceId = state.editingSourceId;
    const path = existingSourceId
      ? `api/setup/task-extra-materials/${requirementId}/sources/${existingSourceId}`
      : `api/setup/task-extra-materials/${requirementId}/sources`;
    const method = existingSourceId ? 'PATCH' : 'POST';

    try {
      const result = await api(path, commandOptions(method, requested));
      const sourceId = existingSourceId
        || result.setup_task_extra_material_source?.setup_task_extra_material_source_id;
      if (!sourceId) throw new Error('Saved source did not return its source ID.');

      const verifiedPayload = await verifySourceRoundTrip(requirementId, sourceId, requested);
      state.requirements = verifiedPayload.extra_materials || [];
      const taskId = state.taskId;
      clearEditor();
      renderRequirements();
      if (typeof window.refreshTaskExtraMaterials === 'function') {
        await window.refreshTaskExtraMaterials(taskId);
      }
      const qty = requested.expected_quantity == null ? '' : ` · Qty ${displayNumber(requested.expected_quantity)}`;
      setAlert(`C${requested.container_id}${qty} saved.`);
    } catch (error) {
      setAlert(error.message || error, 'error');
    }
  }

  async function removeSource(requirementId, sourceId) {
    if (!appState.access?.can_manage_setup) return;
    const source = sourceById(requirementId, sourceId);
    if (!source) return;
    if (!window.confirm(`Remove C${source.container_id} as an expected source?`)) return;
    try {
      await api(
        `api/setup/task-extra-materials/${requirementId}/sources/${sourceId}`,
        commandOptions('PATCH', {
          container_id: Number(source.container_id),
          expected_quantity: source.expected_quantity == null ? null : Number(source.expected_quantity),
          verification_state: source.verification_state || 'UNVERIFIED',
          notes: source.notes || null,
          active_flag: false,
        }),
      );
      const taskId = state.taskId;
      clearEditor();
      await loadTaskSources(taskId);
      if (typeof window.refreshTaskExtraMaterials === 'function') {
        await window.refreshTaskExtraMaterials(taskId);
      }
      setAlert('Expected source removed.');
    } catch (error) {
      setAlert(error.message || error, 'error');
    }
  }

  function handleSectionClick(event) {
    const add = event.target.closest('.task-extra-material-source-add');
    if (add) {
      beginSource(Number(add.dataset.requirementId));
      return;
    }
    const edit = event.target.closest('.task-extra-material-source-edit');
    if (edit) {
      beginSource(Number(edit.dataset.requirementId), Number(edit.dataset.sourceId));
      return;
    }
    const remove = event.target.closest('.task-extra-material-source-remove');
    if (remove) removeSource(Number(remove.dataset.requirementId), Number(remove.dataset.sourceId));
  }

  function bind() {
    installSection();
    const priorSelectTask = selectTask;
    selectTask = function selectTaskWithExtraMaterialSources(taskId) {
      const result = priorSelectTask(taskId);
      loadTaskSources(taskId);
      return result;
    };
    if (appState.selectedTaskId) loadTaskSources(appState.selectedTaskId);
  }

  if (document.readyState === 'loading') document.addEventListener('DOMContentLoaded', bind);
  else bind();
})();