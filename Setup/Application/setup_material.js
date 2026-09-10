/* Setup reusable Display-Setup classification + explicit LOR material sources.
 * Issue #122. Work scope never implies material. Component/KIT timing remains #141.
 */

const setupMaterialState = new Map();
const setupMaterialBaseApi = api;
let setupMaterialCatalog = [];
let setupNewTaskSubmitToken = 0;

function setupMaterialRewritePath(path) {
  const text = String(path || '');
  if (/^\/?api\/setup\/tasks\/\d+\/field-context\?/.test(text)) {
    return text.replace('/field-context?', '/material-context?');
  }
  return text;
}

api = async function apiWithSetupMaterial(path, options = {}) {
  return setupMaterialBaseApi(setupMaterialRewritePath(path), options);
};

function setupMaterialMetadata(taskId) {
  return setupMaterialState.get(Number(taskId)) || { isDisplaySetupStep: false, sources: [] };
}

function setupMaterialSourceId(source) {
  return `${source.source_type}|${source.source_key}`;
}

function applySetupMaterialToTasks() {
  for (const task of appState.tasks || []) {
    const metadata = setupMaterialMetadata(task.setup_task_id);
    task.is_display_setup_step = metadata.isDisplaySetupStep;
    task.material_sources = metadata.sources;
  }
}

function installSetupMaterialEditor() {
  if (el('setup-material-editor')) return;
  const effortRow = el('setup-effort-editor-row');
  const effortSelect = el('edit-effort-level');
  const anchor = effortRow || effortSelect?.closest('label');
  if (!anchor) return;

  const panel = document.createElement('div');
  panel.id = 'setup-material-editor';
  panel.className = 'setup-material-editor';
  panel.innerHTML = `
    <label class="checkbox-label" title="Visual classification only. It never selects Display material.">
      <input id="edit-is-display-setup-step" type="checkbox"> Display Setup step
    </label>
    <div class="setup-material-source-block">
      <div class="setup-material-source-heading">
        <strong>Display material sources</strong>
        <span class="setup-material-editor-note">Explicit current LOR sources; task work scope does not supply material.</span>
      </div>
      <div id="setup-material-selected-sources" class="setup-material-selected-sources"></div>
      <div class="setup-material-source-add">
        <select id="setup-material-source-select" aria-label="Add LOR material source"></select>
        <button id="setup-material-source-add" type="button" class="secondary">Add material source</button>
      </div>
      <div class="setup-material-editor-note">
        No selected source means no Display material. Multiple sources are unioned; current Containers are derived from the resolved Displays.
      </div>
    </div>
  `;
  anchor.insertAdjacentElement('afterend', panel);

  el('edit-is-display-setup-step')?.addEventListener('change', saveSelectedDisplaySetupStep);
  el('setup-material-source-add')?.addEventListener('click', addSelectedMaterialSource);
}

function sourceTypeLabel(sourceType) {
  if (sourceType === 'LOR_STAGE') return 'Stages';
  if (sourceType === 'LOR_PREVIEW') return 'Previews';
  return 'Scenes / programming groups';
}

function renderMaterialSourceSelect(task) {
  const select = el('setup-material-source-select');
  if (!select) return;
  const selectedIds = new Set((task?.material_sources || []).map(setupMaterialSourceId));
  const priorValue = select.value;
  select.replaceChildren();

  const placeholder = document.createElement('option');
  placeholder.value = '';
  placeholder.textContent = 'Choose current LOR material source…';
  select.appendChild(placeholder);

  for (const sourceType of ['LOR_STAGE', 'LOR_PREVIEW', 'LOR_SCENE']) {
    const choices = setupMaterialCatalog.filter(
      (source) => source.source_type === sourceType
        && source.available !== false
        && !selectedIds.has(setupMaterialSourceId(source))
    );
    if (!choices.length) continue;
    const group = document.createElement('optgroup');
    group.label = sourceTypeLabel(sourceType);
    for (const source of choices) {
      const option = document.createElement('option');
      option.value = setupMaterialSourceId(source);
      const count = Number(source.display_count || 0);
      option.textContent = `${source.label} · ${count} Display${count === 1 ? '' : 's'}`;
      group.appendChild(option);
    }
    select.appendChild(group);
  }

  if ([...select.options].some((option) => option.value === priorValue)) select.value = priorValue;
}

