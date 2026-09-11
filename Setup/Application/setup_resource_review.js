/* Structured reusable equipment/resource review for the shared Setup browser. */

const setupResourceState = {
  catalog: [],
  catalogLoaded: false,
  taskResources: []
};

function ensureSetupResourceSection() {
  let section = document.getElementById('setup-resource-section');
  if (section) return section;

  const dependencySection = document.getElementById('detail-dependencies')?.closest('.detail-section');
  if (!dependencySection) return null;

  section = document.createElement('section');
  section.id = 'setup-resource-section';
  section.className = 'detail-section';
  section.innerHTML = `
    <div class="resource-section-header">
      <div>
        <div class="eyebrow">Reusable task requirement</div>
        <h3>Equipment / Resources Needed</h3>
      </div>
      <span class="muted">Current requirements are listed first.</span>
    </div>
    <div id="setup-resource-list" class="resource-list">
      <span class="muted">Select a task to load equipment/resources.</span>
    </div>

    <div id="setup-resource-manager" class="resource-manager-panel manager-only" hidden>
      <section class="resource-manager-block resource-existing-block">
        <div class="resource-manager-heading">
          <h4>Add existing equipment/resource to this task</h4>
          <div class="hint">Choose an item from the reusable resource catalog. If it is already assigned, this form updates that requirement.</div>
        </div>
        <div class="resource-edit-grid">
          <label>Existing resource
            <select id="setup-resource-select"></select>
          </label>
          <label>Quantity
            <input id="setup-resource-quantity" type="number" min="1" value="1">
          </label>
          <label>Requirement
            <select id="setup-resource-requirement">
              <option value="REQUIRED">Required</option>
              <option value="PREFERRED">Preferred</option>
            </select>
          </label>
        </div>
        <label>Task-specific notes
          <input id="setup-resource-notes" type="text" placeholder="Optional note for this task only">
        </label>
        <div id="setup-resource-selection-state" class="resource-selection-state muted"></div>
        <div class="action-row">
          <button id="setup-resource-save" type="button">Add Resource to Task</button>
        </div>
      </section>

      <section class="resource-manager-block resource-create-block">
        <div class="resource-manager-heading">
          <h4>Need something that is not in the catalog?</h4>
          <div class="hint">Create it once as reusable equipment/resource, then add it to this task above.</div>
        </div>
        <form id="setup-new-resource-form" class="resource-new-form">
          <label>New resource name
            <input id="setup-new-resource-name" type="text" placeholder="Example: 60-ft Boom Lift">
          </label>
          <label>Type
            <select id="setup-new-resource-type">
              <option value="EQUIPMENT">Equipment</option>
              <option value="VEHICLE">Vehicle</option>
              <option value="TRAILER">Trailer</option>
              <option value="TOOL">Tool</option>
              <option value="OTHER">Other</option>
            </select>
          </label>
          <label>Catalog notes
            <input id="setup-new-resource-notes" type="text" placeholder="Optional reusable description">
          </label>
          <div class="resource-inline-actions">
            <button type="submit" class="secondary">Create New Catalog Resource</button>
          </div>
        </form>
      </section>
    </div>
  `;
  dependencySection.insertAdjacentElement('afterend', section);

  document.getElementById('setup-resource-save')?.addEventListener('click', saveSetupTaskResource);
  document.getElementById('setup-resource-select')?.addEventListener('change', syncSetupResourceSelection);
  document.getElementById('setup-new-resource-form')?.addEventListener('submit', createSetupResource);
  return section;
}

function syncSetupResourceManagerVisibility() {
  const manager = document.getElementById('setup-resource-manager');
  if (manager) manager.hidden = !appState.access?.can_manage_setup;
}

async function loadSetupResourceCatalog(force = false) {
  if (setupResourceState.catalogLoaded && !force) return setupResourceState.catalog;
  const payload = await api('api/setup/resources');
  setupResourceState.catalog = payload.resources || [];
  setupResourceState.catalogLoaded = true;
  renderSetupResourceCatalog();
  return setupResourceState.catalog;
}

function resourceAssignmentById(resourceId) {
  return setupResourceState.taskResources.find(
    (item) => Number(item.setup_resource_id) === Number(resourceId)
  ) || null;
}

