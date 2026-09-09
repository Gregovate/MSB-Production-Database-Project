/* Reusable Setup physical-effort hint UI. Requires migration 023. */

const setupEffortState = new Map();

function setupEffortLabel(value) {
  const normalized = String(value || '').trim().toUpperCase();
  return normalized || 'Not reviewed';
}

function applySetupEffortToTasks() {
  for (const task of appState.tasks || []) {
    task.effort_level = setupEffortState.get(Number(task.setup_task_id)) ?? null;
  }
}

function applySetupEffortAccess() {
  const editable = Boolean(appState.access?.can_manage_setup);
  const select = el('edit-effort-level');
  if (select) select.disabled = !editable;
  const button = el('save-task-effort');
  if (button) button.disabled = !editable;
}

function applySetupEffortBadges() {
  document.querySelectorAll('.next-task-row[data-task-id], .library-task[data-task-id]').forEach((row) => {
    const taskId = Number(row.dataset.taskId || 0);
    const task = taskById(taskId);
    if (!task) return;
    const meta = row.querySelector('.next-task-main .task-meta') || row.querySelector('.task-meta');
    if (!meta || meta.querySelector('.setup-effort-badge')) return;
    const badge = document.createElement('span');
    badge.className = 'setup-effort-badge';
    badge.textContent = ` · Effort: ${setupEffortLabel(task.effort_level)}`;
    meta.appendChild(badge);
  });
}

function syncSelectedSetupEffort() {
  const select = el('edit-effort-level');
  if (!select) return;
  const task = taskById(appState.selectedTaskId);
  select.value = task?.effort_level || '';
  applySetupEffortAccess();
}

async function loadSetupEfforts({ rerender = true } = {}) {
  const payload = await api('api/setup/task-efforts');
  setupEffortState.clear();
  for (const item of payload.task_efforts || []) {
    setupEffortState.set(Number(item.setup_task_id), item.effort_level || null);
  }
  applySetupEffortToTasks();
  syncSelectedSetupEffort();
  if (rerender && typeof renderLibrary === 'function') renderLibrary();
  else applySetupEffortBadges();
}

async function saveSelectedSetupEffort() {
  const task = taskById(appState.selectedTaskId);
  if (!task || !appState.access?.can_manage_setup) return;
  const select = el('edit-effort-level');
  if (!select) return;
  const effort = select.value || null;
  try {
    setBusy(true);
    await api(
      `api/setup/tasks/${task.setup_task_id}/effort`,
      commandOptions('PATCH', { effort_level: effort })
    );
    setupEffortState.set(Number(task.setup_task_id), effort);
    task.effort_level = effort;
    renderLibrary();
    setAlert(`Reusable effort saved: ${setupEffortLabel(effort)}.`, 'ok');
  } catch (error) {
    setAlert(error.message || error, 'error');
  } finally {
    setBusy(false);
  }
}

if (typeof renderLibrary === 'function') {
  const setupEffortBaseRenderLibrary = renderLibrary;
  renderLibrary = function renderLibraryWithSetupEffort(...args) {
    const result = setupEffortBaseRenderLibrary(...args);
    applySetupEffortBadges();
    return result;
  };
}

if (typeof selectTask === 'function') {
  const setupEffortBaseSelectTask = selectTask;
  selectTask = function selectTaskWithSetupEffort(taskId) {
    const result = setupEffortBaseSelectTask(taskId);
    syncSelectedSetupEffort();
    return result;
  };
}

if (typeof reloadTasks === 'function') {
  const setupEffortBaseReloadTasks = reloadTasks;
  reloadTasks = async function reloadTasksWithSetupEffort(...args) {
    const result = await setupEffortBaseReloadTasks(...args);
    await loadSetupEfforts({ rerender: false });
    return result;
  };
}

el('save-task-effort')?.addEventListener('click', saveSelectedSetupEffort);

window.addEventListener('load', () => {
  applySetupEffortAccess();
  loadSetupEfforts().catch((error) => {
    console.error('Setup effort metadata could not be loaded', error);
  });
});
