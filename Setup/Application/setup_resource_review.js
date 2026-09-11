/* Structured reusable equipment/resource review for the shared Setup browser. */

const setupResourceState = {
  catalog: [],
  catalogLoaded: false,
  taskResources: [],
  adminCatalog: [],
  adminCatalogLoaded: false
};

function normalizeResourceSearchText(value) {
  return String(value ?? '').trim().toLowerCase().replace(/\s+/g, ' ');
}

function resourceSearchText(resource) {
  return normalizeResourceSearchText([
    resource?.resource_name,
    resource?.resource_type,
    resource?.notes,
    resource?.active_flag ? 'active' : 'inactive'
  ].filter(Boolean).join(' '));
}

function resourceMatchesQuery(resource, query) {
  const normalized = normalizeResourceSearchText(query);
  return !normalized || resourceSearchText(resource).includes(normalized);
}

function compareResourceName(left, right) {
  return String(left?.resource_name || '').localeCompare(String(right?.resource_name || ''), undefined, {
    sensitivity: 'base',
    numeric: true
  });
}

function compareResourceTypeThenName(left, right) {
  const typeCompare = String(left?.resource_type || '').localeCompare(String(right?.resource_type || ''), undefined, {
    sensitivity: 'base'
  });
  return typeCompare || compareResourceName(left, right) || Number(left.setup_resource_id) - Number(right.setup_resource_id);
}