function syncSetupResourceSelection() {
  const select = document.getElementById('setup-resource-select');
  const save = document.getElementById('setup-resource-save');
  const state = document.getElementById('setup-resource-selection-state');
  const quantity = document.getElementById('setup-resource-quantity');
  const requirement = document.getElementById('setup-resource-requirement');
  const notes = document.getElementById('setup-resource-notes');
  if (!select || !save || !quantity || !requirement || !notes) return;

  const resourceId = Number(select.value || 0);
  const selected = setupResourceState.catalog.find(
    (item) => Number(item.setup_resource_id) === resourceId
  );
  const assignment = resourceAssignmentById(resourceId);

  if (assignment) {
    quantity.value = assignment.quantity_required ?? 1;
    requirement.value = assignment.requirement_type || 'REQUIRED';
    notes.value = assignment.notes || '';
    save.textContent = 'Update Resource Requirement';
    if (state) state.textContent = `${assignment.resource_name} is already assigned to this task. Saving will update its quantity, requirement, or task-specific note.`;
  } else {
    quantity.value = 1;
    requirement.value = 'REQUIRED';
    notes.value = '';
    save.textContent = 'Add Resource to Task';
    if (state) state.textContent = selected
      ? `${selected.resource_name} is not currently assigned to this task.`
      : 'Choose a reusable resource to add to this task.';
  }
}

function renderSetupResourceCatalog() {
  const select = document.getElementById('setup-resource-select');
  if (!select) return;
  const previous = select.value;
  select.innerHTML = setupResourceState.catalog.map((resource) => {
    const assigned = Boolean(resourceAssignmentById(resource.setup_resource_id));
    const suffix = assigned ? ' · already on task' : '';
    return `<option value="${resource.setup_resource_id}">${escapeHtml(resource.resource_name)} · ${escapeHtml(resource.resource_type)}${suffix}</option>`;
  }).join('');
  if (previous && setupResourceState.catalog.some((item) => String(item.setup_resource_id) === previous)) {
    select.value = previous;
  }
  syncSetupResourceSelection();
}

function resourceAssignmentPayload(resource, activeFlag = true) {
  return {
    quantity_required: Number(resource.quantity_required) || 1,
    requirement_type: resource.requirement_type || 'REQUIRED',
    notes: resource.notes || null,
    active_flag: activeFlag
  };
}

function renderSetupTaskResources(task) {
  const target = document.getElementById('setup-resource-list');
  if (!target) return;

  if (!setupResourceState.taskResources.length) {
    target.innerHTML = `
      <div class="empty-state resource-empty">
        No equipment/resource requirement is recorded for this reusable task yet.
      </div>
    `;
    renderSetupResourceCatalog();
    syncSetupResourceManagerVisibility();
    return;
  }

  target.innerHTML = setupResourceState.taskResources.map((resource) => `
    <div class="resource-row">
      <div>
        <div class="resource-name">${escapeHtml(resource.resource_name)}</div>
        <div class="resource-meta">${escapeHtml(resource.resource_type)}</div>
        ${resource.notes ? `<div class="resource-notes">${escapeHtml(resource.notes)}</div>` : ''}
      </div>
      <div class="resource-quantity">Qty ${escapeHtml(resource.quantity_required)}</div>
      <div class="resource-requirement">
        <span class="pill ${resource.requirement_type === 'REQUIRED' ? 'verified' : 'unverified'}">${escapeHtml(resource.requirement_type)}</span>
        ${appState.access?.can_manage_setup ? `
          <div class="resource-inline-actions">
            <button
              type="button"
              class="small secondary resource-remove"
              data-resource-id="${resource.setup_resource_id}"
            >Remove</button>
          </div>
        ` : ''}
      </div>
    </div>
  `).join('');

  target.querySelectorAll('.resource-remove').forEach((button) => {
    button.addEventListener('click', () => removeSetupTaskResource(task, Number(button.dataset.resourceId)));
  });
  renderSetupResourceCatalog();
  syncSetupResourceManagerVisibility();
}