function renderSelectedMaterialSources(task) {
  const host = el('setup-material-selected-sources');
  if (!host) return;
  host.replaceChildren();
  const sources = task?.material_sources || [];
  if (!sources.length) {
    const empty = document.createElement('div');
    empty.className = 'setup-material-editor-note';
    empty.textContent = 'No Display material selected.';
    host.appendChild(empty);
    return;
  }

  for (const source of sources) {
    const row = document.createElement('div');
    row.className = `setup-material-source-row${source.available === false ? ' setup-material-source-stale' : ''}`;
    const text = document.createElement('span');
    const count = Number(source.display_count || 0);
    text.textContent = source.available === false
      ? source.label
      : `${source.label} · ${count} Display${count === 1 ? '' : 's'}`;
    const remove = document.createElement('button');
    remove.type = 'button';
    remove.className = 'secondary';
    remove.textContent = 'Remove';
    remove.disabled = !Boolean(appState.access?.can_manage_setup);
    remove.addEventListener('click', () => setMaterialSource(source, false));
    row.append(text, remove);
    host.appendChild(row);
  }
}

function applySetupMaterialAccess() {
  const disabled = !Boolean(appState.access?.can_manage_setup);
  const displaySetup = el('edit-is-display-setup-step');
  const sourceSelect = el('setup-material-source-select');
  const sourceAdd = el('setup-material-source-add');
  if (displaySetup) displaySetup.disabled = disabled;
  if (sourceSelect) sourceSelect.disabled = disabled;
  if (sourceAdd) sourceAdd.disabled = disabled;
  document.querySelectorAll('#setup-material-selected-sources button').forEach((button) => { button.disabled = disabled; });
}

function syncSelectedSetupMaterial() {
  installSetupMaterialEditor();
  const task = taskById(appState.selectedTaskId);
  const displaySetup = el('edit-is-display-setup-step');
  if (displaySetup) displaySetup.checked = Boolean(task?.is_display_setup_step);
  renderSelectedMaterialSources(task);
  renderMaterialSourceSelect(task);
  applySetupMaterialAccess();
}

function appendSetupBadge(meta, className, text, title) {
  if (!meta) return;
  const badge = document.createElement('span');
  badge.className = className;
  badge.textContent = text;
  badge.title = title;
  meta.appendChild(badge);
}

function applySetupMaterialBadges() {
  document.querySelectorAll('.setup-material-badge, .setup-material-source-badge').forEach((badge) => badge.remove());
  document.querySelectorAll('.setup-material-task').forEach((row) => row.classList.remove('setup-material-task'));
  document.querySelectorAll('.next-task-row[data-task-id], .library-task[data-task-id], .task-row[data-task-id]').forEach((row) => {
    const task = taskById(Number(row.dataset.taskId || 0));
    if (!task) return;
    const meta = row.querySelector('.next-task-main .task-meta') || row.querySelector('.task-meta');
    if (task.is_display_setup_step) {
      row.classList.add('setup-material-task');
      appendSetupBadge(meta, 'setup-material-badge', 'DISPLAY SETUP', 'Physical Display Setup work classification. Material is selected separately.');
    }
    const sourceCount = Array.isArray(task.material_sources) ? task.material_sources.length : 0;
    if (sourceCount) {
      appendSetupBadge(meta, 'setup-material-source-badge', `MATERIAL ${sourceCount}`, `${sourceCount} explicit current-LOR material source${sourceCount === 1 ? '' : 's'} selected.`);
    }
  });
}

async function loadSetupMaterial({ rerender = true } = {}) {
  const payload = await setupMaterialBaseApi('api/setup/task-display-material');
  setupMaterialCatalog = payload.material_source_catalog || [];
  setupMaterialState.clear();
  for (const item of payload.task_display_material || []) {
    setupMaterialState.set(Number(item.setup_task_id), {
      isDisplaySetupStep: Boolean(item.is_display_setup_step),
      sources: Array.isArray(item.material_sources) ? item.material_sources : []
    });
  }
  applySetupMaterialToTasks();
  syncSelectedSetupMaterial();
  if (rerender && appState.tasks?.length) {
    renderReviewList();
    renderLibrary();
  } else {
    applySetupMaterialBadges();
  }
}

