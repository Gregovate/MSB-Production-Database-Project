/* Setup reusable Display-Setup classification and Stage/Scene material-context adapter.
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
// shape. Route only that read through the Stage/Scene material resolver.
api = async function apiWithSetupMaterial(path, options = {}) {
  return setupMaterialBaseApi(setupMaterialRewritePath(path), options);
};

function setupMaterialMetadata(taskId) {
  return setupMaterialState.get(Number(taskId)) || {
    isDisplaySetupStep: false,
    requiresDisplayMaterial: false
  };
}

function applySetupMaterialToTasks() {
  for (const task of appState.tasks || []) {
    const metadata = setupMaterialMetadata(task.setup_task_id);
    task.is_display_setup_step = metadata.isDisplaySetupStep;
    task.requires_display_material = metadata.requiresDisplayMaterial;
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
    <label class="checkbox-label" title="Visual classification for physical Display Setup work. Multiple tasks in one Stage or Scene may be Display Setup steps.">
      <input id="edit-is-display-setup-step" type="checkbox"> Display Setup step
    </label>
    <label class="checkbox-label" title="Use the complete current LOR Display set for this task's Stage/Scene scope. This does not split components or control staged pick timing.">
      <input id="edit-requires-display-material" type="checkbox"> Use whole Stage/Scene Display material
    </label>
    <div class="setup-material-editor-note">Task-specific component/KIT pick timing is deferred; this whole-scope switch must not be used to invent a material split.</div>
  `;
  anchor.insertAdjacentElement('afterend', panel);

  el('edit-is-display-setup-step')?.addEventListener('change', saveSelectedDisplaySetupStep);
  el('edit-requires-display-material')?.addEventListener('change', saveSelectedScopeMaterial);
}

function applySetupMaterialAccess() {
  const disabled = !Boolean(appState.access?.can_manage_setup);
  const displaySetup = el('edit-is-display-setup-step');
  const scopeMaterial = el('edit-requires-display-material');
  if (displaySetup) displaySetup.disabled = disabled;
  if (scopeMaterial) scopeMaterial.disabled = disabled;
}

function syncSelectedSetupMaterial() {
  installSetupMaterialEditor();
  const task = taskById(appState.selectedTaskId);
  const displaySetup = el('edit-is-display-setup-step');
  const scopeMaterial = el('edit-requires-display-material');
  if (displaySetup) displaySetup.checked = Boolean(task?.is_display_setup_step);
  if (scopeMaterial) scopeMaterial.checked = Boolean(task?.requires_display_material);
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
  document.querySelectorAll('.setup-material-badge, .setup-scope-material-badge').forEach((badge) => badge.remove());
  document.querySelectorAll('.setup-material-task').forEach((row) => row.classList.remove('setup-material-task'));

  document.querySelectorAll('.next-task-row[data-task-id], .library-task[data-task-id], .task-row[data-task-id]').forEach((row) => {
    const task = taskById(Number(row.dataset.taskId || 0));
    if (!task) return;
    const meta = row.querySelector('.next-task-main .task-meta') || row.querySelector('.task-meta');

    if (task.is_display_setup_step) {
      row.classList.add('setup-material-task');
      appendSetupBadge(
        meta,
        'setup-material-badge',
        'DISPLAY SETUP',
        'Physical Display Setup work step.'
      );
    }

    if (task.requires_display_material) {
      appendSetupBadge(
        meta,
        'setup-scope-material-badge',
        'SCOPE MATERIAL',
        'This task resolves the complete current LOR Display set for its Stage/Scene scope.'
      );
    }
  });
}

async function loadSetupMaterial({ rerender = true } = {}) {
  const payload = await setupMaterialBaseApi('api/setup/task-display-material');
  setupMaterialState.clear();
  for (const item of payload.task_display_material || []) {
    setupMaterialState.set(Number(item.setup_task_id), {
      isDisplaySetupStep: Boolean(item.is_display_setup_step),
      requiresDisplayMaterial: Boolean(item.requires_display_material)
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

async function saveSelectedMaterialFlag({ checkboxId, endpoint, payloadKey, stateKey, taskKey, enabledMessage, disabledMessage }) {
  const task = taskById(appState.selectedTaskId);
  const checkbox = el(checkboxId);
  if (!task || !checkbox || !appState.access?.can_manage_setup) return;

  const value = Boolean(checkbox.checked);
  try {
    setBusy(true);
    await setupMaterialBaseApi(
      `api/setup/tasks/${task.setup_task_id}/${endpoint}`,
      commandOptions('PATCH', { [payloadKey]: value })
    );
    const metadata = { ...setupMaterialMetadata(task.setup_task_id), [stateKey]: value };
    setupMaterialState.set(Number(task.setup_task_id), metadata);
    task[taskKey] = value;
    renderReviewList();
    renderLibrary();
    syncSelectedSetupMaterial();
    setAlert(value ? enabledMessage : disabledMessage, 'ok');
  } catch (error) {
    checkbox.checked = !value;
    setAlert(error.message || error, 'error');
    window.alert(error.message || error);
  } finally {
    setBusy(false);
  }
}

async function saveSelectedDisplaySetupStep() {
  return saveSelectedMaterialFlag({
    checkboxId: 'edit-is-display-setup-step',
    endpoint: 'display-setup-step',
    payloadKey: 'is_display_setup_step',
    stateKey: 'isDisplaySetupStep',
    taskKey: 'is_display_setup_step',
    enabledMessage: 'Display Setup classification enabled for this reusable task.',
    disabledMessage: 'Display Setup classification removed from this reusable task.'
  });
}

async function saveSelectedScopeMaterial() {
  return saveSelectedMaterialFlag({
    checkboxId: 'edit-requires-display-material',
    endpoint: 'display-material',
    payloadKey: 'requires_display_material',
    stateKey: 'requiresDisplayMaterial',
    taskKey: 'requires_display_material',
    enabledMessage: 'Whole Stage/Scene Display material enabled for this reusable task.',
    disabledMessage: 'Whole Stage/Scene Display material removed from this reusable task.'
  });
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
// handoff into the complete reusable-task editor.
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