function compareResourceCatalogOrder(left, right) {
  return Number(left?.display_order ?? 100) - Number(right?.display_order ?? 100)
    || compareResourceTypeThenName(left, right);
}

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
          <div class="hint">Search the reusable catalog before creating something new. If the selected item is already assigned, this form updates only this task's requirement.</div>
        </div>
        <div class="resource-search-grid">
          <label>Find existing resource
            <input id="setup-resource-search" type="search" placeholder="Search name, type, or catalog notes">
          </label>
          <div id="setup-resource-search-count" class="resource-selection-state muted"></div>
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

      <section class="resource-manager-block resource-catalog-edit-block">
        <div class="resource-manager-heading">
          <h4>Manage reusable resource catalog</h4>
          <div class="hint">Search active and inactive catalog entries before creating a replacement. Edit poor names in place so every task keeps the same resource ID.</div>
        </div>
        <div class="resource-catalog-search-grid">
          <label>Search catalog
            <input id="setup-resource-catalog-search" type="search" placeholder="Search name, type, notes, active/inactive">
          </label>
          <label>Browse sort
            <select id="setup-resource-catalog-sort">
              <option value="ORDER">Catalog display order</option>
              <option value="NAME">Name</option>
              <option value="TYPE">Type, then name</option>
              <option value="ACTIVE">Active first</option>
            </select>
          </label>
        </div>
        <div id="setup-resource-catalog-results" class="resource-selection-state muted"></div>
        <label>Catalog resource
          <select id="setup-resource-catalog-select"></select>
        </label>
        <div class="resource-catalog-grid">
          <label>Resource name
            <input id="setup-resource-catalog-name" type="text">
          </label>
          <label>Type
            <select id="setup-resource-catalog-type">
              <option value="EQUIPMENT">Equipment</option>
              <option value="VEHICLE">Vehicle</option>
              <option value="TRAILER">Trailer</option>
              <option value="TOOL">Tool</option>
              <option value="OTHER">Other</option>
            </select>
          </label>
          <label>Display order
            <input id="setup-resource-catalog-order" type="number" min="0" value="100">
          </label>
          <label class="checkbox-label resource-active-label">
            <input id="setup-resource-catalog-active" type="checkbox"> Active catalog resource
          </label>
        </div>
        <label>Catalog notes
          <input id="setup-resource-catalog-notes" type="text" placeholder="Reusable description / catalog note">
        </label>
        <div id="setup-resource-catalog-state" class="resource-selection-state muted"></div>
        <div class="action-row">
          <button id="setup-resource-catalog-save" type="button">Save Catalog Resource</button>
        </div>
      </section>

      <section class="resource-manager-block resource-create-block">
        <div class="resource-manager-heading">
          <h4>Need something that is not in the catalog?</h4>
          <div class="hint">Type the name first. Setup will show possible existing matches before you create another reusable resource.</div>
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
        <div id="setup-new-resource-matches" class="resource-match-list muted"></div>
      </section>
    </div>
  `;
  dependencySection.insertAdjacentElement('afterend', section);

  document.getElementById('setup-resource-save')?.addEventListener('click', saveSetupTaskResource);
  document.getElementById('setup-resource-select')?.addEventListener('change', syncSetupResourceSelection);
  document.getElementById('setup-resource-search')?.addEventListener('input', renderSetupResourceCatalog);
  document.getElementById('setup-resource-catalog-select')?.addEventListener('change', syncSetupResourceCatalogEditor);
  document.getElementById('setup-resource-catalog-search')?.addEventListener('input', renderSetupResourceAdminCatalog);
  document.getElementById('setup-resource-catalog-sort')?.addEventListener('change', renderSetupResourceAdminCatalog);
  document.getElementById('setup-resource-catalog-save')?.addEventListener('click', saveSetupResourceCatalogEntry);
  document.getElementById('setup-new-resource-name')?.addEventListener('input', renderSetupNewResourceMatches);
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

async function loadSetupResourceAdminCatalog(force = false) {
  if (!appState.access?.can_manage_setup) return [];
  if (setupResourceState.adminCatalogLoaded && !force) return setupResourceState.adminCatalog;
  const payload = await api('api/setup/resource-catalog');
  setupResourceState.adminCatalog = payload.resources || [];
  setupResourceState.adminCatalogLoaded = true;
  renderSetupResourceAdminCatalog();
  renderSetupNewResourceMatches();
  return setupResourceState.adminCatalog;
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
  save.disabled = !selected;

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
      : 'No matching active resource is selected.';
  }
}

function renderSetupResourceCatalog() {
  const select = document.getElementById('setup-resource-select');
  if (!select) return;
  const search = document.getElementById('setup-resource-search')?.value || '';
  const count = document.getElementById('setup-resource-search-count');
  const previous = select.value;
  const filtered = setupResourceState.catalog.filter((resource) => resourceMatchesQuery(resource, search));

  select.innerHTML = filtered.length
    ? filtered.map((resource) => {
        const assigned = Boolean(resourceAssignmentById(resource.setup_resource_id));
        const suffix = assigned ? ' · already on task' : '';
        return `<option value="${resource.setup_resource_id}">${escapeHtml(resource.resource_name)} · ${escapeHtml(resource.resource_type)}${suffix}</option>`;
      }).join('')
    : '<option value="">No matching active resources</option>';

  if (previous && filtered.some((item) => String(item.setup_resource_id) === previous)) {
    select.value = previous;
  }
  if (count) count.textContent = `${filtered.length} of ${setupResourceState.catalog.length} active catalog resources shown.`;
  syncSetupResourceSelection();
}

function adminResourceById(resourceId) {
  return setupResourceState.adminCatalog.find(
    (item) => Number(item.setup_resource_id) === Number(resourceId)
  ) || null;
}

function filteredSortedAdminResources() {
  const search = document.getElementById('setup-resource-catalog-search')?.value || '';
  const sortMode = document.getElementById('setup-resource-catalog-sort')?.value || 'ORDER';
  const rows = setupResourceState.adminCatalog.filter((resource) => resourceMatchesQuery(resource, search));

  rows.sort((left, right) => {
    if (sortMode === 'NAME') return compareResourceName(left, right) || Number(left.setup_resource_id) - Number(right.setup_resource_id);
    if (sortMode === 'TYPE') return compareResourceTypeThenName(left, right);
    if (sortMode === 'ACTIVE') {
      return Number(Boolean(right.active_flag)) - Number(Boolean(left.active_flag))
        || compareResourceCatalogOrder(left, right);
    }
    return compareResourceCatalogOrder(left, right);
  });
  return rows;
}

function renderSetupResourceAdminCatalog() {
  const select = document.getElementById('setup-resource-catalog-select');
  if (!select) return;
  const results = document.getElementById('setup-resource-catalog-results');
  const previous = select.value;
  const filtered = filteredSortedAdminResources();

  select.innerHTML = filtered.length
    ? filtered.map((resource) => {
        const inactive = resource.active_flag ? '' : ' · INACTIVE';
        return `<option value="${resource.setup_resource_id}">${escapeHtml(resource.resource_name)} · ${escapeHtml(resource.resource_type)} · order ${escapeHtml(resource.display_order)}${inactive}</option>`;
      }).join('')
    : '<option value="">No matching catalog resources</option>';

  if (previous && filtered.some((item) => String(item.setup_resource_id) === previous)) {
    select.value = previous;
  }
  if (results) results.textContent = `${filtered.length} of ${setupResourceState.adminCatalog.length} total catalog resources shown, including inactive entries.`;
  syncSetupResourceCatalogEditor();
}

function syncSetupResourceCatalogEditor() {
  const select = document.getElementById('setup-resource-catalog-select');
  const name = document.getElementById('setup-resource-catalog-name');
  const type = document.getElementById('setup-resource-catalog-type');
  const order = document.getElementById('setup-resource-catalog-order');
  const active = document.getElementById('setup-resource-catalog-active');
  const notes = document.getElementById('setup-resource-catalog-notes');
  const state = document.getElementById('setup-resource-catalog-state');
  const save = document.getElementById('setup-resource-catalog-save');
  if (!select || !name || !type || !order || !active || !notes || !save) return;

  const resource = adminResourceById(Number(select.value || 0));
  save.disabled = !resource;
  if (!resource) {
    name.value = '';
    type.value = 'EQUIPMENT';
    order.value = '100';
    active.checked = false;
    notes.value = '';
    if (state) state.textContent = 'No reusable resource is selected.';
    return;
  }

  name.value = resource.resource_name || '';
  type.value = resource.resource_type || 'EQUIPMENT';
  order.value = String(resource.display_order ?? 100);
  active.checked = Boolean(resource.active_flag);
  notes.value = resource.notes || '';
  if (state) {
    state.textContent = `Resource #${resource.setup_resource_id}. Catalog edits preserve this stable ID and its existing task relationships.${resource.active_flag ? '' : ' This entry is currently inactive.'}`;
  }
}