async function loadSetupTaskResources(task) {
  ensureSetupResourceSection();
  syncSetupResourceManagerVisibility();
  const target = document.getElementById('setup-resource-list');
  if (target) target.innerHTML = '<span class="muted">Loading equipment/resources…</span>';

  try {
    const [catalogPayload, taskPayload] = await Promise.all([
      loadSetupResourceCatalog(),
      api(`api/setup/tasks/${task.setup_task_id}/resources`)
    ]);
    void catalogPayload;
    setupResourceState.taskResources = taskPayload.resources || [];
    renderSetupTaskResources(task);
  } catch (error) {
    setupResourceState.taskResources = [];
    if (target) {
      target.innerHTML = `<strong>Equipment/resources could not be loaded.</strong><div class="muted">${escapeHtml(error.message || error)}</div>`;
    }
  }
}

async function saveSetupTaskResource() {
  const task = taskById(appState.selectedTaskId);
  if (!task || !appState.access?.can_manage_setup) return;

  const resourceId = Number(document.getElementById('setup-resource-select')?.value || 0);
  const quantity = Number(document.getElementById('setup-resource-quantity')?.value || 0);
  const requirement = document.getElementById('setup-resource-requirement')?.value || 'REQUIRED';
  const notes = document.getElementById('setup-resource-notes')?.value.trim() || null;
  if (!resourceId || quantity < 1) {
    window.alert('Choose a resource and quantity of at least 1.');
    return;
  }

  const assignmentBefore = resourceAssignmentById(resourceId);
  const catalogResource = setupResourceState.catalog.find(
    (item) => Number(item.setup_resource_id) === resourceId
  );
  const resourceName = assignmentBefore?.resource_name || catalogResource?.resource_name || `Resource ${resourceId}`;

  try {
    setBusy(true);
    await api(
      `api/setup/tasks/${task.setup_task_id}/resources/${resourceId}`,
      commandOptions('PATCH', {
        quantity_required: quantity,
        requirement_type: requirement,
        notes,
        active_flag: true
      })
    );
    setAlert(
      assignmentBefore
        ? `${resourceName} requirement updated for this reusable task.`
        : `${resourceName} added to this reusable task.`,
      'ok'
    );
    await loadSetupTaskResources(task);
  } catch (error) {
    setAlert(error.message || error, 'error');
    window.alert(error.message || error);
  } finally {
    setBusy(false);
  }
}

async function removeSetupTaskResource(task, resourceId) {
  if (!appState.access?.can_manage_setup) return;
  const assignment = resourceAssignmentById(resourceId);
  if (!assignment) return;
  if (!window.confirm(`Remove ${assignment.resource_name} from this reusable task?`)) return;

  try {
    setBusy(true);
    await api(
      `api/setup/tasks/${task.setup_task_id}/resources/${resourceId}`,
      commandOptions('PATCH', resourceAssignmentPayload(assignment, false))
    );
    setAlert(`${assignment.resource_name} removed from the reusable task.`, 'ok');
    await loadSetupTaskResources(task);
  } catch (error) {
    setAlert(error.message || error, 'error');
    window.alert(error.message || error);
  } finally {
    setBusy(false);
  }
}

async function createSetupResource(event) {
  event.preventDefault();
  if (!appState.access?.can_manage_setup) return;

  const name = document.getElementById('setup-new-resource-name')?.value.trim() || '';
  const type = document.getElementById('setup-new-resource-type')?.value || 'EQUIPMENT';
  const notes = document.getElementById('setup-new-resource-notes')?.value.trim() || null;
  if (!name) return;

  try {
    setBusy(true);
    const payload = await api(
      'api/setup/resources',
      commandOptions('POST', {
        resource_name: name,
        resource_type: type,
        notes
      })
    );
    setupResourceState.catalogLoaded = false;
    await loadSetupResourceCatalog(true);
    const newId = payload.setup_resource?.setup_resource_id;
    if (newId) {
      document.getElementById('setup-resource-select').value = String(newId);
      syncSetupResourceSelection();
    }
    document.getElementById('setup-new-resource-form')?.reset();
    setAlert(`Reusable resource ${name} created in the catalog. It is selected above; click Add Resource to Task to assign it.`, 'ok');
  } catch (error) {
    setAlert(error.message || error, 'error');
    window.alert(error.message || error);
  } finally {
    setBusy(false);
  }
}

const baseSelectTaskForResources = selectTask;
selectTask = function selectTaskWithResources(taskId) {
  baseSelectTaskForResources(taskId);
  const task = taskById(taskId);
  if (task) loadSetupTaskResources(task);
};

ensureSetupResourceSection();
syncSetupResourceManagerVisibility();