async function saveSelectedDisplaySetupStep() {
  const task = taskById(appState.selectedTaskId);
  const checkbox = el('edit-is-display-setup-step');
  if (!task || !checkbox || !appState.access?.can_manage_setup) return;
  const value = Boolean(checkbox.checked);
  try {
    setBusy(true);
    await setupMaterialBaseApi(`api/setup/tasks/${task.setup_task_id}/display-setup-step`, commandOptions('PATCH', { is_display_setup_step: value }));
    const metadata = { ...setupMaterialMetadata(task.setup_task_id), isDisplaySetupStep: value };
    setupMaterialState.set(Number(task.setup_task_id), metadata);
    task.is_display_setup_step = value;
    renderReviewList();
    renderLibrary();
    syncSelectedSetupMaterial();
    setAlert(value ? 'Display Setup classification enabled.' : 'Display Setup classification removed.', 'ok');
  } catch (error) {
    checkbox.checked = !value;
    setAlert(error.message || error, 'error');
    window.alert(error.message || error);
  } finally {
    setBusy(false);
  }
}

function selectedCatalogSource(value) {
  if (!value || !value.includes('|')) return null;
  const [sourceType, ...rest] = value.split('|');
  const sourceKey = rest.join('|');
  return setupMaterialCatalog.find((source) => source.source_type === sourceType && String(source.source_key) === sourceKey) || null;
}

async function addSelectedMaterialSource() {
  const task = taskById(appState.selectedTaskId);
  const source = selectedCatalogSource(el('setup-material-source-select')?.value);
  if (!task || !source || !appState.access?.can_manage_setup) return;
  await setMaterialSource(source, true);
}

async function setMaterialSource(source, active) {
  const task = taskById(appState.selectedTaskId);
  if (!task || !appState.access?.can_manage_setup) return;
  try {
    setBusy(true);
    await setupMaterialBaseApi(`api/setup/tasks/${task.setup_task_id}/material-source`, commandOptions('PATCH', {
      source_type: source.source_type,
      source_key: String(source.source_key),
      active: Boolean(active)
    }));
    await loadSetupMaterial({ rerender: false });
    renderReviewList();
    renderLibrary();
    syncSelectedSetupMaterial();
    setAlert(active ? 'Display material source added.' : 'Display material source removed.', 'ok');
  } catch (error) {
    setAlert(error.message || error, 'error');
    window.alert(error.message || error);
  } finally {
    setBusy(false);
  }
}

if (typeof renderLibrary === 'function') {
  const setupMaterialBaseRenderLibrary = renderLibrary;
  renderLibrary = function renderLibraryWithSetupMaterial(...args) {
    const result = setupMaterialBaseRenderLibrary(...args);
    applySetupMaterialBadges();
    return result;
  };
}

if (typeof renderReviewList === 'function') {
  const setupMaterialBaseRenderReviewList = renderReviewList;
  renderReviewList = function renderReviewListWithSetupMaterial(...args) {
    const result = setupMaterialBaseRenderReviewList(...args);
    applySetupMaterialBadges();
    return result;
  };
}

if (typeof selectTask === 'function') {
  const setupMaterialBaseSelectTask = selectTask;
  selectTask = function selectTaskWithSetupMaterial(taskId) {
    const result = setupMaterialBaseSelectTask(taskId);
    syncSelectedSetupMaterial();
    return result;
  };
}

const setupAddTaskForm = el('add-task-form');
setupAddTaskForm?.addEventListener('submit', () => {
  if (!appState.access?.can_manage_setup) return;
  const token = Date.now();
  setupNewTaskSubmitToken = token;
  window.setTimeout(() => { if (setupNewTaskSubmitToken === token) setupNewTaskSubmitToken = 0; }, 60000);
}, true);

if (typeof reloadTasks === 'function') {
  const setupMaterialBaseReloadTasks = reloadTasks;
  reloadTasks = async function reloadTasksWithSetupMaterial(...args) {
    const requestedTaskId = args[0];
    const openNewTask = Boolean(setupNewTaskSubmitToken && requestedTaskId != null && el('add-task-form')?.hidden);
    const result = await setupMaterialBaseReloadTasks(...args);
    try {
      await loadSetupMaterial({ rerender: false });
    } catch (error) {
      console.error('Setup material metadata refresh failed', error);
    }
    if (openNewTask && taskById(requestedTaskId)) {
      setupNewTaskSubmitToken = 0;
      showView('review');
      selectTask(Number(requestedTaskId));
      requestAnimationFrame(() => el('edit-task-name')?.focus());
    }
    return result;
  };
}

window.addEventListener('load', () => {
  installSetupMaterialEditor();
  applySetupMaterialAccess();
  loadSetupMaterial().catch((error) => { console.error('Setup material metadata could not be loaded', error); });
});