function possibleExistingResourceMatches(name) {
  const query = normalizeResourceSearchText(name);
  if (query.length < 2) return [];
  const queryTokens = query.split(' ').filter((token) => token.length >= 2);

  return setupResourceState.adminCatalog
    .map((resource) => {
      const normalizedName = normalizeResourceSearchText(resource.resource_name);
      let score = 0;
      if (normalizedName === query) score = 100;
      else if (normalizedName.includes(query) || query.includes(normalizedName)) score = 80;
      else if (queryTokens.length && queryTokens.every((token) => normalizedName.includes(token))) score = 60;
      else if (queryTokens.some((token) => normalizedName.includes(token))) score = 20;
      return { resource, score };
    })
    .filter((item) => item.score > 0)
    .sort((left, right) => right.score - left.score
      || Number(Boolean(right.resource.active_flag)) - Number(Boolean(left.resource.active_flag))
      || compareResourceName(left.resource, right.resource))
    .slice(0, 6)
    .map((item) => ({ ...item.resource, match_score: item.score }));
}

function renderSetupNewResourceMatches() {
  const target = document.getElementById('setup-new-resource-matches');
  const input = document.getElementById('setup-new-resource-name');
  if (!target || !input) return;
  const typed = input.value.trim();
  if (typed.length < 2) {
    target.textContent = 'Start typing a name to check the full active/inactive catalog for possible duplicates.';
    return;
  }

  const matches = possibleExistingResourceMatches(typed);
  if (!matches.length) {
    target.innerHTML = '<strong>No likely existing catalog matches found.</strong> Review the catalog search above before creating.';
    return;
  }

  const exact = matches.find((resource) => normalizeResourceSearchText(resource.resource_name) === normalizeResourceSearchText(typed));
  const intro = exact
    ? '<strong>An existing resource has the same normalized name. Do not create another one.</strong>'
    : '<strong>Possible existing catalog matches:</strong>';
  target.innerHTML = `${intro}<ul>${matches.map((resource) => `
    <li>${escapeHtml(resource.resource_name)} · ${escapeHtml(resource.resource_type)} · #${escapeHtml(resource.setup_resource_id)}${resource.active_flag ? '' : ' · INACTIVE'}</li>
  `).join('')}</ul>`;
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
    if (appState.access?.can_manage_setup) {
      await loadSetupResourceAdminCatalog();
    }
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

async function saveSetupResourceCatalogEntry() {
  if (!appState.access?.can_manage_setup) return;
  const resourceId = Number(document.getElementById('setup-resource-catalog-select')?.value || 0);
  const name = document.getElementById('setup-resource-catalog-name')?.value.trim() || '';
  const type = document.getElementById('setup-resource-catalog-type')?.value || 'EQUIPMENT';
  const displayOrder = Number(document.getElementById('setup-resource-catalog-order')?.value ?? -1);
  const activeFlag = Boolean(document.getElementById('setup-resource-catalog-active')?.checked);
  const notes = document.getElementById('setup-resource-catalog-notes')?.value.trim() || null;

  if (!resourceId || !name || !Number.isInteger(displayOrder) || displayOrder < 0) {
    window.alert('Choose a resource, enter a name, and use a display order of zero or greater.');
    return;
  }

  const duplicate = setupResourceState.adminCatalog.find((resource) =>
    Number(resource.setup_resource_id) !== resourceId
    && normalizeResourceSearchText(resource.resource_name) === normalizeResourceSearchText(name)
  );
  if (duplicate) {
    window.alert(`Cannot rename this resource to ${name}. Resource #${duplicate.setup_resource_id} already uses the same normalized name: ${duplicate.resource_name}.`);
    return;
  }

  try {
    setBusy(true);
    await api(
      `api/setup/resources/${resourceId}`,
      commandOptions('PATCH', {
        resource_name: name,
        resource_type: type,
        notes,
        active_flag: activeFlag,
        display_order: displayOrder
      })
    );

    setupResourceState.catalogLoaded = false;
    setupResourceState.adminCatalogLoaded = false;
    await Promise.all([
      loadSetupResourceCatalog(true),
      loadSetupResourceAdminCatalog(true)
    ]);

    const adminSelect = document.getElementById('setup-resource-catalog-select');
    if (adminSelect && setupResourceState.adminCatalog.some((item) => Number(item.setup_resource_id) === resourceId)) {
      adminSelect.value = String(resourceId);
      syncSetupResourceCatalogEditor();
    }

    const task = taskById(appState.selectedTaskId);
    if (task) await loadSetupTaskResources(task);

    setAlert(`${name} catalog entry updated. Existing task relationships remain attached to resource #${resourceId}.`, 'ok');
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
    await loadSetupResourceAdminCatalog();
    const exactExisting = setupResourceState.adminCatalog.find((resource) =>
      normalizeResourceSearchText(resource.resource_name) === normalizeResourceSearchText(name)
    );
    if (exactExisting) {
      const search = document.getElementById('setup-resource-catalog-search');
      if (search) search.value = exactExisting.resource_name;
      renderSetupResourceAdminCatalog();
      const adminSelect = document.getElementById('setup-resource-catalog-select');
      if (adminSelect) {
        adminSelect.value = String(exactExisting.setup_resource_id);
        syncSetupResourceCatalogEditor();
      }
      window.alert(`${exactExisting.resource_name} already exists as resource #${exactExisting.setup_resource_id}${exactExisting.active_flag ? '' : ' and is currently inactive'}. Use or correct that catalog entry instead of creating a duplicate.`);
      return;
    }

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
    setupResourceState.adminCatalogLoaded = false;
    await Promise.all([
      loadSetupResourceCatalog(true),
      loadSetupResourceAdminCatalog(true)
    ]);
    const newId = payload.setup_resource?.setup_resource_id;
    if (newId) {
      const taskSelect = document.getElementById('setup-resource-select');
      if (taskSelect) {
        taskSelect.value = String(newId);
        syncSetupResourceSelection();
      }
      const adminSelect = document.getElementById('setup-resource-catalog-select');
      if (adminSelect) {
        adminSelect.value = String(newId);
        syncSetupResourceCatalogEditor();
      }
    }
    document.getElementById('setup-new-resource-form')?.reset();
    renderSetupNewResourceMatches();
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
