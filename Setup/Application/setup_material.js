/* Setup reusable Display-material marker and Stage/Scene material-context adapter.
 * Issue #122. Task-specific component/KIT pick timing remains deferred to #141.
 */

const setupMaterialState = new Map();
const setupMaterialBaseApi = api;
let setupNewTaskSubmitToken = 0;

function setupMaterialRewritePath(path) {
  const text = String(path || '');
  if (/^\/?api\/setup\/tasks\/\d+\/field-context\?/.test(text)) {
    return text.replace('/field-context?', '/material-context?');
  }
  return text;
}

// The existing Captain/perform UI already consumes the field-context response
// shape. Route only that read through the new governed Stage/Scene material
// resolver so the large planning UI does not gain a second rendering path.
api = async function apiWithSetupMaterial(path, options = {}) {
  return setupMaterialBaseApi(setupMaterialRewritePath(path), options);
};

function applySetupMaterialToTasks() {
  for (const task of appState.tasks || []) {
    task.requires_display_material = Boolean(
      setupMaterialState.get(Number(task.setup_task_id))
    );
  }
}

function installSetupMaterialEditor() {
  if (el('edit-requires-display-material')) return;
  const effortRow = el('setup-effort-editor-row');
  const effortSelect = el('edit-effort-level');
  const anchor = effortRow || effortSelect?.closest('label');
  if (!anchor) return;

  const label = document.createElement('label');
  label.id = 'setup-material-editor';
  label.className = 'checkbox-label setup-material-editor';
  label.title = 'Marks physical Display Setup work and enables current LOR Stage/Scene material context. It does not define staged component pick timing.';
  label.innerHTML = '<input id="edit-requires-display-material" type="checkbox"> Display setup / material context';
  anchor.insertAdjacentElement('afterend', label);

  el('edit-requires-display-material')?.addEventListener('change', saveSelectedSetupMaterial);
}

function applySetupMaterialAccess() {
  const checkbox = el('edit-requires-display-material');
  if (checkbox) checkbox.disabled = !Boolean(appState.access?.can_manage_setup);
}

function syncSelectedSetupMaterial() {
  installSetupMaterialEditor();
  const checkbox = el('edit-requires-display-material');
  if (!checkbox) return;
  const task = taskById(appState.selectedTaskId);
  checkbox.checked = Boolean(task?.requires_display_material);
  applySetupMaterialAccess();
}

function applySetupMaterialBadges() {
  document.querySelectorAll('.setup-material-badge').forEach((badge) => badge.remove());
  document.querySelectorAll('.setup-material-task').forEach((row) => row.classList.remove('setup-material-task'));

  document.querySelectorAll('.next-task-row[data-task-id], .library-task[data-task-id], .task-row[data-task-id]').forEach((row) => {
    const taskId = Number(row.dataset.taskId || 0);
    const task = taskById(taskId);
    if (!task?.requires_display_material) return;

    row.classList.add('setup-material-task');
    const meta = row.querySelector('.next-task-main .task-meta') || row.querySelector('.task-meta');
    if (!meta) return;
    const badge = document.createElement('span');
    badge.className = 'setup-material-badge';
    badge.textContent = 'DISPLAY SETUP';
    badge.title = 'Physical Display Setup step; current Display material is resolved from LOR Stage/Scene scope.';
    meta.appendChild(badge);
  });
}

async function loadSetupMaterial({ rerender = true } = {}) {
  const payload = await setupMaterialBaseApi('api/setup/task-display-material');
  setupMaterialState.clear();
  for (const item of payload.task_display_material || []) {
    setupMaterialState.set(
      Number(item.setup_task_id),
      Boolean(item.requires_display_material)
    );
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

async function saveSelectedSetupMaterial() {
  const task = taskById(appState.selectedTaskId);
  const checkbox = el('edit-requires-display-material');
  if (!task || !checkbox || !appState.access?.can_manage_setup) return;

  const required = Boolean(checkbox.checked);
  try {
    setBusy(true);
    await setupMaterialBaseApi(
      `api/setup/tasks/${task.setup_task_id}/display-material`,
      commandOptions('PATCH', { requires_display_material: required })
    );
    setupMaterialState.set(Number(task.setup_task_id), required);
    task.requires_display_material = required;
    renderReviewList();
    renderLibrary();
    syncSelectedSetupMaterial();
    setAlert(
      required
        ? 'Display setup / material context enabled for this reusable task.'
        : 'Display setup / material context removed from this reusable task.',
      'ok'
    );
  } catch (error) {
    checkbox.checked = !required;
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

// A newly-created Catalog task is only a skeleton. The existing create command
// already reloads with the new task id; use that successful reload as the safe
// handoff into the complete reusable-task editor instead of leaving the user in
// the Catalog with a half-defined task.
const setupAddTaskForm = el('add-task-form');
setupAddTaskForm?.addEventListener('submit', () => {
  if (!appState.access?.can_manage_setup) return;
  const token = Date.now();
  setupNewTaskSubmitToken = token;
  window.setTimeout(() => {
    if (setupNewTaskSubmitToken === token) setupNewTaskSubmitToken = 0;
  }, 60000);
}, true);

if (typeof reloadTasks === 'function') {
  const setupMaterialBaseReloadTasks = reloadTasks;
  reloadTasks = async function reloadTasksWithSetupMaterial(...args) {
    const requestedTaskId = args[0];
    const openNewTask = Boolean(
      setupNewTaskSubmitToken
      && requestedTaskId != null
      && el('add-task-form')?.hidden
    );

    const result = await setupMaterialBaseReloadTasks(...args);
    try {
      await loadSetupMaterial({ rerender: false });
    } catch (error) {
      // Supplemental metadata failure must never make a successfully completed
      // task create/update look like the governed write itself failed.
      console.error('Setup Display material metadata refresh failed', error);
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
  loadSetupMaterial().catch((error) => {
    console.error('Setup Display material metadata could not be loaded', error);
  });
});
